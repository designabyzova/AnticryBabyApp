# US-003: Verify AI Cry Detection Integration

**Feature**: [FS-021: Emergency Systems Consolidation](FEATURE.md)  
**Project**: main  
**Priority**: P0 (Critical)  
**Status**: Planned

## User Story

**As a** parent using the emergency cry response feature  
**I want** AI cry detection to seamlessly trigger the SmartQueue system  
**So that** my baby gets the right soothing sounds immediately when crying

## Acceptance Criteria

- **AC-US3-01**: CryDetectionView always uses SmartQueueView (never EmergencyQueueView)
- **AC-US3-02**: SmartCryResponseEngine correctly initializes SmartEmergencyQueue
- **AC-US3-03**: AI cry classification triggers appropriate SmartQueue playlists
- **AC-US3-04**: E2E flow: Cry detected → AI classifies → SmartQueue plays → Baby calms

## Technical Details

**Verification points**:
1. CryDetectionView.swift line 91: Uses SmartQueueView ✅
2. SmartCryResponseEngine integration with SmartEmergencyQueue
3. EmergencyQueueManager reference removed (line 44 cleanup)

**Critical Flow**:
```
CryDetectionService detects cry
  → EmergencyCryStopService classifies type (hunger/pain/tired/etc)
  → SmartCryResponseEngine activates SmartEmergencyQueue
  → SmartQueueView displays with AI-selected tracks
  → AudioEngine plays soothing content
```

## Testing

**E2E Test Scenarios**:
```yaml
# Maestro flow: emergency_cry_detection_flow.yaml
- Given: Baby monitoring is active
- When: Cry is detected with 80%+ confidence
- Then: SmartQueueView appears with appropriate playlist
- And: AI reasoning card shows detected cry type
- And: First track begins playing within 2 seconds
```

## Tasks

- T-007: Remove EmergencyQueueManager reference from SmartCryResponseEngine (line 44)
- T-015: Run E2E Maestro flow: cry_detection_flow.yaml
- T-016: Run E2E Maestro flow: emergency_baby_calm_flow.yaml

## References

- [ADR-0126: SmartQueue as Canonical System](../../architecture/adr/0126-smartqueue-canonical-system.md)
- [FS-015: Science-Based Cry Intelligence](../FS-015/FEATURE.md)
- Implementation: [plan.md - Phase 2 & 4](../../../../increments/0021-emergency-systems-consolidation/plan.md)
