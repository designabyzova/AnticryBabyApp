# US-003: Add Proactive Memory Management

**Feature**: FS-028
**Project**: main
**Priority**: P1
**Estimate**: 4 hours
**Status**: planned

## User Story

**As a** system preventing memory accumulation
**I want** services to proactively manage memory before warnings
**So that** cleanup is gradual rather than emergency-driven

## Acceptance Criteria

- [ ] **AC-US3-01**: SmartEmergencyQueue reduces maxConcurrentLoadedTracks from 3 to 2
  - Priority: P1
  - Testable: Yes (constant value verified)

- [ ] **AC-US3-02**: AudioEngine implements LRU cache with max 5 recently played buffers
  - Priority: P1
  - Testable: Yes (cache eviction verified)

- [ ] **AC-US3-03**: AI engines implement automatic history trimming at 50% capacity
  - Priority: P1
  - Testable: Yes (trim triggered at threshold)

- [ ] **AC-US3-04**: CryDetectionService reuses ML model instances (no per-frame allocation)
  - Priority: P1
  - Testable: Yes (allocation count verified) - Already implemented in current code

## Implementation Notes

### Proactive Changes (Not Reactive)

These are **preventive measures** that reduce memory before cleanup notifications:

1. **Reduce Concurrent Loads**: SmartEmergencyQueue keeps fewer tracks in memory
2. **LRU Caching**: AudioEngine evicts old buffers automatically
3. **Auto-Trim**: AI engines trim at 50% capacity (before 100% full)

### Benefits

- Smoother memory curve (gradual vs spiky)
- Fewer cleanup triggers
- Better user experience (no audio interruptions from emergency cleanup)

## Related Tasks

- T-009: Reduce SmartEmergencyQueue maxConcurrentLoadedTracks
- T-010: Implement LRU cache in AudioEngine
- T-011: Add auto-trim to AI engines at 50% capacity
