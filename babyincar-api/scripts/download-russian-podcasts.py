#!/usr/bin/env python3
"""
Russian Podcast Downloader for Baby in Car App
Downloads Russian language audio content: fairy tales, lullabies, children's stories

Sources:
- Internet Archive (archive.org) - Russian Fairy Tales LibriVox recordings
- Direct links to public domain Russian content
"""

import os
import json
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path

# Configuration
OUTPUT_BASE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
PODCAST_DIR = os.path.join(OUTPUT_BASE, "podcasts")
DOWNLOAD_DELAY = 1.5  # seconds between downloads

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ============================================
# RUSSIAN FAIRY TALES FROM INTERNET ARCHIVE
# These are actual Russian language recordings from LibriVox
# Collection: Народные русские сказки (Russian Folk Tales) by A.N. Afanasyev
# ============================================

# Russian Fairy Tales Vol 1 (Read in Russian by LibriVox volunteers)
# Collection ID: russianfairytales1_2007_librivox
RUSSIAN_FAIRY_TALES_VOL1 = [
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_01_afanasyev_128kb.mp3", "title": "Лисичка-сестричка и волк", "num": 1},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_02_afanasyev_128kb.mp3", "title": "Кот, петух и лиса", "num": 2},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_03_afanasyev_128kb.mp3", "title": "Волк и коза", "num": 3},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_04_afanasyev_128kb.mp3", "title": "Курочка Ряба", "num": 4},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_05_afanasyev_128kb.mp3", "title": "Репка", "num": 5},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_06_afanasyev_128kb.mp3", "title": "Теремок", "num": 6},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_07_afanasyev_128kb.mp3", "title": "Колобок", "num": 7},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_08_afanasyev_128kb.mp3", "title": "Маша и медведь", "num": 8},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_09_afanasyev_128kb.mp3", "title": "Гуси-лебеди", "num": 9},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_10_afanasyev_128kb.mp3", "title": "Морозко", "num": 10},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_11_afanasyev_128kb.mp3", "title": "Снегурочка", "num": 11},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_12_afanasyev_128kb.mp3", "title": "Сестрица Алёнушка и братец Иванушка", "num": 12},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_13_afanasyev_128kb.mp3", "title": "Царевна-лягушка", "num": 13},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_14_afanasyev_128kb.mp3", "title": "Иван-царевич и серый волк", "num": 14},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_15_afanasyev_128kb.mp3", "title": "Сивка-Бурка", "num": 15},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_16_afanasyev_128kb.mp3", "title": "По щучьему веленью", "num": 16},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_17_afanasyev_128kb.mp3", "title": "Финист ясный сокол", "num": 17},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_18_afanasyev_128kb.mp3", "title": "Василиса Прекрасная", "num": 18},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_19_afanasyev_128kb.mp3", "title": "Марья Моревна", "num": 19},
    {"url": "https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_20_afanasyev_128kb.mp3", "title": "Кощей Бессмертный", "num": 20},
]

# Russian Fairy Tales Vol 2 (More tales read in Russian)
# Collection ID: russianfairytales2_2103_librivox
RUSSIAN_FAIRY_TALES_VOL2 = [
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_01_afanasyev_128kb.mp3", "title": "Баба-Яга", "num": 1},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_02_afanasyev_128kb.mp3", "title": "Жар-птица и Василиса-царевна", "num": 2},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_03_afanasyev_128kb.mp3", "title": "Крошечка-Хаврошечка", "num": 3},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_04_afanasyev_128kb.mp3", "title": "Иванушка-дурачок", "num": 4},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_05_afanasyev_128kb.mp3", "title": "Летучий корабль", "num": 5},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_06_afanasyev_128kb.mp3", "title": "Мальчик с пальчик", "num": 6},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_07_afanasyev_128kb.mp3", "title": "Никита Кожемяка", "num": 7},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_08_afanasyev_128kb.mp3", "title": "Петушок - золотой гребешок", "num": 8},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_09_afanasyev_128kb.mp3", "title": "Три медведя", "num": 9},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_10_afanasyev_128kb.mp3", "title": "Заюшкина избушка", "num": 10},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_11_afanasyev_128kb.mp3", "title": "Лиса и журавль", "num": 11},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_12_afanasyev_128kb.mp3", "title": "Пузырь, соломинка и лапоть", "num": 12},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_13_afanasyev_128kb.mp3", "title": "Бычок - смоляной бочок", "num": 13},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_14_afanasyev_128kb.mp3", "title": "Волшебное кольцо", "num": 14},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_15_afanasyev_128kb.mp3", "title": "Каша из топора", "num": 15},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_16_afanasyev_128kb.mp3", "title": "Петух и жерновцы", "num": 16},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_17_afanasyev_128kb.mp3", "title": "Скатерть, баранчик и сума", "num": 17},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_18_afanasyev_128kb.mp3", "title": "Солнце, Месяц и Ворон", "num": 18},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_19_afanasyev_128kb.mp3", "title": "Хрустальная гора", "num": 19},
    {"url": "https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_20_afanasyev_128kb.mp3", "title": "Чудесная рубашка", "num": 20},
]

# Additional Russian content from other LibriVox collections
ADDITIONAL_RUSSIAN = [
    # Russian Fairy Tales read in English (for bilingual families)
    {"url": "https://archive.org/download/russianfairytales_1505_librivox/russianfairytales_01_polevoi_128kb.mp3", "title": "Russian Fairy Tales - Baba Yaga (English)", "num": 1, "lang": "en"},
    {"url": "https://archive.org/download/russianfairytales_1505_librivox/russianfairytales_02_polevoi_128kb.mp3", "title": "Russian Fairy Tales - Koshchey the Deathless (English)", "num": 2, "lang": "en"},
    {"url": "https://archive.org/download/russianfairytales_1505_librivox/russianfairytales_03_polevoi_128kb.mp3", "title": "Russian Fairy Tales - The Firebird (English)", "num": 3, "lang": "en"},
    {"url": "https://archive.org/download/russianfairytales_1505_librivox/russianfairytales_04_polevoi_128kb.mp3", "title": "Russian Fairy Tales - Vasilisa the Beautiful (English)", "num": 4, "lang": "en"},
    {"url": "https://archive.org/download/russianfairytales_1505_librivox/russianfairytales_05_polevoi_128kb.mp3", "title": "Russian Fairy Tales - The Frog Princess (English)", "num": 5, "lang": "en"},
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
    import re
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    name = re.sub(r'\s+', '_', name)
    name = name[:80]
    return name.lower()

def main():
    print("="*60)
    print("RUSSIAN PODCAST DOWNLOADER FOR BABY IN CAR APP")
    print("="*60)

    # Create directories
    russian_dir = os.path.join(PODCAST_DIR, "ru", "russian_fairy_tales")
    english_dir = os.path.join(PODCAST_DIR, "en", "russian_fairy_tales_english")
    os.makedirs(russian_dir, exist_ok=True)
    os.makedirs(english_dir, exist_ok=True)

    metadata_list = []
    total_downloaded = 0

    # Download Russian Fairy Tales Vol 1
    print("\n" + "="*40)
    print("Russian Fairy Tales Vol 1 (Russian Language)")
    print("="*40)

    for tale in RUSSIAN_FAIRY_TALES_VOL1:
        safe_title = sanitize_filename(tale['title'])
        filename = f"ru_fairytale_v1_{tale['num']:02d}_{safe_title}.mp3"
        output_path = os.path.join(russian_dir, filename)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {tale['title']}")
            continue

        print(f"[DL] {tale['title']}...")

        size, error = download_file(tale['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"ru_fairytale_v1_{tale['num']:02d}",
                "title": tale['title'],
                "title_en": f"Russian Fairy Tale {tale['num']}",
                "artist": "LibriVox Russia",
                "language": "ru",
                "category": "russian_fairy_tales",
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

    # Download Russian Fairy Tales Vol 2
    print("\n" + "="*40)
    print("Russian Fairy Tales Vol 2 (Russian Language)")
    print("="*40)

    for tale in RUSSIAN_FAIRY_TALES_VOL2:
        safe_title = sanitize_filename(tale['title'])
        filename = f"ru_fairytale_v2_{tale['num']:02d}_{safe_title}.mp3"
        output_path = os.path.join(russian_dir, filename)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {tale['title']}")
            continue

        print(f"[DL] {tale['title']}...")

        size, error = download_file(tale['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"ru_fairytale_v2_{tale['num']:02d}",
                "title": tale['title'],
                "title_en": f"Russian Fairy Tale {tale['num'] + 20}",
                "artist": "LibriVox Russia",
                "language": "ru",
                "category": "russian_fairy_tales",
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

    # Download English versions for bilingual families
    print("\n" + "="*40)
    print("Russian Fairy Tales (English translations)")
    print("="*40)

    for tale in ADDITIONAL_RUSSIAN:
        safe_title = sanitize_filename(tale['title'])
        filename = f"ru_fairytale_en_{tale['num']:02d}_{safe_title}.mp3"
        output_path = os.path.join(english_dir, filename)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            print(f"[SKIP] {tale['title']}")
            continue

        print(f"[DL] {tale['title']}...")

        size, error = download_file(tale['url'], output_path)

        if size:
            metadata_list.append({
                "id": f"ru_fairytale_en_{tale['num']:02d}",
                "title": tale['title'],
                "artist": "LibriVox",
                "language": "en",
                "category": "russian_fairy_tales_english",
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

    # Save metadata
    metadata_file = os.path.join(OUTPUT_BASE, "russian_podcast_metadata.json")
    with open(metadata_file, 'w', encoding='utf-8') as f:
        json.dump(metadata_list, f, indent=2, ensure_ascii=False)

    # Summary
    print("\n" + "="*60)
    print("DOWNLOAD COMPLETE")
    print("="*60)
    print(f"Total downloaded: {total_downloaded}")
    print(f"Total in metadata: {len(metadata_list)}")
    print(f"Metadata saved to: {metadata_file}")

    ru_count = sum(1 for m in metadata_list if m.get('language') == 'ru')
    en_count = sum(1 for m in metadata_list if m.get('language') == 'en')
    print(f"\nBy language:")
    print(f"  Russian: {ru_count}")
    print(f"  English: {en_count}")

if __name__ == '__main__':
    main()
