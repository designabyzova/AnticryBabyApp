---
increment: 0019-auto-duck-external-audio
title: "Auto-Duck External Audio on Cry Detection"
priority: P1
status: completed
created: 2026-01-04
dependencies: []
structure: user-stories
project: BabyInCarApp
tech_stack:
  detected_from: "BabyInCarApp.xcodeproj"
  language: "swift"
  framework: "SwiftUI"
  platform: "iOS"
---

# Auto-Duck External Audio on Cry Detection

## Problem Statement

When parents are driving with Spotify, Apple Music, or other audio apps playing, and their baby starts crying, the app currently plays soothing sounds **on top of** the external audio. This creates audio chaos - both streams play simultaneously, making it impossible for the baby to hear the calming sounds clearly.

**Current Behavior (BAD):**
```
Baby cries → App plays soothing audio → Spotify KEEPS PLAYING at 100%
Result: Audio chaos, baby hears mixed confusing sounds
```

**Expected Behavior (GOOD):**
```
Baby cries → App DUCKS external audio (reduces to ~20%) → Plays soothing audio
Baby calms → App RESTORES external audio volume
Result: Clear soothing sounds, then music resumes naturally
```

## User Stories

### US-001: Auto-Duck External Audio When Cry Detected
**Project**: BabyInCarApp
**As a** parent driving with music playing,
**I want** the app to automatically reduce external audio volume when my baby cries,
**So that** my baby can clearly hear the soothing sounds without competing audio.

**Acceptance Criteria:**
- [x] AC-US1-01: When cry is detected and emergency mode activates, external audio (Spotify, Apple Music, etc.) volume is automatically reduced to ~20%
- [x] AC-US1-02: The app's soothing audio plays at full volume while external audio is ducked
- [x] AC-US1-03: Ducking happens within 100ms of cry detection for immediate response
- [x] AC-US1-04: Audio session uses `.duckOthers` option when cry response is active

### US-002: Restore External Audio After Baby Calms
**Project**: BabyInCarApp
**As a** parent,
**I want** external audio to automatically return to normal volume when my baby calms down,
**So that** I can continue enjoying my music without manual intervention.

**Acceptance Criteria:**
- [x] AC-US2-01: When cry response ends (baby calmed or manual stop), external audio volume is restored
- [x] AC-US2-02: Audio restoration happens smoothly (no sudden volume jump)
- [x] AC-US2-03: Audio session returns to `.mixWithOthers` mode after deactivation
- [x] AC-US2-04: Restoration occurs within 500ms of cry response ending

### US-003: User Preference for Auto-Duck
**Project**: BabyInCarApp
**As a** parent,
**I want** to control whether external audio is automatically ducked,
**So that** I can choose my preferred audio behavior based on my needs.

**Acceptance Criteria:**
- [x] AC-US3-01: Settings screen includes "Auto-duck external audio" toggle
- [x] AC-US3-02: Toggle is enabled by default (ducking ON)
- [x] AC-US3-03: Preference is persisted using UserDefaults
- [x] AC-US3-04: When disabled, app uses `.mixWithOthers` (no ducking, legacy behavior)
- [x] AC-US3-05: Preference change takes effect immediately without app restart

### US-004: CarPlay Audio Integration
**Project**: BabyInCarApp
**As a** parent using CarPlay,
**I want** the auto-duck feature to work correctly in CarPlay mode,
**So that** soothing sounds are clearly audible through the car speakers.

**Acceptance Criteria:**
- [x] AC-US4-01: Ducking works correctly when audio is routed through CarPlay
- [x] AC-US4-02: CarPlay audio session respects ducking preferences
- [x] AC-US4-03: No audio glitches or interruptions during CarPlay ducking transitions

## Technical Notes

### iOS Audio Session Categories

| Category | Options | Behavior |
|----------|---------|----------|
| `.playback` | `.mixWithOthers` | Plays alongside other audio (NO ducking) |
| `.playback` | `.duckOthers` | Reduces other app's volume while playing |
| `.playback` | `.mixWithOthers, .duckOthers` | Mix + Duck (best for this use case) |

### Integration Points

1. **AudioEngine.swift** - Add ducking mode toggle
2. **SmartCryResponseEngine.swift** - Enable ducking on emergency activation
3. **ProfileView.swift** - Add user preference toggle
4. **SmartCarPlayController.swift** - CarPlay ducking support

## Out of Scope

- Completely pausing external audio (only ducking/volume reduction)
- Detecting specific external apps (Spotify vs Apple Music)
- Custom ducking volume levels (fixed at iOS default ~20%)
