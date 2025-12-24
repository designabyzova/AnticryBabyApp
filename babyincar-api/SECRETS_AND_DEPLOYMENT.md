# Baby in Car API - Secrets Management & Deployment Guide

## 🔐 Secrets Management Best Practices

### Where to Store Secrets

**NEVER store secrets in:**
- ❌ Source code files
- ❌ wrangler.toml (except for non-sensitive `[vars]`)
- ❌ Git repositories
- ❌ Plain text files

**ALWAYS store secrets in:**
- ✅ Cloudflare Workers Secrets (encrypted at rest)
- ✅ Environment variables (for local dev)
- ✅ Secure password managers (for backup)

### Required Secrets

| Secret Name | Description | How to Generate |
|------------|-------------|-----------------|
| `JWT_SECRET` | Signs JWT tokens | `openssl rand -hex 32` |
| `APP_STORE_SHARED_SECRET` | App Store receipt verification | App Store Connect → App → In-App Purchases |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID | Apple Developer Portal |
| `APPLE_KEY_ID` | Sign In with Apple Key ID | Apple Developer Portal → Keys |
| `APPLE_PRIVATE_KEY` | Sign In with Apple private key | Apple Developer Portal → Keys |

---

## 🚀 Deployment Steps

### Step 1: Install Wrangler CLI

```bash
npm install -g wrangler

# Login to Cloudflare
wrangler login
```

### Step 2: Create Cloudflare Resources

```bash
cd babyincar-api

# Create D1 Database
wrangler d1 create babyincar-db
# Copy the database_id to wrangler.toml

# Create KV Namespaces
wrangler kv:namespace create sessions
wrangler kv:namespace create cache
# Copy the IDs to wrangler.toml

# Create R2 Buckets
wrangler r2 bucket create babyincar-audio
wrangler r2 bucket create babyincar-images
```

### Step 3: Update wrangler.toml

Replace placeholder IDs in `wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "babyincar-db"
database_id = "YOUR_ACTUAL_DATABASE_ID"  # ← Replace this

[[kv_namespaces]]
binding = "SESSIONS"
id = "YOUR_ACTUAL_KV_ID"  # ← Replace this
```

### Step 4: Set Secrets (SECURE METHOD)

```bash
# Generate a strong JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Set secrets using Wrangler (they're encrypted)
wrangler secret put JWT_SECRET
# Paste your secret when prompted

wrangler secret put APP_STORE_SHARED_SECRET
# Paste from App Store Connect

wrangler secret put APPLE_TEAM_ID
wrangler secret put APPLE_KEY_ID
wrangler secret put APPLE_PRIVATE_KEY
```

### Step 5: Run Database Migrations

```bash
# Development (local)
wrangler d1 execute babyincar-db --file=./migrations/001_initial.sql --local
wrangler d1 execute babyincar-db --file=./migrations/002_seed_content.sql --local

# Production (remote)
wrangler d1 execute babyincar-db --file=./migrations/001_initial.sql --remote
wrangler d1 execute babyincar-db --file=./migrations/002_seed_content.sql --remote
```

### Step 6: Deploy

```bash
# Install dependencies
npm install

# Deploy to development
wrangler deploy

# Deploy to production
wrangler deploy --env production
```

---

## 🔧 Local Development

### Create .dev.vars file (gitignored)

```bash
# Create .dev.vars for local secrets (NEVER commit this file)
cat > .dev.vars << 'EOF'
JWT_SECRET=dev-secret-for-local-testing-only
APP_STORE_SHARED_SECRET=your-sandbox-secret
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----"
EOF
```

### Run Local Development Server

```bash
# Start local dev server
npm run dev

# The API will be available at http://localhost:8787
```

### Test API Locally

```bash
# Health check
curl http://localhost:8787/health

# Register user
curl -X POST http://localhost:8787/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test1234!","auth_provider":"email"}'
```

---

## 🌐 Custom Domain Setup

### Option 1: Workers Route

```toml
# In wrangler.toml
routes = [
  { pattern = "api.babyincar.app/*", zone_name = "babyincar.app" }
]
```

### Option 2: Custom Domain (Recommended)

1. Go to Cloudflare Dashboard → Workers & Pages
2. Select your worker → Settings → Triggers
3. Add Custom Domain: `api.babyincar.app`
4. Cloudflare automatically provisions SSL

---

## 📊 Monitoring

### View Logs

```bash
# Real-time logs
wrangler tail

# With filters
wrangler tail --search "error"
```

### Cloudflare Dashboard

- **Analytics**: Workers & Pages → Analytics
- **Errors**: Workers & Pages → Logs
- **D1 Stats**: D1 → Your Database → Metrics

---

## 🔄 CI/CD with GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]
    paths:
      - 'babyincar-api/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: ./babyincar-api
        run: npm install

      - name: Deploy
        working-directory: ./babyincar-api
        run: npx wrangler deploy
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

### Set GitHub Secret

1. Go to GitHub repo → Settings → Secrets
2. Add `CLOUDFLARE_API_TOKEN` (create API token with Workers permissions)

---

## 🛡️ Security Checklist

- [ ] All secrets stored in Wrangler secrets (not in code)
- [ ] `.dev.vars` added to `.gitignore`
- [ ] JWT expiry set to 1 hour
- [ ] Refresh tokens expire in 30 days
- [ ] Rate limiting enabled
- [ ] CORS restricted to app bundle ID in production
- [ ] HTTPS only
- [ ] Input validation on all endpoints
- [ ] SQL injection prevented (parameterized queries)
- [ ] Password hashing with SHA-256 (upgrade to bcrypt via WASM for production)

---

## 📱 iOS App Configuration

Update `APIClient.swift` in the iOS app:

```swift
struct APIConfig {
    #if DEBUG
    static let baseURL = "http://localhost:8787"
    #else
    static let baseURL = "https://api.babyincar.app"
    #endif
}
```

---

## 🆘 Troubleshooting

### "Secret not found"
```bash
wrangler secret list  # Check if secret exists
wrangler secret put SECRET_NAME  # Re-add if missing
```

### "D1 database not found"
```bash
wrangler d1 list  # Check database exists
# Verify database_id in wrangler.toml matches
```

### "KV namespace not found"
```bash
wrangler kv:namespace list  # Check namespace exists
# Verify id in wrangler.toml matches
```
