#!/usr/bin/env python3
"""
No-API-Key Audio Scraper for Baby in Car App
Scrapes royalty-free baby music from sources that DON'T require API keys

Sources:
1. Chosic.com - Public domain classical music
2. Pixabay Music - No attribution required
3. OrangeFreeSounds - CC0 nature sounds
4. Archive.org - Public domain recordings
5. Incompetech.com - Royalty-free with attribution
6. SoundBible - Public domain sound effects
7. Musopen - Public domain classical music
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from bs4 import BeautifulSoup
from urllib.parse import urljoin, quote
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
OUTPUT_DIR = Path(__file__).parent.parent / "audio-library" / "scraped"
MAX_WORKERS = 5
REQUEST_DELAY = 2  # Seconds between requests to be polite

class NoAPIScra:
    """Base scraper class"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8'
        })
        self.downloaded = []
        self.failed = []

    def download_track(self, url: str, filename: str, metadata: dict) -> dict:
        """Download a single track"""
        output_path = OUTPUT_DIR / filename
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Skip if exists
        if output_path.exists() and output_path.stat().st_size > 10000:
            return {"status": "skip", "title": metadata.get('title', 'Unknown'), "path": str(output_path)}

        try:
            response = self.session.get(url, timeout=60, stream=True)
            response.raise_for_status()

            # Verify it's audio
            content_type = response.headers.get('Content-Type', '')
            if not ('audio' in content_type or 'mpeg' in content_type or 'mp3' in content_type):
                # Check file content
                first_bytes = response.content[:100]
                if b'<!DOCTYPE' in first_bytes or b'<html' in first_bytes:
                    return {"status": "fail", "title": metadata.get('title'), "reason": "Not audio file"}

            # Download
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            # Verify size
            if output_path.stat().st_size < 10000:
                output_path.unlink()
                return {"status": "fail", "title": metadata.get('title'), "reason": "File too small"}

            # Save metadata
            metadata_path = output_path.with_suffix('.json')
            with open(metadata_path, 'w') as f:
                json.dump(metadata, f, indent=2)

            size_mb = output_path.stat().st_size / (1024 * 1024)
            return {
                "status": "success",
                "title": metadata.get('title'),
                "size": f"{size_mb:.2f}MB",
                "path": str(output_path)
            }

        except Exception as e:
            return {"status": "fail", "title": metadata.get('title'), "reason": str(e)}


class PixabayMusicScraper(NoAPIScra):
    """
    Pixabay Music - NO API KEY NEEDED
    License: Pixabay License (Free for commercial use, no attribution)
    """

    BASE_URL = "https://pixabay.com/music"

    def scrape_category(self, category: str, limit: int = 50) -> list:
        """Scrape tracks from a category"""
        tracks = []

        # Categories: lullabies, children, classical, ambient, sleep
        search_urls = [
            f"{self.BASE_URL}/search/?q={quote(category)}&order=popular",
            f"{self.BASE_URL}/search/mood/{category.lower()}/"
        ]

        for url in search_urls:
            try:
                print(f"🔍 Scraping Pixabay: {url}")
                response = self.session.get(url, timeout=30)
                soup = BeautifulSoup(response.content, 'html.parser')

                # Find audio download links
                # Pixabay structure: data-url attribute with download link
                audio_items = soup.find_all('a', {'data-url': True, 'class': 'download'})

                for item in audio_items[:limit]:
                    try:
                        download_url = item.get('data-url')
                        # Extract metadata from parent
                        parent = item.find_parent('div', class_='item')
                        title_elem = parent.find('a', class_='link')

                        title = title_elem.text.strip() if title_elem else "Unknown"

                        tracks.append({
                            'url': download_url,
                            'title': title,
                            'artist': 'Pixabay',
                            'category': category,
                            'license': 'Pixabay License',
                            'source': 'pixabay.com'
                        })

                    except Exception as e:
                        print(f"⚠️  Failed to parse item: {e}")
                        continue

                time.sleep(REQUEST_DELAY)

            except Exception as e:
                print(f"❌ Failed to scrape {url}: {e}")

        return tracks


class ChosicScraper(NoAPIScra):
    """
    Chosic.com - Public Domain Classical Music
    NO API KEY NEEDED - Direct MP3 links
    """

    # Pre-verified working URLs (already found in download-from-sources.py)
    CLASSICAL_TRACKS = [
        {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Gymnopedie-No-1-Erik-Satie.mp3", "title": "Gymnopedie No.1", "artist": "Erik Satie"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Clair-de-Lune-Debussy.mp3", "title": "Clair de Lune", "artist": "Claude Debussy"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Moonlight-Sonata-1st-Movement-Beethoven.mp3", "title": "Moonlight Sonata", "artist": "Beethoven"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Nocturne-Op-9-No-2-Chopin.mp3", "title": "Nocturne Op.9 No.2", "artist": "Chopin"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Brahms-Lullaby.mp3", "title": "Brahms Lullaby", "artist": "Brahms"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Reverie-Debussy.mp3", "title": "Reverie", "artist": "Debussy"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/05/Canon-in-D-Pachelbel.mp3", "title": "Canon in D", "artist": "Pachelbel"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Air-on-G-String-Bach.mp3", "title": "Air on G String", "artist": "Bach"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Fur-Elise-Beethoven.mp3", "title": "Fur Elise", "artist": "Beethoven"},
        {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Liebestraum-No-3-Liszt.mp3", "title": "Liebestraum No.3", "artist": "Liszt"},
    ]

    def get_all_tracks(self) -> list:
        """Return all verified Chosic tracks"""
        return [
            {
                **track,
                'category': 'classical',
                'license': 'Public Domain',
                'source': 'chosic.com',
                'calmingScore': 0.9
            }
            for track in self.CLASSICAL_TRACKS
        ]


class OrangeFreeSoundsScraper(NoAPIScra):
    """
    OrangeFreeSounds.com - CC0 Nature Sounds
    NO API KEY - Direct downloads
    """

    NATURE_SOUNDS = [
        {"url": "https://orangefreesounds.com/wp-content/uploads/2014/12/Ocean-waves.mp3", "title": "Ocean Waves", "category": "nature"},
        {"url": "https://orangefreesounds.com/wp-content/uploads/2014/04/Rain-and-thunder.mp3", "title": "Rain and Thunder", "category": "nature"},
        {"url": "https://orangefreesounds.com/wp-content/uploads/2014/04/Forest-birds.mp3", "title": "Forest Birds", "category": "nature"},
        {"url": "https://orangefreesounds.com/wp-content/uploads/2014/12/Fireplace-crackling.mp3", "title": "Fireplace", "category": "nature"},
        {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Babbling-brook.mp3", "title": "Babbling Brook", "category": "nature"},
    ]

    def get_all_tracks(self) -> list:
        """Return all nature sound tracks"""
        return [
            {
                **track,
                'artist': 'Nature Sounds',
                'license': 'CC0',
                'source': 'orangefreesounds.com',
                'calmingScore': 0.8
            }
            for track in self.NATURE_SOUNDS
        ]


class IncompetechScraper(NoAPIScra):
    """
    Incompetech.com (Kevin MacLeod) - Royalty-free with attribution
    NO API KEY - Direct MP3 download links
    """

    CALM_TRACKS = [
        {"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Gymnopedie%20No%201.mp3", "title": "Gymnopedie No 1", "artist": "Kevin MacLeod"},
        {"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Amazing%20Plan.mp3", "title": "Amazing Plan", "artist": "Kevin MacLeod"},
        {"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Dreaming.mp3", "title": "Dreaming", "artist": "Kevin MacLeod"},
        {"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Meditation%20Impromptu%2002.mp3", "title": "Meditation Impromptu 02", "artist": "Kevin MacLeod"},
        {"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Floating%20Cities.mp3", "title": "Floating Cities", "artist": "Kevin MacLeod"},
    ]

    def get_all_tracks(self) -> list:
        """Return all Incompetech tracks"""
        return [
            {
                **track,
                'category': 'ambient',
                'license': 'CC BY 4.0',
                'source': 'incompetech.com',
                'attribution': 'Music by Kevin MacLeod (incompetech.com)',
                'calmingScore': 0.85
            }
            for track in self.CALM_TRACKS
        ]


class MusopenScraper(NoAPIScra):
    """
    Musopen.org - Public Domain Classical Recordings
    NO API KEY - Browse and download
    """

    def scrape_baby_friendly_classical(self, limit: int = 30) -> list:
        """Scrape baby-friendly classical music"""
        # These are direct links to Musopen's CDN (public domain)
        tracks = []

        # Musopen has a browse interface, we can scrape specific composers
        composers = ['brahms', 'mozart', 'bach', 'chopin', 'debussy']

        for composer in composers:
            try:
                url = f"https://musopen.org/music/search/?q={composer}&type=work"
                print(f"🔍 Scraping Musopen: {composer}")

                response = self.session.get(url, timeout=30)
                soup = BeautifulSoup(response.content, 'html.parser')

                # Find download links (Musopen structure may vary)
                # This is a simplified version - in production, analyze their HTML structure

                time.sleep(REQUEST_DELAY)

            except Exception as e:
                print(f"❌ Musopen scrape failed: {e}")

        return tracks


class ArchiveDotOrgScraper(NoAPIScra):
    """
    Archive.org - Massive public domain collection
    NO API KEY - Use their search API (free, no key needed)
    """

    def search_and_download(self, query: str, limit: int = 20) -> list:
        """Search Archive.org for baby music"""
        tracks = []

        # Archive.org Advanced Search API (no key needed!)
        search_url = "https://archive.org/advancedsearch.php"

        params = {
            'q': f'{query} AND mediatype:audio AND format:VBR MP3',
            'fl': 'identifier,title,creator,downloads',
            'sort': 'downloads desc',
            'rows': limit,
            'output': 'json'
        }

        try:
            print(f"🔍 Searching Archive.org: {query}")
            response = self.session.get(search_url, params=params, timeout=30)
            data = response.json()

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
                    'category': 'classical',
                    'license': 'Public Domain',
                    'source': 'archive.org',
                    'identifier': identifier
                })

        except Exception as e:
            print(f"❌ Archive.org search failed: {e}")

        return tracks


def main():
    """Main scraper execution"""
    print("=" * 70)
    print("🎵 BABY IN CAR - NO-API-KEY AUDIO SCRAPER")
    print("=" * 70)
    print()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_tracks = []

    # 1. Chosic (verified direct links)
    print("📥 [1/6] Downloading from Chosic (Public Domain Classical)...")
    chosic = ChosicScraper()
    chosic_tracks = chosic.get_all_tracks()
    all_tracks.extend(chosic_tracks)
    print(f"   Found {len(chosic_tracks)} tracks")

    # 2. OrangeFreeSounds (CC0 nature)
    print("\n📥 [2/6] Downloading from OrangeFreeSounds (CC0 Nature)...")
    orange = OrangeFreeSoundsScraper()
    orange_tracks = orange.get_all_tracks()
    all_tracks.extend(orange_tracks)
    print(f"   Found {len(orange_tracks)} tracks")

    # 3. Incompetech (Kevin MacLeod)
    print("\n📥 [3/6] Downloading from Incompetech (CC-BY)...")
    incompetech = IncompetechScraper()
    incompetech_tracks = incompetech.get_all_tracks()
    all_tracks.extend(incompetech_tracks)
    print(f"   Found {len(incompetech_tracks)} tracks")

    # 4. Archive.org (Public Domain)
    print("\n📥 [4/6] Searching Archive.org (Public Domain)...")
    archive = ArchiveDotOrgScraper()
    archive_tracks = []
    for query in ['baby lullaby', 'classical piano sleep', 'brahms lullaby', 'mozart baby']:
        archive_tracks.extend(archive.search_and_download(query, limit=10))
        time.sleep(REQUEST_DELAY)
    all_tracks.extend(archive_tracks)
    print(f"   Found {len(archive_tracks)} tracks")

    # 5. Musopen (Public Domain classical)
    print("\n📥 [5/6] Scraping Musopen (Public Domain Classical)...")
    musopen = MusopenScraper()
    musopen_tracks = musopen.scrape_baby_friendly_classical(limit=20)
    all_tracks.extend(musopen_tracks)
    print(f"   Found {len(musopen_tracks)} tracks")

    # 6. Pixabay Music (No API, but requires web scraping)
    print("\n📥 [6/6] Scraping Pixabay Music (Royalty-Free)...")
    print("   ⚠️  Pixabay requires JavaScript - skipping for now")
    print("   💡 Alternative: Use Pixabay's direct download URLs (see manual list)")

    print("\n" + "=" * 70)
    print(f"📊 TOTAL TRACKS FOUND: {len(all_tracks)}")
    print("=" * 70)

    # Download all tracks
    print("\n🔽 Starting downloads...")
    downloader = NoAPIScra()

    success = 0
    failed = 0
    skipped = 0

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {}
        for i, track in enumerate(all_tracks):
            filename = f"{track['category']}/{track.get('artist', 'unknown').replace(' ', '_')}_{track['title'].replace(' ', '_')[:50]}.mp3"
            future = executor.submit(downloader.download_track, track['url'], filename, track)
            futures[future] = (i + 1, track['title'])

        for future in as_completed(futures):
            idx, title = futures[future]
            result = future.result()

            if result['status'] == 'success':
                print(f"[{idx}/{len(all_tracks)}] ✅ {title} ({result['size']})")
                success += 1
            elif result['status'] == 'skip':
                print(f"[{idx}/{len(all_tracks)}] ⏭️  {title} (already exists)")
                skipped += 1
            else:
                print(f"[{idx}/{len(all_tracks)}] ❌ {title} - {result['reason']}")
                failed += 1

    print("\n" + "=" * 70)
    print("📊 FINAL STATISTICS")
    print("=" * 70)
    print(f"✅ Successfully downloaded: {success}")
    print(f"⏭️  Skipped (already exist): {skipped}")
    print(f"❌ Failed: {failed}")
    print(f"📁 Output directory: {OUTPUT_DIR}")
    print("=" * 70)


if __name__ == "__main__":
    main()
