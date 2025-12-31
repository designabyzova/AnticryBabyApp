#!/usr/bin/env python3
"""
Podcast Downloader for Baby in Car App
Downloads 100+ free podcasts from English and Russian sources
Focused on: bedtime stories, lullabies, calming content for children

Sources:
- Internet Archive (archive.org) - Public Domain
- LibriVox - Public Domain children's audiobooks
- Free podcast RSS feeds (Creative Commons / permissive licenses)
"""

import os
import sys
import json
import time
import re
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import hashlib

# Configuration
OUTPUT_BASE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
PODCAST_DIR = os.path.join(OUTPUT_BASE, "podcasts")
METADATA_FILE = os.path.join(OUTPUT_BASE, "podcast_metadata.json")

# Rate limiting
DOWNLOAD_DELAY = 1.0  # seconds between downloads
MAX_WORKERS = 3

# User agent for downloads
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ============================================
# PODCAST SOURCES
# ============================================

# RSS Feeds for children's bedtime content
RSS_FEEDS = {
    # English Podcasts
    "bedtime_fm_storytime": {
        "url": "https://www.bedtime.fm/storytime/feed",
        "language": "en",
        "category": "children_stories",
        "max_episodes": 30,
        "title": "Story Time - Bedtime FM"
    },
    "sleep_tight_stories": {
        "url": "https://feed.sleeptightstories.org/sleeptightstories",
        "language": "en",
        "category": "children_stories",
        "max_episodes": 25,
        "title": "Sleep Tight Stories"
    },
    "peace_out": {
        "url": "https://www.bedtime.fm/peaceout/feed",
        "language": "en",
        "category": "mindfulness",
        "max_episodes": 20,
        "title": "Peace Out - Mindfulness for Kids"
    },
    "stories_podcast": {
        "url": "https://feeds.megaphone.fm/wondery-stories-podcast",
        "language": "en",
        "category": "children_stories",
        "max_episodes": 25,
        "title": "Stories Podcast"
    },
}

# Internet Archive Collections
INTERNET_ARCHIVE_COLLECTIONS = [
    # Baby Sleep Music Collections
    {
        "id": "baby-sleep-music",
        "language": "multi",
        "category": "lullabies",
        "max_items": 10
    },
    {
        "id": "BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa",
        "language": "multi",
        "category": "lullabies",
        "max_items": 10
    },
    {
        "id": "SleepSounds",
        "language": "en",
        "category": "whitenoise",
        "max_items": 8
    },
    {
        "id": "CalmingMusicForChildren",
        "language": "en",
        "category": "children_calm",
        "max_items": 5
    },
    {
        "id": "sleepingbabymusicz",
        "language": "multi",
        "category": "lullabies",
        "max_items": 10
    },
    {
        "id": "BestOfMozartBabySleepAndBedtimeSongs",
        "language": "multi",
        "category": "classical",
        "max_items": 10
    },
    # Russian Fairy Tales
    {
        "id": "russianfairytales1_2007_librivox",
        "language": "ru",
        "category": "russian_stories",
        "max_items": 15
    },
    {
        "id": "russianfairytales2_2103_librivox",
        "language": "ru",
        "category": "russian_stories",
        "max_items": 15
    },
]

# LibriVox Children's Audiobooks (Public Domain)
LIBRIVOX_BOOKS = [
    # English Children's Books
    {"id": "velveteen-rabbit", "title": "The Velveteen Rabbit", "language": "en"},
    {"id": "peter-rabbit", "title": "The Tale of Peter Rabbit", "language": "en"},
    {"id": "alices-adventures-in-wonderland-version-7", "title": "Alice in Wonderland", "language": "en"},
    {"id": "the-wonderful-wizard-of-oz", "title": "Wizard of Oz", "language": "en"},
    {"id": "grimms-fairy-tales", "title": "Grimm's Fairy Tales", "language": "en"},
    {"id": "andersens-fairy-tales", "title": "Andersen's Fairy Tales", "language": "en"},
    {"id": "aesops-fables-volume-1", "title": "Aesop's Fables", "language": "en"},
    {"id": "just-so-stories", "title": "Just So Stories", "language": "en"},
    {"id": "wind-in-the-willows", "title": "Wind in the Willows", "language": "en"},
    {"id": "nursery-rhymes", "title": "Nursery Rhymes", "language": "en"},
]

# Direct download URLs for specific audio files (Public Domain / CC0)
DIRECT_DOWNLOADS = [
    # Russian Lullabies and Stories from verified sources
    {
        "url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_01_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_01.mp3",
        "title": "Русская народная сказка 1",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_02_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_02.mp3",
        "title": "Русская народная сказка 2",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_03_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_03.mp3",
        "title": "Русская народная сказка 3",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_04_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_04.mp3",
        "title": "Русская народная сказка 4",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_05_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_05.mp3",
        "title": "Русская народная сказка 5",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_01_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_06.mp3",
        "title": "Русская народная сказка 6",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_02_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_07.mp3",
        "title": "Русская народная сказка 7",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_03_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_08.mp3",
        "title": "Русская народная сказка 8",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_04_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_09.mp3",
        "title": "Русская народная сказка 9",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_05_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_10.mp3",
        "title": "Русская народная сказка 10",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    # More Russian stories
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_06_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_11.mp3",
        "title": "Русская народная сказка 11",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_07_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_12.mp3",
        "title": "Русская народная сказка 12",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_08_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_13.mp3",
        "title": "Русская народная сказка 13",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_09_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_14.mp3",
        "title": "Русская народная сказка 14",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    {
        "url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_10_afanasyev_128kb.mp3",
        "filename": "podcasts/russian/fairy_tale_15.mp3",
        "title": "Русская народная сказка 15",
        "artist": "LibriVox",
        "language": "ru",
        "category": "russian_stories"
    },
    # Baby Sleep Music from Internet Archive
    {
        "url": "https://archive.org/download/baby-sleep-music/Super%20Soothing%20Baby%20Bedtime%20Sleep%20Music.ogg",
        "filename": "podcasts/sleep/baby_sleep_soothing.ogg",
        "title": "Super Soothing Baby Bedtime",
        "artist": "Archive.org",
        "language": "multi",
        "category": "lullabies"
    },
    {
        "url": "https://archive.org/download/baby-sleep-music/Soft%20Relaxing%20Baby%20Sleep%20Music.ogg",
        "filename": "podcasts/sleep/baby_sleep_soft.ogg",
        "title": "Soft Relaxing Baby Sleep",
        "artist": "Archive.org",
        "language": "multi",
        "category": "lullabies"
    },
]

# ============================================
# HELPER FUNCTIONS
# ============================================

def sanitize_filename(name):
    """Clean filename for safe file system use"""
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    name = re.sub(r'\s+', '_', name)
    name = name[:100]  # Limit length
    return name.lower()

def get_file_hash(content):
    """Generate hash for deduplication"""
    return hashlib.md5(content[:10000]).hexdigest()

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

            # Verify it's actual audio content
            if len(content) < 5000:
                return None, "File too small"

            # Check for HTML error pages
            if content[:15].lower().startswith(b'<!doctype') or content[:10].lower().startswith(b'<html'):
                return None, "Received HTML instead of audio"

            # Save the file
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

def parse_rss_feed(url, max_episodes=20):
    """Parse RSS feed and extract episode info"""
    episodes = []
    try:
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as response:
            content = response.read()
            root = ET.fromstring(content)

            # Handle different RSS namespaces
            namespaces = {
                'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd',
                'media': 'http://search.yahoo.com/mrss/',
                'content': 'http://purl.org/rss/1.0/modules/content/'
            }

            channel = root.find('channel')
            if channel is None:
                return episodes

            items = channel.findall('item')[:max_episodes]

            for item in items:
                episode = {}

                # Get title
                title_elem = item.find('title')
                episode['title'] = title_elem.text if title_elem is not None else "Unknown"

                # Get audio URL from enclosure
                enclosure = item.find('enclosure')
                if enclosure is not None:
                    episode['url'] = enclosure.get('url')
                    episode['type'] = enclosure.get('type', 'audio/mpeg')
                else:
                    continue  # Skip episodes without audio

                # Get duration
                duration_elem = item.find('.//itunes:duration', namespaces)
                if duration_elem is not None:
                    episode['duration'] = duration_elem.text

                # Get description
                desc_elem = item.find('description')
                if desc_elem is not None:
                    episode['description'] = desc_elem.text[:200] if desc_elem.text else ""

                # Get publish date
                pub_date = item.find('pubDate')
                if pub_date is not None:
                    episode['pub_date'] = pub_date.text

                episodes.append(episode)

    except Exception as e:
        print(f"Error parsing RSS feed {url}: {e}")

    return episodes

def get_internet_archive_files(collection_id, max_items=10):
    """Get downloadable files from Internet Archive collection"""
    files = []
    try:
        # Get metadata for the item
        metadata_url = f"https://archive.org/metadata/{collection_id}"
        req = urllib.request.Request(metadata_url, headers={'User-Agent': USER_AGENT})

        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode('utf-8'))

            item_files = data.get('files', [])

            # Filter for audio files
            audio_extensions = ['.mp3', '.ogg', '.m4a', '.wav', '.flac']
            count = 0

            for f in item_files:
                if count >= max_items:
                    break

                name = f.get('name', '')
                ext = os.path.splitext(name)[1].lower()

                if ext in audio_extensions:
                    # Skip very small files and derivative formats
                    size = int(f.get('size', 0))
                    if size < 100000:  # Skip files smaller than 100KB
                        continue

                    source = f.get('source', '')
                    if source == 'derivative' and '_64kb' in name:
                        continue  # Skip low quality derivatives if there are better options

                    files.append({
                        'url': f"https://archive.org/download/{collection_id}/{urllib.request.quote(name)}",
                        'name': name,
                        'size': size,
                        'format': f.get('format', 'Unknown')
                    })
                    count += 1

    except Exception as e:
        print(f"Error fetching Internet Archive collection {collection_id}: {e}")

    return files

def get_librivox_book_files(book_id, max_chapters=10):
    """Get audio files from a LibriVox book"""
    files = []
    try:
        # LibriVox API endpoint
        api_url = f"https://librivox.org/api/feed/audiobooks/title/^{urllib.request.quote(book_id)}?format=json"
        req = urllib.request.Request(api_url, headers={'User-Agent': USER_AGENT})

        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode('utf-8'))

            books = data.get('books', [])
            if books:
                book = books[0]
                rss_url = book.get('url_rss')

                if rss_url:
                    # Parse the RSS feed for audio files
                    files = parse_rss_feed(rss_url, max_episodes=max_chapters)

    except Exception as e:
        print(f"Error fetching LibriVox book {book_id}: {e}")

    return files

# ============================================
# MAIN DOWNLOAD FUNCTIONS
# ============================================

def download_from_rss_feeds(metadata_list):
    """Download episodes from RSS feeds"""
    print("\n" + "="*60)
    print("DOWNLOADING FROM RSS FEEDS")
    print("="*60)

    total_downloaded = 0

    for feed_name, feed_info in RSS_FEEDS.items():
        print(f"\n[{feed_name}] Fetching: {feed_info['title']}")

        episodes = parse_rss_feed(feed_info['url'], feed_info['max_episodes'])
        print(f"  Found {len(episodes)} episodes")

        for i, episode in enumerate(episodes):
            if 'url' not in episode:
                continue

            # Create filename
            safe_title = sanitize_filename(episode['title'])
            filename = f"{feed_name}_{i+1:02d}_{safe_title}.mp3"
            output_path = os.path.join(PODCAST_DIR, feed_info['language'], feed_info['category'], filename)

            # Skip if already exists
            if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
                print(f"  [SKIP] {episode['title'][:50]}...")
                continue

            print(f"  [DL] {episode['title'][:50]}...")

            size, error = download_file(episode['url'], output_path)

            if size:
                metadata_list.append({
                    "id": f"podcast_{feed_name}_{i+1:02d}",
                    "title": episode['title'],
                    "artist": feed_info['title'],
                    "language": feed_info['language'],
                    "category": feed_info['category'],
                    "filename": os.path.relpath(output_path, OUTPUT_BASE),
                    "source": "rss_feed",
                    "license": "Podcast (free distribution)",
                    "duration": episode.get('duration', 'unknown'),
                    "size_bytes": size
                })
                total_downloaded += 1
                print(f"       OK ({size/1024/1024:.1f} MB)")
            else:
                print(f"       FAILED: {error}")

            time.sleep(DOWNLOAD_DELAY)

    return total_downloaded

def download_from_internet_archive(metadata_list):
    """Download files from Internet Archive collections"""
    print("\n" + "="*60)
    print("DOWNLOADING FROM INTERNET ARCHIVE")
    print("="*60)

    total_downloaded = 0

    for collection in INTERNET_ARCHIVE_COLLECTIONS:
        print(f"\n[{collection['id']}] Fetching...")

        files = get_internet_archive_files(collection['id'], collection['max_items'])
        print(f"  Found {len(files)} audio files")

        for i, f in enumerate(files):
            # Create filename
            safe_name = sanitize_filename(os.path.splitext(f['name'])[0])
            ext = os.path.splitext(f['name'])[1]
            filename = f"ia_{collection['id']}_{i+1:02d}_{safe_name[:50]}{ext}"
            output_path = os.path.join(PODCAST_DIR, collection['language'], collection['category'], filename)

            # Skip if already exists
            if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
                print(f"  [SKIP] {f['name'][:50]}...")
                continue

            print(f"  [DL] {f['name'][:50]}...")

            size, error = download_file(f['url'], output_path)

            if size:
                metadata_list.append({
                    "id": f"ia_{collection['id']}_{i+1:02d}",
                    "title": f['name'],
                    "artist": "Internet Archive",
                    "language": collection['language'],
                    "category": collection['category'],
                    "filename": os.path.relpath(output_path, OUTPUT_BASE),
                    "source": "internet_archive",
                    "license": "Public Domain / CC0",
                    "size_bytes": size
                })
                total_downloaded += 1
                print(f"       OK ({size/1024/1024:.1f} MB)")
            else:
                print(f"       FAILED: {error}")

            time.sleep(DOWNLOAD_DELAY)

    return total_downloaded

def download_direct_files(metadata_list):
    """Download files from direct URLs"""
    print("\n" + "="*60)
    print("DOWNLOADING DIRECT FILES")
    print("="*60)

    total_downloaded = 0

    for track in DIRECT_DOWNLOADS:
        output_path = os.path.join(OUTPUT_BASE, track['filename'])

        # Skip if already exists
        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {track['title']}")
            continue

        print(f"[DL] {track['title']}...")

        size, error = download_file(track['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"direct_{sanitize_filename(track['title'])}",
                "title": track['title'],
                "artist": track['artist'],
                "language": track['language'],
                "category": track['category'],
                "filename": track['filename'],
                "source": "direct_download",
                "license": "Public Domain",
                "size_bytes": size
            })
            total_downloaded += 1
            print(f"     OK ({size/1024/1024:.1f} MB)")
        else:
            print(f"     FAILED: {error}")

        time.sleep(DOWNLOAD_DELAY)

    return total_downloaded

def download_librivox_children(metadata_list):
    """Download children's audiobooks from LibriVox"""
    print("\n" + "="*60)
    print("DOWNLOADING FROM LIBRIVOX")
    print("="*60)

    # LibriVox children's content RSS feeds
    librivox_feeds = [
        {
            "url": "https://librivox.org/rss/4866",  # Velveteen Rabbit
            "title": "The Velveteen Rabbit",
            "language": "en",
            "max_episodes": 5
        },
        {
            "url": "https://librivox.org/rss/283",  # Alice in Wonderland
            "title": "Alice in Wonderland",
            "language": "en",
            "max_episodes": 12
        },
        {
            "url": "https://librivox.org/rss/227",  # Wizard of Oz
            "title": "The Wonderful Wizard of Oz",
            "language": "en",
            "max_episodes": 10
        },
        {
            "url": "https://librivox.org/rss/549",  # Walden (relaxing)
            "title": "Walden (Relaxing)",
            "language": "en",
            "max_episodes": 5
        },
        {
            "url": "https://librivox.org/rss/5756",  # Russian Fairy Tales 1
            "title": "Russian Fairy Tales Vol 1",
            "language": "ru",
            "max_episodes": 15
        },
        {
            "url": "https://librivox.org/rss/9087",  # Russian Fairy Tales 2
            "title": "Russian Fairy Tales Vol 2",
            "language": "ru",
            "max_episodes": 15
        },
        {
            "url": "https://librivox.org/rss/2015",  # Aesop's Fables
            "title": "Aesop's Fables",
            "language": "en",
            "max_episodes": 10
        },
        {
            "url": "https://librivox.org/rss/310",  # Just So Stories
            "title": "Just So Stories",
            "language": "en",
            "max_episodes": 8
        },
    ]

    total_downloaded = 0

    for feed in librivox_feeds:
        print(f"\n[LibriVox] {feed['title']}")

        episodes = parse_rss_feed(feed['url'], feed['max_episodes'])
        print(f"  Found {len(episodes)} chapters")

        for i, episode in enumerate(episodes):
            if 'url' not in episode:
                continue

            # Create filename
            safe_title = sanitize_filename(episode['title'])
            book_safe = sanitize_filename(feed['title'])
            filename = f"librivox_{book_safe}_{i+1:02d}_{safe_title[:30]}.mp3"
            output_path = os.path.join(PODCAST_DIR, feed['language'], "children_stories", filename)

            # Skip if already exists
            if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
                print(f"  [SKIP] {episode['title'][:50]}...")
                continue

            print(f"  [DL] Ch {i+1}: {episode['title'][:40]}...")

            size, error = download_file(episode['url'], output_path)

            if size:
                metadata_list.append({
                    "id": f"librivox_{book_safe}_{i+1:02d}",
                    "title": f"{feed['title']} - {episode['title']}",
                    "artist": "LibriVox",
                    "language": feed['language'],
                    "category": "children_stories",
                    "filename": os.path.relpath(output_path, OUTPUT_BASE),
                    "source": "librivox",
                    "license": "Public Domain",
                    "duration": episode.get('duration', 'unknown'),
                    "size_bytes": size
                })
                total_downloaded += 1
                print(f"       OK ({size/1024/1024:.1f} MB)")
            else:
                print(f"       FAILED: {error}")

            time.sleep(DOWNLOAD_DELAY)

    return total_downloaded

# ============================================
# MAIN EXECUTION
# ============================================

def main():
    print("="*60)
    print("PODCAST DOWNLOADER FOR BABY IN CAR APP")
    print("="*60)
    print(f"Output directory: {OUTPUT_BASE}")
    print(f"Podcast directory: {PODCAST_DIR}")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Create necessary directories
    for lang in ['en', 'ru', 'multi']:
        for cat in ['children_stories', 'lullabies', 'mindfulness', 'whitenoise', 'classical', 'russian_stories', 'children_calm', 'sleep']:
            os.makedirs(os.path.join(PODCAST_DIR, lang, cat), exist_ok=True)

    # Track all downloaded files
    metadata_list = []

    # Load existing metadata if available
    if os.path.exists(METADATA_FILE):
        try:
            with open(METADATA_FILE, 'r') as f:
                existing = json.load(f)
                if isinstance(existing, list):
                    metadata_list = existing
                    print(f"\nLoaded {len(metadata_list)} existing entries")
        except:
            pass

    # Download from all sources
    rss_count = download_from_rss_feeds(metadata_list)
    librivox_count = download_librivox_children(metadata_list)
    ia_count = download_from_internet_archive(metadata_list)
    direct_count = download_direct_files(metadata_list)

    # Save metadata
    with open(METADATA_FILE, 'w') as f:
        json.dump(metadata_list, f, indent=2, ensure_ascii=False)

    # Print summary
    print("\n" + "="*60)
    print("DOWNLOAD COMPLETE")
    print("="*60)
    print(f"RSS Feeds: {rss_count} episodes")
    print(f"LibriVox: {librivox_count} chapters")
    print(f"Internet Archive: {ia_count} files")
    print(f"Direct Downloads: {direct_count} files")
    print(f"---")
    print(f"TOTAL NEW: {rss_count + librivox_count + ia_count + direct_count}")
    print(f"TOTAL IN LIBRARY: {len(metadata_list)}")
    print(f"\nMetadata saved to: {METADATA_FILE}")

    # Count by language
    en_count = sum(1 for m in metadata_list if m.get('language') == 'en')
    ru_count = sum(1 for m in metadata_list if m.get('language') == 'ru')
    multi_count = sum(1 for m in metadata_list if m.get('language') == 'multi')

    print(f"\nBy Language:")
    print(f"  English: {en_count}")
    print(f"  Russian: {ru_count}")
    print(f"  Multi/Other: {multi_count}")

    # Verify we have 100+ tracks
    if len(metadata_list) >= 100:
        print(f"\n[SUCCESS] Target of 100+ podcasts achieved!")
    else:
        print(f"\n[INFO] Currently at {len(metadata_list)} podcasts. Run again or add more sources.")

if __name__ == '__main__':
    main()
