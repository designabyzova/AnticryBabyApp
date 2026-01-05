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

print("Checking pricing details...")

# Get full price schedule with includes
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appPriceSchedules/{APP_ID}?include=manualPrices,automaticPrices,baseTerritory',
    headers=headers
)
print(f"Price schedule with includes: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(json.dumps(data, indent=2))
else:
    print(response.text[:1000])

# Check manual prices
print("\nManual prices...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appPriceSchedules/{APP_ID}/manualPrices',
    headers=headers
)
print(f"Manual prices: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(json.dumps(data, indent=2)[:1000])
else:
    print(response.text[:500])

# Check automatic prices  
print("\nAutomatic prices...")
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appPriceSchedules/{APP_ID}/automaticPrices',
    headers=headers
)
print(f"Automatic prices: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(json.dumps(data, indent=2)[:1000])
