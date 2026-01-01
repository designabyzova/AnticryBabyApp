# R2 Podcast Upload Instructions

You have **242 podcast files** ready to upload (6.4GB total):
- 87 English podcasts (bedtime stories, fairy tales)
- 100 Russian podcasts (народные сказки)
- 40+ Multi-language lullabies and sleep sounds

## Quick Setup (2 minutes)

### Step 1: Create R2 API Token

1. Go to: https://dash.cloudflare.com/1364b528762500de4f870e064229d443/r2/api-tokens
2. Click "Create API Token"
3. Select:
   - Token name: `baby-audio-upload`
   - Permissions: **Object Read & Write**
   - Bucket: `anticrybaby`
   - TTL: Optional (leave blank for permanent)
4. Click "Create API Token"
5. **COPY both values**:
   - Access Key ID
   - Secret Access Key

### Step 2: Add to .env file

Edit `/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/.env`:

```bash
# Add these lines:
R2_ACCESS_KEY_ID=your_access_key_id_here
R2_SECRET_ACCESS_KEY=your_secret_access_key_here
```

### Step 3: Run Upload Script

```bash
cd "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api/scripts"
python3 upload-podcasts-to-r2.py
```

This will upload all 242 podcasts to your R2 bucket.

## Alternative: Manual Upload via Dashboard

If you prefer not to use scripts:

1. Go to: https://dash.cloudflare.com/1364b528762500de4f870e064229d443/r2/default/buckets/anticrybaby
2. Click "Upload" button
3. Navigate to: `/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts/`
4. Drag and drop the folders:
   - `en/` folder (English content)
   - `ru/` folder (Russian content)
   - `multi/` folder (Multi-language)

## Alternative: Using rclone

Install rclone and configure:

```bash
brew install rclone

# Configure rclone for R2
rclone config

# Create new remote named "r2"
# Type: s3
# Provider: Cloudflare
# Access Key ID: (your R2 access key)
# Secret Access Key: (your R2 secret key)
# Endpoint: https://1364b528762500de4f870e064229d443.r2.cloudflarestorage.com
# ACL: private

# Upload all podcasts
rclone copy "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts" r2:anticrybaby/podcasts --progress
```

## After Upload: Enable Public Access

1. Go to bucket settings: https://dash.cloudflare.com/1364b528762500de4f870e064229d443/r2/default/buckets/anticrybaby/settings
2. Enable "R2.dev subdomain" for public access
3. Public URL format will be:
   ```
   https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/[lang]/[category]/[filename]
   ```

## Verify Upload

After uploading, test a file:
```bash
curl -I "https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_01_лисичка-сестричка_и_волк.mp3"
```

## Files Location

Podcasts are in:
```
/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts/
├── en/                    # English content (87 files)
│   ├── children_calm/     # Calming music for kids
│   ├── children_stories/  # Bedtime FM stories, LibriVox classics
│   └── mindfulness/       # Peace Out episodes
├── ru/                    # Russian content (100 files)
│   ├── children_stories/  # LibriVox story recordings
│   └── russian_fairy_tales/  # Folk tales in Russian
└── multi/                 # Multi-language (40 files)
    ├── lullabies/         # Baby sleep music
    └── whitenoise/        # Sleep sounds
```

## Database Seed

After uploading to R2, run the database migration:
```bash
cd "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/babyincar-api"
wrangler d1 migrations apply babyincar-db --local
```
