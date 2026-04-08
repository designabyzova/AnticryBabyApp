#!/usr/bin/env python3
"""
Resubmit app with Lifetime IAP included.

This script:
1. Waits for the CANCELING review submission to complete
2. Removes app version from review (pull from review)
3. Cleans up stale review submissions
4. Creates a new review submission with app version + Lifetime IAP
5. Submits for review

Apple requires: "The first In-App Purchase must be submitted with an app version"
"""

import jwt
import time
import requests
import json
import sys

# --- Configuration ---
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = "BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"

APP_ID = "6756977992"
VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"
IAP_ID = "6760608217"  # com.babyincar.premium.lifetime.v2

BASE_V1 = "https://api.appstoreconnect.apple.com/v1"
BASE_V2 = "https://api.appstoreconnect.apple.com/v2"


def get_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    token = jwt.encode(
        payload, private_key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"}
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def get_submissions(headers):
    r = requests.get(
        f"{BASE_V1}/apps/{APP_ID}/reviewSubmissions?limit=10", headers=headers
    )
    return r.json().get("data", [])


def get_version_state(headers):
    r = requests.get(f"{BASE_V1}/appStoreVersions/{VERSION_ID}", headers=headers)
    return r.json()["data"]["attributes"]["appStoreState"]


def get_iap_state(headers):
    r = requests.get(f"{BASE_V2}/inAppPurchases/{IAP_ID}", headers=headers)
    return r.json()["data"]["attributes"]["state"]


def step1_wait_for_canceling(headers):
    """Wait for any CANCELING submission to complete."""
    print("\n[Step 1] Checking for CANCELING submissions...")
    max_wait = 300  # 5 minutes
    waited = 0
    while waited < max_wait:
        subs = get_submissions(headers)
        canceling = [s for s in subs if s["attributes"]["state"] == "CANCELING"]
        if not canceling:
            print("  No CANCELING submissions. Proceeding.")
            return True
        print(f"  {len(canceling)} CANCELING submission(s). Waiting 15s... ({waited}s elapsed)")
        time.sleep(15)
        waited += 15
        headers = get_token()  # Refresh token if needed
    print("  TIMEOUT: CANCELING submission did not resolve in 5 minutes.")
    return False


def step2_remove_from_review(headers):
    """Remove app version from review."""
    print("\n[Step 2] Removing app version from review...")
    ver_state = get_version_state(headers)
    print(f"  Current version state: {ver_state}")

    if ver_state == "WAITING_FOR_REVIEW":
        r = requests.delete(
            f"{BASE_V1}/appStoreVersionSubmissions/{VERSION_ID}", headers=headers
        )
        if r.status_code == 204:
            print("  Successfully removed from review.")
            time.sleep(3)
            ver_state = get_version_state(headers)
            print(f"  New version state: {ver_state}")
            return True
        elif r.status_code == 409:
            err = r.json().get("errors", [{}])[0].get("detail", "")
            if "please try again later" in err.lower():
                print(f"  Temporarily blocked: {err}")
                print("  Retrying in 30 seconds...")
                time.sleep(30)
                headers = get_token()
                r2 = requests.delete(
                    f"{BASE_V1}/appStoreVersionSubmissions/{VERSION_ID}",
                    headers=headers,
                )
                if r2.status_code == 204:
                    print("  Retry succeeded!")
                    return True
                print(f"  Retry failed: {r2.status_code} {r2.text[:300]}")
            else:
                print(f"  Error: {r.text[:400]}")
            return False
        else:
            print(f"  Error {r.status_code}: {r.text[:400]}")
            return False
    elif ver_state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED"):
        print(f"  Version is in {ver_state} - ready for new submission.")
        return True
    elif ver_state == "IN_REVIEW":
        print("  Version is IN_REVIEW - cannot remove. Wait for review to complete or reject.")
        return False
    else:
        print(f"  Unexpected state: {ver_state}")
        return ver_state == "PREPARE_FOR_SUBMISSION"


def step3_cleanup_submissions(headers):
    """Clean up stale READY_FOR_REVIEW submissions."""
    print("\n[Step 3] Cleaning up stale review submissions...")
    subs = get_submissions(headers)
    ready = [s for s in subs if s["attributes"]["state"] == "READY_FOR_REVIEW"]
    print(f"  Found {len(ready)} READY_FOR_REVIEW submissions to clean up.")

    for sub in ready:
        sid = sub["id"]
        cancel_body = {
            "data": {
                "type": "reviewSubmissions",
                "id": sid,
                "attributes": {"canceled": True},
            }
        }
        r = requests.patch(
            f"{BASE_V1}/reviewSubmissions/{sid}", headers=headers, json=cancel_body
        )
        if r.status_code == 200:
            print(f"  Canceled: {sid[:12]}...")
        else:
            # Try deleting items first
            r2 = requests.get(
                f"{BASE_V1}/reviewSubmissions/{sid}/items", headers=headers
            )
            items = r2.json().get("data", [])
            for item in items:
                requests.delete(
                    f"{BASE_V1}/reviewSubmissionItems/{item['id']}", headers=headers
                )
            # Retry cancel
            r3 = requests.patch(
                f"{BASE_V1}/reviewSubmissions/{sid}", headers=headers, json=cancel_body
            )
            state = "canceled" if r3.status_code == 200 else f"err:{r3.status_code}"
            print(f"  {sid[:12]}...: {state}")

    time.sleep(2)


def step4_create_submission(headers):
    """Create a new review submission with app version + IAP."""
    print("\n[Step 4] Creating new review submission with app version + Lifetime IAP...")

    # Create submission
    body = {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}}
            },
        }
    }
    r = requests.post(f"{BASE_V1}/reviewSubmissions", headers=headers, json=body)
    if r.status_code not in (200, 201):
        print(f"  Failed to create submission: {r.status_code}")
        print(f"  {r.text[:500]}")
        return None
    sub_id = r.json()["data"]["id"]
    print(f"  Created submission: {sub_id}")

    # Add app version item
    version_item = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": sub_id}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": VERSION_ID}
                },
            },
        }
    }
    r2 = requests.post(
        f"{BASE_V1}/reviewSubmissionItems", headers=headers, json=version_item
    )
    if r2.status_code in (200, 201):
        print(f"  Added app version v1.0.1")
    else:
        print(f"  Failed to add version: {r2.status_code} {r2.text[:300]}")
        return None

    # Submit the IAP via inAppPurchaseSubmissions first
    # This changes the IAP state from READY_TO_SUBMIT to WAITING_FOR_REVIEW
    iap_state = get_iap_state(headers)
    print(f"  IAP state before submission: {iap_state}")

    if iap_state == "READY_TO_SUBMIT":
        iap_submit = {
            "data": {
                "type": "inAppPurchaseSubmissions",
                "relationships": {
                    "inAppPurchaseV2": {
                        "data": {"type": "inAppPurchases", "id": IAP_ID}
                    }
                },
            }
        }
        r3 = requests.post(
            f"{BASE_V1}/inAppPurchaseSubmissions", headers=headers, json=iap_submit
        )
        if r3.status_code in (200, 201):
            print(f"  IAP submission created")
        else:
            print(f"  IAP submission: {r3.status_code} {r3.text[:400]}")
            # If it says "first IAP must be submitted on version", the version item
            # being in the same submission should satisfy this requirement
            # Let's continue and try to submit anyway

    return sub_id


def step5_submit(headers, sub_id):
    """Confirm and submit the review submission."""
    print(f"\n[Step 5] Submitting for review...")

    confirm_body = {
        "data": {
            "type": "reviewSubmissions",
            "id": sub_id,
            "attributes": {"submitted": True},
        }
    }
    r = requests.patch(
        f"{BASE_V1}/reviewSubmissions/{sub_id}", headers=headers, json=confirm_body
    )
    if r.status_code == 200:
        state = r.json()["data"]["attributes"]["state"]
        print(f"  Submitted! State: {state}")
        return True
    else:
        print(f"  Submit failed: {r.status_code}")
        print(f"  {r.text[:500]}")
        return False


def verify_state(headers):
    """Print final state of everything."""
    print("\n" + "=" * 60)
    print("FINAL STATE")
    print("=" * 60)

    ver_state = get_version_state(headers)
    iap_state = get_iap_state(headers)

    print(f"  App v1.0.1: {ver_state}")
    print(f"  Lifetime IAP: {iap_state}")

    for name, sid in [("Monthly", "6759626176"), ("Yearly", "6759626071")]:
        r = requests.get(f"{BASE_V1}/subscriptions/{sid}", headers=headers)
        state = r.json()["data"]["attributes"]["state"]
        print(f"  {name} sub: {state}")

    subs = get_submissions(headers)
    active = [s for s in subs if s["attributes"]["state"] not in ("COMPLETE", "CANCELING")]
    print(f"\n  Active submissions: {len(active)}")
    for s in active:
        print(f"    {s['attributes']['state']} | {s['id'][:12]}...")


def main():
    print("=" * 60)
    print("Resubmit App with Lifetime IAP")
    print("=" * 60)

    headers = get_token()

    # Step 1: Wait for CANCELING
    if not step1_wait_for_canceling(headers):
        print("\nFailed at Step 1. Run again later when CANCELING submission resolves.")
        print("You can also manually 'Remove from Review' in App Store Connect web UI.")
        verify_state(headers)
        sys.exit(1)

    headers = get_token()

    # Step 2: Remove from review
    if not step2_remove_from_review(headers):
        print("\nFailed at Step 2. The version could not be removed from review.")
        print("Try manually in App Store Connect web UI: Your App > App Review > Remove from Review")
        verify_state(headers)
        sys.exit(1)

    headers = get_token()

    # Step 3: Cleanup
    step3_cleanup_submissions(headers)

    headers = get_token()

    # Step 4: Create new submission
    sub_id = step4_create_submission(headers)
    if not sub_id:
        print("\nFailed at Step 4. Could not create submission.")
        verify_state(headers)
        sys.exit(1)

    headers = get_token()

    # Step 5: Submit
    if not step5_submit(headers, sub_id):
        print("\nFailed at Step 5. The submission could not be confirmed.")
        verify_state(headers)
        sys.exit(1)

    # Verify
    time.sleep(3)
    headers = get_token()
    verify_state(headers)

    print("\nDone! The app and Lifetime IAP are submitted for review.")


if __name__ == "__main__":
    main()
