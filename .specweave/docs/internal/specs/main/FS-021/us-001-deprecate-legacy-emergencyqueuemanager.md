# US-001: Deprecate Legacy EmergencyQueueManager

**Feature**: [FS-021: Emergency Systems Consolidation](FEATURE.md)  
**Project**: main  
**Priority**: P1  
**Status**: Planned

## User Story

**As a** developer maintaining the BabyInCarApp  
**I want** the unused EmergencyQueueManager to be removed or deprecated  
**So that** there is a single source of truth for emergency queue management

## Acceptance Criteria

- **AC-US1-01**: EmergencyQueueManager.swift file is marked with @available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead")
- **AC-US1-02**: All class methods in EmergencyQueueManager have deprecation warnings
- **AC-US1-03**: Compiler generates warnings for any EmergencyQueueManager usage
- **AC-US1-04**: Git history is preserved (file not deleted, only deprecated)

## Technical Details

**Files to modify**:
- `BabyInCarApp/BabyInCarApp/Services/EmergencyQueueManager.swift`

**Implementation**:
```swift
@available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead. EmergencyQueueManager is legacy code.")
class EmergencyQueueManager: ObservableObject {
    // Existing code remains for backward compatibility
}
```

## Testing

**Test Criteria**:
- Xcode shows deprecation warnings when EmergencyQueueManager is referenced
- Build succeeds with warnings (not errors)
- No production code uses EmergencyQueueManager

## Tasks

- T-001: Add @available(*, deprecated) annotation to EmergencyQueueManager.swift
- T-002: Add deprecation warnings to all public methods
- T-003: Verify compiler warnings appear

## References

- [ADR-0125: Deprecation vs Deletion Strategy](../../architecture/adr/0125-deprecation-vs-deletion-strategy.md)
- Implementation: [plan.md - Phase 1](../../../../increments/0021-emergency-systems-consolidation/plan.md#phase-1)
