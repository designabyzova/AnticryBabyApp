#!/usr/bin/env python3
"""
Suno AI Music Generator for Baby in Car App
Generates original music using Suno AI

IMPORTANT: Suno doesn't have an official public API.
Use one of these third-party options:

1. SunoAPI.org - https://sunoapi.org/
2. AIMLAPI - https://aimlapi.com/suno-ai-api
3. PiAPI - https://piapi.ai/suno-v5

Each provider has different pricing and features.
This script supports multiple providers.
"""

import os
import json
import time
import requests
from pathlib import Path

# Configuration
SUNO_API_KEY = os.environ.get('SUNO_API_KEY', '')
SUNO_API_PROVIDER = os.environ.get('SUNO_API_PROVIDER', 'sunoapi')  # sunoapi, aimlapi, piapi

OUTPUT_DIR = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/generated'
METADATA_FILE = '/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/scripts/suno-metadata.json'

# Generation prompts
GENERATION_PROMPTS = [
  {
    "id": "suno_lull_001",
    "prompt": "Gentle piano lullaby, soft and soothing, perfect for baby sleep, 60 bpm, major key, no vocals",
    "category": "lullabies",
    "subcategory": "piano",
    "tags": [
      "piano",
      "lullaby",
      "gentle",
      "sleep"
    ]
  },
  {
    "id": "suno_lull_002",
    "prompt": "Soft music box melody, twinkly and delicate, bedtime music for babies, simple harmony",
    "category": "lullabies",
    "subcategory": "music_box",
    "tags": [
      "music box",
      "delicate",
      "bedtime"
    ]
  },
  {
    "id": "suno_lull_003",
    "prompt": "Warm acoustic guitar lullaby, fingerpicked, dreamy and peaceful, 55 bpm",
    "category": "lullabies",
    "subcategory": "guitar",
    "tags": [
      "guitar",
      "acoustic",
      "peaceful"
    ]
  },
  {
    "id": "suno_lull_004",
    "prompt": "Harp lullaby with soft strings, angelic and ethereal, slow tempo, for infant sleep",
    "category": "lullabies",
    "subcategory": "harp",
    "tags": [
      "harp",
      "strings",
      "ethereal"
    ]
  },
  {
    "id": "suno_lull_005",
    "prompt": "Orchestral lullaby with strings and woodwinds, romantic era style, calm and beautiful",
    "category": "lullabies",
    "subcategory": "orchestral",
    "tags": [
      "orchestral",
      "strings",
      "romantic"
    ]
  },
  {
    "id": "suno_class_001",
    "prompt": "Peaceful piano piece in the style of Debussy, impressionistic, water-like arpeggios",
    "category": "classical",
    "subcategory": "piano",
    "tags": [
      "piano",
      "impressionist",
      "peaceful"
    ]
  },
  {
    "id": "suno_class_002",
    "prompt": "Gentle string quartet, adagio tempo, reminiscent of Barber, deeply emotional",
    "category": "classical",
    "subcategory": "strings",
    "tags": [
      "strings",
      "quartet",
      "adagio"
    ]
  },
  {
    "id": "suno_class_003",
    "prompt": "Solo cello piece, warm and expressive, Bach-inspired, baroque ornamentation",
    "category": "classical",
    "subcategory": "cello",
    "tags": [
      "cello",
      "solo",
      "baroque"
    ]
  },
  {
    "id": "suno_class_004",
    "prompt": "Piano and violin duet, romantic and tender, Chopin-esque nocturne style",
    "category": "classical",
    "subcategory": "duet",
    "tags": [
      "piano",
      "violin",
      "romantic"
    ]
  },
  {
    "id": "suno_class_005",
    "prompt": "Minimalist piano piece, Satie style, sparse and meditative, repeating patterns",
    "category": "classical",
    "subcategory": "piano",
    "tags": [
      "piano",
      "minimalist",
      "meditative"
    ]
  },
  {
    "id": "suno_nature_001",
    "prompt": "Ambient music with rain sounds, piano, very calm, spa-like, 50 bpm",
    "category": "ambient",
    "subcategory": "rain",
    "tags": [
      "rain",
      "piano",
      "spa"
    ]
  },
  {
    "id": "suno_nature_002",
    "prompt": "Ocean waves with soft synthesizer pads, new age style, deeply relaxing",
    "category": "ambient",
    "subcategory": "ocean",
    "tags": [
      "ocean",
      "synth",
      "new age"
    ]
  },
  {
    "id": "suno_nature_003",
    "prompt": "Forest ambience with gentle flute melody, birds singing, nature soundscape music",
    "category": "ambient",
    "subcategory": "forest",
    "tags": [
      "forest",
      "flute",
      "birds"
    ]
  },
  {
    "id": "suno_nature_004",
    "prompt": "Soft wind sounds with hang drum, meditative and grounding, slow tempo",
    "category": "ambient",
    "subcategory": "wind",
    "tags": [
      "wind",
      "hang drum",
      "meditative"
    ]
  },
  {
    "id": "suno_child_001",
    "prompt": "Happy gentle children song, xylophone and piano, playful but calm, major key",
    "category": "children",
    "subcategory": "playful",
    "tags": [
      "xylophone",
      "playful",
      "happy"
    ]
  },
  {
    "id": "suno_child_002",
    "prompt": "Sweet nursery melody, simple and pure, glockenspiel lead, for toddlers",
    "category": "children",
    "subcategory": "nursery",
    "tags": [
      "glockenspiel",
      "sweet",
      "simple"
    ]
  },
  {
    "id": "suno_child_003",
    "prompt": "Gentle counting song instrumental, educational music for babies, soft tempo",
    "category": "children",
    "subcategory": "educational",
    "tags": [
      "educational",
      "counting",
      "gentle"
    ]
  },
  {
    "id": "suno_ru_001",
    "prompt": "Russian style lullaby, balalaika and strings, melancholic and beautiful, minor key",
    "category": "lullabies",
    "subcategory": "russian",
    "tags": [
      "russian",
      "balalaika",
      "melancholic"
    ]
  },
  {
    "id": "suno_ru_002",
    "prompt": "Traditional Slavic lullaby style, warm female humming, no words, ethnic instruments",
    "category": "lullabies",
    "subcategory": "russian",
    "tags": [
      "slavic",
      "humming",
      "ethnic"
    ]
  },
  {
    "id": "suno_ru_003",
    "prompt": "Russian folk melody arranged as lullaby, gentle domra and bayan accordion, soft",
    "category": "lullabies",
    "subcategory": "russian",
    "tags": [
      "russian",
      "folk",
      "domra"
    ]
  },
  {
    "id": "suno_med_001",
    "prompt": "Deep sleep meditation music, drone sounds with crystal bowls, 432Hz tuning",
    "category": "meditation",
    "subcategory": "sleep",
    "tags": [
      "meditation",
      "crystal bowls",
      "432Hz"
    ]
  },
  {
    "id": "suno_med_002",
    "prompt": "Tibetan singing bowl meditation, slow and resonant, for deep relaxation",
    "category": "meditation",
    "subcategory": "bowls",
    "tags": [
      "tibetan",
      "singing bowl",
      "resonant"
    ]
  },
  {
    "id": "suno_med_003",
    "prompt": "Binaural beats with soft ambient music, delta waves for infant sleep",
    "category": "meditation",
    "subcategory": "binaural",
    "tags": [
      "binaural",
      "delta",
      "sleep"
    ]
  },
  {
    "id": "suno_med_004",
    "prompt": "Yoga nidra background music, extremely slow and peaceful, barely there",
    "category": "meditation",
    "subcategory": "yoga",
    "tags": [
      "yoga",
      "nidra",
      "peaceful"
    ]
  }
]

class SunoAPIClient:
    """Wrapper for different Suno API providers"""

    def __init__(self, api_key: str, provider: str):
        self.api_key = api_key
        self.provider = provider

        # API endpoints for different providers
        self.endpoints = {
            'sunoapi': 'https://api.sunoapi.org/v1/generate',
            'aimlapi': 'https://api.aimlapi.com/suno/generate',
            'piapi': 'https://api.piapi.ai/suno/v5/generate'
        }

    def generate(self, prompt: str, duration: int = 60) -> dict:
        """Generate music from prompt"""
        if self.provider not in self.endpoints:
            raise ValueError(f"Unknown provider: {self.provider}")

        url = self.endpoints[self.provider]

        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

        data = {
            'prompt': prompt,
            'duration': duration,
            'instrumental': True,
            'wait_audio': True
        }

        response = requests.post(url, json=data, headers=headers)

        if response.status_code != 200:
            raise Exception(f"API Error: {response.status_code} - {response.text}")

        return response.json()

    def download(self, audio_url: str, output_path: str) -> bool:
        """Download generated audio"""
        response = requests.get(audio_url, stream=True)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
        return False

def main():
    if not SUNO_API_KEY:
        print("=" * 60)
        print("SUNO API KEY REQUIRED")
        print("=" * 60)
        print("")
        print("Get API key from one of these providers:")
        print("")
        print("1. SunoAPI.org")
        print("   - Sign up: https://sunoapi.org/")
        print("   - Get key from dashboard")
        print("   - export SUNO_API_PROVIDER=sunoapi")
        print("")
        print("2. AIMLAPI")
        print("   - Sign up: https://aimlapi.com/")
        print("   - Get key from dashboard")
        print("   - export SUNO_API_PROVIDER=aimlapi")
        print("")
        print("3. PiAPI")
        print("   - Sign up: https://piapi.ai/")
        print("   - Get key from workspace")
        print("   - export SUNO_API_PROVIDER=piapi")
        print("")
        print("Then set:")
        print("   export SUNO_API_KEY=your_key_here")
        print("")
        return

    print("=" * 60)
    print("Suno AI Music Generator")
    print(f"Provider: {SUNO_API_PROVIDER}")
    print("=" * 60)
    print("")

    # Create output directory
    output_dir = Path(OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)

    client = SunoAPIClient(SUNO_API_KEY, SUNO_API_PROVIDER)
    all_metadata = []
    generated_count = 0

    for prompt_config in GENERATION_PROMPTS:
        prompt_id = prompt_config['id']
        prompt = prompt_config['prompt']
        category = prompt_config['category']
        subcategory = prompt_config['subcategory']
        tags = prompt_config['tags']

        filename = f"{prompt_id}.mp3"
        output_path = output_dir / filename

        # Skip if already exists
        if output_path.exists() and output_path.stat().st_size > 10000:
            print(f"[SKIP] {prompt_id} (already exists)")
            all_metadata.append({
                'id': prompt_id,
                'title': f"Generated: {' '.join(tags[:3])}",
                'artist': 'Suno AI',
                'category': category,
                'subcategory': subcategory,
                'source': 'suno',
                'license': 'AI Generated (Custom)',
                'filename': filename,
                'tags': tags,
                'calmScore': 0.88,
                'prompt': prompt
            })
            continue

        print(f"[GEN] {prompt_id}")
        print(f"      Prompt: {prompt[:60]}...")

        try:
            result = client.generate(prompt, duration=60)
            audio_url = result.get('audio_url')

            if audio_url and client.download(audio_url, str(output_path)):
                print(f"      ✓ Generated successfully")
                generated_count += 1
                all_metadata.append({
                    'id': prompt_id,
                    'title': f"Generated: {' '.join(tags[:3])}",
                    'artist': 'Suno AI',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'suno',
                    'license': 'AI Generated (Custom)',
                    'filename': filename,
                    'tags': tags,
                    'calmScore': 0.88,
                    'prompt': prompt
                })
            else:
                print(f"      ✗ Download failed")
        except Exception as e:
            print(f"      ✗ Error: {e}")

        # Rate limiting - Suno has strict limits
        time.sleep(30)

    # Save metadata
    with open(METADATA_FILE, 'w') as f:
        json.dump(all_metadata, f, indent=2)

    print("")
    print("=" * 60)
    print(f"Generated: {generated_count} tracks")
    print(f"Metadata saved to: {METADATA_FILE}")
    print("=" * 60)

if __name__ == '__main__':
    main()
