# Apple Watch Companion App

## Overview

Create a simplified Apple Watch companion app for BabyInCarApp that provides essential functionality for parents who want quick access to soothing music and cry alerts without needing to pull out their iPhone.

## Architecture Decision

**Key Constraint**: watchOS does NOT support:
- AVAudioEngine, AVAudioPlayer, AVPlayer (iOS-only)
- Accelerate framework (no FFT/DSP)
- Real-time microphone streaming for cry detection
- Speech framework for voice commands

**Solution**: Companion app architecture where:
- iPhone handles all ML/cry detection
- Watch syncs pre-cached audio files via WatchConnectivity
- Watch uses WKAudioFilePlayer for local playback
- iPhone pushes cry alerts to Watch via notifications

---

## User Stories

### US-001: WatchConnectivity Infrastructure
**Project**: BabyInCarApp
**As a** developer, I want to establish bidirectional communication between iPhone and Watch so that state can be synchronized in real-time.

**Acceptance Criteria**:
- [x] AC-US1-01: WCSession activated on both iPhone and Watch
- [x] AC-US1-02: Application context transfers work for state sync
- [x] AC-US1-03: File transfers work for audio file sync
- [x] AC-US1-04: Message passing works for real-time commands
- [x] AC-US1-05: Reachability detection handles connection state

---

### US-002: Watch Audio Playback
**Project**: BabyInCarApp
**As a** parent, I want to play soothing music directly from my Apple Watch so that I can calm my baby without using my phone.

**Acceptance Criteria**:
- [x] AC-US2-01: WKAudioFilePlayer wrapper created for watchOS
- [x] AC-US2-02: Local audio files play correctly on watch
- [x] AC-US2-03: Play/pause/skip controls work
- [x] AC-US2-04: Volume control via Digital Crown
- [x] AC-US2-05: Now Playing info displays current track

---

### US-003: Favorites Sync
**Project**: BabyInCarApp
**As a** parent, I want my favorite tracks synced to my Watch so that I have quick access to music that works for my baby.

**Acceptance Criteria**:
- [x] AC-US3-01: Favorites list synced from iPhone to Watch
- [x] AC-US3-02: Audio files for favorites transferred to Watch storage
- [x] AC-US3-03: Watch shows favorites list with artwork
- [x] AC-US3-04: Sync happens automatically when Watch is connected
- [x] AC-US3-05: Storage limit enforced (max 50MB on watch)

---

### US-004: Remote Playback Control
**Project**: BabyInCarApp
**As a** parent, I want to control iPhone playback from my Watch so that I can manage music while driving without looking at my phone.

**Acceptance Criteria**:
- [x] AC-US4-01: Watch can send play/pause commands to iPhone
- [x] AC-US4-02: Watch can send skip next/previous commands
- [x] AC-US4-03: Watch displays what's playing on iPhone
- [x] AC-US4-04: Playback state syncs in real-time
- [x] AC-US4-05: Works even when Watch audio is not playing

---

### US-005: Cry Detection Alerts
**Project**: BabyInCarApp
**As a** parent, I want to receive cry alerts on my Watch so that I'm notified immediately when my baby needs attention.

**Acceptance Criteria**:
- [x] AC-US5-01: iPhone sends cry detection notification to Watch
- [x] AC-US5-02: Watch displays cry type (hungry, tired, pain, etc.)
- [x] AC-US5-03: Haptic feedback alerts parent on cry detection
- [x] AC-US5-04: Quick action to start soothing music from alert
- [x] AC-US5-05: Alert history viewable on Watch

---

### US-006: Sleep Timer
**Project**: BabyInCarApp
**As a** parent, I want to set a sleep timer from my Watch so that music automatically stops after my baby falls asleep.

**Acceptance Criteria**:
- [x] AC-US6-01: Sleep timer UI on Watch (5, 10, 15, 30, 60 min options)
- [x] AC-US6-02: Timer syncs with iPhone playback
- [x] AC-US6-03: Visual countdown on Watch
- [x] AC-US6-04: Gentle haptic when timer ends
- [x] AC-US6-05: Cancel timer option available

---

## Technical Constraints

| Constraint | Impact | Solution |
|------------|--------|----------|
| No AVAudioEngine on watchOS | Cannot use existing AudioEngine | Create WatchAudioPlayer with WKAudioFilePlayer |
| No Accelerate framework | Cannot run ML feature extraction | Cry detection stays on iPhone only |
| Limited storage (50-100MB) | Cannot sync full library | Sync only favorites (max 20 tracks) |
| No background audio processing | Cannot detect crying on watch | iPhone sends push notifications |
| Screen size (312x390 max) | Complex UI won't work | Minimal UI with essential controls |

---

## Out of Scope

- Cry detection on Apple Watch (not technically feasible)
- Full library browsing on Watch (storage constraints)
- Voice commands on Watch (limited Speech API)
- Streaming audio on Watch (no AVPlayer)
- CarPlay from Watch (iOS-only feature)
