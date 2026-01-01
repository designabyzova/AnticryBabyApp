#!/usr/bin/env npx ts-node
/**
 * Bulk Audio Collector for Baby in Car App
 *
 * Downloads 100+ royalty-free audio files from:
 * - Internet Archive (public domain classical, lullabies)
 * - Freesound (CC0 sounds - requires API key)
 *
 * Usage:
 *   npx ts-node scripts/bulk-audio-collector.ts
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

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Internet Archive collections with baby/lullaby content
const IA_COLLECTIONS = [
  // Classical music collections
  { query: 'lullaby classical piano', category: 'classical_music' },
  { query: 'brahms lullaby', category: 'classical_music' },
  { query: 'mozart piano soft', category: 'classical_music' },
  { query: 'chopin nocturne', category: 'classical_music' },
  { query: 'debussy claire lune', category: 'classical_music' },
  { query: 'bach cello suite', category: 'classical_music' },
  { query: 'satie gymnopedies', category: 'classical_music' },
  { query: 'pachelbel canon', category: 'classical_music' },
  // Nature sounds
  { query: 'rain sounds relaxing', category: 'nature_sounds' },
  { query: 'ocean waves peaceful', category: 'nature_sounds' },
  { query: 'forest ambience birds', category: 'nature_sounds' },
  { query: 'stream water flowing', category: 'nature_sounds' },
  { query: 'thunderstorm distant', category: 'nature_sounds' },
  // Lullabies and children
  { query: 'children lullaby music', category: 'lullabies' },
  { query: 'nursery rhymes instrumental', category: 'children_songs' },
  { query: 'music box melody', category: 'lullabies' },
  { query: 'harp soothing music', category: 'instrumental' },
  { query: 'acoustic guitar gentle', category: 'instrumental' },
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
          reject(new Error(`JSON parse error: ${data.substring(0, 200)}`));
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
        fs.unlinkSync(destPath);
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
          fs.unlinkSync(destPath);
          resolve(false);
          return;
        }

        res.pipe(file);
        file.on('finish', () => {
          file.close();
          // Verify file is not too small (likely error page)
          const stats = fs.statSync(destPath);
          if (stats.size < 10000) {
            fs.unlinkSync(destPath);
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
      description?: string;
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
    q: `${query} AND mediatype:audio AND licenseurl:*publicdomain*`,
    fl: 'identifier,title,creator,description',
    rows: '30',
    output: 'json',
  });

  const url = `https://archive.org/advancedsearch.php?${params}`;

  try {
    const result = await fetchJson<IASearchResult>(url);
    return result.response?.docs || [];
  } catch (error) {
    console.error(`  Search failed for "${query}":`, error);
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

async function collectFromInternetArchive(): Promise<DownloadedTrack[]> {
  const tracks: DownloadedTrack[] = [];
  let totalDownloaded = 0;
  const TARGET = 120; // Try to get 120 files

  console.log('\n=== Collecting from Internet Archive ===\n');

  for (const collection of IA_COLLECTIONS) {
    if (totalDownloaded >= TARGET) break;

    console.log(`\nSearching: "${collection.query}" (${collection.category})...`);

    const items = await searchInternetArchive(collection.query);
    console.log(`  Found ${items.length} items`);

    for (const item of items.slice(0, 8)) {
      if (totalDownloaded >= TARGET) break;

      await sleep(500); // Rate limiting

      const files = await getIAItemFiles(item.identifier);
      const audioFiles = files.filter((f: any) =>
        f.format === 'VBR MP3' ||
        f.format === '128Kbps MP3' ||
        f.format === '64Kbps MP3' ||
        f.name?.endsWith('.mp3')
      );

      for (const file of audioFiles.slice(0, 3)) {
        if (totalDownloaded >= TARGET) break;

        const duration = parseFloat(file.length) || 0;
        if (duration < 30 || duration > 600) continue; // 30s to 10min

        const filename = `ia_${collection.category}_${generateId()}.mp3`;
        const localPath = path.join(OUTPUT_DIR, filename);
        const downloadUrl = `https://archive.org/download/${item.identifier}/${encodeURIComponent(file.name)}`;

        console.log(`  Downloading: ${file.name?.substring(0, 40) || 'Unknown'}...`);

        const success = await downloadFile(downloadUrl, localPath);

        if (success) {
          totalDownloaded++;
          console.log(`    ✓ Saved (${totalDownloaded}/${TARGET})`);

          const track: DownloadedTrack = {
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
          };

          tracks.push(track);
        } else {
          console.log(`    ✗ Failed`);
        }

        await sleep(300);
      }
    }
  }

  return tracks;
}

function calculateCalmingScore(category: string, tags: string): number {
  let score = 0.7;

  if (category === 'lullabies' || category === 'classical_music') score += 0.15;
  if (category === 'nature_sounds') score += 0.1;
  if (category === 'instrumental') score += 0.1;

  if (tags.includes('soft') || tags.includes('gentle')) score += 0.05;
  if (tags.includes('relaxing') || tags.includes('peaceful')) score += 0.05;
  if (tags.includes('sleep') || tags.includes('lullaby')) score += 0.05;

  return Math.min(0.98, score);
}

// Additional curated sources - direct MP3 links from known free sources
const CURATED_SOURCES = [
  // Musopen.org - Public domain classical recordings
  {
    url: 'https://musopen.org/music/download/1489/',
    title: 'Clair de Lune - Debussy',
    category: 'classical_music',
    artist: 'Debussy',
  },
  {
    url: 'https://musopen.org/music/download/1510/',
    title: 'Gymnopédie No. 1 - Satie',
    category: 'classical_music',
    artist: 'Erik Satie',
  },
];

async function main() {
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║   Bulk Audio Collector - Baby in Car App              ║');
  console.log('║   Collecting 100+ royalty-free audio files            ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  const allTracks: DownloadedTrack[] = [];

  // Collect from Internet Archive
  const iaTracks = await collectFromInternetArchive();
  allTracks.push(...iaTracks);

  console.log(`\n=== Collection Summary ===`);
  console.log(`Total downloaded: ${allTracks.length}`);

  // Group by category
  const byCategory = allTracks.reduce((acc, t) => {
    acc[t.category] = (acc[t.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  console.log('\nBy category:');
  Object.entries(byCategory).forEach(([cat, count]) => {
    console.log(`  ${cat}: ${count}`);
  });

  // Save metadata
  fs.writeFileSync(METADATA_FILE, JSON.stringify(allTracks, null, 2));
  console.log(`\nMetadata saved to: ${METADATA_FILE}`);

  // Generate R2 upload commands
  console.log('\n=== Next Steps ===');
  console.log('1. Review downloaded files in audio-library/downloads/');
  console.log('2. Run upload script to push to R2:');
  console.log('   R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \\');
  console.log('   npx ts-node scripts/upload-collected-to-r2.ts');

  return allTracks;
}

main().catch(console.error);
