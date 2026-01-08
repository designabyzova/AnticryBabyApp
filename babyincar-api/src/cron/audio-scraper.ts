/**
 * 24/7 Audio Scraper - Cloudflare Workers Cron Job
 *
 * Runs every 6 hours to scrape baby-friendly music from free sources
 * NO API KEYS REQUIRED
 *
 * Sources:
 * 1. Chosic.com - Public domain classical (web scraping)
 * 2. Incompetech.com - Kevin MacLeod royalty-free (direct URLs)
 * 3. Archive.org - Public domain (free API)
 * 4. Pixabay - Manual queue (pre-collected URLs)
 *
 * Schedule: 0 */6 * * * (Every 6 hours)
 */

import type { Env } from '../types';

interface ScrapedTrack {
  title: string;
  artist: string;
  category: string;
  url: string;
  duration: number;
  calmingScore: number;
  source: string;
  license: string;
}

export async function scrapeAudioContent(env: Env): Promise<void> {
  console.log('[AudioScraper] 🎵 Starting 24/7 audio scraping job...');

  const scrapedTracks: ScrapedTrack[] = [];

  try {
    // 1. Scrape Chosic.com (public domain classical)
    console.log('[AudioScraper] 📥 Scraping Chosic.com...');
    const chosicTracks = await scrapeChosic();
    scrapedTracks.push(...chosicTracks);
    console.log(`[AudioScraper] ✅ Chosic: Found ${chosicTracks.length} tracks`);

    // 2. Scrape Incompetech.com (Kevin MacLeod)
    console.log('[AudioScraper] 📥 Scraping Incompetech.com...');
    const incompetechTracks = await scrapeIncompetech();
    scrapedTracks.push(...incompetechTracks);
    console.log(`[AudioScraper] ✅ Incompetech: Found ${incompetechTracks.length} tracks`);

    // 3. Search Archive.org (public domain)
    console.log('[AudioScraper] 📥 Searching Archive.org...');
    const archiveTracks = await searchArchiveOrg();
    scrapedTracks.push(...archiveTracks);
    console.log(`[AudioScraper] ✅ Archive.org: Found ${archiveTracks.length} tracks`);

    // 4. Process pre-collected Pixabay URLs
    console.log('[AudioScraper] 📥 Processing Pixabay queue...');
    const pixabayTracks = await processPixabayQueue(env);
    scrapedTracks.push(...pixabayTracks);
    console.log(`[AudioScraper] ✅ Pixabay: Found ${pixabayTracks.length} tracks`);

    console.log(`[AudioScraper] 📊 Total tracks found: ${scrapedTracks.length}`);

    // Download, upload, and insert to database
    for (const track of scrapedTracks.slice(0, 10)) { // Limit to 10 per run
      try {
        await processTrack(track, env);
      } catch (error) {
        console.error(`[AudioScraper] ❌ Failed to process ${track.title}:`, error);
      }
    }

    console.log('[AudioScraper] ✅ Scraping job completed successfully');

  } catch (error) {
    console.error('[AudioScraper] ❌ Scraping job failed:', error);
    throw error;
  }
}

/**
 * Scrape Chosic.com for public domain classical music
 * Uses web scraping - NO API KEY NEEDED
 */
async function scrapeChosic(): Promise<ScrapedTrack[]> {
  const tracks: ScrapedTrack[] = [];

  // Chosic has category pages with direct download links
  const categories = [
    'https://www.chosic.com/free-music/classical/',
    'https://www.chosic.com/free-music/lullaby/',
    'https://www.chosic.com/free-music/meditation/'
  ];

  for (const categoryUrl of categories) {
    try {
      const response = await fetch(categoryUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        }
      });

      const html = await response.text();

      // Parse HTML for download links
      // Chosic structure: <a class="download-link" href="https://...mp3">Download</a>
      const downloadRegex = /href="(https:\/\/www\.chosic\.com\/wp-content\/uploads\/[^"]+\.mp3)"/g;
      const titleRegex = /<h3[^>]*>([^<]+)<\/h3>/g;

      const urls = [...html.matchAll(downloadRegex)].map(m => m[1]);
      const titles = [...html.matchAll(titleRegex)].map(m => m[1]);

      for (let i = 0; i < Math.min(urls.length, titles.length, 5); i++) {
        tracks.push({
          title: titles[i].trim(),
          artist: extractArtist(titles[i]),
          category: 'classical_music',
          url: urls[i],
          duration: 180,
          calmingScore: 0.9,
          source: 'chosic.com',
          license: 'Public Domain'
        });
      }
    } catch (error) {
      console.error(`[Chosic] Failed to scrape ${categoryUrl}:`, error);
    }
  }

  return tracks;
}

/**
 * Scrape Incompetech.com for Kevin MacLeod tracks
 * Direct URLs - NO API KEY NEEDED
 */
async function scrapeIncompetech(): Promise<ScrapedTrack[]> {
  // Incompetech has predictable URL patterns
  const calmTracks = [
    { title: 'Floating Cities', url: 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Floating%20Cities.mp3' },
    { title: 'Meditation Impromptu 01', url: 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Meditation%20Impromptu%2001.mp3' },
    { title: 'Peaceful', url: 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Peaceful.mp3' },
    { title: 'Thatched Villagers', url: 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Thatched%20Villagers.mp3' },
    { title: 'Soaring', url: 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Soaring.mp3' }
  ];

  return calmTracks.map(track => ({
    title: track.title,
    artist: 'Kevin MacLeod',
    category: 'instrumental',
    url: track.url,
    duration: 150,
    calmingScore: 0.85,
    source: 'incompetech.com',
    license: 'CC-BY 4.0'
  }));
}

/**
 * Search Archive.org using their free public API
 * NO API KEY NEEDED
 */
async function searchArchiveOrg(): Promise<ScrapedTrack[]> {
  const tracks: ScrapedTrack[] = [];

  const queries = ['baby lullaby classical', 'brahms lullaby', 'mozart baby'];

  for (const query of queries) {
    try {
      const response = await fetch(
        `https://archive.org/advancedsearch.php?q=${encodeURIComponent(query + ' AND mediatype:audio AND format:VBR MP3')}&fl=identifier,title,creator&sort=downloads desc&rows=3&output=json`
      );

      const data = await response.json() as any;

      for (const doc of data.response?.docs || []) {
        // Archive.org files are in subdirectories - need to fetch file list
        const filesUrl = `https://archive.org/metadata/${doc.identifier}`;
        const filesResponse = await fetch(filesUrl);
        const filesData = await filesResponse.json() as any;

        // Find MP3 file
        const mp3File = filesData.files?.find((f: any) => f.name?.endsWith('.mp3'));

        if (mp3File) {
          tracks.push({
            title: doc.title || 'Unknown',
            artist: doc.creator || 'Unknown',
            category: 'classical_music',
            url: `https://archive.org/download/${doc.identifier}/${mp3File.name}`,
            duration: 180,
            calmingScore: 0.85,
            source: 'archive.org',
            license: 'Public Domain'
          });
        }
      }
    } catch (error) {
      console.error(`[Archive.org] Search failed for "${query}":`, error);
    }
  }

  return tracks;
}

/**
 * Process pre-collected Pixabay URLs from KV storage
 * URLs are manually collected and queued
 */
async function processPixabayQueue(env: Env): Promise<ScrapedTrack[]> {
  try {
    const queueData = await env.CACHE.get('pixabay_queue', 'json') as any;
    const queue = queueData?.tracks || [];

    // Return up to 5 tracks from queue
    return queue.slice(0, 5).map((track: any) => ({
      title: track.title,
      artist: track.artist || 'Pixabay',
      category: track.category || 'instrumental',
      url: track.url,
      duration: track.duration || 180,
      calmingScore: track.calmingScore || 0.9,
      source: 'pixabay.com',
      license: 'Pixabay License'
    }));
  } catch (error) {
    console.error('[Pixabay] Failed to load queue:', error);
    return [];
  }
}

/**
 * Process a single track: Download → Upload to R2 → Insert to DB
 */
async function processTrack(track: ScrapedTrack, env: Env): Promise<void> {
  console.log(`[ProcessTrack] 🔽 Processing: ${track.title}`);

  // 1. Check if track already exists
  const existing = await env.DB.prepare(
    'SELECT id FROM tracks WHERE title = ? AND artist = ?'
  ).bind(track.title, track.artist).first();

  if (existing) {
    console.log(`[ProcessTrack] ⏭️  Skipping ${track.title} (already exists)`);
    return;
  }

  // 2. Download audio file
  const audioResponse = await fetch(track.url, {
    headers: {
      'User-Agent': 'Mozilla/5.0',
    }
  });

  if (!audioResponse.ok) {
    throw new Error(`Download failed: ${audioResponse.status}`);
  }

  const audioData = await audioResponse.arrayBuffer();

  // Verify file size (must be > 100KB)
  if (audioData.byteLength < 100000) {
    throw new Error('File too small (< 100KB)');
  }

  // 3. Upload to R2
  const trackId = crypto.randomUUID();
  const filename = `${sanitizeFilename(track.artist)}_${sanitizeFilename(track.title)}.mp3`;
  const r2Key = `audio/${getCategoryFolder(track.category)}/${filename}`;

  await env.AUDIO_BUCKET.put(r2Key, audioData, {
    httpMetadata: {
      contentType: 'audio/mpeg',
    },
  });

  const streamUrl = `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/${r2Key}`;

  console.log(`[ProcessTrack] ✅ Uploaded to R2: ${r2Key}`);

  // 4. Insert to database
  await env.DB.prepare(`
    INSERT INTO tracks (
      id, title, artist, category, language,
      duration, age_range_min, age_range_max,
      calming_score, is_premium, audio_source_type,
      stream_url, source, license
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    trackId,
    track.title,
    track.artist,
    track.category,
    'multi',
    track.duration,
    0,
    36,
    track.calmingScore,
    0, // is_premium
    'recorded',
    streamUrl,
    track.source,
    track.license
  ).run();

  console.log(`[ProcessTrack] ✅ Inserted to DB: ${track.title}`);
}

// Helper functions

function extractArtist(title: string): string {
  // Extract artist from title like "Clair de Lune - Debussy"
  const match = title.match(/[-–—]\s*([^-–—]+)$/);
  return match ? match[1].trim() : 'Unknown Artist';
}

function sanitizeFilename(str: string): string {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 50);
}

function getCategoryFolder(category: string): string {
  const mapping: Record<string, string> = {
    'classical_music': 'classical',
    'instrumental': 'ambient',
    'nature_sounds': 'nature',
    'white_noise': 'whitenoise',
    'fairy_tales': 'fairytales',
    'lullabies': 'lullabies'
  };
  return mapping[category] || 'misc';
}

// Export for cron trigger
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(scrapeAudioContent(env));
  },
};
