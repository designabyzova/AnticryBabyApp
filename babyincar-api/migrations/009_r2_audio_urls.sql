-- Migration: Update tracks with R2 audio URLs
-- All audio files uploaded to Cloudflare R2 bucket: anticrybaby
-- Public URL: https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/{category}/{filename}
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/009_r2_audio_urls.sql

-- ============================================
-- LULLABIES (from r2-upload.log.success)
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_lullaby_suo_gan', 'Suo Gan', 'Traditional Welsh', 'instrumental', 'instrumental', 180, 0, 36, 60, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/suo_gan.mp3', 0),
  ('r2_lullaby_soft_baby', 'Soft Lullaby for Baby', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 55, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/soft_lullaby_baby.mp3', 0),
  ('r2_lullaby_sleep_sounds', 'Sleep Sounds Lullaby', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 50, 0.93, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/sleep_sounds.mp3', 0),
  ('r2_lullaby_gentle_melody', 'Gentle Melody', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 55, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/gentle_melody.mp3', 0),
  ('r2_lullaby_melody', 'Lullaby Melody', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 60, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/lullaby_melody.mp3', 0),
  ('r2_lullaby_twinkle', 'Twinkle Twinkle Little Star', 'Traditional', 'instrumental', 'instrumental', 120, 0, 36, 70, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/twinkle_twinkle.mp3', 0),
  ('r2_lullaby_bedtime', 'Bedtime Tune', 'AntiCry Baby', 'instrumental', 'instrumental', 180, 0, 36, 55, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/bedtime_tune.mp3', 0),
  ('r2_lullaby_rockabye', 'Rock-a-bye Baby', 'Traditional', 'instrumental', 'instrumental', 120, 0, 36, 65, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/lullabies/rock_a_bye_baby.mp3', 0);

-- ============================================
-- CLASSICAL MUSIC
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_classical_brahms', 'Brahms Lullaby', 'Johannes Brahms', 'classical_music', 'instrumental', 180, 0, 36, 60, 0.95, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/brahms_lullaby.mp3', 0),
  ('r2_classical_moonlight', 'Moonlight Sonata', 'Ludwig van Beethoven', 'classical_music', 'instrumental', 330, 0, 36, 55, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/moonlight_sonata.mp3', 0),
  ('r2_classical_chopin', 'Nocturne Op.9 No.2', 'Frederic Chopin', 'classical_music', 'instrumental', 270, 0, 36, 60, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/chopin_nocturne_op9_no2.mp3', 0),
  ('r2_classical_canon', 'Canon in D', 'Johann Pachelbel', 'classical_music', 'instrumental', 300, 0, 36, 65, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/canon_in_d.mp3', 0),
  ('r2_classical_clair', 'Clair de Lune', 'Claude Debussy', 'classical_music', 'instrumental', 300, 0, 36, 55, 0.94, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/clair_de_lune.mp3', 0),
  ('r2_classical_bach', 'Air on G String', 'Johann Sebastian Bach', 'classical_music', 'instrumental', 300, 0, 36, 50, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/bach_air_on_g_string.mp3', 0),
  ('r2_classical_gymnopedie', 'Gymnopedie No.1', 'Erik Satie', 'classical_music', 'instrumental', 210, 0, 36, 60, 0.93, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/gymnopedie_no1.mp3', 0),
  ('r2_classical_satie_three', 'Three Gymnopedies', 'Erik Satie', 'classical_music', 'instrumental', 600, 0, 36, 55, 0.94, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/satie_three_gymnopedies.mp3', 0),
  ('r2_classical_soft_strings', 'Soft Strings', 'Classical Collection', 'classical_music', 'instrumental', 240, 0, 36, 50, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/soft_strings.mp3', 0),
  ('r2_classical_romantic_violin', 'Romantic Violin', 'Classical Collection', 'classical_music', 'instrumental', 270, 0, 36, 55, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/romantic_violin.mp3', 0),
  ('r2_classical_piano_peaceful', 'Peaceful Piano', 'Classical Collection', 'classical_music', 'instrumental', 240, 0, 36, 50, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/piano_peaceful.mp3', 0),
  ('r2_classical_calm_piano', 'Calm Piano', 'Classical Collection', 'classical_music', 'instrumental', 210, 0, 36, 55, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/calm_piano.mp3', 0),
  ('r2_classical_dreamy_piano', 'Dreamy Piano', 'Classical Collection', 'classical_music', 'instrumental', 240, 0, 36, 50, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/dreamy_piano.mp3', 0),
  ('r2_classical_ambient_calm', 'Ambient Calm', 'Classical Collection', 'classical_music', 'instrumental', 300, 0, 36, 45, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/ambient_calm.mp3', 0),
  ('r2_classical_relaxing_melody', 'Relaxing Piano Melody', 'Classical Collection', 'classical_music', 'instrumental', 240, 0, 36, 55, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/classical/relaxing_piano_melody.mp3', 0);

-- ============================================
-- WHITE NOISE
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_whitenoise_pure', 'Pure White Noise', 'Sound Generator', 'white_noise', 'instrumental', 600, 0, 36, NULL, 0.95, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/whitenoise/white_noise.mp3', 0),
  ('r2_whitenoise_vacuum', 'Vacuum Cleaner', 'Household Sounds', 'white_noise', 'instrumental', 600, 0, 12, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/whitenoise/vacuum_cleaner.mp3', 0),
  ('r2_whitenoise_hairdryer', 'Hair Dryer', 'Household Sounds', 'white_noise', 'instrumental', 600, 0, 12, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/whitenoise/hair_dryer.mp3', 0),
  ('r2_whitenoise_heartbeat', 'Heartbeat', 'Nature Sounds', 'white_noise', 'instrumental', 600, 0, 6, 70, 0.96, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/whitenoise/heartbeat.mp3', 0);

-- ============================================
-- NATURE SOUNDS (sample - full list is extensive)
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_nature_ocean_waves', 'Ocean Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ocean_waves.mp3', 0),
  ('r2_nature_rain_gentle', 'Gentle Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_gentle.mp3', 0),
  ('r2_nature_rain_ambient', 'Rain Ambient', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_ambient.mp3', 0),
  ('r2_nature_rain_sounds', 'Rain Sounds', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_sounds.mp3', 0),
  ('r2_nature_wind', 'Wind', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/wind.mp3', 0),
  ('r2_nature_wind_trees', 'Wind in Trees', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/wind_trees.mp3', 0),
  ('r2_nature_ambient', 'Ambient Nature', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ambient_nature.mp3', 0),
  ('r2_nature_calm_ocean', 'Calm Ocean', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Calm_Ocean_cfcf4690.mp3', 0),
  ('r2_nature_beach_waves', 'Beach Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Beach_Waves_fe1b42d0.mp3', 0),
  ('r2_nature_summer_night', 'Summer Night', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Summer_Night_9b63ae37.mp3', 0),
  ('r2_nature_rain_glass', 'Rain on Glass', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Rain_on_Glass_9539eedf.mp3', 0),
  ('r2_nature_stream', 'Stream', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_stream.mp3', 0),
  ('r2_nature_sb_ocean', 'Ocean Waves (SB)', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_ocean_waves.mp3', 0),
  ('r2_nature_thunderstorm', 'Thunderstorm', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 6, 36, NULL, 0.75, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_thunderstorm.mp3', 0),
  ('r2_nature_sb_wind', 'Wind (SB)', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_wind.mp3', 0),
  ('r2_nature_sb_rain2', 'Rain 2 (SB)', 'Nature Sounds', 'nature_sounds', 'instrumental', 600, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_rain2.mp3', 0);

-- ============================================
-- AMBIENT MUSIC
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_ambient_dreams', 'Dreams', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 50, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_dreams.mp3', 0),
  ('r2_ambient_love', 'Love', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 55, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_love.mp3', 0),
  ('r2_ambient_memories', 'Memories', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 55, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_memories.mp3', 0),
  ('r2_ambient_relaxing', 'Relaxing', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 50, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_relaxing.mp3', 0),
  ('r2_ambient_tomorrow', 'Tomorrow', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 60, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_tomorrow.mp3', 0),
  ('r2_ambient_tenderness', 'Tenderness', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 55, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_tenderness.mp3', 0),
  ('r2_ambient_onceagain', 'Once Again', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 60, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_onceagain.mp3', 0),
  ('r2_ambient_sadday', 'Sad Day', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 50, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_sadday.mp3', 0),
  ('r2_ambient_betterdays', 'Better Days', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 60, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_betterdays.mp3', 0),
  ('r2_ambient_clearday', 'Clear Day', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 65, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_clearday.mp3', 0),
  ('r2_ambient_sweet', 'Sweet', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 55, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_sweet.mp3', 0),
  ('r2_ambient_slowmotion', 'Slow Motion', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 45, 0.93, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_slowmotion.mp3', 0),
  ('r2_ambient_allthat', 'All That', 'Bensound', 'instrumental', 'instrumental', 240, 0, 36, 55, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_allthat.mp3', 0),
  ('r2_ambient_jazzy', 'Jazzy Frenchy', 'Bensound', 'instrumental', 'instrumental', 240, 3, 36, 70, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/bensound_jazzyfrenchy.mp3', 0),
  ('r2_ambient_piano_logo', 'Ambient Piano Logo', 'Ambient Collection', 'instrumental', 'instrumental', 60, 0, 36, 50, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/ambient/ambient_piano_logo.mp3', 0);

-- ============================================
-- ACOUSTIC
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_acoustic_ukulele', 'Ukulele', 'Acoustic Collection', 'instrumental', 'instrumental', 180, 0, 36, 70, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/acoustic/vt_Ukulele_0ba779b7.mp3', 0),
  ('r2_acoustic_breeze', 'Acoustic Breeze', 'Acoustic Collection', 'instrumental', 'instrumental', 240, 0, 36, 65, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/acoustic/vt_Acoustic_Breeze_69815114.mp3', 0);

-- ============================================
-- CHILDREN'S SONGS
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_children_cute', 'Cute', 'Bensound', 'children_songs', 'instrumental', 150, 6, 36, 85, 0.78, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/bensound_cute.mp3', 0),
  ('r2_children_sunny', 'Sunny', 'Bensound', 'children_songs', 'instrumental', 150, 6, 36, 90, 0.75, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/bensound_sunny.mp3', 0),
  ('r2_children_littleidea', 'Little Idea', 'Bensound', 'children_songs', 'instrumental', 120, 6, 36, 80, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/bensound_littleidea.mp3', 0),
  ('r2_children_happyrock', 'Happy Rock', 'Bensound', 'children_songs', 'instrumental', 180, 12, 36, 110, 0.65, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/bensound_happyrock.mp3', 0),
  ('r2_children_creative', 'Creative Minds', 'Bensound', 'children_songs', 'instrumental', 180, 6, 36, 85, 0.77, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/vt_Creative_Minds_b7996078.mp3', 0),
  ('r2_children_small_guitar', 'Small Guitar', 'Acoustic Collection', 'children_songs', 'instrumental', 120, 6, 36, 80, 0.79, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/children/vt_Small_Guitar_d6b8b9ba.mp3', 0);

-- ============================================
-- RUSSIAN FAIRY TALES
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_ft_ru_baba_yaga', 'Baba Yaga', 'Afanasyev Collection', 'fairy_tales', 'ru', 600, 12, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_baba_yaga.mp3', 0),
  ('r2_ft_ru_tsarevna_lyagushka', 'Tsarevna Lyagushka (Frog Princess)', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_tsarevna_lyagushka.mp3', 0),
  ('r2_ft_ru_koschei', 'Koschei the Deathless', 'Afanasyev Collection', 'fairy_tales', 'ru', 1200, 12, 36, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_koschei.mp3', 0),
  ('r2_ft_ru_vasilisa', 'Vasilisa the Beautiful', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_vasilisa.mp3', 0),
  ('r2_ft_ru_sivka_burka', 'Sivka-Burka', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_sivka_burka.mp3', 0),
  ('r2_ft_ru_zhar_ptitsa', 'Zhar-Ptitsa (Firebird)', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_zhar_ptitsa.mp3', 0),
  ('r2_ft_ru_marya_morevna', 'Marya Morevna', 'Afanasyev Collection', 'fairy_tales', 'ru', 1200, 12, 36, NULL, 0.83, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_marya_morevna.mp3', 0),
  ('r2_ft_ru_havroshechka', 'Havroshechka', 'Afanasyev Collection', 'fairy_tales', 'ru', 600, 12, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_havroshechka.mp3', 0),
  ('r2_ft_ru_finist', 'Finist the Bright Falcon', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_finist.mp3', 0),
  ('r2_ft_ru_alyonushka', 'Sister Alyonushka', 'Afanasyev Collection', 'fairy_tales', 'ru', 600, 12, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_alyonushka.mp3', 0),
  ('r2_ft_ru_kot_petuh', 'Cat, Rooster and Fox', 'Afanasyev Collection', 'fairy_tales', 'ru', 480, 6, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_kot_petuh_lisa.mp3', 0),
  ('r2_ft_ru_petushok', 'Golden Rooster', 'Afanasyev Collection', 'fairy_tales', 'ru', 420, 6, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_petushok.mp3', 0),
  ('r2_ft_ru_kozlenochek', 'Kozlenochek', 'Afanasyev Collection', 'fairy_tales', 'ru', 480, 6, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_kozlenochek.mp3', 0),
  ('r2_ft_ru_letuchiy_korabl', 'Flying Ship', 'Afanasyev Collection', 'fairy_tales', 'ru', 900, 12, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_letuchiy_korabl.mp3', 0),
  ('r2_ft_ru_ivan_durak', 'Ivan the Fool', 'Afanasyev Collection', 'fairy_tales', 'ru', 720, 12, 36, NULL, 0.83, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/ru/ru_afanasyev_ivan_durak.mp3', 0);

-- ============================================
-- ENGLISH FAIRY TALES (Grimm Brothers)
-- ============================================
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  ('r2_ft_en_snow_white', 'Snow White', 'Grimm Brothers', 'fairy_tales', 'en', 1200, 18, 36, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_snow_white.mp3', 0),
  ('r2_ft_en_cinderella', 'Cinderella', 'Grimm Brothers', 'fairy_tales', 'en', 1200, 18, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_cinderella.mp3', 0),
  ('r2_ft_en_hansel_gretel', 'Hansel and Gretel', 'Grimm Brothers', 'fairy_tales', 'en', 1200, 18, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_hansel_gretel.mp3', 0),
  ('r2_ft_en_rapunzel', 'Rapunzel', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_rapunzel.mp3', 0),
  ('r2_ft_en_red_riding', 'Little Red Riding Hood', 'Grimm Brothers', 'fairy_tales', 'en', 600, 12, 36, NULL, 0.83, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_red_riding_hood.mp3', 0),
  ('r2_ft_en_briar_rose', 'Briar Rose (Sleeping Beauty)', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_briar_rose.mp3', 0),
  ('r2_ft_en_frog_prince', 'The Frog Prince', 'Grimm Brothers', 'fairy_tales', 'en', 600, 12, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_frog_prince.mp3', 0),
  ('r2_ft_en_rumpelstiltskin', 'Rumpelstiltskin', 'Grimm Brothers', 'fairy_tales', 'en', 720, 18, 36, NULL, 0.81, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_rumpelstiltskin.mp3', 0),
  ('r2_ft_en_tom_thumb', 'Tom Thumb', 'Grimm Brothers', 'fairy_tales', 'en', 600, 12, 36, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_tom_thumb.mp3', 0),
  ('r2_ft_en_bremen', 'Town Musicians of Bremen', 'Grimm Brothers', 'fairy_tales', 'en', 720, 12, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_travelling_musicians.mp3', 0),
  ('r2_ft_en_golden_bird', 'The Golden Bird', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.83, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_golden_bird.mp3', 0),
  ('r2_ft_en_goose_girl', 'The Goose Girl', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_goose_girl.mp3', 0),
  ('r2_ft_en_mother_holle', 'Mother Holle', 'Grimm Brothers', 'fairy_tales', 'en', 600, 12, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_mother_holle.mp3', 0),
  ('r2_ft_en_valiant_tailor', 'The Valiant Little Tailor', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_valiant_tailor.mp3', 0),
  ('r2_ft_en_fisherman', 'The Fisherman and His Wife', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_fisherman_wife.mp3', 0),
  ('r2_ft_en_12_princesses', 'The Twelve Dancing Princesses', 'Grimm Brothers', 'fairy_tales', 'en', 900, 18, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_twelve_princesses.mp3', 0),
  ('r2_ft_en_hans_luck', 'Hans in Luck', 'Grimm Brothers', 'fairy_tales', 'en', 720, 12, 36, NULL, 0.83, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/fairytales/en/en_grimm_hans_luck.mp3', 0);

-- ============================================
-- CREATE/UPDATE PLAYLISTS FOR R2 CONTENT
-- ============================================

-- Update existing playlists or create new ones for R2 content
INSERT OR REPLACE INTO playlists (id, name, description, category, target_age_months, is_system)
VALUES
  ('pl_r2_classical', 'Classical Piano', 'Beautiful classical piano pieces for peaceful moments', 'classical_music', 0, 1),
  ('pl_r2_nature_rain', 'Rain & Water', 'Soothing rain and water sounds', 'nature_sounds', 0, 1),
  ('pl_r2_lullabies', 'Lullabies Collection', 'Gentle lullabies for bedtime', 'instrumental', 0, 1),
  ('pl_r2_ambient', 'Ambient Relaxation', 'Calm ambient music for relaxation', 'instrumental', 0, 1),
  ('pl_r2_fairytales_ru', 'Russian Fairy Tales', 'Classic Russian fairy tales by Afanasyev', 'fairy_tales', 18, 1),
  ('pl_r2_fairytales_en', 'Grimm Fairy Tales', 'Classic fairy tales by Brothers Grimm', 'fairy_tales', 18, 1);

-- Playlist track associations
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_classical', 'r2_classical_brahms', 1),
  ('pl_r2_classical', 'r2_classical_moonlight', 2),
  ('pl_r2_classical', 'r2_classical_chopin', 3),
  ('pl_r2_classical', 'r2_classical_clair', 4),
  ('pl_r2_classical', 'r2_classical_gymnopedie', 5),
  ('pl_r2_classical', 'r2_classical_bach', 6);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_nature_rain', 'r2_nature_rain_gentle', 1),
  ('pl_r2_nature_rain', 'r2_nature_rain_glass', 2),
  ('pl_r2_nature_rain', 'r2_nature_ocean_waves', 3),
  ('pl_r2_nature_rain', 'r2_nature_stream', 4),
  ('pl_r2_nature_rain', 'r2_nature_beach_waves', 5);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_lullabies', 'r2_lullaby_suo_gan', 1),
  ('pl_r2_lullabies', 'r2_lullaby_twinkle', 2),
  ('pl_r2_lullabies', 'r2_lullaby_rockabye', 3),
  ('pl_r2_lullabies', 'r2_lullaby_bedtime', 4),
  ('pl_r2_lullabies', 'r2_lullaby_gentle_melody', 5);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_ambient', 'r2_ambient_dreams', 1),
  ('pl_r2_ambient', 'r2_ambient_relaxing', 2),
  ('pl_r2_ambient', 'r2_ambient_slowmotion', 3),
  ('pl_r2_ambient', 'r2_ambient_tenderness', 4),
  ('pl_r2_ambient', 'r2_ambient_love', 5);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_fairytales_ru', 'r2_ft_ru_tsarevna_lyagushka', 1),
  ('pl_r2_fairytales_ru', 'r2_ft_ru_vasilisa', 2),
  ('pl_r2_fairytales_ru', 'r2_ft_ru_sivka_burka', 3),
  ('pl_r2_fairytales_ru', 'r2_ft_ru_zhar_ptitsa', 4),
  ('pl_r2_fairytales_ru', 'r2_ft_ru_havroshechka', 5);

INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_r2_fairytales_en', 'r2_ft_en_snow_white', 1),
  ('pl_r2_fairytales_en', 'r2_ft_en_cinderella', 2),
  ('pl_r2_fairytales_en', 'r2_ft_en_rapunzel', 3),
  ('pl_r2_fairytales_en', 'r2_ft_en_briar_rose', 4),
  ('pl_r2_fairytales_en', 'r2_ft_en_red_riding', 5);
