# Tasks — Soothbee Rebrand

Execution order: Phase 1 (blockers) → Phase 2 (signature visual) → Phase 3 (delight) → Phase 4 (verification).

## Phase 1 — Brand Shell

### T-001: Remap color tokens in Colors.swift
**AC**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05, AC-US2-06, AC-US2-07 | **Status**: [x] completed
**Test**: Given Colors.swift after edit → When a SwiftUI preview of `Color.appPrimary` renders → Then it shows honey gold `#E8A838`.

### T-002: Update Info.plist (main app) — name + 5 usage descriptions + alt names
**AC**: AC-US1-01, AC-US1-05 | **Status**: [x] completed
**Test**: Given plistbuddy reads Info.plist → When inspecting CFBundleDisplayName, NSMicrophoneUsageDescription, INAlternativeAppNames → Then all strings say "Soothbee", no "Lulla".

### T-003: Update Watch Info.plist display name
**AC**: AC-US1-01 | **Status**: [x] completed
**Test**: Given BabyInCarWatchApp/Info.plist → When reading CFBundleDisplayName → Then it's "Soothbee".

### T-004: Update project.pbxproj INFOPLIST_KEY_CFBundleDisplayName entries
**AC**: AC-US1-01 | **Status**: [x] completed
**Test**: Given `grep INFOPLIST_KEY_CFBundleDisplayName project.pbxproj` → When inspecting the 4 matches → Then none contain "Lulla".

### T-005: Update LaunchScreen.storyboard (name + tagline)
**AC**: AC-US1-03 | **Status**: [x] completed
**Test**: Given LaunchScreen.storyboard → When parsing the label text attrs at lines ~32 and ~39 → Then they are "Soothbee" and "The hum that calms your baby.".

### T-006: Update Localizable.xcstrings across 10 languages (4 keys + privacy/TOS)
**AC**: AC-US1-04, AC-US1-06 | **Status**: [x] completed
**Test**: Given jq query on Localizable.xcstrings → When counting occurrences of "Lulla" vs "Soothbee" across all language stringUnit values → Then "Lulla" = 0 in active translation strings and "Soothbee" appears in all 10 language variants for the brand key.

### T-007: Rename LullaShortcuts.swift → SoothbeeShortcuts.swift and fix call sites
**AC**: AC-US1-07 | **Status**: [x] completed
**Test**: Given `grep -r "LullaShortcuts" BabyInCarApp/` → Then zero hits.

### T-008: Update AccentColor.colorset fallback to honey gold
**AC**: AC-US2-01 | **Status**: [x] completed
**Test**: Given AccentColor.colorset/Contents.json → When reading sRGB components → Then they match `#E8A838`.

### T-009: Write + run placeholder icon generator
**AC**: AC-US1-02 | **Status**: [x] completed
**Test**: Given `scripts/generate-placeholder-icon.swift` runs → When inspecting icon_1024.png → Then it's a 1024×1024 PNG with honey-gold-dominant center pixel.

### T-010: Update BabyInCarAppIntents/README.md Siri command examples
**AC**: AC-US1-07 | **Status**: [x] completed
**Test**: Given README.md → When grepping → Then no "Lulla" references remain; all Siri examples say "in Soothbee".

## Phase 2 — Signature Visual

### T-011: Create HoneycombPulseView.swift
**AC**: AC-US3-01, AC-US3-02, AC-US3-03, AC-US3-04, AC-US3-05, AC-US3-07 | **Status**: [x] completed
**Test**: Given `#Preview` with confidence 0, 0.5, 1.0 → When rendered in Xcode Previews → Then 1, 3, 7 hexagons are visibly active respectively.

### T-012: Integrate HoneycombPulseView into cry detection screen
**AC**: AC-US3-06 | **Status**: [x] completed
**Test**: Given app running and cry detection started → When confidence rises → Then the honeycomb cells animate (not the previous waveform).

### T-013: Create BeeEmptyState component
**AC**: AC-US4-01, AC-US4-02 | **Status**: [x] completed
**Test**: Given `BeeEmptyState(mood: .sleeping, title: "x", caption: "y")` → When rendered → Then a hex + leaf + Zzz overlay is visible.

### T-014: Apply BeeEmptyState to 3 empty screens (Favorites, Playlists, Queue)
**AC**: AC-US4-03, AC-US4-04, AC-US4-05 | **Status**: [x] completed
**Test**: Given a fresh user with empty favorites/playlists/queue → When opening each → Then the appropriate BeeEmptyState renders.

## Phase 3 — Delight

### T-015: Create HoneyDropAnimation + HiveReserveIndicator
**AC**: AC-US5-01, AC-US5-03 | **Status**: [x] completed
**Test**: Given tap on "It Helped" button → When the animation plays → Then a honey drop travels to the reserve and the reserve's fill level increases.

### T-016: Wire honey drop animation + haptic to "It Helped" tap
**AC**: AC-US5-02 | **Status**: [x] completed
**Test**: Given "It Helped" tap → When inspecting HapticManager.impact calls → Then two calls at ~120ms apart are recorded.

### T-017: Rewrite paywall copy + hex bullet markers + hex pattern background
**AC**: AC-US6-01, AC-US6-02, AC-US6-03, AC-US6-04, AC-US6-05, AC-US6-06 | **Status**: [x] completed
**Test**: Given paywall presented → When reading visible text → Then headline is "Unlock the hive", CTA is "Open the hive", bullets use hexagon symbols, background shows subtle hex pattern.

## Phase 4 — Local Testability + Verification

### T-018: Write scripts/build-and-run-simulator.sh
**AC**: AC-US7-01, AC-US7-02, AC-US7-03 | **Status**: [x] completed
**Test**: Given a macOS dev machine with Xcode → When running `bash scripts/build-and-run-simulator.sh` → Then iPhone 15 simulator boots and launches the app.

### T-019: Update Maestro onboarding_flow if it references "Lulla"
**AC**: AC-US1-07 | **Status**: [x] completed
**Test**: Given maestro flow → When grepping for "Lulla" → Then zero hits.

### T-020: Add rebrand smoke flow + snapshot tests
**AC**: AC-US1-02, AC-US1-01 | **Status**: [x] completed
**Test**: Given rebrand_smoke.yaml → When run → Then it launches the app and captures a screenshot containing "Soothbee".

### T-021: Final Lulla-grep sweep
**AC**: AC-US1-07 | **Status**: [x] completed
**Test**: Given `grep -ri "Lulla" BabyInCarApp/ maestro/ scripts/ --exclude-dir=build --exclude-dir=.specweave` → Then only historical/archival hits remain (ADRs, release notes) — zero in active code paths.
