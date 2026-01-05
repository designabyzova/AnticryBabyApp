# FS-016: Smooth Audio Transitions

## Overview

Implement smooth audio transitions (crossfade) as a **global default setting** enabled by default. Every track switch should provide a seamless listening experience with fade-out of the current track and fade-in of the new track.

## User Stories

### US-001: Global Smooth Transitions Setting
**As a** parent using the app,
**I want** all track transitions to be smooth by default,
**So that** sudden audio changes don't startle my baby.

**Acceptance Criteria**:
- [x] AC-US1-01: Smooth transitions setting exists in app settings (default: ON) ✅
- [x] AC-US1-02: Setting persists across app launches via UserDefaults ✅
- [x] AC-US1-03: Setting can be toggled in ProfileView/Settings ✅
- [x] AC-US1-04: Setting name is "Smooth Transitions" with clear description ✅

### US-002: Crossfade Implementation
**As a** parent,
**I want** track changes to crossfade smoothly,
**So that** there's no jarring audio gap when switching songs.

**Acceptance Criteria**:
- [x] AC-US2-01: When smooth transitions ON, tracks crossfade (1 second duration) ✅
- [x] AC-US2-02: When smooth transitions OFF, tracks switch immediately ✅
- [x] AC-US2-03: Crossfade applies to next/previous track navigation ✅
- [x] AC-US2-04: Crossfade applies to playlist auto-advance ✅
- [x] AC-US2-05: Crossfade applies to shuffle mode transitions ✅

### US-003: Fade-In on First Play
**As a** parent,
**I want** audio to fade in when starting playback,
**So that** sound doesn't start abruptly.

**Acceptance Criteria**:
- [x] AC-US3-01: First play of a track fades in over 0.5 seconds ✅
- [x] AC-US3-02: Fade-in respects global smooth transitions setting ✅
- [x] AC-US3-03: Resume from pause does NOT fade (immediate resume) ✅

### US-004: Emergency Response Override
**As a** parent in emergency cry response mode,
**I want** immediate sound switching without fade delay,
**So that** baby gets soothing sound as fast as possible.

**Acceptance Criteria**:
- [x] AC-US4-01: Emergency mode sound switches are immediate (no crossfade delay) ✅
- [x] AC-US4-02: Manual sound switch in emergency mode respects user choice ✅
- [x] AC-US4-03: Emergency mode sound still fades out when baby calms ✅ (fadeOutAndStop already exists)

## Technical Design

### Settings Storage
```swift
// AppState.swift
@Published var smoothTransitionsEnabled: Bool = true {
    didSet {
        UserDefaults.standard.set(smoothTransitionsEnabled, forKey: "smoothTransitionsEnabled")
    }
}
```

### AudioEngine Integration
```swift
// AudioEngine.swift
@Published var smoothTransitionsEnabled: Bool = true

func play(track: AudioTrack) {
    if smoothTransitionsEnabled && playbackState == .playing {
        crossfadeToTrack(track, duration: 1.0)
    } else if smoothTransitionsEnabled {
        startPlaybackWithFadeIn(track: track, fadeDuration: 0.5)
    } else {
        playImmediate(track: track)
    }
}
```

### UI Toggle
ProfileView Settings section with toggle for "Smooth Transitions"

## Out of Scope
- Per-track fade duration customization
- Gapless playback (requires pre-buffering)
- DJ-style beat-matched crossfades

## Dependencies
- Existing AudioEngine crossfade implementation (already in place)
- AppState for settings management
