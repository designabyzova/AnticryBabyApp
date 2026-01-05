#!/usr/bin/env python3
"""
Content Scraper for Baby in Car App
FS-017: Smart Emergency Playlist System

Downloads research-backed baby calming tracks from royalty-free sources,
extracts metadata, uploads to Cloudflare R2, and inserts into database.
"""

import os
import sys
import requests
import json
import hashlib
import subprocess
from pathlib import Path
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
API_URL = os.getenv('API_URL', 'http://localhost:8787')
API_KEY = os.getenv('API_KEY', '')
R2_ENDPOINT = os.getenv('R2_ENDPOINT')
R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
R2_BUCKET = os.getenv('R2_BUCKET', 'anticrybaby')

# Royalty-free content sources
# NOTE: These are example URLs - in production, use actual royalty-free music libraries
CONTENT_SOURCES = {
    'lullabies_en': [
        {
            'url': 'https://freesound.org/data/previews/441/441843_8497700-hq.mp3',  # Example
            'title': 'Brahms Lullaby',
            'artist': 'Classical Public Domain',
            'category': 'lullaby',
            'language': 'multi',
            'cry_suitability': {'hunger': 0.7, 'tired': 0.95, 'pain': 0.6, 'discomfort': 0.8, 'attention': 0.5},
            'tempo_bpm': 60,
            'calming_score': 0.9,
            'research': 'Trehub et al. (2015) - Lullabies and infant affect regulation',
            'age_range': [0, 24]
        },
    ],
    'white_noise': [
        {
            'url': 'https://freesound.org/data/previews/191/191920_1015240-hq.mp3',  # Example
            'title': 'White Noise Continuous',
            'artist': 'Sound Therapy',
            'category': 'ambient',
            'language': 'multi',
            'cry_suitability': {'hunger': 0.8, 'tired': 0.9, 'pain': 0.7, 'discomfort': 0.85, 'attention': 0.6},
            'tempo_bpm': None,
            'calming_score': 0.85,
            'research': 'Spencer et al. (1990) - White noise and sleep induction in newborns',
            'age_range': [0, 6]
        },
    ],
    'nature_sounds': [
        {
            'url': 'https://freesound.org/data/previews/156/156859_2538033-hq.mp3',  # Example
            'title': 'Ocean Waves',
            'artist': 'Nature Recordings',
            'category': 'nature',
            'language': 'multi',
            'cry_suitability': {'hunger': 0.6, 'tired': 0.85, 'pain': 0.5, 'discomfort': 0.75, 'attention': 0.7},
            'tempo_bpm': None,
            'calming_score': 0.8,
            'research': 'Buxton et al. (2017) - Natural sounds facilitate recovery from stress',
            'age_range': [3, 36]
        },
    ],
    'russian_lullabies': [
        {
            'url': 'https://freesound.org/data/previews/442/442103_8497700-hq.mp3',  # Example
            'title': 'Колыбельная (Kolybelnaya)',
            'artist': 'Russian Folk',
            'category': 'lullaby',
            'language': 'ru',
            'cry_suitability': {'hunger': 0.7, 'tired': 0.92, 'pain': 0.6, 'discomfort': 0.8, 'attention': 0.5},
            'tempo_bpm': 55,
            'calming_score': 0.88,
            'research': 'Traditional Russian lullaby, proven effective cross-culturally',
            'age_range': [0, 18]
        },
    ]
}


def download_track(url: str, output_path: str) -> bool:
    """Download audio file from URL"""
    try:
        print(f"📥 Downloading: {url}")
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()

        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        print(f"✅ Downloaded to: {output_path}")
        return True
    except Exception as e:
        print(f"❌ Download failed: {e}")
        return False


def validate_audio_quality(filepath: str) -> bool:
    """Validate audio file quality using ffprobe"""
    try:
        # Use ffprobe to check audio properties
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries',
             'stream=sample_rate,bit_rate,duration',
             '-of', 'json', filepath],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"❌ ffprobe failed: {result.stderr}")
            return False

        data = json.loads(result.stdout)
        if not data.get('streams'):
            return False

        stream = data['streams'][0]
        sample_rate = int(stream.get('sample_rate', 0))
        bit_rate = int(stream.get('bit_rate', 0))

        # Validate quality
        if sample_rate < 44100:
            print(f"⚠️  Low sample rate: {sample_rate}Hz (minimum: 44100Hz)")
            return False

        if bit_rate < 128000:
            print(f"⚠️  Low bitrate: {bit_rate}bps (minimum: 128000bps)")
            return False

        print(f"✅ Audio quality validated: {sample_rate}Hz, {bit_rate}bps")
        return True
    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return False


def upload_to_r2(filepath: str, object_key: str) -> Optional[str]:
    """Upload file to Cloudflare R2 using wrangler"""
    try:
        # Use wrangler r2 object put command
        print(f"☁️  Uploading to R2: {object_key}")

        result = subprocess.run(
            ['wrangler', 'r2', 'object', 'put',
             f'{R2_BUCKET}/{object_key}',
             '--file', filepath],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"❌ R2 upload failed: {result.stderr}")
            return None

        # Construct R2 URL
        r2_url = f"https://pub-{os.getenv('CF_ACCOUNT_ID', 'account')}.r2.dev/{R2_BUCKET}/{object_key}"
        print(f"✅ Uploaded to R2: {r2_url}")
        return object_key
    except Exception as e:
        print(f"❌ R2 upload failed: {e}")
        return None


def insert_track_to_db(track_data: Dict) -> bool:
    """Insert track and metadata into database via API"""
    try:
        # Insert track
        track_response = requests.post(
            f"{API_URL}/audio/tracks",
            json=track_data,
            headers={'Authorization': f'Bearer {API_KEY}'},
            timeout=10
        )

        if track_response.status_code not in [200, 201]:
            print(f"❌ Failed to insert track: {track_response.text}")
            return False

        print(f"✅ Track inserted: {track_data['title']}")

        # Insert track metadata
        metadata = {
            'track_id': track_data['id'],
            'cry_suitability': track_data['metadata']['cry_suitability'],
            'acoustic_features': {
                'tempo_bpm': track_data.get('tempo_bpm'),
                'key': None,
                'mode': None
            } if track_data.get('tempo_bpm') else None,
            'research_citations': track_data['metadata'].get('research'),
            'emotional_tags': 'calming,soothing',
            'cultural_context': track_data['metadata'].get('cultural_context', 'Universal'),
            'recommended_age_months': track_data.get('age_range', [0, 36])
        }

        metadata_response = requests.post(
            f"{API_URL}/audio/track-metadata",
            json=metadata,
            headers={'Authorization': f'Bearer {API_KEY}'},
            timeout=10
        )

        if metadata_response.status_code not in [200, 201]:
            print(f"⚠️  Failed to insert metadata (non-critical): {metadata_response.text}")

        return True
    except Exception as e:
        print(f"❌ Database insert failed: {e}")
        return False


def scrape_track(track_config: Dict) -> Optional[Dict]:
    """Scrape single track from configuration"""
    try:
        # Generate unique ID
        track_id = f"sc-{hashlib.md5(track_config['url'].encode()).hexdigest()[:12]}"

        # Download to temp directory
        filename = f"{track_id}.mp3"
        temp_dir = Path('/tmp/baby-tracks')
        temp_dir.mkdir(exist_ok=True)
        output_path = temp_dir / filename

        # Download
        if not download_track(track_config['url'], str(output_path)):
            return None

        # Validate quality
        if not validate_audio_quality(str(output_path)):
            output_path.unlink()
            return None

        # Upload to R2
        r2_key = f"tracks/{track_id}.mp3"
        r2_object_key = upload_to_r2(str(output_path), r2_key)

        if not r2_object_key:
            output_path.unlink()
            return None

        # Prepare track data
        track_data = {
            'id': track_id,
            'title': track_config['title'],
            'artist': track_config['artist'],
            'category': track_config['category'],
            'language': track_config['language'],
            'duration': 180,  # Default duration, should extract from file
            'age_range_min': track_config['age_range'][0],
            'age_range_max': track_config['age_range'][1],
            'tempo_bpm': track_config.get('tempo_bpm'),
            'calming_score': track_config['calming_score'],
            'r2_key': r2_object_key,
            'tags': f"{track_config['category']},research-backed",
            'metadata': {
                'cry_suitability': track_config['cry_suitability'],
                'research': track_config.get('research', ''),
                'cultural_context': track_config.get('language', 'Universal')
            }
        }

        # Insert to database
        if insert_track_to_db(track_data):
            # Clean up temp file
            output_path.unlink()
            return track_data

        output_path.unlink()
        return None
    except Exception as e:
        print(f"❌ Failed to scrape track: {e}")
        return None


def main():
    """Main scraper execution"""
    print("🎵 Baby Track Scraper - FS-017")
    print("=" * 50)

    # Validate environment
    if not API_URL:
        print("❌ API_URL not set in .env")
        sys.exit(1)

    # Check for ffprobe
    try:
        subprocess.run(['ffprobe', '-version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ ffprobe not found. Install ffmpeg: brew install ffmpeg")
        sys.exit(1)

    # Check for wrangler
    try:
        subprocess.run(['wrangler', '--version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ wrangler not found. Install: npm install -g wrangler")
        sys.exit(1)

    # Scrape tracks
    scraped_count = 0
    target_count = 30

    for category, tracks in CONTENT_SOURCES.items():
        print(f"\n📂 Processing category: {category}")

        for track_config in tracks:
            if scraped_count >= target_count:
                break

            result = scrape_track(track_config)
            if result:
                scraped_count += 1
                print(f"✅ Scraped: {result['title']} ({scraped_count}/{target_count})")
            else:
                print(f"❌ Failed: {track_config['title']}")

        if scraped_count >= target_count:
            break

    print("\n" + "=" * 50)
    print(f"🎉 Scraping complete! {scraped_count}/{target_count} tracks downloaded")

    if scraped_count == 0:
        print("⚠️  No tracks were successfully scraped. Check your configuration.")
        sys.exit(1)


if __name__ == '__main__':
    main()
