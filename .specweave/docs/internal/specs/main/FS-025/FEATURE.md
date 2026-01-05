# FS-025: Fix Next/Previous Track Navigation

**Type**: Bug Fix
**Priority**: P0 (Critical)
**Status**: Planned
**Increment**: [0025-fix-next-previous-track-navigation](../../../../increments/0025-fix-next-previous-track-navigation/)

## Overview

Critical bug fix for non-functional next/previous track navigation when playing from search results, "What Works" recommendations, or AI-suggested tracks. This severely impacts parent UX as they cannot navigate through discovered content while driving.

## Problem Statement

When users play a track from search results, the "What Works" section, or other discovery features, the next/previous track buttons become non-functional. This breaks a core navigation pattern and creates a frustrating user experience.

**Root Cause**: Views call `audioEngine.play(track:)` without providing playlist context, leaving `currentPlaylist` as `nil`. When users tap next/previous, the `AudioEngine.next()` function exits early due to the missing playlist.

**Impact**:
- Parents cannot skip to next soothing sound
- Critical UX regression in core playback functionality
- Affects primary use case (discovering and playing calming content)

## User Stories

This feature includes 3 user stories:

1. **[US-001: Navigate Search Results](us-001-navigate-search-results.md)**
   Enable next/previous navigation through search result playlists

2. **[US-002: Navigate "What Works" Recommendations](us-002-navigate-what-works.md)**
   Enable navigation through effectiveness-ranked track lists

3. **[US-003: Navigate AI Recommendations](us-003-navigate-ai-recommendations.md)**
   Enable navigation through AI-generated recommendation lists

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

## Success Metrics

- Next/previous buttons functional in 100% of playback scenarios
- No regression in existing playlist navigation
- Zero crashes related to nil playlist handling

## Testing Strategy

### Unit Tests
- Verify `AudioEngine.next()` works when playlist context is set
- Verify shuffle mode with search result playlists
- Test repeat modes with contextual playlists

### Integration Tests
1. Search → Play → Next/Previous navigation
2. What Works → Play → Navigate with effectiveness preserved
3. AI Recommendations → Play → Navigate through suggestions

## Rollout Plan

1. Fix SearchView.swift (highest priority)
2. Fix WhatWorksSection.swift
3. Fix PlayerView.swift AI recommendations
4. Run full test suite
5. Deploy to TestFlight
6. Monitor for 24 hours
7. Production release

## Dependencies

None - standalone bug fix

## Related Features

- [AudioEngine Context Management](../../architecture/audio/context-management.md)
- [Playlist Navigation System](../../architecture/audio/playlist-navigation.md)

## Estimated Effort

**2-4 hours** (8 tasks)

- Phase 1: SearchView fixes (75 min)
- Phase 2: WhatWorksSection fixes (80 min)
- Phase 3: PlayerView fixes (60 min)
- Phase 4: Testing (60 min)
