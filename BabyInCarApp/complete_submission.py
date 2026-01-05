import jwt
import time
import requests
import json

# App Store Connect API credentials
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = "./fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"
VERSION_ID = "86f6d6e9-361f-41a4-9479-9a47cb7adf90"

# Read the private key
with open(KEY_PATH, 'r') as f:
    private_key = f.read()

# Generate JWT token
payload = {
    'iss': ISSUER_ID,
    'exp': int(time.time()) + 1200,
    'aud': 'appstoreconnect-v1'
}

token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': KEY_ID})
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

print("JWT token generated successfully")
print("=" * 60)

# 1. Check current app status
print("\n1. CHECKING APP STATUS...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}',
    headers=headers
)
if response.status_code == 200:
    app = response.json()['data']
    print(f"App Name: {app['attributes']['name']}")
    print(f"Bundle ID: {app['attributes']['bundleId']}")
    print(f"Content Rights: {app['attributes'].get('contentRightsDeclaration', 'NOT SET')}")

# 2. Check App Info Localizations
print("\n2. CHECKING APP INFO LOCALIZATIONS...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appInfos',
    headers=headers
)
if response.status_code == 200:
    app_infos = response.json()['data']
    for info in app_infos:
        print(f"App Info ID: {info['id']}")
        print(f"State: {info['attributes'].get('appStoreState', 'N/A')}")

# 3. Check Version Localizations
print("\n3. CHECKING VERSION LOCALIZATIONS...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations',
    headers=headers
)
if response.status_code == 200:
    localizations = response.json()['data']
    for loc in localizations:
        print(f"Locale: {loc['attributes']['locale']}")
        print(f"Description length: {len(loc['attributes'].get('description', '') or '')}")
        print(f"Keywords: {loc['attributes'].get('keywords', 'NOT SET')[:50]}...")
        print(f"Support URL: {loc['attributes'].get('supportUrl', 'NOT SET')}")
        print(f"Privacy URL: {loc['attributes'].get('privacyPolicyUrl', 'NOT SET')}")

# 4. Check what's blocking submission
print("\n4. CHECKING SUBMISSION BLOCKERS...")
# Try to create a submission to see what errors we get
submission_payload = {
    "data": {
        "type": "reviewSubmissions",
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

response = requests.post(
    'https://api.appstoreconnect.apple.com/v1/reviewSubmissions',
    headers=headers,
    json=submission_payload
)

if response.status_code == 201:
    submission = response.json()['data']
    submission_id = submission['id']
    print(f"Submission created: {submission_id}")
    
    # Try to add the version
    item_payload = {
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
    }
    
    response = requests.post(
        'https://api.appstoreconnect.apple.com/v1/reviewSubmissionItems',
        headers=headers,
        json=item_payload
    )
    
    if response.status_code == 201:
        print("Version added to submission!")
        
        # Try to submit
        submit_payload = {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True}
            }
        }
        
        response = requests.patch(
            f'https://api.appstoreconnect.apple.com/v1/reviewSubmissions/{submission_id}',
            headers=headers,
            json=submit_payload
        )
        
        if response.status_code == 200:
            print("\n" + "=" * 60)
            print("SUCCESS! APP SUBMITTED FOR REVIEW!")
            print("=" * 60)
        else:
            print(f"Submit failed: {response.status_code}")
            errors = response.json().get('errors', [])
            for err in errors:
                print(f"- {err.get('title', 'Error')}: {err.get('detail', 'Unknown')}")
    else:
        print(f"Add version failed: {response.status_code}")
        errors = response.json().get('errors', [])
        for err in errors:
            print(f"- {err.get('title', 'Error')}: {err.get('detail', 'Unknown')}")
            # Check for associated errors
            meta = err.get('meta', {})
            if 'associatedErrors' in meta:
                for path, assoc_errors in meta['associatedErrors'].items():
                    for ae in assoc_errors:
                        print(f"  → {path}: {ae.get('detail', 'Unknown')}")
else:
    print(f"Create submission failed: {response.status_code}")
    print(response.text[:1000])

print("\n" + "=" * 60)
print("DONE")
