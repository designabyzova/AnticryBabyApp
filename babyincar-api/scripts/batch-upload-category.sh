#!/bin/bash
# Batch upload a category to R2
# Usage: ./batch-upload-category.sh <category>

CATEGORY="$1"
if [ -z "$CATEGORY" ]; then
    echo "Usage: $0 <category>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$SCRIPT_DIR/../../BabyInCarApp/BabyInCarApp/Resources/Audio/$CATEGORY"
BUCKET_NAME="anticrybaby"

if [ ! -d "$AUDIO_DIR" ]; then
    echo "Error: Directory not found: $AUDIO_DIR"
    exit 1
fi

echo "=== Uploading $CATEGORY ==="
COUNT=0
TOTAL=$(find "$AUDIO_DIR" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.m4a" \) | wc -l | tr -d ' ')

find "$AUDIO_DIR" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.m4a" \) | sort | while read -r file; do
    COUNT=$((COUNT + 1))
    REL="${file#*Resources/Audio/}"
    EXT="${file##*.}"

    case "$EXT" in
        wav) CT="audio/wav" ;;
        mp3) CT="audio/mpeg" ;;
        m4a) CT="audio/mp4" ;;
        *) CT="application/octet-stream" ;;
    esac

    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
    SIZE_MB=$(echo "scale=1; $SIZE / 1048576" | bc)

    echo "[$COUNT/$TOTAL] $REL (${SIZE_MB}MB)"
    npx wrangler r2 object put "$BUCKET_NAME/audio/$REL" --file="$file" --content-type="$CT" 2>&1 | grep -v "wrangler" | head -1
done

echo "=== Done: $CATEGORY ==="
