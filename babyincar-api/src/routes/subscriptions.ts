import { Hono } from 'hono';
import type { Env, User, SubscriptionVerification } from '../types';
import { authMiddleware } from '../middleware/auth';

const subscriptions = new Hono<{ Bindings: Env }>();

// All routes require authentication
subscriptions.use('*', authMiddleware);

// POST /subscriptions/verify - Verify App Store receipt
subscriptions.post('/verify', async (c) => {
  const user = c.get('user');
  const body = await c.req.json<{
    receipt_data: string;
    product_id: string;
  }>();

  if (!body.receipt_data || !body.product_id) {
    return c.json({ success: false, error: 'Receipt data and product ID required' }, 400);
  }

  try {
    // Verify with Apple's servers
    const verification = await verifyAppStoreReceipt(
      body.receipt_data,
      c.env.APP_STORE_SHARED_SECRET,
      c.env.ENVIRONMENT === 'production'
    );

    if (!verification.valid) {
      return c.json({
        success: false,
        error: 'Invalid receipt',
        valid: false,
      }, 400);
    }

    // Update user subscription status
    const subscriptionStatus = getSubscriptionStatus(body.product_id);
    const expiresAt = verification.subscription?.expires_at || null;

    await c.env.DB.prepare(`
      UPDATE users
      SET subscription_status = ?,
          subscription_expires_at = ?,
          updated_at = ?
      WHERE id = ?
    `).bind(
      subscriptionStatus,
      expiresAt,
      new Date().toISOString(),
      user.id
    ).run();

    return c.json({
      success: true,
      valid: true,
      subscription: verification.subscription,
      entitlements: verification.entitlements,
    });
  } catch (error) {
    console.error('Receipt verification failed:', error);
    return c.json({
      success: false,
      error: 'Verification failed',
      valid: false,
    }, 500);
  }
});

// GET /subscriptions/status - Get current subscription status
subscriptions.get('/status', async (c) => {
  const user = c.get('user');

  // Check if subscription is expired
  let status = user.subscription_status;
  let isActive = status !== 'free';

  if (user.subscription_expires_at) {
    const expiresAt = new Date(user.subscription_expires_at);
    if (expiresAt < new Date()) {
      // Subscription expired, update status
      await c.env.DB.prepare(`
        UPDATE users
        SET subscription_status = 'free',
            subscription_expires_at = NULL,
            updated_at = ?
        WHERE id = ?
      `).bind(new Date().toISOString(), user.id).run();

      status = 'free';
      isActive = false;
    }
  }

  const entitlements = getEntitlements(status);

  return c.json({
    success: true,
    subscription: {
      status,
      is_active: isActive,
      expires_at: user.subscription_expires_at,
      entitlements,
    },
  });
});

// POST /subscriptions/webhook - App Store Server Notifications
// This endpoint should be called by Apple, not the app
subscriptions.post('/webhook', async (c) => {
  // Verify the notification is from Apple
  const signedPayload = await c.req.text();

  try {
    const notification = await parseAppStoreNotification(signedPayload, c.env);

    if (!notification) {
      return c.json({ success: false, error: 'Invalid notification' }, 400);
    }

    const { notificationType, data } = notification;

    // Find user by original transaction ID or app account token
    const user = await findUserByTransaction(c.env.DB, data.originalTransactionId);

    if (!user) {
      console.error('User not found for transaction:', data.originalTransactionId);
      return c.json({ success: true }); // Return success to not retry
    }

    // Handle different notification types
    switch (notificationType) {
      case 'SUBSCRIBED':
      case 'DID_RENEW':
        await c.env.DB.prepare(`
          UPDATE users
          SET subscription_status = ?,
              subscription_expires_at = ?,
              updated_at = ?
          WHERE id = ?
        `).bind(
          getSubscriptionStatus(data.productId),
          data.expiresDate,
          new Date().toISOString(),
          user.id
        ).run();
        break;

      case 'EXPIRED':
      case 'DID_FAIL_TO_RENEW':
      case 'REVOKE':
        await c.env.DB.prepare(`
          UPDATE users
          SET subscription_status = 'free',
              subscription_expires_at = NULL,
              updated_at = ?
          WHERE id = ?
        `).bind(new Date().toISOString(), user.id).run();
        break;

      case 'GRACE_PERIOD_EXPIRED':
        // Keep premium but mark as in grace period
        break;

      default:
        console.log('Unhandled notification type:', notificationType);
    }

    return c.json({ success: true });
  } catch (error) {
    console.error('Webhook processing failed:', error);
    return c.json({ success: false, error: 'Processing failed' }, 500);
  }
});

// Helper: Verify App Store receipt
async function verifyAppStoreReceipt(
  receiptData: string,
  sharedSecret: string,
  isProduction: boolean
): Promise<SubscriptionVerification> {
  const verifyUrl = isProduction
    ? 'https://buy.itunes.apple.com/verifyReceipt'
    : 'https://sandbox.itunes.apple.com/verifyReceipt';

  const response = await fetch(verifyUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receiptData,
      password: sharedSecret,
      'exclude-old-transactions': true,
    }),
  });

  const result = await response.json() as {
    status: number;
    latest_receipt_info?: Array<{
      product_id: string;
      expires_date_ms: string;
      is_trial_period: string;
      auto_renew_status: string;
    }>;
  };

  // Status 0 = valid
  if (result.status !== 0) {
    // Status 21007 = sandbox receipt sent to production, retry with sandbox
    if (result.status === 21007 && isProduction) {
      return verifyAppStoreReceipt(receiptData, sharedSecret, false);
    }
    return { valid: false, subscription: null, entitlements: [] };
  }

  // Get latest transaction
  const latestInfo = result.latest_receipt_info?.[0];
  if (!latestInfo) {
    return { valid: false, subscription: null, entitlements: [] };
  }

  const expiresAt = new Date(parseInt(latestInfo.expires_date_ms));
  const isExpired = expiresAt < new Date();

  if (isExpired) {
    return { valid: false, subscription: null, entitlements: [] };
  }

  return {
    valid: true,
    subscription: {
      product_id: latestInfo.product_id,
      expires_at: expiresAt.toISOString(),
      is_trial: latestInfo.is_trial_period === 'true',
      will_renew: latestInfo.auto_renew_status === '1',
    },
    entitlements: getEntitlements(getSubscriptionStatus(latestInfo.product_id)),
  };
}

// Helper: Get subscription status from product ID
function getSubscriptionStatus(productId: string): 'free' | 'premium' | 'family' {
  if (productId.includes('family')) {
    return 'family';
  }
  if (productId.includes('premium') || productId.includes('lifetime')) {
    return 'premium';
  }
  return 'free';
}

// Helper: Get entitlements for subscription status
function getEntitlements(status: string): string[] {
  const baseEntitlements = ['basic_content'];

  if (status === 'premium' || status === 'family') {
    return [
      ...baseEntitlements,
      'premium_content',
      'offline_downloads',
      'all_languages',
      'unlimited_emergency',
      'carplay',
      'advanced_ai',
    ];
  }

  if (status === 'family') {
    return [
      ...baseEntitlements,
      'premium_content',
      'offline_downloads',
      'all_languages',
      'unlimited_emergency',
      'carplay',
      'advanced_ai',
      'family_sharing',
      'multiple_profiles',
    ];
  }

  return baseEntitlements;
}

// Helper: Parse App Store Server Notification
async function parseAppStoreNotification(
  signedPayload: string,
  _env: Env
): Promise<{
  notificationType: string;
  data: {
    originalTransactionId: string;
    productId: string;
    expiresDate: string;
  };
} | null> {
  // In production, verify JWS signature using Apple's public key
  // For simplicity, just decode the payload here
  try {
    const parts = signedPayload.split('.');
    if (parts.length !== 3) return null;

    const payload = JSON.parse(atob(parts[1]));
    return payload;
  } catch {
    return null;
  }
}

// Helper: Find user by transaction ID
async function findUserByTransaction(
  db: D1Database,
  _transactionId: string
): Promise<User | null> {
  // In a real implementation, you would store transaction IDs
  // and look up the user that way
  // For now, return null
  return null;
}

export default subscriptions;
