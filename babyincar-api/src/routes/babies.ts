import { Hono } from 'hono';
import type { Env, Baby, BabyWithAge, CreateBabyRequest, UpdateBabyRequest } from '../types';
import { authMiddleware } from '../middleware/auth';
import { generateId } from '../utils/auth';
import {
  calculateAgeMonths,
  getDevelopmentalStage,
  isValidBirthDate,
  sanitizeString,
} from '../utils/helpers';

const babies = new Hono<{ Bindings: Env }>();

// All routes require authentication
babies.use('*', authMiddleware);

// GET /babies - Get all babies for current user
babies.get('/', async (c) => {
  const userId = c.get('userId');

  const result = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE user_id = ? ORDER BY created_at DESC
  `).bind(userId).all<Baby>();

  const babiesWithAge: BabyWithAge[] = result.results.map((baby) => {
    const ageMonths = calculateAgeMonths(baby.birth_date);
    return {
      ...baby,
      preferences: typeof baby.preferences === 'string'
        ? JSON.parse(baby.preferences)
        : baby.preferences,
      age_months: ageMonths,
      developmental_stage: getDevelopmentalStage(ageMonths),
    };
  });

  return c.json({
    success: true,
    babies: babiesWithAge,
  });
});

// GET /babies/:id - Get single baby
babies.get('/:id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);
  const babyWithAge: BabyWithAge = {
    ...baby,
    preferences: typeof baby.preferences === 'string'
      ? JSON.parse(baby.preferences)
      : baby.preferences,
    age_months: ageMonths,
    developmental_stage: getDevelopmentalStage(ageMonths),
  };

  return c.json({
    success: true,
    baby: babyWithAge,
  });
});

// POST /babies - Create new baby
babies.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<CreateBabyRequest>();

  // Validate name
  if (!body.name || body.name.trim().length === 0) {
    return c.json({ success: false, error: 'Baby name is required' }, 400);
  }

  // Validate birth date
  if (!body.birth_date || !isValidBirthDate(body.birth_date)) {
    return c.json({ success: false, error: 'Invalid birth date' }, 400);
  }

  const babyId = generateId('baby');
  const now = new Date().toISOString();
  const name = sanitizeString(body.name);

  // Handle photo upload if provided
  let photoUrl: string | null = null;
  if (body.photo_data) {
    try {
      // Decode base64 and upload to R2
      const photoBuffer = Uint8Array.from(atob(body.photo_data), c => c.charCodeAt(0));
      const photoKey = `photos/${babyId}.jpg`;

      await c.env.IMAGES_BUCKET.put(photoKey, photoBuffer, {
        httpMetadata: { contentType: 'image/jpeg' },
      });

      photoUrl = `https://images.babyincar.app/${photoKey}`;
    } catch (error) {
      console.error('Failed to upload photo:', error);
      // Continue without photo
    }
  }

  const defaultPreferences = {
    favorite_categories: [],
    preferred_languages: ['english'],
    effective_tracks: [],
  };

  await c.env.DB.prepare(`
    INSERT INTO babies (id, user_id, name, birth_date, photo_url, preferences, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    babyId,
    userId,
    name,
    body.birth_date,
    photoUrl,
    JSON.stringify(defaultPreferences),
    now,
    now
  ).run();

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ?
  `).bind(babyId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Failed to create baby profile' }, 500);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);

  return c.json({
    success: true,
    baby: {
      ...baby,
      preferences: defaultPreferences,
      age_months: ageMonths,
      developmental_stage: getDevelopmentalStage(ageMonths),
    },
  }, 201);
});

// PUT /babies/:id - Update baby
babies.put('/:id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');
  const body = await c.req.json<UpdateBabyRequest>();

  // Check baby exists and belongs to user
  const existing = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<Baby>();

  if (!existing) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const updates: string[] = [];
  const values: (string | null)[] = [];

  if (body.name !== undefined) {
    updates.push('name = ?');
    values.push(sanitizeString(body.name));
  }

  if (body.birth_date !== undefined) {
    if (!isValidBirthDate(body.birth_date)) {
      return c.json({ success: false, error: 'Invalid birth date' }, 400);
    }
    updates.push('birth_date = ?');
    values.push(body.birth_date);
  }

  if (body.photo_data !== undefined) {
    try {
      const photoBuffer = Uint8Array.from(atob(body.photo_data), c => c.charCodeAt(0));
      const photoKey = `photos/${babyId}.jpg`;

      await c.env.IMAGES_BUCKET.put(photoKey, photoBuffer, {
        httpMetadata: { contentType: 'image/jpeg' },
      });

      updates.push('photo_url = ?');
      values.push(`https://images.babyincar.app/${photoKey}`);
    } catch (error) {
      console.error('Failed to upload photo:', error);
    }
  }

  if (updates.length === 0) {
    return c.json({ success: false, error: 'No updates provided' }, 400);
  }

  updates.push('updated_at = ?');
  values.push(new Date().toISOString());
  values.push(babyId);
  values.push(userId);

  await c.env.DB.prepare(`
    UPDATE babies SET ${updates.join(', ')} WHERE id = ? AND user_id = ?
  `).bind(...values).run();

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ?
  `).bind(babyId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Failed to update baby profile' }, 500);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);

  return c.json({
    success: true,
    baby: {
      ...baby,
      preferences: typeof baby.preferences === 'string'
        ? JSON.parse(baby.preferences)
        : baby.preferences,
      age_months: ageMonths,
      developmental_stage: getDevelopmentalStage(ageMonths),
    },
  });
});

// DELETE /babies/:id - Delete baby
babies.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');

  const existing = await c.env.DB.prepare(`
    SELECT id, photo_url FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<{ id: string; photo_url: string | null }>();

  if (!existing) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  // Delete photo from R2 if exists
  if (existing.photo_url) {
    try {
      const photoKey = `photos/${babyId}.jpg`;
      await c.env.IMAGES_BUCKET.delete(photoKey);
    } catch (error) {
      console.error('Failed to delete photo:', error);
    }
  }

  // Delete baby (cascade will handle related records)
  await c.env.DB.prepare(`
    DELETE FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).run();

  return c.json({ success: true, message: 'Baby profile deleted' });
});

// POST /babies/:id/preferences - Update baby preferences based on usage
babies.post('/:id/preferences', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');
  const body = await c.req.json<{
    effective_track_id?: string;
    calming_time_seconds?: number;
    favorite_category?: string;
    preferred_language?: string;
  }>();

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(babyId, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const preferences = typeof baby.preferences === 'string'
    ? JSON.parse(baby.preferences)
    : baby.preferences;

  // Update effective tracks
  if (body.effective_track_id) {
    if (!preferences.effective_tracks.includes(body.effective_track_id)) {
      preferences.effective_tracks.push(body.effective_track_id);
      // Keep only last 50 effective tracks
      if (preferences.effective_tracks.length > 50) {
        preferences.effective_tracks = preferences.effective_tracks.slice(-50);
      }
    }
  }

  // Update favorite categories
  if (body.favorite_category) {
    if (!preferences.favorite_categories.includes(body.favorite_category)) {
      preferences.favorite_categories.push(body.favorite_category);
    }
  }

  // Update preferred languages
  if (body.preferred_language) {
    if (!preferences.preferred_languages.includes(body.preferred_language)) {
      preferences.preferred_languages.push(body.preferred_language);
    }
  }

  await c.env.DB.prepare(`
    UPDATE babies SET preferences = ?, updated_at = ? WHERE id = ?
  `).bind(JSON.stringify(preferences), new Date().toISOString(), babyId).run();

  return c.json({
    success: true,
    preferences,
  });
});

export default babies;
