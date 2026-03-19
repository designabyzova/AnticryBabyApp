#!/usr/bin/env python3
"""Fix IAP availability and submit IAPs for review via App Store Connect API."""

import json
import time
import jwt
import requests
from pathlib import Path

KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = Path(__file__).parent.parent / "fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"
BASE_URL = "https://api.appstoreconnect.apple.com"


def generate_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})


def api_request(method, path, body=None):
    token = generate_token()
    url = f"{BASE_URL}{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    resp = getattr(requests, method)(url, headers=headers, json=body)
    print(f"  {method.upper()} {path} -> {resp.status_code}")
    if resp.text:
        data = resp.json()
        if resp.status_code >= 400:
            for err in data.get("errors", []):
                print(f"    ERROR: {err.get('detail', err.get('title', ''))}")
        return data
    return None


print("=" * 60)
print("APP STORE CONNECT - IAP FIX & METADATA UPDATE")
print("=" * 60)

# Step 1: List all IAPs
print("\n--- Step 1: List all In-App Purchases ---")
iaps = api_request("get", f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=50")

if iaps and iaps.get("data"):
    for iap in iaps["data"]:
        attrs = iap.get("attributes", {})
        print(f"\n  IAP: {attrs.get('name')} ({attrs.get('productId')})")
        print(f"    State: {attrs.get('state')}, Type: {attrs.get('inAppPurchaseType')}")
        print(f"    ID: {iap['id']}")

        iap_id = iap["id"]
        product_id = attrs.get("productId", "")

        # Step 2: Fix Lifetime availability
        if product_id == "com.babyincar.premium.lifetime":
            print("\n--- Step 2: Fix Lifetime availability (set to ALL territories) ---")

            # Get all territories
            all_territories = []
            next_url = "/v1/territories?limit=200"
            while next_url:
                terr_resp = api_request("get", next_url)
                if terr_resp and terr_resp.get("data"):
                    all_territories.extend(terr_resp["data"])
                    next_link = terr_resp.get("links", {}).get("next")
                    next_url = next_link.replace(BASE_URL, "") if next_link else None
                else:
                    break
            print(f"  Found {len(all_territories)} territories")

            # Create InAppPurchaseAvailability
            avail_body = {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "inAppPurchase": {
                            "data": {"type": "inAppPurchases", "id": iap_id}
                        },
                        "availableTerritories": {
                            "data": [
                                {"type": "territories", "id": t["id"]}
                                for t in all_territories
                            ]
                        },
                    },
                }
            }
            result = api_request("post", "/v1/inAppPurchaseAvailabilities", avail_body)
            if result and result.get("data"):
                print("  ✅ Lifetime availability set to ALL territories!")
            elif result:
                # Try check if already set
                print("  Checking current availability...")
                check = api_request(
                    "get", f"/v2/inAppPurchases/{iap_id}?fields[inAppPurchases]=availableInAllTerritories,name,productId,state"
                )
                if check and check.get("data"):
                    is_available = check["data"].get("attributes", {}).get("availableInAllTerritories")
                    print(f"  availableInAllTerritories: {is_available}")

        # Step 3: Submit each IAP for review
        print(f"\n--- Step 3: Submit IAP '{attrs.get('name')}' for review ---")

        # Check if it has a review screenshot
        screenshot_resp = api_request(
            "get", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot"
        )
        has_screenshot = bool(
            screenshot_resp and screenshot_resp.get("data")
        )
        print(f"  Has review screenshot: {has_screenshot}")

        if not has_screenshot:
            print("  ⚠️  Needs a review screenshot before submission!")
            print(f"  → Upload at: https://appstoreconnect.apple.com/apps/{APP_ID}/distribution/iaps")
            continue

        submission_body = {
            "data": {
                "type": "inAppPurchaseSubmissions",
                "relationships": {
                    "inAppPurchase": {
                        "data": {"type": "inAppPurchases", "id": iap_id}
                    }
                },
            }
        }
        result = api_request("post", "/v2/inAppPurchaseSubmissions", submission_body)
        if result and result.get("data"):
            print(f"  ✅ IAP '{attrs.get('name')}' submitted for review!")
        else:
            print(f"  ⚠️  Could not submit - check App Store Connect")
else:
    print("  No IAPs found via v2 endpoint, trying subscriptions...")
    subs = api_request("get", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=50")
    if subs and subs.get("data"):
        for group in subs["data"]:
            print(f"\n  Subscription Group: {group['attributes']['referenceName']}")
            group_subs = api_request(
                "get", f"/v1/subscriptionGroups/{group['id']}/subscriptions?limit=50"
            )
            if group_subs and group_subs.get("data"):
                for sub in group_subs["data"]:
                    sub_attrs = sub.get("attributes", {})
                    print(f"    Sub: {sub_attrs.get('name')} ({sub_attrs.get('productId')}) - State: {sub_attrs.get('state')}")

# Step 4: Check app store version
print("\n--- Step 4: Check App Store Version ---")
versions = api_request(
    "get",
    f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,REJECTED,DEVELOPER_REJECTED&limit=5",
)
if versions and versions.get("data"):
    for v in versions["data"]:
        v_attrs = v.get("attributes", {})
        print(f"  Version: {v_attrs.get('versionString')} - State: {v_attrs.get('appStoreState')}")
        print(f"  Version ID: {v['id']}")

# Step 5: Check builds
print("\n--- Step 5: Check available builds ---")
builds = api_request(
    "get",
    f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5&fields[builds]=version,uploadedDate,processingState,buildAudienceType",
)
if builds and builds.get("data"):
    for b in builds["data"]:
        b_attrs = b.get("attributes", {})
        print(f"  Build {b_attrs.get('version')} - Processing: {b_attrs.get('processingState')} - Uploaded: {b_attrs.get('uploadedDate')}")

print("\n" + "=" * 60)
print("DONE")
print("=" * 60)
