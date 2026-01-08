import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { secureHeaders } from 'hono/secure-headers';
import type { Env } from './types';

// Import routes
import auth from './routes/auth';
import babies from './routes/babies';
import content from './routes/content';
import analytics from './routes/analytics';
import subscriptions from './routes/subscriptions';
import users from './routes/users';
import ai from './routes/ai';
import audio from './routes/audio';
import curation from './routes/curation';
import music from './routes/music';
import search from './routes/search';
import emergency from './routes/emergency';
import preferences from './routes/preferences';

// Import services
import { handleScheduledCuration } from './services/audio-curator';
import { scrapeAudioContent } from './cron/audio-scraper';

const app = new Hono<{ Bindings: Env }>();

// Global middleware
app.use('*', logger());
app.use('*', secureHeaders());
app.use('*', cors({
  origin: '*', // In production, restrict to your app bundle ID
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  exposeHeaders: ['X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset'],
  maxAge: 86400,
}));

// Health check
app.get('/', (c) => {
  return c.json({
    name: 'Baby in Car API',
    version: '1.0.0',
    status: 'healthy',
    environment: c.env.ENVIRONMENT || 'development',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (c) => {
  return c.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.route('/auth', auth);
app.route('/babies', babies);
app.route('/content', content);
app.route('/analytics', analytics);
app.route('/subscriptions', subscriptions);
app.route('/users', users);
app.route('/ai', ai);
app.route('/audio', audio);
app.route('/curation', curation);
app.route('/music', music);
app.route('/search', search);
app.route('/playlists/emergency', emergency);  // FS-017: Emergency playlist selection
app.route('/preferences', preferences);  // FS-017: User language preferences

// 404 handler
app.notFound((c) => {
  return c.json({
    success: false,
    error: 'Not Found',
    path: c.req.path,
  }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);

  // Don't expose internal errors in production
  const isProduction = c.env.ENVIRONMENT === 'production';

  return c.json({
    success: false,
    error: isProduction ? 'Internal Server Error' : err.message,
    ...(isProduction ? {} : { stack: err.stack }),
  }, 500);
});

// Export for Cloudflare Workers
export default {
  // HTTP request handler
  fetch: app.fetch,

  // Cron job handler - runs every 6 hours
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    console.log('[Cron] 🕐 Cron trigger fired at:', new Date(event.scheduledTime).toISOString());

    // Run 24/7 audio scraping (every 6 hours)
    console.log('[Cron] Running 24/7 audio scraping...');
    ctx.waitUntil(scrapeAudioContent(env));

    // Also run legacy audio curation
    console.log('[Cron] Running audio curation...');
    ctx.waitUntil(handleScheduledCuration(env));
  },
};
