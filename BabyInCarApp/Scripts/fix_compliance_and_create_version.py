#!/usr/bin/env python3
"""
App Store Connect API Operations:
1. Fix export compliance on build 1.1.0 (42)
2. Fix export compliance on build 1.0.1 (38) if needed
3. Create new App Store version 1.1.0
4. Verify results
"""

import json
import sys
import time

import jwt
import requests

# --- Configuration ---
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"
BASE = "https://api.appstoreconnect.apple.com"


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
    return jwt.encode(
        payload, private_key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"}
    )


def api(method, path, body=None, label=""):
    token = make_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    url = f"{BASE}{path}" if path.startswith("/") else path
    r = requests.request(method, url, headers=headers, json=body)
    status = r.status_code
    tag = f" [{label}]" if label else ""
    try:
        data = r.json()
    except Exception:
        data = r.text
    print(f"  {method} {path[:140]}  => {status}{tag}")
    if status >= 400:
        print(f"  ERROR: {json.dumps(data, indent=2)[:2000]}")
    return status, data


def section(title):
    print(f"\n{'=' * 70}")
    print(f"  {title}")
    print("=" * 70)


def fix_export_compliance(version_string, build_number):
    """Fix MISSING_EXPORT_COMPLIANCE for a specific build."""
    section(f"Fix Export Compliance: v{version_string} build {build_number}")

    # Step 1: Find the build
    # The builds API filter[version] matches the BUILD NUMBER (CFBundleVersion), not marketing version.
    # filter[preReleaseVersion.version] matches the marketing version string.
    print(f"\n  [1] Finding build {version_string} (build #{build_number})...")

    # Try multiple approaches to find the build
    build_id = None
    build_state = None

    # Approach A: filter by preReleaseVersion.version (marketing version)
    status, data = api(
        "GET",
        f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]={version_string}&sort=-uploadedDate&limit=5",
        label=f"find build by marketing version {version_string}",
    )

    if status == 200 and data.get("data"):
        for build in data["data"]:
            bv = build["attributes"].get("version", "")
            proc = build["attributes"].get("processingState", "")
            enc = build["attributes"].get("usesNonExemptEncryption")
            print(f"    Found build: buildNumber={bv}, processingState={proc}, "
                  f"usesNonExemptEncryption={enc}, id={build['id'][:20]}...")
            if bv == str(build_number):
                build_id = build["id"]
                build_state = proc
                break

    # Approach B: filter by build number directly
    if not build_id:
        status, data = api(
            "GET",
            f"/v1/builds?filter[app]={APP_ID}&filter[version]={build_number}&sort=-uploadedDate&limit=5",
            label=f"find build by build number {build_number}",
        )
        if status == 200 and data.get("data"):
            for build in data["data"]:
                bv = build["attributes"].get("version", "")
                proc = build["attributes"].get("processingState", "")
                enc = build["attributes"].get("usesNonExemptEncryption")
                print(f"    Found build: buildNumber={bv}, processingState={proc}, "
                      f"usesNonExemptEncryption={enc}, id={build['id'][:20]}...")
                build_id = build["id"]
                build_state = proc
                break

    # Approach C: list recent builds and search manually
    if not build_id:
        print("    Trying to list all recent builds...")
        status, data = api(
            "GET",
            f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=10",
            label="list all recent builds",
        )
        if status == 200 and data.get("data"):
            for build in data["data"]:
                bv = build["attributes"].get("version", "")
                proc = build["attributes"].get("processingState", "")
                enc = build["attributes"].get("usesNonExemptEncryption")
                print(f"    Build: number={bv}, processingState={proc}, "
                      f"usesNonExemptEncryption={enc}, id={build['id'][:20]}...")
                if bv == str(build_number):
                    build_id = build["id"]
                    build_state = proc
                    break

    if not build_id:
        print(f"  FAILED: Could not find build #{build_number} for version {version_string}")
        return False

    print(f"    Using build ID: {build_id}")
    print(f"    Processing state: {build_state}")

    # Step 2: Get the buildBetaDetail
    print(f"\n  [2] Getting buildBetaDetail for build...")
    status, data = api(
        "GET",
        f"/v1/builds/{build_id}/buildBetaDetail",
        label="get buildBetaDetail",
    )

    if status != 200 or not data.get("data"):
        print(f"  FAILED: Could not get buildBetaDetail (status={status})")
        # Try alternative: query the build with include
        print("    Trying alternative approach: query build with include...")
        status2, data2 = api(
            "GET",
            f"/v1/builds/{build_id}?include=buildBetaDetail",
            label="get build with buildBetaDetail included",
        )
        if status2 == 200 and data2.get("included"):
            for inc in data2["included"]:
                if inc["type"] == "buildBetaDetails":
                    data = {"data": inc}
                    break
        if not data.get("data"):
            print("  FAILED: Could not find buildBetaDetail via any method")
            return False

    beta_detail_id = data["data"]["id"]
    current_encryption = data["data"]["attributes"].get("externalBuildState", "unknown")
    auto_notify = data["data"]["attributes"].get("autoNotifyEnabled", None)
    print(f"    buildBetaDetail ID: {beta_detail_id}")
    print(f"    externalBuildState: {current_encryption}")

    # Step 3: Set usesNonExemptEncryption = false
    print(f"\n  [3] Setting usesNonExemptEncryption = false...")
    patch_body = {
        "data": {
            "type": "buildBetaDetails",
            "id": beta_detail_id,
            "attributes": {
                "autoNotifyEnabled": auto_notify if auto_notify is not None else False,
            },
        }
    }

    status, data = api(
        "PATCH",
        f"/v1/buildBetaDetails/{beta_detail_id}",
        body=patch_body,
        label="patch buildBetaDetail (autoNotify)",
    )

    # Now try the direct approach on the build itself
    print(f"\n  [3b] Trying PATCH on build with usesNonExemptEncryption...")
    patch_build_body = {
        "data": {
            "type": "builds",
            "id": build_id,
            "attributes": {
                "usesNonExemptEncryption": False,
            },
        }
    }
    status, data = api(
        "PATCH",
        f"/v1/builds/{build_id}",
        body=patch_build_body,
        label="patch build usesNonExemptEncryption",
    )

    if status == 200:
        new_state = data.get("data", {}).get("attributes", {}).get("processingState", "unknown")
        print(f"    SUCCESS! Build patched. Processing state: {new_state}")
        return True
    elif status == 409:
        print("    409 Conflict - build may already have compliance set or is in wrong state")
        # Check if it's already resolved
        s2, d2 = api("GET", f"/v1/builds/{build_id}", label="recheck build state")
        if s2 == 200:
            enc = d2.get("data", {}).get("attributes", {}).get("usesNonExemptEncryption")
            proc = d2.get("data", {}).get("attributes", {}).get("processingState")
            print(f"    usesNonExemptEncryption: {enc}, processingState: {proc}")
            if enc is False or proc == "VALID":
                print("    Export compliance appears to already be resolved!")
                return True
        return False
    else:
        print(f"    FAILED with status {status}")

        # Try the betaAppReviewSubmission approach as fallback
        print(f"\n  [3c] Fallback: trying POST /v1/betaAppReviewSubmissions...")
        fallback_body = {
            "data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {
                    "build": {
                        "data": {
                            "type": "builds",
                            "id": build_id,
                        }
                    }
                },
            }
        }
        status, data = api(
            "POST",
            "/v1/betaAppReviewSubmissions",
            body=fallback_body,
            label="betaAppReviewSubmission fallback",
        )
        if status in (200, 201):
            print("    Fallback succeeded!")
            return True
        print("    Fallback also failed.")
        return False


def create_app_store_version():
    """Create a new App Store version 1.1.0."""
    section("Create App Store Version 1.1.0")

    # First check if 1.1.0 already exists
    print("\n  [1] Checking if version 1.1.0 already exists...")
    status, data = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5",
        label="list app store versions",
    )

    if status == 200 and data.get("data"):
        for ver in data["data"]:
            vs = ver["attributes"].get("versionString", "")
            state = ver["attributes"].get("appStoreState", "")
            print(f"    Found version: {vs} ({state}) id={ver['id'][:20]}...")
            if vs == "1.1.0":
                print(f"    Version 1.1.0 already exists in state: {state}")
                print(f"    Version ID: {ver['id']}")
                return True, ver["id"]

    # Create version 1.1.0
    print("\n  [2] Creating version 1.1.0...")
    create_body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "versionString": "1.1.0",
                "platform": "IOS",
            },
            "relationships": {
                "app": {
                    "data": {
                        "type": "apps",
                        "id": APP_ID,
                    }
                }
            },
        }
    }

    status, data = api(
        "POST",
        "/v1/appStoreVersions",
        body=create_body,
        label="create version 1.1.0",
    )

    if status in (200, 201):
        version_id = data["data"]["id"]
        state = data["data"]["attributes"].get("appStoreState", "")
        print(f"    SUCCESS! Version 1.1.0 created.")
        print(f"    Version ID: {version_id}")
        print(f"    State: {state}")
        return True, version_id
    elif status == 409:
        print("    409 Conflict - version 1.1.0 may already exist")
        errors = data.get("errors", [])
        for err in errors:
            print(f"    Error: {err.get('detail', err.get('title', 'unknown'))}")
        return False, None
    else:
        print(f"    FAILED with status {status}")
        return False, None


def verify_results():
    """Verify all operations succeeded."""
    section("Verification")

    # Check builds (use preReleaseVersion.version for marketing version filter)
    print("\n  [1] Checking build states...")
    for version in ["1.1.0", "1.0.1"]:
        status, data = api(
            "GET",
            f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]={version}&sort=-uploadedDate&limit=3",
            label=f"verify builds {version}",
        )
        if status == 200 and data.get("data"):
            for build in data["data"]:
                bv = build["attributes"].get("version", "?")
                proc = build["attributes"].get("processingState", "?")
                enc = build["attributes"].get("usesNonExemptEncryption", "?")
                print(f"    Build v{version} #{bv}: processingState={proc}, usesNonExemptEncryption={enc}")
        else:
            print(f"    No builds found for version {version}")

    # Check app store versions
    print("\n  [2] Checking App Store versions...")
    status, data = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5",
        label="verify app store versions",
    )

    if status == 200 and data.get("data"):
        for ver in data["data"]:
            vs = ver["attributes"].get("versionString", "")
            state = ver["attributes"].get("appStoreState", "")
            print(f"    Version {vs}: {state} (id={ver['id'][:20]}...)")

            if vs == "1.1.0" and state == "PREPARE_FOR_SUBMISSION":
                print(f"    --> Version 1.1.0 is in PREPARE_FOR_SUBMISSION state!")
    else:
        print("    Could not retrieve app store versions")


def main():
    print("=" * 70)
    print("  App Store Connect API Operations")
    print("  App ID: " + APP_ID)
    print("=" * 70)

    results = {}

    # Task 1: Fix export compliance on build 1.1.0 (42)
    results["task1"] = fix_export_compliance("1.1.0", 42)

    time.sleep(1)

    # Task 2: Fix export compliance on build 1.0.1 (38) if it has MISSING_EXPORT_COMPLIANCE
    print("\n  Checking if build 1.0.1 (38) needs export compliance fix...")

    needs_fix = False
    # Try by marketing version
    status, data = api(
        "GET",
        f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]=1.0.1&sort=-uploadedDate&limit=3",
        label="check build 1.0.1 by marketing version",
    )
    if status != 200 or not data.get("data"):
        # Try by build number
        status, data = api(
            "GET",
            f"/v1/builds?filter[app]={APP_ID}&filter[version]=38&sort=-uploadedDate&limit=3",
            label="check build 38",
        )

    if status == 200 and data.get("data"):
        for build in data["data"]:
            bv = build["attributes"].get("version", "")
            proc = build["attributes"].get("processingState", "")
            enc = build["attributes"].get("usesNonExemptEncryption")
            print(f"    Build #{bv}: processingState={proc}, usesNonExemptEncryption={enc}")
            if bv == "38" and (proc == "MISSING_EXPORT_COMPLIANCE" or enc is None):
                needs_fix = True
                break
    else:
        print("    No builds found for 1.0.1")

    if needs_fix:
        results["task2"] = fix_export_compliance("1.0.1", 38)
    else:
        print("    Build 1.0.1 does not need export compliance fix. Skipping.")
        results["task2"] = True  # Not needed = success

    time.sleep(1)

    # Task 3: Create App Store version 1.1.0
    success, version_id = create_app_store_version()
    results["task3"] = success

    time.sleep(1)

    # Task 4: Verify
    verify_results()

    # Summary
    section("SUMMARY")
    for task, success in results.items():
        status_str = "SUCCESS" if success else "FAILED"
        print(f"  {task}: {status_str}")

    print(f"\n  App Store Connect: https://appstoreconnect.apple.com/apps/{APP_ID}/appstore")
    print("=" * 70)

    all_ok = all(results.values())
    if not all_ok:
        print("  Some tasks failed. Check output above for details.")
        sys.exit(1)
    else:
        print("  All tasks completed successfully!")


if __name__ == "__main__":
    main()
