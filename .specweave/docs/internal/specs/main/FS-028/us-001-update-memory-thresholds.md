# US-001: Update Memory Thresholds to Realistic Values

**Feature**: FS-028
**Project**: main
**Priority**: P0
**Estimate**: 2 hours
**Status**: planned

## User Story

**As a** user running the app for extended periods
**I want** memory warnings to trigger at appropriate levels (80/90/100MB)
**So that** cleanup actions happen before iOS kills the app

## Acceptance Criteria

- [ ] **AC-US1-01**: Normal threshold updated from 40MB to 80MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)

- [ ] **AC-US1-02**: Warning threshold updated from 45MB to 90MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)

- [ ] **AC-US1-03**: Critical threshold updated from 48MB to 100MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)

- [ ] **AC-US1-04**: Emergency threshold triggers at 100MB+ (was 48MB+)
  - Priority: P0
  - Testable: Yes (simulation test)

- [ ] **AC-US1-05**: Existing tests updated for new thresholds
  - Priority: P0
  - Testable: Yes (test suite passes)

## Implementation Notes

**File**: `BabyInCarApp/Services/MemoryMonitor.swift`

Update threshold constants:
```swift
// BEFORE (unrealistic)
private let normalThreshold: Double = 40.0
private let warningThreshold: Double = 45.0
private let criticalThreshold: Double = 48.0

// AFTER (realistic for iOS)
private let normalThreshold: Double = 80.0
private let warningThreshold: Double = 90.0
private let criticalThreshold: Double = 100.0
```

**Rationale**: iOS typically kills apps at 150-200MB for foreground apps. Setting thresholds at 80/90/100MB provides adequate warning buffer.

## Related Tasks

- T-001: Update MemoryMonitor threshold constants
- T-002: Update MemoryMonitor tests for new thresholds
