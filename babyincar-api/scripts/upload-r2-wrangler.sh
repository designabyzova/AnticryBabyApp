#!/bin/bash
#
# Upload Podcasts to Cloudflare R2 using Wrangler
#
# This script uploads all podcast files to R2 using wrangler r2 object put
# Requires: wrangler login with R2 permissions
#
# Usage: ./upload-r2-wrangler.sh
#

set -e

# Configuration
PODCAST_DIR="/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts"
BUCKET_NAME="anticrybaby"

# Use Node 20 for wrangler
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20 > /dev/null 2>&1

# Unset the API token to use OAuth instead
unset CLOUDFLARE_API_TOKEN

echo "============================================"
echo "R2 Upload via Wrangler"
echo "============================================"
echo "Bucket: $BUCKET_NAME"
echo "Source: $PODCAST_DIR"
echo ""

# First, let's check if we can access R2
echo "Checking R2 access..."
if ! wrangler r2 bucket list 2>/dev/null | grep -q "$BUCKET_NAME"; then
    echo "ERROR: Cannot access R2 bucket '$BUCKET_NAME'"
    echo ""
    echo "Please do one of the following:"
    echo ""
    echo "1. Login with OAuth (recommended):"
    echo "   wrangler login"
    echo ""
    echo "2. Create an R2 API token at:"
    echo "   https://dash.cloudflare.com/?account=1364b528762500de4f870e064229d443/r2/api-tokens"
    echo "   Then add to .env:"
    echo "   R2_ACCESS_KEY_ID=your_key"
    echo "   R2_SECRET_ACCESS_KEY=your_secret"
    echo ""
    exit 1
fi

echo "R2 bucket found!"
echo ""

# Count files
TOTAL_FILES=$(find "$PODCAST_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" \) | wc -l | tr -d ' ')
echo "Found $TOTAL_FILES files to upload"
echo ""

# Upload files
SUCCESS=0
FAIL=0
SKIP=0

# Process each language directory
for LANG_DIR in "$PODCAST_DIR"/*; do
    if [ -d "$LANG_DIR" ]; then
        LANG=$(basename "$LANG_DIR")

        # Process each category directory
        for CAT_DIR in "$LANG_DIR"/*; do
            if [ -d "$CAT_DIR" ]; then
                CAT=$(basename "$CAT_DIR")

                echo "Processing: $LANG/$CAT"

                # Upload each file
                for FILE in "$CAT_DIR"/*; do
                    if [ -f "$FILE" ]; then
                        FILENAME=$(basename "$FILE")
                        R2_KEY="podcasts/$LANG/$CAT/$FILENAME"

                        echo -n "  [$((SUCCESS + FAIL + SKIP + 1))/$TOTAL_FILES] $FILENAME... "

                        # Check if file exists in R2 (skip if already uploaded)
                        if wrangler r2 object get "$BUCKET_NAME" "$R2_KEY" --local 2>/dev/null | grep -q "Success"; then
                            echo "SKIP (exists)"
                            SKIP=$((SKIP + 1))
                            continue
                        fi

                        # Upload file
                        if wrangler r2 object put "$BUCKET_NAME" "$R2_KEY" --file "$FILE" 2>/dev/null; then
                            echo "OK"
                            SUCCESS=$((SUCCESS + 1))
                        else
                            echo "FAILED"
                            FAIL=$((FAIL + 1))
                        fi

                        # Rate limit to avoid overwhelming the API
                        sleep 0.5
                    fi
                done
            fi
        done
    fi
done

echo ""
echo "============================================"
echo "UPLOAD COMPLETE"
echo "============================================"
echo "Uploaded: $SUCCESS"
echo "Skipped: $SKIP"
echo "Failed: $FAIL"
echo ""
echo "Public URL format:"
echo "https://pub-1364b528762500de4f870e064229d443.r2.dev/podcasts/[lang]/[category]/[filename]"
