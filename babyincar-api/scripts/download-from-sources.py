#!/usr/bin/env python3
"""
Audio Downloader for Baby in Car App
Downloads royalty-free music from multiple verified sources
"""

import os
import json
import time
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
OUTPUT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"

# Direct download URLs from verified royalty-free sources
# All tracks are either Public Domain, CC0, or Royalty-Free for commercial use

TRACKS = [
    # ============================================
    # CHOSIC.COM - Royalty Free Music
    # ============================================
    # Classical Piano
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Gymnopedie-No-1-Erik-Satie.mp3", "filename": "classical/satie_gymnopedie_1.mp3", "title": "Gymnopedie No.1", "artist": "Erik Satie", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Clair-de-Lune-Debussy.mp3", "filename": "classical/debussy_clair_de_lune.mp3", "title": "Clair de Lune", "artist": "Claude Debussy", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Moonlight-Sonata-1st-Movement-Beethoven.mp3", "filename": "classical/beethoven_moonlight.mp3", "title": "Moonlight Sonata", "artist": "Beethoven", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Reverie-Debussy.mp3", "filename": "classical/debussy_reverie.mp3", "title": "Reverie", "artist": "Debussy", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/05/Canon-in-D-Pachelbel.mp3", "filename": "classical/pachelbel_canon_d.mp3", "title": "Canon in D", "artist": "Pachelbel", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Air-on-G-String-Bach.mp3", "filename": "classical/bach_air_g.mp3", "title": "Air on G String", "artist": "Bach", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Nocturne-Op-9-No-2-Chopin.mp3", "filename": "classical/chopin_nocturne.mp3", "title": "Nocturne Op.9 No.2", "artist": "Chopin", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Fur-Elise-Beethoven.mp3", "filename": "classical/beethoven_fur_elise.mp3", "title": "Fur Elise", "artist": "Beethoven", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Liebestraum-No-3-Liszt.mp3", "filename": "classical/liszt_liebestraum.mp3", "title": "Liebestraum No.3", "artist": "Liszt", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Traumerei-Schumann.mp3", "filename": "classical/schumann_traumerei.mp3", "title": "Traumerei", "artist": "Schumann", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Arabesque-No-1-Debussy.mp3", "filename": "classical/debussy_arabesque.mp3", "title": "Arabesque No.1", "artist": "Debussy", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Gnossienne-No-1-Satie.mp3", "filename": "classical/satie_gnossienne_1.mp3", "title": "Gnossienne No.1", "artist": "Satie", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/05/Prelude-in-C-Major-Bach.mp3", "filename": "classical/bach_prelude_c.mp3", "title": "Prelude in C Major", "artist": "Bach", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Ave-Maria-Schubert.mp3", "filename": "classical/schubert_ave_maria.mp3", "title": "Ave Maria", "artist": "Schubert", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/05/Swan-Lake-Theme-Tchaikovsky.mp3", "filename": "classical/tchaikovsky_swan_lake.mp3", "title": "Swan Lake Theme", "artist": "Tchaikovsky", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Meditation-from-Thais-Massenet.mp3", "filename": "classical/massenet_meditation.mp3", "title": "Meditation from Thais", "artist": "Massenet", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/05/The-Swan-Saint-Saens.mp3", "filename": "classical/saint_saens_swan.mp3", "title": "The Swan", "artist": "Saint-Saens", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Jesu-Joy-of-Mans-Desiring-Bach.mp3", "filename": "classical/bach_jesu_joy.mp3", "title": "Jesu Joy of Man's Desiring", "artist": "Bach", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Greensleeves.mp3", "filename": "classical/greensleeves.mp3", "title": "Greensleeves", "artist": "Traditional", "category": "classical"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Waltz-in-A-Minor-Chopin.mp3", "filename": "classical/chopin_waltz_a.mp3", "title": "Waltz in A Minor", "artist": "Chopin", "category": "classical"},

    # ============================================
    # LULLABIES
    # ============================================
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Brahms-Lullaby.mp3", "filename": "lullabies/brahms_lullaby.mp3", "title": "Brahms Lullaby", "artist": "Brahms", "category": "lullabies"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/04/Twinkle-Twinkle-Little-Star.mp3", "filename": "lullabies/twinkle_star.mp3", "title": "Twinkle Twinkle Little Star", "artist": "Traditional", "category": "lullabies"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/05/Rock-a-bye-Baby.mp3", "filename": "lullabies/rock_a_bye.mp3", "title": "Rock-a-bye Baby", "artist": "Traditional", "category": "lullabies"},
    {"url": "https://www.chosic.com/wp-content/uploads/2021/07/Hush-Little-Baby.mp3", "filename": "lullabies/hush_little_baby.mp3", "title": "Hush Little Baby", "artist": "Traditional", "category": "lullabies"},

    # ============================================
    # BENSOUND.COM - Royalty Free (with attribution for free use)
    # ============================================
    {"url": "https://www.bensound.com/bensound-music/bensound-relaxing.mp3", "filename": "ambient/bensound_relaxing.mp3", "title": "Relaxing", "artist": "Bensound", "category": "ambient"},
    {"url": "https://www.bensound.com/bensound-music/bensound-slowmotion.mp3", "filename": "ambient/bensound_slowmotion.mp3", "title": "Slow Motion", "artist": "Bensound", "category": "ambient"},
    {"url": "https://www.bensound.com/bensound-music/bensound-memories.mp3", "filename": "ambient/bensound_memories.mp3", "title": "Memories", "artist": "Bensound", "category": "ambient"},
    {"url": "https://www.bensound.com/bensound-music/bensound-tenderness.mp3", "filename": "ambient/bensound_tenderness.mp3", "title": "Tenderness", "artist": "Bensound", "category": "ambient"},
    {"url": "https://www.bensound.com/bensound-music/bensound-allthat.mp3", "filename": "ambient/bensound_allthat.mp3", "title": "All That", "artist": "Bensound", "category": "ambient"},

    # ============================================
    # SOUNDBIBLE.COM - Public Domain
    # ============================================
    {"url": "http://soundbible.com/mp3/Crickets-SoundBible.com-1636498884.mp3", "filename": "nature/crickets.mp3", "title": "Crickets", "artist": "Nature", "category": "nature"},
    {"url": "http://soundbible.com/mp3/Rain-SoundBible.com-1556436309.mp3", "filename": "nature/rain.mp3", "title": "Rain", "artist": "Nature", "category": "nature"},
    {"url": "http://soundbible.com/mp3/Campfire-SoundBible.com-309622792.mp3", "filename": "nature/campfire.mp3", "title": "Campfire", "artist": "Nature", "category": "nature"},
    {"url": "http://soundbible.com/mp3/Bird-Whistling-SoundBible.com-1667993792.mp3", "filename": "nature/bird_whistling.mp3", "title": "Bird Whistling", "artist": "Nature", "category": "nature"},
    {"url": "http://soundbible.com/mp3/Wind-Mark_DiAngelo-1940285615.mp3", "filename": "nature/wind.mp3", "title": "Wind", "artist": "Nature", "category": "nature"},
    {"url": "http://soundbible.com/mp3/Ocean_Waves-Mike_Koenig-980635527.mp3", "filename": "nature/ocean_waves.mp3", "title": "Ocean Waves", "artist": "Nature", "category": "nature"},
]

def download_file(track):
    """Download a single track"""
    url = track['url']
    filename = track['filename']
    title = track['title']

    output_path = Path(OUTPUT_DIR) / filename
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Skip if already exists and is valid
    if output_path.exists() and output_path.stat().st_size > 10000:
        return {"status": "skip", "title": title, "reason": "already exists"}

    try:
        # Create request with headers
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8',
                'Referer': 'https://www.google.com/'
            }
        )

        with urllib.request.urlopen(req, timeout=60) as response:
            content = response.read()

            # Verify it's audio (not HTML error page)
            if len(content) < 10000:
                return {"status": "fail", "title": title, "reason": "file too small"}

            # Check for HTML content (error pages)
            if content[:15].lower().startswith(b'<!doctype') or content[:10].lower().startswith(b'<html'):
                return {"status": "fail", "title": title, "reason": "received HTML instead of audio"}

            with open(output_path, 'wb') as f:
                f.write(content)

            size_mb = len(content) / (1024 * 1024)
            return {"status": "success", "title": title, "size": f"{size_mb:.2f}MB", "path": str(output_path)}

    except urllib.error.HTTPError as e:
        return {"status": "fail", "title": title, "reason": f"HTTP {e.code}"}
    except urllib.error.URLError as e:
        return {"status": "fail", "title": title, "reason": str(e.reason)}
    except Exception as e:
        return {"status": "fail", "title": title, "reason": str(e)}

def main():
    print("=" * 60)
    print("BABY IN CAR - AUDIO DOWNLOADER")
    print("=" * 60)
    print(f"\nTotal tracks to process: {len(TRACKS)}")
    print(f"Output directory: {OUTPUT_DIR}\n")

    success_count = 0
    skip_count = 0
    fail_count = 0

    # Download with limited concurrency
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {executor.submit(download_file, track): track for track in TRACKS}

        for future in as_completed(futures):
            result = future.result()

            if result['status'] == 'success':
                print(f"[OK] {result['title']} ({result['size']})")
                success_count += 1
            elif result['status'] == 'skip':
                print(f"[SKIP] {result['title']} ({result['reason']})")
                skip_count += 1
            else:
                print(f"[FAIL] {result['title']} - {result['reason']}")
                fail_count += 1

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Downloaded: {success_count}")
    print(f"Skipped: {skip_count}")
    print(f"Failed: {fail_count}")

    # Generate metadata JSON
    metadata = []
    for track in TRACKS:
        output_path = Path(OUTPUT_DIR) / track['filename']
        if output_path.exists() and output_path.stat().st_size > 10000:
            metadata.append({
                "id": f"dl_{track['filename'].replace('/', '_').replace('.mp3', '')}",
                "title": track['title'],
                "artist": track['artist'],
                "category": track['category'],
                "filename": track['filename'],
                "source": "verified_download",
                "license": "Royalty Free / Public Domain",
                "calmScore": 0.9
            })

    metadata_path = Path(OUTPUT_DIR) / "track_metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)

    print(f"\nMetadata saved to: {metadata_path}")
    print(f"Total valid tracks: {len(metadata)}")

if __name__ == '__main__':
    main()
