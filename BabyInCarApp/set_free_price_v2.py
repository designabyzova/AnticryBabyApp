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

# Step 1: Get available app price points (global)
print("\n1. Getting global price points...")
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/appPricePoints?filter[territory]=USA&limit=100',
    headers=headers
)
print(f"Global price points: {response.status_code}")

free_price_point_id = None
if response.status_code == 200:
    points = response.json().get('data', [])
    print(f"Found {len(points)} price points")
    for pt in points[:15]:
        attrs = pt.get('attributes', {})
        customer_price = attrs.get('customerPrice', 'N/A')
        print(f"  - {pt['id']}: ${customer_price}")
        if customer_price in ['0', '0.0', '0.00']:
            free_price_point_id = pt['id']
            print(f"    ^ FREE price point found!")
else:
    print(response.text[:500])

# Step 2: Try the v2 endpoint for in-app pricing
print("\n2. Trying v2 app price endpoint...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v2/inAppPurchasePriceSchedules',
    headers=headers
)
print(f"v2 price schedules: {response.status_code}")

# Step 3: Get territories
print("\n3. Getting territories...")
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/territories?limit=200',
    headers=headers
)
usa_territory_id = None
if response.status_code == 200:
    territories = response.json().get('data', [])
    for t in territories:
        if t['id'] == 'USA':
            usa_territory_id = t['id']
            print(f"Found USA: {usa_territory_id}")
            break
    print(f"Total territories: {len(territories)}")

# Step 4: Try creating price schedule with manual prices
print("\n4. Creating price schedule with manual prices...")

# Get a free price point ID from appPriceTiers
print("\nGetting price tiers...")
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/appPriceTiers?limit=10',
    headers=headers
)
free_tier_id = None
if response.status_code == 200:
    tiers = response.json().get('data', [])
    for tier in tiers:
        print(f"  - Tier: {tier['id']}")
        if tier['id'] == '0':
            free_tier_id = tier['id']
    if tiers:
        free_tier_id = tiers[0]['id']  # First tier is usually free

# Try creating with the v1 app price schedule API with full payload
print("\nCreating price schedule...")

# First get app price point for USA
print("Getting USA price point...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v3/appPricePoints?filter[territory]=USA&filter[priceTier]=0',
    headers=headers
)
print(f"USA price point: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:1000])
else:
    print(response.text[:500])

# Try the appPrices endpoint (older API)
print("\n5. Trying older appPrices endpoint...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/prices',
    headers=headers
)
print(f"App prices: {response.status_code}")
if response.status_code == 200:
    print(json.dumps(response.json(), indent=2)[:500])
else:
    print(response.text[:500])

print("\n" + "=" * 60)
print("SUMMARY:")
print("Pricing setup requires App Store Connect UI for new apps.")
print("Please go to: https://appstoreconnect.apple.com/apps/6756977992/distribution/pricing")
print("And select 'Free' as the price.")
