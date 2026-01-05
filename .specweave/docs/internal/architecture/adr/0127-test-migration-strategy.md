# ADR-0127: Test Migration Strategy

**Date**: 2026-01-04
**Status**: Proposed

## Context

Following the decision to deprecate EmergencyQueueManager and EmergencyQueueView (ADR-0125), we need to migrate tests to use the canonical SmartQueue system (ADR-0126).

### Current Test Files Affected

| Test File | Current State | Migration Needed |
|-----------|---------------|------------------|
| `EmergencyQueueSnapshotTests.swift` | Uses EmergencyQueueView preview wrappers | Migrate to SmartQueueView |
| `PlaybackVerificationTests.swift` | May reference EmergencyQueueManager | Verify and update |
| `EffectivenessTrackingTests.swift` | May test legacy effectiveness flow | Update to SmartQueue flow |

### Test Categories

1. **Snapshot Tests**: Visual regression tests for UI components
2. **Unit Tests**: Service and model logic tests
3. **Integration Tests**: Multi-component flow tests
4. **E2E Tests (Maestro)**: Full user journey tests

## Decision

**Migrate all tests to use SmartEmergencyQueue and SmartQueueView as test subjects.**

### Migration Strategy

#### Phase 1: Identify All Test References

```bash
# Find all test files referencing legacy code
grep -r "EmergencyQueueManager" BabyInCarApp/BabyInCarAppTests/
grep -r "EmergencyQueueView" BabyInCarApp/BabyInCarAppTests/
```

#### Phase 2: Snapshot Test Migration

Current `EmergencyQueueSnapshotTests.swift` uses custom preview wrappers:
- `EmergencyQueuePreview`
- `CurrentTrackCardPreview`
- `UpcomingTrackRowPreview`
- etc.

**Migration Approach**:

```swift
// BEFORE: Testing legacy preview wrappers
func testEmergencyQueueView_iPhone15() {
    let view = EmergencyQueuePreview(...)  // Legacy wrapper
    assertSnapshot(...)
}

// AFTER: Testing actual SmartQueueView
func testSmartQueueView_iPhone15() {
    let view = SmartQueueView()
        .environmentObject(SmartEmergencyQueue.mock)
    assertSnapshot(...)
}
```

**Mock State for Snapshots**:

```swift
extension SmartEmergencyQueue {
    /// Mock instance for snapshot testing
    static var mock: SmartEmergencyQueue {
        let queue = SmartEmergencyQueue()
        queue.isActive = true
        queue.currentTrack = AudioTrack(
            title: "Brahms Lullaby",
            artist: "Classical Collection",
            category: .classicalMusic,
            duration: 180,
            audioSourceType: .bundled,
            calmingScore: 0.9
        )
        queue.upcomingTracks = [...]
        queue.isPlaying = true
        queue.progress = 0.45
        queue.queueName = "Sleep Time"
        queue.queueDescription = "Lullabies & gentle sounds for your baby"
        return queue
    }
}
```

#### Phase 3: Unit Test Migration

**EmergencyQueueManager Tests** (if any exist):

```swift
// BEFORE: Testing legacy manager
func testSessionStart() async throws {
    let manager = EmergencyQueueManager()
    try await manager.startSession(playlist: mockPlaylist, babyId: "test")
    XCTAssertNotNil(manager.sessionId)
}

// AFTER: Testing SmartEmergencyQueue
func testQueueBuild() async {
    let queue = SmartEmergencyQueue.shared
    let tracks = await queue.buildQueue(for: .tired, babyAge: 12)
    #expect(!tracks.isEmpty)
    #expect(queue.cryType == .tired)
}
```

#### Phase 4: Integration Test Migration

Ensure the full cry response pipeline is tested:

```swift
@Suite("Emergency Cry Response Integration")
@MainActor
struct CryResponseIntegrationTests {

    @Test("Cry detection triggers SmartQueue")
    func cryDetectionTriggersQueue() async {
        // Setup
        let cryService = CryDetectionService.shared
        let queue = SmartEmergencyQueue.shared

        // Simulate cry detection
        cryService.simulateCryDetection(type: .tired, confidence: 0.9)

        // Verify queue activated
        try await Task.sleep(for: .milliseconds(500))
        #expect(queue.isActive == true)
        #expect(queue.cryType == .tired)
    }
}
```

#### Phase 5: E2E Test Verification

Maestro flows should already test production code:

```yaml
# maestro/flows/smart_queue_e2e_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- tapOn: "Start Monitoring"
# Wait for cry simulation or manual trigger
- assertVisible: "Smart Soothing"  # SmartQueueView header
- assertVisible: "Up Next"
- tapOn: "Stop"
```

## Alternatives Considered

### 1. Keep Legacy Tests Separate

**Approach**: Maintain EmergencyQueueSnapshotTests as-is, add new SmartQueueSnapshotTests

**Pros**:
- No immediate changes needed
- Historical reference

**Cons**:
- Tests for deprecated code
- Confusion about which tests matter
- Doubled maintenance

**Why Not Chosen**: Tests should reflect production code. Legacy tests provide false confidence.

### 2. Delete All Legacy Tests

**Approach**: Remove EmergencyQueueSnapshotTests entirely

**Pros**:
- Clean test suite
- No deprecated code tested

**Cons**:
- Loss of snapshot test patterns
- Need to recreate from scratch

**Why Not Chosen**: The preview wrapper patterns in EmergencyQueueSnapshotTests are useful. We should adapt them, not delete.

### 3. Abstract Test Helpers

**Approach**: Create shared test helpers that work with both systems

**Pros**:
- Flexibility
- Reusable patterns

**Cons**:
- Over-engineering
- Legacy system shouldn't be tested anyway

**Why Not Chosen**: Unnecessary abstraction for deprecated code.

## Consequences

### Positive

- **Tests reflect reality**: All tests exercise production code
- **Higher confidence**: Test results directly indicate production health
- **Cleaner test suite**: No tests for deprecated code
- **Better coverage**: SmartQueue features get proper test coverage

### Negative

- **Migration effort**: ~1-2 days of test updates
- **Snapshot re-recording**: New baselines needed for SmartQueueView
- **Temporary test failures**: During migration, some tests will fail

### Neutral

- **Preview wrappers preserved**: Useful patterns can be adapted
- **Mock data reusable**: AudioTrack mocks work with both systems

## Implementation Checklist

### EmergencyQueueSnapshotTests.swift Migration

- [ ] Rename to `SmartQueueSnapshotTests.swift`
- [ ] Update all preview wrappers to use SmartQueueView components
- [ ] Create `SmartEmergencyQueue.mock` extension
- [ ] Re-record all snapshot baselines
- [ ] Update test names to reflect SmartQueue
- [ ] Add new tests for AI reasoning cards
- [ ] Add new tests for quick suggestions panel

### Unit Test Updates

- [ ] Search for `EmergencyQueueManager` references
- [ ] Replace with `SmartEmergencyQueue` tests
- [ ] Verify `EffectivenessManager` integration tests
- [ ] Add tests for category rotation algorithm
- [ ] Add tests for banned sounds filtering

### Integration Test Updates

- [ ] Verify `SmartCryResponseEngine` integration
- [ ] Test cry type propagation to queue
- [ ] Test effectiveness feedback loop
- [ ] Test favorites boosting

### E2E Test Verification

- [ ] Run all Maestro flows
- [ ] Verify `smart_queue_e2e_flow.yaml` passes
- [ ] Verify `emergency_playlist_flow.yaml` passes
- [ ] Update any flows referencing legacy views

## Related Decisions

- **ADR-0125**: Deprecation vs Deletion Strategy
- **ADR-0126**: SmartQueue as Canonical Emergency System
- **FS-021**: Emergency Systems Consolidation
