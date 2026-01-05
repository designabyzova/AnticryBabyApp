-- Emergency Playlist Metadata Migration
-- Adds cry-scenario mapping, language preferences, and AI selection metadata

-- Cry scenario playlists table (system playlists for emergency mode)
CREATE TABLE IF NOT EXISTS cry_scenario_playlists (
  id TEXT PRIMARY KEY,
  cry_type TEXT NOT NULL, -- hunger, tired, pain, discomfort, attention, general
  name TEXT NOT NULL,
  description TEXT,
  language TEXT NOT NULL, -- en, ru, multi
  age_range_min INTEGER DEFAULT 0,
  age_range_max INTEGER DEFAULT 36,
  priority INTEGER DEFAULT 0, -- Higher priority playlists tried first
  ai_confidence_score REAL DEFAULT 0.0, -- Learning from effectiveness
  total_duration_seconds INTEGER DEFAULT 0,
  track_count INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Cry scenario playlist tracks junction (ordered)
CREATE TABLE IF NOT EXISTS cry_playlist_tracks (
  cry_playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  transition_type TEXT DEFAULT 'smooth', -- smooth, immediate, fade
  PRIMARY KEY (cry_playlist_id, track_id),
  FOREIGN KEY (cry_playlist_id) REFERENCES cry_scenario_playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Track metadata for AI selection
CREATE TABLE IF NOT EXISTS track_metadata (
  track_id TEXT PRIMARY KEY,
  cry_suitability JSON DEFAULT '{}', -- {"hunger": 0.9, "tired": 0.7, ...}
  acoustic_features JSON DEFAULT '{}', -- {"tempo_bpm": 60, "key": "C", "mode": "major"}
  research_citations TEXT, -- Links to research papers
  emotional_tags TEXT, -- calming, energizing, soothing, etc.
  cultural_context TEXT, -- Russian lullaby, Western classical, etc.
  recommended_age_months JSON DEFAULT '[]', -- [0, 3, 6, 9, 12]
  language_specific_metadata JSON DEFAULT '{}',
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Playlist effectiveness tracking (per baby)
CREATE TABLE IF NOT EXISTS playlist_effectiveness (
  id TEXT PRIMARY KEY,
  baby_id TEXT NOT NULL,
  cry_playlist_id TEXT NOT NULL,
  cry_type TEXT NOT NULL,
  was_effective INTEGER NOT NULL, -- 0 or 1
  calming_time_seconds INTEGER DEFAULT 0,
  tracks_played_count INTEGER DEFAULT 0,
  user_switched INTEGER DEFAULT 0, -- User manually switched playlist
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE,
  FOREIGN KEY (cry_playlist_id) REFERENCES cry_scenario_playlists(id) ON DELETE CASCADE
);

-- User language preferences
CREATE TABLE IF NOT EXISTS user_language_preferences (
  user_id TEXT PRIMARY KEY,
  preferred_languages TEXT NOT NULL, -- Comma-separated: en,ru
  primary_language TEXT DEFAULT 'en',
  exclude_instrumental INTEGER DEFAULT 0, -- Prefer vocal content
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Emergency session queue (current playing queue for emergency mode)
CREATE TABLE IF NOT EXISTS emergency_session_queue (
  id TEXT PRIMARY KEY,
  baby_id TEXT NOT NULL,
  cry_playlist_id TEXT NOT NULL,
  current_track_id TEXT,
  current_position INTEGER DEFAULT 0,
  queue_tracks JSON DEFAULT '[]', -- Array of track IDs in order
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  ended_at DATETIME,
  session_duration_seconds INTEGER DEFAULT 0,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE,
  FOREIGN KEY (cry_playlist_id) REFERENCES cry_scenario_playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (current_track_id) REFERENCES tracks(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cry_playlists_type ON cry_scenario_playlists(cry_type);
CREATE INDEX IF NOT EXISTS idx_cry_playlists_language ON cry_scenario_playlists(language);
CREATE INDEX IF NOT EXISTS idx_cry_playlists_age ON cry_scenario_playlists(age_range_min, age_range_max);
CREATE INDEX IF NOT EXISTS idx_playlist_effectiveness_baby ON playlist_effectiveness(baby_id);
CREATE INDEX IF NOT EXISTS idx_playlist_effectiveness_type ON playlist_effectiveness(cry_type);
CREATE INDEX IF NOT EXISTS idx_emergency_queue_baby ON emergency_session_queue(baby_id);
CREATE INDEX IF NOT EXISTS idx_track_metadata_track ON track_metadata(track_id);
