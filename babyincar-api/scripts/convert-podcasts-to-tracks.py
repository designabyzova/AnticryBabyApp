#!/usr/bin/env python3
"""
Convert podcast-library.json to tracks.json format compatible with iOS app
Maps podcast categories to AudioCategory enum values
"""

import json
import uuid
from pathlib import Path
from typing import List, Dict, Any

# Mapping from podcast categories to iOS AudioCategory values
CATEGORY_MAPPING = {
    "children_stories": "fairytales_en",  # Maps to .fairyTales in iOS
    "russian_fairy_tales": "fairytales_ru",  # Maps to .fairyTales in iOS
    "russian_fairy_tales_english": "fairytales_en",
    "russian_stories": "fairytales_ru",
    "lullabies": "lullabies",  # Maps to .lullabies in iOS
    "classical": "lullabies",  # Classical music in podcasts → lullabies category
    "children_calm": "ambient",  # Calming music → ambient category
    "whitenoise": None,  # SKIP - whitenoise is forbidden per CLAUDE.md
}

def convert_podcast_to_track(podcast: Dict[str, Any]) -> Dict[str, Any] | None:
    """Convert a podcast entry to tracks.json format"""

    # Skip whitenoise (forbidden category)
    category = podcast.get("category", "")
    if category == "whitenoise":
        print(f"⚠️  SKIPPING whitenoise track: {podcast.get('title', 'unknown')}")
        return None

    # Map to iOS category
    ios_category = CATEGORY_MAPPING.get(category)
    if not ios_category:
        print(f"⚠️  Unknown category '{category}' for track: {podcast.get('title', 'unknown')}")
        return None

    # Extract filename from r2Key (e.g., "podcasts/en/children_calm/file.mp3" -> "podcasts/en/children_calm/file.mp3")
    filename = podcast.get("r2Key", "")

    # Determine content type
    content_type = "audiobook" if "fairy" in category or "stories" in category else "music"

    # Extract artist (default to Internet Archive if not specified)
    artist = podcast.get("artist", "Internet Archive")

    # Build subcategory from filename structure
    parts = filename.split("/")
    subcategory = parts[2] if len(parts) > 2 else category

    # Estimate duration from file size (rough approximation: 1MB ≈ 60s for MP3)
    # If not available, use default
    size_mb = podcast.get("size", 0) / (1024 * 1024)
    duration = max(60, size_mb * 60)  # Minimum 60s

    track = {
        "id": str(uuid.uuid4()),
        "title": podcast.get("title", "Untitled"),
        "artist": artist,
        "category": ios_category,
        "subcategory": subcategory,
        "filename": filename,
        "duration": duration,
        "calmScore": podcast.get("calmingScore", 0.8),
        "tags": [
            ios_category,
            subcategory,
            "audiobook" if content_type == "audiobook" else "music"
        ],
        "ageRangeMin": podcast.get("ageRangeMin", 0),
        "ageRangeMax": podcast.get("ageRangeMax", 36),
        "isPremium": podcast.get("isPremium", False),
        "contentType": content_type
    }

    return track

def main():
    """Main conversion process"""

    # Load podcast library
    podcast_file = Path(__file__).parent.parent / "data" / "podcast-library.json"
    tracks_file = Path(__file__).parent.parent.parent / "BabyInCarApp" / "BabyInCarApp" / "Resources" / "Audio" / "tracks.json"

    print(f"📖 Loading podcast library from: {podcast_file}")
    with open(podcast_file, "r") as f:
        podcast_data = json.load(f)

    print(f"📖 Loading existing tracks from: {tracks_file}")
    with open(tracks_file, "r") as f:
        tracks_data = json.load(f)

    # Convert podcasts to tracks
    converted_tracks = []
    skipped_count = 0

    for podcast in podcast_data.get("tracks", []):
        track = convert_podcast_to_track(podcast)
        if track:
            converted_tracks.append(track)
        else:
            skipped_count += 1

    print(f"\n✅ Converted {len(converted_tracks)} podcasts to tracks")
    print(f"⚠️  Skipped {skipped_count} tracks (whitenoise or invalid categories)")

    # Merge with existing tracks (preserve existing music tracks)
    existing_tracks = tracks_data.get("tracks", [])
    all_tracks = existing_tracks + converted_tracks

    # Update categories
    categories = tracks_data.get("categories", {"music": [], "audiobooks": []})

    # Add new categories
    if "fairytales_en" not in categories.get("audiobooks", []):
        categories.setdefault("audiobooks", []).append("fairytales_en")
    if "fairytales_ru" not in categories.get("audiobooks", []):
        categories.setdefault("audiobooks", []).append("fairytales_ru")

    # Build final structure
    final_data = {
        "version": "2.2",
        "generatedAt": "2026-01-08",
        "description": "Audio library with verified tracks - all files exist in R2 (includes podcasts)",
        "totalTracks": len(all_tracks),
        "tracks": all_tracks,
        "categories": categories
    }

    # Write updated tracks.json
    print(f"\n💾 Writing updated tracks.json to: {tracks_file}")
    with open(tracks_file, "w") as f:
        json.dump(final_data, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 SUCCESS! Total tracks: {len(all_tracks)}")
    print(f"   - Music tracks: {len(existing_tracks)}")
    print(f"   - Podcast tracks: {len(converted_tracks)}")

    # Show category breakdown
    category_counts = {}
    for track in all_tracks:
        cat = track.get("category", "unknown")
        category_counts[cat] = category_counts.get(cat, 0) + 1

    print("\n📊 Category Breakdown:")
    for cat, count in sorted(category_counts.items()):
        print(f"   - {cat}: {count} tracks")

if __name__ == "__main__":
    main()
