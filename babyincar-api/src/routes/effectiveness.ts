import { Hono } from 'hono';
import type { Env } from '../types';
import { authMiddleware } from '../middleware/auth';
import { generateId } from '../utils/auth';

// Cry types enum (matches iOS CryType)
type CryType = 'hunger' | 'tired' | 'pain' | 'attention' | 'discomfort' | 'general' | 'unknown';

// Request types for FS-029 effectiveness sync
interface CryTypeEffectivenessRecord {
  track_id: string;
  cry_type: CryType;
  helped_count: number;
  not_helped_count: number;
  total_play_duration_seconds: number;
  avg_effectiveness_score: number;
  auto_detected_helped: number;
  auto_detected_weight: number;
  last_played_at: string | null;
}

interface SyncEffectivenessRequest {
  records: CryTypeEffectivenessRecord[];
  last_sync_at?: string;
}

interface FeedbackSessionRecord {
  id: string;
  baby_id?: string;
  cry_type: CryType;
  start_time: string;
  end_time?: string;
  outcome?: 'helped_manual' | 'helped_auto' | 'not_helped' | 'abandoned' | 'cry_type_changed';
  tracks_played: string[];  // JSON array of track IDs
  session_duration_seconds: number;
  tracks_count: number;
}

interface TrackFeedbackEventRecord {
  session_id: string;
  track_id: string;
  cry_type: CryType;
  event_type: 'played' | 'helped_manual' | 'helped_auto' | 'not_helped' | 'skipped';
  play_duration_seconds: number;
  position_in_session: number;
  auto_detection_confidence?: number;
}

const effectiveness = new Hono<{ Bindings: Env }>();

// All routes require authentication
effectiveness.use('*', authMiddleware);

// GET /effectiveness - Fetch user's cry-type effectiveness data
effectiveness.get('/', async (c) => {
  const userId = c.get('userId');
  const sinceParam = c.req.query('since'); // Optional: only fetch records updated after this timestamp

  let query = `
    SELECT * FROM cry_type_effectiveness
    WHERE user_id = ?
  `;
  const params: (string | number)[] = [userId];

  if (sinceParam) {
    query += ` AND updated_at > ?`;
    params.push(sinceParam);
  }

  query += ` ORDER BY updated_at DESC LIMIT 1000`;

  const records = await c.env.DB.prepare(query).bind(...params).all<CryTypeEffectivenessRecord>();

  return c.json({
    success: true,
    records: records.results,
    count: records.results.length,
    fetched_at: new Date().toISOString(),
  });
});

// GET /effectiveness/summary - Get aggregated effectiveness summary per cry type
effectiveness.get('/summary', async (c) => {
  const userId = c.get('userId');

  // Get overall stats per cry type
  const summary = await c.env.DB.prepare(`
    SELECT
      cry_type,
      COUNT(DISTINCT track_id) as tracks_count,
      SUM(helped_count) as total_helped,
      SUM(not_helped_count) as total_not_helped,
      AVG(avg_effectiveness_score) as avg_score,
      MAX(last_played_at) as last_activity
    FROM cry_type_effectiveness
    WHERE user_id = ?
    GROUP BY cry_type
    ORDER BY total_helped DESC
  `).bind(userId).all<{
    cry_type: CryType;
    tracks_count: number;
    total_helped: number;
    total_not_helped: number;
    avg_score: number;
    last_activity: string | null;
  }>();

  // Get top tracks per cry type
  const topTracks: Record<CryType, Array<{ track_id: string; score: number }>> = {
    hunger: [],
    tired: [],
    pain: [],
    attention: [],
    discomfort: [],
    general: [],
    unknown: [],
  };

  for (const cryType of Object.keys(topTracks) as CryType[]) {
    const tracks = await c.env.DB.prepare(`
      SELECT track_id, avg_effectiveness_score as score
      FROM cry_type_effectiveness
      WHERE user_id = ? AND cry_type = ? AND (helped_count + not_helped_count) >= 2
      ORDER BY avg_effectiveness_score DESC
      LIMIT 5
    `).bind(userId, cryType).all<{ track_id: string; score: number }>();

    topTracks[cryType] = tracks.results;
  }

  return c.json({
    success: true,
    summary: summary.results,
    top_tracks_by_cry_type: topTracks,
    generated_at: new Date().toISOString(),
  });
});

// POST /effectiveness - Sync effectiveness data from iOS app
effectiveness.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<SyncEffectivenessRequest>();

  if (!body.records || !Array.isArray(body.records)) {
    return c.json({ success: false, error: 'Missing or invalid records array' }, 400);
  }

  let synced = 0;
  let errors = 0;

  for (const record of body.records) {
    try {
      // Validate cry type
      const validCryTypes: CryType[] = ['hunger', 'tired', 'pain', 'attention', 'discomfort', 'general', 'unknown'];
      if (!validCryTypes.includes(record.cry_type)) {
        errors++;
        continue;
      }

      // Check if record exists
      const existing = await c.env.DB.prepare(`
        SELECT id FROM cry_type_effectiveness
        WHERE user_id = ? AND track_id = ? AND cry_type = ?
      `).bind(userId, record.track_id, record.cry_type).first<{ id: string }>();

      if (existing) {
        // Update existing record - merge counts (iOS might have newer data)
        await c.env.DB.prepare(`
          UPDATE cry_type_effectiveness
          SET
            helped_count = MAX(helped_count, ?),
            not_helped_count = MAX(not_helped_count, ?),
            total_play_duration_seconds = MAX(total_play_duration_seconds, ?),
            avg_effectiveness_score = ?,
            auto_detected_helped = MAX(auto_detected_helped, ?),
            auto_detected_weight = ?,
            last_played_at = CASE WHEN ? > last_played_at OR last_played_at IS NULL THEN ? ELSE last_played_at END,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).bind(
          record.helped_count,
          record.not_helped_count,
          record.total_play_duration_seconds,
          record.avg_effectiveness_score,
          record.auto_detected_helped,
          record.auto_detected_weight,
          record.last_played_at,
          record.last_played_at,
          existing.id
        ).run();
      } else {
        // Insert new record
        const recordId = generateId('cte');
        await c.env.DB.prepare(`
          INSERT INTO cry_type_effectiveness (
            id, user_id, track_id, cry_type,
            helped_count, not_helped_count, total_play_duration_seconds,
            avg_effectiveness_score, auto_detected_helped, auto_detected_weight,
            last_played_at, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        `).bind(
          recordId,
          userId,
          record.track_id,
          record.cry_type,
          record.helped_count,
          record.not_helped_count,
          record.total_play_duration_seconds,
          record.avg_effectiveness_score,
          record.auto_detected_helped,
          record.auto_detected_weight,
          record.last_played_at
        ).run();
      }

      synced++;
    } catch (err) {
      console.error('[Effectiveness] Sync error:', err);
      errors++;
    }
  }

  return c.json({
    success: true,
    synced,
    errors,
    synced_at: new Date().toISOString(),
  });
});

// POST /effectiveness/sessions - Record a feedback session
effectiveness.post('/sessions', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<FeedbackSessionRecord>();

  if (!body.id || !body.cry_type || !body.start_time) {
    return c.json({ success: false, error: 'Missing required fields: id, cry_type, start_time' }, 400);
  }

  // Validate baby belongs to user if provided
  if (body.baby_id) {
    const baby = await c.env.DB.prepare(`
      SELECT id FROM babies WHERE id = ? AND user_id = ?
    `).bind(body.baby_id, userId).first();

    if (!baby) {
      return c.json({ success: false, error: 'Baby not found' }, 404);
    }
  }

  // Check if session already exists (idempotency)
  const existing = await c.env.DB.prepare(`
    SELECT id FROM feedback_sessions WHERE id = ?
  `).bind(body.id).first();

  if (existing) {
    // Update existing session
    await c.env.DB.prepare(`
      UPDATE feedback_sessions
      SET
        end_time = ?,
        outcome = ?,
        tracks_played = ?,
        session_duration_seconds = ?,
        tracks_count = ?
      WHERE id = ?
    `).bind(
      body.end_time || null,
      body.outcome || null,
      JSON.stringify(body.tracks_played || []),
      body.session_duration_seconds || 0,
      body.tracks_count || 0,
      body.id
    ).run();

    return c.json({ success: true, session_id: body.id, action: 'updated' });
  }

  // Insert new session
  await c.env.DB.prepare(`
    INSERT INTO feedback_sessions (
      id, user_id, baby_id, cry_type,
      start_time, end_time, outcome,
      tracks_played, session_duration_seconds, tracks_count,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
  `).bind(
    body.id,
    userId,
    body.baby_id || null,
    body.cry_type,
    body.start_time,
    body.end_time || null,
    body.outcome || null,
    JSON.stringify(body.tracks_played || []),
    body.session_duration_seconds || 0,
    body.tracks_count || 0
  ).run();

  return c.json({ success: true, session_id: body.id, action: 'created' });
});

// POST /effectiveness/events - Record track feedback events
effectiveness.post('/events', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{ events: TrackFeedbackEventRecord[] }>();

  if (!body.events || !Array.isArray(body.events)) {
    return c.json({ success: false, error: 'Missing or invalid events array' }, 400);
  }

  let created = 0;
  let errors = 0;

  for (const event of body.events) {
    try {
      // Validate required fields
      if (!event.session_id || !event.track_id || !event.cry_type || !event.event_type) {
        errors++;
        continue;
      }

      const eventId = generateId('tfe');

      await c.env.DB.prepare(`
        INSERT INTO track_feedback_events (
          id, session_id, user_id, track_id, cry_type,
          event_type, play_duration_seconds, position_in_session,
          auto_detection_confidence, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      `).bind(
        eventId,
        event.session_id,
        userId,
        event.track_id,
        event.cry_type,
        event.event_type,
        event.play_duration_seconds || 0,
        event.position_in_session || 0,
        event.auto_detection_confidence || null
      ).run();

      created++;
    } catch (err) {
      console.error('[Effectiveness] Event error:', err);
      errors++;
    }
  }

  return c.json({
    success: true,
    created,
    errors,
    recorded_at: new Date().toISOString(),
  });
});

// GET /effectiveness/sessions - Get recent feedback sessions
effectiveness.get('/sessions', async (c) => {
  const userId = c.get('userId');
  const limit = parseInt(c.req.query('limit') || '20', 10);
  const babyId = c.req.query('baby_id');

  let query = `
    SELECT * FROM feedback_sessions
    WHERE user_id = ?
  `;
  const params: (string | number)[] = [userId];

  if (babyId) {
    query += ` AND baby_id = ?`;
    params.push(babyId);
  }

  query += ` ORDER BY start_time DESC LIMIT ?`;
  params.push(Math.min(limit, 100));

  const sessions = await c.env.DB.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    sessions: sessions.results.map((s: any) => ({
      ...s,
      tracks_played: JSON.parse(s.tracks_played || '[]'),
    })),
    count: sessions.results.length,
  });
});

// GET /effectiveness/tracks/:track_id - Get effectiveness data for a specific track
effectiveness.get('/tracks/:track_id', async (c) => {
  const userId = c.get('userId');
  const trackId = c.req.param('track_id');

  const records = await c.env.DB.prepare(`
    SELECT * FROM cry_type_effectiveness
    WHERE user_id = ? AND track_id = ?
    ORDER BY avg_effectiveness_score DESC
  `).bind(userId, trackId).all();

  // Get recent feedback events for this track
  const events = await c.env.DB.prepare(`
    SELECT * FROM track_feedback_events
    WHERE user_id = ? AND track_id = ?
    ORDER BY created_at DESC
    LIMIT 20
  `).bind(userId, trackId).all();

  return c.json({
    success: true,
    track_id: trackId,
    effectiveness_by_cry_type: records.results,
    recent_events: events.results,
  });
});

// DELETE /effectiveness - Clear all effectiveness data for user
effectiveness.delete('/', async (c) => {
  const userId = c.get('userId');

  // Delete all effectiveness records
  const effectivenessResult = await c.env.DB.prepare(`
    DELETE FROM cry_type_effectiveness WHERE user_id = ?
  `).bind(userId).run();

  // Delete all feedback events
  const eventsResult = await c.env.DB.prepare(`
    DELETE FROM track_feedback_events WHERE user_id = ?
  `).bind(userId).run();

  // Delete all sessions
  const sessionsResult = await c.env.DB.prepare(`
    DELETE FROM feedback_sessions WHERE user_id = ?
  `).bind(userId).run();

  return c.json({
    success: true,
    message: 'All effectiveness data cleared',
    deleted: {
      effectiveness_records: effectivenessResult.meta?.changes || 0,
      feedback_events: eventsResult.meta?.changes || 0,
      feedback_sessions: sessionsResult.meta?.changes || 0,
    },
  });
});

export default effectiveness;
