-- FS-029: Cry Type Effectiveness Tracking Migration
-- Adds per-cry-type effectiveness data and feedback history for smart playlist generation
--
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/016_cry_type_effectiveness.sql

-- =====================================
-- Table: cry_type_effectiveness
-- Per-cry-type effectiveness scores for tracks
-- =====================================
CREATE TABLE IF NOT EXISTS cry_type_effectiveness (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  cry_type TEXT NOT NULL CHECK (cry_type IN ('hunger', 'tired', 'pain', 'attention', 'discomfort', 'general', 'unknown')),

  -- Effectiveness metrics
  helped_count INTEGER DEFAULT 0,           -- Times marked as "It Helped!"
  not_helped_count INTEGER DEFAULT 0,       -- Times marked as "Still Crying"
  total_play_duration_seconds INTEGER DEFAULT 0,  -- Total seconds played for this cry type
  avg_effectiveness_score REAL DEFAULT 0.5, -- Calculated effectiveness (0.0-1.0)

  -- Auto-detection metrics
  auto_detected_helped INTEGER DEFAULT 0,   -- Times auto-detected as helped
  auto_detected_weight REAL DEFAULT 0.7,    -- Weight factor for auto-detected feedback

  -- Timestamps
  last_played_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE,
  UNIQUE(user_id, track_id, cry_type)
);

-- Index for quick lookup by user and cry type
CREATE INDEX IF NOT EXISTS idx_cry_type_effectiveness_user_cry
  ON cry_type_effectiveness(user_id, cry_type);

-- Index for finding effective tracks
CREATE INDEX IF NOT EXISTS idx_cry_type_effectiveness_score
  ON cry_type_effectiveness(cry_type, avg_effectiveness_score DESC);

-- =====================================
-- Table: feedback_sessions
-- Records complete feedback sessions for analytics
-- =====================================
CREATE TABLE IF NOT EXISTS feedback_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  baby_id TEXT,

  -- Session info
  cry_type TEXT NOT NULL CHECK (cry_type IN ('hunger', 'tired', 'pain', 'attention', 'discomfort', 'general', 'unknown')),
  start_time DATETIME NOT NULL,
  end_time DATETIME,

  -- Outcome
  outcome TEXT CHECK (outcome IN ('helped_manual', 'helped_auto', 'not_helped', 'abandoned', 'cry_type_changed')),

  -- Tracks played during session (JSON array of track IDs)
  tracks_played JSON DEFAULT '[]',

  -- Duration stats
  session_duration_seconds INTEGER DEFAULT 0,
  tracks_count INTEGER DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE SET NULL
);

-- Index for session history
CREATE INDEX IF NOT EXISTS idx_feedback_sessions_user
  ON feedback_sessions(user_id, start_time DESC);

-- Index for analytics by cry type
CREATE INDEX IF NOT EXISTS idx_feedback_sessions_cry_type
  ON feedback_sessions(cry_type, outcome);

-- =====================================
-- Table: track_feedback_events
-- Individual feedback events for detailed tracking
-- =====================================
CREATE TABLE IF NOT EXISTS track_feedback_events (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  cry_type TEXT NOT NULL,

  -- Event details
  event_type TEXT NOT NULL CHECK (event_type IN ('played', 'helped_manual', 'helped_auto', 'not_helped', 'skipped')),
  play_duration_seconds INTEGER DEFAULT 0,
  position_in_session INTEGER DEFAULT 0,  -- 1-based position in playlist

  -- Confidence for auto-detected events
  auto_detection_confidence REAL,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (session_id) REFERENCES feedback_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Index for events by track
CREATE INDEX IF NOT EXISTS idx_track_feedback_events_track
  ON track_feedback_events(track_id, cry_type);

-- =====================================
-- View: track_effectiveness_summary
-- Aggregated effectiveness data for quick access
-- =====================================
CREATE VIEW IF NOT EXISTS track_effectiveness_summary AS
SELECT
  track_id,
  user_id,
  SUM(CASE WHEN cry_type = 'hunger' THEN avg_effectiveness_score ELSE 0 END) as hunger_score,
  SUM(CASE WHEN cry_type = 'tired' THEN avg_effectiveness_score ELSE 0 END) as tired_score,
  SUM(CASE WHEN cry_type = 'pain' THEN avg_effectiveness_score ELSE 0 END) as pain_score,
  SUM(helped_count) as total_helped,
  SUM(not_helped_count) as total_not_helped,
  MAX(last_played_at) as last_played
FROM cry_type_effectiveness
GROUP BY track_id, user_id;

-- =====================================
-- Trigger: Update timestamps automatically
-- =====================================
CREATE TRIGGER IF NOT EXISTS update_cry_type_effectiveness_timestamp
AFTER UPDATE ON cry_type_effectiveness
BEGIN
  UPDATE cry_type_effectiveness
  SET updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;
