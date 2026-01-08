#!/usr/bin/env python3
"""
Archive.org Audio Downloader - NO API KEY NEEDED
Downloads baby-friendly public domain music from Internet Archive
"""

import os
import sys
import json
import requests
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent.parent / "audio-library" / "archive-org"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def search_archive(query, limit=20):
    """Search Archive.org using their free public API"""
    url = "https://archive.org/advancedsearch.php"

    params = {
        'q': f'{query} AND mediatype:audio AND format:VBR MP3',
        'fl': 'identifier,title,creator,downloads',
        'sort': 'downloads desc',
        'rows': limit,
        'output': 'json'
    }

    print(f"🔍 Searching Archive.org: {query}")

    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()

        tracks = []
        for doc in data.get('response', {}).get('docs', []):
            identifier = doc.get('identifier')
            title = doc.get('title', 'Unknown')
            creator = doc.get('creator', 'Unknown')

            # Get download URL
            download_url = f"https://archive.org/download/{identifier}/{identifier}.mp3"

            tracks.append({
                'url': download_url,
                'title': title,
                'artist': creator,
                'identifier': identifier
            })

        print(f"   Found {len(tracks)} tracks")
        return tracks

    except Exception as e:
        print(f"❌ Search failed: {e}")
        return []

def download_track(track, output_path):
    """Download a single track"""
    url = track['url']
    title = track['title']

    # Skip if exists
    if output_path.exists() and output_path.stat().st_size > 100000:
        print(f"[SKIP] {title} (already exists)")
        return True

    print(f"[DOWNLOADING] {title}")

    try:
        response = requests.get(url, timeout=120, stream=True)
        response.raise_for_status()

        # Download
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        # Verify size
        if output_path.stat().st_size < 100000:
            output_path.unlink()
            print(f"[FAIL] {title} (file too small)")
            return False

        size_mb = output_path.stat().st_size / (1024 * 1024)
        print(f"[OK] {title} ({size_mb:.1f}MB)")
        return True

    except Exception as e:
        print(f"[FAIL] {title} - {e}")
        if output_path.exists():
            output_path.unlink()
        return False

def main():
    print("=" * 70)
    print("📚 ARCHIVE.ORG BABY MUSIC DOWNLOADER")
    print("=" * 70)
    print()

    # Search queries optimized for baby music
    queries = [
        'baby lullaby classical',
        'brahms lullaby',
        'mozart baby',
        'classical piano sleep',
        'gentle piano lullaby'
    ]

    all_tracks = []

    for query in queries:
        tracks = search_archive(query, limit=5)
        all_tracks.extend(tracks)

    print()
    print(f"📊 Total tracks found: {len(all_tracks)}")
    print()
    print("🔽 Starting downloads...")
    print()

    success = 0
    failed = 0

    for i, track in enumerate(all_tracks, 1):
        safe_filename = f"{track['identifier']}.mp3"
        output_path = OUTPUT_DIR / safe_filename

        if download_track(track, output_path):
            success += 1

            # Save metadata
            metadata_path = output_path.with_suffix('.json')
            with open(metadata_path, 'w') as f:
                json.dump(track, f, indent=2)
        else:
            failed += 1

    print()
    print("=" * 70)
    print("📊 DOWNLOAD COMPLETE")
    print("=" * 70)
    print(f"✅ Success: {success}")
    print(f"❌ Failed: {failed}")
    print(f"📁 Output: {OUTPUT_DIR}")
    print("=" * 70)

if __name__ == "__main__":
    main()
