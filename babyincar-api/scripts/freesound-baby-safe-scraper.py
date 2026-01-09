#!/usr/bin/env python3
"""
Freesound Baby-Safe Audio Scraper
Downloads ONLY baby-appropriate sounds from Freesound.

ALLOWED: Lullabies, music box, gentle ocean/birds/river, classical instruments
FORBIDDEN: Rain, thunder, white noise, mechanical sounds, loud/scary sounds

Usage:
    python freesound-baby-safe-scraper.py           # One-time run
    python freesound-baby-safe-scraper.py --daemon  # 24/7 mode (runs every 6 hours)

Requires:
    pip install requests boto3 python-dotenv schedule
"""

import os
import sys
import json
import time
import hashlib
import requests
import logging
import argparse
from pathlib import Path
from datetime import datetime
from typing import Optional

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Configuration
FREESOUND_API_KEY = os.environ.get('FREESOUND_API_KEY', '')
FREESOUND_CLIENT_ID = os.environ.get('FREESOUND_CLIENT_ID', '')

# R2 Configuration
CF_ACCOUNT_ID = os.environ.get('CF_ACCOUNT_ID', '')
CF_R2_ACCESS_KEY_ID = os.environ.get('CF_R2_ACCESS_KEY_ID', '')
CF_R2_SECRET_ACCESS_KEY = os.environ.get('CF_R2_SECRET_ACCESS_KEY', '')
CF_R2_BUCKET_NAME = os.environ.get('CF_R2_BUCKET_NAME', 'babyincar-audio')

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
DOWNLOAD_DIR = SCRIPT_DIR / 'freesound-downloads'
METADATA_FILE = SCRIPT_DIR / 'freesound-baby-safe-metadata.json'
PROCESSED_IDS_FILE = SCRIPT_DIR / 'freesound-processed-ids.json'
LOG_FILE = SCRIPT_DIR / 'freesound-scraper.log'

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============================================================
# BABY-SAFE SEARCH QUERIES
# Only gentle, soothing sounds appropriate for babies
# ============================================================

ALLOWED_SEARCHES = [
    # Lullabies & Music Box
    {
        "query": "lullaby gentle",
        "category": "lullabies",
        "subcategory": "vocal",
        "tags": ["lullaby", "gentle", "baby"],
        "minDuration": 30,
        "maxDuration": 600
    },
    {
        "query": "music box melody",
        "category": "lullabies",
        "subcategory": "music_box",
        "tags": ["music box", "melody", "gentle"],
        "minDuration": 30,
        "maxDuration": 300
    },
    {
        "query": "music box lullaby baby",
        "category": "lullabies",
        "subcategory": "music_box",
        "tags": ["music box", "lullaby", "baby"],
        "minDuration": 30,
        "maxDuration": 300
    },
    {
        "query": "glockenspiel gentle",
        "category": "lullabies",
        "subcategory": "music_box",
        "tags": ["glockenspiel", "gentle", "melody"],
        "minDuration": 20,
        "maxDuration": 180
    },
    {
        "query": "harp lullaby calm",
        "category": "lullabies",
        "subcategory": "harp",
        "tags": ["harp", "lullaby", "calm"],
        "minDuration": 30,
        "maxDuration": 300
    },

    # Classical Music (gentle pieces only)
    {
        "query": "piano gentle calm",
        "category": "classical",
        "subcategory": "piano",
        "tags": ["piano", "gentle", "calm"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "classical piano soft",
        "category": "classical",
        "subcategory": "piano",
        "tags": ["classical", "piano", "soft"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "strings peaceful ambient",
        "category": "classical",
        "subcategory": "strings",
        "tags": ["strings", "peaceful", "ambient"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "violin gentle melody",
        "category": "classical",
        "subcategory": "strings",
        "tags": ["violin", "gentle", "melody"],
        "minDuration": 30,
        "maxDuration": 300
    },
    {
        "query": "cello peaceful",
        "category": "classical",
        "subcategory": "strings",
        "tags": ["cello", "peaceful", "calm"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "flute gentle melody",
        "category": "classical",
        "subcategory": "woodwind",
        "tags": ["flute", "gentle", "melody"],
        "minDuration": 30,
        "maxDuration": 300
    },

    # Gentle Nature (NO rain, thunder, wind)
    {
        "query": "ocean waves gentle calm",
        "category": "nature",
        "subcategory": "ocean",
        "tags": ["ocean", "waves", "calm"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "sea waves soft",
        "category": "nature",
        "subcategory": "ocean",
        "tags": ["sea", "waves", "soft"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "birds singing morning gentle",
        "category": "nature",
        "subcategory": "birds",
        "tags": ["birds", "singing", "morning"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "birdsong peaceful",
        "category": "nature",
        "subcategory": "birds",
        "tags": ["birdsong", "peaceful", "nature"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "river stream gentle",
        "category": "nature",
        "subcategory": "water",
        "tags": ["river", "stream", "gentle"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "brook babbling water",
        "category": "nature",
        "subcategory": "water",
        "tags": ["brook", "water", "peaceful"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "forest ambience peaceful",
        "category": "nature",
        "subcategory": "forest",
        "tags": ["forest", "ambience", "peaceful"],
        "minDuration": 60,
        "maxDuration": 600
    },

    # Ambient (gentle only)
    {
        "query": "ambient calm meditation",
        "category": "ambient",
        "subcategory": "meditation",
        "tags": ["ambient", "calm", "meditation"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "spa relaxing music",
        "category": "ambient",
        "subcategory": "spa",
        "tags": ["spa", "relaxing", "calm"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "wind chimes gentle",
        "category": "ambient",
        "subcategory": "chimes",
        "tags": ["wind chimes", "gentle", "peaceful"],
        "minDuration": 30,
        "maxDuration": 180
    },

    # Baby-specific
    {
        "query": "humming soothing",
        "category": "lullabies",
        "subcategory": "vocal",
        "tags": ["humming", "soothing", "gentle"],
        "minDuration": 30,
        "maxDuration": 300
    },
    {
        "query": "heartbeat womb",
        "category": "ambient",
        "subcategory": "heartbeat",
        "tags": ["heartbeat", "womb", "baby"],
        "minDuration": 60,
        "maxDuration": 600
    },
    {
        "query": "shush soothing baby",
        "category": "ambient",
        "subcategory": "shush",
        "tags": ["shush", "soothing", "baby"],
        "minDuration": 30,
        "maxDuration": 300
    },
]

# ============================================================
# FORBIDDEN KEYWORDS - Never download sounds containing these
# ============================================================

FORBIDDEN_KEYWORDS = [
    # Weather (scary for babies)
    'rain', 'thunder', 'storm', 'lightning', 'thunderstorm',
    'wind', 'windy', 'hurricane', 'tornado',

    # Mechanical/Harsh sounds
    'vacuum', 'hoover', 'hair dryer', 'hairdryer', 'blowdryer',
    'washing machine', 'dishwasher', 'dryer', 'laundry',
    'fan', 'air conditioner', 'ac unit', 'hvac',
    'car engine', 'motor', 'engine', 'vehicle',
    'airplane', 'plane', 'jet', 'helicopter',
    'train', 'railway', 'locomotive',
    'machine', 'industrial', 'factory',

    # White/Pink/Brown noise (user feedback: scary)
    'white noise', 'whitenoise', 'white-noise',
    'pink noise', 'pinknoise', 'pink-noise',
    'brown noise', 'brownnoise', 'brown-noise',
    'noise generator', 'static',

    # City/Urban (not soothing)
    'traffic', 'city', 'urban', 'street', 'crowd',
    'construction', 'sirens', 'alarm',

    # Scary/Loud sounds
    'scary', 'horror', 'creepy', 'dark', 'evil',
    'explosion', 'gunshot', 'war', 'battle',
    'scream', 'crying', 'loud', 'intense',
]

def is_sound_safe(sound_name: str, sound_tags: list) -> bool:
    """Check if a sound is safe for babies (no forbidden keywords)"""
    check_text = (sound_name + ' ' + ' '.join(sound_tags)).lower()

    for forbidden in FORBIDDEN_KEYWORDS:
        if forbidden.lower() in check_text:
            return False
    return True

def load_processed_ids() -> set:
    """Load IDs of already processed sounds"""
    if PROCESSED_IDS_FILE.exists():
        with open(PROCESSED_IDS_FILE, 'r') as f:
            return set(json.load(f))
    return set()

def save_processed_ids(ids: set):
    """Save processed IDs to avoid re-downloading"""
    with open(PROCESSED_IDS_FILE, 'w') as f:
        json.dump(list(ids), f)

def search_freesound(query: str, min_duration: int = 30, max_duration: int = 600) -> list:
    """Search Freesound for CC0 licensed sounds"""
    if not FREESOUND_API_KEY:
        logger.error("FREESOUND_API_KEY not set!")
        return []

    url = "https://freesound.org/apiv2/search/text/"
    params = {
        'query': query,
        'filter': f'license:"Creative Commons 0" duration:[{min_duration} TO {max_duration}]',
        'fields': 'id,name,duration,previews,tags,avg_rating,num_downloads,description',
        'sort': 'rating_desc',
        'page_size': 15,
        'token': FREESOUND_API_KEY
    }

    try:
        response = requests.get(url, params=params, timeout=30)
        if response.status_code == 200:
            return response.json().get('results', [])
        else:
            logger.error(f"API error {response.status_code}: {response.text[:200]}")
    except Exception as e:
        logger.error(f"Request failed: {e}")

    return []

def download_sound(preview_url: str, output_path: Path) -> bool:
    """Download a sound preview"""
    try:
        response = requests.get(preview_url, stream=True, timeout=60)
        if response.status_code == 200:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
    except Exception as e:
        logger.error(f"Download failed: {e}")
    return False

def upload_to_r2(local_path: Path, r2_key: str) -> Optional[str]:
    """Upload file to Cloudflare R2"""
    if not all([CF_ACCOUNT_ID, CF_R2_ACCESS_KEY_ID, CF_R2_SECRET_ACCESS_KEY]):
        logger.warning("R2 credentials not configured, skipping upload")
        return None

    try:
        import boto3
        from botocore.config import Config

        s3 = boto3.client(
            's3',
            endpoint_url=f'https://{CF_ACCOUNT_ID}.r2.cloudflarestorage.com',
            aws_access_key_id=CF_R2_ACCESS_KEY_ID,
            aws_secret_access_key=CF_R2_SECRET_ACCESS_KEY,
            config=Config(signature_version='s3v4'),
            region_name='auto'
        )

        s3.upload_file(
            str(local_path),
            CF_R2_BUCKET_NAME,
            r2_key,
            ExtraArgs={'ContentType': 'audio/mpeg'}
        )

        # Return public URL
        return f"https://audio.babyincar.app/{r2_key}"
    except Exception as e:
        logger.error(f"R2 upload failed: {e}")
        return None

def run_scraper():
    """Main scraper logic"""
    logger.info("=" * 60)
    logger.info("Freesound Baby-Safe Scraper Started")
    logger.info(f"Time: {datetime.now().isoformat()}")
    logger.info("=" * 60)

    if not FREESOUND_API_KEY:
        logger.error("FREESOUND_API_KEY not set! Add to .env file.")
        return

    # Create download directory
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)

    # Load existing metadata and processed IDs
    processed_ids = load_processed_ids()
    all_metadata = []

    if METADATA_FILE.exists():
        with open(METADATA_FILE, 'r') as f:
            all_metadata = json.load(f)

    total_new = 0
    total_skipped = 0
    total_forbidden = 0

    for search_config in ALLOWED_SEARCHES:
        query = search_config['query']
        category = search_config['category']
        subcategory = search_config['subcategory']
        tags = search_config['tags']
        min_dur = search_config.get('minDuration', 30)
        max_dur = search_config.get('maxDuration', 600)

        logger.info(f"\nSearching: '{query}'")

        results = search_freesound(query, min_dur, max_dur)
        logger.info(f"  Found {len(results)} results")

        for sound in results:
            sound_id = str(sound['id'])
            name = sound['name']
            sound_tags = sound.get('tags', [])
            duration = sound['duration']

            # Skip already processed
            if sound_id in processed_ids:
                total_skipped += 1
                continue

            # Safety check
            if not is_sound_safe(name, sound_tags):
                logger.info(f"  [FORBIDDEN] {name}")
                total_forbidden += 1
                processed_ids.add(sound_id)
                continue

            # Get preview URL
            preview_url = sound.get('previews', {}).get('preview-hq-mp3', '')
            if not preview_url:
                continue

            # Generate filename
            safe_name = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name[:30])
            filename = f"fs_{sound_id}_{safe_name}.mp3"
            r2_key = f"freesound/{category}/{subcategory}/{filename}"
            local_path = DOWNLOAD_DIR / category / subcategory / filename

            # Download
            logger.info(f"  [DOWNLOAD] {name} ({duration:.1f}s)")
            if download_sound(preview_url, local_path):
                # Upload to R2
                stream_url = upload_to_r2(local_path, r2_key)

                # Create metadata entry
                metadata_entry = {
                    'id': f'fs_{sound_id}',
                    'title': name,
                    'artist': 'Freesound CC0',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'freesound',
                    'freesoundId': sound_id,
                    'license': 'CC0',
                    'filename': r2_key,
                    'streamURL': stream_url,
                    'duration': int(duration),
                    'tags': list(set(tags + sound_tags[:5])),
                    'calmScore': 0.85,
                    'ageRangeMin': 0,
                    'ageRangeMax': 36,
                    'isPremium': False,
                    'contentType': 'music' if category in ['lullabies', 'classical'] else 'sound',
                    'addedAt': datetime.now().isoformat()
                }

                all_metadata.append(metadata_entry)
                processed_ids.add(sound_id)
                total_new += 1

            # Rate limiting
            time.sleep(0.5)

        # Save progress after each search
        save_processed_ids(processed_ids)
        with open(METADATA_FILE, 'w') as f:
            json.dump(all_metadata, f, indent=2)

    # Final summary
    logger.info("")
    logger.info("=" * 60)
    logger.info("SCRAPER COMPLETE")
    logger.info(f"  New downloads: {total_new}")
    logger.info(f"  Already processed: {total_skipped}")
    logger.info(f"  Forbidden (filtered): {total_forbidden}")
    logger.info(f"  Total in library: {len(all_metadata)}")
    logger.info(f"  Metadata saved to: {METADATA_FILE}")
    logger.info("=" * 60)

def run_daemon():
    """Run scraper in daemon mode (every 6 hours)"""
    import schedule

    logger.info("Starting Freesound scraper in DAEMON mode")
    logger.info("Will run every 6 hours")

    # Run immediately on start
    run_scraper()

    # Schedule for every 6 hours
    schedule.every(6).hours.do(run_scraper)

    while True:
        schedule.run_pending()
        time.sleep(60)  # Check every minute

def main():
    parser = argparse.ArgumentParser(description='Freesound Baby-Safe Scraper')
    parser.add_argument('--daemon', action='store_true', help='Run in 24/7 daemon mode')
    args = parser.parse_args()

    if args.daemon:
        run_daemon()
    else:
        run_scraper()

if __name__ == '__main__':
    main()
