# US-003: Navigate AI Recommendations

**Feature**: [FS-025: Fix Next/Previous Track Navigation](FEATURE.md)
**Project**: main
**Priority**: P0
**Status**: Planned

## User Story

**As a** parent using AI-generated recommendations,
**I want** to navigate through suggested tracks,
**So that** I can explore AI recommendations without manual searching.

## Acceptance Criteria

- [ ] **AC-US3-01**: Playing from AI recommendations in PlayerView creates playlist context
- [ ] **AC-US3-02**: Next/previous buttons work with AI-recommended track lists
- [ ] **AC-US3-03**: Recommendation context is maintained across navigation

## Technical Details

### Current Behavior (BROKEN)

```swift
// PlayerView.swift:2329
private func playTrack(_ track: SearchTrack) {
    let audioTrack = AudioTrack(...)
    audioEngine.play(track: audioTrack)  // ❌ No context!
}
```

**Result**: When playing AI recommendations from PlayerView search, `currentPlaylist` remains `nil`.

### Fixed Behavior

```swift
// PlayerView.swift:2329
private func playTrack(_ track: SearchTrack) {
    let audioTrack = AudioTrack(...)
    let allRecommendations = recommendations.map { convertToAudioTrack($0) }
    audioEngine.play(
        track: audioTrack,
        fromTracks: allRecommendations,
        contextName: "AI Recommendations"
    )  // ✅ Context provided!
}
```

**Result**: `currentPlaylist` set to AI recommendations, navigation works.

## AI Recommendation Context

### Recommendation Sources

AI recommendations can come from multiple sources:

1. **BabyMoodLLMEngine**
   - Analyzes cry patterns
   - Suggests tracks based on mood classification
   - Provides 5-10 recommendations

2. **AIRecommendationEngine**
   - Machine learning-based suggestions
   - Considers historical effectiveness
   - Personalized to baby's preferences

3. **AdaptiveFeedbackLoop**
   - Real-time response monitoring
   - Adjusts recommendations based on baby's reaction
   - Dynamically updates suggestion list

### Context Preservation

When playing from AI recommendations, we must preserve:
- Recommendation order (confidence-ranked)
- Source metadata (which engine generated it)
- Timestamp (when recommended)
- Baby mood context (what triggered the recommendation)

## Implementation Tasks

### T-006: Update PlayerView AI recommendation playback
**Status**: Pending
**Estimated Time**: 30 minutes

Update AI recommendation playback in PlayerView to include context.

**Steps**:
1. Read PlayerView.swift
2. Locate AI recommendation playback (around line 2329)
3. Identify the recommendations array variable
4. Update to use `play(track:fromTracks:contextName:)`
5. Ensure recommendations list is accessible in playback scope

**Files**:
- `BabyInCarApp/BabyInCarApp/Views/PlayerView.swift:2329`

### T-007: Add tests for AI recommendation navigation
**Status**: Pending
**Estimated Time**: 30 minutes

Create tests for AI recommendation context and navigation.

**Test Cases**:
- `testAIRecommendationsCreateContext()`
- `testNavigationThroughRecommendations()`
- `testRecommendationMetadataPreserved()`

**Files**:
- `BabyInCarApp/BabyInCarAppTests/Views/PlayerViewTests.swift`

## Testing Scenarios

### Manual Testing

1. **LLM-Based Recommendations**
   - Trigger cry detection
   - Wait for LLM recommendations to appear
   - Play a recommendation
   - Tap "Next" → Should play next LLM recommendation
   - Verify recommendation context maintained

2. **ML-Based Recommendations**
   - Use app over time to build history
   - View ML-generated suggestions
   - Play a recommendation
   - Navigate through suggestions

3. **Mixed Recommendations**
   - System provides both LLM + ML recommendations
   - Play from mixed list
   - Verify navigation works across all types

## AI Recommendation Flow

```
Cry Detected
    │
    ├─ BabyMoodLLMEngine.analyzeCry()
    │   └─ Returns: ["hungry", "tired", "pain"]
    │
    ├─ AIRecommendationEngine.getRecommendations(mood: "hungry")
    │   └─ Returns: [Track1, Track2, Track3, Track4, Track5]
    │
    ├─ Display in PlayerView
    │
    ├─ User plays Track2:
    │   audioEngine.play(
    │       track: Track2,
    │       fromTracks: [Track1, Track2, Track3, Track4, Track5],
    │       contextName: "AI Recommendations"
    │   )
    │
    └─ Navigation:
        Next → Track3 ✅
        Previous → Track1 ✅
```

## User Impact

**Before Fix**:
- Cry detected, AI suggests 5 soothing tracks
- Parent plays AI recommendation #1
- Baby still crying (wrong sound)
- Taps "Next" → Nothing happens ❌
- Must wait for new AI recommendations or search manually

**After Fix**:
- Cry detected, AI suggests 5 soothing tracks
- Parent plays AI recommendation #1
- Baby still crying
- Taps "Next" → AI recommendation #2 plays ✅
- Can quickly try all AI suggestions

## Integration with AI Systems

### BabyMoodLLMEngine Integration

```swift
// Current integration (no change needed)
let mood = await babyMoodLLM.analyzeCry(audioData)
let recommendations = aiEngine.getRecommendations(mood: mood)

// NEW: When playing, pass full recommendations
audioEngine.play(
    track: selectedTrack,
    fromTracks: recommendations,  // ✅ Full context
    contextName: "AI Recommendations (\(mood))"
)
```

### AdaptiveFeedbackLoop Integration

```swift
// Adaptive learning continues during navigation
audioEngine.onTrackChange = { track in
    adaptiveFeedback.recordPlayback(track: track, context: "AI Recommendation")

    // If baby calms down quickly, boost this recommendation
    if cryDetection.isBabyCalmNow {
        effectivenessManager.recordSuccess(track: track)
    }
}
```

## Edge Cases

1. **Recommendation List Updates Mid-Play**
   - User playing from recommendations
   - New cry pattern detected → new recommendations
   - Current playlist remains unchanged until user explicitly plays new recommendation

2. **Recommendation Expiry**
   - Old recommendations (>30 min) may become stale
   - Context still works, but recommendations might refresh

3. **No Recommendations Available**
   - AI engine returns empty list
   - Fallback to emergency playlist
   - Navigation not applicable

## Related Documentation

- [BabyMoodLLMEngine](../../../../BabyInCarApp/BabyInCarApp/Services/BabyMoodLLMEngine.swift)
- [AIRecommendationEngine](../../../../BabyInCarApp/BabyInCarApp/Services/AIRecommendationEngine.swift)
- [AdaptiveFeedbackLoop](../../../../BabyInCarApp/BabyInCarApp/Services/AdaptiveFeedbackLoop.swift)
- [AI Architecture](../../architecture/ml/ai-recommendation-system.md)

## Definition of Done

- [ ] PlayerView AI recommendation playback updated
- [ ] Recommendation context passed correctly
- [ ] Unit tests created and passing
- [ ] Manual testing with all AI engines
- [ ] Recommendation metadata preserved
- [ ] No regressions in AI recommendation display
- [ ] Code review approved
- [ ] Merged to main branch
