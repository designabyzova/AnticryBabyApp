-- Audio Library Seed Data
-- Contains curated royalty-free and CC0 audio content from various sources
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/004_audio_library_seed.sql

-- ============================================
-- WHITE NOISE CATEGORY (Generated/Synthesized)
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('gen_white_noise_pure', 'Pure White Noise', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 36, NULL, 0.95, 'generated', 'white_noise', NULL, 0, 'generated', 'Proprietary', '["white noise","sleep","calming","continuous"]'),
  ('gen_pink_noise', 'Gentle Pink Noise', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 36, NULL, 0.93, 'generated', 'pink_noise', NULL, 0, 'generated', 'Proprietary', '["pink noise","sleep","gentle","baby"]'),
  ('gen_brown_noise', 'Deep Brown Noise', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 24, NULL, 0.91, 'generated', 'brown_noise', NULL, 0, 'generated', 'Proprietary', '["brown noise","deep","womb sounds","newborn"]'),
  ('gen_womb_sounds', 'Womb Sounds', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 6, NULL, 0.97, 'generated', 'womb_sounds', NULL, 0, 'generated', 'Proprietary', '["womb","heartbeat","prenatal","newborn"]'),
  ('gen_heartbeat', 'Heartbeat Rhythm', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 6, 70, 0.96, 'generated', 'heartbeat', NULL, 0, 'generated', 'Proprietary', '["heartbeat","rhythm","calming","newborn"]'),
  ('gen_shushing', 'Gentle Shushing', 'AntiCry Baby', 'white_noise', 'instrumental', 300, 0, 12, NULL, 0.94, 'generated', 'shushing', NULL, 0, 'generated', 'Proprietary', '["shush","soothing","calming","technique"]'),
  ('gen_vacuum', 'Vacuum Cleaner', 'Household Sounds', 'white_noise', 'instrumental', 300, 0, 12, NULL, 0.82, 'generated', 'vacuum', NULL, 0, 'generated', 'Proprietary', '["vacuum","household","white noise","constant"]'),
  ('gen_fan', 'Electric Fan', 'Household Sounds', 'white_noise', 'instrumental', 300, 0, 36, NULL, 0.85, 'generated', 'fan', NULL, 0, 'generated', 'Proprietary', '["fan","air","continuous","sleep"]'),
  ('gen_hairdryer', 'Hair Dryer', 'Household Sounds', 'white_noise', 'instrumental', 300, 0, 12, NULL, 0.80, 'generated', 'hair_dryer', NULL, 0, 'generated', 'Proprietary', '["hair dryer","household","white noise"]'),
  ('gen_washer', 'Washing Machine', 'Household Sounds', 'white_noise', 'instrumental', 300, 0, 24, NULL, 0.78, 'generated', 'washer', NULL, 0, 'generated', 'Proprietary', '["washing machine","household","rhythmic"]'),
  ('gen_car_engine', 'Car Engine Ride', 'Vehicle Sounds', 'white_noise', 'instrumental', 300, 0, 36, NULL, 0.83, 'generated', 'car_engine', NULL, 0, 'generated', 'Proprietary', '["car","engine","driving","vibration"]'),
  ('gen_airplane', 'Airplane Cabin', 'Vehicle Sounds', 'white_noise', 'instrumental', 300, 0, 36, NULL, 0.79, 'generated', 'airplane', NULL, 0, 'generated', 'Proprietary', '["airplane","cabin","travel","white noise"]');

-- ============================================
-- NATURE SOUNDS CATEGORY (Generated/Synthesized)
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('gen_rain_gentle', 'Gentle Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.90, 'generated', 'rain', NULL, 0, 'generated', 'Proprietary', '["rain","nature","calming","sleep"]'),
  ('gen_rain_heavy', 'Heavy Rainfall', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.85, 'generated', 'rain_heavy', NULL, 0, 'generated', 'Proprietary', '["rain","heavy","storm","nature"]'),
  ('gen_ocean_waves', 'Ocean Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.88, 'generated', 'ocean', NULL, 0, 'generated', 'Proprietary', '["ocean","waves","beach","peaceful"]'),
  ('gen_river_stream', 'River Stream', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.87, 'generated', 'stream', NULL, 0, 'generated', 'Proprietary', '["river","stream","water","flowing"]'),
  ('gen_forest_birds', 'Forest Birds', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 3, 36, NULL, 0.82, 'generated', 'birds', NULL, 0, 'generated', 'Proprietary', '["forest","birds","chirping","morning"]'),
  ('gen_wind_gentle', 'Gentle Wind', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.86, 'generated', 'wind', NULL, 0, 'generated', 'Proprietary', '["wind","breeze","gentle","nature"]'),
  ('gen_thunder_distant', 'Distant Thunder', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 6, 36, NULL, 0.75, 'generated', 'thunder', NULL, 0, 'generated', 'Proprietary', '["thunder","storm","distant","rain"]'),
  ('gen_crickets', 'Night Crickets', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.84, 'generated', 'crickets', NULL, 0, 'generated', 'Proprietary', '["crickets","night","summer","peaceful"]'),
  ('gen_campfire', 'Crackling Campfire', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.83, 'generated', 'campfire', NULL, 0, 'generated', 'Proprietary', '["campfire","crackling","warm","cozy"]'),
  ('gen_waterfall', 'Peaceful Waterfall', 'Nature Sounds', 'nature_sounds', 'instrumental', 300, 0, 36, NULL, 0.86, 'generated', 'waterfall', NULL, 0, 'generated', 'Proprietary', '["waterfall","water","cascading","nature"]');

-- ============================================
-- INSTRUMENTAL/LULLABY CATEGORY (Generated)
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('gen_music_box', 'Music Box Lullaby', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 60, 0.92, 'generated', 'music_box', NULL, 0, 'generated', 'Proprietary', '["music box","lullaby","melody","gentle"]'),
  ('gen_wind_chimes', 'Wind Chimes', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, NULL, 0.88, 'generated', 'chimes', NULL, 0, 'generated', 'Proprietary', '["wind chimes","peaceful","gentle","ambient"]'),
  ('gen_bells', 'Soft Bells', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 50, 0.85, 'generated', 'bells', NULL, 0, 'generated', 'Proprietary', '["bells","soft","calming","sleep"]'),
  ('gen_lullaby_melody', 'Sweet Lullaby', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 65, 0.90, 'generated', 'lullaby', NULL, 0, 'generated', 'Proprietary', '["lullaby","melody","sweet","bedtime"]'),
  ('gen_piano_soft', 'Soft Piano Notes', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 55, 0.89, 'generated', 'piano_soft', NULL, 0, 'generated', 'Proprietary', '["piano","soft","gentle","classical"]'),
  ('gen_harp_gentle', 'Gentle Harp', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 50, 0.91, 'generated', 'harp', NULL, 0, 'generated', 'Proprietary', '["harp","gentle","peaceful","ethereal"]');

-- ============================================
-- CLASSICAL MUSIC CATEGORY (Public Domain)
-- These reference public domain classical recordings
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('pd_brahms_lullaby', 'Brahms Lullaby (Wiegenlied)', 'Johannes Brahms', 'classical_music', 'instrumental', 180, 0, 36, 60, 0.95, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["brahms","lullaby","classical","bedtime"]'),
  ('pd_mozart_lullaby', 'Mozart Lullaby K.350', 'Wolfgang Amadeus Mozart', 'classical_music', 'instrumental', 210, 0, 36, 65, 0.93, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["mozart","lullaby","classical","gentle"]'),
  ('pd_bach_air', 'Air on G String', 'Johann Sebastian Bach', 'classical_music', 'instrumental', 300, 0, 36, 50, 0.92, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["bach","air","classical","peaceful"]'),
  ('pd_debussy_clair', 'Clair de Lune', 'Claude Debussy', 'classical_music', 'instrumental', 300, 0, 36, 55, 0.94, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["debussy","piano","classical","dreamy"]'),
  ('pd_chopin_nocturne', 'Nocturne Op.9 No.2', 'Frederic Chopin', 'classical_music', 'instrumental', 270, 0, 36, 60, 0.91, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["chopin","nocturne","piano","romantic"]'),
  ('pd_pachelbel_canon', 'Canon in D', 'Johann Pachelbel', 'classical_music', 'instrumental', 300, 0, 36, 65, 0.90, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["pachelbel","canon","classical","peaceful"]'),
  ('pd_beethoven_moonlight', 'Moonlight Sonata', 'Ludwig van Beethoven', 'classical_music', 'instrumental', 330, 0, 36, 55, 0.89, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["beethoven","moonlight","piano","serene"]'),
  ('pd_satie_gymnopedie', 'Gymnopedie No.1', 'Erik Satie', 'classical_music', 'instrumental', 210, 0, 36, 60, 0.93, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["satie","piano","minimalist","calm"]'),
  ('pd_grieg_morning', 'Morning Mood (Peer Gynt)', 'Edvard Grieg', 'classical_music', 'instrumental', 240, 0, 36, 70, 0.85, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["grieg","morning","orchestral","peaceful"]'),
  ('pd_schubert_serenade', 'Serenade', 'Franz Schubert', 'classical_music', 'instrumental', 270, 0, 36, 55, 0.91, 'recorded', NULL, NULL, 0, 'musopen', 'Public Domain', '["schubert","serenade","romantic","gentle"]');

-- ============================================
-- CHILDREN'S SONGS CATEGORY (Traditional/Public Domain)
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_twinkle_en', 'Twinkle Twinkle Little Star', 'Traditional', 'children_songs', 'en', 120, 0, 36, 80, 0.85, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","traditional","star","bedtime"]'),
  ('trad_rockabye_en', 'Rock-a-bye Baby', 'Traditional', 'children_songs', 'en', 90, 0, 24, 70, 0.88, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","traditional","rocking","sleep"]'),
  ('trad_hush_en', 'Hush Little Baby', 'Traditional', 'children_songs', 'en', 120, 0, 24, 75, 0.87, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","traditional","soothing"]'),
  ('trad_mary_lamb_en', 'Mary Had a Little Lamb', 'Traditional', 'children_songs', 'en', 90, 6, 36, 90, 0.75, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","traditional","fun"]'),
  ('trad_itsy_spider_en', 'Itsy Bitsy Spider', 'Traditional', 'children_songs', 'en', 75, 6, 36, 85, 0.72, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","traditional","playful"]'),
  ('trad_row_boat_en', 'Row Row Row Your Boat', 'Traditional', 'children_songs', 'en', 60, 6, 36, 85, 0.78, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","traditional","boat"]'),
  ('trad_baa_sheep_en', 'Baa Baa Black Sheep', 'Traditional', 'children_songs', 'en', 60, 6, 36, 85, 0.76, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","traditional","animals"]'),
  ('trad_star_light_en', 'Star Light Star Bright', 'Traditional', 'children_songs', 'en', 45, 0, 36, 70, 0.82, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["wish","star","bedtime","traditional"]');

-- ============================================
-- CHILDREN'S SONGS - SPANISH
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_arrorró_es', 'Arrorró Mi Niño', 'Traditional', 'children_songs', 'es', 120, 0, 24, 65, 0.92, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","spanish","traditional","sleep"]'),
  ('trad_duérmete_es', 'Duérmete Mi Niño', 'Traditional', 'children_songs', 'es', 100, 0, 24, 60, 0.90, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","spanish","bedtime"]'),
  ('trad_estrellita_es', 'Estrellita Dónde Estás', 'Traditional', 'children_songs', 'es', 120, 0, 36, 80, 0.85, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","spanish","star"]'),
  ('trad_luna_es', 'La Luna', 'Traditional', 'children_songs', 'es', 90, 0, 36, 70, 0.88, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","spanish","moon","night"]');

-- ============================================
-- CHILDREN'S SONGS - FRENCH
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_dodo_fr', 'Dodo l''Enfant Do', 'Traditional', 'children_songs', 'fr', 90, 0, 24, 65, 0.91, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","french","traditional","sleep"]'),
  ('trad_frere_fr', 'Frère Jacques', 'Traditional', 'children_songs', 'fr', 60, 6, 36, 90, 0.75, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","french","traditional"]'),
  ('trad_clair_lune_fr', 'Au Clair de la Lune', 'Traditional', 'children_songs', 'fr', 90, 0, 36, 75, 0.85, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","french","moon"]'),
  ('trad_berceau_fr', 'Berceuse de Brahms', 'Brahms/French', 'children_songs', 'fr', 120, 0, 24, 60, 0.93, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","french","brahms","classical"]');

-- ============================================
-- CHILDREN'S SONGS - GERMAN
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_schlaf_de', 'Schlaf Kindlein Schlaf', 'Traditional', 'children_songs', 'de', 120, 0, 24, 60, 0.92, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","german","traditional","sleep"]'),
  ('trad_weisst_de', 'Weißt Du Wieviel Sternlein', 'Traditional', 'children_songs', 'de', 150, 0, 36, 70, 0.88, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","german","stars"]'),
  ('trad_guten_de', 'Guten Abend Gute Nacht', 'Brahms', 'children_songs', 'de', 120, 0, 24, 65, 0.94, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","german","brahms","bedtime"]'),
  ('trad_sandmann_de', 'Sandmann', 'Traditional', 'children_songs', 'de', 90, 0, 36, 70, 0.86, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","german","sandman","sleep"]');

-- ============================================
-- CHILDREN'S SONGS - ITALIAN
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_ninna_it', 'Ninna Nanna', 'Traditional', 'children_songs', 'it', 120, 0, 24, 60, 0.91, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","italian","traditional","sleep"]'),
  ('trad_stella_it', 'Stella Stellina', 'Traditional', 'children_songs', 'it', 90, 0, 36, 70, 0.87, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["nursery rhyme","italian","star"]'),
  ('trad_dormi_it', 'Dormi Dormi', 'Traditional', 'children_songs', 'it', 100, 0, 24, 55, 0.90, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Public Domain', '["lullaby","italian","sleep","gentle"]');

-- ============================================
-- CHILDREN'S SONGS - JAPANESE
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_edo_lullaby_ja', 'Edo Lullaby', 'Traditional', 'children_songs', 'ja', 120, 0, 24, 60, 0.90, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","japanese","traditional","edo"]'),
  ('trad_takeda_ja', 'Takeda Lullaby', 'Traditional', 'children_songs', 'ja', 150, 0, 24, 55, 0.92, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","japanese","folk"]'),
  ('trad_sakura_ja', 'Sakura Sakura', 'Traditional', 'children_songs', 'ja', 90, 3, 36, 70, 0.85, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["folk","japanese","cherry blossom"]');

-- ============================================
-- CHILDREN'S SONGS - MANDARIN CHINESE
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_xiaobao_zh', 'Xiaobao Bao Shuijiao', 'Traditional', 'children_songs', 'zh', 120, 0, 24, 60, 0.91, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","mandarin","traditional","sleep"]'),
  ('trad_yaoalan_zh', 'Yao Lan Qu', 'Traditional', 'children_songs', 'zh', 100, 0, 24, 55, 0.90, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","mandarin","cradle"]'),
  ('trad_xingxing_zh', 'Xiao Xing Xing', 'Traditional', 'children_songs', 'zh', 90, 0, 36, 75, 0.86, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["nursery rhyme","mandarin","star"]');

-- ============================================
-- CHILDREN'S SONGS - RUSSIAN
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('trad_bayushki_ru', 'Bayushki Bayu', 'Traditional', 'children_songs', 'ru', 120, 0, 24, 60, 0.92, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","russian","traditional","sleep"]'),
  ('trad_spi_ru', 'Spi Mladenets', 'Traditional', 'children_songs', 'ru', 100, 0, 24, 55, 0.91, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","russian","sleep"]'),
  ('trad_kolybelny_ru', 'Kolybelnya', 'Traditional', 'children_songs', 'ru', 150, 0, 24, 50, 0.93, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Public Domain', '["lullaby","russian","cradle song"]');

-- ============================================
-- FAIRY TALES / STORIES CATEGORY
-- Short calming stories for older babies
-- ============================================

INSERT OR IGNORE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium, source, license, tags)
VALUES
  ('story_moon_en', 'Goodnight Moon', 'Classic Stories', 'fairy_tales', 'en', 300, 12, 36, NULL, 0.88, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Custom', '["story","bedtime","moon","classic"]'),
  ('story_bunny_en', 'The Sleepy Bunny', 'Bedtime Stories', 'fairy_tales', 'en', 420, 12, 36, NULL, 0.90, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Custom', '["story","bunny","sleep","gentle"]'),
  ('story_stars_en', 'Counting Stars', 'Bedtime Stories', 'fairy_tales', 'en', 360, 12, 36, NULL, 0.87, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Custom', '["story","stars","counting","night"]'),
  ('story_cloud_en', 'The Little Cloud', 'Bedtime Stories', 'fairy_tales', 'en', 300, 12, 36, NULL, 0.85, 'text_to_speech', NULL, NULL, 0, 'bundled', 'Custom', '["story","cloud","sky","dreamy"]'),
  ('story_bear_en', 'Sleepy Bear', 'Bedtime Stories', 'fairy_tales', 'en', 360, 12, 36, NULL, 0.89, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Custom', '["story","bear","hibernation","sleep"]'),
  ('story_ocean_en', 'Under the Ocean', 'Bedtime Stories', 'fairy_tales', 'en', 420, 18, 36, NULL, 0.84, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Custom', '["story","ocean","fish","adventure"]'),
  ('story_forest_en', 'Forest Friends', 'Bedtime Stories', 'fairy_tales', 'en', 480, 18, 36, NULL, 0.82, 'text_to_speech', NULL, NULL, 1, 'bundled', 'Custom', '["story","forest","animals","friendship"]');

-- ============================================
-- PLAYLISTS - Curated Collections
-- ============================================

INSERT OR IGNORE INTO playlists (id, name, description, category, target_age_months, is_system)
VALUES
  ('pl_newborn_essentials', 'Newborn Essentials', 'Perfect sounds for the first 3 months - womb sounds, heartbeat, and gentle noise', 'white_noise', 1, 1),
  ('pl_sleep_sounds', 'Sleep Time Sounds', 'Calming sounds to help your baby drift off to sleep', 'white_noise', 6, 1),
  ('pl_calming_nature', 'Calming Nature', 'Gentle nature sounds for peaceful relaxation', 'nature_sounds', 6, 1),
  ('pl_classical_baby', 'Classical for Baby', 'Beautiful classical pieces perfect for developing minds', 'classical_music', 3, 1),
  ('pl_lullaby_collection', 'Lullaby Collection', 'Traditional lullabies from around the world', 'children_songs', 0, 1),
  ('pl_bedtime_stories', 'Bedtime Stories', 'Gentle stories to end the day', 'fairy_tales', 18, 1),
  ('pl_emergency_calm', 'Emergency Calm', 'Quick-acting sounds to soothe a crying baby', 'white_noise', 0, 1),
  ('pl_car_ride', 'Car Ride Companion', 'Perfect sounds for peaceful car journeys', 'white_noise', 0, 1);

-- ============================================
-- PLAYLIST TRACKS - Link tracks to playlists
-- ============================================

-- Newborn Essentials
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_newborn_essentials', 'gen_womb_sounds', 1),
  ('pl_newborn_essentials', 'gen_heartbeat', 2),
  ('pl_newborn_essentials', 'gen_shushing', 3),
  ('pl_newborn_essentials', 'gen_white_noise_pure', 4),
  ('pl_newborn_essentials', 'gen_pink_noise', 5);

-- Sleep Time Sounds
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_sleep_sounds', 'gen_white_noise_pure', 1),
  ('pl_sleep_sounds', 'gen_rain_gentle', 2),
  ('pl_sleep_sounds', 'gen_ocean_waves', 3),
  ('pl_sleep_sounds', 'gen_fan', 4),
  ('pl_sleep_sounds', 'gen_pink_noise', 5);

-- Calming Nature
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_calming_nature', 'gen_rain_gentle', 1),
  ('pl_calming_nature', 'gen_ocean_waves', 2),
  ('pl_calming_nature', 'gen_river_stream', 3),
  ('pl_calming_nature', 'gen_forest_birds', 4),
  ('pl_calming_nature', 'gen_wind_gentle', 5),
  ('pl_calming_nature', 'gen_crickets', 6);

-- Classical for Baby
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_classical_baby', 'pd_brahms_lullaby', 1),
  ('pl_classical_baby', 'pd_mozart_lullaby', 2),
  ('pl_classical_baby', 'pd_debussy_clair', 3),
  ('pl_classical_baby', 'pd_bach_air', 4),
  ('pl_classical_baby', 'pd_satie_gymnopedie', 5);

-- Lullaby Collection
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_lullaby_collection', 'trad_twinkle_en', 1),
  ('pl_lullaby_collection', 'trad_rockabye_en', 2),
  ('pl_lullaby_collection', 'trad_hush_en', 3),
  ('pl_lullaby_collection', 'gen_music_box', 4),
  ('pl_lullaby_collection', 'gen_lullaby_melody', 5);

-- Bedtime Stories
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_bedtime_stories', 'story_moon_en', 1),
  ('pl_bedtime_stories', 'story_bunny_en', 2),
  ('pl_bedtime_stories', 'story_stars_en', 3),
  ('pl_bedtime_stories', 'story_cloud_en', 4);

-- Emergency Calm
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_emergency_calm', 'gen_womb_sounds', 1),
  ('pl_emergency_calm', 'gen_shushing', 2),
  ('pl_emergency_calm', 'gen_white_noise_pure', 3),
  ('pl_emergency_calm', 'gen_vacuum', 4),
  ('pl_emergency_calm', 'gen_hairdryer', 5);

-- Car Ride Companion
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_car_ride', 'gen_car_engine', 1),
  ('pl_car_ride', 'gen_white_noise_pure', 2),
  ('pl_car_ride', 'gen_rain_gentle', 3),
  ('pl_car_ride', 'pd_brahms_lullaby', 4),
  ('pl_car_ride', 'gen_music_box', 5);
