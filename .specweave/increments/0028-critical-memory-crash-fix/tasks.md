---
increment: 0028-critical-memory-crash-fix
status: in-progress
estimated_tasks: 15
estimated_hours: 20
completed_tasks: 15
---

# Tasks for Critical Memory Crash Fix

## Phase 1: Update MemoryMonitor Thresholds

### T-001: Update MemoryMonitor threshold constants
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/MemoryMonitor.swift`
**Estimate**: 0.5 hours

**Implementation**:
- Update `normalThreshold` from 40.0 to 80.0
- Update `warningThreshold` from 45.0 to 90.0
- Update `criticalThreshold` from 48.0 to 100.0
- Update comments to reflect iOS memory limits

**Test**:
```swift
Given MemoryMonitor with new thresholds
When memory is at 79MB
Then warningLevel should be .normal

When memory is at 85MB
Then warningLevel should be .warning

When memory is at 95MB
Then warningLevel should be .critical

When memory is at 105MB
Then warningLevel should be .emergency
```

### T-002: Update MemoryMonitor tests for new thresholds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**File**: `BabyInCarApp/BabyInCarAppTests/Services/MemoryMonitorTests.swift`
**Estimate**: 1 hour

**Implementation**:
- Update test expectations from 40/45/48 to 80/90/100
- Add test for emergency threshold at 100MB+
- Verify notification posting at new thresholds

**Test**:
```swift
Given MemoryMonitor test suite
When all tests run
Then all threshold tests pass with new values
And no test failures occur
```

## Phase 2: Implement Cleanup Handlers in Services

### T-003: Add cleanup handler to AudioEngine
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/AudioEngine.swift`
**Estimate**: 2 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: clear playbackHistory, upNextQueue
- Implement `performEmergencyCleanup()`: + clear originalPlaylistOrder, shufflePlayedIndices
- Add cleanup observer removal in deinit

**Test**:
```swift
Given AudioEngine with playback history populated
When MemoryCleanupRequested notification posted with level="critical"
Then playbackHistory is cleared
And upNextQueue is cleared
And currentTrack is NOT cleared
And memory reduction >= 10MB

When notification posted with level="emergency"
Then all buffers cleared except currentTrack
And memory reduction >= 20MB
```

### T-004: Add cleanup handler to SmartEmergencyQueue
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02, AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/SmartEmergencyQueue.swift`
**Estimate**: 2 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: trim upcomingTracks to 2, clear playedTracks
- Implement `performEmergencyCleanup()`: trim upcomingTracks to 1, clear queuedTrackIds
- Add cleanup observer removal in deinit

**Test**:
```swift
Given SmartEmergencyQueue with 10 upcoming tracks
When MemoryCleanupRequested with level="critical"
Then upcomingTracks.count == 2
And playedTracks is empty
And memory reduction >= 5MB

When level="emergency"
Then upcomingTracks.count == 1
And queuedTrackIds is empty
And memory reduction >= 8MB
```

### T-005: Add cleanup handler to BabyMoodLLMEngine
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03, AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/BabyMoodLLMEngine.swift`
**Estimate**: 1.5 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: trim sessionHistory to 50
- Implement `performEmergencyCleanup()`: trim sessionHistory to 20, clear strategyWeights
- Add cleanup observer removal in deinit

**Test**:
```swift
Given BabyMoodLLMEngine with 100 sessionHistory entries
When MemoryCleanupRequested with level="critical"
Then sessionHistory.count == 50
And memory reduction >= 2MB

When level="emergency"
Then sessionHistory.count == 20
And strategyWeights is empty
And memory reduction >= 3MB
```

### T-006: Add cleanup handler to AdaptiveLearningEngine
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04, AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/AdaptiveLearningEngine.swift`
**Estimate**: 1.5 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: trim successfulFeatureVectors to 50
- Implement `performEmergencyCleanup()`: trim to 30, clear effectivenessMatrix
- Add cleanup observer removal in deinit

**Test**:
```swift
Given AdaptiveLearningEngine with 100 feature vectors
When MemoryCleanupRequested with level="critical"
Then successfulFeatureVectors.count == 50
And memory reduction >= 2MB

When level="emergency"
Then successfulFeatureVectors.count == 30
And effectivenessMatrix is empty
And memory reduction >= 5MB
```

### T-007: Add cleanup handler to CryDetectionService
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05, AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/CryDetectionService.swift`
**Estimate**: 1.5 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: clear deepInfantBuffer, cryPatternBuffer
- Implement `performEmergencyCleanup()`: + disable ML enhancement temporarily
- Add cleanup observer removal in deinit

**Test**:
```swift
Given CryDetectionService with populated buffers
When MemoryCleanupRequested with level="critical"
Then deepInfantBuffer is cleared
And cryPatternBuffer is cleared
And useMLEnhancement remains true
And memory reduction >= 1MB

When level="emergency"
Then useMLEnhancement == false
And audioBuffer is cleared
And memory reduction >= 2MB
```

### T-008: Add cleanup handler to SmartCryResponseEngine
**User Story**: US-002 | **Satisfies ACs**: AC-US2-06 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/SmartCryResponseEngine.swift`
**Estimate**: 1.5 hours

**Implementation**:
- Add `cleanupObserver` property
- Implement `setupMemoryCleanupObserver()` in init
- Implement `performCriticalCleanup()`: clear responseHistory, soundEffectiveness
- Implement `performEmergencyCleanup()`: + clear sessionHistory, recentlyPlayedSounds
- Add cleanup observer removal in deinit

**Test**:
```swift
Given SmartCryResponseEngine with response history
When MemoryCleanupRequested with level="critical"
Then responseHistory is cleared
And soundEffectiveness is cleared
And memory reduction >= 1MB

When level="emergency"
Then sessionHistory is cleared
And recentlyPlayedSounds is cleared
And memory reduction >= 2MB
```

## Phase 3: Proactive Memory Management

### T-009: Reduce SmartEmergencyQueue maxConcurrentLoadedTracks
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/SmartEmergencyQueue.swift`
**Estimate**: 0.5 hours

**Implementation**:
- Update `maxConcurrentLoadedTracks` from 3 to 2
- Verify queue loading logic respects new limit

**Test**:
```swift
Given SmartEmergencyQueue starting ambient mode
When queue builds
Then loadedTracks.count <= 2
And remaining tracks stay queued (not loaded)
```

### T-010: Implement LRU cache in AudioEngine
**User Story**: US-003 | **Satisfies ACs**: AC-US3-02 | **Status**: [x] completed
**File**: `BabyInCarApp/Services/AudioEngine.swift`
**Estimate**: 2 hours

**Implementation**:
- Add `recentlyPlayedBuffers` LRU cache with max 5 entries
- Implement cache eviction logic
- Update playback to use cache

**Test**:
```swift
Given AudioEngine with LRU cache
When 6 tracks played in sequence
Then recentlyPlayedBuffers.count == 5
And oldest track buffer evicted
And most recent 5 tracks cached
```

### T-011: Add auto-trim to AI engines at 50% capacity
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed
**Files**: `BabyInCarApp/Services/BabyMoodLLMEngine.swift`, `AdaptiveLearningEngine.swift`
**Estimate**: 1.5 hours

**Implementation**:
- Add proactive trimming when history reaches 50 entries (50% of 100)
- Add proactive trimming when vectors reach 50 entries
- Log proactive trims for debugging

**Test**:
```swift
Given BabyMoodLLMEngine with 49 history entries
When new entry added (total 50)
Then auto-trim triggered
And history trimmed to 40 entries
And cleanup is gradual, not emergency

Given AdaptiveLearningEngine with 49 vectors
When new vector added
Then auto-trim triggered
And vectors trimmed to 40
```

## Phase 4: Comprehensive Testing

### T-012: Create integration tests for cleanup handlers
**User Story**: US-004 | **Satisfies ACs**: AC-US4-02, AC-US4-03 | **Status**: [x] completed
**File**: `BabyInCarApp/BabyInCarAppTests/Services/ServiceMemoryCleanupTests.swift`
**Estimate**: 3 hours

**Implementation**:
- Create test suite with mock notification posting
- Test each service's cleanup handler (6 services)
- Verify memory reduction with before/after measurement
- Test both critical and emergency levels

**Test**:
```swift
Given all 6 services with populated data
When MemoryCleanupRequested posted with level="critical"
Then all services cleanup handlers invoked
And total memory reduction >= 15MB
And no crashes occur
And services remain functional

When level="emergency"
Then aggressive cleanup performed
And total memory reduction >= 30MB
```

### T-013: Create performance test with 80MB baseline
**User Story**: US-004 | **Satisfies ACs**: AC-US4-04 | **Status**: [x] completed
**File**: `BabyInCarApp/BabyInCarAppTests/Performance/MemoryProfilingTests.swift`
**Estimate**: 2 hours

**Implementation**:
- Create XCTest with XCTMemoryMetric
- Set 80MB baseline expectation
- Simulate normal app usage (audio + cry detection)
- Verify memory stays under baseline

**Test**:
```swift
Given app in normal operation mode
When 5-minute simulation runs
Then peak memory <= 80MB
And no cleanup triggers (memory stays in normal range)
And baseline test passes
```

### T-014: Create extended monitoring session test
**User Story**: US-004 | **Satisfies ACs**: AC-US4-05 | **Status**: [x] completed
**File**: `BabyInCarApp/BabyInCarAppTests/Performance/MemoryProfilingTests.swift`
**Estimate**: 2 hours

**Implementation**:
- Simulate 5-minute monitoring session
- Include audio playback, cry detection, AI analysis
- Measure peak memory
- Verify no iOS termination

**Test**:
```swift
Given app monitoring for 5 minutes
When cry detected and AI responds
And audio plays continuously
Then peak memory < 100MB
And app not terminated by iOS
And cleanup handlers successfully maintain memory
```

### T-015: Verify cleanup handlers respond to both levels
**User Story**: US-004 | **Satisfies ACs**: AC-US4-02 | **Status**: [x] completed
**File**: `BabyInCarApp/BabyInCarAppTests/Services/ServiceMemoryCleanupTests.swift`
**Estimate**: 1 hour

**Implementation**:
- Test each service with "critical" notification
- Test each service with "emergency" notification
- Verify different cleanup strategies applied
- Ensure emergency is more aggressive than critical

**Test**:
```swift
Given service with full data
When MemoryCleanupRequested with level="critical"
Then moderate cleanup performed

When level="emergency"
Then aggressive cleanup performed
And emergency reduction > critical reduction
And service checks userInfo["level"] correctly
```

## Summary

**Total Tasks**: 15
**Total Estimated Hours**: 20 hours (~2.5 days)

**Critical Path**:
1. T-001, T-002 (thresholds) → 1.5 hours
2. T-003 through T-008 (cleanup handlers) → 10 hours
3. T-009 through T-011 (proactive management) → 4 hours
4. T-012 through T-015 (testing) → 8 hours

**Success Criteria**:
- All 15 tasks completed
- All tests passing (unit + integration + performance)
- App survives 30-minute session without crash
- Peak memory < 100MB during normal operation
