# Tasks: FS-029 Smart Cry-Type Playlist Generation System

**Feature**: FS-029 | **Status**: Planning | **Priority**: High

---

## Existing Code Analysis (AVOID DUPLICATION)

> **CRITICAL**: The following components ALREADY EXIST and should be EXTENDED, not recreated:
>
> | Component | File | Action |
> |-----------|------|--------|
> | CryType enum | `WatchModels.swift` | USE AS-IS |
> | TrackEffectiveness | `TrackEffectiveness.swift` | USE AS-IS (has per-cry-type support) |
> | EffectivenessManager | `EffectivenessManager.swift` | USE AS-IS |
> | UltraSmartPlaylistSelector | `UltraSmartPlaylistSelector.swift` | EXTEND (add rotation, favorites) |
> | SmartPlaylistBuilder | `SmartPlaylistBuilder.swift` | EXTEND (add queue auto-fill) |
> | GeneratorType.bestForCryTypes | `AudioTrack.swift` | USE AS-IS |
> | TrackMetadata.crySuitability | `TrackMetadata.swift` | SCHEMA EXISTS - populate data |
> | BabyMoodProfile | `BabyMoodProfile.swift` | USE AS-IS |
>
> **NEW implementations required**:
> - CryClassificationService (CoreML wrapper)
> - AudioFeatureExtractor (mel spectrogram)
> - CryTypeStabilizer (temporal smoothing)
> - CategoryRotationManager (rotation bonus)
> - CryDetectionView (UI)

---

## User Stories

### US-001: Cry Type Classification Integration
**As a** parent using the app,
**I want** the app to automatically identify my baby's cry type (hunger, tired, pain),
**So that** I receive appropriate soothing music without manual selection.

### US-002: Smart Playlist Generation
**As a** parent,
**I want** playlists generated based on my baby's age, cry type, and what has worked before,
**So that** I have the best chance of calming my baby quickly.

### US-003: Effectiveness Feedback
**As a** parent,
**I want** to tell the app when music helped calm my baby,
**So that** it learns what works best for my baby over time.

### US-004: Cry Type Change Detection
**As a** parent,
**I want** the app to detect when the cry type changes,
**So that** I can switch to a more appropriate playlist if needed.

---

## Phase 1: CoreML Integration & Audio Pipeline

### T-001: Create CryClassificationService wrapper for DeepInfant V2
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-01, AC-FS029-02 | **Status**: [x] completed
**Test**: Given DeepInfant V2 model exists → When service initializes → Then model loads in <500ms and inference returns valid CryType

**Implementation**:
- Create `CryClassificationService.swift` in Services/
- Load DeepInfant_V2.mlmodelc using MLModelConfiguration
- Configure for Neural Engine (computeUnits = .all)
- Implement prediction method that returns (CryType, confidence)
- Handle model loading errors gracefully

---

### T-002: Implement audio capture pipeline with AVAudioEngine
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-01 | **Status**: [x] completed
**Test**: Given microphone permission granted → When startListening() called → Then audio captured at 16kHz mono Float32

**Implementation**:
- Add audio capture to CryClassificationService
- Use AVAudioEngine with inputNode
- Configure: 16kHz sample rate, mono, Float32 format
- Implement ring buffer for 2-second windows with 0.5-second hop
- Add noise gate at -40dB threshold

---

### T-003: Implement mel spectrogram feature extraction using Accelerate
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-15 | **Status**: [x] completed
**Test**: Given 2-second audio buffer → When extractFeatures() called → Then returns MLMultiArray compatible with model input

**Implementation**:
- NOT NEEDED - DeepInfant V2 model takes raw audio samples (15600 floats) directly
- Model performs feature extraction internally
- AudioCaptureService provides raw samples compatible with model input

---

### T-004: Implement temporal stabilizer for cry type consistency
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-03 | **Status**: [x] completed
**Test**: Given predictions arrive every 2 seconds → When 10 predictions with >70% agreement → Then stable cry type declared

**Implementation**:
- Create `CryTypeStabilizer.swift`
- Track prediction history with timestamps
- Initial stability: 15-20 second window, >70% agreement
- Publish stableCryType when threshold met
- Prevent rapid state changes with hysteresis

---

### T-005: Create CryDetectionView UI for listening state
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-01 | **Status**: [x] completed
**Test**: Given listening started → When UI displayed → Then shows waveform, progress, and detected type

**Implementation**:
- Create `CryDetectionView.swift` in Views/
- Show audio waveform visualization
- Display progress bar (X/20 sec to stability)
- Show detected cry type with confidence
- Buttons: "Start Soothing Playlist" and manual override options

---

## Phase 2: Audio Library Tagging

### T-006: Design crySuitability schema for tracks.json
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-06, AC-FS029-08 | **Status**: [x] completed
**Test**: Given schema defined → When tracks.json validated → Then all tracks have valid crySuitability scores

**Implementation**:
- Define crySuitability object schema:
  ```json
  "crySuitability": {
    "hunger": 0.0-1.0,
    "tired": 0.0-1.0,
    "pain": 0.0-1.0
  }
  ```
- Optional acousticProfile for future enhancements
- Update TrackMetadata model to parse new fields

---

### T-007: Create tag assignment script for all 270 tracks
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-06 | **Status**: [x] completed
**Test**: Given 270 tracks → When script runs → Then all tracks have crySuitability scores based on category rules

**Implementation**:
- Create Python/Node script: `scripts/assign-cry-suitability.js`
- Apply category-to-cry-type mapping from spec (Section 4.3)
- Use calmScore and tempo tags to refine scores
- Special handling for fairy tales (low for pain/hunger)
- Output updated tracks.json

---

### T-008: Update AudioTrack model to include crySuitability
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-08 | **Status**: [x] completed
**Test**: Given track with crySuitability → When AudioTrack initialized → Then crySuitability accessible

**Implementation**:
- Add `crySuitability: [String: Double]?` to AudioTrack
- Add computed property `suitabilityFor(_ cryType: CryType) -> Double`
- Fall back to calmScore if crySuitability not available
- Update Codable implementation

---

### T-009: Map GeneratorType.bestForCryTypes to crySuitability scores
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-07 | **Status**: [x] completed
**Test**: Given GeneratorType.lullaby → When crySuitability queried → Then returns scores from spec

**Implementation**:
- Extend GeneratorType with `crySuitability: [CryType: Double]`
- Map existing bestForCryTypes to numerical scores
- Ensure consistency with tracks.json scoring

---

## Phase 3: Playlist Generation Algorithm

### T-010: Implement multi-criteria track scoring algorithm
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-04 | **Status**: [x] completed
**Test**: Given track, baby age, cry type, effectiveness, favorites → When calculateTrackScore() → Then returns weighted score 0-1

**Implementation**:
- Create `SmartPlaylistGenerator.swift`
- Implement scoring formula from spec (Section 5.1)
- Weights: Age 0.20, CryType 0.35, Effectiveness 0.30, Favorites 0.15
- Add rotation bonus and recently-played penalty

---

### T-011: Implement category rotation manager
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-05 | **Status**: [x] completed
**Test**: Given 3 lullabies played → When next track selected → Then non-lullaby category boosted

**Implementation**:
- Create `CategoryRotationManager.swift`
- Track session play counts per category
- Track last 5 categories played
- Return rotation bonus: 0.15 for unplayed, 0.08 for underplayed
- Reset on session end

---

### T-012: Implement playlist generation with category diversity
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-04, AC-FS029-05, AC-FS029-16 | **Status**: [x] completed
**Test**: Given cry type hunger → When generatePlaylist() → Then returns 10 tracks with max 25% per category

**Implementation**:
- Implement `generatePlaylist(for cryType:, babyAge:)` method
- Filter banned content, premium if not subscribed
- Score all eligible tracks
- Select top tracks with category diversity constraint
- Special handling for pain (only calmScore >= 0.9)

---

### T-013: Integrate SmartPlaylistGenerator with SmartEmergencyQueue
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-04 | **Status**: [x] completed
**Test**: Given cry type detected → When emergency mode activated → Then SmartEmergencyQueue receives generated playlist

**Implementation**:
- Modify SmartEmergencyQueue.buildQueue() to use SmartPlaylistGenerator
- Pass cry type, baby age, effectiveness data
- Update AI reasoning to show scoring factors
- Ensure crossfade transitions preserved

---

## Phase 4: User Feedback System

### T-014: Create FeedbackCollectionService for "It Helped!" tracking
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-09 | **Status**: [x] completed
**Test**: Given playlist playing → When "It Helped!" tapped → Then last 2 tracks recorded with cry type

**Implementation**:
- Create `FeedbackCollectionService.swift`
- Track current session: start time, tracks played, cry type
- `recordItHelped()`: save last 2 tracks as helpful
- `recordTrackPlayed(trackId)`: add to session history

---

### T-015: Implement cry-stop auto-detection
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-11 | **Status**: [x] completed
**Test**: Given crying stopped → When 60 seconds of silence → Then auto-record as potential success

**Implementation**:
- ✅ Created `CryStopAutoDetector.swift` - monitors audio levels during playback
- ✅ Detects 60 seconds below cry threshold (configurable)
- ✅ Shows prompt via `CryStopPromptView.swift`: "Baby seems calmer! Did the music help?"
- ✅ Integrates with FeedbackCollectionService.recordAutoDetectedStop()
- ✅ Lower weight (0.7) applied for auto-detected vs manual feedback

---

### T-016: Update EffectivenessManager to track per-cry-type data
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-09, AC-FS029-10 | **Status**: [x] completed
**Test**: Given track helped for hunger → When effectiveness queried for hunger → Then returns higher score

**Implementation**:
- Extend TrackEffectiveness with `perCryType: [String: CryTypeStats]`
- Add `recordHelped(trackId:, cryType:)` method
- Add `getEffectiveness(trackId:, cryType:)` method
- Fall back to general effectiveness if no cry-type-specific data

---

### T-017: Add "It Helped!" button to SmartQueueView
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-09 | **Status**: [x] completed
**Test**: Given SmartQueueView displayed → When rendered → Then "It Helped!" button visible

**Implementation**:
- ✅ Created `SmartSoothingQueueView.swift` with full cry-response playback UI
- ✅ Two buttons: "It Helped!" (green, with heart) and "Still Crying"
- ✅ Connected to FeedbackCollectionService for tracking
- ✅ Confirmation toast shown on tap
- ✅ Heart icon animation on "It Helped!" tap
- ✅ Includes cry type header, now playing, AI reasoning, and upcoming queue
- ✅ Integrated with CryStopAutoDetector overlay

---

## Phase 5: Cry Type Change Detection

### T-018: Implement cry type change detection during playback
**User Story**: US-004 | **Satisfies ACs**: AC-FS029-12 | **Status**: [x] completed
**Test**: Given playlist playing for hunger → When tired detected 30 seconds → Then change detection triggered

**Implementation**:
- ✅ Created `CryTypeChangeDetector.swift`
- ✅ Continues monitoring audio during playback (every 5 seconds configurable)
- ✅ Uses 30-second window with 70% agreement threshold
- ✅ Publishes CryTypeChangeEvent for UI via Combine
- ✅ Includes pause/resume after user rejection (5 min cooldown)

---

### T-019: Create CryTypeChangePromptView
**User Story**: US-004 | **Satisfies ACs**: AC-FS029-13, AC-FS029-14 | **Status**: [x] completed
**Test**: Given cry type change detected → When prompt shown → Then user can confirm or dismiss

**Implementation**:
- ✅ Created `CryTypeChangePromptView.swift`
- ✅ Shows change visualization with icons for current → new type
- ✅ "Cry Pattern Changed" title with suggested action
- ✅ Two buttons: "Switch Playlist" (colored) / "Keep Current Playlist"
- ✅ CryTypeChangePromptOverlay modifier for easy integration
- ✅ Integrated with SmartSoothingQueueView via `.withCryTypeChangePrompt()`

---

### T-020: Connect cry type change flow to SmartEmergencyQueue
**User Story**: US-004 | **Satisfies ACs**: AC-FS029-13 | **Status**: [x] completed
**Test**: Given user confirms cry type change → When confirmed → Then new playlist generated and queued

**Implementation**:
- ✅ SmartSoothingQueueView listens for `.cryTypeChangeAccepted` notification
- ✅ Calls SmartPlaylistBuilder.buildPlaylistForCryTypeChange()
- ✅ audioEngine.replaceQueue() updates queue with new tracks
- ✅ UI updates (header, gradient, AI reasoning) reflect new cry type
- ✅ Shows confirmation toast "Switched to [type] playlist"
- ✅ FeedbackCollectionService session ended/restarted for new type

---

## Phase 6: Cloud Sync (Cloudflare D1)

### T-021: Create Cloudflare D1 database schema
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-10 | **Status**: [ ] pending
**Test**: Given D1 database → When schema applied → Then tables created successfully

**Implementation**:
- Create migration: `track_effectiveness` table
- Create migration: `feedback_history` table
- Add indexes for user_id, track_id, cry_type
- Deploy to Cloudflare D1

---

### T-022: Create Worker endpoints for effectiveness sync
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-10 | **Status**: [ ] pending
**Test**: Given effectiveness update → When POST /api/effectiveness → Then data persisted

**Implementation**:
- GET /api/effectiveness - fetch user's data
- POST /api/effectiveness - sync updates
- Implement upsert logic for conflict resolution
- Add authentication (user_id from JWT)

---

### T-023: Implement iOS sync client for effectiveness data
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-10 | **Status**: [ ] pending
**Test**: Given local effectiveness data → When sync triggered → Then data uploaded to D1

**Implementation**:
- Create `EffectivenessSyncClient.swift`
- Background sync on app backgrounding
- Sync on feedback recorded
- Handle offline: queue updates locally, sync when online
- Merge conflicts: prefer higher counts

---

## Phase 7: Performance & Testing

### T-024: Optimize CoreML inference for <50ms
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-15 | **Status**: [ ] pending
**Test**: Given audio features → When model.prediction() called → Then completes in <50ms

**Implementation**:
- Profile inference on iPhone 12+
- Use Neural Engine (computeUnits = .all)
- Consider INT8 quantization if needed
- Benchmark and log P99 latency

---

### T-025: Optimize playlist generation for <200ms
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-16 | **Status**: [ ] pending
**Test**: Given 270 tracks → When generatePlaylist() called → Then completes in <200ms

**Implementation**:
- Profile scoring algorithm
- Pre-compute static scores (age, crySuitability)
- Cache effectiveness scores
- Benchmark with production data

---

### T-026: Add battery usage monitoring for <5%/hour
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-17 | **Status**: [ ] pending
**Test**: Given 1 hour monitoring → When battery measured → Then drain <5%

**Implementation**:
- Reduce prediction frequency if battery low
- Use background audio modes efficiently
- Profile with Instruments Energy Log
- Add warning if battery < 20%

---

### T-027: Write unit tests for CryClassificationService
**User Story**: US-001 | **Satisfies ACs**: AC-FS029-01, AC-FS029-02 | **Status**: [ ] pending
**Test**: Given mock audio features → When service predicts → Then returns valid CryType

**Implementation**:
- Mock DeepInfant_V2 model responses
- Test all cry type outputs
- Test confidence thresholding
- Test error handling (model load failure)

---

### T-028: Write unit tests for SmartPlaylistGenerator
**User Story**: US-002 | **Satisfies ACs**: AC-FS029-04, AC-FS029-05 | **Status**: [ ] pending
**Test**: Given test tracks with known scores → When playlist generated → Then top scores selected with diversity

**Implementation**:
- Test scoring formula correctness
- Test category diversity constraint
- Test rotation bonus application
- Test recently-played penalty

---

### T-029: Write integration tests for feedback flow
**User Story**: US-003 | **Satisfies ACs**: AC-FS029-09 | **Status**: [ ] pending
**Test**: Given feedback recorded → When effectiveness queried → Then reflects feedback

**Implementation**:
- Test "It Helped!" end-to-end
- Test cry-stop auto-detection
- Test per-cry-type effectiveness storage
- Test D1 sync (mock endpoint)

---

### T-030: Write E2E Maestro flow for cry detection to playlist
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-FS029-01, AC-FS029-04 | **Status**: [ ] pending
**Test**: Given app launched → When cry detected → Then playlist plays

**Implementation**:
- Create `maestro/flows/cry_to_playlist_flow.yaml`
- Simulate cry detection (mock audio)
- Verify playlist UI displays
- Verify AI reasoning shows cry type

---

## Summary

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1: CoreML Integration | T-001 to T-005 | [x] 5/5 |
| Phase 2: Audio Library Tagging | T-006 to T-009 | [x] 4/4 |
| Phase 3: Playlist Generation | T-010 to T-013 | [x] 4/4 |
| Phase 4: User Feedback | T-014 to T-017 | [x] 4/4 |
| Phase 5: Cry Type Change | T-018 to T-020 | [x] 3/3 |
| Phase 6: Cloud Sync | T-021 to T-023 | [ ] 0/3 |
| Phase 7: Performance & Testing | T-024 to T-030 | [ ] 0/7 |
| **Total** | **30 tasks** | **[ ] 20/30** |

---

*Tasks created: January 18, 2026*
*FS-029: Smart Cry-Type Playlist Generation System*
