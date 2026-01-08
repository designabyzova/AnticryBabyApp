#!/usr/bin/env python3
"""
Chosic.com Scraper (2026 Updated)
Scrapes current Chosic website for public domain classical music

NO API KEY NEEDED - Web scraping only
"""

import re
import json
import requests
from pathlib import Path
from bs4 import BeautifulSoup
from urllib.parse import urljoin, quote

OUTPUT_DIR = Path(__file__).parent.parent / "audio-library" / "chosic"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

class ChosicScraper:
    BASE_URL = "https://www.chosic.com"

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://www.chosic.com/'
        })
        self.tracks = []

    def scrape_category(self, category_path: str, category_name: str, limit: int = 20):
        """Scrape a specific category page"""
        url = urljoin(self.BASE_URL, category_path)
        print(f"\n🔍 Scraping: {url}")

        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()

            soup = BeautifulSoup(response.content, 'html.parser')

            # Method 1: Find download links in article/post content
            articles = soup.find_all(['article', 'div'], class_=re.compile('post|entry|music-item'))

            for article in articles[:limit]:
                try:
                    # Find title
                    title_elem = article.find(['h2', 'h3', 'h4'], class_=re.compile('title|entry-title'))
                    if not title_elem:
                        title_elem = article.find(['a'], class_=re.compile('title'))

                    if not title_elem:
                        continue

                    title = title_elem.get_text(strip=True)

                    # Find download link
                    download_link = None

                    # Look for direct MP3 links
                    mp3_links = article.find_all('a', href=re.compile(r'\.mp3$', re.I))
                    if mp3_links:
                        download_link = mp3_links[0]['href']

                    # Look for download buttons
                    if not download_link:
                        download_btn = article.find('a', class_=re.compile('download|btn-download'))
                        if download_btn and download_btn.get('href'):
                            download_link = download_btn['href']

                    # Look for data attributes
                    if not download_link:
                        audio_elem = article.find(['audio', 'a'], attrs={'data-url': True})
                        if audio_elem:
                            download_link = audio_elem.get('data-url') or audio_elem.get('href')

                    if download_link and download_link.endswith('.mp3'):
                        # Make URL absolute
                        if not download_link.startswith('http'):
                            download_link = urljoin(self.BASE_URL, download_link)

                        # Extract artist from title (usually "Title - Artist")
                        artist = "Unknown"
                        if ' - ' in title:
                            parts = title.split(' - ')
                            title = parts[0].strip()
                            artist = parts[-1].strip()
                        elif ' by ' in title.lower():
                            parts = title.lower().split(' by ')
                            title = parts[0].strip()
                            artist = parts[1].strip().title()

                        track = {
                            'title': title,
                            'artist': artist,
                            'category': category_name,
                            'url': download_link,
                            'source': 'chosic.com',
                            'license': 'Public Domain'
                        }

                        self.tracks.append(track)
                        print(f"  ✅ Found: {title} - {artist}")

                except Exception as e:
                    print(f"  ⚠️  Failed to parse article: {e}")
                    continue

            # Method 2: Look for embedded audio players with source URLs
            audio_elements = soup.find_all('audio')
            for audio in audio_elements[:limit]:
                try:
                    source = audio.find('source')
                    if source and source.get('src'):
                        mp3_url = source['src']
                        if not mp3_url.startswith('http'):
                            mp3_url = urljoin(self.BASE_URL, mp3_url)

                        # Try to find associated title
                        parent = audio.find_parent(['article', 'div'], class_=re.compile('post|entry'))
                        title = "Unknown Track"
                        if parent:
                            title_elem = parent.find(['h2', 'h3', 'h4'])
                            if title_elem:
                                title = title_elem.get_text(strip=True)

                        track = {
                            'title': title,
                            'artist': 'Classical',
                            'category': category_name,
                            'url': mp3_url,
                            'source': 'chosic.com',
                            'license': 'Public Domain'
                        }

                        if track not in self.tracks:
                            self.tracks.append(track)
                            print(f"  ✅ Found (audio element): {title}")

                except Exception as e:
                    print(f"  ⚠️  Failed to parse audio element: {e}")

            print(f"  📊 Total tracks found on this page: {len([t for t in self.tracks if t['category'] == category_name])}")

        except Exception as e:
            print(f"  ❌ Failed to scrape {url}: {e}")

    def download_track(self, track: dict) -> bool:
        """Download a single track"""
        try:
            filename = f"{self.sanitize_filename(track['artist'])}_{self.sanitize_filename(track['title'])}.mp3"
            output_path = OUTPUT_DIR / filename

            # Skip if exists
            if output_path.exists() and output_path.stat().st_size > 100000:
                print(f"[SKIP] {track['title']} (already exists)")
                return True

            print(f"[DOWNLOAD] {track['title']} - {track['artist']}")

            response = self.session.get(track['url'], timeout=120, stream=True)
            response.raise_for_status()

            # Verify content type
            content_type = response.headers.get('Content-Type', '')
            if 'audio' not in content_type and 'mpeg' not in content_type:
                print(f"[FAIL] Invalid content type: {content_type}")
                return False

            # Download
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            # Verify size
            if output_path.stat().st_size < 100000:
                output_path.unlink()
                print(f"[FAIL] File too small")
                return False

            size_mb = output_path.stat().st_size / (1024 * 1024)
            print(f"[OK] Downloaded {size_mb:.1f}MB")

            # Save metadata
            metadata_path = output_path.with_suffix('.json')
            with open(metadata_path, 'w') as f:
                json.dump(track, f, indent=2)

            return True

        except Exception as e:
            print(f"[FAIL] {track['title']}: {e}")
            return False

    def sanitize_filename(self, name: str) -> str:
        """Create safe filename"""
        return re.sub(r'[^\w\s-]', '', name).strip().replace(' ', '_')[:50]

    def save_track_list(self):
        """Save list of all found tracks"""
        output_file = OUTPUT_DIR / "chosic_tracks.json"
        with open(output_file, 'w') as f:
            json.dump({
                'total': len(self.tracks),
                'tracks': self.tracks
            }, f, indent=2)
        print(f"\n📝 Saved track list to {output_file}")


def main():
    print("=" * 70)
    print("🎵 CHOSIC.COM SCRAPER (2026 Updated)")
    print("=" * 70)

    scraper = ChosicScraper()

    # Categories to scrape
    categories = [
        ('/free-music/classical/', 'classical_music'),
        ('/free-music/lullaby/', 'lullabies'),
        ('/free-music/meditation/', 'instrumental'),
        ('/free-music/piano/', 'classical_music'),
        ('/free-music/ambient/', 'instrumental'),
    ]

    # Scrape all categories
    for path, category in categories:
        scraper.scrape_category(path, category, limit=10)

    print("\n" + "=" * 70)
    print(f"📊 SCRAPING COMPLETE")
    print("=" * 70)
    print(f"Total tracks found: {len(scraper.tracks)}")
    print()

    # Save track list
    scraper.save_track_list()

    # Download tracks
    if scraper.tracks:
        print("\n🔽 Starting downloads...")
        success = 0
        failed = 0

        for track in scraper.tracks[:20]:  # Limit to 20 downloads for testing
            if scraper.download_track(track):
                success += 1
            else:
                failed += 1

        print("\n" + "=" * 70)
        print("📊 DOWNLOAD COMPLETE")
        print("=" * 70)
        print(f"✅ Success: {success}")
        print(f"❌ Failed: {failed}")
        print(f"📁 Output: {OUTPUT_DIR}")
        print("=" * 70)
    else:
        print("\n⚠️  No tracks found to download")
        print("💡 This might mean Chosic.com has changed their website structure")
        print("   Try visiting https://www.chosic.com/free-music/ manually to inspect")

if __name__ == "__main__":
    main()
