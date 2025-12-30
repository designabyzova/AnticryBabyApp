import { Hono } from 'hono';
import type { Env, Track } from '../types';
import { authMiddleware, optionalAuthMiddleware, adminMiddleware } from '../middleware/auth';

const audio = new Hono<{ Bindings: Env }>();

/**
 * GET /audio/stream/:trackId
 *
 * Stream audio file from R2 bucket.
 * Supports range requests for efficient streaming.
 * Premium content requires subscription.
 */
audio.get('/stream/:trackId', optionalAuthMiddleware, async (c) => {
  const trackId = c.req.param('trackId');

  // Get track metadata from database
  const track = await c.env.DB.prepare(`
    SELECT * FROM tracks WHERE id = ?
  `).bind(trackId).first<Track>();

  if (!track) {
    return c.json({ success: false, error: 'Track not found' }, 404);
  }

  // Check premium access
  const user = c.get('user');
  const isPremium = user && user.subscription_status !== 'free';

  if (track.is_premium && !isPremium) {
    return c.json({
      success: false,
      error: 'Premium subscription required',
      upgrade_required: true,
    }, 403);
  }

  // For generated audio, return generator info (client synthesizes)
  if (track.audio_source_type === 'generated') {
    return c.json({
      success: true,
      audio_source_type: 'generated',
      generator_type: track.generator_type,
      duration: track.duration,
    });
  }

  // Check if we have an R2 key (stored in stream_url as r2://key format)
  const streamUrl = track.stream_url;

  if (!streamUrl) {
    return c.json({ success: false, error: 'Audio file not available' }, 404);
  }

  // If it's an R2 URL, stream from bucket
  if (streamUrl.startsWith('r2://')) {
    const r2Key = streamUrl.replace('r2://', '');
    return streamFromR2(c, r2Key);
  }

  // External URL - redirect
  return c.redirect(streamUrl, 302);
});

/**
 * GET /audio/file/:key
 *
 * Direct file access from R2 bucket by key.
 * Used for CDN/caching integration.
 */
audio.get('/file/*', async (c) => {
  const key = c.req.path.replace('/audio/file/', '');

  if (!key) {
    return c.json({ success: false, error: 'File key required' }, 400);
  }

  return streamFromR2(c, key);
});

/**
 * POST /audio/upload
 *
 * Admin endpoint to upload audio files to R2.
 * Requires admin authentication.
 */
audio.post('/upload', authMiddleware, adminMiddleware, async (c) => {
  const formData = await c.req.formData();
  const file = formData.get('file') as File | null;
  const category = formData.get('category') as string;
  const title = formData.get('title') as string;
  const artist = formData.get('artist') as string || 'Unknown';

  if (!file) {
    return c.json({ success: false, error: 'No file provided' }, 400);
  }

  if (!category || !title) {
    return c.json({ success: false, error: 'Category and title required' }, 400);
  }

  // Validate file type
  const allowedTypes = ['audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/mp4'];
  if (!allowedTypes.includes(file.type)) {
    return c.json({
      success: false,
      error: 'Invalid file type. Allowed: MP3, OGG, WAV, M4A',
    }, 400);
  }

  // Generate unique key
  const ext = file.name.split('.').pop() || 'mp3';
  const timestamp = Date.now();
  const randomId = Math.random().toString(36).substring(2, 10);
  const r2Key = `audio/${category}/${timestamp}_${randomId}.${ext}`;

  try {
    // Upload to R2
    const arrayBuffer = await file.arrayBuffer();
    await c.env.AUDIO_BUCKET.put(r2Key, arrayBuffer, {
      httpMetadata: {
        contentType: file.type,
      },
      customMetadata: {
        title,
        artist,
        category,
        uploadedAt: new Date().toISOString(),
      },
    });

    // Create track in database
    const trackId = `track_${timestamp}_${randomId}`;
    const duration = 0; // Would need audio processing to get actual duration

    await c.env.DB.prepare(`
      INSERT INTO tracks (
        id, title, artist, category, language, duration,
        age_range_min, age_range_max, calming_score,
        audio_source_type, stream_url, is_premium, created_at
      ) VALUES (?, ?, ?, ?, 'en', ?, 0, 36, 0.8, 'recorded', ?, 0, ?)
    `).bind(
      trackId,
      title,
      artist,
      category,
      duration,
      `r2://${r2Key}`,
      new Date().toISOString()
    ).run();

    return c.json({
      success: true,
      track_id: trackId,
      r2_key: r2Key,
      message: 'Audio uploaded successfully',
    });

  } catch (error) {
    console.error('Upload error:', error);
    return c.json({ success: false, error: 'Upload failed' }, 500);
  }
});

/**
 * DELETE /audio/:trackId
 *
 * Admin endpoint to delete audio track and file.
 */
audio.delete('/:trackId', authMiddleware, adminMiddleware, async (c) => {
  const trackId = c.req.param('trackId');

  // Get track to find R2 key
  const track = await c.env.DB.prepare(`
    SELECT * FROM tracks WHERE id = ?
  `).bind(trackId).first<Track>();

  if (!track) {
    return c.json({ success: false, error: 'Track not found' }, 404);
  }

  // Delete from R2 if applicable
  if (track.stream_url?.startsWith('r2://')) {
    const r2Key = track.stream_url.replace('r2://', '');
    try {
      await c.env.AUDIO_BUCKET.delete(r2Key);
    } catch (error) {
      console.error('R2 delete error:', error);
      // Continue even if R2 delete fails
    }
  }

  // Delete from database
  await c.env.DB.prepare(`
    DELETE FROM tracks WHERE id = ?
  `).bind(trackId).run();

  // Also remove from playlists
  await c.env.DB.prepare(`
    DELETE FROM playlist_tracks WHERE track_id = ?
  `).bind(trackId).run();

  return c.json({
    success: true,
    message: 'Track deleted successfully',
  });
});

/**
 * GET /audio/list
 *
 * Admin endpoint to list all files in R2 bucket.
 */
audio.get('/list', authMiddleware, adminMiddleware, async (c) => {
  const prefix = c.req.query('prefix') || 'audio/';
  const limit = parseInt(c.req.query('limit') || '100');
  const cursor = c.req.query('cursor');

  try {
    const listed = await c.env.AUDIO_BUCKET.list({
      prefix,
      limit,
      cursor: cursor || undefined,
    });

    const files = listed.objects.map(obj => ({
      key: obj.key,
      size: obj.size,
      uploaded: obj.uploaded.toISOString(),
      etag: obj.etag,
    }));

    return c.json({
      success: true,
      files,
      truncated: listed.truncated,
      cursor: listed.truncated ? listed.cursor : null,
    });

  } catch (error) {
    console.error('List error:', error);
    return c.json({ success: false, error: 'Failed to list files' }, 500);
  }
});

/**
 * GET /audio/stats
 *
 * Get audio library statistics.
 */
audio.get('/stats', async (c) => {
  try {
    // Count tracks by category
    const categoryStats = await c.env.DB.prepare(`
      SELECT category, COUNT(*) as count,
             SUM(duration) as total_duration,
             AVG(calming_score) as avg_calming_score
      FROM tracks
      GROUP BY category
    `).all();

    // Count by source type
    const sourceStats = await c.env.DB.prepare(`
      SELECT audio_source_type, COUNT(*) as count
      FROM tracks
      GROUP BY audio_source_type
    `).all();

    // Total counts
    const totals = await c.env.DB.prepare(`
      SELECT
        COUNT(*) as total_tracks,
        SUM(duration) as total_duration,
        SUM(CASE WHEN is_premium = 1 THEN 1 ELSE 0 END) as premium_tracks,
        SUM(CASE WHEN is_premium = 0 THEN 1 ELSE 0 END) as free_tracks
      FROM tracks
    `).first();

    return c.json({
      success: true,
      stats: {
        totals,
        by_category: categoryStats.results,
        by_source_type: sourceStats.results,
      },
    });

  } catch (error) {
    console.error('Stats error:', error);
    return c.json({ success: false, error: 'Failed to get stats' }, 500);
  }
});

/**
 * Helper: Stream file from R2 bucket with range support
 */
async function streamFromR2(c: any, key: string): Promise<Response> {
  const rangeHeader = c.req.header('Range');

  try {
    // Check if file exists
    const headObject = await c.env.AUDIO_BUCKET.head(key);
    if (!headObject) {
      return c.json({ success: false, error: 'File not found' }, 404);
    }

    const contentType = headObject.httpMetadata?.contentType || 'audio/mpeg';
    const contentLength = headObject.size;

    // Handle range requests for efficient streaming
    if (rangeHeader) {
      const rangeMatch = rangeHeader.match(/bytes=(\d+)-(\d*)/);
      if (rangeMatch) {
        const start = parseInt(rangeMatch[1]);
        const end = rangeMatch[2] ? parseInt(rangeMatch[2]) : contentLength - 1;

        const object = await c.env.AUDIO_BUCKET.get(key, {
          range: { offset: start, length: end - start + 1 },
        });

        if (!object) {
          return c.json({ success: false, error: 'File not found' }, 404);
        }

        return new Response(object.body, {
          status: 206,
          headers: {
            'Content-Type': contentType,
            'Content-Length': (end - start + 1).toString(),
            'Content-Range': `bytes ${start}-${end}/${contentLength}`,
            'Accept-Ranges': 'bytes',
            'Cache-Control': 'public, max-age=31536000',
          },
        });
      }
    }

    // Full file request
    const object = await c.env.AUDIO_BUCKET.get(key);
    if (!object) {
      return c.json({ success: false, error: 'File not found' }, 404);
    }

    return new Response(object.body, {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Content-Length': contentLength.toString(),
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=31536000',
      },
    });

  } catch (error) {
    console.error('R2 stream error:', error);
    return c.json({ success: false, error: 'Failed to stream file' }, 500);
  }
}

export default audio;
