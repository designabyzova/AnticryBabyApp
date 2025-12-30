# Audio Library Setup Guide

This guide explains how to set up and manage the audio library for the Baby in Car app.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
│  │ AudioEngine  │   │ ContentLib   │   │ Audio Synthesizer    │ │
│  │ (Playback)   │◄──│ Service      │   │ (Generated Sounds)   │ │
│  └──────────────┘   └──────────────┘   └──────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cloudflare Workers API                        │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
│  │ /content     │   │ /audio       │   │ /ai                  │ │
│  │ Metadata     │   │ Streaming    │   │ Recommendations      │ │
│  └──────────────┘   └──────┬───────┘   └──────────────────────┘ │
└─────────────────────────────┼───────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │ Cloudflare   │ │ Cloudflare   │ │ Cloudflare   │
     │ D1 Database  │ │ R2 Storage   │ │ Workers AI   │
     │ (Metadata)   │ │ (Audio Files)│ │ (Stories)    │
     └──────────────┘ └──────────────┘ └──────────────┘
```

## Audio Sources

### 1. Generated Audio (In-App Synthesis)
These sounds are synthesized in real-time by the iOS app:
- White/Pink/Brown Noise
- Womb sounds & Heartbeat
- Nature sounds (rain, ocean, wind)
- Musical tones (music box, bells)
- Household sounds (fan, vacuum)

### 2. Recorded Audio (R2 Storage)
Pre-recorded audio files stored in Cloudflare R2:
- Classical music (public domain)
- Professional lullaby recordings
- High-quality nature recordings

### 3. Text-to-Speech Audio
Generated dynamically using AI:
- Personalized bedtime stories
- Nursery rhymes in multiple languages

## Setup Instructions

### Step 1: Create Cloudflare R2 Bucket

```bash
# Create R2 bucket for development
wrangler r2 bucket create babyincar-audio

# Create R2 bucket for production
wrangler r2 bucket create babyincar-audio-prod
```

### Step 2: Create R2 API Token

1. Go to Cloudflare Dashboard → R2 → Manage R2 API Tokens
2. Create a new API token with "Object Read & Write" permissions
3. Save the Access Key ID and Secret Access Key

### Step 3: Configure Environment Variables

Add to your `.dev.vars` file:
```
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
FREESOUND_API_KEY=your_freesound_api_key
```

### Step 4: Run Database Migrations

```bash
cd babyincar-api

# Run initial schema
wrangler d1 execute babyincar-db --file=./migrations/001_initial.sql

# Run seed content
wrangler d1 execute babyincar-db --file=./migrations/002_seed_content.sql

# Run audio enhancements migration
wrangler d1 execute babyincar-db --file=./migrations/003_audio_enhancements.sql

# Run audio library seed
wrangler d1 execute babyincar-db --file=./migrations/004_audio_library_seed.sql
```

### Step 5: (Optional) Collect Additional Audio

To collect additional royalty-free audio from external sources:

```bash
# Install dependencies
npm install

# Collect metadata from Freesound and Internet Archive
FREESOUND_API_KEY=your_key npx ts-node scripts/audio-collector.ts --collect

# Download collected audio files
npx ts-node scripts/audio-collector.ts --download

# Upload to R2
R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \
npx ts-node scripts/upload-to-r2.ts

# Generate SQL for new tracks
npx ts-node scripts/audio-collector.ts --generate-sql
```

### Step 6: Enable Public Access (Optional)

For production, you can set up a custom domain for R2:

1. Go to Cloudflare Dashboard → R2 → babyincar-audio-prod
2. Click "Settings" → "Public Access"
3. Add custom domain: `audio.babyincar.app`
4. Configure DNS accordingly

## API Endpoints

### Content API

```
GET /content/tracks
GET /content/tracks/:id
GET /content/playlists
GET /content/playlists/:id
GET /content/recommendations
```

### Audio Streaming API

```
GET /audio/stream/:trackId   # Stream audio (supports range requests)
GET /audio/file/*            # Direct R2 file access
GET /audio/stats             # Library statistics
POST /audio/upload           # Admin: Upload new audio
DELETE /audio/:trackId       # Admin: Delete track
GET /audio/list              # Admin: List R2 files
```

## Audio Categories

| Category | Description | Age Range |
|----------|-------------|-----------|
| white_noise | White, pink, brown noise, household sounds | 0-36 months |
| nature_sounds | Rain, ocean, birds, wind, etc. | 0-36 months |
| instrumental | Music box, bells, harp, piano | 0-36 months |
| classical_music | Public domain classical pieces | 0-36 months |
| children_songs | Nursery rhymes, lullabies | 0-36 months |
| fairy_tales | Short bedtime stories | 12-36 months |
| podcasts | Educational content | 24-36 months |

## Audio Source Types

| Type | Description | Storage |
|------|-------------|---------|
| `generated` | Synthesized in app | None (real-time) |
| `recorded` | Pre-recorded files | R2 bucket |
| `text_to_speech` | AI-generated speech | Cached in R2 |

## Licensing

### Public Domain / CC0 Sources
- **Freesound.org** - CC0 sounds (API key required)
- **Internet Archive** - Public domain audio
- **Musopen** - Public domain classical music
- **Pixabay** - Royalty-free sounds

### Important Notes
- Always verify license before commercial use
- CC0 = No attribution required
- Public Domain = Copyright expired
- Some sources may require attribution

## Free Tier Limits

### Cloudflare R2 (Free Tier)
- 10 GB storage
- 10 million Class A operations/month (writes)
- 1 million Class B operations/month (reads)
- Unlimited egress (no bandwidth charges!)

### Estimated Capacity
- ~1,000 MP3 files @ 5MB each = 5GB
- Perfect for a comprehensive baby audio library

## Monitoring

Check audio library statistics:
```bash
curl https://api.babyincar.app/audio/stats
```

Response:
```json
{
  "success": true,
  "stats": {
    "totals": {
      "total_tracks": 85,
      "total_duration": 28500,
      "premium_tracks": 15,
      "free_tracks": 70
    },
    "by_category": [
      {"category": "white_noise", "count": 12},
      {"category": "nature_sounds", "count": 10},
      ...
    ]
  }
}
```

## Troubleshooting

### Audio not streaming
1. Check if track exists in database
2. Verify R2 file exists: `GET /audio/list?prefix=audio/`
3. Check `stream_url` format (should be `r2://key` or external URL)

### Upload failing
1. Verify R2 API credentials
2. Check file type (must be audio/mpeg, audio/ogg, etc.)
3. Ensure admin privileges

### Missing tracks
1. Run migrations in order
2. Check D1 database connection
3. Verify wrangler.toml configuration

---

## Autonomous AI-Powered Audio Curation

The app includes an **autonomous curation system** that continuously discovers, evaluates, and downloads new audio content using AI.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AUTONOMOUS AUDIO CURATION PIPELINE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌─────────────┐    ┌────────────┐ │
│  │ Cron     │───►│ Discover     │───►│ AI Analyze  │───►│ Download   │ │
│  │ Trigger  │    │ Audio        │    │ & Score     │    │ to R2      │ │
│  └──────────┘    └──────────────┘    └─────────────┘    └────────────┘ │
│       │                 │                   │                  │        │
│   (Every 6h)      Freesound.org      Workers AI          Cloudflare    │
│   (Daily 3AM)     Internet Archive   Llama 3.1           R2 Bucket     │
│                   Pixabay                                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Curation Schedule

| Cron Expression | Description |
|-----------------|-------------|
| `0 3 * * *` | Daily at 3 AM UTC - Full curation run |
| `0 */6 * * *` | Every 6 hours - Quick discovery check |

### AI Analysis Scoring

The AI evaluates each discovered audio file on these criteria:

| Score | Weight | Description |
|-------|--------|-------------|
| Safety Score | 30% | No loud/harsh/scary content |
| Quality Score | 20% | Audio quality, format, duration |
| Baby Fit Score | 25% | Keywords, category match |
| AI Analysis | 25% | Llama 3.1 semantic analysis |

**Action Thresholds:**
- Overall ≥ 0.7 + Safety ≥ 0.8 → **Download**
- Overall ≥ 0.5 + Safety ≥ 0.6 → **Review**
- Below threshold → **Skip**

### Curation API Endpoints

```bash
# Get curation stats and library summary
GET /curation/stats

# Manually trigger curation (admin only)
POST /curation/run
POST /curation/run {"category": "white_noise"}

# Preview what would be discovered (without downloading)
GET /curation/discover?query=white+noise+baby&category=white_noise

# Get curation history
GET /curation/history?days=7

# Get quality report
GET /curation/quality-report

# Manage audio sources
GET /curation/sources
POST /curation/sources/:id/toggle

# Delete low-quality track
DELETE /curation/tracks/:id
```

### Example: Check Curation Stats

```bash
curl https://api.babyincar.app/curation/stats
```

Response:
```json
{
  "success": true,
  "library": {
    "totals": {
      "total_tracks": 247,
      "total_duration": 82500,
      "total_size_mb": 1240,
      "total_hours": 22.9,
      "avg_calming_score": 0.84
    },
    "by_category_and_source": [
      {"category": "white_noise", "source": "freesound", "count": 45},
      {"category": "nature_sounds", "source": "freesound", "count": 38},
      {"category": "classical_music", "source": "internet_archive", "count": 52}
    ],
    "recent_additions": [
      {"id": "curated_1703...", "title": "Gentle Rain Loop", "calming_score": 0.91}
    ]
  },
  "curation": {
    "totalDiscovered": 156,
    "totalAnalyzed": 156,
    "totalDownloaded": 23,
    "totalSkipped": 133,
    "lastRunAt": "2024-12-26T03:00:00.000Z"
  }
}
```

### Configure Freesound API Key

To enable Freesound collection (recommended):

1. Get an API key from: https://freesound.org/apiv2/apply
2. Add to Cloudflare secrets:
   ```bash
   wrangler secret put FREESOUND_API_KEY
   # Enter your API key when prompted
   ```

### Search Queries Optimized for Babies

The curation system uses category-specific search queries:

| Category | Search Terms |
|----------|--------------|
| white_noise | "white noise sleep", "pink noise baby", "vacuum cleaner sound", "womb sounds heartbeat" |
| nature_sounds | "rain sounds gentle", "ocean waves calm", "forest birds morning" |
| classical_music | "lullaby classical piano", "mozart baby sleep", "brahms lullaby" |
| instrumental | "music box lullaby", "harp gentle melody", "wind chimes peaceful" |

### Content Safety Filters

**Excluded Tags** (auto-rejected):
- loud, intense, scary, horror, explosion
- alarm, siren, scream, harsh, aggressive
- metal, rock, electronic, beat, bass

**Preferred Tags** (boost score):
- calm, peaceful, relaxing, gentle, soft
- soothing, ambient, sleep, baby, lullaby

### Monitor Curation Logs

```bash
# Watch real-time logs
wrangler tail

# Example log output:
# [Scheduled] Cron trigger fired: 0 3 * * *
# [AudioCurator] Starting full curation cycle...
# [AudioCurator] Processing category: white_noise
#   Searching: "white noise sleep"...
#     Found 15 sounds
# [AudioCurator] Downloaded and stored: Gentle Fan Sound -> audio/white_noise/freesound_123456.mp3
# [AudioCurator] Curation cycle completed: {totalDownloaded: 12, totalSkipped: 143}
```

### Quality Report

Check the health of your audio library:

```bash
curl https://api.babyincar.app/curation/quality-report
```

Response:
```json
{
  "success": true,
  "report": {
    "score_distribution": [
      {"quality_tier": "excellent", "count": 45},
      {"quality_tier": "very_good", "count": 89},
      {"quality_tier": "good", "count": 78},
      {"quality_tier": "needs_review", "count": 5}
    ],
    "top_tracks": [...],
    "needs_review": [...],
    "category_health": [
      {"category": "white_noise", "track_count": 52, "avg_score": 0.88},
      {"category": "nature_sounds", "track_count": 41, "avg_score": 0.85}
    ]
  }
}
```
