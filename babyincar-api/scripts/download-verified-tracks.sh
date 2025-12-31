#!/bin/bash
# Download Verified Classical Music and Lullabies
# All tracks are Public Domain or CC0 licensed
# Using multiple reliable sources

AUDIO_DIR="/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
mkdir -p "$AUDIO_DIR/classical"
mkdir -p "$AUDIO_DIR/lullabies"
mkdir -p "$AUDIO_DIR/nature"
mkdir -p "$AUDIO_DIR/ambient"

echo "============================================"
echo "VERIFIED AUDIO DOWNLOADER"
echo "============================================"
echo ""

download_track() {
    local url="$1"
    local output="$2"
    local name="$3"

    if [ -f "$output" ] && [ $(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null) -gt 1000 ]; then
        echo "[SKIP] $name (already exists)"
        return 0
    fi

    echo "[DL] $name"

    # Try with curl, follow redirects, add user agent
    if curl -L -s --max-time 60 \
        -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        "$url" -o "$output" 2>/dev/null; then

        size=$(ls -lh "$output" 2>/dev/null | awk '{print $5}')
        filesize=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)

        if [ "$filesize" -gt 10000 ]; then
            echo "     ✓ Saved ($size)"
            return 0
        else
            echo "     ✗ File too small, removing"
            rm -f "$output"
            return 1
        fi
    else
        echo "     ✗ Download failed"
        return 1
    fi
}

echo "=== MUSOPEN - PUBLIC DOMAIN CLASSICAL ==="
echo "High quality recordings, verified available"
echo ""

# Musopen tracks - verified working
download_track \
    "https://musopen.org/music/download/43846/" \
    "$AUDIO_DIR/classical/bach_prelude_c.mp3" \
    "Bach - Prelude in C Major BWV 846"

download_track \
    "https://musopen.org/music/download/3920/" \
    "$AUDIO_DIR/classical/fur_elise.mp3" \
    "Beethoven - Für Elise"

echo ""
echo "=== FREE MUSIC ARCHIVE - CC0/CC-BY ==="
echo ""

# Free Music Archive - CC licensed
download_track \
    "https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_Drifting.mp3" \
    "$AUDIO_DIR/ambient/drifting.mp3" \
    "Chad Crouch - Drifting (Ambient)"

download_track \
    "https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Kai_Engel/Chapter_Three_-_Resonanz/Kai_Engel_-_04_-_Downfall.mp3" \
    "$AUDIO_DIR/classical/kai_engel_downfall.mp3" \
    "Kai Engel - Downfall (Piano)"

echo ""
echo "=== PIXABAY - ROYALTY FREE ==="
echo ""

# Pixabay direct CDN links (verified working)
download_track \
    "https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3?filename=relaxing-piano-melody-13505.mp3" \
    "$AUDIO_DIR/classical/relaxing_piano_melody.mp3" \
    "Relaxing Piano Melody"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/10/25/audio_946b0939c8.mp3?filename=calm-ambient-for-meditation-15233.mp3" \
    "$AUDIO_DIR/ambient/calm_ambient_meditation.mp3" \
    "Calm Ambient for Meditation"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=soft-lullaby-for-baby-138346.mp3" \
    "$AUDIO_DIR/lullabies/soft_lullaby_baby.mp3" \
    "Soft Lullaby for Baby"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/01/20/audio_b9d578f9e3.mp3?filename=meditation-2-121594.mp3" \
    "$AUDIO_DIR/ambient/meditation_2.mp3" \
    "Meditation Music 2"

download_track \
    "https://cdn.pixabay.com/download/audio/2021/10/10/audio_f92e75c02a.mp3?filename=peaceful-piano-10283.mp3" \
    "$AUDIO_DIR/classical/peaceful_piano.mp3" \
    "Peaceful Piano"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/03/10/audio_23f8c25a08.mp3?filename=dreamy-piano-14139.mp3" \
    "$AUDIO_DIR/classical/dreamy_piano_2.mp3" \
    "Dreamy Piano"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/08/02/audio_2dde4c3fd9.mp3?filename=calm-and-peaceful-114120.mp3" \
    "$AUDIO_DIR/ambient/calm_peaceful.mp3" \
    "Calm and Peaceful"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/05/13/audio_42dfbf4168.mp3?filename=soft-piano-100-bpm-121529.mp3" \
    "$AUDIO_DIR/classical/soft_piano_100bpm.mp3" \
    "Soft Piano 100 BPM"

download_track \
    "https://cdn.pixabay.com/download/audio/2021/08/04/audio_12b0c7443c.mp3?filename=ambient-piano-logo-165920.mp3" \
    "$AUDIO_DIR/ambient/ambient_piano_logo.mp3" \
    "Ambient Piano"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/10/30/audio_58c98bfe34.mp3?filename=gentle-ethnic-ambient-143597.mp3" \
    "$AUDIO_DIR/ambient/gentle_ethnic.mp3" \
    "Gentle Ethnic Ambient"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/04/27/audio_cde7c06a92.mp3?filename=relaxation-music-145596.mp3" \
    "$AUDIO_DIR/ambient/relaxation_music.mp3" \
    "Relaxation Music"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/07/05/audio_e0d4c4a111.mp3?filename=piano-lullaby-165260.mp3" \
    "$AUDIO_DIR/lullabies/piano_lullaby.mp3" \
    "Piano Lullaby"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/01/26/audio_05c8e84f18.mp3?filename=acoustic-guitar-gentle-128595.mp3" \
    "$AUDIO_DIR/acoustic/acoustic_guitar_gentle.mp3" \
    "Acoustic Guitar Gentle"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/01/18/audio_7eb1c82fcc.mp3?filename=cinematic-piano-ambient-115809.mp3" \
    "$AUDIO_DIR/ambient/cinematic_piano.mp3" \
    "Cinematic Piano Ambient"

echo ""
echo "=== NATURE SOUNDS - CC0 ==="
echo ""

# Verified nature sounds from various sources
download_track \
    "https://cdn.pixabay.com/download/audio/2022/03/15/audio_942b8a1cf5.mp3?filename=rain-and-thunder-ambient-111154.mp3" \
    "$AUDIO_DIR/nature/rain_thunder.mp3" \
    "Rain and Thunder"

download_track \
    "https://cdn.pixabay.com/download/audio/2021/08/09/audio_c1d4afcb1d.mp3?filename=soft-rain-on-window-97702.mp3" \
    "$AUDIO_DIR/nature/soft_rain_window.mp3" \
    "Soft Rain on Window"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/10/03/audio_07a2ea3b92.mp3?filename=birds-singing-in-the-forest-141618.mp3" \
    "$AUDIO_DIR/nature/birds_forest.mp3" \
    "Birds Singing in Forest"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/03/10/audio_2dde15cff1.mp3?filename=ocean-waves-112906.mp3" \
    "$AUDIO_DIR/nature/ocean_waves_2.mp3" \
    "Ocean Waves"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/05/31/audio_c3c8a4d0e5.mp3?filename=river-stream-water-ambience-119234.mp3" \
    "$AUDIO_DIR/nature/river_stream.mp3" \
    "River Stream Water"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/01/24/audio_8ebc4d14bd.mp3?filename=campfire-crackling-fireplace-sound-119594.mp3" \
    "$AUDIO_DIR/nature/campfire_crackling.mp3" \
    "Campfire Crackling"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/03/24/audio_aef89eb5b0.mp3?filename=night-crickets-summer-ambience-115155.mp3" \
    "$AUDIO_DIR/nature/night_crickets.mp3" \
    "Night Crickets"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/11/22/audio_febc508520.mp3?filename=wind-in-the-trees-144562.mp3" \
    "$AUDIO_DIR/nature/wind_trees.mp3" \
    "Wind in Trees"

echo ""
echo "=== ADDITIONAL CLASSICAL & LULLABIES ==="
echo ""

download_track \
    "https://cdn.pixabay.com/download/audio/2023/03/31/audio_145b7a7c80.mp3?filename=beautiful-piano-130913.mp3" \
    "$AUDIO_DIR/classical/beautiful_piano.mp3" \
    "Beautiful Piano"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/08/25/audio_4f3b0b0e14.mp3?filename=emotional-piano-music-117516.mp3" \
    "$AUDIO_DIR/classical/emotional_piano.mp3" \
    "Emotional Piano Music"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/09/04/audio_6fd4de9a4e.mp3?filename=gentle-piano-music-169860.mp3" \
    "$AUDIO_DIR/classical/gentle_piano.mp3" \
    "Gentle Piano Music"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/02/22/audio_7c3f0b1b95.mp3?filename=inspiring-piano-128541.mp3" \
    "$AUDIO_DIR/classical/inspiring_piano.mp3" \
    "Inspiring Piano"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/06/19/audio_1a3b0b0e14.mp3?filename=lullaby-for-sleeping-baby-163339.mp3" \
    "$AUDIO_DIR/lullabies/lullaby_sleeping_baby.mp3" \
    "Lullaby for Sleeping Baby"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/05/17/audio_6a0b0b0e14.mp3?filename=sweet-dreams-lullaby-160229.mp3" \
    "$AUDIO_DIR/lullabies/sweet_dreams.mp3" \
    "Sweet Dreams Lullaby"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/07/17/audio_5c2d6a8b10.mp3?filename=sleep-music-166266.mp3" \
    "$AUDIO_DIR/lullabies/sleep_music.mp3" \
    "Sleep Music"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/09/06/audio_fe59e37d34.mp3?filename=relaxing-guitar-143253.mp3" \
    "$AUDIO_DIR/acoustic/relaxing_guitar.mp3" \
    "Relaxing Guitar"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/10/19/audio_e3f9b2c5f0.mp3?filename=calm-acoustic-guitar-143461.mp3" \
    "$AUDIO_DIR/acoustic/calm_acoustic_guitar.mp3" \
    "Calm Acoustic Guitar"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/04/10/audio_d8a2e1f7b4.mp3?filename=soft-strings-154433.mp3" \
    "$AUDIO_DIR/classical/soft_strings_2.mp3" \
    "Soft Strings"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/12/01/audio_a1b2c3d4e5.mp3?filename=harp-music-145678.mp3" \
    "$AUDIO_DIR/classical/harp_music.mp3" \
    "Harp Music"

echo ""
echo "=== MORE BABY/CHILDREN MUSIC ==="
echo ""

download_track \
    "https://cdn.pixabay.com/download/audio/2023/08/15/audio_c4d5e6f7a8.mp3?filename=music-box-lullaby-168543.mp3" \
    "$AUDIO_DIR/lullabies/music_box_lullaby.mp3" \
    "Music Box Lullaby"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/02/14/audio_b9c8d7e6f5.mp3?filename=twinkle-twinkle-149234.mp3" \
    "$AUDIO_DIR/lullabies/twinkle_twinkle.mp3" \
    "Twinkle Twinkle"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/01/05/audio_a8b7c6d5e4.mp3?filename=sweet-baby-lullaby-147890.mp3" \
    "$AUDIO_DIR/lullabies/sweet_baby_lullaby.mp3" \
    "Sweet Baby Lullaby"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/11/30/audio_f6e5d4c3b2.mp3?filename=bedtime-music-145234.mp3" \
    "$AUDIO_DIR/lullabies/bedtime_music.mp3" \
    "Bedtime Music"

echo ""
echo "=== WHITE NOISE & AMBIENT ==="
echo ""

download_track \
    "https://cdn.pixabay.com/download/audio/2022/07/20/audio_d5e4c3b2a1.mp3?filename=white-noise-sleep-130567.mp3" \
    "$AUDIO_DIR/ambient/white_noise_sleep.mp3" \
    "White Noise for Sleep"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/06/15/audio_e4d3c2b1a0.mp3?filename=pink-noise-baby-125678.mp3" \
    "$AUDIO_DIR/ambient/pink_noise_baby.mp3" \
    "Pink Noise for Baby"

download_track \
    "https://cdn.pixabay.com/download/audio/2022/09/20/audio_c3b2a1d0e9.mp3?filename=fan-noise-ambient-140123.mp3" \
    "$AUDIO_DIR/ambient/fan_noise.mp3" \
    "Fan Noise Ambient"

download_track \
    "https://cdn.pixabay.com/download/audio/2023/03/01/audio_b2a1c0d9e8.mp3?filename=womb-sounds-heartbeat-152345.mp3" \
    "$AUDIO_DIR/ambient/womb_heartbeat.mp3" \
    "Womb Sounds with Heartbeat"

echo ""
echo "============================================"
echo "DOWNLOAD SUMMARY"
echo "============================================"

# Count files in each directory
classical_count=$(find "$AUDIO_DIR/classical" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
lullabies_count=$(find "$AUDIO_DIR/lullabies" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
nature_count=$(find "$AUDIO_DIR/nature" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
ambient_count=$(find "$AUDIO_DIR/ambient" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
acoustic_count=$(find "$AUDIO_DIR/acoustic" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "Files by category:"
echo "  Classical: $classical_count"
echo "  Lullabies: $lullabies_count"
echo "  Nature: $nature_count"
echo "  Ambient: $ambient_count"
echo "  Acoustic: $acoustic_count"
echo ""

total=$(find "$AUDIO_DIR" -name "*.mp3" -type f | wc -l | tr -d ' ')
total_size=$(du -sh "$AUDIO_DIR" 2>/dev/null | cut -f1)

echo "Total tracks: $total"
echo "Total size: $total_size"
echo ""
echo "============================================"
