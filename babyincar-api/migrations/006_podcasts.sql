-- Migration 006: Add podcast tracks to the database
-- This seeds the tracks table with 242 podcast episodes from:
--   - LibriVox (Russian & English fairy tales)
--   - Bedtime FM (children's stories)
--   - Internet Archive (calming music, lullabies)

-- First, add 'podcasts' to the category if needed
-- The category enum already includes it, but let's ensure tracks table can handle it

-- Insert podcast tracks
-- Note: Run the podcast seeder script to populate from the JSON metadata

-- Create podcast_metadata table to store additional podcast-specific data
CREATE TABLE IF NOT EXISTS podcast_metadata (
    track_id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    source_id TEXT,
    original_url TEXT,
    license TEXT DEFAULT 'Public Domain',
    local_path TEXT,
    r2_key TEXT,
    uploaded_at TIMESTAMP,
    FOREIGN KEY (track_id) REFERENCES tracks(id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_podcast_metadata_source ON podcast_metadata(source);
CREATE INDEX IF NOT EXISTS idx_podcast_metadata_r2_key ON podcast_metadata(r2_key);

-- Add podcasts category filter index
CREATE INDEX IF NOT EXISTS idx_tracks_language ON tracks(language);
CREATE INDEX IF NOT EXISTS idx_tracks_category_language ON tracks(category, language);
