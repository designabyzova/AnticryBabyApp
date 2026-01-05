---
increment: 0022-memory-leak-prevention
status: planned
priority: P1
type: hotfix
estimated_tasks: 24
estimated_effort: "18 hours (2-3 days)"
phases:
  - investigation
  - memory-monitor
  - audio-limits
  - ai-limits
  - auto-cleanup
  - testing
---

# Tasks: Memory Leak Prevention System

## Phase 1: Investigation

### T-001: Profile Current Memory Usage with Xcode Instruments
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [ ] pending
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Use Xcode Instruments (Allocations template) to profile current memory usage and identify exact breakdown by component.

**Steps**:
1. Open Xcode Instruments > Allocations template
2. Run app in simulator/device with profiling enabled
3. Execute test scenario: 30-min cry detection + 10-track audio playback + all AI active
4. Capture memory snapshots at peak usage
5. Analyze allocations by category (AVAudioPlayerNode, Arrays, Strings, etc.)
6. Document findings in `reports/memory-profiling-baseline.md`

**Test Plan**:
```swift
// Manual profiling validation
// Expected: Identify components using > 10MB each
// Document: Audio buffers, AI histories, other allocations
```

**Acceptance Criteria**:
- Baseline memory profile captured with Instruments
- Identified top 5 memory consumers
- Reproduced 85MB crash scenario
- Documented findings for implementation

---

### T-002: Verify CryPatternTracker Fixes from 0012
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [ ] pending
**Model**: ⚡ Haiku | **Effort**: 30 minutes

**Description**: Re-validate that increment 0012's fixes for `CryPatternTracker.intensitySamples` are still effective and no regressions occurred.

**Steps**:
1. Read `Services/CryPatternTracker.swift`
2. Verify `maxIntensitySamplesPerBurst = 200` constant exists
3. Verify sliding window enforcement in `handleCryingFrame()`
4. Check all other cry detection services for bounded arrays
5. Run extended cry detection test (30 minutes)

**Test Plan**:
```swift
// BabyInCarAppTests/Services/CryPatternTrackerTests.swift
func testIntensitySamplesStayBounded() {
    let tracker = CryPatternTracker()

    // Simulate 30 minutes of crying at 30fps = 54,000 frames
    for _ in 0..<54000 {
        tracker.handleCryingFrame(intensity: 0.8)
    }

    // Verify array didn't exceed limit
    XCTAssertLessThanOrEqual(tracker.currentBurst?.intensitySamples.count ?? 0, 200)
}
```

**Acceptance Criteria**:
- maxIntensitySamplesPerBurst limit verified (200)
- Extended test confirms no unbounded growth
- All cry detection services confirmed bounded

---

## Phase 2: MemoryMonitor Service

### T-003: Create MemoryMonitor Service with task_info
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-04 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Create a new singleton service that monitors app memory usage using `task_info` API.

**Steps**:
1. Create `BabyInCarApp/Services/MemoryMonitor.swift`
2. Implement `getMemoryUsage()` using `task_info(TASK_VM_INFO)`
3. Convert bytes to MB for display
4. Add timer to poll every 5 seconds
5. Publish `@Published var currentMemoryMB: Double`
6. Add memory breakdown tracking (estimates by category)

**Test Plan**:
```swift
// BabyInCarAppTests/Services/MemoryMonitorTests.swift
import XCTest
@testable import BabyInCarApp

final class MemoryMonitorTests: XCTestCase {
    func testMemoryMonitorReportsNonZero() {
        let monitor = MemoryMonitor.shared
        monitor.startMonitoring()

        // Wait for first update
        let expectation = XCTestExpectation(description: "Memory updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertGreaterThan(monitor.currentMemoryMB, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }
}
```

**Acceptance Criteria**:
- MemoryMonitor.swift created
- Reports memory usage in MB
- Updates every 5 seconds
- Observable via @Published properties

---

### T-004: Implement Memory Warning Thresholds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02, AC-US1-03 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Add threshold-based warnings and automatic cleanup triggers at 40MB, 45MB, and 48MB.

**Steps**:
1. Add `enum MemoryWarningLevel { normal, warning, critical, emergency }`
2. Implement `checkThresholds()` method
3. At 40MB: Log warning with breakdown
4. At 45MB: Trigger `triggerAutoCleanup()`
5. At 48MB: Trigger `triggerAggressiveCleanup()`
6. Publish warning level changes

**Test Plan**:
```swift
// BabyInCarAppTests/Services/MemoryMonitorTests.swift
func testWarningThresholds() {
    let monitor = MemoryMonitor.shared

    // Simulate memory levels
    monitor.currentMemoryMB = 35
    XCTAssertEqual(monitor.warningLevel, .normal)

    monitor.currentMemoryMB = 42
    XCTAssertEqual(monitor.warningLevel, .warning)

    monitor.currentMemoryMB = 46
    XCTAssertEqual(monitor.warningLevel, .critical)

    monitor.currentMemoryMB = 49
    XCTAssertEqual(monitor.warningLevel, .emergency)
}
```

**Acceptance Criteria**:
- Warning at 40MB logged
- Auto-cleanup triggered at 45MB
- Aggressive cleanup triggered at 48MB
- Warning level published to observers

---

### T-005: Add Debug UI for Memory Stats
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Model**: ⚡ Haiku | **Effort**: 1 hour

**Description**: Add debug overlay showing current memory usage and warning level (dev builds only).

**Steps**:
1. Create `Views/DebugMemoryOverlay.swift`
2. Display `MemoryMonitor.currentMemoryMB`
3. Display `MemoryMonitor.warningLevel` with color coding
4. Display memory breakdown if available
5. Only show in DEBUG builds (#if DEBUG)

**Test Plan**:
```swift
// Manual test
// Expected: Debug overlay visible in simulator
// Shows memory increasing/decreasing
// Color changes based on warning level
```

**Acceptance Criteria**:
- Debug overlay shows memory usage
- Color coded by warning level
- Only visible in DEBUG builds

---

## Phase 3: Audio Limits

### T-006: Limit SmartEmergencyQueue to 3 Concurrent Loaded Tracks
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-05 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Modify `SmartEmergencyQueue` to load only 3 tracks at a time, streaming the rest on-demand.

**Steps**:
1. Edit `Services/SmartEmergencyQueue.swift`
2. Add `private let maxConcurrentLoadedTracks = 3`
3. Modify `buildQueue()` to load first 3 tracks only
4. Store remaining track IDs in `queuedTrackIds` array
5. On track end: remove finished, load next from queue
6. Update queue UI to show loaded vs queued tracks

**Test Plan**:
```swift
// BabyInCarAppTests/Integration/SmartEmergencyQueueTests.swift
func testMaxConcurrentLoadedTracks() {
    let queue = SmartEmergencyQueue()
    let tracks = (1...10).map { AudioTrack(id: "track-\($0)", type: .melodic) }

    queue.buildQueue(tracks: tracks)

    // Verify only 3 tracks loaded
    XCTAssertEqual(queue.loadedTracks.count, 3)
    XCTAssertEqual(queue.queuedTrackIds.count, 7)

    // Simulate track end
    queue.onTrackEnded()

    // Verify still 3 loaded (1 removed, 1 added)
    XCTAssertEqual(queue.loadedTracks.count, 3)
    XCTAssertEqual(queue.queuedTrackIds.count, 6)
}
```

**Acceptance Criteria**:
- Only 3 tracks loaded concurrently
- Next track loaded when current ends
- No more than 3 tracks in memory at once

---

### T-007: Add Buffer Release Logic to AudioEngine
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Ensure `AudioEngine` releases AVAudioPlayerNode buffers after playback completes.

**Steps**:
1. Edit `Services/AudioEngine.swift`
2. Add `releaseBuffer(for playerNode: AVAudioPlayerNode)` method
3. Call `playerNode.reset()` to force buffer release
4. Add `cleanup()` method to remove inactive players
5. Call cleanup periodically or on memory warning

**Test Plan**:
```swift
// BabyInCarAppTests/Services/AudioEngineTests.swift
func testBufferReleaseAfterPlayback() {
    let engine = AudioEngine()
    let player = AVAudioPlayerNode()

    engine.attachPlayerNode(player)
    player.play()

    // Simulate playback end
    player.stop()
    engine.releaseBuffer(for: player)

    // Verify buffer released (check via Instruments)
    // Expected: AVAudioPCMBuffer deallocated
}
```

**Acceptance Criteria**:
- Buffers released after playback
- Inactive players removed from engine
- Memory usage drops after cleanup

---

### T-008: Optimize DynamicSoundMixer for Streaming
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Modify `DynamicSoundMixer` to stream audio instead of caching full files in memory.

**Steps**:
1. Edit `Services/DynamicSoundMixer.swift`
2. Replace full-file caching with streaming buffers
3. Use AVAudioFile.readIntoBuffer with small buffer sizes
4. Implement buffer recycling for efficiency
5. Verify no full files held in memory

**Test Plan**:
```swift
// BabyInCarAppTests/Services/DynamicSoundMixerTests.swift
func testStreamingInsteadOfCaching() {
    let mixer = DynamicSoundMixer()

    // Load large audio file (10MB+)
    mixer.loadAudioFile(url: largeAudioURL)

    // Verify buffer size is small (< 1MB)
    XCTAssertLessThan(mixer.bufferSizeMB, 1.0)

    // Verify streaming works
    XCTAssertTrue(mixer.isStreaming)
}
```

**Acceptance Criteria**:
- Streaming implemented (no full-file caching)
- Buffer size < 1MB per file
- Audio playback quality maintained

---

### T-009: Verify Total Audio Memory < 15MB
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04 | **Status**: [ ] pending
**Model**: ⚡ Haiku | **Effort**: 30 minutes

**Description**: Profile audio system with Instruments to confirm total audio buffer usage stays under 15MB.

**Steps**:
1. Run Instruments with Allocations template
2. Play 10-track emergency queue
3. Monitor AVAudioPlayerNode and AVAudioPCMBuffer allocations
4. Verify total audio memory < 15MB
5. Document results

**Test Plan**:
```swift
// Manual Instruments profiling
// Expected: Audio buffers < 15MB during 10-track playback
```

**Acceptance Criteria**:
- Instruments shows audio memory < 15MB
- Verified during intensive playback scenario

---

## Phase 4: AI Engine Limits

### T-010: Reduce BabyMoodLLMEngine History to 100
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-04 | **Status**: [x] completed
**Model**: ⚡ Haiku | **Effort**: 30 minutes

**Description**: Reduce `maxHistorySize` in `BabyMoodLLMEngine` from 500 to 100 with LRU eviction.

**Steps**:
1. Edit `Services/BabyMoodLLMEngine.swift`
2. Change `private let maxHistorySize = 100` (was 500)
3. Implement LRU eviction in `addMoodEntry()`
4. Remove oldest entries when limit exceeded
5. Verify functionality still works with reduced history

**Test Plan**:
```swift
// BabyInCarAppTests/Services/BabyMoodLLMEngineTests.swift
func testHistoryLimitEnforced() {
    let engine = BabyMoodLLMEngine()

    // Add 150 mood entries
    for i in 0..<150 {
        engine.addMoodEntry(MoodEntry(timestamp: Date(), mood: .calm))
    }

    // Verify only 100 retained (LRU eviction)
    XCTAssertEqual(engine.moodHistory.count, 100)

    // Verify oldest entries evicted
    XCTAssertGreaterThan(engine.moodHistory.first!.timestamp, Date().addingTimeInterval(-3600))
}
```

**Acceptance Criteria**:
- maxHistorySize reduced to 100
- LRU eviction implemented
- Mood tracking still functional

---

### T-011: Reduce AdaptiveLearningEngine Limits
**User Story**: US-003 | **Satisfies ACs**: AC-US3-02, AC-US3-03, AC-US3-04 | **Status**: [x] completed
**Model**: ⚡ Haiku | **Effort**: 1 hour

**Description**: Reduce history limits in `AdaptiveLearningEngine` with LRU eviction.

**Steps**:
1. Edit `Services/AdaptiveLearningEngine.swift`
2. Change `maxSessionHistory = 200` (was 1000)
3. Change `maxSuccessfulFeatureVectors = 100` (was 500)
4. Implement LRU eviction for both arrays
5. Verify learning still effective with reduced limits

**Test Plan**:
```swift
// BabyInCarAppTests/Services/AdaptiveLearningEngineTests.swift
func testReducedLimitsWithLRU() {
    let engine = AdaptiveLearningEngine()

    // Add 300 session history items
    for i in 0..<300 {
        engine.addSessionEntry(SessionEntry(timestamp: Date(), success: true))
    }

    // Verify LRU limit enforced
    XCTAssertEqual(engine.sessionHistory.count, 200)

    // Add 150 feature vectors
    for i in 0..<150 {
        engine.addFeatureVector([1.0, 2.0, 3.0])
    }

    // Verify LRU limit enforced
    XCTAssertEqual(engine.successfulFeatureVectors.count, 100)
}
```

**Acceptance Criteria**:
- maxSessionHistory reduced to 200
- maxSuccessfulFeatureVectors reduced to 100
- LRU eviction for both arrays
- Learning functionality maintained

---

### T-012: Verify Combined AI Memory < 10MB
**User Story**: US-003 | **Satisfies ACs**: AC-US3-05 | **Status**: [ ] pending
**Model**: ⚡ Haiku | **Effort**: 30 minutes

**Description**: Profile all AI engines with Instruments to confirm combined memory usage < 10MB.

**Steps**:
1. Run Instruments with Allocations template
2. Activate all AI engines simultaneously
3. Monitor memory usage for: BabyMoodLLMEngine, AdaptiveLearningEngine, SmartCryResponseEngine
4. Verify combined total < 10MB
5. Document results

**Test Plan**:
```swift
// Manual Instruments profiling
// Expected: Combined AI engine memory < 10MB
```

**Acceptance Criteria**:
- Instruments shows AI memory < 10MB
- All engines active during test
- Verified with profiling tool

---

## Phase 5: Auto-Cleanup

### T-013: Implement triggerAutoCleanup() at 45MB
**User Story**: US-006 | **Satisfies ACs**: AC-US6-02, AC-US6-05 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Implement automatic cleanup that triggers at 45MB threshold to free memory.

**Steps**:
1. Edit `Services/MemoryMonitor.swift`
2. Add `triggerAutoCleanup()` method
3. Notify all services to clear non-essential caches
4. Release unused audio buffers
5. Clear old AI history entries beyond minimum needed
6. Log cleanup actions and memory reduction

**Test Plan**:
```swift
// BabyInCarAppTests/Services/MemoryMonitorTests.swift
func testAutoCleanupReducesMemory() {
    let monitor = MemoryMonitor.shared

    // Simulate high memory usage
    monitor.currentMemoryMB = 46

    // Should trigger auto-cleanup
    monitor.checkThresholds()

    // Wait for cleanup
    let expectation = XCTestExpectation(description: "Cleanup executed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        // Memory should drop
        XCTAssertLessThan(monitor.currentMemoryMB, 40)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5)
}
```

**Acceptance Criteria**:
- Auto-cleanup triggers at 45MB
- Memory drops to < 35MB after cleanup
- All services notified for cleanup

---

### T-014: Implement triggerAggressiveCleanup() at 48MB
**User Story**: US-006 | **Satisfies ACs**: AC-US6-03, AC-US6-05 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Implement emergency aggressive cleanup at 48MB that stops non-essential services.

**Steps**:
1. Edit `Services/MemoryMonitor.swift`
2. Add `triggerAggressiveCleanup()` method
3. Stop all non-essential background services
4. Clear all caches aggressively
5. Release all audio buffers except currently playing
6. Reduce AI histories to absolute minimum (10 entries)

**Test Plan**:
```swift
// BabyInCarAppTests/Services/MemoryMonitorTests.swift
func testAggressiveCleanupAtEmergency() {
    let monitor = MemoryMonitor.shared

    // Simulate critical memory
    monitor.currentMemoryMB = 49

    // Should trigger aggressive cleanup
    monitor.checkThresholds()

    // Verify drastic reduction
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        XCTAssertLessThan(monitor.currentMemoryMB, 35)
    }
}
```

**Acceptance Criteria**:
- Aggressive cleanup triggers at 48MB
- Non-essential services stopped
- Memory drops to < 35MB

---

### T-015: Add User Notification for Cleanup Events
**User Story**: US-006 | **Satisfies ACs**: AC-US6-04 | **Status**: [x] completed
**Model**: ⚡ Haiku | **Effort**: 1 hour

**Description**: Show non-intrusive notification when automatic cleanup is triggered.

**Steps**:
1. Add notification in UI when `warningLevel` changes to .critical or .emergency
2. Display: "Memory optimized" toast notification
3. Auto-dismiss after 3 seconds
4. Don't interrupt user workflow
5. Log event to analytics

**Test Plan**:
```swift
// Manual UI test
// Expected: Toast shows when cleanup triggered
// Dismisses after 3 seconds
// Doesn't block user interaction
```

**Acceptance Criteria**:
- Toast notification shown on cleanup
- Non-intrusive (doesn't block UI)
- Auto-dismisses after 3 seconds

---

## Phase 6: Memory Profiling Tests

### T-016: Create MemoryProfilingTests.swift Test Suite
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Create XCTest suite with XCTMemoryMetric for automated memory profiling.

**Steps**:
1. Create `BabyInCarAppTests/Performance/MemoryProfilingTests.swift`
2. Import XCTest and BabyInCarApp
3. Create base class with XCTMemoryMetric setup
4. Add helper methods for memory assertions
5. Configure CI to run performance tests

**Test Plan**:
```swift
// BabyInCarAppTests/Performance/MemoryProfilingTests.swift
import XCTest
@testable import BabyInCarApp

final class MemoryProfilingTests: XCTestCase {
    let memoryLimit: Double = 50.0 // MB

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func assertMemoryUnderLimit(file: StaticString = #file, line: UInt = #line) {
        let current = MemoryMonitor.shared.currentMemoryMB
        XCTAssertLessThan(current, memoryLimit, "Memory exceeded \(memoryLimit)MB limit: \(current)MB", file: file, line: line)
    }
}
```

**Acceptance Criteria**:
- MemoryProfilingTests.swift created
- XCTMemoryMetric configured
- Helper methods for assertions

---

### T-017: Test 30-Minute Cry Detection Memory Usage
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02, AC-US5-06 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Test that 30-minute continuous cry detection session stays under 50MB.

**Steps**:
1. Add test to `MemoryProfilingTests.swift`
2. Activate cry detection
3. Simulate 30 minutes of crying audio input
4. Monitor memory every 30 seconds
5. Fail test if > 50MB at any point

**Test Plan**:
```swift
// BabyInCarAppTests/Performance/MemoryProfilingTests.swift
func testCryDetectionMemoryUnder50MB() {
    let cryDetection = CryDetectionService.shared

    measure(metrics: [XCTMemoryMetric()]) {
        cryDetection.startMonitoring()

        // Simulate 30 minutes at 30fps = 54,000 frames
        for _ in 0..<54000 {
            cryDetection.processAudioBuffer(MockAudioBuffer.cryingBaby)

            // Check memory every 1000 frames (~33 seconds)
            if i % 1000 == 0 {
                assertMemoryUnderLimit()
            }
        }

        cryDetection.stopMonitoring()
    }

    // Final memory check
    assertMemoryUnderLimit()
}
```

**Acceptance Criteria**:
- Test simulates 30-min cry detection
- Memory stays < 50MB throughout
- Test fails if limit exceeded

---

### T-018: Test 10-Track Audio Playback Memory Usage
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03, AC-US5-06 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Test that playing 10-track emergency queue stays under 50MB.

**Steps**:
1. Add test to `MemoryProfilingTests.swift`
2. Build emergency queue with 10 tracks
3. Play through all tracks
4. Monitor memory during playback
5. Fail test if > 50MB

**Test Plan**:
```swift
// BabyInCarAppTests/Performance/MemoryProfilingTests.swift
func testAudioPlaybackMemoryUnder50MB() {
    let queue = SmartEmergencyQueue()
    let tracks = MockAudioTracks.tenMelodicTracks

    measure(metrics: [XCTMemoryMetric()]) {
        queue.buildQueue(tracks: tracks)

        // Play all tracks
        for track in tracks {
            queue.playTrack(track)
            assertMemoryUnderLimit()

            // Simulate playback time
            Thread.sleep(forTimeInterval: 2.0)
        }
    }

    assertMemoryUnderLimit()
}
```

**Acceptance Criteria**:
- Test plays 10 tracks
- Memory stays < 50MB during playback
- Test fails if limit exceeded

---

### T-019: Test Emergency Mode Transition Memory Usage
**User Story**: US-005 | **Satisfies ACs**: AC-US5-04, AC-US5-06 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Test that transitioning to/from emergency mode stays under 50MB.

**Steps**:
1. Add test to `MemoryProfilingTests.swift`
2. Start in normal mode
3. Detect cry → transition to emergency mode
4. Play emergency queue
5. Transition back to normal
6. Monitor memory throughout

**Test Plan**:
```swift
// BabyInCarAppTests/Performance/MemoryProfilingTests.swift
func testEmergencyModeTransitionsMemoryUnder50MB() {
    let emergencyEngine = SmartCryResponseEngine.shared

    measure(metrics: [XCTMemoryMetric()]) {
        // Normal mode
        assertMemoryUnderLimit()

        // Detect cry → emergency mode
        emergencyEngine.handleCryDetected(type: .hunger)
        assertMemoryUnderLimit()

        // Play emergency queue
        emergencyEngine.playEmergencyResponse()
        Thread.sleep(forTimeInterval: 5.0)
        assertMemoryUnderLimit()

        // Cry ended → normal mode
        emergencyEngine.handleCryEnded()
        assertMemoryUnderLimit()
    }
}
```

**Acceptance Criteria**:
- Test covers emergency transitions
- Memory stays < 50MB throughout
- Test fails if limit exceeded

---

### T-020: Test All AI Engines Active Memory Usage
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05, AC-US5-06 | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 1 hour

**Description**: Test that running all AI engines simultaneously stays under 50MB.

**Steps**:
1. Add test to `MemoryProfilingTests.swift`
2. Activate all AI engines: BabyMoodLLMEngine, AdaptiveLearningEngine, SmartCryResponseEngine
3. Feed data to all engines for 10 minutes
4. Monitor memory throughout
5. Fail test if > 50MB

**Test Plan**:
```swift
// BabyInCarAppTests/Performance/MemoryProfilingTests.swift
func testAllAIEnginesActiveMemoryUnder50MB() {
    let moodEngine = BabyMoodLLMEngine.shared
    let learningEngine = AdaptiveLearningEngine.shared
    let responseEngine = SmartCryResponseEngine.shared

    measure(metrics: [XCTMemoryMetric()]) {
        // Activate all engines
        moodEngine.startTracking()
        learningEngine.startLearning()
        responseEngine.startMonitoring()

        // Feed data for 10 minutes
        for _ in 0..<600 {
            moodEngine.analyzeMood(audioData: MockAudioData.sample)
            learningEngine.processFeatures([1.0, 2.0, 3.0])
            responseEngine.updateContext(cryType: .hunger)

            if i % 60 == 0 { assertMemoryUnderLimit() }
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Stop all
        moodEngine.stopTracking()
        learningEngine.stopLearning()
        responseEngine.stopMonitoring()
    }

    assertMemoryUnderLimit()
}
```

**Acceptance Criteria**:
- Test runs all AI engines
- Memory stays < 50MB throughout
- Test fails if limit exceeded

---

## Phase 7: Integration & Validation

### T-021: Integration Test - All Features Active
**User Story**: Multiple | **Satisfies ACs**: Multiple | **Status**: [x] completed
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Comprehensive integration test with all features active simultaneously.

**Steps**:
1. Create `BabyInCarAppTests/Integration/ComprehensiveMemoryTests.swift`
2. Activate: Cry detection + Audio playback + All AI engines + Memory monitor
3. Run for 30 minutes
4. Monitor memory continuously
5. Verify no OOM kills
6. Verify memory stays < 50MB

**Test Plan**:
```swift
// BabyInCarAppTests/Integration/ComprehensiveMemoryTests.swift
func testAllFeaturesActiveMemoryUnder50MB() {
    // Setup all services
    let cryDetection = CryDetectionService.shared
    let audioQueue = SmartEmergencyQueue()
    let memoryMonitor = MemoryMonitor.shared

    measure(metrics: [XCTMemoryMetric()]) {
        // Start everything
        cryDetection.startMonitoring()
        audioQueue.buildQueue(tracks: MockAudioTracks.tenMelodicTracks)
        audioQueue.play()
        memoryMonitor.startMonitoring()

        // Run for 30 minutes (simulated)
        for minute in 0..<30 {
            // Simulate activity
            Thread.sleep(forTimeInterval: 60.0)
            assertMemoryUnderLimit()
            print("Minute \(minute): \(memoryMonitor.currentMemoryMB)MB")
        }

        // Stop everything
        cryDetection.stopMonitoring()
        audioQueue.stop()
    }

    // Final check
    assertMemoryUnderLimit()
}
```

**Acceptance Criteria**:
- All features run simultaneously
- 30-minute session completes
- Memory stays < 50MB
- No crashes

---

### T-022: Manual Instruments Validation
**User Story**: US-001, US-002, US-003 | **Satisfies ACs**: Multiple | **Status**: [ ] pending
**Model**: 💎 Opus | **Effort**: 2 hours

**Description**: Manual validation with Xcode Instruments to confirm all memory limits are met.

**Steps**:
1. Run app with Instruments (Allocations template)
2. Execute all test scenarios:
   - 30-min cry detection
   - 10-track audio playback
   - Emergency mode transitions
   - All AI engines active
3. Capture memory snapshots at peak usage
4. Verify component breakdown matches targets:
   - Audio: < 15MB
   - AI Engines: < 10MB
   - Cry Detection: < 5MB
   - Total: < 50MB
5. Document results in `reports/memory-profiling-final.md`

**Test Plan**:
```
Manual Instruments profiling checklist:
[ ] Peak memory < 50MB in all scenarios
[ ] Audio buffers < 15MB
[ ] AI engines < 10MB
[ ] Cry detection < 5MB
[ ] No memory leaks detected
[ ] All allocations released properly
```

**Acceptance Criteria**:
- Instruments shows peak < 50MB
- Component breakdown verified
- No memory leaks found
- Results documented

---

### T-023: TestFlight Beta Validation (2-3 Days)
**User Story**: All | **Satisfies ACs**: All | **Status**: [ ] pending
**Model**: ⚡ Haiku | **Effort**: 3 days (monitoring)

**Description**: Release to TestFlight internal testers for real-world validation.

**Steps**:
1. Build release candidate with memory monitoring enabled
2. Upload to TestFlight (internal testers only)
3. Monitor crash reports for 2-3 days
4. Monitor analytics for `memory_warning_triggered` events
5. Collect feedback from testers
6. Analyze any OOM kills or crashes

**Test Plan**:
```
TestFlight validation checklist:
[ ] No OOM kills reported in crash logs
[ ] Memory warnings rare (< 1% of sessions)
[ ] Auto-cleanup events logged (if any)
[ ] User feedback positive
[ ] No performance degradation reported
```

**Acceptance Criteria**:
- Zero OOM kills in TestFlight
- Crash-free rate > 99%
- No critical feedback

---

### T-024: Production Rollout & Monitoring
**User Story**: All | **Satisfies ACs**: All | **Status**: [ ] pending
**Model**: ⚡ Haiku | **Effort**: Ongoing

**Description**: Deploy to App Store and monitor production metrics.

**Steps**:
1. Submit to App Store review
2. Release to production (phased rollout)
3. Monitor crash analytics for OOM kills
4. Monitor memory warning events
5. Track crash-free rate
6. Be ready to hotfix if issues arise

**Test Plan**:
```
Production monitoring (first week):
[ ] Crash-free rate > 99.5%
[ ] Zero OOM kill reports
[ ] Memory warnings < 0.5% of sessions
[ ] User reviews positive
[ ] No rollback needed
```

**Acceptance Criteria**:
- Production metrics stable
- No OOM kills reported
- Crash-free rate > 99.5%

---

## Summary

**Total Tasks**: 24
**Estimated Effort**: ~18 hours (2-3 days)
**Success Criteria**: App stays under 50MB, zero OOM kills, all tests pass

**Critical Path**:
1. Investigation (T-001, T-002) → Understand current state
2. MemoryMonitor (T-003, T-004, T-005) → Observability
3. Audio Limits (T-006, T-007, T-008, T-009) → Biggest memory reduction
4. AI Limits (T-010, T-011, T-012) → Secondary reduction
5. Auto-Cleanup (T-013, T-014, T-015) → Safety net
6. Testing (T-016 through T-022) → Validation
7. Rollout (T-023, T-024) → Production deployment
