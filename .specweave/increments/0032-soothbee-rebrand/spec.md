# Spec — Soothbee Rebrand

## Context

App currently ships as "Lulla" with a generic lavender palette and text-only wordmark. We're rebranding to **Soothbee** ("soothe" + "bee") with a Honeycomb Dusk palette (honey gold primary, lavender demoted to accent) and a bee/hexagon mark. Bundle ID `com.babyincar.app` and App Store ID `6756977992` are preserved — this is an in-place update, not a new app.

Full plan: `/Users/aabyzovext/.claude/plans/cheerful-percolating-lightning.md`

## User Stories

### US-001: App identity reads as "Soothbee" everywhere
**Project**: BabyInCarApp

**As a** user installing or re-opening the app
**I want** the brand name, launch screen, and iconography to consistently show "Soothbee"
**So that** the rebrand feels coherent and intentional

**Acceptance Criteria**:
- [x] **AC-US1-01**: iOS springboard shows "Soothbee" as the app name under the icon
- [x] **AC-US1-02**: App icon shows the honey-gold hexagon + bee placeholder mark (no lavender lozenge)
- [x] **AC-US1-03**: Launch screen displays "Soothbee" wordmark + tagline "The hum that calms your baby."
- [x] **AC-US1-04**: All 10 language variants (en, ru, es, fr, de, zh-Hans, ja, pt, ar, it) in Localizable.xcstrings use "Soothbee"
- [x] **AC-US1-05**: Info.plist permission prompts (microphone, Siri, photos, camera, speech) reference "Soothbee", not "Lulla"
- [x] **AC-US1-06**: Privacy + Terms of Use strings reference `soothbee.app` domain and `@soothbee.app` email addresses
- [x] **AC-US1-07**: `grep -ri "Lulla" BabyInCarApp/ maestro/ scripts/ --exclude-dir=build` returns zero hits in active code (archival ADR/CHANGELOG entries allowed)

### US-002: Visual palette reflects Honeycomb Dusk
**Project**: BabyInCarApp

**As a** user
**I want** the UI to feel warmer and more distinctive (honey gold primary, lavender accent retained)
**So that** Soothbee visually differentiates from generic pastel baby apps while preserving the calming tone

**Acceptance Criteria**:
- [x] **AC-US2-01**: `Color.appPrimary` returns honey gold `#E8A838` (was lavender `#9B8DC7`)
- [x] **AC-US2-02**: `Color.appPrimaryDark` returns amber `#B8791E`; `appPrimaryLight` returns `#F5D985`
- [x] **AC-US2-03**: `Color.appSecondary` holds lavender `#9B8DC7` (role swap preserves calm cue)
- [x] **AC-US2-04**: New tokens `Color.honeyDeep` and `Color.hiveCharcoal` exist and are usable from SwiftUI
- [x] **AC-US2-05**: `Color.appBackground` shifts to warmer cream `#FDF6E8`
- [x] **AC-US2-06**: Instrumental category color retinted to `#C49A5E` so it no longer clashes with primary brand
- [x] **AC-US2-07**: 273 existing call sites of `Color.appPrimary*` require no edits (in-place remap)

### US-003: Cry detection feels like "the hive wakes up"
**Project**: BabyInCarApp

**As a** parent in a cry-monitoring moment
**I want** to see a clear, distinctive animation that shows the app is listening and how confident it is
**So that** I trust the detection and the moment feels calm rather than clinical

**Acceptance Criteria**:
- [x] **AC-US3-01**: `HoneycombPulseView` exists at `Views/Components/HoneycombPulseView.swift`
- [x] **AC-US3-02**: View accepts `confidence: Double (0–1)`, `detectedCryType: CryType?`, `isListening: Bool`
- [x] **AC-US3-03**: Idle state pulses the center hex at ~1.5s spring cadence
- [x] **AC-US3-04**: As confidence rises, concentric rings light up — center only at <0.3, center+ring1 at 0.3–0.6, all 7 at >0.6
- [x] **AC-US3-05**: Pulse color is `appPrimary` (honey gold), tinted by the detected cry type's category color when present
- [x] **AC-US3-06**: Existing cry-detection view integrates `HoneycombPulseView`, preserving bindings to `SoundAnalysisCryDetector.shared`
- [x] **AC-US3-07**: View has at least one `#Preview` showing idle, rising, and detected states

### US-004: Empty states show the bee, not a void
**Project**: BabyInCarApp

**As a** user who opens Favorites / Playlists / Queue for the first time
**I want** to see a warm bee illustration and a copy line that invites the next action
**So that** empty screens feel friendly instead of abandoned

**Acceptance Criteria**:
- [x] **AC-US4-01**: `BeeEmptyState` component exists at `Views/Components/BeeEmptyState.swift` with a `mood: Mood` enum (`.sleeping`, `.listening`, `.happy`)
- [x] **AC-US4-02**: Each mood renders via SF Symbols (hexagon + leaf wing + mood-specific overlay) — no raster assets required
- [x] **AC-US4-03**: Empty Favorites screen uses `BeeEmptyState(mood: .sleeping, ...)`
- [x] **AC-US4-04**: Empty Playlists screen uses `BeeEmptyState(mood: .happy, ...)`
- [x] **AC-US4-05**: Empty Queue (Smart/Emergency) screen uses `BeeEmptyState(mood: .listening, ...)`

### US-005: "It Helped!" feels rewarding via honey drop
**Project**: BabyInCarApp

**As a** parent confirming that a track calmed the baby
**I want** a delightful, brand-coherent micro-interaction
**So that** positive feedback is pleasant to give and reinforces the bee metaphor

**Acceptance Criteria**:
- [x] **AC-US5-01**: `HoneyDropAnimation` component exists and animates a honey drop from the tap point toward a hex reserve icon
- [x] **AC-US5-02**: Tapping "It Helped" triggers the animation plus a soft double-tap haptic (120ms apart)
- [x] **AC-US5-03**: A hex reserve indicator is visible somewhere persistent (nav/tab bar) and gains honey on each helpful tap (non-reversible session counter is acceptable for this increment)

### US-006: Paywall reads "Unlock the hive"
**Project**: BabyInCarApp

**As a** user hitting a free-tier cap
**I want** a paywall that feels native to the bee world, not a generic upgrade screen
**So that** the upsell moment reinforces the brand instead of feeling transactional

**Acceptance Criteria**:
- [x] **AC-US6-01**: Paywall headline reads "Unlock the hive"
- [x] **AC-US6-02**: Subhead: "Every lullaby. Every fairy tale. Every sound your baby trusts."
- [x] **AC-US6-03**: Primary CTA button label is "Open the hive"
- [x] **AC-US6-04**: Feature bullets use SF Symbol `hexagon.fill` at ~10pt as the bullet marker (not checkmarks)
- [x] **AC-US6-05**: Paywall background shows a subtle repeating hex outline pattern at ~8% opacity in `honeyDeep`
- [x] **AC-US6-06**: All pricing, tier logic, and StoreKit flow are unchanged (copy/visual only)

### US-007: I can build and run locally on iPhone 15 simulator
**Project**: BabyInCarApp

**As a** developer
**I want** a one-command build-and-run script
**So that** I can visually verify the rebrand in under 2 minutes

**Acceptance Criteria**:
- [x] **AC-US7-01**: `scripts/build-and-run-simulator.sh` exists, is executable, and accepts no required arguments
- [x] **AC-US7-02**: The script boots an iPhone 15 simulator, installs the Debug build, launches `com.babyincar.app`
- [x] **AC-US7-03**: The script prints a helpful message if `actool` hangs (reboot recommendation from project memory)
- [x] **AC-US7-04**: On successful launch, the simulator shows the new app icon on the home screen and the "Soothbee" display name
