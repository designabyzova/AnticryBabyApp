#!/usr/bin/env python3
"""
Generate SQL seed file for podcast tracks
Reads the podcast-library.json and generates INSERT statements for the D1 database
"""

import os
import json
import uuid
from datetime import datetime, timezone

# Paths
METADATA_FILE = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/data/podcast-library.json"
OUTPUT_SQL = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/migrations/007_podcast_seed.sql"

# Category mapping from podcast categories to database categories
CATEGORY_MAP = {
    'children_calm': 'podcasts',
    'children_stories': 'fairy_tales',
    'lullabies': 'instrumental',
    'russian_fairy_tales': 'fairy_tales',
    'russian_stories': 'fairy_tales',
    'mindfulness': 'podcasts',
    'sleep_sounds': 'white_noise',
    'classical': 'classical_music',
    'whitenoise': 'white_noise',
    'sleep': 'white_noise',
}

def escape_sql(s):
    """Escape single quotes for SQL"""
    if s is None:
        return ''
    return str(s).replace("'", "''")

def main():
    # Load metadata
    with open(METADATA_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    tracks = data.get('tracks', [])
    public_url = data.get('publicUrl', 'https://pub-1364b528762500de4f870e064229d443.r2.dev')

    print(f"Processing {len(tracks)} podcast tracks...")

    # Generate SQL
    sql_lines = [
        "-- Migration 007: Seed podcast tracks",
        f"-- Generated at: {datetime.now(timezone.utc).isoformat()}",
        f"-- Total tracks: {len(tracks)}",
        "",
        "-- Delete existing podcast tracks to avoid duplicates",
        "DELETE FROM tracks WHERE audio_source_type = 'streamed' AND source = 'podcast';",
        "",
        "-- Insert podcast tracks",
    ]

    for track in tracks:
        track_id = track.get('id', str(uuid.uuid4()))
        title = escape_sql(track.get('title', 'Unknown'))[:200]
        artist = escape_sql(track.get('artist', 'Unknown'))[:100]
        language = track.get('language', 'en')
        category = CATEGORY_MAP.get(track.get('category', 'misc'), 'podcasts')
        stream_url = escape_sql(track.get('streamUrl', ''))
        file_size = track.get('size', 0)

        # Estimate duration from file size (rough estimate: 1MB = ~1 minute for MP3)
        estimated_duration = max(60, file_size // (128 * 1024 // 8))  # 128kbps

        calming_score = track.get('calmingScore', 0.8)
        age_min = track.get('ageRangeMin', 0)
        age_max = track.get('ageRangeMax', 36)
        is_premium = 1 if track.get('isPremium', False) else 0

        sql = f"""INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at, updated_at)
VALUES ('{track_id}', '{title}', '{artist}', '{category}', '{language}', {estimated_duration}, {calming_score}, {age_min}, {age_max}, 'streamed', '{stream_url}', {is_premium}, 'podcast', datetime('now'), datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url, updated_at = datetime('now');"""

        sql_lines.append(sql)
        sql_lines.append("")

    # Add podcast metadata entries
    sql_lines.append("-- Insert podcast metadata")
    for track in tracks:
        track_id = track.get('id', str(uuid.uuid4()))
        source = escape_sql(track.get('source', 'podcast'))
        license_type = escape_sql(track.get('license', 'Public Domain'))
        r2_key = escape_sql(track.get('r2Key', ''))
        local_path = escape_sql(track.get('localPath', ''))

        sql = f"""INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('{track_id}', '{source}', '{license_type}', '{r2_key}', '{local_path}', datetime('now'))
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');"""

        sql_lines.append(sql)
        sql_lines.append("")

    # Write SQL file
    with open(OUTPUT_SQL, 'w', encoding='utf-8') as f:
        f.write('\n'.join(sql_lines))

    print(f"Generated SQL seed: {OUTPUT_SQL}")

    # Summary
    lang_counts = {}
    cat_counts = {}
    for track in tracks:
        lang = track.get('language', 'en')
        cat = track.get('category', 'misc')
        lang_counts[lang] = lang_counts.get(lang, 0) + 1
        cat_counts[cat] = cat_counts.get(cat, 0) + 1

    print("\nBy Language:")
    for lang, count in sorted(lang_counts.items()):
        print(f"  {lang}: {count}")

    print("\nBy Category:")
    for cat, count in sorted(cat_counts.items()):
        print(f"  {cat}: {count}")

if __name__ == '__main__':
    main()
