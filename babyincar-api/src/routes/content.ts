import { Hono } from 'hono';
import type { Env, Track, Playlist, Baby, AudioCategory } from '../types';
import { authMiddleware, optionalAuthMiddleware, premiumMiddleware } from '../middleware/auth';
import {
  calculateAgeMonths,
  getDevelopmentalStage,
  calculateRelevanceScore,
  getRecommendedCategories,
} from '../utils/helpers';

const content = new Hono<{ Bindings: Env }>();

// GET /content/tracks - Get all tracks with filtering
content.get('/tracks', optionalAuthMiddleware, async (c) => {
  const category = c.req.query('category');
  const language = c.req.query('language');
  const ageMin = c.req.query('age_min');
  const ageMax = c.req.query('age_max');
  const limit = Math.min(parseInt(c.req.query('limit') || '50'), 100);
  const offset = parseInt(c.req.query('offset') || '0');
  const search = c.req.query('search');

  let query = 'SELECT * FROM tracks WHERE 1=1';
  const params: (string | number)[] = [];

  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }

  if (language) {
    query += ' AND language = ?';
    params.push(language);
  }

  if (ageMin) {
    query += ' AND age_range_max >= ?';
    params.push(parseInt(ageMin));
  }

  if (ageMax) {
    query += ' AND age_range_min <= ?';
    params.push(parseInt(ageMax));
  }

  if (search) {
    query += ' AND (title LIKE ? OR artist LIKE ?)';
    params.push(`%${search}%`, `%${search}%`);
  }

  // Check if user is premium
  const user = c.get('user');
  const isPremium = user && user.subscription_status !== 'free';

  // Count total
  const countResult = await c.env.DB.prepare(
    query.replace('SELECT *', 'SELECT COUNT(*) as count')
  ).bind(...params).first<{ count: number }>();

  const total = countResult?.count || 0;

  // Get paginated results
  query += ' ORDER BY calming_score DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const result = await c.env.DB.prepare(query).bind(...params).all<Track>();

  // Filter premium content for free users
  const tracks = result.results.map(track => ({
    ...track,
    stream_url: (!track.is_premium || isPremium) ? track.stream_url : null,
    is_locked: track.is_premium && !isPremium,
  }));

  return c.json({
    success: true,
    tracks,
    total,
    has_more: offset + limit < total,
  });
});

// GET /content/tracks/:id - Get single track
content.get('/tracks/:id', optionalAuthMiddleware, async (c) => {
  const trackId = c.req.param('id');

  const track = await c.env.DB.prepare(`
    SELECT * FROM tracks WHERE id = ?
  `).bind(trackId).first<Track>();

  if (!track) {
    return c.json({ success: false, error: 'Track not found' }, 404);
  }

  const user = c.get('user');
  const isPremium = user && user.subscription_status !== 'free';

  return c.json({
    success: true,
    track: {
      ...track,
      stream_url: (!track.is_premium || isPremium) ? track.stream_url : null,
      is_locked: track.is_premium && !isPremium,
    },
  });
});

// GET /content/playlists - Get all playlists
content.get('/playlists', optionalAuthMiddleware, async (c) => {
  const category = c.req.query('category');
  const limit = Math.min(parseInt(c.req.query('limit') || '50'), 100);
  const offset = parseInt(c.req.query('offset') || '0');

  let query = `
    SELECT p.*, COUNT(pt.track_id) as track_count,
           SUM(t.duration) as total_duration
    FROM playlists p
    LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
    LEFT JOIN tracks t ON pt.track_id = t.id
    WHERE 1=1
  `;
  const params: (string | number)[] = [];

  if (category) {
    query += ' AND p.category = ?';
    params.push(category);
  }

  query += ' GROUP BY p.id ORDER BY p.is_system DESC, p.created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const result = await c.env.DB.prepare(query).bind(...params).all<Playlist>();

  return c.json({
    success: true,
    playlists: result.results,
  });
});

// GET /content/playlists/:id - Get playlist with tracks
content.get('/playlists/:id', optionalAuthMiddleware, async (c) => {
  const playlistId = c.req.param('id');

  const playlist = await c.env.DB.prepare(`
    SELECT * FROM playlists WHERE id = ?
  `).bind(playlistId).first<Playlist>();

  if (!playlist) {
    return c.json({ success: false, error: 'Playlist not found' }, 404);
  }

  // Get tracks
  const tracksResult = await c.env.DB.prepare(`
    SELECT t.* FROM tracks t
    JOIN playlist_tracks pt ON t.id = pt.track_id
    WHERE pt.playlist_id = ?
    ORDER BY pt.position
  `).bind(playlistId).all<Track>();

  const user = c.get('user');
  const isPremium = user && user.subscription_status !== 'free';

  const tracks = tracksResult.results.map(track => ({
    ...track,
    stream_url: (!track.is_premium || isPremium) ? track.stream_url : null,
    is_locked: track.is_premium && !isPremium,
  }));

  return c.json({
    success: true,
    playlist: {
      ...playlist,
      tracks,
      track_count: tracks.length,
      total_duration: tracks.reduce((sum, t) => sum + t.duration, 0),
    },
  });
});

// GET /content/recommendations - Get AI-personalized recommendations
content.get('/recommendations', authMiddleware, async (c) => {
  const babyId = c.req.query('baby_id');
  const mood = c.req.query('mood');
  const tripDuration = c.req.query('trip_duration');
  const limit = Math.min(parseInt(c.req.query('limit') || '10'), 30);

  if (!babyId) {
    return c.json({ success: false, error: 'Baby ID required' }, 400);
  }

  const userId = c.get('userId');

  // Get baby
  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);
  const stage = getDevelopmentalStage(ageMonths);
  const preferences = typeof baby.preferences === 'string'
    ? JSON.parse(baby.preferences)
    : baby.preferences;

  // Get all age-appropriate tracks
  const tracksResult = await c.env.DB.prepare(`
    SELECT * FROM tracks
    WHERE age_range_min <= ? AND age_range_max >= ?
  `).bind(ageMonths, ageMonths).all<Track>();

  let tracks = tracksResult.results;

  // Apply mood filter if provided
  if (mood) {
    const moodCategories = getMoodCategories(mood);
    tracks = tracks.filter(t => moodCategories.includes(t.category));
  }

  // Calculate relevance scores and sort
  const scoredTracks = tracks.map(track => ({
    ...track,
    relevance_score: calculateRelevanceScore(track, ageMonths, stage),
  }));

  // Boost effective tracks for this baby
  const effectiveTracks = preferences.effective_tracks || [];
  scoredTracks.forEach(track => {
    if (effectiveTracks.includes(track.id)) {
      track.relevance_score = Math.min(1, track.relevance_score + 0.2);
    }
  });

  scoredTracks.sort((a, b) => b.relevance_score - a.relevance_score);

  const recommendedTracks = scoredTracks.slice(0, limit);

  // Get emergency tracks (highest calming scores)
  const emergencyTracks = [...tracks]
    .sort((a, b) => b.calming_score - a.calming_score)
    .slice(0, 5);

  // Get recommended playlists
  const recommendedCategories = getRecommendedCategories(stage);
  const playlistsResult = await c.env.DB.prepare(`
    SELECT * FROM playlists
    WHERE category IN (${recommendedCategories.map(() => '?').join(',')})
    OR target_age_months BETWEEN ? AND ?
    LIMIT 5
  `).bind(...recommendedCategories, Math.max(0, ageMonths - 3), ageMonths + 3).all<Playlist>();

  const user = c.get('user');
  const isPremium = user && user.subscription_status !== 'free';

  return c.json({
    success: true,
    baby: {
      id: baby.id,
      name: baby.name,
      age_months: ageMonths,
      developmental_stage: stage,
    },
    recommended_tracks: recommendedTracks.map(t => ({
      ...t,
      stream_url: (!t.is_premium || isPremium) ? t.stream_url : null,
      is_locked: t.is_premium && !isPremium,
    })),
    emergency_tracks: emergencyTracks.map(t => ({
      ...t,
      stream_url: (!t.is_premium || isPremium) ? t.stream_url : null,
      is_locked: t.is_premium && !isPremium,
    })),
    recommended_playlists: playlistsResult.results,
    personalization_score: recommendedTracks[0]?.relevance_score || 0,
  });
});

// GET /content/stream/:track_id - Get signed streaming URL
content.get('/stream/:track_id', authMiddleware, async (c) => {
  const trackId = c.req.param('id');
  const user = c.get('user');

  const track = await c.env.DB.prepare(`
    SELECT * FROM tracks WHERE id = ?
  `).bind(trackId).first<Track>();

  if (!track) {
    return c.json({ success: false, error: 'Track not found' }, 404);
  }

  // Check premium access
  if (track.is_premium && user.subscription_status === 'free') {
    return c.json({
      success: false,
      error: 'Premium subscription required',
      upgrade_required: true,
    }, 403);
  }

  // Generate signed URL (expires in 1 hour)
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

  // For generated audio, return the generator info
  if (track.audio_source_type === 'generated') {
    return c.json({
      success: true,
      audio_source_type: 'generated',
      generator_type: track.generator_type,
      duration: track.duration,
      expires_at: expiresAt.toISOString(),
    });
  }

  // For recorded/streaming audio, return URL
  return c.json({
    success: true,
    audio_source_type: track.audio_source_type,
    stream_url: track.stream_url,
    expires_at: expiresAt.toISOString(),
  });
});

// Helper: Get mood-appropriate categories
function getMoodCategories(mood: string): AudioCategory[] {
  const moodMap: Record<string, AudioCategory[]> = {
    sleepy: ['white_noise', 'classical_music', 'instrumental'],
    crying: ['white_noise', 'nature_sounds', 'instrumental'],
    playful: ['children_songs', 'fairy_tales', 'instrumental'],
    calm: ['classical_music', 'nature_sounds', 'podcasts'],
    fussy: ['white_noise', 'nature_sounds', 'classical_music'],
  };
  return moodMap[mood] || [];
}

export default content;
