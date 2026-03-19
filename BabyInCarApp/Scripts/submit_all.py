#!/usr/bin/env python3
"""Complete App Store submission: IAP submit, metadata update, build select, submit for review."""

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


def section(title):
    print(f"\n{'='*60}\n{title}\n{'='*60}")


# ============================================================
section("1. SUBMIT NON-CONSUMABLE IAP (Lifetime)")
# ============================================================

iap_id = "6759626284"  # Premium Lifetime
# Use v1 endpoint for IAP submission
data, code = api("post", "/v1/inAppPurchaseSubmissions", {
    "data": {
        "type": "inAppPurchaseSubmissions",
        "relationships": {
            "inAppPurchase": {
                "data": {"type": "inAppPurchases", "id": iap_id}
            }
        }
    }
})
if code < 300:
    print("  ✅ Premium Lifetime IAP submitted for review!")
else:
    print("  ⚠️  Lifetime IAP submission issue (may already be submitted or needs screenshot)")

# ============================================================
section("2. SUBMIT SUBSCRIPTIONS FOR REVIEW")
# ============================================================

# Get subscription groups
groups_data, _ = api("get", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=50")
if groups_data and groups_data.get("data"):
    for group in groups_data["data"]:
        group_id = group["id"]
        group_name = group["attributes"]["referenceName"]
        print(f"\n  Subscription Group: {group_name} (ID: {group_id})")

        # Get subscriptions in this group
        subs_data, _ = api("get", f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=50")
        if subs_data and subs_data.get("data"):
            for sub in subs_data["data"]:
                sub_id = sub["id"]
                sub_attrs = sub.get("attributes", {})
                print(f"    Sub: {sub_attrs.get('name')} ({sub_attrs.get('productId')}) - State: {sub_attrs.get('state')}")

                # Check for review screenshot
                screenshot_data, sc_code = api("get", f"/v1/subscriptions/{sub_id}/appStoreReviewScreenshot")
                has_screenshot = bool(screenshot_data and screenshot_data.get("data"))
                print(f"    Has review screenshot: {has_screenshot}")

                if not has_screenshot:
                    print(f"    ⚠️  Need screenshot before submission!")
                    continue

                # Submit subscription for review
                sub_submit_data, sub_code = api("post", "/v1/subscriptionSubmissions", {
                    "data": {
                        "type": "subscriptionSubmissions",
                        "relationships": {
                            "subscription": {
                                "data": {"type": "subscriptions", "id": sub_id}
                            }
                        }
                    }
                })
                if sub_code < 300:
                    print(f"    ✅ Subscription '{sub_attrs.get('name')}' submitted for review!")
                else:
                    print(f"    ⚠️  Subscription submission issue")

# ============================================================
section("3. WAIT FOR BUILD 9 PROCESSING")
# ============================================================

max_wait = 300  # 5 minutes
waited = 0
build_9_id = None
while waited < max_wait:
    builds_data, _ = api("get", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=3&fields[builds]=version,uploadedDate,processingState")
    if builds_data and builds_data.get("data"):
        for b in builds_data["data"]:
            b_attrs = b.get("attributes", {})
            if b_attrs.get("version") == "9":
                state = b_attrs.get("processingState")
                print(f"  Build 9 processing state: {state}")
                if state == "VALID":
                    build_9_id = b["id"]
                    print(f"  ✅ Build 9 is VALID! ID: {build_9_id}")
                    break
                elif state == "INVALID":
                    print("  ❌ Build 9 is INVALID!")
                    break
        if build_9_id:
            break
    print(f"  Waiting for build processing... ({waited}s)")
    time.sleep(30)
    waited += 30

# Fall back to build 8 if build 9 isn't ready
if not build_9_id:
    print("  Build 9 not ready yet, using build 8...")
    builds_data, _ = api("get", f"/v1/builds?filter[app]={APP_ID}&filter[version]=8&fields[builds]=version,processingState")
    if builds_data and builds_data.get("data"):
        build_9_id = builds_data["data"][0]["id"]
        print(f"  Using build 8 ID: {build_9_id}")

# ============================================================
section("4. SELECT BUILD FOR VERSION")
# ============================================================

# Get the version
versions_data, _ = api("get", f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=REJECTED,PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED&limit=5")
version_id = None
if versions_data and versions_data.get("data"):
    version_id = versions_data["data"][0]["id"]
    v_attrs = versions_data["data"][0]["attributes"]
    print(f"  Version: {v_attrs['versionString']} - State: {v_attrs['appStoreState']}")

    # If REJECTED, we may need to create a new version or just resubmit
    if v_attrs["appStoreState"] == "REJECTED":
        print("  Version is REJECTED - will resubmit with updated build")

if version_id and build_9_id:
    # Select build for this version
    data, code = api("patch", f"/v1/appStoreVersions/{version_id}", {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "relationships": {
                "build": {
                    "data": {"type": "builds", "id": build_9_id}
                }
            }
        }
    })
    if code < 300:
        print(f"  ✅ Build selected for version!")
    else:
        print(f"  ⚠️  Could not select build")

# ============================================================
section("5. UPDATE APP STORE METADATA (Description + EULA)")
# ============================================================

if version_id:
    # Get localizations
    locs_data, _ = api("get", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    if locs_data and locs_data.get("data"):
        for loc in locs_data["data"]:
            loc_id = loc["id"]
            locale = loc["attributes"]["locale"]
            print(f"  Updating locale: {locale}")

            # Read description from file
            desc_path = Path(__file__).parent.parent / "fastlane/metadata/en-US/description.txt"
            description = desc_path.read_text().strip()

            data, code = api("patch", f"/v1/appStoreVersionLocalizations/{loc_id}", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": {
                        "description": description
                    }
                }
            })
            if code < 300:
                print(f"  ✅ Description updated for {locale}!")

# ============================================================
section("6. SUBMIT FOR APP STORE REVIEW")
# ============================================================

if version_id:
    data, code = api("post", "/v1/appStoreVersionSubmissions", {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            }
        }
    })
    if code < 300:
        print("  ✅ APP SUBMITTED FOR REVIEW!")
    else:
        # Try the newer reviewSubmissions endpoint
        print("  Trying newer reviewSubmissions endpoint...")
        data, code = api("post", "/v2/reviewSubmissions", {
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
        if code < 300:
            submission_id = data["data"]["id"]
            print(f"  Review submission created: {submission_id}")

            # Add the version as an item
            data2, code2 = api("post", "/v2/reviewSubmissionItems", {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {"type": "reviewSubmissions", "id": submission_id}
                        },
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    }
                }
            })

            # Confirm submission
            data3, code3 = api("patch", f"/v2/reviewSubmissions/{submission_id}", {
                "data": {
                    "type": "reviewSubmissions",
                    "id": submission_id,
                    "attributes": {
                        "submitted": True
                    }
                }
            })
            if code3 < 300:
                print("  ✅ APP SUBMITTED FOR REVIEW (v2)!")
            else:
                print("  ⚠️  Submission might need manual completion")

print("\n" + "=" * 60)
print("COMPLETE - Check App Store Connect for final status")
print(f"URL: https://appstoreconnect.apple.com/apps/{APP_ID}/appstore")
print("=" * 60)
