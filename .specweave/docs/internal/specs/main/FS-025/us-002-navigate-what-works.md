# US-002: Navigate "What Works" Recommendations

**Feature**: [FS-025: Fix Next/Previous Track Navigation](FEATURE.md)
**Project**: main
**Priority**: P0
**Status**: Planned

## User Story

**As a** parent browsing effective tracks,
**I want** to navigate through recommended tracks using next/previous buttons,
**So that** I can efficiently try different sounds based on effectiveness data.

## Acceptance Criteria

- [ ] **AC-US2-01**: Playing from "What Works" section creates playlist context from all effective tracks
- [ ] **AC-US2-02**: Next/previous buttons navigate through the effective tracks list
- [ ] **AC-US2-03**: Track effectiveness metadata is preserved during navigation
- [ ] **AC-US2-04**: Navigation respects the effectiveness sorting order

## Technical Details

### Current Behavior (BROKEN)

```swift
// WhatWorksSection.swift:140
EffectiveTrackCard(track: track, effectiveness: effectiveness) {
    audioEngine.play(track: track)  // ❌ No context!
}

// WhatWorksSection.swift:362
EffectiveTrackRow(track: track, effectiveness: effectiveness) {
    audioEngine.play(track: track)  // ❌ No context!
    dismiss()
}
```

**Result**: `currentPlaylist` remains `nil`, next/previous buttons don't work.

### Fixed Behavior

```swift
// WhatWorksSection.swift:140
EffectiveTrackCard(track: track, effectiveness: effectiveness) {
    audioEngine.play(
        track: track,
        fromTracks: tracks,  // All effective tracks
        contextName: "Effective Tracks"
    )  // ✅ Context provided!
}

// WhatWorksSection.swift:362
EffectiveTrackRow(track: track, effectiveness: effectiveness) {
    audioEngine.play(
        track: track,
        fromTracks: tracks,  // All effective tracks
        contextName: "Effective Tracks"
    )  // ✅ Context provided!
    dismiss()
}
```

**Result**: `currentPlaylist` set to effective tracks, navigation works while preserving effectiveness order.

## Implementation Tasks

### T-003: Update EffectiveTrackCard to use context
**Status**: Pending
**Estimated Time**: 20 minutes

Update tap handler in EffectiveTrackCard (line 140) to pass effective tracks as context.

**Steps**:
1. Read WhatWorksSection.swift
2. Locate EffectiveTrackCard tap handler
3. Ensure `tracks` array is accessible in closure
4. Update to use `play(track:fromTracks:contextName:)`

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/WhatWorksSection.swift:140`

### T-004: Update EffectiveTrackRow to use context
**Status**: Pending
**Estimated Time**: 20 minutes

Update tap handler in EffectiveTrackRow (line 362) to pass effective tracks as context.

**Steps**:
1. Read WhatWorksSection.swift
2. Locate EffectiveTrackRow tap handler (around line 362)
3. Verify effectiveness sorting is preserved in tracks array
4. Update to use `play(track:fromTracks:contextName:)`

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/WhatWorksSection.swift:362`

### T-005: Add integration tests for What Works navigation
**Status**: Pending
**Estimated Time**: 40 minutes

Create integration tests for "What Works" section navigation.

**Test Cases**:
- `testEffectiveTracksCreateContext()`
- `testNavigationPreservesEffectiveness()`
- `testEffectivenessSortingMaintained()`

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Integration/WhatWorksSectionTests.swift` (new)

## Testing Scenarios

### Manual Testing

1. **Card View Navigation**
   - Open "What Works" section
   - Play a track from card view
   - Tap "Next" → Should play next effective track
   - Verify effectiveness score displays correctly

2. **All Tracks Sheet Navigation**
   - Tap "See All" in What Works
   - Play a track from the list
   - Navigate with next/previous
   - Verify sorting order maintained (most → least effective)

3. **Effectiveness Preservation**
   - Play effective track
   - Navigate to next track
   - Verify effectiveness data still displayed
   - Check that effectiveness-based recommendations update

## Effectiveness Data Flow

```
WhatWorksSection
    │
    ├─ EffectivenessManager.getEffectiveness(trackId)
    │   └─ Returns EffectivenessData (score, usage count, last used)
    │
    ├─ Sort tracks by effectiveness score
    │
    ├─ Play with context:
    │   audioEngine.play(track, fromTracks: sortedTracks, contextName: "Effective Tracks")
    │
    └─ Navigation maintains:
        ├─ Effectiveness sort order ✅
        ├─ EffectivenessData for each track ✅
        └─ Adaptive learning continues ✅
```

## User Impact

**Before Fix**:
- Parent opens "What Works" (e.g., 8 effective tracks shown)
- Plays 3rd most effective track
- Baby still fussy
- Taps "Next" → Nothing happens ❌
- Must exit player, find next track manually

**After Fix**:
- Parent opens "What Works" (8 effective tracks)
- Plays 3rd most effective track
- Baby still fussy
- Taps "Next" → 4th most effective track plays ✅
- Can navigate efficiently through proven sounds

## Edge Cases

1. **Empty What Works Section**
   - If no effective tracks, section doesn't show
   - No navigation needed

2. **Single Effective Track**
   - Next/Previous should handle gracefully
   - Repeat One mode makes sense here

3. **Effectiveness Score Updates**
   - While navigating, effectiveness can update
   - Context already set, no re-calculation needed
   - Future plays will reflect new scores

## Related Documentation

- [Effectiveness Tracking System](../../architecture/features/effectiveness-tracking.md)
- [Adaptive Learning Engine](../../architecture/ml/adaptive-learning.md)
- [EffectivenessManager.swift](../../../../BabyInCarApp/BabyInCarApp/Services/EffectivenessManager.swift)

## Definition of Done

- [ ] EffectiveTrackCard updated with context
- [ ] EffectiveTrackRow updated with context
- [ ] Integration tests created and passing
- [ ] Effectiveness data preserved during navigation
- [ ] Sorting order maintained
- [ ] Manual testing completed
- [ ] Code review approved
- [ ] Merged to main branch
