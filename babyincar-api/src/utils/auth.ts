import * as jose from 'jose';
import type { Env, AuthPayload, User } from '../types';

// Generate unique ID
export function generateId(prefix: string): string {
  const timestamp = Date.now().toString(36);
  const randomPart = Math.random().toString(36).substring(2, 10);
  return `${prefix}_${timestamp}${randomPart}`;
}

// Hash password using Web Crypto API
export async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Verify password
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  const passwordHash = await hashPassword(password);
  return passwordHash === hash;
}

// Generate JWT token
export async function generateToken(
  user: User,
  secret: string,
  expiresInHours: number = 1
): Promise<string> {
  const secretKey = new TextEncoder().encode(secret);

  const token = await new jose.SignJWT({
    user_id: user.id,
    email: user.email,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(`${expiresInHours}h`)
    .sign(secretKey);

  return token;
}

// Generate refresh token
export async function generateRefreshToken(): Promise<string> {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

// Verify JWT token
export async function verifyToken(
  token: string,
  secret: string
): Promise<AuthPayload | null> {
  try {
    const secretKey = new TextEncoder().encode(secret);
    const { payload } = await jose.jwtVerify(token, secretKey);

    return {
      user_id: payload.user_id as string,
      email: payload.email as string,
      exp: payload.exp as number,
      iat: payload.iat as number,
    };
  } catch {
    return null;
  }
}

// Hash token for storage
export async function hashToken(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Store session in KV
export async function storeSession(
  env: Env,
  userId: string,
  refreshToken: string,
  expiresInDays: number = 30
): Promise<void> {
  const tokenHash = await hashToken(refreshToken);
  const sessionId = generateId('sess');
  const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);

  // Store in D1
  await env.DB.prepare(`
    INSERT INTO sessions (id, user_id, token_hash, expires_at)
    VALUES (?, ?, ?, ?)
  `).bind(sessionId, userId, tokenHash, expiresAt.toISOString()).run();

  // Also store in KV for fast lookup
  await env.SESSIONS.put(
    `refresh:${tokenHash}`,
    JSON.stringify({ session_id: sessionId, user_id: userId }),
    { expirationTtl: expiresInDays * 24 * 60 * 60 }
  );
}

// Verify refresh token
export async function verifyRefreshToken(
  env: Env,
  refreshToken: string
): Promise<string | null> {
  const tokenHash = await hashToken(refreshToken);

  // Check KV first
  const sessionData = await env.SESSIONS.get(`refresh:${tokenHash}`);
  if (!sessionData) {
    return null;
  }

  const { user_id } = JSON.parse(sessionData);
  return user_id;
}

// Revoke session
export async function revokeSession(
  env: Env,
  refreshToken: string
): Promise<void> {
  const tokenHash = await hashToken(refreshToken);

  // Delete from KV
  await env.SESSIONS.delete(`refresh:${tokenHash}`);

  // Delete from D1
  await env.DB.prepare(`
    DELETE FROM sessions WHERE token_hash = ?
  `).bind(tokenHash).run();
}

// Revoke all sessions for user
export async function revokeAllSessions(
  env: Env,
  userId: string
): Promise<void> {
  // Get all sessions from D1
  const sessions = await env.DB.prepare(`
    SELECT token_hash FROM sessions WHERE user_id = ?
  `).bind(userId).all();

  // Delete each from KV
  for (const session of sessions.results) {
    await env.SESSIONS.delete(`refresh:${session.token_hash as string}`);
  }

  // Delete all from D1
  await env.DB.prepare(`
    DELETE FROM sessions WHERE user_id = ?
  `).bind(userId).run();
}

// Validate email format
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Validate password strength
export function isValidPassword(password: string): { valid: boolean; message?: string } {
  if (password.length < 8) {
    return { valid: false, message: 'Password must be at least 8 characters' };
  }
  if (!/[A-Z]/.test(password)) {
    return { valid: false, message: 'Password must contain an uppercase letter' };
  }
  if (!/[a-z]/.test(password)) {
    return { valid: false, message: 'Password must contain a lowercase letter' };
  }
  if (!/[0-9]/.test(password)) {
    return { valid: false, message: 'Password must contain a number' };
  }
  return { valid: true };
}

// Verify Apple ID token
export async function verifyAppleIdToken(
  idToken: string,
  env: Env
): Promise<{ email: string; sub: string } | null> {
  try {
    // Fetch Apple's public keys
    const response = await fetch('https://appleid.apple.com/auth/keys');
    const { keys } = await response.json() as { keys: jose.JWK[] };

    // Create JWKS
    const JWKS = jose.createRemoteJWKSet(
      new URL('https://appleid.apple.com/auth/keys')
    );

    // Verify the token
    const { payload } = await jose.jwtVerify(idToken, JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: 'com.babyincar.app', // Your app's bundle ID
    });

    return {
      email: payload.email as string,
      sub: payload.sub as string,
    };
  } catch (error) {
    console.error('Apple ID token verification failed:', error);
    return null;
  }
}
