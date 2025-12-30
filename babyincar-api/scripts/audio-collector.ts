/**
 * Audio Content Collector for Baby in Car App
 *
 * This script collects royalty-free audio files from multiple sources:
 * - Freesound.org (CC0 sounds via API)
 * - Internet Archive (public domain audio)
 * - Pixabay (royalty-free sounds)
 *
 * Audio is downloaded, processed, and uploaded to Cloudflare R2.
 *
 * Usage:
 *   npx ts-node scripts/audio-collector.ts --collect
 *   npx ts-node scripts/audio-collector.ts --upload
 *   npx ts-node scripts/audio-collector.ts --seed
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';

// Configuration
const CONFIG = {
  // Freesound API (requires API key from https://freesound.org/apiv2/apply)
  freesound: {
    apiKey: process.env.FREESOUND_API_KEY || '',
    baseUrl: 'https://freesound.org/apiv2',
    rateLimit: 60, // requests per minute
  },
  // Output directories
  outputDir: path.join(__dirname, '../audio-library'),
  metadataFile: path.join(__dirname, '../audio-library/metadata.json'),
  // Categories to collect
  categories: {
    white_noise: [
      'white noise', 'pink noise', 'brown noise', 'static noise',
      'fan noise', 'air conditioner', 'vacuum cleaner sound',
    ],
    nature_sounds: [
      'rain sound', 'ocean waves', 'river stream', 'wind sounds',
      'birds chirping gentle', 'thunderstorm distant', 'forest ambience',
    ],
    instrumental: [
      'music box lullaby', 'soft piano melody', 'gentle guitar',
      'wind chimes', 'harp music soothing', 'bells gentle',
    ],
    classical_music: [
      'brahms lullaby', 'mozart lullaby', 'bach air',
      'debussy clair de lune', 'chopin nocturne', 'pachelbel canon',
    ],
    children_songs: [
      'twinkle twinkle little star', 'rock a bye baby',
      'hush little baby', 'lullaby baby song',
    ],
  },
  // Quality requirements
  minDuration: 30, // seconds
  maxDuration: 600, // 10 minutes
  preferredFormats: ['mp3', 'ogg', 'wav'],
};

// Types
interface AudioMetadata {
  id: string;
  source: 'freesound' | 'internet_archive' | 'pixabay' | 'bundled';
  sourceId: string;
  title: string;
  artist: string;
  category: string;
  subcategory: string;
  duration: number;
  fileSize: number;
  format: string;
  license: string;
  licenseUrl: string;
  sourceUrl: string;
  downloadUrl: string;
  localPath?: string;
  r2Key?: string;
  tags: string[];
  calmingScore: number;
  ageRangeMin: number;
  ageRangeMax: number;
  isPremium: boolean;
  createdAt: string;
}

interface FreesoundSearchResult {
  count: number;
  results: FreesoundSound[];
  next: string | null;
}

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

// Utility functions
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function generateId(): string {
  return `audio_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

async function fetchJson<T>(url: string, headers: Record<string, string> = {}): Promise<T> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const req = protocol.get(url, { headers }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${data.substring(0, 100)}`));
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

async function downloadFile(url: string, destPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);
    const protocol = url.startsWith('https') ? https : http;

    const request = (currentUrl: string) => {
      protocol.get(currentUrl, (res) => {
        // Handle redirects
        if (res.statusCode === 301 || res.statusCode === 302) {
          const redirectUrl = res.headers.location;
          if (redirectUrl) {
            request(redirectUrl);
            return;
          }
        }

        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode}`));
          return;
        }

        res.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      }).on('error', (err) => {
        fs.unlink(destPath, () => {}); // Delete failed file
        reject(err);
      });
    };

    request(url);
  });
}

function calculateCalmingScore(sound: FreesoundSound): number {
  // Base score from rating
  let score = sound.avg_rating / 5;

  // Adjust based on tags
  const calmingTags = ['relaxing', 'calm', 'soothing', 'peaceful', 'gentle', 'soft', 'ambient'];
  const energeticTags = ['loud', 'harsh', 'intense', 'energetic', 'fast'];

  const tags = sound.tags.map(t => t.toLowerCase());

  calmingTags.forEach(tag => {
    if (tags.some(t => t.includes(tag))) score += 0.1;
  });

  energeticTags.forEach(tag => {
    if (tags.some(t => t.includes(tag))) score -= 0.1;
  });

  // Prefer longer durations for sleep sounds
  if (sound.duration >= 60) score += 0.05;
  if (sound.duration >= 180) score += 0.05;

  return Math.max(0, Math.min(1, score));
}

function determineAgeRange(category: string, tags: string[]): { min: number; max: number } {
  // All sounds are generally suitable for babies 0-36 months
  // but some categories have specific optimal ranges
  const tagStr = tags.join(' ').toLowerCase();

  if (category === 'white_noise' || category === 'nature_sounds') {
    return { min: 0, max: 36 }; // Great for all ages
  }

  if (category === 'classical_music' || category === 'instrumental') {
    return { min: 0, max: 36 };
  }

  if (category === 'children_songs') {
    return { min: 3, max: 36 }; // Better for older babies
  }

  if (category === 'fairy_tales') {
    return { min: 12, max: 36 }; // For babies who understand language
  }

  return { min: 0, max: 36 };
}

// Freesound collector
class FreesoundCollector {
  private apiKey: string;
  private baseUrl: string;
  private requestCount = 0;
  private lastRequestTime = 0;

  constructor() {
    this.apiKey = CONFIG.freesound.apiKey;
    this.baseUrl = CONFIG.freesound.baseUrl;
  }

  private async rateLimit(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;

    if (elapsed < 1000) {
      await sleep(1000 - elapsed);
    }

    this.lastRequestTime = Date.now();
    this.requestCount++;
  }

  async searchSounds(query: string, page = 1, pageSize = 15): Promise<FreesoundSearchResult> {
    await this.rateLimit();

    const params = new URLSearchParams({
      query,
      page: page.toString(),
      page_size: pageSize.toString(),
      filter: 'license:"Creative Commons 0" duration:[30 TO 600]',
      fields: 'id,name,tags,license,username,duration,filesize,type,previews,description,avg_rating,num_downloads',
      sort: 'rating_desc',
    });

    const url = `${this.baseUrl}/search/text/?${params}&token=${this.apiKey}`;

    try {
      return await fetchJson<FreesoundSearchResult>(url);
    } catch (error) {
      console.error(`Search failed for "${query}":`, error);
      return { count: 0, results: [], next: null };
    }
  }

  async collectCategory(category: string, searchTerms: string[]): Promise<AudioMetadata[]> {
    const results: AudioMetadata[] = [];

    for (const term of searchTerms) {
      console.log(`  Searching: "${term}"...`);

      try {
        const searchResult = await this.searchSounds(term);
        console.log(`    Found ${searchResult.count} sounds (showing ${searchResult.results.length})`);

        for (const sound of searchResult.results) {
          // Filter by format and duration
          if (!CONFIG.preferredFormats.includes(sound.type)) continue;
          if (sound.duration < CONFIG.minDuration || sound.duration > CONFIG.maxDuration) continue;

          const ageRange = determineAgeRange(category, sound.tags);

          const metadata: AudioMetadata = {
            id: generateId(),
            source: 'freesound',
            sourceId: sound.id.toString(),
            title: sound.name.replace(/[_-]/g, ' ').trim(),
            artist: sound.username,
            category,
            subcategory: term,
            duration: Math.round(sound.duration),
            fileSize: sound.filesize,
            format: sound.type,
            license: 'CC0',
            licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
            sourceUrl: `https://freesound.org/s/${sound.id}`,
            downloadUrl: sound.previews['preview-hq-mp3'] || sound.previews['preview-lq-mp3'],
            tags: sound.tags.slice(0, 10),
            calmingScore: calculateCalmingScore(sound),
            ageRangeMin: ageRange.min,
            ageRangeMax: ageRange.max,
            isPremium: false, // CC0 content is free
            createdAt: new Date().toISOString(),
          };

          results.push(metadata);
        }

        // Add delay between searches
        await sleep(500);

      } catch (error) {
        console.error(`    Error searching "${term}":`, error);
      }
    }

    return results;
  }

  async collectAll(): Promise<AudioMetadata[]> {
    if (!this.apiKey) {
      console.error('FREESOUND_API_KEY not set. Get one at https://freesound.org/apiv2/apply');
      return [];
    }

    const allResults: AudioMetadata[] = [];

    for (const [category, terms] of Object.entries(CONFIG.categories)) {
      console.log(`\nCollecting ${category}...`);
      const results = await this.collectCategory(category, terms);
      allResults.push(...results);
      console.log(`  Total: ${results.length} sounds`);
    }

    return allResults;
  }
}

// Internet Archive collector (for public domain classical music)
class InternetArchiveCollector {
  async searchItems(query: string, mediaType = 'audio'): Promise<any[]> {
    const params = new URLSearchParams({
      q: `${query} AND mediatype:${mediaType} AND licenseurl:*publicdomain*`,
      fl: 'identifier,title,creator,description,item_size',
      rows: '50',
      output: 'json',
    });

    const url = `https://archive.org/advancedsearch.php?${params}`;

    try {
      const result = await fetchJson<any>(url);
      return result.response?.docs || [];
    } catch (error) {
      console.error('Internet Archive search failed:', error);
      return [];
    }
  }

  async getItemFiles(identifier: string): Promise<any[]> {
    const url = `https://archive.org/metadata/${identifier}/files`;

    try {
      const result = await fetchJson<any>(url);
      return result.result || [];
    } catch (error) {
      console.error(`Failed to get files for ${identifier}:`, error);
      return [];
    }
  }

  async collectClassicalMusic(): Promise<AudioMetadata[]> {
    const results: AudioMetadata[] = [];
    const queries = ['lullaby classical', 'baby sleep music', 'brahms lullaby'];

    for (const query of queries) {
      console.log(`  Searching Internet Archive: "${query}"...`);
      const items = await this.searchItems(query);

      for (const item of items.slice(0, 10)) {
        const files = await this.getItemFiles(item.identifier);
        const audioFiles = files.filter((f: any) =>
          f.format === 'VBR MP3' || f.format === 'Ogg Vorbis'
        );

        for (const file of audioFiles.slice(0, 3)) {
          if (!file.length || parseFloat(file.length) < 30) continue;

          const metadata: AudioMetadata = {
            id: generateId(),
            source: 'internet_archive',
            sourceId: `${item.identifier}/${file.name}`,
            title: file.title || file.name.replace(/\.[^.]+$/, '').replace(/[_-]/g, ' '),
            artist: item.creator || 'Unknown',
            category: 'classical_music',
            subcategory: query,
            duration: Math.round(parseFloat(file.length) || 180),
            fileSize: parseInt(file.size) || 0,
            format: file.format.includes('MP3') ? 'mp3' : 'ogg',
            license: 'Public Domain',
            licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/',
            sourceUrl: `https://archive.org/details/${item.identifier}`,
            downloadUrl: `https://archive.org/download/${item.identifier}/${encodeURIComponent(file.name)}`,
            tags: ['classical', 'lullaby', 'baby', 'sleep'],
            calmingScore: 0.8,
            ageRangeMin: 0,
            ageRangeMax: 36,
            isPremium: false,
            createdAt: new Date().toISOString(),
          };

          results.push(metadata);
        }

        await sleep(500);
      }
    }

    return results;
  }
}

// Curated bundled audio list (known royalty-free sources)
const CURATED_AUDIO: AudioMetadata[] = [
  // White Noise (these would be generated or from verified CC0 sources)
  {
    id: 'bundled_white_noise_1',
    source: 'bundled',
    sourceId: 'pure_white_noise',
    title: 'Pure White Noise',
    artist: 'Generated',
    category: 'white_noise',
    subcategory: 'white noise',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['white noise', 'sleep', 'baby', 'soothing'],
    calmingScore: 0.95,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_pink_noise_1',
    source: 'bundled',
    sourceId: 'pink_noise',
    title: 'Gentle Pink Noise',
    artist: 'Generated',
    category: 'white_noise',
    subcategory: 'pink noise',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['pink noise', 'sleep', 'baby', 'calming'],
    calmingScore: 0.92,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_brown_noise_1',
    source: 'bundled',
    sourceId: 'brown_noise',
    title: 'Deep Brown Noise',
    artist: 'Generated',
    category: 'white_noise',
    subcategory: 'brown noise',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['brown noise', 'deep', 'sleep', 'womb sounds'],
    calmingScore: 0.9,
    ageRangeMin: 0,
    ageRangeMax: 24,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  // Nature sounds (generated/synthesized)
  {
    id: 'bundled_rain_1',
    source: 'bundled',
    sourceId: 'rain_gentle',
    title: 'Gentle Rain',
    artist: 'Nature Sounds',
    category: 'nature_sounds',
    subcategory: 'rain',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['rain', 'nature', 'calming', 'sleep'],
    calmingScore: 0.88,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_ocean_1',
    source: 'bundled',
    sourceId: 'ocean_waves',
    title: 'Ocean Waves',
    artist: 'Nature Sounds',
    category: 'nature_sounds',
    subcategory: 'ocean',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['ocean', 'waves', 'nature', 'peaceful'],
    calmingScore: 0.85,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_heartbeat_1',
    source: 'bundled',
    sourceId: 'womb_heartbeat',
    title: 'Womb Heartbeat',
    artist: 'Generated',
    category: 'white_noise',
    subcategory: 'womb sounds',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['heartbeat', 'womb', 'baby', 'newborn'],
    calmingScore: 0.95,
    ageRangeMin: 0,
    ageRangeMax: 6,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  // Mechanical sounds
  {
    id: 'bundled_vacuum_1',
    source: 'bundled',
    sourceId: 'vacuum_sound',
    title: 'Vacuum Cleaner',
    artist: 'Household Sounds',
    category: 'white_noise',
    subcategory: 'household',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['vacuum', 'household', 'white noise', 'baby'],
    calmingScore: 0.82,
    ageRangeMin: 0,
    ageRangeMax: 12,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_fan_1',
    source: 'bundled',
    sourceId: 'fan_sound',
    title: 'Electric Fan',
    artist: 'Household Sounds',
    category: 'white_noise',
    subcategory: 'fan',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['fan', 'white noise', 'continuous', 'sleep'],
    calmingScore: 0.85,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_hairdryer_1',
    source: 'bundled',
    sourceId: 'hair_dryer',
    title: 'Hair Dryer',
    artist: 'Household Sounds',
    category: 'white_noise',
    subcategory: 'household',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['hair dryer', 'white noise', 'baby', 'calming'],
    calmingScore: 0.8,
    ageRangeMin: 0,
    ageRangeMax: 12,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 'bundled_car_1',
    source: 'bundled',
    sourceId: 'car_engine',
    title: 'Car Engine Ride',
    artist: 'Vehicle Sounds',
    category: 'white_noise',
    subcategory: 'vehicle',
    duration: 300,
    fileSize: 0,
    format: 'generated',
    license: 'Generated',
    licenseUrl: '',
    sourceUrl: '',
    downloadUrl: '',
    tags: ['car', 'engine', 'driving', 'baby'],
    calmingScore: 0.78,
    ageRangeMin: 0,
    ageRangeMax: 36,
    isPremium: false,
    createdAt: new Date().toISOString(),
  },
];

// Main execution
async function main() {
  const args = process.argv.slice(2);

  // Ensure output directory exists
  if (!fs.existsSync(CONFIG.outputDir)) {
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  }

  if (args.includes('--collect')) {
    console.log('=== Audio Content Collector ===\n');

    const allMetadata: AudioMetadata[] = [...CURATED_AUDIO];

    // Collect from Freesound
    if (CONFIG.freesound.apiKey) {
      console.log('Collecting from Freesound.org...');
      const freesoundCollector = new FreesoundCollector();
      const freesoundResults = await freesoundCollector.collectAll();
      allMetadata.push(...freesoundResults);
    } else {
      console.log('Skipping Freesound (no API key set)');
      console.log('  Set FREESOUND_API_KEY env variable to enable');
    }

    // Collect from Internet Archive
    console.log('\nCollecting from Internet Archive...');
    const iaCollector = new InternetArchiveCollector();
    const iaResults = await iaCollector.collectClassicalMusic();
    allMetadata.push(...iaResults);

    // Remove duplicates by source ID
    const uniqueMetadata = Array.from(
      new Map(allMetadata.map(m => [`${m.source}_${m.sourceId}`, m])).values()
    );

    // Save metadata
    fs.writeFileSync(
      CONFIG.metadataFile,
      JSON.stringify(uniqueMetadata, null, 2)
    );

    console.log(`\n=== Collection Complete ===`);
    console.log(`Total unique sounds: ${uniqueMetadata.length}`);
    console.log(`Metadata saved to: ${CONFIG.metadataFile}`);

    // Summary by category
    const byCategory = uniqueMetadata.reduce((acc, m) => {
      acc[m.category] = (acc[m.category] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    console.log('\nBy category:');
    Object.entries(byCategory).forEach(([cat, count]) => {
      console.log(`  ${cat}: ${count}`);
    });
  }

  if (args.includes('--download')) {
    console.log('=== Downloading Audio Files ===\n');

    if (!fs.existsSync(CONFIG.metadataFile)) {
      console.error('No metadata file found. Run --collect first.');
      return;
    }

    const metadata: AudioMetadata[] = JSON.parse(
      fs.readFileSync(CONFIG.metadataFile, 'utf-8')
    );

    // Only download non-bundled audio
    const toDownload = metadata.filter(m =>
      m.source !== 'bundled' && m.downloadUrl && !m.localPath
    );

    console.log(`Found ${toDownload.length} files to download\n`);

    for (let i = 0; i < toDownload.length; i++) {
      const audio = toDownload[i];
      const ext = audio.format === 'mp3' ? 'mp3' : 'ogg';
      const filename = `${audio.id}.${ext}`;
      const filepath = path.join(CONFIG.outputDir, filename);

      console.log(`[${i + 1}/${toDownload.length}] Downloading: ${audio.title}`);

      try {
        await downloadFile(audio.downloadUrl, filepath);
        audio.localPath = filepath;
        console.log(`  Saved to: ${filename}`);
      } catch (error) {
        console.error(`  Failed: ${error}`);
      }

      // Rate limiting
      await sleep(500);
    }

    // Update metadata
    fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(metadata, null, 2));
    console.log('\nMetadata updated with local paths');
  }

  if (args.includes('--generate-sql')) {
    console.log('=== Generating SQL Seed Data ===\n');

    if (!fs.existsSync(CONFIG.metadataFile)) {
      console.error('No metadata file found. Run --collect first.');
      return;
    }

    const metadata: AudioMetadata[] = JSON.parse(
      fs.readFileSync(CONFIG.metadataFile, 'utf-8')
    );

    const sqlStatements: string[] = [];

    for (const audio of metadata) {
      const streamUrl = audio.source === 'bundled'
        ? null
        : audio.r2Key
          ? `https://audio.babyincar.app/${audio.r2Key}`
          : audio.downloadUrl;

      const audioSourceType = audio.source === 'bundled' ? 'generated' : 'recorded';
      const generatorType = audio.source === 'bundled' ? audio.sourceId : null;

      const sql = `INSERT INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, artwork_url, is_premium, created_at)
VALUES ('${audio.id}', '${audio.title.replace(/'/g, "''")}', '${audio.artist.replace(/'/g, "''")}', '${audio.category}', 'en', ${audio.duration}, ${audio.ageRangeMin}, ${audio.ageRangeMax}, NULL, ${audio.calmingScore.toFixed(2)}, '${audioSourceType}', ${generatorType ? `'${generatorType}'` : 'NULL'}, ${streamUrl ? `'${streamUrl}'` : 'NULL'}, NULL, ${audio.isPremium ? 1 : 0}, '${audio.createdAt}');`;

      sqlStatements.push(sql);
    }

    const seedFile = path.join(__dirname, '../migrations/003_audio_seed.sql');
    fs.writeFileSync(seedFile, sqlStatements.join('\n\n'));

    console.log(`Generated ${sqlStatements.length} INSERT statements`);
    console.log(`Saved to: ${seedFile}`);
  }

  if (args.includes('--help') || args.length === 0) {
    console.log(`
Audio Content Collector for Baby in Car App

Usage:
  npx ts-node scripts/audio-collector.ts [options]

Options:
  --collect       Collect metadata from all sources (Freesound, Internet Archive)
  --download      Download audio files to local directory
  --generate-sql  Generate SQL seed statements for database
  --help          Show this help message

Environment Variables:
  FREESOUND_API_KEY   Your Freesound API key (get one at https://freesound.org/apiv2/apply)

Examples:
  # Collect metadata from all sources
  FREESOUND_API_KEY=your_key npx ts-node scripts/audio-collector.ts --collect

  # Download all collected audio files
  npx ts-node scripts/audio-collector.ts --download

  # Generate SQL for database seeding
  npx ts-node scripts/audio-collector.ts --generate-sql
`);
  }
}

main().catch(console.error);
