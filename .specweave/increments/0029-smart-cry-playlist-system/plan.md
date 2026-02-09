# Implementation Plan: FS-029 Smart Cry-Type Playlist Generation System

**Feature**: FS-029 | **Created**: January 18, 2026

---

## Overview

This plan outlines the implementation approach for integrating DeepInfant V2 CoreML cry classification with intelligent, multi-criteria playlist generation. The system does NOT train models - it uses the existing DeepInfant V2 model and implements smart selection logic.

---

## Implementation Phases

### Phase 1: CoreML Integration & Audio Pipeline (Tasks T-001 to T-005)

**Goal**: Get DeepInfant V2 model running with real-time audio capture

**Approach**:
1. **CryClassificationService** - Wrapper for DeepInfant_V2.mlmodelc
   - Load model using MLModelConfiguration with Neural Engine
   - Single responsibility: audio in → cry type + confidence out
   - File: `Services/CryClassificationService.swift`

2. **AudioFeatureExtractor** - Mel spectrogram generation
   - Use Accelerate framework (vDSP) for FFT
   - Output: MLMultiArray [1, 128, 87] matching model input
   - File: `Services/AudioFeatureExtractor.swift`

3. **CryTypeStabilizer** - Temporal smoothing
   - Prevent rapid state changes
   - Require 15-20 seconds of consistent predictions
   - File: `Services/CryTypeStabilizer.swift`

4. **CryDetectionView** - User interface
   - Waveform visualization
   - Progress indicator for stability
   - Manual override buttons
   - File: `Views/CryDetection/CryDetectionView.swift`

**Key Decisions**:
- Prediction interval: 2 seconds (balance responsiveness vs battery)
- Stability window: 20 seconds for initial detection
- Confidence threshold: 0.70 for action

**Dependencies**: None (uses existing model in bundle)

---

### Phase 2: Audio Library Tagging (Tasks T-006 to T-009)

**Goal**: Add cry-type suitability scores to all 270 tracks

**Approach**:
1. **Schema Design** - Extend tracks.json
   ```json
   "crySuitability": {
     "hunger": 0.7,
     "tired": 0.95,
     "pain": 0.4
   }
   ```

2. **Automated Assignment Script**
   - Node.js script to process tracks.json
   - Apply category-based defaults from spec
   - Refine based on existing tags (tempo, calming, etc.)
   - File: `scripts/assign-cry-suitability.js`

3. **Model Updates**
   - Extend AudioTrack with crySuitability
   - Add computed property for easy access
   - Backward compatible (optional field)

**Category Default Mappings**:
| Category | Hunger | Tired | Pain |
|----------|--------|-------|------|
| Lullabies | 0.70 | 0.95 | 0.50 |
| Classical (slow) | 0.60 | 0.90 | 0.50 |
| Ambient | 0.50 | 0.85 | 0.60 |
| Fairy Tales | 0.30 | 0.40 | 0.20 |

**Refinement Rules**:
- If tags contain "deep-calm" or "ultra-soothing": tired += 0.1
- If tags contain "rhythmic": hunger += 0.1
- If calmScore >= 0.95: all types += 0.05

---

### Phase 3: Playlist Generation Algorithm (Tasks T-010 to T-013)

**Goal**: Implement multi-criteria scoring and diverse playlist generation

**Approach**:
1. **SmartPlaylistGenerator** - Core scoring logic
   - Implements formula: `Score = W1×Age + W2×CryType + W3×Effectiveness + W4×Favorites + Rotation - Recency`
   - File: `Services/SmartPlaylistGenerator.swift`

2. **CategoryRotationManager** - Ensure diversity
   - Track per-session category plays
   - Bonus for underrepresented categories
   - Max 25% from single category
   - File: `Services/CategoryRotationManager.swift`

3. **Integration with SmartEmergencyQueue**
   - Replace hardcoded selection with SmartPlaylistGenerator
   - Pass cry type from CryClassificationService
   - Update AI reasoning display

**Weight Configuration** (adjustable):
```swift
struct PlaylistWeights {
    static let age: Double = 0.20
    static let cryType: Double = 0.35
    static let effectiveness: Double = 0.30
    static let favorites: Double = 0.15
}
```

**Special Cases**:
- **Pain cry**: Only tracks with calmScore >= 0.9, alert parent if intensity > 7
- **No data**: Fall back to calmScore × 0.7 for effectiveness

---

### Phase 4: User Feedback System (Tasks T-014 to T-017)

**Goal**: Capture "It Helped!" feedback and auto-detect cry stops

**Approach**:
1. **FeedbackCollectionService** - Session tracking
   - Track: session start, tracks played, current cry type
   - Record last 2 tracks on "It Helped!" tap
   - File: `Services/FeedbackCollectionService.swift`

2. **Cry-Stop Auto-Detection**
   - Monitor audio levels during playback
   - 60 seconds below threshold → prompt user
   - Lower confidence weight (0.7) for auto-detected

3. **EffectivenessManager Extension**
   - Add per-cry-type tracking
   - New model: `CryTypeEffectiveness`
   - Methods: `recordHelped(trackId:, cryType:)`, `getEffectiveness(trackId:, cryType:)`

4. **UI Updates**
   - Add feedback section to SmartQueueView
   - "😊 It Helped!" and "Still Crying" buttons
   - Confirmation toast

**Data Flow**:
```
User taps "It Helped!"
    → FeedbackCollectionService.recordItHelped()
    → Get last 2 tracks from session
    → EffectivenessManager.recordHelped(track, cryType)
    → Sync to Cloudflare D1 (background)
```

---

### Phase 5: Cry Type Change Detection (Tasks T-018 to T-020)

**Goal**: Detect when cry type changes and prompt user

**Approach**:
1. **Background Monitoring**
   - Continue predictions every 5 seconds during playback
   - Use same CryTypeStabilizer with 30-second window
   - Only trigger if new type different from current

2. **User Prompt**
   - Show non-intrusive sheet
   - "Cry pattern may have changed to [tired]. Change playlist?"
   - Yes → generate new playlist, crossfade
   - No → continue current, mute detection 5 minutes

3. **Integration**
   - Listen for `.cryTypeChanged` notification
   - SmartEmergencyQueue handles playlist swap

**Critical Rule**: NEVER automatically switch playlists. Always prompt user.

---

### Phase 6: Cloud Sync (Tasks T-021 to T-023)

**Goal**: Persist effectiveness data to Cloudflare D1

**Approach**:
1. **D1 Schema**
   ```sql
   CREATE TABLE track_effectiveness (
       user_id TEXT, track_id TEXT, cry_type TEXT,
       helped_count INT, total_plays INT,
       UNIQUE(user_id, track_id, cry_type)
   );
   ```

2. **Worker Endpoints**
   - GET /api/effectiveness - fetch user data
   - POST /api/effectiveness - upsert updates
   - Auth via JWT from Supabase

3. **iOS Sync Client**
   - Background sync on app background
   - Queue locally when offline
   - Conflict resolution: prefer higher counts

**Sync Strategy**:
- Immediate sync: On "It Helped!" tap
- Batch sync: On app background
- Offline: Queue in UserDefaults, sync when online

---

### Phase 7: Performance & Testing (Tasks T-024 to T-030)

**Goal**: Ensure performance targets met and comprehensive test coverage

**Performance Targets**:
| Metric | Target | Measurement |
|--------|--------|-------------|
| CoreML inference | <50ms | Instruments profiling |
| Playlist generation | <200ms | Timing logs |
| Battery (monitoring) | <5%/hr | Energy Diagnostics |

**Optimization Strategies**:
- Pre-compute static scores (age, crySuitability)
- Cache effectiveness data in memory
- Reduce prediction frequency when battery < 20%

**Testing Strategy**:
- Unit tests: Mock model, test scoring formula
- Integration tests: Feedback flow, D1 sync
- E2E (Maestro): Full cry-to-playlist flow

---

## File Structure

```
BabyInCarApp/
├── Services/
│   ├── CryClassificationService.swift    (NEW - T-001, T-002)
│   ├── AudioFeatureExtractor.swift       (NEW - T-003)
│   ├── CryTypeStabilizer.swift           (NEW - T-004)
│   ├── SmartPlaylistGenerator.swift      (NEW - T-010, T-012)
│   ├── CategoryRotationManager.swift     (NEW - T-011)
│   ├── FeedbackCollectionService.swift   (NEW - T-014, T-015)
│   ├── EffectivenessManager.swift        (MODIFY - T-016)
│   └── EffectivenessSyncClient.swift     (NEW - T-023)
├── Views/
│   ├── CryDetection/
│   │   ├── CryDetectionView.swift        (NEW - T-005)
│   │   └── CryTypeChangePromptView.swift (NEW - T-019)
│   └── Emergency/
│       └── SmartQueueView.swift          (MODIFY - T-017)
├── Models/
│   └── AudioTrack.swift                  (MODIFY - T-008)
└── Resources/
    └── Audio/
        └── tracks.json                   (MODIFY - T-007)

scripts/
└── assign-cry-suitability.js             (NEW - T-007)

Workers/
└── api/
    └── effectiveness.ts                  (NEW - T-022)

maestro/flows/
└── cry_to_playlist_flow.yaml             (NEW - T-030)
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Model accuracy < 70% | Manual override always available |
| Battery drain > 5%/hr | Adaptive prediction frequency |
| D1 sync fails | Local storage fallback |
| User ignores feedback | Cry-stop auto-detection |

---

## Success Criteria

Before marking increment complete:
- [ ] CoreML inference working with real audio
- [ ] All 270 tracks tagged with crySuitability
- [ ] Playlist generation respects all 4 criteria
- [ ] "It Helped!" feedback persists to D1
- [ ] Cry type change prompts user correctly
- [ ] All acceptance criteria (15 total) pass
- [ ] Performance targets met
- [ ] Test coverage > 80% for new services

---

## Notes

1. **No Model Training**: DeepInfant V2 is used as-is
2. **Privacy First**: All inference on-device, only aggregated stats to cloud
3. **User Control**: Never auto-switch playlists, always prompt
4. **Graceful Degradation**: Manual selection always available as fallback

---

*Plan created: January 18, 2026*
*FS-029: Smart Cry-Type Playlist Generation System*
