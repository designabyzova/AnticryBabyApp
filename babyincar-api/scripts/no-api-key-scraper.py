#!/usr/bin/env python3
"""
No-API-Key Audio Scraper for Baby in Car App
Downloads royalty-free/CC0 audio from sources that don't require API keys.

Sources:
- Internet Archive (public domain)
- Incompetech/Kevin MacLeod (royalty-free with attribution)
- CC Mixter (Creative Commons)

Usage: python no-api-key-scraper.py
"""

import os
import json
import time
import hashlib
import requests
from pathlib import Path
from urllib.parse import quote, urljoin
from datetime import datetime

# Configuration
OUTPUT_DIR = Path('/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio')
METADATA_FILE = OUTPUT_DIR / 'scraped_tracks.json'
MAX_PER_CATEGORY = 10

# Headers to avoid blocks
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/html, */*',
}

def generate_id(text: str) -> str:
    """Generate consistent ID from text"""
    return hashlib.md5(text.encode()).hexdigest()[:16]

def download_file(url: str, output_path: Path) -> bool:
    """Download a file with proper error handling"""
    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=60)
        if response.status_code == 200:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            # Verify file size
            if output_path.stat().st_size > 1000:
                return True
            else:
                output_path.unlink()
        return False
    except Exception as e:
        print(f"    Download error: {e}")
        return False

def search_internet_archive(query: str, category: str, max_results: int = 5) -> list:
    """
    Search Internet Archive for public domain audio.
    No API key required!
    """
    results = []

    # Search API
    search_url = "https://archive.org/advancedsearch.php"
    params = {
        'q': f'{query} AND mediatype:audio AND licenseurl:*publicdomain*',
        'fl[]': ['identifier', 'title', 'creator', 'description'],
        'rows': max_results,
        'output': 'json',
    }

    try:
        response = requests.get(search_url, params=params, headers=HEADERS, timeout=30)
        if response.status_code != 200:
            print(f"    IA search failed: {response.status_code}")
            return results

        data = response.json()
        docs = data.get('response', {}).get('docs', [])

        for item in docs:
            identifier = item.get('identifier', '')
            if not identifier:
                continue

            # Get files for this item
            files_url = f"https://archive.org/metadata/{identifier}/files"
            files_resp = requests.get(files_url, headers=HEADERS, timeout=30)

            if files_resp.status_code != 200:
                continue

            files_data = files_resp.json()
            audio_files = [
                f for f in files_data.get('result', [])
                if f.get('format') in ['VBR MP3', 'MP3', 'Ogg Vorbis', '128Kbps MP3']
            ]

            for file in audio_files[:2]:  # Max 2 files per item
                duration = float(file.get('length', 180) or 180)
                if duration < 30 or duration > 600:
                    continue

                filename = file.get('name', '')
                download_url = f"https://archive.org/download/{identifier}/{quote(filename)}"

                results.append({
                    'source': 'internet_archive',
                    'source_id': f"{identifier}_{filename}",
                    'title': file.get('title') or filename.replace('.mp3', '').replace('_', ' ').title(),
                    'artist': item.get('creator', 'Internet Archive'),
                    'category': category,
                    'download_url': download_url,
                    'duration': int(duration),
                    'license': 'Public Domain',
                    'tags': ['archive', 'public domain', category],
                })

            time.sleep(0.3)  # Rate limiting

    except Exception as e:
        print(f"    IA error: {e}")

    return results

def search_ccmixter(query: str, category: str, max_results: int = 5) -> list:
    """
    Search CCMixter for Creative Commons music.
    No API key required!
    """
    results = []

    # CCMixter has a simple API
    search_url = "http://ccmixter.org/api/query"
    params = {
        'tags': query.replace(' ', '+'),
        'f': 'json',
        'limit': max_results,
        'lic': 'open',  # Open licenses only
    }

    try:
        response = requests.get(search_url, params=params, headers=HEADERS, timeout=30)
        if response.status_code != 200:
            return results

        data = response.json()

        for item in data:
            download_url = item.get('files', [{}])[0].get('download_url', '')
            if not download_url or not download_url.endswith('.mp3'):
                continue

            results.append({
                'source': 'ccmixter',
                'source_id': str(item.get('upload_id', '')),
                'title': item.get('upload_name', 'Unknown'),
                'artist': item.get('user_name', 'CCMixter Artist'),
                'category': category,
                'download_url': download_url,
                'duration': 180,  # Default, will be detected by app
                'license': item.get('license_name', 'CC'),
                'tags': ['ccmixter', 'creative commons', category],
            })

    except Exception as e:
        print(f"    CCMixter error: {e}")

    return results

def get_incompetech_tracks(category: str) -> list:
    """
    Get royalty-free music from Kevin MacLeod's Incompetech.
    These are well-known royalty-free tracks used in many videos.
    Direct download links - no API needed!
    """
    # Curated list of calming tracks from Incompetech
    INCOMPETECH_TRACKS = {
        'classical': [
            {'title': 'Gymnopedie No 1', 'file': 'Gymnopedie_No_1.mp3', 'duration': 180},
            {'title': 'Moonlight Sonata', 'file': 'Moonlight_Sonata_by_Beethoven.mp3', 'duration': 360},
            {'title': 'Canon in D Major', 'file': 'Canon_in_D_Major.mp3', 'duration': 270},
            {'title': 'Air on G String', 'file': 'Air_on_the_G_String.mp3', 'duration': 320},
            {'title': 'Clair de Lune', 'file': 'Clair_de_Lune.mp3', 'duration': 300},
        ],
        'ambient': [
            {'title': 'Dewdrop Fantasy', 'file': 'Dewdrop_Fantasy.mp3', 'duration': 192},
            {'title': 'Floating Cities', 'file': 'Floating_Cities.mp3', 'duration': 218},
            {'title': 'Peaceful Desolation', 'file': 'Peaceful_Desolation.mp3', 'duration': 153},
            {'title': 'Tranquility', 'file': 'Tranquility.mp3', 'duration': 245},
            {'title': 'Evening Meditation', 'file': 'Evening_Meditation.mp3', 'duration': 186},
        ],
        'lullabies': [
            {'title': 'Dreamy Flashback', 'file': 'Dreamy_Flashback.mp3', 'duration': 142},
            {'title': 'Sovereign', 'file': 'Sovereign.mp3', 'duration': 214},
            {'title': 'Sleeping Lullaby', 'file': 'Sleeping_Lullaby.mp3', 'duration': 180},
        ],
    }

    results = []
    tracks = INCOMPETECH_TRACKS.get(category, [])

    for track in tracks:
        results.append({
            'source': 'incompetech',
            'source_id': f"km_{track['file']}",
            'title': track['title'],
            'artist': 'Kevin MacLeod',
            'category': category,
            'download_url': f"https://incompetech.com/music/royalty-free/mp3-royaltyfree/{track['file']}",
            'duration': track['duration'],
            'license': 'Royalty Free (Attribution)',
            'tags': ['incompetech', 'kevin macleod', 'royalty free', category],
        })

    return results

def get_chosic_tracks() -> list:
    """
    Get royalty-free music from Chosic (curated free music).
    These are specifically for baby/calm content.
    """
    # Curated calm/baby tracks with direct download links
    CHOSIC_CALM_TRACKS = [
        {
            'title': 'Tender Love',
            'artist': 'Chosic',
            'url': 'https://www.chosic.com/wp-content/uploads/2021/05/Tender-Love.mp3',
            'category': 'lullabies',
            'duration': 180,
        },
        {
            'title': 'Peaceful Garden',
            'artist': 'Chosic',
            'url': 'https://www.chosic.com/wp-content/uploads/2021/04/Peaceful-Garden.mp3',
            'category': 'ambient',
            'duration': 195,
        },
    ]

    results = []
    for track in CHOSIC_CALM_TRACKS:
        results.append({
            'source': 'chosic',
            'source_id': f"ch_{generate_id(track['title'])}",
            'title': track['title'],
            'artist': track['artist'],
            'category': track['category'],
            'download_url': track['url'],
            'duration': track['duration'],
            'license': 'Royalty Free',
            'tags': ['chosic', 'royalty free', track['category']],
        })

    return results

# Search queries for different categories
SEARCH_QUERIES = {
    'nature': [
        'rain ambient',
        'ocean waves',
        'forest birds',
        'river stream',
        'wind gentle',
    ],
    'classical': [
        'classical piano calm',
        'lullaby orchestra',
        'baroque peaceful',
    ],
    'ambient': [
        'ambient meditation',
        'peaceful drone',
        'calm atmosphere',
    ],
    'lullabies': [
        'lullaby music box',
        'baby sleep music',
        'gentle melody',
    ],
}

def main():
    print("=" * 60)
    print("No-API-Key Audio Scraper for Baby in Car")
    print("=" * 60)
    print()

    all_tracks = []
    downloaded = 0
    skipped = 0

    # 1. Get Incompetech tracks (direct links, no scraping needed)
    print("\n[1] Getting Kevin MacLeod (Incompetech) tracks...")
    for category in ['classical', 'ambient', 'lullabies']:
        tracks = get_incompetech_tracks(category)
        print(f"    {category}: {len(tracks)} tracks available")

        category_dir = OUTPUT_DIR / category
        category_dir.mkdir(parents=True, exist_ok=True)

        for track in tracks:
            filename = f"km_{track['source_id'].replace('km_', '')}"
            output_path = category_dir / filename

            if output_path.exists() and output_path.stat().st_size > 1000:
                print(f"    [SKIP] {track['title']}")
                skipped += 1
            else:
                print(f"    [DL] {track['title']}...")
                if download_file(track['download_url'], output_path):
                    downloaded += 1
                    track['filename'] = f"{category}/{filename}"
                    all_tracks.append(track)
                time.sleep(0.5)

    # 2. Search Internet Archive
    print("\n[2] Searching Internet Archive (Public Domain)...")
    for category, queries in SEARCH_QUERIES.items():
        category_dir = OUTPUT_DIR / category
        category_dir.mkdir(parents=True, exist_ok=True)

        for query in queries[:2]:  # Limit queries
            print(f"    Searching: '{query}'")
            tracks = search_internet_archive(query, category, max_results=3)

            for track in tracks:
                safe_name = track['source_id'].replace('/', '_').replace(' ', '_')[:50]
                filename = f"ia_{safe_name}.mp3"
                output_path = category_dir / filename

                if output_path.exists() and output_path.stat().st_size > 1000:
                    print(f"      [SKIP] {track['title']}")
                    skipped += 1
                else:
                    print(f"      [DL] {track['title'][:40]}...")
                    if download_file(track['download_url'], output_path):
                        downloaded += 1
                        track['filename'] = f"{category}/{filename}"
                        all_tracks.append(track)
                    time.sleep(0.5)

    # 3. Search CCMixter
    print("\n[3] Searching CCMixter (Creative Commons)...")
    for category, queries in SEARCH_QUERIES.items():
        category_dir = OUTPUT_DIR / category

        for query in queries[:1]:  # Limit queries
            print(f"    Searching: '{query}'")
            tracks = search_ccmixter(query, category, max_results=3)

            for track in tracks:
                filename = f"ccm_{track['source_id']}.mp3"
                output_path = category_dir / filename

                if output_path.exists() and output_path.stat().st_size > 1000:
                    print(f"      [SKIP] {track['title']}")
                    skipped += 1
                else:
                    print(f"      [DL] {track['title'][:40]}...")
                    if download_file(track['download_url'], output_path):
                        downloaded += 1
                        track['filename'] = f"{category}/{filename}"
                        all_tracks.append(track)
                    time.sleep(0.5)

    # Save metadata
    if all_tracks:
        # Load existing if present
        existing = []
        if METADATA_FILE.exists():
            with open(METADATA_FILE) as f:
                existing = json.load(f)

        # Merge (avoid duplicates)
        existing_ids = {t.get('source_id') for t in existing}
        new_tracks = [t for t in all_tracks if t.get('source_id') not in existing_ids]

        combined = existing + new_tracks

        with open(METADATA_FILE, 'w') as f:
            json.dump(combined, f, indent=2)

        print(f"\n    Metadata saved: {len(new_tracks)} new tracks added")

    print()
    print("=" * 60)
    print(f"Downloaded: {downloaded} tracks")
    print(f"Skipped (already exist): {skipped}")
    print(f"Total in library: {len(all_tracks)}")
    print("=" * 60)

    return downloaded

if __name__ == '__main__':
    main()
