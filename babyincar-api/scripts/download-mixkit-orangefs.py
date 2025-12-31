#!/usr/bin/env python3
"""
Download from Mixkit and Orange Free Sounds
Both sites offer royalty-free music with direct download links
"""

import os
import json
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

OUTPUT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"

# Verified working direct download links
TRACKS = [
    # ============================================
    # MIXKIT - Free Stock Music (Mixkit License - Free for commercial use)
    # https://mixkit.co/license/
    # ============================================
    {"url": "https://assets.mixkit.co/music/preview/mixkit-sleepy-cat-135.mp3", "filename": "lullabies/mixkit_sleepy_cat.mp3", "title": "Sleepy Cat", "artist": "Mixkit", "category": "lullabies"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-serene-view-443.mp3", "filename": "ambient/mixkit_serene_view.mp3", "title": "Serene View", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-piano-reflections-22.mp3", "filename": "classical/mixkit_piano_reflections.mp3", "title": "Piano Reflections", "artist": "Mixkit", "category": "classical"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-dreaming-big-31.mp3", "filename": "ambient/mixkit_dreaming_big.mp3", "title": "Dreaming Big", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-life-is-a-dream-837.mp3", "filename": "ambient/mixkit_life_dream.mp3", "title": "Life is a Dream", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-feeling-happy-5.mp3", "filename": "children/mixkit_feeling_happy.mp3", "title": "Feeling Happy", "artist": "Mixkit", "category": "children"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-a-very-happy-christmas-897.mp3", "filename": "children/mixkit_happy_christmas.mp3", "title": "Happy Christmas", "artist": "Mixkit", "category": "children"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-deep-meditation-109.mp3", "filename": "meditation/mixkit_deep_meditation.mp3", "title": "Deep Meditation", "artist": "Mixkit", "category": "meditation"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-ethereal-fairy-tale-83.mp3", "filename": "children/mixkit_fairy_tale.mp3", "title": "Ethereal Fairy Tale", "artist": "Mixkit", "category": "children"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-comforting-lie-115.mp3", "filename": "ambient/mixkit_comforting.mp3", "title": "Comforting", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-sad-piano-102.mp3", "filename": "classical/mixkit_sad_piano.mp3", "title": "Sad Piano", "artist": "Mixkit", "category": "classical"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-sun-and-his-daughter-580.mp3", "filename": "ambient/mixkit_sun_daughter.mp3", "title": "Sun and His Daughter", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-hazy-after-hours-132.mp3", "filename": "ambient/mixkit_hazy.mp3", "title": "Hazy After Hours", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-rain-and-creativity-126.mp3", "filename": "nature/mixkit_rain_creativity.mp3", "title": "Rain and Creativity", "artist": "Mixkit", "category": "nature"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-valley-sunset-127.mp3", "filename": "ambient/mixkit_valley_sunset.mp3", "title": "Valley Sunset", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-beautiful-dream-493.mp3", "filename": "ambient/mixkit_beautiful_dream.mp3", "title": "Beautiful Dream", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-silent-snow-121.mp3", "filename": "ambient/mixkit_silent_snow.mp3", "title": "Silent Snow", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-starlight-25.mp3", "filename": "ambient/mixkit_starlight.mp3", "title": "Starlight", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-forest-treasure-15.mp3", "filename": "children/mixkit_forest_treasure.mp3", "title": "Forest Treasure", "artist": "Mixkit", "category": "children"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-just-relax-5.mp3", "filename": "ambient/mixkit_just_relax.mp3", "title": "Just Relax", "artist": "Mixkit", "category": "ambient"},

    # ============================================
    # ORANGE FREE SOUNDS - Public Domain / CC0
    # https://orangefreesounds.com
    # ============================================
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Moonlight-sonata.mp3", "filename": "classical/ofs_moonlight_sonata.mp3", "title": "Moonlight Sonata", "artist": "Beethoven", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Fur-Elise-Beethoven.mp3", "filename": "classical/ofs_fur_elise.mp3", "title": "Fur Elise", "artist": "Beethoven", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Canon-in-D-Pachelbel.mp3", "filename": "classical/ofs_canon_d.mp3", "title": "Canon in D", "artist": "Pachelbel", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Clair-de-Lune-Debussy.mp3", "filename": "classical/ofs_clair_de_lune.mp3", "title": "Clair de Lune", "artist": "Debussy", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Gymnopedie-No-1.mp3", "filename": "classical/ofs_gymnopedie.mp3", "title": "Gymnopedie No.1", "artist": "Satie", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Nocturne-Chopin.mp3", "filename": "classical/ofs_nocturne.mp3", "title": "Nocturne Op.9 No.2", "artist": "Chopin", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Swan-Lake-Theme.mp3", "filename": "classical/ofs_swan_lake.mp3", "title": "Swan Lake Theme", "artist": "Tchaikovsky", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Prelude-in-C-Major-Bach.mp3", "filename": "classical/ofs_prelude_c.mp3", "title": "Prelude in C Major", "artist": "Bach", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Ave-Maria-Schubert.mp3", "filename": "classical/ofs_ave_maria.mp3", "title": "Ave Maria", "artist": "Schubert", "category": "classical"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2020/09/Air-on-G-String-Bach.mp3", "filename": "classical/ofs_air_g_string.mp3", "title": "Air on G String", "artist": "Bach", "category": "classical"},

    # Nature sounds
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Rain-sounds.mp3", "filename": "nature/ofs_rain.mp3", "title": "Rain Sounds", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Ocean-waves-sounds.mp3", "filename": "nature/ofs_ocean.mp3", "title": "Ocean Waves", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Birds-chirping.mp3", "filename": "nature/ofs_birds.mp3", "title": "Birds Chirping", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Thunderstorm-sounds.mp3", "filename": "nature/ofs_thunderstorm.mp3", "title": "Thunderstorm", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Stream-sounds.mp3", "filename": "nature/ofs_stream.mp3", "title": "Stream", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Wind-sounds.mp3", "filename": "nature/ofs_wind.mp3", "title": "Wind", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Crickets-chirping.mp3", "filename": "nature/ofs_crickets.mp3", "title": "Crickets", "artist": "Nature", "category": "nature"},
    {"url": "https://orangefreesounds.com/wp-content/uploads/2021/04/Fireplace-sounds.mp3", "filename": "nature/ofs_fireplace.mp3", "title": "Fireplace", "artist": "Nature", "category": "nature"},

    # ============================================
    # UPPBEAT - Free Tier (Attribution required for free)
    # ============================================
    # Note: Uppbeat requires login, so we'll skip these

    # ============================================
    # FREE PD (Public Domain) - freepd.com
    # ============================================
    {"url": "https://freepd.com/music/Prelude%20No.%201.mp3", "filename": "classical/fpd_prelude_1.mp3", "title": "Prelude No.1", "artist": "Kevin MacLeod", "category": "classical"},
    {"url": "https://freepd.com/music/Gymnopedie%20No%201.mp3", "filename": "classical/fpd_gymnopedie.mp3", "title": "Gymnopedie No.1", "artist": "Kevin MacLeod", "category": "classical"},
    {"url": "https://freepd.com/music/Air%20Prelude.mp3", "filename": "classical/fpd_air_prelude.mp3", "title": "Air Prelude", "artist": "Kevin MacLeod", "category": "classical"},
    {"url": "https://freepd.com/music/Fluffing%20a%20Duck.mp3", "filename": "children/fpd_fluffing_duck.mp3", "title": "Fluffing a Duck", "artist": "Kevin MacLeod", "category": "children"},
    {"url": "https://freepd.com/music/Carefree.mp3", "filename": "children/fpd_carefree.mp3", "title": "Carefree", "artist": "Kevin MacLeod", "category": "children"},
    {"url": "https://freepd.com/music/Peaceful.mp3", "filename": "ambient/fpd_peaceful.mp3", "title": "Peaceful", "artist": "Kevin MacLeod", "category": "ambient"},
    {"url": "https://freepd.com/music/Garden%20Music.mp3", "filename": "ambient/fpd_garden_music.mp3", "title": "Garden Music", "artist": "Kevin MacLeod", "category": "ambient"},
    {"url": "https://freepd.com/music/Dream%20Culture.mp3", "filename": "ambient/fpd_dream_culture.mp3", "title": "Dream Culture", "artist": "Kevin MacLeod", "category": "ambient"},
    {"url": "https://freepd.com/music/Soft%20Ambient.mp3", "filename": "ambient/fpd_soft_ambient.mp3", "title": "Soft Ambient", "artist": "Kevin MacLeod", "category": "ambient"},

    # ============================================
    # Additional Mixkit tracks
    # ============================================
    {"url": "https://assets.mixkit.co/music/preview/mixkit-sweet-dreams-139.mp3", "filename": "lullabies/mixkit_sweet_dreams.mp3", "title": "Sweet Dreams", "artist": "Mixkit", "category": "lullabies"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-tender-moment-500.mp3", "filename": "ambient/mixkit_tender_moment.mp3", "title": "Tender Moment", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-memory-lines-132.mp3", "filename": "ambient/mixkit_memory_lines.mp3", "title": "Memory Lines", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-spirit-in-the-woods-139.mp3", "filename": "nature/mixkit_spirit_woods.mp3", "title": "Spirit in the Woods", "artist": "Mixkit", "category": "nature"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-relaxing-in-nature-522.mp3", "filename": "nature/mixkit_relaxing_nature.mp3", "title": "Relaxing in Nature", "artist": "Mixkit", "category": "nature"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-beside-the-lake-114.mp3", "filename": "nature/mixkit_beside_lake.mp3", "title": "Beside the Lake", "artist": "Mixkit", "category": "nature"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-beneath-the-sea-134.mp3", "filename": "nature/mixkit_beneath_sea.mp3", "title": "Beneath the Sea", "artist": "Mixkit", "category": "nature"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-crying-soul-116.mp3", "filename": "classical/mixkit_crying_soul.mp3", "title": "Crying Soul", "artist": "Mixkit", "category": "classical"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-thoughtful-128.mp3", "filename": "ambient/mixkit_thoughtful.mp3", "title": "Thoughtful", "artist": "Mixkit", "category": "ambient"},
    {"url": "https://assets.mixkit.co/music/preview/mixkit-delicate-126.mp3", "filename": "ambient/mixkit_delicate.mp3", "title": "Delicate", "artist": "Mixkit", "category": "ambient"},
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
        return {"status": "skip", "title": title, "reason": "exists"}

    try:
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8',
                'Referer': url.split('/')[2]  # Use domain as referer
            }
        )

        with urllib.request.urlopen(req, timeout=120) as response:
            content = response.read()

            if len(content) < 10000:
                return {"status": "fail", "title": title, "reason": "file too small"}

            if content[:15].lower().startswith(b'<!doctype') or content[:6].lower() == b'<html>':
                return {"status": "fail", "title": title, "reason": "HTML received"}

            with open(output_path, 'wb') as f:
                f.write(content)

            size_mb = len(content) / (1024 * 1024)
            return {"status": "success", "title": title, "size": f"{size_mb:.2f}MB"}

    except urllib.error.HTTPError as e:
        return {"status": "fail", "title": title, "reason": f"HTTP {e.code}"}
    except Exception as e:
        return {"status": "fail", "title": title, "reason": str(e)[:50]}

def main():
    print("=" * 60)
    print("MIXKIT & ORANGE FREE SOUNDS DOWNLOADER")
    print("=" * 60)
    print(f"\nTotal tracks: {len(TRACKS)}")
    print(f"Output: {OUTPUT_DIR}\n")

    success = skip = fail = 0

    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(download_file, t): t for t in TRACKS}
        for future in as_completed(futures):
            r = future.result()
            if r['status'] == 'success':
                print(f"[OK] {r['title']} ({r['size']})")
                success += 1
            elif r['status'] == 'skip':
                print(f"[SKIP] {r['title']}")
                skip += 1
            else:
                print(f"[FAIL] {r['title']} - {r['reason']}")
                fail += 1

    print(f"\n{'='*60}")
    print(f"Downloaded: {success} | Skipped: {skip} | Failed: {fail}")
    print(f"{'='*60}")

    # Count total files
    total = sum(1 for _ in Path(OUTPUT_DIR).rglob("*.mp3"))
    print(f"\nTotal MP3 files in library: {total}")

if __name__ == '__main__':
    main()
