#!/usr/bin/env python3
"""Upload App Store screenshots via App Store Connect API."""

import hashlib
import json
import os
import time

import jwt
import requests

# --- Configuration ---
KEY_PATH = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"
BASE_URL = "https://api.appstoreconnect.apple.com"
DISPLAY_TYPE = "APP_IPHONE_67"

SCREENSHOT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/screenshots/en-US"
SCREENSHOT_FILES = [
    "1_home_APP_IPHONE_67_0.png",
    "2_library_APP_IPHONE_67_0.png",
    "3_detect_APP_IPHONE_67_0.png",
    "3_favorites_APP_IPHONE_67_0.png",
    "4_profile_APP_IPHONE_67_0.png",
]


def generate_token():
    """Generate a JWT token for App Store Connect API."""
    with open(KEY_PATH, "r") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1",
    }
    token = jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})
    return token


def api_request(method, path, token, json_data=None, params=None):
    """Make an authenticated API request."""
    url = f"{BASE_URL}{path}" if path.startswith("/") else path
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    resp = requests.request(method, url, headers=headers, json=json_data, params=params)
    return resp


def md5_checksum(filepath):
    """Calculate MD5 checksum of a file."""
    h = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    token = generate_token()
    print("=== Step 1: Get version localizations ===")
    resp = api_request("GET", f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations", token)
    if resp.status_code != 200:
        print(f"FAILED to get localizations: {resp.status_code}")
        print(resp.text)
        return
    localizations = resp.json()["data"]
    en_us_loc = None
    for loc in localizations:
        locale = loc["attributes"]["locale"]
        print(f"  Found locale: {locale} (id: {loc['id']})")
        if locale == "en-US":
            en_us_loc = loc
    if not en_us_loc:
        print("ERROR: en-US localization not found!")
        return
    loc_id = en_us_loc["id"]
    print(f"  Using en-US localization ID: {loc_id}")

    # Step 2: Get existing screenshot sets
    print("\n=== Step 2: Get existing screenshot sets ===")
    resp = api_request("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets", token)
    if resp.status_code != 200:
        print(f"FAILED to get screenshot sets: {resp.status_code}")
        print(resp.text)
        return
    screenshot_sets = resp.json()["data"]
    existing_67_set = None
    for ss in screenshot_sets:
        dt = ss["attributes"]["screenshotDisplayType"]
        print(f"  Found screenshot set: {dt} (id: {ss['id']})")
        if dt == DISPLAY_TYPE:
            existing_67_set = ss

    # Step 3: Delete existing APP_IPHONE_67 screenshot set
    if existing_67_set:
        set_id = existing_67_set["id"]
        print(f"\n=== Step 3: Delete existing {DISPLAY_TYPE} screenshot set ({set_id}) ===")
        # First get existing screenshots in this set and delete them individually
        resp = api_request("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots", token)
        if resp.status_code == 200:
            existing_screenshots = resp.json()["data"]
            for ss in existing_screenshots:
                ss_id = ss["id"]
                print(f"  Deleting screenshot {ss_id}...")
                del_resp = api_request("DELETE", f"/v1/appScreenshots/{ss_id}", token)
                if del_resp.status_code in (200, 204):
                    print(f"    Deleted successfully")
                else:
                    print(f"    Delete failed: {del_resp.status_code} - {del_resp.text}")
        # Now delete the set itself
        resp = api_request("DELETE", f"/v1/appScreenshotSets/{set_id}", token)
        if resp.status_code in (200, 204):
            print(f"  Deleted screenshot set successfully")
        else:
            print(f"  Delete set failed: {resp.status_code} - {resp.text}")
            print("  Continuing anyway...")
    else:
        print(f"\n=== Step 3: No existing {DISPLAY_TYPE} screenshot set to delete ===")

    # Step 4: Create new screenshot set
    print(f"\n=== Step 4: Create new screenshot set for {DISPLAY_TYPE} ===")
    create_set_payload = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {
                "screenshotDisplayType": DISPLAY_TYPE,
            },
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": loc_id,
                    }
                }
            },
        }
    }
    resp = api_request("POST", "/v1/appScreenshotSets", token, json_data=create_set_payload)
    if resp.status_code not in (200, 201):
        print(f"FAILED to create screenshot set: {resp.status_code}")
        print(resp.text)
        return
    new_set_id = resp.json()["data"]["id"]
    print(f"  Created screenshot set: {new_set_id}")

    # Step 5: Upload each screenshot
    print(f"\n=== Step 5: Upload {len(SCREENSHOT_FILES)} screenshots ===")
    for idx, filename in enumerate(SCREENSHOT_FILES):
        filepath = os.path.join(SCREENSHOT_DIR, filename)
        filesize = os.path.getsize(filepath)
        checksum = md5_checksum(filepath)
        print(f"\n--- Screenshot {idx + 1}/{len(SCREENSHOT_FILES)}: {filename} ---")
        print(f"  Size: {filesize} bytes, MD5: {checksum}")

        # 5a: Create screenshot reservation
        print("  Creating reservation...")
        reserve_payload = {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": filename,
                    "fileSize": filesize,
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {
                            "type": "appScreenshotSets",
                            "id": new_set_id,
                        }
                    }
                },
            }
        }
        resp = api_request("POST", "/v1/appScreenshots", token, json_data=reserve_payload)
        if resp.status_code not in (200, 201):
            print(f"  FAILED to create reservation: {resp.status_code}")
            print(f"  {resp.text}")
            continue
        reservation = resp.json()["data"]
        screenshot_id = reservation["id"]
        upload_operations = reservation["attributes"]["uploadOperations"]
        print(f"  Reservation created: {screenshot_id}")
        print(f"  Upload operations: {len(upload_operations)} part(s)")

        # 5b: Upload the binary data
        with open(filepath, "rb") as f:
            file_data = f.read()

        all_uploads_ok = True
        for op_idx, op in enumerate(upload_operations):
            url = op["url"]
            method = op["method"]
            offset = op["offset"]
            length = op["length"]
            req_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}

            chunk = file_data[offset : offset + length]
            print(f"  Uploading part {op_idx + 1}: offset={offset}, length={length}, actual={len(chunk)} bytes")

            upload_resp = requests.request(method, url, headers=req_headers, data=chunk)
            if upload_resp.status_code in (200, 201):
                print(f"    Upload part {op_idx + 1} succeeded (HTTP {upload_resp.status_code})")
            else:
                print(f"    Upload part {op_idx + 1} FAILED: HTTP {upload_resp.status_code}")
                print(f"    Response: {upload_resp.text[:500]}")
                all_uploads_ok = False
                break

        if not all_uploads_ok:
            print(f"  Skipping commit for {filename} due to upload failure")
            continue

        # 5c: Commit the upload
        print(f"  Committing upload...")
        commit_payload = {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": {
                        "type": "md5",
                        "value": checksum,
                    },
                },
            }
        }
        resp = api_request("PATCH", f"/v1/appScreenshots/{screenshot_id}", token, json_data=commit_payload)
        if resp.status_code == 200:
            state = resp.json()["data"]["attributes"].get("assetDeliveryState", {})
            print(f"  Commit succeeded! State: {state.get('state', 'unknown')}")
        else:
            print(f"  Commit FAILED: {resp.status_code}")
            print(f"  {resp.text}")

    print("\n=== DONE ===")
    print("All screenshots have been processed.")


if __name__ == "__main__":
    main()
