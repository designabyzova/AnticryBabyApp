-- Migration: CC0 Licensed High-Quality Nature Sounds
-- Generated: 2026-01-01
-- Source: Internet Archive naturesounds-soundtheraphy collection (CC0 1.0 Universal)
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/011_cc0_nature_sounds.sql

-- Delete old placeholder entries that were garbage (< 100KB files)
DELETE FROM tracks WHERE id IN (
  'r2_nature_calm_ocean',      -- Was 1.5 seconds
  'r2_nature_beach_waves',     -- Was 3 seconds
  'r2_nature_sb_stream'        -- Was 2 seconds
);

-- Also clean up any potential duplicate entries for new files
DELETE FROM tracks WHERE id LIKE 'cc0_nature_%';

-- ============================================
-- HIGH-QUALITY CC0 NATURE SOUNDS
-- All sourced from Internet Archive CC0 collection
-- ============================================

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Ocean & Beach Sounds (27+ minutes!)
  ('cc0_nature_ocean_waves_beach', 'Ocean Waves with Beach Sounds', 'CC0 Nature Sounds', 'nature_sounds', 'instrumental', 1650, 0, 36, NULL, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ocean_waves_beach_cc0.mp3', 0),

  -- Sea Storm (60 minutes!)
  ('cc0_nature_sea_storm', 'Sea Storm Therapy', 'CC0 Nature Sounds', 'nature_sounds', 'instrumental', 3600, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sea_storm_cc0.mp3', 0),

  -- Stream with Birds (26+ minutes)
  ('cc0_nature_stream_birds', 'Trickling Stream with Birds', 'CC0 Nature Sounds', 'nature_sounds', 'instrumental', 1597, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/stream_birds_cc0.mp3', 0),

  -- Gentle Rain (36 minutes!)
  ('cc0_nature_gentle_rain', 'Light Gentle Rain', 'CC0 Nature Sounds', 'nature_sounds', 'instrumental', 2160, 0, 36, NULL, 0.93, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/gentle_rain_cc0.mp3', 0),

  -- Birdsong (9+ minutes)
  ('cc0_nature_birdsong', 'Relaxing Forest Birdsong', 'CC0 Nature Sounds', 'nature_sounds', 'instrumental', 582, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/birdsong_cc0.mp3', 0);

-- Update water sounds playlist with new high-quality tracks
DELETE FROM playlist_tracks WHERE playlist_id = 'pl_nature_water' AND track_id IN ('r2_nature_calm_ocean', 'r2_nature_beach_waves', 'r2_nature_sb_stream');

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_water', 'cc0_nature_ocean_waves_beach', 1),
  ('pl_nature_water', 'cc0_nature_stream_birds', 4),
  ('pl_nature_water', 'cc0_nature_sea_storm', 6);

-- Update rain playlist with new high-quality rain
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_rain', 'cc0_nature_gentle_rain', 1);

-- Update forest playlist with birdsong
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_forest', 'cc0_nature_birdsong', 1);

-- Create a new "Baby Sleep" playlist with best calming sounds
INSERT OR REPLACE INTO playlists (id, name, description, category, target_age_months, is_system)
VALUES ('pl_baby_sleep', 'Baby Sleep Sounds', 'Long-duration calming sounds perfect for baby sleep', 'nature_sounds', 0, 1);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_baby_sleep', 'cc0_nature_gentle_rain', 1),
  ('pl_baby_sleep', 'cc0_nature_ocean_waves_beach', 2),
  ('pl_baby_sleep', 'cc0_nature_stream_birds', 3),
  ('pl_baby_sleep', 'cc0_nature_birdsong', 4),
  ('pl_baby_sleep', 'cc0_nature_sea_storm', 5);

-- Summary: 5 high-quality CC0 nature sounds added
-- Total new duration: ~130 minutes of premium content
-- License: CC0 1.0 Universal (Public Domain)
