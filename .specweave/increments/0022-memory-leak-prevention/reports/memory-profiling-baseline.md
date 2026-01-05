# Memory Profiling Baseline - BabyInCarApp

**Date**: 2026-01-04
**Increment**: 0022-memory-leak-prevention
**Issue**: App killed by iOS at 85MB+ memory usage

## Crash Report Analysis

### Error Details
```
The app "BabyInCarApp" has been killed by the operating system because it is using too much memory.
Domain: IDEDebugSessionErrorDomain
Code: 11
Memory pressure: Emergency → Warning (85MB)
```

### Crash Context
- **When**: During audio playback
- **Scenario**: SmartEmergencyQueue loading 10 MELODIC tracks
- **Last log**: "Built queue with 10 MELODIC tracks (no white noise)"

## Memory Budget Analysis

| Component | Estimated Current | Target | Gap |
|-----------|-------------------|--------|-----|
| **Audio Buffers** | ~30MB | 15MB | -15MB |
| **AI Engines** | ~20MB | 10MB | -10MB |
| **Cry Detection** | ~5MB | 5MB | ✅ |
| **UI/System** | ~15MB | 10MB | -5MB |
| **Headroom** | ~15MB | 10MB | -5MB |
| **TOTAL** | **~85MB** | **50MB** | **-35MB** |

## Identified Memory Leaks

### 1. Audio System (PRIMARY - ~30MB)

**SmartEmergencyQueue.swift**
- Loading 10 tracks simultaneously
- Each track: ~3MB average
- Total: ~30MB in memory at once

**Root Cause**: No limit on concurrent loaded tracks

**Evidence**:
```swift
// Console log from crash:
[SmartQueue] Built queue with 10 MELODIC tracks (no white noise)
```

**Fix**: Limit to 3 concurrent loaded tracks

### 2. AI Engine Histories (SECONDARY - ~20MB)

**BabyMoodLLMEngine.swift**
- `maxHistorySize = 500`
- Each entry: ~40KB (estimated)
- Total: ~20MB

**AdaptiveLearningEngine.swift**
- `maxSessionHistory = 1000`
- `successfulFeatureVectors = 500`
- Combined: ~20MB

**Fix**: Reduce limits with LRU caching

### 3. Cry Detection (VERIFIED OK - ~5MB)

**CryPatternTracker.swift** ✅
- `maxIntensitySamplesPerBurst = 50` (GOOD!)
- Sliding window enforced correctly
- Memory bounded

**Status**: Already fixed in increment 0012

## Profiling Recommendations

### Manual Instruments Profiling Steps

1. **Open Xcode Instruments**
   ```bash
   xcodebuild -project BabyInCarApp.xcodeproj \
     -scheme BabyInCarApp \
     -destination 'platform=iOS Simulator,name=iPhone 15' \
     -enableCodeCoverage YES \
     clean build

   # Open Instruments > Allocations template
   instruments -t Allocations
   ```

2. **Test Scenarios**
   - Scenario 1: 30-min cry detection session
   - Scenario 2: 10-track audio playback
   - Scenario 3: Emergency mode transitions
   - Scenario 4: All AI engines active

3. **Capture Snapshots**
   - Snapshot at app launch
   - Snapshot at 10-track queue built
   - Snapshot during playback
   - Snapshot at peak memory (before crash)

4. **Analyze Allocations**
   - Filter by category: AVAudioPlayerNode, AVAudioPCMBuffer
   - Filter by category: Array, Dictionary
   - Filter by class: BabyMoodLLMEngine, AdaptiveLearningEngine
   - Identify top 10 memory consumers

## Expected Profiling Results

### Before Fixes
- **Peak Memory**: 85MB+
- **Audio Buffers**: ~30MB (10 tracks loaded)
- **AI Histories**: ~20MB (unbounded arrays)
- **Cry Detection**: ~5MB (bounded)

### After Fixes (Target)
- **Peak Memory**: < 50MB
- **Audio Buffers**: < 15MB (3 tracks max)
- **AI Histories**: < 10MB (LRU cache)
- **Cry Detection**: < 5MB (already bounded)

## Top Memory Consumers (Estimated)

1. **AVAudioPCMBuffer** (Audio): ~30MB
2. **Array allocations** (AI histories): ~20MB
3. **CryBurst.intensitySamples**: ~0.4MB (bounded ✅)
4. **SwiftUI View hierarchy**: ~10MB
5. **Other framework overhead**: ~25MB

## Implementation Priority

**Phase 1**: Audio Limits (highest impact: -15MB)
**Phase 2**: MemoryMonitor (observability)
**Phase 3**: AI Limits (second highest: -10MB)
**Phase 4**: Auto-Cleanup (safety net)
**Phase 5**: Testing (validation)

## Validation Criteria

- [ ] Instruments shows peak < 50MB
- [ ] Audio buffers < 15MB
- [ ] AI engines < 10MB
- [ ] No memory leaks detected
- [ ] Zero OOM kills in test scenarios

---

**Next**: Implement MemoryMonitor service for real-time tracking
