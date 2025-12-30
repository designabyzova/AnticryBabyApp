import { Hono } from 'hono';
import type { Env } from '../types';
import { authMiddleware, adminMiddleware } from '../middleware/auth';
import { AudioCurator, CURATION_QUERIES } from '../services/audio-curator';

const curation = new Hono<{ Bindings: Env }>();

/**
 * GET /curation/stats
 *
 * Get current curation statistics and library summary.
 */
curation.get('/stats', async (c) => {
  const curator = new AudioCurator(c.env);

  const [stats, librarySummary] = await Promise.all([
    curator.getStats(),
    curator.getLibrarySummary(),
  ]);

  // Get total counts
  const totals = await c.env.DB.prepare(`
    SELECT
      COUNT(*) as total_tracks,
      SUM(duration) as total_duration,
      COUNT(DISTINCT source) as sources_count,
      COUNT(DISTINCT category) as categories_count,
      SUM(file_size) as total_size_bytes,
      AVG(calming_score) as avg_calming_score
    FROM tracks
  `).first();

  // Get recent additions
  const recentTracks = await c.env.DB.prepare(`
    SELECT id, title, artist, category, source, calming_score, created_at
    FROM tracks
    ORDER BY created_at DESC
    LIMIT 10
  `).all();

  return c.json({
    success: true,
    library: {
      totals: {
        ...totals,
        total_size_mb: totals?.total_size_bytes
          ? Math.round((totals.total_size_bytes as number) / 1024 / 1024)
          : 0,
        total_hours: totals?.total_duration
          ? Math.round((totals.total_duration as number) / 3600 * 10) / 10
          : 0,
      },
      by_category_and_source: librarySummary,
      recent_additions: recentTracks.results,
    },
    curation: stats || { message: 'No curation runs yet' },
    available_categories: Object.keys(CURATION_QUERIES),
  });
});

/**
 * POST /curation/run
 *
 * Manually trigger a curation run. Admin only.
 */
curation.post('/run', authMiddleware, adminMiddleware, async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const category = body.category as string | undefined;

  const curator = new AudioCurator(c.env);

  // Run in background (don't await)
  c.executionCtx.waitUntil(
    (async () => {
      try {
        if (category && CURATION_QUERIES[category as keyof typeof CURATION_QUERIES]) {
          // Run single category
          const config = CURATION_QUERIES[category as keyof typeof CURATION_QUERIES];
          const result = await curator.curateCategory(category, config);
          console.log(`[Curation] Category ${category} completed:`, result);
        } else {
          // Run full curation
          const stats = await curator.runFullCuration();
          console.log('[Curation] Full run completed:', stats);
        }
      } catch (error) {
        console.error('[Curation] Run failed:', error);
      }
    })()
  );

  return c.json({
    success: true,
    message: category
      ? `Curation started for category: ${category}`
      : 'Full curation started',
    note: 'Running in background. Check /curation/stats for progress.',
  });
});

/**
 * GET /curation/discover
 *
 * Preview what would be discovered without downloading.
 * Useful for testing search queries.
 */
curation.get('/discover', authMiddleware, adminMiddleware, async (c) => {
  const query = c.req.query('query') || 'white noise baby';
  const category = c.req.query('category') || 'white_noise';

  const curator = new AudioCurator(c.env);

  try {
    const discovered = await curator.discoverAudio(query, category);

    // Analyze first few without downloading
    const analyzed = [];
    for (const audio of discovered.slice(0, 5)) {
      const analysis = await curator.analyzeAudio(audio, category);
      analyzed.push({
        audio: {
          id: audio.id,
          title: audio.title,
          artist: audio.artist,
          duration: audio.duration,
          source: audio.source,
          tags: audio.tags.slice(0, 10),
          rating: audio.rating,
        },
        analysis: {
          category: analysis.category,
          overallScore: Math.round(analysis.overallScore * 100) / 100,
          calmingScore: Math.round(analysis.calmingScore * 100) / 100,
          safetyScore: Math.round(analysis.safetyScore * 100) / 100,
          recommendedAction: analysis.recommendedAction,
          reasoning: analysis.reasoning,
        },
      });
    }

    return c.json({
      success: true,
      query,
      category,
      total_discovered: discovered.length,
      samples: analyzed,
    });

  } catch (error) {
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Discovery failed',
    }, 500);
  }
});

/**
 * GET /curation/history
 *
 * Get curation run history.
 */
curation.get('/history', authMiddleware, adminMiddleware, async (c) => {
  const days = parseInt(c.req.query('days') || '7');

  const history: any[] = [];
  const now = new Date();

  for (let i = 0; i < days; i++) {
    const date = new Date(now);
    date.setDate(date.getDate() - i);
    const dateStr = date.toISOString().split('T')[0];

    const stats = await c.env.CACHE.get(`curation:history:${dateStr}`);
    if (stats) {
      history.push({
        date: dateStr,
        stats: JSON.parse(stats),
      });
    }
  }

  return c.json({
    success: true,
    history,
  });
});

/**
 * GET /curation/sources
 *
 * Get configured audio sources and their status.
 */
curation.get('/sources', async (c) => {
  const sources = await c.env.DB.prepare(`
    SELECT * FROM audio_sources ORDER BY name
  `).all();

  // Count tracks per source
  const counts = await c.env.DB.prepare(`
    SELECT source, COUNT(*) as count
    FROM tracks
    GROUP BY source
  `).all();

  const countMap = new Map(
    counts.results.map((r: any) => [r.source, r.count])
  );

  const enrichedSources = sources.results.map((source: any) => ({
    ...source,
    track_count: countMap.get(source.id) || 0,
  }));

  return c.json({
    success: true,
    sources: enrichedSources,
  });
});

/**
 * POST /curation/sources/:id/toggle
 *
 * Enable or disable an audio source.
 */
curation.post('/sources/:id/toggle', authMiddleware, adminMiddleware, async (c) => {
  const sourceId = c.req.param('id');

  const source = await c.env.DB.prepare(`
    SELECT * FROM audio_sources WHERE id = ?
  `).bind(sourceId).first();

  if (!source) {
    return c.json({ success: false, error: 'Source not found' }, 404);
  }

  const newStatus = (source as any).is_active ? 0 : 1;

  await c.env.DB.prepare(`
    UPDATE audio_sources SET is_active = ? WHERE id = ?
  `).bind(newStatus, sourceId).run();

  return c.json({
    success: true,
    source_id: sourceId,
    is_active: newStatus === 1,
  });
});

/**
 * GET /curation/quality-report
 *
 * Get a quality report of the audio library.
 */
curation.get('/quality-report', async (c) => {
  // Score distribution
  const scoreDistribution = await c.env.DB.prepare(`
    SELECT
      CASE
        WHEN calming_score >= 0.9 THEN 'excellent'
        WHEN calming_score >= 0.8 THEN 'very_good'
        WHEN calming_score >= 0.7 THEN 'good'
        WHEN calming_score >= 0.6 THEN 'acceptable'
        ELSE 'needs_review'
      END as quality_tier,
      COUNT(*) as count
    FROM tracks
    GROUP BY quality_tier
    ORDER BY quality_tier
  `).all();

  // Top rated tracks
  const topTracks = await c.env.DB.prepare(`
    SELECT id, title, artist, category, calming_score, source
    FROM tracks
    ORDER BY calming_score DESC
    LIMIT 20
  `).all();

  // Lowest rated (might need review)
  const needsReview = await c.env.DB.prepare(`
    SELECT id, title, artist, category, calming_score, source
    FROM tracks
    WHERE calming_score < 0.6
    ORDER BY calming_score ASC
    LIMIT 10
  `).all();

  // Category health
  const categoryHealth = await c.env.DB.prepare(`
    SELECT
      category,
      COUNT(*) as track_count,
      AVG(calming_score) as avg_score,
      MIN(calming_score) as min_score,
      MAX(calming_score) as max_score,
      SUM(duration) / 60 as total_minutes
    FROM tracks
    GROUP BY category
    ORDER BY avg_score DESC
  `).all();

  return c.json({
    success: true,
    report: {
      score_distribution: scoreDistribution.results,
      top_tracks: topTracks.results,
      needs_review: needsReview.results,
      category_health: categoryHealth.results,
      generated_at: new Date().toISOString(),
    },
  });
});

/**
 * DELETE /curation/tracks/:id
 *
 * Remove a low-quality track from the library.
 */
curation.delete('/tracks/:id', authMiddleware, adminMiddleware, async (c) => {
  const trackId = c.req.param('id');

  const track = await c.env.DB.prepare(`
    SELECT * FROM tracks WHERE id = ?
  `).bind(trackId).first();

  if (!track) {
    return c.json({ success: false, error: 'Track not found' }, 404);
  }

  // Delete from R2 if exists
  const r2Key = (track as any).r2_key;
  if (r2Key) {
    try {
      await c.env.AUDIO_BUCKET.delete(r2Key);
    } catch (error) {
      console.error('R2 delete failed:', error);
    }
  }

  // Delete from database
  await c.env.DB.prepare(`DELETE FROM tracks WHERE id = ?`).bind(trackId).run();
  await c.env.DB.prepare(`DELETE FROM playlist_tracks WHERE track_id = ?`).bind(trackId).run();

  return c.json({
    success: true,
    message: 'Track deleted',
    track_id: trackId,
  });
});

export default curation;
