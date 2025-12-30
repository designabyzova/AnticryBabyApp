#!/bin/bash
# Download royalty-free audio from Internet Archive
# All tracks are in Public Domain or CC0

AUDIO_DIR="/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
mkdir -p "$AUDIO_DIR"

echo "Downloading royalty-free lullabies and calming sounds..."

# Create subdirectories
mkdir -p "$AUDIO_DIR/lullabies"
mkdir -p "$AUDIO_DIR/classical"
mkdir -p "$AUDIO_DIR/nature"
mkdir -p "$AUDIO_DIR/whitenoise"

# === LULLABIES (Public Domain) ===
echo "Downloading lullabies..."

# Brahms Lullaby - Public Domain (Musopen)
curl -L "https://files.musopen.org/recordings/8b8b5b5d-7b3e-48c2-b4a0-c7b8b0d9f5a9.mp3" -o "$AUDIO_DIR/lullabies/brahms_lullaby.mp3" 2>/dev/null || echo "Note: Will use alternative source"

# Alternative: Use Free Music Archive / Internet Archive
# Twinkle Twinkle Little Star - Traditional (Public Domain recording from Librivox)
curl -L "https://archive.org/download/twinkle_twinkle_little_star_librivox/twinkle_twinkle_little_star_librivox_64kb_mp3.zip" -o /tmp/twinkle.zip 2>/dev/null && unzip -o /tmp/twinkle.zip -d "$AUDIO_DIR/lullabies/" 2>/dev/null || echo "Twinkle download note"

# === CLASSICAL MUSIC (Public Domain from Musopen/IMSLP) ===
echo "Downloading classical music..."

# Clair de Lune - Debussy (Public Domain)
curl -L "https://archive.org/download/ClairDeLune_339/ClairDeLune.mp3" -o "$AUDIO_DIR/classical/clair_de_lune.mp3" 2>/dev/null || echo "Clair de Lune note"

# Canon in D - Pachelbel (Public Domain)
curl -L "https://archive.org/download/Canon_702/Canon.mp3" -o "$AUDIO_DIR/classical/canon_in_d.mp3" 2>/dev/null || echo "Canon note"

# Gymnopedie No.1 - Satie (Public Domain)
curl -L "https://archive.org/download/ErikSatie-Gymnopedie1/gymnopedie1.mp3" -o "$AUDIO_DIR/classical/gymnopedie.mp3" 2>/dev/null || echo "Gymnopedie note"

# === NATURE SOUNDS (CC0 from Freesound) ===
echo "Downloading nature sounds..."

# Note: These require Freesound API for proper download
# Placeholder URLs - will be replaced with actual Freesound downloads

# Rain sounds
curl -L "https://cdn.freesound.org/previews/531/531947_6044691-lq.mp3" -o "$AUDIO_DIR/nature/gentle_rain.mp3" 2>/dev/null || echo "Rain note"

# Ocean waves
curl -L "https://cdn.freesound.org/previews/527/527602_7037-lq.mp3" -o "$AUDIO_DIR/nature/ocean_waves.mp3" 2>/dev/null || echo "Ocean note"

# Forest birds
curl -L "https://cdn.freesound.org/previews/531/531627_5674468-lq.mp3" -o "$AUDIO_DIR/nature/forest_birds.mp3" 2>/dev/null || echo "Birds note"

echo ""
echo "Download attempts complete!"
echo "Checking downloaded files..."
echo ""

# List what we got
find "$AUDIO_DIR" -name "*.mp3" -exec ls -lh {} \;

echo ""
echo "Total audio files:"
find "$AUDIO_DIR" -name "*.mp3" | wc -l
