import { Context, Next } from 'hono';
import { verifyToken } from '../utils/auth';
import type { Env, User } from '../types';

// Extend Hono context with user
declare module 'hono' {
  interface ContextVariableMap {
    user: User;
    userId: string;
  }
}

// Auth middleware - requires valid JWT
export async function authMiddleware(c: Context<{ Bindings: Env }>, next: Next) {
  const authHeader = c.req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ success: false, error: 'Missing authorization header' }, 401);
  }

  const token = authHeader.substring(7);
  const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';

  const payload = await verifyToken(token, jwtSecret);

  if (!payload) {
    return c.json({ success: false, error: 'Invalid or expired token' }, 401);
  }

  // Check if token is expired
  if (payload.exp * 1000 < Date.now()) {
    return c.json({ success: false, error: 'Token expired' }, 401);
  }

  // Get user from database
  const user = await c.env.DB.prepare(`
    SELECT * FROM users WHERE id = ?
  `).bind(payload.user_id).first<User>();

  if (!user) {
    return c.json({ success: false, error: 'User not found' }, 401);
  }

  // Set user in context
  c.set('user', user);
  c.set('userId', user.id);

  await next();
}

// Optional auth middleware - sets user if token is valid, but doesn't require it
export async function optionalAuthMiddleware(c: Context<{ Bindings: Env }>, next: Next) {
  const authHeader = c.req.header('Authorization');

  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    const jwtSecret = c.env.JWT_SECRET || 'dev-secret-change-in-production';

    const payload = await verifyToken(token, jwtSecret);

    if (payload && payload.exp * 1000 > Date.now()) {
      const user = await c.env.DB.prepare(`
        SELECT * FROM users WHERE id = ?
      `).bind(payload.user_id).first<User>();

      if (user) {
        c.set('user', user);
        c.set('userId', user.id);
      }
    }
  }

  await next();
}

// Premium check middleware - requires premium subscription
export async function premiumMiddleware(c: Context<{ Bindings: Env }>, next: Next) {
  const user = c.get('user');

  if (!user) {
    return c.json({ success: false, error: 'Authentication required' }, 401);
  }

  if (user.subscription_status === 'free') {
    return c.json({
      success: false,
      error: 'Premium subscription required',
      upgrade_required: true
    }, 403);
  }

  // Check if subscription is still valid
  if (user.subscription_expires_at) {
    const expiresAt = new Date(user.subscription_expires_at);
    if (expiresAt < new Date()) {
      // Update user status to free
      await c.env.DB.prepare(`
        UPDATE users SET subscription_status = 'free', subscription_expires_at = NULL
        WHERE id = ?
      `).bind(user.id).run();

      return c.json({
        success: false,
        error: 'Subscription expired',
        upgrade_required: true
      }, 403);
    }
  }

  await next();
}

// Rate limiting middleware
export async function rateLimitMiddleware(
  limit: number = 100,
  windowSeconds: number = 60
) {
  return async function(c: Context<{ Bindings: Env }>, next: Next) {
    const identifier = c.get('userId') || c.req.header('CF-Connecting-IP') || 'anonymous';
    const window = Math.floor(Date.now() / (windowSeconds * 1000));
    const key = `ratelimit:${identifier}:${window}`;

    const current = await c.env.SESSIONS.get(key);
    const count = current ? parseInt(current, 10) : 0;

    if (count >= limit) {
      return c.json({
        success: false,
        error: 'Rate limit exceeded',
        retry_after: windowSeconds
      }, 429);
    }

    await c.env.SESSIONS.put(key, (count + 1).toString(), {
      expirationTtl: windowSeconds
    });

    // Add rate limit headers
    c.header('X-RateLimit-Limit', limit.toString());
    c.header('X-RateLimit-Remaining', (limit - count - 1).toString());
    c.header('X-RateLimit-Reset', ((window + 1) * windowSeconds * 1000).toString());

    await next();
  };
}

// CORS middleware
export function corsMiddleware() {
  return async function(c: Context, next: Next) {
    // Handle preflight
    if (c.req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    await next();

    // Add CORS headers to response
    c.header('Access-Control-Allow-Origin', '*');
    c.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  };
}
