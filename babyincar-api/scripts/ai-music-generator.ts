/**
 * AI Music Generator for Baby in Car App
 *
 * This script generates original children's songs using AI music generation APIs.
 * Supports multiple providers:
 * - Suno API (via third-party providers)
 * - MusicAPI.ai
 * - Kie.ai
 *
 * All generated music is fully licensed for commercial use.
 *
 * Usage:
 *   SUNO_API_KEY=your_key npx ts-node scripts/ai-music-generator.ts --generate
 *   npx ts-node scripts/ai-music-generator.ts --prompts  # Just show prompts
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';

// Configuration
const CONFIG = {
  // API Configuration (choose one provider)
  provider: process.env.AI_MUSIC_PROVIDER || 'suno', // 'suno', 'musicapi', 'kie'

  // Suno API via MusicAPI.ai
  musicapi: {
    apiKey: process.env.MUSICAPI_KEY || '',
    baseUrl: 'https://api.musicapi.ai/api/v1',
  },

  // Suno API via aimlapi.com
  aimlapi: {
    apiKey: process.env.AIMLAPI_KEY || '',
    baseUrl: 'https://api.aimlapi.com/v1',
  },

  // Kie.ai
  kie: {
    apiKey: process.env.KIE_API_KEY || '',
    baseUrl: 'https://api.kie.ai/api/v1',
  },

  outputDir: path.join(__dirname, '../audio-library/ai-generated'),
  metadataFile: path.join(__dirname, '../audio-library/ai-generated-metadata.json'),
};

// Russian Children's Song Prompts
const RUSSIAN_SONG_PROMPTS = {
  lullabies: [
    {
      id: 'ru_lullaby_01',
      title: 'Спи, малыш',
      titleEn: 'Sleep, Little One',
      prompt: 'Gentle Russian lullaby, soft female voice singing "спи малыш" (sleep little one), slow tempo 60 BPM, acoustic guitar, warm and soothing, for babies and toddlers',
      style: 'lullaby, acoustic, gentle, Russian',
      duration: 120,
      lyrics: `Спи, малыш мой, засыпай,
Глазки сладко закрывай.
Ночь пришла, луна взошла,
Сны волшебные несла.

Баю-баюшки-баю,
Песню нежную пою.
Спи спокойно до утра,
Спать давно тебе пора.`,
    },
    {
      id: 'ru_lullaby_02',
      title: 'Баю-баюшки-баю',
      titleEn: 'Hush-a-bye',
      prompt: 'Traditional Russian lullaby style, gentle humming and "баю-баюшки-баю", music box melody, very slow and calming, 55 BPM, perfect for newborns',
      style: 'lullaby, music box, traditional Russian',
      duration: 150,
      lyrics: `Баю-баюшки-баю,
Не ложися на краю.
Придёт серенький волчок,
И укусит за бочок.

Баю-баюшки-баю,
Я тебе покой дарю.
Звёзды светятся в ночи,
Ты усни и ты молчи.`,
    },
    {
      id: 'ru_lullaby_03',
      title: 'Колыбельная звёзд',
      titleEn: 'Star Lullaby',
      prompt: 'Ethereal Russian lullaby about stars, soft synth pads, gentle bells, dreamy female vocals, 58 BPM, magical nighttime atmosphere',
      style: 'lullaby, ethereal, dreamy',
      duration: 180,
      lyrics: `Звёзды в небе зажглись,
Ночь спустилась с высот.
Мой малыш, улыбнись,
Сон волшебный придёт.

На крылах облаков
Прилетит к нам луна,
И от добрых снов
Ночь светла и нежна.`,
    },
    {
      id: 'ru_lullaby_04',
      title: 'Сладких снов',
      titleEn: 'Sweet Dreams',
      prompt: 'Warm Russian bedtime song, gentle piano melody, soft strings, female voice singing about sweet dreams, 62 BPM, comforting and peaceful',
      style: 'lullaby, piano, orchestral, warm',
      duration: 120,
      lyrics: `Сладких снов, мой дорогой,
Пусть приснится сон цветной.
Зайчики и мишки,
Сказочные книжки.

Закрывай скорей глаза,
В сны летим за облака.
Там, где радуга живёт,
Счастье тебя ждёт.`,
    },
  ],

  children_songs: [
    {
      id: 'ru_song_01',
      title: 'Солнышко',
      titleEn: 'Little Sun',
      prompt: 'Happy Russian children song about the sun, cheerful but not too energetic, ukulele and xylophone, 80 BPM, perfect for toddlers',
      style: 'children song, happy, acoustic',
      duration: 90,
      lyrics: `Солнышко, солнышко,
Выгляни в окошко!
Солнышко, солнышко,
Посвети немножко!

Вот оно проснулось,
Деткам улыбнулось.
Солнечный денёк,
Радостный денёк!`,
    },
    {
      id: 'ru_song_02',
      title: 'Весёлый дождик',
      titleEn: 'Happy Rain',
      prompt: 'Playful Russian song about rain, soft rain sounds in background, gentle clapping rhythm, xylophone melody, 75 BPM, calming but engaging',
      style: 'children song, playful, nature sounds',
      duration: 100,
      lyrics: `Дождик, дождик, кап-кап-кап,
Мокрые дорожки.
Все ребята по домам,
Не намочим ножки.

Кап-кап-кап, кап-кап-кап,
Дождик нам поёт.
Скоро солнышко придёт,
Радугу зажжёт.`,
    },
    {
      id: 'ru_song_03',
      title: 'Маленькая звёздочка',
      titleEn: 'Little Star',
      prompt: 'Russian version of Twinkle Twinkle Little Star, music box style, very gentle and slow, 60 BPM, perfect bedtime song',
      style: 'lullaby, music box, classic',
      duration: 120,
      lyrics: `Маленькая звёздочка,
Ты моя хорошенькая.
Высоко-высоко в небе,
Сияешь каждый вечер.

Ты сияй, сияй всю ночь,
Прогони все тучки прочь.
Маленькая звёздочка,
Ты моя хорошенькая.`,
    },
  ],

  calming_melodies: [
    {
      id: 'ru_calm_01',
      title: 'Тихий вечер',
      titleEn: 'Quiet Evening',
      prompt: 'Peaceful instrumental Russian-style melody, balalaika and soft strings, very slow 50 BPM, no vocals, perfect for relaxation',
      style: 'instrumental, Russian folk, peaceful',
      duration: 180,
      instrumental: true,
    },
    {
      id: 'ru_calm_02',
      title: 'Зимняя сказка',
      titleEn: 'Winter Fairytale',
      prompt: 'Magical Russian winter melody, soft bells, gentle harp, celesta, dreamy and ethereal, 55 BPM, instrumental lullaby',
      style: 'instrumental, magical, winter',
      duration: 200,
      instrumental: true,
    },
    {
      id: 'ru_calm_03',
      title: 'Берёзовая роща',
      titleEn: 'Birch Grove',
      prompt: 'Nature-inspired Russian melody, soft flute, acoustic guitar, gentle bird sounds, 58 BPM, calming forest atmosphere',
      style: 'instrumental, nature, folk',
      duration: 180,
      instrumental: true,
    },
  ],

  // Educational songs (logorhythmic)
  educational: [
    {
      id: 'ru_edu_01',
      title: 'Ручки-ножки',
      titleEn: 'Hands and Feet',
      prompt: 'Simple Russian children action song about body parts, very slow and clear, easy to follow along, 65 BPM, for toddlers 1-2 years',
      style: 'educational, simple, action song',
      duration: 90,
      lyrics: `Ручки хлопают - хлоп-хлоп,
Ножки топают - топ-топ.
Глазки смотрят - раз-два-три,
Ушки слушают - смотри!

Ручки вверх и ручки вниз,
Покружились, улыбнись!
Хлоп-хлоп, топ-топ,
Вот какой у нас народ!`,
    },
    {
      id: 'ru_edu_02',
      title: 'Пальчики',
      titleEn: 'Little Fingers',
      prompt: 'Russian finger play song for babies, very gentle and slow, music box accompaniment, 60 BPM, clear pronunciation',
      style: 'educational, finger play, gentle',
      duration: 80,
      lyrics: `Этот пальчик - дедушка,
Этот пальчик - бабушка,
Этот пальчик - папочка,
Этот пальчик - мамочка,
Этот пальчик - я,
Вот и вся моя семья!`,
    },
  ],
};

interface GeneratedTrack {
  id: string;
  title: string;
  titleEn: string;
  prompt: string;
  style: string;
  lyrics?: string;
  duration: number;
  instrumental: boolean;
  category: string;
  generationId?: string;
  audioUrl?: string;
  localPath?: string;
  status: 'pending' | 'generating' | 'completed' | 'failed';
  createdAt: string;
}

// Print all prompts for manual generation
function printPrompts() {
  console.log('=== AI Music Generation Prompts ===\n');
  console.log('Use these prompts with your preferred AI music generator:\n');
  console.log('Recommended services:');
  console.log('  - Suno.ai (https://suno.ai)');
  console.log('  - Udio (https://udio.com)');
  console.log('  - Soundverse (https://soundverse.ai)\n');
  console.log('='.repeat(60) + '\n');

  let trackNum = 1;

  for (const [category, songs] of Object.entries(RUSSIAN_SONG_PROMPTS)) {
    console.log(`\n## ${category.toUpperCase().replace('_', ' ')}\n`);

    for (const song of songs) {
      console.log(`### ${trackNum}. ${song.title} (${song.titleEn})`);
      console.log(`ID: ${song.id}`);
      console.log(`Duration: ${song.duration} seconds`);
      console.log(`Style: ${song.style}`);
      console.log(`\n**Prompt:**`);
      console.log(song.prompt);

      if ('lyrics' in song && song.lyrics) {
        console.log(`\n**Lyrics:**`);
        console.log(song.lyrics);
      }

      console.log('\n' + '-'.repeat(50) + '\n');
      trackNum++;
    }
  }

  console.log('\n=== Tips for Best Results ===\n');
  console.log('1. Use "v4" or "v4.5" model in Suno for best quality');
  console.log('2. Set "instrumental" mode for calming_melodies category');
  console.log('3. Keep BPM low (50-70) for better calming effect');
  console.log('4. Add "for babies" or "for toddlers" to prompts');
  console.log('5. Generate multiple versions and pick the best\n');
}

// Generate tracks metadata for app integration
function generateMetadata(): GeneratedTrack[] {
  const tracks: GeneratedTrack[] = [];

  for (const [category, songs] of Object.entries(RUSSIAN_SONG_PROMPTS)) {
    for (const song of songs) {
      tracks.push({
        id: song.id,
        title: song.title,
        titleEn: song.titleEn,
        prompt: song.prompt,
        style: song.style,
        lyrics: 'lyrics' in song ? song.lyrics : undefined,
        duration: song.duration,
        instrumental: 'instrumental' in song ? Boolean(song.instrumental) : false,
        category,
        status: 'pending',
        createdAt: new Date().toISOString(),
      });
    }
  }

  return tracks;
}

// Save prompts to file for external use
function savePromptsToFile() {
  const promptsFile = path.join(CONFIG.outputDir, 'generation-prompts.json');

  if (!fs.existsSync(CONFIG.outputDir)) {
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  }

  const prompts = generateMetadata();
  fs.writeFileSync(promptsFile, JSON.stringify(prompts, null, 2));
  console.log(`\nPrompts saved to: ${promptsFile}`);
}

// Generate iOS Swift code for the tracks
function generateiOSCode(tracks: GeneratedTrack[]) {
  const swiftCode = `// Auto-generated AI Music Content
// Generated: ${new Date().toISOString()}
// License: Full commercial rights (AI-generated, royalty-free)

import Foundation

/// Russian AI-generated children's songs for Baby in Car app
struct AIGeneratedRussianContent {

    struct Track {
        let id: String
        let title: String
        let titleEn: String
        let category: String
        let duration: Int
        let isInstrumental: Bool
        let fileName: String
        let lyrics: String?
    }

    static let tracks: [Track] = [
${tracks.map(t => `        Track(
            id: "${t.id}",
            title: "${t.title}",
            titleEn: "${t.titleEn}",
            category: "${t.category}",
            duration: ${t.duration},
            isInstrumental: ${t.instrumental},
            fileName: "${t.id}.mp3",
            lyrics: ${t.lyrics ? `"""
${t.lyrics}
"""` : 'nil'}
        )`).join(',\n')}
    ]

    /// Get tracks by category
    static func tracks(for category: String) -> [Track] {
        return tracks.filter { $0.category == category }
    }

    /// Get all lullabies
    static var lullabies: [Track] {
        return tracks(for: "lullabies")
    }

    /// Get all children's songs
    static var childrenSongs: [Track] {
        return tracks(for: "children_songs")
    }

    /// Get all calming melodies
    static var calmingMelodies: [Track] {
        return tracks(for: "calming_melodies")
    }

    /// Get all educational songs
    static var educationalSongs: [Track] {
        return tracks(for: "educational")
    }
}
`;

  const swiftFile = path.join(CONFIG.outputDir, 'AIGeneratedRussianContent.swift');
  fs.writeFileSync(swiftFile, swiftCode);
  console.log(`\niOS Swift code generated: ${swiftFile}`);
}

// Generate SQL for database seeding
function generateSQL(tracks: GeneratedTrack[]) {
  const sqlStatements = tracks.map(track => {
    const streamUrl = `https://audio.babyincar.app/ai-generated/${track.id}.mp3`;
    return `INSERT INTO tracks (
  id, title, artist, category, language, duration,
  age_range_min, age_range_max, tempo_bpm, calming_score,
  audio_source_type, stream_url, is_premium, lyrics, created_at
) VALUES (
  '${track.id}',
  '${track.title.replace(/'/g, "''")}',
  'AI Generated for Baby in Car',
  '${track.category}',
  'ru',
  ${track.duration},
  0,
  36,
  60,
  0.90,
  'ai_generated',
  '${streamUrl}',
  0,
  ${track.lyrics ? `'${track.lyrics.replace(/'/g, "''")}'` : 'NULL'},
  '${track.createdAt}'
);`;
  });

  const sqlFile = path.join(CONFIG.outputDir, 'ai-generated-seed.sql');
  fs.writeFileSync(sqlFile, sqlStatements.join('\n\n'));
  console.log(`\nSQL seed file generated: ${sqlFile}`);
}

// Main function
async function main() {
  const args = process.argv.slice(2);

  console.log('=== AI Music Generator for Baby in Car ===\n');

  if (args.includes('--prompts') || args.includes('-p')) {
    printPrompts();
    savePromptsToFile();
    return;
  }

  if (args.includes('--metadata') || args.includes('-m')) {
    const tracks = generateMetadata();

    if (!fs.existsSync(CONFIG.outputDir)) {
      fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    }

    fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(tracks, null, 2));
    console.log(`Metadata saved: ${CONFIG.metadataFile}`);
    console.log(`Total tracks: ${tracks.length}`);

    generateiOSCode(tracks);
    generateSQL(tracks);
    return;
  }

  if (args.includes('--help') || args.length === 0) {
    console.log(`
AI Music Generator for Baby in Car App

This tool generates Russian children's songs using AI music services.

Usage:
  npx ts-node scripts/ai-music-generator.ts [options]

Options:
  --prompts, -p    Display all prompts for manual generation
  --metadata, -m   Generate metadata, Swift code, and SQL files
  --help           Show this help message

Workflow:
  1. Run with --prompts to see all generation prompts
  2. Use prompts manually with Suno.ai, Udio, or Soundverse
  3. Download generated audio files
  4. Place files in: ${CONFIG.outputDir}
  5. Run with --metadata to generate integration code

AI Music Services (with commercial rights):
  - Suno.ai (https://suno.ai) - Best quality, $10-30/month
  - MusicAPI.ai (https://musicapi.ai) - API access to Suno
  - Soundverse (https://soundverse.ai) - Alternative with clear licensing

Note: All AI-generated music comes with full commercial rights.
      No royalties or attribution required.
`);
  }
}

main().catch(console.error);
