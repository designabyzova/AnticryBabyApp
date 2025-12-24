-- Baby in Car - Seed Content Data
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/002_seed_content.sql

-- ============================================
-- WHITE NOISE & CALMING SOUNDS
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, calming_score, audio_source_type, generator_type, is_premium) VALUES
('track_wn_001', 'Pure White Noise', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 36, 0.90, 'generated', 'white_noise', 0),
('track_wn_002', 'Soft Pink Noise', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 36, 0.92, 'generated', 'pink_noise', 0),
('track_wn_003', 'Deep Brown Noise', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 36, 0.88, 'generated', 'brown_noise', 0),
('track_wn_004', 'Womb Sounds', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 6, 0.95, 'generated', 'womb', 0),
('track_wn_005', 'Mother''s Heartbeat', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 6, 0.94, 'generated', 'heartbeat', 0),
('track_wn_006', 'Gentle Shushing', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 12, 0.93, 'generated', 'shushing', 0),
('track_wn_007', 'Vacuum Cleaner', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 24, 0.85, 'generated', 'vacuum', 1),
('track_wn_008', 'Hair Dryer', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 24, 0.84, 'generated', 'hair_dryer', 1),
('track_wn_009', 'Electric Fan', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 36, 0.86, 'generated', 'fan', 0),
('track_wn_010', 'Washing Machine', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 24, 0.83, 'generated', 'washing_machine', 1),
('track_wn_011', 'Car Engine Hum', 'Baby in Car', 'white_noise', 'instrumental', 3600, 0, 36, 0.87, 'generated', 'car_engine', 0);

-- ============================================
-- NATURE SOUNDS
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, calming_score, audio_source_type, generator_type, is_premium) VALUES
('track_ns_001', 'Gentle Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 0, 36, 0.91, 'generated', 'rain', 0),
('track_ns_002', 'Ocean Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 0, 36, 0.90, 'generated', 'ocean', 0),
('track_ns_003', 'Babbling Brook', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 3, 36, 0.88, 'generated', 'river', 0),
('track_ns_004', 'Soft Breeze', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 3, 36, 0.85, 'generated', 'wind', 1),
('track_ns_005', 'Distant Thunder', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 6, 36, 0.82, 'generated', 'thunderstorm', 1),
('track_ns_006', 'Morning Birds', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 6, 36, 0.80, 'generated', 'birds', 1),
('track_ns_007', 'Summer Crickets', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 6, 36, 0.78, 'generated', 'crickets', 1),
('track_ns_008', 'Crackling Fire', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 6, 36, 0.84, 'generated', 'fireplace', 1);

-- ============================================
-- INSTRUMENTAL / MUSIC BOX
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, is_premium) VALUES
('track_in_001', 'Music Box Lullaby', 'Instrumental', 'instrumental', 'instrumental', 1800, 0, 36, 60, 0.89, 'generated', 'lullaby', 0),
('track_in_002', 'Gentle Music Box', 'Instrumental', 'instrumental', 'instrumental', 1800, 0, 36, 55, 0.88, 'generated', 'music_box', 0),
('track_in_003', 'Wind Chimes', 'Instrumental', 'instrumental', 'instrumental', 1800, 3, 36, 50, 0.85, 'generated', 'chimes', 0),
('track_in_004', 'Soft Bells', 'Instrumental', 'instrumental', 'instrumental', 1800, 3, 36, 45, 0.84, 'generated', 'bells', 1);

-- ============================================
-- CLASSICAL MUSIC
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, is_premium) VALUES
('track_cl_001', 'Brahms'' Lullaby', 'Johannes Brahms', 'classical_music', 'instrumental', 180, 0, 36, 60, 0.92, 'generated', 'lullaby', 0),
('track_cl_002', 'Twinkle Twinkle (Mozart)', 'Mozart Variation', 'classical_music', 'instrumental', 120, 0, 36, 70, 0.88, 'generated', 'lullaby', 0),
('track_cl_003', 'Clair de Lune', 'Claude Debussy', 'classical_music', 'instrumental', 300, 3, 36, 55, 0.90, 'generated', 'lullaby', 1),
('track_cl_004', 'Canon in D', 'Johann Pachelbel', 'classical_music', 'instrumental', 240, 3, 36, 60, 0.87, 'generated', 'lullaby', 1),
('track_cl_005', 'Gymnopédie No. 1', 'Erik Satie', 'classical_music', 'instrumental', 180, 0, 36, 50, 0.91, 'generated', 'lullaby', 0),
('track_cl_006', 'Air on G String', 'J.S. Bach', 'classical_music', 'instrumental', 300, 3, 36, 55, 0.89, 'generated', 'lullaby', 1),
('track_cl_007', 'Moonlight Sonata', 'Beethoven', 'classical_music', 'instrumental', 360, 6, 36, 52, 0.86, 'generated', 'lullaby', 1),
('track_cl_008', 'Für Elise', 'Beethoven', 'classical_music', 'instrumental', 180, 6, 36, 65, 0.84, 'generated', 'lullaby', 0),
('track_cl_009', 'Swan Lake Theme', 'Tchaikovsky', 'classical_music', 'instrumental', 240, 6, 36, 58, 0.85, 'generated', 'lullaby', 1),
('track_cl_010', 'Nocturne Op. 9 No. 2', 'Chopin', 'classical_music', 'instrumental', 270, 3, 36, 54, 0.88, 'generated', 'lullaby', 1);

-- ============================================
-- FAIRY TALES - ENGLISH
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, calming_score, audio_source_type, is_premium) VALUES
('track_ft_en_001', 'Goodnight Moon', 'Story Time', 'fairy_tales', 'english', 300, 0, 12, 0.85, 'text_to_speech', 0),
('track_ft_en_002', 'The Very Hungry Caterpillar', 'Story Time', 'fairy_tales', 'english', 420, 6, 24, 0.82, 'text_to_speech', 0),
('track_ft_en_003', 'Where the Wild Things Are', 'Story Time', 'fairy_tales', 'english', 480, 12, 36, 0.78, 'text_to_speech', 1),
('track_ft_en_004', 'Guess How Much I Love You', 'Story Time', 'fairy_tales', 'english', 360, 3, 24, 0.84, 'text_to_speech', 0),
('track_ft_en_005', 'The Runaway Bunny', 'Story Time', 'fairy_tales', 'english', 420, 6, 24, 0.80, 'text_to_speech', 1),
('track_ft_en_006', 'Pat the Bunny', 'Story Time', 'fairy_tales', 'english', 240, 0, 12, 0.83, 'text_to_speech', 0),
('track_ft_en_007', 'Brown Bear, Brown Bear', 'Story Time', 'fairy_tales', 'english', 180, 3, 18, 0.81, 'text_to_speech', 0),
('track_ft_en_008', 'Chicka Chicka Boom Boom', 'Story Time', 'fairy_tales', 'english', 240, 6, 24, 0.79, 'text_to_speech', 1),
('track_ft_en_009', 'The Snowy Day', 'Story Time', 'fairy_tales', 'english', 360, 12, 36, 0.77, 'text_to_speech', 1),
('track_ft_en_010', 'Corduroy', 'Story Time', 'fairy_tales', 'english', 480, 18, 36, 0.75, 'text_to_speech', 1);

-- ============================================
-- FAIRY TALES - SPANISH
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, calming_score, audio_source_type, is_premium) VALUES
('track_ft_es_001', 'Buenas Noches Luna', 'Cuentos', 'fairy_tales', 'spanish', 300, 0, 12, 0.85, 'text_to_speech', 1),
('track_ft_es_002', 'La Oruga Muy Hambrienta', 'Cuentos', 'fairy_tales', 'spanish', 420, 6, 24, 0.82, 'text_to_speech', 1),
('track_ft_es_003', 'Donde Viven los Monstruos', 'Cuentos', 'fairy_tales', 'spanish', 480, 12, 36, 0.78, 'text_to_speech', 1),
('track_ft_es_004', 'Adivina Cuánto Te Quiero', 'Cuentos', 'fairy_tales', 'spanish', 360, 3, 24, 0.84, 'text_to_speech', 1);

-- ============================================
-- FAIRY TALES - OTHER LANGUAGES
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, calming_score, audio_source_type, is_premium) VALUES
('track_ft_fr_001', 'Bonne Nuit Lune', 'Histoires', 'fairy_tales', 'french', 300, 0, 12, 0.85, 'text_to_speech', 1),
('track_ft_de_001', 'Gute Nacht Mond', 'Geschichten', 'fairy_tales', 'german', 300, 0, 12, 0.85, 'text_to_speech', 1),
('track_ft_it_001', 'Buonanotte Luna', 'Storie', 'fairy_tales', 'italian', 300, 0, 12, 0.85, 'text_to_speech', 1),
('track_ft_zh_001', '晚安月亮', '故事时间', 'fairy_tales', 'mandarin', 300, 0, 12, 0.85, 'text_to_speech', 1),
('track_ft_ja_001', 'おやすみなさいおつきさま', '物語', 'fairy_tales', 'japanese', 300, 0, 12, 0.85, 'text_to_speech', 1);

-- ============================================
-- CHILDREN'S SONGS
-- ============================================
INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, is_premium) VALUES
('track_cs_001', 'Twinkle Twinkle Little Star', 'Children''s Songs', 'children_songs', 'english', 120, 0, 36, 75, 0.85, 'generated', 'music_box', 0),
('track_cs_002', 'Rock-a-Bye Baby', 'Children''s Songs', 'children_songs', 'english', 150, 0, 24, 60, 0.88, 'generated', 'music_box', 0),
('track_cs_003', 'Hush Little Baby', 'Children''s Songs', 'children_songs', 'english', 180, 0, 24, 65, 0.86, 'generated', 'music_box', 0),
('track_cs_004', 'All the Pretty Horses', 'Children''s Songs', 'children_songs', 'english', 180, 0, 24, 55, 0.87, 'generated', 'music_box', 1),
('track_cs_005', 'You Are My Sunshine', 'Children''s Songs', 'children_songs', 'english', 150, 3, 36, 80, 0.82, 'generated', 'music_box', 0),
('track_cs_006', 'Mary Had a Little Lamb', 'Children''s Songs', 'children_songs', 'english', 90, 6, 36, 85, 0.78, 'generated', 'music_box', 0),
('track_cs_007', 'Itsy Bitsy Spider', 'Children''s Songs', 'children_songs', 'english', 60, 6, 36, 90, 0.75, 'generated', 'music_box', 0),
('track_cs_008', 'Row Row Row Your Boat', 'Children''s Songs', 'children_songs', 'english', 60, 6, 36, 88, 0.76, 'generated', 'music_box', 0),
('track_cs_009', 'Old MacDonald', 'Children''s Songs', 'children_songs', 'english', 120, 9, 36, 92, 0.72, 'generated', 'music_box', 1),
('track_cs_010', 'Wheels on the Bus', 'Children''s Songs', 'children_songs', 'english', 150, 9, 36, 95, 0.70, 'generated', 'music_box', 1),
('track_cs_011', 'ABC Song', 'Children''s Songs', 'children_songs', 'english', 90, 12, 36, 88, 0.74, 'generated', 'music_box', 0),
('track_cs_012', 'Baby Shark (Calm Version)', 'Children''s Songs', 'children_songs', 'english', 120, 12, 36, 70, 0.73, 'generated', 'music_box', 1);

-- ============================================
-- PLAYLISTS
-- ============================================
INSERT INTO playlists (id, name, description, category, target_age_months, is_system) VALUES
('playlist_001', 'Newborn Essentials', 'Womb-like sounds perfect for newborns 0-3 months', 'white_noise', 1, 1),
('playlist_002', 'Sleep Time Favorites', 'The most soothing sounds for peaceful sleep', NULL, NULL, 1),
('playlist_003', 'White Noise Collection', 'All white noise and mechanical sounds', 'white_noise', NULL, 1),
('playlist_004', 'Nature Sounds', 'Peaceful sounds from nature', 'nature_sounds', NULL, 1),
('playlist_005', 'Classical for Babies', 'Timeless classical pieces for development', 'classical_music', NULL, 1),
('playlist_006', 'Stories in English', 'Fairy tales in English', 'fairy_tales', NULL, 1),
('playlist_007', 'Lullabies & Songs', 'Gentle songs for little ones', 'children_songs', NULL, 1),
('playlist_008', 'Emergency Cry-Stop', 'Highest calming score tracks for emergencies', 'white_noise', NULL, 1);

-- ============================================
-- PLAYLIST TRACKS
-- ============================================
-- Newborn Essentials
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_001', 'track_wn_004', 1),
('playlist_001', 'track_wn_005', 2),
('playlist_001', 'track_wn_006', 3),
('playlist_001', 'track_wn_002', 4),
('playlist_001', 'track_ns_001', 5);

-- Sleep Time Favorites
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_002', 'track_wn_002', 1),
('playlist_002', 'track_wn_004', 2),
('playlist_002', 'track_ns_001', 3),
('playlist_002', 'track_ns_002', 4),
('playlist_002', 'track_cl_001', 5),
('playlist_002', 'track_cl_005', 6),
('playlist_002', 'track_in_001', 7);

-- White Noise Collection
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_003', 'track_wn_001', 1),
('playlist_003', 'track_wn_002', 2),
('playlist_003', 'track_wn_003', 3),
('playlist_003', 'track_wn_004', 4),
('playlist_003', 'track_wn_005', 5),
('playlist_003', 'track_wn_006', 6),
('playlist_003', 'track_wn_009', 7),
('playlist_003', 'track_wn_011', 8);

-- Nature Sounds
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_004', 'track_ns_001', 1),
('playlist_004', 'track_ns_002', 2),
('playlist_004', 'track_ns_003', 3),
('playlist_004', 'track_ns_004', 4),
('playlist_004', 'track_ns_005', 5),
('playlist_004', 'track_ns_006', 6);

-- Classical for Babies
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_005', 'track_cl_001', 1),
('playlist_005', 'track_cl_002', 2),
('playlist_005', 'track_cl_005', 3),
('playlist_005', 'track_cl_003', 4),
('playlist_005', 'track_cl_004', 5),
('playlist_005', 'track_cl_008', 6);

-- Stories in English
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_006', 'track_ft_en_001', 1),
('playlist_006', 'track_ft_en_004', 2),
('playlist_006', 'track_ft_en_006', 3),
('playlist_006', 'track_ft_en_007', 4),
('playlist_006', 'track_ft_en_002', 5);

-- Lullabies & Songs
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_007', 'track_cs_001', 1),
('playlist_007', 'track_cs_002', 2),
('playlist_007', 'track_cs_003', 3),
('playlist_007', 'track_cs_005', 4),
('playlist_007', 'track_in_001', 5),
('playlist_007', 'track_in_002', 6);

-- Emergency Cry-Stop
INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES
('playlist_008', 'track_wn_004', 1),
('playlist_008', 'track_wn_005', 2),
('playlist_008', 'track_wn_006', 3),
('playlist_008', 'track_wn_002', 4),
('playlist_008', 'track_ns_001', 5);
