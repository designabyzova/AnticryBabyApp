import type { DevelopmentalStage } from '../types';

// Calculate age in months from birth date
export function calculateAgeMonths(birthDate: string): number {
  const birth = new Date(birthDate);
  const now = new Date();
  const months = (now.getFullYear() - birth.getFullYear()) * 12 +
    (now.getMonth() - birth.getMonth());
  return Math.max(0, Math.min(36, months));
}

// Get developmental stage from age in months
export function getDevelopmentalStage(ageMonths: number): DevelopmentalStage {
  if (ageMonths < 3) return 'fourth_trimester';
  if (ageMonths < 6) return 'early_regulation';
  if (ageMonths < 9) return 'sensory_exploration';
  if (ageMonths < 12) return 'motor_development';
  if (ageMonths < 18) return 'vocabulary_burst';
  if (ageMonths < 24) return 'sentence_building';
  return 'imagination_growth';
}

// Get recommended categories for developmental stage
export function getRecommendedCategories(stage: DevelopmentalStage): string[] {
  const recommendations: Record<DevelopmentalStage, string[]> = {
    fourth_trimester: ['white_noise', 'nature_sounds', 'instrumental'],
    early_regulation: ['white_noise', 'nature_sounds', 'classical_music', 'instrumental'],
    sensory_exploration: ['nature_sounds', 'classical_music', 'children_songs', 'instrumental'],
    motor_development: ['children_songs', 'classical_music', 'nature_sounds', 'fairy_tales'],
    vocabulary_burst: ['fairy_tales', 'children_songs', 'classical_music', 'podcasts'],
    sentence_building: ['fairy_tales', 'children_songs', 'podcasts', 'classical_music'],
    imagination_growth: ['fairy_tales', 'podcasts', 'children_songs', 'classical_music'],
  };
  return recommendations[stage] || [];
}

// Calculate relevance score for a track
export function calculateRelevanceScore(
  track: {
    calming_score: number;
    age_range_min: number;
    age_range_max: number;
    category: string;
    tempo_bpm: number | null;
  },
  ageMonths: number,
  stage: DevelopmentalStage
): number {
  let score = 0;

  // Base calming score (40% weight)
  score += track.calming_score * 0.4;

  // Optimal age match bonus (30% weight)
  const ageCenter = (track.age_range_min + track.age_range_max) / 2;
  const ageDistance = Math.abs(ageMonths - ageCenter);
  const ageRange = (track.age_range_max - track.age_range_min) / 2;
  const ageScore = Math.max(0, 1 - ageDistance / (ageRange + 1));
  score += ageScore * 0.3;

  // Category relevance (20% weight)
  const recommendedCategories = getRecommendedCategories(stage);
  if (recommendedCategories.includes(track.category)) {
    const categoryIndex = recommendedCategories.indexOf(track.category);
    score += (1 - categoryIndex * 0.15) * 0.2;
  }

  // Tempo match bonus (10% weight)
  if (track.tempo_bpm) {
    const optimalTempo = getOptimalTempo(stage);
    const tempoScore = Math.max(0, 1 - Math.abs(track.tempo_bpm - optimalTempo) / 60);
    score += tempoScore * 0.1;
  }

  return Math.min(1, Math.max(0, score));
}

// Get optimal tempo for developmental stage
function getOptimalTempo(stage: DevelopmentalStage): number {
  const tempos: Record<DevelopmentalStage, number> = {
    fourth_trimester: 60,
    early_regulation: 65,
    sensory_exploration: 70,
    motor_development: 75,
    vocabulary_burst: 80,
    sentence_building: 85,
    imagination_growth: 90,
  };
  return tempos[stage];
}

// Format duration in seconds to HH:MM:SS
export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

// Parse ISO date string
export function parseDate(dateString: string): Date | null {
  const date = new Date(dateString);
  return isNaN(date.getTime()) ? null : date;
}

// Validate birth date (must be in the past, within last 4 years)
export function isValidBirthDate(dateString: string): boolean {
  const date = parseDate(dateString);
  if (!date) return false;

  const now = new Date();
  const fourYearsAgo = new Date(now.getFullYear() - 4, now.getMonth(), now.getDate());

  return date <= now && date >= fourYearsAgo;
}

// Sanitize string input
export function sanitizeString(input: string): string {
  return input
    .trim()
    .replace(/[<>]/g, '')
    .substring(0, 500);
}

// Generate signed URL for R2 object
export async function generateSignedUrl(
  bucket: R2Bucket,
  key: string,
  expiresInSeconds: number = 3600
): Promise<string | null> {
  try {
    const object = await bucket.head(key);
    if (!object) return null;

    // For now, return direct URL. In production, implement actual signing
    // Cloudflare R2 signed URLs require custom implementation
    return `https://audio.babyincar.app/${key}`;
  } catch {
    return null;
  }
}

// Paginate results
export function paginate<T>(
  items: T[],
  limit: number,
  offset: number
): { items: T[]; total: number; has_more: boolean } {
  const total = items.length;
  const paginatedItems = items.slice(offset, offset + limit);

  return {
    items: paginatedItems,
    total,
    has_more: offset + limit < total,
  };
}

// Rate limit key generation
export function getRateLimitKey(identifier: string, action: string): string {
  const minute = Math.floor(Date.now() / 60000);
  return `ratelimit:${action}:${identifier}:${minute}`;
}

// Check rate limit
export async function checkRateLimit(
  kv: KVNamespace,
  key: string,
  limit: number
): Promise<{ allowed: boolean; remaining: number }> {
  const current = await kv.get(key);
  const count = current ? parseInt(current, 10) : 0;

  if (count >= limit) {
    return { allowed: false, remaining: 0 };
  }

  await kv.put(key, (count + 1).toString(), { expirationTtl: 60 });
  return { allowed: true, remaining: limit - count - 1 };
}
