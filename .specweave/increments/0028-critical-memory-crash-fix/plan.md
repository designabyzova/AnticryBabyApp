---
increment: 0028-critical-memory-crash-fix
architecture_docs:
  - ../../docs/internal/architecture/system-design.md
---

# Technical Architecture Plan: Critical Memory Crash Fix

## Executive Summary

This plan addresses the critical memory crash issue where iOS terminates the app at ~111MB. The fix involves:
1. Updating MemoryMonitor thresholds from 40/45/48MB to 80/90/100MB
2. Implementing NotificationCenter cleanup handlers in 6 services
3. Adding proactive memory management patterns
4. Comprehensive test coverage

## Architecture Overview

### Current State (Problem)

```
┌─────────────────────────────────────────────────────────────┐
│  MemoryMonitor (thresholds: 40/45/48 MB - TOO LOW)         │
│  Posts: MemoryCleanupRequested notification                 │
└─────────────────────────┬───────────────────────────────────┘
                          │ NotificationCenter
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6 Services - NO HANDLERS IMPLEMENTED!                      │
│  • AudioEngine           - ignores notification             │
│  • SmartEmergencyQueue   - ignores notification             │
│  • BabyMoodLLMEngine     - ignores notification             │
│  • AdaptiveLearningEngine- ignores notification             │
│  • CryDetectionService   - ignores notification             │
│  • SmartCryResponseEngine- ignores notification             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ Memory grows unchecked
                    iOS KILLS APP @ 111MB
```

### Target State (Solution)

```
┌─────────────────────────────────────────────────────────────┐
│  MemoryMonitor (thresholds: 80/90/100 MB - REALISTIC)      │
│  Posts: MemoryCleanupRequested notification                 │
│  userInfo: ["level": "critical"|"emergency", "memoryMB": N] │
└─────────────────────────┬───────────────────────────────────┘
                          │ NotificationCenter
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6 Services - CLEANUP HANDLERS IMPLEMENTED                  │
│  • AudioEngine           → releases non-playing buffers     │
│  • SmartEmergencyQueue   → keeps current+1 track only       │
│  • BabyMoodLLMEngine     → trims sessionHistory to 20       │
│  • AdaptiveLearningEngine→ trims featureVectors to 30       │
│  • CryDetectionService   → clears deepInfantBuffer          │
│  • SmartCryResponseEngine→ clears sessionHistory            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ Memory stabilizes < 100MB
                    APP SURVIVES 30+ MINUTES
```

## Implementation Details

### Phase 1: MemoryMonitor Threshold Update

**File**: `BabyInCarApp/Services/MemoryMonitor.swift`

**Changes**:
```swift
// BEFORE (unrealistic)
private let normalThreshold: Double = 40.0
private let warningThreshold: Double = 45.0
private let criticalThreshold: Double = 48.0

// AFTER (realistic for iOS)
private let normalThreshold: Double = 80.0
private let warningThreshold: Double = 90.0
private let criticalThreshold: Double = 100.0
```

**Rationale**: iOS typically kills apps at 150-200MB for foreground apps. Setting thresholds at 80/90/100MB provides adequate warning buffer.

### Phase 2: Cleanup Handler Pattern (Shared Implementation)

All 6 services will use this standardized pattern:

```swift
// MARK: - Memory Cleanup Handler

private var cleanupObserver: NSObjectProtocol?

private func setupMemoryCleanupObserver() {
    cleanupObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("MemoryCleanupRequested"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let level = notification.userInfo?["level"] as? String else { return }
        Task { @MainActor in
            self?.handleMemoryCleanup(level: level)
        }
    }
}

private func handleMemoryCleanup(level: String) {
    switch level {
    case "critical":
        performCriticalCleanup()
    case "emergency":
        performEmergencyCleanup()
    default:
        break
    }
}

deinit {
    if let observer = cleanupObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### Phase 3: Per-Service Cleanup Strategies

#### 3.1 AudioEngine

**File**: `BabyInCarApp/Services/AudioEngine.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Release all non-playing track buffers | 10-20MB |
| Emergency | Release ALL buffers except current track | 20-30MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[AudioEngine] Critical cleanup: releasing non-playing buffers")
    // Clear playback history (keeps references to tracks)
    playbackHistory.removeAll()
    // Clear up-next queue
    upNextQueue.removeAll()
    // Invalidate any cached audio data
}

private func performEmergencyCleanup() {
    performCriticalCleanup()
    print("[AudioEngine] Emergency cleanup: aggressive buffer release")
    // Keep only currentTrack, release everything else
    originalPlaylistOrder.removeAll()
    shufflePlayedIndices.removeAll()
}
```

#### 3.2 SmartEmergencyQueue

**File**: `BabyInCarApp/Services/SmartEmergencyQueue.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Keep current + 2 upcoming tracks | 5-10MB |
| Emergency | Keep current + 1 track only | 8-15MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[SmartQueue] Critical cleanup: trimming queue to 3 tracks")
    // Keep current + 2 upcoming
    if upcomingTracks.count > 2 {
        upcomingTracks = Array(upcomingTracks.prefix(2))
    }
    playedTracks.removeAll()
    loadedTracks = Array(loadedTracks.prefix(3))
}

private func performEmergencyCleanup() {
    print("[SmartQueue] Emergency cleanup: minimal queue")
    // Keep current + 1 only
    if upcomingTracks.count > 1 {
        upcomingTracks = Array(upcomingTracks.prefix(1))
    }
    playedTracks.removeAll()
    loadedTracks = Array(loadedTracks.prefix(2))
    queuedTrackIds.removeAll()
}
```

#### 3.3 BabyMoodLLMEngine

**File**: `BabyInCarApp/Services/BabyMoodLLMEngine.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Trim sessionHistory to 50 entries | 2-5MB |
| Emergency | Trim sessionHistory to 20 entries | 3-8MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[BabyMoodLLM] Critical cleanup: trimming history to 50")
    if sessionHistory.count > 50 {
        sessionHistory = Array(sessionHistory.suffix(50))
    }
}

private func performEmergencyCleanup() {
    print("[BabyMoodLLM] Emergency cleanup: trimming history to 20")
    sessionHistory = Array(sessionHistory.suffix(20))
    strategyWeights.removeAll()  // Will be reloaded on next use
}
```

#### 3.4 AdaptiveLearningEngine

**File**: `BabyInCarApp/Services/AdaptiveLearningEngine.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Trim featureVectors to 50 | 2-5MB |
| Emergency | Trim featureVectors to 30, clear sessionHistory | 5-10MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[AdaptiveLearning] Critical cleanup: trimming vectors to 50")
    if successfulFeatureVectors.count > 50 {
        successfulFeatureVectors = Array(successfulFeatureVectors.suffix(50))
    }
}

private func performEmergencyCleanup() {
    print("[AdaptiveLearning] Emergency cleanup: aggressive trim")
    successfulFeatureVectors = Array(successfulFeatureVectors.suffix(30))
    sessionHistory = Array(sessionHistory.suffix(50))
    effectivenessMatrix = .empty  // Will rebuild from persisted data
}
```

#### 3.5 CryDetectionService

**File**: `BabyInCarApp/Services/CryDetectionService.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Clear deepInfantBuffer, reduce audioBuffer | 1-3MB |
| Emergency | + Temporarily disable ML enhancement | 2-5MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[CryDetection] Critical cleanup: clearing buffers")
    deepInfantBuffer.removeAll(keepingCapacity: true)
    deepInfantBufferWriteIndex = 0
    cryPatternBuffer.removeAll()
    cryTypeHistory.removeAll()
}

private func performEmergencyCleanup() {
    performCriticalCleanup()
    print("[CryDetection] Emergency cleanup: disabling ML temporarily")
    // Temporarily disable ML to save memory (rule-based still works)
    useMLEnhancement = false
    useDeepInfant = false
    audioBuffer.removeAll(keepingCapacity: true)
}
```

#### 3.6 SmartCryResponseEngine

**File**: `BabyInCarApp/Services/SmartCryResponseEngine.swift`

| Level | Action | Expected Reduction |
|-------|--------|-------------------|
| Critical | Clear responseHistory, soundEffectiveness | 1-2MB |
| Emergency | + Clear sessionHistory, recentlyPlayedSounds | 2-3MB |

**Implementation**:
```swift
private func performCriticalCleanup() {
    print("[SmartCryResponse] Critical cleanup: clearing response history")
    responseHistory.removeAll()
    soundEffectiveness.removeAll()
}

private func performEmergencyCleanup() {
    performCriticalCleanup()
    print("[SmartCryResponse] Emergency cleanup: full reset")
    sessionHistory.removeAll()
    recentlyPlayedSounds.removeAll()
}
```

### Phase 4: Proactive Memory Management

**Changes to existing code** (not new handlers):

1. **SmartEmergencyQueue**: Reduce `maxConcurrentLoadedTracks` from 3 to 2
2. **AudioEngine**: Implement LRU cache with max 5 buffers
3. **AI Engines**: Auto-trim at 50% capacity (not just when full)

### Phase 5: Main Thread Safety

All cleanup handlers MUST:
- Use `@MainActor` isolation (services already are `@MainActor`)
- Complete within 100ms (no blocking operations)
- Use `removeAll(keepingCapacity: true)` where appropriate to avoid deallocation spikes
- Log before/after memory for debugging

## Test Strategy

### Unit Tests (MemoryMonitorTests.swift)

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

```swift
@Suite("Service Memory Cleanup Handlers")
@MainActor
struct ServiceMemoryCleanupTests {
    @Test("AudioEngine responds to critical cleanup")
    func audioEngineCriticalCleanup() async {
        let engine = AudioEngine.shared
        // Pre-populate history
        // ... setup code ...

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

```swift
func testExtendedMonitoringSessionMemory() throws {
    // Simulate 5-minute monitoring session
    let expectation = XCTestExpectation(description: "Memory stays under 100MB")

    measure(metrics: [XCTMemoryMetric()]) {
        // Run monitoring simulation
        // Verify peak memory < 100MB
    }
}
```

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Cleanup too aggressive | Keep minimum data for functionality (current track, 20 history entries) |
| Race condition | All handlers run on MainActor |
| Audio interruption | Never release currently playing track |
| ML accuracy drop | Emergency-only ML disable; re-enable when memory recovers |
| Over-cleanup | Only cleanup at critical/emergency, not warning |

## Success Metrics

1. App survives 30-minute monitoring session without iOS termination
2. Peak memory stays below 100MB during normal operation
3. Cleanup reduces memory by at least 15MB when triggered
4. All 6 services log cleanup actions with before/after memory
5. Audio playback continues uninterrupted during cleanup

## Implementation Order

1. **T-001**: Update MemoryMonitor thresholds (80/90/100MB)
2. **T-002**: Update existing tests for new thresholds
3. **T-003**: Add cleanup handler to AudioEngine
4. **T-004**: Add cleanup handler to SmartEmergencyQueue
5. **T-005**: Add cleanup handler to BabyMoodLLMEngine
6. **T-006**: Add cleanup handler to AdaptiveLearningEngine
7. **T-007**: Add cleanup handler to CryDetectionService
8. **T-008**: Add cleanup handler to SmartCryResponseEngine
9. **T-009**: Integration tests for all cleanup handlers
10. **T-010**: Performance test with 80MB baseline
11. **T-011**: 5-minute monitoring session test

## Dependencies

- Existing MemoryMonitor.swift (observer pattern already in place)
- NotificationCenter (iOS standard)
- All services are `@MainActor` singletons (thread-safe pattern)
