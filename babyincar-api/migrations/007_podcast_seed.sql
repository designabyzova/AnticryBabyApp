-- Migration 007: Seed podcast tracks
-- Generated at: 2025-12-31T10:09:04.756574+00:00
-- Total tracks: 212

-- Delete existing podcast tracks to avoid duplicates
DELETE FROM tracks WHERE audio_source_type = 'streamed' AND source = 'podcast';

-- Insert podcast tracks
INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_calm_0000', '01. 5 Minute Calm Down - Relaxing Music For Panic ', 'Internet Archive', 'podcasts', 'en', 439, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_calm/ia_CalmingMusicForChildren_01_01._5_minute_calm_down_-_relaxing_music_for_panic_.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_calm_0001', '01. 5 Minute Calm Down - Relaxing Music For Panic ', 'Internet Archive', 'podcasts', 'en', 187, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_calm/ia_CalmingMusicForChildren_02_01._5_minute_calm_down_-_relaxing_music_for_panic_.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_calm_0002', '02. 5 Minute Meditation Music For Kids5 Minute Min', 'Internet Archive', 'podcasts', 'en', 451, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_calm/ia_CalmingMusicForChildren_03_02._5_minute_meditation_music_for_kids5_minute_min.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_calm_0003', '02. 5 Minute Meditation Music For Kids5 Minute Min', 'Internet Archive', 'podcasts', 'en', 189, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_calm/ia_CalmingMusicForChildren_04_02._5_minute_meditation_music_for_kids5_minute_min.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_calm_0004', '03. 5 Minute Relaxation Music For Yoga And Meditat', 'Internet Archive', 'podcasts', 'en', 470, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_calm/ia_CalmingMusicForChildren_05_03._5_minute_relaxation_music_for_yoga_and_meditat.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0005', '01 The Little Boy Who Wouldn''T Eat Cheesecake Written By Christina Meyers', 'Bedtime FM', 'fairy_tales', 'en', 471, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_01_the_little_boy_who_wouldn''t_eat_cheesecake_written_by_christina_meyers.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0006', '02 A Sausage Dog’S Tale Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 499, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_02_a_sausage_dog’s_tale_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0007', '03 The Midnight Princess 👸🏽 Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 734, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_03_the_midnight_princess_👸🏽_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0008', '04 The Swamp Monster Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 876, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_04_the_swamp_monster_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0009', '05 The Sea Mice 🐁 Written By Kenneth Stevens', 'Bedtime FM', 'fairy_tales', 'en', 1559, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_05_the_sea_mice_🐁_written_by_kenneth_stevens.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0010', '06 Nora And The Narwhals Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 1299, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_06_nora_and_the_narwhals_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0011', '07 Bunny Magic 🐰 Written By Nicole Esquino', 'Bedtime FM', 'fairy_tales', 'en', 646, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_07_bunny_magic_🐰_written_by_nicole_esquino.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0012', '08 Butterfly Magic 🦋 Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 758, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_08_butterfly_magic_🦋_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0013', '09 Monkey Brain Matilda 🧠 Written By Brooke Taylor', 'Bedtime FM', 'fairy_tales', 'en', 358, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_09_monkey_brain_matilda_🧠_written_by_brooke_taylor.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0014', '10 The Magic Spark Written By Hannah Erickson', 'Bedtime FM', 'fairy_tales', 'en', 717, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_10_the_magic_spark_written_by_hannah_erickson.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0015', '11 The Search For The Missing Sock 🧦 Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 926, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_11_the_search_for_the_missing_sock_🧦_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0016', '12 Tardy Zombies 🧟‍♂️🧟‍♀️ Written By Stuart Baum', 'Bedtime FM', 'fairy_tales', 'en', 934, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_12_tardy_zombies_🧟‍♂️🧟‍♀️_written_by_stuart_baum.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0017', '13 Just One Day Written By Angela Nissen', 'Bedtime FM', 'fairy_tales', 'en', 636, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_13_just_one_day_written_by_angela_nissen.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0018', '14 Forest School 2 The Lost Treasure 🌳🏫🌳 ⌚ Written By Hannah Erickson', 'Bedtime FM', 'fairy_tales', 'en', 730, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_14_forest_school_2_the_lost_treasure_🌳🏫🌳_⌚_written_by_hannah_erickson.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0019', '15 The Little Raindrop Written By Ghost Sung', 'Bedtime FM', 'fairy_tales', 'en', 347, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_15_the_little_raindrop_written_by_ghost_sung.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0020', '16 Thank You From The Jifflings Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_16_thank_you_from_the_jifflings_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0021', '17 Episode 10 The Donkey’S Bucket Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_17_episode_10_the_donkey’s_bucket_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0022', '18 Episode 9 The Tug Of War Rope Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_18_episode_9_the_tug_of_war_rope_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0023', '19 Episode 8 The Elephant’S Trumpet Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_19_episode_8_the_elephant’s_trumpet_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0024', '20 Episode 7 The Christmas Diamond Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_20_episode_7_the_christmas_diamond_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0025', '21 Episode 6 The Paintbrush Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_21_episode_6_the_paintbrush_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0026', '22 Episode 5 The Clown’S Nose Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_22_episode_5_the_clown’s_nose_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0027', '23 Episode 4 The Fascinating Moose Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_23_episode_4_the_fascinating_moose_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0028', '24 Episode 3 The Astronaut’S Helmet Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 601, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_24_episode_3_the_astronaut’s_helmet_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0029', '25 Episode 2 The Sunglasses Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_25_episode_2_the_sunglasses_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0030', '26 Episode 1 The Old Boot Written By Charly Conquest And Ben Mullins', 'Bedtime FM', 'fairy_tales', 'en', 600, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_26_episode_1_the_old_boot_written_by_charly_conquest_and_ben_mullins.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0031', '27 Buffy Bunny And The Magical Adventure Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 1116, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_27_buffy_bunny_and_the_magical_adventure_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0032', '28 Robyn Goes Flying! Written By Elaine Binns', 'Bedtime FM', 'fairy_tales', 'en', 566, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_28_robyn_goes_flying!_written_by_elaine_binns.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0033', '29 Ski Trip Surprise ⛷ Written By Jess Judd', 'Bedtime FM', 'fairy_tales', 'en', 646, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_29_ski_trip_surprise_⛷_written_by_jess_judd.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0034', '30 Hide And Seek Tips Written By Nicole Esquino', 'Bedtime FM', 'fairy_tales', 'en', 876, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/bedtime_fm_storytime_30_hide_and_seek_tips_written_by_nicole_esquino.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0035', 'Fables 01 The People''S Idea Of God', 'LibriVox', 'fairy_tales', 'en', 850, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_aesop''s_fables_01_the_people''s_idea_of_god.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0036', 'In Wonderland 01 The Aged Pilot Man', 'LibriVox', 'fairy_tales', 'en', 199, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_01_the_aged_pilot_man.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0037', 'In Wonderland 02 Ballad Of The Goodly Fere', 'LibriVox', 'fairy_tales', 'en', 90, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_02_ballad_of_the_goodly_fere.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0038', 'In Wonderland 03 Dover Beach', 'LibriVox', 'fairy_tales', 'en', 83, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_03_dover_beach.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0039', 'In Wonderland 04 Dulce Et Decorum Est', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_04_dulce_et_decorum_est.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0040', 'In Wonderland 05 Dutch Lullabye', 'LibriVox', 'fairy_tales', 'en', 61, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_05_dutch_lullabye.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0041', 'In Wonderland 06 Gunga Din', 'LibriVox', 'fairy_tales', 'en', 125, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_06_gunga_din.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0042', 'In Wonderland 07 The Highwayman', 'LibriVox', 'fairy_tales', 'en', 216, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_07_the_highwayman.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0043', 'In Wonderland 08 His Excuse For Loving', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_08_his_excuse_for_loving.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0044', 'In Wonderland 09 Jenny Kiss''D Me', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_09_jenny_kiss''d_me.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0045', 'In Wonderland 10 On First Looking Into Chapman''', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_10_on_first_looking_into_chapman''.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0046', 'In Wonderland 11 Ozymandias Of Egypt', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_11_ozymandias_of_egypt.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0047', 'In Wonderland 12 Ozymandias Of Egypt', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_alice_in_wonderland_12_ozymandias_of_egypt.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0048', 'So Stories 01 Bk1 00 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 95, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_01_bk1_00_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0049', 'So Stories 02 Bk1 01 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 1030, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_02_bk1_01_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0050', 'So Stories 03 Bk1 02 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 727, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_03_bk1_02_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0051', 'So Stories 04 Bk1 03 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 593, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_04_bk1_03_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0052', 'So Stories 05 Bk1 04 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 966, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_05_bk1_04_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0053', 'So Stories 06 Bk1 05 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 1020, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_06_bk1_05_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0054', 'So Stories 07 Bk1 06 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 643, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_07_bk1_06_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0055', 'So Stories 08 Bk1 07 - The Legende Of The Kn', 'LibriVox', 'fairy_tales', 'en', 686, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_just_so_stories_08_bk1_07_-_the_legende_of_the_kn.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0056', 'Velveteen Rabbit 01 Xix Secondary Sexual Character', 'LibriVox', 'fairy_tales', 'en', 1224, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_velveteen_rabbit_01_xix_secondary_sexual_character.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0057', 'Velveteen Rabbit 02 Xix Secondary Sexual Character', 'LibriVox', 'fairy_tales', 'en', 742, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_velveteen_rabbit_02_xix_secondary_sexual_character.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0058', 'Velveteen Rabbit 03 Xx. Secondary Sexual Character', 'LibriVox', 'fairy_tales', 'en', 901, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_velveteen_rabbit_03_xx._secondary_sexual_character.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0059', 'Velveteen Rabbit 04 Xx. Secondary Sexual Character', 'LibriVox', 'fairy_tales', 'en', 874, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_velveteen_rabbit_04_xx._secondary_sexual_character.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0060', 'Velveteen Rabbit 05 Xxi.General Summary And Conclu', 'LibriVox', 'fairy_tales', 'en', 1301, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_velveteen_rabbit_05_xxi.general_summary_and_conclu.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0061', 'Wonderful Wizard Of Oz 01 Version 1', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_01_version_1.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0062', 'Wonderful Wizard Of Oz 02 Version 2', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_02_version_2.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0063', 'Wonderful Wizard Of Oz 03 Version 3', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_03_version_3.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0064', 'Wonderful Wizard Of Oz 04 Version 4', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_04_version_4.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0065', 'Wonderful Wizard Of Oz 05 Version 5', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_05_version_5.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0066', 'Wonderful Wizard Of Oz 06 Version 6', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_06_version_6.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0067', 'Wonderful Wizard Of Oz 07 Version 7', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_07_version_7.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0068', 'Wonderful Wizard Of Oz 08 Version 8', 'LibriVox', 'fairy_tales', 'en', 60, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_08_version_8.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0069', '(Relaxing) 01 Chapter 1, Part 1', 'LibriVox', 'fairy_tales', 'en', 886, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_walden_(relaxing)_01_chapter_1,_part_1.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0070', '(Relaxing) 02 Chapter 1, Part 2', 'LibriVox', 'fairy_tales', 'en', 1130, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_walden_(relaxing)_02_chapter_1,_part_2.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0071', '(Relaxing) 03 Chapter 1, Part 3', 'LibriVox', 'fairy_tales', 'en', 1727, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_walden_(relaxing)_03_chapter_1,_part_3.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0072', '(Relaxing) 04 Chapter 1, Part 4', 'LibriVox', 'fairy_tales', 'en', 1360, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_walden_(relaxing)_04_chapter_1,_part_4.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_children_stories_0073', '(Relaxing) 05 Chapter 1, Part 5', 'LibriVox', 'fairy_tales', 'en', 686, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/children_stories/librivox_walden_(relaxing)_05_chapter_1,_part_5.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_russian_fairy_tales_english_0074', 'russian fairy tales - baba yaga (english)', 'LibriVox Russia', 'podcasts', 'en', 505, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/russian_fairy_tales_english/ru_fairytale_en_01_russian_fairy_tales_-_baba_yaga_(english).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_russian_fairy_tales_english_0075', 'russian fairy tales - koshchey the deathless (english)', 'LibriVox Russia', 'podcasts', 'en', 375, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/russian_fairy_tales_english/ru_fairytale_en_02_russian_fairy_tales_-_koshchey_the_deathless_(english).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_russian_fairy_tales_english_0076', 'russian fairy tales - the firebird (english)', 'LibriVox Russia', 'podcasts', 'en', 687, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/russian_fairy_tales_english/ru_fairytale_en_03_russian_fairy_tales_-_the_firebird_(english).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_russian_fairy_tales_english_0077', 'russian fairy tales - vasilisa the beautiful (english)', 'LibriVox Russia', 'podcasts', 'en', 890, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/russian_fairy_tales_english/ru_fairytale_en_04_russian_fairy_tales_-_vasilisa_the_beautiful_(english).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_russian_fairy_tales_english_0078', 'russian fairy tales - the frog princess (english)', 'LibriVox Russia', 'podcasts', 'en', 1741, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/russian_fairy_tales_english/ru_fairytale_en_05_russian_fairy_tales_-_the_frog_princess_(english).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0079', 'Air Conditioner A', 'Internet Archive', 'white_noise', 'en', 15820, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_01_air_conditioner_a.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0080', 'Air Conditioner A', 'Internet Archive', 'white_noise', 'en', 11519, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_02_air_conditioner_a.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0081', 'Air Conditioner B', 'Internet Archive', 'white_noise', 'en', 15820, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_03_air_conditioner_b.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0082', 'Air Conditioner B', 'Internet Archive', 'white_noise', 'en', 10699, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_04_air_conditioner_b.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0083', 'Air Fan Deep', 'Internet Archive', 'white_noise', 'en', 15820, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_05_air_fan_deep.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0084', 'Air Fan Deep', 'Internet Archive', 'white_noise', 'en', 10553, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_06_air_fan_deep.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0085', 'Air Fan Desk', 'Internet Archive', 'white_noise', 'en', 15819, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_07_air_fan_desk.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_en_whitenoise_0086', 'Air Fan Desk', 'Internet Archive', 'white_noise', 'en', 11071, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/en/whitenoise/ia_SleepSounds_08_air_fan_desk.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0087', '1 Hour Beethoven Brahms And Mozart Lullaby', 'Internet Archive', 'classical_music', 'multi', 700, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_01_1_hour_beethoven_brahms_and_mozart_lullaby.m4a', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0088', '1 Hour Beethoven Brahms And Mozart Lullaby', 'Internet Archive', 'classical_music', 'multi', 4653, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_02_1_hour_beethoven_brahms_and_mozart_lullaby.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0089', '1 Hour Beethoven Brahms And Mozart Lullaby', 'Internet Archive', 'classical_music', 'multi', 2128, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_03_1_hour_beethoven_brahms_and_mozart_lullaby.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0090', '1 Hour Lullabies For Babies To Go To Sleep', 'Internet Archive', 'classical_music', 'multi', 572, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_04_1_hour_lullabies_for_babies_to_go_to_sleep.m4a', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0091', '1 Hour Lullabies For Babies To Go To Sleep', 'Internet Archive', 'classical_music', 'multi', 3798, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_05_1_hour_lullabies_for_babies_to_go_to_sleep.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0092', '1 Hour Lullabies For Babies To Go To Sleep', 'Internet Archive', 'classical_music', 'multi', 1660, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_06_1_hour_lullabies_for_babies_to_go_to_sleep.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0093', '1 Hour Music Instrumental - Peaceful Lullabies For', 'Internet Archive', 'classical_music', 'multi', 701, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_07_1_hour_music_instrumental_-_peaceful_lullabies_for.m4a', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0094', '1 Hour Music Instrumental - Peaceful Lullabies For', 'Internet Archive', 'classical_music', 'multi', 4091, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_08_1_hour_music_instrumental_-_peaceful_lullabies_for.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0095', '1 Hour Music Instrumental - Peaceful Lullabies For', 'Internet Archive', 'classical_music', 'multi', 2020, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_09_1_hour_music_instrumental_-_peaceful_lullabies_for.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_classical_0096', '1 Hour Piano Music For Babies Lullabies - Download', 'Internet Archive', 'classical_music', 'multi', 683, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_10_1_hour_piano_music_for_babies_lullabies_-_download.m4a', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0097', 'Bacrahms Lullaby For Baby - Bedtime Music - Lullab', 'Internet Archive', 'instrumental', 'multi', 133, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_01_bacrahms_lullaby_for_baby_-_bedtime_music_-_lullab.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0098', 'Bacrahms Lullaby For Baby - Bedtime Music - Lullab', 'Internet Archive', 'instrumental', 'multi', 81, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_02_bacrahms_lullaby_for_baby_-_bedtime_music_-_lullab.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0099', 'Balullabies For Babies - Brahms Lullaby, Bedtime L', 'Internet Archive', 'instrumental', 'multi', 222, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_03_balullabies_for_babies_-_brahms_lullaby,_bedtime_l.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0100', 'Balullabies For Babies - Brahms Lullaby, Bedtime L', 'Internet Archive', 'instrumental', 'multi', 134, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_04_balullabies_for_babies_-_brahms_lullaby,_bedtime_l.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0101', 'Bamusic For Babies, Sleep Relax', 'Internet Archive', 'instrumental', 'multi', 215, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_05_bamusic_for_babies,_sleep_relax.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0102', 'Bamusic For Babies, Sleep Relax', 'Internet Archive', 'instrumental', 'multi', 108, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_06_bamusic_for_babies,_sleep_relax.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0103', 'Bamusicbox For Babies 5 - Sleep - Soothing - Relax', 'Internet Archive', 'instrumental', 'multi', 219, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_07_bamusicbox_for_babies_5_-_sleep_-_soothing_-_relax.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0104', 'Bamusicbox For Babies 5 - Sleep - Soothing - Relax', 'Internet Archive', 'instrumental', 'multi', 123, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_08_bamusicbox_for_babies_5_-_sleep_-_soothing_-_relax.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0105', 'Basweet Dreams (Goodnight Song)', 'Internet Archive', 'instrumental', 'multi', 183, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_09_basweet_dreams_(goodnight_song).mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0106', 'Basweet Dreams (Goodnight Song)', 'Internet Archive', 'instrumental', 'multi', 126, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_10_basweet_dreams_(goodnight_song).ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0107', 'Baby Sleep Music', 'Internet Archive', 'instrumental', 'multi', 42218, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_01_baby_sleep_music.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0108', 'Baby Songs To Go To Sleep', 'Internet Archive', 'instrumental', 'multi', 32199, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_02_baby_songs_to_go_to_sleep.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0109', 'Bedtime Music', 'Internet Archive', 'instrumental', 'multi', 16055, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_03_bedtime_music.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0110', 'Good Night Sweet Dreams', 'Internet Archive', 'instrumental', 'multi', 15840, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_04_good_night_sweet_dreams.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0111', 'Happy Sleep Music', 'Internet Archive', 'instrumental', 'multi', 6165, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_05_happy_sleep_music.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0112', 'Relaxing Lullaby For Kids', 'Internet Archive', 'instrumental', 'multi', 2708, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_06_relaxing_lullaby_for_kids.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0113', 'Soft Relaxing Baby Sleep Music', 'Internet Archive', 'instrumental', 'multi', 3173, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_07_soft_relaxing_baby_sleep_music.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0114', 'Songs To Put A Baby To Sleep', 'Internet Archive', 'instrumental', 'multi', 23296, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_08_songs_to_put_a_baby_to_sleep.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0115', 'Super Relaxing Baby Sleep Music', 'Internet Archive', 'instrumental', 'multi', 6263, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_09_super_relaxing_baby_sleep_music.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0116', 'Sweet Dreams', 'Internet Archive', 'instrumental', 'multi', 11459, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_baby-sleep-music_10_sweet_dreams.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0117', 'Sleeping Baby Music1 Hour Super Soothing Hush Litt', 'Internet Archive', 'instrumental', 'multi', 3650, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_01_sleeping_baby_music1_hour_super_soothing_hush_litt.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0118', 'Sleeping Baby Music1 Hour Super Soothing Hush Litt', 'Internet Archive', 'instrumental', 'multi', 2289, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_02_sleeping_baby_music1_hour_super_soothing_hush_litt.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0119', 'Sleeping Baby Music2 Hours Super Relaxing Baby Mus', 'Internet Archive', 'instrumental', 'multi', 6680, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_03_sleeping_baby_music2_hours_super_relaxing_baby_mus.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0120', 'Sleeping Baby Music2 Hours Super Relaxing Baby Mus', 'Internet Archive', 'instrumental', 'multi', 3779, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_04_sleeping_baby_music2_hours_super_relaxing_baby_mus.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0121', 'Sleeping Baby Musicbaby Mozart Best Of Mozart Baby', 'Internet Archive', 'instrumental', 'multi', 3840, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_05_sleeping_baby_musicbaby_mozart_best_of_mozart_baby.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0122', 'Sleeping Baby Musicbaby Mozart Best Of Mozart Baby', 'Internet Archive', 'instrumental', 'multi', 2273, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_06_sleeping_baby_musicbaby_mozart_best_of_mozart_baby.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0123', 'Sleeping Baby Musicbedtime Lullaby - Baby Sleep Mu', 'Internet Archive', 'instrumental', 'multi', 1474, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_07_sleeping_baby_musicbedtime_lullaby_-_baby_sleep_mu.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0124', 'Sleeping Baby Musicbedtime Lullaby - Baby Sleep Mu', 'Internet Archive', 'instrumental', 'multi', 701, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_08_sleeping_baby_musicbedtime_lullaby_-_baby_sleep_mu.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0125', 'Sleeping Baby Musiclullabies Lullaby For Babies To', 'Internet Archive', 'instrumental', 'multi', 5966, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_09_sleeping_baby_musiclullabies_lullaby_for_babies_to.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_multi_lullabies_0126', 'Sleeping Baby Musiclullabies Lullaby For Babies To', 'Internet Archive', 'instrumental', 'multi', 3528, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/multi/lullabies/ia_sleepingbabymusicz_10_sleeping_baby_musiclullabies_lullaby_for_babies_to.ogg', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0157', 'лисичка-сестричка и волк', 'LibriVox Russia', 'fairy_tales', 'ru', 735, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_01_лисичка-сестричка_и_волк.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0158', 'кот, петух и лиса', 'LibriVox Russia', 'fairy_tales', 'ru', 147, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_02_кот,_петух_и_лиса.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0159', 'волк и коза', 'LibriVox Russia', 'fairy_tales', 'ru', 229, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_03_волк_и_коза.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0160', 'курочка ряба', 'LibriVox Russia', 'fairy_tales', 'ru', 117, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_04_курочка_ряба.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0161', 'репка', 'LibriVox Russia', 'fairy_tales', 'ru', 184, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_05_репка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0162', 'теремок', 'LibriVox Russia', 'fairy_tales', 'ru', 180, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_06_теремок.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0163', 'колобок', 'LibriVox Russia', 'fairy_tales', 'ru', 337, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_07_колобок.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0164', 'маша и медведь', 'LibriVox Russia', 'fairy_tales', 'ru', 491, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_08_маша_и_медведь.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0165', 'гуси-лебеди', 'LibriVox Russia', 'fairy_tales', 'ru', 646, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_09_гуси-лебеди.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0166', 'морозко', 'LibriVox Russia', 'fairy_tales', 'ru', 541, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_10_морозко.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0167', 'снегурочка', 'LibriVox Russia', 'fairy_tales', 'ru', 585, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_11_снегурочка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0168', 'сестрица алёнушка и братец иванушка', 'LibriVox Russia', 'fairy_tales', 'ru', 1021, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_12_сестрица_алёнушка_и_братец_иванушка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0169', 'царевна-лягушка', 'LibriVox Russia', 'fairy_tales', 'ru', 563, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_13_царевна-лягушка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0170', 'иван-царевич и серый волк', 'LibriVox Russia', 'fairy_tales', 'ru', 655, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_14_иван-царевич_и_серый_волк.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0171', 'сивка-бурка', 'LibriVox Russia', 'fairy_tales', 'ru', 312, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_15_сивка-бурка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0172', 'по щучьему веленью', 'LibriVox Russia', 'fairy_tales', 'ru', 928, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_16_по_щучьему_веленью.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0173', 'финист ясный сокол', 'LibriVox Russia', 'fairy_tales', 'ru', 253, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_17_финист_ясный_сокол.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0174', 'василиса прекрасная', 'LibriVox Russia', 'fairy_tales', 'ru', 707, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_18_василиса_прекрасная.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0175', 'марья моревна', 'LibriVox Russia', 'fairy_tales', 'ru', 322, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_19_марья_моревна.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0176', 'кощей бессмертный', 'LibriVox Russia', 'fairy_tales', 'ru', 1029, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v1_20_кощей_бессмертный.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0177', 'баба-яга', 'LibriVox Russia', 'fairy_tales', 'ru', 110, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_01_баба-яга.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0178', 'жар-птица и василиса-царевна', 'LibriVox Russia', 'fairy_tales', 'ru', 86, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_02_жар-птица_и_василиса-царевна.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0179', 'крошечка-хаврошечка', 'LibriVox Russia', 'fairy_tales', 'ru', 191, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_03_крошечка-хаврошечка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0180', 'иванушка-дурачок', 'LibriVox Russia', 'fairy_tales', 'ru', 348, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_04_иванушка-дурачок.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0181', 'летучий корабль', 'LibriVox Russia', 'fairy_tales', 'ru', 174, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_05_летучий_корабль.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0182', 'мальчик с пальчик', 'LibriVox Russia', 'fairy_tales', 'ru', 482, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_06_мальчик_с_пальчик.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0183', 'никита кожемяка', 'LibriVox Russia', 'fairy_tales', 'ru', 369, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_07_никита_кожемяка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0184', 'петушок - золотой гребешок', 'LibriVox Russia', 'fairy_tales', 'ru', 234, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_08_петушок_-_золотой_гребешок.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0185', 'три медведя', 'LibriVox Russia', 'fairy_tales', 'ru', 200, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_09_три_медведя.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0186', 'заюшкина избушка', 'LibriVox Russia', 'fairy_tales', 'ru', 355, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_10_заюшкина_избушка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0187', 'лиса и журавль', 'LibriVox Russia', 'fairy_tales', 'ru', 233, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_11_лиса_и_журавль.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0188', 'пузырь, соломинка и лапоть', 'LibriVox Russia', 'fairy_tales', 'ru', 101, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_12_пузырь,_соломинка_и_лапоть.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0189', 'бычок - смоляной бочок', 'LibriVox Russia', 'fairy_tales', 'ru', 261, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_13_бычок_-_смоляной_бочок.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0190', 'волшебное кольцо', 'LibriVox Russia', 'fairy_tales', 'ru', 319, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_14_волшебное_кольцо.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0191', 'каша из топора', 'LibriVox Russia', 'fairy_tales', 'ru', 158, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_15_каша_из_топора.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0192', 'петух и жерновцы', 'LibriVox Russia', 'fairy_tales', 'ru', 972, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_16_петух_и_жерновцы.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0193', 'скатерть, баранчик и сума', 'LibriVox Russia', 'fairy_tales', 'ru', 356, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_17_скатерть,_баранчик_и_сума.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0194', 'солнце, месяц и ворон', 'LibriVox Russia', 'fairy_tales', 'ru', 474, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_18_солнце,_месяц_и_ворон.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0195', 'хрустальная гора', 'LibriVox Russia', 'fairy_tales', 'ru', 366, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_19_хрустальная_гора.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_fairy_tales_0196', 'чудесная рубашка', 'LibriVox Russia', 'fairy_tales', 'ru', 288, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_fairy_tales/ru_fairytale_v2_20_чудесная_рубашка.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0197', '2007 Librivox 01 Russianfairytales1 01 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 610, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_01_russianfairytales1_01_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0198', '2007 Librivox 02 Russianfairytales1 01 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 735, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_02_russianfairytales1_01_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0199', '2007 Librivox 03 Russianfairytales1 02 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 118, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_03_russianfairytales1_02_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0200', '2007 Librivox 04 Russianfairytales1 02 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 147, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_04_russianfairytales1_02_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0201', '2007 Librivox 05 Russianfairytales1 03 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 183, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_05_russianfairytales1_03_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0202', '2007 Librivox 06 Russianfairytales1 03 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 229, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_06_russianfairytales1_03_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0203', '2007 Librivox 07 Russianfairytales1 04 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 96, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_07_russianfairytales1_04_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0204', '2007 Librivox 08 Russianfairytales1 04 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 117, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_08_russianfairytales1_04_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0205', '2007 Librivox 09 Russianfairytales1 05 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 147, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_09_russianfairytales1_05_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0206', '2007 Librivox 10 Russianfairytales1 05 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 184, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_10_russianfairytales1_05_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0207', '2007 Librivox 11 Russianfairytales1 06 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 147, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_11_russianfairytales1_06_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0208', '2007 Librivox 12 Russianfairytales1 06 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 180, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_12_russianfairytales1_06_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0209', '2007 Librivox 13 Russianfairytales1 07 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 299, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_13_russianfairytales1_07_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0210', '2007 Librivox 14 Russianfairytales1 07 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 337, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_14_russianfairytales1_07_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0211', '2007 Librivox 15 Russianfairytales1 08 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 439, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_15_russianfairytales1_08_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0212', '2103 Librivox 01 Russianfairytales2 01 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 86, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_01_russianfairytales2_01_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0213', '2103 Librivox 02 Russianfairytales2 01 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 110, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_02_russianfairytales2_01_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0214', '2103 Librivox 03 Russianfairytales2 02 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 66, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_03_russianfairytales2_02_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0215', '2103 Librivox 04 Russianfairytales2 02 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 86, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_04_russianfairytales2_02_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0216', '2103 Librivox 05 Russianfairytales2 03 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 156, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_05_russianfairytales2_03_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0217', '2103 Librivox 06 Russianfairytales2 03 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 191, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_06_russianfairytales2_03_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0218', '2103 Librivox 07 Russianfairytales2 04 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 308, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_07_russianfairytales2_04_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0219', '2103 Librivox 08 Russianfairytales2 04 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 348, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_08_russianfairytales2_04_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0220', '2103 Librivox 09 Russianfairytales2 05 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 145, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_09_russianfairytales2_05_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0221', '2103 Librivox 10 Russianfairytales2 05 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 174, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_10_russianfairytales2_05_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0222', '2103 Librivox 11 Russianfairytales2 06 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 364, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_11_russianfairytales2_06_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0223', '2103 Librivox 12 Russianfairytales2 06 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 482, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_12_russianfairytales2_06_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0224', '2103 Librivox 13 Russianfairytales2 07 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 318, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_13_russianfairytales2_07_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0225', '2103 Librivox 14 Russianfairytales2 07 Afanasyev 128Kb', 'LibriVox', 'fairy_tales', 'ru', 369, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_14_russianfairytales2_07_afanasyev_128kb.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_ru_russian_stories_0226', '2103 Librivox 15 Russianfairytales2 08 Afanasyev', 'LibriVox', 'fairy_tales', 'ru', 178, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_15_russianfairytales2_08_afanasyev.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_01.mp3_0227', 'Fairy Tale 01', 'Baby in Car', 'fairy_tales', 'ru', 735, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_01.mp3/fairy_tale_01.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_02.mp3_0228', 'Fairy Tale 02', 'Baby in Car', 'fairy_tales', 'ru', 147, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_02.mp3/fairy_tale_02.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_03.mp3_0229', 'Fairy Tale 03', 'Baby in Car', 'fairy_tales', 'ru', 229, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_03.mp3/fairy_tale_03.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_04.mp3_0230', 'Fairy Tale 04', 'Baby in Car', 'fairy_tales', 'ru', 117, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_04.mp3/fairy_tale_04.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_05.mp3_0231', 'Fairy Tale 05', 'Baby in Car', 'fairy_tales', 'ru', 184, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_05.mp3/fairy_tale_05.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_06.mp3_0232', 'Fairy Tale 06', 'Baby in Car', 'fairy_tales', 'ru', 110, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_06.mp3/fairy_tale_06.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_07.mp3_0233', 'Fairy Tale 07', 'Baby in Car', 'fairy_tales', 'ru', 86, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_07.mp3/fairy_tale_07.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_08.mp3_0234', 'Fairy Tale 08', 'Baby in Car', 'fairy_tales', 'ru', 191, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_08.mp3/fairy_tale_08.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_09.mp3_0235', 'Fairy Tale 09', 'Baby in Car', 'fairy_tales', 'ru', 348, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_09.mp3/fairy_tale_09.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_10.mp3_0236', 'Fairy Tale 10', 'Baby in Car', 'fairy_tales', 'ru', 174, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_10.mp3/fairy_tale_10.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_11.mp3_0237', 'Fairy Tale 11', 'Baby in Car', 'fairy_tales', 'ru', 482, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_11.mp3/fairy_tale_11.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_12.mp3_0238', 'Fairy Tale 12', 'Baby in Car', 'fairy_tales', 'ru', 369, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_12.mp3/fairy_tale_12.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_13.mp3_0239', 'Fairy Tale 13', 'Baby in Car', 'fairy_tales', 'ru', 234, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_13.mp3/fairy_tale_13.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_14.mp3_0240', 'Fairy Tale 14', 'Baby in Car', 'fairy_tales', 'ru', 200, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_14.mp3/fairy_tale_14.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

INSERT INTO tracks (id, title, artist, category, language, duration, calming_score, age_range_min, age_range_max, audio_source_type, stream_url, is_premium, source, created_at)
VALUES ('podcast_russian_fairy_tale_15.mp3_0241', 'Fairy Tale 15', 'Baby in Car', 'fairy_tales', 'ru', 355, 0.8, 0, 36, 'streamed', 'https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/russian/fairy_tale_15.mp3/fairy_tale_15.mp3', 0, 'podcast', datetime('now'))
ON CONFLICT(id) DO UPDATE SET stream_url = excluded.stream_url;

-- Insert podcast metadata
INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_calm_0000', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_calm/ia_CalmingMusicForChildren_01_01._5_minute_calm_down_-_relaxing_music_for_panic_.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_calm_0001', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_calm/ia_CalmingMusicForChildren_02_01._5_minute_calm_down_-_relaxing_music_for_panic_.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_calm_0002', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_calm/ia_CalmingMusicForChildren_03_02._5_minute_meditation_music_for_kids5_minute_min.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_calm_0003', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_calm/ia_CalmingMusicForChildren_04_02._5_minute_meditation_music_for_kids5_minute_min.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_calm_0004', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_calm/ia_CalmingMusicForChildren_05_03._5_minute_relaxation_music_for_yoga_and_meditat.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0005', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_01_the_little_boy_who_wouldn''t_eat_cheesecake_written_by_christina_meyers.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0006', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_02_a_sausage_dog’s_tale_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0007', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_03_the_midnight_princess_👸🏽_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0008', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_04_the_swamp_monster_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0009', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_05_the_sea_mice_🐁_written_by_kenneth_stevens.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0010', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_06_nora_and_the_narwhals_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0011', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_07_bunny_magic_🐰_written_by_nicole_esquino.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0012', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_08_butterfly_magic_🦋_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0013', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_09_monkey_brain_matilda_🧠_written_by_brooke_taylor.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0014', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_10_the_magic_spark_written_by_hannah_erickson.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0015', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_11_the_search_for_the_missing_sock_🧦_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0016', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_12_tardy_zombies_🧟‍♂️🧟‍♀️_written_by_stuart_baum.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0017', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_13_just_one_day_written_by_angela_nissen.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0018', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_14_forest_school_2_the_lost_treasure_🌳🏫🌳_⌚_written_by_hannah_erickson.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0019', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_15_the_little_raindrop_written_by_ghost_sung.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0020', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_16_thank_you_from_the_jifflings_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0021', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_17_episode_10_the_donkey’s_bucket_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0022', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_18_episode_9_the_tug_of_war_rope_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0023', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_19_episode_8_the_elephant’s_trumpet_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0024', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_20_episode_7_the_christmas_diamond_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0025', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_21_episode_6_the_paintbrush_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0026', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_22_episode_5_the_clown’s_nose_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0027', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_23_episode_4_the_fascinating_moose_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0028', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_24_episode_3_the_astronaut’s_helmet_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0029', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_25_episode_2_the_sunglasses_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0030', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_26_episode_1_the_old_boot_written_by_charly_conquest_and_ben_mullins.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0031', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_27_buffy_bunny_and_the_magical_adventure_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0032', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_28_robyn_goes_flying!_written_by_elaine_binns.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0033', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_29_ski_trip_surprise_⛷_written_by_jess_judd.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0034', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/bedtime_fm_storytime_30_hide_and_seek_tips_written_by_nicole_esquino.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0035', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_aesop''s_fables_01_the_people''s_idea_of_god.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0036', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_01_the_aged_pilot_man.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0037', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_02_ballad_of_the_goodly_fere.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0038', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_03_dover_beach.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0039', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_04_dulce_et_decorum_est.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0040', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_05_dutch_lullabye.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0041', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_06_gunga_din.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0042', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_07_the_highwayman.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0043', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_08_his_excuse_for_loving.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0044', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_09_jenny_kiss''d_me.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0045', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_10_on_first_looking_into_chapman''.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0046', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_11_ozymandias_of_egypt.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0047', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_alice_in_wonderland_12_ozymandias_of_egypt.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0048', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_01_bk1_00_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0049', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_02_bk1_01_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0050', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_03_bk1_02_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0051', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_04_bk1_03_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0052', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_05_bk1_04_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0053', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_06_bk1_05_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0054', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_07_bk1_06_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0055', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_just_so_stories_08_bk1_07_-_the_legende_of_the_kn.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0056', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_velveteen_rabbit_01_xix_secondary_sexual_character.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0057', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_velveteen_rabbit_02_xix_secondary_sexual_character.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0058', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_velveteen_rabbit_03_xx._secondary_sexual_character.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0059', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_velveteen_rabbit_04_xx._secondary_sexual_character.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0060', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_velveteen_rabbit_05_xxi.general_summary_and_conclu.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0061', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_01_version_1.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0062', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_02_version_2.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0063', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_03_version_3.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0064', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_04_version_4.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0065', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_05_version_5.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0066', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_06_version_6.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0067', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_07_version_7.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0068', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_the_wonderful_wizard_of_oz_08_version_8.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0069', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_walden_(relaxing)_01_chapter_1,_part_1.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0070', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_walden_(relaxing)_02_chapter_1,_part_2.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0071', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_walden_(relaxing)_03_chapter_1,_part_3.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0072', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_walden_(relaxing)_04_chapter_1,_part_4.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_children_stories_0073', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/children_stories/librivox_walden_(relaxing)_05_chapter_1,_part_5.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_russian_fairy_tales_english_0074', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/russian_fairy_tales_english/ru_fairytale_en_01_russian_fairy_tales_-_baba_yaga_(english).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_russian_fairy_tales_english_0075', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/russian_fairy_tales_english/ru_fairytale_en_02_russian_fairy_tales_-_koshchey_the_deathless_(english).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_russian_fairy_tales_english_0076', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/russian_fairy_tales_english/ru_fairytale_en_03_russian_fairy_tales_-_the_firebird_(english).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_russian_fairy_tales_english_0077', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/russian_fairy_tales_english/ru_fairytale_en_04_russian_fairy_tales_-_vasilisa_the_beautiful_(english).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_russian_fairy_tales_english_0078', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/russian_fairy_tales_english/ru_fairytale_en_05_russian_fairy_tales_-_the_frog_princess_(english).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0079', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_01_air_conditioner_a.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0080', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_02_air_conditioner_a.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0081', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_03_air_conditioner_b.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0082', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_04_air_conditioner_b.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0083', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_05_air_fan_deep.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0084', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_06_air_fan_deep.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0085', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_07_air_fan_desk.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_en_whitenoise_0086', 'podcast', 'Public Domain / Free Distribution', 'podcasts/en/whitenoise/ia_SleepSounds_08_air_fan_desk.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0087', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_01_1_hour_beethoven_brahms_and_mozart_lullaby.m4a', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0088', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_02_1_hour_beethoven_brahms_and_mozart_lullaby.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0089', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_03_1_hour_beethoven_brahms_and_mozart_lullaby.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0090', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_04_1_hour_lullabies_for_babies_to_go_to_sleep.m4a', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0091', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_05_1_hour_lullabies_for_babies_to_go_to_sleep.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0092', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_06_1_hour_lullabies_for_babies_to_go_to_sleep.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0093', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_07_1_hour_music_instrumental_-_peaceful_lullabies_for.m4a', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0094', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_08_1_hour_music_instrumental_-_peaceful_lullabies_for.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0095', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_09_1_hour_music_instrumental_-_peaceful_lullabies_for.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_classical_0096', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/classical/ia_BestOfMozartBabySleepAndBedtimeSongs_10_1_hour_piano_music_for_babies_lullabies_-_download.m4a', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0097', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_01_bacrahms_lullaby_for_baby_-_bedtime_music_-_lullab.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0098', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_02_bacrahms_lullaby_for_baby_-_bedtime_music_-_lullab.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0099', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_03_balullabies_for_babies_-_brahms_lullaby,_bedtime_l.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0100', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_04_balullabies_for_babies_-_brahms_lullaby,_bedtime_l.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0101', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_05_bamusic_for_babies,_sleep_relax.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0102', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_06_bamusic_for_babies,_sleep_relax.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0103', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_07_bamusicbox_for_babies_5_-_sleep_-_soothing_-_relax.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0104', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_08_bamusicbox_for_babies_5_-_sleep_-_soothing_-_relax.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0105', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_09_basweet_dreams_(goodnight_song).mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0106', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_BabyGoesToSleepMutionNurturingRelaxationsicForRelaxa_10_basweet_dreams_(goodnight_song).ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0107', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_01_baby_sleep_music.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0108', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_02_baby_songs_to_go_to_sleep.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0109', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_03_bedtime_music.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0110', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_04_good_night_sweet_dreams.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0111', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_05_happy_sleep_music.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0112', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_06_relaxing_lullaby_for_kids.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0113', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_07_soft_relaxing_baby_sleep_music.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0114', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_08_songs_to_put_a_baby_to_sleep.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0115', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_09_super_relaxing_baby_sleep_music.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0116', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_baby-sleep-music_10_sweet_dreams.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0117', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_01_sleeping_baby_music1_hour_super_soothing_hush_litt.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0118', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_02_sleeping_baby_music1_hour_super_soothing_hush_litt.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0119', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_03_sleeping_baby_music2_hours_super_relaxing_baby_mus.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0120', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_04_sleeping_baby_music2_hours_super_relaxing_baby_mus.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0121', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_05_sleeping_baby_musicbaby_mozart_best_of_mozart_baby.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0122', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_06_sleeping_baby_musicbaby_mozart_best_of_mozart_baby.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0123', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_07_sleeping_baby_musicbedtime_lullaby_-_baby_sleep_mu.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0124', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_08_sleeping_baby_musicbedtime_lullaby_-_baby_sleep_mu.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0125', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_09_sleeping_baby_musiclullabies_lullaby_for_babies_to.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_multi_lullabies_0126', 'podcast', 'Public Domain / Free Distribution', 'podcasts/multi/lullabies/ia_sleepingbabymusicz_10_sleeping_baby_musiclullabies_lullaby_for_babies_to.ogg', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0157', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_01_лисичка-сестричка_и_волк.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0158', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_02_кот,_петух_и_лиса.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0159', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_03_волк_и_коза.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0160', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_04_курочка_ряба.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0161', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_05_репка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0162', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_06_теремок.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0163', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_07_колобок.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0164', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_08_маша_и_медведь.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0165', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_09_гуси-лебеди.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0166', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_10_морозко.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0167', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_11_снегурочка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0168', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_12_сестрица_алёнушка_и_братец_иванушка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0169', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_13_царевна-лягушка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0170', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_14_иван-царевич_и_серый_волк.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0171', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_15_сивка-бурка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0172', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_16_по_щучьему_веленью.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0173', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_17_финист_ясный_сокол.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0174', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_18_василиса_прекрасная.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0175', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_19_марья_моревна.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0176', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v1_20_кощей_бессмертный.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0177', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_01_баба-яга.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0178', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_02_жар-птица_и_василиса-царевна.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0179', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_03_крошечка-хаврошечка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0180', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_04_иванушка-дурачок.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0181', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_05_летучий_корабль.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0182', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_06_мальчик_с_пальчик.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0183', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_07_никита_кожемяка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0184', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_08_петушок_-_золотой_гребешок.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0185', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_09_три_медведя.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0186', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_10_заюшкина_избушка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0187', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_11_лиса_и_журавль.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0188', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_12_пузырь,_соломинка_и_лапоть.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0189', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_13_бычок_-_смоляной_бочок.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0190', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_14_волшебное_кольцо.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0191', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_15_каша_из_топора.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0192', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_16_петух_и_жерновцы.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0193', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_17_скатерть,_баранчик_и_сума.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0194', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_18_солнце,_месяц_и_ворон.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0195', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_19_хрустальная_гора.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_fairy_tales_0196', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_fairy_tales/ru_fairytale_v2_20_чудесная_рубашка.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0197', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_01_russianfairytales1_01_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0198', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_02_russianfairytales1_01_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0199', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_03_russianfairytales1_02_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0200', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_04_russianfairytales1_02_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0201', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_05_russianfairytales1_03_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0202', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_06_russianfairytales1_03_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0203', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_07_russianfairytales1_04_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0204', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_08_russianfairytales1_04_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0205', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_09_russianfairytales1_05_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0206', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_10_russianfairytales1_05_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0207', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_11_russianfairytales1_06_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0208', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_12_russianfairytales1_06_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0209', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_13_russianfairytales1_07_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0210', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_14_russianfairytales1_07_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0211', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales1_2007_librivox_15_russianfairytales1_08_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0212', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_01_russianfairytales2_01_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0213', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_02_russianfairytales2_01_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0214', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_03_russianfairytales2_02_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0215', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_04_russianfairytales2_02_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0216', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_05_russianfairytales2_03_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0217', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_06_russianfairytales2_03_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0218', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_07_russianfairytales2_04_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0219', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_08_russianfairytales2_04_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0220', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_09_russianfairytales2_05_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0221', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_10_russianfairytales2_05_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0222', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_11_russianfairytales2_06_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0223', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_12_russianfairytales2_06_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0224', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_13_russianfairytales2_07_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0225', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_14_russianfairytales2_07_afanasyev_128kb.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_ru_russian_stories_0226', 'podcast', 'Public Domain / Free Distribution', 'podcasts/ru/russian_stories/ia_russianfairytales2_2103_librivox_15_russianfairytales2_08_afanasyev.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_01.mp3_0227', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_01.mp3/fairy_tale_01.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_02.mp3_0228', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_02.mp3/fairy_tale_02.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_03.mp3_0229', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_03.mp3/fairy_tale_03.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_04.mp3_0230', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_04.mp3/fairy_tale_04.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_05.mp3_0231', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_05.mp3/fairy_tale_05.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_06.mp3_0232', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_06.mp3/fairy_tale_06.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_07.mp3_0233', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_07.mp3/fairy_tale_07.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_08.mp3_0234', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_08.mp3/fairy_tale_08.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_09.mp3_0235', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_09.mp3/fairy_tale_09.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_10.mp3_0236', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_10.mp3/fairy_tale_10.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_11.mp3_0237', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_11.mp3/fairy_tale_11.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_12.mp3_0238', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_12.mp3/fairy_tale_12.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_13.mp3_0239', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_13.mp3/fairy_tale_13.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_14.mp3_0240', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_14.mp3/fairy_tale_14.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');

INSERT INTO podcast_metadata (track_id, source, license, r2_key, local_path, uploaded_at)
VALUES ('podcast_russian_fairy_tale_15.mp3_0241', 'podcast', 'Public Domain / Free Distribution', 'podcasts/russian/fairy_tale_15.mp3/fairy_tale_15.mp3', '')
ON CONFLICT(track_id) DO UPDATE SET r2_key = excluded.r2_key, uploaded_at = datetime('now');
-- Force re-upload Wed Dec 31 15:47:30 EST 2025
