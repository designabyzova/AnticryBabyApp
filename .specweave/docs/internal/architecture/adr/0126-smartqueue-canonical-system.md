# ADR-0126: SmartQueue as Canonical Emergency System

**Date**: 2026-01-04
**Status**: Accepted (already in production)

## Context

The BabyInCarApp has evolved two emergency queue systems over time:

### Legacy System (FS-017 Original)

Created in FS-017 increment, the original emergency system consisted of:

| Component | Purpose | Lines |
|-----------|---------|-------|
| `EmergencyQueueManager` | Session management, API calls | 291 |
| `EmergencyQueueView` | Basic queue display | 153 |

**Features**:
- API-based session management (`/emergency/session/start`, `/emergency/session/end`)
- Basic track list display
- Progress tracking
- Session effectiveness recording

### SmartQueue System (Enhanced FS-017)

Enhanced version with AI-powered features:

| Component | Purpose | Lines |
|-----------|---------|-------|
| `SmartEmergencyQueue` | AI-powered track selection, queue management | 1,185 |
| `SmartQueueView` | Spotify-like UI, animations, gestures | 1,091 |

**Features**:
- AI-powered track selection using effectiveness history
- Favorites integration
- Category rotation algorithm
- Science-based scoring (Standley 2002, Rauscher 1993, Shenfield 2003)
- Proactive ambient mode (plays before cry detection)
- Cry-type specific queue building
- Real-time crossfade transitions
- Interactive progress bar with scrubbing
- Quick suggestions panel
- Drag-to-reorder capability
- Track detail sheets
- Effectiveness feedback ("Was baby calmed?")
- Banned sounds list (no white/pink/brown noise - research shows these scare babies)

### Current Production State

As of this ADR, the production code already uses SmartQueue:

```swift
// CryDetectionView.swift (line ~91)
SmartQueueView()  // Production uses SmartQueueView

// SmartCryResponseEngine.swift (line ~49)
private let smartEmergencyQueue = SmartEmergencyQueue.shared  // Correct
```

The legacy reference at line 44 (`EmergencyQueueManager?`) is never instantiated.

## Decision

**SmartQueue (SmartEmergencyQueue + SmartQueueView) is the canonical emergency system.**

### Singleton Pattern

```swift
// The ONE source of truth for emergency queue
SmartEmergencyQueue.shared

// The ONE UI for emergency queue display
SmartQueueView()
```

### Integration Points

| Integration | Component | Notes |
|-------------|-----------|-------|
| Cry Detection | `CryDetectionService` -> `SmartCryResponseEngine` -> `SmartEmergencyQueue` | Cry type passed through |
| UI Display | `CryDetectionView` overlays `SmartQueueView` | Sheet presentation |
| Audio Playback | `SmartEmergencyQueue` -> `PlaybackSessionManager` -> `AudioEngine` | Priority queue |
| Effectiveness | `SmartEmergencyQueue` -> `EffectivenessManager` | Learning loop |
| Favorites | `SmartEmergencyQueue` -> `FavoritesManager` | Boost favorite tracks |

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    EMERGENCY RESPONSE PIPELINE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CryDetectionService                                             │
│       │ (detects cry)                                           │
│       ▼                                                          │
│  SmartCryResponseEngine                                          │
│       │ (classifies cry type: tired/hunger/pain/etc)            │
│       ▼                                                          │
│  SmartEmergencyQueue.shared                                      │
│       │ buildQueue(for: cryType, babyAge: age)                  │
│       │   • Gets tracks from ContentLibraryService              │
│       │   • Scores by effectiveness history                      │
│       │   • Boosts favorites                                     │
│       │   • Applies category rotation                            │
│       │   • Filters banned sounds (no white noise)              │
│       ▼                                                          │
│  PlaybackSessionManager.shared                                   │
│       │ requestPlayback(track:, from: .emergencyMode)           │
│       ▼                                                          │
│  AudioEngine.shared                                              │
│       │ (plays audio with crossfade)                            │
│       ▼                                                          │
│  SmartQueueView (UI)                                             │
│       • Shows current track                                      │
│       • Displays AI reasoning                                    │
│       • Allows skip/previous/scrub                              │
│       • Collects effectiveness feedback                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Alternatives Considered

### 1. Keep Both Systems Active

**Approach**: Maintain both EmergencyQueueManager and SmartEmergencyQueue

**Pros**:
- No migration effort
- Fallback if SmartQueue fails

**Cons**:
- Developer confusion (which to use?)
- Maintenance burden (sync features?)
- Divergent behavior
- Doubled testing surface

**Why Not Chosen**: Confusion outweighs fallback benefit. SmartQueue is already production-proven.

### 2. Merge Systems

**Approach**: Combine EmergencyQueueManager features into SmartEmergencyQueue

**Pros**:
- Single system
- All features in one place

**Cons**:
- EmergencyQueueManager has API-based session (not used)
- Different paradigms (API vs local-first)
- Unnecessary complexity

**Why Not Chosen**: SmartEmergencyQueue already has superset of features. API session management is not used in practice.

### 3. Create New Unified System

**Approach**: Build new emergency system from scratch

**Pros**:
- Clean architecture
- No legacy baggage

**Cons**:
- 2,276 lines of working code exists
- SmartQueue already has all needed features
- High risk for P0 feature
- Wasted effort

**Why Not Chosen**: SmartQueue works well. No reason to rewrite.

## Consequences

### Positive

- **Single source of truth**: Only one emergency system to understand
- **Clear ownership**: SmartEmergencyQueue.shared is THE singleton
- **Feature-complete**: AI learning, favorites, category rotation, etc.
- **Production-proven**: Already running in production
- **Reduced maintenance**: One system instead of two
- **Clear documentation**: This ADR serves as official record

### Negative

- **Legacy code remains**: EmergencyQueueManager stays (deprecated)
- **Migration effort**: Tests need updating
- **Reference cleanup**: Remove line 44 from SmartCryResponseEngine

### Neutral

- **API endpoints unused**: `/emergency/session/*` API not called
- **EmergencySession model may be orphaned**: Verify usage

## Technical Notes

### Key Features of SmartEmergencyQueue

1. **AI Track Selection**
   ```swift
   func getMelodicTracksForCryType(cryType:babyAge:language:maxCount:)
   // Uses: effectiveness history, favorites, category scoring, recency penalty
   ```

2. **Ambient Mode**
   ```swift
   func startAmbientMode(babyAge:language:)
   // Proactive playlist - plays BEFORE cry detection
   ```

3. **Cry-Specific Queue Building**
   ```swift
   func buildQueue(for:babyAge:language:maxTracks:)
   // Different categories prioritized per cry type
   ```

4. **Banned Sounds**
   ```swift
   private static let bannedCategories: Set<String> = [
       "whitenoise", "noise", "generated"
   ]
   // Research shows white noise scares babies
   ```

### SmartQueueView Key Features

1. **Spotify-like UI**: Album art, progress bar, up next
2. **AI Reasoning Cards**: Shows WHY tracks were selected
3. **Interactive Progress**: Scrubbing, skip, previous
4. **Effectiveness Feedback**: "Was baby calmed?" prompt
5. **Quick Suggestions**: Tap to play recommended tracks

## Related Decisions

- **ADR-0125**: Deprecation vs Deletion Strategy
- **ADR-0127**: Test Migration Strategy
- **FS-017**: Original Smart Emergency Playlist System
- **FS-021**: Emergency Systems Consolidation
