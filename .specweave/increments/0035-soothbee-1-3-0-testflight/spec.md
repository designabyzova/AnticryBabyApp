---
increment: 0035-soothbee-1-3-0-testflight
title: "Soothbee 1.3.0 TestFlight release"
type: feature
priority: P1
status: active
created: 2026-05-01
structure: user-stories
test_mode: test-after
coverage_target: 70
---

# Feature: Soothbee 1.3.0 TestFlight release

## Overview

The Soothbee rebrand shipped to the App Store as v1.2.0 (build 13) on Apr 21, 2026. Three iOS changes have landed since then on `main` but have not been released:

1. `f2ab976` — logo-first empty states + honeycomb halos
2. `2b04a4c` — mini-player tap-zone fix
3. `3307e38` — Russian Siri vocabulary (`ru.lproj/AppIntentVocabulary.plist`)

This increment cuts a TestFlight release of the cumulative state as **v1.3.0 (build 14)**. App Store submission is deferred to the user; this increment ends at TestFlight verification.

## User Stories

### US-001: TestFlight build 14 staged for review (P1)
**Project**: BabyInCarApp

**As a** product owner
**I want** v1.3.0 build 14 of Soothbee uploaded to TestFlight with refreshed screenshots and release notes
**So that** I can verify the polish work end-to-end before triggering App Store review

**Acceptance Criteria**:
- [x] **AC-US1-01**: `MARKETING_VERSION = 1.3.0` and `CURRENT_PROJECT_VERSION = 14` set across all 4 targets (main, watch, intents, intentsUI) in both Debug and Release configs.
- [x] **AC-US1-02**: `BabyInCarApp/fastlane/metadata/en-US/release_notes.txt` contains 1.3.0 release notes describing the three queued changes.
- [x] **AC-US1-03**: Fresh App Store screenshots in `BabyInCarApp/fastlane/screenshots/en-US/` for at least one iPhone size (6.9" or 6.7") and one iPad size (12.9" or 13"), generated against the current UI including new empty states.
- [x] **AC-US1-04**: Build visible in App Store Connect with status `VALID`. *(Build 50 / v1.3.0 / encryption=exempt, uploaded 2026-05-01 00:34 PDT.)*
- [x] **AC-US1-05**: Metadata + screenshots uploaded to App Store Connect, v1.3.0 row created, build attached, **submitted for App Store review** with `--automatic_release false` (will land in "Pending Developer Release" after Apple approval). *(Version ID `226f0e13-212e-4eb8-b7b6-f4ec2c4423b4`, state `WAITING_FOR_REVIEW` since 2026-05-01 06:22 PDT.)*

## Out of Scope

- App Store submission (`fastlane submit`) — user-triggered after TestFlight verification
- Subscription promo art refresh (Mar 19 art predates Soothbee colors — separate follow-up)
- Non-en-US localized metadata (existing setup is en-US only)
- Any code changes beyond the version-string bump
