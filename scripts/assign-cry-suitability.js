#!/usr/bin/env node
/**
 * assign-cry-suitability.js
 *
 * Script to assign crySuitability scores to all tracks in tracks.json
 * Based on category-to-cry-type mappings from FS-029 spec
 *
 * Usage: node scripts/assign-cry-suitability.js
 */

const fs = require('fs');
const path = require('path');

// Input/output paths
const TRACKS_PATH = path.join(__dirname, '../BabyInCarApp/BabyInCarApp/Resources/Audio/tracks.json');
const OUTPUT_PATH = TRACKS_PATH; // Overwrite in place

// Category-to-cry-type base mappings (from spec Section 4.3)
// Support both underscore and dash variations
const CATEGORY_DEFAULTS = {
  // Music categories
  'lullabies': { hunger: 0.70, tired: 0.95, pain: 0.50 },
  'classical': { hunger: 0.60, tired: 0.90, pain: 0.50 },
  'ambient': { hunger: 0.50, tired: 0.85, pain: 0.60 },
  'modern-piano': { hunger: 0.55, tired: 0.88, pain: 0.45 },
  'modern_piano': { hunger: 0.55, tired: 0.88, pain: 0.45 },
  'childrens-songs': { hunger: 0.60, tired: 0.70, pain: 0.35 },
  'children_songs': { hunger: 0.60, tired: 0.70, pain: 0.35 },

  // Spoken content - generally less suitable for distress
  'fairytales': { hunger: 0.30, tired: 0.40, pain: 0.20 },
  'fairytales-en': { hunger: 0.30, tired: 0.40, pain: 0.20 },
  'fairytales_en': { hunger: 0.30, tired: 0.40, pain: 0.20 },
  'fairytales-ru': { hunger: 0.30, tired: 0.40, pain: 0.20 },
  'fairytales_ru': { hunger: 0.30, tired: 0.40, pain: 0.20 },
  'podcasts': { hunger: 0.25, tired: 0.35, pain: 0.15 },
};

// Tag-based refinements
const TAG_REFINEMENTS = {
  // Positive modifiers (add to scores)
  'deep-calm': { hunger: 0.05, tired: 0.10, pain: 0.05 },
  'ultra-soothing': { hunger: 0.05, tired: 0.10, pain: 0.05 },
  'rhythmic': { hunger: 0.10, tired: 0.00, pain: 0.00 },
  'heartbeat': { hunger: 0.15, tired: 0.15, pain: 0.10 },
  'womb': { hunger: 0.15, tired: 0.15, pain: 0.10 },
  'repetitive': { hunger: 0.05, tired: 0.05, pain: 0.05 },
  'gentle': { hunger: 0.05, tired: 0.05, pain: 0.10 },
  'slow': { hunger: 0.00, tired: 0.10, pain: 0.05 },
  'sleep': { hunger: 0.00, tired: 0.10, pain: 0.00 },
  'naptime': { hunger: 0.00, tired: 0.08, pain: 0.00 },
  'bedtime': { hunger: 0.00, tired: 0.08, pain: 0.00 },

  // Negative modifiers (subtract from scores)
  'playful': { hunger: 0.00, tired: -0.10, pain: -0.05 },
  'upbeat': { hunger: 0.05, tired: -0.15, pain: -0.10 },
  'dramatic': { hunger: -0.05, tired: -0.10, pain: -0.10 },
  'exciting': { hunger: 0.00, tired: -0.15, pain: -0.10 },
  'adventure': { hunger: 0.00, tired: -0.10, pain: -0.10 },
};

// CalmScore multiplier (higher calmScore = better for all types)
const CALM_SCORE_BONUS_THRESHOLD = 0.90;
const CALM_SCORE_BONUS = 0.05;

/**
 * Calculate crySuitability scores for a track
 */
function calculateCrySuitability(track) {
  // Get base scores from category
  const category = track.category?.toLowerCase() || 'ambient';
  let scores = { ...CATEGORY_DEFAULTS[category] || CATEGORY_DEFAULTS['ambient'] };

  // Apply tag-based refinements
  const tags = track.tags || [];
  for (const tag of tags) {
    const refinement = TAG_REFINEMENTS[tag.toLowerCase()];
    if (refinement) {
      scores.hunger += refinement.hunger;
      scores.tired += refinement.tired;
      scores.pain += refinement.pain;
    }
  }

  // Apply calmScore bonus
  const calmScore = track.calmScore || 0.5;
  if (calmScore >= CALM_SCORE_BONUS_THRESHOLD) {
    scores.hunger += CALM_SCORE_BONUS;
    scores.tired += CALM_SCORE_BONUS;
    scores.pain += CALM_SCORE_BONUS;
  }

  // Special handling for high calmScore and pain
  // Very calming tracks get a boost for pain (baby needs comfort)
  if (calmScore >= 0.95) {
    scores.pain += 0.10;
  }

  // Clamp all values to 0.0 - 1.0 range and round to 2 decimal places
  return {
    hunger: Math.round(Math.max(0, Math.min(1, scores.hunger)) * 100) / 100,
    tired: Math.round(Math.max(0, Math.min(1, scores.tired)) * 100) / 100,
    pain: Math.round(Math.max(0, Math.min(1, scores.pain)) * 100) / 100,
  };
}

/**
 * Main function
 */
function main() {
  console.log('Loading tracks.json...');

  // Read existing tracks
  const data = JSON.parse(fs.readFileSync(TRACKS_PATH, 'utf8'));
  console.log(`Found ${data.tracks.length} tracks`);

  // Track statistics
  const stats = {
    total: data.tracks.length,
    byCategory: {},
    avgScores: { hunger: 0, tired: 0, pain: 0 },
  };

  // Assign crySuitability to each track
  for (const track of data.tracks) {
    track.crySuitability = calculateCrySuitability(track);

    // Update stats
    const cat = track.category || 'unknown';
    stats.byCategory[cat] = (stats.byCategory[cat] || 0) + 1;
    stats.avgScores.hunger += track.crySuitability.hunger;
    stats.avgScores.tired += track.crySuitability.tired;
    stats.avgScores.pain += track.crySuitability.pain;
  }

  // Calculate averages
  stats.avgScores.hunger = (stats.avgScores.hunger / stats.total).toFixed(2);
  stats.avgScores.tired = (stats.avgScores.tired / stats.total).toFixed(2);
  stats.avgScores.pain = (stats.avgScores.pain / stats.total).toFixed(2);

  // Update version and generated date
  data.version = '2.4';
  data.generatedAt = new Date().toISOString().split('T')[0];
  data.description = 'Audio library with crySuitability scores for smart playlist generation (FS-029)';

  // Write updated tracks
  console.log('Writing updated tracks.json...');
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(data, null, 2), 'utf8');

  // Print summary
  console.log('\n=== Summary ===');
  console.log(`Total tracks: ${stats.total}`);
  console.log('\nBy category:');
  for (const [cat, count] of Object.entries(stats.byCategory).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${cat}: ${count}`);
  }
  console.log('\nAverage crySuitability scores:');
  console.log(`  hunger: ${stats.avgScores.hunger}`);
  console.log(`  tired: ${stats.avgScores.tired}`);
  console.log(`  pain: ${stats.avgScores.pain}`);

  console.log('\nDone! tracks.json updated with crySuitability scores.');
}

main();
