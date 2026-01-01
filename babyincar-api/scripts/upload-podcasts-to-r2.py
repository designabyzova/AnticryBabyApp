#!/usr/bin/env python3
"""
Upload Podcasts to Cloudflare R2

This script uploads all podcast files to Cloudflare R2 using the S3-compatible API.
It generates metadata JSON for the API and iOS app to consume.

Prerequisites:
1. Create R2 bucket: wrangler r2 bucket create babyincar-audio
2. Create R2 API token at Cloudflare Dashboard > R2 > Manage R2 API Tokens
3. Set environment variables:
   R2_ACCOUNT_ID=your_account_id
   R2_ACCESS_KEY_ID=your_access_key
   R2_SECRET_ACCESS_KEY=your_secret_key

Usage:
   python3 upload-podcasts-to-r2.py
"""

import os
import sys
import json
import hmac
import hashlib
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
import mimetypes

# Configuration
PODCAST_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts"
OUTPUT_METADATA = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/data/podcast-library.json"

# R2 Configuration (from environment or .env file)
R2_ACCOUNT_ID = os.environ.get('R2_ACCOUNT_ID', '1364b528762500de4f870e064229d443')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID', '')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY', '')
R2_BUCKET_NAME = os.environ.get('R2_BUCKET_NAME', 'anticrybaby')
R2_PUBLIC_URL = os.environ.get('R2_PUBLIC_URL', 'https://pub-1364b528762500de4f870e064229d443.r2.dev')

# Try to load from .env file if not in environment
ENV_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/.env"
if os.path.exists(ENV_FILE):
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                if key == 'R2_ACCESS_KEY_ID' and not R2_ACCESS_KEY_ID:
                    R2_ACCESS_KEY_ID = value
                elif key == 'R2_SECRET_ACCESS_KEY' and not R2_SECRET_ACCESS_KEY:
                    R2_SECRET_ACCESS_KEY = value
                elif key == 'R2_BUCKET_NAME' and value:
                    R2_BUCKET_NAME = value

def sign(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

def get_signature_key(key, date_stamp, region_name, service_name):
    k_date = sign(('AWS4' + key).encode('utf-8'), date_stamp)
    k_region = sign(k_date, region_name)
    k_service = sign(k_region, service_name)
    k_signing = sign(k_service, 'aws4_request')
    return k_signing

def sha256_hash(data):
    if isinstance(data, str):
        data = data.encode('utf-8')
    return hashlib.sha256(data).hexdigest()

def upload_to_r2(file_path, key, content_type='audio/mpeg'):
    """Upload a file to R2 using AWS Signature V4"""

    with open(file_path, 'rb') as f:
        file_content = f.read()

    payload_hash = sha256_hash(file_content)

    method = 'PUT'
    service = 's3'
    region = 'auto'
    host = f'{R2_BUCKET_NAME}.{R2_ACCOUNT_ID}.r2.cloudflarestorage.com'

    now = datetime.now(timezone.utc)
    amz_date = now.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = now.strftime('%Y%m%d')

    # URL encode the key properly
    encoded_key = urllib.request.quote(key, safe='/')
    canonical_uri = f'/{encoded_key}'
    canonical_querystring = ''

    canonical_headers = (
        f'content-length:{len(file_content)}\n'
        f'content-type:{content_type}\n'
        f'host:{host}\n'
        f'x-amz-content-sha256:{payload_hash}\n'
        f'x-amz-date:{amz_date}\n'
    )
    signed_headers = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date'

    canonical_request = (
        f'{method}\n'
        f'{canonical_uri}\n'
        f'{canonical_querystring}\n'
        f'{canonical_headers}\n'
        f'{signed_headers}\n'
        f'{payload_hash}'
    )

    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = f'{date_stamp}/{region}/{service}/aws4_request'
    string_to_sign = (
        f'{algorithm}\n'
        f'{amz_date}\n'
        f'{credential_scope}\n'
        f'{sha256_hash(canonical_request)}'
    )

    signing_key = get_signature_key(R2_SECRET_ACCESS_KEY, date_stamp, region, service)
    signature = hmac.new(signing_key, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()

    authorization_header = (
        f'{algorithm} '
        f'Credential={R2_ACCESS_KEY_ID}/{credential_scope}, '
        f'SignedHeaders={signed_headers}, '
        f'Signature={signature}'
    )

    url = f'https://{host}{canonical_uri}'

    headers = {
        'Content-Type': content_type,
        'Content-Length': str(len(file_content)),
        'X-Amz-Content-Sha256': payload_hash,
        'X-Amz-Date': amz_date,
        'Authorization': authorization_header,
    }

    try:
        req = urllib.request.Request(url, data=file_content, headers=headers, method='PUT')
        with urllib.request.urlopen(req, timeout=300) as response:
            return True, response.status
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='ignore')
        return False, f'HTTP {e.code}: {error_body[:200]}'
    except Exception as e:
        return False, str(e)

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

    # Expected structure: language/category/filename.mp3
    language = parts[0] if len(parts) > 0 else 'en'
    category = parts[1] if len(parts) > 1 else 'misc'
    filename = parts[-1]

    # Clean up title from filename
    name_without_ext = os.path.splitext(filename)[0]

    # Try to extract title from filename patterns
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

def main():
    print("=" * 60)
    print("PODCAST UPLOADER TO CLOUDFLARE R2")
    print("=" * 60)

    # Validate credentials
    if not R2_ACCESS_KEY_ID or not R2_SECRET_ACCESS_KEY:
        print("""
ERROR: R2 credentials not configured!

To upload files to Cloudflare R2, you need to:

1. Go to Cloudflare Dashboard > R2 > Manage R2 API Tokens
2. Create a new API token with "Object Read & Write" permissions
3. Add to your .env file:
   R2_ACCESS_KEY_ID=your_access_key_id
   R2_SECRET_ACCESS_KEY=your_secret_access_key

Or set environment variables before running this script.
""")

        # Still generate metadata for local use
        print("\nGenerating local metadata without uploading...")
        generate_metadata_only()
        return

    print(f"\nR2 Account ID: {R2_ACCOUNT_ID}")
    print(f"R2 Bucket: {R2_BUCKET_NAME}")
    print(f"Podcast Directory: {PODCAST_DIR}")

    # Find all podcast files
    podcast_files = []
    for root, dirs, files in os.walk(PODCAST_DIR):
        for file in files:
            if file.endswith(('.mp3', '.ogg', '.wav', '.m4a')):
                podcast_files.append(os.path.join(root, file))

    print(f"\nFound {len(podcast_files)} podcast files to upload")

    # Prepare metadata
    metadata_list = []
    success_count = 0
    fail_count = 0
    skip_count = 0

    # Create output directory
    os.makedirs(os.path.dirname(OUTPUT_METADATA), exist_ok=True)

    for i, file_path in enumerate(sorted(podcast_files)):
        # Extract metadata from path
        meta = extract_metadata_from_path(file_path, PODCAST_DIR)

        # Create R2 key
        r2_key = f"podcasts/{meta['language']}/{meta['category']}/{meta['filename']}"

        # Get file size
        file_size = os.path.getsize(file_path)
        content_type = get_content_type(file_path)

        print(f"[{i+1}/{len(podcast_files)}] {meta['title'][:40]}...")

        # Upload to R2
        success, result = upload_to_r2(file_path, r2_key, content_type)

        if success:
            print(f"  OK ({file_size/1024/1024:.1f} MB)")
            success_count += 1

            # Add to metadata
            metadata_list.append({
                'id': f"podcast_{meta['language']}_{meta['category']}_{i:04d}",
                'title': meta['title'],
                'artist': meta['artist'],
                'language': meta['language'],
                'category': meta['category'],
                'filename': meta['filename'],
                'r2Key': r2_key,
                'streamUrl': f"{R2_PUBLIC_URL}/{r2_key}",
                'size': file_size,
                'contentType': content_type,
                'source': 'podcast',
                'license': 'Public Domain / Free Distribution',
                'audioSourceType': 'streamed',
                'calmingScore': 0.8,
                'ageRangeMin': 0,
                'ageRangeMax': 36,
                'isPremium': False,
                'uploadedAt': datetime.now(timezone.utc).isoformat()
            })
        else:
            print(f"  FAILED: {result}")
            fail_count += 1

    # Save metadata
    output_data = {
        'version': '1.0',
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'totalTracks': len(metadata_list),
        'r2Bucket': R2_BUCKET_NAME,
        'publicUrl': R2_PUBLIC_URL,
        'tracks': metadata_list
    }

    with open(OUTPUT_METADATA, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    # Summary
    print("\n" + "=" * 60)
    print("UPLOAD COMPLETE")
    print("=" * 60)
    print(f"Uploaded: {success_count}")
    print(f"Failed: {fail_count}")
    print(f"\nMetadata saved to: {OUTPUT_METADATA}")
    print(f"Total tracks in library: {len(metadata_list)}")

    # Count by language
    lang_counts = {}
    for track in metadata_list:
        lang = track['language']
        lang_counts[lang] = lang_counts.get(lang, 0) + 1

    print("\nBy Language:")
    for lang, count in sorted(lang_counts.items()):
        print(f"  {lang}: {count}")

    print(f"\nPublic URL format: {R2_PUBLIC_URL}/podcasts/[lang]/[category]/[filename]")

def generate_metadata_only():
    """Generate metadata without uploading (for testing or when credentials are missing)"""

    # Find all podcast files
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
            'streamUrl': f"{R2_PUBLIC_URL}/{r2_key}",
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

    # Create output directory
    os.makedirs(os.path.dirname(OUTPUT_METADATA), exist_ok=True)

    output_data = {
        'version': '1.0',
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'totalTracks': len(metadata_list),
        'r2Bucket': R2_BUCKET_NAME,
        'publicUrl': R2_PUBLIC_URL,
        'tracks': metadata_list,
        'uploadPending': True
    }

    with open(OUTPUT_METADATA, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"\nMetadata saved to: {OUTPUT_METADATA}")
    print(f"Total tracks: {len(metadata_list)}")

    # Count by language
    lang_counts = {}
    for track in metadata_list:
        lang = track['language']
        lang_counts[lang] = lang_counts.get(lang, 0) + 1

    print("\nBy Language:")
    for lang, count in sorted(lang_counts.items()):
        print(f"  {lang}: {count}")

if __name__ == '__main__':
    main()
