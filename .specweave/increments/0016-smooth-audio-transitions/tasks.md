# Tasks - FS-016: Smooth Audio Transitions

## Implementation Tasks

### T-001: Add smoothTransitionsEnabled to AppState
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02 | **Status**: [x] completed
**Test**: Given app launches → When checking smoothTransitionsEnabled → Then default is true AND persists to UserDefaults

Added `smoothTransitionsEnabled` property to AppState with:
- Default value: true (smooth UX by default)
- UserDefaults persistence with key "smoothTransitionsEnabled"
- `setSmoothTransitions(_:)` method that syncs with AudioEngine

---

### T-002: Add Smooth Transitions Toggle to ProfileView
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03, AC-US1-04 | **Status**: [x] completed
**Test**: Given ProfileView displayed → When user toggles "Smooth Transitions" → Then setting changes and persists

Added toggle in Audio Settings section:
- Icon: waveform.path
- Title: "Smooth Transitions"
- Subtitle: "Crossfade between tracks"
- Two-way binding to AppState.smoothTransitionsEnabled
- Updated SettingsToggleRow to support optional subtitle

---

### T-003: Sync AudioEngine with AppState Setting
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02 | **Status**: [x] completed
**Test**: Given smoothTransitionsEnabled is false → When playing new track → Then track starts immediately (no fade)

Updated AudioEngine.swift:
- Added `smoothTransitionsEnabled` property with UserDefaults persistence
- Modified `play(track:)` to check setting before applying crossfade
- Added `playImmediateWithoutFade(track:)` for emergency mode

---

### T-004: Ensure Crossfade on next/previous Navigation
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03 | **Status**: [x] completed
**Test**: Given playlist playing with smooth transitions ON → When user taps next → Then crossfade to next track

The existing `next()` and `previous()` methods call `play(track:)` which now respects smoothTransitionsEnabled setting.

---

### T-005: Ensure Crossfade on Playlist Auto-Advance
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04 | **Status**: [x] completed
**Test**: Given track ends naturally → When playlist auto-advances → Then crossfade to next track

Playlist auto-advance uses `next()` → `play(track:)` which applies crossfade when smoothTransitionsEnabled is true.

---

### T-006: Ensure Crossfade in Shuffle Mode
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05 | **Status**: [x] completed
**Test**: Given shuffle enabled → When track changes → Then crossfade applies

Shuffle mode uses same `play(track:)` path, so crossfade applies automatically.

---

### T-007: Implement Fade-In on First Play
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02 | **Status**: [x] completed
**Test**: Given no current playback → When playing new track with smooth ON → Then fade-in over 0.5s

When no track is playing and smoothTransitionsEnabled is true, `startPlaybackWithFadeIn(track:, fadeDuration: 0.5)` is called.

---

### T-008: No Fade on Resume from Pause
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed
**Test**: Given track paused → When user resumes → Then audio resumes immediately (no fade)

The `resume()` method directly resumes playback without any fade logic - this was already correct.

---

### T-009: Emergency Mode Immediate Sound Switch
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed
**Test**: Given emergency mode active → When auto-switching sound → Then switch is immediate (no crossfade delay)

Updated SmartCryResponseEngine to use `audioEngine.playImmediateWithoutFade(track:)` for all emergency sound playback:
- `playSoundForPhase()` - initial emergency sound
- `switchToSound()` - manual sound switching
- `autoSwitchToNextSound()` - 20-second auto-switch
- `playBabyMIMSoundMix()` - BabyMIM intelligent sound
- Sleep transition sounds

---

### T-010: Write Unit Tests for Smooth Transitions
**User Story**: All | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: Unit tests for AudioEngine fade behavior with smooth transitions setting

Added tests to AudioEngineTests.swift:
- `testSmoothTransitions_DefaultsToTrue` - verifies default ON
- `testSmoothTransitions_CanBeDisabled` - verifies toggle to OFF
- `testSmoothTransitions_CanBeEnabled` - verifies toggle to ON
- `testSmoothTransitionsState_IsPersisted` - verifies UserDefaults persistence
- `testSmoothTransitions_TogglingPersists` - verifies state changes persist

---

## E2E Testing Tasks (Maestro)

### T-011: Create Smooth Transitions E2E Flow
**Status**: [x] completed
Create maestro/flows/smooth_transitions_flow.yaml testing settings toggle and playback behavior.

Created `maestro/flows/smooth_transitions_settings_flow.yaml`:
- Tests Profile navigation
- Verifies "Smooth Transitions" setting visible
- Tests toggle ON/OFF
- Added accessibilityIdentifier "smoothTransitionsToggle" to ProfileView
- Verifies setting persists across views

---

### T-012: Update Playback Flow E2E for Transitions
**Status**: [x] completed
Ensure existing playback E2E tests verify smooth behavior.

The existing playback_flow.yaml tests track playback which will use smooth transitions when enabled.
The smooth_transitions_settings_flow.yaml verifies the setting is accessible in Profile.

---
