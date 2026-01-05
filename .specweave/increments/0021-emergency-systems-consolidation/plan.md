---
increment: 0021-emergency-systems-consolidation
architecture_docs:
  - ../../docs/internal/architecture/adr/0125-deprecation-vs-deletion-strategy.md
  - ../../docs/internal/architecture/adr/0126-smartqueue-canonical-system.md
  - ../../docs/internal/architecture/adr/0127-test-migration-strategy.md
---

# Implementation Plan: Emergency Systems Consolidation

## Architecture Overview

**Complete architecture**: See ADRs in `.specweave/docs/internal/architecture/adr/`

**Key decisions**:
- [ADR-0125: Deprecation vs Deletion Strategy](../../docs/internal/architecture/adr/0125-deprecation-vs-deletion-strategy.md) - Use `@available(*, deprecated)` annotations
- [ADR-0126: SmartQueue as Canonical System](../../docs/internal/architecture/adr/0126-smartqueue-canonical-system.md) - SmartEmergencyQueue.shared is THE singleton
- [ADR-0127: Test Migration Strategy](../../docs/internal/architecture/adr/0127-test-migration-strategy.md) - Migrate snapshot tests to SmartQueueView

## Systems Summary

| System | Status | Files | Lines |
|--------|--------|-------|-------|
| **SmartQueue** | KEEP (Production) | SmartEmergencyQueue.swift, SmartQueueView.swift | 2,276 |
| **EmergencyQueue** | DEPRECATE | EmergencyQueueManager.swift, EmergencyQueueView.swift | 444 |

## Implementation Phases

### Phase 1: Code Deprecation (Day 1)

**Objective**: Mark legacy code as deprecated without breaking anything

**Tasks**:

1. **T-001**: Add deprecation annotation to EmergencyQueueManager
   ```swift
   // EmergencyQueueManager.swift
   @available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead. See ADR-0125.")
   @MainActor
   class EmergencyQueueManager: ObservableObject { ... }
   ```

2. **T-002**: Add deprecation annotation to EmergencyQueueView
   ```swift
   // EmergencyQueueView.swift
   @available(*, deprecated, message: "Use SmartQueueView instead. See ADR-0125.")
   struct EmergencyQueueView: View { ... }
   ```

3. **T-003**: Remove EmergencyQueueManager reference from SmartCryResponseEngine
   - File: `SmartCryResponseEngine.swift`
   - Line 44: `@Published var emergencyQueueManager: EmergencyQueueManager?`
   - Action: Remove this property entirely

**Verification**:
```bash
# Build should succeed with deprecation warnings
xcodebuild build -project BabyInCarApp/BabyInCarApp.xcodeproj -scheme BabyInCarApp

# Verify deprecation warnings appear
xcodebuild build 2>&1 | grep -i "deprecated"
```

### Phase 2: Production Reference Cleanup (Day 2)

**Objective**: Ensure no production code uses legacy systems

**Tasks**:

4. **T-004**: Verify no production views reference EmergencyQueueView
   ```bash
   grep -r "EmergencyQueueView" BabyInCarApp/BabyInCarApp/Views/ --include="*.swift"
   # Expected: No matches (only SmartQueueView should be used)
   ```

5. **T-005**: Verify SmartCryResponseEngine uses only SmartEmergencyQueue
   ```bash
   grep -n "SmartEmergencyQueue\|EmergencyQueueManager" BabyInCarApp/BabyInCarApp/Services/SmartCryResponseEngine.swift
   # Expected: Only SmartEmergencyQueue references
   ```

6. **T-006**: Add inline documentation to SmartEmergencyQueue
   ```swift
   /// Smart queue that builds cry-type specific playlists using real audio library tracks
   /// This is the Spotify-like queue experience for emergency cry response
   ///
   /// NOTE: This replaces the legacy EmergencyQueueManager. See ADR-0126.
   /// - SmartEmergencyQueue: AI-powered track selection, queue management
   /// - SmartQueueView: Spotify-like UI with animations and gestures
   ```

### Phase 3: Test Migration (Days 3-4)

**Objective**: Update tests to use SmartQueue components

**Tasks**:

7. **T-007**: Rename EmergencyQueueSnapshotTests to SmartQueueSnapshotTests
   - Rename file
   - Update class name
   - Update all test method names

8. **T-008**: Create SmartEmergencyQueue.mock for testing
   ```swift
   extension SmartEmergencyQueue {
       static var mock: SmartEmergencyQueue {
           let queue = SmartEmergencyQueue()
           queue.isActive = true
           queue.currentTrack = mockCurrentTrack
           queue.upcomingTracks = mockUpcomingTracks
           queue.isPlaying = true
           queue.progress = 0.45
           return queue
       }
   }
   ```

9. **T-009**: Update snapshot tests to use SmartQueueView
   ```swift
   func testSmartQueueView_iPhone15() {
       let view = SmartQueueView()
           .environmentObject(SmartEmergencyQueue.mock)
       assertSnapshot(...)
   }
   ```

10. **T-010**: Re-record all snapshot baselines
    ```bash
    # Set isRecording = true in setUp()
    # Run tests
    # Set isRecording = false
    # Commit new snapshots
    ```

11. **T-011**: Update EffectivenessTrackingTests to use SmartQueue
    - Verify test methods use SmartEmergencyQueue
    - Update mock data if needed

12. **T-012**: Update PlaybackVerificationTests if needed
    - Check for EmergencyQueueManager references
    - Replace with SmartEmergencyQueue

### Phase 4: E2E Verification (Day 5)

**Objective**: Verify all E2E flows pass with consolidated system

**Tasks**:

13. **T-013**: Run all Maestro flows
    ```bash
    ~/.maestro/bin/maestro test maestro/flows/
    ```

14. **T-014**: Verify specific emergency flows
    ```bash
    ~/.maestro/bin/maestro test maestro/flows/smart_queue_e2e_flow.yaml
    ~/.maestro/bin/maestro test maestro/flows/emergency_playlist_flow.yaml
    ```

15. **T-015**: Run full unit test suite
    ```bash
    xcodebuild test \
      -project BabyInCarApp/BabyInCarApp.xcodeproj \
      -scheme BabyInCarApp \
      -destination 'platform=iOS Simulator,name=iPhone 15'
    ```

### Phase 5: Documentation (Day 5-6)

**Objective**: Update all documentation to reflect consolidated system

**Tasks**:

16. **T-016**: Update CLAUDE.md with emergency system architecture note
    - Add section explaining SmartQueue is the canonical system
    - Reference ADR-0126

17. **T-017**: Update FS-017 spec to note deprecation of original implementation
    - Add note that original EmergencyQueueManager is deprecated
    - Link to FS-021 for consolidation details

18. **T-018**: Add deprecation notices to legacy files
    - Add header comment explaining why file is deprecated
    - Add link to ADR-0125

## File Modification Order

```
1. SmartCryResponseEngine.swift     # Remove line 44
2. EmergencyQueueManager.swift      # Add @available annotation
3. EmergencyQueueView.swift         # Add @available annotation
4. SmartEmergencyQueue.swift        # Add documentation
5. EmergencyQueueSnapshotTests.swift → SmartQueueSnapshotTests.swift
6. EffectivenessTrackingTests.swift # Verify/update
7. CLAUDE.md                        # Add architecture note
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing tests | Medium | Medium | Run tests after each change |
| Hidden dependency on legacy code | Low | High | Comprehensive grep search |
| Snapshot test failures | Medium | Low | Re-record baselines |
| E2E flow failures | Low | Medium | Run Maestro after each phase |
| Production regression | Very Low | Critical | SmartQueue already in production |

## Rollback Plan

### Phase 1 Rollback
```bash
git checkout HEAD -- BabyInCarApp/BabyInCarApp/Services/EmergencyQueueManager.swift
git checkout HEAD -- BabyInCarApp/BabyInCarApp/Views/EmergencyQueueView.swift
git checkout HEAD -- BabyInCarApp/BabyInCarApp/Services/SmartCryResponseEngine.swift
```

### Test Rollback
```bash
git checkout HEAD -- BabyInCarApp/BabyInCarAppTests/
```

### Full Rollback
```bash
git revert HEAD  # Revert last commit
# or
git reset --hard <commit-before-changes>
```

## Success Criteria

- [ ] Zero production references to EmergencyQueueManager/EmergencyQueueView
- [ ] All 5+ Maestro E2E flows pass
- [ ] Unit test coverage on SmartEmergencyQueue >= 80%
- [ ] No new compiler warnings (only deprecation warnings on legacy code)
- [ ] Build succeeds on all supported iOS versions (15+)

## Estimated Effort

| Phase | Duration | Complexity |
|-------|----------|------------|
| Phase 1: Code Deprecation | 2 hours | Low |
| Phase 2: Reference Cleanup | 2 hours | Low |
| Phase 3: Test Migration | 4-6 hours | Medium |
| Phase 4: E2E Verification | 2 hours | Low |
| Phase 5: Documentation | 2 hours | Low |
| **Total** | **1-2 days** | **Medium** |

## Dependencies

- SmartEmergencyQueue must remain fully functional
- AI cry detection integration unchanged
- Existing E2E tests (Maestro flows) must pass
- No changes to AudioEngine or PlaybackSessionManager
