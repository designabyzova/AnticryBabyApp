# FS-003: "It Helped!" Feedback System

## Problem Statement

Parents using the app to calm their crying baby need a quick way to:
1. Mark when a specific track successfully calmed their baby
2. Build a personalized library of "proven effective" content for THEIR specific child
3. Quickly find what worked before, especially during stressful moments (e.g., 3am crying)
4. Understand correlations between cry types and effective responses

The app currently has an EffectivenessFeedbackSheet with 4 rating options, but:
- Feedback is only sent to cloud, not persisted locally
- No aggregated "what works for MY baby" view exists
- No quick one-tap feedback mechanism during playback
- Parents can't see "these tracks actually stopped crying" at a glance

## Solution Overview

Implement a lightweight feedback system that:
1. Adds a quick "It Helped!" button during/after playback
2. Persists effectiveness ratings locally per track
3. Creates a "What Works for [BabyName]" smart section
4. Shows effectiveness badges on track cards
5. Correlates effectiveness with detected cry types

## User Stories

### US-001: Quick "It Helped!" Feedback
**As a** parent whose baby just calmed down
**I want** a one-tap button to mark that the track worked
**So that** I can quickly note success without complex interactions during a stressful moment

#### Acceptance Criteria
- [ ] AC-US1-01: "It Helped!" floating button appears in PlayerView during playback
- [ ] AC-US1-02: Button shows success animation and haptic feedback on tap
- [ ] AC-US1-03: Feedback is saved locally with timestamp and context
- [ ] AC-US1-04: Button is large enough for easy tapping (min 60x60 points)
- [ ] AC-US1-05: Visual confirmation toast appears after tapping
- [ ] AC-US1-06: Integrates with existing AnalyticsCloudService for detailed tracking

### US-002: Local Effectiveness Persistence
**As a** parent
**I want** my feedback stored on device
**So that** I can see what works even without internet connection

#### Acceptance Criteria
- [ ] AC-US2-01: Create TrackEffectiveness model with trackId, helpedCount, totalPlays, lastHelped
- [ ] AC-US2-02: Create EffectivenessManager service following FavoritesManager pattern
- [ ] AC-US2-03: Persist to UserDefaults with JSON encoding (Codable)
- [ ] AC-US2-04: Track effectiveness per cry type (hunger, tired, discomfort, etc.)
- [ ] AC-US2-05: Calculate effectiveness score (0-100%) based on helped/plays ratio

### US-003: "What Works" Smart Section
**As a** parent with a crying baby at 3am
**I want** quick access to tracks that have worked before
**So that** I can find relief faster

#### Acceptance Criteria
- [ ] AC-US3-01: Add "What Works for [BabyName]" section on HomeView
- [ ] AC-US3-02: Section shows tracks sorted by effectiveness score (highest first)
- [ ] AC-US3-03: If baby profile not set, show "What Works for Your Baby"
- [ ] AC-US3-04: Section updates dynamically as new feedback is recorded
- [ ] AC-US3-05: Show effectiveness percentage badge on each track card
- [ ] AC-US3-06: Empty state with friendly illustration if no feedback yet

### US-004: Effectiveness Badges on Track Cards
**As a** parent browsing the library
**I want** to see at a glance which tracks have worked before
**So that** I can make informed choices quickly

#### Acceptance Criteria
- [ ] AC-US4-01: Add effectiveness badge component showing percentage
- [ ] AC-US4-02: Badge appears on TrackCardView when effectiveness > 0%
- [ ] AC-US4-03: Color-coded: green (>70%), yellow (40-70%), gray (<40%)
- [ ] AC-US4-04: Tooltip/long-press shows detailed stats (X times helped out of Y plays)
- [ ] AC-US4-05: Badge integrates with existing card styling (neumorphic design)

### US-005: Cry Type Correlation
**As a** parent
**I want** to know which tracks work best for specific cry types
**So that** I can quickly find the right content for each situation

#### Acceptance Criteria
- [ ] AC-US5-01: Store cry type context with each "It Helped!" feedback
- [ ] AC-US5-02: Filter "What Works" by cry type (hunger, tired, discomfort, etc.)
- [ ] AC-US5-03: Show cry type tags on tracks with multiple successes for that type
- [ ] AC-US5-04: Integrate with existing CryDetectionService for automatic context
- [ ] AC-US5-05: Allow manual cry type selection if detection not active

### US-006: Effectiveness History & Insights
**As a** parent
**I want** to see trends in what helps my baby
**So that** I can understand my baby's preferences over time

#### Acceptance Criteria
- [ ] AC-US6-01: Create "Insights" tab in Settings or dedicated view
- [ ] AC-US6-02: Show top 5 most effective tracks with stats
- [ ] AC-US6-03: Show most effective category breakdown (pie/bar chart)
- [ ] AC-US6-04: Show effectiveness trends over time (simple line graph)
- [ ] AC-US6-05: Export/share insights option (optional, P2)

## Technical Approach

### New Files to Create
1. `Models/TrackEffectiveness.swift` - Effectiveness data model
2. `Services/EffectivenessManager.swift` - Manages feedback persistence
3. `Components/ItHelpedButton.swift` - Floating feedback button
4. `Components/EffectivenessBadge.swift` - Badge component for track cards
5. `Views/WhatWorksSection.swift` - Smart section component for home
6. `Views/InsightsView.swift` - Effectiveness insights dashboard

### Integration Points
1. **PlayerView.swift** - Add ItHelpedButton overlay
2. **HomeView.swift** - Add WhatWorksSection before categories
3. **TrackCardView.swift** - Add EffectivenessBadge
4. **ContentView.swift** - Add Insights tab (optional)
5. **EffectivenessFeedbackSheet.swift** - Connect to local persistence

### Data Model

```swift
struct TrackEffectiveness: Codable, Identifiable {
    let id: UUID  // trackId
    var helpedCount: Int
    var totalPlays: Int
    var cryTypeBreakdown: [CryType: CryTypeStats]
    var lastHelped: Date?
    var firstRecorded: Date

    var effectivenessScore: Double {
        guard totalPlays > 0 else { return 0 }
        return Double(helpedCount) / Double(totalPlays) * 100
    }
}

struct CryTypeStats: Codable {
    var helpedCount: Int
    var totalCount: Int
}
```

## Out of Scope
- Server-side aggregation of effectiveness data (keep local for MVP)
- Machine learning-based recommendations (future enhancement)
- Social/community effectiveness sharing
- Detailed audio analysis correlation

## Success Metrics
- 70%+ of active users use "It Helped!" button at least once/week
- Average time to find effective track reduced by 50%
- User retention improvement (parents keep using what works)
