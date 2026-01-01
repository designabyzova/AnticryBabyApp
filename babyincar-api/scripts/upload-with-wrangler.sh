#!/bin/bash
# Upload collected audio files to R2 using wrangler
# This uses your existing Cloudflare authentication

BUCKET_NAME="babyincar-audio"
DOWNLOADS_DIR="$(dirname "$0")/../audio-library/downloads"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   Upload Audio Files to Cloudflare R2                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Check if wrangler is available
if ! command -v wrangler &> /dev/null; then
    echo "Error: wrangler not found. Install with: npm install -g wrangler"
    exit 1
fi

# Check if logged in
echo "Checking Cloudflare authentication..."
if ! wrangler whoami &> /dev/null; then
    echo "Not logged in. Running: wrangler login"
    wrangler login
fi

# Count files
FILE_COUNT=$(ls -1 "$DOWNLOADS_DIR"/*.mp3 2>/dev/null | wc -l | tr -d ' ')
echo "Found $FILE_COUNT MP3 files to upload"
echo ""

# Upload each file
UPLOADED=0
FAILED=0

for file in "$DOWNLOADS_DIR"/*.mp3; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Determine category from filename
        if [[ $filename == *"classical"* ]]; then
            category="classical_music"
        elif [[ $filename == *"nature"* ]]; then
            category="nature_sounds"
        elif [[ $filename == *"lullabies"* ]]; then
            category="lullabies"
        elif [[ $filename == *"instrumental"* ]]; then
            category="instrumental"
        elif [[ $filename == *"ambient"* ]]; then
            category="ambient"
        elif [[ $filename == *"white_noise"* ]]; then
            category="white_noise"
        elif [[ $filename == *"children"* ]]; then
            category="children_songs"
        else
            category="other"
        fi

        key="audio/${category}/${filename}"

        echo -n "[$((UPLOADED + FAILED + 1))/$FILE_COUNT] $filename... "

        if wrangler r2 object put "${BUCKET_NAME}/${key}" --file="$file" --content-type="audio/mpeg" 2>/dev/null; then
            echo "✓"
            ((UPLOADED++))
        else
            echo "✗"
            ((FAILED++))
        fi
    fi
done

echo ""
echo "=== Upload Complete ==="
echo "Success: $UPLOADED"
echo "Failed: $FAILED"
echo ""
echo "Files accessible at: https://audio.babyincar.app/audio/[category]/[filename]"
