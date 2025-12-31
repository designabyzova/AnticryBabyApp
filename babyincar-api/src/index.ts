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

// Import services
import { handleScheduledCuration } from './services/audio-curator';

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

  // Scheduled cron handler for automated audio curation
  // Runs daily to discover and download new content
  async scheduled(
    controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    console.log('[Scheduled] Cron trigger fired:', controller.cron);

    switch (controller.cron) {
      case '0 3 * * *': // Daily at 3 AM UTC - Full curation
        ctx.waitUntil(handleScheduledCuration(env));
        break;

      case '0 */6 * * *': // Every 6 hours - Quick check for new content
        ctx.waitUntil(handleScheduledCuration(env));
        break;

      default:
        console.log('[Scheduled] Unknown cron pattern:', controller.cron);
    }
  },
};
