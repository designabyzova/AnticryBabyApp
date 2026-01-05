---
increment: 0021-emergency-systems-consolidation
title: "Emergency Systems Consolidation"
priority: P1
status: completed
type: refactor
created: 2026-01-04
epic: FS-021
test_mode: test-after
coverage_target: 80
estimated_effort: 1-2 weeks
started: 2026-01-04
---

# Feature: Emergency Systems Consolidation

## Overview

**Problem Statement**: The codebase has duplicate emergency queue implementations causing developer confusion, maintenance burden, and potential bugs. Two parallel systems exist:
- **SmartQueue** (Active): SmartQueueView (1091 lines) + SmartEmergencyQueue (1185 lines) - Production system
- **EmergencyQueue** (Legacy): EmergencyQueueView (153 lines) + EmergencyQueueManager (291 lines) - Unused legacy code

**Target Users**: Developers maintaining the codebase, QA testing emergency flows

**Business Value**:
- Eliminate 444 lines of dead code (EmergencyQueueView + EmergencyQueueManager)
- Single source of truth for emergency cry response
- Reduced testing surface area
- Clearer onboarding for new developers
- Prevent accidental use of legacy system

**Dependencies**:
- SmartEmergencyQueue must remain fully functional
- AI cry detection integration must work seamlessly
- Existing E2E tests (maestro flows) must pass

## Current State Analysis

### Production System (KEEP)
| File | Lines | Purpose |
|------|-------|---------|
| SmartQueueView.swift | 1091 | Spotify-like emergency queue UI |
| SmartEmergencyQueue.swift | 1185 | AI-powered track selection, queue management |

**Features**:
- Full Spotify-like queue UI with animations
- AI reasoning cards showing why tracks were selected
- Ambient mode for proactive playlist
- Interactive progress bar with scrubbing
- Quick suggestions panel
- Drag reorder capability
- Track detail sheets
- Effectiveness feedback (was baby calmed?)

### Legacy System (DEPRECATE)
| File | Lines | Purpose |
|------|-------|---------|
| EmergencyQueueView.swift | 153 | Basic emergency queue view (FS-017) |
| EmergencyQueueManager.swift | 291 | Basic session management with API calls |

**Usage Analysis**:
- EmergencyQueueView: Only used in snapshot tests and previews
- EmergencyQueueManager: Referenced in SmartCryResponseEngine (line 44) but never instantiated for production use

## User Stories

### US-001: Deprecate Legacy EmergencyQueueManager (Priority: P1)

**Project**: main

**As a** developer maintaining the BabyInCarApp
**I want** the unused EmergencyQueueManager to be removed or deprecated
**So that** there is a single source of truth for emergency queue management

**Acceptance Criteria**:
- [x] **AC-US1-01**: EmergencyQueueManager.swift is marked as deprecated with @available annotation
  - **Priority**: P1
  - **Testable**: Yes (compiler warning check)
- [x] **AC-US1-02**: SmartCryResponseEngine no longer references EmergencyQueueManager (line 44)
  - **Priority**: P1
  - **Testable**: Yes (grep verification)
- [x] **AC-US1-03**: All EmergencyQueueManager functionality is verified to exist in SmartEmergencyQueue
  - **Priority**: P1
  - **Testable**: Yes (feature parity checklist)
- [x] **AC-US1-04**: Mock object preserved for test compatibility if needed
  - **Priority**: P2
  - **Testable**: Yes (tests compile)

---

### US-002: Deprecate Legacy EmergencyQueueView (Priority: P1)

**Project**: main

**As a** developer maintaining the BabyInCarApp
**I want** the unused EmergencyQueueView to be deprecated
**So that** SmartQueueView is the only emergency queue UI component

**Acceptance Criteria**:
- [x] **AC-US2-01**: EmergencyQueueView.swift is marked as deprecated with @available annotation
  - **Priority**: P1
  - **Testable**: Yes (compiler warning check)
- [x] **AC-US2-02**: No production code references EmergencyQueueView
  - **Priority**: P1
  - **Testable**: Yes (grep verification)
- [x] **AC-US2-03**: Snapshot tests migrated to use SmartQueueView instead
  - **Priority**: P1
  - **Testable**: Yes (snapshot tests pass)
- [x] **AC-US2-04**: EmergencyQueueSnapshotTests.swift updated to test SmartQueueView
  - **Priority**: P1
  - **Testable**: Yes (test file references SmartQueueView)

---

### US-003: Verify AI Cry Detection Integration (Priority: P0)

**Project**: main

**As a** parent using the emergency cry response feature
**I want** AI cry detection to seamlessly trigger the SmartQueue system
**So that** my baby receives appropriate soothing music immediately

**Acceptance Criteria**:
- [x] **AC-US3-01**: SmartCryResponseEngine triggers SmartEmergencyQueue on cry detection
  - **Priority**: P0
  - **Testable**: Yes (unit test)
- [x] **AC-US3-02**: Cry type (hunger, tired, pain, etc.) correctly passed to queue building
  - **Priority**: P0
  - **Testable**: Yes (integration test)
- [x] **AC-US3-03**: Emergency mode activates SmartQueueView overlay in CryDetectionView
  - **Priority**: P0
  - **Testable**: Yes (E2E test)
- [x] **AC-US3-04**: EmergencyCryStopService correctly deactivates on queue stop
  - **Priority**: P0
  - **Testable**: Yes (integration test)

---

### US-004: Update Tests for Consolidated System (Priority: P1)

**Project**: main

**As a** QA engineer testing the app
**I want** all tests to validate the SmartQueue system
**So that** test coverage reflects the actual production code

**Acceptance Criteria**:
- [x] **AC-US4-01**: PlaybackVerificationTests.swift updated to use SmartEmergencyQueue
  - **Priority**: P1
  - **Testable**: Yes (tests pass)
- [x] **AC-US4-02**: EffectivenessTrackingTests.swift updated to use SmartEmergencyQueue
  - **Priority**: P1
  - **Testable**: Yes (tests pass)
- [x] **AC-US4-03**: Maestro E2E flows (emergency_playlist_flow.yaml, smart_queue_e2e_flow.yaml) pass
  - **Priority**: P1
  - **Testable**: Yes (maestro test execution)
- [x] **AC-US4-04**: No test references deprecated EmergencyQueueManager or EmergencyQueueView
  - **Priority**: P2
  - **Testable**: Yes (grep verification)

---

### US-005: Documentation and Code Cleanup (Priority: P2)

**Project**: main

**As a** new developer joining the project
**I want** clear documentation on the emergency system architecture
**So that** I understand there is ONE emergency queue system

**Acceptance Criteria**:
- [x] **AC-US5-01**: CLAUDE.md updated with emergency system architecture note
  - **Priority**: P2
  - **Testable**: Yes (manual review)
- [x] **AC-US5-02**: Inline comments in SmartEmergencyQueue.swift explain it replaces EmergencyQueueManager
  - **Priority**: P2
  - **Testable**: Yes (code review)
- [x] **AC-US5-03**: Legacy files have clear deprecation notices explaining migration path
  - **Priority**: P2
  - **Testable**: Yes (code review)
- [x] **AC-US5-04**: FS-017 feature spec updated to note deprecation of original implementation
  - **Priority**: P3
  - **Testable**: Yes (doc exists)

## Functional Requirements

- **FR-001**: SmartEmergencyQueue.shared is the singleton for all emergency queue operations
  - Priority: P0
- **FR-002**: SmartQueueView is the only UI for emergency queue display
  - Priority: P0
- **FR-003**: Legacy code must compile but show deprecation warnings
  - Priority: P1
- **FR-004**: AI cry detection pipeline unchanged (CryDetectionService -> SmartCryResponseEngine -> SmartEmergencyQueue)
  - Priority: P0

## Non-Functional Requirements

- **NFR-001**: Zero runtime regressions after deprecation
  - Priority: P0
- **NFR-002**: Build time not increased by more than 5%
  - Priority: P2
- **NFR-003**: Test suite execution time unchanged
  - Priority: P2

## Success Criteria

- **Metric 1**: Zero production references to EmergencyQueueManager/EmergencyQueueView
- **Metric 2**: All 5 Maestro E2E flows pass
- **Metric 3**: Unit test coverage on SmartEmergencyQueue >= 80%
- **Metric 4**: No new compiler warnings (only deprecation warnings on legacy code)

## Out of Scope

- Adding new features to SmartQueue (that's a separate increment)
- Changing the AI cry detection algorithm
- Modifying audio playback behavior
- UI redesign of SmartQueueView

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing tests | Medium | Medium | Update tests incrementally, run after each change |
| Hidden dependency on EmergencyQueueManager | Low | High | Thorough grep search, runtime testing |
| Snapshot test failures | Medium | Low | Re-record snapshots with SmartQueueView |

## Technical Notes

### Files to Deprecate (NOT Delete)
We deprecate rather than delete to maintain git history and allow rollback if needed:

```swift
// EmergencyQueueManager.swift
@available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead")
class EmergencyQueueManager: ObservableObject { ... }

// EmergencyQueueView.swift
@available(*, deprecated, message: "Use SmartQueueView instead")
struct EmergencyQueueView: View { ... }
```

### Key Integration Points
1. **CryDetectionView.swift:91** - Already uses SmartQueueView (CORRECT)
2. **SmartCryResponseEngine.swift:49** - Uses SmartEmergencyQueue.shared (CORRECT)
3. **SmartCryResponseEngine.swift:44** - References EmergencyQueueManager (REMOVE)

### Test Files Requiring Updates
- BabyInCarAppTests/Integration/PlaybackVerificationTests.swift
- BabyInCarAppTests/Snapshots/EmergencyQueueSnapshotTests.swift
- BabyInCarAppTests/Services/EffectivenessTrackingTests.swift
