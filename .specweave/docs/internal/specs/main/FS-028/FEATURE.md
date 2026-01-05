# FS-028: Critical Memory Crash Fix

**Increment**: 0028-critical-memory-crash-fix
**Type**: hotfix
**Priority**: P1
**Status**: planned
**Project**: main

## Overview

Fix critical app crashes from excessive memory usage at 111MB. The app is being killed by iOS due to unrealistic MemoryMonitor thresholds (40/45/48MB) and missing cleanup handlers in services.

## Problem Statement

The BabyInCarApp is being killed by iOS at 111MB memory usage. The current MemoryMonitor has unrealistic thresholds that trigger cleanup notifications, but NO services actually respond to these notifications. This results in cascading memory growth until iOS terminates the app.

**Evidence from crash logs**:
```
Memory pressure changed: Emergency → Critical (111MB)
The app "BabyInCarApp" has been killed by the operating system
because it is using too much memory.
```

## Root Cause Analysis

1. **Unrealistic thresholds**: Current 40/45/48MB limits are far below actual iOS memory pressure (~100-150MB for foreground apps)
2. **No cleanup handlers**: Services receive `MemoryCleanupRequested` notifications but have NO implemented handlers
3. **Multiple AI services**: BabyMoodLLMEngine, AdaptiveLearningEngine, SmartCryResponse all maintain large history arrays
4. **Audio buffers**: SmartEmergencyQueue and AudioEngine hold loaded tracks in memory

## Solution

1. Update MemoryMonitor thresholds to realistic 80/90/100MB limits
2. Implement cleanup notification handlers in 6 services
3. Add proactive memory management patterns
4. Comprehensive test coverage with 80MB baseline

## User Stories

- [US-001: Update Memory Thresholds to Realistic Values](./us-001-update-memory-thresholds.md)
- [US-002: Implement Cleanup Handlers in All Services](./us-002-implement-cleanup-handlers.md)
- [US-003: Add Proactive Memory Management](./us-003-proactive-memory-management.md)
- [US-004: Comprehensive Memory Testing](./us-004-comprehensive-testing.md)

## Success Criteria

- App survives 30-minute monitoring session without iOS termination
- Peak memory stays below 100MB during normal operation
- Cleanup reduces memory by at least 15MB when triggered
- Zero crashes in memory-related crash reports (post-release)

## Technical Architecture

See [plan.md](../../../../increments/0028-critical-memory-crash-fix/plan.md) for detailed technical architecture.

## Dependencies

- Existing MemoryMonitor.swift service
- Existing service architecture (singletons with shared instances)
- NotificationCenter for cleanup coordination

## Out of Scope

- Memory warning from iOS system (UIApplication.didReceiveMemoryWarningNotification)
- Complete memory architecture redesign
- Streaming audio instead of buffering (separate increment)
