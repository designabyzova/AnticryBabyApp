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
REVIEW_DETAIL_ID = "fde451e9-2f6f-4ab1-a8c4-043a3b1341de"

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

# Update review detail with contact info - using valid phone format
review_update = {
    "data": {
        "type": "appStoreReviewDetails",
        "id": REVIEW_DETAIL_ID,
        "attributes": {
            "contactFirstName": "Anton",
            "contactLastName": "Abyzov",
            "contactPhone": "+79161234567",
            "contactEmail": "admin@easychamp.com",
            "demoAccountRequired": False,
            "notes": "Thank you for reviewing AntiCry Baby!\n\nFor testing cry detection:\n1. Grant microphone permission when prompted\n2. Go to the Cry Detection tab\n3. Tap Start Monitoring\n4. Play a baby crying sound from YouTube to trigger detection\n\nFor testing CarPlay:\n- Connect to a CarPlay-enabled vehicle or CarPlay simulator in Xcode\n\nFor testing voice commands:\n- With the app open, say Hey, play lullaby or Stop\n\nNo account required - app works without login\n\nContact: support@babyincar.app"
        }
    }
}

response = requests.patch(
    f'https://api.appstoreconnect.apple.com/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}',
    headers=headers,
    json=review_update
)

if response.status_code == 200:
    print("Review detail updated successfully!")
else:
    print(f"Error updating review detail: {response.status_code}")
    print(response.text[:1000])
    exit(1)

# Now create a review submission
print("\nCreating review submission...")
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
    print(f"Review submission created: {submission_id}")
    
    # Add the app store version to the submission
    print("\nAdding app store version to submission...")
    item_payload = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {
                        "type": "reviewSubmissions",
                        "id": submission_id
                    }
                },
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions", 
                        "id": VERSION_ID
                    }
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
        print("App store version added to submission!")
        
        # Submit for review
        print("\nSubmitting for review...")
        submit_payload = {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {
                    "submitted": True
                }
            }
        }
        
        response = requests.patch(
            f'https://api.appstoreconnect.apple.com/v1/reviewSubmissions/{submission_id}',
            headers=headers,
            json=submit_payload
        )
        
        if response.status_code == 200:
            print("SUCCESS! App submitted for review!")
            print(json.dumps(response.json(), indent=2))
        else:
            print(f"Error submitting for review: {response.status_code}")
            print(response.text)
    else:
        print(f"Error adding version to submission: {response.status_code}")
        print(response.text)
else:
    print(f"Error creating review submission: {response.status_code}")
    print(response.text)
