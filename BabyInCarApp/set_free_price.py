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

print("Setting app to FREE pricing...")

# Step 1: First we need to create/update the app price schedule
# For a free app, we need to set a base price of 0

# Get all territories to find USA
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/territories?limit=200',
    headers=headers
)

usa_territory_id = None
if response.status_code == 200:
    territories = response.json()['data']
    for t in territories:
        if t['attributes']['currency'] == 'USD':
            usa_territory_id = t['id']
            print(f"Found USA territory: {usa_territory_id}")
            break

# Try to create app price schedule with FREE (tier 0)
# The v2 API endpoint for app prices

# First check if schedule exists
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appPriceSchedules/{APP_ID}',
    headers=headers
)
print(f"Price schedule check: {response.status_code}")

if response.status_code == 404:
    print("No price schedule - need to create one")
    
    # Create a price schedule
    # We need to use the territory-based pricing API
    
    # Get all price points for USA territory
    response = requests.get(
        f'https://api.appstoreconnect.apple.com/v1/appPricePoints?filter[territory]=USA&limit=50',
        headers=headers
    )
    print(f"Price points: {response.status_code}")
    if response.status_code == 200:
        points = response.json()['data']
        free_point = None
        for pt in points:
            # Look for FREE (tier 0)
            if 'customerPrice' in pt['attributes'] and pt['attributes']['customerPrice'] == '0':
                free_point = pt
                break
        if free_point:
            print(f"Found FREE price point: {free_point['id']}")

# Try the AppPrices endpoint
print("\nTrying AppPrices endpoint...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/prices',
    headers=headers
)
print(f"App prices: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:500])

# Try different endpoints
print("\nTrying alternative pricing endpoints...")

# Try appPriceTiers
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/appPriceTiers?limit=5',
    headers=headers
)
print(f"Price tiers: {response.status_code}")
if response.status_code == 200:
    tiers = response.json()['data']
    for tier in tiers[:5]:
        print(f"  Tier: {tier['id']}")

# See if we can set price via v3 API
print("\nTrying v3 API...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v3/apps/{APP_ID}',
    headers=headers
)
print(f"v3 app: {response.status_code}")

print("\n" + "=" * 60)
print("NOTE: Pricing setup may require UI or specific API version")
print("Try: https://appstoreconnect.apple.com/apps/6756977992/pricing")
