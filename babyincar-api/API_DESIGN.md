# Baby in Car - Backend API Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │ SwiftUI  │ │  Audio   │ │ CarPlay  │ │ Speech Recognition│   │
│  │   Views  │ │  Engine  │ │ Support  │ │                  │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┬─────────┘   │
│       └────────────┴────────────┴────────────────┘              │
│                           │                                      │
│                    APIClient.swift                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Cloudflare Edge Network                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Cloudflare Workers (API)                     │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────────┐ │   │
│  │  │  Auth   │ │ Babies  │ │ Content │ │   Analytics     │ │   │
│  │  │ /auth/* │ │/babies/*│ │/content*│ │   /analytics/*  │ │   │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └───────┬─────────┘ │   │
│  └───────┴───────────┴───────────┴──────────────┴───────────┘   │
│                            │                                     │
│  ┌─────────────┐  ┌────────┴────────┐  ┌────────────────────┐   │
│  │   D1 SQL    │  │   KV Storage    │  │    R2 Storage      │   │
│  │  Database   │  │  (Sessions,     │  │  (Audio Files,     │   │
│  │  (Users,    │  │   Cache)        │  │   Images)          │   │
│  │   Babies,   │  │                 │  │                    │   │
│  │   Analytics)│  │                 │  │                    │   │
│  └─────────────┘  └─────────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## API Endpoints

### Base URL
```
Production: https://api.babyincar.app
Development: https://babyincar-api.{your-subdomain}.workers.dev
```

---

## 1. Authentication API

### POST /auth/register
Register new user with email/password or Apple Sign-In.

**Request:**
```json
{
  "email": "parent@example.com",
  "password": "securepassword123",
  "name": "John Parent",
  "auth_provider": "email" | "apple",
  "apple_id_token": "optional_for_apple_signin"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "usr_abc123",
    "email": "parent@example.com",
    "name": "John Parent",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "rt_xyz789..."
}
```

### POST /auth/login
```json
{
  "email": "parent@example.com",
  "password": "securepassword123"
}
```

### POST /auth/refresh
```json
{
  "refresh_token": "rt_xyz789..."
}
```

### POST /auth/apple
Apple Sign-In token exchange.
```json
{
  "id_token": "apple_id_token",
  "authorization_code": "apple_auth_code"
}
```

### DELETE /auth/logout
Invalidate current session.

---

## 2. Baby Profiles API

### GET /babies
Get all babies for current user.

**Response:**
```json
{
  "babies": [
    {
      "id": "baby_123",
      "name": "Emma",
      "birth_date": "2024-06-15",
      "age_months": 6,
      "developmental_stage": "sensory_exploration",
      "photo_url": "https://r2.babyincar.app/photos/baby_123.jpg",
      "preferences": {
        "favorite_categories": ["white_noise", "nature_sounds"],
        "preferred_languages": ["english", "spanish"],
        "effective_tracks": ["track_001", "track_002"]
      },
      "created_at": "2024-06-20T10:00:00Z"
    }
  ]
}
```

### POST /babies
Create new baby profile.

**Request:**
```json
{
  "name": "Emma",
  "birth_date": "2024-06-15",
  "photo_data": "base64_encoded_image_optional"
}
```

### PUT /babies/:id
Update baby profile.

### DELETE /babies/:id
Delete baby profile.

### POST /babies/:id/preferences
Update baby preferences based on usage.

```json
{
  "effective_track_id": "track_001",
  "calming_time_seconds": 45,
  "context": "emergency_mode"
}
```

---

## 3. Content Catalog API

### GET /content/tracks
Get all available tracks with filtering.

**Query Parameters:**
- `category`: Filter by category (white_noise, nature_sounds, etc.)
- `language`: Filter by language
- `age_min`: Minimum age in months
- `age_max`: Maximum age in months
- `limit`: Results per page (default 50)
- `offset`: Pagination offset

**Response:**
```json
{
  "tracks": [
    {
      "id": "track_001",
      "title": "Gentle Rain",
      "artist": "Nature Sounds",
      "category": "nature_sounds",
      "language": "instrumental",
      "duration": 3600,
      "age_range_min": 0,
      "age_range_max": 36,
      "calming_score": 0.92,
      "audio_source_type": "generated",
      "generator_type": "rain",
      "stream_url": "https://r2.babyincar.app/audio/track_001.mp3",
      "artwork_url": "https://r2.babyincar.app/artwork/rain.jpg",
      "is_premium": false
    }
  ],
  "total": 150,
  "has_more": true
}
```

### GET /content/tracks/:id
Get single track details.

### GET /content/playlists
Get all playlists.

**Response:**
```json
{
  "playlists": [
    {
      "id": "playlist_001",
      "name": "Newborn Essentials",
      "description": "Womb-like sounds perfect for newborns",
      "track_count": 10,
      "total_duration": 36000,
      "target_age_months": 1,
      "category": "white_noise",
      "artwork_url": "https://r2.babyincar.app/artwork/newborn.jpg",
      "is_system": true
    }
  ]
}
```

### GET /content/playlists/:id
Get playlist with tracks.

### GET /content/recommendations
Get AI-personalized recommendations for a baby.

**Query Parameters:**
- `baby_id`: Baby profile ID
- `mood`: Current mood (sleepy, crying, playful, calm, fussy)
- `trip_duration`: Trip type (quick, medium, long, road_trip)
- `limit`: Number of recommendations

**Response:**
```json
{
  "recommended_tracks": [...],
  "recommended_playlists": [...],
  "emergency_tracks": [...],
  "personalization_score": 0.87
}
```

### GET /content/stream/:track_id
Get signed streaming URL for a track.

**Response:**
```json
{
  "stream_url": "https://r2.babyincar.app/audio/track_001.mp3?token=xyz&expires=1234567890",
  "expires_at": "2024-01-15T11:30:00Z"
}
```

---

## 4. Analytics API

### POST /analytics/playback
Record playback event.

```json
{
  "baby_id": "baby_123",
  "track_id": "track_001",
  "event_type": "play" | "pause" | "complete" | "skip",
  "position_seconds": 120,
  "session_id": "sess_abc",
  "context": "home" | "carplay" | "emergency",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### POST /analytics/effectiveness
Record track effectiveness (for AI learning).

```json
{
  "baby_id": "baby_123",
  "track_id": "track_001",
  "was_effective": true,
  "calming_time_seconds": 45,
  "context": "crying" | "fussy" | "sleepy",
  "emergency_mode": false
}
```

### POST /analytics/emergency
Record emergency cry-stop usage.

```json
{
  "baby_id": "baby_123",
  "started_at": "2024-01-15T10:30:00Z",
  "ended_at": "2024-01-15T10:32:30Z",
  "phases_completed": ["attention", "transition", "sustained"],
  "was_successful": true,
  "tracks_used": ["track_001", "track_002"]
}
```

### GET /analytics/insights/:baby_id
Get personalized insights for a baby.

**Response:**
```json
{
  "total_listening_time_minutes": 1250,
  "most_effective_category": "white_noise",
  "most_effective_tracks": [
    {"track_id": "track_001", "success_rate": 0.92}
  ],
  "average_calming_time_seconds": 38,
  "emergency_mode_usage": {
    "total_activations": 15,
    "success_rate": 0.87
  },
  "weekly_trend": [...]
}
```

---

## 5. Subscription API

### POST /subscriptions/verify
Verify App Store receipt.

```json
{
  "receipt_data": "base64_encoded_receipt",
  "product_id": "com.babyincar.premium.monthly"
}
```

**Response:**
```json
{
  "valid": true,
  "subscription": {
    "product_id": "com.babyincar.premium.monthly",
    "expires_at": "2024-02-15T10:30:00Z",
    "is_trial": false,
    "will_renew": true
  },
  "entitlements": ["premium_content", "offline_downloads", "carplay"]
}
```

### GET /subscriptions/status
Get current subscription status.

### POST /subscriptions/webhook
App Store Server Notifications (server-to-server).

---

## 6. User Settings API

### GET /users/me
Get current user profile.

### PUT /users/me
Update user profile.

### GET /users/me/settings
Get user settings.

```json
{
  "notifications_enabled": true,
  "auto_play_carplay": true,
  "max_volume_db": 50,
  "default_sleep_timer_minutes": 30,
  "preferred_languages": ["english", "spanish"],
  "theme": "auto"
}
```

### PUT /users/me/settings
Update settings.

### DELETE /users/me
Delete account and all data.

---

## Database Schema (D1)

```sql
-- Users table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  name TEXT,
  auth_provider TEXT DEFAULT 'email',
  apple_user_id TEXT,
  subscription_status TEXT DEFAULT 'free',
  subscription_expires_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Babies table
CREATE TABLE babies (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  birth_date DATE NOT NULL,
  photo_url TEXT,
  preferences JSON DEFAULT '{}',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Tracks table
CREATE TABLE tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT,
  category TEXT NOT NULL,
  language TEXT DEFAULT 'instrumental',
  duration INTEGER NOT NULL,
  age_range_min INTEGER DEFAULT 0,
  age_range_max INTEGER DEFAULT 36,
  tempo_bpm INTEGER,
  calming_score REAL DEFAULT 0.5,
  audio_source_type TEXT NOT NULL,
  generator_type TEXT,
  stream_url TEXT,
  artwork_url TEXT,
  is_premium INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Playlists table
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  target_age_months INTEGER,
  artwork_url TEXT,
  is_system INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Playlist tracks junction
CREATE TABLE playlist_tracks (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Playback events table
CREATE TABLE playback_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  baby_id TEXT,
  track_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  position_seconds INTEGER,
  context TEXT,
  session_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE SET NULL,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Track effectiveness table
CREATE TABLE track_effectiveness (
  id TEXT PRIMARY KEY,
  baby_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  was_effective INTEGER NOT NULL,
  calming_time_seconds INTEGER,
  context TEXT,
  emergency_mode INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Emergency sessions table
CREATE TABLE emergency_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  baby_id TEXT NOT NULL,
  started_at DATETIME NOT NULL,
  ended_at DATETIME,
  phases_completed JSON,
  was_successful INTEGER,
  tracks_used JSON,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
);

-- User favorites
CREATE TABLE favorites (
  user_id TEXT NOT NULL,
  track_id TEXT,
  playlist_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, track_id, playlist_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Sessions for auth
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX idx_babies_user ON babies(user_id);
CREATE INDEX idx_tracks_category ON tracks(category);
CREATE INDEX idx_tracks_age ON tracks(age_range_min, age_range_max);
CREATE INDEX idx_playback_user ON playback_events(user_id);
CREATE INDEX idx_playback_baby ON playback_events(baby_id);
CREATE INDEX idx_effectiveness_baby ON track_effectiveness(baby_id);
CREATE INDEX idx_sessions_token ON sessions(token_hash);
```

---

## Security

### Authentication
- JWT tokens with 1-hour expiry
- Refresh tokens with 30-day expiry
- Tokens stored in KV with ability to revoke

### Rate Limiting
- 100 requests/minute for authenticated users
- 20 requests/minute for unauthenticated
- 1000 requests/minute for streaming

### Data Protection
- All data encrypted at rest (Cloudflare default)
- HTTPS only
- CORS restricted to app bundle ID
- No PII in logs

---

## Deployment

```bash
# Install Wrangler
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Create D1 database
wrangler d1 create babyincar-db

# Create KV namespace
wrangler kv:namespace create sessions

# Create R2 bucket
wrangler r2 bucket create babyincar-audio

# Deploy
wrangler deploy
```
