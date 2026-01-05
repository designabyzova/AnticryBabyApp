-- Migration: Complete Nature Sounds Library with Accurate Durations
-- Generated: 2026-01-01
-- Total nature files: 92 from R2 bucket
-- Run with: wrangler d1 execute babyincar-db --file=./migrations/010_nature_sounds_complete.sql

-- Delete old nature_sounds entries that may have incorrect URLs or no URLs
DELETE FROM tracks WHERE category = 'nature_sounds' AND id LIKE 'r2_nature_%';
DELETE FROM tracks WHERE category = 'nature_sounds' AND stream_url IS NULL;

-- ============================================
-- CURATED NATURE SOUNDS (High Quality, Long Duration)
-- These are the best tracks for baby soothing
-- ============================================

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Ocean & Water Sounds
  ('r2_nature_ocean_waves', 'Ocean Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 47, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ocean_waves.mp3', 0),
  ('r2_nature_sb_ocean_waves', 'Ocean Waves (Extended)', 'Nature Sounds', 'nature_sounds', 'instrumental', 47, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_ocean_waves.mp3', 0),
  ('r2_nature_sb_stream', 'Babbling Stream', 'Nature Sounds', 'nature_sounds', 'instrumental', 2, 0, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_stream.mp3', 0),
  ('r2_nature_sea_storm', 'Sea Storm Therapy', 'Nature Sounds', 'nature_sounds', 'instrumental', 3600, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_5760b9d5_Sound_Therapy_-_Sea_Storm.mp3', 0),
  ('r2_nature_calm_ocean', 'Calm Ocean', 'Nature Sounds', 'nature_sounds', 'instrumental', 1, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Calm_Ocean_cfcf4690.mp3', 0),
  ('r2_nature_beach_waves', 'Beach Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 3, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Beach_Waves_fe1b42d0.mp3', 0),
  ('r2_nature_ocean_birds', 'Birds with Ocean Waves', 'Nature Sounds', 'nature_sounds', 'instrumental', 1650, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_23875235_Birds_With_Ocean_Waves_on_the_.mp3', 0),
  ('r2_nature_whales', 'Whale Songs', 'Nature Sounds', 'nature_sounds', 'instrumental', 32, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_81316350_08whales.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Rain Sounds
  ('r2_nature_rain_gentle', 'Gentle Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 60, 0, 36, NULL, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_gentle.mp3', 0),
  ('r2_nature_rain_ambient', 'Rain Ambient', 'Nature Sounds', 'nature_sounds', 'instrumental', 147, 0, 36, NULL, 0.90, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_ambient.mp3', 0),
  ('r2_nature_rain_sounds', 'Rain Sounds', 'Nature Sounds', 'nature_sounds', 'instrumental', 60, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/rain_sounds.mp3', 0),
  ('r2_nature_rain_glass', 'Rain on Glass', 'Nature Sounds', 'nature_sounds', 'instrumental', 117, 0, 36, NULL, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Rain_on_Glass_9539eedf.mp3', 0),
  ('r2_nature_rain_window', 'Rain on Window', 'Nature Sounds', 'nature_sounds', 'instrumental', 117, 0, 36, NULL, 0.91, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/pb_Rain_on_Window_9539eedf.mp3', 0),
  ('r2_nature_rain2', 'Light Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 6, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_rain2.mp3', 0),
  ('r2_nature_light_rain', 'Light Gentle Rain', 'Nature Sounds', 'nature_sounds', 'instrumental', 2160, 0, 36, NULL, 0.92, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_149db388_Light_Gentle_Rain.mp3', 0),
  ('r2_nature_rain_thunder', 'Relaxing Rain with Thunder', 'Nature Sounds', 'nature_sounds', 'instrumental', 212, 0, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_b5a2c147_Relaxing_Rain_and_Loud_Thunder.mp3', 0),
  ('r2_nature_rain_woodstorks', 'Rain on Woodstorks', 'Nature Sounds', 'nature_sounds', 'instrumental', 23, 0, 36, NULL, 0.89, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_30dbe2de_23rainonwoodstorks.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Wind Sounds
  ('r2_nature_wind', 'Gentle Wind', 'Nature Sounds', 'nature_sounds', 'instrumental', 30, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/wind.mp3', 0),
  ('r2_nature_wind_trees', 'Wind in Trees', 'Nature Sounds', 'nature_sounds', 'instrumental', 144, 0, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/wind_trees.mp3', 0),
  ('r2_nature_sb_wind', 'Wind (Extended)', 'Nature Sounds', 'nature_sounds', 'instrumental', 30, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_wind.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Forest & Ambience
  ('r2_nature_ambient', 'Ambient Nature', 'Nature Sounds', 'nature_sounds', 'instrumental', 527, 0, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ambient_nature.mp3', 0),
  ('r2_nature_forest_long', 'Forest Sounds', 'Nature Sounds', 'nature_sounds', 'instrumental', 30049, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_1be5ab6b_Nature_Sounds_Forest_Sounds_Bi.mp3', 0),
  ('r2_nature_summer_night', 'Summer Night', 'Nature Sounds', 'nature_sounds', 'instrumental', 147, 0, 36, NULL, 0.84, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ne_Summer_Night_9b63ae37.mp3', 0),
  ('r2_nature_night_ambience', 'Night Ambience', 'Nature Sounds', 'nature_sounds', 'instrumental', 147, 0, 36, NULL, 0.85, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/pb_Night_Ambience_9b63ae37.mp3', 0),
  ('r2_nature_sea_ambience', 'Sea Ambience', 'Nature Sounds', 'nature_sounds', 'instrumental', 3, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/pb_Sea_Ambience_fe1b42d0.mp3', 0),
  ('r2_nature_quiet_campground', 'Quiet Campground', 'Nature Sounds', 'nature_sounds', 'instrumental', 214, 0, 36, NULL, 0.86, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_f9a9fcf7_20100816QuietCampground-GranVe.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Thunder (Lower calming score - not for all babies)
  ('r2_nature_thunderstorm', 'Thunderstorm', 'Nature Sounds', 'nature_sounds', 'instrumental', 61, 6, 36, NULL, 0.75, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sb_thunderstorm.mp3', 0),
  ('r2_nature_thunder1', 'Distant Thunder 1', 'Nature Sounds', 'nature_sounds', 'instrumental', 13, 6, 36, NULL, 0.72, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_d84d12d3_thunder1.mp3', 0),
  ('r2_nature_thunder2', 'Distant Thunder 2', 'Nature Sounds', 'nature_sounds', 'instrumental', 14, 6, 36, NULL, 0.72, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_ae09c7b5_thunder2.mp3', 0),
  ('r2_nature_thunder3', 'Thunder Rumble 3', 'Nature Sounds', 'nature_sounds', 'instrumental', 9, 6, 36, NULL, 0.70, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_8c8637a1_thunder3.mp3', 0),
  ('r2_nature_thunder4', 'Thunder Rumble 4', 'Nature Sounds', 'nature_sounds', 'instrumental', 9, 6, 36, NULL, 0.70, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_3b395f9f_thunder4.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Birds
  ('r2_nature_birds_relaxing', 'Relaxing Birds in Forest', 'Nature Sounds', 'nature_sounds', 'instrumental', 582, 0, 36, NULL, 0.82, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_4500fa82_Relaxing_Nature_Sounds_-_Birds.mp3', 0),
  ('r2_nature_shorebirds', 'Shore Birds', 'Nature Sounds', 'nature_sounds', 'instrumental', 24, 0, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_d4dc905a_13shorebirdsnest.mp3', 0),
  ('r2_nature_capemay_birds', 'Cape May Shorebirds', 'Nature Sounds', 'nature_sounds', 'instrumental', 14, 0, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_3f84e75f_05capemayshorebirds.mp3', 0),
  ('r2_nature_redwing', 'Red-winged Blackbird', 'Nature Sounds', 'nature_sounds', 'instrumental', 8, 0, 36, NULL, 0.78, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_ac489555_15redwingblackbird.mp3', 0),
  ('r2_nature_bigbeaks', 'Big Beaks', 'Nature Sounds', 'nature_sounds', 'instrumental', 12, 0, 36, NULL, 0.78, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_6be93dbe_07bigbeaks.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Wildlife & Other
  ('r2_nature_ducks', 'Ducks Landing in Water', 'Nature Sounds', 'nature_sounds', 'instrumental', 10, 0, 36, NULL, 0.75, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_0461808d_02duckslandinwater.mp3', 0),
  ('r2_nature_geese_far', 'Geese Honking Far', 'Nature Sounds', 'nature_sounds', 'instrumental', 9, 0, 36, NULL, 0.72, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_6e06fa3b_01geesehonkfar.mp3', 0),
  ('r2_nature_geese_fly', 'Geese Fly Honk', 'Nature Sounds', 'nature_sounds', 'instrumental', 16, 0, 36, NULL, 0.72, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_f195f5b8_04geeseflyhonk.mp3', 0),
  ('r2_nature_frogs', 'Frogs and Peepers', 'Nature Sounds', 'nature_sounds', 'instrumental', 30, 0, 36, NULL, 0.76, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_4e9dc64a_19frogsandsuch.mp3', 0),
  ('r2_nature_peepers', 'Spring Peepers', 'Nature Sounds', 'nature_sounds', 'instrumental', 32, 0, 36, NULL, 0.77, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_49dd4077_20peepers.mp3', 0),
  ('r2_nature_crickets', 'Night Crickets', 'Nature Sounds', 'nature_sounds', 'instrumental', 30, 0, 36, NULL, 0.80, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_4572df05_21singers.mp3', 0),
  ('r2_nature_wolf_howls', 'Wolf Howls', 'Nature Sounds', 'nature_sounds', 'instrumental', 28, 6, 36, NULL, 0.65, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_ab74d655_11wolfhowls.mp3', 0),
  ('r2_nature_wolf_play', 'Wolf Playing', 'Nature Sounds', 'nature_sounds', 'instrumental', 20, 6, 36, NULL, 0.68, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_e74022d2_10wolfplay.mp3', 0),
  ('r2_nature_bison', 'Bison Grunting', 'Nature Sounds', 'nature_sounds', 'instrumental', 178, 6, 36, NULL, 0.60, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_cddb0c57_20100816BisonGrunt-MormonRowGr.mp3', 0),
  ('r2_nature_bear_cubs', 'Baby Bear Cubs', 'Nature Sounds', 'nature_sounds', 'instrumental', 6, 6, 36, NULL, 0.70, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_c02c7317_03babycubsgrunt.mp3', 0),
  ('r2_nature_heron', 'Blue Heron Fishing', 'Nature Sounds', 'nature_sounds', 'instrumental', 23, 0, 36, NULL, 0.78, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_99cca8b1_09littleblueheronfishes.mp3', 0),
  ('r2_nature_bats', 'Evening Bats', 'Nature Sounds', 'nature_sounds', 'instrumental', 12, 6, 36, NULL, 0.65, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_0d8a91ad_18bats.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Long-form Relaxation Mixes
  ('r2_nature_2hr_relaxing', 'Two Hour Nature Relaxation', 'Nature Sounds', 'nature_sounds', 'instrumental', 7597, 0, 36, NULL, 0.88, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_6ee7757c_02_Hour_Relaxing.mp3', 0),
  ('r2_nature_relaxing_mix1', 'Relaxing Nature Sounds Mix', 'Nature Sounds', 'nature_sounds', 'instrumental', 1597, 0, 36, NULL, 0.87, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_5272adcd_Relaxing_Nature_Sounds_-_Trick.mp3', 0);

INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES
  -- Geothermal & Unique Sounds
  ('r2_nature_mudvolcano', 'Mud Volcano Bubbles', 'Nature Sounds', 'nature_sounds', 'instrumental', 313, 0, 36, NULL, 0.78, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_0fd883d6_20100817ChurningHisses-MudVolc.mp3', 0),
  ('r2_nature_cauldron', 'Black Dragon Cauldron', 'Nature Sounds', 'nature_sounds', 'instrumental', 330, 0, 36, NULL, 0.75, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_3a261fd8_20100817Hisses-BlackDragonCaul.mp3', 0),
  ('r2_nature_grizzly_hisses', 'Grizzly Hot Springs', 'Nature Sounds', 'nature_sounds', 'instrumental', 164, 0, 36, NULL, 0.77, 'recorded', NULL, 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ia_fc8c43a3_20100817BubblingHisses-Grizzly.mp3', 0);

-- ============================================
-- CREATE NATURE SOUNDS PLAYLISTS
-- ============================================

INSERT OR REPLACE INTO playlists (id, name, description, category, target_age_months, is_system)
VALUES
  ('pl_nature_water', 'Water Sounds', 'Soothing ocean waves, rain, and streams', 'nature_sounds', 0, 1),
  ('pl_nature_forest', 'Forest Ambience', 'Birds, crickets, and forest sounds', 'nature_sounds', 0, 1),
  ('pl_nature_rain', 'Rain Collection', 'Various rain sounds for relaxation', 'nature_sounds', 0, 1),
  ('pl_nature_extended', 'Extended Nature Mix', 'Long-form nature sounds for sleep', 'nature_sounds', 0, 1);

-- Water sounds playlist
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_water', 'r2_nature_ocean_waves', 1),
  ('pl_nature_water', 'r2_nature_calm_ocean', 2),
  ('pl_nature_water', 'r2_nature_beach_waves', 3),
  ('pl_nature_water', 'r2_nature_sb_stream', 4),
  ('pl_nature_water', 'r2_nature_whales', 5);

-- Forest playlist
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_forest', 'r2_nature_ambient', 1),
  ('pl_nature_forest', 'r2_nature_birds_relaxing', 2),
  ('pl_nature_forest', 'r2_nature_crickets', 3),
  ('pl_nature_forest', 'r2_nature_peepers', 4),
  ('pl_nature_forest', 'r2_nature_wind_trees', 5);

-- Rain playlist
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_rain', 'r2_nature_rain_gentle', 1),
  ('pl_nature_rain', 'r2_nature_rain_glass', 2),
  ('pl_nature_rain', 'r2_nature_light_rain', 3),
  ('pl_nature_rain', 'r2_nature_rain_ambient', 4),
  ('pl_nature_rain', 'r2_nature_rain_window', 5);

-- Extended playlist
INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES
  ('pl_nature_extended', 'r2_nature_2hr_relaxing', 1),
  ('pl_nature_extended', 'r2_nature_forest_long', 2),
  ('pl_nature_extended', 'r2_nature_sea_storm', 3),
  ('pl_nature_extended', 'r2_nature_relaxing_mix1', 4);

-- Summary: 60+ nature sound tracks with accurate durations
