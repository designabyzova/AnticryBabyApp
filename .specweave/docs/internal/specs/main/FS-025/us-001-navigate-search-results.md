# US-001: Navigate Search Results

**Feature**: [FS-025: Fix Next/Previous Track Navigation](FEATURE.md)
**Project**: main
**Priority**: P0
**Status**: Planned

## User Story

**As a** parent searching for calming content,
**I want** to skip to the next/previous track in my search results,
**So that** I can quickly find the right sound to calm my baby without taking my eyes off the road.

## Acceptance Criteria

- [ ] **AC-US1-01**: When I play a track from search results, the entire search result list becomes my playlist context
- [ ] **AC-US1-02**: Tapping "Next" advances to the next track in the search results
- [ ] **AC-US1-03**: Tapping "Previous" goes back to the previous track in the search results
- [ ] **AC-US1-04**: Search result position is maintained across next/previous navigation
- [ ] **AC-US1-05**: Shuffle and repeat modes work correctly with search result playlists

## Technical Details

### Current Behavior (BROKEN)

```swift
// SearchView.swift:442
func playTrack(_ track: SearchTrack) {
    let audioTrack = AudioTrack(...)
    audioEngine.play(track: audioTrack)  // ❌ No context!
}
```

**Result**: `currentPlaylist` remains `nil`, next/previous buttons don't work.

### Fixed Behavior

```swift
// SearchView.swift:442
func playTrack(_ track: SearchTrack) {
    let audioTrack = AudioTrack(...)
    let allSearchResults = searchResults.map { convertToAudioTrack($0) }
    audioEngine.play(
        track: audioTrack,
        fromTracks: allSearchResults,
        contextName: "Search Results"
    )  // ✅ Context provided!
}
```

**Result**: `currentPlaylist` set to search results, navigation works.

## Implementation Tasks

### T-001: Update SearchView track playback
**Status**: Pending
**Estimated Time**: 30 minutes

Update `playTrack()` function in SearchView.swift to pass full search results as context.

**Steps**:
1. Read SearchView.swift
2. Locate `playTrack()` function (around line 442)
3. Convert all search results to AudioTrack array
4. Update call to `play(track:fromTracks:contextName:)`
5. Verify search position is preserved

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/SearchView.swift:442`
- `BabyInCarApp/BabyInCarApp/Views/PlayerView.swift:2329` (search in PlayerView)

### T-002: Add unit tests for search context
**Status**: Pending
**Estimated Time**: 45 minutes

Create unit tests to verify search results context passing.

**Test Cases**:
- `testSearchResultsCreatePlaylistContext()`
- `testSearchResultIndexMaintained()`
- `testShuffleWorksWithSearchResults()`
- `testRepeatModesWithSearchResults()`

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Views/SearchViewContextTests.swift` (new)

## Testing Scenarios

### Manual Testing

1. **Basic Navigation**
   - Search for "lullaby"
   - Play 3rd result
   - Tap "Next" → Should play 4th result
   - Tap "Previous" → Should play 3rd result again

2. **Edge Cases**
   - Play last search result → Next should wrap or stop (based on repeat mode)
   - Play first search result → Previous should wrap or stop
   - Search with 1 result → Next/Previous should handle gracefully

3. **Shuffle Mode**
   - Enable shuffle
   - Play from search
   - Next should play random unplayed track from search results
   - Verify all tracks eventually play

4. **Repeat Modes**
   - Repeat Off: Stops at end of search results
   - Repeat All: Loops back to first result
   - Repeat One: Replays current track

## User Impact

**Before Fix**:
- Parent searches for "white noise"
- Plays first result
- Baby still crying
- Taps "Next" → Nothing happens ❌
- Must manually search and select next track (unsafe while driving)

**After Fix**:
- Parent searches for "white noise"
- Plays first result
- Baby still crying
- Taps "Next" → Next white noise track plays ✅
- Can navigate safely through search results

## Related Documentation

- [AudioEngine.swift Context Management](../../architecture/audio/context-management.md)
- [Search Implementation](../../architecture/features/search.md)
- [AudioEngine.next() function](../../../../BabyInCarApp/BabyInCarApp/Services/AudioEngine.swift#L559-L604)

## Definition of Done

- [ ] SearchView.swift updated to pass search results as context
- [ ] Unit tests created and passing
- [ ] Manual testing completed successfully
- [ ] No regressions in existing search functionality
- [ ] Code review approved
- [ ] Merged to main branch
