#!/usr/bin/env python3
"""
Verify R2 uploads by listing objects in the bucket
"""

import os
import json
import hmac
import hashlib
import urllib.request
import urllib.error
from datetime import datetime, timezone
import xml.etree.ElementTree as ET

# Configuration
R2_ACCOUNT_ID = "1364b528762500de4f870e064229d443"
R2_BUCKET_NAME = "anticrybaby"

# Load credentials from .env
ENV_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/.env"
R2_ACCESS_KEY_ID = ""
R2_SECRET_ACCESS_KEY = ""

if os.path.exists(ENV_FILE):
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                if key == 'R2_ACCESS_KEY_ID':
                    R2_ACCESS_KEY_ID = value
                elif key == 'R2_SECRET_ACCESS_KEY':
                    R2_SECRET_ACCESS_KEY = value

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

def list_objects(prefix="podcasts/", max_keys=100):
    """List objects in R2 bucket using S3 API"""

    method = 'GET'
    service = 's3'
    region = 'auto'
    host = f'{R2_BUCKET_NAME}.{R2_ACCOUNT_ID}.r2.cloudflarestorage.com'

    now = datetime.now(timezone.utc)
    amz_date = now.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = now.strftime('%Y%m%d')

    canonical_uri = '/'
    canonical_querystring = f'list-type=2&max-keys={max_keys}&prefix={urllib.request.quote(prefix, safe="")}'

    payload_hash = sha256_hash('')

    canonical_headers = (
        f'host:{host}\n'
        f'x-amz-content-sha256:{payload_hash}\n'
        f'x-amz-date:{amz_date}\n'
    )
    signed_headers = 'host;x-amz-content-sha256;x-amz-date'

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

    url = f'https://{host}/?{canonical_querystring}'

    headers = {
        'X-Amz-Content-Sha256': payload_hash,
        'X-Amz-Date': amz_date,
        'Authorization': authorization_header,
    }

    try:
        req = urllib.request.Request(url, headers=headers, method='GET')
        with urllib.request.urlopen(req, timeout=30) as response:
            content = response.read().decode('utf-8')
            return content
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='ignore')
        return f'Error: HTTP {e.code}: {error_body[:500]}'
    except Exception as e:
        return f'Error: {str(e)}'

def main():
    print("="*60)
    print("VERIFYING R2 UPLOADS")
    print("="*60)

    # List objects
    print("\nListing objects in bucket...")
    result = list_objects(prefix="podcasts/", max_keys=1000)

    if result.startswith('Error:'):
        print(result)
        return

    # Parse XML response
    try:
        root = ET.fromstring(result)

        # Extract namespace
        ns = {'s3': 'http://s3.amazonaws.com/doc/2006-03-01/'}

        # Get key count
        key_count = root.find('.//s3:KeyCount', ns)
        if key_count is not None:
            print(f"Objects found: {key_count.text}")

        # List first 20 objects
        contents = root.findall('.//s3:Contents', ns)

        print(f"\nTotal objects: {len(contents)}")
        print("\nSample objects:")

        lang_counts = {'en': 0, 'ru': 0, 'multi': 0, 'other': 0}
        total_size = 0

        for content in contents[:20]:
            key = content.find('s3:Key', ns)
            size = content.find('s3:Size', ns)
            if key is not None:
                key_text = key.text
                size_bytes = int(size.text) if size is not None else 0
                total_size += size_bytes

                # Count by language
                if '/en/' in key_text:
                    lang_counts['en'] += 1
                elif '/ru/' in key_text:
                    lang_counts['ru'] += 1
                elif '/multi/' in key_text:
                    lang_counts['multi'] += 1
                else:
                    lang_counts['other'] += 1

                print(f"  {key_text[:70]}... ({size_bytes/1024/1024:.1f} MB)")

        # Count all by language
        for content in contents[20:]:
            key = content.find('s3:Key', ns)
            size = content.find('s3:Size', ns)
            if key is not None:
                key_text = key.text
                size_bytes = int(size.text) if size is not None else 0
                total_size += size_bytes

                if '/en/' in key_text:
                    lang_counts['en'] += 1
                elif '/ru/' in key_text:
                    lang_counts['ru'] += 1
                elif '/multi/' in key_text:
                    lang_counts['multi'] += 1
                else:
                    lang_counts['other'] += 1

        print(f"\n{'='*60}")
        print("SUMMARY")
        print("="*60)
        print(f"Total objects: {len(contents)}")
        print(f"Total size: {total_size/1024/1024/1024:.2f} GB")
        print(f"\nBy language:")
        print(f"  English: {lang_counts['en']}")
        print(f"  Russian: {lang_counts['ru']}")
        print(f"  Multi-language: {lang_counts['multi']}")
        if lang_counts['other'] > 0:
            print(f"  Other: {lang_counts['other']}")

        if len(contents) >= 240:
            print("\n[SUCCESS] All podcasts appear to be uploaded!")
        else:
            print(f"\n[WARNING] Expected ~242 files, found {len(contents)}")

    except ET.ParseError as e:
        print(f"Failed to parse response: {e}")
        print(f"Response: {result[:500]}")

if __name__ == '__main__':
    main()
