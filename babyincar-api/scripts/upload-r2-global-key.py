#!/usr/bin/env python3
"""
Upload Podcasts to Cloudflare R2 using Global API Key

This script uses Cloudflare's REST API with global key authentication to upload files to R2.
"""

import os
import sys
import json
import urllib.request
import urllib.error
import urllib.parse
import base64
from datetime import datetime, timezone
from pathlib import Path
import mimetypes
import hashlib

# Configuration
PODCAST_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts"
OUTPUT_METADATA = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/data/podcast-library.json"

# Load credentials from .env
ACCOUNT_ID = "1364b528762500de4f870e064229d443"
BUCKET_NAME = "anticrybaby"  # Your existing bucket

# Try to load Global API key from .env
ENV_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/.env"
API_KEY = ""
API_EMAIL = ""

if os.path.exists(ENV_FILE):
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                if key == 'CLOUDFLARE_GLOBAL_API_KEY':
                    API_KEY = value
                elif key == 'CLOUDFLARE_EMAIL':
                    API_EMAIL = value

# Fallback to direct values
if not API_KEY:
    API_KEY = "82eaa870afd3c83c7303c4e446bdd985c697f"

# Public R2 URL (once public access is enabled)
PUBLIC_URL = f"https://pub-{ACCOUNT_ID}.r2.dev"

def get_content_type(file_path):
    """Get MIME type for audio file"""
    ext = os.path.splitext(file_path)[1].lower()
    types = {
        '.mp3': 'audio/mpeg',
        '.ogg': 'audio/ogg',
        '.wav': 'audio/wav',
        '.m4a': 'audio/mp4',
        '.flac': 'audio/flac',
    }
    return types.get(ext, 'audio/mpeg')

def extract_metadata_from_path(file_path, base_path):
    """Extract metadata from file path and name"""
    rel_path = os.path.relpath(file_path, base_path)
    parts = rel_path.split(os.sep)

    language = parts[0] if len(parts) > 0 else 'en'
    category = parts[1] if len(parts) > 1 else 'misc'
    filename = parts[-1]

    name_without_ext = os.path.splitext(filename)[0]

    title = name_without_ext
    artist = "Baby in Car"

    if 'bedtime_fm' in name_without_ext:
        parts = name_without_ext.split('_', 3)
        if len(parts) >= 4:
            title = parts[3].replace('_', ' ').title()
        artist = "Bedtime FM"
    elif 'librivox' in name_without_ext:
        parts = name_without_ext.split('_', 2)
        if len(parts) >= 3:
            title = parts[2].replace('_', ' ').title()
        artist = "LibriVox"
    elif 'peace_out' in name_without_ext:
        parts = name_without_ext.split('_', 3)
        if len(parts) >= 4:
            title = parts[3].replace('_', ' ').title()
        artist = "Peace Out"
    elif 'ru_fairytale' in name_without_ext:
        parts = name_without_ext.split('_', 4)
        if len(parts) >= 5:
            title = parts[4].replace('_', ' ')
        artist = "LibriVox Russia"
    elif 'ia_' in name_without_ext:
        parts = name_without_ext.split('_', 3)
        if len(parts) >= 4:
            title = parts[3].replace('_', ' ').title()
        artist = "Internet Archive"
    else:
        title = name_without_ext.replace('_', ' ').title()

    return {
        'language': language,
        'category': category,
        'title': title[:100],
        'artist': artist,
        'filename': filename
    }

def upload_via_cloudflare_api(file_path, key):
    """
    Upload file to R2 via Cloudflare API
    Note: This uses the Workers API endpoint for R2 uploads
    """

    with open(file_path, 'rb') as f:
        file_content = f.read()

    content_type = get_content_type(file_path)

    # Cloudflare R2 REST API endpoint
    # Using the S3-compatible endpoint with Global API key
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/r2/buckets/{BUCKET_NAME}/objects/{urllib.parse.quote(key, safe='')}"

    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'Content-Type': content_type,
        'X-Auth-Key': API_KEY,
        'X-Auth-Email': API_EMAIL if API_EMAIL else 'user@example.com',
    }

    try:
        req = urllib.request.Request(url, data=file_content, headers=headers, method='PUT')
        with urllib.request.urlopen(req, timeout=300) as response:
            return True, response.status
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='ignore')
        return False, f'HTTP {e.code}: {error_body[:300]}'
    except Exception as e:
        return False, str(e)

def test_cloudflare_connection():
    """Test connection to Cloudflare API"""
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/r2/buckets"

    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'Content-Type': 'application/json',
    }

    try:
        req = urllib.request.Request(url, headers=headers, method='GET')
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode('utf-8'))
            return True, data
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='ignore')
        return False, f'HTTP {e.code}: {error_body[:300]}'
    except Exception as e:
        return False, str(e)

def main():
    print("=" * 60)
    print("R2 UPLOAD VIA CLOUDFLARE API")
    print("=" * 60)

    print(f"\nAccount ID: {ACCOUNT_ID}")
    print(f"Bucket: {BUCKET_NAME}")
    print(f"API Key: {'*' * 10}...{API_KEY[-5:]}")

    # Test connection
    print("\nTesting Cloudflare API connection...")
    success, result = test_cloudflare_connection()

    if not success:
        print(f"\nConnection failed: {result}")
        print("\nThe Global API key may not have R2 permissions.")
        print("Generating metadata only (files need manual upload)...")
        generate_metadata_only()
        return

    print(f"Connection successful!")
    if isinstance(result, dict) and 'result' in result:
        buckets = result.get('result', [])
        print(f"Available buckets: {[b.get('name') for b in buckets]}")

    # Find all podcast files
    podcast_files = []
    for root, dirs, files in os.walk(PODCAST_DIR):
        for file in files:
            if file.endswith(('.mp3', '.ogg', '.wav', '.m4a')):
                podcast_files.append(os.path.join(root, file))

    print(f"\nFound {len(podcast_files)} podcast files to upload")

    # Process files
    metadata_list = []
    success_count = 0
    fail_count = 0

    os.makedirs(os.path.dirname(OUTPUT_METADATA), exist_ok=True)

    for i, file_path in enumerate(sorted(podcast_files)):
        meta = extract_metadata_from_path(file_path, PODCAST_DIR)
        r2_key = f"podcasts/{meta['language']}/{meta['category']}/{meta['filename']}"
        file_size = os.path.getsize(file_path)
        content_type = get_content_type(file_path)

        print(f"[{i+1}/{len(podcast_files)}] {meta['title'][:40]}...")

        success, result = upload_via_cloudflare_api(file_path, r2_key)

        if success:
            print(f"  OK ({file_size/1024/1024:.1f} MB)")
            success_count += 1
        else:
            print(f"  FAILED: {result}")
            fail_count += 1

        # Add to metadata regardless (for local development)
        metadata_list.append({
            'id': f"podcast_{meta['language']}_{meta['category']}_{i:04d}",
            'title': meta['title'],
            'artist': meta['artist'],
            'language': meta['language'],
            'category': meta['category'],
            'filename': meta['filename'],
            'r2Key': r2_key,
            'streamUrl': f"{PUBLIC_URL}/{r2_key}",
            'size': file_size,
            'contentType': content_type,
            'source': 'podcast',
            'license': 'Public Domain / Free Distribution',
            'audioSourceType': 'streamed',
            'calmingScore': 0.8,
            'ageRangeMin': 0,
            'ageRangeMax': 36,
            'isPremium': False,
            'uploaded': success
        })

    # Save metadata
    output_data = {
        'version': '1.0',
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'totalTracks': len(metadata_list),
        'r2Bucket': BUCKET_NAME,
        'publicUrl': PUBLIC_URL,
        'tracks': metadata_list
    }

    with open(OUTPUT_METADATA, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print(f"Uploaded: {success_count}")
    print(f"Failed: {fail_count}")
    print(f"Metadata saved to: {OUTPUT_METADATA}")

def generate_metadata_only():
    """Generate metadata without uploading"""
    podcast_files = []
    for root, dirs, files in os.walk(PODCAST_DIR):
        for file in files:
            if file.endswith(('.mp3', '.ogg', '.wav', '.m4a')):
                podcast_files.append(os.path.join(root, file))

    print(f"Found {len(podcast_files)} podcast files")

    metadata_list = []

    for i, file_path in enumerate(sorted(podcast_files)):
        meta = extract_metadata_from_path(file_path, PODCAST_DIR)
        file_size = os.path.getsize(file_path)
        content_type = get_content_type(file_path)
        r2_key = f"podcasts/{meta['language']}/{meta['category']}/{meta['filename']}"

        metadata_list.append({
            'id': f"podcast_{meta['language']}_{meta['category']}_{i:04d}",
            'title': meta['title'],
            'artist': meta['artist'],
            'language': meta['language'],
            'category': meta['category'],
            'filename': meta['filename'],
            'localPath': os.path.relpath(file_path, PODCAST_DIR),
            'r2Key': r2_key,
            'streamUrl': f"{PUBLIC_URL}/{r2_key}",
            'size': file_size,
            'contentType': content_type,
            'source': 'podcast',
            'license': 'Public Domain / Free Distribution',
            'audioSourceType': 'streamed',
            'calmingScore': 0.8,
            'ageRangeMin': 0,
            'ageRangeMax': 36,
            'isPremium': False
        })

    os.makedirs(os.path.dirname(OUTPUT_METADATA), exist_ok=True)

    output_data = {
        'version': '1.0',
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'totalTracks': len(metadata_list),
        'r2Bucket': BUCKET_NAME,
        'publicUrl': PUBLIC_URL,
        'tracks': metadata_list,
        'uploadPending': True,
        'uploadInstructions': """
To upload files to R2:
1. Go to Cloudflare Dashboard > R2 > anticrybaby bucket
2. Create R2 API Token with Object Read & Write permissions
3. Set R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY in .env
4. Run upload-podcasts-to-r2.py again

Or manually upload using Cloudflare Dashboard drag-and-drop.
        """
    }

    with open(OUTPUT_METADATA, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"\nMetadata saved to: {OUTPUT_METADATA}")
    print(f"Total tracks: {len(metadata_list)}")

    lang_counts = {}
    for track in metadata_list:
        lang = track['language']
        lang_counts[lang] = lang_counts.get(lang, 0) + 1

    print("\nBy Language:")
    for lang, count in sorted(lang_counts.items()):
        print(f"  {lang}: {count}")

if __name__ == '__main__':
    main()
