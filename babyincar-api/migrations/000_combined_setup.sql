-- Combined Setup Migration for BabyInCar API
-- This is a single migration that sets up all tables without restrictive constraints

-- Users table
CREATE TABLE IF NOT EXISTS users (
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
CREATE TABLE IF NOT EXISTS babies (
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

-- Tracks table (no restrictive CHECK constraints)
CREATE TABLE IF NOT EXISTS tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT DEFAULT '',
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
  source TEXT,
  r2_key TEXT,
  file_format TEXT,
  license TEXT,
  tags TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Playlists table
CREATE TABLE IF NOT EXISTS playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  category TEXT,
  target_age_months INTEGER,
  artwork_url TEXT,
  is_system INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Playlist tracks junction table
CREATE TABLE IF NOT EXISTS playlist_tracks (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Playback events table
CREATE TABLE IF NOT EXISTS playback_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  baby_id TEXT,
  track_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  position_seconds INTEGER DEFAULT 0,
  context TEXT DEFAULT 'home',
  session_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE SET NULL,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Track effectiveness table
CREATE TABLE IF NOT EXISTS track_effectiveness (
  id TEXT PRIMARY KEY,
  baby_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  was_effective INTEGER NOT NULL,
  calming_time_seconds INTEGER DEFAULT 0,
  context TEXT DEFAULT 'crying',
  emergency_mode INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Emergency sessions table
CREATE TABLE IF NOT EXISTS emergency_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  baby_id TEXT NOT NULL,
  started_at DATETIME NOT NULL,
  ended_at DATETIME,
  phases_completed JSON DEFAULT '[]',
  was_successful INTEGER,
  tracks_used JSON DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
);

-- User favorites table
CREATE TABLE IF NOT EXISTS favorites (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  track_id TEXT,
  playlist_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE,
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
);

-- Sessions for auth
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Podcasts table
CREATE TABLE IF NOT EXISTS podcasts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  rss_feed_url TEXT,
  artwork_url TEXT,
  author TEXT,
  language TEXT DEFAULT 'en',
  category TEXT DEFAULT 'general',
  is_active INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_babies_user ON babies(user_id);
CREATE INDEX IF NOT EXISTS idx_tracks_category ON tracks(category);
CREATE INDEX IF NOT EXISTS idx_tracks_age ON tracks(age_range_min, age_range_max);
CREATE INDEX IF NOT EXISTS idx_tracks_calming ON tracks(calming_score DESC);
CREATE INDEX IF NOT EXISTS idx_tracks_language ON tracks(language);
CREATE INDEX IF NOT EXISTS idx_playback_user ON playback_events(user_id);
CREATE INDEX IF NOT EXISTS idx_playback_baby ON playback_events(baby_id);
CREATE INDEX IF NOT EXISTS idx_playback_session ON playback_events(session_id);
CREATE INDEX IF NOT EXISTS idx_effectiveness_baby ON track_effectiveness(baby_id);
CREATE INDEX IF NOT EXISTS idx_effectiveness_track ON track_effectiveness(track_id);
CREATE INDEX IF NOT EXISTS idx_emergency_baby ON emergency_sessions(baby_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_apple ON users(apple_user_id);
