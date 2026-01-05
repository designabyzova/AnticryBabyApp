# FS-012: Memory Crash Fix - CryPatternTracker

## Problem Statement

The app "BabyInCarApp" was being killed by the operating system due to excessive memory usage:
> "The app has been killed by the operating system because it is using too much memory."

Root cause: **Unbounded array growth** in `CryPatternTracker.CryBurst.intensitySamples`.

During a long continuous crying episode, the `intensitySamples` array grows indefinitely, consuming memory until iOS kills the app.

## Technical Analysis

### The Bug

```swift
// CryPatternTracker.swift - handleCryingFrame()
currentBurst?.intensitySamples.append(intensity)  // ← UNBOUNDED!
```

At ~30fps audio analysis:
- 1 minute of crying = 1,800 samples
- 10 minutes = 18,000 samples
- 30 minutes = 54,000 samples (potential OOM crash)

Each sample is a `Double` (8 bytes), so 54,000 samples = ~432KB just for one array.
Combined with other buffers, this causes memory pressure leading to OOM.

### The Fix

Added `maxIntensitySamplesPerBurst = 200` constant and sliding window enforcement:

```swift
// Keep only recent samples (sliding window)
if let count = currentBurst?.intensitySamples.count, count > maxIntensitySamplesPerBurst {
    currentBurst?.intensitySamples.removeFirst(count - maxIntensitySamplesPerBurst)
}
```

This limits memory to 200 × 8 bytes = 1.6KB per burst regardless of cry duration.

## User Stories

### US-001: Prevent OOM Crash During Long Cry Detection
**As a** parent using cry detection for extended periods
**I want** the app to manage memory efficiently
**So that** it doesn't crash during long crying episodes

**Acceptance Criteria:**
- [x] AC-US1-01: `CryBurst.intensitySamples` is bounded to 200 samples
- [x] AC-US1-02: Sliding window preserves recent data for accurate calculations
- [x] AC-US1-03: Memory usage remains stable during extended cry detection
- [x] AC-US1-04: All existing functionality preserved (metrics calculation works correctly)

## Verification

All other services already have proper memory bounds:
- `CryDetectionService`: `patternBufferSize = 30`, `cryTypeHistorySize = 15`
- `SmartCryResponseEngine`: `maxSessionHistory = 50`, `maxRecentSounds = 5`
- `AdaptiveLearningEngine`: `maxSessionHistory = 1000`, `successfulFeatureVectors max 500`
- `AudioEngine`: `maxHistorySize = 50`
- `ContextSignalCollector`: `motionBufferSize = 50`
- `EnvironmentSoundDetector`: `accelerationHistorySize = 50`
- `VoiceCharacteristicsAnalyzer`: `maxHistorySize = 100`
- `BabyMoodLLMEngine`: `maxHistorySize = 500`

## Files Modified

| File | Change |
|------|--------|
| `Services/CryPatternTracker.swift` | Added `maxIntensitySamplesPerBurst = 200`, enforced sliding window |
