#!/bin/bash
# Batch upload all audio files to Cloudflare R2
# Uses curl with AWS Signature V4

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load environment
source .env

BUCKET="anticrybaby"
AUDIO_DIR="$SCRIPT_DIR/../../BabyInCarApp/BabyInCarApp/Resources/Audio"
LOG_FILE="$SCRIPT_DIR/../r2-upload.log"
METADATA_FILE="$SCRIPT_DIR/../r2-uploaded-files.json"

echo "==========================================="
echo "Batch Upload All Audio to R2"
echo "==========================================="
echo ""
echo "Bucket: $BUCKET"
echo "Audio directory: $AUDIO_DIR"
echo ""

# Initialize JSON array
echo "[]" > "$METADATA_FILE.tmp"

upload_file() {
    local file="$1"
    local rel_path="${file#$AUDIO_DIR/}"
    local r2_key="audio/${rel_path}"
    local content_type="audio/mpeg"

    case "${file##*.}" in
        mp3) content_type="audio/mpeg" ;;
        ogg) content_type="audio/ogg" ;;
        wav) content_type="audio/wav" ;;
        m4a) content_type="audio/mp4" ;;
        *) content_type="application/octet-stream" ;;
    esac

    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))

    local url="https://${BUCKET}.${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${r2_key}"

    local response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X PUT \
        -H "Content-Type: ${content_type}" \
        --data-binary "@${file}" \
        --aws-sigv4 "aws:amz:auto:s3" \
        --user "${R2_ACCESS_KEY_ID}:${R2_SECRET_ACCESS_KEY}" \
        "$url" 2>&1)

    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        echo "SUCCESS $rel_path (${file_size_mb}MB)"
        echo "$rel_path" >> "$LOG_FILE.success"
        return 0
    else
        echo "FAILED  $rel_path (HTTP $response)"
        echo "$rel_path" >> "$LOG_FILE.failed"
        return 1
    fi
}

export -f upload_file
export BUCKET R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY AUDIO_DIR LOG_FILE

# Clear log files
> "$LOG_FILE.success"
> "$LOG_FILE.failed"

# Count files
TOTAL=$(find "$AUDIO_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ')
echo "Found $TOTAL audio files to upload"
echo ""

# Calculate total size
TOTAL_SIZE=$(find "$AUDIO_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" \) -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s}')
TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
echo "Total size: ${TOTAL_SIZE_MB}MB"
echo ""

# Upload files one by one (could use parallel but keeping simple)
COUNT=0
SUCCESS=0
FAILED=0

find "$AUDIO_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    echo -n "[$COUNT/$TOTAL] "

    if upload_file "$file"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "==========================================="
echo "Upload Complete"
echo "==========================================="

SUCCESS_COUNT=$(wc -l < "$LOG_FILE.success" 2>/dev/null | tr -d ' ')
FAILED_COUNT=$(wc -l < "$LOG_FILE.failed" 2>/dev/null | tr -d ' ')

echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAILED_COUNT"
echo ""
echo "Success log: $LOG_FILE.success"
echo "Failed log: $LOG_FILE.failed"
