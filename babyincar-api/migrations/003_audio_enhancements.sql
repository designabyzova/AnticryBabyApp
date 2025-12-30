-- Audio Enhancements Migration
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/003_audio_enhancements.sql

-- Add admin flag to users table
ALTER TABLE users ADD COLUMN is_admin INTEGER DEFAULT 0;

-- Add audio source metadata fields to tracks
ALTER TABLE tracks ADD COLUMN source TEXT DEFAULT 'bundled';
ALTER TABLE tracks ADD COLUMN source_id TEXT;
ALTER TABLE tracks ADD COLUMN source_url TEXT;
ALTER TABLE tracks ADD COLUMN license TEXT DEFAULT 'proprietary';
ALTER TABLE tracks ADD COLUMN license_url TEXT;
ALTER TABLE tracks ADD COLUMN r2_key TEXT;
ALTER TABLE tracks ADD COLUMN file_size INTEGER DEFAULT 0;
ALTER TABLE tracks ADD COLUMN file_format TEXT DEFAULT 'mp3';
ALTER TABLE tracks ADD COLUMN tags JSON DEFAULT '[]';

-- Create index for R2 key lookups
CREATE INDEX IF NOT EXISTS idx_tracks_r2_key ON tracks(r2_key);
CREATE INDEX IF NOT EXISTS idx_tracks_source ON tracks(source);

-- Audio sources reference table
CREATE TABLE IF NOT EXISTS audio_sources (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('api', 'manual', 'generated', 'user_upload')),
  base_url TEXT,
  api_key_env TEXT,
  rate_limit_per_minute INTEGER DEFAULT 60,
  license_default TEXT,
  is_active INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert known audio sources
INSERT OR IGNORE INTO audio_sources (id, name, type, base_url, api_key_env, license_default, is_active)
VALUES
  ('freesound', 'Freesound.org', 'api', 'https://freesound.org/apiv2', 'FREESOUND_API_KEY', 'CC0', 1),
  ('internet_archive', 'Internet Archive', 'api', 'https://archive.org', NULL, 'Public Domain', 1),
  ('pixabay', 'Pixabay', 'api', 'https://pixabay.com/api', 'PIXABAY_API_KEY', 'Pixabay License', 1),
  ('musopen', 'Musopen', 'manual', 'https://musopen.org', NULL, 'Public Domain', 1),
  ('generated', 'App Generated', 'generated', NULL, NULL, 'Proprietary', 1),
  ('bundled', 'Bundled Audio', 'manual', NULL, NULL, 'Proprietary', 1);

-- Audio collection jobs for tracking collection status
CREATE TABLE IF NOT EXISTS audio_collection_jobs (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  query TEXT NOT NULL,
  category TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  results_count INTEGER DEFAULT 0,
  error_message TEXT,
  started_at DATETIME,
  completed_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (source_id) REFERENCES audio_sources(id)
);

-- R2 upload tracking
CREATE TABLE IF NOT EXISTS r2_uploads (
  id TEXT PRIMARY KEY,
  track_id TEXT,
  r2_key TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  content_type TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'uploading', 'completed', 'failed')),
  error_message TEXT,
  uploaded_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_r2_uploads_track ON r2_uploads(track_id);
CREATE INDEX IF NOT EXISTS idx_r2_uploads_status ON r2_uploads(status);
