# FS-017: Test Execution Guide

## 🧪 Test Stack Overview

| Test Layer | Tool | Coverage | Run Time |
|------------|------|----------|----------|
| **Unit Tests** | Swift Testing + XCTest | Services, Models | ~5s |
| **Snapshot Tests** | swift-snapshot-testing | UI Components | ~10s |
| **E2E Tests** | Maestro | User Journeys | ~2min |
| **Manual Tests** | Xcode Simulator | UX Validation | ~10min |

## 🚀 Quick Start

### 1. Install Maestro (if not installed)

```bash
# Install Maestro CLI
curl -fsSL "https://get.maestro.mobile.dev" | bash

# Verify installation
~/.maestro/bin/maestro --version
```

### 2. Run E2E Tests

```bash
# Navigate to Maestro flows directory
cd "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/maestro"

# Run all flows
~/.maestro/bin/maestro test flows/

# Run specific flow
~/.maestro/bin/maestro test flows/emergency_playlist_flow.yaml

# Run with screenshots
~/.maestro/bin/maestro test --format junit flows/
```

### 3. Run Unit Tests (Xcode)

```bash
# Command line (if Xcode CLI tools available)
xcodebuild test \
  -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: Product → Test (⌘U)
```

## 📋 E2E Test Flows

### Emergency Playlist Flow (`emergency_playlist_flow.yaml`)

**Purpose**: Verify full emergency mode activation and cancellation

**Steps**:
1. Launch app
2. Navigate to Cry Detection tab
3. Start monitoring
4. Trigger emergency mode (manual or mock)
5. Verify Emergency Queue View displays:
   - Cancel button
   - Current track card
   - Progress bar
   - Upcoming tracks list
6. Scroll through upcoming tracks
7. Tap cancel button
8. Verify effectiveness dialog
9. Select effectiveness rating
10. Verify emergency mode exits

**Expected Result**: Emergency mode activates, displays Spotify-like queue, and exits cleanly

### Language Filtering Flow (`language_filtering_flow.yaml`)

**Purpose**: Verify language preferences affect playlist selection

**Steps**:
1. Navigate to Profile/Settings
2. Select English only
3. Trigger emergency mode
4. Verify only English/Instrumental tracks in queue
5. Cancel and switch to Russian
6. Trigger emergency again
7. Verify Russian tracks now appear

**Expected Result**: Playlist selection respects language preferences

### Queue Navigation Flow (`queue_navigation_flow.yaml`)

**Purpose**: Verify queue updates and track metadata

**Steps**:
1. Activate emergency mode
2. Verify initial queue state
3. Verify track progress bar updates
4. Scroll through upcoming tracks
5. Tap current track card to view metadata
6. Verify metadata sheet displays:
   - Research citations
   - Effectiveness by cry type
   - Audio features
7. Close metadata sheet
8. Cancel emergency mode

**Expected Result**: Queue UI updates correctly, metadata accessible

## 🎯 Manual Test Scenarios

### Scenario 1: First-Time Emergency Activation

1. Fresh app install
2. Complete onboarding
3. Navigate to Cry Detection
4. Simulate cry (or manual trigger)
5. **Verify**:
   - Emergency mode activates within 2 seconds
   - Playlist name matches cry type
   - First track plays immediately (no fade)
   - Queue shows 5 upcoming tracks
   - Progress bar animates smoothly

### Scenario 2: Track Transitions

1. Activate emergency mode
2. Wait for first track to finish
3. **Verify**:
   - Second track starts with 2s crossfade
   - Current track card updates
   - Upcoming tracks shift up
   - Progress bar resets to 0:00
   - No audio glitches

### Scenario 3: Effectiveness Recording

1. Activate emergency mode
2. Let 3 tracks play
3. Tap cancel button
4. **Verify**:
   - Effectiveness dialog appears
   - Two options: "Very Effective" and "Not Effective"
   - Tapping either closes dialog
   - Emergency mode exits
   - No errors in console

### Scenario 4: Language Switching

1. Set language to English only
2. Trigger emergency mode
3. Observe playlist selection
4. Cancel and switch to Russian
5. Trigger emergency again
6. **Verify**:
   - Different playlist selected
   - Track language badges match preference
   - Playlist name in correct language

### Scenario 5: Metadata Inspection

1. Activate emergency mode
2. Tap current track card
3. **Verify Metadata Sheet**:
   - Track title and artist
   - Duration formatted (MM:SS)
   - Language badge
   - Calming score (0-100%)
   - Tempo (if rhythmic)
   - Research citations displayed
   - Effectiveness breakdown by cry type
   - Progress bars for each cry type

## 🐛 Common Test Failures

### Test: Emergency mode doesn't activate

**Symptoms**:
- Cry detected but no queue view
- Console shows "useEmergencyPlaylists is false"

**Fix**:
```swift
// In UserDefaults or Settings
UserDefaults.standard.set(true, forKey: "useEmergencyPlaylists")
```

### Test: Queue view shows but no tracks

**Symptoms**:
- Empty queue list
- Console shows "Failed to fetch playlists"

**Fix**:
- Verify `PlaylistSelector.mockPlaylists` is populated
- Check API connectivity (if using real backend)
- Verify AudioTrack model compatibility

### Test: Cancel button doesn't work

**Symptoms**:
- Tapping cancel has no effect
- No effectiveness dialog

**Fix**:
```swift
// Ensure EmergencyQueueManager.cancelSession() is called
// Verify @Published var showEffectivenessDialog is toggled
```

### Test: Track metadata sheet not appearing

**Symptoms**:
- Tapping current track card does nothing

**Fix**:
```swift
// Verify CurrentTrackCard has .sheet modifier:
.sheet(isPresented: $showMetadata) {
    TrackMetadataSheet(track: track)
}
```

### Test: Progress bar not animating

**Symptoms**:
- Progress stays at 0%
- Time doesn't update

**Fix**:
- Verify `EmergencyQueueManager.progress` is @Published
- Check Timer or AVPlayer progress updates
- Ensure smooth transitions enabled

## 📊 Test Coverage Targets

| Component | Target | Current | Notes |
|-----------|--------|---------|-------|
| PlaylistSelector | 80% | TBD | AI selection logic |
| EmergencyQueueManager | 80% | TBD | Session management |
| EmergencyQueueView | 60% | TBD | UI snapshots |
| TrackMetadata | 70% | TBD | Data parsing |
| API Endpoints | 90% | TBD | Integration tests |
| E2E Critical Paths | 100% | 3 flows | Emergency, language, queue |

## 🔍 Test Data

### Mock Playlists (16 total)

- **Hunger**: 3 playlists (newborn-multi, baby-multi, newborn-ru)
- **Tired**: 3 playlists (newborn-multi, baby-multi, baby-ru)
- **Pain**: 2 playlists (newborn-multi, baby-multi)
- **Discomfort**: 2 playlists (all-multi, all-ru)
- **Attention**: 2 playlists (baby-multi, toddler-multi)
- **General**: 4 playlists (newborn-multi, baby-multi, all-ru, toddler-multi)

### Mock Tracks (7 types)

- White Noise (0.95 calming score)
- Heartbeat (0.98 calming score)
- Brahms Lullaby (0.90 calming score)
- Russian Lullaby (0.92 calming score)
- Rain Sounds (0.88 calming score)
- Ocean Waves (0.85 calming score)
- Mozart (0.75 calming score, high attention)

## 📝 Test Execution Checklist

Before running tests:

- [ ] All Swift files added to Xcode project
- [ ] Project builds without errors
- [ ] Simulator running (iPhone 15, iOS 17+)
- [ ] Maestro installed and verified
- [ ] Mock data populated in PlaylistSelector
- [ ] useEmergencyPlaylists setting enabled

During E2E tests:

- [ ] Emergency mode activates within 2s
- [ ] Queue view displays all components
- [ ] Track transitions work smoothly
- [ ] Cancel flow completes successfully
- [ ] Language filtering works
- [ ] Metadata sheet accessible
- [ ] No crashes or memory leaks

After testing:

- [ ] All 3 Maestro flows pass
- [ ] Screenshots captured for each flow
- [ ] Console shows no errors
- [ ] Memory usage < 100MB
- [ ] UI responsive (<16ms frame time)

## 🚀 CI/CD Integration (Future)

```yaml
# .github/workflows/test-emergency-playlists.yml
name: Test Emergency Playlists

on: [push, pull_request]

jobs:
  e2e-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Maestro
        run: curl -fsSL "https://get.maestro.mobile.dev" | bash
      - name: Build iOS app
        run: xcodebuild -project BabyInCarApp.xcodeproj -scheme BabyInCarApp -destination 'platform=iOS Simulator,name=iPhone 15' build
      - name: Run E2E tests
        run: ~/.maestro/bin/maestro test maestro/flows/ --format junit
      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: maestro/results/
```

## 📞 Support

If tests fail or you encounter issues:

1. Check BUILD_VERIFICATION.md for build errors
2. Review IMPLEMENTATION_SUMMARY.md for architecture overview
3. Verify all files are added to Xcode project
4. Ensure mock data is populated
5. Check console logs for error messages

---

**Status**: Ready for testing! All E2E flows created and documented.
