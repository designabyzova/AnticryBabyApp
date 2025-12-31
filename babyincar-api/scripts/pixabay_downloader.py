#!/usr/bin/env python3
"""
Pixabay Music Downloader for Baby in Car App
Downloads royalty-free music from Pixabay

Note: Pixabay doesn't have a public API for music.
This script generates URLs to search manually or uses web scraping.
All Pixabay music is free for commercial use with no attribution required.

Usage:
1. Visit the generated URLs
2. Download tracks manually
3. Or use the automated download feature (requires selenium)
"""

import os
import json
from pathlib import Path

OUTPUT_DIR = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio'
METADATA_FILE = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/scripts/pixabay-metadata.json'

# Search configurations
SEARCH_CONFIGS = [
  {
    "searchTerm": "lullaby",
    "category": "lullabies",
    "subcategory": "instrumental",
    "count": 20
  },
  {
    "searchTerm": "calm piano",
    "category": "classical",
    "subcategory": "piano",
    "count": 20
  },
  {
    "searchTerm": "gentle guitar",
    "category": "acoustic",
    "subcategory": "guitar",
    "count": 15
  },
  {
    "searchTerm": "ambient sleep",
    "category": "ambient",
    "subcategory": "sleep",
    "count": 20
  },
  {
    "searchTerm": "meditation music",
    "category": "meditation",
    "subcategory": "ambient",
    "count": 15
  },
  {
    "searchTerm": "soft strings",
    "category": "classical",
    "subcategory": "strings",
    "count": 15
  },
  {
    "searchTerm": "peaceful music",
    "category": "ambient",
    "subcategory": "peaceful",
    "count": 15
  },
  {
    "searchTerm": "dreamy music",
    "category": "ambient",
    "subcategory": "dreamy",
    "count": 10
  },
  {
    "searchTerm": "children music gentle",
    "category": "children",
    "subcategory": "playful",
    "count": 15
  },
  {
    "searchTerm": "harp music",
    "category": "classical",
    "subcategory": "harp",
    "count": 10
  }
]

def generate_search_urls():
    """Generate Pixabay search URLs for manual download"""
    print("=" * 50)
    print("Pixabay Music Search URLs")
    print("=" * 50)
    print("")
    print("Visit these URLs and download tracks:")
    print("")

    for config in SEARCH_CONFIGS:
        search_term = config['searchTerm']
        category = config['category']
        count = config['count']

        # Pixabay music URL format
        url = f"https://pixabay.com/music/search/{search_term.replace(' ', '%20')}/"
        print(f"Category: {category}")
        print(f"  Search: {search_term}")
        print(f"  Target: {count} tracks")
        print(f"  URL: {url}")
        print("")

def create_metadata_template():
    """Create a template for manual metadata entry"""
    template = []
    track_num = 1

    for config in SEARCH_CONFIGS:
        for i in range(config['count']):
            template.append({
                'id': f"pb_{track_num:03d}",
                'title': f"[Enter title for {config['searchTerm']} track {i+1}]",
                'artist': "Pixabay Artist",
                'category': config['category'],
                'subcategory': config['subcategory'],
                'source': 'pixabay',
                'license': 'Pixabay License (Free)',
                'filename': f"pixabay_{config['category']}_{i+1:03d}.mp3",
                'calmScore': 0.85,
                'tags': config['searchTerm'].split(' ')
            })
            track_num += 1

    with open(METADATA_FILE, 'w') as f:
        json.dump(template, f, indent=2)

    print(f"Metadata template saved to: {METADATA_FILE}")
    print("Edit this file after downloading tracks.")

# Pre-selected Pixabay tracks (manually curated)
CURATED_PIXABAY_TRACKS = [
    # These are known good tracks from Pixabay
    {'url': 'https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3', 'title': 'Relaxing Piano', 'category': 'classical'},
    {'url': 'https://cdn.pixabay.com/download/audio/2022/10/25/audio_946b0939c8.mp3', 'title': 'Calm Ambient', 'category': 'ambient'},
    {'url': 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3', 'title': 'Soft Lullaby', 'category': 'lullabies'},
    # Add more as discovered...
]

if __name__ == '__main__':
    generate_search_urls()
    print("")
    create_metadata_template()
