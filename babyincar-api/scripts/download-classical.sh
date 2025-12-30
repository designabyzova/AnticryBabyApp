#!/bin/bash
# Download Free Classical Music for Baby in Car App
# All tracks are Public Domain or CC0 licensed
# Sources: Internet Archive, Musopen, Chosic

AUDIO_DIR="/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/classical"
mkdir -p "$AUDIO_DIR"

echo "=== Downloading Free Classical Music ==="
echo "All tracks are Public Domain or CC0 licensed"
echo ""

# Function to download with progress
download_track() {
    local url="$1"
    local output="$2"
    local name="$3"

    echo "Downloading: $name"
    if curl -L --progress-bar "$url" -o "$output" 2>&1; then
        size=$(ls -lh "$output" 2>/dev/null | awk '{print $5}')
        echo "  Saved: $(basename "$output") ($size)"
    else
        echo "  FAILED: $name"
    fi
    echo ""
}

# ============================================
# PIANO PIECES
# ============================================
echo "--- PIANO PIECES ---"
echo ""

# 1. Beethoven - Moonlight Sonata (1st Movement) - Musopen/Public Domain
download_track \
    "https://archive.org/download/MoonlightSonata_845/Moonlight%20Sonata.mp3" \
    "$AUDIO_DIR/moonlight_sonata.mp3" \
    "Beethoven - Moonlight Sonata (Paul Pitman/Musopen - Public Domain)"

# 2. Chopin - Nocturne Op.9 No.2 - Frank Levy (Public Domain)
download_track \
    "https://archive.org/download/nocturneineflatmajorop.9no.2/Nocturne%20in%20E%20flat%20major%2C%20Op.%209%20no.%202.mp3" \
    "$AUDIO_DIR/chopin_nocturne_op9_no2.mp3" \
    "Chopin - Nocturne Op.9 No.2 (Frank Levy - Public Domain)"

# 3. Debussy - Clair de Lune - Caela Harrison
download_track \
    "https://archive.org/download/ClairDeLunedebussy/Clair%20de%20Lune.mp3" \
    "$AUDIO_DIR/clair_de_lune.mp3" \
    "Debussy - Clair de Lune (Caela Harrison)"

# 4. Erik Satie - Gymnopedie No.1
download_track \
    "https://archive.org/download/ErikSatieGymnopdieNo.1/Erik%20Satie%20-%20Gymnopedie%20No.%201.mp3" \
    "$AUDIO_DIR/gymnopedie_no1.mp3" \
    "Erik Satie - Gymnopedie No.1"

# 5. Erik Satie - All Three Gymnopedies (S. Robert Powell)
download_track \
    "https://archive.org/download/SatiesThreeGymnopedies/Satie%27s%20three%20Gymnopedies.mp3" \
    "$AUDIO_DIR/satie_three_gymnopedies.mp3" \
    "Erik Satie - Three Gymnopedies (S. Robert Powell)"

# ============================================
# VIOLIN/ORCHESTRAL PIECES
# ============================================
echo "--- VIOLIN & ORCHESTRAL PIECES ---"
echo ""

# 6. Bach - Air on the G String
download_track \
    "https://archive.org/download/Bach-airOnTheGString/Bach%20-%20Air%20on%20the%20G%20String.mp3" \
    "$AUDIO_DIR/bach_air_on_g_string.mp3" \
    "Bach - Air on the G String"

# 7. Bach - Air on G String (Violin/Cello duet)
download_track \
    "https://archive.org/download/AirOnTheGStringviolincello/Air%20on%20the%20G%20String%20%28violin_cello%29.mp3" \
    "$AUDIO_DIR/bach_air_violin_cello.mp3" \
    "Bach - Air on G String (Violin/Cello)"

# ============================================
# ADDITIONAL CALMING CLASSICAL
# ============================================
echo "--- ADDITIONAL CLASSICAL PIECES ---"
echo ""

# 8. Pachelbel - Canon in D (from archive.org)
download_track \
    "https://archive.org/download/Canon_702/Canon.mp3" \
    "$AUDIO_DIR/pachelbel_canon.mp3" \
    "Pachelbel - Canon in D"

# 9. Brahms - Lullaby (Wiegenlied) - check multiple sources
download_track \
    "https://archive.org/download/BrahmsLullaby_201311/BrahmsLullaby.mp3" \
    "$AUDIO_DIR/brahms_lullaby.mp3" \
    "Brahms - Lullaby (Wiegenlied)"

# ============================================
# CALMING VIOLIN COLLECTION
# ============================================
echo "--- CALMING VIOLIN MUSIC ---"
echo ""

# 10. Beautiful Romantic Violin (from archive.org)
download_track \
    "https://archive.org/download/calmingrelaxingviolinmusic/Beautiful%20Romantic%20Violin%20Music.mp3" \
    "$AUDIO_DIR/romantic_violin.mp3" \
    "Beautiful Romantic Violin Music"

# ============================================
# SUMMARY
# ============================================
echo "=== Download Complete ==="
echo ""
echo "Files downloaded to: $AUDIO_DIR"
echo ""
echo "Checking downloaded files:"
echo ""

# List all downloaded files with sizes
for f in "$AUDIO_DIR"/*.mp3; do
    if [ -f "$f" ]; then
        size=$(ls -lh "$f" | awk '{print $5}')
        duration=$(ffprobe -i "$f" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null | cut -d'.' -f1)
        if [ -n "$duration" ]; then
            mins=$((duration / 60))
            secs=$((duration % 60))
            echo "  $(basename "$f"): $size (${mins}:${secs})"
        else
            echo "  $(basename "$f"): $size"
        fi
    fi
done

echo ""
echo "Total files:"
find "$AUDIO_DIR" -name "*.mp3" -type f | wc -l

echo ""
echo "Total size:"
du -sh "$AUDIO_DIR"

echo ""
echo "=== License Information ==="
echo "All tracks are Public Domain or Creative Commons licensed."
echo "Compositions by Beethoven, Chopin, Debussy, Satie, Bach, Pachelbel, Brahms"
echo "are Public Domain (composers died over 70 years ago)."
echo ""
echo "Performance recordings sourced from:"
echo "  - Internet Archive (archive.org)"
echo "  - Musopen (musopen.org) - Public Domain releases"
echo ""
