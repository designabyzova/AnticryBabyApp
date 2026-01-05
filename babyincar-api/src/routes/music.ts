/**
 * Music Generation Routes
 *
 * API endpoints for AI-powered music generation.
 * Uses Suno API or AIML API to create baby-appropriate audio content.
 */

import { Hono } from 'hono';
import type { Env, AudioCategory } from '../types';
import { authMiddleware, adminMiddleware } from '../middleware/auth';
import {
  MusicGenerationService,
  BABY_MUSIC_PRESETS,
  downloadAndStoreTrack,
  type MusicGenerationRequest,
} from '../services/music-generation';

const music = new Hono<{ Bindings: Env }>();

/**
 * GET /music/presets
 *
 * List all available music generation presets.
 * These are pre-configured prompts optimized for baby content.
 */
music.get('/presets', async (c) => {
  const category = c.req.query('category') as AudioCategory | undefined;
  const ageMonths = c.req.query('age') ? parseInt(c.req.query('age')!) : undefined;

  let presets = BABY_MUSIC_PRESETS;

  if (category) {
    presets = presets.filter(p => p.category === category);
  }

  if (ageMonths !== undefined) {
    presets = presets.filter(
      p => ageMonths >= p.targetAge.min && ageMonths <= p.targetAge.max
    );
  }

  return c.json({
    success: true,
    presets: presets.map(p => ({
      id: p.id,
      name: p.name,
      category: p.category,
      instrumental: p.instrumental,
      language: p.language,
      targetAge: p.targetAge,
    })),
  });
});

/**
 * GET /music/presets/:id
 *
 * Get details of a specific preset.
 */
music.get('/presets/:id', async (c) => {
  const presetId = c.req.param('id');
  const preset = BABY_MUSIC_PRESETS.find(p => p.id === presetId);

  if (!preset) {
    return c.json({ success: false, error: 'Preset not found' }, 404);
  }

  return c.json({
    success: true,
    preset,
  });
});

/**
 * POST /music/generate
 *
 * Generate music from a custom prompt.
 * Requires admin authentication.
 */
music.post('/generate', authMiddleware, adminMiddleware, async (c) => {
  try {
    const service = new MusicGenerationService(c.env);
    const body = await c.req.json<MusicGenerationRequest>();

    if (!body.prompt) {
      return c.json({ success: false, error: 'Prompt is required' }, 400);
    }

    // Add callback URL for async processing
    const callbackUrl = c.req.query('callback_url');

    const result = await service.generate({
      ...body,
      callbackUrl: callbackUrl || undefined,
    });

    if (!result.success) {
      return c.json(result, 500);
    }

    return c.json({
      success: true,
      taskId: result.taskId,
      status: result.status,
      tracks: result.tracks,
      credits: {
        used: result.creditsUsed,
        remaining: result.creditsRemaining,
      },
    });
  } catch (error) {
    console.error('Music generation error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Music generation failed',
    }, 500);
  }
});

/**
 * POST /music/generate/preset/:id
 *
 * Generate music from a preset.
 * Requires admin authentication.
 */
music.post('/generate/preset/:id', authMiddleware, adminMiddleware, async (c) => {
  try {
    const presetId = c.req.param('id');
    const service = new MusicGenerationService(c.env);

    const callbackUrl = c.req.query('callback_url');

    const result = await service.generateFromPreset(presetId, callbackUrl || undefined);

    if (!result.success) {
      return c.json(result, result.error?.includes('not found') ? 404 : 500);
    }

    return c.json({
      success: true,
      taskId: result.taskId,
      status: result.status,
      preset: presetId,
    });
  } catch (error) {
    console.error('Preset generation error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Generation failed',
    }, 500);
  }
});

/**
 * GET /music/status/:taskId
 *
 * Check the status of a music generation task.
 */
music.get('/status/:taskId', authMiddleware, async (c) => {
  try {
    const taskId = c.req.param('taskId');
    const service = new MusicGenerationService(c.env);

    const status = await service.getTaskStatus(taskId);

    return c.json({
      success: true,
      ...status,
    });
  } catch (error) {
    console.error('Status check error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Status check failed',
    }, 500);
  }
});

/**
 * POST /music/store/:taskId
 *
 * Download completed generation and store in R2.
 * Requires admin authentication.
 */
music.post('/store/:taskId', authMiddleware, adminMiddleware, async (c) => {
  try {
    const taskId = c.req.param('taskId');
    const service = new MusicGenerationService(c.env);

    // Get task status first
    const status = await service.getTaskStatus(taskId);

    if (status.status !== 'completed') {
      return c.json({
        success: false,
        error: `Task not completed. Current status: ${status.status}`,
        status: status.status,
      }, 400);
    }

    if (!status.tracks || status.tracks.length === 0) {
      return c.json({
        success: false,
        error: 'No tracks found in completed task',
      }, 404);
    }

    // Get category from request body or default to instrumental
    const body = await c.req.json<{ category?: AudioCategory }>().catch(() => ({ category: undefined }));
    const category: AudioCategory = body.category || 'instrumental';

    // Download and store each track
    const storedTracks = [];
    for (const track of status.tracks) {
      const result = await downloadAndStoreTrack(c.env, track, category);
      if (result) {
        storedTracks.push({
          originalId: track.id,
          trackId: result.trackId,
          r2Key: result.r2Key,
          title: track.title,
        });
      }
    }

    return c.json({
      success: true,
      stored: storedTracks.length,
      tracks: storedTracks,
    });
  } catch (error) {
    console.error('Store error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to store tracks',
    }, 500);
  }
});

/**
 * POST /music/lyrics
 *
 * Generate lyrics for a baby song.
 * Requires admin authentication.
 */
music.post('/lyrics', authMiddleware, adminMiddleware, async (c) => {
  try {
    const service = new MusicGenerationService(c.env);
    const body = await c.req.json<{ prompt: string; style?: string }>();

    if (!body.prompt) {
      return c.json({ success: false, error: 'Prompt is required' }, 400);
    }

    const result = await service.generateLyrics({
      prompt: body.prompt,
      style: body.style,
    });

    return c.json(result);
  } catch (error) {
    console.error('Lyrics generation error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Lyrics generation failed',
    }, 500);
  }
});

/**
 * GET /music/credits
 *
 * Get current API credit balance.
 * Requires admin authentication.
 */
music.get('/credits', authMiddleware, adminMiddleware, async (c) => {
  try {
    const service = new MusicGenerationService(c.env);
    const result = await service.getCreditBalance();

    return c.json(result);
  } catch (error) {
    console.error('Credits check error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get credits',
    }, 500);
  }
});

/**
 * POST /music/callback
 *
 * Webhook callback for async music generation.
 * Called by the music generation API when a task completes.
 */
music.post('/callback', async (c) => {
  try {
    const body = await c.req.json<any>();

    console.log('[Music Callback] Received:', JSON.stringify(body).substring(0, 500));

    // Validate the callback (in production, verify signature)
    if (!body.task_id && !body.id) {
      return c.json({ success: false, error: 'Invalid callback data' }, 400);
    }

    const taskId = body.task_id || body.id;
    const status = body.status;

    // Store callback data in KV for retrieval
    await c.env.CACHE.put(
      `music_callback:${taskId}`,
      JSON.stringify({
        ...body,
        received_at: new Date().toISOString(),
      }),
      { expirationTtl: 86400 } // 24 hours
    );

    // If completed with tracks, auto-store them
    if (status === 'completed' || status === 'complete') {
      console.log(`[Music Callback] Task ${taskId} completed, processing tracks...`);

      // Note: In production, you might want to queue this for background processing
    }

    return c.json({ success: true, received: true });
  } catch (error) {
    console.error('Callback error:', error);
    return c.json({
      success: false,
      error: 'Callback processing failed',
    }, 500);
  }
});

/**
 * POST /music/batch
 *
 * Generate multiple tracks from presets.
 * Useful for populating the library.
 * Requires admin authentication.
 */
music.post('/batch', authMiddleware, adminMiddleware, async (c) => {
  try {
    const service = new MusicGenerationService(c.env);
    const body = await c.req.json<{ presetIds: string[]; callbackUrl?: string }>();

    if (!body.presetIds || body.presetIds.length === 0) {
      return c.json({ success: false, error: 'presetIds array is required' }, 400);
    }

    if (body.presetIds.length > 10) {
      return c.json({ success: false, error: 'Maximum 10 presets per batch' }, 400);
    }

    const results = [];
    for (const presetId of body.presetIds) {
      const result = await service.generateFromPreset(presetId, body.callbackUrl);
      results.push({
        presetId,
        success: result.success,
        taskId: result.taskId,
        error: result.error,
      });

      // Small delay between requests to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    const successCount = results.filter(r => r.success).length;

    return c.json({
      success: successCount > 0,
      total: body.presetIds.length,
      succeeded: successCount,
      failed: body.presetIds.length - successCount,
      results,
    });
  } catch (error) {
    console.error('Batch generation error:', error);
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Batch generation failed',
    }, 500);
  }
});

export default music;
