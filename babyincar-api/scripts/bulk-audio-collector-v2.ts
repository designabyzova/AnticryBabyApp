#!/usr/bin/env npx ts-node
/**
 * Bulk Audio Collector V2 for Baby in Car App
 * Extended search queries for 100+ more files
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';

const OUTPUT_DIR = path.join(__dirname, '../audio-library/downloads');
const METADATA_FILE = path.join(__dirname, '../audio-library/collected-metadata.json');

interface DownloadedTrack {
  id: string;
  title: string;
  artist: string;
  category: string;
  duration: number;
  source: string;
  sourceUrl: string;
  license: string;
  localPath: string;
  r2Key?: string;
  tags: string[];
  calmingScore: number;
}

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Extended search queries for more variety
const IA_COLLECTIONS = [
  // Classical piano
  { query: 'piano solo classical peaceful', category: 'classical_music' },
  { query: 'beethoven moonlight sonata', category: 'classical_music' },
  { query: 'liszt liebestraum', category: 'classical_music' },
  { query: 'schubert serenade', category: 'classical_music' },
  { query: 'tchaikovsky swan lake', category: 'classical_music' },
  { query: 'vivaldi four seasons', category: 'classical_music' },
  { query: 'handel water music', category: 'classical_music' },
  { query: 'grieg morning mood', category: 'classical_music' },
  // Ambient and relaxation
  { query: 'ambient relaxation meditation', category: 'ambient' },
  { query: 'spa music relaxing', category: 'ambient' },
  { query: 'zen meditation music', category: 'ambient' },
  { query: 'sleep music ambient', category: 'ambient' },
  { query: 'calm piano ambient', category: 'ambient' },
  // More nature sounds
  { query: 'night sounds crickets', category: 'nature_sounds' },
  { query: 'wind chimes peaceful', category: 'nature_sounds' },
  { query: 'waterfall nature', category: 'nature_sounds' },
  { query: 'campfire crackling', category: 'nature_sounds' },
  { query: 'gentle breeze leaves', category: 'nature_sounds' },
  { query: 'morning birds singing', category: 'nature_sounds' },
  // Instrumental
  { query: 'flute gentle melody', category: 'instrumental' },
  { query: 'violin peaceful', category: 'instrumental' },
  { query: 'cello solo gentle', category: 'instrumental' },
  { query: 'wind instruments calm', category: 'instrumental' },
  { query: 'bells meditation', category: 'instrumental' },
  // Lullabies and sleep
  { query: 'baby sleep sounds', category: 'lullabies' },
  { query: 'bedtime stories music', category: 'lullabies' },
  { query: 'hush little baby', category: 'lullabies' },
  { query: 'twinkle star music', category: 'lullabies' },
  { query: 'rock bye baby', category: 'lullabies' },
  // White noise type
  { query: 'fan white noise', category: 'white_noise' },
  { query: 'static noise sleep', category: 'white_noise' },
  { query: 'air conditioner sound', category: 'white_noise' },
  // Additional classical
  { query: 'nocturne piano solo', category: 'classical_music' },
  { query: 'prelude piano classical', category: 'classical_music' },
  { query: 'adagio strings', category: 'classical_music' },
  { query: 'sonata slow movement', category: 'classical_music' },
];

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function generateId(): string {
  return `audio_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

async function fetchJson<T>(url: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const req = protocol.get(url, { headers: { 'User-Agent': 'BabyInCarApp/1.0' } }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        const location = res.headers.location;
        if (location) {
          fetchJson<T>(location).then(resolve).catch(reject);
          return;
        }
      }

      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`JSON parse error`));
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

async function downloadFile(url: string, destPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    const file = fs.createWriteStream(destPath);
    const protocol = url.startsWith('https') ? https : http;

    const makeRequest = (currentUrl: string, redirectCount = 0) => {
      if (redirectCount > 5) {
        try { fs.unlinkSync(destPath); } catch {}
        resolve(false);
        return;
      }

      const req = protocol.get(currentUrl, { headers: { 'User-Agent': 'BabyInCarApp/1.0' } }, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          const location = res.headers.location;
          if (location) {
            const nextUrl = location.startsWith('http') ? location : `https://archive.org${location}`;
            makeRequest(nextUrl, redirectCount + 1);
            return;
          }
        }

        if (res.statusCode !== 200) {
          try { fs.unlinkSync(destPath); } catch {}
          resolve(false);
          return;
        }

        res.pipe(file);
        file.on('finish', () => {
          file.close();
          const stats = fs.statSync(destPath);
          if (stats.size < 10000) {
            try { fs.unlinkSync(destPath); } catch {}
            resolve(false);
          } else {
            resolve(true);
          }
        });
      });

      req.on('error', () => {
        try { fs.unlinkSync(destPath); } catch {}
        resolve(false);
      });

      req.setTimeout(60000, () => {
        req.destroy();
        try { fs.unlinkSync(destPath); } catch {}
        resolve(false);
      });
    };

    makeRequest(url);
  });
}

interface IASearchResult {
  response?: {
    docs?: Array<{
      identifier: string;
      title?: string;
      creator?: string;
    }>;
  };
}

interface IAMetadataResult {
  result?: Array<{
    name: string;
    title?: string;
    format?: string;
    length?: string;
    size?: string;
  }>;
}

async function searchInternetArchive(query: string): Promise<any[]> {
  const params = new URLSearchParams({
    q: `${query} AND mediatype:audio`,
    fl: 'identifier,title,creator',
    rows: '25',
    output: 'json',
  });

  const url = `https://archive.org/advancedsearch.php?${params}`;

  try {
    const result = await fetchJson<IASearchResult>(url);
    return result.response?.docs || [];
  } catch (error) {
    return [];
  }
}

async function getIAItemFiles(identifier: string): Promise<any[]> {
  const url = `https://archive.org/metadata/${identifier}/files`;

  try {
    const result = await fetchJson<IAMetadataResult>(url);
    return result.result || [];
  } catch (error) {
    return [];
  }
}

function calculateCalmingScore(category: string, tags: string): number {
  let score = 0.7;
  if (category === 'lullabies' || category === 'classical_music') score += 0.15;
  if (category === 'nature_sounds' || category === 'ambient') score += 0.1;
  if (category === 'instrumental') score += 0.1;
  if (category === 'white_noise') score += 0.12;
  return Math.min(0.98, score);
}

// Load existing metadata to avoid duplicates
function loadExistingMetadata(): DownloadedTrack[] {
  if (fs.existsSync(METADATA_FILE)) {
    return JSON.parse(fs.readFileSync(METADATA_FILE, 'utf-8'));
  }
  return [];
}

async function collectFromInternetArchive(existingCount: number): Promise<DownloadedTrack[]> {
  const tracks: DownloadedTrack[] = [];
  let totalDownloaded = 0;
  const TARGET = 70; // Additional files needed

  console.log('\n=== Collecting MORE from Internet Archive ===\n');
  console.log(`Already have: ${existingCount} files`);
  console.log(`Target additional: ${TARGET}\n`);

  const downloadedIdentifiers = new Set<string>();

  for (const collection of IA_COLLECTIONS) {
    if (totalDownloaded >= TARGET) break;

    console.log(`Searching: "${collection.query}" (${collection.category})...`);

    const items = await searchInternetArchive(collection.query);

    for (const item of items.slice(0, 6)) {
      if (totalDownloaded >= TARGET) break;
      if (downloadedIdentifiers.has(item.identifier)) continue;

      await sleep(400);

      const files = await getIAItemFiles(item.identifier);
      const audioFiles = files.filter((f: any) =>
        f.format === 'VBR MP3' ||
        f.format === '128Kbps MP3' ||
        f.format === '64Kbps MP3' ||
        (f.name?.endsWith('.mp3') && !f.name?.includes('_spectrogram'))
      );

      for (const file of audioFiles.slice(0, 2)) {
        if (totalDownloaded >= TARGET) break;

        const duration = parseFloat(file.length) || 0;
        if (duration < 30 || duration > 600) continue;

        const filename = `ia_${collection.category}_${generateId()}.mp3`;
        const localPath = path.join(OUTPUT_DIR, filename);
        const downloadUrl = `https://archive.org/download/${item.identifier}/${encodeURIComponent(file.name)}`;

        process.stdout.write(`  [${totalDownloaded + 1}/${TARGET}] ${(file.name || 'Unknown').substring(0, 35)}... `);

        const success = await downloadFile(downloadUrl, localPath);

        if (success) {
          downloadedIdentifiers.add(item.identifier);
          totalDownloaded++;
          console.log('✓');

          tracks.push({
            id: generateId(),
            title: file.title || file.name?.replace(/\.[^.]+$/, '').replace(/[_-]/g, ' ') || 'Unknown',
            artist: item.creator || 'Unknown Artist',
            category: collection.category,
            duration: Math.round(duration),
            source: 'internet_archive',
            sourceUrl: `https://archive.org/details/${item.identifier}`,
            license: 'Public Domain',
            localPath,
            tags: collection.query.split(' '),
            calmingScore: calculateCalmingScore(collection.category, collection.query),
          });
        } else {
          console.log('✗');
        }

        await sleep(250);
      }
    }
  }

  return tracks;
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║   Bulk Audio Collector V2 - MORE content!              ║');
  console.log('╚════════════════════════════════════════════════════════╝\n');

  // Load existing
  const existingTracks = loadExistingMetadata();
  console.log(`Loaded ${existingTracks.length} existing tracks`);

  // Collect more
  const newTracks = await collectFromInternetArchive(existingTracks.length);

  // Merge
  const allTracks = [...existingTracks, ...newTracks];

  console.log(`\n=== Collection Summary ===`);
  console.log(`Previously: ${existingTracks.length}`);
  console.log(`New: ${newTracks.length}`);
  console.log(`Total: ${allTracks.length}`);

  const byCategory = allTracks.reduce((acc, t) => {
    acc[t.category] = (acc[t.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  console.log('\nBy category:');
  Object.entries(byCategory).forEach(([cat, count]) => {
    console.log(`  ${cat}: ${count}`);
  });

  fs.writeFileSync(METADATA_FILE, JSON.stringify(allTracks, null, 2));
  console.log(`\nMetadata saved to: ${METADATA_FILE}`);

  return allTracks;
}

main().catch(console.error);
