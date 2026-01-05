# Progress Bar Scrubbing Fix

## Problem
The progress bars across multiple views were **display-only** - users couldn't drag the handle to seek/rewind through tracks. This affected:
- Emergency Queue View
- Smart Queue View
- Playback Queue View

## Root Cause
1. **TrackProgressBar component** had no drag gesture implementation
2. Views were passing only `progress` value without AudioEngine reference
3. No scrubber knob visual feedback for interactive state

## Solution

### 1. Enhanced TrackProgressBar Component
**File**: `BabyInCarApp/Views/Components/TrackProgressBar.swift`

**Changes**:
- Added optional `audioEngine` parameter for interactive mode
- Added `DragGesture` with `onChanged` and `onEnded` handlers
- Added scrubber knob that:
  - Only shows in interactive mode
  - Scales up during drag (1.0 → 1.3x)
  - Provides visual feedback
- Now accepts `currentTime` and `duration` for accurate time display
- Supports two modes:
  - **Interactive**: With AudioEngine reference, full drag support
  - **Display-only**: Without AudioEngine, just visual indicator

**Key Code**:
```swift
.gesture(
    interactive ? DragGesture(minimumDistance: 0)
        .onChanged { value in
            isDragging = true
            let progress = min(max(0, value.location.x / geometry.size.width), 1)
            let time = progress * duration
            audioEngine?.seek(to: time)
        }
        .onEnded { _ in
            isDragging = false
        }
    : nil
)
```

### 2. Updated EmergencyQueueView
**File**: `BabyInCarApp/Views/EmergencyQueueView.swift`

**Changes**:
- Added `@EnvironmentObject var audioEngine: AudioEngine`
- Updated TrackProgressBar call to pass:
  - `currentTime: audioEngine.currentTime`
  - `duration: audioEngine.duration`
  - `audioEngine: audioEngine` (enables interactive mode)

**Before**:
```swift
TrackProgressBar(progress: queueManager.progress)
```

**After**:
```swift
TrackProgressBar(
    progress: queueManager.progress,
    currentTime: audioEngine.currentTime,
    duration: audioEngine.duration,
    audioEngine: audioEngine
)
```

### 3. Updated SmartQueueView
**File**: `BabyInCarApp/Views/SmartQueueView.swift`

**Changes**:
- Added `@EnvironmentObject var audioEngine: AudioEngine`
- Added `@State private var isDraggingProgress = false`
- Enhanced existing progress bar with:
  - `DragGesture` for scrubbing
  - Animated scrubber knob (12px → 16px when dragging)
  - Direct `audioEngine.seek(to:)` calls
  - Accurate time labels from `audioEngine.currentTime` and `audioEngine.duration`

### 4. Updated PlaybackQueueView (NowPlayingHeroCard)
**File**: `BabyInCarApp/Views/PlaybackQueueView.swift`

**Changes**:
- Added `@EnvironmentObject var audioEngine: AudioEngine` to NowPlayingHeroCard
- Added `@State private var isDraggingProgress = false`
- Enhanced progress bar with:
  - `DragGesture` for interactive scrubbing
  - Animated scrubber knob (10px → 14px when dragging)
  - Real-time time updates from AudioEngine
  - Increased touch target height (4px → 14px)

## Technical Details

### Drag Gesture Pattern
All implementations use this consistent pattern:

```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        // Background track
        Capsule().fill(.opacity(0.2))

        // Progress fill
        Capsule().fill(...)
            .frame(width: geo.size.width * progress)

        // Scrubber knob
        Circle()
            .fill(.white)
            .frame(width: isDragging ? larger : normal)
            .offset(x: geo.size.width * progress - radius)
    }
    .contentShape(Rectangle())  // Make entire area tappable
    .gesture(
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let progress = clamp(value.location.x / geo.size.width, 0...1)
                audioEngine.seek(to: progress * duration)
            }
            .onEnded { _ in
                isDragging = false
            }
    )
}
```

### Key Features
1. **Zero minimum distance** - Immediate response to touch
2. **Clamping** - Progress constrained to 0.0-1.0
3. **Visual feedback** - Knob scales up during drag
4. **Spring animation** - Smooth transitions
5. **Shadow effects** - Better depth perception
6. **Content shape** - Full width is tappable, not just the knob

## Testing Checklist

- [x] EmergencyQueueView - Can drag progress bar to seek
- [x] SmartQueueView - Can drag progress bar to seek
- [x] PlaybackQueueView - Can drag progress bar to seek
- [ ] Visual feedback works (knob scales during drag)
- [ ] Time labels update in real-time
- [ ] Seeking is smooth and responsive
- [ ] Works on all screen sizes
- [ ] No crashes when duration is 0
- [ ] Accessibility - VoiceOver announces progress

## Files Modified

1. ✅ `BabyInCarApp/Views/Components/TrackProgressBar.swift`
2. ✅ `BabyInCarApp/Views/EmergencyQueueView.swift`
3. ✅ `BabyInCarApp/Views/SmartQueueView.swift`
4. ✅ `BabyInCarApp/Views/PlaybackQueueView.swift`

## Performance Notes

- `DragGesture` is efficient - no performance impact
- `seek(to:)` calls are throttled by AudioEngine's implementation
- Animations use spring physics for natural feel
- `contentShape(Rectangle())` ensures good touch targets

## Future Enhancements

- [ ] Haptic feedback on scrub start/end
- [ ] Show preview time while dragging (tooltip)
- [ ] Waveform visualization in progress bar
- [ ] Chapter markers for long tracks
- [ ] Double-tap to skip 15s forward/back
