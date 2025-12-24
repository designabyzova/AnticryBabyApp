import { Hono } from 'hono';
import type { Env, User, RegisterRequest, LoginRequest } from '../types';
import {
  generateId,
  hashPassword,
  verifyPassword,
  generateToken,
  generateRefreshToken,
  storeSession,
  verifyRefreshToken,
  revokeSession,
  revokeAllSessions,
  isValidEmail,
  isValidPassword,
  verifyAppleIdToken,
} from '../utils/auth';
import { authMiddleware } from '../middleware/auth';

const auth = new Hono<{ Bindings: Env }>();

// POST /auth/register
auth.post('/register', async (c) => {
  const body = await c.req.json<RegisterRequest>();

  // Validate email
  if (!body.email || !isValidEmail(body.email)) {
    return c.json({ success: false, error: 'Invalid email address' }, 400);
  }

  // Check if user exists
  const existingUser = await c.env.DB.prepare(`
    SELECT id FROM users WHERE email = ?
  `).bind(body.email.toLowerCase()).first();

  if (existingUser) {
    return c.json({ success: false, error: 'Email already registered' }, 409);
  }

  let userId: string;
  let passwordHash: string | null = null;
  let appleUserId: string | null = null;

  if (body.auth_provider === 'apple') {
    // Apple Sign-In
    if (!body.apple_id_token) {
      return c.json({ success: false, error: 'Apple ID token required' }, 400);
    }

    const appleData = await verifyAppleIdToken(body.apple_id_token, c.env);
    if (!appleData) {
      return c.json({ success: false, error: 'Invalid Apple ID token' }, 401);
    }

    appleUserId = appleData.sub;
  } else {
    // Email/Password registration
    if (!body.password) {
      return c.json({ success: false, error: 'Password required' }, 400);
    }

    const passwordValidation = isValidPassword(body.password);
    if (!passwordValidation.valid) {
      return c.json({ success: false, error: passwordValidation.message }, 400);
    }

    passwordHash = await hashPassword(body.password);
  }

  userId = generateId('usr');
  const now = new Date().toISOString();

  // Create user
  await c.env.DB.prepare(`
    INSERT INTO users (id, email, password_hash, name, auth_provider, apple_user_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    userId,
    body.email.toLowerCase(),
    passwordHash,
    body.name || null,
    body.auth_provider,
    appleUserId,
    now,
    now
  ).run();

  // Get created user
  const user = await c.env.DB.prepare(`
    SELECT * FROM users WHERE id = ?
  `).bind(userId).first<User>();

  if (!user) {
    return c.json({ success: false, error: 'Failed to create user' }, 500);
  }

  // Generate tokens
  const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';
  const token = await generateToken(user, jwtSecret);
  const refreshToken = await generateRefreshToken();

  // Store session
  await storeSession(c.env, userId, refreshToken);

  return c.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      created_at: user.created_at,
    },
    token,
    refresh_token: refreshToken,
  });
});

// POST /auth/login
auth.post('/login', async (c) => {
  const body = await c.req.json<LoginRequest>();

  if (!body.email || !body.password) {
    return c.json({ success: false, error: 'Email and password required' }, 400);
  }

  // Find user
  const user = await c.env.DB.prepare(`
    SELECT * FROM users WHERE email = ? AND auth_provider = 'email'
  `).bind(body.email.toLowerCase()).first<User>();

  if (!user || !user.password_hash) {
    return c.json({ success: false, error: 'Invalid credentials' }, 401);
  }

  // Verify password
  const validPassword = await verifyPassword(body.password, user.password_hash);
  if (!validPassword) {
    return c.json({ success: false, error: 'Invalid credentials' }, 401);
  }

  // Generate tokens
  const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';
  const token = await generateToken(user, jwtSecret);
  const refreshToken = await generateRefreshToken();

  // Store session
  await storeSession(c.env, user.id, refreshToken);

  return c.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      subscription_status: user.subscription_status,
      created_at: user.created_at,
    },
    token,
    refresh_token: refreshToken,
  });
});

// POST /auth/apple
auth.post('/apple', async (c) => {
  const body = await c.req.json<{ id_token: string; authorization_code?: string }>();

  if (!body.id_token) {
    return c.json({ success: false, error: 'Apple ID token required' }, 400);
  }

  const appleData = await verifyAppleIdToken(body.id_token, c.env);
  if (!appleData) {
    return c.json({ success: false, error: 'Invalid Apple ID token' }, 401);
  }

  // Check if user exists with this Apple ID
  let user = await c.env.DB.prepare(`
    SELECT * FROM users WHERE apple_user_id = ?
  `).bind(appleData.sub).first<User>();

  if (!user) {
    // Check if user exists with this email
    user = await c.env.DB.prepare(`
      SELECT * FROM users WHERE email = ?
    `).bind(appleData.email.toLowerCase()).first<User>();

    if (user) {
      // Link Apple ID to existing account
      await c.env.DB.prepare(`
        UPDATE users SET apple_user_id = ?, auth_provider = 'apple', updated_at = ?
        WHERE id = ?
      `).bind(appleData.sub, new Date().toISOString(), user.id).run();
    } else {
      // Create new user
      const userId = generateId('usr');
      const now = new Date().toISOString();

      await c.env.DB.prepare(`
        INSERT INTO users (id, email, auth_provider, apple_user_id, created_at, updated_at)
        VALUES (?, ?, 'apple', ?, ?, ?)
      `).bind(userId, appleData.email.toLowerCase(), appleData.sub, now, now).run();

      user = await c.env.DB.prepare(`
        SELECT * FROM users WHERE id = ?
      `).bind(userId).first<User>();
    }
  }

  if (!user) {
    return c.json({ success: false, error: 'Failed to authenticate' }, 500);
  }

  // Generate tokens
  const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';
  const token = await generateToken(user, jwtSecret);
  const refreshToken = await generateRefreshToken();

  // Store session
  await storeSession(c.env, user.id, refreshToken);

  return c.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      subscription_status: user.subscription_status,
      created_at: user.created_at,
    },
    token,
    refresh_token: refreshToken,
  });
});

// POST /auth/refresh
auth.post('/refresh', async (c) => {
  const body = await c.req.json<{ refresh_token: string }>();

  if (!body.refresh_token) {
    return c.json({ success: false, error: 'Refresh token required' }, 400);
  }

  const userId = await verifyRefreshToken(c.env, body.refresh_token);
  if (!userId) {
    return c.json({ success: false, error: 'Invalid refresh token' }, 401);
  }

  // Get user
  const user = await c.env.DB.prepare(`
    SELECT * FROM users WHERE id = ?
  `).bind(userId).first<User>();

  if (!user) {
    return c.json({ success: false, error: 'User not found' }, 401);
  }

  // Revoke old refresh token
  await revokeSession(c.env, body.refresh_token);

  // Generate new tokens
  const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';
  const token = await generateToken(user, jwtSecret);
  const refreshToken = await generateRefreshToken();

  // Store new session
  await storeSession(c.env, user.id, refreshToken);

  return c.json({
    success: true,
    token,
    refresh_token: refreshToken,
  });
});

// DELETE /auth/logout
auth.delete('/logout', authMiddleware, async (c) => {
  const body = await c.req.json<{ refresh_token?: string; all_devices?: boolean }>();

  if (body.all_devices) {
    await revokeAllSessions(c.env, c.get('userId'));
  } else if (body.refresh_token) {
    await revokeSession(c.env, body.refresh_token);
  }

  return c.json({ success: true, message: 'Logged out successfully' });
});

export default auth;
