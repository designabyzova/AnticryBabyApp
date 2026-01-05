-- Migration: Premium Rain Sound - HIGH QUALITY
-- Generated: 2026-01-02
-- Source: FreeSoundsLibrary.com (CC-BY 4.0)
-- Quality: 320 kbps, 44.1 kHz stereo, 5:48 duration
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/012_premium_rain_sound.sql

-- Delete old low-quality rain tracks
DELETE FROM tracks WHERE id IN (
  'cc0_nature_gentle_rain',    -- Was 91 kbps, 22.05 kHz - sounded like noise
  'r2_nature_rain_ambient',
  'r2_nature_rain_gentle'
);

-- Insert PREMIUM HIGH-QUALITY rain sound
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  (
    'premium_gentle_rain',
    'Gentle Rain - Premium Quality',
    'Nature Recordings',
    'nature_sounds',
    'instrumental',
    348,                                    -- 5:48 duration
    0,
    36,
    NULL,
    0.95,                                   -- Very high calming score
    'recorded',
    NULL,
    'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/gentle_rain_premium.mp3',
    0                                       -- Free tier
  );

-- Update rain playlist with new premium track
DELETE FROM playlist_tracks WHERE playlist_id = 'pl_nature_rain' AND track_id = 'cc0_nature_gentle_rain';

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_rain', 'premium_gentle_rain', 1);

-- Update baby sleep playlist
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_baby_sleep', 'premium_gentle_rain', 1);

-- Summary:
-- ✅ Replaced low-quality 91kbps rain with professional 320kbps version
-- ✅ Audio quality: 320 kbps MP3, 44.1 kHz stereo (CD quality)
-- ✅ Duration: 5:48 minutes (perfect for looping)
-- ✅ License: CC-BY 4.0 (https://www.freesoundslibrary.com/6-minutes-of-rain-sound/)
-- ✅ Source attribution: FreeSoundsLibrary.com
