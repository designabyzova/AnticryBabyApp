#!/bin/bash

# Script to regenerate tracks.json with actual bundled MP3 files
# This fixes the audio playback errors caused by referencing non-existent WAV files

AUDIO_DIR="BabyInCarApp/BabyInCarApp/Resources/Audio"
OUTPUT_FILE="$AUDIO_DIR/tracks.json"

echo "Regenerating tracks.json from actual MP3 files..."

# Create JSON header
cat > "$OUTPUT_FILE" << 'EOF'
{
  "version": "2.0",
  "generatedAt": "2026-01-02",
  "description": "Regenerated to match actual bundled MP3 files",
  "totalTracks": 0,
  "tracks": [
EOF

count=0
first=true

# Process each MP3 file
find "$AUDIO_DIR" -name "*.mp3" -type f | sort | while IFS= read -r filepath; do
    # Get relative path from Audio directory
    relpath="${filepath#$AUDIO_DIR/}"

    # Skip tracks.json itself
    [[ "$relpath" == "tracks.json" ]] && continue

    # Extract filename without path and extension
    filename=$(basename "$filepath" .mp3)

    # Determine category from directory
    category=$(echo "$relpath" | cut -d'/' -f1)

    # Map directory names to proper category names
    case "$category" in
        "lullabies")
            cat_display="Instrumental"
            subcategory="lullabies"
            artist="Lullaby Collection"
            calm_score="0.90"
            ;;
        "classical")
            cat_display="Classical Music"
            subcategory="classical"
            artist="Classical Collection"
            calm_score="0.88"
            ;;
        "nature")
            cat_display="Nature Sounds"
            subcategory="nature"
            artist="Nature Collection"
            calm_score="0.85"
            ;;
        "whitenoise")
            cat_display="White Noise"
            subcategory="whitenoise"
            artist="Baby in Car"
            calm_score="0.87"
            ;;
        "fairytales/en")
            cat_display="Fairy Tales"
            subcategory="english"
            artist="Grimm Brothers"
            calm_score="0.75"
            ;;
        "fairytales/ru")
            cat_display="Fairy Tales"
            subcategory="russian"
            artist="Russian Tales"
            calm_score="0.75"
            ;;
        "children")
            cat_display="Children's Songs"
            subcategory="children"
            artist="Children's Collection"
            calm_score="0.80"
            ;;
        "ambient")
            cat_display="Instrumental"
            subcategory="ambient"
            artist="Bensound"
            calm_score="0.82"
            ;;
        "acoustic")
            cat_display="Instrumental"
            subcategory="acoustic"
            artist="Acoustic Collection"
            calm_score="0.83"
            ;;
        *)
            cat_display="Instrumental"
            subcategory="general"
            artist="Baby in Car"
            calm_score="0.80"
            ;;
    esac

    # Clean up title from filename
    title=$(echo "$filename" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')

    # Generate UUID (simple hash-based approach for consistency)
    uuid=$(echo -n "$relpath" | md5 | cut -c1-8,9-12,13-16,17-20,21-32 | sed 's/\(....\)\(....\)\(....\)\(....\)\(.*\)/\1-\2-\3-\4-\5/')

    # Add comma before each entry except the first
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    # Write track entry
    cat >> "$OUTPUT_FILE" << TRACK_EOF
    {
      "id": "$uuid",
      "title": "$title",
      "artist": "$artist",
      "category": "$subcategory",
      "subcategory": "$subcategory",
      "filename": "$relpath",
      "duration": 180.0,
      "calmScore": $calm_score,
      "tags": ["$category"],
      "ageRangeMin": 0,
      "ageRangeMax": 36,
      "isPremium": false
    }
TRACK_EOF

    count=$((count + 1))
done

# Close JSON
cat >> "$OUTPUT_FILE" << 'EOF'
  ]
}
EOF

# Update total count
total=$(find "$AUDIO_DIR" -name "*.mp3" -type f | wc -l | tr -d ' ')
sed -i.bak "s/\"totalTracks\": 0/\"totalTracks\": $total/" "$OUTPUT_FILE"
rm "${OUTPUT_FILE}.bak" 2>/dev/null

echo "✅ Generated $total tracks in $OUTPUT_FILE"
echo "🎵 All tracks now reference actual MP3 files"
