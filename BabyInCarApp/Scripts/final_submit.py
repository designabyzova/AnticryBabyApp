#!/usr/bin/env python3
"""Final submission: Fix IAP relationships, upload metadata via fastlane, submit for review."""

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
VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"


def generate_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})


def api(method, path, body=None):
    token = generate_token()
    url = f"{BASE_URL}{path}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    resp = getattr(requests, method)(url, headers=headers, json=body)
    print(f"  {method.upper()} {path} -> {resp.status_code}")
    data = resp.json() if resp.text else None
    if resp.status_code >= 400 and data:
        for err in data.get("errors", []):
            print(f"    ERROR: {err.get('detail', err.get('title', ''))}")
    return data, resp.status_code


# Step 1: Submit IAP using v2 relationship name
print("=" * 60)
print("1. SUBMIT LIFETIME IAP FOR REVIEW")
print("=" * 60)

iap_id = "6759626284"
data, code = api("post", "/v1/inAppPurchaseSubmissions", {
    "data": {
        "type": "inAppPurchaseSubmissions",
        "relationships": {
            "inAppPurchaseV2": {
                "data": {"type": "inAppPurchases", "id": iap_id}
            }
        }
    }
})
if code < 300:
    print("  ✅ Premium Lifetime IAP submitted!")
elif code == 409:
    print("  Already submitted or conflict - checking state...")
    iap_data, _ = api("get", f"/v2/inAppPurchases/{iap_id}?fields[inAppPurchases]=name,productId,state")
    if iap_data and iap_data.get("data"):
        state = iap_data["data"]["attributes"]["state"]
        print(f"  Current state: {state}")
        if state == "WAITING_FOR_REVIEW":
            print("  ✅ Already waiting for review!")

# Step 2: Submit subscriptions
print("\n" + "=" * 60)
print("2. SUBMIT SUBSCRIPTIONS FOR REVIEW")
print("=" * 60)

sub_ids = {
    "6759626176": "Premium Monthly",
    "6759626071": "Premium Yearly"
}

for sub_id, sub_name in sub_ids.items():
    print(f"\n  Submitting: {sub_name} ({sub_id})")
    data, code = api("post", "/v1/subscriptionSubmissions", {
        "data": {
            "type": "subscriptionSubmissions",
            "relationships": {
                "subscription": {
                    "data": {"type": "subscriptions", "id": sub_id}
                }
            }
        }
    })
    if code < 300:
        print(f"  ✅ {sub_name} submitted!")
    else:
        # Check current state
        sub_data, _ = api("get", f"/v1/subscriptions/{sub_id}?fields[subscriptions]=name,productId,state")
        if sub_data and sub_data.get("data"):
            state = sub_data["data"]["attributes"]["state"]
            print(f"  Current state: {state}")


# Step 3: Create review submission using v1 endpoint
print("\n" + "=" * 60)
print("3. SUBMIT APP FOR REVIEW")
print("=" * 60)

# Try creating a review submission
data, code = api("post", "/v1/reviewSubmissions", {
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
})

if code < 300 and data and data.get("data"):
    submission_id = data["data"]["id"]
    print(f"  Review submission created: {submission_id}")

    # Add version as review item
    data2, code2 = api("post", "/v1/reviewSubmissionItems", {
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
    })
    if code2 < 300:
        print("  ✅ Version added to review submission!")

    # Confirm/submit the review
    data3, code3 = api("patch", f"/v1/reviewSubmissions/{submission_id}", {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {
                "submitted": True
            }
        }
    })
    if code3 < 300:
        print("  ✅✅✅ APP SUBMITTED FOR APP STORE REVIEW! ✅✅✅")
    else:
        print("  ⚠️  Could not finalize review submission")
        # Check what's blocking
        items_data, _ = api("get", f"/v1/reviewSubmissions/{submission_id}/items")
        if items_data:
            print(f"  Items: {json.dumps(items_data.get('data', []), indent=2)[:500]}")
else:
    print("  ⚠️  Could not create review submission via API")
    print("  → Manual submission may be needed via App Store Connect")
    print(f"  → URL: https://appstoreconnect.apple.com/apps/{APP_ID}/appstore/ios/version/deliverable")

# Step 4: Final status check
print("\n" + "=" * 60)
print("4. FINAL STATUS CHECK")
print("=" * 60)

# Check version state
ver_data, _ = api("get", f"/v1/appStoreVersions/{VERSION_ID}?fields[appStoreVersions]=appStoreState,versionString")
if ver_data and ver_data.get("data"):
    state = ver_data["data"]["attributes"]["appStoreState"]
    version = ver_data["data"]["attributes"]["versionString"]
    print(f"  Version {version} state: {state}")

# Check IAP states
iap_data, _ = api("get", f"/v2/inAppPurchases/{iap_id}?fields[inAppPurchases]=name,productId,state")
if iap_data and iap_data.get("data"):
    print(f"  Lifetime IAP state: {iap_data['data']['attributes']['state']}")

for sub_id, sub_name in sub_ids.items():
    sub_data, _ = api("get", f"/v1/subscriptions/{sub_id}?fields[subscriptions]=name,state")
    if sub_data and sub_data.get("data"):
        print(f"  {sub_name} state: {sub_data['data']['attributes']['state']}")

print("\n" + "=" * 60)
print("DONE")
print("=" * 60)
