#!/bin/bash
# Simple bulk downloader for baby music - NO API KEYS NEEDED
# Uses wget/curl to download from free sources

set -e

OUTPUT_DIR="../audio-library/downloaded"
mkdir -p "$OUTPUT_DIR"/{classical,lullabies,nature,ambient}

echo "=========================================="
echo "Baby Music Bulk Downloader (No API Keys)"
echo "=========================================="
echo ""

# Function to download with retry
download_track() {
    local url="$1"
    local output="$2"
    local title="$3"

    if [ -f "$output" ] && [ $(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null) -gt 10000 ]; then
        echo "[SKIP] $title (already exists)"
        return 0
    fi

    echo "[DOWNLOADING] $title"
    if command -v wget &> /dev/null; then
        wget -q --timeout=60 --tries=3 -O "$output" "$url" 2>&1
    elif command -v curl &> /dev/null; then
        curl -s --max-time 60 --retry 3 -o "$output" -L "$url" 2>&1
    else
        echo "[ERROR] Neither wget nor curl found!"
        return 1
    fi

    # Verify file size
    if [ ! -f "$output" ] || [ $(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null) -lt 10000 ]; then
        echo "[FAIL] $title (file too small or invalid)"
        rm -f "$output"
        return 1
    fi

    local size=$(du -h "$output" | cut -f1)
    echo "[OK] $title ($size)"
    return 0
}

# Counter
SUCCESS=0
FAILED=0
SKIPPED=0

echo "=== CHOSIC.COM - Public Domain Classical ==="
echo ""

# Classical Piano from Chosic
download_track "https://www.chosic.com/wp-content/uploads/2021/04/Gymnopedie-No-1-Erik-Satie.mp3" \
    "$OUTPUT_DIR/classical/satie_gymnopedie_1.mp3" "Gymnopedie No.1 - Satie" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/07/Clair-de-Lune-Debussy.mp3" \
    "$OUTPUT_DIR/classical/debussy_clair_de_lune.mp3" "Clair de Lune - Debussy" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/04/Nocturne-Op-9-No-2-Chopin.mp3" \
    "$OUTPUT_DIR/classical/chopin_nocturne.mp3" "Nocturne Op.9 No.2 - Chopin" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/07/Moonlight-Sonata-1st-Movement-Beethoven.mp3" \
    "$OUTPUT_DIR/classical/beethoven_moonlight.mp3" "Moonlight Sonata - Beethoven" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/04/Reverie-Debussy.mp3" \
    "$OUTPUT_DIR/classical/debussy_reverie.mp3" "Reverie - Debussy" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/05/Canon-in-D-Pachelbel.mp3" \
    "$OUTPUT_DIR/classical/pachelbel_canon_d.mp3" "Canon in D - Pachelbel" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/07/Air-on-G-String-Bach.mp3" \
    "$OUTPUT_DIR/classical/bach_air_g.mp3" "Air on G String - Bach" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/07/Fur-Elise-Beethoven.mp3" \
    "$OUTPUT_DIR/classical/beethoven_fur_elise.mp3" "Fur Elise - Beethoven" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/04/Liebestraum-No-3-Liszt.mp3" \
    "$OUTPUT_DIR/classical/liszt_liebestraum.mp3" "Liebestraum No.3 - Liszt" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/04/Traumerei-Schumann.mp3" \
    "$OUTPUT_DIR/classical/schumann_traumerei.mp3" "Traumerei - Schumann" && ((SUCCESS++)) || ((FAILED++))

echo ""
echo "=== CHOSIC.COM - Lullabies ==="
echo ""

download_track "https://www.chosic.com/wp-content/uploads/2021/07/Brahms-Lullaby.mp3" \
    "$OUTPUT_DIR/lullabies/brahms_lullaby.mp3" "Brahms Lullaby" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/04/Twinkle-Twinkle-Little-Star.mp3" \
    "$OUTPUT_DIR/lullabies/twinkle_star.mp3" "Twinkle Twinkle Little Star" && ((SUCCESS++)) || ((FAILED++))

download_track "https://www.chosic.com/wp-content/uploads/2021/05/Rock-a-bye-Baby.mp3" \
    "$OUTPUT_DIR/lullabies/rock_a_bye.mp3" "Rock-a-bye Baby" && ((SUCCESS++)) || ((FAILED++))

echo ""
echo "=== MIXKIT.CO - Royalty-Free Music ==="
echo ""

download_track "https://assets.mixkit.co/music/download/mixkit-sleepy-cat-135.mp3" \
    "$OUTPUT_DIR/lullabies/mixkit_sleepy_cat.mp3" "Sleepy Cat - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-serene-view-443.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_serene_view.mp3" "Serene View - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-piano-reflections-22.mp3" \
    "$OUTPUT_DIR/classical/mixkit_piano_reflections.mp3" "Piano Reflections - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-dreaming-big-31.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_dreaming_big.mp3" "Dreaming Big - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-life-is-a-dream-837.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_life_dream.mp3" "Life is a Dream - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-deep-meditation-109.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_deep_meditation.mp3" "Deep Meditation - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-beautiful-dream-493.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_beautiful_dream.mp3" "Beautiful Dream - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-silent-snow-121.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_silent_snow.mp3" "Silent Snow - Mixkit" && ((SUCCESS++)) || ((FAILED++))

download_track "https://assets.mixkit.co/music/download/mixkit-starlight-25.mp3" \
    "$OUTPUT_DIR/ambient/mixkit_starlight.mp3" "Starlight - Mixkit" && ((SUCCESS++)) || ((FAILED++))

echo ""
echo "=== INCOMPETECH.COM - Kevin MacLeod (CC-BY) ==="
echo ""

download_track "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Gymnopedie%20No%201.mp3" \
    "$OUTPUT_DIR/classical/incompetech_gymnopedie.mp3" "Gymnopedie No 1 - Kevin MacLeod" && ((SUCCESS++)) || ((FAILED++))

download_track "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Amazing%20Plan.mp3" \
    "$OUTPUT_DIR/ambient/incompetech_amazing_plan.mp3" "Amazing Plan - Kevin MacLeod" && ((SUCCESS++)) || ((FAILED++))

download_track "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Dreaming.mp3" \
    "$OUTPUT_DIR/ambient/incompetech_dreaming.mp3" "Dreaming - Kevin MacLeod" && ((SUCCESS++)) || ((FAILED++))

echo ""
echo "=========================================="
echo "DOWNLOAD COMPLETE"
echo "=========================================="
echo "✅ Success: $SUCCESS"
echo "❌ Failed: $FAILED"
echo "⏭️  Skipped: $SKIPPED"
echo "📁 Output: $OUTPUT_DIR"
echo "=========================================="
echo ""
echo "💡 Next steps:"
echo "1. Run: python3 no-api-scraper.py (for Archive.org + more)"
echo "2. Browse Pixabay Music manually and add more URLs"
echo "3. Upload to R2: wrangler r2 object put anticrybaby/audio/..."
