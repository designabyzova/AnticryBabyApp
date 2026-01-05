# Plan: Multi-Baby Profiles Implementation

## Phase 1: Data Model Foundation

### 1.1 Update Baby Model
- Add `BabyPreferences` struct to Baby.swift
- Add `favoriteTracks` and `favoritePlaylists` arrays to Baby
- Create `BabyFamily` container struct
- Ensure Codable conformance for all new types

### 1.2 Create Migration Service
- Detect single-baby legacy data format
- Migrate `currentBaby` to `BabyFamily.babies[0]`
- Migrate global favorites to first baby
- Clean up deprecated UserDefaults keys
- Add version marker to prevent re-migration

### 1.3 Update AppState
- Replace `currentBaby: Baby?` with `babyFamily: BabyFamily`
- Add computed property for backwards compatibility
- Add `switchBaby()`, `addBaby()`, `removeBaby()` methods
- Persist to UserDefaults as single "babyFamily" key

---

## Phase 2: Service Updates

### 2.1 FavoritesManager Refactor
- Change from global storage to reading from `appState.currentBaby.favoriteTracks`
- Update all methods to operate on active baby
- Add baby parameter overloads for testing

### 2.2 CryDetectionService Context
- Ensure cry detection uses `appState.currentBaby.id`
- Pass baby context to learning profile updates
- Verify BabyProfileManager already handles this correctly

### 2.3 Recommendations Engine
- Update to use current baby's age and preferences
- Verify AIRecommendationEngine uses correct baby context

---

## Phase 3: UI Components

### 3.1 BabyPicker Component
- Circular avatar button showing active baby
- Dropdown menu on tap with all babies
- Checkmark indicator for active baby
- Quick add/manage actions at bottom

### 3.2 Profile View Updates
- Add "My Babies" horizontal scroll section
- Per-baby settings section with baby name header
- Per-baby stats section
- Add/edit baby sheets

### 3.3 Navigation Integration
- Add BabyPicker to HomeView, LibraryView, FavoritesView
- Consistent placement (trailing navigation item)
- Animate avatar on baby switch

---

## Phase 4: Baby Management Screens

### 4.1 AddBabySheet
- Name field (required)
- Birthdate picker (required)
- Photo picker (optional)
- Validation and error states

### 4.2 EditBabySheet
- Pre-populated fields
- Delete button with confirmation
- Save/cancel actions

### 4.3 ManageBabiesView
- Full list of all babies
- Reorderable (drag to set preference order)
- Edit and delete actions

---

## Phase 5: CarPlay Integration

### 5.1 CarPlay Header Update
- Show active baby name in CPTemplate header
- Use baby avatar if available

### 5.2 CarPlay Baby Switcher
- "Switch Baby" as root menu item
- CPListTemplate with all babies
- On selection, update appState and refresh content

---

## Phase 6: Testing & Polish

### 6.1 Unit Tests
- Migration from single to multi-baby
- Baby CRUD operations
- Favorites per-baby isolation
- Settings per-baby isolation

### 6.2 UI Tests (Maestro)
- Add baby flow
- Switch baby flow
- Edit baby flow
- Delete baby with confirmation

### 6.3 Edge Cases
- First baby creation (fresh install)
- Delete only remaining baby (blocked)
- Switch while audio playing (continue or stop?)
- Deep links with baby context

---

## Implementation Order

```
1. Baby.swift model update
2. BabyFamily model
3. Migration service
4. AppState update + persistence
5. FavoritesManager refactor
6. BabyPicker component
7. Profile view updates
8. Add/Edit baby sheets
9. Navigation integration
10. Service context updates
11. CarPlay updates
12. Tests
```

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Migration data loss | Backup old keys before migration, rollback on failure |
| Performance (many babies) | Limit to 6 babies, lazy load profiles |
| State inconsistency | Single source of truth (appState.babyFamily) |
| Audio interruption on switch | Keep audio playing, just update context |

## Definition of Done

- [ ] All ACs passing
- [ ] Migration tested on existing user data
- [ ] Unit test coverage >80% for new code
- [ ] Maestro E2E flows passing
- [ ] CarPlay verified on simulator
- [ ] No memory leaks (Instruments check)
- [ ] Accessibility labels on all new components
