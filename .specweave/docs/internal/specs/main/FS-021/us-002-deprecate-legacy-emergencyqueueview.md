# US-002: Deprecate Legacy EmergencyQueueView

**Feature**: [FS-021: Emergency Systems Consolidation](FEATURE.md)  
**Project**: main  
**Priority**: P1  
**Status**: Planned

## User Story

**As a** developer maintaining the BabyInCarApp  
**I want** the unused EmergencyQueueView to be deprecated  
**So that** developers use the production-ready SmartQueueView instead

## Acceptance Criteria

- **AC-US2-01**: EmergencyQueueView.swift file is marked with @available(*, deprecated)
- **AC-US2-02**: All view components have deprecation warnings
- **AC-US2-03**: Compiler warnings guide developers to SmartQueueView
- **AC-US2-04**: View remains functional for backward compatibility

## Technical Details

**Files to modify**:
- `BabyInCarApp/BabyInCarApp/Views/EmergencyQueueView.swift`

**Implementation**:
```swift
@available(*, deprecated, message: "Use SmartQueueView instead. EmergencyQueueView is legacy UI.")
struct EmergencyQueueView: View {
    // Existing code remains for backward compatibility
}
```

## Testing

**Test Criteria**:
- Xcode shows deprecation warnings for EmergencyQueueView usage
- SwiftUI previews still work (for reference)
- No production code uses EmergencyQueueView

## Tasks

- T-004: Add @available(*, deprecated) annotation to EmergencyQueueView.swift
- T-005: Add deprecation warnings to supporting views (CurrentTrackCard, etc.)
- T-006: Verify no production references exist

## References

- [ADR-0125: Deprecation vs Deletion Strategy](../../architecture/adr/0125-deprecation-vs-deletion-strategy.md)
- Implementation: [plan.md - Phase 1](../../../../increments/0021-emergency-systems-consolidation/plan.md#phase-1)
