# FS-0014: Multi-Baby Profiles

## Overview

Enable parents with multiple children (twins, siblings, or caregivers watching different babies) to manage separate baby profiles with individual settings, favorites, and learning histories within a single app instance.

## Problem Statement

Currently, BabyInCarApp supports only a single baby profile (`currentBaby`). This creates problems for:

1. **Parents of twins/multiple children** - Can't track each baby's unique preferences and cry patterns
2. **Shared devices** - Grandparents/nannies using same phone for different families' babies
3. **Siblings** - Different ages require different content recommendations
4. **Learning accuracy** - All cry detection learning gets mixed between babies

## Architecture Decision: Contextual Profile System

After thorough analysis (see ADR below), we chose **Option C: Contextual Profile System** over:
- Simple profile switching (too limited)
- Dual-monitoring (technically impractical, battery drain)

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **One active baby at a time** | Phone mic can't distinguish multiple criers |
| **Quick-switch UI** | Parents need instant access during drives |
| **Per-baby favorites** | Each baby has unique calming preferences |
| **Per-baby settings** | Volume, timers, detection may differ by age |
| **Shared premium status** | One subscription covers all babies |

### The "Both Crying" Reality

**Honest limitation**: When two babies cry simultaneously, the app cannot distinguish which baby is crying. The parent must:
1. Select the baby most likely to need immediate attention
2. Switch manually if needed

**Future enhancement** (not this increment): Cry signature fingerprinting to identify individual babies.

---

## User Stories

### US-001: Add Multiple Babies
**As a** parent of multiple children
**I want to** add separate profiles for each of my babies
**So that** each child's preferences and learning history remain distinct

**Acceptance Criteria:**
- [ ] AC-US1-01: Can add a new baby from Profile screen (name, birthdate, optional photo)
- [ ] AC-US1-02: Maximum 6 babies per account (reasonable family limit)
- [ ] AC-US1-03: Each baby gets unique UUID and isolated data namespace
- [ ] AC-US1-04: Existing single baby automatically becomes first profile in list
- [ ] AC-US1-05: Baby creation validates required fields (name, birthdate)

### US-002: Switch Between Babies
**As a** parent or caregiver
**I want to** quickly switch which baby is active
**So that** cry detection and recommendations target the correct child

**Acceptance Criteria:**
- [ ] AC-US2-01: Baby avatar visible in top navigation bar (all main screens)
- [ ] AC-US2-02: Tap avatar opens quick-switch popup with all babies
- [ ] AC-US2-03: Switch completes in <200ms (no loading spinner needed)
- [ ] AC-US2-04: Active baby indicated with checkmark/highlight in switcher
- [ ] AC-US2-05: Switch updates cry detection context immediately
- [ ] AC-US2-06: Recent/last-used baby appears first in list (after active)

### US-003: Per-Baby Favorites
**As a** parent of multiple children
**I want to** save different favorite tracks for each baby
**So that** I can quickly access what works for each child

**Acceptance Criteria:**
- [ ] AC-US3-01: Favorites are stored per-baby (not global)
- [ ] AC-US3-02: Switching babies updates Favorites view immediately
- [ ] AC-US3-03: "Add to Favorites" saves to currently active baby
- [ ] AC-US3-04: Migration: existing global favorites assigned to first baby
- [ ] AC-US3-05: Favorites count shown per-baby in Profile

### US-004: Per-Baby Settings
**As a** parent
**I want to** configure different settings for each baby
**So that** volume levels and timers match each child's needs

**Acceptance Criteria:**
- [ ] AC-US4-01: Volume settings (default, max) stored per-baby
- [ ] AC-US4-02: Sleep timer preferences stored per-baby
- [ ] AC-US4-03: Cry detection toggle stored per-baby
- [ ] AC-US4-04: Settings screen shows/edits active baby's settings
- [ ] AC-US4-05: Settings header shows which baby's settings are displayed

### US-005: Per-Baby Learning Profiles
**As a** parent
**I want** the app to learn each baby's unique preferences separately
**So that** recommendations improve accurately for each child

**Acceptance Criteria:**
- [ ] AC-US5-01: BabyListeningProfile correctly uses babyId key (already implemented, verify)
- [ ] AC-US5-02: BabyMoodProfile correctly uses babyId key (already implemented, verify)
- [ ] AC-US5-03: Track effectiveness feedback stored with babyId
- [ ] AC-US5-04: "What Works" insights show data for active baby only
- [ ] AC-US5-05: AI recommendations use active baby's profile

### US-006: Manage Baby Profiles
**As a** parent
**I want to** edit or remove baby profiles
**So that** I can keep my family's information accurate

**Acceptance Criteria:**
- [ ] AC-US6-01: Can edit baby name and photo from Profile
- [ ] AC-US6-02: Can update birthdate (with age recalculation)
- [ ] AC-US6-03: Can delete a baby profile (with confirmation)
- [ ] AC-US6-04: Cannot delete if only one baby exists (keep at least one)
- [ ] AC-US6-05: Deleting active baby auto-switches to another baby

### US-007: CarPlay Baby Indicator
**As a** driving parent
**I want to** see which baby is active on CarPlay
**So that** I know the correct child is being monitored

**Acceptance Criteria:**
- [ ] AC-US7-01: Active baby name shown in CarPlay header
- [ ] AC-US7-02: "Switch Baby" is a root menu item in CarPlay
- [ ] AC-US7-03: Baby switch in CarPlay updates phone app state
- [ ] AC-US7-04: CarPlay baby list shows up to 6 babies safely

---

## Technical Design

### Data Model Changes

```swift
// NEW: Container for all babies
struct BabyFamily: Codable {
    var babies: [Baby]
    var activeBabyId: UUID?
    var quickSwitchEnabled: Bool = true
    var maxBabies: Int = 6

    var activeBaby: Baby? {
        babies.first { $0.id == activeBabyId }
    }
}

// UPDATED: Baby with embedded preferences
struct Baby: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var birthDate: Date
    var photoData: Data?

    // NEW: Per-baby preferences (previously global)
    var preferences: BabyPreferences
    var favoriteTracks: [UUID]
    var favoritePlaylists: [UUID]

    // Computed (existing)
    var ageInMonths: Int { ... }
    var developmentalStage: DevelopmentalStage { ... }
}

// NEW: Per-baby settings
struct BabyPreferences: Codable, Hashable {
    var defaultVolume: Float = 0.7
    var maxVolume: Float = 1.0
    var preferredSleepTimer: TimeInterval? = nil
    var enableCryDetection: Bool = true
    var downloadOnWiFiOnly: Bool = true
}
```

### AppState Changes

```swift
class AppState: ObservableObject {
    // OLD
    // @Published var currentBaby: Baby?

    // NEW
    @Published var babyFamily: BabyFamily = BabyFamily(babies: [])

    var currentBaby: Baby? { babyFamily.activeBaby }
    var allBabies: [Baby] { babyFamily.babies }

    func switchBaby(to babyId: UUID) {
        babyFamily.activeBabyId = babyId
        // Notify services of baby change
    }

    func addBaby(_ baby: Baby) {
        guard babyFamily.babies.count < babyFamily.maxBabies else { return }
        babyFamily.babies.append(baby)
        if babyFamily.activeBabyId == nil {
            babyFamily.activeBabyId = baby.id
        }
    }
}
```

### Migration Strategy

```swift
// One-time migration from single-baby to multi-baby
func migrateToMultiBaby() {
    if let singleBabyData = UserDefaults.standard.data(forKey: "currentBaby"),
       let singleBaby = try? JSONDecoder().decode(Baby.self, from: singleBabyData) {

        // Migrate global favorites to this baby
        let globalFavorites = UserDefaults.standard.array(forKey: "favoriteTracks") as? [String] ?? []
        var migratedBaby = singleBaby
        migratedBaby.favoriteTracks = globalFavorites.compactMap { UUID(uuidString: $0) }

        // Create family with migrated baby
        let family = BabyFamily(
            babies: [migratedBaby],
            activeBabyId: migratedBaby.id
        )

        // Save new structure
        saveBabyFamily(family)

        // Clean up old keys
        UserDefaults.standard.removeObject(forKey: "currentBaby")
        UserDefaults.standard.removeObject(forKey: "favoriteTracks")
    }
}
```

### Persistence Keys

| Old Key | New Key | Scope |
|---------|---------|-------|
| `currentBaby` | `babyFamily` | Single JSON blob |
| `favoriteTracks` | (embedded in Baby) | Per-baby |
| `BabyListeningProfiles` | (unchanged) | Already keyed by UUID |
| `BabyMoodProfiles` | (unchanged) | Already keyed by UUID |

---

## UI/UX Design

### Baby Picker Component

```
┌──────────────────────────────────────┐
│ [🏠] Home          [👶 Emma ▼]      │ ← Avatar + name, tap to switch
└──────────────────────────────────────┘

On tap, dropdown appears:
┌──────────────────────────────────────┐
│  Switch Baby                         │
├──────────────────────────────────────┤
│  ✓ 👶 Emma (3 mo)                   │ ← Active (checkmark)
│    👶 Noah (18 mo)                   │
│    👶 Lily (6 mo)                    │
├──────────────────────────────────────┤
│  [+ Add Baby]     [Manage Babies]   │
└──────────────────────────────────────┘
```

### Profile Screen Updates

```
┌──────────────────────────────────────┐
│ Profile                              │
├──────────────────────────────────────┤
│                                      │
│     👶 [Photo]                       │
│     Emma, 3 months                   │
│     [Switch Baby ▼]                  │
│                                      │
├──────────────────────────────────────┤
│ My Babies                            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│ │ 👶Emma  │ │ 👶Noah  │ │ + Add   │ │
│ │ ✓Active │ │         │ │  Baby   │ │
│ └─────────┘ └─────────┘ └─────────┘ │
├──────────────────────────────────────┤
│ Emma's Settings                      │ ← Shows active baby's name
│ • Volume: 70%                        │
│ • Cry Detection: On                  │
│ • Sleep Timer: 30 min                │
├──────────────────────────────────────┤
│ Emma's Stats                         │
│ • 45 favorite tracks                 │
│ • 12 listening hours                 │
│ • Top category: Lullabies            │
└──────────────────────────────────────┘
```

---

## Out of Scope (Future Increments)

1. **Cry signature fingerprinting** - ML to distinguish which baby is crying
2. **Dual-baby monitoring** - Simultaneous tracking (technically impractical)
3. **Cloud sync of baby profiles** - Backend storage for multi-device
4. **Family sharing** - Multiple parents accessing same babies
5. **Baby handoff** - Transfer baby profile to another device/caregiver

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Multi-baby adoption | 15% of users have 2+ babies | Analytics |
| Switch latency | <200ms | Performance test |
| Migration success | 100% of existing users migrated | Crash-free |
| Baby creation completion | >90% complete all fields | Funnel analytics |

---

## ADR: Multi-Baby Architecture Choice

**Decision**: Contextual Profile System with quick-switch

**Considered Alternatives**:
1. Simple profile list (rejected: no quick access while driving)
2. Dual-monitoring mode (rejected: phone mic limitation, battery drain)
3. Account-per-baby (rejected: login friction, subscription confusion)

**Consequences**:
- (+) Clean UX for 95% case (single baby)
- (+) Quick access for multi-baby families
- (+) Future-proof for cry fingerprinting
- (-) No simultaneous monitoring (acceptable limitation)
- (-) Manual switch required when both babies present

**Status**: Accepted
