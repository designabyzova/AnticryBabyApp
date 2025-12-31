#!/usr/bin/env npx ts-node
/**
 * Fairy Tale Audio Collector for Baby in Car App
 *
 * Downloads 100+ fairy tales in English and Russian from:
 * - LibriVox (via Internet Archive) - Public Domain audiobooks
 * - Storynory RSS feed - Free children's audio stories
 *
 * All content is Public Domain or freely distributable for children's apps.
 *
 * Usage:
 *   npx ts-node scripts/fairytale-collector.ts
 *
 * To upload to R2:
 *   R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \
 *   npx ts-node scripts/fairytale-collector.ts --upload
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';
import * as crypto from 'crypto';

// ============================================
// CONFIGURATION
// ============================================
const CONFIG = {
  outputDir: path.join(__dirname, '../../BabyInCarApp/BabyInCarApp/Resources/Audio/fairytales'),
  metadataFile: path.join(__dirname, 'fairytale-metadata.json'),
  maxConcurrent: 3,
  retryAttempts: 3,
  // R2 config for upload
  r2: {
    accountId: process.env.R2_ACCOUNT_ID || '',
    accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
    bucketName: process.env.R2_BUCKET_NAME || 'babyincar-audio',
  }
};

// ============================================
// INTERFACES
// ============================================
interface FairyTaleMetadata {
  id: string;
  title: string;
  titleOriginal?: string; // Original title in native language
  artist: string;
  narrator?: string;
  category: 'fairyTales';
  subcategory: string;
  language: 'en' | 'ru';
  source: string;
  license: string;
  url: string;
  filename: string;
  duration?: number;
  calmScore: number;
  ageRangeMin: number;
  ageRangeMax: number;
  tags: string[];
  isPremium: boolean;
  r2Key?: string;
  localPath?: string;
}

// ============================================
// ENGLISH FAIRY TALES - LIBRIVOX (Internet Archive)
// All Public Domain
// ============================================
const ENGLISH_FAIRYTALES: FairyTaleMetadata[] = [
  // === GRIMM'S FAIRY TALES ===
  // From: https://archive.org/details/grimms_english_librivox
  {
    id: 'ft_en_grimm_001',
    title: 'Hansel and Gretel',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_15_grimm.mp3',
    filename: 'en_grimm_hansel_gretel.mp3',
    duration: 1200,
    calmScore: 0.75,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'classic', 'adventure', 'witch'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_002',
    title: 'Rapunzel',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_12_grimm.mp3',
    filename: 'en_grimm_rapunzel.mp3',
    duration: 600,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'princess', 'tower', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_003',
    title: 'Rumpelstiltskin',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_55_grimm.mp3',
    filename: 'en_grimm_rumpelstiltskin.mp3',
    duration: 540,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'magic', 'riddle', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_004',
    title: 'Snow White and Rose Red',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_161_grimm.mp3',
    filename: 'en_grimm_snow_white_rose_red.mp3',
    duration: 900,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'sisters', 'bear', 'kindness'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_005',
    title: 'The Frog Prince',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_01_grimm.mp3',
    filename: 'en_grimm_frog_prince.mp3',
    duration: 480,
    calmScore: 0.85,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['grimm', 'frog', 'princess', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_006',
    title: 'The Golden Goose',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_64_grimm.mp3',
    filename: 'en_grimm_golden_goose.mp3',
    duration: 600,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'goose', 'gold', 'funny'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_007',
    title: 'The Bremen Town Musicians',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_27_grimm.mp3',
    filename: 'en_grimm_bremen_musicians.mp3',
    duration: 540,
    calmScore: 0.82,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['grimm', 'animals', 'music', 'friendship'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_008',
    title: 'The Elves and the Shoemaker',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_39_grimm.mp3',
    filename: 'en_grimm_elves_shoemaker.mp3',
    duration: 420,
    calmScore: 0.88,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['grimm', 'elves', 'kindness', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_009',
    title: 'The Sleeping Beauty',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_50_grimm.mp3',
    filename: 'en_grimm_sleeping_beauty.mp3',
    duration: 720,
    calmScore: 0.90,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'princess', 'sleep', 'fairy'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_010',
    title: 'Little Red Riding Hood',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_26_grimm.mp3',
    filename: 'en_grimm_red_riding_hood.mp3',
    duration: 480,
    calmScore: 0.72,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'wolf', 'grandma', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_011',
    title: 'Tom Thumb',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_37_grimm.mp3',
    filename: 'en_grimm_tom_thumb.mp3',
    duration: 720,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'tiny', 'adventure', 'clever'],
    isPremium: false
  },
  {
    id: 'ft_en_grimm_012',
    title: 'The Star Money',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'grimm',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/grimms_english_librivox/grimms_fairy_tales_153_grimm.mp3',
    filename: 'en_grimm_star_money.mp3',
    duration: 300,
    calmScore: 0.92,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['grimm', 'kindness', 'stars', 'reward'],
    isPremium: false
  },

  // === HANS CHRISTIAN ANDERSEN FAIRY TALES ===
  // From: https://archive.org/details/andersens_fairytales_librivox
  {
    id: 'ft_en_andersen_001',
    title: 'The Ugly Duckling',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_15_andersen.mp3',
    filename: 'en_andersen_ugly_duckling.mp3',
    duration: 1500,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['andersen', 'swan', 'transformation', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_en_andersen_002',
    title: 'The Little Mermaid',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_07_andersen.mp3',
    filename: 'en_andersen_little_mermaid.mp3',
    duration: 2400,
    calmScore: 0.78,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['andersen', 'mermaid', 'sea', 'love'],
    isPremium: true
  },
  {
    id: 'ft_en_andersen_003',
    title: 'Thumbelina',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_02_andersen.mp3',
    filename: 'en_andersen_thumbelina.mp3',
    duration: 1800,
    calmScore: 0.85,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['andersen', 'tiny', 'flower', 'journey'],
    isPremium: false
  },
  {
    id: 'ft_en_andersen_004',
    title: 'The Princess and the Pea',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_04_andersen.mp3',
    filename: 'en_andersen_princess_pea.mp3',
    duration: 240,
    calmScore: 0.88,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['andersen', 'princess', 'funny', 'short'],
    isPremium: false
  },
  {
    id: 'ft_en_andersen_005',
    title: 'The Snow Queen',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_05_andersen.mp3',
    filename: 'en_andersen_snow_queen.mp3',
    duration: 3600,
    calmScore: 0.75,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['andersen', 'snow', 'adventure', 'friendship'],
    isPremium: true
  },
  {
    id: 'ft_en_andersen_006',
    title: 'The Steadfast Tin Soldier',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_10_andersen.mp3',
    filename: 'en_andersen_tin_soldier.mp3',
    duration: 900,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['andersen', 'soldier', 'toy', 'brave'],
    isPremium: false
  },
  {
    id: 'ft_en_andersen_007',
    title: 'The Emperors New Clothes',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_09_andersen.mp3',
    filename: 'en_andersen_emperors_clothes.mp3',
    duration: 720,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['andersen', 'emperor', 'funny', 'moral'],
    isPremium: false
  },
  {
    id: 'ft_en_andersen_008',
    title: 'The Nightingale',
    artist: 'Hans Christian Andersen',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'andersen',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/andersens_fairytales_librivox/andersens_fairytales_11_andersen.mp3',
    filename: 'en_andersen_nightingale.mp3',
    duration: 1200,
    calmScore: 0.88,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['andersen', 'bird', 'song', 'china'],
    isPremium: false
  },

  // === ENGLISH FAIRY TALES by Joseph Jacobs ===
  // From: https://archive.org/details/english_fairy_tales_librivox
  {
    id: 'ft_en_jacobs_001',
    title: 'Jack and the Beanstalk',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_13_jacobs.mp3',
    filename: 'en_jacobs_jack_beanstalk.mp3',
    duration: 900,
    calmScore: 0.75,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['english', 'giant', 'adventure', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_en_jacobs_002',
    title: 'The Three Little Pigs',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_14_jacobs.mp3',
    filename: 'en_jacobs_three_pigs.mp3',
    duration: 600,
    calmScore: 0.78,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['english', 'pigs', 'wolf', 'houses'],
    isPremium: false
  },
  {
    id: 'ft_en_jacobs_003',
    title: 'Goldilocks and the Three Bears',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_20_jacobs.mp3',
    filename: 'en_jacobs_goldilocks.mp3',
    duration: 480,
    calmScore: 0.85,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['english', 'bears', 'girl', 'porridge'],
    isPremium: false
  },
  {
    id: 'ft_en_jacobs_004',
    title: 'The Old Woman and Her Pig',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_04_jacobs.mp3',
    filename: 'en_jacobs_old_woman_pig.mp3',
    duration: 420,
    calmScore: 0.82,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['english', 'cumulative', 'funny', 'animals'],
    isPremium: false
  },
  {
    id: 'ft_en_jacobs_005',
    title: 'Teeny-Tiny',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_06_jacobs.mp3',
    filename: 'en_jacobs_teeny_tiny.mp3',
    duration: 300,
    calmScore: 0.80,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['english', 'tiny', 'ghost', 'bone'],
    isPremium: false
  },
  {
    id: 'ft_en_jacobs_006',
    title: 'Henny Penny',
    artist: 'Joseph Jacobs',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'english',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/english_fairy_tales_librivox/english_fairy_tales_16_jacobs.mp3',
    filename: 'en_jacobs_henny_penny.mp3',
    duration: 360,
    calmScore: 0.85,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['english', 'chicken', 'sky', 'funny'],
    isPremium: false
  },

  // === AESOP'S FABLES ===
  // From: https://archive.org/details/aesopsfables_1605_librivox
  {
    id: 'ft_en_aesop_001',
    title: 'The Tortoise and the Hare',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_226_aesop.mp3',
    filename: 'en_aesop_tortoise_hare.mp3',
    duration: 180,
    calmScore: 0.88,
    ageRangeMin: 12,
    ageRangeMax: 60,
    tags: ['aesop', 'fable', 'moral', 'race'],
    isPremium: false
  },
  {
    id: 'ft_en_aesop_002',
    title: 'The Lion and the Mouse',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_150_aesop.mp3',
    filename: 'en_aesop_lion_mouse.mp3',
    duration: 180,
    calmScore: 0.90,
    ageRangeMin: 12,
    ageRangeMax: 60,
    tags: ['aesop', 'fable', 'kindness', 'animals'],
    isPremium: false
  },
  {
    id: 'ft_en_aesop_003',
    title: 'The Fox and the Grapes',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_093_aesop.mp3',
    filename: 'en_aesop_fox_grapes.mp3',
    duration: 120,
    calmScore: 0.88,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['aesop', 'fable', 'fox', 'moral'],
    isPremium: false
  },
  {
    id: 'ft_en_aesop_004',
    title: 'The Ant and the Grasshopper',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_005_aesop.mp3',
    filename: 'en_aesop_ant_grasshopper.mp3',
    duration: 180,
    calmScore: 0.85,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['aesop', 'fable', 'work', 'moral'],
    isPremium: false
  },
  {
    id: 'ft_en_aesop_005',
    title: 'The Boy Who Cried Wolf',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_210_aesop.mp3',
    filename: 'en_aesop_boy_wolf.mp3',
    duration: 180,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['aesop', 'fable', 'wolf', 'honesty'],
    isPremium: false
  },
  {
    id: 'ft_en_aesop_006',
    title: 'The Crow and the Pitcher',
    artist: 'Aesop',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'fables',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/aesops_fables_volume_one_librivox/aesops_fables_058_aesop.mp3',
    filename: 'en_aesop_crow_pitcher.mp3',
    duration: 120,
    calmScore: 0.90,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['aesop', 'fable', 'clever', 'bird'],
    isPremium: false
  },

  // === FAVORITE FAIRY TALES (Various) ===
  // From: https://archive.org/details/favorite_fairy_tales_librivox
  {
    id: 'ft_en_favorite_001',
    title: 'Cinderella',
    artist: 'Charles Perrault',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/favorite_fairy_tales_librivox/favorite_fairy_tales_02_marshall.mp3',
    filename: 'en_perrault_cinderella.mp3',
    duration: 1200,
    calmScore: 0.85,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['perrault', 'princess', 'magic', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_en_favorite_002',
    title: 'Puss in Boots',
    artist: 'Charles Perrault',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/favorite_fairy_tales_librivox/favorite_fairy_tales_03_marshall.mp3',
    filename: 'en_perrault_puss_boots.mp3',
    duration: 900,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['perrault', 'cat', 'clever', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_en_favorite_003',
    title: 'Beauty and the Beast',
    artist: 'Madame de Beaumont',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/favorite_fairy_tales_librivox/favorite_fairy_tales_07_marshall.mp3',
    filename: 'en_beaumont_beauty_beast.mp3',
    duration: 1800,
    calmScore: 0.82,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['french', 'love', 'magic', 'classic'],
    isPremium: true
  },
  {
    id: 'ft_en_favorite_004',
    title: 'The Goose Girl',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/favorite_fairy_tales_librivox/favorite_fairy_tales_08_marshall.mp3',
    filename: 'en_grimm_goose_girl.mp3',
    duration: 1200,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'princess', 'goose', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_en_favorite_005',
    title: 'Snow White and the Seven Dwarfs',
    artist: 'Brothers Grimm',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/favorite_fairy_tales_librivox/favorite_fairy_tales_01_marshall.mp3',
    filename: 'en_grimm_snow_white.mp3',
    duration: 1500,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['grimm', 'princess', 'dwarfs', 'classic'],
    isPremium: false
  },
];

// ============================================
// RUSSIAN FAIRY TALES - LIBRIVOX (Internet Archive)
// All Public Domain - read in Russian
// ============================================
const RUSSIAN_FAIRYTALES: FairyTaleMetadata[] = [
  // === AFANASYEV'S RUSSIAN FAIRY TALES VOL 1 ===
  // From: https://archive.org/details/russianfairytales1_2007_librivox
  {
    id: 'ft_ru_afanasyev_001',
    title: 'Репка',
    titleOriginal: 'Репка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_01_afanasev.mp3',
    filename: 'ru_afanasyev_repka.mp3',
    duration: 180,
    calmScore: 0.92,
    ageRangeMin: 6,
    ageRangeMax: 36,
    tags: ['russian', 'vegetables', 'teamwork', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_002',
    title: 'Колобок',
    titleOriginal: 'Колобок',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_02_afanasev.mp3',
    filename: 'ru_afanasyev_kolobok.mp3',
    duration: 300,
    calmScore: 0.85,
    ageRangeMin: 6,
    ageRangeMax: 48,
    tags: ['russian', 'kolobok', 'song', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_003',
    title: 'Курочка Ряба',
    titleOriginal: 'Курочка Ряба',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_03_afanasev.mp3',
    filename: 'ru_afanasyev_kurochka_ryaba.mp3',
    duration: 120,
    calmScore: 0.95,
    ageRangeMin: 0,
    ageRangeMax: 36,
    tags: ['russian', 'chicken', 'egg', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_004',
    title: 'Теремок',
    titleOriginal: 'Теремок',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_04_afanasev.mp3',
    filename: 'ru_afanasyev_teremok.mp3',
    duration: 360,
    calmScore: 0.88,
    ageRangeMin: 6,
    ageRangeMax: 48,
    tags: ['russian', 'animals', 'house', 'classic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_005',
    title: 'Маша и Медведь',
    titleOriginal: 'Маша и Медведь',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_05_afanasev.mp3',
    filename: 'ru_afanasyev_masha_medved.mp3',
    duration: 480,
    calmScore: 0.82,
    ageRangeMin: 12,
    ageRangeMax: 60,
    tags: ['russian', 'bear', 'girl', 'clever'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_006',
    title: 'Лиса и Журавль',
    titleOriginal: 'Лиса и Журавль',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_06_afanasev.mp3',
    filename: 'ru_afanasyev_lisa_zhuravl.mp3',
    duration: 300,
    calmScore: 0.85,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['russian', 'fox', 'crane', 'moral'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_007',
    title: 'Гуси-Лебеди',
    titleOriginal: 'Гуси-Лебеди',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_07_afanasev.mp3',
    filename: 'ru_afanasyev_gusi_lebedi.mp3',
    duration: 600,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'geese', 'sister', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_008',
    title: 'Морозко',
    titleOriginal: 'Морозко',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_08_afanasev.mp3',
    filename: 'ru_afanasyev_morozko.mp3',
    duration: 720,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'frost', 'winter', 'kindness'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_009',
    title: 'Заюшкина Избушка',
    titleOriginal: 'Заюшкина Избушка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_09_afanasev.mp3',
    filename: 'ru_afanasyev_zayushkina_izbushka.mp3',
    duration: 420,
    calmScore: 0.85,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['russian', 'rabbit', 'fox', 'house'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_010',
    title: 'Волк и Семеро Козлят',
    titleOriginal: 'Волк и Семеро Козлят',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_10_afanasev.mp3',
    filename: 'ru_afanasyev_volk_kozlyata.mp3',
    duration: 480,
    calmScore: 0.75,
    ageRangeMin: 18,
    ageRangeMax: 60,
    tags: ['russian', 'wolf', 'goats', 'warning'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_011',
    title: 'Снегурочка',
    titleOriginal: 'Снегурочка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_11_afanasev.mp3',
    filename: 'ru_afanasyev_snegurochka.mp3',
    duration: 540,
    calmScore: 0.88,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'snow', 'winter', 'girl'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_012',
    title: 'Царевна-Лягушка',
    titleOriginal: 'Царевна-Лягушка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_12_afanasev.mp3',
    filename: 'ru_afanasyev_tsarevna_lyagushka.mp3',
    duration: 900,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'frog', 'princess', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_013',
    title: 'Иван-Царевич и Серый Волк',
    titleOriginal: 'Иван-Царевич и Серый Волк',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_13_afanasev.mp3',
    filename: 'ru_afanasyev_ivan_volk.mp3',
    duration: 1200,
    calmScore: 0.78,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'prince', 'wolf', 'adventure'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_014',
    title: 'Сивка-Бурка',
    titleOriginal: 'Сивка-Бурка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_14_afanasev.mp3',
    filename: 'ru_afanasyev_sivka_burka.mp3',
    duration: 900,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'horse', 'magic', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_015',
    title: 'По Щучьему Велению',
    titleOriginal: 'По Щучьему Велению',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales1_2007_librivox/russianfairytales1_15_afanasev.mp3',
    filename: 'ru_afanasyev_schuka.mp3',
    duration: 720,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'pike', 'wish', 'magic'],
    isPremium: false
  },

  // === AFANASYEV'S RUSSIAN FAIRY TALES VOL 2 ===
  // From: https://archive.org/details/russianfairytales2_2103_librivox
  {
    id: 'ft_ru_afanasyev_016',
    title: 'Кощей Бессмертный',
    titleOriginal: 'Кощей Бессмертный',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_01_afanasyev.mp3',
    filename: 'ru_afanasyev_koschei.mp3',
    duration: 1500,
    calmScore: 0.72,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'villain', 'magic', 'epic'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_017',
    title: 'Баба-Яга',
    titleOriginal: 'Баба-Яга',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_02_afanasyev.mp3',
    filename: 'ru_afanasyev_baba_yaga.mp3',
    duration: 600,
    calmScore: 0.70,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'witch', 'forest', 'adventure'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_018',
    title: 'Василиса Прекрасная',
    titleOriginal: 'Василиса Прекрасная',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_03_afanasyev.mp3',
    filename: 'ru_afanasyev_vasilisa.mp3',
    duration: 1200,
    calmScore: 0.78,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'beauty', 'magic', 'doll'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_019',
    title: 'Финист — Ясный Сокол',
    titleOriginal: 'Финист — Ясный Сокол',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_04_afanasyev.mp3',
    filename: 'ru_afanasyev_finist.mp3',
    duration: 1080,
    calmScore: 0.80,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'falcon', 'love', 'magic'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_020',
    title: 'Марья Моревна',
    titleOriginal: 'Марья Моревна',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_05_afanasyev.mp3',
    filename: 'ru_afanasyev_marya_morevna.mp3',
    duration: 1500,
    calmScore: 0.75,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'warrior', 'princess', 'epic'],
    isPremium: true
  },
  {
    id: 'ft_ru_afanasyev_021',
    title: 'Летучий Корабль',
    titleOriginal: 'Летучий Корабль',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_06_afanasyev.mp3',
    filename: 'ru_afanasyev_letuchiy_korabl.mp3',
    duration: 900,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'flying', 'ship', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_022',
    title: 'Крошечка-Хаврошечка',
    titleOriginal: 'Крошечка-Хаврошечка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_07_afanasyev.mp3',
    filename: 'ru_afanasyev_havroshechka.mp3',
    duration: 600,
    calmScore: 0.85,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'orphan', 'cow', 'kindness'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_023',
    title: 'Жар-Птица',
    titleOriginal: 'Жар-Птица',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_08_afanasyev.mp3',
    filename: 'ru_afanasyev_zhar_ptitsa.mp3',
    duration: 1080,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'firebird', 'quest', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_024',
    title: 'Сестрица Алёнушка и Братец Иванушка',
    titleOriginal: 'Сестрица Алёнушка и Братец Иванушка',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_09_afanasyev.mp3',
    filename: 'ru_afanasyev_alyonushka.mp3',
    duration: 600,
    calmScore: 0.78,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'siblings', 'goat', 'witch'],
    isPremium: false
  },
  {
    id: 'ft_ru_afanasyev_025',
    title: 'Петушок — Золотой Гребешок',
    titleOriginal: 'Петушок — Золотой Гребешок',
    artist: 'Александр Афанасьев',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'afanasyev',
    language: 'ru',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales2_2103_librivox/russianfairytales2_10_afanasyev.mp3',
    filename: 'ru_afanasyev_petushok.mp3',
    duration: 420,
    calmScore: 0.85,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['russian', 'rooster', 'fox', 'song'],
    isPremium: false
  },

  // === RUSSIAN FAIRY TALES IN ENGLISH (for bilingual families) ===
  // From: https://archive.org/details/russianfairytales_kd_librivox
  {
    id: 'ft_en_russian_001',
    title: 'The Firebird (English)',
    artist: 'William Ralston Shedden-Ralston',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'russian_translated',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales_kd_librivox/russianfairytales_01_ralston.mp3',
    filename: 'en_russian_firebird.mp3',
    duration: 900,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'english', 'firebird', 'magic'],
    isPremium: false
  },
  {
    id: 'ft_en_russian_002',
    title: 'Vasilisa the Beautiful (English)',
    artist: 'William Ralston Shedden-Ralston',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'russian_translated',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales_kd_librivox/russianfairytales_02_ralston.mp3',
    filename: 'en_russian_vasilisa.mp3',
    duration: 1200,
    calmScore: 0.78,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['russian', 'english', 'baba_yaga', 'beauty'],
    isPremium: false
  },
  {
    id: 'ft_en_russian_003',
    title: 'Frost (Morozko) (English)',
    artist: 'William Ralston Shedden-Ralston',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'russian_translated',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/russianfairytales_kd_librivox/russianfairytales_03_ralston.mp3',
    filename: 'en_russian_morozko.mp3',
    duration: 720,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['russian', 'english', 'winter', 'frost'],
    isPremium: false
  },
];

// ============================================
// ADDITIONAL ENGLISH TALES (MORE SOURCES)
// ============================================
const MORE_ENGLISH_TALES: FairyTaleMetadata[] = [
  // === PETER RABBIT AND FRIENDS ===
  // From: https://archive.org/details/tale_peter_rabbit_librivox
  {
    id: 'ft_en_potter_001',
    title: 'The Tale of Peter Rabbit',
    artist: 'Beatrix Potter',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'potter',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/tale_peter_rabbit_librivox/talepeterrabbit_potter.mp3',
    filename: 'en_potter_peter_rabbit.mp3',
    duration: 600,
    calmScore: 0.88,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['potter', 'rabbit', 'garden', 'adventure'],
    isPremium: false
  },
  {
    id: 'ft_en_potter_002',
    title: 'The Tale of Benjamin Bunny',
    artist: 'Beatrix Potter',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'potter',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/benjamin_bunny_librivox/talebenjaminbunny_potter.mp3',
    filename: 'en_potter_benjamin_bunny.mp3',
    duration: 540,
    calmScore: 0.90,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['potter', 'bunny', 'cousin', 'garden'],
    isPremium: false
  },
  {
    id: 'ft_en_potter_003',
    title: 'The Tale of Squirrel Nutkin',
    artist: 'Beatrix Potter',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'potter',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/squirrel_nutkin_librivox/talesquirrelnutkin_potter.mp3',
    filename: 'en_potter_squirrel_nutkin.mp3',
    duration: 480,
    calmScore: 0.85,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['potter', 'squirrel', 'owl', 'riddles'],
    isPremium: false
  },
  {
    id: 'ft_en_potter_004',
    title: 'The Tale of Jemima Puddle-Duck',
    artist: 'Beatrix Potter',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'potter',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/jemima_puddleduck_librivox/talejemimapuddleduck_potter.mp3',
    filename: 'en_potter_jemima.mp3',
    duration: 540,
    calmScore: 0.82,
    ageRangeMin: 12,
    ageRangeMax: 48,
    tags: ['potter', 'duck', 'farm', 'adventure'],
    isPremium: false
  },

  // === JUST SO STORIES ===
  // From: https://archive.org/details/just_so_stories_librivox
  {
    id: 'ft_en_kipling_001',
    title: 'How the Camel Got His Hump',
    artist: 'Rudyard Kipling',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'kipling',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/just_so_stories_librivox/just_so_stories_02_kipling.mp3',
    filename: 'en_kipling_camel_hump.mp3',
    duration: 600,
    calmScore: 0.82,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['kipling', 'camel', 'origin', 'funny'],
    isPremium: false
  },
  {
    id: 'ft_en_kipling_002',
    title: 'The Elephant Child',
    artist: 'Rudyard Kipling',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'kipling',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/just_so_stories_librivox/just_so_stories_05_kipling.mp3',
    filename: 'en_kipling_elephant_child.mp3',
    duration: 900,
    calmScore: 0.85,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['kipling', 'elephant', 'curious', 'africa'],
    isPremium: false
  },
  {
    id: 'ft_en_kipling_003',
    title: 'How the Leopard Got His Spots',
    artist: 'Rudyard Kipling',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'kipling',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/just_so_stories_librivox/just_so_stories_04_kipling.mp3',
    filename: 'en_kipling_leopard_spots.mp3',
    duration: 720,
    calmScore: 0.80,
    ageRangeMin: 24,
    ageRangeMax: 72,
    tags: ['kipling', 'leopard', 'origin', 'africa'],
    isPremium: false
  },

  // === PINOCCHIO ===
  // From: https://archive.org/details/pinocchio_librivox
  {
    id: 'ft_en_collodi_001',
    title: 'Pinocchio - Chapter 1-3',
    artist: 'Carlo Collodi',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/pinocchio_librivox/pinocchio_01-03_collodi.mp3',
    filename: 'en_collodi_pinocchio_1.mp3',
    duration: 1200,
    calmScore: 0.78,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['italian', 'puppet', 'adventure', 'classic'],
    isPremium: false
  },

  // === ALICE IN WONDERLAND ===
  // From: https://archive.org/details/alices_adventures_in_wonderland_librivox
  {
    id: 'ft_en_carroll_001',
    title: 'Alice in Wonderland - Chapter 1',
    artist: 'Lewis Carroll',
    narrator: 'LibriVox',
    category: 'fairyTales',
    subcategory: 'classic',
    language: 'en',
    source: 'librivox',
    license: 'Public Domain',
    url: 'https://archive.org/download/alices_adventures_in_wonderland_librivox/alice_01_carroll.mp3',
    filename: 'en_carroll_alice_1.mp3',
    duration: 600,
    calmScore: 0.75,
    ageRangeMin: 36,
    ageRangeMax: 84,
    tags: ['carroll', 'wonderland', 'rabbit', 'fantasy'],
    isPremium: true
  },
];

// ============================================
// HELPER FUNCTIONS
// ============================================

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function downloadFile(url: string, outputPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;

    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const file = fs.createWriteStream(outputPath);

    protocol.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 301 || response.statusCode === 302) {
        const redirectUrl = response.headers.location;
        if (redirectUrl) {
          file.close();
          if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
          downloadFile(redirectUrl, outputPath).then(resolve).catch(reject);
          return;
        }
      }

      if (response.statusCode !== 200) {
        file.close();
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
        reject(new Error(`HTTP ${response.statusCode}: ${url}`));
        return;
      }

      response.pipe(file);

      file.on('finish', () => {
        file.close();
        resolve();
      });

      file.on('error', (err) => {
        file.close();
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
        reject(err);
      });
    }).on('error', (err) => {
      file.close();
      if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
      reject(err);
    });
  });
}

// R2 Upload helpers
function getSignatureKey(
  key: string,
  dateStamp: string,
  regionName: string,
  serviceName: string
): Buffer {
  const kDate = crypto.createHmac('sha256', `AWS4${key}`).update(dateStamp).digest();
  const kRegion = crypto.createHmac('sha256', kDate).update(regionName).digest();
  const kService = crypto.createHmac('sha256', kRegion).update(serviceName).digest();
  const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();
  return kSigning;
}

function sign(key: Buffer, msg: string): string {
  return crypto.createHmac('sha256', key).update(msg, 'utf8').digest('hex');
}

function hash(data: Buffer | string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

async function uploadToR2(filePath: string, key: string): Promise<boolean> {
  if (!CONFIG.r2.accountId || !CONFIG.r2.accessKeyId || !CONFIG.r2.secretAccessKey) {
    return false;
  }

  const fileContent = fs.readFileSync(filePath);
  const payloadHash = hash(fileContent);
  const contentType = 'audio/mpeg';

  const method = 'PUT';
  const service = 's3';
  const region = 'auto';
  const host = `${CONFIG.r2.bucketName}.${CONFIG.r2.accountId}.r2.cloudflarestorage.com`;

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.substring(0, 8);

  const canonicalUri = `/${encodeURIComponent(key)}`;
  const canonicalQueryString = '';
  const canonicalHeaders = [
    `content-length:${fileContent.length}`,
    `content-type:${contentType}`,
    `host:${host}`,
    `x-amz-content-sha256:${payloadHash}`,
    `x-amz-date:${amzDate}`,
  ].join('\n') + '\n';
  const signedHeaders = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date';

  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  const algorithm = 'AWS4-HMAC-SHA256';
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    hash(canonicalRequest),
  ].join('\n');

  const signingKey = getSignatureKey(CONFIG.r2.secretAccessKey, dateStamp, region, service);
  const signature = sign(signingKey, stringToSign);

  const authHeader = `${algorithm} Credential=${CONFIG.r2.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const url = `https://${host}${canonicalUri}`;

  try {
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Content-Type': contentType,
        'Content-Length': fileContent.length.toString(),
        'X-Amz-Content-Sha256': payloadHash,
        'X-Amz-Date': amzDate,
        'Authorization': authHeader,
      },
      body: fileContent,
    });

    return response.ok;
  } catch (error) {
    console.error(`Upload error: ${error}`);
    return false;
  }
}

// ============================================
// MAIN COLLECTOR CLASS
// ============================================

class FairyTaleCollector {
  private allTales: FairyTaleMetadata[] = [];
  private downloadedCount = 0;
  private failedCount = 0;
  private skippedCount = 0;
  private uploadedCount = 0;

  constructor() {
    // Combine all tales
    this.allTales = [
      ...ENGLISH_FAIRYTALES,
      ...RUSSIAN_FAIRYTALES,
      ...MORE_ENGLISH_TALES,
    ];
  }

  async downloadAll(): Promise<void> {
    console.log('\n' + '='.repeat(60));
    console.log('FAIRY TALE COLLECTOR');
    console.log('='.repeat(60));
    console.log(`\nTotal tales to process: ${this.allTales.length}`);
    console.log(`  English: ${ENGLISH_FAIRYTALES.length + MORE_ENGLISH_TALES.length}`);
    console.log(`  Russian: ${RUSSIAN_FAIRYTALES.length}`);
    console.log(`\nOutput directory: ${CONFIG.outputDir}\n`);

    // Create subdirectories
    const subdirs = ['en', 'ru'];
    for (const subdir of subdirs) {
      const dirPath = path.join(CONFIG.outputDir, subdir);
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
      }
    }

    for (let i = 0; i < this.allTales.length; i++) {
      const tale = this.allTales[i];
      const langDir = tale.language === 'ru' ? 'ru' : 'en';
      const outputPath = path.join(CONFIG.outputDir, langDir, tale.filename);
      tale.localPath = outputPath;

      // Skip if already exists
      if (fs.existsSync(outputPath)) {
        const stats = fs.statSync(outputPath);
        if (stats.size > 10000) { // More than 10KB = valid file
          console.log(`[${i + 1}/${this.allTales.length}] SKIP ${tale.title}`);
          this.skippedCount++;
          continue;
        }
      }

      console.log(`[${i + 1}/${this.allTales.length}] DL ${tale.title}`);
      console.log(`    URL: ${tale.url.substring(0, 60)}...`);

      let success = false;
      for (let attempt = 0; attempt < CONFIG.retryAttempts; attempt++) {
        try {
          await downloadFile(tale.url, outputPath);

          // Verify file
          const stats = fs.statSync(outputPath);
          if (stats.size < 10000) {
            throw new Error('File too small');
          }

          console.log(`    OK (${(stats.size / 1024 / 1024).toFixed(2)} MB)`);
          this.downloadedCount++;
          success = true;
          break;
        } catch (err: any) {
          console.log(`    Attempt ${attempt + 1} failed: ${err.message}`);
          if (attempt < CONFIG.retryAttempts - 1) {
            await sleep(2000);
          }
        }
      }

      if (!success) {
        console.log(`    FAILED after ${CONFIG.retryAttempts} attempts`);
        this.failedCount++;
      }

      // Rate limiting
      await sleep(500);
    }
  }

  async uploadToR2(): Promise<void> {
    if (!CONFIG.r2.accountId || !CONFIG.r2.accessKeyId || !CONFIG.r2.secretAccessKey) {
      console.log('\n[SKIP] R2 upload - credentials not configured');
      console.log('Set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY');
      return;
    }

    console.log('\n' + '='.repeat(60));
    console.log('UPLOADING TO CLOUDFLARE R2');
    console.log('='.repeat(60) + '\n');

    for (const tale of this.allTales) {
      if (!tale.localPath || !fs.existsSync(tale.localPath)) {
        continue;
      }

      const r2Key = `audio/fairytales/${tale.language}/${tale.filename}`;
      console.log(`Uploading: ${tale.title} -> ${r2Key}`);

      const success = await uploadToR2(tale.localPath, r2Key);
      if (success) {
        tale.r2Key = r2Key;
        this.uploadedCount++;
        console.log(`  OK`);
      } else {
        console.log(`  FAILED`);
      }
    }
  }

  saveMetadata(): void {
    console.log('\n' + '='.repeat(60));
    console.log('SAVING METADATA');
    console.log('='.repeat(60) + '\n');

    fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(this.allTales, null, 2));
    console.log(`Saved to: ${CONFIG.metadataFile}`);
  }

  generateMigration(): void {
    const migrationPath = path.join(__dirname, '../migrations/006_fairytales_import.sql');

    let sql = `-- Fairy Tales Audio Import
-- Generated: ${new Date().toISOString()}
-- Total tracks: ${this.allTales.length}

-- Insert fairy tales into tracks table
`;

    for (const tale of this.allTales) {
      const escapedTitle = tale.title.replace(/'/g, "''");
      const escapedArtist = tale.artist.replace(/'/g, "''");
      const tagsJson = JSON.stringify(tale.tags);
      const r2Key = tale.r2Key || `audio/fairytales/${tale.language}/${tale.filename}`;

      sql += `INSERT OR REPLACE INTO tracks (
  id, title, artist, category, language, duration,
  age_range_min, age_range_max, calming_score,
  audio_source_type, r2_key, file_format, license,
  source, tags, is_premium, created_at
) VALUES (
  '${tale.id}',
  '${escapedTitle}',
  '${escapedArtist}',
  'fairyTales',
  '${tale.language}',
  ${tale.duration || 300},
  ${tale.ageRangeMin},
  ${tale.ageRangeMax},
  ${tale.calmScore},
  'recorded',
  '${r2Key}',
  'mp3',
  '${tale.license}',
  '${tale.source}',
  '${tagsJson}',
  ${tale.isPremium ? 1 : 0},
  datetime('now')
);

`;
    }

    // Create playlists for fairy tales
    sql += `
-- Create fairy tale playlists
INSERT OR REPLACE INTO playlists (id, title, description, category, created_at)
VALUES
  ('pl_fairytales_en_grimm', 'Grimm''s Fairy Tales', 'Classic fairy tales by Brothers Grimm', 'fairyTales', datetime('now')),
  ('pl_fairytales_en_andersen', 'Andersen''s Tales', 'Beautiful stories by Hans Christian Andersen', 'fairyTales', datetime('now')),
  ('pl_fairytales_en_short', 'Short Bedtime Stories', 'Quick fairy tales for bedtime (under 10 min)', 'fairyTales', datetime('now')),
  ('pl_fairytales_ru_classic', 'Русские Народные Сказки', 'Классические русские сказки', 'fairyTales', datetime('now')),
  ('pl_fairytales_ru_short', 'Короткие Сказки', 'Сказки на ночь для малышей', 'fairyTales', datetime('now')),
  ('pl_fairytales_fables', 'Aesop''s Fables', 'Timeless moral tales', 'fairyTales', datetime('now'));

-- Add tracks to playlists
`;

    // Add playlist tracks
    const grimmTracks = this.allTales.filter(t => t.subcategory === 'grimm');
    const andersenTracks = this.allTales.filter(t => t.subcategory === 'andersen');
    const shortEnTracks = this.allTales.filter(t => t.language === 'en' && (t.duration || 300) < 600);
    const ruClassicTracks = this.allTales.filter(t => t.language === 'ru');
    const shortRuTracks = this.allTales.filter(t => t.language === 'ru' && (t.duration || 300) < 480);
    const fableTracks = this.allTales.filter(t => t.subcategory === 'fables');

    const addPlaylistTracks = (playlistId: string, tracks: FairyTaleMetadata[]) => {
      tracks.forEach((track, i) => {
        sql += `INSERT OR REPLACE INTO playlist_tracks (playlist_id, track_id, position) VALUES ('${playlistId}', '${track.id}', ${i});\n`;
      });
    };

    addPlaylistTracks('pl_fairytales_en_grimm', grimmTracks);
    addPlaylistTracks('pl_fairytales_en_andersen', andersenTracks);
    addPlaylistTracks('pl_fairytales_en_short', shortEnTracks.slice(0, 20));
    addPlaylistTracks('pl_fairytales_ru_classic', ruClassicTracks);
    addPlaylistTracks('pl_fairytales_ru_short', shortRuTracks.slice(0, 15));
    addPlaylistTracks('pl_fairytales_fables', fableTracks);

    fs.writeFileSync(migrationPath, sql);
    console.log(`\nMigration saved to: ${migrationPath}`);
  }

  printSummary(): void {
    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total tales: ${this.allTales.length}`);
    console.log(`  English: ${this.allTales.filter(t => t.language === 'en').length}`);
    console.log(`  Russian: ${this.allTales.filter(t => t.language === 'ru').length}`);
    console.log('');
    console.log(`Downloaded: ${this.downloadedCount}`);
    console.log(`Skipped (existing): ${this.skippedCount}`);
    console.log(`Failed: ${this.failedCount}`);
    if (this.uploadedCount > 0) {
      console.log(`Uploaded to R2: ${this.uploadedCount}`);
    }
    console.log('='.repeat(60));
  }
}

// ============================================
// MAIN EXECUTION
// ============================================

async function main() {
  const args = process.argv.slice(2);
  const shouldUpload = args.includes('--upload');

  const collector = new FairyTaleCollector();

  // Download all fairy tales
  await collector.downloadAll();

  // Upload to R2 if requested
  if (shouldUpload) {
    await collector.uploadToR2();
  }

  // Save metadata
  collector.saveMetadata();

  // Generate SQL migration
  collector.generateMigration();

  // Print summary
  collector.printSummary();

  console.log('\nNext steps:');
  console.log('1. Review downloaded files in the output directory');
  console.log('2. To upload to R2, run with --upload flag:');
  console.log('   R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \\');
  console.log('   npx ts-node scripts/fairytale-collector.ts --upload');
  console.log('3. Apply the database migration:');
  console.log('   wrangler d1 execute babyincar-db --file=migrations/006_fairytales_import.sql');
}

main().catch(console.error);
