#!/bin/bash
# Cloudflare Infrastructure Setup Script for BabyInCar API
#
# PREREQUISITES:
# 1. Create a new API Token at https://dash.cloudflare.com/profile/api-tokens
#    with these permissions:
#    - Account > Workers Scripts > Edit
#    - Account > D1 > Edit
#    - Account > Workers KV Storage > Edit
#    - Account > R2 > Edit
#    - Account > Workers R2 Storage > Edit
#
# 2. Set the token: export CLOUDFLARE_API_TOKEN=your_new_token
#
# 3. Run this script: ./scripts/setup-cloudflare.sh

set -e

# Load .env if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check for required env vars
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN not set"
    echo ""
    echo "Create a new API Token at:"
    echo "https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    echo "Required permissions:"
    echo "  - Account > Workers Scripts > Edit"
    echo "  - Account > D1 > Edit"
    echo "  - Account > Workers KV Storage > Edit"
    echo "  - Account > R2 > Edit"
    echo ""
    echo "Then run: export CLOUDFLARE_API_TOKEN=your_token"
    exit 1
fi

echo "============================================"
echo "Setting up Cloudflare Infrastructure"
echo "============================================"
echo ""

# 1. Create D1 Database
echo "1. Creating D1 Database..."
D1_OUTPUT=$(npx wrangler d1 create babyincar-db 2>&1 || true)
echo "$D1_OUTPUT"

D1_ID=$(echo "$D1_OUTPUT" | grep -o 'database_id = "[^"]*"' | cut -d'"' -f2)
if [ -n "$D1_ID" ]; then
    echo "   D1 Database ID: $D1_ID"
fi
echo ""

# 2. Create KV Namespaces
echo "2. Creating KV Namespaces..."

echo "   Creating SESSIONS namespace..."
KV_SESSIONS=$(npx wrangler kv:namespace create sessions 2>&1 || true)
echo "$KV_SESSIONS"
SESSIONS_ID=$(echo "$KV_SESSIONS" | grep -o 'id = "[^"]*"' | cut -d'"' -f2)

echo "   Creating CACHE namespace..."
KV_CACHE=$(npx wrangler kv:namespace create cache 2>&1 || true)
echo "$KV_CACHE"
CACHE_ID=$(echo "$KV_CACHE" | grep -o 'id = "[^"]*"' | cut -d'"' -f2)
echo ""

# 3. Create R2 Buckets
echo "3. Creating R2 Buckets..."

echo "   Creating audio bucket..."
npx wrangler r2 bucket create babyincar-audio 2>&1 || true

echo "   Creating images bucket..."
npx wrangler r2 bucket create babyincar-images 2>&1 || true
echo ""

# 4. Print summary and wrangler.toml updates
echo "============================================"
echo "SETUP COMPLETE"
echo "============================================"
echo ""
echo "Update your wrangler.toml with these values:"
echo ""
echo "[[d1_databases]]"
echo "binding = \"DB\""
echo "database_name = \"babyincar-db\""
if [ -n "$D1_ID" ]; then
    echo "database_id = \"$D1_ID\""
fi
echo ""
echo "[[kv_namespaces]]"
echo "binding = \"SESSIONS\""
if [ -n "$SESSIONS_ID" ]; then
    echo "id = \"$SESSIONS_ID\""
fi
echo ""
echo "[[kv_namespaces]]"
echo "binding = \"CACHE\""
if [ -n "$CACHE_ID" ]; then
    echo "id = \"$CACHE_ID\""
fi
echo ""
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Update wrangler.toml with the IDs above"
echo "2. Run database migrations:"
echo "   npx wrangler d1 execute babyincar-db --local --file=migrations/001_initial.sql"
echo "3. Deploy the worker:"
echo "   npx wrangler deploy"
echo ""
echo "For R2 API access (for uploads from scripts):"
echo "1. Go to: Cloudflare Dashboard > R2 > Manage R2 API Tokens"
echo "2. Create a token with 'Object Read & Write' permission"
echo "3. Add to .env:"
echo "   R2_ACCESS_KEY_ID=your_access_key"
echo "   R2_SECRET_ACCESS_KEY=your_secret_key"
