# Tasks: Multi-Baby Profiles

## Phase 1: Data Model Foundation

### T-001: Create BabyPreferences struct
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03 | **Status**: [ ] pending
**Test**: Given new BabyPreferences → When initialized → Then has sensible defaults (volume 0.7, cry detection on)

**Implementation**:
- Create `BabyPreferences` struct in Baby.swift
- Properties: defaultVolume, maxVolume, preferredSleepTimer, enableCryDetection, downloadOnWiFiOnly
- Conform to Codable, Hashable
- Add default initializer with sensible values

---

### T-002: Update Baby model with per-baby data
**User Story**: US-003, US-004 | **Satisfies ACs**: AC-US3-01, AC-US1-03 | **Status**: [ ] pending
**Test**: Given Baby with favorites → When encoded/decoded → Then favorites preserved

**Implementation**:
- Add `preferences: BabyPreferences` property to Baby
- Add `favoriteTracks: [UUID]` property
- Add `favoritePlaylists: [UUID]` property
- Update Codable conformance
- Add backward-compatible decoder for legacy Baby format

---

### T-003: Create BabyFamily container model
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02, AC-US1-03 | **Status**: [ ] pending
**Test**: Given BabyFamily with 6 babies → When adding 7th → Then returns false (max limit)

**Implementation**:
- Create `BabyFamily` struct with `babies: [Baby]`, `activeBabyId: UUID?`
- Add `maxBabies: Int = 6` constant
- Add computed `activeBaby: Baby?` property
- Add helper methods: `baby(withId:)`, `canAddBaby: Bool`
- Conform to Codable

---

### T-004: Create migration service for single→multi baby
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04, AC-US3-04 | **Status**: [ ] pending
**Test**: Given legacy "currentBaby" UserDefaults → When migration runs → Then BabyFamily created with baby

**Implementation**:
- Create `BabyMigrationService` class
- Check for legacy "currentBaby" key
- Migrate existing baby to BabyFamily.babies[0]
- Migrate global "favoriteTracks" to first baby
- Add version marker "babyFamilyVersion" to prevent re-migration
- Clean up deprecated keys after successful migration

---

### T-005: Update AppState with BabyFamily
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03, AC-US2-05 | **Status**: [ ] pending
**Test**: Given appState → When switchBaby(to:) called → Then activeBabyId changes instantly

**Implementation**:
- Replace `@Published var currentBaby: Baby?` with `@Published var babyFamily: BabyFamily`
- Add computed `currentBaby` for backward compatibility
- Add `switchBaby(to babyId: UUID)` method
- Add `addBaby(_ baby: Baby) -> Bool` method
- Add `removeBaby(_ babyId: UUID) -> Bool` method
- Persist babyFamily to UserDefaults on change
- Call migration service on init if needed

---

## Phase 2: Service Layer Updates

### T-006: Refactor FavoritesManager to use per-baby storage
**User Story**: US-003 | **Satisfies ACs**: AC-US3-02, AC-US3-03, AC-US3-05 | **Status**: [ ] pending
**Test**: Given Baby A and Baby B → When adding favorite to A → Then B's favorites unchanged

**Implementation**:
- Update FavoritesManager to read from `appState.currentBaby.favoriteTracks`
- Modify `addFavorite(trackId:)` to update current baby
- Modify `removeFavorite(trackId:)` to update current baby
- Remove global UserDefaults storage for favorites
- Emit change notification when favorites change

---

### T-007: Update CryDetectionService with baby context
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03 | **Status**: [ ] pending
**Test**: Given active baby changed → When cry detected → Then correct baby's profile updated

**Implementation**:
- Verify `CryDetectionService` uses current babyId for profile updates
- Add `activeBabyId` property that syncs with AppState
- Pass babyId to `BabyProfileManager` updates
- Log baby context in cry detection events

---

### T-008: Verify learning profiles use correct baby context
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01, AC-US5-02, AC-US5-04 | **Status**: [ ] pending
**Test**: Given Baby A and B → When viewing "What Works" → Then shows A's data only

**Implementation**:
- Audit BabyProfileManager for babyId usage
- Audit BabyMoodProfileManager for babyId usage
- Verify WhatWorksInsightsView uses current baby
- Verify EffectivenessManager uses current baby
- Add integration tests for baby isolation

---

### T-009: Update AI Recommendations to use active baby
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05 | **Status**: [ ] pending
**Test**: Given 3-month baby active → When fetching recommendations → Then age-appropriate content returned

**Implementation**:
- Review AIRecommendationEngine.swift
- Ensure recommendations use `appState.currentBaby.ageInMonths`
- Pass baby's learning profile to recommendation engine
- Update SmartCryResponseEngine baby context

---

## Phase 3: UI Components

### T-010: Create BabyPicker component
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-04 | **Status**: [ ] pending
**Test**: Given 3 babies → When tapping picker → Then all 3 shown with active marked

**Implementation**:
- Create `BabyPickerView` SwiftUI component
- Circular avatar button (40x40) with baby photo or initials
- On tap, show dropdown Menu with all babies
- Checkmark icon on active baby
- "Add Baby" and "Manage Babies" at bottom
- Animate avatar on selection change

---

### T-011: Add BabyPicker to main navigation views
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-06 | **Status**: [ ] pending
**Test**: Given any main screen → When looking at nav bar → Then baby picker visible

**Implementation**:
- Add BabyPicker to HomeView toolbar (trailing)
- Add BabyPicker to LibraryView toolbar
- Add BabyPicker to FavoritesView toolbar
- Add BabyPicker to PlayerView (if space allows)
- Consistent placement and styling

---

### T-012: Update ProfileView with "My Babies" section
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01 | **Status**: [ ] pending
**Test**: Given 2 babies → When viewing Profile → Then both shown in horizontal scroll

**Implementation**:
- Add "My Babies" section at top of ProfileView
- Horizontal scroll of baby cards (avatar, name, age)
- Active baby highlighted
- "+ Add Baby" card at end
- Tap to select/switch baby
- Long-press for edit menu

---

### T-013: Update ProfileView settings to be per-baby
**User Story**: US-004 | **Satisfies ACs**: AC-US4-04, AC-US4-05 | **Status**: [ ] pending
**Test**: Given Baby Emma active → When viewing settings → Then header says "Emma's Settings"

**Implementation**:
- Update settings section header to show baby name
- Bind volume sliders to current baby's preferences
- Bind toggles to current baby's preferences
- Add observer to update on baby switch

---

## Phase 4: Baby Management

### T-014: Create AddBabySheet
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-05 | **Status**: [ ] pending
**Test**: Given AddBabySheet → When submitting with empty name → Then validation error shown

**Implementation**:
- Create `AddBabySheet` view with form
- Name TextField (required)
- DatePicker for birthdate (required, max today)
- PhotosPicker for baby photo (optional)
- Validation state for required fields
- "Add Baby" button calls appState.addBaby()
- Close sheet on success

---

### T-015: Create EditBabySheet
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01, AC-US6-02, AC-US6-03, AC-US6-04, AC-US6-05 | **Status**: [ ] pending
**Test**: Given EditBabySheet for only baby → When tapping delete → Then delete button disabled

**Implementation**:
- Create `EditBabySheet` view pre-populated with baby data
- Editable name, birthdate, photo
- Delete button (red, requires confirmation)
- Disable delete if only one baby
- On delete of active baby, switch to another

---

### T-016: Create ManageBabiesView
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01 | **Status**: [ ] pending
**Test**: Given ManageBabiesView → When tapping baby → Then EditBabySheet opens

**Implementation**:
- Create `ManageBabiesView` as full-screen list
- Show all babies with avatar, name, age
- Swipe actions: Edit, Delete
- Drag to reorder (optional, future)
- Tap row opens EditBabySheet

---

## Phase 5: CarPlay Integration

### T-017: Update CarPlay header with active baby
**User Story**: US-007 | **Satisfies ACs**: AC-US7-01 | **Status**: [ ] pending
**Test**: Given baby "Emma" active → When viewing CarPlay → Then header shows "Emma"

**Implementation**:
- Update CarPlaySceneDelegate header text
- Show "Listening for [BabyName]" or similar
- Update on baby switch notification

---

### T-018: Add CarPlay baby switcher menu
**User Story**: US-007 | **Satisfies ACs**: AC-US7-02, AC-US7-03, AC-US7-04 | **Status**: [ ] pending
**Test**: Given CarPlay → When tapping "Switch Baby" → Then all babies listed

**Implementation**:
- Add "Switch Baby" as root CPListTemplate item
- List all babies (max 6 per AC)
- On selection, call appState.switchBaby()
- Navigate back to main menu on switch
- Sync with phone app state

---

## Phase 6: Testing

### T-019: Write unit tests for migration service
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04, AC-US3-04 | **Status**: [ ] pending
**Test**: Comprehensive migration test coverage

**Implementation**:
- Test fresh install (no migration needed)
- Test single baby migration
- Test favorites migration
- Test idempotency (migration runs only once)
- Test corrupt data handling

---

### T-020: Write unit tests for BabyFamily operations
**User Story**: US-001, US-006 | **Satisfies ACs**: AC-US1-02, AC-US6-04 | **Status**: [ ] pending
**Test**: CRUD operations on BabyFamily

**Implementation**:
- Test add baby (success and max limit)
- Test remove baby (success and last baby protection)
- Test switch baby
- Test persistence round-trip
- Test activeBaby computed property

---

### T-021: Write integration tests for per-baby favorites
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02 | **Status**: [ ] pending
**Test**: Favorites isolation between babies

**Implementation**:
- Add favorite to Baby A
- Switch to Baby B
- Verify Baby B favorites empty
- Add favorite to Baby B
- Switch back to Baby A
- Verify Baby A favorites unchanged

---

### T-022: Create Maestro E2E flow for multi-baby
**User Story**: US-001, US-002, US-006 | **Satisfies ACs**: All | **Status**: [ ] pending
**Test**: Full E2E coverage of multi-baby journeys

**Implementation**:
- Flow: Add first baby during onboarding
- Flow: Add second baby from Profile
- Flow: Switch baby via picker
- Flow: Edit baby details
- Flow: Delete baby with confirmation
- Add to maestro/flows/multi_baby_flow.yaml

---

## Summary

| Phase | Tasks | Priority |
|-------|-------|----------|
| 1. Data Model | T-001 to T-005 | P0 - Must complete first |
| 2. Services | T-006 to T-009 | P0 - Core functionality |
| 3. UI Components | T-010 to T-013 | P0 - User-facing |
| 4. Baby Management | T-014 to T-016 | P0 - Required for CRUD |
| 5. CarPlay | T-017 to T-018 | P1 - Important but can ship without |
| 6. Testing | T-019 to T-022 | P0 - Required for quality |

**Total Tasks**: 22
**Estimated Effort**: 3-5 days
