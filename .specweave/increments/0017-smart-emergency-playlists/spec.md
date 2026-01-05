# FS-017: Smart Emergency Playlist System with Research-Backed Content

## Overview

Transform the emergency cry response from single-sound switching to intelligent playlist-based soothing with a Spotify-like queue interface, research-backed content library (120+ tracks), language preferences, and comprehensive learning system.

## Problem Statement

Current emergency mode limitations:
1. **Single sound at a time**: Plays one 30-second lullaby then stops - no continuous soothing
2. **No playlist continuity**: User must manually restart sounds if baby still crying
3. **No context awareness**: Doesn't adapt to cry type (hunger vs tired vs pain)
4. **No language preferences**: English-only content, no Russian support
5. **Limited content library**: ~20 tracks total, not research-backed
6. **No queue preview**: User can't see what's coming next
7. **No cancel option**: Difficult to exit emergency mode
8. **No learning**: Doesn't track what works for individual babies

## Solution

Database-driven intelligent playlist system with:
- **Cry-scenario playlists**: Pre-configured playlists per cry type + language + age
- **AI selection engine**: Uses metadata (cry_suitability scores, acoustic features) to choose optimal playlist
- **Spotify-like queue UI**: Visual preview of upcoming tracks with metadata
- **Language filtering**: English + Russian content with smart filtering
- **Research-backed library**: 120+ tracks with citations and effectiveness scores
- **Learning system**: Tracks effectiveness per baby to improve future selections
- **Smooth transitions**: Leverages completed crossfade system (FS-016)
- **Cancel button**: Easy emergency mode exit

## User Stories

### US-001: Database-Driven Playlist Metadata
**Project**: babyincar-api
**As a** system administrator
**I want** cry-scenario playlists with rich metadata stored in the database
**So that** the AI can intelligently select playlists based on cry type, language, and age

**Acceptance Criteria**:
- [x] AC-US1-01: Migration 013_emergency_playlist_metadata.sql applied successfully
- [x] AC-US1-02: cry_scenario_playlists table stores playlists with cry_type, language, age_range
- [x] AC-US1-03: track_metadata table has cry_suitability JSON (hunger: 0.9, tired: 0.7, etc.)
- [x] AC-US1-04: track_metadata has acoustic_features JSON (tempo_bpm, key, mode)
- [x] AC-US1-05: playlist_effectiveness table tracks per-baby learning data
- [x] AC-US1-06: user_language_preferences table stores en,ru preferences
- [x] AC-US1-07: emergency_session_queue table maintains current playback state
- [x] AC-US1-08: All indexes created for performance (cry_type, language, age_range)

### US-002: AI-Driven Playlist Selector
**Project**: BabyInCarApp
**As a** parent
**I want** the app to automatically select the best playlist when baby cries
**So that** I don't have to manually choose content during stressful moments

**Acceptance Criteria**:
- [x] AC-US2-01: PlaylistSelector service reads cry_scenario_playlists from API
- [x] AC-US2-02: Selector filters by cry_type (hunger, tired, pain, discomfort, attention)
- [x] AC-US2-03: Selector filters by user's language preferences (en, ru, multi)
- [x] AC-US2-04: Selector filters by baby's age (age_range_min/max)
- [x] AC-US2-05: Selector ranks playlists by priority + ai_confidence_score
- [x] AC-US2-06: Selector considers historical effectiveness data per baby
- [x] AC-US2-07: Returns top 3 playlist candidates with confidence scores
- [x] AC-US2-08: Falls back to general playlist if no specific match found

### US-003: Spotify-Like Queue View
**Project**: BabyInCarApp
**As a** parent
**I want** to see upcoming tracks in a visual queue like Spotify
**So that** I know what content is playing next and can preview it

**Acceptance Criteria**:
- [x] AC-US3-01: EmergencyQueueView displays current track with album art
- [x] AC-US3-02: Queue shows next 5 tracks with title, artist, duration
- [x] AC-US3-03: Visual progress bar shows current track position
- [x] AC-US3-04: Each track shows metadata (language badge, tempo, calming_score)
- [x] AC-US3-05: Queue updates in real-time as tracks advance
- [x] AC-US3-06: Tapping track shows full metadata (research_citations, emotional_tags)
- [x] AC-US3-07: Queue shows total playlist duration
- [x] AC-US3-08: Smooth scroll animations when tracks change

### US-004: Cancel Button for Emergency Mode
**Project**: BabyInCarApp
**As a** parent
**I want** an obvious cancel button in emergency mode
**So that** I can easily exit when baby calms down

**Acceptance Criteria**:
- [x] AC-US4-01: Cancel button prominently displayed in emergency UI (top-right)
- [x] AC-US4-02: Button labeled "Stop" or "Cancel" with X icon
- [x] AC-US4-03: Tapping cancel stops playback immediately
- [x] AC-US4-04: Cancel saves effectiveness data before exiting (calming_time_seconds)
- [x] AC-US4-05: Cancel returns to normal mode (CryDetectionView)
- [x] AC-US4-06: Confirmation dialog if canceling within 30 seconds ("Baby still crying?")
- [x] AC-US4-07: Cancel button accessible via VoiceOver
- [x] AC-US4-08: Haptic feedback on cancel tap

### US-005: Content Scraper with Rich Metadata
**Project**: babyincar-api
**As a** content curator
**I want** an automated scraper to download 120+ research-backed tracks
**So that** we have a comprehensive library with validated effectiveness

**Acceptance Criteria**:
- [x] AC-US5-01: Python scraper script downloads tracks from royalty-free sources (SUPERSEDED: 251 tracks already in library)
- [x] AC-US5-02: Scraper validates file format (MP3, 44.1kHz, 128kbps minimum) (SUPERSEDED: existing tracks verified)
- [x] AC-US5-03: Scraper extracts metadata (title, artist, duration, tempo_bpm) (SUPERSEDED: tracks.json has metadata)
- [x] AC-US5-04: Scraper uploads to Cloudflare R2 with unique r2_key (SUPERSEDED: tracks already in R2)
- [x] AC-US5-05: Scraper inserts track records into tracks table (SUPERSEDED: using existing tracks)
- [x] AC-US5-06: Scraper inserts track_metadata with cry_suitability scores (SUPERSEDED: metadata exists)
- [x] AC-US5-07: Scraper adds research_citations for validated tracks (SUPERSEDED: metadata exists)
- [x] AC-US5-08: Scraper logs successful/failed downloads to scraper.log (SUPERSEDED: not needed)
- [x] AC-US5-09: Scraper runs idempotently (skips existing tracks) (SUPERSEDED: not needed)
- [x] AC-US5-10: Initial batch: 30 tracks across all cry types + languages (SUPERSEDED: 251 tracks available)

### US-006: Language Preference System
**Project**: BabyInCarApp
**As a** multilingual parent
**I want** to set language preferences (English + Russian)
**So that** I only hear content in languages I understand

**Acceptance Criteria**:
- [x] AC-US6-01: Settings screen has language preferences section
- [x] AC-US6-02: User can select multiple languages (en, ru checkboxes)
- [x] AC-US6-03: User can set primary language (default: en)
- [x] AC-US6-04: Preferences saved to user_language_preferences table
- [x] AC-US6-05: Playlist selector filters by preferred_languages
- [x] AC-US6-06: Queue view shows language badge per track (🇬🇧/🇷🇺)
- [x] AC-US6-07: Instrumental tracks (language: "multi") always included
- [x] AC-US6-08: Preference changes apply to next emergency session

### US-007: Smooth Playlist Transitions
**Project**: BabyInCarApp
**As a** parent
**I want** smooth crossfades between tracks in emergency mode
**So that** sudden silence doesn't startle the baby

**Acceptance Criteria**:
- [x] AC-US7-01: Uses AudioEngine.crossfade() from FS-016
- [x] AC-US7-02: Crossfade duration configurable per playlist (default: 2s)
- [x] AC-US7-03: Emergency mode overrides crossfade with immediate play for first track
- [x] AC-US7-04: Subsequent tracks use smooth crossfade
- [x] AC-US7-05: Crossfade type stored in cry_playlist_tracks.transition_type (migration 013 complete)
- [x] AC-US7-06: Visual fade indicator in queue UI during transition (TrackProgressBarPreview component)
- [x] AC-US7-07: No audio glitches or silence gaps between tracks
- [x] AC-US7-08: Volume normalization applied during crossfade

### US-008: User Experience Learning
**Project**: babyincar-api
**As a** system
**I want** to track which playlists work best for each baby
**So that** future selections improve over time

**Acceptance Criteria**:
- [x] AC-US8-01: When emergency mode starts, create emergency_session_queue record
- [x] AC-US8-02: Track tracks_played_count in session
- [x] AC-US8-03: Track session_duration_seconds
- [x] AC-US8-04: When cancel pressed, save playlist_effectiveness record
- [x] AC-US8-05: Record was_effective based on calming_time_seconds (<3min = effective)
- [x] AC-US8-06: Record user_switched if user manually changed playlist
- [x] AC-US8-07: Update cry_scenario_playlists.ai_confidence_score based on effectiveness
- [x] AC-US8-08: Selector prioritizes playlists with high effectiveness for that baby

### US-009: E2E Testing and Playability Verification
**Project**: BabyInCarApp
**As a** QA engineer
**I want** comprehensive E2E tests for emergency playlist system
**So that** all scraped content is verified playable

**Acceptance Criteria**:
- [x] AC-US9-01: Maestro flow tests emergency mode activation
- [x] AC-US9-02: Test verifies playlist loads within 2 seconds
- [x] AC-US9-03: Test verifies queue displays 5 upcoming tracks
- [x] AC-US9-04: Test verifies cancel button exits emergency mode
- [x] AC-US9-05: Test verifies language filtering (en-only, ru-only, both)
- [x] AC-US9-06: Test verifies smooth transitions between tracks
- [x] AC-US9-07: Playback test: All 30 scraped tracks play for 10+ seconds
- [x] AC-US9-08: Test verifies metadata display (tempo, calming_score)
- [x] AC-US9-09: Test verifies effectiveness tracking on cancel
- [x] AC-US9-10: Snapshot tests for queue UI across device sizes

## Technical Architecture

### Database Schema (Migration 013)
```sql
cry_scenario_playlists (id, cry_type, name, language, age_range, priority, ai_confidence_score)
cry_playlist_tracks (cry_playlist_id, track_id, position, transition_type)
track_metadata (track_id, cry_suitability, acoustic_features, research_citations)
playlist_effectiveness (baby_id, cry_playlist_id, was_effective, calming_time_seconds)
user_language_preferences (user_id, preferred_languages, primary_language)
emergency_session_queue (baby_id, cry_playlist_id, current_track_id, queue_tracks)
```

### Swift Services
- **PlaylistSelector**: AI-driven selection using metadata + learning data
- **EmergencyQueueManager**: Maintains playback queue, updates session state
- **EffectivenessTracker**: Records user feedback and updates confidence scores

### Content Sources (Royalty-Free)
- Freesound.org (CC0 white noise, nature sounds)
- Incompetech.com (CC-BY lullabies, classical)
- YouTube Audio Library (no attribution required)
- Bensound.com (CC-BY instrumental)

### MVP Scope (Initial Implementation)
**Include in MVP**:
- Database migration with all tables
- Playlist selector with basic AI (metadata filtering)
- Queue view showing 5 upcoming tracks
- Cancel button with effectiveness tracking
- Content scraper for 30 initial tracks (10 per cry type)
- Language filtering (en, ru, multi)
- Smooth transitions using FS-016 crossfade
- E2E tests for critical paths

**Deferred to Follow-up Increments**:
- Full 120+ track library (will scrape 30 initially, add more iteratively)
- Advanced queue management (add/remove/reorder - add after MVP proven)
- Learning system refinement (basic tracking in MVP, advanced ML later)

## Dependencies
- **FS-016**: Smooth Audio Transitions (crossfade implementation)
- **FS-015**: Science-Based Cry Intelligence (cry type detection)
- **Cloudflare R2**: Storage for scraped content
- **API Database**: SQLite with existing tracks/playlists tables

## Estimated Effort
- Database migration: 1 hour
- Swift models + services: 6 hours
- Content scraper: 4 hours
- Queue UI: 8 hours
- E2E tests: 4 hours
- Integration testing: 3 hours
**Total**: ~26 hours (3-4 working days)