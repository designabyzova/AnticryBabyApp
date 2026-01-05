/**
 * User Preferences API Routes
 * FS-017: Smart Emergency Playlist System
 *
 * Endpoints for managing user language preferences
 */

import { Hono } from 'hono';
import type { Env } from '../index';

const preferences = new Hono<{ Bindings: Env }>();

/**
 * GET /api/preferences/language/:userId
 *
 * Get user's language preferences
 *
 * Returns: UserLanguagePreference object
 */
preferences.get('/language/:userId', async (c) => {
  try {
    const { userId } = c.req.param();

    const query = `SELECT * FROM user_language_preferences WHERE user_id = ?`;
    const result = await c.env.DB.prepare(query).bind(userId).first();

    if (!result) {
      // Return default preferences
      return c.json({
        userId,
        preferred_languages: 'en',
        primary_language: 'en',
        exclude_instrumental: 0,
      });
    }

    return c.json(result);
  } catch (error: any) {
    console.error('Language preferences fetch error:', error);
    return c.json(
      { error: 'Failed to fetch language preferences', details: error.message },
      500
    );
  }
});

/**
 * PUT /api/preferences/language/:userId
 *
 * Update user's language preferences
 *
 * Body: { preferred_languages, primary_language, exclude_instrumental }
 * Returns: { success: true }
 */
preferences.put('/language/:userId', async (c) => {
  try {
    const { userId } = c.req.param();
    const { preferred_languages, primary_language, exclude_instrumental } = await c.req.json();

    if (!preferred_languages || !primary_language) {
      return c.json(
        { error: 'Missing required fields: preferred_languages, primary_language' },
        400
      );
    }

    // Upsert preferences
    const query = `
      INSERT INTO user_language_preferences
      (user_id, preferred_languages, primary_language, exclude_instrumental, updated_at)
      VALUES (?, ?, ?, ?, datetime('now'))
      ON CONFLICT(user_id) DO UPDATE SET
        preferred_languages = excluded.preferred_languages,
        primary_language = excluded.primary_language,
        exclude_instrumental = excluded.exclude_instrumental,
        updated_at = datetime('now')
    `;

    await c.env.DB.prepare(query)
      .bind(userId, preferred_languages, primary_language, exclude_instrumental ? 1 : 0)
      .run();

    return c.json({ success: true });
  } catch (error: any) {
    console.error('Language preferences update error:', error);
    return c.json(
      { error: 'Failed to update language preferences', details: error.message },
      500
    );
  }
});

export default preferences;
