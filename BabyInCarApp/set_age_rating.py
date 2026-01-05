import jwt
import time
import requests
from pathlib import Path

# App Store Connect API credentials
KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = "./fastlane/keys/AuthKey_JZ2ML9M66A.p8"
APP_ID = "6756977992"  # From the altool output earlier

# Read the private key
with open(KEY_PATH, 'r') as f:
    private_key = f.read()

# Generate JWT token
payload = {
    'iss': ISSUER_ID,
    'exp': int(time.time()) + 1200,  # 20 minutes
    'aud': 'appstoreconnect-v1'
}

token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': KEY_ID})
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

print("JWT token generated successfully")

# First, get the app infos to find the age rating declaration ID
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appInfos',
    headers=headers
)

if response.status_code != 200:
    print(f"Error getting app infos: {response.status_code}")
    print(response.text)
    exit(1)

app_infos = response.json()['data']
print(f"Found {len(app_infos)} app infos")

# Get the age rating declaration from the app info
app_info_id = app_infos[0]['id']
print(f"App Info ID: {app_info_id}")

# Get age rating declaration
response = requests.get(
    f'https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/ageRatingDeclaration',
    headers=headers
)

if response.status_code != 200:
    print(f"Error getting age rating: {response.status_code}")
    print(response.text)
    exit(1)

age_rating = response.json()['data']
age_rating_id = age_rating['id']
print(f"Age Rating Declaration ID: {age_rating_id}")
print(f"Current age rating: {age_rating['attributes']}")

# Update the age rating - set all to NONE for 4+ rating
update_payload = {
    "data": {
        "type": "ageRatingDeclarations",
        "id": age_rating_id,
        "attributes": {
            "violenceCartoonOrFantasy": "NONE",
            "violenceRealistic": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
            "profanityOrCrudeHumor": "NONE",
            "matureOrSuggestiveThemes": "NONE",
            "horrorOrFearThemes": "NONE",
            "medicalOrTreatmentInformation": "NONE",
            "alcoholTobaccoOrDrugUseOrReferences": "NONE",
            "gamblingSimulated": "NONE",
            "sexualContentOrNudity": "NONE",
            "sexualContentGraphicAndNudity": "NONE",
            "unrestrictedWebAccess": False,
            "gambling": False,
            "contests": False
        }
    }
}

response = requests.patch(
    f'https://api.appstoreconnect.apple.com/v1/ageRatingDeclarations/{age_rating_id}',
    headers=headers,
    json=update_payload
)

if response.status_code == 200:
    print("Age rating updated successfully!")
    print(response.json())
else:
    print(f"Error updating age rating: {response.status_code}")
    print(response.text)
