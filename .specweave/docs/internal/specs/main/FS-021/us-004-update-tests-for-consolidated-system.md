# US-004: Update Tests for Consolidated System

**Feature**: [FS-021: Emergency Systems Consolidation](FEATURE.md)  
**Project**: main  
**Priority**: P1  
**Status**: Planned

## User Story

**As a** QA engineer testing the app  
**I want** all tests to validate the SmartQueue system  
**So that** we maintain ≥80% code coverage with accurate tests

## Acceptance Criteria

- **AC-US4-01**: EmergencyQueueSnapshotTests migrated to SmartQueueSnapshotTests
- **AC-US4-02**: All test mocks use SmartEmergencyQueue.mock (not EmergencyQueueManager.mock)
- **AC-US4-03**: Snapshot baselines re-recorded with SmartQueueView
- **AC-US4-04**: All tests pass with ≥80% coverage on modified files

## Technical Details

**Test files to migrate**:
1. `EmergencyQueueSnapshotTests.swift` → Rename to `SmartQueueSnapshotTests.swift`
2. Create `SmartEmergencyQueue.mock` test helper
3. Update unit tests in `SmartCryResponseEngineTests.swift`

**Migration strategy**:
- Rename test class: `EmergencyQueueSnapshotTests` → `SmartQueueSnapshotTests`
- Replace mock: `EmergencyQueueManager.mock` → `SmartEmergencyQueue.mock`
- Re-record snapshots: `recordMode = true` → run tests → `recordMode = false`

## Testing

**Test Coverage Targets**:
| File | Current | Target |
|------|---------|--------|
| SmartEmergencyQueue.swift | ~60% | ≥80% |
| SmartQueueView.swift | ~40% | ≥80% |
| SmartCryResponseEngine.swift | ~50% | ≥80% |

**Verification**:
```bash
# Run unit tests
xcodebuild test -scheme BabyInCarApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Check coverage
xcodebuild -resultBundlePath ./test-results test -scheme BabyInCarApp
xcrun xccov view --report ./test-results.xcresult
```

## Tasks

- T-008: Rename EmergencyQueueSnapshotTests to SmartQueueSnapshotTests
- T-009: Create SmartEmergencyQueue.mock test helper
- T-010: Update test imports and dependencies
- T-011: Re-record snapshot baselines
- T-012: Run full unit test suite
- T-013: Verify code coverage ≥80%
- T-014: Update test documentation

## References

- [ADR-0127: Test Migration Strategy](../../architecture/adr/0127-test-migration-strategy.md)
- Implementation: [plan.md - Phase 3](../../../../increments/0021-emergency-systems-consolidation/plan.md#phase-3)
