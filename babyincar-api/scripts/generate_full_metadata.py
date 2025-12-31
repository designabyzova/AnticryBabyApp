#!/usr/bin/env python3
"""
Full Metadata Generator for Baby in Car App
Scans all audio files and creates a comprehensive searchable metadata JSON.

Features:
- Scans all MP3/WAV files in the Audio directory
- Extracts duration using mutagen
- Auto-categorizes based on filename and directory
- Creates searchable indexes by category, tag, etc.
- Outputs iOS-compatible JSON
"""

import os
import json
import re
from pathlib import Path
from datetime import datetime
import hashlib

try:
    from mutagen.mp3 import MP3
    from mutagen.wave import WAVE
    HAS_MUTAGEN = True
except ImportError:
    HAS_MUTAGEN = False
    print("Note: mutagen not installed, duration will not be extracted")

BASE_DIR = Path("/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio")
OUTPUT_FILE = BASE_DIR / "all_tracks_metadata.json"
IOS_OUTPUT_FILE = BASE_DIR / "tracks.json"  # Simpler format for iOS

# Category detection patterns
CATEGORY_PATTERNS = {
    'nature': ['rain', 'ocean', 'wave', 'bird', 'forest', 'wind', 'stream', 'river', 'water', 'thunder', 'storm', 'fire', 'campfire', 'crickets', 'night', 'frog', 'waterfall', 'beach', 'sea', 'meadow', 'jungle', 'garden'],
    'whitenoise': ['white_noise', 'pink_noise', 'brown_noise', 'noise', 'fan', 'dryer', 'vacuum', 'heartbeat', 'womb', 'shush', 'hair_dryer', 'washing'],
    'lullabies': ['lullaby', 'twinkle', 'brahms', 'rock_a_bye', 'hush', 'baby', 'sleep', 'music_box', 'kalimba'],
    'classical': ['piano', 'violin', 'cello', 'bach', 'mozart', 'beethoven', 'chopin', 'debussy', 'moonlight', 'nocturne', 'sonata', 'canon', 'gymnopedie', 'clair_de_lune', 'air_on_g', 'harp', 'strings', 'flute', 'orchestra'],
    'ambient': ['ambient', 'pad', 'drone', 'meditation', 'spa', 'relaxing', 'calm', 'peaceful', 'dream', 'ethereal', 'memories', 'tenderness', 'slow_motion'],
    'children': ['cute', 'playful', 'happy', 'sunny', 'little', 'creative', 'small', 'fun'],
    'acoustic': ['guitar', 'ukulele', 'acoustic', 'folk'],
}

SUBCATEGORY_PATTERNS = {
    # Nature subcategories
    'rain': ['rain', 'drizzle', 'shower'],
    'ocean': ['ocean', 'wave', 'sea', 'beach', 'shore', 'coastal'],
    'water': ['stream', 'river', 'brook', 'waterfall', 'fountain', 'water'],
    'birds': ['bird', 'songbird', 'owl', 'seagull', 'chirp'],
    'wind': ['wind', 'breeze', 'gust'],
    'night': ['night', 'cricket', 'frog', 'cicada', 'owl'],
    'fire': ['fire', 'campfire', 'fireplace', 'crackling'],
    'storm': ['thunder', 'storm', 'lightning'],
    'forest': ['forest', 'jungle', 'rainforest', 'woods'],

    # Music subcategories
    'piano': ['piano', 'nocturne', 'sonata'],
    'strings': ['violin', 'cello', 'strings', 'harp'],
    'guitar': ['guitar', 'acoustic'],
    'music_box': ['music_box', 'musicbox', 'kalimba', 'glockenspiel', 'chimes'],

    # Whitenoise subcategories
    'noise': ['white_noise', 'pink_noise', 'brown_noise'],
    'appliance': ['fan', 'dryer', 'vacuum', 'washing', 'hair_dryer', 'ac'],
    'heartbeat': ['heartbeat', 'womb', 'heart'],
}

def get_audio_duration(file_path: Path) -> float:
    """Get audio file duration in seconds"""
    if not HAS_MUTAGEN:
        return 0.0

    try:
        if file_path.suffix.lower() == '.mp3':
            audio = MP3(str(file_path))
            return audio.info.length
        elif file_path.suffix.lower() == '.wav':
            audio = WAVE(str(file_path))
            return audio.info.length
    except Exception:
        pass
    return 0.0

def detect_category(filename: str, parent_dir: str) -> str:
    """Detect category from filename and parent directory"""
    filename_lower = filename.lower()
    parent_lower = parent_dir.lower()

    # First check parent directory
    for category in CATEGORY_PATTERNS:
        if category in parent_lower:
            return category

    # Then check filename patterns
    for category, patterns in CATEGORY_PATTERNS.items():
        for pattern in patterns:
            if pattern in filename_lower:
                return category

    return 'ambient'  # Default category

def detect_subcategory(filename: str, category: str) -> str:
    """Detect subcategory from filename"""
    filename_lower = filename.lower()

    for subcat, patterns in SUBCATEGORY_PATTERNS.items():
        for pattern in patterns:
            if pattern in filename_lower:
                return subcat

    return 'misc'

def extract_tags(filename: str, category: str, subcategory: str) -> list:
    """Extract relevant tags from filename"""
    tags = [category]
    if subcategory != 'misc':
        tags.append(subcategory)

    # Extract words from filename
    words = re.findall(r'[a-z]+', filename.lower())

    # Add relevant words as tags
    tag_words = ['gentle', 'soft', 'calm', 'peaceful', 'relaxing', 'soothing',
                 'morning', 'night', 'summer', 'winter', 'forest', 'ocean',
                 'rain', 'wind', 'birds', 'piano', 'guitar', 'lullaby',
                 'sleep', 'baby', 'ambient', 'loop', 'distant', 'light']

    for word in words:
        if word in tag_words and word not in tags:
            tags.append(word)

    return tags[:8]  # Limit to 8 tags

def calculate_calm_score(category: str, subcategory: str, filename: str) -> float:
    """Calculate a calm score (0-1) for the track"""
    base_scores = {
        'nature': 0.85,
        'whitenoise': 0.80,
        'lullabies': 0.90,
        'classical': 0.85,
        'ambient': 0.88,
        'children': 0.70,
        'acoustic': 0.75,
    }

    score = base_scores.get(category, 0.75)

    # Adjust based on subcategory
    calming_subcats = ['rain', 'ocean', 'heartbeat', 'piano', 'music_box']
    if subcategory in calming_subcats:
        score += 0.05

    # Adjust based on filename keywords
    calming_words = ['gentle', 'soft', 'calm', 'peaceful', 'sleep', 'slow']
    for word in calming_words:
        if word in filename.lower():
            score += 0.02

    return min(score, 1.0)

def clean_title(filename: str) -> str:
    """Clean filename to create a nice title"""
    # Remove extension
    name = filename.rsplit('.', 1)[0]

    # Remove common prefixes
    prefixes = ['fs_', 'ia_', 'pb_', 'mk_', 'vt_', 'ne_', 'bensound_', 'sb_']
    for prefix in prefixes:
        if name.lower().startswith(prefix):
            name = name[len(prefix):]

    # Remove hash suffixes (8 char hex at end after underscore)
    name = re.sub(r'_[a-f0-9]{8}$', '', name)

    # Replace underscores with spaces and title case
    name = name.replace('_', ' ')
    name = ' '.join(word.capitalize() for word in name.split())

    return name[:50]  # Limit length

def extract_artist(filename: str, parent_dir: str) -> str:
    """Extract artist from filename"""
    filename_lower = filename.lower()

    if 'bensound' in filename_lower:
        return 'Bensound'
    elif 'fs_' in filename_lower:
        return 'Freesound'
    elif 'ia_' in filename_lower:
        return 'Internet Archive'
    elif 'pb_' in filename_lower:
        return 'Pixabay'
    elif 'mk_' in filename_lower:
        return 'Mixkit'
    elif 'sb_' in filename_lower:
        return 'SoundBible'
    elif 'librivox' in filename_lower:
        return 'LibriVox'
    elif 'bedtime_fm' in filename_lower:
        return 'Bedtime FM'

    return 'Various Artists'

def main():
    print("=" * 60)
    print("FULL METADATA GENERATOR")
    print("=" * 60)
    print()

    all_tracks = []
    categories_count = {}

    # Scan all audio files
    audio_extensions = {'.mp3', '.wav', '.m4a', '.ogg', '.flac'}

    for audio_file in BASE_DIR.rglob('*'):
        if audio_file.suffix.lower() not in audio_extensions:
            continue

        if audio_file.is_file():
            relative_path = audio_file.relative_to(BASE_DIR)
            parent_dir = str(relative_path.parent)
            filename = audio_file.name

            # Skip podcasts for now (they're handled separately)
            if 'podcasts' in parent_dir.lower():
                continue

            # Detect metadata
            category = detect_category(filename, parent_dir)
            subcategory = detect_subcategory(filename, category)
            tags = extract_tags(filename, category, subcategory)
            calm_score = calculate_calm_score(category, subcategory, filename)
            title = clean_title(filename)
            artist = extract_artist(filename, parent_dir)
            duration = get_audio_duration(audio_file)

            # Generate ID
            file_hash = hashlib.md5(str(relative_path).encode()).hexdigest()[:12]
            track_id = f"{category[:3]}_{file_hash}"

            track = {
                'id': track_id,
                'title': title,
                'artist': artist,
                'category': category,
                'subcategory': subcategory,
                'filename': str(relative_path),
                'duration': round(duration, 1),
                'tags': tags,
                'calmScore': round(calm_score, 2),
                'fileSize': audio_file.stat().st_size,
            }

            all_tracks.append(track)

            # Count categories
            if category not in categories_count:
                categories_count[category] = {'count': 0, 'subcategories': {}}
            categories_count[category]['count'] += 1
            if subcategory not in categories_count[category]['subcategories']:
                categories_count[category]['subcategories'][subcategory] = 0
            categories_count[category]['subcategories'][subcategory] += 1

    # Sort tracks by category, then calm score
    all_tracks.sort(key=lambda x: (x['category'], -x['calmScore'], x['title']))

    # Build search indexes
    search_index = {
        'by_category': {},
        'by_subcategory': {},
        'by_tag': {},
    }

    for track in all_tracks:
        cat = track['category']
        subcat = track['subcategory']
        track_id = track['id']

        if cat not in search_index['by_category']:
            search_index['by_category'][cat] = []
        search_index['by_category'][cat].append(track_id)

        subcat_key = f"{cat}/{subcat}"
        if subcat_key not in search_index['by_subcategory']:
            search_index['by_subcategory'][subcat_key] = []
        search_index['by_subcategory'][subcat_key].append(track_id)

        for tag in track['tags']:
            if tag not in search_index['by_tag']:
                search_index['by_tag'][tag] = []
            search_index['by_tag'][tag].append(track_id)

    # Full metadata with indexes
    full_metadata = {
        'version': '2.0',
        'generated': datetime.now().isoformat(),
        'total_tracks': len(all_tracks),
        'categories': categories_count,
        'search_index': search_index,
        'tracks': all_tracks,
    }

    # Save full metadata
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(full_metadata, f, indent=2, ensure_ascii=False)

    # Save iOS-compatible simple format
    ios_tracks = []
    for track in all_tracks:
        ios_tracks.append({
            'id': track['id'],
            'title': track['title'],
            'artist': track['artist'],
            'category': track['category'],
            'subcategory': track['subcategory'],
            'filename': track['filename'],
            'duration': track['duration'],
            'tags': track['tags'],
            'calmScore': track['calmScore'],
        })

    ios_metadata = {
        'version': '2.0',
        'generated': datetime.now().isoformat(),
        'total': len(ios_tracks),
        'categories': list(categories_count.keys()),
        'tracks': ios_tracks,
    }

    with open(IOS_OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(ios_metadata, f, indent=2, ensure_ascii=False)

    # Print summary
    print(f"Total tracks: {len(all_tracks)}")
    print()
    print("Categories:")
    for cat, info in sorted(categories_count.items()):
        print(f"  {cat}: {info['count']} tracks")
        for subcat, count in sorted(info['subcategories'].items()):
            print(f"    └── {subcat}: {count}")

    print()
    print(f"Full metadata: {OUTPUT_FILE}")
    print(f"iOS metadata: {IOS_OUTPUT_FILE}")
    print()

    # Show top tags
    tag_counts = {}
    for track in all_tracks:
        for tag in track['tags']:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1

    print("Top 20 tags:")
    for tag, count in sorted(tag_counts.items(), key=lambda x: -x[1])[:20]:
        print(f"  {tag}: {count}")

if __name__ == '__main__':
    main()
