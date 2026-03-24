/**
 * AI-Powered Audio Curator Service
 *
 * This service autonomously discovers, evaluates, and curates audio content
 * for the Baby in Car app. It uses AI to analyze audio metadata and determine
 * the best content for soothing babies.
 *
 * Key Features:
 * - Continuous discovery from multiple free sources
 * - AI-powered content quality analysis
 * - Automatic categorization and scoring
 * - Scheduled collection via Cloudflare Cron Triggers
 */

import type { Env } from '../types';
import { callGemini } from '../lib/gemini';

// Audio source configurations
export const AUDIO_SOURCES = {
  freesound: {
    name: 'Freesound.org',
    baseUrl: 'https://freesound.org/apiv2',
    rateLimit: 60, // requests per minute
    license: 'CC0',
    enabled: true,
  },
  internetArchive: {
    name: 'Internet Archive',
    baseUrl: 'https://archive.org',
    rateLimit: 30,
    license: 'Public Domain',
    enabled: true,
  },
};

// Search queries optimized for baby content
export const CURATION_QUERIES = {
  white_noise: {
    priority: 1,
    queries: [
      'white noise sleep',
      'pink noise baby',
      'brown noise deep',
      'fan sound constant',
      'air conditioner ambient',
      'vacuum cleaner sound',
      'washing machine hum',
      'womb sounds heartbeat',
      'shushing sound baby',
    ],
    idealDuration: { min: 60, max: 600 },
    targetCalmingScore: 0.9,
  },
  nature_sounds: {
    priority: 2,
    queries: [
      'rain sounds gentle',
      'ocean waves calm',
      'river stream peaceful',
      'forest birds morning',
      'wind gentle breeze',
      'thunderstorm distant',
      'waterfall relaxing',
      'crickets night ambient',
    ],
    idealDuration: { min: 60, max: 600 },
    targetCalmingScore: 0.85,
  },
  classical_music: {
    priority: 3,
    queries: [
      'lullaby classical piano',
      'mozart baby sleep',
      'brahms lullaby',
      'debussy peaceful',
      'bach air gentle',
      'chopin nocturne soft',
    ],
    idealDuration: { min: 120, max: 400 },
    targetCalmingScore: 0.88,
  },
  instrumental: {
    priority: 4,
    queries: [
      'music box lullaby',
      'harp gentle melody',
      'piano soft ambient',
      'guitar acoustic calm',
      'wind chimes peaceful',
      'bells soft gentle',
    ],
    idealDuration: { min: 60, max: 300 },
    targetCalmingScore: 0.87,
  },
};

// Quality criteria for baby audio
export const QUALITY_CRITERIA = {
  // Audio characteristics
  preferredFormats: ['mp3', 'ogg', 'wav', 'flac'],
  minBitrate: 128, // kbps
  minSampleRate: 44100,

  // Duration preferences by category
  durationRanges: {
    white_noise: { min: 60, max: 600, optimal: 300 },
    nature_sounds: { min: 60, max: 600, optimal: 300 },
    classical_music: { min: 120, max: 400, optimal: 240 },
    instrumental: { min: 60, max: 300, optimal: 180 },
    children_songs: { min: 30, max: 180, optimal: 90 },
    fairy_tales: { min: 180, max: 600, optimal: 360 },
  },

  // Content safety
  excludeTags: [
    'loud', 'intense', 'scary', 'horror', 'explosion',
    'alarm', 'siren', 'scream', 'harsh', 'aggressive',
    'metal', 'rock', 'electronic', 'beat', 'bass',
  ],

  // Preferred tags
  preferredTags: [
    'calm', 'peaceful', 'relaxing', 'gentle', 'soft',
    'soothing', 'ambient', 'sleep', 'baby', 'lullaby',
    'quiet', 'serene', 'tranquil', 'meditative',
  ],
};

// Types
export interface DiscoveredAudio {
  id: string;
  source: string;
  sourceId: string;
  title: string;
  artist: string;
  description: string;
  duration: number;
  fileSize: number;
  format: string;
  tags: string[];
  license: string;
  downloadUrl: string;
  previewUrl: string;
  rating: number;
  downloads: number;
}

export interface AudioAnalysis {
  audioId: string;
  category: string;
  calmingScore: number;
  babyFitScore: number;
  qualityScore: number;
  safetyScore: number;
  overallScore: number;
  ageRangeMin: number;
  ageRangeMax: number;
  isPremiumWorthy: boolean;
  reasoning: string;
  recommendedAction: 'download' | 'skip' | 'review';
}

export interface CurationJob {
  id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  category: string;
  source: string;
  query: string;
  discoveredCount: number;
  analyzedCount: number;
  downloadedCount: number;
  skippedCount: number;
  errorCount: number;
  startedAt: string;
  completedAt: string | null;
  errors: string[];
}

export interface CurationStats {
  totalDiscovered: number;
  totalAnalyzed: number;
  totalDownloaded: number;
  totalSkipped: number;
  byCategory: Record<string, number>;
  bySource: Record<string, number>;
  averageQualityScore: number;
  lastRunAt: string;
}

/**
 * Audio Curator - Main service class
 */
export class AudioCurator {
  private env: Env;
  private freesoundApiKey: string;

  constructor(env: Env) {
    this.env = env;
    this.freesoundApiKey = (env as any).FREESOUND_API_KEY || '';
  }

  /**
   * Run a complete curation cycle for all categories
   */
  async runFullCuration(): Promise<CurationStats> {
    console.log('[AudioCurator] Starting full curation cycle...');

    const stats: CurationStats = {
      totalDiscovered: 0,
      totalAnalyzed: 0,
      totalDownloaded: 0,
      totalSkipped: 0,
      byCategory: {},
      bySource: {},
      averageQualityScore: 0,
      lastRunAt: new Date().toISOString(),
    };

    // Process categories by priority
    const sortedCategories = Object.entries(CURATION_QUERIES)
      .sort(([, a], [, b]) => a.priority - b.priority);

    for (const [category, config] of sortedCategories) {
      console.log(`[AudioCurator] Processing category: ${category}`);

      try {
        const categoryStats = await this.curateCategory(category, config);
        stats.totalDiscovered += categoryStats.discovered;
        stats.totalAnalyzed += categoryStats.analyzed;
        stats.totalDownloaded += categoryStats.downloaded;
        stats.totalSkipped += categoryStats.skipped;
        stats.byCategory[category] = categoryStats.downloaded;
      } catch (error) {
        console.error(`[AudioCurator] Error processing ${category}:`, error);
      }
    }

    // Save stats
    await this.saveCurationStats(stats);

    console.log('[AudioCurator] Curation cycle completed:', stats);
    return stats;
  }

  /**
   * Curate a single category
   */
  async curateCategory(
    category: string,
    config: typeof CURATION_QUERIES[keyof typeof CURATION_QUERIES]
  ): Promise<{ discovered: number; analyzed: number; downloaded: number; skipped: number }> {
    const result = { discovered: 0, analyzed: 0, downloaded: 0, skipped: 0 };

    for (const query of config.queries) {
      try {
        // Discover audio from sources
        const discovered = await this.discoverAudio(query, category);
        result.discovered += discovered.length;

        // Analyze each discovered audio
        for (const audio of discovered) {
          const analysis = await this.analyzeAudio(audio, category);
          result.analyzed++;

          if (analysis.recommendedAction === 'download') {
            const success = await this.downloadAndStore(audio, analysis);
            if (success) {
              result.downloaded++;
            } else {
              result.skipped++;
            }
          } else {
            result.skipped++;
          }

          // Rate limiting
          await this.sleep(100);
        }
      } catch (error) {
        console.error(`[AudioCurator] Error with query "${query}":`, error);
      }
    }

    return result;
  }

  /**
   * Discover audio from Freesound
   */
  async discoverAudio(query: string, category: string): Promise<DiscoveredAudio[]> {
    const discovered: DiscoveredAudio[] = [];

    // Freesound search
    if (this.freesoundApiKey) {
      try {
        const freesoundResults = await this.searchFreesound(query);
        discovered.push(...freesoundResults);
      } catch (error) {
        console.error('[AudioCurator] Freesound search failed:', error);
      }
    }

    // Internet Archive search
    try {
      const iaResults = await this.searchInternetArchive(query);
      discovered.push(...iaResults);
    } catch (error) {
      console.error('[AudioCurator] Internet Archive search failed:', error);
    }

    // Filter out already downloaded content
    const newAudio = await this.filterExisting(discovered);

    return newAudio;
  }

  /**
   * Search Freesound.org API
   */
  async searchFreesound(query: string): Promise<DiscoveredAudio[]> {
    const params = new URLSearchParams({
      query,
      page_size: '15',
      filter: 'license:"Creative Commons 0" duration:[30 TO 600]',
      fields: 'id,name,tags,license,username,duration,filesize,type,previews,description,avg_rating,num_downloads',
      sort: 'rating_desc',
      token: this.freesoundApiKey,
    });

    const response = await fetch(
      `${AUDIO_SOURCES.freesound.baseUrl}/search/text/?${params}`
    );

    if (!response.ok) {
      throw new Error(`Freesound API error: ${response.status}`);
    }

    const data = await response.json() as any;

    return (data.results || []).map((sound: any) => ({
      id: `freesound_${sound.id}`,
      source: 'freesound',
      sourceId: sound.id.toString(),
      title: sound.name,
      artist: sound.username,
      description: sound.description || '',
      duration: Math.round(sound.duration),
      fileSize: sound.filesize,
      format: sound.type,
      tags: sound.tags || [],
      license: 'CC0',
      downloadUrl: sound.previews?.['preview-hq-mp3'] || '',
      previewUrl: sound.previews?.['preview-lq-mp3'] || '',
      rating: sound.avg_rating || 0,
      downloads: sound.num_downloads || 0,
    }));
  }

  /**
   * Search Internet Archive
   */
  async searchInternetArchive(query: string): Promise<DiscoveredAudio[]> {
    const params = new URLSearchParams({
      q: `${query} AND mediatype:audio AND licenseurl:*publicdomain*`,
      fl: 'identifier,title,creator,description',
      rows: '10',
      output: 'json',
    });

    const response = await fetch(
      `${AUDIO_SOURCES.internetArchive.baseUrl}/advancedsearch.php?${params}`
    );

    if (!response.ok) {
      throw new Error(`Internet Archive API error: ${response.status}`);
    }

    const data = await response.json() as any;
    const results: DiscoveredAudio[] = [];

    for (const item of (data.response?.docs || []).slice(0, 5)) {
      // Get files for this item
      const filesResponse = await fetch(
        `https://archive.org/metadata/${item.identifier}/files`
      );

      if (filesResponse.ok) {
        const filesData = await filesResponse.json() as any;
        const audioFiles = (filesData.result || []).filter(
          (f: any) => f.format === 'VBR MP3' || f.format === 'Ogg Vorbis'
        );

        for (const file of audioFiles.slice(0, 2)) {
          if (file.length && parseFloat(file.length) >= 30) {
            results.push({
              id: `ia_${item.identifier}_${file.name}`,
              source: 'internet_archive',
              sourceId: `${item.identifier}/${file.name}`,
              title: file.title || file.name.replace(/\.[^.]+$/, ''),
              artist: item.creator || 'Unknown',
              description: item.description || '',
              duration: Math.round(parseFloat(file.length) || 180),
              fileSize: parseInt(file.size) || 0,
              format: file.format.includes('MP3') ? 'mp3' : 'ogg',
              tags: ['classical', 'public domain'],
              license: 'Public Domain',
              downloadUrl: `https://archive.org/download/${item.identifier}/${encodeURIComponent(file.name)}`,
              previewUrl: '',
              rating: 0,
              downloads: 0,
            });
          }
        }
      }

      await this.sleep(200);
    }

    return results;
  }

  /**
   * Filter out already downloaded content
   */
  async filterExisting(audio: DiscoveredAudio[]): Promise<DiscoveredAudio[]> {
    const newAudio: DiscoveredAudio[] = [];

    for (const item of audio) {
      const exists = await this.env.DB.prepare(`
        SELECT 1 FROM tracks WHERE source_id = ? AND source = ?
      `).bind(item.sourceId, item.source).first();

      if (!exists) {
        newAudio.push(item);
      }
    }

    return newAudio;
  }

  /**
   * Check if AI curation is enabled (Gemini free tier — enabled by default)
   */
  private isAIEnabled(): boolean {
    return !!this.env.GEMINI_API_KEY;
  }

  /**
   * Keyword-based scoring fallback (no AI calls, zero cost)
   */
  private keywordScore(audio: DiscoveredAudio, category: string): { score: number; reasoning: string } {
    const text = [audio.title, audio.description, ...audio.tags].join(' ').toLowerCase();

    let score = 0.5;
    const hits: string[] = [];

    // Positive signals
    const positiveKeywords = [
      'calm', 'peaceful', 'relaxing', 'soothing', 'gentle', 'soft',
      'quiet', 'lullaby', 'baby', 'sleep', 'ambient', 'meditative',
      'serene', 'tranquil', 'dreamy', 'nursery', 'infant', 'newborn',
    ];
    for (const kw of positiveKeywords) {
      if (text.includes(kw)) { score += 0.04; hits.push(`+${kw}`); }
    }

    // Negative signals
    const negativeKeywords = [
      'loud', 'intense', 'scary', 'horror', 'explosion', 'alarm',
      'siren', 'scream', 'harsh', 'aggressive', 'metal', 'rock',
      'electronic', 'beat', 'bass', 'energetic', 'fast', 'upbeat',
    ];
    for (const kw of negativeKeywords) {
      if (text.includes(kw)) { score -= 0.08; hits.push(`-${kw}`); }
    }

    // Category match bonus
    const categoryKeywords: Record<string, string[]> = {
      white_noise: ['noise', 'fan', 'vacuum', 'womb', 'shush', 'hum'],
      nature_sounds: ['rain', 'ocean', 'river', 'forest', 'wind', 'water', 'thunder', 'cricket'],
      classical_music: ['classical', 'piano', 'mozart', 'brahms', 'debussy', 'chopin', 'bach'],
      instrumental: ['music box', 'harp', 'guitar', 'chimes', 'bells'],
    };
    for (const kw of (categoryKeywords[category] || [])) {
      if (text.includes(kw)) { score += 0.05; hits.push(`cat:${kw}`); }
    }

    score = Math.max(0, Math.min(1, score));
    const reasoning = hits.length > 0
      ? `Keyword scoring: ${hits.join(', ')} -> ${(score * 10).toFixed(1)}/10`
      : 'Keyword scoring: no strong signals, neutral score.';

    return { score, reasoning };
  }

  /**
   * Analyze audio using AI to determine quality and fit
   */
  async analyzeAudio(audio: DiscoveredAudio, category: string): Promise<AudioAnalysis> {
    // Calculate scores based on metadata
    const safetyScore = this.calculateSafetyScore(audio.tags, audio.title, audio.description);
    const qualityScore = this.calculateQualityScore(audio);
    const babyFitScore = this.calculateBabyFitScore(audio, category);

    let aiReasoning = '';
    let aiScore = 0.5;

    if (this.isAIEnabled()) {
      // AI path: check cache first, then call Workers AI
      try {
        const aiAnalysis = await this.getAIAnalysis(audio, category);
        aiReasoning = aiAnalysis.reasoning;
        aiScore = aiAnalysis.score;
      } catch (error) {
        console.error('[AudioCurator] AI analysis failed, falling back to keywords:', error);
        const fallback = this.keywordScore(audio, category);
        aiReasoning = fallback.reasoning;
        aiScore = fallback.score;
      }
    } else {
      // Default: keyword-based scoring (no AI cost)
      const kw = this.keywordScore(audio, category);
      aiReasoning = kw.reasoning;
      aiScore = kw.score;
    }

    // Calculate calming score
    const calmingScore = this.calculateCalmingScore(audio.tags);

    // Calculate overall score (weighted average)
    const overallScore = (
      safetyScore * 0.3 +
      qualityScore * 0.2 +
      babyFitScore * 0.25 +
      aiScore * 0.25
    );

    // Determine age range based on category
    const ageRange = this.determineAgeRange(category, audio.tags);

    // Determine recommended action
    let recommendedAction: 'download' | 'skip' | 'review' = 'skip';
    if (overallScore >= 0.7 && safetyScore >= 0.8) {
      recommendedAction = 'download';
    } else if (overallScore >= 0.5 && safetyScore >= 0.6) {
      recommendedAction = 'review';
    }

    return {
      audioId: audio.id,
      category,
      calmingScore,
      babyFitScore,
      qualityScore,
      safetyScore,
      overallScore,
      ageRangeMin: ageRange.min,
      ageRangeMax: ageRange.max,
      isPremiumWorthy: overallScore >= 0.85,
      reasoning: aiReasoning,
      recommendedAction,
    };
  }

  /**
   * Use Gemini to analyze audio metadata (with KV cache to avoid duplicate calls)
   */
  async getAIAnalysis(audio: DiscoveredAudio, category: string): Promise<{ score: number; reasoning: string }> {
    // Check KV cache first
    const cacheKey = `ai_analysis:${audio.id}`;
    try {
      const cached = await this.env.CACHE.get(cacheKey, 'json') as { score: number; reasoning: string } | null;
      if (cached) {
        console.log(`[AudioCurator] Cache hit for ${audio.id}`);
        return cached;
      }
    } catch {
      // Cache miss or read error, proceed to AI
    }

    const prompt = `Analyze this audio content for a baby soothing app:

Title: ${audio.title}
Artist: ${audio.artist}
Category: ${category}
Duration: ${audio.duration} seconds
Tags: ${audio.tags.join(', ')}
Description: ${audio.description.substring(0, 500)}

Rate this audio's suitability for calming babies (0-10) and explain why.
Consider:
1. Is it calming and gentle?
2. Is it safe for babies (no sudden loud sounds)?
3. Does it fit the category well?
4. Would parents trust this for their baby?

Respond in this format:
SCORE: [0-10]
REASONING: [1-2 sentences]`;

    try {
      const text = await callGemini(this.env.GEMINI_API_KEY, prompt, 150, this.env.CACHE);
      if (!text) {
        // Daily quota exceeded — fall back to neutral score
        return { score: 0.5, reasoning: 'Daily AI quota reached, using default score.' };
      }

      const scoreMatch = text.match(/SCORE:\s*(\d+(?:\.\d+)?)/i);
      const reasoningMatch = text.match(/REASONING:\s*(.+)/is);

      const score = scoreMatch ? parseFloat(scoreMatch[1]) / 10 : 0.5;
      const reasoning = reasoningMatch ? reasoningMatch[1].trim() : 'Analysis completed.';

      const result = { score: Math.min(1, Math.max(0, score)), reasoning };

      // Cache result for 30 days to avoid re-analyzing
      await this.env.CACHE.put(cacheKey, JSON.stringify(result), {
        expirationTtl: 86400 * 30,
      });

      return result;
    } catch (error) {
      console.error('[AudioCurator] Gemini analysis error:', error);
      return { score: 0.5, reasoning: 'AI analysis unavailable.' };
    }
  }

  /**
   * Calculate safety score based on content
   */
  calculateSafetyScore(tags: string[], title: string, description: string): number {
    let score = 1.0;
    const allText = [...tags, title, description].join(' ').toLowerCase();

    // Penalize excluded tags
    for (const excludeTag of QUALITY_CRITERIA.excludeTags) {
      if (allText.includes(excludeTag)) {
        score -= 0.2;
      }
    }

    // Bonus for preferred tags
    for (const preferTag of QUALITY_CRITERIA.preferredTags) {
      if (allText.includes(preferTag)) {
        score += 0.05;
      }
    }

    return Math.max(0, Math.min(1, score));
  }

  /**
   * Calculate quality score based on audio properties
   */
  calculateQualityScore(audio: DiscoveredAudio): number {
    let score = 0.5;

    // Format bonus
    if (QUALITY_CRITERIA.preferredFormats.includes(audio.format)) {
      score += 0.1;
    }

    // Duration in optimal range
    const durationConfig = QUALITY_CRITERIA.durationRanges.white_noise;
    if (audio.duration >= durationConfig.min && audio.duration <= durationConfig.max) {
      score += 0.2;
      if (Math.abs(audio.duration - durationConfig.optimal) < 60) {
        score += 0.1;
      }
    }

    // Rating bonus
    if (audio.rating >= 4) score += 0.1;
    if (audio.rating >= 4.5) score += 0.1;

    // Download count indicates popularity
    if (audio.downloads > 100) score += 0.05;
    if (audio.downloads > 1000) score += 0.05;

    return Math.min(1, score);
  }

  /**
   * Calculate how well audio fits baby content criteria
   */
  calculateBabyFitScore(audio: DiscoveredAudio, category: string): number {
    let score = 0.5;
    const tags = audio.tags.map(t => t.toLowerCase());
    const title = audio.title.toLowerCase();

    // Baby-specific keywords
    const babyKeywords = ['baby', 'infant', 'newborn', 'lullaby', 'nursery', 'sleep', 'calm'];
    for (const keyword of babyKeywords) {
      if (tags.some(t => t.includes(keyword)) || title.includes(keyword)) {
        score += 0.1;
      }
    }

    // Category-specific fit
    const categoryKeywords: Record<string, string[]> = {
      white_noise: ['noise', 'ambient', 'continuous', 'loop', 'background'],
      nature_sounds: ['nature', 'rain', 'ocean', 'forest', 'water', 'wind'],
      classical_music: ['classical', 'piano', 'orchestra', 'symphony', 'baroque'],
      instrumental: ['music box', 'harp', 'guitar', 'bells', 'chimes'],
    };

    const keywords = categoryKeywords[category] || [];
    for (const keyword of keywords) {
      if (tags.some(t => t.includes(keyword)) || title.includes(keyword)) {
        score += 0.1;
      }
    }

    return Math.min(1, score);
  }

  /**
   * Calculate calming score
   */
  calculateCalmingScore(tags: string[]): number {
    let score = 0.7; // Base score
    const tagStr = tags.join(' ').toLowerCase();

    const calmingIndicators = ['calm', 'peaceful', 'relaxing', 'soothing', 'gentle', 'soft', 'quiet'];
    const energeticIndicators = ['energetic', 'upbeat', 'fast', 'loud', 'intense'];

    for (const indicator of calmingIndicators) {
      if (tagStr.includes(indicator)) score += 0.05;
    }

    for (const indicator of energeticIndicators) {
      if (tagStr.includes(indicator)) score -= 0.1;
    }

    return Math.max(0.3, Math.min(1, score));
  }

  /**
   * Determine age range based on category and tags
   */
  determineAgeRange(category: string, tags: string[]): { min: number; max: number } {
    const tagStr = tags.join(' ').toLowerCase();

    // Newborn-specific content
    if (tagStr.includes('newborn') || tagStr.includes('womb') || tagStr.includes('heartbeat')) {
      return { min: 0, max: 6 };
    }

    // Stories for older babies
    if (category === 'fairy_tales') {
      return { min: 12, max: 36 };
    }

    // Default ranges by category
    const ranges: Record<string, { min: number; max: number }> = {
      white_noise: { min: 0, max: 36 },
      nature_sounds: { min: 0, max: 36 },
      classical_music: { min: 0, max: 36 },
      instrumental: { min: 0, max: 36 },
      children_songs: { min: 3, max: 36 },
    };

    return ranges[category] || { min: 0, max: 36 };
  }

  /**
   * Download audio and store in R2
   */
  async downloadAndStore(audio: DiscoveredAudio, analysis: AudioAnalysis): Promise<boolean> {
    try {
      // Download the audio file
      const response = await fetch(audio.downloadUrl);
      if (!response.ok) {
        console.error(`[AudioCurator] Download failed: ${response.status}`);
        return false;
      }

      const arrayBuffer = await response.arrayBuffer();
      const contentType = response.headers.get('content-type') || 'audio/mpeg';

      // Generate R2 key
      const ext = audio.format || 'mp3';
      const timestamp = Date.now();
      const r2Key = `audio/${analysis.category}/${audio.source}_${audio.sourceId.replace(/[^a-zA-Z0-9]/g, '_')}.${ext}`;

      // Upload to R2
      await this.env.AUDIO_BUCKET.put(r2Key, arrayBuffer, {
        httpMetadata: { contentType },
        customMetadata: {
          source: audio.source,
          sourceId: audio.sourceId,
          title: audio.title,
          analyzedAt: new Date().toISOString(),
        },
      });

      // Save to database
      const trackId = `curated_${timestamp}_${Math.random().toString(36).substr(2, 8)}`;

      await this.env.DB.prepare(`
        INSERT INTO tracks (
          id, title, artist, category, language, duration,
          age_range_min, age_range_max, calming_score,
          audio_source_type, stream_url, is_premium,
          source, source_id, source_url, license, r2_key, file_size, tags,
          created_at
        ) VALUES (?, ?, ?, ?, 'instrumental', ?, ?, ?, ?, 'recorded', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        trackId,
        audio.title,
        audio.artist,
        analysis.category,
        audio.duration,
        analysis.ageRangeMin,
        analysis.ageRangeMax,
        analysis.calmingScore,
        `r2://${r2Key}`,
        analysis.isPremiumWorthy ? 1 : 0,
        audio.source,
        audio.sourceId,
        audio.downloadUrl,
        audio.license,
        r2Key,
        audio.fileSize,
        JSON.stringify(audio.tags),
        new Date().toISOString()
      ).run();

      console.log(`[AudioCurator] Downloaded and stored: ${audio.title} -> ${r2Key}`);
      return true;

    } catch (error) {
      console.error(`[AudioCurator] Error storing ${audio.title}:`, error);
      return false;
    }
  }

  /**
   * Save curation statistics
   */
  async saveCurationStats(stats: CurationStats): Promise<void> {
    await this.env.CACHE.put(
      'curation:latest_stats',
      JSON.stringify(stats),
      { expirationTtl: 86400 * 7 } // Keep for 7 days
    );

    // Also save to history
    const historyKey = `curation:history:${new Date().toISOString().split('T')[0]}`;
    await this.env.CACHE.put(historyKey, JSON.stringify(stats), {
      expirationTtl: 86400 * 30, // Keep for 30 days
    });
  }

  /**
   * Get latest curation statistics
   */
  async getStats(): Promise<CurationStats | null> {
    const stats = await this.env.CACHE.get('curation:latest_stats');
    return stats ? JSON.parse(stats) : null;
  }

  /**
   * Get library summary
   */
  async getLibrarySummary(): Promise<any> {
    const result = await this.env.DB.prepare(`
      SELECT
        category,
        source,
        COUNT(*) as count,
        SUM(duration) as total_duration,
        AVG(calming_score) as avg_calming_score,
        SUM(CASE WHEN is_premium = 1 THEN 1 ELSE 0 END) as premium_count
      FROM tracks
      GROUP BY category, source
      ORDER BY category, source
    `).all();

    return result.results;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * Scheduled handler for cron triggers
 */
export async function handleScheduledCuration(env: Env): Promise<void> {
  console.log('[Scheduled] Starting automated curation...');

  const curator = new AudioCurator(env);

  try {
    const stats = await curator.runFullCuration();
    console.log('[Scheduled] Curation completed:', stats);
  } catch (error) {
    console.error('[Scheduled] Curation failed:', error);
  }
}
