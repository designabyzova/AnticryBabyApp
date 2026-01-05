-- FS-017: Simplified Emergency Playlist Seed (No Foreign Keys)
-- Migration 015: Seed data for iOS testing

-- ============================================================================
-- SIMPLE APPROACH: Insert test data directly into existing tables
-- ============================================================================

-- INSERT TRACKS INTO CRY_SCENARIO_PLAYLISTS (Simplified - using track_ids as JSON array)

-- HUNGER PLAYLISTS
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-hunger-newborn-multi', 'hunger', 'Hunger Comfort (Newborn)', 'White noise + gentle lullabies for hungry newborns', 'multi', 0, 6, 1, 0.85, 4, datetime('now')),
  ('pl-hunger-baby-multi', 'hunger', 'Hunger Calm (3-12 months)', 'Soothing instrumentals for feeding time', 'multi', 3, 12, 2, 0.78, 4, datetime('now')),
  ('pl-hunger-newborn-ru', 'hunger', 'Голод: Новорождённый', 'Russian lullabies + white noise for hungry newborns', 'ru', 0, 6, 1, 0.82, 4, datetime('now'));

-- TIRED PLAYLISTS
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-tired-newborn-multi', 'tired', 'Sleep Induction (Newborn)', 'Maximum calming for sleepy newborns', 'multi', 0, 6, 1, 0.92, 5, datetime('now')),
  ('pl-tired-baby-multi', 'tired', 'Naptime Classics (3-18 months)', 'Gentle lullabies for naptime', 'multi', 3, 18, 2, 0.88, 5, datetime('now')),
  ('pl-tired-baby-ru', 'tired', 'Сон: Колыбельные', 'Traditional Russian lullabies for sleep', 'ru', 0, 18, 2, 0.85, 4, datetime('now'));

-- PAIN PLAYLISTS
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-pain-newborn-multi', 'pain', 'Pain Relief (Newborn)', 'Womb sounds + white noise for distressed newborns', 'multi', 0, 6, 1, 0.80, 3, datetime('now')),
  ('pl-pain-baby-multi', 'pain', 'Comfort Zone (3-12 months)', 'Calming sounds for discomfort', 'multi', 3, 12, 2, 0.72, 4, datetime('now'));

-- DISCOMFORT PLAYLISTS
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-discomfort-all-multi', 'discomfort', 'Soothing Sounds (All Ages)', 'General calming for mild discomfort', 'multi', 0, 36, 1, 0.83, 5, datetime('now')),
  ('pl-discomfort-all-ru', 'discomfort', 'Утешение: Успокаивающие', 'Russian calming playlist for discomfort', 'ru', 0, 24, 2, 0.78, 4, datetime('now'));

-- ATTENTION PLAYLISTS
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-attention-baby-multi', 'attention', 'Engagement Sounds (6+ months)', 'Melodic sounds for attention-seeking', 'multi', 6, 36, 1, 0.68, 4, datetime('now')),
  ('pl-attention-toddler-multi', 'attention', 'Interactive Classics (12+ months)', 'Classical music for curious toddlers', 'multi', 12, 36, 2, 0.65, 4, datetime('now'));

-- GENERAL (UNKNOWN CRY TYPE)
INSERT OR IGNORE INTO cry_scenario_playlists (id, cry_type, name, description, language, age_range_min, age_range_max, priority, ai_confidence_score, track_count, created_at)
VALUES
  ('pl-general-newborn-multi', 'general', 'Universal Calm (Newborn)', 'All-purpose calming for newborns', 'multi', 0, 6, 1, 0.80, 5, datetime('now')),
  ('pl-general-baby-multi', 'general', 'Universal Calm (3-18 months)', 'All-purpose calming for babies', 'multi', 3, 18, 2, 0.75, 5, datetime('now')),
  ('pl-general-all-ru', 'general', 'Универсальное Успокоение', 'All-purpose Russian calming playlist', 'ru', 0, 24, 2, 0.72, 5, datetime('now'));

-- INSERT MOCK TRACK METADATA (simplified - only what's needed for AI selection)
INSERT OR IGNORE INTO track_metadata (track_id, cry_suitability, acoustic_features, research_citations, emotional_tags, cultural_context, recommended_age_months)
VALUES
  -- White Noise (universal calming)
  ('mock-white-noise', '{"hunger": 0.85, "tired": 0.92, "pain": 0.78, "discomfort": 0.88, "attention": 0.70}',
   '{}', 'Spencer et al. (1990) - White noise and sleep induction in newborns', 'womb-like,continuous', 'Universal', '[0,1,2,3,4,5,6]'),

  -- Heartbeat (womb sounds)
  ('mock-heartbeat', '{"hunger": 0.80, "tired": 0.88, "pain": 0.82, "discomfort": 0.90, "attention": 0.65}',
   '{"tempo_bpm": 72}', 'DeCasper & Fifer (1980) - Prenatal maternal speech', 'familiar,rhythmic,womb-like', 'Prenatal', '[0,1,2,3]'),

  -- Brahms Lullaby
  ('mock-brahms', '{"hunger": 0.75, "tired": 0.95, "pain": 0.65, "discomfort": 0.80, "attention": 0.55}',
   '{"tempo_bpm": 60, "key": "C", "mode": "major"}', 'Trehub et al. (2015) - Lullabies and infant affect regulation', 'calming,soothing', 'Western classical', '[0,3,6,9,12,15,18,21,24]'),

  -- Russian Lullaby
  ('mock-kolybelnaya', '{"hunger": 0.72, "tired": 0.92, "pain": 0.62, "discomfort": 0.78, "attention": 0.52}',
   '{"tempo_bpm": 55, "key": "A", "mode": "minor"}', 'Traditional Russian lullaby - proven effective across cultures', 'calming,traditional', 'Russian folk', '[0,3,6,9,12,15,18]'),

  -- Rain Sounds
  ('mock-rain', '{"hunger": 0.65, "tired": 0.85, "pain": 0.58, "discomfort": 0.78, "attention": 0.72}',
   '{}', 'Buxton et al. (2017) - Natural sounds facilitate recovery from stress', 'natural,gentle', 'Nature', '[3,6,9,12,15,18,21,24,27,30,33,36]'),

  -- Ocean Waves
  ('mock-ocean', '{"hunger": 0.62, "tired": 0.83, "pain": 0.55, "discomfort": 0.75, "attention": 0.75}',
   '{}', 'Annerstedt et al. (2013) - Nature-assisted stress recovery', 'natural,rhythmic', 'Nature', '[3,6,9,12,15,18,21,24,27,30,33,36]'),

  -- Mozart (attention/engagement)
  ('mock-mozart', '{"hunger": 0.55, "tired": 0.65, "pain": 0.48, "discomfort": 0.60, "attention": 0.88}',
   '{"tempo_bpm": 120}', 'Rauscher et al. (1993) - Mozart effect', 'melodic,engaging', 'Western classical', '[6,9,12,15,18,21,24,27,30,33,36]');

-- SUCCESS MESSAGE
SELECT '✅ Emergency playlist metadata seeded successfully!' AS message;
SELECT COUNT(*) || ' playlists created' AS playlists FROM cry_scenario_playlists;
SELECT COUNT(*) || ' track metadata entries created' AS metadata FROM track_metadata;
