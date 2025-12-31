#!/bin/bash
# Upload Audio Files to Cloudflare R2 using Wrangler CLI
#
# This script uploads audio files from the iOS app's Resources directory
# to Cloudflare R2 storage using the wrangler CLI.
#
# Prerequisites:
#   - wrangler installed: npm install -g wrangler
#   - Logged in to Cloudflare: wrangler login
#   - R2 bucket created: wrangler r2 bucket create babyincar-audio
#
# Usage:
#   cd babyincar-api
#   ./scripts/upload-audio-wrangler.sh [--all]
#
# Options:
#   --all    Upload all audio files (default: only files > 50MB)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$SCRIPT_DIR/../../BabyInCarApp/BabyInCarApp/Resources/Audio"
BUCKET_NAME="babyincar-audio"
MIN_SIZE_MB=50  # Minimum file size in MB to upload (default)

# Check for --all flag
UPLOAD_ALL=false
if [[ "$1" == "--all" ]]; then
    UPLOAD_ALL=true
    MIN_SIZE_MB=0
fi

echo "==========================================="
echo "Upload Audio Files to Cloudflare R2"
echo "==========================================="
echo ""
echo "Audio directory: $AUDIO_DIR"
echo "Bucket: $BUCKET_NAME"
echo "Mode: $([ "$UPLOAD_ALL" = true ] && echo "All files" || echo "Files > ${MIN_SIZE_MB}MB only")"
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "Error: wrangler CLI not found."
    echo "Install with: npm install -g wrangler"
    exit 1
fi

# Check if logged in
if ! wrangler whoami &> /dev/null; then
    echo "Error: Not logged in to Cloudflare."
    echo "Run: wrangler login"
    exit 1
fi

# Check if directory exists
if [ ! -d "$AUDIO_DIR" ]; then
    echo "Error: Audio directory not found: $AUDIO_DIR"
    exit 1
fi

# Find audio files
echo "Scanning for audio files..."
MIN_SIZE_BYTES=$((MIN_SIZE_MB * 1024 * 1024))

# Create temporary file list
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Find audio files larger than minimum size
find "$AUDIO_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" -o -name "*.flac" \) -size +${MIN_SIZE_BYTES}c > "$TEMP_FILE"

FILE_COUNT=$(wc -l < "$TEMP_FILE" | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No files found to upload."
    exit 0
fi

echo "Found $FILE_COUNT files to upload."
echo ""

# Calculate total size
TOTAL_SIZE=0
while IFS= read -r file; do
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
done < "$TEMP_FILE"

TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
echo "Total size: ${TOTAL_SIZE_MB} MB"
echo ""

# Ask for confirmation
read -p "Proceed with upload? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting upload..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
UPLOADED_FILES=""

while IFS= read -r file; do
    # Get relative path from Audio directory
    REL_PATH="${file#$AUDIO_DIR/}"
    R2_KEY="audio/$REL_PATH"

    # Get file size for display
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    SIZE_MB=$((SIZE / 1024 / 1024))

    echo "Uploading: $REL_PATH (${SIZE_MB} MB)"

    # Upload using wrangler
    if wrangler r2 object put "$BUCKET_NAME/$R2_KEY" --file="$file" --content-type="$(file --mime-type -b "$file")" 2>/dev/null; then
        echo "  SUCCESS"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        UPLOADED_FILES="$UPLOADED_FILES$file\n"
    else
        echo "  FAILED"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done < "$TEMP_FILE"

echo ""
echo "==========================================="
echo "Upload Complete"
echo "==========================================="
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "Next steps to remove large files from git:"
    echo ""
    echo "1. Add to .gitignore (files > 50MB):"
    echo '   echo "# Large audio files (stored in R2)" >> BabyInCarApp/.gitignore'
    echo '   echo "BabyInCarApp/Resources/Audio/**/*.mp3" >> BabyInCarApp/.gitignore'
    echo ""
    echo "2. Remove from git index (keeps local files):"
    echo "   git rm --cached -r BabyInCarApp/BabyInCarApp/Resources/Audio/podcasts/"
    echo ""
    echo "3. Commit the changes:"
    echo '   git commit -m "Move large audio files to R2 storage"'
fi
