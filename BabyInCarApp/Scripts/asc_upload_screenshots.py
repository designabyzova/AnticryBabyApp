#!/usr/bin/env python3
"""
App Store Connect: Cancel review, replace APP_IPHONE_67 screenshots, resubmit.
"""

import json
import hashlib
import os
import time
import sys
import jwt
import requests
from datetime import datetime, timezone, timedelta

# -- Config --
KEY_PATH = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
APP_ID = "6756977992"
VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"
BASE = "https://api.appstoreconnect.apple.com"

SCREENSHOT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/screenshots/en-US"
SCREENSHOTS = [
    "1_home_APP_IPHONE_67_0.png",
    "2_library_APP_IPHONE_67_0.png",
    "3_detect_APP_IPHONE_67_0.png",
    "3_favorites_APP_IPHONE_67_0.png",
    "4_profile_APP_IPHONE_67_0.png",
]

# -- JWT Token --
def make_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = datetime.now(timezone.utc)
    payload = {
        "iss": ISSUER_ID,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=20)).timestamp()),
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})

TOKEN = make_token()
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}


def api(method, path, body=None, label=""):
    url = f"{BASE}{path}" if path.startswith("/") else path
    r = requests.request(method, url, headers=HEADERS, json=body)
    status = r.status_code
    tag = f"[{label}]" if label else ""
    try:
        data = r.json()
    except Exception:
        data = r.text
    print(f"  {method} {path[:120]}  => {status} {tag}")
    if status >= 400:
        print(f"  ERROR: {json.dumps(data, indent=2)[:2000]}")
    return status, data


# =========================================================================
# STEP 1: Cancel current review submission
# =========================================================================
print("\n" + "="*70)
print("STEP 1: Cancel current review submission")
print("="*70)

status, data = api("GET",
    f"/v1/apps/{APP_ID}/reviewSubmissions?filter[state]=WAITING_FOR_REVIEW,IN_REVIEW",
    label="find review submissions")

submission_id = None
if status == 200 and data.get("data"):
    for sub in data["data"]:
        sid = sub["id"]
        state = sub["attributes"]["state"]
        print(f"  Found submission {sid} in state {state}")
        submission_id = sid
        break

if submission_id:
    print(f"  Canceling submission {submission_id}...")
    cancel_body = {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {
                "canceled": True
            }
        }
    }
    status, data = api("PATCH", f"/v1/reviewSubmissions/{submission_id}",
                        cancel_body, label="cancel submission")
    if status in (200, 204):
        print(f"  Submission canceled successfully.")
    else:
        print(f"  Cancel may have failed, continuing anyway...")
    print("  Waiting 5 seconds for state to propagate...")
    time.sleep(5)
else:
    print("  No active review submissions found. Continuing...")

# =========================================================================
# STEP 2: Verify version is back to editable state
# =========================================================================
print("\n" + "="*70)
print("STEP 2: Verify version is editable")
print("="*70)

for attempt in range(3):
    status, data = api("GET", f"/v1/appStoreVersions/{VERSION_ID}",
                        label="check version state")
    if status == 200:
        state = data["data"]["attributes"]["appStoreState"]
        print(f"  Version state: {state}")
        if state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
                      "METADATA_REJECTED", "INVALID_BINARY", "READY_FOR_REVIEW"):
            print("  Version is editable.")
            break
        else:
            print(f"  State is still {state}, waiting 5 more seconds...")
            time.sleep(5)
    else:
        break

# =========================================================================
# STEP 3: Get en-US localization ID
# =========================================================================
print("\n" + "="*70)
print("STEP 3: Get en-US localization ID")
print("="*70)

status, data = api("GET",
    f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations",
    label="get localizations")

loc_id = None
if status == 200:
    for loc in data["data"]:
        locale = loc["attributes"]["locale"]
        if locale == "en-US":
            loc_id = loc["id"]
            print(f"  en-US localization ID: {loc_id}")
            break
    if not loc_id:
        print("  en-US not found! Available locales:")
        for loc in data["data"]:
            print(f"    - {loc['attributes']['locale']} (id: {loc['id']})")
        sys.exit(1)

# =========================================================================
# STEP 4: Delete existing APP_IPHONE_67 screenshot sets
# =========================================================================
print("\n" + "="*70)
print("STEP 4: Delete existing APP_IPHONE_67 screenshot sets")
print("="*70)

status, data = api("GET",
    f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
    label="get screenshot sets")

if status == 200:
    for ss_set in data["data"]:
        display_type = ss_set["attributes"]["screenshotDisplayType"]
        set_id = ss_set["id"]
        if display_type == "APP_IPHONE_67":
            print(f"  Found APP_IPHONE_67 set: {set_id}")

            # Get screenshots in this set
            s2, screenshots_data = api("GET",
                f"/v1/appScreenshotSets/{set_id}/appScreenshots",
                label="get screenshots in set")

            if s2 == 200 and screenshots_data.get("data"):
                for ss in screenshots_data["data"]:
                    ss_id = ss["id"]
                    fname = ss["attributes"].get("fileName", "?")
                    print(f"    Deleting screenshot {ss_id} ({fname})...")
                    api("DELETE", f"/v1/appScreenshots/{ss_id}",
                        label=f"delete screenshot {fname}")
                    time.sleep(0.5)

            print(f"  Deleting set {set_id}...")
            api("DELETE", f"/v1/appScreenshotSets/{set_id}",
                label="delete screenshot set")
            time.sleep(1)
        else:
            print(f"  Skipping {display_type} set")

# =========================================================================
# STEP 5: Create new APP_IPHONE_67 screenshot set
# =========================================================================
print("\n" + "="*70)
print("STEP 5: Create new APP_IPHONE_67 screenshot set")
print("="*70)

create_set_body = {
    "data": {
        "type": "appScreenshotSets",
        "attributes": {
            "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
            "appStoreVersionLocalization": {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id
                }
            }
        }
    }
}

status, data = api("POST", "/v1/appScreenshotSets", create_set_body,
                    label="create screenshot set")

new_set_id = None
if status == 201:
    new_set_id = data["data"]["id"]
    print(f"  New screenshot set ID: {new_set_id}")
else:
    print("  Failed to create screenshot set!")
    sys.exit(1)

# =========================================================================
# STEP 6: Upload each screenshot
# =========================================================================
print("\n" + "="*70)
print("STEP 6: Upload screenshots")
print("="*70)

for i, filename in enumerate(SCREENSHOTS, 1):
    filepath = os.path.join(SCREENSHOT_DIR, filename)
    filesize = os.path.getsize(filepath)

    with open(filepath, "rb") as f:
        file_bytes = f.read()

    md5_hex = hashlib.md5(file_bytes).hexdigest()

    print(f"\n  [{i}/5] {filename} ({filesize:,} bytes, md5={md5_hex})")

    # a) Reserve the upload
    reserve_body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": filename,
                "fileSize": filesize
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": new_set_id
                    }
                }
            }
        }
    }

    status, data = api("POST", "/v1/appScreenshots", reserve_body,
                        label=f"reserve upload {filename}")

    if status != 201:
        print(f"  FAILED to reserve upload for {filename}, skipping!")
        continue

    screenshot_id = data["data"]["id"]
    upload_ops = data["data"]["attributes"].get("uploadOperations", [])
    print(f"    Screenshot ID: {screenshot_id}, upload operations: {len(upload_ops)}")

    # b) Upload binary data
    all_uploads_ok = True
    for op_idx, op in enumerate(upload_ops):
        url = op["url"]
        method = op["method"]
        offset = op["offset"]
        length = op["length"]
        req_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}

        chunk = file_bytes[offset:offset + length]

        # Use raw PUT, not JSON
        r = requests.request(method, url, headers=req_headers, data=chunk)
        if r.status_code < 300:
            print(f"    Upload part {op_idx+1}/{len(upload_ops)}: {r.status_code} OK "
                  f"(offset={offset}, length={length})")
        else:
            print(f"    Upload part {op_idx+1}/{len(upload_ops)}: {r.status_code} FAILED")
            print(f"    Response: {r.text[:500]}")
            all_uploads_ok = False

    if not all_uploads_ok:
        print(f"  Some upload parts failed for {filename}!")
        continue

    # c) Commit the upload
    commit_body = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": md5_hex
            }
        }
    }

    status, data = api("PATCH", f"/v1/appScreenshots/{screenshot_id}",
                        commit_body, label=f"commit {filename}")

    if status == 200:
        asset_state = data["data"]["attributes"].get("assetDeliveryState", {})
        print(f"    Commit OK. State: {asset_state.get('state', 'unknown')}")

    # Small delay between uploads
    time.sleep(1)

# Wait for processing
print("\n  Waiting 5 seconds for screenshot processing...")
time.sleep(5)

# =========================================================================
# STEP 7: Resubmit for review
# =========================================================================
print("\n" + "="*70)
print("STEP 7: Resubmit for review")
print("="*70)

# Create review submission
create_sub_body = {
    "data": {
        "type": "reviewSubmissions",
        "attributes": {
            "platform": "IOS"
        },
        "relationships": {
            "app": {
                "data": {
                    "type": "apps",
                    "id": APP_ID
                }
            }
        }
    }
}

status, data = api("POST", "/v1/reviewSubmissions", create_sub_body,
                    label="create review submission")

new_submission_id = None
if status == 201:
    new_submission_id = data["data"]["id"]
    print(f"  New submission ID: {new_submission_id}")
else:
    print("  Failed to create review submission!")
    sys.exit(1)

# Add version as submission item
item_body = {
    "data": {
        "type": "reviewSubmissionItems",
        "relationships": {
            "reviewSubmission": {
                "data": {
                    "type": "reviewSubmissions",
                    "id": new_submission_id
                }
            },
            "appStoreVersion": {
                "data": {
                    "type": "appStoreVersions",
                    "id": VERSION_ID
                }
            }
        }
    }
}

status, data = api("POST", "/v1/reviewSubmissionItems", item_body,
                    label="add version to submission")

# Submit for review
submit_body = {
    "data": {
        "type": "reviewSubmissions",
        "id": new_submission_id,
        "attributes": {
            "submitted": True
        }
    }
}

status, data = api("PATCH", f"/v1/reviewSubmissions/{new_submission_id}",
                    submit_body, label="submit for review")

if status == 200:
    final_state = data["data"]["attributes"]["state"]
    print(f"  Submitted! State: {final_state}")
else:
    print("  Submission may have failed. Check App Store Connect.")

print("\n" + "="*70)
print("DONE!")
print("="*70)
