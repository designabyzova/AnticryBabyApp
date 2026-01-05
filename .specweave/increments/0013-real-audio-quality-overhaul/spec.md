# Real Audio Quality Overhaul

## Problem Statement

The current audio library contains **10 placeholder/fake audio files** that are useless for baby soothing:

### Identified Fake/Placeholder Files (under 100KB, 1-3 seconds):
1. `ne_Calm_Ocean_cfcf4690.mp3` - 29KB, 1.5 seconds (GARBAGE)
2. `pb_Ocean_Waves_Calm_cfcf4690.mp3` - 29KB, 1.5 seconds (GARBAGE)
3. `ne_Beach_Waves_fe1b42d0.mp3` - 67KB, 3 seconds (GARBAGE)
4. `pb_Sea_Ambience_fe1b42d0.mp3` - 67KB, 3 seconds (GARBAGE)
5. `sb_stream.mp3` - 39KB, 2 seconds (GARBAGE)
6. `pb_Sleep_Music_cfcf4690.mp3` - 29KB (lullabies - GARBAGE)
7. `relaxing_piano_melody.mp3` - 29KB (classical - GARBAGE)
8. `vt_Ofelia_9ab56a18.mp3` - 18KB (ambient - GARBAGE)
9. `vt_Going_Higher_8b6cbbcb.mp3` - 18KB (ambient - GARBAGE)
10. `ambient_piano_logo.mp3` - 78KB (ambient - GARBAGE)

### Good Files Already Present:
- Internet Archive (ia_*) files: High quality, long duration (2min to 8hrs)
- rain_gentle.mp3, rain_sounds.mp3, rain_ambient.mp3: Good quality
- white_noise.mp3: 10 minutes, good quality
- Classical files from collected sources

## User Story

### US-001: Replace Fake Audio with Real High-Quality Content
As a **parent using the app**, I want **all audio files to be real, high-quality recordings** so that **my baby actually gets soothed by genuine calming sounds**.

#### Acceptance Criteria

- [x] **AC-US1-01**: All placeholder files (< 100KB) are deleted from the app bundle
- [x] **AC-US1-02**: Real ocean wave sounds (minimum 5 minutes) are sourced and added
- [x] **AC-US1-03**: Real stream/river sounds (minimum 5 minutes) are sourced and added
- [x] **AC-US1-04**: Real beach waves sounds (minimum 5 minutes) are sourced and added
- [x] **AC-US1-05**: Real calm ambient music (minimum 3 minutes each) - verified existing bensound tracks
- [x] **AC-US1-06**: Real lullaby/sleep music - verified existing high-quality lullabies
- [x] **AC-US1-07**: Real classical piano music - verified existing classical tracks
- [x] **AC-US1-08**: All new audio files are uploaded to Cloudflare R2
- [x] **AC-US1-09**: Database is updated with correct URLs and accurate durations
- [x] **AC-US1-10**: All audio files pass quality verification test (> 100KB, > 60 seconds)

### US-002: E2E Audio Quality Tests
As a **developer**, I want **automated tests to verify audio file quality** so that **no fake/placeholder files slip into production**.

#### Acceptance Criteria

- [x] **AC-US2-01**: E2E test verifies all audio URLs return 200 status
- [x] **AC-US2-02**: E2E test verifies all audio files are > 100KB
- [x] **AC-US2-03**: E2E test verifies audio duration metadata matches actual file duration
- [x] **AC-US2-04**: Test suite runs (16 tests passing in Vitest)
- [x] **AC-US2-05**: Maestro flow tests audio playback in app

## Technical Approach

### Audio Sourcing Strategy

1. **Freesound.org** - Creative Commons licensed nature sounds
2. **Internet Archive** - Public domain nature recordings (already have good ia_* files)
3. **Pixabay Audio** - Royalty-free music and sounds
4. **Free Music Archive** - CC-licensed lullabies and ambient music

### Quality Requirements

| Category | Min Duration | Min Size | Max Size | Format |
|----------|-------------|----------|----------|--------|
| Nature Sounds | 5 min | 1 MB | 50 MB | MP3 128kbps+ |
| Lullabies | 3 min | 500 KB | 20 MB | MP3 128kbps+ |
| White Noise | 10 min | 2 MB | 100 MB | MP3 128kbps+ |
| Classical | 3 min | 500 KB | 30 MB | MP3 128kbps+ |
| Ambient | 3 min | 500 KB | 30 MB | MP3 128kbps+ |

### Files to Source

1. **Ocean Waves** - 10+ minute loop of calm ocean waves
2. **Babbling Stream** - 5+ minute forest stream
3. **Beach Waves** - 5+ minute gentle beach sounds
4. **Calm Ocean** - 10+ minute deep ocean ambience
5. **Sleep Music** - 5+ minute calming instrumental
6. **Piano Melody** - 3+ minute relaxing piano
7. **Ambient Music** - 2-3 tracks, 3+ minutes each

## Out of Scope

- Regenerating existing good quality files (ia_* files are fine)
- Adding new categories
- Changing app UI
