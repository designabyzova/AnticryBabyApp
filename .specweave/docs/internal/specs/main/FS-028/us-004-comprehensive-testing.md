# US-004: Comprehensive Memory Testing

**Feature**: FS-028
**Project**: main
**Priority**: P1
**Estimate**: 6 hours
**Status**: planned

## User Story

**As a** developer maintaining code quality
**I want** comprehensive memory tests
**So that** memory issues are caught before release

## Acceptance Criteria

- [ ] **AC-US4-01**: Unit tests for new threshold values (80/90/100MB)
  - Priority: P1
  - Testable: Yes (test exists and passes)

- [ ] **AC-US4-02**: Integration tests verifying cleanup notification triggers handlers
  - Priority: P1
  - Testable: Yes (mock notification, verify handler called)

- [ ] **AC-US4-03**: Integration tests measuring actual memory reduction per service
  - Priority: P1
  - Testable: Yes (memory delta > 5MB after cleanup)

- [ ] **AC-US4-04**: Performance tests with 80MB baseline metric
  - Priority: P1
  - Testable: Yes (XCTest measure with baseline)

- [ ] **AC-US4-05**: Memory profiling test for 5-minute monitoring session
  - Priority: P1
  - Testable: Yes (peak memory < 100MB)

## Test Strategy

### Unit Tests (MemoryMonitorTests.swift)

Verify threshold values and warning level transitions:

```swift
@Suite("Memory Monitor Thresholds")
struct MemoryMonitorThresholdTests {
    @Test("Normal threshold is 80MB")
    func normalThreshold() {
        let monitor = MemoryMonitor.shared
        monitor.simulateMemoryLevel(79.0)
        #expect(monitor.warningLevel == .normal)
    }

    @Test("Warning threshold is 90MB")
    func warningThreshold() {
        let monitor = MemoryMonitor.shared
        monitor.simulateMemoryLevel(85.0)
        #expect(monitor.warningLevel == .warning)
    }

    @Test("Critical threshold is 100MB")
    func criticalThreshold() {
        let monitor = MemoryMonitor.shared
        monitor.simulateMemoryLevel(95.0)
        #expect(monitor.warningLevel == .critical)
    }
}
```

### Integration Tests (ServiceMemoryCleanupTests.swift)

Verify all 6 services respond to cleanup notifications:

```swift
@Suite("Service Memory Cleanup Handlers")
@MainActor
struct ServiceMemoryCleanupTests {
    @Test("AudioEngine responds to critical cleanup")
    func audioEngineCriticalCleanup() async {
        let engine = AudioEngine.shared
        // Pre-populate history

        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            userInfo: ["level": "critical", "memoryMB": 95.0]
        )

        // Allow handler to execute
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(engine.playbackHistory.isEmpty)
    }

    // Similar tests for all 6 services...
}
```

### Performance Tests (MemoryProfilingTests.swift)

Measure memory during realistic app usage:

```swift
func testExtendedMonitoringSessionMemory() throws {
    // Simulate 5-minute monitoring session
    measure(metrics: [XCTMemoryMetric()]) {
        // Run monitoring simulation
        // Verify peak memory < 100MB
    }
}

func test80MBBaseline() throws {
    let baseline = XCTMemoryMetric.applicationLaunch
    measure(metrics: [baseline]) {
        // Normal app usage
        // Baseline: 80MB
    }
}
```

## Success Metrics

- All unit tests pass (threshold verification)
- All integration tests pass (6 services × 2 cleanup levels = 12 tests)
- Performance test peak memory < 100MB
- 80MB baseline test passes
- No memory-related test failures in CI

## Related Tasks

- T-012: Create integration tests for cleanup handlers
- T-013: Create performance test with 80MB baseline
- T-014: Create extended monitoring session test
- T-015: Verify cleanup handlers respond to both levels
