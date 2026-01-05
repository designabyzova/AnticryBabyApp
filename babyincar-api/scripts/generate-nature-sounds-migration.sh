#!/bin/bash
# Generate SQL migration for all nature sounds with accurate durations
# Fetches audio file info from R2 and generates INSERT statements

set -e

R2_BASE="https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio"
OUTPUT_FILE="../migrations/010_nature_sounds_complete.sql"

# Read nature files from upload log
NATURE_FILES=$(grep "^nature/" ../r2-upload.log.success)

echo "-- Migration: Complete Nature Sounds Library with Accurate Durations" > "$OUTPUT_FILE"
echo "-- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"
echo "-- Total nature files: $(echo "$NATURE_FILES" | wc -l | tr -d ' ')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "-- Delete old nature_sounds entries to avoid duplicates" >> "$OUTPUT_FILE"
echo "DELETE FROM tracks WHERE category = 'nature_sounds' AND id LIKE 'r2_nature_%';" >> "$OUTPUT_FILE"
echo "DELETE FROM tracks WHERE category = 'nature_sounds' AND id LIKE 'audio_%' AND stream_url IS NULL;" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "-- Insert nature sounds with accurate durations" >> "$OUTPUT_FILE"

count=0
while IFS= read -r file; do
    if [ -z "$file" ]; then continue; fi

    # Get file from path
    filename=$(basename "$file" .mp3)
    url="${R2_BASE}/${file}"

    # Get duration using ffprobe (download just enough to get metadata)
    duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$url" 2>/dev/null || echo "600")
    duration_int=$(printf "%.0f" "$duration" 2>/dev/null || echo "600")

    # Generate a clean title from filename
    title=$(echo "$filename" | sed 's/_/ /g' | sed 's/^ia [a-f0-9]* //i' | sed 's/^ne //i' | sed 's/^sb //i' | sed 's/^pb //i' | sed 's/  */ /g')
    # Capitalize first letter of each word
    title=$(echo "$title" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

    # Generate ID from filename
    id="r2_nature_$(echo "$filename" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g' | head -c 50)"

    # Determine calming score based on content
    calming_score="0.85"
    if echo "$filename" | grep -qi "rain\|ocean\|wave\|stream\|water"; then
        calming_score="0.90"
    elif echo "$filename" | grep -qi "thunder\|storm"; then
        calming_score="0.75"
    elif echo "$filename" | grep -qi "bird\|forest"; then
        calming_score="0.82"
    elif echo "$filename" | grep -qi "wind"; then
        calming_score="0.86"
    fi

    count=$((count + 1))
    echo "Processing [$count]: $filename (${duration_int}s)" >&2

    cat >> "$OUTPUT_FILE" << EOF
INSERT OR REPLACE INTO tracks (id, title, artist, category, language, duration, age_range_min, age_range_max, tempo_bpm, calming_score, audio_source_type, generator_type, stream_url, is_premium)
VALUES ('$id', '$title', 'Nature Sounds', 'nature_sounds', 'instrumental', $duration_int, 0, 36, NULL, $calming_score, 'recorded', NULL, '$url', 0);

EOF

done <<< "$NATURE_FILES"

echo "" >> "$OUTPUT_FILE"
echo "-- Summary: Inserted $count nature sound tracks" >> "$OUTPUT_FILE"

echo ""
echo "Generated migration with $count tracks: $OUTPUT_FILE"
