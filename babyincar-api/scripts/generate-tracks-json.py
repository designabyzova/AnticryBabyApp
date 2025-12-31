#!/usr/bin/env python3
"""
Generate tracks.json metadata file from all audio files
This file will be read by ContentLibraryService to load bundled tracks
"""

import os
import json
import uuid
import hashlib
from pathlib import Path

AUDIO_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
OUTPUT_FILE = os.path.join(AUDIO_DIR, "tracks.json")

# Category mappings
CATEGORY_MAP = {
    'ambient': 'ambient',
    'classical': 'classical',
    'lullabies': 'lullabies',
    'nature': 'nature',
    'whitenoise': 'whitenoise',
    'children': 'children',
    'fairytales': 'fairytales',
    'podcasts': 'podcasts',
    'meditation': 'meditation',
}

# Calm score by category/type
CALM_SCORES = {
    'whitenoise': 0.95,
    'nature': 0.90,
    'ambient': 0.88,
    'classical': 0.85,
    'lullabies': 0.92,
    'meditation': 0.93,
    'children': 0.75,
    'fairytales': 0.70,
    'podcasts': 0.65,
}

# Sub-category calm scores
SUBCATEGORY_CALM = {
    'rain': 0.94,
    'ocean': 0.92,
    'heartbeat': 0.96,
    'womb': 0.97,
    'pink_noise': 0.94,
    'brown_noise': 0.93,
    'white_noise': 0.95,
    'lullaby': 0.93,
    'musicbox': 0.90,
    'piano': 0.88,
    'harp': 0.87,
    'strings': 0.86,
    'bells': 0.85,
    'choir': 0.82,
    'drone': 0.80,
    'birds': 0.78,
    'stream': 0.89,
    'fireplace': 0.85,
    'thunder': 0.75,
    'wind': 0.82,
}

def generate_id(filepath):
    """Generate a deterministic UUID from filepath"""
    hash_input = filepath.encode('utf-8')
    hash_digest = hashlib.md5(hash_input).hexdigest()
    return str(uuid.UUID(hash_digest[:32]))

def get_title_from_filename(filename):
    """Convert filename to readable title"""
    # Remove extension
    name = os.path.splitext(filename)[0]

    # Remove common prefixes
    prefixes_to_remove = ['ia_', 'sb_', 'bensound_', 'dl_']
    for prefix in prefixes_to_remove:
        if name.startswith(prefix):
            name = name[len(prefix):]

    # Remove numeric suffixes like _001, _01
    parts = name.rsplit('_', 1)
    if len(parts) == 2 and parts[1].isdigit():
        name = parts[0]

    # Replace underscores with spaces and title case
    name = name.replace('_', ' ').replace('-', ' ')

    # Title case
    name = ' '.join(word.capitalize() for word in name.split())

    return name

def get_artist(category, filename):
    """Determine artist based on category and filename"""
    if 'bensound' in filename.lower():
        return 'Bensound'
    elif 'ia_' in filename.lower():
        return 'Internet Archive'
    elif 'sb_' in filename.lower():
        return 'SoundBible'
    elif category == 'nature':
        return 'Nature Sounds'
    elif category == 'whitenoise':
        return 'White Noise Collection'
    elif category == 'lullabies':
        return 'Lullaby Collection'
    elif category == 'classical':
        return 'Classical Collection'
    elif category == 'ambient':
        return 'Ambient Music'
    elif category == 'children':
        return "Children's Music"
    elif category == 'fairytales':
        return 'Story Time'
    elif category == 'podcasts':
        return 'Baby Sleep Podcast'
    else:
        return 'Baby in Car'

def get_calm_score(category, filename):
    """Calculate calming score based on category and filename"""
    base_score = CALM_SCORES.get(category, 0.80)

    # Adjust based on subcategory/filename patterns
    filename_lower = filename.lower()
    for pattern, score in SUBCATEGORY_CALM.items():
        if pattern in filename_lower:
            return (base_score + score) / 2  # Average with base

    return base_score

def get_duration_estimate(filepath, extension):
    """Estimate duration based on file size (rough estimate)"""
    try:
        size_bytes = os.path.getsize(filepath)

        if extension in ['mp3']:
            # ~128kbps = 16KB/s -> duration = size / 16000
            return size_bytes / 16000
        elif extension in ['wav']:
            # 44100 Hz * 2 channels * 2 bytes = 176400 bytes/s
            return size_bytes / 176400
        elif extension in ['ogg']:
            # ~128kbps
            return size_bytes / 16000
        else:
            return 180  # Default 3 minutes
    except:
        return 180

def get_tags(category, filename):
    """Generate tags based on category and filename"""
    tags = [category]

    filename_lower = filename.lower()
    tag_patterns = [
        'rain', 'ocean', 'wind', 'birds', 'crickets', 'thunder', 'stream',
        'heartbeat', 'womb', 'shushing', 'vacuum', 'dryer', 'fan',
        'piano', 'guitar', 'harp', 'violin', 'strings', 'bells', 'chimes',
        'lullaby', 'musicbox', 'melody',
        'white', 'pink', 'brown', 'noise',
        'sleep', 'calm', 'relax', 'soothing', 'gentle', 'soft',
        'baby', 'child', 'toddler', 'infant',
        'classical', 'ambient', 'nature',
    ]

    for pattern in tag_patterns:
        if pattern in filename_lower:
            tags.append(pattern)

    return list(set(tags))

def scan_audio_directory():
    """Scan audio directory and generate track metadata"""
    tracks = []

    for root, dirs, files in os.walk(AUDIO_DIR):
        # Get relative path from AUDIO_DIR
        rel_root = os.path.relpath(root, AUDIO_DIR)

        # Determine category from first directory level
        if rel_root == '.':
            continue

        category_dir = rel_root.split(os.sep)[0]
        category = CATEGORY_MAP.get(category_dir, 'misc')

        # Get subcategory if nested
        subcategory = 'general'
        path_parts = rel_root.split(os.sep)
        if len(path_parts) > 1:
            subcategory = path_parts[-1]

        for filename in files:
            # Skip non-audio files
            ext = os.path.splitext(filename)[1].lower()
            if ext not in ['.mp3', '.wav', '.ogg', '.m4a', '.aac']:
                continue

            filepath = os.path.join(root, filename)
            rel_filepath = os.path.relpath(filepath, AUDIO_DIR)

            # Check file size
            try:
                if os.path.getsize(filepath) < 1000:  # Skip files < 1KB
                    continue
            except:
                continue

            track = {
                'id': generate_id(rel_filepath),
                'title': get_title_from_filename(filename),
                'artist': get_artist(category, filename),
                'category': category,
                'subcategory': subcategory,
                'filename': rel_filepath,
                'duration': get_duration_estimate(filepath, ext[1:]),
                'calmScore': get_calm_score(category, filename),
                'tags': get_tags(category, filename),
                'ageRangeMin': 0,
                'ageRangeMax': 36,
                'isPremium': False
            }

            tracks.append(track)

    return tracks

def main():
    print("=" * 60)
    print("GENERATING TRACKS.JSON METADATA")
    print("=" * 60)
    print(f"\nScanning: {AUDIO_DIR}")

    tracks = scan_audio_directory()

    print(f"\nFound {len(tracks)} audio tracks")

    # Count by category
    categories = {}
    for track in tracks:
        cat = track['category']
        categories[cat] = categories.get(cat, 0) + 1

    print("\nBy category:")
    for cat, count in sorted(categories.items()):
        print(f"  {cat}: {count}")

    # Create output
    output = {
        'version': '1.0',
        'generatedAt': '2024-12-30',
        'totalTracks': len(tracks),
        'tracks': tracks
    }

    # Write JSON
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nSaved to: {OUTPUT_FILE}")
    print(f"File size: {os.path.getsize(OUTPUT_FILE) / 1024:.1f} KB")
    print("=" * 60)

if __name__ == "__main__":
    main()
