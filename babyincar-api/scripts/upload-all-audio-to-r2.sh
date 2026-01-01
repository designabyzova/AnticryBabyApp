#!/bin/bash
# Upload ALL Audio Files to Cloudflare R2 and optionally delete after upload
#
# Usage:
#   cd babyincar-api
#   ./scripts/upload-all-audio-to-r2.sh [CATEGORY] [--delete]
#
# Examples:
#   ./scripts/upload-all-audio-to-r2.sh                    # Upload all, keep files
#   ./scripts/upload-all-audio-to-r2.sh ambient            # Upload ambient only
#   ./scripts/upload-all-audio-to-r2.sh ambient --delete   # Upload ambient, delete after

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$SCRIPT_DIR/../../BabyInCarApp/BabyInCarApp/Resources/Audio"
BUCKET_NAME="anticrybaby"

# Parse arguments
CATEGORY=""
DELETE_AFTER=false

for arg in "$@"; do
    if [[ "$arg" == "--delete" ]]; then
        DELETE_AFTER=true
    elif [[ -z "$CATEGORY" && "$arg" != "--"* ]]; then
        CATEGORY="$arg"
    fi
done

echo "==========================================="
echo "Upload Audio Files to R2: $BUCKET_NAME"
echo "==========================================="
echo "Category: ${CATEGORY:-ALL}"
echo "Delete after upload: $DELETE_AFTER"
echo ""

# Build find path
if [[ -n "$CATEGORY" ]]; then
    SEARCH_PATH="$AUDIO_DIR/$CATEGORY"
    if [[ ! -d "$SEARCH_PATH" ]]; then
        echo "Error: Category directory not found: $SEARCH_PATH"
        exit 1
    fi
else
    SEARCH_PATH="$AUDIO_DIR"
fi

# Count files
FILE_COUNT=$(find "$SEARCH_PATH" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.ogg" \) 2>/dev/null | wc -l | tr -d ' ')

echo "Found $FILE_COUNT audio files to upload"
echo ""

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "No files to upload."
    exit 0
fi

# Upload files
SUCCESS_COUNT=0
FAIL_COUNT=0
BYTES_UPLOADED=0

find "$SEARCH_PATH" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.ogg" \) 2>/dev/null | while read -r file; do
    # Get relative path from Audio directory
    REL_PATH="${file#$AUDIO_DIR/}"
    R2_KEY="audio/$REL_PATH"

    # Determine content type
    case "${file##*.}" in
        wav) CONTENT_TYPE="audio/wav" ;;
        mp3) CONTENT_TYPE="audio/mpeg" ;;
        m4a) CONTENT_TYPE="audio/mp4" ;;
        ogg) CONTENT_TYPE="audio/ogg" ;;
        *) CONTENT_TYPE="application/octet-stream" ;;
    esac

    # Get file size
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    SIZE_MB=$(echo "scale=1; $SIZE / 1048576" | bc)

    echo -n "[$((SUCCESS_COUNT + FAIL_COUNT + 1))/$FILE_COUNT] $REL_PATH (${SIZE_MB}MB)... "

    # Upload using wrangler
    if npx wrangler r2 object put "$BUCKET_NAME/$R2_KEY" --file="$file" --content-type="$CONTENT_TYPE" 2>/dev/null; then
        echo "OK"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        BYTES_UPLOADED=$((BYTES_UPLOADED + SIZE))

        # Delete if requested
        if [[ "$DELETE_AFTER" == true ]]; then
            rm -f "$file"
            echo "  (deleted local file)"
        fi
    else
        echo "FAILED"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "==========================================="
echo "Upload Complete"
echo "==========================================="
echo "Success: $SUCCESS_COUNT"
echo "Failed:  $FAIL_COUNT"
UPLOADED_MB=$(echo "scale=1; $BYTES_UPLOADED / 1048576" | bc)
echo "Uploaded: ${UPLOADED_MB}MB"
