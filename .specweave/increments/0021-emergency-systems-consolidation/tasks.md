# Tasks: Emergency Systems Consolidation

**Increment**: 0021-emergency-systems-consolidation
**Total Tasks**: 18
**Estimated Effort**: 1-2 days

---

## Phase 1: Code Deprecation

### T-001: Add deprecation annotation to EmergencyQueueManager
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed

Add `@available(*, deprecated)` annotation to EmergencyQueueManager class to trigger compiler warnings when used.

**File**: `BabyInCarApp/BabyInCarApp/Services/EmergencyQueueManager.swift`

**Implementation**:
```swift
@available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead. See ADR-0125.")
@MainActor
class EmergencyQueueManager: ObservableObject { ... }
```

**Test**: Given EmergencyQueueManager.swift exists -> When compiled -> Then deprecation warning is shown in Xcode

---

### T-002: Add deprecation annotation to EmergencyQueueView
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 | **Status**: [x] completed

Add `@available(*, deprecated)` annotation to EmergencyQueueView struct to trigger compiler warnings when used.

**File**: `BabyInCarApp/BabyInCarApp/Views/EmergencyQueueView.swift`

**Implementation**:
```swift
@available(*, deprecated, message: "Use SmartQueueView instead. See ADR-0125.")
struct EmergencyQueueView: View { ... }
```

**Test**: Given EmergencyQueueView.swift exists -> When compiled -> Then deprecation warning is shown in Xcode

---

### T-003: Remove EmergencyQueueManager reference from SmartCryResponseEngine
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02 | **Status**: [x] completed

Remove the unused `emergencyQueueManager` property from SmartCryResponseEngine.

**File**: `BabyInCarApp/BabyInCarApp/Services/SmartCryResponseEngine.swift`

**Action**: Remove line 44 (`@Published var emergencyQueueManager: EmergencyQueueManager?`)

**Verification**:
```bash
grep -n "EmergencyQueueManager" BabyInCarApp/BabyInCarApp/Services/SmartCryResponseEngine.swift
# Expected: No matches
```

**Test**: Given SmartCryResponseEngine.swift -> When grepping for EmergencyQueueManager -> Then zero matches found

---

## Phase 2: Production Reference Cleanup

### T-004: Verify feature parity between SmartEmergencyQueue and EmergencyQueueManager
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03 | **Status**: [x] completed

Document that all EmergencyQueueManager functionality exists in SmartEmergencyQueue.

**Parity Checklist**:
| Feature | EmergencyQueueManager | SmartEmergencyQueue |
|---------|----------------------|---------------------|
| Start session | startSession() | activateForCry() |
| Stop session | stopSession() | deactivate() |
| Track queue | currentQueue | upcomingTracks |
| Playback state | isPlaying | isPlaying |
| API calls | APIClient | Internal + AI |

**Test**: Given feature checklist -> When comparing both classes -> Then SmartEmergencyQueue has all features (plus more)

---

### T-005: Verify no production views reference EmergencyQueueView
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02 | **Status**: [x] completed

Ensure EmergencyQueueView is not used in any production view files.

**Verification**:
```bash
grep -r "EmergencyQueueView" BabyInCarApp/BabyInCarApp/Views/ --include="*.swift" | grep -v "//.*EmergencyQueueView"
# Expected: No matches (or only comments)
```

**Test**: Given Views directory -> When grepping for EmergencyQueueView -> Then zero production usages found

---

### T-006: Verify SmartCryResponseEngine uses only SmartEmergencyQueue
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 | **Status**: [x] completed

Confirm SmartCryResponseEngine exclusively uses SmartEmergencyQueue for queue management.

**Verification**:
```bash
grep -n "SmartEmergencyQueue" BabyInCarApp/BabyInCarApp/Services/SmartCryResponseEngine.swift
# Expected: Multiple matches showing SmartEmergencyQueue.shared usage
```

**Test**: Given SmartCryResponseEngine -> When cry is detected -> Then SmartEmergencyQueue.shared is triggered

---

### T-007: Add inline documentation to SmartEmergencyQueue
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02 | **Status**: [x] completed

Add documentation header explaining SmartEmergencyQueue replaces legacy EmergencyQueueManager.

**File**: `BabyInCarApp/BabyInCarApp/Services/SmartEmergencyQueue.swift`

**Implementation**:
```swift
/// Smart queue that builds cry-type specific playlists using real audio library tracks.
/// This is the Spotify-like queue experience for emergency cry response.
///
/// NOTE: This replaces the legacy EmergencyQueueManager. See ADR-0126.
/// - SmartEmergencyQueue: AI-powered track selection, queue management
/// - SmartQueueView: Spotify-like UI with animations and gestures
@MainActor
class SmartEmergencyQueue: ObservableObject { ... }
```

**Test**: Given SmartEmergencyQueue.swift -> When reading file header -> Then documentation explains it replaces legacy system

---

## Phase 3: Test Migration

### T-008: Preserve mock compatibility for EmergencyQueueManager
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04 | **Status**: [x] completed

Ensure any existing mock objects for EmergencyQueueManager still compile (even if deprecated).

**Verification**:
```bash
grep -r "MockEmergencyQueue\|EmergencyQueueManager" BabyInCarApp/BabyInCarAppTests/ --include="*.swift"
# Document any mocks found and verify they compile
```

**Test**: Given test suite -> When building tests -> Then all mocks compile (with deprecation warnings acceptable)

---

### T-009: Update EmergencyQueueSnapshotTests to test SmartQueueView
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04, AC-US2-03 | **Status**: [x] completed

Migrate snapshot tests from EmergencyQueueView to SmartQueueView.

**File**: `BabyInCarApp/BabyInCarAppTests/Snapshots/EmergencyQueueSnapshotTests.swift`

**Actions**:
1. Rename file to `SmartQueueSnapshotTests.swift`
2. Update class name
3. Update test methods to use SmartQueueView
4. Create SmartEmergencyQueue.mock for test data

**Test**: Given snapshot test file -> When running tests -> Then SmartQueueView is rendered and compared

---

### T-010: Create SmartEmergencyQueue.mock extension for testing
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01 | **Status**: [x] completed

Create a mock factory extension for SmartEmergencyQueue for use in tests.

**File**: `BabyInCarApp/BabyInCarAppTests/Mocks/SmartEmergencyQueueMock.swift` (or extension)

**Implementation**:
```swift
extension SmartEmergencyQueue {
    static var mock: SmartEmergencyQueue {
        let queue = SmartEmergencyQueue()
        queue.isActive = true
        queue.currentTrack = QueueTrack.mock
        queue.upcomingTracks = [QueueTrack.mock]
        queue.isPlaying = true
        queue.progress = 0.45
        return queue
    }
}
```

**Test**: Given SmartEmergencyQueue.mock -> When used in tests -> Then valid mock state is provided

---

### T-011: Re-record snapshot baselines for SmartQueueView
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03 | **Status**: [x] completed

Generate new snapshot baselines using SmartQueueView.

**Actions**:
1. Set `isRecording = true` in snapshot test setUp()
2. Run snapshot tests to generate baselines
3. Set `isRecording = false`
4. Verify snapshots look correct
5. Commit new snapshot images

**Test**: Given SmartQueueView -> When snapshot test runs -> Then baseline matches recorded image

---

### T-012: Update EffectivenessTrackingTests to use SmartEmergencyQueue
**User Story**: US-004 | **Satisfies ACs**: AC-US4-02 | **Status**: [x] completed

Verify and update EffectivenessTrackingTests to use SmartEmergencyQueue.

**File**: `BabyInCarApp/BabyInCarAppTests/Services/EffectivenessTrackingTests.swift`

**Verification**:
```bash
grep -n "EmergencyQueueManager\|SmartEmergencyQueue" BabyInCarApp/BabyInCarAppTests/Services/EffectivenessTrackingTests.swift
```

**Test**: Given EffectivenessTrackingTests -> When running tests -> Then all tests pass using SmartEmergencyQueue

---

### T-013: Update PlaybackVerificationTests to use SmartEmergencyQueue
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01 | **Status**: [x] completed

Verify and update PlaybackVerificationTests to use SmartEmergencyQueue.

**File**: `BabyInCarApp/BabyInCarAppTests/Integration/PlaybackVerificationTests.swift`

**Test**: Given PlaybackVerificationTests -> When running tests -> Then all tests pass using SmartEmergencyQueue

---

### T-014: Verify no test files reference deprecated classes
**User Story**: US-004 | **Satisfies ACs**: AC-US4-04 | **Status**: [x] completed

Ensure test files do not reference EmergencyQueueManager or EmergencyQueueView (except for intentional deprecation tests).

**Verification**:
```bash
grep -r "EmergencyQueueManager\|EmergencyQueueView" BabyInCarApp/BabyInCarAppTests/ --include="*.swift" | grep -v "deprecated\|// Legacy"
# Expected: Zero matches or only intentional legacy compatibility tests
```

**Test**: Given test directory -> When grepping for deprecated classes -> Then zero unexpected references found

---

## Phase 4: E2E Verification

### T-015: Verify AI cry detection triggers SmartQueueView overlay
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed

Confirm that cry detection activates SmartQueueView in CryDetectionView.

**Verification**: Check CryDetectionView.swift line 91 for SmartQueueView usage.

**Test**: Given CryDetectionView in monitoring mode -> When cry is detected -> Then SmartQueueView overlay is displayed

---

### T-016: Run all Maestro E2E flows
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03 | **Status**: [x] completed

Execute all Maestro E2E test flows to verify no regressions.

**Command**:
```bash
~/.maestro/bin/maestro test maestro/flows/
```

**Specific flows to verify**:
- `smart_queue_e2e_flow.yaml`
- `emergency_playlist_flow.yaml`
- `emergency_baby_calm_flow.yaml`

**Test**: Given Maestro flows -> When executed -> Then all flows pass

---

## Phase 5: Documentation

### T-017: Update CLAUDE.md with emergency system architecture note
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed

Add section to CLAUDE.md explaining SmartQueue is the canonical emergency system.

**File**: `/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/CLAUDE.md`

**Content to add**:
```markdown
## Emergency System Architecture

**Canonical System**: SmartQueue (SmartEmergencyQueue + SmartQueueView)

The emergency cry response uses a single system:
- `SmartEmergencyQueue.swift` - AI-powered queue management
- `SmartQueueView.swift` - Spotify-like queue UI

Legacy files (EmergencyQueueManager, EmergencyQueueView) are deprecated.
See ADR-0126 for details.
```

**Test**: Given CLAUDE.md -> When reading -> Then emergency architecture section exists

---

### T-018: Add deprecation notices to legacy files with migration path
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03, AC-US5-04 | **Status**: [x] completed

Add comprehensive header comments to deprecated files explaining migration.

**Files**:
- `EmergencyQueueManager.swift`
- `EmergencyQueueView.swift`

**Header format**:
```swift
// =============================================================================
// DEPRECATED: This file is deprecated as of FS-021 (Emergency Systems Consolidation)
//
// Migration: Use SmartEmergencyQueue.shared instead of EmergencyQueueManager
//            Use SmartQueueView instead of EmergencyQueueView
//
// Reason: Duplicate functionality. SmartQueue provides superior Spotify-like UX
//         with AI-powered track selection.
//
// See: ADR-0125 (Deprecation Strategy), ADR-0126 (SmartQueue Canonical System)
// =============================================================================
```

**Test**: Given deprecated files -> When reading headers -> Then clear deprecation notice and migration path is documented

---

## Summary

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1: Code Deprecation | T-001, T-002, T-003 | [x] completed |
| Phase 2: Reference Cleanup | T-004, T-005, T-006, T-007 | [x] completed |
| Phase 3: Test Migration | T-008, T-009, T-010, T-011, T-012, T-013, T-014 | [x] completed |
| Phase 4: E2E Verification | T-015, T-016 | [x] completed |
| Phase 5: Documentation | T-017, T-018 | [x] completed |

**Total**: 18 tasks
**Estimated**: 1-2 days

## Acceptance Criteria Mapping

| AC | Task(s) |
|----|---------|
| AC-US1-01 | T-001 |
| AC-US1-02 | T-003 |
| AC-US1-03 | T-004 |
| AC-US1-04 | T-008 |
| AC-US2-01 | T-002 |
| AC-US2-02 | T-005 |
| AC-US2-03 | T-009, T-011 |
| AC-US2-04 | T-009 |
| AC-US3-01 | T-006 |
| AC-US3-02 | (Covered by existing SmartCryResponseEngine tests) |
| AC-US3-03 | T-015 |
| AC-US3-04 | (Covered by existing integration tests) |
| AC-US4-01 | T-010, T-013 |
| AC-US4-02 | T-012 |
| AC-US4-03 | T-016 |
| AC-US4-04 | T-014 |
| AC-US5-01 | T-017 |
| AC-US5-02 | T-007 |
| AC-US5-03 | T-018 |
| AC-US5-04 | T-018 |
