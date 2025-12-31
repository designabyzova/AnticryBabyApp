#!/usr/bin/env python3
"""
Additional English Podcast Downloader
Downloads more classic children's stories and calming content

Sources:
- LibriVox Public Domain Audiobooks
- Internet Archive sleep sounds
"""

import os
import json
import time
import urllib.request
import urllib.error
from pathlib import Path
import re

# Configuration
OUTPUT_BASE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
PODCAST_DIR = os.path.join(OUTPUT_BASE, "podcasts")
DOWNLOAD_DELAY = 1.5

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ============================================
# CLASSIC CHILDREN'S STORIES FROM LIBRIVOX
# ============================================

CLASSIC_STORIES = [
    # The Velveteen Rabbit
    {"url": "https://archive.org/download/velveteen_rabbit_1505_librivox/velveteen_rabbit_01_williams_128kb.mp3", "title": "The Velveteen Rabbit - Part 1", "collection": "velveteen_rabbit", "num": 1},
    {"url": "https://archive.org/download/velveteen_rabbit_1505_librivox/velveteen_rabbit_02_williams_128kb.mp3", "title": "The Velveteen Rabbit - Part 2", "collection": "velveteen_rabbit", "num": 2},

    # Aesop's Fables
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_01_aesop_128kb.mp3", "title": "Aesop's Fables - The Wolf and the Lamb", "collection": "aesops_fables", "num": 1},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_02_aesop_128kb.mp3", "title": "Aesop's Fables - The Fox and the Grapes", "collection": "aesops_fables", "num": 2},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_03_aesop_128kb.mp3", "title": "Aesop's Fables - The Hare and the Tortoise", "collection": "aesops_fables", "num": 3},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_04_aesop_128kb.mp3", "title": "Aesop's Fables - The Lion and the Mouse", "collection": "aesops_fables", "num": 4},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_05_aesop_128kb.mp3", "title": "Aesop's Fables - The Ant and the Grasshopper", "collection": "aesops_fables", "num": 5},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_06_aesop_128kb.mp3", "title": "Aesop's Fables - The Crow and the Pitcher", "collection": "aesops_fables", "num": 6},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_07_aesop_128kb.mp3", "title": "Aesop's Fables - The Dog and the Shadow", "collection": "aesops_fables", "num": 7},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_08_aesop_128kb.mp3", "title": "Aesop's Fables - The Boy Who Cried Wolf", "collection": "aesops_fables", "num": 8},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_09_aesop_128kb.mp3", "title": "Aesop's Fables - The City Mouse and Country Mouse", "collection": "aesops_fables", "num": 9},
    {"url": "https://archive.org/download/aesops_fables_volume_one_librivox/aesopsfables_10_aesop_128kb.mp3", "title": "Aesop's Fables - The Fox and the Crow", "collection": "aesops_fables", "num": 10},

    # Just So Stories by Rudyard Kipling
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_01_kipling_128kb.mp3", "title": "Just So Stories - How the Whale Got His Throat", "collection": "just_so", "num": 1},
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_02_kipling_128kb.mp3", "title": "Just So Stories - How the Camel Got His Hump", "collection": "just_so", "num": 2},
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_03_kipling_128kb.mp3", "title": "Just So Stories - How the Rhinoceros Got His Skin", "collection": "just_so", "num": 3},
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_04_kipling_128kb.mp3", "title": "Just So Stories - How the Leopard Got His Spots", "collection": "just_so", "num": 4},
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_05_kipling_128kb.mp3", "title": "Just So Stories - The Elephant's Child", "collection": "just_so", "num": 5},
    {"url": "https://archive.org/download/just_so_stories_librivox/justso_06_kipling_128kb.mp3", "title": "Just So Stories - The Sing-Song of Old Man Kangaroo", "collection": "just_so", "num": 6},

    # Grimm's Fairy Tales
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_01_grimm_128kb.mp3", "title": "Grimm's Tales - Rapunzel", "collection": "grimm", "num": 1},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_02_grimm_128kb.mp3", "title": "Grimm's Tales - Hansel and Gretel", "collection": "grimm", "num": 2},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_03_grimm_128kb.mp3", "title": "Grimm's Tales - The Frog Prince", "collection": "grimm", "num": 3},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_04_grimm_128kb.mp3", "title": "Grimm's Tales - Little Red Riding Hood", "collection": "grimm", "num": 4},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_05_grimm_128kb.mp3", "title": "Grimm's Tales - Cinderella", "collection": "grimm", "num": 5},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_06_grimm_128kb.mp3", "title": "Grimm's Tales - Snow White", "collection": "grimm", "num": 6},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_07_grimm_128kb.mp3", "title": "Grimm's Tales - Rumpelstiltskin", "collection": "grimm", "num": 7},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_08_grimm_128kb.mp3", "title": "Grimm's Tales - The Bremen Town Musicians", "collection": "grimm", "num": 8},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_09_grimm_128kb.mp3", "title": "Grimm's Tales - Sleeping Beauty", "collection": "grimm", "num": 9},
    {"url": "https://archive.org/download/grimms_fairy_tales_librivox/grimmsfairytales_10_grimm_128kb.mp3", "title": "Grimm's Tales - The Golden Goose", "collection": "grimm", "num": 10},

    # Andersen's Fairy Tales
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_01_andersen_128kb.mp3", "title": "Andersen's Tales - The Ugly Duckling", "collection": "andersen", "num": 1},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_02_andersen_128kb.mp3", "title": "Andersen's Tales - Thumbelina", "collection": "andersen", "num": 2},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_03_andersen_128kb.mp3", "title": "Andersen's Tales - The Little Mermaid", "collection": "andersen", "num": 3},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_04_andersen_128kb.mp3", "title": "Andersen's Tales - The Snow Queen", "collection": "andersen", "num": 4},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_05_andersen_128kb.mp3", "title": "Andersen's Tales - The Emperor's New Clothes", "collection": "andersen", "num": 5},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_06_andersen_128kb.mp3", "title": "Andersen's Tales - The Steadfast Tin Soldier", "collection": "andersen", "num": 6},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_07_andersen_128kb.mp3", "title": "Andersen's Tales - The Princess and the Pea", "collection": "andersen", "num": 7},
    {"url": "https://archive.org/download/andersensfairytales_1508_librivox/andersensfairytales_08_andersen_128kb.mp3", "title": "Andersen's Tales - The Little Match Girl", "collection": "andersen", "num": 8},

    # Peter Rabbit
    {"url": "https://archive.org/download/tale_of_peter_rabbit_librivox/tale_of_peter_rabbit_potter_128kb.mp3", "title": "The Tale of Peter Rabbit", "collection": "peter_rabbit", "num": 1},

    # Alice in Wonderland
    {"url": "https://archive.org/download/alices_adventures_in_wonderland_librivox/alicesadventures_01_carroll_128kb.mp3", "title": "Alice in Wonderland - Down the Rabbit Hole", "collection": "alice", "num": 1},
    {"url": "https://archive.org/download/alices_adventures_in_wonderland_librivox/alicesadventures_02_carroll_128kb.mp3", "title": "Alice in Wonderland - The Pool of Tears", "collection": "alice", "num": 2},
    {"url": "https://archive.org/download/alices_adventures_in_wonderland_librivox/alicesadventures_03_carroll_128kb.mp3", "title": "Alice in Wonderland - A Mad Tea Party", "collection": "alice", "num": 3},
    {"url": "https://archive.org/download/alices_adventures_in_wonderland_librivox/alicesadventures_04_carroll_128kb.mp3", "title": "Alice in Wonderland - The Queen's Croquet Ground", "collection": "alice", "num": 4},
]

# Sleep and relaxation sounds from Internet Archive
SLEEP_SOUNDS = [
    {"url": "https://archive.org/download/SleepSounds/01_Rain_Window.mp3", "title": "Rain on Window - Sleep Sound", "category": "sleep"},
    {"url": "https://archive.org/download/SleepSounds/02_Ocean_Waves.mp3", "title": "Ocean Waves - Sleep Sound", "category": "sleep"},
    {"url": "https://archive.org/download/SleepSounds/03_Forest_Night.mp3", "title": "Forest Night - Sleep Sound", "category": "sleep"},
    {"url": "https://archive.org/download/SleepSounds/04_Crickets.mp3", "title": "Crickets - Sleep Sound", "category": "sleep"},
    {"url": "https://archive.org/download/SleepSounds/05_Campfire.mp3", "title": "Campfire - Sleep Sound", "category": "sleep"},
]


def download_file(url, output_path, timeout=120):
    """Download a file with proper headers"""
    try:
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': USER_AGENT,
                'Accept': 'audio/*, */*;q=0.8',
            }
        )

        with urllib.request.urlopen(req, timeout=timeout) as response:
            content = response.read()

            if len(content) < 5000:
                return None, "File too small"

            if content[:15].lower().startswith(b'<!doctype') or content[:10].lower().startswith(b'<html'):
                return None, "Received HTML instead of audio"

            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'wb') as f:
                f.write(content)

            return len(content), None

    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}"
    except urllib.error.URLError as e:
        return None, str(e.reason)
    except Exception as e:
        return None, str(e)

def sanitize_filename(name):
    """Clean filename for safe file system use"""
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    name = re.sub(r'\s+', '_', name)
    name = name[:80]
    return name.lower()

def main():
    print("="*60)
    print("ADDITIONAL ENGLISH PODCAST DOWNLOADER")
    print("="*60)

    # Create directories
    stories_dir = os.path.join(PODCAST_DIR, "en", "classic_stories")
    sleep_dir = os.path.join(PODCAST_DIR, "en", "sleep_sounds")
    os.makedirs(stories_dir, exist_ok=True)
    os.makedirs(sleep_dir, exist_ok=True)

    metadata_list = []
    total_downloaded = 0

    # Download classic stories
    print("\n" + "="*40)
    print("Classic Children's Stories")
    print("="*40)

    for story in CLASSIC_STORIES:
        safe_title = sanitize_filename(story['title'])
        collection = story['collection']
        filename = f"{collection}_{story['num']:02d}_{safe_title}.mp3"
        output_path = os.path.join(stories_dir, filename)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {story['title']}")
            continue

        print(f"[DL] {story['title']}...")

        size, error = download_file(story['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"classic_{collection}_{story['num']:02d}",
                "title": story['title'],
                "artist": "LibriVox",
                "language": "en",
                "category": "classic_stories",
                "collection": collection,
                "filename": os.path.relpath(output_path, OUTPUT_BASE),
                "source": "librivox_archive",
                "license": "Public Domain",
                "size_bytes": size
            })
            total_downloaded += 1
            print(f"     OK ({size/1024/1024:.1f} MB)")
        else:
            print(f"     FAILED: {error}")

        time.sleep(DOWNLOAD_DELAY)

    # Download sleep sounds
    print("\n" + "="*40)
    print("Sleep Sounds")
    print("="*40)

    for i, sound in enumerate(SLEEP_SOUNDS):
        safe_title = sanitize_filename(sound['title'])
        filename = f"sleep_{i+1:02d}_{safe_title}.mp3"
        output_path = os.path.join(sleep_dir, filename)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {sound['title']}")
            continue

        print(f"[DL] {sound['title']}...")

        size, error = download_file(sound['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"sleep_{i+1:02d}",
                "title": sound['title'],
                "artist": "Internet Archive",
                "language": "en",
                "category": "sleep_sounds",
                "filename": os.path.relpath(output_path, OUTPUT_BASE),
                "source": "internet_archive",
                "license": "Public Domain / CC0",
                "size_bytes": size
            })
            total_downloaded += 1
            print(f"     OK ({size/1024/1024:.1f} MB)")
        else:
            print(f"     FAILED: {error}")

        time.sleep(DOWNLOAD_DELAY)

    # Save metadata
    metadata_file = os.path.join(OUTPUT_BASE, "english_podcast_metadata.json")
    with open(metadata_file, 'w', encoding='utf-8') as f:
        json.dump(metadata_list, f, indent=2, ensure_ascii=False)

    print("\n" + "="*60)
    print("DOWNLOAD COMPLETE")
    print("="*60)
    print(f"Total downloaded: {total_downloaded}")
    print(f"Total in metadata: {len(metadata_list)}")
    print(f"Metadata saved to: {metadata_file}")

if __name__ == '__main__':
    main()
