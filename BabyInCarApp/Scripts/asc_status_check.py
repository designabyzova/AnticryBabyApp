#!/usr/bin/env python3
"""
App Store Connect API Status Checker
Queries all app versions, TestFlight builds, and current live/review status.
"""

import jwt
import time
import requests
import json
from datetime import datetime

# === Configuration ===
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"
BASE_URL = "https://api.appstoreconnect.apple.com"


def generate_jwt_token():
    """Generate a JWT token for App Store Connect API authentication."""
    with open(KEY_FILE, "r") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1",
    }
    headers = {
        "alg": "ES256",
        "kid": KEY_ID,
        "typ": "JWT",
    }
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    return token


def api_get(token, path, params=None):
    """Make a GET request to the ASC API."""
    url = f"{BASE_URL}{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    response = requests.get(url, headers=headers, params=params)
    if response.status_code != 200:
        print(f"  ERROR {response.status_code}: {response.text[:500]}")
        return None
    return response.json()


def format_date(iso_str):
    """Format an ISO date string to a readable format."""
    if not iso_str:
        return "N/A"
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except Exception:
        return iso_str


def print_separator(char="=", length=80):
    print(char * length)


def main():
    print_separator()
    print("  APP STORE CONNECT STATUS CHECK")
    print(f"  App ID: {APP_ID}")
    print(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print_separator()

    # Generate JWT
    print("\nGenerating JWT token...")
    token = generate_jwt_token()
    print("Token generated successfully.\n")

    # ─── 1. App Store Versions ────────────────────────────────────────────
    print_separator()
    print("  APP STORE VERSIONS")
    print_separator()

    versions_data = api_get(
        token,
        f"/v1/apps/{APP_ID}/appStoreVersions",
        params={
            "limit": 20,
            "fields[appStoreVersions]": "versionString,appStoreState,createdDate,releaseType,platform",
        },
    )

    live_version = None
    in_review_version = None

    if versions_data and "data" in versions_data:
        versions = versions_data["data"]
        print(f"\nFound {len(versions)} version(s):\n")
        print(f"  {'Version':<12} {'Platform':<10} {'State':<35} {'Created'}")
        print(f"  {'-'*12} {'-'*10} {'-'*35} {'-'*25}")

        for v in versions:
            attrs = v.get("attributes", {})
            version_str = attrs.get("versionString", "?")
            state = attrs.get("appStoreState", "UNKNOWN")
            created = format_date(attrs.get("createdDate"))
            platform = attrs.get("platform", "?")
            release_type = attrs.get("releaseType", "?")

            marker = ""
            if state in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION"):
                live_version = version_str
                marker = " <-- LIVE"
            elif "REVIEW" in state.upper():
                in_review_version = version_str
                marker = " <-- IN REVIEW"
            elif "WAITING" in state.upper():
                marker = " <-- WAITING"
            elif "REJECTED" in state.upper():
                marker = " <-- REJECTED"

            print(f"  {version_str:<12} {platform:<10} {state:<35} {created}{marker}")
    else:
        print("\n  No versions found or API error.\n")

    # ─── 2. TestFlight Builds ─────────────────────────────────────────────
    print()
    print_separator()
    print("  TESTFLIGHT BUILDS (Recent)")
    print_separator()

    builds_data = api_get(
        token,
        "/v1/builds",
        params={
            "filter[app]": APP_ID,
            "sort": "-uploadedDate",
            "limit": 15,
            "include": "preReleaseVersion,buildBetaDetail",
        },
    )

    if builds_data and "data" in builds_data:
        builds = builds_data["data"]
        included = builds_data.get("included", [])

        # Index included resources
        included_map = {}
        for inc in included:
            included_map[inc["id"]] = inc

        print(f"\nFound {len(builds)} recent build(s):\n")
        print(f"  {'Version':<10} {'Build':<10} {'Processing':<15} {'Internal':<22} {'External':<22} {'Uploaded'}")
        print(f"  {'-'*10} {'-'*10} {'-'*15} {'-'*22} {'-'*22} {'-'*25}")

        for b in builds:
            attrs = b.get("attributes", {})
            build_num = attrs.get("version", "?")
            processing = attrs.get("processingState", "?")
            uploaded = format_date(attrs.get("uploadedDate"))

            # Get pre-release version (app version string)
            version_str = "?"
            rels = b.get("relationships", {})
            prv_data = rels.get("preReleaseVersion", {}).get("data")
            if prv_data and prv_data.get("id") in included_map:
                prv = included_map[prv_data["id"]]
                version_str = prv.get("attributes", {}).get("version", "?")

            # Get beta detail (internal/external states)
            internal_state = "?"
            external_state = "?"
            bbd_data = rels.get("buildBetaDetail", {}).get("data")
            if bbd_data and bbd_data.get("id") in included_map:
                bbd = included_map[bbd_data["id"]]
                bbd_attrs = bbd.get("attributes", {})
                internal_state = bbd_attrs.get("internalBuildState", "?")
                external_state = bbd_attrs.get("externalBuildState", "?")

            print(f"  {version_str:<10} {build_num:<10} {processing:<15} {internal_state:<22} {external_state:<22} {uploaded}")
    else:
        print("\n  No builds found or API error.\n")

    # ─── 3. In-App Purchases ──────────────────────────────────────────────
    print()
    print_separator()
    print("  IN-APP PURCHASES")
    print_separator()

    iap_data = api_get(
        token,
        f"/v1/apps/{APP_ID}/inAppPurchasesV2",
        params={
            "limit": 20,
            "fields[inAppPurchases]": "name,productId,inAppPurchaseType,state,reviewNote",
        },
    )

    if iap_data and "data" in iap_data:
        iaps = iap_data["data"]
        print(f"\nFound {len(iaps)} IAP(s):\n")
        print(f"  {'Name':<30} {'Product ID':<40} {'Type':<25} {'State'}")
        print(f"  {'-'*30} {'-'*40} {'-'*25} {'-'*25}")

        for iap in iaps:
            attrs = iap.get("attributes", {})
            name = attrs.get("name", "?")
            product_id = attrs.get("productId", "?")
            iap_type = attrs.get("inAppPurchaseType", "?")
            state = attrs.get("state", "?")
            print(f"  {name:<30} {product_id:<40} {iap_type:<25} {state}")
    else:
        print("\n  No IAPs found or API error.\n")

    # ─── 4. Subscriptions ─────────────────────────────────────────────────
    print()
    print_separator()
    print("  SUBSCRIPTION GROUPS")
    print_separator()

    sub_groups_data = api_get(
        token,
        f"/v1/apps/{APP_ID}/subscriptionGroups",
        params={
            "limit": 20,
            "fields[subscriptionGroups]": "referenceName",
        },
    )

    if sub_groups_data and "data" in sub_groups_data:
        groups = sub_groups_data["data"]
        print(f"\nFound {len(groups)} subscription group(s):\n")

        for group in groups:
            group_id = group["id"]
            group_name = group.get("attributes", {}).get("referenceName", "?")
            print(f"  Group: {group_name} (ID: {group_id})")

            # Fetch subscriptions in this group
            subs_data = api_get(
                token,
                f"/v1/subscriptionGroups/{group_id}/subscriptions",
                params={
                    "limit": 20,
                    "fields[subscriptions]": "name,productId,state,subscriptionPeriod",
                },
            )

            if subs_data and "data" in subs_data:
                subs = subs_data["data"]
                for sub in subs:
                    s_attrs = sub.get("attributes", {})
                    s_name = s_attrs.get("name", "?")
                    s_pid = s_attrs.get("productId", "?")
                    s_state = s_attrs.get("state", "?")
                    s_period = s_attrs.get("subscriptionPeriod", "?")
                    print(f"    - {s_name:<25} {s_pid:<40} {s_period:<15} {s_state}")
    else:
        print("\n  No subscription groups found or API error.\n")

    # ─── Summary ──────────────────────────────────────────────────────────
    print()
    print_separator()
    print("  SUMMARY")
    print_separator()
    if live_version:
        print(f"\n  LIVE version:      {live_version}")
    else:
        print("\n  LIVE version:      None found")
    if in_review_version:
        print(f"  IN REVIEW version: {in_review_version}")
    else:
        print("  IN REVIEW version: None")
    print()
    print_separator()


if __name__ == "__main__":
    main()
