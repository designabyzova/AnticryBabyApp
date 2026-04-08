#!/usr/bin/env python3
"""
Upload IAP review screenshots, subscription promotional image, and resubmit for review.

Fixes App Store rejection 2.1.0 Performance: App Completeness
- Uploads review screenshot for Lifetime IAP (MISSING_METADATA)
- Uploads subscription group promotional image (1024x1024)
- Submits IAP + subscriptions for review
- Resubmits app for review
"""

import hashlib
import json
import os
import sys
import time

import jwt
import requests

# -- Config --
KEY_PATH = os.path.join(os.path.dirname(__file__), "..", "fastlane", "keys", "AuthKey_JZ2ML9M66A.p8")
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
APP_ID = "6756977992"
BASE = "https://api.appstoreconnect.apple.com"

VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"

# IAP and Subscription IDs
LIFETIME_IAP_ID = "6760608217"  # com.babyincar.premium.lifetime.v2

SUBSCRIPTION_IDS = {
    "6759626176": "Premium Monthly",   # com.babyincar.premium.monthly
    "6759626071": "Premium Yearly",    # com.babyincar.premium.yearly
}

SUBSCRIPTION_GROUP_LOC_ID = "590ef632-038c-4426-9560-7355b4d564c6"  # en-US

# Screenshot paths
REVIEW_SCREENSHOTS_DIR = os.path.join(
    os.path.dirname(__file__), "..", "fastlane", "metadata", "review_screenshots"
)

IAP_SCREENSHOT_MAP = {
    # product_id -> (resource_type, resource_id, screenshot_file, api_prefix)
    "lifetime": {
        "file": os.path.join(REVIEW_SCREENSHOTS_DIR, "iap_review_lifetime_premium.png"),
        "id": LIFETIME_IAP_ID,
        "type": "iap",  # inAppPurchase
    },
}

SUBSCRIPTION_SCREENSHOT_MAP = {
    "6759626176": os.path.join(REVIEW_SCREENSHOTS_DIR, "iap_review_monthly_premium.png"),
    "6759626071": os.path.join(REVIEW_SCREENSHOTS_DIR, "iap_review_yearly_premium.png"),
}

PROMO_IMAGE = os.path.join(REVIEW_SCREENSHOTS_DIR, "iap_promotional_1024x1024.png")
# Also check alternative location
PROMO_IMAGE_ALT = os.path.join(
    os.path.dirname(__file__), "..", "fastlane", "metadata", "subscription_promo_1024x1024.png"
)


# -- JWT Token --
def make_token():
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


def api(method, path, body=None, label=""):
    token = make_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    url = f"{BASE}{path}" if path.startswith("/") else path
    r = requests.request(method, url, headers=headers, json=body)
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


def upload_screenshot_file(filepath, reserve_url, reserve_body, label=""):
    """Upload a screenshot file using the App Store Connect upload flow:
    1. Reserve upload slot
    2. Upload binary data to Apple's CDN
    3. Commit the upload
    """
    filesize = os.path.getsize(filepath)
    with open(filepath, "rb") as f:
        file_bytes = f.read()
    md5_hex = hashlib.md5(file_bytes).hexdigest()

    filename = os.path.basename(filepath)
    print(f"\n  Uploading: {filename} ({filesize:,} bytes, md5={md5_hex}) {label}")

    # 1. Reserve
    status, data = api("POST", reserve_url, reserve_body, label=f"reserve {filename}")
    if status != 201:
        print(f"  FAILED to reserve upload for {filename}")
        return None

    screenshot_id = data["data"]["id"]
    upload_ops = data["data"]["attributes"].get("uploadOperations", [])
    print(f"    ID: {screenshot_id}, upload operations: {len(upload_ops)}")

    # 2. Upload binary data
    all_ok = True
    for op_idx, op in enumerate(upload_ops):
        url = op["url"]
        method = op["method"]
        offset = op["offset"]
        length = op["length"]
        req_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        chunk = file_bytes[offset:offset + length]

        r = requests.request(method, url, headers=req_headers, data=chunk)
        if r.status_code < 300:
            print(f"    Upload part {op_idx + 1}/{len(upload_ops)}: {r.status_code} OK")
        else:
            print(f"    Upload part {op_idx + 1}/{len(upload_ops)}: {r.status_code} FAILED")
            print(f"    Response: {r.text[:500]}")
            all_ok = False

    if not all_ok:
        print(f"  Some upload parts failed for {filename}!")
        return None

    # 3. Commit
    resource_type = data["data"]["type"]
    commit_body = {
        "data": {
            "type": resource_type,
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": md5_hex,
            },
        }
    }
    status, data = api("PATCH", f"/v1/{resource_type}/{screenshot_id}", commit_body, label=f"commit {filename}")
    if status == 200:
        asset_state = data["data"]["attributes"].get("assetDeliveryState", {})
        print(f"    Commit OK. State: {asset_state.get('state', 'unknown')}")
        return screenshot_id
    else:
        print(f"    Commit FAILED!")
        return None


def section(title):
    print(f"\n{'=' * 70}")
    print(title)
    print("=" * 70)


# =========================================================================
section("STEP 1: Upload review screenshot for Lifetime IAP")
# =========================================================================

lifetime_file = IAP_SCREENSHOT_MAP["lifetime"]["file"]
if not os.path.exists(lifetime_file):
    print(f"  ERROR: File not found: {lifetime_file}")
    sys.exit(1)

filesize = os.path.getsize(lifetime_file)
reserve_body = {
    "data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {
            "fileName": os.path.basename(lifetime_file),
            "fileSize": filesize,
        },
        "relationships": {
            "inAppPurchaseV2": {
                "data": {
                    "type": "inAppPurchases",
                    "id": LIFETIME_IAP_ID,
                }
            }
        },
    }
}

lifetime_ss_id = upload_screenshot_file(
    lifetime_file,
    "/v1/inAppPurchaseAppStoreReviewScreenshots",
    reserve_body,
    label="Lifetime IAP review screenshot",
)

if lifetime_ss_id:
    print(f"  Lifetime IAP screenshot uploaded! ID: {lifetime_ss_id}")
else:
    print("  WARNING: Lifetime IAP screenshot upload may have failed")

time.sleep(2)

# =========================================================================
section("STEP 2: Replace review screenshots for Monthly & Yearly subscriptions")
# =========================================================================

for sub_id, sub_name in SUBSCRIPTION_IDS.items():
    screenshot_file = SUBSCRIPTION_SCREENSHOT_MAP.get(sub_id)
    if not screenshot_file or not os.path.exists(screenshot_file):
        print(f"  Skipping {sub_name}: no screenshot file found")
        continue

    print(f"\n  Processing: {sub_name} (ID: {sub_id})")

    # Check if screenshot already exists -- delete it first if so
    status, data = api("GET", f"/v1/subscriptions/{sub_id}/appStoreReviewScreenshot",
                       label=f"check existing screenshot for {sub_name}")

    if status == 200 and data.get("data"):
        existing_id = data["data"]["id"]
        print(f"    Existing screenshot found: {existing_id} - deleting...")
        del_status, _ = api("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{existing_id}",
                           label=f"delete old screenshot for {sub_name}")
        if del_status in (200, 204):
            print(f"    Deleted old screenshot")
        time.sleep(1)

    # Upload new screenshot
    filesize = os.path.getsize(screenshot_file)
    reserve_body = {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {
                "fileName": os.path.basename(screenshot_file),
                "fileSize": filesize,
            },
            "relationships": {
                "subscription": {
                    "data": {
                        "type": "subscriptions",
                        "id": sub_id,
                    }
                }
            },
        }
    }

    ss_id = upload_screenshot_file(
        screenshot_file,
        "/v1/subscriptionAppStoreReviewScreenshots",
        reserve_body,
        label=f"{sub_name} review screenshot",
    )

    if ss_id:
        print(f"  {sub_name} screenshot uploaded! ID: {ss_id}")
    else:
        print(f"  WARNING: {sub_name} screenshot upload may have failed")

    time.sleep(1)

# =========================================================================
section("STEP 3: Upload subscription group promotional image (1024x1024)")
# =========================================================================

promo_file = PROMO_IMAGE if os.path.exists(PROMO_IMAGE) else PROMO_IMAGE_ALT
if not os.path.exists(promo_file):
    print(f"  WARNING: No promotional image found at {PROMO_IMAGE} or {PROMO_IMAGE_ALT}")
    print("  Skipping promotional image upload")
else:
    print(f"  Using promotional image: {promo_file}")

    # Check if promotional image already exists
    status, data = api("GET",
        f"/v1/subscriptionGroupLocalizations/{SUBSCRIPTION_GROUP_LOC_ID}/subscriptionGroupLocalization",
        label="check subscription group localization")

    # Upload the promotional image to the subscription group localization
    filesize = os.path.getsize(promo_file)
    reserve_body = {
        "data": {
            "type": "subscriptionImages",
            "attributes": {
                "fileName": os.path.basename(promo_file),
                "fileSize": filesize,
            },
            "relationships": {
                "subscriptionGroup": {
                    "data": {
                        "type": "subscriptionGroups",
                        "id": "21948535",  # Premium group
                    }
                }
            },
        }
    }

    # Try the subscription image endpoint
    print("  Attempting promotional image upload...")
    ss_id = upload_screenshot_file(
        promo_file,
        "/v1/subscriptionImages",
        reserve_body,
        label="subscription group promo image",
    )

    if ss_id:
        print(f"  Promotional image uploaded! ID: {ss_id}")
    else:
        print("  Note: Promotional image may need manual upload via App Store Connect")
        print(f"  URL: https://appstoreconnect.apple.com/apps/{APP_ID}/distribution/subscriptions")

time.sleep(2)

# =========================================================================
section("STEP 4: Submit Lifetime IAP for review")
# =========================================================================

status, data = api("POST", "/v1/inAppPurchaseSubmissions", {
    "data": {
        "type": "inAppPurchaseSubmissions",
        "relationships": {
            "inAppPurchase": {
                "data": {"type": "inAppPurchases", "id": LIFETIME_IAP_ID}
            }
        }
    }
}, label="submit Lifetime IAP for review")

if status < 300:
    print("  Lifetime IAP submitted for review!")
elif status == 409:
    print("  Lifetime IAP already submitted or conflict -- checking state...")
    s, d = api("GET", f"/v2/inAppPurchases/{LIFETIME_IAP_ID}?fields[inAppPurchases]=name,productId,state",
               label="check lifetime state")
    if d and d.get("data"):
        state = d["data"]["attributes"]["state"]
        print(f"  Current state: {state}")
else:
    print("  WARNING: Could not submit Lifetime IAP")

# =========================================================================
section("STEP 5: Submit subscriptions for review")
# =========================================================================

for sub_id, sub_name in SUBSCRIPTION_IDS.items():
    print(f"\n  Submitting: {sub_name} (ID: {sub_id})")
    status, data = api("POST", "/v1/subscriptionSubmissions", {
        "data": {
            "type": "subscriptionSubmissions",
            "relationships": {
                "subscription": {
                    "data": {"type": "subscriptions", "id": sub_id}
                }
            }
        }
    }, label=f"submit {sub_name} for review")

    if status < 300:
        print(f"  {sub_name} submitted for review!")
    elif status == 409:
        print(f"  {sub_name} already submitted or in review")
    else:
        # Check state
        s, d = api("GET", f"/v1/subscriptions/{sub_id}?fields[subscriptions]=name,productId,state",
                   label=f"check {sub_name} state")
        if d and d.get("data"):
            print(f"  Current state: {d['data']['attributes']['state']}")

time.sleep(2)

# =========================================================================
section("STEP 6: Verify all IAP/subscription states before app submission")
# =========================================================================

# Check Lifetime IAP state
s, d = api("GET", f"/v2/inAppPurchases/{LIFETIME_IAP_ID}?fields[inAppPurchases]=name,productId,state",
           label="verify Lifetime IAP state")
if d and d.get("data"):
    state = d["data"]["attributes"]["state"]
    print(f"  Lifetime IAP: {state}")

# Check subscription states
for sub_id, sub_name in SUBSCRIPTION_IDS.items():
    s, d = api("GET", f"/v1/subscriptions/{sub_id}?fields[subscriptions]=name,productId,state",
               label=f"verify {sub_name} state")
    if d and d.get("data"):
        state = d["data"]["attributes"]["state"]
        print(f"  {sub_name}: {state}")

# =========================================================================
section("STEP 7: Resubmit app for review")
# =========================================================================

# Verify version state
status, data = api("GET", f"/v1/appStoreVersions/{VERSION_ID}?fields[appStoreVersions]=appStoreState,versionString",
                   label="check version state")
if status == 200 and data.get("data"):
    state = data["data"]["attributes"]["appStoreState"]
    version = data["data"]["attributes"]["versionString"]
    print(f"  Version {version} state: {state}")

# Create review submission
status, data = api("POST", "/v1/reviewSubmissions", {
    "data": {
        "type": "reviewSubmissions",
        "attributes": {
            "platform": "IOS"
        },
        "relationships": {
            "app": {
                "data": {"type": "apps", "id": APP_ID}
            }
        }
    }
}, label="create review submission")

submission_id = None
if status == 201 and data.get("data"):
    submission_id = data["data"]["id"]
    print(f"  Review submission created: {submission_id}")
else:
    print("  Failed to create review submission!")
    print("  Checking for existing submissions...")
    s, d = api("GET", f"/v1/apps/{APP_ID}/reviewSubmissions?filter[state]=WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED&limit=5",
               label="check existing submissions")
    if d and d.get("data"):
        for sub in d["data"]:
            print(f"  Found: {sub['id']} - {sub['attributes']['state']}")

if submission_id:
    # Add version as review item
    status, data = api("POST", "/v1/reviewSubmissionItems", {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": submission_id}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": VERSION_ID}
                }
            }
        }
    }, label="add version to review submission")

    # Submit for review
    status, data = api("PATCH", f"/v1/reviewSubmissions/{submission_id}", {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {
                "submitted": True
            }
        }
    }, label="finalize review submission")

    if status == 200:
        final_state = data["data"]["attributes"]["state"]
        print(f"\n  APP SUBMITTED FOR REVIEW! State: {final_state}")
    else:
        print("\n  Submission may need manual completion")
        print(f"  URL: https://appstoreconnect.apple.com/apps/{APP_ID}/appstore/ios/version/deliverable")

# =========================================================================
section("FINAL STATUS")
# =========================================================================

# Check version state
s, d = api("GET", f"/v1/appStoreVersions/{VERSION_ID}?fields[appStoreVersions]=appStoreState,versionString",
           label="final version state")
if d and d.get("data"):
    state = d["data"]["attributes"]["appStoreState"]
    version = d["data"]["attributes"]["versionString"]
    print(f"  Version {version}: {state}")

# Check latest review submission
s, d = api("GET", f"/v1/apps/{APP_ID}/reviewSubmissions?limit=3&sort=-submittedDate",
           label="final review submission state")
if d and d.get("data"):
    for sub in d["data"]:
        print(f"  Submission {sub['id']}: {sub['attributes']['state']}")

print(f"\n  App Store Connect: https://appstoreconnect.apple.com/apps/{APP_ID}/appstore")
print("\n" + "=" * 70)
print("DONE!")
print("=" * 70)
