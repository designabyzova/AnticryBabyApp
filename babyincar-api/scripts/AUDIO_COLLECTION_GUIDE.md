# Baby in Car - Audio Collection Guide

## Current Audio Library Status

**Total bundled tracks: ~36 files**
- Classical: 18 tracks
- Lullabies: 6 tracks
- Nature: 5 tracks
- Ambient: 5 tracks
- White Noise: 1 track

All tracks are royalty-free, CC0, or public domain licensed.

---

## How to Add More Tracks

### Option 1: Suno AI (Recommended for Original Music)

Suno AI can generate high-quality, original music. Since there's no official API, use third-party providers:

1. **SunoAPI.org** - https://sunoapi.org/
   - Sign up and get API key
   - Affordable pricing, good reliability

2. **PiAPI** - https://piapi.ai/suno-v5
   - Free credits for new users
   - Supports Suno V5

3. **AIMLAPI** - https://aimlapi.com/suno-ai-api
   - Multiple AI music models

**To use:**
```bash
export SUNO_API_KEY=your_key_here
export SUNO_API_PROVIDER=sunoapi  # or piapi, aimlapi
python3 scripts/suno_generator.py
```

The script contains 25+ prompts optimized for baby lullabies and calming music.

---

### Option 2: Freesound API (CC0 Nature Sounds)

Freesound offers thousands of CC0 licensed audio files.

1. Get API key: https://freesound.org/apiv2/apply/
2. Run the downloader:

```bash
export FREESOUND_API_KEY=your_key_here
python3 scripts/freesound_downloader.py
```

**Best search queries for babies:**
- `rain gentle`
- `ocean waves calm`
- `forest birds morning`
- `white noise sleep`
- `heartbeat calm`
- `music box lullaby`

---

### Option 3: Manual Download from Verified Sources

#### Mixkit (Free, Royalty-Free)
https://mixkit.co/free-stock-music/
- License: Mixkit License (Free for all uses)
- Search: "lullaby", "calm", "meditation"

#### Pixabay Music (Free, No Attribution)
https://pixabay.com/music/
- License: Pixabay License (Free commercial use)
- Search: "baby", "sleep", "gentle piano"

#### Free Music Archive (CC Licensed)
https://freemusicarchive.org/genre/Classical/
- License: Various CC licenses
- Search: Classical genre for public domain

#### Musopen (Public Domain Classical)
https://musopen.org/music/
- License: Public Domain / CC0
- High quality classical recordings

---

### Option 4: Internet Archive (Public Domain)

The Internet Archive has many public domain recordings, but access can be spotty.

**Recommended collections:**
- Baby Einstein Music Box Orchestra
- Brahms Lullaby collections
- Classical music compilations

Direct download script is included but may have availability issues.

---

## File Organization

Place downloaded files in:
```
BabyInCarApp/BabyInCarApp/Resources/Audio/
├── classical/     # Piano, violin, orchestral
├── lullabies/     # Lullabies and bedtime music
├── nature/        # Rain, ocean, birds, etc.
├── ambient/       # Ambient, meditation
├── whitenoise/    # White/pink/brown noise
├── russian/       # Russian language content
└── children/      # Children's songs
```

---

## Adding Tracks to the App

After adding MP3 files, update `ContentLibraryService.swift`:

```swift
// In generateClassicalMusicTracks() or similar function:
let newTracks: [(String, String, String, String, Int, Double)] = [
    ("Track Title", "Artist", "filename", "mp3", 180, 0.90)
]

for (title, artist, fileName, ext, duration, calmingScore) in newTracks {
    if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/subfolder") != nil {
        tracks.append(AudioTrack(
            title: title,
            artist: artist,
            category: .classicalMusic,
            duration: TimeInterval(duration),
            ageRangeMin: 0,
            ageRangeMax: 36,
            calmingScore: calmingScore,
            audioSourceType: .bundled,
            fileName: fileName,
            fileExtension: ext
        ))
    }
}
```

---

## License Compliance

Always verify licensing before including tracks:

| License | Attribution | Commercial | Modify |
|---------|------------|------------|--------|
| Public Domain | No | Yes | Yes |
| CC0 | No | Yes | Yes |
| CC-BY | Yes | Yes | Yes |
| Pixabay | No | Yes | Yes |
| Mixkit | No | Yes | Yes |
| Bensound Free | Yes | Yes | Limited |

**Include attribution in app credits for CC-BY tracks.**

---

## Scripts Available

| Script | Purpose |
|--------|---------|
| `suno_generator.py` | Generate original music via Suno AI |
| `freesound_downloader.py` | Download CC0 sounds from Freesound |
| `pixabay_downloader.py` | Generate Pixabay search URLs |
| `download-verified-tracks.sh` | Download from various sources |
| `mass-audio-collector.ts` | TypeScript bulk downloader |

---

## Recommended Next Steps

1. **Sign up for Suno API** - Generate 50-100 original lullabies
2. **Get Freesound API key** - Download 100+ nature sounds
3. **Manual curation** - Pick 50+ tracks from Pixabay/Mixkit
4. **Test playback** - Verify all tracks work in the app
5. **Optimize file sizes** - Compress to 128kbps for smaller app size

---

## Support

For issues with audio collection:
- Check file format (MP3 required)
- Verify file size (>10KB = valid)
- Ensure proper subdirectory structure
- Update ContentLibraryService.swift after adding files
