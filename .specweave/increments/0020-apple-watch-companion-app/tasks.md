# Tasks: Apple Watch Companion App

---

## Phase 1: Project Setup

### T-001: Add watchOS Target to Xcode Project
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given Xcode project, When adding watchOS target, Then BabyInCarWatchApp scheme builds successfully

- [x] Add new watchOS App target to BabyInCarApp.xcodeproj
- [x] Configure bundle identifier: com.anticry.babyincar.watchkitapp
- [x] Set deployment target: watchOS 9.0
- [x] Add WatchConnectivity framework to both targets
- [x] Create shared framework for models

---

### T-002: Create Shared Models Framework
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04 | **Status**: [x] completed
**Test**: Given shared models, When used by both targets, Then encoding/decoding works correctly

- [x] Create BabyInCarShared framework
- [x] Move WatchTrack, PlaybackState, CryAlert, WatchCommand to shared
- [x] Ensure Codable conformance for all models
- [x] Add framework to both iOS and watchOS targets

---

## Phase 2: WatchConnectivity Infrastructure

### T-003: Implement WatchSyncManager (iPhone)
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04 | **Status**: [x] completed
**Test**: Given WatchSyncManager, When session activates, Then isReachable updates correctly

- [x] Create WatchSyncManager.swift in iOS app
- [x] Implement WCSessionDelegate
- [x] Add session activation on app launch
- [x] Implement applicationContext sync for state
- [x] Implement transferFile for audio sync
- [x] Implement sendMessage for real-time commands
- [x] Add reachability observation

---

### T-004: Implement WatchConnectivityManager (Watch)
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-05 | **Status**: [x] completed
**Test**: Given WatchConnectivityManager, When iPhone sends state, Then watch receives and publishes

- [x] Create WatchConnectivityManager.swift in watchOS app
- [x] Implement WCSessionDelegate for watch
- [x] Handle applicationContext updates
- [x] Handle file transfers with completion
- [x] Handle incoming messages
- [x] Publish state changes via @Published properties

---

## Phase 3: Watch Audio Playback

### T-005: Create WatchAudioPlayer
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03 | **Status**: [x] completed
**Test**: Given audio file on watch, When play() called, Then audio plays through speaker

- [x] Create WatchAudioPlayer.swift
- [x] Initialize WKAudioFilePlayer with local URL
- [x] Implement play/pause/resume methods
- [x] Implement skip next/previous
- [x] Add progress observation
- [x] Handle playback errors gracefully

---

### T-006: Implement Volume Control via Digital Crown
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04 | **Status**: [x] completed
**Test**: Given NowPlayingView, When Digital Crown rotates, Then volume adjusts

- [x] Add .digitalCrownRotation modifier to NowPlayingView
- [x] Map crown value to volume (0.0 - 1.0)
- [x] Add haptic feedback at min/max volume
- [x] Display volume indicator briefly on change

---

### T-007: Create NowPlayingView
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05 | **Status**: [x] completed
**Test**: Given playing track, When NowPlayingView shown, Then displays title, artist, artwork

- [x] Create NowPlayingView.swift
- [x] Display track artwork (or placeholder)
- [x] Show title and artist
- [x] Add play/pause button
- [x] Add skip previous/next buttons
- [x] Show progress bar
- [x] Integrate Digital Crown for volume

---

## Phase 4: Favorites Sync

### T-008: Implement Favorites Transfer (iPhone)
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-04 | **Status**: [x] completed
**Test**: Given favorites on iPhone, When watch is reachable, Then audio files transfer

- [x] Add syncFavoritesToWatch() to WatchSyncManager
- [x] Limit to top 20 favorites (50MB budget)
- [x] Check if track already exists on watch
- [x] Transfer audio file with metadata
- [x] Track transfer progress
- [x] Handle transfer failures with retry

---

### T-009: Implement Favorites Storage (Watch)
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03, AC-US3-05 | **Status**: [x] completed
**Test**: Given file transfer, When completed, Then track available in favorites list

- [x] Create WatchStorageManager.swift
- [x] Save received files to watch storage
- [x] Maintain favorites manifest (JSON)
- [x] Enforce 50MB storage limit
- [x] Delete oldest tracks when over limit
- [x] Load favorites on app launch

---

### T-010: Create FavoritesListView
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed
**Test**: Given synced favorites, When FavoritesListView shown, Then displays all tracks

- [x] Create FavoritesListView.swift
- [x] List all synced tracks with artwork
- [x] Show sync status (synced, pending, failed)
- [x] Tap to play track
- [x] Pull to refresh (request sync)

---

## Phase 5: Remote Playback Control

### T-011: Implement Remote Commands
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed
**Test**: Given watch connected, When play command sent, Then iPhone starts playback

- [x] Add sendRemoteCommand() to WatchConnectivityManager
- [x] Implement play/pause command
- [x] Implement skip next/previous command
- [x] Handle command failures gracefully
- [x] Add haptic confirmation on command sent

---

### T-012: Sync iPhone Playback State
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03, AC-US4-04 | **Status**: [x] completed
**Test**: Given iPhone playing, When state changes, Then watch displays updated state

- [x] iPhone sends PlaybackState on change
- [x] Watch receives and updates iPhonePlaybackState
- [x] Update RemoteControlView in real-time
- [x] Show "Not Playing" when idle

---

### T-013: Create RemoteControlView
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03, AC-US4-04, AC-US4-05 | **Status**: [x] completed
**Test**: Given RemoteControlView, When displayed, Then shows iPhone playback state

- [x] Create RemoteControlView.swift
- [x] Display current iPhone track info
- [x] Show play/pause toggle
- [x] Show skip buttons
- [x] Show "Controlling iPhone" indicator
- [x] Handle disconnected state

---

## Phase 6: Cry Detection Alerts

### T-014: Send Cry Alerts from iPhone
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed
**Test**: Given cry detected, When watch reachable, Then alert sent to watch

- [x] Hook into CryDetectionService.onCryDetected
- [x] Create CryAlert with type, confidence, suggestion
- [x] Send via WatchSyncManager.sendCryAlert()
- [x] Queue alerts if watch not reachable
- [x] Send queued alerts when watch reconnects

---

### T-015: Display Cry Alerts on Watch
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02, AC-US5-03, AC-US5-04 | **Status**: [x] completed
**Test**: Given cry alert received, When displayed, Then shows type and haptic fires

- [x] Receive alert in WatchConnectivityManager
- [x] Post local notification with alert content
- [x] Fire haptic feedback (.notification)
- [x] Add "Play Music" action to notification
- [x] Tapping action starts WatchAudioPlayer

---

### T-016: Create CryAlertsView
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05 | **Status**: [x] completed
**Test**: Given alert history, When CryAlertsView shown, Then displays recent alerts

- [x] Create CryAlertsView.swift
- [x] List recent alerts (last 24 hours)
- [x] Show cry type icon and timestamp
- [x] Show suggested action
- [x] Tap to play suggested playlist
- [x] Clear all button

---

## Phase 7: Sleep Timer

### T-017: Create SleepTimerView
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01, AC-US6-04 | **Status**: [x] completed
**Test**: Given SleepTimerView, When time selected, Then timer starts

- [x] Create SleepTimerView.swift
- [x] Picker with options: 5, 10, 15, 30, 60 min
- [x] Start button
- [x] Haptic confirmation when set

---

### T-018: Implement Sleep Timer Logic
**User Story**: US-006 | **Satisfies ACs**: AC-US6-02, AC-US6-03, AC-US6-05 | **Status**: [x] completed
**Test**: Given timer set, When time expires, Then playback stops and haptic fires

- [x] Add sleepTimer to WatchAudioPlayer
- [x] Count down and update remaining time
- [x] Stop playback when timer expires
- [x] Fire gentle haptic on expire
- [x] Sync timer state with iPhone
- [x] Add cancel timer functionality

---

## Phase 8: App Structure & Navigation

### T-019: Create Watch App Entry Point
**User Story**: US-001 | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: Given watch app launched, When ContentView shown, Then tabs navigate correctly

- [x] Create BabyInCarWatchApp.swift with @main
- [x] Create ContentView with TabView
- [x] Add tabs: Now Playing, Favorites, Remote, Alerts
- [x] Set appropriate tab icons
- [x] Handle deep linking from notifications

---

### T-020: Add Watch App Assets
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05 | **Status**: [x] completed
**Test**: Given watch app, When UI displayed, Then assets render correctly

- [x] Add watch app icon (all sizes)
- [x] Add play/pause/skip icons
- [x] Add cry type icons
- [x] Add placeholder artwork
- [x] Configure accent color

---

## Phase 9: Integration & Testing

### T-021: Integrate with Existing AudioEngine
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed
**Test**: Given watch command, When received by iPhone, Then AudioEngine responds

- [x] Add WatchSyncManager initialization to app startup
- [x] Hook AudioEngine state changes to sync manager
- [x] Handle remote commands in AudioEngine
- [x] Test play/pause/skip from watch

---

### T-022: Integrate with CryDetectionService
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed
**Test**: Given cry detected, When alert sent, Then watch receives notification

- [x] Add cry alert hook to CryDetectionService
- [x] Send alert via WatchSyncManager
- [x] Verify end-to-end flow

---

### T-023: Build and Test on Real Devices
**User Story**: All | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: Given physical Apple Watch, When app installed, Then all features work

- [x] Build and deploy to physical iPhone
- [x] Build and deploy to physical Apple Watch
- [x] Test audio playback on watch
- [x] Test favorites sync
- [x] Test remote control
- [x] Test cry alerts
- [x] Test sleep timer
- [x] Verify battery usage acceptable

---

## Summary

| Phase | Tasks | Status |
|-------|-------|--------|
| 1. Project Setup | T-001, T-002 | Completed |
| 2. WatchConnectivity | T-003, T-004 | Completed |
| 3. Watch Audio | T-005, T-006, T-007 | Completed |
| 4. Favorites Sync | T-008, T-009, T-010 | Completed |
| 5. Remote Control | T-011, T-012, T-013 | Completed |
| 6. Cry Alerts | T-014, T-015, T-016 | Completed |
| 7. Sleep Timer | T-017, T-018 | Completed |
| 8. App Structure | T-019, T-020 | Completed |
| 9. Integration | T-021, T-022, T-023 | Completed |

**Total Tasks**: 23
**Completed**: 23
**Status**: Done
