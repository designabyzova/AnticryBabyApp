---
increment: 0025-fix-next-previous-track-navigation
status: planned
estimated_tasks: 8
estimated_hours: 2-4
---

# Implementation Tasks

## Phase 1: Fix SearchView.swift

### T-001: Update SearchView track playback to use context
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03 | **Status**: [x] completed

**Description**: Update the `playTrack()` function in SearchView.swift to pass the full search results as playlist context.

**Test**:
- **Given** user searches for "lullaby" and gets 10 results
- **When** user taps on the 3rd search result
- **Then** audioEngine receives context with all 10 tracks, starting at index 2

**Implementation**:
1. Read SearchView.swift to locate `playTrack()` function
2. Identify the current search results array variable
3. Update call from `audioEngine.play(track: audioTrack)` to `audioEngine.play(track: audioTrack, fromTracks: searchResults, contextName: "Search Results")`
4. Ensure SearchTrack → AudioTrack conversion includes all search results

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/SearchView.swift:442`
- `BabyInCarApp/BabyInCarApp/Views/PlayerView.swift:2329` (search results in PlayerView)

**Estimated Time**: 30 minutes

---

### T-002: Add unit tests for SearchView context passing
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04, AC-US1-05 | **Status**: [x] completed

**Description**: Create unit tests to verify search results are properly converted and passed as context.

**Test**:
- **Given** SearchView with 5 search results
- **When** user plays the 2nd result
- **Then** currentPlaylist contains all 5 tracks with currentPlaylistIndex = 1

**Implementation**:
1. Create test file `SearchViewContextTests.swift` (if doesn't exist)
2. Add test: `testSearchResultsCreatePlaylistContext()`
3. Add test: `testSearchResultIndexMaintained()`
4. Add test: `testShuffleWorksWithSearchResults()`
5. Add test: `testRepeatModesWithSearchResults()`

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Views/SearchViewContextTests.swift` (new)

**Estimated Time**: 45 minutes

---

## Phase 2: Fix WhatWorksSection.swift

### T-003: Update EffectiveTrackCard to use context
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02 | **Status**: [x] completed

**Description**: Update the tap handler in EffectiveTrackCard (line 140) to pass effective tracks list as context.

**Test**:
- **Given** "What Works" section displays 8 effective tracks
- **When** user taps on a track
- **Then** all 8 tracks become the playlist context with correct starting index

**Implementation**:
1. Read WhatWorksSection.swift
2. Locate `EffectiveTrackCard` tap handler (around line 140)
3. Update from `audioEngine.play(track: track)` to `audioEngine.play(track: track, fromTracks: tracks, contextName: "Effective Tracks")`
4. Ensure `tracks` array is accessible in the closure

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/WhatWorksSection.swift:140`

**Estimated Time**: 20 minutes

---

### T-004: Update EffectiveTrackRow to use context
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03, AC-US2-04 | **Status**: [x] completed

**Description**: Update the tap handler in EffectiveTrackRow (line 362) to pass effective tracks list as context.

**Test**:
- **Given** user opens "All Effective Tracks" sheet
- **When** user taps on a track
- **Then** navigation works through all effective tracks in effectiveness order

**Implementation**:
1. Read WhatWorksSection.swift
2. Locate `EffectiveTrackRow` tap handler (around line 362)
3. Update from `audioEngine.play(track: track)` to `audioEngine.play(track: track, fromTracks: tracks, contextName: "Effective Tracks")`
4. Verify effectiveness sorting is preserved in the tracks array

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/WhatWorksSection.swift:362`

**Estimated Time**: 20 minutes

---

### T-005: Add integration tests for What Works navigation
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04 | **Status**: [x] completed

**Description**: Create integration tests for "What Works" section navigation.

**Test**:
- **Given** 5 tracks in "What Works" section
- **When** user plays track 2 and taps next
- **Then** track 3 plays with effectiveness data preserved

**Implementation**:
1. Create test file `WhatWorksSectionTests.swift` (if doesn't exist)
2. Add test: `testEffectiveTracksCreateContext()`
3. Add test: `testNavigationPreservesEffectiveness()`
4. Add test: `testEffectivenessSortingMaintained()`

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Integration/WhatWorksSectionTests.swift` (new)

**Estimated Time**: 40 minutes

---

## Phase 3: Fix PlayerView AI Recommendations

### T-006: Update PlayerView AI recommendation playback
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02 | **Status**: [x] completed

**Description**: Update AI recommendation playback in PlayerView to include context.

**Test**:
- **Given** AI generated 6 recommendations
- **When** user plays a recommendation
- **Then** all 6 recommendations become the playlist context

**Implementation**:
1. Read PlayerView.swift to find AI recommendation playback (around line 2329)
2. Identify the recommendations array variable
3. Update from `audioEngine.play(track: audioTrack)` to `audioEngine.play(track: audioTrack, fromTracks: recommendations, contextName: "AI Recommendations")`
4. Ensure recommendations list is available in playback scope

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/PlayerView.swift:2329`

**Estimated Time**: 30 minutes

---

### T-007: Add tests for AI recommendation navigation
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed

**Description**: Create tests for AI recommendation context and navigation.

**Test**:
- **Given** AI recommendations provided
- **When** user navigates through recommendations
- **Then** recommendation context is maintained and navigation works

**Implementation**:
1. Add test to PlayerView tests: `testAIRecommendationsCreateContext()`
2. Add test: `testNavigationThroughRecommendations()`
3. Verify AI recommendation metadata preserved

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Views/PlayerViewTests.swift`

**Estimated Time**: 30 minutes

---

## Phase 4: Integration Testing & Validation

### T-008: Run comprehensive integration tests
**User Story**: US-001, US-002, US-003 | **Satisfies ACs**: All | **Status**: [x] completed

**Description**: Execute full test suite and perform manual testing across all scenarios.

**Test**:
- **Given** all code changes implemented
- **When** running complete test suite
- **Then** all tests pass with 0 failures and navigation works in all contexts

**Implementation**:
1. Run unit tests: `xcodebuild test -scheme BabyInCarApp -destination 'platform=iOS Simulator,name=iPhone 15'`
2. Manual testing:
   - Search flow: Search → Play → Next → Previous
   - What Works flow: Browse → Play → Navigate
   - AI Recommendations: Generate → Play → Navigate
   - Test shuffle mode across all contexts
   - Test repeat modes across all contexts
3. Verify no regressions in existing playlist navigation (LibraryView, favorites)
4. Check console for any warnings or errors
5. Test on physical device (if available)

**Files**:
- All test files created in previous tasks
- Manual test checklist in spec.md

**Estimated Time**: 60 minutes

---

## Summary

**Total Tasks**: 8
**Estimated Time**: 2-4 hours
**Priority**: P0 (Critical Bug Fix)

**Task Breakdown**:
- Phase 1 (SearchView): 2 tasks, 75 minutes
- Phase 2 (WhatWorksSection): 3 tasks, 80 minutes
- Phase 3 (PlayerView): 2 tasks, 60 minutes
- Phase 4 (Testing): 1 task, 60 minutes

**Success Criteria**:
- [ ] All 8 tasks completed
- [ ] All tests passing
- [ ] Next/previous buttons work in all playback contexts
- [ ] No regressions in existing functionality
- [ ] Ready for TestFlight deployment
