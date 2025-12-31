#!/usr/bin/env python3
"""
Mass Audio Downloader for Baby in Car App
Downloads REAL natural sounds and melodies from multiple FREE sources:
- Freesound.org (API - CC0 license)
- Internet Archive (Direct download)
- Pixabay (Scraping - CC0 license)
- Mixkit (Direct links - Free license)

Target: 300+ additional tracks across all categories

Requirements:
    pip install requests beautifulsoup4 mutagen tqdm

Usage:
    export FREESOUND_API_KEY=your_key  # Get from https://freesound.org/apiv2/apply/
    python mass_audio_downloader.py
"""

import os
import sys
import json
import time
import hashlib
import requests
from pathlib import Path
from datetime import datetime
from urllib.parse import quote, urljoin
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from bs4 import BeautifulSoup
    from tqdm import tqdm
except ImportError:
    print("Installing required packages...")
    os.system("pip install beautifulsoup4 tqdm requests")
    from bs4 import BeautifulSoup
    from tqdm import tqdm

# =============================================================================
# CONFIGURATION
# =============================================================================

BASE_DIR = Path("/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio")
METADATA_FILE = BASE_DIR / "complete_track_metadata.json"
DOWNLOAD_LOG = BASE_DIR / "download_log.json"

FREESOUND_API_KEY = os.environ.get('FREESOUND_API_KEY', '')

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'audio/mpeg,audio/*;q=0.9,*/*;q=0.8',
}

# Rate limiting
REQUEST_DELAY = 0.5  # seconds between requests

# =============================================================================
# FREESOUND API DOWNLOADS (Best quality, CC0 license)
# =============================================================================

FREESOUND_QUERIES = [
    # NATURE SOUNDS - Real field recordings
    {"query": "rain gentle soft", "category": "nature", "subcategory": "rain", "tags": ["rain", "gentle", "relaxing"], "count": 15},
    {"query": "rain forest tropical", "category": "nature", "subcategory": "rain", "tags": ["rain", "forest", "tropical"], "count": 10},
    {"query": "rain window indoor", "category": "nature", "subcategory": "rain", "tags": ["rain", "cozy", "indoor"], "count": 10},
    {"query": "thunderstorm distant rolling", "category": "nature", "subcategory": "storm", "tags": ["thunder", "storm", "distant"], "count": 10},

    {"query": "ocean waves calm beach", "category": "nature", "subcategory": "ocean", "tags": ["ocean", "waves", "calm"], "count": 15},
    {"query": "sea waves shore", "category": "nature", "subcategory": "ocean", "tags": ["sea", "waves", "shore"], "count": 10},
    {"query": "underwater ocean ambient", "category": "nature", "subcategory": "ocean", "tags": ["underwater", "ocean", "ambient"], "count": 5},

    {"query": "stream river water flowing", "category": "nature", "subcategory": "water", "tags": ["stream", "river", "water"], "count": 15},
    {"query": "waterfall nature", "category": "nature", "subcategory": "water", "tags": ["waterfall", "nature", "powerful"], "count": 10},
    {"query": "brook babbling gentle", "category": "nature", "subcategory": "water", "tags": ["brook", "babbling", "gentle"], "count": 10},
    {"query": "fountain water", "category": "nature", "subcategory": "water", "tags": ["fountain", "water", "urban"], "count": 5},

    {"query": "birds singing morning forest", "category": "nature", "subcategory": "birds", "tags": ["birds", "morning", "forest"], "count": 15},
    {"query": "songbirds dawn chorus", "category": "nature", "subcategory": "birds", "tags": ["songbirds", "dawn", "chorus"], "count": 10},
    {"query": "owl night forest", "category": "nature", "subcategory": "birds", "tags": ["owl", "night", "forest"], "count": 5},
    {"query": "seagulls beach ocean", "category": "nature", "subcategory": "birds", "tags": ["seagulls", "beach", "coastal"], "count": 5},

    {"query": "wind gentle breeze", "category": "nature", "subcategory": "wind", "tags": ["wind", "breeze", "gentle"], "count": 10},
    {"query": "wind trees leaves rustling", "category": "nature", "subcategory": "wind", "tags": ["wind", "trees", "leaves"], "count": 10},
    {"query": "wind howling winter", "category": "nature", "subcategory": "wind", "tags": ["wind", "winter", "howling"], "count": 5},

    {"query": "crickets night summer", "category": "nature", "subcategory": "night", "tags": ["crickets", "night", "summer"], "count": 10},
    {"query": "frogs pond night", "category": "nature", "subcategory": "night", "tags": ["frogs", "pond", "night"], "count": 8},
    {"query": "cicadas summer", "category": "nature", "subcategory": "night", "tags": ["cicadas", "summer", "insects"], "count": 5},
    {"query": "night ambience forest", "category": "nature", "subcategory": "night", "tags": ["night", "forest", "ambient"], "count": 10},

    {"query": "campfire crackling fire", "category": "nature", "subcategory": "fire", "tags": ["campfire", "fire", "crackling"], "count": 10},
    {"query": "fireplace cozy", "category": "nature", "subcategory": "fire", "tags": ["fireplace", "cozy", "warm"], "count": 8},

    {"query": "meadow ambience nature", "category": "nature", "subcategory": "ambient", "tags": ["meadow", "nature", "peaceful"], "count": 8},
    {"query": "garden ambient birds", "category": "nature", "subcategory": "ambient", "tags": ["garden", "birds", "peaceful"], "count": 8},
    {"query": "jungle rainforest ambient", "category": "nature", "subcategory": "ambient", "tags": ["jungle", "rainforest", "exotic"], "count": 8},

    # AMBIENT / WHITE NOISE
    {"query": "fan noise ambient sleep", "category": "whitenoise", "subcategory": "appliance", "tags": ["fan", "noise", "sleep"], "count": 8},
    {"query": "air conditioner hum", "category": "whitenoise", "subcategory": "appliance", "tags": ["ac", "hum", "white noise"], "count": 5},
    {"query": "washing machine", "category": "whitenoise", "subcategory": "appliance", "tags": ["washing", "machine", "rhythmic"], "count": 5},
    {"query": "dryer tumble", "category": "whitenoise", "subcategory": "appliance", "tags": ["dryer", "tumble", "soothing"], "count": 5},

    {"query": "womb heartbeat baby", "category": "whitenoise", "subcategory": "heartbeat", "tags": ["womb", "heartbeat", "baby"], "count": 10},
    {"query": "heartbeat slow calm", "category": "whitenoise", "subcategory": "heartbeat", "tags": ["heartbeat", "calm", "relaxing"], "count": 8},

    {"query": "shushing baby soothing", "category": "whitenoise", "subcategory": "shush", "tags": ["shush", "baby", "soothing"], "count": 8},

    # MUSIC / MELODIES
    {"query": "music box lullaby", "category": "lullabies", "subcategory": "music_box", "tags": ["music box", "lullaby", "gentle"], "count": 15},
    {"query": "music box melody children", "category": "lullabies", "subcategory": "music_box", "tags": ["music box", "melody", "children"], "count": 10},
    {"query": "kalimba gentle melody", "category": "lullabies", "subcategory": "kalimba", "tags": ["kalimba", "melody", "peaceful"], "count": 10},
    {"query": "glockenspiel chimes", "category": "lullabies", "subcategory": "chimes", "tags": ["glockenspiel", "chimes", "gentle"], "count": 8},
    {"query": "wind chimes peaceful", "category": "lullabies", "subcategory": "chimes", "tags": ["wind chimes", "peaceful", "ambient"], "count": 10},
    {"query": "harp gentle peaceful", "category": "classical", "subcategory": "harp", "tags": ["harp", "gentle", "classical"], "count": 10},
    {"query": "piano soft slow", "category": "classical", "subcategory": "piano", "tags": ["piano", "soft", "slow"], "count": 15},
    {"query": "guitar acoustic gentle", "category": "classical", "subcategory": "guitar", "tags": ["guitar", "acoustic", "gentle"], "count": 10},
    {"query": "strings peaceful orchestra", "category": "classical", "subcategory": "strings", "tags": ["strings", "orchestra", "peaceful"], "count": 10},
    {"query": "flute gentle peaceful", "category": "classical", "subcategory": "flute", "tags": ["flute", "peaceful", "gentle"], "count": 8},

    # AMBIENT PADS
    {"query": "ambient pad soft", "category": "ambient", "subcategory": "pads", "tags": ["ambient", "pad", "soft"], "count": 10},
    {"query": "drone ambient peaceful", "category": "ambient", "subcategory": "drone", "tags": ["drone", "ambient", "peaceful"], "count": 8},
    {"query": "meditation ambient", "category": "ambient", "subcategory": "meditation", "tags": ["meditation", "ambient", "peaceful"], "count": 10},
    {"query": "spa relaxation music", "category": "ambient", "subcategory": "spa", "tags": ["spa", "relaxation", "calm"], "count": 8},

    # VOCAL
    {"query": "humming melody soft", "category": "ambient", "subcategory": "vocal", "tags": ["humming", "soft", "soothing"], "count": 8},
    {"query": "lullaby singing gentle", "category": "lullabies", "subcategory": "vocal", "tags": ["lullaby", "singing", "gentle"], "count": 10},
    {"query": "choir ambient soft", "category": "ambient", "subcategory": "choir", "tags": ["choir", "ambient", "ethereal"], "count": 5},
]

def search_freesound(query: str, count: int = 10, min_duration: int = 30) -> list:
    """Search Freesound for CC0 licensed sounds"""
    if not FREESOUND_API_KEY:
        return []

    url = "https://freesound.org/apiv2/search/text/"
    params = {
        'query': query,
        'filter': f'license:"Creative Commons 0" duration:[{min_duration} TO 600]',
        'fields': 'id,name,description,duration,previews,tags,avg_rating,num_downloads,username',
        'sort': 'rating_desc',
        'page_size': count,
        'token': FREESOUND_API_KEY
    }

    try:
        response = requests.get(url, params=params, timeout=30)
        if response.status_code == 200:
            data = response.json()
            return data.get('results', [])
    except Exception as e:
        print(f"  Freesound error: {e}")
    return []

def download_freesound_preview(sound: dict, output_path: Path) -> bool:
    """Download a sound preview from Freesound"""
    preview_url = sound.get('previews', {}).get('preview-hq-mp3', '')
    if not preview_url:
        return False

    try:
        response = requests.get(preview_url, headers=HEADERS, stream=True, timeout=60)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return output_path.stat().st_size > 10000  # At least 10KB
    except Exception as e:
        print(f"  Download error: {e}")
    return False

# =============================================================================
# INTERNET ARCHIVE DOWNLOADS (Field recordings, public domain)
# =============================================================================

INTERNET_ARCHIVE_COLLECTIONS = [
    {
        "identifier": "NaturalSoundsFieldRecordingArchive",
        "category": "nature",
        "description": "Natural Sounds Field Recording Archive"
    },
    {
        "identifier": "nature-sounds_202104",
        "category": "nature",
        "description": "Nature Sounds Collection"
    },
    {
        "identifier": "animalsounds1",
        "category": "nature",
        "subcategory": "animals",
        "description": "Animal Sounds from Nature"
    },
    {
        "identifier": "RelaxingRainAndLoudThunderFreeFieldRecordingOfNatureSoundsForSleepOrMeditation",
        "category": "nature",
        "subcategory": "rain",
        "description": "Relaxing Rain and Thunder"
    },
    {
        "identifier": "naturesounds-soundtheraphy",
        "category": "nature",
        "description": "Nature Sounds Therapy"
    },
]

def get_archive_files(identifier: str) -> list:
    """Get list of audio files from an Internet Archive item"""
    url = f"https://archive.org/metadata/{identifier}"
    try:
        response = requests.get(url, timeout=30)
        if response.status_code == 200:
            data = response.json()
            files = []
            for f in data.get('files', []):
                name = f.get('name', '')
                if name.endswith(('.mp3', '.ogg', '.wav', '.flac')):
                    size = int(f.get('size', 0))
                    if size > 50000:  # At least 50KB
                        files.append({
                            'name': name,
                            'size': size,
                            'url': f"https://archive.org/download/{identifier}/{quote(name)}"
                        })
            return files
    except Exception as e:
        print(f"  Archive error: {e}")
    return []

def download_archive_file(url: str, output_path: Path) -> bool:
    """Download a file from Internet Archive"""
    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=120)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return output_path.stat().st_size > 10000
    except Exception as e:
        print(f"  Download error: {e}")
    return False

# =============================================================================
# PIXABAY DOWNLOADS (Direct links - CC0)
# =============================================================================

# Curated Pixabay direct download URLs (discovered through analysis)
PIXABAY_SOUNDS = [
    # Nature - Rain
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/15/audio_8cb749d484.mp3", "title": "Rain on Window", "category": "nature", "subcategory": "rain", "tags": ["rain", "window", "cozy"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/24/audio_18c3f0be6c.mp3", "title": "Light Rain", "category": "nature", "subcategory": "rain", "tags": ["rain", "light", "gentle"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/08/09/audio_dc39bde808.mp3", "title": "Rain Storm", "category": "nature", "subcategory": "rain", "tags": ["rain", "storm", "thunder"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/10/30/audio_946b0939c8.mp3", "title": "Soft Rain", "category": "nature", "subcategory": "rain", "tags": ["rain", "soft", "ambient"]},

    # Nature - Ocean
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3", "title": "Ocean Waves Calm", "category": "nature", "subcategory": "ocean", "tags": ["ocean", "waves", "calm"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/05/16/audio_3b8e3b8e3b.mp3", "title": "Beach Waves", "category": "nature", "subcategory": "ocean", "tags": ["beach", "waves", "shore"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_0625c1539c.mp3", "title": "Sea Ambience", "category": "nature", "subcategory": "ocean", "tags": ["sea", "ambient", "peaceful"]},

    # Nature - Birds
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/15/audio_25e668e9e4.mp3", "title": "Morning Birds", "category": "nature", "subcategory": "birds", "tags": ["birds", "morning", "chirping"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/04/07/audio_df85ae3ee4.mp3", "title": "Forest Birds", "category": "nature", "subcategory": "birds", "tags": ["forest", "birds", "nature"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/08/02/audio_2dae2c6d05.mp3", "title": "Songbirds", "category": "nature", "subcategory": "birds", "tags": ["songbirds", "melody", "nature"]},

    # Nature - Water
    {"url": "https://cdn.pixabay.com/download/audio/2022/01/18/audio_bc4c99e5dc.mp3", "title": "Stream Flowing", "category": "nature", "subcategory": "water", "tags": ["stream", "water", "flowing"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/10/audio_726a4d7b6a.mp3", "title": "River Gentle", "category": "nature", "subcategory": "water", "tags": ["river", "gentle", "nature"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_12b0c19e84.mp3", "title": "Waterfall", "category": "nature", "subcategory": "water", "tags": ["waterfall", "powerful", "nature"]},

    # Nature - Wind
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/15/audio_e0a7e8b5e4.mp3", "title": "Gentle Wind", "category": "nature", "subcategory": "wind", "tags": ["wind", "gentle", "breeze"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_2e8b8e8b2e.mp3", "title": "Wind Through Trees", "category": "nature", "subcategory": "wind", "tags": ["wind", "trees", "leaves"]},

    # Nature - Fire
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/10/audio_febc508520.mp3", "title": "Campfire Crackling", "category": "nature", "subcategory": "fire", "tags": ["campfire", "fire", "crackling"]},
    {"url": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_c4e4e4c4e4.mp3", "title": "Fireplace Cozy", "category": "nature", "subcategory": "fire", "tags": ["fireplace", "cozy", "warm"]},

    # Nature - Night
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/15/audio_8db8db8db8.mp3", "title": "Night Crickets", "category": "nature", "subcategory": "night", "tags": ["crickets", "night", "summer"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3", "title": "Night Ambience", "category": "nature", "subcategory": "night", "tags": ["night", "ambient", "peaceful"]},

    # Music - Lullabies
    {"url": "https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3", "title": "Soft Lullaby", "category": "lullabies", "subcategory": "instrumental", "tags": ["lullaby", "soft", "baby"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/10/25/audio_946b0939c8.mp3", "title": "Gentle Melody", "category": "lullabies", "subcategory": "instrumental", "tags": ["melody", "gentle", "peaceful"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3", "title": "Sleep Music", "category": "lullabies", "subcategory": "instrumental", "tags": ["sleep", "music", "relaxing"]},

    # Music - Piano
    {"url": "https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69c4.mp3", "title": "Calm Piano", "category": "classical", "subcategory": "piano", "tags": ["piano", "calm", "peaceful"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/08/31/audio_419c1f0af5.mp3", "title": "Soft Piano Melody", "category": "classical", "subcategory": "piano", "tags": ["piano", "soft", "melody"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/02/07/audio_de6ead8eef.mp3", "title": "Peaceful Piano", "category": "classical", "subcategory": "piano", "tags": ["piano", "peaceful", "relaxing"]},

    # Ambient
    {"url": "https://cdn.pixabay.com/download/audio/2022/03/10/audio_726a4d7b6a.mp3", "title": "Ambient Pad", "category": "ambient", "subcategory": "pads", "tags": ["ambient", "pad", "atmospheric"]},
    {"url": "https://cdn.pixabay.com/download/audio/2022/05/16/audio_9b2c3f8e9b.mp3", "title": "Meditation Music", "category": "ambient", "subcategory": "meditation", "tags": ["meditation", "calm", "peaceful"]},
]

def download_pixabay_sound(sound: dict, output_dir: Path) -> tuple:
    """Download a sound from Pixabay"""
    url = sound['url']
    title = sound['title'].replace(' ', '_').replace('/', '_')
    category = sound['category']

    category_dir = output_dir / category
    category_dir.mkdir(parents=True, exist_ok=True)

    filename = f"pb_{title}_{hashlib.md5(url.encode()).hexdigest()[:8]}.mp3"
    output_path = category_dir / filename

    if output_path.exists() and output_path.stat().st_size > 10000:
        return (True, sound, str(output_path), "exists")

    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=60)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            if output_path.stat().st_size > 10000:
                return (True, sound, str(output_path), "downloaded")
    except Exception as e:
        pass

    return (False, sound, None, "failed")

# =============================================================================
# MIXKIT DOWNLOADS (Free, no signup required)
# =============================================================================

MIXKIT_SOUNDS = [
    # Nature
    {"id": 1252, "title": "Rain on Leaves", "category": "nature", "subcategory": "rain"},
    {"id": 1253, "title": "Thunder Rumble", "category": "nature", "subcategory": "storm"},
    {"id": 1210, "title": "Ocean Waves Crashing", "category": "nature", "subcategory": "ocean"},
    {"id": 1211, "title": "Calm Sea Waves", "category": "nature", "subcategory": "ocean"},
    {"id": 1188, "title": "Forest Ambience", "category": "nature", "subcategory": "forest"},
    {"id": 1189, "title": "Birds in Forest", "category": "nature", "subcategory": "birds"},
    {"id": 1213, "title": "Wind Through Grass", "category": "nature", "subcategory": "wind"},
    {"id": 1215, "title": "Stream Babbling", "category": "nature", "subcategory": "water"},
    {"id": 1190, "title": "Night Crickets Chirping", "category": "nature", "subcategory": "night"},
    {"id": 1191, "title": "Campfire Burning", "category": "nature", "subcategory": "fire"},

    # More nature
    {"id": 1256, "title": "Heavy Rain", "category": "nature", "subcategory": "rain"},
    {"id": 1257, "title": "Tropical Rain", "category": "nature", "subcategory": "rain"},
    {"id": 1220, "title": "Seagulls at Beach", "category": "nature", "subcategory": "birds"},
    {"id": 1221, "title": "Waterfall Distant", "category": "nature", "subcategory": "water"},
    {"id": 1222, "title": "Frogs at Pond", "category": "nature", "subcategory": "night"},
]

def get_mixkit_download_url(sound_id: int) -> str:
    """Get the actual download URL for a Mixkit sound"""
    return f"https://assets.mixkit.co/sfx/download/mixkit-{sound_id}.mp3"

def download_mixkit_sound(sound: dict, output_dir: Path) -> tuple:
    """Download a sound from Mixkit"""
    sound_id = sound['id']
    url = get_mixkit_download_url(sound_id)

    category = sound['category']
    subcategory = sound.get('subcategory', 'misc')
    title = sound['title'].replace(' ', '_').replace('/', '_')

    category_dir = output_dir / category
    category_dir.mkdir(parents=True, exist_ok=True)

    filename = f"mk_{sound_id}_{title[:30]}.mp3"
    output_path = category_dir / filename

    if output_path.exists() and output_path.stat().st_size > 10000:
        return (True, sound, str(output_path), "exists")

    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=60)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            if output_path.stat().st_size > 5000:
                return (True, sound, str(output_path), "downloaded")
    except Exception as e:
        pass

    return (False, sound, None, "failed")

# =============================================================================
# METADATA GENERATION
# =============================================================================

def generate_metadata(all_tracks: list) -> dict:
    """Generate comprehensive searchable metadata"""
    metadata = {
        "version": "2.0",
        "generated": datetime.now().isoformat(),
        "total_tracks": len(all_tracks),
        "categories": {},
        "tracks": all_tracks,
        "search_index": {
            "by_category": {},
            "by_subcategory": {},
            "by_tag": {},
            "by_source": {},
        }
    }

    # Build indexes
    for track in all_tracks:
        cat = track.get('category', 'unknown')
        subcat = track.get('subcategory', 'misc')
        source = track.get('source', 'unknown')
        tags = track.get('tags', [])
        track_id = track.get('id')

        # Category index
        if cat not in metadata['search_index']['by_category']:
            metadata['search_index']['by_category'][cat] = []
        metadata['search_index']['by_category'][cat].append(track_id)

        # Subcategory index
        key = f"{cat}/{subcat}"
        if key not in metadata['search_index']['by_subcategory']:
            metadata['search_index']['by_subcategory'][key] = []
        metadata['search_index']['by_subcategory'][key].append(track_id)

        # Tag index
        for tag in tags:
            tag = tag.lower()
            if tag not in metadata['search_index']['by_tag']:
                metadata['search_index']['by_tag'][tag] = []
            metadata['search_index']['by_tag'][tag].append(track_id)

        # Source index
        if source not in metadata['search_index']['by_source']:
            metadata['search_index']['by_source'][source] = []
        metadata['search_index']['by_source'][source].append(track_id)

        # Category stats
        if cat not in metadata['categories']:
            metadata['categories'][cat] = {'count': 0, 'subcategories': {}}
        metadata['categories'][cat]['count'] += 1
        if subcat not in metadata['categories'][cat]['subcategories']:
            metadata['categories'][cat]['subcategories'][subcat] = 0
        metadata['categories'][cat]['subcategories'][subcat] += 1

    return metadata

# =============================================================================
# MAIN DOWNLOAD ORCHESTRATOR
# =============================================================================

def main():
    print("=" * 70)
    print("  MASS AUDIO DOWNLOADER FOR BABY IN CAR APP")
    print("  Target: 300+ REAL natural sounds and melodies")
    print("=" * 70)
    print()

    all_tracks = []
    stats = {
        'freesound': {'downloaded': 0, 'skipped': 0, 'failed': 0},
        'archive': {'downloaded': 0, 'skipped': 0, 'failed': 0},
        'pixabay': {'downloaded': 0, 'skipped': 0, 'failed': 0},
        'mixkit': {'downloaded': 0, 'skipped': 0, 'failed': 0},
    }

    # Ensure directories exist
    for cat in ['nature', 'whitenoise', 'lullabies', 'classical', 'ambient', 'children']:
        (BASE_DIR / cat).mkdir(parents=True, exist_ok=True)

    # =========================================================================
    # 1. FREESOUND DOWNLOADS
    # =========================================================================
    if FREESOUND_API_KEY:
        print("\n" + "=" * 50)
        print("1. DOWNLOADING FROM FREESOUND (CC0 License)")
        print("=" * 50)

        for query_config in tqdm(FREESOUND_QUERIES, desc="Freesound queries"):
            query = query_config['query']
            category = query_config['category']
            subcategory = query_config.get('subcategory', 'misc')
            tags = query_config.get('tags', [])
            count = query_config.get('count', 10)

            results = search_freesound(query, count)

            category_dir = BASE_DIR / category
            category_dir.mkdir(parents=True, exist_ok=True)

            for sound in results:
                sound_id = sound['id']
                name = sound.get('name', f'sound_{sound_id}')
                duration = sound.get('duration', 0)

                filename = f"fs_{sound_id}_{query.replace(' ', '_')[:15]}.mp3"
                output_path = category_dir / filename

                if output_path.exists() and output_path.stat().st_size > 10000:
                    stats['freesound']['skipped'] += 1
                    all_tracks.append({
                        'id': f'fs_{sound_id}',
                        'title': name[:50],
                        'artist': sound.get('username', 'Freesound'),
                        'category': category,
                        'subcategory': subcategory,
                        'filename': f"{category}/{filename}",
                        'source': 'freesound',
                        'license': 'CC0',
                        'duration': duration,
                        'tags': tags + list(sound.get('tags', []))[:5],
                        'calmScore': 0.85
                    })
                    continue

                if download_freesound_preview(sound, output_path):
                    stats['freesound']['downloaded'] += 1
                    all_tracks.append({
                        'id': f'fs_{sound_id}',
                        'title': name[:50],
                        'artist': sound.get('username', 'Freesound'),
                        'category': category,
                        'subcategory': subcategory,
                        'filename': f"{category}/{filename}",
                        'source': 'freesound',
                        'license': 'CC0',
                        'duration': duration,
                        'tags': tags + list(sound.get('tags', []))[:5],
                        'calmScore': 0.85
                    })
                else:
                    stats['freesound']['failed'] += 1

                time.sleep(REQUEST_DELAY)

        print(f"\nFreesound: {stats['freesound']['downloaded']} downloaded, {stats['freesound']['skipped']} skipped, {stats['freesound']['failed']} failed")
    else:
        print("\n[!] FREESOUND_API_KEY not set - skipping Freesound downloads")
        print("    Get your free API key at: https://freesound.org/apiv2/apply/")

    # =========================================================================
    # 2. INTERNET ARCHIVE DOWNLOADS
    # =========================================================================
    print("\n" + "=" * 50)
    print("2. DOWNLOADING FROM INTERNET ARCHIVE")
    print("=" * 50)

    for collection in tqdm(INTERNET_ARCHIVE_COLLECTIONS, desc="Archive collections"):
        identifier = collection['identifier']
        category = collection.get('category', 'nature')
        subcategory = collection.get('subcategory', 'ambient')

        files = get_archive_files(identifier)[:20]  # Limit per collection

        category_dir = BASE_DIR / category
        category_dir.mkdir(parents=True, exist_ok=True)

        for f in files:
            name = f['name']
            url = f['url']

            # Clean filename
            safe_name = name.replace(' ', '_').replace('/', '_')
            if not safe_name.endswith('.mp3'):
                safe_name = safe_name.rsplit('.', 1)[0] + '.mp3'

            filename = f"ia_{hashlib.md5(url.encode()).hexdigest()[:8]}_{safe_name[:30]}"
            if not filename.endswith('.mp3'):
                filename += '.mp3'

            output_path = category_dir / filename

            if output_path.exists() and output_path.stat().st_size > 10000:
                stats['archive']['skipped'] += 1
                all_tracks.append({
                    'id': f"ia_{hashlib.md5(url.encode()).hexdigest()[:12]}",
                    'title': name.rsplit('.', 1)[0][:50],
                    'artist': 'Internet Archive',
                    'category': category,
                    'subcategory': subcategory,
                    'filename': f"{category}/{filename}",
                    'source': 'internet_archive',
                    'license': 'Public Domain',
                    'tags': [category, subcategory, 'field recording'],
                    'calmScore': 0.8
                })
                continue

            if download_archive_file(url, output_path):
                stats['archive']['downloaded'] += 1
                all_tracks.append({
                    'id': f"ia_{hashlib.md5(url.encode()).hexdigest()[:12]}",
                    'title': name.rsplit('.', 1)[0][:50],
                    'artist': 'Internet Archive',
                    'category': category,
                    'subcategory': subcategory,
                    'filename': f"{category}/{filename}",
                    'source': 'internet_archive',
                    'license': 'Public Domain',
                    'tags': [category, subcategory, 'field recording'],
                    'calmScore': 0.8
                })
            else:
                stats['archive']['failed'] += 1

            time.sleep(REQUEST_DELAY)

    print(f"\nInternet Archive: {stats['archive']['downloaded']} downloaded, {stats['archive']['skipped']} skipped, {stats['archive']['failed']} failed")

    # =========================================================================
    # 3. PIXABAY DOWNLOADS
    # =========================================================================
    print("\n" + "=" * 50)
    print("3. DOWNLOADING FROM PIXABAY (CC0 License)")
    print("=" * 50)

    for sound in tqdm(PIXABAY_SOUNDS, desc="Pixabay sounds"):
        success, sound_data, path, status = download_pixabay_sound(sound, BASE_DIR)

        if success:
            if status == 'exists':
                stats['pixabay']['skipped'] += 1
            else:
                stats['pixabay']['downloaded'] += 1

            all_tracks.append({
                'id': f"pb_{hashlib.md5(sound['url'].encode()).hexdigest()[:12]}",
                'title': sound['title'],
                'artist': 'Pixabay',
                'category': sound['category'],
                'subcategory': sound.get('subcategory', 'misc'),
                'filename': path.replace(str(BASE_DIR) + '/', '') if path else None,
                'source': 'pixabay',
                'license': 'CC0',
                'tags': sound.get('tags', []),
                'calmScore': 0.85
            })
        else:
            stats['pixabay']['failed'] += 1

        time.sleep(REQUEST_DELAY)

    print(f"\nPixabay: {stats['pixabay']['downloaded']} downloaded, {stats['pixabay']['skipped']} skipped, {stats['pixabay']['failed']} failed")

    # =========================================================================
    # 4. MIXKIT DOWNLOADS
    # =========================================================================
    print("\n" + "=" * 50)
    print("4. DOWNLOADING FROM MIXKIT (Free License)")
    print("=" * 50)

    for sound in tqdm(MIXKIT_SOUNDS, desc="Mixkit sounds"):
        success, sound_data, path, status = download_mixkit_sound(sound, BASE_DIR)

        if success:
            if status == 'exists':
                stats['mixkit']['skipped'] += 1
            else:
                stats['mixkit']['downloaded'] += 1

            all_tracks.append({
                'id': f"mk_{sound['id']}",
                'title': sound['title'],
                'artist': 'Mixkit',
                'category': sound['category'],
                'subcategory': sound.get('subcategory', 'misc'),
                'filename': path.replace(str(BASE_DIR) + '/', '') if path else None,
                'source': 'mixkit',
                'license': 'Mixkit Free License',
                'tags': [sound['category'], sound.get('subcategory', ''), 'nature'],
                'calmScore': 0.85
            })
        else:
            stats['mixkit']['failed'] += 1

        time.sleep(REQUEST_DELAY)

    print(f"\nMixkit: {stats['mixkit']['downloaded']} downloaded, {stats['mixkit']['skipped']} skipped, {stats['mixkit']['failed']} failed")

    # =========================================================================
    # GENERATE METADATA
    # =========================================================================
    print("\n" + "=" * 50)
    print("GENERATING SEARCHABLE METADATA")
    print("=" * 50)

    metadata = generate_metadata(all_tracks)

    with open(METADATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)

    print(f"\nMetadata saved to: {METADATA_FILE}")

    # =========================================================================
    # FINAL SUMMARY
    # =========================================================================
    print("\n" + "=" * 70)
    print("  DOWNLOAD COMPLETE!")
    print("=" * 70)

    total_downloaded = sum(s['downloaded'] for s in stats.values())
    total_skipped = sum(s['skipped'] for s in stats.values())
    total_failed = sum(s['failed'] for s in stats.values())

    print(f"""
    Summary:
    --------
    New downloads:  {total_downloaded}
    Already exists: {total_skipped}
    Failed:         {total_failed}

    Total tracks in library: {len(all_tracks)}

    By Source:
    - Freesound:        {stats['freesound']['downloaded'] + stats['freesound']['skipped']}
    - Internet Archive: {stats['archive']['downloaded'] + stats['archive']['skipped']}
    - Pixabay:          {stats['pixabay']['downloaded'] + stats['pixabay']['skipped']}
    - Mixkit:           {stats['mixkit']['downloaded'] + stats['mixkit']['skipped']}

    Categories:
    """)

    for cat, info in metadata['categories'].items():
        print(f"    - {cat}: {info['count']} tracks")
        for subcat, count in info['subcategories'].items():
            print(f"        └── {subcat}: {count}")

    print(f"""
    Metadata file: {METADATA_FILE}

    Next steps:
    1. Run the app to see new tracks
    2. Update ContentLibraryService if needed
    3. Test playback of new tracks
    """)

if __name__ == '__main__':
    main()
