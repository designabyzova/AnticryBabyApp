---
name: email-worker
description: Integrate the existing Cloudflare Email Worker service into any website, app, or project for sending emails. Use this skill whenever the user needs to add a contact form, send transactional emails, set up email notifications, wire up a "request a quote" or "book now" form, send order confirmations, or integrate email sending into any project. Also use when the user mentions email, contact forms, SendGrid, or email notifications in the context of building or extending a website or app. The email worker already exists and is deployed — this skill knows exactly how to call it.
---

# Cloudflare Email Worker Integration

You are an expert at integrating the existing Cloudflare Email Worker service into any website, app, or project. The worker is already deployed and running — your job is to wire it up, not rebuild it.

## The Service

A **generic email sending service** running as a Cloudflare Worker using **SendGrid** as the provider. It's designed to be reused across multiple websites and projects by simply calling its API.

- **Source code**: `/Users/aabyzovext/Projects/Webstudio/cloudflare-email-worker/`
- **Worker name**: `email-service`
- **Deployed URL pattern**: `https://email-service.<subdomain>.workers.dev`

For full API details, source code reference, and deployment commands, read `references/api-reference.md`.

## Integration Workflow

When the user wants email functionality in any project, follow these steps:

### Step 1: Add the origin to CORS

The worker only accepts requests from whitelisted origins. Edit `wrangler.toml` at the source path above — add the new domain to `ALLOWED_ORIGINS` (comma-separated). Then redeploy with `npm run deploy` from the worker directory.

Localhost origins are always allowed automatically, so local dev works out of the box.

### Step 2: Create the client-side integration

Build the form or trigger that POSTs to the worker's `/send` endpoint. Adapt to whatever framework or language the project uses. The API reference in `references/api-reference.md` has examples for vanilla JS, React, and Swift.

The core pattern is always the same — a POST with JSON:

```javascript
await fetch(WORKER_URL + '/send', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    to: 'business@example.com',
    from: { email: 'noreply@domain.com', name: 'Site Name' },
    subject: 'New inquiry',
    html: '<p>Message content</p>',
    replyTo: 'customer@email.com'
  })
});
```

### Step 3: Build a proper HTML email template

Never send raw user input as email body. Always generate a clean, branded HTML template that includes the business name/logo, structured form fields, a timestamp, and a footer. This makes emails look professional and trustworthy.

### Step 4: Handle UX properly

- Validate form fields client-side before hitting the API
- Show loading states while the request is in flight
- Display user-friendly success/error messages (not raw API errors)
- Disable the submit button after send to prevent duplicates

## Important Constraints

1. **SendGrid sender verification** — The `from.email` must be verified in SendGrid's Sender Authentication. New domains need verification at https://app.sendgrid.com/settings/sender_auth
2. **CORS** — Every new domain must be added to `ALLOWED_ORIGINS` and the worker redeployed
3. **No attachments** — The current worker doesn't support file attachments
4. **No queuing** — Emails are sent synchronously; if SendGrid is down, the request fails
5. **No rebuilding** — The worker already works. Call the API, don't recreate the service

## When NOT to Use This

- If the user needs email with attachments (this worker doesn't support them yet)
- If the user needs a full email marketing platform (suggest Mailchimp, ConvertKit, etc.)
- If the user wants to receive/parse incoming emails (this is send-only)
