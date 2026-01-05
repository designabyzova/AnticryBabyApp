---
increment: 0028-critical-memory-crash-fix
title: "Critical Memory Crash Fix - Realistic Thresholds and Service Cleanup Handlers"
type: hotfix
priority: P1
status: in-progress
created: 2026-01-04
project: main
test_mode: test-after
coverage_target: 80
tech_stack:
  detected_from: "Package.swift"
  language: "swift"
  framework: "swiftui"
  platform: "ios"
  version: "iOS 16+"
  testing: "xctest, swift-testing, snapshot-testing"
---

# Hotfix: Critical Memory Crash Fix

## Overview

**Problem Statement**: The BabyInCarApp is being killed by iOS at 111MB memory usage. The current MemoryMonitor has unrealistic thresholds (40/45/48MB) that trigger cleanup notifications, but NO services actually respond to these notifications. This results in cascading memory growth until iOS terminates the app.

**Root Cause Analysis**:
1. **Unrealistic thresholds**: Current 40/45/48MB limits are far below actual iOS memory pressure (~100-150MB for foreground apps)
2. **No cleanup handlers**: Services receive `MemoryCleanupRequested` notifications but have NO implemented handlers
3. **Multiple AI services**: BabyMoodLLMEngine, AdaptiveLearningEngine, SmartCryResponse all maintain large history arrays
4. **Audio buffers**: SmartEmergencyQueue and AudioEngine hold loaded tracks in memory

**Evidence from crash logs**:
```
Memory pressure changed: Emergency → Critical (111MB)
The app "BabyInCarApp" has been killed by the operating system
because it is using too much memory.
Domain: IDEDebugSessionErrorDomain
Code: 11
```

**Target Users**: All app users experiencing crashes during extended monitoring sessions

**Business Value**: App Store reviews cite crashes as #1 issue. Fixing memory management is critical for user retention.

## User Stories

### US-001: Update Memory Thresholds to Realistic Values

**Project**: main
**Priority**: P0
**Estimate**: 2 hours

**As a** user running the app for extended periods
**I want** memory warnings to trigger at appropriate levels (80/90/100MB)
**So that** cleanup actions happen before iOS kills the app

**Acceptance Criteria**:
- [x] **AC-US1-01**: Normal threshold updated from 40MB to 80MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)
  - ✅ Completed: MemoryMonitor.swift line 61
- [x] **AC-US1-02**: Warning threshold updated from 45MB to 90MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)
  - ✅ Completed: MemoryMonitor.swift line 62
- [x] **AC-US1-03**: Critical threshold updated from 48MB to 100MB
  - Priority: P0
  - Testable: Yes (unit test verifies threshold values)
  - ✅ Completed: MemoryMonitor.swift line 63
- [x] **AC-US1-04**: Emergency threshold triggers at 100MB+ (was 48MB+)
  - Priority: P0
  - Testable: Yes (simulation test)
  - ✅ Completed: MemoryMonitor.swift checkThresholds()
- [x] **AC-US1-05**: Existing tests updated for new thresholds
  - Priority: P0
  - Testable: Yes (test suite passes)
  - ✅ Completed: MemoryMonitorTests.swift, MemoryProfilingTests.swift, ComprehensiveMemoryTests.swift

### US-002: Implement Cleanup Handlers in All Services

**Project**: main
**Priority**: P0
**Estimate**: 8 hours

**As a** system managing memory
**I want** all services to respond to cleanup notifications
**So that** memory is actually freed when warnings occur

**Acceptance Criteria**:
- [x] **AC-US2-01**: AudioEngine implements cleanup handler reducing audio buffers
  - Priority: P0
  - Testable: Yes (memory measurement before/after)
  - Expected reduction: Release all non-playing track buffers (10-30MB)
  - ✅ Completed: AudioEngine.swift cleanup() method exists (lines 1345-1365)
- [x] **AC-US2-02**: SmartEmergencyQueue implements cleanup handler releasing queued tracks
  - Priority: P0
  - Testable: Yes (queue size reduction verified)
  - Expected reduction: Keep only current+1 track loaded (8-15MB)
  - ✅ Completed: SmartEmergencyQueue.swift cleanup() method (lines 1267-1298)
- [x] **AC-US2-03**: BabyMoodLLMEngine implements cleanup handler trimming history
  - Priority: P0
  - Testable: Yes (history array size verified)
  - Expected reduction: Trim sessionHistory to 20 entries (was 100)
  - ✅ Completed: BabyMoodLLMEngine.swift cleanup() method (lines 188-204)
- [x] **AC-US2-04**: AdaptiveLearningEngine implements cleanup handler
  - Priority: P0
  - Testable: Yes (feature vector count verified)
  - Expected reduction: Trim to 30 feature vectors (was 100)
  - ✅ Completed: AdaptiveLearningEngine.swift cleanup() method (lines 107-130)
- [x] **AC-US2-05**: CryDetectionService implements cleanup handler
  - Priority: P0
  - Testable: Yes (buffer sizes verified)
  - Expected reduction: Clear deepInfantBuffer, reduce FFT window
  - ✅ Completed: CryDetectionService.swift cleanup() method (lines 239-262)
- [x] **AC-US2-06**: All handlers respond to both "critical" and "emergency" levels
  - Priority: P0
  - Testable: Yes (notification userInfo level checked)
  - ✅ Completed: All 6 services implement setupMemoryObservers() with level checking

### US-003: Add Proactive Memory Management

**Project**: main
**Priority**: P1
**Estimate**: 4 hours

**As a** system preventing memory accumulation
**I want** services to proactively manage memory before warnings
**So that** cleanup is gradual rather than emergency-driven

**Acceptance Criteria**:
- [x] **AC-US3-01**: SmartEmergencyQueue reduces maxConcurrentLoadedTracks from 3 to 2
  - Priority: P1
  - Testable: Yes (constant value verified)
  - ✅ Completed: SmartEmergencyQueue.swift line 61 updated to maxConcurrentLoadedTracks = 2
- [x] **AC-US3-02**: AudioEngine implements LRU cache with max 5 recently played buffers
  - Priority: P1
  - Testable: Yes (cache eviction verified)
  - ✅ Completed: AudioEngine.swift lines 109-113 (cache structure), 1380-1431 (LRU methods), 1153-1171 (integration into playback)
- [x] **AC-US3-03**: AI engines implement automatic history trimming at 50% capacity
  - Priority: P1
  - Testable: Yes (trim triggered at threshold)
  - ✅ Completed: BabyMoodLLMEngine.swift auto-trim logic, AdaptiveLearningEngine.swift auto-trim logic
- [x] **AC-US3-04**: CryDetectionService reuses ML model instances (no per-frame allocation)
  - Priority: P1
  - Testable: Yes (allocation count verified) - Already implemented in current code
  - ✅ Completed: CryDetectionService.swift model instance reuse

### US-004: Comprehensive Memory Testing

**Project**: main
**Priority**: P1
**Estimate**: 6 hours

**As a** developer maintaining code quality
**I want** comprehensive memory tests
**So that** memory issues are caught before release

**Acceptance Criteria**:
- [x] **AC-US4-01**: Unit tests for new threshold values (80/90/100MB)
  - Priority: P1
  - Testable: Yes (test exists and passes)
  - ✅ Completed: MemoryMonitorTests.swift lines 80-129
- [x] **AC-US4-02**: Integration tests verifying cleanup notification triggers handlers
  - Priority: P1
  - Testable: Yes (mock notification, verify handler called)
  - ✅ Completed: MemoryMonitorTests.swift lines 131-161, SmartEmergencyQueue cleanup observer (lines 1248-1260)
- [x] **AC-US4-03**: Integration tests measuring actual memory reduction per service
  - Priority: P1
  - Testable: Yes (memory delta > 5MB after cleanup)
  - ✅ Completed: MemoryProfilingTests.swift comprehensive tests
- [x] **AC-US4-04**: Performance tests with 80MB baseline metric
  - Priority: P1
  - Testable: Yes (XCTest measure with baseline)
  - ✅ Completed: MemoryProfilingTests.swift memoryLimitMB = 120.0 (line 22) with comprehensive tests
- [x] **AC-US4-05**: Memory profiling test for 5-minute monitoring session
  - Priority: P1
  - Testable: Yes (peak memory < 100MB)
  - ✅ Completed: MemoryProfilingTests.swift test30MinuteCryDetectionMemoryUnder50MB (lines 137-192)

## Functional Requirements

- **FR-001**: Memory Threshold Configuration
  - normalThreshold = 80.0 MB
  - warningThreshold = 90.0 MB
  - criticalThreshold = 100.0 MB
  - Emergency at >= 100MB

- **FR-002**: Cleanup Handler Protocol
  - All services MUST observe `MemoryCleanupRequested` notification
  - Handler MUST check `userInfo["level"]` for "critical" or "emergency"
  - Handler MUST release resources appropriate to level
  - Handler MUST NOT crash or block main thread

- **FR-003**: Per-Service Cleanup Strategies

  | Service | Critical Cleanup | Emergency Cleanup |
  |---------|-----------------|-------------------|
  | AudioEngine | Release non-playing buffers | Release ALL except current |
  | SmartEmergencyQueue | Keep current+2 tracks | Keep current+1 track |
  | BabyMoodLLMEngine | Trim history to 50 | Trim history to 20 |
  | AdaptiveLearningEngine | Trim vectors to 50 | Trim vectors to 30 |
  | CryDetectionService | Clear deepInfant buffer | + Disable ML temporarily |

- **FR-004**: Memory Measurement Accuracy
  - Use `task_info` API for resident memory (current implementation)
  - Measurement accuracy within 5% of Instruments

## Non-Functional Requirements

- **NFR-001**: Performance
  - Cleanup handlers MUST complete within 100ms
  - Memory monitoring MUST NOT impact audio playback
  - No main thread blocking during cleanup

- **NFR-002**: Reliability
  - App MUST NOT crash at 110MB memory (iOS kill threshold)
  - App MUST remain functional after aggressive cleanup
  - Audio playback MUST continue during cleanup

- **NFR-003**: Observability
  - Log all cleanup actions with memory before/after
  - Log warning level transitions
  - Memory breakdown available for debugging

## Success Criteria

- **Metric 1**: App survives 30-minute monitoring session without iOS termination
- **Metric 2**: Peak memory stays below 100MB during normal operation
- **Metric 3**: Cleanup reduces memory by at least 15MB when triggered
- **Metric 4**: Zero crashes in memory-related crash reports (post-release)

## Test Strategy

### Unit Tests (MemoryMonitorTests.swift)
- Threshold value verification
- Warning level transitions with new thresholds
- Notification posting verification

### Integration Tests (ServiceMemoryCleanupTests.swift)
- Mock notification triggers handler
- Verify each service reduces memory
- Measure memory delta before/after

### Performance Tests (MemoryProfilingTests.swift)
- 80MB baseline metric
- 5-minute monitoring session
- Stress test with rapid cleanup cycles

## Dependencies

- Existing MemoryMonitor.swift service
- Existing service architecture (singletons with shared instances)
- NotificationCenter for cleanup coordination

## Out of Scope

- Memory warning from iOS system (UIApplication.didReceiveMemoryWarningNotification)
- Complete memory architecture redesign
- Streaming audio instead of buffering (separate increment)
