#!/usr/bin/env python3
"""Upload fairy tales to Cloudflare R2 using S3-compatible API."""

import os
import boto3
from botocore.config import Config
from pathlib import Path
from dotenv import load_dotenv

# Load .env from parent directory
load_dotenv(Path(__file__).parent.parent / '.env')

# R2 Configuration
R2_ACCOUNT_ID = os.getenv('R2_ACCOUNT_ID') or os.getenv('CLOUDFLARE_ACCOUNT_ID')
R2_ACCESS_KEY_ID = os.getenv('R2_ACCESS_KEY_ID')
R2_SECRET_ACCESS_KEY = os.getenv('R2_SECRET_ACCESS_KEY')
R2_BUCKET_NAME = os.getenv('R2_BUCKET_NAME', 'anticrybaby')
R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

print(f"R2 Endpoint: {R2_ENDPOINT}")
print(f"R2 Bucket: {R2_BUCKET_NAME}")
print(f"Access Key ID: {R2_ACCESS_KEY_ID[:8]}..." if R2_ACCESS_KEY_ID else "Access Key ID: NOT SET")

if not all([R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY]):
    print("ERROR: Missing R2 credentials in .env")
    exit(1)

# Create S3 client for R2
s3 = boto3.client(
    's3',
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    config=Config(
        signature_version='s3v4',
        retries={'max_attempts': 3}
    ),
    region_name='auto'
)

# Fairy tales directory
FAIRYTALES_DIR = Path(__file__).parent.parent.parent / 'BabyInCarApp/BabyInCarApp/Resources/Audio/fairytales'

def upload_file(local_path: Path, r2_key: str) -> bool:
    """Upload a single file to R2."""
    try:
        s3.upload_file(
            str(local_path),
            R2_BUCKET_NAME,
            r2_key,
            ExtraArgs={'ContentType': 'audio/mpeg'}
        )
        return True
    except Exception as e:
        print(f"  ERROR: {e}")
        return False

def main():
    """Upload all fairy tales to R2."""
    uploaded = 0
    failed = 0

    for lang in ['en', 'ru']:
        lang_dir = FAIRYTALES_DIR / lang
        if not lang_dir.exists():
            print(f"Directory not found: {lang_dir}")
            continue

        mp3_files = list(lang_dir.glob('*.mp3'))
        print(f"\n{'='*60}")
        print(f"Uploading {len(mp3_files)} {lang.upper()} fairy tales...")
        print(f"{'='*60}")

        for i, mp3_file in enumerate(mp3_files, 1):
            r2_key = f"audio/fairytales/{lang}/{mp3_file.name}"
            print(f"[{i}/{len(mp3_files)}] {mp3_file.name}...", end=' ')

            if upload_file(mp3_file, r2_key):
                print("✓")
                uploaded += 1
            else:
                print("✗")
                failed += 1

    print(f"\n{'='*60}")
    print(f"UPLOAD COMPLETE: {uploaded} uploaded, {failed} failed")
    print(f"{'='*60}")

    if uploaded > 0:
        public_url = os.getenv('R2_PUBLIC_URL', f"https://pub-{R2_ACCOUNT_ID[:16]}.r2.dev")
        print(f"\nFiles accessible at: {public_url}/audio/fairytales/{{en|ru}}/")

if __name__ == '__main__':
    main()
