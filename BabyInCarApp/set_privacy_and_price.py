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
print("=" * 60)

# 1. Set Privacy URL on version localization first
print("\n1. SETTING PRIVACY URL...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION',
    headers=headers
)
if response.status_code == 200:
    versions = response.json()['data']
    if versions:
        version_id = versions[0]['id']
        
        # Get localizations
        response = requests.get(
            f'https://api.appstoreconnect.apple.com/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations',
            headers=headers
        )
        if response.status_code == 200:
            localizations = response.json()['data']
            for loc in localizations:
                loc_id = loc['id']
                update_payload = {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": loc_id,
                        "attributes": {
                            "privacyPolicyUrl": "https://babyincar.app/privacy"
                        }
                    }
                }
                response = requests.patch(
                    f'https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{loc_id}',
                    headers=headers,
                    json=update_payload
                )
                if response.status_code == 200:
                    print(f"Privacy URL set for {loc['attributes']['locale']}")
                else:
                    print(f"Failed to set privacy URL: {response.status_code}")
                    print(response.text[:300])

# 2. Check app data usage categories
print("\n2. CHECKING APP DATA USAGE CATEGORIES...")
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/appDataUsageCategories',
    headers=headers
)
if response.status_code == 200:
    categories = response.json()['data']
    print(f"Found {len(categories)} categories")
    for cat in categories[:5]:
        print(f"  - {cat['id']}: {cat['attributes']}")

# 3. Check if we can publish data usages (declare "no data collected")
print("\n3. ATTEMPTING TO PUBLISH DATA USAGES...")

# First, check current state
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appDataUsages',
    headers=headers
)
print(f"App data status: {response.status_code}")

# Try to get app data usages directly
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appDataUsages',
    headers=headers
)
print(f"App data usages: {response.status_code}")
if response.status_code == 200:
    usages = response.json()
    print(json.dumps(usages, indent=2)[:500])
elif response.status_code == 404:
    print("No data usages configured yet")
    
    # Try to create a "no data collected" declaration
    # This requires publishing the privacy state
    
# 4. Try to set pricing
print("\n4. SETTING APP PRICING TO FREE...")

# Get available price points for the app
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appPriceSchedule?include=baseTerritory,manualPrices',
    headers=headers
)
print(f"Price schedule: {response.status_code}")
if response.status_code == 200:
    schedule = response.json()
    print(json.dumps(schedule, indent=2)[:500])

# Try to get price points
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/pricePoints?filter[territory]=USA',
    headers=headers
)
print(f"Price points: {response.status_code}")
if response.status_code == 200:
    points = response.json()
    for pt in points['data'][:5]:
        print(f"  Price point: {pt['id']} - {pt['attributes']}")

# Try the v2 API
print("\n5. TRYING V2 PRICING API...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v2/apps/{APP_ID}/appAvailability',
    headers=headers
)
print(f"App availability: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:500])

print("\n" + "=" * 60)
print("SUMMARY: Privacy and Pricing APIs require App Store Connect UI")
print("URL: https://appstoreconnect.apple.com/apps/6756977992")
