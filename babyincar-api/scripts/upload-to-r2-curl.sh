#!/bin/bash
# Upload Audio Files to Cloudflare R2 using curl with AWS Signature V4
# Usage: ./upload-to-r2-curl.sh [category]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
BUCKET="anticrybaby"
REGION="auto"
SERVICE="s3"
AUDIO_DIR="$SCRIPT_DIR/../../BabyInCarApp/BabyInCarApp/Resources/Audio"
CATEGORY="${1:-}"

echo "==========================================="
echo "Upload Audio Files to Cloudflare R2"
echo "==========================================="
echo ""

# Check credentials
if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
    echo "Error: R2 credentials not found in .env"
    echo "Required: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY"
    exit 1
fi

HOST="${BUCKET}.${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
ENDPOINT="https://${HOST}"

echo "Account: ${R2_ACCOUNT_ID:0:8}..."
echo "Bucket: $BUCKET"
echo "Audio dir: $AUDIO_DIR"
echo "Category: ${CATEGORY:-all}"
echo ""

# Function to create AWS Signature V4
sign_request() {
    local method="$1"
    local path="$2"
    local file="$3"
    local content_type="$4"

    local date_stamp=$(date -u +%Y%m%d)
    local amz_date=$(date -u +%Y%m%dT%H%M%SZ)

    # Hash the file content
    local payload_hash=$(openssl dgst -sha256 "$file" | awk '{print $2}')

    # Canonical headers
    local canonical_headers="content-type:${content_type}\nhost:${HOST}\nx-amz-content-sha256:${payload_hash}\nx-amz-date:${amz_date}"
    local signed_headers="content-type;host;x-amz-content-sha256;x-amz-date"

    # Canonical request
    local canonical_request="${method}\n${path}\n\n${canonical_headers}\n\n${signed_headers}\n${payload_hash}"
    local canonical_request_hash=$(echo -en "$canonical_request" | openssl dgst -sha256 | awk '{print $2}')

    # String to sign
    local algorithm="AWS4-HMAC-SHA256"
    local credential_scope="${date_stamp}/${REGION}/${SERVICE}/aws4_request"
    local string_to_sign="${algorithm}\n${amz_date}\n${credential_scope}\n${canonical_request_hash}"

    # Signing key
    local kDate=$(echo -n "$date_stamp" | openssl dgst -sha256 -hmac "AWS4${R2_SECRET_ACCESS_KEY}" -binary)
    local kRegion=$(echo -n "$REGION" | openssl dgst -sha256 -hmac "$kDate" -binary)
    local kService=$(echo -n "$SERVICE" | openssl dgst -sha256 -hmac "$kRegion" -binary)
    local kSigning=$(echo -n "aws4_request" | openssl dgst -sha256 -hmac "$kService" -binary)

    # Signature
    local signature=$(echo -en "$string_to_sign" | openssl dgst -sha256 -hmac "$kSigning" | awk '{print $2}')

    # Authorization header
    local auth_header="${algorithm} Credential=${R2_ACCESS_KEY_ID}/${credential_scope}, SignedHeaders=${signed_headers}, Signature=${signature}"

    # Return the curl command
    echo "-H 'Content-Type: ${content_type}' -H 'X-Amz-Content-Sha256: ${payload_hash}' -H 'X-Amz-Date: ${amz_date}' -H 'Authorization: ${auth_header}'"
}

# Function to get content type
get_content_type() {
    local file="$1"
    case "${file##*.}" in
        mp3) echo "audio/mpeg" ;;
        ogg) echo "audio/ogg" ;;
        wav) echo "audio/wav" ;;
        m4a) echo "audio/mp4" ;;
        flac) echo "audio/flac" ;;
        *) echo "application/octet-stream" ;;
    esac
}

# Find audio files
if [ -n "$CATEGORY" ]; then
    SEARCH_DIR="$AUDIO_DIR/$CATEGORY"
else
    SEARCH_DIR="$AUDIO_DIR"
fi

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory not found: $SEARCH_DIR"
    exit 1
fi

# Count files
FILE_COUNT=$(find "$SEARCH_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ')
echo "Found $FILE_COUNT audio files"
echo ""

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No audio files found."
    exit 0
fi

# Upload files
SUCCESS=0
FAILED=0
COUNT=0

find "$SEARCH_DIR" -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.m4a" \) | while read -r file; do
    COUNT=$((COUNT + 1))
    REL_PATH="${file#$AUDIO_DIR/}"
    R2_KEY="audio/${REL_PATH}"
    CONTENT_TYPE=$(get_content_type "$file")
    FILE_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "?")
    FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

    echo "[$COUNT/$FILE_COUNT] $REL_PATH (${FILE_SIZE_MB}MB)"

    # Create signature and upload
    DATE_STAMP=$(date -u +%Y%m%d)
    AMZ_DATE=$(date -u +%Y%m%dT%H%M%SZ)
    PAYLOAD_HASH=$(openssl dgst -sha256 "$file" 2>/dev/null | awk '{print $NF}')

    # Simplified upload using curl with basic auth approach
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
        -X PUT \
        -H "Content-Type: ${CONTENT_TYPE}" \
        --data-binary "@${file}" \
        --aws-sigv4 "aws:amz:auto:s3" \
        --user "${R2_ACCESS_KEY_ID}:${R2_SECRET_ACCESS_KEY}" \
        "${ENDPOINT}/${R2_KEY}" 2>&1)

    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "201" ]; then
        echo "  -> SUCCESS"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  -> FAILED (HTTP $RESPONSE)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "==========================================="
echo "Upload Complete"
echo "==========================================="
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"
