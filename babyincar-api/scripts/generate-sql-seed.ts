#!/usr/bin/env npx ts-node
/**
 * Generate SQL Seed Data from collected audio metadata
 *
 * Creates INSERT statements for D1 database
 */

import * as fs from 'fs';
import * as path from 'path';

const METADATA_FILE = path.join(__dirname, '../audio-library/collected-metadata.json');
const OUTPUT_FILE = path.join(__dirname, '../migrations/004_collected_audio_seed.sql');

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

function escapeSQL(str: string | undefined | null): string {
  if (str === undefined || str === null) return '';
  return String(str).replace(/'/g, "''").replace(/\\/g, '\\\\');
}

function main() {
  console.log('=== Generating SQL Seed Data ===\n');

  if (!fs.existsSync(METADATA_FILE)) {
    console.error('Metadata file not found.');
    process.exit(1);
  }

  const tracks: DownloadedTrack[] = JSON.parse(
    fs.readFileSync(METADATA_FILE, 'utf-8')
  );

  const sqlStatements: string[] = [
    '-- Auto-generated audio seed data',
    `-- Generated: ${new Date().toISOString()}`,
    `-- Total tracks: ${tracks.length}`,
    '',
    '-- Insert collected audio tracks',
    '',
  ];

  for (const track of tracks) {
    const streamUrl = track.r2Key
      ? `https://audio.babyincar.app/${track.r2Key}`
      : null;

    const sql = `INSERT OR IGNORE INTO tracks (
  id,
  title,
  artist,
  category,
  language,
  duration,
  age_range_min,
  age_range_max,
  calming_score,
  audio_source_type,
  stream_url,
  is_premium,
  created_at
) VALUES (
  '${escapeSQL(track.id)}',
  '${escapeSQL(track.title)}',
  '${escapeSQL(track.artist)}',
  '${escapeSQL(track.category)}',
  'en',
  ${track.duration},
  0,
  36,
  ${track.calmingScore.toFixed(2)},
  'recorded',
  ${streamUrl ? `'${streamUrl}'` : 'NULL'},
  0,
  '${new Date().toISOString()}'
);`;

    sqlStatements.push(sql);
    sqlStatements.push('');
  }

  // Ensure migrations directory exists
  const migrationsDir = path.dirname(OUTPUT_FILE);
  if (!fs.existsSync(migrationsDir)) {
    fs.mkdirSync(migrationsDir, { recursive: true });
  }

  fs.writeFileSync(OUTPUT_FILE, sqlStatements.join('\n'));

  console.log(`Generated ${tracks.length} INSERT statements`);
  console.log(`Output: ${OUTPUT_FILE}`);

  // Also generate a summary by category
  const byCategory = tracks.reduce((acc, t) => {
    acc[t.category] = (acc[t.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  console.log('\nBy category:');
  Object.entries(byCategory).forEach(([cat, count]) => {
    console.log(`  ${cat}: ${count}`);
  });
}

main();
