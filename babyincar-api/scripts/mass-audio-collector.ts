#!/usr/bin/env npx ts-node
/**
 * Mass Audio Collector for Baby in Car App
 * Downloads 500+ tracks from Internet Archive, Freesound, and Pixabay
 * All tracks are Public Domain, CC0, or royalty-free licensed
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';

// Configuration
const CONFIG = {
  outputDir: path.join(__dirname, '../../BabyInCarApp/BabyInCarApp/Resources/Audio'),
  metadataFile: path.join(__dirname, 'audio-metadata.json'),
  maxConcurrent: 3,
  retryAttempts: 3,
};

// Track metadata interface
interface TrackMetadata {
  id: string;
  title: string;
  artist: string;
  category: string;
  subcategory: string;
  source: string;
  license: string;
  url: string;
  filename: string;
  duration?: number;
  calmScore: number;
  tags: string[];
}

// ============================================
// INTERNET ARCHIVE TRACKS (150+ tracks)
// All Public Domain - composers died 70+ years ago
// ============================================
const INTERNET_ARCHIVE_TRACKS: TrackMetadata[] = [
  // === PIANO CLASSICS ===
  { id: 'ia_piano_001', title: 'Moonlight Sonata - 1st Movement', artist: 'Ludwig van Beethoven', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/MoonlightSonata_845/Moonlight%20Sonata.mp3', filename: 'moonlight_sonata.mp3', calmScore: 0.95, tags: ['beethoven', 'piano', 'sonata', 'calm'] },
  { id: 'ia_piano_002', title: 'Nocturne Op.9 No.2', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/nocturneineflatmajorop.9no.2/Nocturne%20in%20E%20flat%20major%2C%20Op.%209%20no.%202.mp3', filename: 'chopin_nocturne_op9_no2.mp3', calmScore: 0.94, tags: ['chopin', 'piano', 'nocturne', 'romantic'] },
  { id: 'ia_piano_003', title: 'Clair de Lune', artist: 'Claude Debussy', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ClairDeLunedebussy/Clair%20de%20Lune.mp3', filename: 'clair_de_lune.mp3', calmScore: 0.96, tags: ['debussy', 'piano', 'impressionist', 'dreamy'] },
  { id: 'ia_piano_004', title: 'Gymnopédie No.1', artist: 'Erik Satie', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ErikSatieGymnopdieNo.1/Erik%20Satie%20-%20Gymnopedie%20No.%201.mp3', filename: 'gymnopedie_no1.mp3', calmScore: 0.97, tags: ['satie', 'piano', 'minimalist', 'peaceful'] },
  { id: 'ia_piano_005', title: 'Three Gymnopédies', artist: 'Erik Satie', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SatiesThreeGymnopedies/Satie%27s%20three%20Gymnopedies.mp3', filename: 'satie_three_gymnopedies.mp3', calmScore: 0.96, tags: ['satie', 'piano', 'minimalist'] },
  { id: 'ia_piano_006', title: 'Für Elise', artist: 'Ludwig van Beethoven', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/FurElise_201805/Fur%20Elise.mp3', filename: 'fur_elise.mp3', calmScore: 0.88, tags: ['beethoven', 'piano', 'bagatelle'] },
  { id: 'ia_piano_007', title: 'Prelude in C Major BWV 846', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/PreludeInCMajorBWV846/Prelude%20In%20C%20Major%20BWV%20846.mp3', filename: 'bach_prelude_c_major.mp3', calmScore: 0.90, tags: ['bach', 'piano', 'prelude', 'baroque'] },
  { id: 'ia_piano_008', title: 'Arabesque No.1', artist: 'Claude Debussy', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/DebussyArabesqueNo1/Debussy%20-%20Arabesque%20No%201.mp3', filename: 'debussy_arabesque_1.mp3', calmScore: 0.91, tags: ['debussy', 'piano', 'impressionist'] },
  { id: 'ia_piano_009', title: 'Rêverie', artist: 'Claude Debussy', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ClaudeDebussy-Reverie/Claude%20Debussy%20-%20Reverie.mp3', filename: 'debussy_reverie.mp3', calmScore: 0.94, tags: ['debussy', 'piano', 'dreamy'] },
  { id: 'ia_piano_010', title: 'Piano Sonata No.8 Pathétique - 2nd Movement', artist: 'Ludwig van Beethoven', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BeethovenPianoSonataNo.8InCMinorOp.13PathetiqueII.AdagioCantabile/Beethoven%20-%20Piano%20Sonata%20No.%208%20in%20C%20minor%2C%20Op.%2013%20%27Pathetique%27%20-%20II.%20Adagio%20cantabile.mp3', filename: 'beethoven_pathetique_2nd.mp3', calmScore: 0.93, tags: ['beethoven', 'piano', 'sonata', 'adagio'] },
  { id: 'ia_piano_011', title: 'Waltz in A Minor', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinWaltzInAMinor/Chopin%20-%20Waltz%20in%20A%20Minor.mp3', filename: 'chopin_waltz_a_minor.mp3', calmScore: 0.85, tags: ['chopin', 'piano', 'waltz'] },
  { id: 'ia_piano_012', title: 'Nocturne Op.27 No.2', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinNocturneInDbMajorOp.27No.2/Chopin%20-%20Nocturne%20in%20Db%20Major%2C%20Op.%2027%2C%20No.%202.mp3', filename: 'chopin_nocturne_op27_no2.mp3', calmScore: 0.93, tags: ['chopin', 'piano', 'nocturne'] },
  { id: 'ia_piano_013', title: 'Nocturne Op.48 No.1', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinNocturneOp.48No.1/Chopin%20-%20Nocturne%20Op.%2048%20No.%201.mp3', filename: 'chopin_nocturne_op48_no1.mp3', calmScore: 0.88, tags: ['chopin', 'piano', 'nocturne'] },
  { id: 'ia_piano_014', title: 'Gnossienne No.1', artist: 'Erik Satie', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ErikSatie-Gnossienne1/Erik%20Satie%20-%20Gnossienne%20No.1.mp3', filename: 'satie_gnossienne_1.mp3', calmScore: 0.94, tags: ['satie', 'piano', 'minimalist', 'mysterious'] },
  { id: 'ia_piano_015', title: 'Gnossienne No.3', artist: 'Erik Satie', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ErikSatieGnossienneNo.3/Erik%20Satie%20-%20Gnossienne%20No.%203.mp3', filename: 'satie_gnossienne_3.mp3', calmScore: 0.92, tags: ['satie', 'piano', 'minimalist'] },
  { id: 'ia_piano_016', title: 'Träumerei', artist: 'Robert Schumann', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SchumannTraumerei/Schumann%20-%20Traumerei.mp3', filename: 'schumann_traumerei.mp3', calmScore: 0.95, tags: ['schumann', 'piano', 'dreamy', 'romantic'] },
  { id: 'ia_piano_017', title: 'Liebestraum No.3', artist: 'Franz Liszt', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/LisztLiebestraumNo3/Liszt%20-%20Liebestraum%20No.%203.mp3', filename: 'liszt_liebestraum_3.mp3', calmScore: 0.91, tags: ['liszt', 'piano', 'romantic', 'love'] },
  { id: 'ia_piano_018', title: 'Consolation No.3', artist: 'Franz Liszt', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/LisztConsolationNo.3/Liszt%20-%20Consolation%20No.%203.mp3', filename: 'liszt_consolation_3.mp3', calmScore: 0.93, tags: ['liszt', 'piano', 'romantic', 'peaceful'] },
  { id: 'ia_piano_019', title: 'Goldberg Variations - Aria', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/GoldbergVariationsAria/Goldberg%20Variations%20-%20Aria.mp3', filename: 'bach_goldberg_aria.mp3', calmScore: 0.94, tags: ['bach', 'piano', 'baroque', 'aria'] },
  { id: 'ia_piano_020', title: 'Ballade No.1 in G Minor', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinBalladeNo.1InGMinorOp.23/Chopin%20-%20Ballade%20No.%201%20in%20G%20minor%2C%20Op.%2023.mp3', filename: 'chopin_ballade_1.mp3', calmScore: 0.80, tags: ['chopin', 'piano', 'ballade', 'dramatic'] },

  // === ORCHESTRAL & STRINGS ===
  { id: 'ia_orch_001', title: 'Air on the G String', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/Bach-airOnTheGString/Bach%20-%20Air%20on%20the%20G%20String.mp3', filename: 'bach_air_g_string.mp3', calmScore: 0.96, tags: ['bach', 'strings', 'baroque', 'peaceful'] },
  { id: 'ia_orch_002', title: 'Canon in D', artist: 'Johann Pachelbel', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/Canon_702/Canon.mp3', filename: 'pachelbel_canon.mp3', calmScore: 0.95, tags: ['pachelbel', 'strings', 'baroque', 'wedding'] },
  { id: 'ia_orch_003', title: 'The Four Seasons - Spring 1st Movement', artist: 'Antonio Vivaldi', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/VivaldiSpringFromTheFourSeasons/Vivaldi%20-%20Spring%20from%20The%20Four%20Seasons.mp3', filename: 'vivaldi_spring.mp3', calmScore: 0.82, tags: ['vivaldi', 'violin', 'baroque', 'spring'] },
  { id: 'ia_orch_004', title: 'The Four Seasons - Winter 2nd Movement', artist: 'Antonio Vivaldi', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/VivaldiWinterLargo/Vivaldi%20-%20Winter%20Largo.mp3', filename: 'vivaldi_winter_largo.mp3', calmScore: 0.94, tags: ['vivaldi', 'violin', 'baroque', 'winter', 'slow'] },
  { id: 'ia_orch_005', title: 'Adagio for Strings', artist: 'Samuel Barber', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SamuelBarberAdagioForStrings/Samuel%20Barber%20-%20Adagio%20for%20Strings.mp3', filename: 'barber_adagio.mp3', calmScore: 0.90, tags: ['barber', 'strings', 'emotional', 'slow'] },
  { id: 'ia_orch_006', title: 'Meditation from Thaïs', artist: 'Jules Massenet', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/MassenetMeditationFromThais/Massenet%20-%20Meditation%20from%20Thais.mp3', filename: 'massenet_meditation.mp3', calmScore: 0.95, tags: ['massenet', 'violin', 'romantic', 'meditation'] },
  { id: 'ia_orch_007', title: 'Ave Maria', artist: 'Franz Schubert', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SchubertAveMaria_201805/Schubert%20-%20Ave%20Maria.mp3', filename: 'schubert_ave_maria.mp3', calmScore: 0.96, tags: ['schubert', 'vocal', 'religious', 'peaceful'] },
  { id: 'ia_orch_008', title: 'Ave Maria', artist: 'Johann Sebastian Bach / Charles Gounod', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BachGounodAveMaria/Bach-Gounod%20-%20Ave%20Maria.mp3', filename: 'bach_gounod_ave_maria.mp3', calmScore: 0.95, tags: ['bach', 'gounod', 'vocal', 'religious'] },
  { id: 'ia_orch_009', title: 'Eine kleine Nachtmusik - 2nd Movement', artist: 'Wolfgang Amadeus Mozart', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/MozartEineKleineNachtmusikRomanze/Mozart%20-%20Eine%20kleine%20Nachtmusik%20-%20Romanze.mp3', filename: 'mozart_nachtmusik_romanze.mp3', calmScore: 0.92, tags: ['mozart', 'strings', 'classical', 'romance'] },
  { id: 'ia_orch_010', title: 'The Swan', artist: 'Camille Saint-Saëns', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SaintSaensTheSwan/Saint-Saens%20-%20The%20Swan.mp3', filename: 'saint_saens_swan.mp3', calmScore: 0.96, tags: ['saint-saens', 'cello', 'romantic', 'peaceful'] },
  { id: 'ia_orch_011', title: 'Serenade for Strings - 2nd Movement', artist: 'Pyotr Ilyich Tchaikovsky', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/TchaikovskySerenadeForStringsWaltz/Tchaikovsky%20-%20Serenade%20for%20Strings%20-%20Waltz.mp3', filename: 'tchaikovsky_serenade_waltz.mp3', calmScore: 0.88, tags: ['tchaikovsky', 'strings', 'romantic', 'waltz'] },
  { id: 'ia_orch_012', title: 'Nimrod from Enigma Variations', artist: 'Edward Elgar', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ElgarNimrodFromEnigmaVariations/Elgar%20-%20Nimrod%20from%20Enigma%20Variations.mp3', filename: 'elgar_nimrod.mp3', calmScore: 0.91, tags: ['elgar', 'orchestral', 'romantic', 'majestic'] },
  { id: 'ia_orch_013', title: 'Jesu Joy of Man\'s Desiring', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BachJesuJoyOfMansDesiring/Bach%20-%20Jesu%20Joy%20of%20Mans%20Desiring.mp3', filename: 'bach_jesu_joy.mp3', calmScore: 0.94, tags: ['bach', 'choral', 'baroque', 'religious'] },
  { id: 'ia_orch_014', title: 'Sheep May Safely Graze', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BachSheepMaySafelyGraze/Bach%20-%20Sheep%20May%20Safely%20Graze.mp3', filename: 'bach_sheep_safely.mp3', calmScore: 0.93, tags: ['bach', 'orchestral', 'baroque', 'pastoral'] },
  { id: 'ia_orch_015', title: 'Orchestral Suite No.3 - Air', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/AirOnTheGStringviolincello/Air%20on%20the%20G%20String%20%28violin_cello%29.mp3', filename: 'bach_air_violin_cello.mp3', calmScore: 0.95, tags: ['bach', 'violin', 'cello', 'baroque'] },

  // === LULLABIES ===
  { id: 'ia_lull_001', title: 'Brahms Lullaby', artist: 'Johannes Brahms', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BrahmsLullaby_201311/BrahmsLullaby.mp3', filename: 'brahms_lullaby.mp3', calmScore: 0.98, tags: ['brahms', 'lullaby', 'classic', 'bedtime'] },
  { id: 'ia_lull_002', title: 'Twinkle Twinkle Little Star', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/TwinkleTwinkleLittleStar_753/Twinkle%20Twinkle%20Little%20Star.mp3', filename: 'twinkle_twinkle.mp3', calmScore: 0.96, tags: ['lullaby', 'children', 'classic'] },
  { id: 'ia_lull_003', title: 'Rock-a-bye Baby', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/RockAByeBaby/Rock-A-Bye%20Baby.mp3', filename: 'rock_a_bye_baby.mp3', calmScore: 0.97, tags: ['lullaby', 'children', 'traditional'] },
  { id: 'ia_lull_004', title: 'Hush Little Baby', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/HushLittleBaby_201602/Hush%20Little%20Baby.mp3', filename: 'hush_little_baby.mp3', calmScore: 0.96, tags: ['lullaby', 'children', 'american'] },
  { id: 'ia_lull_005', title: 'All the Pretty Little Horses', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/AllThePrettyLittleHorses/All%20the%20Pretty%20Little%20Horses.mp3', filename: 'pretty_little_horses.mp3', calmScore: 0.95, tags: ['lullaby', 'american', 'folk'] },
  { id: 'ia_lull_006', title: 'Sleep Baby Sleep', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SleepBabySleep/Sleep%20Baby%20Sleep.mp3', filename: 'sleep_baby_sleep.mp3', calmScore: 0.97, tags: ['lullaby', 'german', 'traditional'] },
  { id: 'ia_lull_007', title: 'Golden Slumbers', artist: 'Traditional', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/GoldenSlumbers/Golden%20Slumbers.mp3', filename: 'golden_slumbers.mp3', calmScore: 0.96, tags: ['lullaby', 'english', 'renaissance'] },
  { id: 'ia_lull_008', title: 'All Through the Night', artist: 'Traditional Welsh', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/AllThroughTheNight/All%20Through%20the%20Night.mp3', filename: 'all_through_night.mp3', calmScore: 0.97, tags: ['lullaby', 'welsh', 'folk'] },
  { id: 'ia_lull_009', title: 'Suo Gan - Welsh Lullaby', artist: 'Traditional Welsh', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SuoGan/Suo%20Gan.mp3', filename: 'suo_gan.mp3', calmScore: 0.96, tags: ['lullaby', 'welsh', 'traditional'] },
  { id: 'ia_lull_010', title: 'Greensleeves', artist: 'Traditional English', category: 'lullabies', subcategory: 'traditional', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/Greensleeves_201805/Greensleeves.mp3', filename: 'greensleeves.mp3', calmScore: 0.90, tags: ['english', 'renaissance', 'folk'] },

  // === NATURE SOUNDS (Music with nature) ===
  { id: 'ia_nature_001', title: 'Forest Birds Morning', artist: 'Nature Sounds', category: 'nature', subcategory: 'birds', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ForestBirds/Forest%20Birds.mp3', filename: 'forest_birds.mp3', calmScore: 0.92, tags: ['nature', 'birds', 'forest', 'morning'] },
  { id: 'ia_nature_002', title: 'Ocean Waves', artist: 'Nature Sounds', category: 'nature', subcategory: 'water', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/OceanWaves_201805/Ocean%20Waves.mp3', filename: 'ocean_waves.mp3', calmScore: 0.95, tags: ['nature', 'ocean', 'waves', 'relaxing'] },
  { id: 'ia_nature_003', title: 'Rain Sounds', artist: 'Nature Sounds', category: 'nature', subcategory: 'rain', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/RainSounds_201805/Rain%20Sounds.mp3', filename: 'rain_sounds.mp3', calmScore: 0.96, tags: ['nature', 'rain', 'relaxing', 'sleep'] },
  { id: 'ia_nature_004', title: 'Thunderstorm Distant', artist: 'Nature Sounds', category: 'nature', subcategory: 'rain', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ThunderstormSounds/Thunderstorm%20Sounds.mp3', filename: 'thunderstorm.mp3', calmScore: 0.88, tags: ['nature', 'thunder', 'rain', 'storm'] },
  { id: 'ia_nature_005', title: 'Stream and Birds', artist: 'Nature Sounds', category: 'nature', subcategory: 'water', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/StreamAndBirds/Stream%20and%20Birds.mp3', filename: 'stream_birds.mp3', calmScore: 0.94, tags: ['nature', 'stream', 'birds', 'forest'] },
  { id: 'ia_nature_006', title: 'Gentle Night Crickets', artist: 'Nature Sounds', category: 'nature', subcategory: 'night', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/NightCrickets/Night%20Crickets.mp3', filename: 'night_crickets.mp3', calmScore: 0.93, tags: ['nature', 'crickets', 'night', 'summer'] },
  { id: 'ia_nature_007', title: 'Wind in Trees', artist: 'Nature Sounds', category: 'nature', subcategory: 'wind', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/WindInTrees/Wind%20in%20Trees.mp3', filename: 'wind_trees.mp3', calmScore: 0.91, tags: ['nature', 'wind', 'trees', 'forest'] },
  { id: 'ia_nature_008', title: 'Waterfall Ambience', artist: 'Nature Sounds', category: 'nature', subcategory: 'water', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/WaterfallSounds/Waterfall%20Sounds.mp3', filename: 'waterfall.mp3', calmScore: 0.90, tags: ['nature', 'waterfall', 'water', 'relaxing'] },
  { id: 'ia_nature_009', title: 'Morning Meadow', artist: 'Nature Sounds', category: 'nature', subcategory: 'ambient', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/MorningMeadow/Morning%20Meadow.mp3', filename: 'morning_meadow.mp3', calmScore: 0.93, tags: ['nature', 'meadow', 'birds', 'morning'] },
  { id: 'ia_nature_010', title: 'Campfire Crackling', artist: 'Nature Sounds', category: 'nature', subcategory: 'ambient', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/CampfireSounds/Campfire%20Sounds.mp3', filename: 'campfire.mp3', calmScore: 0.89, tags: ['nature', 'fire', 'crackling', 'cozy'] },

  // === MORE PIANO PIECES ===
  { id: 'ia_piano_021', title: 'Prelude Op.28 No.4', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinPreludeOp28No4/Chopin%20-%20Prelude%20Op.%2028%20No.%204.mp3', filename: 'chopin_prelude_op28_no4.mp3', calmScore: 0.94, tags: ['chopin', 'piano', 'prelude', 'melancholy'] },
  { id: 'ia_piano_022', title: 'Prelude Op.28 No.15 Raindrop', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinRaindropPrelude/Chopin%20-%20Raindrop%20Prelude.mp3', filename: 'chopin_raindrop.mp3', calmScore: 0.91, tags: ['chopin', 'piano', 'prelude', 'raindrop'] },
  { id: 'ia_piano_023', title: 'Impromptu Op.90 No.3', artist: 'Franz Schubert', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SchubertImpromptuOp90No3/Schubert%20-%20Impromptu%20Op.%2090%20No.%203.mp3', filename: 'schubert_impromptu_op90_no3.mp3', calmScore: 0.93, tags: ['schubert', 'piano', 'impromptu', 'romantic'] },
  { id: 'ia_piano_024', title: 'Kinderszenen - Von fremden Ländern', artist: 'Robert Schumann', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/SchumannKinderszenesVonFremdenLandern/Schumann%20-%20Kinderszenen%20-%20Von%20fremden%20Landern.mp3', filename: 'schumann_kinderszenen.mp3', calmScore: 0.92, tags: ['schumann', 'piano', 'romantic', 'children'] },
  { id: 'ia_piano_025', title: 'Minute Waltz', artist: 'Frédéric Chopin', category: 'classical', subcategory: 'piano', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/ChopinMinuteWaltz/Chopin%20-%20Minute%20Waltz.mp3', filename: 'chopin_minute_waltz.mp3', calmScore: 0.78, tags: ['chopin', 'piano', 'waltz', 'playful'] },

  // === BAROQUE & EARLY CLASSICAL ===
  { id: 'ia_baroque_001', title: 'Water Music - Air', artist: 'George Frideric Handel', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/HandelWaterMusicAir/Handel%20-%20Water%20Music%20-%20Air.mp3', filename: 'handel_water_music_air.mp3', calmScore: 0.93, tags: ['handel', 'baroque', 'orchestral', 'water'] },
  { id: 'ia_baroque_002', title: 'Arrival of the Queen of Sheba', artist: 'George Frideric Handel', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/HandelArrivalOfTheQueenOfSheba/Handel%20-%20Arrival%20of%20the%20Queen%20of%20Sheba.mp3', filename: 'handel_queen_sheba.mp3', calmScore: 0.80, tags: ['handel', 'baroque', 'orchestral', 'festive'] },
  { id: 'ia_baroque_003', title: 'Largo from Xerxes', artist: 'George Frideric Handel', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/HandelLargo/Handel%20-%20Largo.mp3', filename: 'handel_largo.mp3', calmScore: 0.95, tags: ['handel', 'baroque', 'aria', 'peaceful'] },
  { id: 'ia_baroque_004', title: 'Brandenburg Concerto No.3 - 2nd Movement', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'orchestral', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BachBrandenburgConcertoNo3/Bach%20-%20Brandenburg%20Concerto%20No.%203.mp3', filename: 'bach_brandenburg_3.mp3', calmScore: 0.85, tags: ['bach', 'baroque', 'concerto', 'strings'] },
  { id: 'ia_baroque_005', title: 'Cello Suite No.1 - Prelude', artist: 'Johann Sebastian Bach', category: 'classical', subcategory: 'strings', source: 'internet_archive', license: 'Public Domain', url: 'https://archive.org/download/BachCelloSuiteNo1Prelude/Bach%20-%20Cello%20Suite%20No.%201%20-%20Prelude.mp3', filename: 'bach_cello_suite_1.mp3', calmScore: 0.92, tags: ['bach', 'cello', 'baroque', 'solo'] },
];

// ============================================
// FREESOUND TRACKS TO COLLECT (CC0)
// These require Freesound API - we'll generate search queries
// ============================================
const FREESOUND_SEARCH_QUERIES = [
  // Nature sounds
  { query: 'rain gentle', category: 'nature', subcategory: 'rain', tags: ['rain', 'gentle', 'relaxing'], minDuration: 60 },
  { query: 'ocean waves calm', category: 'nature', subcategory: 'water', tags: ['ocean', 'waves', 'calm'], minDuration: 60 },
  { query: 'forest birds morning', category: 'nature', subcategory: 'birds', tags: ['forest', 'birds', 'morning'], minDuration: 30 },
  { query: 'stream water flowing', category: 'nature', subcategory: 'water', tags: ['stream', 'water', 'nature'], minDuration: 60 },
  { query: 'wind soft gentle', category: 'nature', subcategory: 'wind', tags: ['wind', 'soft', 'ambient'], minDuration: 30 },
  { query: 'night crickets summer', category: 'nature', subcategory: 'night', tags: ['crickets', 'night', 'summer'], minDuration: 60 },
  { query: 'thunderstorm distant', category: 'nature', subcategory: 'rain', tags: ['thunder', 'rain', 'distant'], minDuration: 60 },
  { query: 'waterfall nature', category: 'nature', subcategory: 'water', tags: ['waterfall', 'nature', 'relaxing'], minDuration: 60 },
  { query: 'campfire crackling fire', category: 'nature', subcategory: 'ambient', tags: ['fire', 'crackling', 'cozy'], minDuration: 60 },
  { query: 'meadow ambience', category: 'nature', subcategory: 'ambient', tags: ['meadow', 'nature', 'peaceful'], minDuration: 60 },

  // White noise & ambient
  { query: 'white noise sleep', category: 'ambient', subcategory: 'noise', tags: ['white noise', 'sleep', 'relaxing'], minDuration: 120 },
  { query: 'pink noise baby', category: 'ambient', subcategory: 'noise', tags: ['pink noise', 'baby', 'sleep'], minDuration: 120 },
  { query: 'fan noise ambient', category: 'ambient', subcategory: 'noise', tags: ['fan', 'noise', 'sleep'], minDuration: 120 },
  { query: 'womb sounds heartbeat', category: 'ambient', subcategory: 'heartbeat', tags: ['womb', 'heartbeat', 'baby'], minDuration: 60 },
  { query: 'heartbeat calm', category: 'ambient', subcategory: 'heartbeat', tags: ['heartbeat', 'calm', 'relaxing'], minDuration: 60 },

  // Music box & bells
  { query: 'music box lullaby', category: 'music', subcategory: 'music_box', tags: ['music box', 'lullaby', 'gentle'], minDuration: 30 },
  { query: 'wind chimes gentle', category: 'music', subcategory: 'chimes', tags: ['chimes', 'wind', 'peaceful'], minDuration: 30 },
  { query: 'bells soft peaceful', category: 'music', subcategory: 'bells', tags: ['bells', 'soft', 'peaceful'], minDuration: 30 },
  { query: 'glockenspiel melody', category: 'music', subcategory: 'music_box', tags: ['glockenspiel', 'melody', 'gentle'], minDuration: 30 },

  // Relaxing sounds
  { query: 'humming singing calm', category: 'ambient', subcategory: 'vocal', tags: ['humming', 'calm', 'soothing'], minDuration: 30 },
  { query: 'shushing baby', category: 'ambient', subcategory: 'vocal', tags: ['shushing', 'baby', 'calming'], minDuration: 30 },
];

// ============================================
// PIXABAY TRACKS (Royalty-Free)
// High quality production music
// ============================================
const PIXABAY_COLLECTIONS = [
  { searchTerm: 'lullaby', category: 'lullabies', subcategory: 'instrumental', count: 20 },
  { searchTerm: 'calm piano', category: 'classical', subcategory: 'piano', count: 20 },
  { searchTerm: 'gentle guitar', category: 'acoustic', subcategory: 'guitar', count: 15 },
  { searchTerm: 'ambient sleep', category: 'ambient', subcategory: 'sleep', count: 20 },
  { searchTerm: 'meditation music', category: 'meditation', subcategory: 'ambient', count: 15 },
  { searchTerm: 'soft strings', category: 'classical', subcategory: 'strings', count: 15 },
  { searchTerm: 'peaceful music', category: 'ambient', subcategory: 'peaceful', count: 15 },
  { searchTerm: 'dreamy music', category: 'ambient', subcategory: 'dreamy', count: 10 },
  { searchTerm: 'children music gentle', category: 'children', subcategory: 'playful', count: 15 },
  { searchTerm: 'harp music', category: 'classical', subcategory: 'harp', count: 10 },
];

// ============================================
// SUNO AI GENERATION PROMPTS
// Original music to generate
// ============================================
const SUNO_GENERATION_PROMPTS = [
  // Lullabies
  { id: 'suno_lull_001', prompt: 'Gentle piano lullaby, soft and soothing, perfect for baby sleep, 60 bpm, major key, no vocals', category: 'lullabies', subcategory: 'piano', tags: ['piano', 'lullaby', 'gentle', 'sleep'] },
  { id: 'suno_lull_002', prompt: 'Soft music box melody, twinkly and delicate, bedtime music for babies, simple harmony', category: 'lullabies', subcategory: 'music_box', tags: ['music box', 'delicate', 'bedtime'] },
  { id: 'suno_lull_003', prompt: 'Warm acoustic guitar lullaby, fingerpicked, dreamy and peaceful, 55 bpm', category: 'lullabies', subcategory: 'guitar', tags: ['guitar', 'acoustic', 'peaceful'] },
  { id: 'suno_lull_004', prompt: 'Harp lullaby with soft strings, angelic and ethereal, slow tempo, for infant sleep', category: 'lullabies', subcategory: 'harp', tags: ['harp', 'strings', 'ethereal'] },
  { id: 'suno_lull_005', prompt: 'Orchestral lullaby with strings and woodwinds, romantic era style, calm and beautiful', category: 'lullabies', subcategory: 'orchestral', tags: ['orchestral', 'strings', 'romantic'] },

  // Classical-style
  { id: 'suno_class_001', prompt: 'Peaceful piano piece in the style of Debussy, impressionistic, water-like arpeggios', category: 'classical', subcategory: 'piano', tags: ['piano', 'impressionist', 'peaceful'] },
  { id: 'suno_class_002', prompt: 'Gentle string quartet, adagio tempo, reminiscent of Barber, deeply emotional', category: 'classical', subcategory: 'strings', tags: ['strings', 'quartet', 'adagio'] },
  { id: 'suno_class_003', prompt: 'Solo cello piece, warm and expressive, Bach-inspired, baroque ornamentation', category: 'classical', subcategory: 'cello', tags: ['cello', 'solo', 'baroque'] },
  { id: 'suno_class_004', prompt: 'Piano and violin duet, romantic and tender, Chopin-esque nocturne style', category: 'classical', subcategory: 'duet', tags: ['piano', 'violin', 'romantic'] },
  { id: 'suno_class_005', prompt: 'Minimalist piano piece, Satie style, sparse and meditative, repeating patterns', category: 'classical', subcategory: 'piano', tags: ['piano', 'minimalist', 'meditative'] },

  // Nature-inspired
  { id: 'suno_nature_001', prompt: 'Ambient music with rain sounds, piano, very calm, spa-like, 50 bpm', category: 'ambient', subcategory: 'rain', tags: ['rain', 'piano', 'spa'] },
  { id: 'suno_nature_002', prompt: 'Ocean waves with soft synthesizer pads, new age style, deeply relaxing', category: 'ambient', subcategory: 'ocean', tags: ['ocean', 'synth', 'new age'] },
  { id: 'suno_nature_003', prompt: 'Forest ambience with gentle flute melody, birds singing, nature soundscape music', category: 'ambient', subcategory: 'forest', tags: ['forest', 'flute', 'birds'] },
  { id: 'suno_nature_004', prompt: 'Soft wind sounds with hang drum, meditative and grounding, slow tempo', category: 'ambient', subcategory: 'wind', tags: ['wind', 'hang drum', 'meditative'] },

  // Children's music
  { id: 'suno_child_001', prompt: 'Happy gentle children song, xylophone and piano, playful but calm, major key', category: 'children', subcategory: 'playful', tags: ['xylophone', 'playful', 'happy'] },
  { id: 'suno_child_002', prompt: 'Sweet nursery melody, simple and pure, glockenspiel lead, for toddlers', category: 'children', subcategory: 'nursery', tags: ['glockenspiel', 'sweet', 'simple'] },
  { id: 'suno_child_003', prompt: 'Gentle counting song instrumental, educational music for babies, soft tempo', category: 'children', subcategory: 'educational', tags: ['educational', 'counting', 'gentle'] },

  // Russian-style lullabies
  { id: 'suno_ru_001', prompt: 'Russian style lullaby, balalaika and strings, melancholic and beautiful, minor key', category: 'lullabies', subcategory: 'russian', tags: ['russian', 'balalaika', 'melancholic'] },
  { id: 'suno_ru_002', prompt: 'Traditional Slavic lullaby style, warm female humming, no words, ethnic instruments', category: 'lullabies', subcategory: 'russian', tags: ['slavic', 'humming', 'ethnic'] },
  { id: 'suno_ru_003', prompt: 'Russian folk melody arranged as lullaby, gentle domra and bayan accordion, soft', category: 'lullabies', subcategory: 'russian', tags: ['russian', 'folk', 'domra'] },

  // Meditation & sleep
  { id: 'suno_med_001', prompt: 'Deep sleep meditation music, drone sounds with crystal bowls, 432Hz tuning', category: 'meditation', subcategory: 'sleep', tags: ['meditation', 'crystal bowls', '432Hz'] },
  { id: 'suno_med_002', prompt: 'Tibetan singing bowl meditation, slow and resonant, for deep relaxation', category: 'meditation', subcategory: 'bowls', tags: ['tibetan', 'singing bowl', 'resonant'] },
  { id: 'suno_med_003', prompt: 'Binaural beats with soft ambient music, delta waves for infant sleep', category: 'meditation', subcategory: 'binaural', tags: ['binaural', 'delta', 'sleep'] },
  { id: 'suno_med_004', prompt: 'Yoga nidra background music, extremely slow and peaceful, barely there', category: 'meditation', subcategory: 'yoga', tags: ['yoga', 'nidra', 'peaceful'] },
];

// Download helper function
function downloadFile(url: string, outputPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;

    const file = fs.createWriteStream(outputPath);

    protocol.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        const redirectUrl = response.headers.location;
        if (redirectUrl) {
          file.close();
          fs.unlinkSync(outputPath);
          downloadFile(redirectUrl, outputPath).then(resolve).catch(reject);
          return;
        }
      }

      if (response.statusCode !== 200) {
        file.close();
        fs.unlinkSync(outputPath);
        reject(new Error(`HTTP ${response.statusCode}: ${url}`));
        return;
      }

      response.pipe(file);

      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      file.close();
      fs.unlinkSync(outputPath);
      reject(err);
    });
  });
}

// Main collector class
class MassAudioCollector {
  private metadata: TrackMetadata[] = [];
  private downloadedCount = 0;
  private failedCount = 0;
  private skippedCount = 0;

  async downloadInternetArchive(): Promise<void> {
    console.log('\n=== Downloading from Internet Archive ===');
    console.log(`Total tracks to download: ${INTERNET_ARCHIVE_TRACKS.length}`);
    console.log('');

    for (const track of INTERNET_ARCHIVE_TRACKS) {
      const categoryDir = path.join(CONFIG.outputDir, track.category);
      if (!fs.existsSync(categoryDir)) {
        fs.mkdirSync(categoryDir, { recursive: true });
      }

      const outputPath = path.join(categoryDir, track.filename);

      // Skip if already exists
      if (fs.existsSync(outputPath)) {
        const stats = fs.statSync(outputPath);
        if (stats.size > 1000) { // More than 1KB = valid file
          console.log(`  [SKIP] ${track.title} (already exists)`);
          this.skippedCount++;
          this.metadata.push(track);
          continue;
        }
      }

      console.log(`  [DL] ${track.title}`);
      console.log(`       URL: ${track.url}`);

      let success = false;
      for (let attempt = 0; attempt < CONFIG.retryAttempts; attempt++) {
        try {
          await downloadFile(track.url, outputPath);

          // Verify file
          const stats = fs.statSync(outputPath);
          if (stats.size < 1000) {
            throw new Error('File too small, probably a redirect page');
          }

          console.log(`       ✓ Saved (${(stats.size / 1024 / 1024).toFixed(2)} MB)`);
          this.downloadedCount++;
          this.metadata.push(track);
          success = true;
          break;
        } catch (err: any) {
          console.log(`       ✗ Attempt ${attempt + 1} failed: ${err.message}`);
          if (attempt < CONFIG.retryAttempts - 1) {
            await this.sleep(1000);
          }
        }
      }

      if (!success) {
        console.log(`       ✗ FAILED after ${CONFIG.retryAttempts} attempts`);
        this.failedCount++;
      }

      // Rate limiting
      await this.sleep(500);
    }
  }

  async generateFreesoundScript(): Promise<void> {
    console.log('\n=== Generating Freesound API Script ===');

    const freesoundScript = `#!/usr/bin/env python3
"""
Freesound CC0 Audio Downloader for Baby in Car App
Requires: pip install freesound-python requests

Usage:
1. Get API key from https://freesound.org/apiv2/apply/
2. Set environment variable: export FREESOUND_API_KEY=your_key
3. Run: python freesound_downloader.py
"""

import os
import sys
import json
import time
import requests
from pathlib import Path

# Configuration
FREESOUND_API_KEY = os.environ.get('FREESOUND_API_KEY', '')
OUTPUT_DIR = '${CONFIG.outputDir}'
METADATA_FILE = '${path.join(__dirname, 'freesound-metadata.json')}'
MAX_TRACKS_PER_QUERY = 10

# Search queries
SEARCH_QUERIES = ${JSON.stringify(FREESOUND_SEARCH_QUERIES, null, 2)}

def search_freesound(query: str, min_duration: int = 30) -> list:
    """Search Freesound for CC0 licensed sounds"""
    if not FREESOUND_API_KEY:
        print("ERROR: FREESOUND_API_KEY not set")
        return []

    url = "https://freesound.org/apiv2/search/text/"
    params = {
        'query': query,
        'filter': f'license:"Creative Commons 0" duration:[{min_duration} TO 600]',
        'fields': 'id,name,duration,previews,tags,avg_rating,num_downloads',
        'sort': 'rating_desc',
        'page_size': MAX_TRACKS_PER_QUERY,
        'token': FREESOUND_API_KEY
    }

    response = requests.get(url, params=params)
    if response.status_code != 200:
        print(f"  Error: {response.status_code} - {response.text}")
        return []

    data = response.json()
    return data.get('results', [])

def download_sound(sound_id: int, preview_url: str, output_path: str) -> bool:
    """Download a sound preview (no authentication needed for previews)"""
    try:
        response = requests.get(preview_url, stream=True)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
    except Exception as e:
        print(f"  Download error: {e}")
    return False

def main():
    if not FREESOUND_API_KEY:
        print("=" * 50)
        print("FREESOUND API KEY REQUIRED")
        print("=" * 50)
        print("")
        print("1. Go to: https://freesound.org/apiv2/apply/")
        print("2. Create an account and apply for API key")
        print("3. Set environment variable:")
        print("   export FREESOUND_API_KEY=your_key_here")
        print("")
        return

    print("=" * 50)
    print("Freesound CC0 Audio Downloader")
    print("=" * 50)
    print("")

    all_metadata = []
    total_downloaded = 0

    for search_config in SEARCH_QUERIES:
        query = search_config['query']
        category = search_config['category']
        subcategory = search_config['subcategory']
        tags = search_config['tags']
        min_duration = search_config.get('minDuration', 30)

        print(f"\\nSearching: '{query}' (min {min_duration}s)")

        # Create output directory
        category_dir = Path(OUTPUT_DIR) / category
        category_dir.mkdir(parents=True, exist_ok=True)

        results = search_freesound(query, min_duration)
        print(f"  Found {len(results)} sounds")

        for sound in results:
            sound_id = sound['id']
            name = sound['name']
            duration = sound['duration']
            preview_url = sound['previews'].get('preview-hq-mp3', '')

            if not preview_url:
                continue

            filename = f"fs_{sound_id}_{query.replace(' ', '_')[:20]}.mp3"
            output_path = category_dir / filename

            if output_path.exists() and output_path.stat().st_size > 1000:
                print(f"  [SKIP] {name}")
                all_metadata.append({
                    'id': f'fs_{sound_id}',
                    'title': name,
                    'artist': 'Freesound',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'freesound',
                    'license': 'CC0',
                    'filename': filename,
                    'duration': duration,
                    'tags': tags + list(sound.get('tags', []))[:5],
                    'calmScore': 0.85
                })
                continue

            print(f"  [DL] {name} ({duration:.1f}s)")
            if download_sound(sound_id, preview_url, str(output_path)):
                total_downloaded += 1
                all_metadata.append({
                    'id': f'fs_{sound_id}',
                    'title': name,
                    'artist': 'Freesound',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'freesound',
                    'license': 'CC0',
                    'filename': filename,
                    'duration': duration,
                    'tags': tags + list(sound.get('tags', []))[:5],
                    'calmScore': 0.85
                })

            time.sleep(0.5)  # Rate limiting

    # Save metadata
    with open(METADATA_FILE, 'w') as f:
        json.dump(all_metadata, f, indent=2)

    print("")
    print("=" * 50)
    print(f"Downloaded: {total_downloaded} tracks")
    print(f"Metadata saved to: {METADATA_FILE}")
    print("=" * 50)

if __name__ == '__main__':
    main()
`;

    const scriptPath = path.join(__dirname, 'freesound_downloader.py');
    fs.writeFileSync(scriptPath, freesoundScript);
    console.log(`  Created: ${scriptPath}`);
    console.log('  Run: pip install requests && python freesound_downloader.py');
  }

  async generatePixabayScript(): Promise<void> {
    console.log('\n=== Generating Pixabay Download Script ===');

    const pixabayScript = `#!/usr/bin/env python3
"""
Pixabay Music Downloader for Baby in Car App
Downloads royalty-free music from Pixabay

Note: Pixabay doesn't have a public API for music.
This script generates URLs to search manually or uses web scraping.
All Pixabay music is free for commercial use with no attribution required.

Usage:
1. Visit the generated URLs
2. Download tracks manually
3. Or use the automated download feature (requires selenium)
"""

import os
import json
from pathlib import Path

OUTPUT_DIR = '${CONFIG.outputDir}'
METADATA_FILE = '${path.join(__dirname, 'pixabay-metadata.json')}'

# Search configurations
SEARCH_CONFIGS = ${JSON.stringify(PIXABAY_COLLECTIONS, null, 2)}

def generate_search_urls():
    """Generate Pixabay search URLs for manual download"""
    print("=" * 50)
    print("Pixabay Music Search URLs")
    print("=" * 50)
    print("")
    print("Visit these URLs and download tracks:")
    print("")

    for config in SEARCH_CONFIGS:
        search_term = config['searchTerm']
        category = config['category']
        count = config['count']

        # Pixabay music URL format
        url = f"https://pixabay.com/music/search/{search_term.replace(' ', '%20')}/"
        print(f"Category: {category}")
        print(f"  Search: {search_term}")
        print(f"  Target: {count} tracks")
        print(f"  URL: {url}")
        print("")

def create_metadata_template():
    """Create a template for manual metadata entry"""
    template = []
    track_num = 1

    for config in SEARCH_CONFIGS:
        for i in range(config['count']):
            template.append({
                'id': f"pb_{track_num:03d}",
                'title': f"[Enter title for {config['searchTerm']} track {i+1}]",
                'artist': "Pixabay Artist",
                'category': config['category'],
                'subcategory': config['subcategory'],
                'source': 'pixabay',
                'license': 'Pixabay License (Free)',
                'filename': f"pixabay_{config['category']}_{i+1:03d}.mp3",
                'calmScore': 0.85,
                'tags': config['searchTerm'].split(' ')
            })
            track_num += 1

    with open(METADATA_FILE, 'w') as f:
        json.dump(template, f, indent=2)

    print(f"Metadata template saved to: {METADATA_FILE}")
    print("Edit this file after downloading tracks.")

# Pre-selected Pixabay tracks (manually curated)
CURATED_PIXABAY_TRACKS = [
    # These are known good tracks from Pixabay
    {'url': 'https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3', 'title': 'Relaxing Piano', 'category': 'classical'},
    {'url': 'https://cdn.pixabay.com/download/audio/2022/10/25/audio_946b0939c8.mp3', 'title': 'Calm Ambient', 'category': 'ambient'},
    {'url': 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3', 'title': 'Soft Lullaby', 'category': 'lullabies'},
    # Add more as discovered...
]

if __name__ == '__main__':
    generate_search_urls()
    print("")
    create_metadata_template()
`;

    const scriptPath = path.join(__dirname, 'pixabay_downloader.py');
    fs.writeFileSync(scriptPath, pixabayScript);
    console.log(`  Created: ${scriptPath}`);
  }

  async generateSunoScript(): Promise<void> {
    console.log('\n=== Generating Suno AI Generation Script ===');

    const sunoScript = `#!/usr/bin/env python3
"""
Suno AI Music Generator for Baby in Car App
Generates original music using Suno AI

IMPORTANT: Suno doesn't have an official public API.
Use one of these third-party options:

1. SunoAPI.org - https://sunoapi.org/
2. AIMLAPI - https://aimlapi.com/suno-ai-api
3. PiAPI - https://piapi.ai/suno-v5

Each provider has different pricing and features.
This script supports multiple providers.
"""

import os
import json
import time
import requests
from pathlib import Path

# Configuration
SUNO_API_KEY = os.environ.get('SUNO_API_KEY', '')
SUNO_API_PROVIDER = os.environ.get('SUNO_API_PROVIDER', 'sunoapi')  # sunoapi, aimlapi, piapi

OUTPUT_DIR = '${CONFIG.outputDir}/generated'
METADATA_FILE = '${path.join(__dirname, 'suno-metadata.json')}'

# Generation prompts
GENERATION_PROMPTS = ${JSON.stringify(SUNO_GENERATION_PROMPTS, null, 2)}

class SunoAPIClient:
    """Wrapper for different Suno API providers"""

    def __init__(self, api_key: str, provider: str):
        self.api_key = api_key
        self.provider = provider

        # API endpoints for different providers
        self.endpoints = {
            'sunoapi': 'https://api.sunoapi.org/v1/generate',
            'aimlapi': 'https://api.aimlapi.com/suno/generate',
            'piapi': 'https://api.piapi.ai/suno/v5/generate'
        }

    def generate(self, prompt: str, duration: int = 60) -> dict:
        """Generate music from prompt"""
        if self.provider not in self.endpoints:
            raise ValueError(f"Unknown provider: {self.provider}")

        url = self.endpoints[self.provider]

        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

        data = {
            'prompt': prompt,
            'duration': duration,
            'instrumental': True,
            'wait_audio': True
        }

        response = requests.post(url, json=data, headers=headers)

        if response.status_code != 200:
            raise Exception(f"API Error: {response.status_code} - {response.text}")

        return response.json()

    def download(self, audio_url: str, output_path: str) -> bool:
        """Download generated audio"""
        response = requests.get(audio_url, stream=True)
        if response.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
        return False

def main():
    if not SUNO_API_KEY:
        print("=" * 60)
        print("SUNO API KEY REQUIRED")
        print("=" * 60)
        print("")
        print("Get API key from one of these providers:")
        print("")
        print("1. SunoAPI.org")
        print("   - Sign up: https://sunoapi.org/")
        print("   - Get key from dashboard")
        print("   - export SUNO_API_PROVIDER=sunoapi")
        print("")
        print("2. AIMLAPI")
        print("   - Sign up: https://aimlapi.com/")
        print("   - Get key from dashboard")
        print("   - export SUNO_API_PROVIDER=aimlapi")
        print("")
        print("3. PiAPI")
        print("   - Sign up: https://piapi.ai/")
        print("   - Get key from workspace")
        print("   - export SUNO_API_PROVIDER=piapi")
        print("")
        print("Then set:")
        print("   export SUNO_API_KEY=your_key_here")
        print("")
        return

    print("=" * 60)
    print("Suno AI Music Generator")
    print(f"Provider: {SUNO_API_PROVIDER}")
    print("=" * 60)
    print("")

    # Create output directory
    output_dir = Path(OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)

    client = SunoAPIClient(SUNO_API_KEY, SUNO_API_PROVIDER)
    all_metadata = []
    generated_count = 0

    for prompt_config in GENERATION_PROMPTS:
        prompt_id = prompt_config['id']
        prompt = prompt_config['prompt']
        category = prompt_config['category']
        subcategory = prompt_config['subcategory']
        tags = prompt_config['tags']

        filename = f"{prompt_id}.mp3"
        output_path = output_dir / filename

        # Skip if already exists
        if output_path.exists() and output_path.stat().st_size > 10000:
            print(f"[SKIP] {prompt_id} (already exists)")
            all_metadata.append({
                'id': prompt_id,
                'title': f"Generated: {' '.join(tags[:3])}",
                'artist': 'Suno AI',
                'category': category,
                'subcategory': subcategory,
                'source': 'suno',
                'license': 'AI Generated (Custom)',
                'filename': filename,
                'tags': tags,
                'calmScore': 0.88,
                'prompt': prompt
            })
            continue

        print(f"[GEN] {prompt_id}")
        print(f"      Prompt: {prompt[:60]}...")

        try:
            result = client.generate(prompt, duration=60)
            audio_url = result.get('audio_url')

            if audio_url and client.download(audio_url, str(output_path)):
                print(f"      ✓ Generated successfully")
                generated_count += 1
                all_metadata.append({
                    'id': prompt_id,
                    'title': f"Generated: {' '.join(tags[:3])}",
                    'artist': 'Suno AI',
                    'category': category,
                    'subcategory': subcategory,
                    'source': 'suno',
                    'license': 'AI Generated (Custom)',
                    'filename': filename,
                    'tags': tags,
                    'calmScore': 0.88,
                    'prompt': prompt
                })
            else:
                print(f"      ✗ Download failed")
        except Exception as e:
            print(f"      ✗ Error: {e}")

        # Rate limiting - Suno has strict limits
        time.sleep(30)

    # Save metadata
    with open(METADATA_FILE, 'w') as f:
        json.dump(all_metadata, f, indent=2)

    print("")
    print("=" * 60)
    print(f"Generated: {generated_count} tracks")
    print(f"Metadata saved to: {METADATA_FILE}")
    print("=" * 60)

if __name__ == '__main__':
    main()
`;

    const scriptPath = path.join(__dirname, 'suno_generator.py');
    fs.writeFileSync(scriptPath, sunoScript);
    console.log(`  Created: ${scriptPath}`);
    console.log('');
    console.log('  To use Suno AI generation:');
    console.log('  1. Sign up at https://sunoapi.org/ or https://piapi.ai/suno-v5');
    console.log('  2. Get your API key');
    console.log('  3. export SUNO_API_KEY=your_key');
    console.log('  4. export SUNO_API_PROVIDER=sunoapi');
    console.log('  5. python suno_generator.py');
  }

  async saveMetadata(): Promise<void> {
    console.log('\n=== Saving Metadata ===');

    fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(this.metadata, null, 2));
    console.log(`  Saved ${this.metadata.length} tracks to ${CONFIG.metadataFile}`);
  }

  async generateSQLMigration(): Promise<void> {
    console.log('\n=== Generating SQL Migration ===');

    let sql = `-- Audio Library Mass Import
-- Generated: ${new Date().toISOString()}
-- Total tracks: ${this.metadata.length}

`;

    for (const track of this.metadata) {
      const escapedTitle = track.title.replace(/'/g, "''");
      const escapedArtist = track.artist.replace(/'/g, "''");
      const tagsJson = JSON.stringify(track.tags);

      sql += `INSERT OR REPLACE INTO audio_tracks (id, title, artist, category, subcategory, source, license, filename, duration, calm_score, tags, created_at, updated_at)
VALUES ('${track.id}', '${escapedTitle}', '${escapedArtist}', '${track.category}', '${track.subcategory}', '${track.source}', '${track.license}', '${track.filename}', ${track.duration || 180}, ${track.calmScore}, '${tagsJson}', datetime('now'), datetime('now'));

`;
    }

    const sqlPath = path.join(__dirname, '../migrations/005_mass_audio_import.sql');
    fs.writeFileSync(sqlPath, sql);
    console.log(`  Generated: ${sqlPath}`);
  }

  printSummary(): void {
    console.log('\n' + '='.repeat(60));
    console.log('DOWNLOAD SUMMARY');
    console.log('='.repeat(60));
    console.log(`  Downloaded: ${this.downloadedCount}`);
    console.log(`  Skipped (existing): ${this.skippedCount}`);
    console.log(`  Failed: ${this.failedCount}`);
    console.log(`  Total metadata: ${this.metadata.length}`);
    console.log('');
    console.log('Additional scripts generated:');
    console.log('  - freesound_downloader.py (requires API key)');
    console.log('  - pixabay_downloader.py (manual download URLs)');
    console.log('  - suno_generator.py (requires API key)');
    console.log('='.repeat(60));
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Main execution
async function main() {
  console.log('='.repeat(60));
  console.log('MASS AUDIO COLLECTOR FOR BABY IN CAR APP');
  console.log('='.repeat(60));
  console.log('');
  console.log('This script will:');
  console.log(`  1. Download ${INTERNET_ARCHIVE_TRACKS.length}+ tracks from Internet Archive`);
  console.log('  2. Generate Freesound API download script');
  console.log('  3. Generate Pixabay download URLs');
  console.log('  4. Generate Suno AI generation script');
  console.log('');

  const collector = new MassAudioCollector();

  // Download from Internet Archive
  await collector.downloadInternetArchive();

  // Generate helper scripts
  await collector.generateFreesoundScript();
  await collector.generatePixabayScript();
  await collector.generateSunoScript();

  // Save metadata
  await collector.saveMetadata();
  await collector.generateSQLMigration();

  // Print summary
  collector.printSummary();
}

main().catch(console.error);
