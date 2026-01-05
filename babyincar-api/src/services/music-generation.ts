/**
 * Music Generation Service
 *
 * Integrates with AI music generation APIs to create high-quality
 * baby-appropriate audio content.
 *
 * Supported providers:
 * - Suno API (via sunoapi.org) - Best for lullabies and songs
 * - AIML API - Alternative provider with multiple models
 *
 * @see https://docs.sunoapi.org/
 * @see https://aimlapi.com/suno-ai-api
 */

import type { Env, AudioCategory } from '../types';

// ============================================================================
// Types & Interfaces
// ============================================================================

export interface MusicGenerationRequest {
  /** Text description of the music to generate */
  prompt: string;
  /** Optional custom lyrics */
  lyrics?: string;
  /** Music style/genre tags */
  style?: string;
  /** Title for the generated track */
  title?: string;
  /** Whether to generate instrumental only (no vocals) */
  instrumental?: boolean;
  /** Target duration in seconds (30-240) */
  duration?: number;
  /** Model version to use */
  model?: 'v4' | 'v4.5' | 'v5';
  /** Callback URL for async notification */
  callbackUrl?: string;
}

export interface MusicGenerationResponse {
  success: boolean;
  taskId?: string;
  status?: 'pending' | 'processing' | 'completed' | 'failed';
  tracks?: GeneratedTrack[];
  error?: string;
  creditsUsed?: number;
  creditsRemaining?: number;
}

export interface GeneratedTrack {
  id: string;
  title: string;
  audioUrl: string;
  imageUrl?: string;
  duration: number;
  lyrics?: string;
  style?: string;
  createdAt: string;
}

export interface TaskStatusResponse {
  taskId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  progress?: number;
  tracks?: GeneratedTrack[];
  error?: string;
}

export interface LyricsGenerationRequest {
  prompt: string;
  style?: string;
}

export interface LyricsGenerationResponse {
  success: boolean;
  lyrics?: string;
  title?: string;
  error?: string;
}

export interface CreditBalanceResponse {
  success: boolean;
  credits?: number;
  plan?: string;
  error?: string;
}

// Preset prompts for baby content
export interface BabyMusicPreset {
  id: string;
  name: string;
  category: AudioCategory;
  prompt: string;
  style: string;
  instrumental: boolean;
  targetAge: { min: number; max: number };
  language: string;
}

// ============================================================================
// Baby Music Presets
// ============================================================================

export const BABY_MUSIC_PRESETS: BabyMusicPreset[] = [
  // Lullabies
  {
    id: 'lullaby_gentle_piano',
    name: 'Gentle Piano Lullaby',
    category: 'children_songs',
    prompt: 'A gentle, soothing piano lullaby for babies. Soft, slow tempo around 60 BPM. Warm and comforting melody that helps babies fall asleep. No sudden changes, very peaceful.',
    style: 'lullaby, piano, soft, gentle, soothing, calm, sleep music',
    instrumental: true,
    targetAge: { min: 0, max: 24 },
    language: 'instrumental',
  },
  {
    id: 'lullaby_music_box',
    name: 'Music Box Lullaby',
    category: 'children_songs',
    prompt: 'A delicate music box lullaby. Twinkling, magical sounds like a classic baby mobile. Simple repeating melody, very calming for infants.',
    style: 'music box, lullaby, twinkling, magical, gentle, nursery',
    instrumental: true,
    targetAge: { min: 0, max: 12 },
    language: 'instrumental',
  },
  {
    id: 'lullaby_strings',
    name: 'Soft Strings Lullaby',
    category: 'classical_music',
    prompt: 'A beautiful string quartet lullaby. Warm cello and violin playing a gentle, flowing melody. Classical style, perfect for calming babies.',
    style: 'classical, strings, violin, cello, lullaby, orchestral, soft',
    instrumental: true,
    targetAge: { min: 0, max: 36 },
    language: 'instrumental',
  },
  {
    id: 'lullaby_harp',
    name: 'Heavenly Harp',
    category: 'classical_music',
    prompt: 'Ethereal harp music for babies. Gentle arpeggios, dreamy and peaceful. Like angels playing. Perfect for naptime and bedtime.',
    style: 'harp, ethereal, angelic, peaceful, dreamy, soft',
    instrumental: true,
    targetAge: { min: 0, max: 36 },
    language: 'instrumental',
  },

  // Russian Lullabies
  {
    id: 'ru_lullaby_bayu',
    name: 'Баюшки-баю',
    category: 'children_songs',
    prompt: 'A traditional Russian lullaby "Баюшки-баю". Soft female voice singing in Russian. Gentle piano accompaniment. Very soothing and traditional.',
    style: 'russian lullaby, traditional, soft vocals, piano, soothing',
    instrumental: false,
    targetAge: { min: 0, max: 36 },
    language: 'ru',
  },
  {
    id: 'ru_lullaby_spi',
    name: 'Спи, малыш',
    category: 'children_songs',
    prompt: 'Russian lullaby "Спи, малыш". Tender female voice, slow tempo. Warm and loving melody about sweet dreams. Simple piano and soft strings.',
    style: 'russian, lullaby, tender vocals, piano, strings, slow',
    instrumental: false,
    targetAge: { min: 0, max: 24 },
    language: 'ru',
  },

  // Nature-inspired
  {
    id: 'nature_rain_melody',
    name: 'Rainy Day Melody',
    category: 'nature_sounds',
    prompt: 'Soft piano music with gentle rain sounds in the background. Peaceful and calming, like watching rain from a cozy room. Perfect for baby relaxation.',
    style: 'ambient, piano, rain sounds, relaxing, peaceful, soft',
    instrumental: true,
    targetAge: { min: 0, max: 36 },
    language: 'instrumental',
  },
  {
    id: 'nature_ocean_dreams',
    name: 'Ocean Dreams',
    category: 'nature_sounds',
    prompt: 'Gentle music with soft ocean wave sounds. Dreamy synthesizer pads and distant piano. Like being by the peaceful sea. Very calming for babies.',
    style: 'ambient, ocean, waves, dreamy, synthesizer, calm',
    instrumental: true,
    targetAge: { min: 0, max: 36 },
    language: 'instrumental',
  },

  // Children's Songs (with vocals)
  {
    id: 'song_twinkle',
    name: 'Twinkle Twinkle Little Star',
    category: 'children_songs',
    prompt: 'A beautiful, slow version of Twinkle Twinkle Little Star. Soft female voice, gentle piano. Very calming arrangement for babies.',
    style: 'nursery rhyme, lullaby, soft vocals, piano, gentle',
    instrumental: false,
    targetAge: { min: 0, max: 36 },
    language: 'en',
  },
  {
    id: 'song_hush',
    name: 'Hush Little Baby',
    category: 'children_songs',
    prompt: 'Hush Little Baby traditional lullaby. Tender female voice, acoustic guitar, very slow and soothing. Perfect for calming crying babies.',
    style: 'traditional lullaby, acoustic, tender vocals, slow',
    instrumental: false,
    targetAge: { min: 0, max: 24 },
    language: 'en',
  },

  // Ambient/Meditation
  {
    id: 'ambient_womb',
    name: 'Womb Sounds',
    category: 'white_noise',
    prompt: 'Recreate the sounds a baby hears in the womb. Deep, warm rumbling, muffled heartbeat, gentle swooshing. Very comforting for newborns.',
    style: 'ambient, womb sounds, heartbeat, white noise, deep',
    instrumental: true,
    targetAge: { min: 0, max: 6 },
    language: 'instrumental',
  },
  {
    id: 'ambient_meditation',
    name: 'Baby Meditation',
    category: 'instrumental',
    prompt: 'Gentle meditation music for babies. Soft singing bowls, gentle bells, peaceful drones. Very slow and hypnotic, helps babies relax.',
    style: 'meditation, singing bowls, bells, ambient, peaceful',
    instrumental: true,
    targetAge: { min: 0, max: 36 },
    language: 'instrumental',
  },
];

// ============================================================================
// Music Generation Service Class
// ============================================================================

export class MusicGenerationService {
  private apiKey: string;
  private baseUrl: string;
  private provider: 'sunoapi' | 'aimlapi';

  constructor(env: Env) {
    // Try Suno API first, fall back to AIML API
    if (env.SUNO_API_KEY) {
      this.apiKey = env.SUNO_API_KEY;
      this.baseUrl = 'https://api.sunoapi.org';
      this.provider = 'sunoapi';
    } else if (env.AIML_API_KEY) {
      this.apiKey = env.AIML_API_KEY;
      this.baseUrl = 'https://api.aimlapi.com';
      this.provider = 'aimlapi';
    } else {
      throw new Error('No music generation API key configured. Set SUNO_API_KEY or AIML_API_KEY.');
    }
  }

  /**
   * Generate music from a text prompt
   */
  async generate(request: MusicGenerationRequest): Promise<MusicGenerationResponse> {
    if (this.provider === 'sunoapi') {
      return this.generateWithSunoApi(request);
    } else {
      return this.generateWithAimlApi(request);
    }
  }

  /**
   * Generate music using Suno API
   */
  private async generateWithSunoApi(request: MusicGenerationRequest): Promise<MusicGenerationResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/generate`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt: request.prompt,
          custom_lyrics: request.lyrics,
          style: request.style,
          title: request.title,
          instrumental: request.instrumental ?? true,
          model: request.model || 'v4.5',
          callback_url: request.callbackUrl,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return {
          success: false,
          error: `Suno API error: ${response.status} - ${JSON.stringify(errorData)}`,
        };
      }

      const data = await response.json() as any;

      return {
        success: true,
        taskId: data.task_id || data.id,
        status: this.mapStatus(data.status),
        tracks: data.data?.map(this.mapTrack) || [],
        creditsUsed: data.credits_used,
        creditsRemaining: data.credits_remaining,
      };
    } catch (error) {
      return {
        success: false,
        error: `Failed to generate music: ${error instanceof Error ? error.message : 'Unknown error'}`,
      };
    }
  }

  /**
   * Generate music using AIML API
   */
  private async generateWithAimlApi(request: MusicGenerationRequest): Promise<MusicGenerationResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/v1/music/generate`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'chirp-v3-5',
          prompt: request.prompt,
          lyrics: request.lyrics,
          tags: request.style,
          title: request.title,
          make_instrumental: request.instrumental ?? true,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return {
          success: false,
          error: `AIML API error: ${response.status} - ${JSON.stringify(errorData)}`,
        };
      }

      const data = await response.json() as any;

      return {
        success: true,
        taskId: data.id,
        status: this.mapStatus(data.status),
        tracks: data.tracks?.map(this.mapTrack) || [],
      };
    } catch (error) {
      return {
        success: false,
        error: `Failed to generate music: ${error instanceof Error ? error.message : 'Unknown error'}`,
      };
    }
  }

  /**
   * Check the status of a generation task
   */
  async getTaskStatus(taskId: string): Promise<TaskStatusResponse> {
    try {
      const endpoint = this.provider === 'sunoapi'
        ? `${this.baseUrl}/api/v1/generate/record-info?ids=${taskId}`
        : `${this.baseUrl}/v1/music/status/${taskId}`;

      const response = await fetch(endpoint, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
        },
      });

      if (!response.ok) {
        return {
          taskId,
          status: 'failed',
          error: `Failed to get status: ${response.status}`,
        };
      }

      const data = await response.json() as any;

      if (this.provider === 'sunoapi') {
        const record = data.data?.[0] || data;
        return {
          taskId,
          status: this.mapStatus(record.status),
          progress: record.progress,
          tracks: record.status === 'completed' ? [this.mapTrack(record)] : undefined,
          error: record.error_message,
        };
      } else {
        return {
          taskId,
          status: this.mapStatus(data.status),
          progress: data.progress,
          tracks: data.tracks?.map(this.mapTrack),
          error: data.error,
        };
      }
    } catch (error) {
      return {
        taskId,
        status: 'failed',
        error: `Failed to get status: ${error instanceof Error ? error.message : 'Unknown error'}`,
      };
    }
  }

  /**
   * Generate lyrics from a prompt
   */
  async generateLyrics(request: LyricsGenerationRequest): Promise<LyricsGenerationResponse> {
    if (this.provider !== 'sunoapi') {
      return {
        success: false,
        error: 'Lyrics generation only supported with Suno API',
      };
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/v1/lyrics`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt: request.prompt,
          style: request.style,
        }),
      });

      if (!response.ok) {
        return {
          success: false,
          error: `Lyrics generation failed: ${response.status}`,
        };
      }

      const data = await response.json() as any;

      return {
        success: true,
        lyrics: data.lyrics || data.text,
        title: data.title,
      };
    } catch (error) {
      return {
        success: false,
        error: `Failed to generate lyrics: ${error instanceof Error ? error.message : 'Unknown error'}`,
      };
    }
  }

  /**
   * Get current credit balance
   */
  async getCreditBalance(): Promise<CreditBalanceResponse> {
    if (this.provider !== 'sunoapi') {
      return {
        success: false,
        error: 'Credit balance only available with Suno API',
      };
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/v1/generate/credit`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
        },
      });

      if (!response.ok) {
        return {
          success: false,
          error: `Failed to get credits: ${response.status}`,
        };
      }

      const data = await response.json() as any;

      return {
        success: true,
        credits: data.credits || data.remaining,
        plan: data.plan,
      };
    } catch (error) {
      return {
        success: false,
        error: `Failed to get credits: ${error instanceof Error ? error.message : 'Unknown error'}`,
      };
    }
  }

  /**
   * Generate music from a preset
   */
  async generateFromPreset(presetId: string, callbackUrl?: string): Promise<MusicGenerationResponse> {
    const preset = BABY_MUSIC_PRESETS.find(p => p.id === presetId);
    if (!preset) {
      return {
        success: false,
        error: `Preset not found: ${presetId}`,
      };
    }

    return this.generate({
      prompt: preset.prompt,
      style: preset.style,
      title: preset.name,
      instrumental: preset.instrumental,
      callbackUrl,
    });
  }

  /**
   * Get all available presets
   */
  getPresets(): BabyMusicPreset[] {
    return BABY_MUSIC_PRESETS;
  }

  /**
   * Get presets filtered by category
   */
  getPresetsByCategory(category: AudioCategory): BabyMusicPreset[] {
    return BABY_MUSIC_PRESETS.filter(p => p.category === category);
  }

  /**
   * Get presets suitable for a specific age
   */
  getPresetsForAge(ageMonths: number): BabyMusicPreset[] {
    return BABY_MUSIC_PRESETS.filter(
      p => ageMonths >= p.targetAge.min && ageMonths <= p.targetAge.max
    );
  }

  // Helper methods
  private mapStatus(status: string): 'pending' | 'processing' | 'completed' | 'failed' {
    const statusMap: Record<string, 'pending' | 'processing' | 'completed' | 'failed'> = {
      'pending': 'pending',
      'queued': 'pending',
      'submitted': 'pending',
      'processing': 'processing',
      'running': 'processing',
      'in_progress': 'processing',
      'completed': 'completed',
      'complete': 'completed',
      'success': 'completed',
      'done': 'completed',
      'failed': 'failed',
      'error': 'failed',
    };
    return statusMap[status?.toLowerCase()] || 'pending';
  }

  private mapTrack(data: any): GeneratedTrack {
    return {
      id: data.id || data.song_id || data.clip_id,
      title: data.title || data.song_name || 'Untitled',
      audioUrl: data.audio_url || data.song_url || data.url,
      imageUrl: data.image_url || data.cover_url || data.artwork_url,
      duration: data.duration || data.song_duration || 0,
      lyrics: data.lyrics || data.prompt,
      style: data.style || data.tags,
      createdAt: data.created_at || new Date().toISOString(),
    };
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Download generated audio and upload to R2
 */
export async function downloadAndStoreTrack(
  env: Env,
  track: GeneratedTrack,
  category: AudioCategory
): Promise<{ r2Key: string; trackId: string } | null> {
  try {
    // Download the audio file
    const audioResponse = await fetch(track.audioUrl);
    if (!audioResponse.ok) {
      console.error(`Failed to download track: ${audioResponse.status}`);
      return null;
    }

    const audioBuffer = await audioResponse.arrayBuffer();

    // Generate R2 key
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(2, 10);
    const r2Key = `audio/${category}/${timestamp}_${randomId}.mp3`;

    // Upload to R2
    await env.AUDIO_BUCKET.put(r2Key, audioBuffer, {
      httpMetadata: {
        contentType: 'audio/mpeg',
      },
      customMetadata: {
        title: track.title,
        source: 'ai-generated',
        generatedAt: track.createdAt,
      },
    });

    // Create track in database
    const trackId = `track_${timestamp}_${randomId}`;
    await env.DB.prepare(`
      INSERT INTO tracks (
        id, title, artist, category, language, duration,
        age_range_min, age_range_max, calming_score,
        audio_source_type, generator_type, stream_url, is_premium, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      trackId,
      track.title,
      'AI Generated',
      category,
      'en',
      Math.round(track.duration),
      0,
      36,
      0.85,
      'generated',
      'suno-ai',
      `r2://${r2Key}`,
      0,
      new Date().toISOString()
    ).run();

    return { r2Key, trackId };
  } catch (error) {
    console.error('Failed to download and store track:', error);
    return null;
  }
}

export default MusicGenerationService;
