import jwt
import time
import requests
import json

# App Store Connect API credentials
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = "./fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"

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

print("Setting Privacy URL on App Info Localization...")

# Get app infos
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appInfos',
    headers=headers
)

if response.status_code == 200:
    app_infos = response.json()['data']
    for info in app_infos:
        app_info_id = info['id']
        print(f"App Info ID: {app_info_id}")
        
        # Get localizations for this app info
        response = requests.get(
            f'https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations',
            headers=headers
        )
        
        if response.status_code == 200:
            localizations = response.json()['data']
            for loc in localizations:
                loc_id = loc['id']
                locale = loc['attributes']['locale']
                print(f"  Localization: {loc_id} ({locale})")
                print(f"  Current privacy URL: {loc['attributes'].get('privacyPolicyUrl', 'NOT SET')}")
                
                # Update privacy URL
                update_payload = {
                    "data": {
                        "type": "appInfoLocalizations",
                        "id": loc_id,
                        "attributes": {
                            "privacyPolicyUrl": "https://babyincar.app/privacy",
                            "privacyPolicyText": None
                        }
                    }
                }
                
                response = requests.patch(
                    f'https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{loc_id}',
                    headers=headers,
                    json=update_payload
                )
                
                if response.status_code == 200:
                    print(f"  ✓ Privacy URL set successfully!")
                else:
                    print(f"  ✗ Failed: {response.status_code}")
                    print(response.text[:500])
        else:
            print(f"Failed to get localizations: {response.status_code}")
else:
    print(f"Failed to get app infos: {response.status_code}")

print("\nDone!")
