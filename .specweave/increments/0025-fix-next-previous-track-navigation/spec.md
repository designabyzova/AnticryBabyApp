---
increment: 0025-fix-next-previous-track-navigation
title: "Fix Next/Previous Track Navigation"
priority: P0
status: planned
type: bug
created: 2026-01-04
dependencies: []
structure: user-stories
tech_stack:
  detected_from: "BabyInCarApp.xcodeproj"
  language: "swift"
  framework: "swiftui"
  platform: "ios"
---

# Fix Next/Previous Track Navigation

## Problem Statement

When users play a track from search results, the "What Works" section, or other discovery features, the next/previous track buttons become non-functional. This severely impacts the user experience as parents cannot navigate through their search results or recommendations while the baby is in the car.

**Root Cause**: These views call `audioEngine.play(track:)` without providing playlist context, which means `currentPlaylist` remains `nil`. When users tap next/previous, the `AudioEngine.next()` function exits early because there's no playlist to navigate.

**Impact**:
- Parents lose the ability to skip to the next soothing sound
- Critical UX regression in core playback functionality
- Affects primary use case (discovering and playing calming content)

## User Stories

### US-001: Navigate Search Results
**Project**: main
**As a** parent searching for calming content,
**I want** to skip to the next/previous track in my search results,
**So that** I can quickly find the right sound to calm my baby without taking my eyes off the road.

**Acceptance Criteria**:
- [x] **AC-US1-01**: When I play a track from search results, the entire search result list becomes my playlist context
- [x] **AC-US1-02**: Tapping "Next" advances to the next track in the search results
- [x] **AC-US1-03**: Tapping "Previous" goes back to the previous track in the search results
- [x] **AC-US1-04**: Search result position is maintained across next/previous navigation
- [x] **AC-US1-05**: Shuffle and repeat modes work correctly with search result playlists

### US-002: Navigate "What Works" Recommendations
**Project**: main
**As a** parent browsing effective tracks,
**I want** to navigate through recommended tracks using next/previous buttons,
**So that** I can efficiently try different sounds based on effectiveness data.

**Acceptance Criteria**:
- [x] **AC-US2-01**: Playing from "What Works" section creates playlist context from all effective tracks
- [x] **AC-US2-02**: Next/previous buttons navigate through the effective tracks list
- [x] **AC-US2-03**: Track effectiveness metadata is preserved during navigation
- [x] **AC-US2-04**: Navigation respects the effectiveness sorting order

### US-003: Navigate AI Recommendations in PlayerView
**Project**: main
**As a** parent using AI-generated recommendations,
**I want** to navigate through suggested tracks,
**So that** I can explore AI recommendations without manual searching.

**Acceptance Criteria**:
- [x] **AC-US3-01**: Playing from AI recommendations in PlayerView creates playlist context
- [x] **AC-US3-02**: Next/previous buttons work with AI-recommended track lists
- [x] **AC-US3-03**: Recommendation context is maintained across navigation

## Technical Approach

### Files to Modify

1. **SearchView.swift** (Lines 442, 2329)
   - Update `playTrack()` to use `play(track:fromTracks:contextName:)`
   - Pass full search results as context

2. **WhatWorksSection.swift** (Lines 140, 362)
   - Update track card tap handlers to include context
   - Pass effective tracks list as context

3. **PlayerView.swift** (Line 2329)
   - Update AI recommendation playback to include context
   - Ensure recommendations list is passed as playlist context

### Implementation Pattern

```swift
// Before (BROKEN):
audioEngine.play(track: audioTrack)

// After (FIXED):
audioEngine.play(track: audioTrack, fromTracks: allTracksInContext, contextName: "Search Results")
```

### Context Names
- Search results: `"Search Results"`
- What Works section: `"Effective Tracks"`
- AI recommendations: `"AI Recommendations"`

## Testing Strategy

### Unit Tests
- Verify `AudioEngine.next()` works when playlist context is set
- Verify `AudioEngine.previous()` navigates correctly with context
- Test shuffle mode with search result playlists
- Test repeat modes with contextual playlists

### Integration Tests
1. **Search Flow**:
   - Search for "lullaby"
   - Play first result
   - Tap next → should play second search result
   - Tap previous → should return to first result

2. **What Works Flow**:
   - Open "What Works" section
   - Play an effective track
   - Tap next → should play next effective track
   - Verify effectiveness data displays correctly

3. **AI Recommendations Flow**:
   - Trigger AI recommendations in PlayerView
   - Play a recommended track
   - Tap next → should play next recommendation
   - Verify recommendation context maintained

### Manual Testing Checklist
- [ ] Search for tracks, play one, verify next/previous buttons work
- [ ] Browse "What Works", play a track, navigate with next/previous
- [ ] Use AI recommendations, verify navigation works
- [ ] Test with shuffle enabled
- [ ] Test with repeat modes (off, all, one)
- [ ] Verify skip forward/backward (15s) still works independently

## Success Metrics

- Next/previous buttons functional in 100% of playback scenarios
- No regression in existing playlist navigation
- Search result context preserved across app suspension/resume
- Zero crashes related to nil playlist handling

## Dependencies

None - this is a standalone bug fix that doesn't depend on other increments.

## Rollout Plan

1. Fix SearchView.swift (highest priority - most common use case)
2. Fix WhatWorksSection.swift (secondary use case)
3. Fix PlayerView.swift AI recommendations
4. Run full test suite
5. Deploy to TestFlight for beta testing
6. Monitor crash reports for 24 hours
7. Release to production

## Risk Assessment

**Risk Level**: Low
- Small, focused code change
- No database or API changes
- No new dependencies
- Existing pattern already proven (LibraryView.swift uses this correctly)

**Mitigation**:
- Comprehensive testing across all affected views
- Reference working implementation in LibraryView.swift
- Beta testing before production release
