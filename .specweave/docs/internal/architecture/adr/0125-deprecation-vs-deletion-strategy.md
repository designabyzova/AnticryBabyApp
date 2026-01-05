# ADR-0125: Deprecation vs Deletion Strategy

**Date**: 2026-01-04
**Status**: Proposed

## Context

The BabyInCarApp codebase has duplicate emergency queue implementations:

| System | Files | Lines | Usage |
|--------|-------|-------|-------|
| **SmartQueue (Active)** | SmartEmergencyQueue.swift, SmartQueueView.swift | 2,276 | Production - CryDetectionView uses SmartQueueView |
| **EmergencyQueue (Legacy)** | EmergencyQueueManager.swift, EmergencyQueueView.swift | 444 | Unused - Only snapshot tests and previews |

We need to decide how to handle the legacy code:

1. **Delete immediately** - Remove all legacy files
2. **Deprecate with annotations** - Mark as deprecated, keep code
3. **Archive to separate branch** - Remove from main but preserve in git

### Factors Influencing Decision

1. **Git History Preservation**: Swift deprecation maintains full git blame and history
2. **Rollback Safety**: If SmartQueue has issues, we can quickly restore legacy
3. **Test Compatibility**: Some tests may reference legacy classes
4. **Compiler Warnings**: Deprecation annotations provide clear warnings to developers
5. **Codebase Cleanliness**: Balance between cleanup and safety

## Decision

**Use Swift `@available(*, deprecated)` annotations instead of deletion.**

### Implementation Pattern

```swift
// EmergencyQueueManager.swift
@available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead. See ADR-0125.")
@MainActor
class EmergencyQueueManager: ObservableObject {
    // ... existing implementation preserved ...
}

// EmergencyQueueView.swift
@available(*, deprecated, message: "Use SmartQueueView instead. See ADR-0125.")
struct EmergencyQueueView: View {
    // ... existing implementation preserved ...
}
```

### Deprecation Timeline

| Phase | Duration | Action |
|-------|----------|--------|
| **Phase 1** | Immediate | Add `@available(*, deprecated)` annotations |
| **Phase 2** | 1 sprint | Remove all production references |
| **Phase 3** | 2-3 sprints | Update/remove tests using legacy code |
| **Phase 4** | Next major version | Consider deletion (optional) |

## Alternatives Considered

### 1. Immediate Deletion

**Pros**:
- Clean codebase immediately
- No confusion about which system to use
- Smaller binary size

**Cons**:
- Loses git history context (blame)
- No rollback path if SmartQueue has issues
- Breaks any remaining tests immediately
- Risk of missing hidden dependencies

**Why Not Chosen**: Too risky for P0 emergency cry response feature. Rollback safety is paramount.

### 2. Archive to Separate Branch

**Pros**:
- Preserves history in git
- Clean main branch
- Can restore if needed

**Cons**:
- Harder to reference (different branch)
- May diverge over time
- Not visible in IDE autocomplete (good and bad)
- Harder to run tests against

**Why Not Chosen**: Deprecation annotations achieve same goal with better developer experience.

### 3. Move to `Legacy/` Folder

**Pros**:
- Visible separation
- Still in main codebase
- Can be compiled and tested

**Cons**:
- Xcode project changes needed
- Import paths change (breaking)
- Still compiles without warnings
- Doesn't prevent usage

**Why Not Chosen**: Swift deprecation annotations are more idiomatic and provide compiler warnings.

## Consequences

### Positive

- **Compiler warnings**: Developers see deprecation warnings if they accidentally use legacy code
- **Clear migration path**: Deprecation message points to replacement
- **Zero breaking changes**: Existing code continues to compile
- **Git history preserved**: `git blame` shows original authors
- **Gradual migration**: Tests can be updated incrementally
- **Rollback safety**: If SmartQueue fails, legacy code is still functional

### Negative

- **Code size**: 444 lines of "dead" code remain in repo
- **Potential confusion**: Two systems exist simultaneously (mitigated by warnings)
- **Build time**: Slightly longer (negligible for 444 lines)

### Neutral

- **Documentation required**: Clear ADRs and inline comments explaining deprecation
- **Test updates needed**: Snapshot tests should migrate to SmartQueueView

## Technical Notes

### Files to Deprecate

1. `BabyInCarApp/Services/EmergencyQueueManager.swift` (291 lines)
   - Add `@available(*, deprecated)` to class
   - Add `@available(*, deprecated)` to public methods
   - Keep `EmergencyQueueError` enum (may be useful)

2. `BabyInCarApp/Views/EmergencyQueueView.swift` (153 lines)
   - Add `@available(*, deprecated)` to struct
   - Preview providers can remain (useful for reference)

### References to Remove

- `SmartCryResponseEngine.swift:44` - Remove `EmergencyQueueManager` property
- Any remaining production code references (verify with grep)

### Tests to Update

- `EmergencyQueueSnapshotTests.swift` - Migrate to SmartQueueView
- Any unit tests using EmergencyQueueManager mock

## Related Decisions

- **ADR-0126**: SmartQueue as Canonical Emergency System
- **ADR-0127**: Test Migration Strategy
- **FS-017**: Smart Emergency Playlist System (original legacy implementation)
- **FS-021**: Emergency Systems Consolidation (this increment)
