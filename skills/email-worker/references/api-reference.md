# Email Worker API Reference

## Endpoints

### POST /send — Send an email

**Request body (JSON):**

```json
{
  "to": "recipient@example.com",
  "from": {
    "email": "noreply@yourdomain.com",
    "name": "Your Site Name"
  },
  "subject": "Contact Form Submission",
  "text": "Plain text body",
  "html": "<h1>HTML body</h1>",
  "replyTo": "user@email.com"
}
```

| Field | Required | Type | Notes |
|-------|----------|------|-------|
| `to` | Yes | `string \| string[]` | Single email or array of recipients |
| `from.email` | Yes | `string` | Must be a verified SendGrid sender |
| `from.name` | No | `string` | Defaults to "Contact Form" |
| `subject` | Yes | `string` | Email subject line |
| `text` | One of text/html | `string` | Plain text body |
| `html` | One of text/html | `string` | HTML body |
| `replyTo` | No | `string` | Sets Reply-To header for replies |

**Responses:**

| Status | Body | Meaning |
|--------|------|---------|
| `200` | `{ "success": true, "message": "Email sent successfully" }` | Email delivered to SendGrid |
| `400` | `{ "success": false, "error": "Missing required field: ..." }` | Validation error |
| `500` | `{ "success": false, "error": "Email service not configured..." }` | Missing API key |
| `4xx/5xx` | `{ "success": false, "error": "Email service error", "details": "..." }` | SendGrid error |

### GET /health — Health check

Returns: `{ "status": "ok", "timestamp": 1234567890 }`

---

## CORS Configuration

The worker checks the `Origin` header against the `ALLOWED_ORIGINS` env var in `wrangler.toml`.

**Current configuration** (`/Users/aabyzovext/Projects/Webstudio/cloudflare-email-worker/wrangler.toml`):

```toml
[vars]
ALLOWED_ORIGINS = "https://merenkovanutrition.com,https://localhost:3000"
```

To add a new domain, append it to the comma-separated list and redeploy.

Localhost origins (`localhost`, `127.0.0.1`) are always allowed regardless of this setting.

---

## Validation Rules

The worker validates:
- `to` — must be present; each email must match `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`
- `from.email` — must be present and valid format
- `subject` — must be present
- Content — at least one of `text` or `html` must be provided

---

## Integration Examples

### Vanilla JavaScript

```javascript
const EMAIL_WORKER_URL = 'https://email-service.YOUR_SUBDOMAIN.workers.dev';

async function sendContactForm(formData) {
  const response = await fetch(`${EMAIL_WORKER_URL}/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: 'business@example.com',
      from: {
        email: 'noreply@yourdomain.com',
        name: 'Your Site Name'
      },
      subject: `New inquiry from ${formData.name}`,
      html: `
        <h2>New Contact Form Submission</h2>
        <p><strong>Name:</strong> ${formData.name}</p>
        <p><strong>Email:</strong> ${formData.email}</p>
        <p><strong>Message:</strong></p>
        <p>${formData.message}</p>
        <hr>
        <p style="color: #999; font-size: 12px;">
          Sent from your website at ${new Date().toLocaleString()}
        </p>
      `,
      replyTo: formData.email
    })
  });

  const result = await response.json();
  if (!result.success) throw new Error(result.error);
  return result;
}
```

### React / Next.js

```tsx
const EMAIL_WORKER_URL = process.env.NEXT_PUBLIC_EMAIL_WORKER_URL;

async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();
  setLoading(true);
  setError(null);

  try {
    const res = await fetch(`${EMAIL_WORKER_URL}/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: 'owner@business.com',
        from: { email: 'noreply@domain.com', name: 'Site Name' },
        subject: `Contact from ${name}`,
        html: buildEmailHtml({ name, email, phone, message }),
        replyTo: email
      })
    });

    const data = await res.json();
    if (data.success) {
      setSuccess(true);
      resetForm();
    } else {
      setError('Failed to send message. Please try again.');
    }
  } catch {
    setError('Something went wrong. Please try again later.');
  } finally {
    setLoading(false);
  }
}
```

### Swift (iOS)

```swift
struct EmailRequest: Encodable {
    let to: String
    let from: EmailSender
    let subject: String
    let html: String
    let replyTo: String?

    struct EmailSender: Encodable {
        let email: String
        let name: String
    }
}

func sendEmail(_ request: EmailRequest) async throws -> Bool {
    let url = URL(string: "\(emailWorkerURL)/send")!
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, _) = try await URLSession.shared.data(for: urlRequest)
    let result = try JSONDecoder().decode(EmailResponse.self, from: data)
    return result.success
}
```

---

## Worker Management

All commands from: `cd /Users/aabyzovext/Projects/Webstudio/cloudflare-email-worker`

| Task | Command |
|------|---------|
| Deploy changes | `npm run deploy` |
| Local development | `npm run dev` |
| View live logs | `npm run tail` |
| Set SendGrid key | `wrangler secret put SENDGRID_API_KEY` |

---

## Source Code Location

```
/Users/aabyzovext/Projects/Webstudio/cloudflare-email-worker/
├── wrangler.toml       # Worker config + CORS origins
├── package.json        # Scripts: dev, deploy, tail
├── src/
│   └── index.js        # Full worker (~215 lines)
└── .gitignore
```

The entire worker is a single `src/index.js` file. If you need to understand or modify the worker behavior, read that file directly.
