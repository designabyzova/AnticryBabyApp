#!/usr/bin/env python3
"""
App Store Connect API: Upload en-US metadata for v1.1.0 and attach build 42.

Tasks:
1. Upload/update en-US localization metadata (description, keywords, etc.)
2. Attach build d72cf1c1-... to version 289aea31-...
3. Verify everything is set correctly
"""

import json
import time
import datetime
import sys
import os

import jwt
import requests

# ── Auth Config ──────────────────────────────────────────────────────────────
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"

# ── Known IDs ────────────────────────────────────────────────────────────────
APP_ID = "6756977992"
VERSION_ID = "289aea31-4d88-4b29-a961-748933412198"
BUILD_ID = "d72cf1c1-f242-460f-a2f6-bdfe9b8c5c6a"

# ── Metadata files ───────────────────────────────────────────────────────────
METADATA_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/metadata/en-US"

BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def generate_token():
    """Generate a JWT for App Store Connect API."""
    with open(KEY_FILE, "r") as f:
        private_key = f.read()

    now = datetime.datetime.now(datetime.timezone.utc)
    exp = now + datetime.timedelta(minutes=20)

    payload = {
        "iss": ISSUER_ID,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "aud": "appstoreconnect-v1",
    }

    token = jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})
    return token


def headers():
    """Return authorization headers."""
    token = generate_token()
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def read_file(filename):
    """Read a text file from the metadata directory."""
    path = os.path.join(METADATA_DIR, filename)
    with open(path, "r") as f:
        return f.read().strip()


def api_get(path):
    """GET request to ASC API."""
    url = f"{BASE_URL}{path}"
    print(f"  GET {url}")
    resp = requests.get(url, headers=headers())
    if resp.status_code != 200:
        print(f"  ERROR {resp.status_code}: {resp.text}")
    return resp


def api_patch(path, payload):
    """PATCH request to ASC API."""
    url = f"{BASE_URL}{path}"
    print(f"  PATCH {url}")
    resp = requests.patch(url, headers=headers(), json=payload)
    if resp.status_code not in (200, 204):
        print(f"  ERROR {resp.status_code}: {resp.text}")
    return resp


def api_post(path, payload):
    """POST request to ASC API."""
    url = f"{BASE_URL}{path}"
    print(f"  POST {url}")
    resp = requests.post(url, headers=headers(), json=payload)
    if resp.status_code not in (200, 201):
        print(f"  ERROR {resp.status_code}: {resp.text}")
    return resp


# ─────────────────────────────────────────────────────────────────────────────
# TASK 1: Upload en-US localization metadata
# ─────────────────────────────────────────────────────────────────────────────
def task1_upload_localization():
    print("=" * 70)
    print("TASK 1: Upload en-US localization metadata")
    print("=" * 70)

    # Step 1: Get existing localizations for the version
    print("\n[1.1] Fetching existing localizations...")
    resp = api_get(f"/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations")
    if resp.status_code != 200:
        print("FAILED to fetch localizations.")
        return None

    data = resp.json()
    localizations = data.get("data", [])

    print(f"  Found {len(localizations)} localization(s):")
    en_us_id = None
    for loc in localizations:
        locale = loc["attributes"].get("locale", "unknown")
        loc_id = loc["id"]
        print(f"    - {locale} (ID: {loc_id})")
        if locale == "en-US":
            en_us_id = loc_id

    # Step 2: Read metadata files
    print("\n[1.2] Reading metadata files...")
    description = read_file("description.txt")
    whats_new = read_file("release_notes.txt")
    print(f"  description.txt: {len(description)} chars")
    print(f"  release_notes.txt: {len(whats_new)} chars")

    keywords = "baby sleep,cry detection,lullaby,soothing,newborn,infant,car seat,carplay,baby music,classical"
    marketing_url = "https://lulla-app.pages.dev"
    promotional_text = "AI-powered baby soothing for peaceful car rides. Cry detection automatically plays calming sounds!"
    support_url = "https://lulla-app.pages.dev/support"

    attributes = {
        "description": description,
        "keywords": keywords,
        "marketingUrl": marketing_url,
        "promotionalText": promotional_text,
        "supportUrl": support_url,
        "whatsNew": whats_new,
    }

    # Step 3: Create or update the en-US localization
    if en_us_id:
        print(f"\n[1.3] en-US localization exists (ID: {en_us_id}). Updating via PATCH...")
        payload = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": en_us_id,
                "attributes": attributes,
            }
        }
        resp = api_patch(f"/appStoreVersionLocalizations/{en_us_id}", payload)
    else:
        print("\n[1.3] en-US localization NOT found. Creating via POST...")
        payload = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {
                    **attributes,
                    "locale": "en-US",
                },
                "relationships": {
                    "appStoreVersion": {
                        "data": {
                            "type": "appStoreVersions",
                            "id": VERSION_ID,
                        }
                    }
                },
            }
        }
        resp = api_post(f"/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations", payload)

    if resp.status_code in (200, 201):
        result = resp.json()
        loc_id = result["data"]["id"]
        attrs = result["data"]["attributes"]
        print(f"\n  SUCCESS! Localization ID: {loc_id}")
        print(f"  locale:          {attrs.get('locale')}")
        print(f"  description:     {len(attrs.get('description', '') or '')} chars")
        print(f"  keywords:        {attrs.get('keywords')}")
        print(f"  marketingUrl:    {attrs.get('marketingUrl')}")
        print(f"  promotionalText: {(attrs.get('promotionalText') or '')[:60]}...")
        print(f"  supportUrl:      {attrs.get('supportUrl')}")
        print(f"  whatsNew:        {len(attrs.get('whatsNew', '') or '')} chars")
        return loc_id
    else:
        print(f"\n  FAILED ({resp.status_code})")
        return en_us_id


# ─────────────────────────────────────────────────────────────────────────────
# TASK 2: Attach build 42 to version 1.1.0
# ─────────────────────────────────────────────────────────────────────────────
def task2_attach_build():
    print("\n" + "=" * 70)
    print("TASK 2: Attach build 42 to version 1.1.0")
    print("=" * 70)

    print(f"\n[2.1] Attaching build {BUILD_ID[:12]}... to version {VERSION_ID[:12]}...")
    payload = {
        "data": {
            "type": "builds",
            "id": BUILD_ID,
        }
    }
    resp = api_patch(f"/appStoreVersions/{VERSION_ID}/relationships/build", payload)

    if resp.status_code in (200, 204):
        print("  SUCCESS! Build attached to version.")
        return True
    else:
        print(f"  FAILED ({resp.status_code})")
        return False


# ─────────────────────────────────────────────────────────────────────────────
# TASK 3: Verify everything
# ─────────────────────────────────────────────────────────────────────────────
def task3_verify():
    print("\n" + "=" * 70)
    print("TASK 3: Verify version, build, and metadata")
    print("=" * 70)

    # 3.1: Get version details with build relationship
    print("\n[3.1] Fetching version details...")
    resp = api_get(f"/appStoreVersions/{VERSION_ID}?include=build")
    if resp.status_code == 200:
        data = resp.json()
        ver_attrs = data["data"]["attributes"]
        print(f"  Version:     {ver_attrs.get('versionString')}")
        print(f"  State:       {ver_attrs.get('appStoreState')}")
        print(f"  Created:     {ver_attrs.get('createdDate')}")

        # Check if build is included
        included = data.get("included", [])
        build_found = False
        for item in included:
            if item["type"] == "builds":
                build_attrs = item["attributes"]
                print(f"  Build:       {build_attrs.get('version')} (uploaded: {build_attrs.get('uploadedDate', 'N/A')})")
                print(f"  Build ID:    {item['id']}")
                print(f"  Processing:  {build_attrs.get('processingState', 'N/A')}")
                build_found = True
        if not build_found:
            # Check relationship data
            build_rel = data["data"].get("relationships", {}).get("build", {}).get("data")
            if build_rel:
                print(f"  Build ID:    {build_rel['id']} (attached)")
                build_found = True
            else:
                print("  Build:       NOT ATTACHED")
    else:
        print(f"  FAILED to fetch version ({resp.status_code})")
        build_found = False

    # 3.2: Get localization details
    print("\n[3.2] Fetching en-US localization details...")
    resp = api_get(f"/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations")
    localization_ok = False
    if resp.status_code == 200:
        data = resp.json()
        for loc in data.get("data", []):
            if loc["attributes"].get("locale") == "en-US":
                attrs = loc["attributes"]
                desc = attrs.get("description") or ""
                wn = attrs.get("whatsNew") or ""
                print(f"  Locale:          en-US")
                print(f"  Description:     {'SET' if desc else 'MISSING'} ({len(desc)} chars)")
                print(f"  Keywords:        {attrs.get('keywords') or 'MISSING'}")
                print(f"  Marketing URL:   {attrs.get('marketingUrl') or 'MISSING'}")
                print(f"  Promotional:     {'SET' if attrs.get('promotionalText') else 'MISSING'}")
                print(f"  Support URL:     {attrs.get('supportUrl') or 'MISSING'}")
                print(f"  What's New:      {'SET' if wn else 'MISSING'} ({len(wn)} chars)")
                localization_ok = bool(desc and wn and attrs.get("keywords"))
                break
        else:
            print("  en-US localization NOT FOUND")

    # 3.3: Check what's still needed
    print("\n[3.3] Checking submission readiness...")

    # Get app store review detail
    resp = api_get(f"/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
    review_detail = False
    if resp.status_code == 200:
        rd = resp.json().get("data", {}).get("attributes", {})
        contact_email = rd.get("contactEmail")
        contact_phone = rd.get("contactPhone")
        contact_first = rd.get("contactFirstName")
        contact_last = rd.get("contactLastName")
        demo_user = rd.get("demoAccountName")
        notes = rd.get("notes")
        print(f"  Review Contact:  {contact_first} {contact_last} ({contact_email})")
        print(f"  Review Phone:    {contact_phone}")
        print(f"  Demo Account:    {demo_user or 'Not set'}")
        print(f"  Review Notes:    {(notes or 'None')[:80]}")
        review_detail = bool(contact_email)
    else:
        print(f"  Review detail: Could not fetch ({resp.status_code})")

    # Check screenshots
    print("\n[3.4] Checking screenshot sets...")
    resp = api_get(f"/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations")
    if resp.status_code == 200:
        for loc in resp.json().get("data", []):
            if loc["attributes"].get("locale") == "en-US":
                loc_id = loc["id"]
                ss_resp = api_get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
                if ss_resp.status_code == 200:
                    ss_data = ss_resp.json().get("data", [])
                    if ss_data:
                        for ss_set in ss_data:
                            display_type = ss_set["attributes"].get("screenshotDisplayType", "unknown")
                            print(f"  Screenshot set:  {display_type}")
                    else:
                        print("  Screenshots:     NONE uploaded yet")
                break

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    checks = {
        "en-US metadata (description, keywords, whatsNew)": localization_ok,
        "Build attached to version": build_found,
        "Review contact info": review_detail,
    }

    all_good = True
    for check, status in checks.items():
        icon = "PASS" if status else "NEEDS ATTENTION"
        if not status:
            all_good = False
        print(f"  [{icon}] {check}")

    print()
    if all_good:
        print("  All verified checks PASSED.")
    else:
        print("  Some items may still need attention before submission.")

    print("\n  Remaining steps for full submission:")
    print("  - Upload screenshots for all required device sizes")
    print("  - Upload IAP review screenshot (if applicable)")
    print("  - Set app rating/age rating (if not already done)")
    print("  - Set pricing and availability (if not already done)")
    print("  - Submit for review via ASC or API")


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("App Store Connect API - Metadata Upload & Build Attach")
    print(f"App ID:     {APP_ID}")
    print(f"Version ID: {VERSION_ID}")
    print(f"Build ID:   {BUILD_ID}")
    print()

    loc_id = task1_upload_localization()
    build_ok = task2_attach_build()
    task3_verify()
