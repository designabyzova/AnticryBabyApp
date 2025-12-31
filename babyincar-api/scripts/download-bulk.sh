#!/bin/bash
# Bulk download audio from verified working sources
# All files are royalty-free or public domain

AUDIO_DIR="/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
mkdir -p "$AUDIO_DIR"/{classical,lullabies,nature,ambient,whitenoise,children}

echo "============================================"
echo "BULK AUDIO DOWNLOADER"
echo "============================================"

download() {
    local url="$1"
    local output="$2"
    local name="$3"

    if [ -f "$output" ] && [ $(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null) -gt 10000 ]; then
        echo "[SKIP] $name"
        return 0
    fi

    echo "[DL] $name"
    if curl -L -s --max-time 120 \
        -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        -H "Accept: */*" \
        "$url" -o "$output" 2>/dev/null; then

        size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
        if [ "$size" -gt 10000 ]; then
            echo "     OK ($(echo "scale=1; $size/1024" | bc) KB)"
            return 0
        else
            rm -f "$output"
            echo "     FAIL (too small)"
            return 1
        fi
    else
        echo "     FAIL"
        return 1
    fi
}

echo ""
echo "=== BENSOUND (Royalty-Free) ==="

# Bensound tracks - verified working
download "https://www.bensound.com/bensound-music/bensound-relaxing.mp3" \
    "$AUDIO_DIR/ambient/bensound_relaxing.mp3" "Relaxing"

download "https://www.bensound.com/bensound-music/bensound-slowmotion.mp3" \
    "$AUDIO_DIR/ambient/bensound_slowmotion.mp3" "Slow Motion"

download "https://www.bensound.com/bensound-music/bensound-memories.mp3" \
    "$AUDIO_DIR/ambient/bensound_memories.mp3" "Memories"

download "https://www.bensound.com/bensound-music/bensound-tenderness.mp3" \
    "$AUDIO_DIR/ambient/bensound_tenderness.mp3" "Tenderness"

download "https://www.bensound.com/bensound-music/bensound-allthat.mp3" \
    "$AUDIO_DIR/ambient/bensound_allthat.mp3" "All That"

download "https://www.bensound.com/bensound-music/bensound-dreams.mp3" \
    "$AUDIO_DIR/ambient/bensound_dreams.mp3" "Dreams"

download "https://www.bensound.com/bensound-music/bensound-sadday.mp3" \
    "$AUDIO_DIR/ambient/bensound_sadday.mp3" "Sad Day"

download "https://www.bensound.com/bensound-music/bensound-love.mp3" \
    "$AUDIO_DIR/ambient/bensound_love.mp3" "Love"

download "https://www.bensound.com/bensound-music/bensound-tomorrow.mp3" \
    "$AUDIO_DIR/ambient/bensound_tomorrow.mp3" "Tomorrow"

download "https://www.bensound.com/bensound-music/bensound-onceagain.mp3" \
    "$AUDIO_DIR/ambient/bensound_onceagain.mp3" "Once Again"

download "https://www.bensound.com/bensound-music/bensound-betterdays.mp3" \
    "$AUDIO_DIR/ambient/bensound_betterdays.mp3" "Better Days"

download "https://www.bensound.com/bensound-music/bensound-pianomoment.mp3" \
    "$AUDIO_DIR/classical/bensound_pianomoment.mp3" "Piano Moment"

download "https://www.bensound.com/bensound-music/bensound-littleidea.mp3" \
    "$AUDIO_DIR/children/bensound_littleidea.mp3" "Little Idea"

download "https://www.bensound.com/bensound-music/bensound-cute.mp3" \
    "$AUDIO_DIR/children/bensound_cute.mp3" "Cute"

download "https://www.bensound.com/bensound-music/bensound-jazzyfrenchy.mp3" \
    "$AUDIO_DIR/ambient/bensound_jazzyfrenchy.mp3" "Jazzy Frenchy"

download "https://www.bensound.com/bensound-music/bensound-sunny.mp3" \
    "$AUDIO_DIR/children/bensound_sunny.mp3" "Sunny"

download "https://www.bensound.com/bensound-music/bensound-happyrock.mp3" \
    "$AUDIO_DIR/children/bensound_happyrock.mp3" "Happy Rock"

download "https://www.bensound.com/bensound-music/bensound-clearday.mp3" \
    "$AUDIO_DIR/ambient/bensound_clearday.mp3" "Clear Day"

download "https://www.bensound.com/bensound-music/bensound-acoustic.mp3" \
    "$AUDIO_DIR/ambient/bensound_acoustic.mp3" "Acoustic Breeze"

download "https://www.bensound.com/bensound-music/bensound-sweet.mp3" \
    "$AUDIO_DIR/ambient/bensound_sweet.mp3" "Sweet"

echo ""
echo "=== SOUNDBIBLE (Public Domain) ==="

# SoundBible - public domain sounds
download "http://soundbible.com/mp3/Ocean_Waves-Mike_Koenig-980635527.mp3" \
    "$AUDIO_DIR/nature/sb_ocean_waves.mp3" "Ocean Waves"

download "http://soundbible.com/mp3/Wind-Mark_DiAngelo-1940285615.mp3" \
    "$AUDIO_DIR/nature/sb_wind.mp3" "Wind"

download "http://soundbible.com/grab.php?id=2189&type=mp3" \
    "$AUDIO_DIR/nature/sb_rain2.mp3" "Rain 2"

download "http://soundbible.com/grab.php?id=1818&type=mp3" \
    "$AUDIO_DIR/nature/sb_thunderstorm.mp3" "Thunderstorm"

download "http://soundbible.com/grab.php?id=1645&type=mp3" \
    "$AUDIO_DIR/nature/sb_birds2.mp3" "Birds"

download "http://soundbible.com/grab.php?id=1195&type=mp3" \
    "$AUDIO_DIR/nature/sb_stream.mp3" "Stream"

echo ""
echo "=== ZAPSPLAT ALTERNATIVE (CC0) ==="

# Try Freesound previews (no auth needed for previews)
# These are short samples but usable

echo ""
echo "============================================"
echo "DOWNLOAD SUMMARY"
echo "============================================"

mp3_count=$(find "$AUDIO_DIR" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
wav_count=$(find "$AUDIO_DIR" -name "*.wav" -type f 2>/dev/null | wc -l | tr -d ' ')
total=$((mp3_count + wav_count))

echo ""
echo "MP3 files: $mp3_count"
echo "WAV files: $wav_count"
echo "Total: $total"
echo ""

# List by category
echo "By category:"
for cat in classical lullabies nature ambient whitenoise children; do
    count=$(find "$AUDIO_DIR/$cat" -type f \( -name "*.mp3" -o -name "*.wav" \) 2>/dev/null | wc -l | tr -d ' ')
    echo "  $cat: $count"
done

echo ""
du -sh "$AUDIO_DIR"
