import { Hono } from 'hono';
import type { Env, User, UserSettings } from '../types';
import { authMiddleware } from '../middleware/auth';
import { revokeAllSessions, hashPassword, isValidPassword } from '../utils/auth';
import { sanitizeString } from '../utils/helpers';

const users = new Hono<{ Bindings: Env }>();

// All routes require authentication
users.use('*', authMiddleware);

// GET /users/me - Get current user profile
users.get('/me', async (c) => {
  const user = c.get('user');

  return c.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      auth_provider: user.auth_provider,
      subscription_status: user.subscription_status,
      subscription_expires_at: user.subscription_expires_at,
      created_at: user.created_at,
    },
  });
});

// PUT /users/me - Update user profile
users.put('/me', async (c) => {
  const user = c.get('user');
  const body = await c.req.json<{
    name?: string;
    email?: string;
    current_password?: string;
    new_password?: string;
  }>();

  const updates: string[] = [];
  const values: (string | null)[] = [];

  if (body.name !== undefined) {
    updates.push('name = ?');
    values.push(sanitizeString(body.name));
  }

  if (body.email !== undefined) {
    // Check if email is already taken
    const existing = await c.env.DB.prepare(`
      SELECT id FROM users WHERE email = ? AND id != ?
    `).bind(body.email.toLowerCase(), user.id).first();

    if (existing) {
      return c.json({ success: false, error: 'Email already in use' }, 409);
    }

    updates.push('email = ?');
    values.push(body.email.toLowerCase());
  }

  if (body.new_password) {
    // Require current password for password change
    if (user.auth_provider === 'email') {
      if (!body.current_password) {
        return c.json({ success: false, error: 'Current password required' }, 400);
      }

      // Verify current password
      const currentHash = await hashPassword(body.current_password);
      if (currentHash !== user.password_hash) {
        return c.json({ success: false, error: 'Current password is incorrect' }, 401);
      }
    }

    const passwordValidation = isValidPassword(body.new_password);
    if (!passwordValidation.valid) {
      return c.json({ success: false, error: passwordValidation.message }, 400);
    }

    updates.push('password_hash = ?');
    values.push(await hashPassword(body.new_password));
  }

  if (updates.length === 0) {
    return c.json({ success: false, error: 'No updates provided' }, 400);
  }

  updates.push('updated_at = ?');
  values.push(new Date().toISOString());
  values.push(user.id);

  await c.env.DB.prepare(`
    UPDATE users SET ${updates.join(', ')} WHERE id = ?
  `).bind(...values).run();

  // Get updated user
  const updatedUser = await c.env.DB.prepare(`
    SELECT * FROM users WHERE id = ?
  `).bind(user.id).first<User>();

  return c.json({
    success: true,
    user: {
      id: updatedUser!.id,
      email: updatedUser!.email,
      name: updatedUser!.name,
      auth_provider: updatedUser!.auth_provider,
      subscription_status: updatedUser!.subscription_status,
      created_at: updatedUser!.created_at,
    },
  });
});

// GET /users/me/settings - Get user settings
users.get('/me/settings', async (c) => {
  const userId = c.get('userId');

  // Get settings from KV (faster) or create defaults
  const settingsKey = `settings:${userId}`;
  const cached = await c.env.CACHE.get(settingsKey);

  if (cached) {
    return c.json({
      success: true,
      settings: JSON.parse(cached),
    });
  }

  // Default settings
  const defaultSettings: UserSettings = {
    notifications_enabled: true,
    auto_play_carplay: true,
    max_volume_db: 50,
    default_sleep_timer_minutes: 30,
    preferred_languages: ['english'],
    theme: 'auto',
  };

  // Store in KV for future requests
  await c.env.CACHE.put(settingsKey, JSON.stringify(defaultSettings), {
    expirationTtl: 86400, // 24 hours
  });

  return c.json({
    success: true,
    settings: defaultSettings,
  });
});

// PUT /users/me/settings - Update user settings
users.put('/me/settings', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<Partial<UserSettings>>();

  const settingsKey = `settings:${userId}`;
  const cached = await c.env.CACHE.get(settingsKey);

  const currentSettings: UserSettings = cached
    ? JSON.parse(cached)
    : {
        notifications_enabled: true,
        auto_play_carplay: true,
        max_volume_db: 50,
        default_sleep_timer_minutes: 30,
        preferred_languages: ['english'],
        theme: 'auto',
      };

  // Merge updates
  const updatedSettings: UserSettings = {
    ...currentSettings,
    ...body,
  };

  // Validate max_volume_db (must be between 30 and 70 for safety)
  if (updatedSettings.max_volume_db < 30) {
    updatedSettings.max_volume_db = 30;
  } else if (updatedSettings.max_volume_db > 70) {
    updatedSettings.max_volume_db = 70;
  }

  // Validate sleep timer (must be between 5 and 120 minutes)
  if (updatedSettings.default_sleep_timer_minutes < 5) {
    updatedSettings.default_sleep_timer_minutes = 5;
  } else if (updatedSettings.default_sleep_timer_minutes > 120) {
    updatedSettings.default_sleep_timer_minutes = 120;
  }

  // Store in KV
  await c.env.CACHE.put(settingsKey, JSON.stringify(updatedSettings), {
    expirationTtl: 86400,
  });

  return c.json({
    success: true,
    settings: updatedSettings,
  });
});

// DELETE /users/me - Delete account
users.delete('/me', async (c) => {
  const user = c.get('user');
  const body = await c.req.json<{ confirm_email: string }>();

  // Require email confirmation
  if (body.confirm_email?.toLowerCase() !== user.email.toLowerCase()) {
    return c.json({
      success: false,
      error: 'Please confirm your email to delete account',
    }, 400);
  }

  // Revoke all sessions
  await revokeAllSessions(c.env, user.id);

  // Delete settings from KV
  await c.env.CACHE.delete(`settings:${user.id}`);

  // Delete user photos from R2
  const babies = await c.env.DB.prepare(`
    SELECT photo_url FROM babies WHERE user_id = ?
  `).bind(user.id).all<{ photo_url: string | null }>();

  for (const baby of babies.results) {
    if (baby.photo_url) {
      try {
        const key = baby.photo_url.split('/').pop();
        if (key) {
          await c.env.IMAGES_BUCKET.delete(`photos/${key}`);
        }
      } catch (error) {
        console.error('Failed to delete photo:', error);
      }
    }
  }

  // Delete user (cascade will delete babies, analytics, etc.)
  await c.env.DB.prepare(`
    DELETE FROM users WHERE id = ?
  `).bind(user.id).run();

  return c.json({
    success: true,
    message: 'Account deleted successfully',
  });
});

// GET /users/me/favorites - Get user favorites
users.get('/me/favorites', async (c) => {
  const userId = c.get('userId');

  const favorites = await c.env.DB.prepare(`
    SELECT f.track_id, f.playlist_id, f.created_at,
           t.title as track_title, t.artist as track_artist, t.category as track_category,
           p.name as playlist_name
    FROM favorites f
    LEFT JOIN tracks t ON f.track_id = t.id
    LEFT JOIN playlists p ON f.playlist_id = p.id
    WHERE f.user_id = ?
    ORDER BY f.created_at DESC
  `).bind(userId).all();

  return c.json({
    success: true,
    favorites: favorites.results,
  });
});

// POST /users/me/favorites - Add favorite
users.post('/me/favorites', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{ track_id?: string; playlist_id?: string }>();

  if (!body.track_id && !body.playlist_id) {
    return c.json({ success: false, error: 'Track or playlist ID required' }, 400);
  }

  try {
    await c.env.DB.prepare(`
      INSERT INTO favorites (user_id, track_id, playlist_id, created_at)
      VALUES (?, ?, ?, ?)
    `).bind(
      userId,
      body.track_id || null,
      body.playlist_id || null,
      new Date().toISOString()
    ).run();

    return c.json({ success: true });
  } catch {
    // Likely duplicate
    return c.json({ success: true, message: 'Already favorited' });
  }
});

// DELETE /users/me/favorites - Remove favorite
users.delete('/me/favorites', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{ track_id?: string; playlist_id?: string }>();

  if (!body.track_id && !body.playlist_id) {
    return c.json({ success: false, error: 'Track or playlist ID required' }, 400);
  }

  if (body.track_id) {
    await c.env.DB.prepare(`
      DELETE FROM favorites WHERE user_id = ? AND track_id = ?
    `).bind(userId, body.track_id).run();
  }

  if (body.playlist_id) {
    await c.env.DB.prepare(`
      DELETE FROM favorites WHERE user_id = ? AND playlist_id = ?
    `).bind(userId, body.playlist_id).run();
  }

  return c.json({ success: true });
});

export default users;
