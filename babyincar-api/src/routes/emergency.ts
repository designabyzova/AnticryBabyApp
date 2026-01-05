/**
 * Emergency Playlist API Routes
 * FS-017: Smart Emergency Playlist System
 *
 * Endpoints for AI-driven cry-scenario playlist selection,
 * emergency session management, and effectiveness tracking.
 */

import { Hono } from 'hono';
import type { Env } from '../index';

const emergency = new Hono<{ Bindings: Env }>();

/**
 * GET /api/playlists/emergency/:cryType
 *
 * Select optimal playlists for a given cry scenario
 *
 * Query params:
 * - language: Comma-separated language codes (e.g., "en,ru")
 * - age: Baby age in months
 * - babyId: Optional baby ID for personalized selection based on history
 *
 * Returns: Array of CryScenarioPlaylist with embedded tracks
 */
emergency.get('/:cryType', async (c) => {
  const { cryType } = c.req.param();
  const language = c.req.query('language') || 'en';
  const age = parseInt(c.req.query('age') || '12');
  const babyId = c.req.query('babyId');

  try {
    // Parse language preferences
    const languages = language.split(',').map(l => l.trim());

    // Build SQL query for playlist selection
    const languageConditions = languages.map(() => '?').join(',');

    const playlistQuery = `
      SELECT *
      FROM cry_scenario_playlists
      WHERE cry_type = ?
        AND (language IN (${languageConditions}) OR language = 'multi')
        AND age_range_min <= ?
        AND age_range_max >= ?
      ORDER BY priority DESC, ai_confidence_score DESC
      LIMIT 3
    `;

    const playlists = await c.env.DB.prepare(playlistQuery)
      .bind(cryType, ...languages, age, age)
      .all();

    // Load tracks for each playlist with metadata
    for (const playlist of playlists.results) {
      const tracksQuery = `
        SELECT
          t.*,
          tm.cry_suitability,
          tm.acoustic_features,
          tm.research_citations,
          tm.emotional_tags,
          tm.cultural_context
        FROM cry_playlist_tracks cpt
        JOIN tracks t ON t.id = cpt.track_id
        LEFT JOIN track_metadata tm ON tm.track_id = t.id
        WHERE cpt.cry_playlist_id = ?
        ORDER BY cpt.position
      `;

      const tracks = await c.env.DB.prepare(tracksQuery)
        .bind(playlist.id)
        .all();

      // Parse JSON fields
      playlist.tracks = tracks.results.map((track: any) => ({
        ...track,
        cry_suitability: track.cry_suitability ? JSON.parse(track.cry_suitability) : null,
        acoustic_features: track.acoustic_features ? JSON.parse(track.acoustic_features) : null,
      }));
    }

    // Apply learning-based ranking if babyId provided
    if (babyId && playlists.results.length > 0) {
      const effectivenessQuery = `
        SELECT cry_playlist_id, AVG(was_effective) as effectiveness_score
        FROM playlist_effectiveness
        WHERE baby_id = ? AND cry_type = ?
        GROUP BY cry_playlist_id
      `;

      const effectiveness = await c.env.DB.prepare(effectivenessQuery)
        .bind(babyId, cryType)
        .all();

      // Create effectiveness map
      const effectivenessMap = new Map(
        effectiveness.results.map((e: any) => [e.cry_playlist_id, e.effectiveness_score])
      );

      // Re-rank playlists by combining AI confidence and historical effectiveness
      playlists.results.sort((a: any, b: any) => {
        const aScore =
          a.ai_confidence_score * 0.4 + (effectivenessMap.get(a.id) || 0.5) * 0.6;
        const bScore =
          b.ai_confidence_score * 0.4 + (effectivenessMap.get(b.id) || 0.5) * 0.6;
        return bScore - aScore;
      });
    }

    return c.json({
      playlists: playlists.results,
      metadata: {
        cryType,
        languages,
        age,
        count: playlists.results.length,
        personalized: !!babyId,
      },
    });
  } catch (error: any) {
    console.error('Playlist selection error:', error);
    return c.json({ error: 'Failed to select playlists', details: error.message }, 500);
  }
});

/**
 * POST /api/emergency/session/start
 *
 * Start a new emergency cry response session
 *
 * Body: { babyId, playlistId }
 * Returns: { sessionId, queueTracks }
 */
emergency.post('/session/start', async (c) => {
  try {
    const { babyId, playlistId } = await c.req.json();

    if (!babyId || !playlistId) {
      return c.json({ error: 'Missing required fields: babyId, playlistId' }, 400);
    }

    // Get playlist tracks in order
    const tracksQuery = `
      SELECT track_id, position
      FROM cry_playlist_tracks
      WHERE cry_playlist_id = ?
      ORDER BY position
    `;

    const tracks = await c.env.DB.prepare(tracksQuery).bind(playlistId).all();

    if (tracks.results.length === 0) {
      return c.json({ error: 'Playlist not found or has no tracks' }, 404);
    }

    const queueTracks = tracks.results.map((t: any) => t.track_id);

    // Create emergency session
    const sessionId = crypto.randomUUID();
    const insertQuery = `
      INSERT INTO emergency_session_queue
      (id, baby_id, cry_playlist_id, current_track_id, queue_tracks, started_at, session_duration_seconds)
      VALUES (?, ?, ?, ?, ?, datetime('now'), 0)
    `;

    await c.env.DB.prepare(insertQuery)
      .bind(sessionId, babyId, playlistId, queueTracks[0], JSON.stringify(queueTracks))
      .run();

    return c.json({
      sessionId,
      queueTracks,
      currentTrackId: queueTracks[0],
    });
  } catch (error: any) {
    console.error('Session start error:', error);
    return c.json({ error: 'Failed to start session', details: error.message }, 500);
  }
});

/**
 * POST /api/emergency/session/end
 *
 * End an emergency session and record effectiveness
 *
 * Body: { sessionId, effective, calmingTimeSeconds, userSwitched }
 * Returns: { success: true }
 */
emergency.post('/session/end', async (c) => {
  try {
    const { sessionId, effective, calmingTimeSeconds, userSwitched } = await c.req.json();

    if (!sessionId || effective === undefined || !calmingTimeSeconds) {
      return c.json(
        { error: 'Missing required fields: sessionId, effective, calmingTimeSeconds' },
        400
      );
    }

    // Get session details
    const sessionQuery = `SELECT * FROM emergency_session_queue WHERE id = ?`;
    const session = await c.env.DB.prepare(sessionQuery).bind(sessionId).first();

    if (!session) {
      return c.json({ error: 'Session not found' }, 404);
    }

    // Update session end time
    const updateSessionQuery = `
      UPDATE emergency_session_queue
      SET ended_at = datetime('now'),
          session_duration_seconds = ?
      WHERE id = ?
    `;

    await c.env.DB.prepare(updateSessionQuery).bind(calmingTimeSeconds, sessionId).run();

    // Get cry_type from playlist
    const playlistQuery = `SELECT cry_type FROM cry_scenario_playlists WHERE id = ?`;
    const playlist = await c.env.DB.prepare(playlistQuery).bind(session.cry_playlist_id).first();

    // Record effectiveness
    const effectivenessId = crypto.randomUUID();
    const insertEffectivenessQuery = `
      INSERT INTO playlist_effectiveness
      (id, baby_id, cry_playlist_id, cry_type, was_effective, calming_time_seconds, user_switched, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
    `;

    await c.env.DB.prepare(insertEffectivenessQuery)
      .bind(
        effectivenessId,
        session.baby_id,
        session.cry_playlist_id,
        playlist?.cry_type || 'general',
        effective ? 1 : 0,
        calmingTimeSeconds,
        userSwitched ? 1 : 0
      )
      .run();

    // Update playlist AI confidence score (running average)
    const avgEffectivenessQuery = `
      SELECT AVG(was_effective) as score
      FROM playlist_effectiveness
      WHERE cry_playlist_id = ?
    `;

    const avgResult = await c.env.DB.prepare(avgEffectivenessQuery)
      .bind(session.cry_playlist_id)
      .first();

    if (avgResult) {
      const updateConfidenceQuery = `
        UPDATE cry_scenario_playlists
        SET ai_confidence_score = ?
        WHERE id = ?
      `;

      await c.env.DB.prepare(updateConfidenceQuery)
        .bind(avgResult.score, session.cry_playlist_id)
        .run();
    }

    return c.json({ success: true, updatedConfidenceScore: avgResult?.score || 0 });
  } catch (error: any) {
    console.error('Session end error:', error);
    return c.json({ error: 'Failed to end session', details: error.message }, 500);
  }
});

/**
 * GET /api/emergency/queue/:sessionId
 *
 * Get current queue state for an active session
 *
 * Returns: { session, currentTrack, upcomingTracks }
 */
emergency.get('/queue/:sessionId', async (c) => {
  try {
    const { sessionId } = c.req.param();

    const sessionQuery = `SELECT * FROM emergency_session_queue WHERE id = ?`;
    const session = await c.env.DB.prepare(sessionQuery).bind(sessionId).first();

    if (!session) {
      return c.json({ error: 'Session not found' }, 404);
    }

    const queueTracks = JSON.parse(session.queue_tracks as string);
    const currentIndex = queueTracks.indexOf(session.current_track_id);

    // Get upcoming tracks (next 5)
    const upcomingTrackIds = queueTracks.slice(currentIndex + 1, currentIndex + 6);

    if (upcomingTrackIds.length > 0) {
      const placeholders = upcomingTrackIds.map(() => '?').join(',');
      const tracksQuery = `SELECT * FROM tracks WHERE id IN (${placeholders})`;

      const tracks = await c.env.DB.prepare(tracksQuery).bind(...upcomingTrackIds).all();

      // Preserve order
      const orderedTracks = upcomingTrackIds.map(id =>
        tracks.results.find((t: any) => t.id === id)
      );

      return c.json({
        session,
        queueTracks,
        currentIndex,
        upcomingTracks: orderedTracks,
      });
    }

    return c.json({
      session,
      queueTracks,
      currentIndex,
      upcomingTracks: [],
    });
  } catch (error: any) {
    console.error('Queue fetch error:', error);
    return c.json({ error: 'Failed to fetch queue', details: error.message }, 500);
  }
});

export default emergency;
