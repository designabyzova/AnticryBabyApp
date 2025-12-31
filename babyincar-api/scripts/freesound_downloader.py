#!/usr/bin/env python3
"""
Freesound CC0 Audio Downloader for Baby in Car App
Requires: pip install freesound-python requests

Usage:
1. Get API key from https://freesound.org/apiv2/apply/
2. Set environment variable: export FREESOUND_API_KEY=your_key
3. Run: python freesound_downloader.py
"""

import os
import sys
import json
import time
import requests
from pathlib import Path

# Configuration
FREESOUND_API_KEY = os.environ.get('FREESOUND_API_KEY', '')
OUTPUT_DIR = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio'
METADATA_FILE = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/scripts/freesound-metadata.json'
MAX_TRACKS_PER_QUERY = 10

# Search queries
SEARCH_QUERIES = [
  {
    "query": "rain gentle",
    "category": "nature",
    "subcategory": "rain",
    "tags": [
      "rain",
      "gentle",
      "relaxing"
    ],
    "minDuration": 60
  },
  {
    "query": "ocean waves calm",
    "category": "nature",
    "subcategory": "water",
    "tags": [
      "ocean",
      "waves",
      "calm"
    ],
    "minDuration": 60
  },
  {
    "query": "forest birds morning",
    "category": "nature",
    "subcategory": "birds",
    "tags": [
      "forest",
      "birds",
      "morning"
    ],
    "minDuration": 30
  },
  {
    "query": "stream water flowing",
    "category": "nature",
    "subcategory": "water",
    "tags": [
      "stream",
      "water",
      "nature"
    ],
    "minDuration": 60
  },
  {
    "query": "wind soft gentle",
    "category": "nature",
    "subcategory": "wind",
    "tags": [
      "wind",
      "soft",
      "ambient"
    ],
    "minDuration": 30
  },
  {
    "query": "night crickets summer",
    "category": "nature",
    "subcategory": "night",
    "tags": [
      "crickets",
      "night",
      "summer"
    ],
    "minDuration": 60
  },
  {
    "query": "thunderstorm distant",
    "category": "nature",
    "subcategory": "rain",
    "tags": [
      "thunder",
      "rain",
      "distant"
    ],
    "minDuration": 60
  },
  {
    "query": "waterfall nature",
    "category": "nature",
    "subcategory": "water",
    "tags": [
      "waterfall",
      "nature",
      "relaxing"
    ],
    "minDuration": 60
  },
  {
    "query": "campfire crackling fire",
    "category": "nature",
    "subcategory": "ambient",
    "tags": [
      "fire",
      "crackling",
      "cozy"
    ],
    "minDuration": 60
  },
  {
    "query": "meadow ambience",
    "category": "nature",
    "subcategory": "ambient",
    "tags": [
      "meadow",
      "nature",
      "peaceful"
    ],
    "minDuration": 60
  },
  {
    "query": "white noise sleep",
    "category": "ambient",
    "subcategory": "noise",
    "tags": [
      "white noise",
      "sleep",
      "relaxing"
    ],
    "minDuration": 120
  },
  {
    "query": "pink noise baby",
    "category": "ambient",
    "subcategory": "noise",
    "tags": [
      "pink noise",
      "baby",
      "sleep"
    ],
    "minDuration": 120
  },
  {
    "query": "fan noise ambient",
    "category": "ambient",
    "subcategory": "noise",
    "tags": [
      "fan",
      "noise",
      "sleep"
    ],
    "minDuration": 120
  },
  {
    "query": "womb sounds heartbeat",
    "category": "ambient",
    "subcategory": "heartbeat",
    "tags": [
      "womb",
      "heartbeat",
      "baby"
    ],
    "minDuration": 60
  },
  {
    "query": "heartbeat calm",
    "category": "ambient",
    "subcategory": "heartbeat",
    "tags": [
      "heartbeat",
      "calm",
      "relaxing"
    ],
    "minDuration": 60
  },
  {
    "query": "music box lullaby",
    "category": "music",
    "subcategory": "music_box",
    "tags": [
      "music box",
      "lullaby",
      "gentle"
    ],
    "minDuration": 30
  },
  {
    "query": "wind chimes gentle",
    "category": "music",
    "subcategory": "chimes",
    "tags": [
      "chimes",
      "wind",
      "peaceful"
    ],
    "minDuration": 30
  },
  {
    "query": "bells soft peaceful",
    "category": "music",
    "subcategory": "bells",
    "tags": [
      "bells",
      "soft",
      "peaceful"
    ],
    "minDuration": 30
  },
  {
    "query": "glockenspiel melody",
    "category": "music",
    "subcategory": "music_box",
    "tags": [
      "glockenspiel",
      "melody",
      "gentle"
    ],
    "minDuration": 30
  },
  {
    "query": "humming singing calm",
    "category": "ambient",
    "subcategory": "vocal",
    "tags": [
      "humming",
      "calm",
      "soothing"
    ],
    "minDuration": 30
  },
  {
    "query": "shushing baby",
    "category": "ambient",
    "subcategory": "vocal",
    "tags": [
      "shushing",
      "baby",
      "calming"
    ],
    "minDuration": 30
  }
]

def search_freesound(query: str, min_duration: int = 30) -> list:
    """Search Freesound for CC0 licensed sounds"""
    if not FREESOUND_API_KEY:
        print("ERROR: FREESOUND_API_KEY not set")
        return []

    url = "https://freesound.org/apiv2/search/text/"
    params = {
        'query': query,
        'filter': f'license:"Creative Commons 0" duration:[{min_duration} TO 600]',
        'fields': 'id,name,duration,previews,tags,avg_rating,num_downloads',
        'sort': 'rating_desc',
        'page_size': MAX_TRACKS_PER_QUERY,
        'token': FREESOUND_API_KEY
    }

    response = requests.get(url, params=params)
    if response.status_code != 200:
        print(f"  Error: {response.status_code} - {response.text}")
        return []

    data = response.json()
    return data.get('results', [])

def download_sound(sound_id: int, preview_url: str, output_path: str) -> bool:
    """Download a sound preview (no authentication needed for previews)"""
    try:
        response = requests.get(preview_url, stream=True)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
    except Exception as e:
        print(f"  Download error: {e}")
    return False

def main():
    if not FREESOUND_API_KEY:
        print("=" * 50)
        print("FREESOUND API KEY REQUIRED")
        print("=" * 50)
        print("")
        print("1. Go to: https://freesound.org/apiv2/apply/")
        print("2. Create an account and apply for API key")
        print("3. Set environment variable:")
        print("   export FREESOUND_API_KEY=your_key_here")
        print("")
        return

    print("=" * 50)
    print("Freesound CC0 Audio Downloader")
    print("=" * 50)
    print("")

    all_metadata = []
    total_downloaded = 0

    for search_config in SEARCH_QUERIES:
        query = search_config['query']
        category = search_config['category']
        subcategory = search_config['subcategory']
        tags = search_config['tags']
        min_duration = search_config.get('minDuration', 30)

        print(f"\nSearching: '{query}' (min {min_duration}s)")

        # Create output directory
        category_dir = Path(OUTPUT_DIR) / category
        category_dir.mkdir(parents=True, exist_ok=True)

        results = search_freesound(query, min_duration)
        print(f"  Found {len(results)} sounds")

        for sound in results:
            sound_id = sound['id']
            name = sound['name']
            duration = sound['duration']
            preview_url = sound['previews'].get('preview-hq-mp3', '')

            if not preview_url:
                continue

            filename = f"fs_{sound_id}_{query.replace(' ', '_')[:20]}.mp3"
            output_path = category_dir / filename

            if output_path.exists() and output_path.stat().st_size > 1000:
                print(f"  [SKIP] {name}")
                all_metadata.append({
                    'id': f'fs_{sound_id}',
                    'title': name,
                    'artist': 'Freesound',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'freesound',
                    'license': 'CC0',
                    'filename': filename,
                    'duration': duration,
                    'tags': tags + list(sound.get('tags', []))[:5],
                    'calmScore': 0.85
                })
                continue

            print(f"  [DL] {name} ({duration:.1f}s)")
            if download_sound(sound_id, preview_url, str(output_path)):
                total_downloaded += 1
                all_metadata.append({
                    'id': f'fs_{sound_id}',
                    'title': name,
                    'artist': 'Freesound',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'freesound',
                    'license': 'CC0',
                    'filename': filename,
                    'duration': duration,
                    'tags': tags + list(sound.get('tags', []))[:5],
                    'calmScore': 0.85
                })

            time.sleep(0.5)  # Rate limiting

    # Save metadata
    with open(METADATA_FILE, 'w') as f:
        json.dump(all_metadata, f, indent=2)

    print("")
    print("=" * 50)
    print(f"Downloaded: {total_downloaded} tracks")
    print(f"Metadata saved to: {METADATA_FILE}")
    print("=" * 50)

if __name__ == '__main__':
    main()
