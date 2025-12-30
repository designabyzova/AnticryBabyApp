# Audio Content Guide for Baby in Car App

This guide explains how to legally source and generate audio content for the Baby in Car app.

## Overview

The app supports multiple audio sources:
1. **Bundled audio** - MP3 files included in the app bundle
2. **Generated audio** - Programmatically synthesized sounds (white noise, nature sounds)
3. **Streamed audio** - Audio files served from Cloudflare R2
4. **Text-to-Speech** - Fairy tales generated via TTS
5. **AI-generated music** - Original songs created via AI services

## Legal Content Sources

### 1. Freesound.org (CC0 License)

**Best for:** Nature sounds, ambient audio, sound effects

```bash
# Get API key from https://freesound.org/apiv2/apply

# Run the collector script
cd babyincar-api
FREESOUND_API_KEY=your_key npx ts-node scripts/freesound-russian-collector.ts

# Download preview files
FREESOUND_API_KEY=your_key npx ts-node scripts/freesound-russian-collector.ts --download
```

**License:** CC0 (Creative Commons Zero) - No attribution required, full commercial use allowed.

### 2. Internet Archive (Public Domain)

**Best for:** Classical music recordings

The `audio-collector.ts` script includes an Internet Archive collector:

```bash
npx ts-node scripts/audio-collector.ts --collect
```

**License:** Public Domain - Unrestricted use.

### 3. AI Music Generation (Suno, Udio, etc.)

**Best for:** Original lullabies, children's songs, Russian content

#### Option A: Use our pre-made prompts

```bash
# View all generation prompts
npx ts-node scripts/ai-music-generator.ts --prompts

# Generate metadata and iOS code
npx ts-node scripts/ai-music-generator.ts --metadata
```

#### Option B: Manual generation on Suno.ai

1. Go to [suno.ai](https://suno.ai)
2. Sign up for a subscription ($10-30/month)
3. Use the prompts from our script
4. Download the generated tracks
5. Place files in `BabyInCarApp/Resources/Audio/russian/`

**License:** Full commercial rights with Suno subscription.

### 4. Pixabay Music

**Best for:** Background music, instrumental tracks

Visit [pixabay.com/music](https://pixabay.com/music/) and download manually.

**License:** Pixabay Content License - Free for commercial use, no attribution required.

**Note:** Pixabay API currently only supports images/videos, not music.

## Russian Content Collection

### Freesound Russian Queries

The `freesound-russian-collector.ts` script searches for:

| Category | Russian Queries |
|----------|-----------------|
| Lullabies | колыбельная, баюшки баю, спи малыш |
| Nature | дождь звук, море волны, лес птицы |
| Children's Music | детская музыка, детская песенка |
| White Noise | белый шум, розовый шум |

### AI-Generated Russian Songs

We have prepared 12+ prompts for Russian children's content:

| ID | Title | Type |
|----|-------|------|
| ru_lullaby_01 | Спи, малыш | Lullaby |
| ru_lullaby_02 | Баю-баюшки-баю | Lullaby |
| ru_lullaby_03 | Колыбельная звёзд | Lullaby |
| ru_lullaby_04 | Сладких снов | Lullaby |
| ru_song_01 | Солнышко | Song |
| ru_song_02 | Весёлый дождик | Song |
| ru_song_03 | Маленькая звёздочка | Song |
| ru_calm_01 | Тихий вечер | Instrumental |
| ru_calm_02 | Зимняя сказка | Instrumental |
| ru_calm_03 | Берёзовая роща | Instrumental |
| ru_edu_01 | Ручки-ножки | Educational |
| ru_edu_02 | Пальчики | Educational |

## File Organization

```
BabyInCarApp/
└── Resources/
    └── Audio/
        ├── classical/
        │   ├── calm_piano.mp3
        │   ├── soft_strings.mp3
        │   └── ...
        ├── lullabies/
        │   ├── gentle_melody.mp3
        │   └── ...
        ├── nature/
        │   ├── rain_ambient.mp3
        │   └── ...
        ├── whitenoise/
        │   └── white_noise.mp3
        └── russian/           # NEW
            ├── ru_lullaby_01.mp3
            ├── ru_lullaby_02.mp3
            ├── ru_song_01.mp3
            └── ...
```

## Adding New Audio to the App

### Step 1: Add files to Xcode project

1. Copy MP3 files to appropriate subfolder in `Resources/Audio/`
2. In Xcode, add the folder to the project as a folder reference
3. Ensure it's included in "Copy Bundle Resources" build phase

### Step 2: Update ContentLibraryService

Add new tracks to the appropriate generator method in `ContentLibraryService.swift`:

```swift
let newTracks: [(String, String, String, String, Int)] = [
    ("Track Title", "Artist Name", "file_name", "mp3", 180)
]

for (title, artist, fileName, ext, duration) in newTracks {
    if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/category") != nil {
        tracks.append(AudioTrack(
            title: title,
            artist: artist,
            category: .childrenSongs,
            duration: TimeInterval(duration),
            audioSourceType: .bundled,
            fileName: fileName,
            fileExtension: ext
        ))
    }
}
```

## Cloud Deployment (R2)

For streaming audio from Cloudflare R2:

```bash
# Set up R2 credentials
export R2_ACCOUNT_ID=your_account_id
export R2_ACCESS_KEY_ID=your_access_key
export R2_SECRET_ACCESS_KEY=your_secret_key

# Upload audio files
npx ts-node scripts/upload-to-r2.ts
```

## Best Practices

1. **Always verify licenses** before adding audio
2. **Keep file sizes reasonable** - Compress to 128-192 kbps MP3
3. **Normalize audio levels** - Ensure consistent volume across tracks
4. **Test on device** - Bundled audio should be tested on real iOS devices
5. **Document attributions** - Even for CC0, keep records of sources

## Troubleshooting

### Audio not playing

1. Check file is included in bundle: `Bundle.main.url(forResource:withExtension:subdirectory:)`
2. Verify file path matches ContentLibraryService configuration
3. Check audio file isn't corrupted (can play in VLC/QuickTime)

### Files too large

- Convert to MP3 128kbps mono for voice
- Use MP3 192kbps stereo for music
- Consider splitting long tracks

## API Keys Required

| Service | Purpose | Get Key |
|---------|---------|---------|
| Freesound | CC0 audio search | https://freesound.org/apiv2/apply |
| Suno (via MusicAPI) | AI music generation | https://musicapi.ai |
| Cloudflare R2 | Audio hosting | Cloudflare Dashboard |

## Summary

| Source | License | Best For | Cost |
|--------|---------|----------|------|
| Freesound | CC0 | Sound effects, nature | Free |
| Internet Archive | Public Domain | Classical | Free |
| Pixabay | Pixabay License | Background music | Free |
| Suno AI | Commercial | Original songs | $10-30/mo |
| Generated | App-owned | White noise | Free |
