---
increment: 0022-memory-leak-prevention
title: "Comprehensive Memory Leak Prevention System"
priority: P1
status: planned
type: hotfix
created: 2026-01-04
dependencies: []
structure: user-stories
tech_stack:
  detected_from: "project.pbxproj"
  language: "swift"
  framework: "swiftui"
  platform: ["ios"]
---

# FS-022: Comprehensive Memory Leak Prevention System

## Problem Statement

**CRITICAL**: The app "BabyInCarApp" is being killed by iOS for excessive memory usage (85MB+):

```
The app "BabyInCarApp" has been killed by the operating system because it is using too much memory.
Domain: IDEDebugSessionErrorDomain
Code: 11
Recovery Suggestion: Use a memory profiling tool to track the process memory usage.
Memory pressure changed: Emergency → Warning (85MB)
```

### Root Causes Identified

Previous fix (0012-memory-crash-fix) only addressed `CryPatternTracker.intensitySamples` unbounded growth. The crash on 2026-01-04 reveals **additional memory leaks**:

1. **Audio Streaming Buffers** (PRIMARY SUSPECT - crash during playback)
   - `SmartEmergencyQueue` loading 10 MELODIC tracks simultaneously
   - `AudioEngine` may be holding onto old buffers
   - `DynamicSoundMixer` potentially caching too much

2. **AI Engine Memory** (SECONDARY)
   - `BabyMoodLLMEngine` (maxHistorySize: 500)
   - `AdaptiveLearningEngine` (successfulFeatureVectors: 500, sessionHistory: 1000)
   - `SmartCryResponseEngine` (maxSessionHistory: 50, maxRecentSounds: 5)

3. **Unbounded Arrays** (ALREADY FIXED IN 0012, but verify)
   - CryPatternTracker (fixed: maxIntensitySamplesPerBurst = 200)
   - Other services verified in 0012 but need re-validation

4. **No Global Monitoring** (CRITICAL GAP)
   - No runtime memory tracking
   - No alerts when approaching limits
   - No automatic cleanup triggers

## Success Criteria

- ✅ App stays **under 50MB** during intensive usage
- ✅ No iOS OOM kills during 30+ minute sessions
- ✅ Memory usage stable across all scenarios:
  - Continuous cry detection (30 min)
  - Audio playback (10 tracks queued)
  - Emergency mode transitions
  - All AI engines active
- ✅ Memory profiling tests catch regressions
- ✅ Runtime monitoring alerts before OOM

## Technical Analysis

### Memory Budget (50MB Target)

| Component | Current (Est) | Target | Strategy |
|-----------|---------------|--------|----------|
| Audio Buffers | ~30MB | 15MB | Limit concurrent loaded tracks, streaming |
| AI Engines | ~20MB | 10MB | LRU cache, reduce history limits |
| Cry Detection | ~10MB | 5MB | Verified bounded in 0012 |
| UI/System | ~15MB | 10MB | Profile & optimize |
| Headroom | ~10MB | 10MB | Safety margin |
| **TOTAL** | **~85MB** | **50MB** | -35MB reduction needed |

### Investigation Areas

1. **Audio System** (HIGH PRIORITY)
   - `SmartEmergencyQueue.swift:762` - "Built queue with 10 MELODIC tracks"
   - Are all 10 tracks loaded into memory?
   - Does `AudioEngine` release old buffers?
   - Profile: AVAudioPlayerNode buffer usage

2. **AI Engines** (MEDIUM PRIORITY)
   - `BabyMoodLLMEngine` - 500 history items ×  size?
   - `AdaptiveLearningEngine` - 500 feature vectors × size?
   - Implement LRU cache instead of unlimited growth

3. **Global Limits** (HIGH PRIORITY)
   - NO central memory manager
   - NO app-wide limit enforcement
   - ADD: `MemoryMonitor.swift` service

## User Stories

### US-001: Global Memory Monitoring Service
**Project**: main
**As a** system, I want continuous memory monitoring
**So that** I can detect and prevent OOM crashes before they happen

**Acceptance Criteria**:
- [ ] **AC-US1-01**: `MemoryMonitor.swift` service tracks app memory usage every 5 seconds
- [ ] **AC-US1-02**: Emits warnings at 40MB (80% of 50MB target)
- [ ] **AC-US1-03**: Triggers automatic cleanup at 45MB (90% of target)
- [ ] **AC-US1-04**: Logs memory breakdown by component (audio, AI, detection)
- [ ] **AC-US1-05**: Provides real-time memory stats to debug UI

### US-002: Audio Buffer Management Limits
**Project**: main
**As a** audio system, I want strict buffer limits
**So that** I don't exceed 15MB during intensive playback

**Acceptance Criteria**:
- [ ] **AC-US2-01**: `SmartEmergencyQueue` limits concurrent loaded tracks to 3 (not 10)
- [ ] **AC-US2-02**: `AudioEngine` releases buffers for tracks not in active use
- [ ] **AC-US2-03**: `DynamicSoundMixer` uses streaming instead of full caching
- [ ] **AC-US2-04**: Total audio buffer usage stays under 15MB
- [ ] **AC-US2-05**: Preload next track only, not entire queue

### US-003: AI Engine Memory Limits
**Project**: main
**As a** AI system, I want LRU caching and reduced limits
**So that** AI engines stay under 10MB combined

**Acceptance Criteria**:
- [ ] **AC-US3-01**: `BabyMoodLLMEngine.maxHistorySize` reduced from 500 to 100
- [ ] **AC-US3-02**: `AdaptiveLearningEngine.successfulFeatureVectors` reduced from 500 to 100
- [ ] **AC-US3-03**: `AdaptiveLearningEngine.maxSessionHistory` reduced from 1000 to 200
- [ ] **AC-US3-04**: All AI engines implement LRU eviction for history
- [ ] **AC-US3-05**: Combined AI engine memory usage < 10MB

### US-004: Verify Cry Detection Bounds (Re-validation)
**Project**: main
**As a** cry detection system, I want re-validation of memory limits
**So that** I ensure 0012 fixes are still effective

**Acceptance Criteria**:
- [ ] **AC-US4-01**: `CryPatternTracker.maxIntensitySamplesPerBurst` still enforced (200 limit)
- [ ] **AC-US4-02**: All cry detection services have bounded arrays verified
- [ ] **AC-US4-03**: Cry detection memory usage < 5MB during extended sessions
- [ ] **AC-US4-04**: No unbounded growth in any detection service

### US-005: Automated Memory Profiling Tests
**Project**: main
**As a** developer, I want XCTest memory profiling
**So that** regressions are caught in CI before release

**Acceptance Criteria**:
- [ ] **AC-US5-01**: XCTestCase `MemoryProfilingTests.swift` created
- [ ] **AC-US5-02**: Test: 30-min cry detection session stays < 50MB
- [ ] **AC-US5-03**: Test: 10-track audio playback stays < 50MB
- [ ] **AC-US5-04**: Test: Emergency mode transitions stay < 50MB
- [ ] **AC-US5-05**: Test: All AI engines active simultaneously < 50MB
- [ ] **AC-US5-06**: Tests fail if memory exceeds 50MB threshold

### US-006: Runtime Memory Alerts & Auto-Cleanup
**Project**: main
**As a** user, I want automatic memory management
**So that** the app never crashes from OOM

**Acceptance Criteria**:
- [ ] **AC-US6-01**: At 40MB warning: Log detailed breakdown
- [ ] **AC-US6-02**: At 45MB critical: Trigger automatic cleanup (clear caches, release old buffers)
- [ ] **AC-US6-03**: At 48MB emergency: Force aggressive cleanup (stop non-essential services)
- [ ] **AC-US6-04**: User sees non-intrusive notification if cleanup triggered
- [ ] **AC-US6-05**: Memory usage drops to < 35MB after auto-cleanup

## Out of Scope

- Rewriting audio engine architecture (keep current streaming design)
- Removing AI features (just optimize limits)
- Changing UI memory usage (focus on services only)

## Dependencies

- Increment 0012 (memory-crash-fix) - builds on previous fixes
- Xcode Instruments - for memory profiling validation

## Estimated Effort

- Investigation: 4 hours (profile with Instruments)
- Implementation: 8 hours (MemoryMonitor, limits, LRU caches)
- Testing: 6 hours (XCTest profiling, validation)
- **Total: ~18 hours (2-3 days)**

## Verification Plan

1. **Pre-fix Baseline**:
   - Profile current memory with Xcode Instruments
   - Reproduce 85MB crash scenario

2. **Post-fix Validation**:
   - All XCTest memory profiling tests pass
   - 30-min session: Memory < 50MB (currently 85MB)
   - Peak memory during intensive use < 50MB
   - No iOS OOM kills in test scenarios

3. **Regression Prevention**:
   - Memory profiling tests run in CI
   - `MemoryMonitor` logs reviewed weekly
   - Alerts if approaching 50MB in production

## Related Increments

- **0012-memory-crash-fix**: Fixed CryPatternTracker unbounded array (COMPLETE)
- This increment addresses remaining memory leaks in audio and AI systems
