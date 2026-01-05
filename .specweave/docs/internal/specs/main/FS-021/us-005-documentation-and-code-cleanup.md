# US-005: Documentation and Code Cleanup

**Feature**: [FS-021: Emergency Systems Consolidation](FEATURE.md)  
**Project**: main  
**Priority**: P2  
**Status**: Planned

## User Story

**As a** future developer joining the project  
**I want** clear documentation explaining the emergency system architecture  
**So that** I can quickly understand and maintain the codebase

## Acceptance Criteria

- **AC-US5-01**: CLAUDE.md updated with SmartQueue as the canonical system
- **AC-US5-02**: Inline code comments explain why EmergencyQueue is deprecated
- **AC-US5-03**: Architecture diagram shows SmartQueue as primary flow
- **AC-US5-04**: Git commit history preserved (no force deletion)

## Technical Details

**Documentation to update**:
1. `CLAUDE.md` - iOS Testing section
2. Code comments in deprecated files
3. Architecture diagrams (if any)

**Updates needed**:
```markdown
## Emergency Response System

**Production System**: SmartQueue  
- SmartQueueView.swift - Full-featured Spotify-like UI
- SmartEmergencyQueue.swift - AI-powered queue manager
- Used by: CryDetectionView (primary integration point)

**Legacy System** (deprecated as of 2026-01-04):  
- EmergencyQueueView.swift - ⚠️ Deprecated, use SmartQueueView
- EmergencyQueueManager.swift - ⚠️ Deprecated, use SmartEmergencyQueue

See ADR-0126 for rationale on SmartQueue selection.
```

## Testing

**Verification**:
- Documentation is clear and accurate
- New developers can understand emergency flow in < 5 minutes
- Links to ADRs are working
- Code comments explain deprecation reasons

## Tasks

- T-017: Update CLAUDE.md with SmartQueue architecture
- T-018: Add inline deprecation comments to legacy code

## References

- [ADR-0125: Deprecation vs Deletion Strategy](../../architecture/adr/0125-deprecation-vs-deletion-strategy.md)
- [ADR-0126: SmartQueue as Canonical System](../../architecture/adr/0126-smartqueue-canonical-system.md)
- Implementation: [plan.md - Phase 5](../../../../increments/0021-emergency-systems-consolidation/plan.md#phase-5)
