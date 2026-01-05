# Implementation Plan: Memory Leak Prevention System

## Overview

This hotfix addresses critical memory leaks causing iOS to kill the app at 85MB+. Target: Stay under 50MB during all usage scenarios.

## Architecture

### New Component: MemoryMonitor Service

```swift
// Services/MemoryMonitor.swift
class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()

    @Published var currentMemoryMB: Double = 0
    @Published var memoryBreakdown: [String: Double] = [:]
    @Published var warningLevel: MemoryWarningLevel = .normal

    enum MemoryWarningLevel {
        case normal      // < 40MB
        case warning     // 40-45MB
        case critical    // 45-48MB
        case emergency   // > 48MB
    }

    // Monitor every 5 seconds
    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMemoryUsage()
            self.checkThresholds()
        }
    }

    private func updateMemoryUsage() {
        // Use task_info to get memory usage
        let usage = getMemoryUsage()
        DispatchQueue.main.async {
            self.currentMemoryMB = usage
            self.updateBreakdown()
        }
    }

    private func checkThresholds() {
        switch currentMemoryMB {
        case 0..<40:
            warningLevel = .normal
        case 40..<45:
            warningLevel = .warning
            logWarning()
        case 45..<48:
            warningLevel = .critical
            triggerAutoCleanup()
        default:
            warningLevel = .emergency
            triggerAggressiveCleanup()
        }
    }
}
```

### Modified Components

#### 1. SmartEmergencyQueue
**Problem**: Loading 10 tracks simultaneously (~30MB)
**Solution**: Limit to 3 concurrent loaded tracks, preload next only

```swift
// Services/SmartEmergencyQueue.swift
class SmartEmergencyQueue {
    private let maxConcurrentLoadedTracks = 3  // ← NEW LIMIT (was unlimited)
    private var loadedTracks: [AudioTrack] = []
    private var queuedTrackIds: [String] = []

    func buildQueue() {
        // Load first 3 tracks
        loadedTracks = queue.prefix(3).map { loadTrack($0) }
        queuedTrackIds = queue.dropFirst(3).map { $0.id }
    }

    func onTrackEnded() {
        // Remove finished track, load next if available
        if !loadedTracks.isEmpty {
            loadedTracks.removeFirst()
        }
        if let nextId = queuedTrackIds.first {
            queuedTrackIds.removeFirst()
            loadedTracks.append(loadTrack(nextId))
        }
    }
}
```

#### 2. AudioEngine
**Problem**: May be holding onto old AVAudioPlayerNode buffers
**Solution**: Explicit buffer release after playback

```swift
// Services/AudioEngine.swift
extension AudioEngine {
    func releaseBuffer(for playerNode: AVAudioPlayerNode) {
        playerNode.stop()
        playerNode.reset() // ← Force buffer release
    }

    func cleanup() {
        // Release all inactive player nodes
        players.removeAll { !$0.isPlaying }
    }
}
```

#### 3. AI Engines - Reduce History Limits

```swift
// Services/BabyMoodLLMEngine.swift
class BabyMoodLLMEngine {
    private let maxHistorySize = 100  // ← REDUCED from 500
    private var moodHistory: [MoodEntry] = []

    func addMoodEntry(_ entry: MoodEntry) {
        moodHistory.append(entry)
        if moodHistory.count > maxHistorySize {
            moodHistory.removeFirst(moodHistory.count - maxHistorySize) // LRU eviction
        }
    }
}

// Services/AdaptiveLearningEngine.swift
class AdaptiveLearningEngine {
    private let maxSessionHistory = 200  // ← REDUCED from 1000
    private let maxSuccessfulFeatureVectors = 100  // ← REDUCED from 500

    // Implement LRU cache for both arrays
}

// Services/SmartCryResponseEngine.swift (already bounded, verify)
class SmartCryResponseEngine {
    private let maxSessionHistory = 50  // ← Already good
    private let maxRecentSounds = 5     // ← Already good
}
```

## Implementation Phases

### Phase 1: Investigation (4 hours)
1. Profile with Xcode Instruments (Allocations template)
2. Reproduce 85MB crash scenario
3. Identify exact memory breakdown by component
4. Validate assumptions about audio buffers

### Phase 2: MemoryMonitor Service (3 hours)
1. Create `Services/MemoryMonitor.swift`
2. Implement `task_info` memory tracking
3. Add breakdown by component (estimate heuristics)
4. Add threshold-based warnings

### Phase 3: Audio Limits (3 hours)
1. Update `SmartEmergencyQueue` with `maxConcurrentLoadedTracks = 3`
2. Add buffer release logic to `AudioEngine`
3. Update `DynamicSoundMixer` to stream instead of cache
4. Verify audio memory < 15MB

### Phase 4: AI Limits (2 hours)
1. Reduce `BabyMoodLLMEngine.maxHistorySize` to 100
2. Reduce `AdaptiveLearningEngine` limits (history: 200, vectors: 100)
3. Implement LRU eviction for all AI engines
4. Verify AI memory < 10MB

### Phase 5: Auto-Cleanup (2 hours)
1. Implement `MemoryMonitor.triggerAutoCleanup()` at 45MB
2. Implement `MemoryMonitor.triggerAggressiveCleanup()` at 48MB
3. Add cleanup delegates to all services
4. Test cleanup reduces memory to < 35MB

### Phase 6: Memory Profiling Tests (6 hours)
1. Create `BabyInCarAppTests/Performance/MemoryProfilingTests.swift`
2. Test: 30-min cry detection session
3. Test: 10-track audio playback
4. Test: Emergency mode transitions
5. Test: All AI engines active
6. Add CI integration for memory tests

## Testing Strategy

### Unit Tests
- `MemoryMonitorTests.swift` - Verify thresholds and cleanup triggers
- `SmartEmergencyQueueTests.swift` - Verify 3-track limit enforced
- `AudioEngineTests.swift` - Verify buffer release
- `AdaptiveLearningEngineTests.swift` - Verify LRU eviction

### Performance Tests
- `MemoryProfilingTests.swift` - XCTestMetric-based memory assertions
- Use `XCTMemoryMetric` to measure peak memory
- Fail test if > 50MB during any scenario

### Manual Validation
- Run Xcode Instruments Allocations template
- Monitor app for 30+ minutes with all features active
- Verify no iOS OOM kills

## Success Metrics

| Metric | Before | Target | How to Measure |
|--------|--------|--------|----------------|
| Peak Memory | 85MB | < 50MB | Xcode Instruments |
| Audio Buffers | ~30MB | < 15MB | Instruments (AVAudioPlayerNode) |
| AI Engines | ~20MB | < 10MB | Instruments (Array allocations) |
| Crash-Free Sessions | 70% | 100% | No OOM kills in 30-min test |

## Rollout Plan

1. **Development**: Implement on feature branch
2. **Testing**: Run all XCTests + Instruments profiling
3. **TestFlight**: Release to internal testers (2-3 days monitoring)
4. **Production**: Deploy to App Store if no regressions

## Monitoring & Alerts

### Development
- Xcode console logs from `MemoryMonitor`
- Unit test failures if memory limits breached

### Production (Future)
- Analytics event: `memory_warning_triggered`
- Analytics event: `memory_cleanup_auto`
- Dashboard: Memory usage P50, P95, P99

## Rollback Plan

If memory issues persist or new crashes introduced:
1. Revert all changes
2. Keep `MemoryMonitor` service for observability
3. Investigate alternative solutions (e.g., lazy loading, pagination)

## Dependencies

- **Xcode 15+**: For `XCTMemoryMetric` and Instruments
- **iOS 16+**: For `task_info` memory APIs
- **Swift 5.9+**: For LRU cache implementation

## Open Questions

1. **Q**: Should we cache audio in a circular buffer instead of full files?
   **A**: Explore streaming from R2 directly (future increment)

2. **Q**: Can we reduce AI model sizes?
   **A**: Out of scope - focus on history limits first

3. **Q**: Should we add user-facing memory stats in Settings?
   **A**: Yes, but defer to separate increment (nice-to-have)
