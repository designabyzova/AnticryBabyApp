#!/usr/bin/env python3
"""
Add public domain children's songs to tracks.json
These will use AI-generated audio (AudioEngine.generateLullaby with specific patterns)
"""

import json
import uuid
from pathlib import Path
from typing import List, Dict, Any

# Public domain children's songs (traditional, pre-1926)
CHILDREN_SONGS = [
    {
        "title": "Twinkle Twinkle Little Star",
        "artist": "Traditional",
        "duration": 120,
        "calmScore": 0.95,
        "subcategory": "nursery_rhyme",
        "tags": ["lullaby", "nursery_rhyme", "bedtime"]
    },
    {
        "title": "Mary Had a Little Lamb",
        "artist": "Traditional",
        "duration": 90,
        "calmScore": 0.85,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "playful", "children"]
    },
    {
        "title": "Rock-a-Bye Baby",
        "artist": "Traditional",
        "duration": 110,
        "calmScore": 0.97,
        "subcategory": "lullaby",
        "tags": ["lullaby", "bedtime", "calming"]
    },
    {
        "title": "Hush Little Baby",
        "artist": "Traditional",
        "duration": 130,
        "calmScore": 0.96,
        "subcategory": "lullaby",
        "tags": ["lullaby", "bedtime", "soothing"]
    },
    {
        "title": "Baa Baa Black Sheep",
        "artist": "Traditional",
        "duration": 85,
        "calmScore": 0.82,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "educational", "children"]
    },
    {
        "title": "Row Row Row Your Boat",
        "artist": "Traditional",
        "duration": 75,
        "calmScore": 0.80,
        "subcategory": "action_song",
        "tags": ["action_song", "playful", "children"]
    },
    {
        "title": "The Wheels on the Bus",
        "artist": "Traditional",
        "duration": 150,
        "calmScore": 0.75,
        "subcategory": "action_song",
        "tags": ["action_song", "vehicle", "playful"]
    },
    {
        "title": "Old MacDonald Had a Farm",
        "artist": "Traditional",
        "duration": 140,
        "calmScore": 0.78,
        "subcategory": "animal_song",
        "tags": ["animal_song", "educational", "farm"]
    },
    {
        "title": "Itsy Bitsy Spider",
        "artist": "Traditional",
        "duration": 95,
        "calmScore": 0.83,
        "subcategory": "action_song",
        "tags": ["action_song", "nature", "playful"]
    },
    {
        "title": "Head Shoulders Knees and Toes",
        "artist": "Traditional",
        "duration": 100,
        "calmScore": 0.70,
        "subcategory": "action_song",
        "tags": ["action_song", "educational", "body_parts"]
    },
    {
        "title": "Five Little Ducks",
        "artist": "Traditional",
        "duration": 120,
        "calmScore": 0.81,
        "subcategory": "counting_song",
        "tags": ["counting_song", "educational", "animals"]
    },
    {
        "title": "London Bridge Is Falling Down",
        "artist": "Traditional",
        "duration": 110,
        "calmScore": 0.79,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "historic", "playful"]
    },
    {
        "title": "Ring Around the Rosie",
        "artist": "Traditional",
        "duration": 80,
        "calmScore": 0.77,
        "subcategory": "game_song",
        "tags": ["game_song", "circle_dance", "playful"]
    },
    {
        "title": "If You're Happy and You Know It",
        "artist": "Traditional",
        "duration": 130,
        "calmScore": 0.72,
        "subcategory": "action_song",
        "tags": ["action_song", "emotions", "interactive"]
    },
    {
        "title": "The Alphabet Song",
        "artist": "Traditional",
        "duration": 95,
        "calmScore": 0.74,
        "subcategory": "educational",
        "tags": ["educational", "alphabet", "learning"]
    },
    {
        "title": "Hickory Dickory Dock",
        "artist": "Traditional",
        "duration": 85,
        "calmScore": 0.82,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "clock", "time"]
    },
    {
        "title": "Humpty Dumpty",
        "artist": "Traditional",
        "duration": 75,
        "calmScore": 0.80,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "classic", "story"]
    },
    {
        "title": "Jack and Jill",
        "artist": "Traditional",
        "duration": 90,
        "calmScore": 0.81,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "classic", "adventure"]
    },
    {
        "title": "Little Miss Muffet",
        "artist": "Traditional",
        "duration": 70,
        "calmScore": 0.78,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "classic", "spider"]
    },
    {
        "title": "Three Blind Mice",
        "artist": "Traditional",
        "duration": 85,
        "calmScore": 0.76,
        "subcategory": "nursery_rhyme",
        "tags": ["nursery_rhyme", "animals", "mice"]
    }
]

def create_children_song_track(song: Dict[str, Any]) -> Dict[str, Any]:
    """Create a track entry for a children's song"""

    # Use AI-generated audio (AudioEngine will generate these at runtime)
    filename = f"generated/children_songs/{song['title'].lower().replace(' ', '_').replace("'", '')}.wav"

    track = {
        "id": str(uuid.uuid4()),
        "title": song["title"],
        "artist": song["artist"],
        "category": "children_songs",
        "subcategory": song["subcategory"],
        "filename": filename,
        "duration": song["duration"],
        "calmScore": song["calmScore"],
        "tags": song["tags"],
        "ageRangeMin": 0,
        "ageRangeMax": 36,
        "isPremium": False,
        "contentType": "music",
        "isGenerated": True  # Flag for AudioEngine to generate this track
    }

    return track

def main():
    """Add children's songs to tracks.json"""

    tracks_file = Path(__file__).parent.parent.parent / "BabyInCarApp" / "BabyInCarApp" / "Resources" / "Audio" / "tracks.json"

    print(f"📖 Loading existing tracks from: {tracks_file}")
    with open(tracks_file, "r") as f:
        tracks_data = json.load(f)

    # Create children's song tracks
    children_tracks = [create_children_song_track(song) for song in CHILDREN_SONGS]

    print(f"✅ Created {len(children_tracks)} children's songs")

    # Merge with existing tracks
    existing_tracks = tracks_data.get("tracks", [])
    all_tracks = existing_tracks + children_tracks

    # Update categories
    categories = tracks_data.get("categories", {"music": [], "audiobooks": []})
    if "children_songs" not in categories.get("music", []):
        categories.setdefault("music", []).append("children_songs")

    # Build final structure
    final_data = {
        "version": "2.3",
        "generatedAt": "2026-01-08",
        "description": "Audio library with verified tracks - includes podcasts and children's songs",
        "totalTracks": len(all_tracks),
        "tracks": all_tracks,
        "categories": categories
    }

    # Write updated tracks.json
    print(f"\n💾 Writing updated tracks.json to: {tracks_file}")
    with open(tracks_file, "w") as f:
        json.dump(final_data, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 SUCCESS! Total tracks: {len(all_tracks)}")
    print(f"   - Previous total: {len(existing_tracks)}")
    print(f"   - Added children's songs: {len(children_tracks)}")

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
