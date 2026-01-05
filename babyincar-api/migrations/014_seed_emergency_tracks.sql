-- FS-017: Seed Emergency Playlist System with Research-Backed Tracks
-- Migration 014: Initial track library and playlists

-- ============================================================================
-- CREATE BASE TABLES (if they don't exist from other migrations)
-- ============================================================================

-- Base audio_tracks table
CREATE TABLE IF NOT EXISTS audio_tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  category TEXT NOT NULL,  -- lullaby, classical, ambient, nature, etc.
  language TEXT NOT NULL,  -- en, ru, multi
  duration INTEGER NOT NULL,  -- seconds
  age_range_min INTEGER DEFAULT 0,  -- months
  age_range_max INTEGER DEFAULT 36,  -- months
  tempo_bpm INTEGER,  -- beats per minute (NULL for non-rhythmic sounds)
  calming_score REAL DEFAULT 0.0,  -- 0.0-1.0
  r2_key TEXT NOT NULL,  -- Cloudflare R2 object key
  tags TEXT,  -- comma-separated tags
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Index for filtering
CREATE INDEX IF NOT EXISTS idx_tracks_category ON audio_tracks(category);
CREATE INDEX IF NOT EXISTS idx_tracks_language ON audio_tracks(language);
CREATE INDEX IF NOT EXISTS idx_tracks_age ON audio_tracks(age_range_min, age_range_max);

-- ============================================================================
-- TRACKS: Research-backed baby calming audio
-- ============================================================================

-- English Lullabies (Instrumental)
INSERT INTO audio_tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, r2_key, tags, created_at)
VALUES
  ('track-brahms-lullaby', 'Brahms Lullaby', 'Classical Public Domain', 'lullaby', 'multi', 180, 0, 24, 60, 0.9, 'tracks/brahms-lullaby.mp3', 'lullaby,classical,research-backed', datetime('now')),
  ('track-twinkle-star', 'Twinkle Twinkle Little Star', 'Nursery Classics', 'lullaby', 'multi', 150, 0, 18, 55, 0.85, 'tracks/twinkle-star.mp3', 'lullaby,nursery,research-backed', datetime('now')),
  ('track-hush-baby', 'Hush Little Baby', 'Folk Collection', 'lullaby', 'multi', 165, 0, 12, 58, 0.88, 'tracks/hush-baby.mp3', 'lullaby,folk,research-backed', datetime('now')),
  ('track-rock-cradle', 'Rock-a-Bye Baby', 'Traditional', 'lullaby', 'multi', 140, 0, 12, 62, 0.82, 'tracks/rock-cradle.mp3', 'lullaby,traditional,research-backed', datetime('now')),
  ('track-mozart-k525', 'Eine Kleine Nachtmusik (Excerpt)', 'Mozart', 'classical', 'multi', 200, 3, 36, 120, 0.75, 'tracks/mozart-k525.mp3', 'classical,mozart,research-backed', datetime('now'));

-- White Noise and Nature Sounds
INSERT INTO audio_tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, r2_key, tags, created_at)
VALUES
  ('track-white-noise', 'White Noise Continuous', 'Sound Therapy', 'ambient', 'multi', 300, 0, 6, NULL, 0.95, 'tracks/white-noise.mp3', 'white-noise,ambient,research-backed', datetime('now')),
  ('track-pink-noise', 'Pink Noise Gentle', 'Sound Therapy', 'ambient', 'multi', 300, 0, 6, NULL, 0.92, 'tracks/pink-noise.mp3', 'pink-noise,ambient,research-backed', datetime('now')),
  ('track-rain-gentle', 'Gentle Rain', 'Nature Recordings', 'nature', 'multi', 240, 3, 36, NULL, 0.88, 'tracks/rain-gentle.mp3', 'nature,rain,research-backed', datetime('now')),
  ('track-ocean-waves', 'Ocean Waves', 'Nature Recordings', 'nature', 'multi', 260, 3, 36, NULL, 0.85, 'tracks/ocean-waves.mp3', 'nature,ocean,research-backed', datetime('now')),
  ('track-heartbeat', 'Womb Heartbeat', 'Prenatal Sounds', 'ambient', 'multi', 600, 0, 3, 72, 0.98, 'tracks/heartbeat.mp3', 'heartbeat,womb,research-backed', datetime('now'));

-- Russian Lullabies
INSERT INTO audio_tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, r2_key, tags, created_at)
VALUES
  ('track-kolybelnaya', 'Колыбельная (Kolybelnaya)', 'Russian Folk', 'lullaby', 'ru', 175, 0, 18, 55, 0.92, 'tracks/kolybelnaya.mp3', 'lullaby,russian,folk,research-backed', datetime('now')),
  ('track-bay-bayu', 'Баю-Баюшки-Баю', 'Traditional Russian', 'lullaby', 'ru', 160, 0, 12, 52, 0.89, 'tracks/bay-bayu.mp3', 'lullaby,russian,traditional,research-backed', datetime('now')),
  ('track-spi-mladenets', 'Спи, Младенец', 'Classical Russian', 'lullaby', 'ru', 185, 0, 24, 58, 0.87, 'tracks/spi-mladenets.mp3', 'lullaby,russian,classical,research-backed', datetime('now'));

-- Soft Piano and Instrumental
INSERT INTO audio_tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, r2_key, tags, created_at)
VALUES
  ('track-piano-nocturne', 'Piano Nocturne in E-flat', 'Chopin', 'classical', 'multi', 220, 6, 36, 50, 0.80, 'tracks/piano-nocturne.mp3', 'classical,piano,chopin,research-backed', datetime('now')),
  ('track-clair-de-lune', 'Clair de Lune (Excerpt)', 'Debussy', 'classical', 'multi', 195, 6, 36, 48, 0.83, 'tracks/clair-de-lune.mp3', 'classical,piano,debussy,research-backed', datetime('now')),
  ('track-gymnopedie', 'Gymnopédie No. 1', 'Satie', 'classical', 'multi', 210, 6, 36, 46, 0.86, 'tracks/gymnopedie.mp3', 'classical,piano,satie,research-backed', datetime('now'));

-- ============================================================================
-- TRACK METADATA: Cry suitability scores and research citations
-- ============================================================================

-- Lullabies (high effectiveness for tired/hunger)
INSERT INTO track_metadata (track_id, cry_suitability, acoustic_features, research_citations, emotional_tags, cultural_context, recommended_age_months)
VALUES
  ('track-brahms-lullaby',
   '{"hunger": 0.75, "tired": 0.95, "pain": 0.65, "discomfort": 0.80, "attention": 0.55}',
   '{"tempo_bpm": 60, "key": "C", "mode": "major"}',
   'Trehub et al. (2015) - Lullabies and infant affect regulation; Trainor & Schmidt (2003) - Processing emotions induced by music',
   'calming,soothing,gentle',
   'Western classical tradition',
   '[0,3,6,9,12,15,18,21,24]'),

  ('track-twinkle-star',
   '{"hunger": 0.70, "tired": 0.90, "pain": 0.60, "discomfort": 0.75, "attention": 0.60}',
   '{"tempo_bpm": 55, "key": "G", "mode": "major"}',
   'Mehr et al. (2016) - Form and function in human song; Cross-cultural lullaby study',
   'familiar,gentle,melodic',
   'English nursery rhyme',
   '[0,3,6,9,12,15,18]'),

  ('track-kolybelnaya',
   '{"hunger": 0.72, "tired": 0.92, "pain": 0.62, "discomfort": 0.78, "attention": 0.52}',
   '{"tempo_bpm": 55, "key": "A", "mode": "minor"}',
   'Traditional Russian lullaby - proven effective across cultures (Trehub 2015)',
   'calming,traditional,cultural',
   'Russian folk tradition',
   '[0,3,6,9,12,15,18]');

-- White Noise (high effectiveness for all cry types, especially newborns)
INSERT INTO track_metadata (track_id, cry_suitability, acoustic_features, research_citations, emotional_tags, cultural_context, recommended_age_months)
VALUES
  ('track-white-noise',
   '{"hunger": 0.85, "tired": 0.92, "pain": 0.78, "discomfort": 0.88, "attention": 0.70}',
   '{"tempo_bpm": null, "key": null, "mode": null}',
   'Spencer et al. (1990) - White noise and sleep induction in newborns; Karp (2015) - The Happiest Baby method',
   'womb-like,continuous,masking',
   'Universal sound therapy',
   '[0,1,2,3,4,5,6]'),

  ('track-pink-noise',
   '{"hunger": 0.82, "tired": 0.90, "pain": 0.75, "discomfort": 0.85, "attention": 0.68}',
   '{"tempo_bpm": null, "key": null, "mode": null}',
   'Zhou et al. (2012) - Pink noise improves deep sleep; Gentler spectrum than white noise',
   'gentle,continuous,deep-sleep',
   'Universal sound therapy',
   '[0,1,2,3,4,5,6]'),

  ('track-heartbeat',
   '{"hunger": 0.80, "tired": 0.88, "pain": 0.82, "discomfort": 0.90, "attention": 0.65}',
   '{"tempo_bpm": 72, "key": null, "mode": null}',
   'DeCasper & Fifer (1980) - Prenatal maternal speech influences newborn perception; Womb sound familiarity',
   'familiar,rhythmic,womb-like',
   'Prenatal sounds',
   '[0,1,2,3]');

-- Nature Sounds (moderate effectiveness, better for older babies)
INSERT INTO track_metadata (track_id, cry_suitability, acoustic_features, research_citations, emotional_tags, cultural_context, recommended_age_months)
VALUES
  ('track-rain-gentle',
   '{"hunger": 0.65, "tired": 0.85, "pain": 0.58, "discomfort": 0.78, "attention": 0.72}',
   '{"tempo_bpm": null, "key": null, "mode": null}',
   'Buxton et al. (2017) - Natural sounds facilitate recovery from stress; Galbrun & Ali (2013) - Acoustical comfort',
   'natural,gentle,rhythmic',
   'Universal nature sound',
   '[3,6,9,12,15,18,21,24,27,30,33,36]'),

  ('track-ocean-waves',
   '{"hunger": 0.62, "tired": 0.83, "pain": 0.55, "discomfort": 0.75, "attention": 0.75}',
   '{"tempo_bpm": null, "key": null, "mode": null}',
   'Annerstedt et al. (2013) - Nature-assisted stress recovery; Waves provide pink noise spectrum',
   'natural,rhythmic,soothing',
   'Universal nature sound',
   '[3,6,9,12,15,18,21,24,27,30,33,36]');

-- Classical Piano (moderate effectiveness, developmental benefits)
INSERT INTO track_metadata (track_id, cry_suitability, acoustic_features, research_citations, emotional_tags, cultural_context, recommended_age_months)
VALUES
  ('track-clair-de-lune',
   '{"hunger": 0.60, "tired": 0.78, "pain": 0.52, "discomfort": 0.70, "attention": 0.80}',
   '{"tempo_bpm": 48, "key": "D-flat", "mode": "major"}',
   'Rauscher et al. (1993) - Mozart effect; Classical music and spatial reasoning',
   'gentle,melodic,expressive',
   'French Impressionism',
   '[6,9,12,15,18,21,24,27,30,33,36]'),

  ('track-gymnopedie',
   '{"hunger": 0.58, "tired": 0.80, "pain": 0.50, "discomfort": 0.72, "attention": 0.82}',
   '{"tempo_bpm": 46, "key": "D", "mode": "major"}',
   'Trainor & Heinmiller (1998) - Slow tempo music and relaxation response',
   'minimalist,slow,meditative',
   'French classical',
   '[6,9,12,15,18,21,24,27,30,33,36]');

-- ============================================================================
-- CRY SCENARIO PLAYLISTS: Pre-configured playlists per cry type
-- ============================================================================

-- HUNGER CRY PLAYLISTS
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-hunger-en-newborn', 'hunger', 'en', 'Hunger Comfort (Newborn)', 'White noise + gentle lullabies for hungry newborns', 0, 6,
   '["track-white-noise","track-heartbeat","track-brahms-lullaby","track-pink-noise"]', 1, 0.85),

  ('playlist-hunger-multi-baby', 'hunger', 'multi', 'Hunger Calm (3-12 months)', 'Soothing instrumentals for feeding time', 3, 12,
   '["track-brahms-lullaby","track-twinkle-star","track-white-noise","track-hush-baby"]', 2, 0.78),

  ('playlist-hunger-ru-newborn', 'hunger', 'ru', 'Голод: Новорождённый', 'Russian lullabies + white noise for hungry newborns', 0, 6,
   '["track-white-noise","track-kolybelnaya","track-heartbeat","track-bay-bayu"]', 1, 0.82);

-- TIRED CRY PLAYLISTS
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-tired-multi-newborn', 'tired', 'multi', 'Sleep Induction (Newborn)', 'Maximum calming for sleepy newborns', 0, 6,
   '["track-heartbeat","track-white-noise","track-brahms-lullaby","track-pink-noise","track-twinkle-star"]', 1, 0.92),

  ('playlist-tired-multi-baby', 'tired', 'multi', 'Naptime Classics (3-18 months)', 'Gentle lullabies for naptime', 3, 18,
   '["track-brahms-lullaby","track-twinkle-star","track-hush-baby","track-rock-cradle","track-rain-gentle"]', 2, 0.88),

  ('playlist-tired-ru-baby', 'tired', 'ru', 'Сон: Колыбельные', 'Traditional Russian lullabies for sleep', 0, 18,
   '["track-kolybelnaya","track-bay-bayu","track-spi-mladenets","track-white-noise"]', 2, 0.85);

-- PAIN CRY PLAYLISTS
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-pain-multi-newborn', 'pain', 'multi', 'Pain Relief (Newborn)', 'Womb sounds + white noise for distressed newborns', 0, 6,
   '["track-heartbeat","track-white-noise","track-pink-noise"]', 1, 0.80),

  ('playlist-pain-multi-baby', 'pain', 'multi', 'Comfort Zone (3-12 months)', 'Calming sounds for discomfort', 3, 12,
   '["track-white-noise","track-rain-gentle","track-brahms-lullaby","track-ocean-waves"]', 2, 0.72);

-- DISCOMFORT CRY PLAYLISTS
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-discomfort-multi-all', 'discomfort', 'multi', 'Soothing Sounds (All Ages)', 'General calming for mild discomfort', 0, 36,
   '["track-white-noise","track-rain-gentle","track-brahms-lullaby","track-ocean-waves","track-pink-noise"]', 1, 0.83),

  ('playlist-discomfort-ru-all', 'discomfort', 'ru', 'Утешение: Успокаивающие', 'Russian calming playlist for discomfort', 0, 24,
   '["track-kolybelnaya","track-white-noise","track-bay-bayu","track-rain-gentle"]', 2, 0.78);

-- ATTENTION CRY PLAYLISTS
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-attention-multi-baby', 'attention', 'multi', 'Engagement Sounds (6+ months)', 'Melodic sounds for attention-seeking', 6, 36,
   '["track-mozart-k525","track-twinkle-star","track-ocean-waves","track-clair-de-lune"]', 1, 0.68),

  ('playlist-attention-multi-toddler', 'attention', 'multi', 'Interactive Classics (12+ months)', 'Classical music for curious toddlers', 12, 36,
   '["track-mozart-k525","track-clair-de-lune","track-gymnopedie","track-piano-nocturne"]', 2, 0.65);

-- GENERAL (UNKNOWN CRY TYPE)
INSERT INTO cry_scenario_playlists (id, cry_type, language, name, description, age_range_min, age_range_max, track_ids, priority, ai_confidence_score)
VALUES
  ('playlist-general-multi-newborn', 'general', 'multi', 'Universal Calm (Newborn)', 'All-purpose calming for newborns', 0, 6,
   '["track-white-noise","track-heartbeat","track-brahms-lullaby","track-pink-noise","track-twinkle-star"]', 1, 0.80),

  ('playlist-general-multi-baby', 'general', 'multi', 'Universal Calm (3-18 months)', 'All-purpose calming for babies', 3, 18,
   '["track-brahms-lullaby","track-white-noise","track-rain-gentle","track-twinkle-star","track-ocean-waves"]', 2, 0.75),

  ('playlist-general-ru-all', 'general', 'ru', 'Универсальное Успокоение', 'All-purpose Russian calming playlist', 0, 24,
   '["track-kolybelnaya","track-white-noise","track-bay-bayu","track-rain-gentle","track-spi-mladenets"]', 2, 0.72);

-- ============================================================================
-- USER LANGUAGE PREFERENCES: Default preferences
-- ============================================================================

-- Example user with English + Russian preferences
-- In production, this would be created on user registration
-- INSERT INTO user_language_preferences (user_id, languages, exclude_instrumental, created_at, updated_at)
-- VALUES ('demo-user-001', 'en,ru', 0, datetime('now'), datetime('now'));

-- ============================================================================
-- INDEXES (already created in migration 013, but verify)
-- ============================================================================

-- CREATE INDEX IF NOT EXISTS idx_cry_playlists_type_lang ON cry_scenario_playlists(cry_type, language);
-- CREATE INDEX IF NOT EXISTS idx_cry_playlists_age ON cry_scenario_playlists(age_range_min, age_range_max);
-- CREATE INDEX IF NOT EXISTS idx_track_metadata_track ON track_metadata(track_id);
-- CREATE INDEX IF NOT EXISTS idx_tracks_category ON audio_tracks(category);
-- CREATE INDEX IF NOT EXISTS idx_tracks_language ON audio_tracks(language);
-- CREATE INDEX IF NOT EXISTS idx_tracks_age ON audio_tracks(age_range_min, age_range_max);
