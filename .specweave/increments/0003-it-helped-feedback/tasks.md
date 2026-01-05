# Tasks - "It Helped!" Feedback System

## Phase 1: Data Models & Persistence

### T-001: Create TrackEffectiveness Data Model
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-04 | **Status**: [x] completed
**Test**: Given TrackEffectiveness model → When encoded/decoded → Then all properties preserved correctly

Create `Models/TrackEffectiveness.swift`:
- `id: UUID` (trackId reference)
- `helpedCount: Int`
- `totalPlays: Int`
- `cryTypeBreakdown: [String: CryTypeStats]` (keyed by cry type raw value)
- `lastHelped: Date?`
- `firstRecorded: Date`
- Computed `effectivenessScore: Double` (0-100%)
- Conform to Codable, Identifiable, Hashable

### T-002: Create CryTypeStats Nested Model
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed
**Test**: Given CryTypeStats → When tracking cry type → Then counts increment correctly

Create nested struct in TrackEffectiveness.swift:
- `helpedCount: Int`
- `totalCount: Int`
- Computed `successRate: Double`
- Conform to Codable

### T-003: Create EffectivenessManager Service
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02, AC-US2-03, AC-US2-05 | **Status**: [x] completed
**Test**: Given EffectivenessManager → When saving/loading → Then data persists across app launches

Create `Services/EffectivenessManager.swift`:
- Singleton pattern matching FavoritesManager
- `@Published var effectivenessData: [UUID: TrackEffectiveness]`
- `recordPlay(track: AudioTrack, cryType: CryType?)` - increment totalPlays
- `recordHelped(track: AudioTrack, cryType: CryType?)` - increment helpedCount
- `getEffectiveness(for trackId: UUID) -> TrackEffectiveness?`
- `getTopEffectiveTracks(limit: Int, cryType: CryType?) -> [AudioTrack]`
- Persist to UserDefaults key "TrackEffectiveness"
- Load on init, save after mutations

## Phase 2: UI Components

### T-004: Create ItHelpedButton Component
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-04 | **Status**: [x] completed
**Test**: Given ItHelpedButton → When tapped → Then triggers haptic and animation

Create `Components/ItHelpedButton.swift`:
- SwiftUI Button with heart/thumbs-up icon
- Minimum 60x60 point touch target
- Scale animation on tap (1.0 → 1.3 → 1.0)
- Success state animation (checkmark, confetti effect)
- Haptic feedback (UIImpactFeedbackGenerator)
- `@Binding var isPressed: Bool` for state tracking
- Soft, calming colors matching design system

### T-005: Create Success Toast Component
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Test**: Given success toast → When shown → Then animates in and auto-dismisses

Create `Components/SuccessToast.swift`:
- Slide-in animation from top
- "Noted! We'll remember this worked" message
- Auto-dismiss after 2 seconds
- Matches app design (soft colors, rounded corners)
- Can be dismissed by tap

### T-006: Create EffectivenessBadge Component
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03, AC-US4-05 | **Status**: [x] completed
**Test**: Given track with 80% effectiveness → When badge displayed → Then shows green badge with "80%"

Create `Components/EffectivenessBadge.swift`:
- Displays percentage (e.g., "75%")
- Color coding: green (>70%), yellow (40-70%), gray (<40%)
- Pill-shaped design matching neumorphic style
- Small size to fit on track cards
- Optional icon (checkmark/star)

### T-007: Create EffectivenessDetailPopover
**User Story**: US-004 | **Satisfies ACs**: AC-US4-04 | **Status**: [x] completed
**Test**: Given badge long-pressed → When popover appears → Then shows detailed stats

Create popover view showing:
- "Helped X out of Y times"
- Breakdown by cry type (if available)
- First and last helped dates
- Triggered by long press on badge

## Phase 3: Main Feature Views

### T-008: Create WhatWorksSection Component
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03, AC-US3-04 | **Status**: [x] completed
**Test**: Given tracks with effectiveness data → When section displayed → Then shows sorted by effectiveness

Create `Views/WhatWorksSection.swift`:
- Section header "What Works for [BabyName]" (from BabyProfileManager)
- Fallback to "What Works for Your Baby" if no profile
- Horizontal scroll of track cards
- Sorted by effectivenessScore descending
- "See All" button to dedicated view
- Observes EffectivenessManager for updates

### T-009: Create WhatWorksEmptyState
**User Story**: US-003 | **Satisfies ACs**: AC-US3-06 | **Status**: [x] completed
**Test**: Given no effectiveness data → When section displayed → Then shows friendly empty state

Create empty state view:
- Illustration (sleeping baby with question mark or lightbulb)
- "Start noting what helps!"
- "Tap 'It Helped!' when a track calms your baby"
- CTA button to start playing content

### T-010: Create InsightsView
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01, AC-US6-02, AC-US6-03 | **Status**: [x] completed
**Test**: Given effectiveness history → When insights viewed → Then shows charts and stats

Create `Views/InsightsView.swift`:
- Top 5 most effective tracks list
- Category breakdown (bar chart using SwiftUI Charts or custom)
- Simple statistics: total helped, most effective category
- Pull to refresh
- Empty state if no data

## Phase 4: Integration

### T-011: Integrate ItHelpedButton in PlayerView
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given player playing → When "It Helped!" tapped → Then feedback recorded

Modify PlayerView.swift:
- Add ItHelpedButton as floating overlay (bottom-right or dedicated area)
- Position to not overlap controls
- Show only when track is playing or recently paused
- Connect to EffectivenessManager.recordHelped()
- Pass current cryType if CryDetectionService has active detection

### T-012: Connect to AnalyticsCloudService
**User Story**: US-001 | **Satisfies ACs**: AC-US1-06 | **Status**: [x] completed
**Test**: Given "It Helped!" tapped → When online → Then analytics sent to cloud

Modify ItHelpedButton or PlayerView:
- Call AnalyticsCloudService.shared on feedback
- Include track metadata, cry type, timestamp
- Handle offline gracefully (queue for later)

### T-013: Track Play Count in EffectivenessManager
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 | **Status**: [x] completed
**Test**: Given track played → When playback starts → Then totalPlays incremented

Modify AudioEngine or PlayerView:
- On track start/play, call EffectivenessManager.recordPlay()
- Include cry type context if available
- Don't count repeated plays within short window (debounce)

### T-014: Add EffectivenessBadge to TrackCardView
**User Story**: US-004 | **Satisfies ACs**: AC-US4-02 | **Status**: [x] completed
**Test**: Given track with 60% effectiveness → When card displayed → Then badge shows

Modify TrackCardView.swift:
- Add EffectivenessBadge overlay (top-right corner)
- Only show if effectiveness > 0%
- Observe EffectivenessManager for data
- Add long-press gesture for detail popover

### T-015: Add WhatWorksSection to HomeView
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 | **Status**: [x] completed
**Test**: Given home view → When displayed → Then "What Works" section appears

Modify HomeView.swift:
- Add WhatWorksSection after hero card, before categories
- Only show if at least one track has effectiveness data
- Animate appearance

### T-016: Integrate Cry Type from CryDetectionService
**User Story**: US-005 | **Satisfies ACs**: AC-US5-04 | **Status**: [x] completed
**Test**: Given active cry detection → When "It Helped!" tapped → Then cry type auto-captured

Integration work:
- Check CryDetectionService.shared.currentCryType
- Pass to recordHelped() and recordPlay()
- Update UI to show detected cry type context

### T-017: Add Manual Cry Type Selection
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05 | **Status**: [x] completed
**Test**: Given no active detection → When "It Helped!" long-pressed → Then cry type picker appears

Add optional cry type picker:
- Long press on ItHelpedButton shows picker
- Options: Hungry, Tired, Discomfort, Bored, Unknown
- Quick tap uses auto-detected or "Unknown"

### T-018: Add Cry Type Filter to WhatWorksSection
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02, AC-US5-03 | **Status**: [x] completed
**Test**: Given filter to "Hungry" → When applied → Then shows tracks effective for hunger cries

Add filtering:
- Horizontal chip/pill filter buttons for cry types
- "All" plus individual cry types
- Filter getTopEffectiveTracks() by cryType
- Show cry type tags on track cards with strong correlation

## Phase 5: Polish & Refinements

### T-019: Connect to Existing EffectivenessFeedbackSheet
**User Story**: US-001 | **Satisfies ACs**: AC-US1-06 | **Status**: [x] completed
**Test**: Given detailed feedback submitted → When saved → Then also updates local EffectivenessManager

Bridge existing sheet:
- When EffectivenessFeedbackSheet submits "Very Effective" or "Worked Well"
- Also call EffectivenessManager.recordHelped()
- This unifies both feedback mechanisms

### T-020: Add Effectiveness Trends (Optional P2)
**User Story**: US-006 | **Satisfies ACs**: AC-US6-04 | **Status**: [x] completed
**Test**: Given historical data → When trends viewed → Then line chart shows improvement

Optional enhancement for InsightsView:
- Simple line chart of helped count over time
- Weekly/monthly aggregation
- Use SwiftUI Charts or custom path drawing

## Progress Summary
- Total Tasks: 20
- Phase 1 (Data): 3 tasks
- Phase 2 (Components): 4 tasks
- Phase 3 (Views): 3 tasks
- Phase 4 (Integration): 8 tasks
- Phase 5 (Polish): 2 tasks
