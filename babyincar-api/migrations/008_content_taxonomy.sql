-- Content Taxonomy & Search Migration
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/008_content_taxonomy.sql

-- ============================================
-- 1. TAXONOMY TABLE
-- Stores structured taxonomy for browsable content discovery
-- ============================================

CREATE TABLE IF NOT EXISTS content_taxonomy (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  track_id TEXT NOT NULL,
  taxonomy_type TEXT NOT NULL CHECK (taxonomy_type IN ('origin', 'author', 'theme', 'source', 'collection')),
  taxonomy_value TEXT NOT NULL,
  display_name TEXT NOT NULL,
  display_name_localized TEXT DEFAULT '{}', -- JSON: {"en": "Russian Tales", "ru": "Русские сказки"}
  icon TEXT, -- SF Symbol name or emoji
  sort_order INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE,
  UNIQUE (track_id, taxonomy_type, taxonomy_value)
);

-- Indices for fast lookups
CREATE INDEX IF NOT EXISTS idx_taxonomy_type_value ON content_taxonomy(taxonomy_type, taxonomy_value);
CREATE INDEX IF NOT EXISTS idx_taxonomy_track ON content_taxonomy(track_id);

-- ============================================
-- 2. TAXONOMY CATALOG
-- Master list of taxonomy values with metadata
-- ============================================

CREATE TABLE IF NOT EXISTS taxonomy_catalog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taxonomy_type TEXT NOT NULL,
  taxonomy_value TEXT NOT NULL,
  display_name TEXT NOT NULL,
  display_name_localized TEXT DEFAULT '{}',
  description TEXT,
  icon TEXT,
  color TEXT, -- Hex color for UI
  parent_value TEXT, -- For hierarchical taxonomies
  sort_order INTEGER DEFAULT 0,
  is_featured INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (taxonomy_type, taxonomy_value)
);

CREATE INDEX IF NOT EXISTS idx_catalog_type ON taxonomy_catalog(taxonomy_type);
CREATE INDEX IF NOT EXISTS idx_catalog_featured ON taxonomy_catalog(is_featured);

-- ============================================
-- 3. FULL-TEXT SEARCH
-- FTS5 virtual table for fast text search
-- Note: D1 supports FTS5 natively
-- ============================================

-- Add searchable fields to tracks if not exists
-- We'll add a 'search_text' column that combines all searchable fields
ALTER TABLE tracks ADD COLUMN search_text TEXT;
ALTER TABLE tracks ADD COLUMN description TEXT;
ALTER TABLE tracks ADD COLUMN themes TEXT; -- JSON array of themes

-- Create FTS5 virtual table
CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5(
  title,
  artist,
  search_text,
  content='tracks',
  content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 2'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS tracks_ai AFTER INSERT ON tracks BEGIN
  INSERT INTO tracks_fts(rowid, title, artist, search_text)
  VALUES (new.rowid, new.title, new.artist, new.search_text);
END;

CREATE TRIGGER IF NOT EXISTS tracks_ad AFTER DELETE ON tracks BEGIN
  INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, search_text)
  VALUES ('delete', old.rowid, old.title, old.artist, old.search_text);
END;

CREATE TRIGGER IF NOT EXISTS tracks_au AFTER UPDATE ON tracks BEGIN
  INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, search_text)
  VALUES ('delete', old.rowid, old.title, old.artist, old.search_text);
  INSERT INTO tracks_fts(rowid, title, artist, search_text)
  VALUES (new.rowid, new.title, new.artist, new.search_text);
END;

-- ============================================
-- 4. SEARCH HISTORY
-- For recent searches and suggestions
-- ============================================

CREATE TABLE IF NOT EXISTS search_history (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  query TEXT NOT NULL,
  query_normalized TEXT NOT NULL, -- Lowercase, trimmed for dedup
  results_count INTEGER DEFAULT 0,
  selected_track_id TEXT, -- If user selected a result
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (selected_track_id) REFERENCES tracks(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_search_user ON search_history(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_query ON search_history(query_normalized);

-- ============================================
-- 5. POPULAR SEARCHES (Aggregated)
-- ============================================

CREATE TABLE IF NOT EXISTS popular_searches (
  query_normalized TEXT PRIMARY KEY,
  display_query TEXT NOT NULL,
  search_count INTEGER DEFAULT 1,
  last_searched_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. SEED TAXONOMY CATALOG
-- Pre-populate with known taxonomy values
-- ============================================

-- Origins (Language/Culture)
INSERT OR REPLACE INTO taxonomy_catalog (taxonomy_type, taxonomy_value, display_name, display_name_localized, icon, color, sort_order, is_featured) VALUES
  ('origin', 'russian', 'Russian Tales', '{"en": "Russian Tales", "ru": "Русские сказки"}', 'globe.europe.africa', '#E53935', 1, 1),
  ('origin', 'german', 'German Tales', '{"en": "German Tales", "ru": "Немецкие сказки", "de": "Deutsche Märchen"}', 'globe.europe.africa', '#FFC107', 2, 1),
  ('origin', 'english', 'English Tales', '{"en": "English Tales", "ru": "Английские сказки"}', 'globe.europe.africa', '#2196F3', 3, 1),
  ('origin', 'french', 'French Tales', '{"en": "French Tales", "ru": "Французские сказки", "fr": "Contes français"}', 'globe.europe.africa', '#9C27B0', 4, 0),
  ('origin', 'scandinavian', 'Scandinavian Tales', '{"en": "Scandinavian Tales", "ru": "Скандинавские сказки"}', 'globe.europe.africa', '#00BCD4', 5, 0),
  ('origin', 'japanese', 'Japanese Tales', '{"en": "Japanese Tales", "ru": "Японские сказки", "ja": "日本の昔話"}', 'globe.asia.australia', '#FF5722', 6, 0),
  ('origin', 'arabian', 'Arabian Tales', '{"en": "Arabian Tales", "ru": "Арабские сказки"}', 'globe.europe.africa', '#795548', 7, 0),
  ('origin', 'indian', 'Indian Tales', '{"en": "Indian Tales", "ru": "Индийские сказки"}', 'globe.asia.australia', '#FF9800', 8, 0),
  ('origin', 'chinese', 'Chinese Tales', '{"en": "Chinese Tales", "ru": "Китайские сказки", "zh": "中国民间故事"}', 'globe.asia.australia', '#F44336', 9, 0),
  ('origin', 'african', 'African Tales', '{"en": "African Tales", "ru": "Африканские сказки"}', 'globe.europe.africa', '#4CAF50', 10, 0),
  ('origin', 'american', 'American Tales', '{"en": "American Tales", "ru": "Американские сказки"}', 'globe.americas', '#3F51B5', 11, 0);

-- Authors/Collectors
INSERT OR REPLACE INTO taxonomy_catalog (taxonomy_type, taxonomy_value, display_name, display_name_localized, icon, sort_order, is_featured) VALUES
  ('author', 'brothers_grimm', 'Brothers Grimm', '{"en": "Brothers Grimm", "ru": "Братья Гримм", "de": "Brüder Grimm"}', 'person.2', 1, 1),
  ('author', 'afanasyev', 'Alexander Afanasyev', '{"en": "Alexander Afanasyev", "ru": "Александр Афанасьев"}', 'person', 2, 1),
  ('author', 'andersen', 'Hans Christian Andersen', '{"en": "Hans Christian Andersen", "ru": "Ганс Христиан Андерсен"}', 'person', 3, 1),
  ('author', 'perrault', 'Charles Perrault', '{"en": "Charles Perrault", "ru": "Шарль Перро"}', 'person', 4, 0),
  ('author', 'pushkin', 'Alexander Pushkin', '{"en": "Alexander Pushkin", "ru": "Александр Пушкин"}', 'person', 5, 0),
  ('author', 'aesop', 'Aesop', '{"en": "Aesop", "ru": "Эзоп"}', 'person', 6, 0),
  ('author', 'folk', 'Folk Tales', '{"en": "Folk Tales", "ru": "Народные сказки"}', 'person.3', 7, 0);

-- Themes
INSERT OR REPLACE INTO taxonomy_catalog (taxonomy_type, taxonomy_value, display_name, display_name_localized, icon, color, sort_order, is_featured) VALUES
  ('theme', 'animals', 'Animals', '{"en": "Animals", "ru": "Животные"}', 'hare', '#8BC34A', 1, 1),
  ('theme', 'magic', 'Magic & Fantasy', '{"en": "Magic & Fantasy", "ru": "Волшебство"}', 'wand.and.stars', '#9C27B0', 2, 1),
  ('theme', 'adventure', 'Adventure', '{"en": "Adventure", "ru": "Приключения"}', 'figure.hiking', '#FF9800', 3, 1),
  ('theme', 'princess', 'Princesses & Royalty', '{"en": "Princesses & Royalty", "ru": "Принцессы и короли"}', 'crown', '#E91E63', 4, 1),
  ('theme', 'moral', 'Moral Lessons', '{"en": "Moral Lessons", "ru": "Поучительные"}', 'lightbulb', '#FFEB3B', 5, 0),
  ('theme', 'bedtime', 'Bedtime Stories', '{"en": "Bedtime Stories", "ru": "Сказки на ночь"}', 'moon.stars', '#3F51B5', 6, 1),
  ('theme', 'funny', 'Funny Stories', '{"en": "Funny Stories", "ru": "Смешные сказки"}', 'face.smiling', '#FFEB3B', 7, 0),
  ('theme', 'scary', 'Slightly Scary', '{"en": "Slightly Scary", "ru": "Немного страшные"}', 'ghost', '#607D8B', 8, 0),
  ('theme', 'nature', 'Nature & Seasons', '{"en": "Nature & Seasons", "ru": "Природа и времена года"}', 'leaf', '#4CAF50', 9, 0),
  ('theme', 'friendship', 'Friendship', '{"en": "Friendship", "ru": "Дружба"}', 'heart', '#E91E63', 10, 0),
  ('theme', 'clever', 'Clever Heroes', '{"en": "Clever Heroes", "ru": "Умные герои"}', 'brain', '#00BCD4', 11, 0),
  ('theme', 'short', 'Short Stories', '{"en": "Short Stories (< 5 min)", "ru": "Короткие (< 5 мин)"}', 'clock', '#9E9E9E', 12, 1);

-- Sources
INSERT OR REPLACE INTO taxonomy_catalog (taxonomy_type, taxonomy_value, display_name, display_name_localized, icon, sort_order, is_featured) VALUES
  ('source', 'librivox', 'LibriVox', '{"en": "LibriVox - Free Audiobooks", "ru": "LibriVox - Бесплатные аудиокниги"}', 'book', 1, 1),
  ('source', 'internet_archive', 'Internet Archive', '{"en": "Internet Archive", "ru": "Интернет Архив"}', 'archivebox', 2, 1),
  ('source', 'freesound', 'Freesound', '{"en": "Freesound", "ru": "Freesound"}', 'waveform', 3, 0),
  ('source', 'original', 'Original Content', '{"en": "AntiCry Originals", "ru": "Оригиналы AntiCry"}', 'star', 4, 1),
  ('source', 'public_domain', 'Public Domain', '{"en": "Public Domain", "ru": "Общественное достояние"}', 'globe', 5, 0);

-- Collections (Curated groupings)
INSERT OR REPLACE INTO taxonomy_catalog (taxonomy_type, taxonomy_value, display_name, display_name_localized, icon, color, sort_order, is_featured) VALUES
  ('collection', 'bedtime_favorites', 'Bedtime Favorites', '{"en": "Bedtime Favorites", "ru": "Любимые на ночь"}', 'moon.stars', '#3F51B5', 1, 1),
  ('collection', 'classic_tales', 'Classic Tales', '{"en": "Classic Tales", "ru": "Классические сказки"}', 'book.closed', '#795548', 2, 1),
  ('collection', 'calming_nature', 'Calming Nature', '{"en": "Calming Nature", "ru": "Успокаивающая природа"}', 'leaf', '#4CAF50', 3, 1),
  ('collection', 'russian_classics', 'Russian Classics', '{"en": "Russian Classics", "ru": "Русская классика"}', 'flag', '#E53935', 4, 1),
  ('collection', 'grimm_best', 'Best of Grimm', '{"en": "Best of Brothers Grimm", "ru": "Лучшее от братьев Гримм"}', 'star', '#FFC107', 5, 1);

-- ============================================
-- 7. POPULATE TAXONOMY FROM EXISTING TRACKS
-- ============================================

-- Update search_text field for existing tracks
UPDATE tracks SET search_text =
  title || ' ' ||
  COALESCE(artist, '') || ' ' ||
  COALESCE(tags, '') || ' ' ||
  COALESCE(category, '')
WHERE search_text IS NULL;

-- Rebuild FTS index
INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');

-- Populate taxonomy from existing tracks

-- Origin: Russian tracks (language = 'ru' or artist contains Russian name)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'origin', 'russian', 'Russian'
FROM tracks
WHERE language = 'ru'
   OR artist LIKE '%Афанасьев%'
   OR artist LIKE '%Пушкин%'
   OR tags LIKE '%russian%';

-- Origin: German tracks (artist = Brothers Grimm)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'origin', 'german', 'German'
FROM tracks
WHERE artist LIKE '%Grimm%'
   OR tags LIKE '%grimm%';

-- Origin: English tracks
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'origin', 'english', 'English'
FROM tracks
WHERE language = 'en'
  AND id NOT IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'origin');

-- Author: Brothers Grimm
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'author', 'brothers_grimm', 'Brothers Grimm'
FROM tracks
WHERE artist LIKE '%Grimm%';

-- Author: Afanasyev
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'author', 'afanasyev', 'Alexander Afanasyev'
FROM tracks
WHERE artist LIKE '%Афанасьев%';

-- Theme: Animals (from tags)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'animals', 'Animals'
FROM tracks
WHERE tags LIKE '%wolf%'
   OR tags LIKE '%fox%'
   OR tags LIKE '%bear%'
   OR tags LIKE '%cat%'
   OR tags LIKE '%dog%'
   OR tags LIKE '%bird%'
   OR tags LIKE '%frog%'
   OR tags LIKE '%horse%'
   OR tags LIKE '%animals%'
   OR tags LIKE '%goat%'
   OR tags LIKE '%rooster%'
   OR tags LIKE '%hen%';

-- Theme: Magic
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'magic', 'Magic'
FROM tracks
WHERE tags LIKE '%magic%'
   OR tags LIKE '%witch%'
   OR tags LIKE '%transformation%'
   OR tags LIKE '%wishes%'
   OR tags LIKE '%koschei%'
   OR tags LIKE '%baba_yaga%';

-- Theme: Princess/Royalty
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'princess', 'Princesses'
FROM tracks
WHERE tags LIKE '%princess%'
   OR tags LIKE '%prince%'
   OR tags LIKE '%king%'
   OR tags LIKE '%queen%'
   OR title LIKE '%Царевна%'
   OR title LIKE '%Царевич%';

-- Theme: Adventure
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'adventure', 'Adventure'
FROM tracks
WHERE tags LIKE '%adventure%'
   OR tags LIKE '%quest%'
   OR tags LIKE '%journey%'
   OR tags LIKE '%hero%';

-- Theme: Moral
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'moral', 'Moral'
FROM tracks
WHERE tags LIKE '%moral%'
   OR tags LIKE '%lesson%';

-- Theme: Funny
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'funny', 'Funny'
FROM tracks
WHERE tags LIKE '%funny%'
   OR tags LIKE '%humor%'
   OR tags LIKE '%silly%';

-- Theme: Classic
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'classic', 'Classic'
FROM tracks
WHERE tags LIKE '%classic%';

-- Theme: Short stories (duration < 300 seconds = 5 min)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'short', 'Short'
FROM tracks
WHERE duration <= 300 AND category = 'fairy_tales';

-- Theme: Bedtime (high calming score fairy tales)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'theme', 'bedtime', 'Bedtime'
FROM tracks
WHERE calming_score >= 0.8 AND category IN ('fairy_tales', 'classical_music', 'nature_sounds');

-- Source: LibriVox
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'source', 'librivox', 'LibriVox'
FROM tracks
WHERE source = 'librivox';

-- Source: Public Domain (all fairy tales from LibriVox)
INSERT OR IGNORE INTO content_taxonomy (track_id, taxonomy_type, taxonomy_value, display_name)
SELECT id, 'source', 'public_domain', 'Public Domain'
FROM tracks
WHERE license = 'Public Domain';

-- ============================================
-- 8. VIEW FOR EASY TAXONOMY QUERIES
-- ============================================

CREATE VIEW IF NOT EXISTS v_taxonomy_counts AS
SELECT
  tc.taxonomy_type,
  tc.taxonomy_value,
  cat.display_name,
  cat.display_name_localized,
  cat.icon,
  cat.color,
  cat.is_featured,
  COUNT(DISTINCT tc.track_id) as track_count
FROM content_taxonomy tc
JOIN taxonomy_catalog cat ON tc.taxonomy_type = cat.taxonomy_type AND tc.taxonomy_value = cat.taxonomy_value
GROUP BY tc.taxonomy_type, tc.taxonomy_value
ORDER BY tc.taxonomy_type, cat.sort_order, track_count DESC;

-- ============================================
-- 9. SYNONYM TABLE FOR SEARCH
-- Maps alternative terms to canonical terms
-- ============================================

CREATE TABLE IF NOT EXISTS search_synonyms (
  term TEXT PRIMARY KEY,
  canonical TEXT NOT NULL,
  language TEXT DEFAULT 'en'
);

INSERT OR REPLACE INTO search_synonyms (term, canonical, language) VALUES
  -- Russian synonyms
  ('сказки', 'fairy tales', 'ru'),
  ('колыбельная', 'lullaby', 'ru'),
  ('колыбельные', 'lullabies', 'ru'),
  ('русские', 'russian', 'ru'),
  ('немецкие', 'german', 'ru'),
  ('животные', 'animals', 'ru'),
  ('волшебство', 'magic', 'ru'),
  ('принцесса', 'princess', 'ru'),
  ('на ночь', 'bedtime', 'ru'),
  ('короткие', 'short', 'ru'),
  ('смешные', 'funny', 'ru'),
  ('гримм', 'grimm', 'ru'),
  ('афанасьев', 'afanasyev', 'ru'),

  -- English synonyms
  ('fairytales', 'fairy tales', 'en'),
  ('fairy-tales', 'fairy tales', 'en'),
  ('bed time', 'bedtime', 'en'),
  ('sleep stories', 'bedtime', 'en'),
  ('sleepy', 'bedtime', 'en'),
  ('calming', 'bedtime', 'en'),
  ('soothing', 'calming', 'en'),
  ('kids', 'children', 'en'),
  ('toddler', 'children', 'en'),
  ('tales', 'fairy tales', 'en'),
  ('stories', 'fairy tales', 'en'),
  ('nature', 'nature_sounds', 'en'),
  ('rain', 'nature_sounds', 'en'),
  ('forest', 'nature_sounds', 'en'),
  ('ocean', 'nature_sounds', 'en'),
  ('white noise', 'white_noise', 'en'),
  ('whitenoise', 'white_noise', 'en'),
  ('classical', 'classical_music', 'en'),
  ('mozart', 'classical_music', 'en'),
  ('chopin', 'classical_music', 'en'),
  ('lullaby', 'lullabies', 'en');

CREATE INDEX IF NOT EXISTS idx_synonyms_lang ON search_synonyms(language);
