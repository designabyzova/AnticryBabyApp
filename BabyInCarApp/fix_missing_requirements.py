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

print("JWT token generated successfully")

# 1. Set Content Rights Declaration - we don't use third party content that we don't own
print("\n1. Setting content rights declaration...")
content_rights_payload = {
    "data": {
        "type": "apps",
        "id": APP_ID,
        "attributes": {
            "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"
        }
    }
}

response = requests.patch(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}',
    headers=headers,
    json=content_rights_payload
)

if response.status_code == 200:
    print("Content rights declaration set successfully!")
else:
    print(f"Error setting content rights: {response.status_code}")
    print(response.text[:500])

# 2. Check current App Privacy configuration
print("\n2. Checking app privacy data usages...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appDataUsages',
    headers=headers
)
print(f"Current data usages: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(f"Data usages count: {len(data.get('data', []))}")
    
    # Check if we can publish data usages
    response = requests.get(
        f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appDataUsagesPublishState',
        headers=headers
    )
    print(f"Publish state: {response.json() if response.status_code == 200 else response.text[:200]}")

# 3. Check app prices
print("\n3. Checking app prices...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appPricePoints',
    headers=headers
)
print(f"Price points status: {response.status_code}")
if response.status_code != 200:
    print(response.text[:500])

# Get app price schedules
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appPriceSchedule',
    headers=headers
)
print(f"Price schedule: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:500])
else:
    print(response.text[:500])

print("\n\nNOTE: App Privacy and Pricing typically need to be set through App Store Connect UI")
print("as the APIs for these are complex and require territory-specific data.")
