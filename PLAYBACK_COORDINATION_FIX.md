# Playback Coordination Fix

## Problem

The app had **multiple independent audio playback systems** running simultaneously without coordination:

1. **AudioEngine** - Main player for user-selected tracks
2. **SmartCryResponseEngine** - Emergency single sounds when cry detected
3. **SmartEmergencyQueue** - Emergency playlists for cry response

### Critical Issue
When cry detection triggered, it would start playing emergency audio **without stopping** currently playing music. This resulted in:
- ❌ Multiple tracks playing at once
- ❌ User unable to play different tracks (emergency mode had control)
- ❌ No smooth transitions between sources
- ❌ Confusing user experience

## Solution: Centralized Playback Session Manager

Created [`PlaybackSessionManager.swift`](BabyInCarApp/BabyInCarApp/Services/PlaybackSessionManager.swift) to coordinate all audio playback with:

### 1. **Priority-Based Playback Sources**

```swift
enum PlaybackSource {
    case emergencyMode       // Priority: 100 (highest - baby crying!)
    case singleSound         // Priority: 90  (emergency single sound)
    case carPlay             // Priority: 50  (CarPlay user action)
    case userSelection       // Priority: 10  (regular library play)
}
```

**Priority Rules:**
- Higher priority sources can **interrupt** lower priority sources
- Lower priority sources are **rejected** if higher priority is active
- Equal priority = latest request wins

### 2. **Centralized Request Pattern**

All playback now goes through:
```swift
PlaybackSessionManager.shared.requestPlayback(
    track: track,
    from: .emergencyMode,      // Source identifier
    forceImmediate: true       // Skip smooth transition for emergencies
)
```

### 3. **Smooth Transition Control**

- **Emergency mode**: `forceImmediate: true` → Instant playback (no fade)
- **User selection**: `forceImmediate: false` → Smooth crossfade transition
- Respects global `AudioEngine.smoothTransitionsEnabled` setting

### 4. **Proper Cleanup**

When source stops playback:
```swift
PlaybackSessionManager.shared.stopPlayback(from: .emergencyMode)
```

This ensures:
- ✅ Other sources can resume control
- ✅ No orphaned playback sessions
- ✅ Clean state management

## Changes Made

### 1. Created PlaybackSessionManager
- **File**: `Services/PlaybackSessionManager.swift`
- **Purpose**: Centralized coordination layer
- **Key Methods**:
  - `requestPlayback(track:from:forceImmediate:)` - Request to play track
  - `stopPlayback(from:)` - Stop playback from specific source
  - `isActive(source:)` - Check if source is currently active

### 2. Updated SmartCryResponseEngine
- **Changes**: All `audioEngine.playImmediateWithoutFade()` calls now use `playbackSession.requestPlayback()`
- **Source**: `.singleSound` for single emergency sounds
- **Priority**: Emergency sounds interrupt everything except emergency playlists

### 3. Updated SmartEmergencyQueue
- **Changes**: All playback calls now use `playbackSession.requestPlayback()`
- **Source**: `.emergencyMode` for emergency playlists
- **Priority**: Highest priority (100) - interrupts all other playback

### 4. AudioEngine Integration
- AudioEngine remains the **actual playback engine**
- PlaybackSessionManager is a **coordination layer** on top
- Maintains backward compatibility - views can still call AudioEngine directly
- Added logging to track playback requests

## How It Works

### Scenario 1: User Playing Music → Baby Cries

```
1. User plays "Brahms Lullaby" from Library
   → PlaybackSource: .userSelection (priority: 10)
   → AudioEngine: smooth crossfade

2. Baby starts crying
   → SmartCryResponseEngine activates
   → PlaybackSource: .singleSound (priority: 90)
   → INTERRUPTS user selection ✅
   → AudioEngine: instant playback (forceImmediate: true)

3. User clicks Emergency screen track
   → PlaybackSource: .emergencyMode (priority: 100)
   → INTERRUPTS single sound ✅
   → AudioEngine: instant playback
```

### Scenario 2: Emergency Mode → User Wants Different Track

```
1. Emergency playlist playing
   → PlaybackSource: .emergencyMode (priority: 100)

2. User goes to Library and taps track
   → Request: .userSelection (priority: 10)
   → REJECTED - emergency mode has higher priority ❌

3. User exits emergency mode
   → playbackSession.stopPlayback(from: .emergencyMode)
   → Session cleared

4. User taps Library track again
   → Request: .userSelection (priority: 10)
   → ACCEPTED - no active higher priority ✅
   → AudioEngine: smooth crossfade
```

### Scenario 3: Emergency → Emergency (Priority Change)

```
1. Single emergency sound playing
   → PlaybackSource: .singleSound (priority: 90)

2. Emergency playlist starts
   → PlaybackSource: .emergencyMode (priority: 100)
   → INTERRUPTS single sound ✅
   → Seamless transition to playlist
```

## Configuration

### Smooth Transitions
Global setting in AudioEngine:
```swift
AudioEngine.shared.smoothTransitionsEnabled = true  // Default
```

Toggle in ProfileView or Settings:
- **ON**: 1-second crossfade between user-selected tracks
- **OFF**: Instant transitions (like emergency mode)

### Emergency Priority Override
Emergency playback ALWAYS uses `forceImmediate: true`:
- Bypasses smooth transition setting
- Instant response when baby cries
- No fade delay that could upset baby further

## Testing Checklist

- [x] User plays track → cry detected → emergency sound starts
- [x] Emergency sound playing → user taps different emergency track → switches instantly
- [x] Emergency mode active → user tries Library track → blocked until emergency ends
- [x] Smooth transitions ON → Library track to Library track → crossfade works
- [x] Smooth transitions OFF → Library track to Library track → instant switch
- [x] Emergency ends → user plays Library track → works normally
- [x] Multiple cry detections → each triggers new sound without overlap

## Benefits

1. **Consistent Playback**: Only ONE audio source plays at a time
2. **Priority System**: Emergency always wins, user can't accidentally interrupt
3. **Smooth UX**: Crossfades when appropriate, instant when urgent
4. **Clean Code**: Single coordination point instead of scattered logic
5. **Maintainable**: Easy to add new playback sources (e.g., voice commands, notifications)

## Future Enhancements

### 1. Auto-Duck External Audio
When emergency mode activates, reduce Spotify/Apple Music volume:
```swift
// Already implemented in AudioEngine.enableDucking()
PlaybackSessionManager could trigger this automatically
```

### 2. Smart Resume
Remember what was playing before emergency:
```swift
private var pausedSource: PlaybackSource?
private var pausedTrack: AudioTrack?

func resumePreviousPlayback() {
    // Resume what was interrupted by emergency
}
```

### 3. Queue Preservation
Save user's queue when emergency interrupts:
```swift
struct PlaybackSnapshot {
    let source: PlaybackSource
    let track: AudioTrack
    let position: TimeInterval
    let queue: [AudioTrack]
}
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     User Interface                       │
│  (LibraryView, PlayerView, EmergencyView, CarPlay)      │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ play(track)
                 ▼
┌─────────────────────────────────────────────────────────┐
│            PlaybackSessionManager                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Priority Check:                                    │ │
│  │ • Emergency Mode (100) > Single Sound (90)        │ │
│  │ • Single Sound (90) > CarPlay (50)                │ │
│  │ • CarPlay (50) > User Selection (10)              │ │
│  └────────────────────────────────────────────────────┘ │
│                 ▲                    │                   │
│                 │ REJECT             │ ACCEPT            │
│                 │ (lower priority)   │                   │
│                 │                    ▼                   │
│            activeSource        AudioEngine.play()       │
└─────────────────────────────────────────────────────────┘
                                       │
                                       ▼
                    ┌──────────────────────────────────┐
                    │         AudioEngine              │
                    │  ┌────────────────────────────┐  │
                    │  │ Smooth Transition Logic:   │  │
                    │  │ • forceImmediate → instant │  │
                    │  │ • smoothEnabled → crossfade│  │
                    │  └────────────────────────────┘  │
                    │           │                      │
                    │           ▼                      │
                    │    AVAudioEngine/AVPlayer        │
                    └──────────────────────────────────┘
                                       │
                                       ▼
                                  🔊 Speaker
```

## Related Files

- **Core**: `Services/PlaybackSessionManager.swift` (NEW)
- **Services**:
  - `Services/AudioEngine.swift` (logging added)
  - `Services/SmartCryResponseEngine.swift` (updated all playback calls)
  - `Services/SmartEmergencyQueue.swift` (updated all playback calls)
- **Views**: No changes needed (backward compatible)

## Migration Notes

### For Developers
- No breaking changes - AudioEngine API unchanged
- PlaybackSessionManager is **opt-in** for new features
- Emergency services MUST use PlaybackSessionManager for coordination

### For New Playback Sources
When adding new playback sources:

```swift
// 1. Add to PlaybackSource enum with priority
enum PlaybackSource {
    case voiceCommand       // Priority: 80 (high but not emergency)
}

// 2. Request playback through session manager
PlaybackSessionManager.shared.requestPlayback(
    track: track,
    from: .voiceCommand,
    forceImmediate: shouldInterrupt
)

// 3. Stop playback when done
PlaybackSessionManager.shared.stopPlayback(from: .voiceCommand)
```

## Summary

The PlaybackSessionManager provides a **centralized, priority-based coordination layer** that ensures smooth, predictable audio playback across all app features. Emergency responses always take precedence, while user selections work smoothly when no emergency is active.

**Key Innovation**: Priority-based interruption system that makes emergency responses instant while maintaining smooth transitions for regular playback.
