#!/usr/bin/env python3
"""
Regenerate tracks.json with actual bundled MP3 files.
Fixes audio playback errors caused by referencing non-existent WAV files.
"""

import json
import os
from pathlib import Path
import hashlib
from datetime import date

# Configuration
AUDIO_DIR = Path("BabyInCarApp/BabyInCarApp/Resources/Audio")
OUTPUT_FILE = AUDIO_DIR / "tracks.json"

# Category mapping
CATEGORY_MAP = {
    "lullabies": {
        "category": "Instrumental",
        "subcategory": "lullabies",
        "artist": "Lullaby Collection",
        "calm_score": 0.90
    },
    "classical": {
        "category": "Classical Music",
        "subcategory": "classical",
        "artist": "Classical Collection",
        "calm_score": 0.88
    },
    "nature": {
        "category": "Nature Sounds",
        "subcategory": "nature",
        "artist": "Nature Collection",
        "calm_score": 0.85
    },
    "fairytales_en": {
        "category": "Fairy Tales",
        "subcategory": "english",
        "artist": "Grimm Brothers",
        "calm_score": 0.75
    },
    "fairytales_ru": {
        "category": "Fairy Tales",
        "subcategory": "russian",
        "artist": "Russian Tales",
        "calm_score": 0.75
    },
    "children": {
        "category": "Children's Songs",
        "subcategory": "children",
        "artist": "Children's Collection",
        "calm_score": 0.80
    },
    "ambient": {
        "category": "Instrumental",
        "subcategory": "ambient",
        "artist": "Bensound",
        "calm_score": 0.82
    },
    "acoustic": {
        "category": "Instrumental",
        "subcategory": "acoustic",
        "artist": "Acoustic Collection",
        "calm_score": 0.83
    }
}

def generate_uuid(text):
    """Generate consistent UUID from text using MD5 hash"""
    hash_val = hashlib.md5(text.encode()).hexdigest()
    return f"{hash_val[0:8]}-{hash_val[8:12]}-{hash_val[12:16]}-{hash_val[16:20]}-{hash_val[20:32]}"

def clean_title(filename):
    """Convert filename to readable title"""
    # Remove common prefixes
    title = filename
    for prefix in ['ia_', 'pb_', 'vt_', 'ne_', 'en_', 'ru_', 'sb_', 'bensound_']:
        title = title.replace(prefix, '')

    # Replace underscores with spaces and title case
    title = title.replace('_', ' ').title()
    return title

def get_category_info(relpath):
    """Determine category info from file path"""
    parts = relpath.split('/')

    if len(parts) >= 2 and parts[0] == 'fairytales':
        key = f"fairytales_{parts[1]}"
        return CATEGORY_MAP.get(key, CATEGORY_MAP.get(parts[0], CATEGORY_MAP["ambient"]))

    return CATEGORY_MAP.get(parts[0], CATEGORY_MAP["ambient"])

def main():
    print(f"Regenerating tracks.json from actual MP3 files in {AUDIO_DIR}...")

    if not AUDIO_DIR.exists():
        print(f"❌ Error: {AUDIO_DIR} does not exist!")
        return

    tracks = []

    # Find all MP3 files
    mp3_files = sorted(AUDIO_DIR.rglob("*.mp3"))

    for filepath in mp3_files:
        # Skip tracks.json itself if it exists
        if filepath.name == "tracks.json":
            continue

        # Get relative path from Audio directory
        relpath = filepath.relative_to(AUDIO_DIR)
        relpath_str = str(relpath).replace('\\', '/')  # Normalize path separators

        # Get category info
        cat_info = get_category_info(relpath_str)

        # Clean up title
        filename_stem = filepath.stem
        title = clean_title(filename_stem)

        # Generate consistent UUID
        track_id = generate_uuid(relpath_str)

        # Create track entry
        track = {
            "id": track_id,
            "title": title,
            "artist": cat_info["artist"],
            "category": cat_info["subcategory"],
            "subcategory": cat_info["subcategory"],
            "filename": relpath_str,
            "duration": 180.0,  # Default duration - will be detected by app
            "calmScore": cat_info["calm_score"],
            "tags": [relpath_str.split('/')[0]],
            "ageRangeMin": 0,
            "ageRangeMax": 36,
            "isPremium": False
        }

        tracks.append(track)

    # Create final JSON structure
    output_data = {
        "version": "2.0",
        "generatedAt": date.today().isoformat(),
        "description": "Regenerated to match actual bundled MP3 files",
        "totalTracks": len(tracks),
        "tracks": tracks
    }

    # Write to file
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"✅ Generated {len(tracks)} tracks in {OUTPUT_FILE}")
    print(f"🎵 All tracks now reference actual MP3 files")

    # Show sample tracks
    if tracks:
        print("\n📋 Sample tracks:")
        for track in tracks[:5]:
            print(f"  • {track['title']} ({track['filename']})")

if __name__ == "__main__":
    main()
