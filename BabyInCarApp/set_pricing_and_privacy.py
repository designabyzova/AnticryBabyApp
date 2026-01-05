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

# 1. Set app to free (base price = 0)
print("\n1. Setting app pricing to FREE...")

# First, get territory for USD
response = requests.get(
    'https://api.appstoreconnect.apple.com/v1/territories?filter[id]=USA',
    headers=headers
)
if response.status_code == 200:
    territories = response.json()
    print(f"USA territory found")
else:
    print(f"Could not get territories: {response.status_code}")
    
# Set the price schedule - free app
# We need to add a manual price with price point 0 (FREE)
price_schedule_payload = {
    "data": {
        "type": "appPrices",
        "attributes": {
            "startDate": None  # Immediate
        },
        "relationships": {
            "app": {
                "data": {
                    "type": "apps",
                    "id": APP_ID
                }
            },
            "priceTier": {
                "data": {
                    "type": "appPriceTiers",
                    "id": "0"  # FREE tier
                }
            }
        }
    }
}

# Try the v2 API for prices
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v2/appPricePoints?filter[territory]=USA&limit=5',
    headers=headers
)
print(f"Price points v2: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    free_point = None
    for point in data['data'][:5]:
        if point['attributes'].get('customerPrice') == "0":
            free_point = point
            break
    if free_point:
        print(f"Found FREE price point: {free_point['id']}")
        
        # Create app price with this price point
        app_price_payload = {
            "data": {
                "type": "appPrices",
                "relationships": {
                    "app": {
                        "data": {
                            "type": "apps",
                            "id": APP_ID
                        }
                    },
                    "appPricePoint": {
                        "data": {
                            "type": "appPricePoints",
                            "id": free_point['id']
                        }
                    }
                }
            }
        }
        response = requests.post(
            'https://api.appstoreconnect.apple.com/v2/appPrices',
            headers=headers,
            json=app_price_payload
        )
        print(f"Set price result: {response.status_code}")
        print(response.text[:500] if response.status_code != 201 else "Price set!")

# 2. Try setting privacy - declare app collects no data
print("\n2. Setting privacy - no data collected...")

# Create app data usage - declare no data collection
# This requires publishing a "NO DATA COLLECTED" state

response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appDataUsagesPublishState',
    headers=headers
)
print(f"Current publish state: {response.status_code}")
if response.status_code == 200:
    state = response.json()['data']
    state_id = state['id']
    print(f"State ID: {state_id}")
    print(f"Published: {state['attributes'].get('published', False)}")
    
    # If not published, try to publish
    if not state['attributes'].get('published', False):
        publish_payload = {
            "data": {
                "type": "appDataUsagesPublishState",
                "id": state_id,
                "attributes": {
                    "published": True
                }
            }
        }
        response = requests.patch(
            f'https://api.appstoreconnect.apple.com/v1/appDataUsagesPublishState/{state_id}',
            headers=headers,
            json=publish_payload
        )
        print(f"Publish result: {response.status_code}")
        print(response.text[:500])
elif response.status_code == 404:
    print("Privacy publish state not found - creating one...")
    
    # First need to create the app data usage declaration
    create_payload = {
        "data": {
            "type": "appDataUsagesPublishState",
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
    # This might not be the right endpoint...
    
print("\nDone checking pricing and privacy!")
print("\nIf issues persist, these need to be set in App Store Connect UI:")
print("1. Go to https://appstoreconnect.apple.com/apps/" + APP_ID)
print("2. Click on 'App Privacy' and answer questions")
print("3. Click on 'Pricing and Availability' to set price")
