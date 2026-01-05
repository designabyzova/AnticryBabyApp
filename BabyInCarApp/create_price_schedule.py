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

print("Creating FREE price schedule...")

# First, get the app price points for the base territory (USA)
print("\n1. Getting price points for USA...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/pricePoints?filter[territory]=USA&limit=50',
    headers=headers
)
print(f"Price points status: {response.status_code}")

free_price_point_id = None
if response.status_code == 200:
    points = response.json().get('data', [])
    print(f"Found {len(points)} price points")
    for pt in points[:10]:
        attrs = pt.get('attributes', {})
        customer_price = attrs.get('customerPrice', 'N/A')
        print(f"  - {pt['id']}: ${customer_price}")
        if customer_price == '0' or customer_price == '0.0':
            free_price_point_id = pt['id']
            print(f"    ^ Found FREE price point!")
else:
    print(response.text[:500])

# Try alternate endpoint to get app price points
if not free_price_point_id:
    print("\n2. Trying alternate price points endpoint...")
    response = requests.get(
        'https://api.appstoreconnect.apple.com/v3/appPricePoints?filter[territory]=USA&include=territory',
        headers=headers
    )
    print(f"v3 price points: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(json.dumps(data, indent=2)[:1000])

# Try to create price schedule
print("\n3. Attempting to create price schedule...")
price_schedule_payload = {
    "data": {
        "type": "appPriceSchedules",
        "relationships": {
            "app": {
                "data": {
                    "type": "apps",
                    "id": APP_ID
                }
            },
            "baseTerritory": {
                "data": {
                    "type": "territories",
                    "id": "USA"
                }
            }
        }
    },
    "included": []
}

response = requests.post(
    'https://api.appstoreconnect.apple.com/v1/appPriceSchedules',
    headers=headers,
    json=price_schedule_payload
)
print(f"Create price schedule: {response.status_code}")
if response.status_code in [200, 201]:
    print("Price schedule created!")
    print(json.dumps(response.json(), indent=2)[:1000])
else:
    print(response.text[:1000])

# Check current app availability
print("\n4. Checking app availability...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v2/apps/{APP_ID}/appAvailability',
    headers=headers
)
print(f"App availability: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:500])
else:
    print(response.text[:500])

print("\n" + "=" * 60)
print("NOTE: If pricing cannot be set via API, use App Store Connect UI:")
print("https://appstoreconnect.apple.com/apps/6756977992/pricing")
