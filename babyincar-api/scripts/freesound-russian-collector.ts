/**
 * Freesound Russian Content Collector
 *
 * This script searches Freesound.org for Russian-language children's content
 * with CC0 (Creative Commons Zero) license.
 *
 * Usage:
 *   FREESOUND_API_KEY=your_key npx ts-node scripts/freesound-russian-collector.ts
 *
 * Get API key at: https://freesound.org/apiv2/apply
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';

// Configuration
const CONFIG = {
  freesound: {
    apiKey: process.env.FREESOUND_API_KEY || '',
    baseUrl: 'https://freesound.org/apiv2',
  },
  outputDir: path.join(__dirname, '../audio-library/russian'),
  metadataFile: path.join(__dirname, '../audio-library/russian-metadata.json'),

  // Russian search queries for children's content
  russianQueries: {
    lullabies: [
      'колыбельная',           // lullaby
      'баюшки баю',           // hush-a-bye
      'спи малыш',            // sleep baby
      'колыбельная песня',    // lullaby song
      'детская колыбельная',  // children's lullaby
    ],
    nature_sounds: [
      'дождь звук',           // rain sound
      'море волны',           // sea waves
      'лес птицы',            // forest birds
      'ручей',                // stream
      'природа успокаивающая', // nature calming
    ],
    children_music: [
      'детская музыка',       // children's music
      'музыка для детей',     // music for children
      'baby music russian',
      'russian lullaby',
      'детская песенка',      // children's song
    ],
    white_noise: [
      'белый шум',            // white noise
      'шум дождя',            // rain noise
      'розовый шум',          // pink noise
    ],
    // Also search in English for Russian-tagged content
    english_with_russian_tags: [
      'lullaby russian',
      'russian baby',
      'russian children song',
      'slavic lullaby',
    ],
  },

  minDuration: 30,   // seconds
  maxDuration: 600,  // 10 minutes
};

interface FreesoundSound {
  id: number;
  name: string;
  tags: string[];
  license: string;
  username: string;
  duration: number;
  filesize: number;
  type: string;
  previews: {
    'preview-hq-mp3': string;
    'preview-lq-mp3': string;
    'preview-hq-ogg': string;
  };
  description: string;
  avg_rating: number;
  num_downloads: number;
}

interface FreesoundSearchResult {
  count: number;
  results: FreesoundSound[];
  next: string | null;
}

interface AudioMetadata {
  id: string;
  source: 'freesound';
  sourceId: string;
  title: string;
  titleRussian?: string;
  artist: string;
  category: string;
  subcategory: string;
  language: 'ru' | 'en' | 'unknown';
  duration: number;
  fileSize: number;
  format: string;
  license: string;
  licenseUrl: string;
  sourceUrl: string;
  downloadUrl: string;
  previewUrl: string;
  localPath?: string;
  tags: string[];
  calmingScore: number;
  ageRangeMin: number;
  ageRangeMax: number;
  isPremium: boolean;
  createdAt: string;
}

// Utility functions
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function generateId(): string {
  return `ru_audio_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

async function fetchJson<T>(url: string): Promise<T> {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${data.substring(0, 200)}`));
        }
      });
    }).on('error', reject);
  });
}

async function downloadFile(url: string, destPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    const file = fs.createWriteStream(destPath);

    const request = (currentUrl: string) => {
      https.get(currentUrl, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          const redirectUrl = res.headers.location;
          if (redirectUrl) {
            request(redirectUrl);
            return;
          }
        }

        if (res.statusCode !== 200) {
          file.close();
          fs.unlink(destPath, () => {});
          resolve(false);
          return;
        }

        res.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve(true);
        });
      }).on('error', () => {
        file.close();
        fs.unlink(destPath, () => {});
        resolve(false);
      });
    };

    request(url);
  });
}

// Check if content is Russian-related
function isRussianRelated(sound: FreesoundSound): boolean {
  const russianIndicators = [
    'russian', 'russia', 'ru', 'русский', 'русская', 'россия',
    'колыбельная', 'детская', 'малыш', 'ребенок', 'slavic', 'slavonic'
  ];

  const textToCheck = [
    sound.name.toLowerCase(),
    sound.description.toLowerCase(),
    ...sound.tags.map(t => t.toLowerCase())
  ].join(' ');

  return russianIndicators.some(indicator => textToCheck.includes(indicator));
}

// Detect language from text
function detectLanguage(sound: FreesoundSound): 'ru' | 'en' | 'unknown' {
  const textToCheck = sound.name + ' ' + sound.description + ' ' + sound.tags.join(' ');

  // Check for Cyrillic characters
  if (/[а-яА-ЯёЁ]/.test(textToCheck)) {
    return 'ru';
  }

  return 'unknown';
}

// Calculate calming score
function calculateCalmingScore(sound: FreesoundSound): number {
  let score = sound.avg_rating / 5 * 0.5;

  const calmingTags = ['relaxing', 'calm', 'soothing', 'peaceful', 'gentle', 'soft',
                       'ambient', 'sleep', 'lullaby', 'baby', 'колыбельная', 'спокойный'];
  const energeticTags = ['loud', 'harsh', 'intense', 'energetic', 'fast', 'громкий'];

  const tags = sound.tags.map(t => t.toLowerCase());

  calmingTags.forEach(tag => {
    if (tags.some(t => t.includes(tag))) score += 0.08;
  });

  energeticTags.forEach(tag => {
    if (tags.some(t => t.includes(tag))) score -= 0.1;
  });

  if (sound.duration >= 60) score += 0.05;
  if (sound.duration >= 180) score += 0.05;

  return Math.max(0.3, Math.min(1, score));
}

class FreesoundRussianCollector {
  private apiKey: string;
  private baseUrl: string;
  private lastRequestTime = 0;

  constructor() {
    this.apiKey = CONFIG.freesound.apiKey;
    this.baseUrl = CONFIG.freesound.baseUrl;
  }

  private async rateLimit(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;
    if (elapsed < 1100) { // ~1 request per second to stay under 60/min
      await sleep(1100 - elapsed);
    }
    this.lastRequestTime = Date.now();
  }

  async searchSounds(query: string, page = 1): Promise<FreesoundSearchResult> {
    await this.rateLimit();

    const params = new URLSearchParams({
      query,
      page: page.toString(),
      page_size: '30',
      filter: 'license:"Creative Commons 0" duration:[30 TO 600]',
      fields: 'id,name,tags,license,username,duration,filesize,type,previews,description,avg_rating,num_downloads',
      sort: 'downloads_desc',
    });

    const url = `${this.baseUrl}/search/text/?${params}&token=${this.apiKey}`;

    try {
      return await fetchJson<FreesoundSearchResult>(url);
    } catch (error) {
      console.error(`Search failed for "${query}":`, error);
      return { count: 0, results: [], next: null };
    }
  }

  async collectCategory(category: string, queries: string[]): Promise<AudioMetadata[]> {
    const results: AudioMetadata[] = [];
    const seenIds = new Set<number>();

    for (const query of queries) {
      console.log(`  Searching: "${query}"...`);

      try {
        const searchResult = await this.searchSounds(query);
        console.log(`    Found ${searchResult.count} total (showing ${searchResult.results.length})`);

        let addedCount = 0;

        for (const sound of searchResult.results) {
          // Skip duplicates
          if (seenIds.has(sound.id)) continue;
          seenIds.add(sound.id);

          // Filter by format and duration
          if (!['mp3', 'ogg', 'wav'].includes(sound.type)) continue;
          if (sound.duration < CONFIG.minDuration || sound.duration > CONFIG.maxDuration) continue;

          const language = detectLanguage(sound);

          const metadata: AudioMetadata = {
            id: generateId(),
            source: 'freesound',
            sourceId: sound.id.toString(),
            title: sound.name.replace(/[_-]/g, ' ').trim(),
            artist: sound.username,
            category,
            subcategory: query,
            language,
            duration: Math.round(sound.duration),
            fileSize: sound.filesize,
            format: sound.type,
            license: 'CC0',
            licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
            sourceUrl: `https://freesound.org/s/${sound.id}`,
            downloadUrl: `https://freesound.org/apiv2/sounds/${sound.id}/download/`,
            previewUrl: sound.previews['preview-hq-mp3'] || sound.previews['preview-lq-mp3'],
            tags: sound.tags.slice(0, 15),
            calmingScore: calculateCalmingScore(sound),
            ageRangeMin: 0,
            ageRangeMax: 36,
            isPremium: false,
            createdAt: new Date().toISOString(),
          };

          results.push(metadata);
          addedCount++;
        }

        console.log(`    Added: ${addedCount} sounds`);
        await sleep(300);

      } catch (error) {
        console.error(`    Error: ${error}`);
      }
    }

    return results;
  }

  async collectAll(): Promise<AudioMetadata[]> {
    if (!this.apiKey) {
      console.error('\nError: FREESOUND_API_KEY not set.');
      console.error('Get your API key at: https://freesound.org/apiv2/apply\n');
      return [];
    }

    const allResults: AudioMetadata[] = [];

    for (const [category, queries] of Object.entries(CONFIG.russianQueries)) {
      console.log(`\nCollecting ${category}...`);
      const results = await this.collectCategory(category, queries);
      allResults.push(...results);
      console.log(`  Category total: ${results.length}`);
    }

    return allResults;
  }

  async downloadPreviews(metadata: AudioMetadata[]): Promise<void> {
    const toDownload = metadata.filter(m => m.previewUrl && !m.localPath);

    console.log(`\nDownloading ${toDownload.length} preview files...`);

    // Ensure directory exists
    if (!fs.existsSync(CONFIG.outputDir)) {
      fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    }

    for (let i = 0; i < toDownload.length; i++) {
      const audio = toDownload[i];
      const ext = 'mp3'; // Previews are always mp3
      const filename = `${audio.id}.${ext}`;
      const filepath = path.join(CONFIG.outputDir, filename);

      process.stdout.write(`[${i + 1}/${toDownload.length}] ${audio.title.substring(0, 40)}... `);

      const success = await downloadFile(audio.previewUrl, filepath);

      if (success) {
        const stats = fs.statSync(filepath);
        if (stats.size > 10000) { // At least 10KB
          audio.localPath = filepath;
          console.log('OK');
        } else {
          fs.unlinkSync(filepath);
          console.log('Too small, skipped');
        }
      } else {
        console.log('Failed');
      }

      await sleep(200);
    }
  }
}

async function main() {
  console.log('=== Freesound Russian Content Collector ===\n');
  console.log('This script searches for CC0-licensed Russian children\'s audio.\n');

  const collector = new FreesoundRussianCollector();

  // Collect metadata
  const allMetadata = await collector.collectAll();

  if (allMetadata.length === 0) {
    console.log('\nNo sounds collected. Check your API key.');
    return;
  }

  // Remove duplicates
  const uniqueMetadata = Array.from(
    new Map(allMetadata.map(m => [m.sourceId, m])).values()
  );

  console.log(`\n=== Collection Summary ===`);
  console.log(`Total unique sounds: ${uniqueMetadata.length}`);

  // Summary by category
  const byCategory = uniqueMetadata.reduce((acc, m) => {
    acc[m.category] = (acc[m.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  console.log('\nBy category:');
  Object.entries(byCategory).forEach(([cat, count]) => {
    console.log(`  ${cat}: ${count}`);
  });

  // Summary by language
  const byLanguage = uniqueMetadata.reduce((acc, m) => {
    acc[m.language] = (acc[m.language] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  console.log('\nBy detected language:');
  Object.entries(byLanguage).forEach(([lang, count]) => {
    console.log(`  ${lang}: ${count}`);
  });

  // Save metadata
  if (!fs.existsSync(path.dirname(CONFIG.metadataFile))) {
    fs.mkdirSync(path.dirname(CONFIG.metadataFile), { recursive: true });
  }
  fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(uniqueMetadata, null, 2));
  console.log(`\nMetadata saved to: ${CONFIG.metadataFile}`);

  // Ask to download
  const args = process.argv.slice(2);
  if (args.includes('--download')) {
    await collector.downloadPreviews(uniqueMetadata);

    // Update metadata with local paths
    fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(uniqueMetadata, null, 2));

    const downloaded = uniqueMetadata.filter(m => m.localPath).length;
    console.log(`\n=== Download Complete ===`);
    console.log(`Successfully downloaded: ${downloaded} files`);
    console.log(`Files saved to: ${CONFIG.outputDir}`);
  } else {
    console.log('\nTo download preview files, run with --download flag');
  }

  // Generate TypeScript content for iOS app
  console.log('\n=== Generating iOS Integration Code ===');
  generateiOSContent(uniqueMetadata.filter(m => m.localPath));
}

function generateiOSContent(metadata: AudioMetadata[]) {
  if (metadata.length === 0) {
    console.log('No downloaded files to generate iOS code for.');
    return;
  }

  const swiftCode = `// Auto-generated Russian audio content
// Generated: ${new Date().toISOString()}
// Source: Freesound.org (CC0 License)

import Foundation

struct RussianAudioContent {
    static let tracks: [(title: String, fileName: String, category: String, duration: Int, calmingScore: Double)] = [
${metadata.map(m => `        ("${m.title.replace(/"/g, '\\"')}", "${path.basename(m.localPath || '')}", "${m.category}", ${m.duration}, ${m.calmingScore.toFixed(2)})`).join(',\n')}
    ]

    // Attribution (CC0 - not required but nice to have)
    static let attributions: [String: String] = [
${metadata.map(m => `        "${path.basename(m.localPath || '')}": "By ${m.artist} from Freesound.org (CC0)"`).join(',\n')}
    ]
}
`;

  const iosCodePath = path.join(__dirname, '../audio-library/RussianAudioContent.swift');
  fs.writeFileSync(iosCodePath, swiftCode);
  console.log(`iOS Swift code generated: ${iosCodePath}`);
}

main().catch(console.error);
