#!/usr/bin/env python3
"""
Upload Audio Files to Cloudflare R2 using boto3
Requires: pip install boto3
"""

import os
import sys
import json
import boto3
from botocore.config import Config
from pathlib import Path
from datetime import datetime

# Load .env file
def load_env():
    env_path = Path(__file__).parent.parent / '.env'
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ.setdefault(key.strip(), value.strip())

load_env()

# Configuration
R2_ACCOUNT_ID = os.environ.get('R2_ACCOUNT_ID')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY')
BUCKET_NAME = 'anticrybaby'
AUDIO_DIR = Path(__file__).parent.parent.parent / 'BabyInCarApp/BabyInCarApp/Resources/Audio'

# Content types
CONTENT_TYPES = {
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.m4a': 'audio/mp4',
    '.flac': 'audio/flac',
}

def get_r2_client():
    """Create R2 client using S3-compatible API."""
    return boto3.client(
        's3',
        endpoint_url=f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com',
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(
            signature_version='s3v4',
            s3={'addressing_style': 'path'}
        ),
        region_name='auto'
    )

def format_size(size_bytes):
    """Format file size for display."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"

def get_audio_files(category=None):
    """Get list of audio files to upload."""
    files = []
    audio_extensions = {'.mp3', '.ogg', '.wav', '.m4a', '.flac'}

    if not AUDIO_DIR.exists():
        print(f"Error: Audio directory not found: {AUDIO_DIR}")
        return files

    for path in AUDIO_DIR.rglob('*'):
        if path.is_file() and path.suffix.lower() in audio_extensions:
            rel_path = path.relative_to(AUDIO_DIR)
            file_category = rel_path.parts[0] if rel_path.parts else 'uncategorized'

            if category and file_category != category:
                continue

            files.append({
                'local_path': path,
                'rel_path': str(rel_path),
                'r2_key': f'audio/{rel_path}',
                'category': file_category,
                'size': path.stat().st_size,
                'content_type': CONTENT_TYPES.get(path.suffix.lower(), 'application/octet-stream'),
            })

    return files

def upload_file(client, file_info):
    """Upload a single file to R2."""
    try:
        with open(file_info['local_path'], 'rb') as f:
            client.put_object(
                Bucket=BUCKET_NAME,
                Key=file_info['r2_key'],
                Body=f,
                ContentType=file_info['content_type'],
            )
        return True
    except Exception as e:
        print(f"  Error: {e}")
        return False

def main():
    # Parse arguments
    category = None
    dry_run = '--dry-run' in sys.argv

    for arg in sys.argv[1:]:
        if not arg.startswith('--'):
            category = arg

    print("=" * 60)
    print("Upload Audio Files to Cloudflare R2")
    print("=" * 60)
    print()

    # Check credentials
    if not all([R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY]):
        print("Error: R2 credentials not found in .env file")
        print("Required: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY")
        sys.exit(1)

    print(f"Account ID: {R2_ACCOUNT_ID[:8]}...")
    print(f"Bucket: {BUCKET_NAME}")
    print(f"Audio directory: {AUDIO_DIR}")
    print(f"Category filter: {category or 'all'}")
    print(f"Dry run: {dry_run}")
    print()

    # Get files
    files = get_audio_files(category)

    if not files:
        print("No audio files found to upload.")
        return

    # Summary by category
    by_category = {}
    for f in files:
        cat = f['category']
        if cat not in by_category:
            by_category[cat] = {'count': 0, 'size': 0}
        by_category[cat]['count'] += 1
        by_category[cat]['size'] += f['size']

    print("Files by category:")
    total_size = 0
    for cat, info in sorted(by_category.items()):
        print(f"  {cat}: {info['count']} files ({format_size(info['size'])})")
        total_size += info['size']

    print()
    print(f"Total: {len(files)} files ({format_size(total_size)})")
    print()

    if dry_run:
        print("DRY RUN - Files that would be uploaded:")
        for f in files[:20]:
            print(f"  {f['r2_key']} ({format_size(f['size'])})")
        if len(files) > 20:
            print(f"  ... and {len(files) - 20} more files")
        print()
        print("Run without --dry-run to upload.")
        return

    # Create R2 client
    print("Connecting to R2...")
    client = get_r2_client()

    # Upload files
    print("Starting upload...")
    print()

    success_count = 0
    fail_count = 0
    uploaded = []

    for i, f in enumerate(files, 1):
        progress = f"[{i}/{len(files)}]"
        print(f"{progress} {f['rel_path']} ({format_size(f['size'])})")

        if upload_file(client, f):
            success_count += 1
            uploaded.append(f)
            print(f"  -> r2://{BUCKET_NAME}/{f['r2_key']} SUCCESS")
        else:
            fail_count += 1
            print(f"  -> FAILED")

    print()
    print("=" * 60)
    print("Upload Complete")
    print("=" * 60)
    print(f"Successful: {success_count}")
    print(f"Failed: {fail_count}")
    print()

    # Save metadata
    if uploaded:
        metadata_path = Path(__file__).parent.parent / 'r2-uploaded-files.json'
        metadata = [{
            'localPath': str(f['rel_path']),
            'r2Key': f['r2_key'],
            'r2Url': f"r2://{BUCKET_NAME}/{f['r2_key']}",
            'publicUrl': f"https://anticrybaby.{R2_ACCOUNT_ID}.r2.cloudflarestorage.com/{f['r2_key']}",
            'size': f['size'],
            'category': f['category'],
            'contentType': f['content_type'],
            'uploadedAt': datetime.utcnow().isoformat() + 'Z',
        } for f in uploaded]

        # Append to existing if exists
        existing = []
        if metadata_path.exists():
            try:
                with open(metadata_path) as f:
                    existing = json.load(f)
            except:
                pass

        # Merge, avoiding duplicates
        existing_keys = {m['r2Key'] for m in existing}
        for m in metadata:
            if m['r2Key'] not in existing_keys:
                existing.append(m)

        with open(metadata_path, 'w') as f:
            json.dump(existing, f, indent=2)

        print(f"Metadata saved to: {metadata_path}")

if __name__ == '__main__':
    main()
