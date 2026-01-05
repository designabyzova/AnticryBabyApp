import { Hono } from 'hono';
import type {
  Env,
  RecordPlaybackRequest,
  RecordEffectivenessRequest,
  RecordEmergencyRequest,
  BabyInsights,
} from '../types';
import { authMiddleware } from '../middleware/auth';
import { generateId } from '../utils/auth';

const analytics = new Hono<{ Bindings: Env }>();

// All routes require authentication
analytics.use('*', authMiddleware);

// POST /analytics/playback - Record playback event
analytics.post('/playback', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<RecordPlaybackRequest>();

  if (!body.track_id || !body.event_type || !body.session_id) {
    return c.json({ success: false, error: 'Missing required fields' }, 400);
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

  const eventId = generateId('evt');

  await c.env.DB.prepare(`
    INSERT INTO playback_events (id, user_id, baby_id, track_id, event_type, position_seconds, context, session_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    eventId,
    userId,
    body.baby_id || null,
    body.track_id,
    body.event_type,
    body.position_seconds || 0,
    body.context || 'home',
    body.session_id,
    new Date().toISOString()
  ).run();

  return c.json({ success: true, event_id: eventId });
});

// POST /analytics/effectiveness - Record track effectiveness
analytics.post('/effectiveness', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<RecordEffectivenessRequest>();

  if (!body.baby_id || !body.track_id || body.was_effective === undefined) {
    return c.json({ success: false, error: 'Missing required fields' }, 400);
  }

  // Validate baby belongs to user
  const baby = await c.env.DB.prepare(`
    SELECT id, preferences FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first<{ id: string; preferences: string }>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const effectivenessId = generateId('eff');

  await c.env.DB.prepare(`
    INSERT INTO track_effectiveness (id, baby_id, track_id, was_effective, calming_time_seconds, context, emergency_mode, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    effectivenessId,
    body.baby_id,
    body.track_id,
    body.was_effective ? 1 : 0,
    body.calming_time_seconds || 0,
    body.context || 'crying',
    body.emergency_mode ? 1 : 0,
    new Date().toISOString()
  ).run();

  // Update baby preferences if effective
  if (body.was_effective) {
    const preferences = JSON.parse(baby.preferences || '{}');
    if (!preferences.effective_tracks) {
      preferences.effective_tracks = [];
    }

    if (!preferences.effective_tracks.includes(body.track_id)) {
      preferences.effective_tracks.push(body.track_id);
      // Keep only last 50
      if (preferences.effective_tracks.length > 50) {
        preferences.effective_tracks = preferences.effective_tracks.slice(-50);
      }

      await c.env.DB.prepare(`
        UPDATE babies SET preferences = ?, updated_at = ? WHERE id = ?
      `).bind(JSON.stringify(preferences), new Date().toISOString(), body.baby_id).run();
    }
  }

  return c.json({ success: true, effectiveness_id: effectivenessId });
});

// POST /analytics/emergency - Record emergency cry-stop usage
analytics.post('/emergency', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<RecordEmergencyRequest>();

  if (!body.baby_id || !body.started_at) {
    return c.json({ success: false, error: 'Missing required fields' }, 400);
  }

  // Validate baby belongs to user
  const baby = await c.env.DB.prepare(`
    SELECT id FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const sessionId = generateId('emerg');

  await c.env.DB.prepare(`
    INSERT INTO emergency_sessions (id, user_id, baby_id, started_at, ended_at, phases_completed, was_successful, tracks_used, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    sessionId,
    userId,
    body.baby_id,
    body.started_at,
    body.ended_at || null,
    JSON.stringify(body.phases_completed || []),
    body.was_successful !== undefined ? (body.was_successful ? 1 : 0) : null,
    JSON.stringify(body.tracks_used || []),
    new Date().toISOString()
  ).run();

  return c.json({ success: true, session_id: sessionId });
});

// PUT /analytics/emergency/:id - Update emergency session
analytics.put('/emergency/:id', async (c) => {
  const userId = c.get('userId');
  const sessionId = c.req.param('id');
  const body = await c.req.json<Partial<RecordEmergencyRequest>>();

  const existing = await c.env.DB.prepare(`
    SELECT id FROM emergency_sessions WHERE id = ? AND user_id = ?
  `).bind(sessionId, userId).first();

  if (!existing) {
    return c.json({ success: false, error: 'Session not found' }, 404);
  }

  const updates: string[] = [];
  const values: (string | number | null)[] = [];

  if (body.ended_at) {
    updates.push('ended_at = ?');
    values.push(body.ended_at);
  }

  if (body.phases_completed) {
    updates.push('phases_completed = ?');
    values.push(JSON.stringify(body.phases_completed));
  }

  if (body.was_successful !== undefined) {
    updates.push('was_successful = ?');
    values.push(body.was_successful ? 1 : 0);
  }

  if (body.tracks_used) {
    updates.push('tracks_used = ?');
    values.push(JSON.stringify(body.tracks_used));
  }

  if (updates.length === 0) {
    return c.json({ success: false, error: 'No updates provided' }, 400);
  }

  values.push(sessionId);

  await c.env.DB.prepare(`
    UPDATE emergency_sessions SET ${updates.join(', ')} WHERE id = ?
  `).bind(...values).run();

  return c.json({ success: true });
});

// GET /analytics/insights/:baby_id - Get personalized insights
analytics.get('/insights/:baby_id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('baby_id');

  // Validate baby belongs to user
  const baby = await c.env.DB.prepare(`
    SELECT id FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  // Get total listening time
  const listeningResult = await c.env.DB.prepare(`
    SELECT SUM(position_seconds) as total_seconds
    FROM playback_events
    WHERE baby_id = ? AND event_type IN ('complete', 'pause')
  `).bind(babyId).first<{ total_seconds: number }>();

  const totalListeningMinutes = Math.round((listeningResult?.total_seconds || 0) / 60);

  // Get most effective category
  const categoryResult = await c.env.DB.prepare(`
    SELECT t.category, COUNT(*) as count
    FROM track_effectiveness te
    JOIN tracks t ON te.track_id = t.id
    WHERE te.baby_id = ? AND te.was_effective = 1
    GROUP BY t.category
    ORDER BY count DESC
    LIMIT 1
  `).bind(babyId).first<{ category: string; count: number }>();

  // Get most effective tracks
  const effectiveTracksResult = await c.env.DB.prepare(`
    SELECT track_id,
           SUM(CASE WHEN was_effective = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as success_rate
    FROM track_effectiveness
    WHERE baby_id = ?
    GROUP BY track_id
    HAVING COUNT(*) >= 3
    ORDER BY success_rate DESC
    LIMIT 5
  `).bind(babyId).all<{ track_id: string; success_rate: number }>();

  // Get average calming time
  const calmingTimeResult = await c.env.DB.prepare(`
    SELECT AVG(calming_time_seconds) as avg_time
    FROM track_effectiveness
    WHERE baby_id = ? AND was_effective = 1
  `).bind(babyId).first<{ avg_time: number }>();

  // Get emergency mode stats
  const emergencyResult = await c.env.DB.prepare(`
    SELECT
      COUNT(*) as total_activations,
      SUM(CASE WHEN was_successful = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as success_rate
    FROM emergency_sessions
    WHERE baby_id = ?
  `).bind(babyId).first<{ total_activations: number; success_rate: number }>();

  const insights: BabyInsights = {
    total_listening_time_minutes: totalListeningMinutes,
    most_effective_category: categoryResult?.category as any || null,
    most_effective_tracks: effectiveTracksResult.results.map(r => ({
      track_id: r.track_id,
      success_rate: Math.round(r.success_rate * 100) / 100,
    })),
    average_calming_time_seconds: Math.round(calmingTimeResult?.avg_time || 0),
    emergency_mode_usage: {
      total_activations: emergencyResult?.total_activations || 0,
      success_rate: Math.round((emergencyResult?.success_rate || 0) * 100) / 100,
    },
  };

  return c.json({
    success: true,
    insights,
  });
});

// DELETE /analytics/history/:baby_id - Clear all learning history for a baby
// Use this to reset "what worked" data and start fresh
analytics.delete('/history/:baby_id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('baby_id');

  // Validate baby belongs to user
  const baby = await c.env.DB.prepare(`
    SELECT id, preferences FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<{ id: string; preferences: string }>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  // Delete track effectiveness records
  const effectivenessResult = await c.env.DB.prepare(`
    DELETE FROM track_effectiveness WHERE baby_id = ?
  `).bind(babyId).run();

  // Delete playback events
  const playbackResult = await c.env.DB.prepare(`
    DELETE FROM playback_events WHERE baby_id = ?
  `).bind(babyId).run();

  // Delete emergency sessions
  const emergencyResult = await c.env.DB.prepare(`
    DELETE FROM emergency_sessions WHERE baby_id = ?
  `).bind(babyId).run();

  // Reset baby preferences (clear effective_tracks)
  const preferences = JSON.parse(baby.preferences || '{}');
  preferences.effective_tracks = [];

  await c.env.DB.prepare(`
    UPDATE babies SET preferences = ?, updated_at = ? WHERE id = ?
  `).bind(JSON.stringify(preferences), new Date().toISOString(), babyId).run();

  return c.json({
    success: true,
    message: 'Learning history cleared',
    deleted: {
      effectiveness_records: effectivenessResult.meta?.changes || 0,
      playback_events: playbackResult.meta?.changes || 0,
      emergency_sessions: emergencyResult.meta?.changes || 0,
    },
  });
});

// GET /analytics/history/:baby_id - Get all learning history for a baby
analytics.get('/history/:baby_id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('baby_id');

  // Validate baby belongs to user
  const baby = await c.env.DB.prepare(`
    SELECT id, preferences FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<{ id: string; preferences: string }>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  // Get track effectiveness records
  const effectiveness = await c.env.DB.prepare(`
    SELECT te.*, t.title as track_title, t.category as track_category
    FROM track_effectiveness te
    LEFT JOIN tracks t ON te.track_id = t.id
    WHERE te.baby_id = ?
    ORDER BY te.created_at DESC
    LIMIT 100
  `).bind(babyId).all();

  // Get emergency sessions
  const emergencySessions = await c.env.DB.prepare(`
    SELECT * FROM emergency_sessions
    WHERE baby_id = ?
    ORDER BY created_at DESC
    LIMIT 50
  `).bind(babyId).all();

  // Get baby preferences
  const preferences = JSON.parse(baby.preferences || '{}');

  return c.json({
    success: true,
    history: {
      effectiveness_records: effectiveness.results,
      emergency_sessions: emergencySessions.results,
      effective_tracks: preferences.effective_tracks || [],
      total_effectiveness_records: effectiveness.results.length,
      total_emergency_sessions: emergencySessions.results.length,
    },
  });
});

export default analytics;
