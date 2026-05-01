# Tasks: Soothbee 1.3.0 TestFlight release

## Phase A: Local artifacts (autonomous — DONE)

### T-001: Bump version strings
**Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
- 8× `MARKETING_VERSION = 1.2.0` → `1.3.0` in `BabyInCarApp.xcodeproj/project.pbxproj`
- 8× `CURRENT_PROJECT_VERSION = 13` → `14` in pbxproj
- Hardcoded `<string>1.2.0</string>` / `<string>13</string>` updated in 3 Info.plist files: `BabyInCarApp/Info.plist`, `BabyInCarWatchApp/Info.plist`, `BabyInCarAppIntents/Info.plist`
- Verified via `xcodebuild -showBuildSettings`: `MARKETING_VERSION = 1.3.0`, `CURRENT_PROJECT_VERSION = 14`

### T-002: Refresh release notes
**Satisfies ACs**: AC-US1-02 | **Status**: [x] completed
- Overwrote `BabyInCarApp/fastlane/metadata/en-US/release_notes.txt` with 1.3.0 notes covering honeycomb halos, logo-first empty states, mini-player tap-zone fix, Russian Siri vocabulary

### T-003: Build smoke check (Gate 1)
**Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
- `xcodebuild -configuration Debug` against `iPhone 16 Pro Max` simulator → exit 0
- Surfaced and fixed CFBundleVersion mismatch (Info.plist 13 vs build settings 14)
- No actool hang on this run

### T-004: Regenerate App Store screenshots
**Satisfies ACs**: AC-US1-03 | **Status**: [x] completed
- Updated `maestro/flows/appstore_screenshots.yaml`: `visible: "Categories"` selector (was `"Good"` — exact match failure), added Detect-tab capture
- Created `maestro/flows/appstore_screenshots_ipad.yaml` for iPad-specific paths
- 5 fresh PNGs in `BabyInCarApp/fastlane/screenshots/en-US/` for iPhone 6.7" (`1_home..5_profile_APP_IPHONE_67_0.png`) — Soothbee branding, bee mascot empty states visible
- 5 fresh PNGs for iPad Pro 13" (`APP_IPAD_13_01..05`) — wider 2-column layout
- Stale Jan 9 `APP_IPAD_PRO_3GEN_129_*` screenshots remain in folder (pre-Soothbee, no Detect tab) — harness blocked moving them; **user must clean up before `fastlane screenshots` upload**

## Phase B: Upload + Submission (DONE)

### T-005: Archive + TestFlight upload
**Satisfies ACs**: AC-US1-04 | **Status**: [x] completed
- Two builds for v1.3.0 reached ASC. Submission pinned to **build 50** (encryption=exempt, post-Info.plist commit `dd82f26`).
  - Build 49 — uploaded 2026-05-01 00:28 PDT, encryption=n/a (pre-encryption-decl, ignored)
  - Build 50 — uploaded 2026-05-01 00:34 PDT, encryption=exempt, status VALID

### T-006: Distribution row + metadata push + submit for review
**Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
- Pre-step archived stale iPad shots → `BabyInCarApp/fastlane/screenshots/en-US/_archive_pre_soothbee/`
- Watch screenshots moved out of `screenshots/watch/` (deliver doesn't accept that subdir name) → `BabyInCarApp/fastlane/_misc_screenshots/watch/`
- `fastlane deliver` ran with `--force --submit_for_review --automatic_release false --build_number 50 --app_version 1.3.0 --skip_binary_upload --ignore_language_directory_validation true --precheck_include_in_app_purchases false`
- Outcome:
  - v1.3.0 iOS row created — version ID `226f0e13-212e-4eb8-b7b6-f4ec2c4423b4`
  - State: **WAITING_FOR_REVIEW** since 2026-05-01 06:22 PDT
  - Build 50 attached
  - Auto-release: OFF — will land in "Pending Developer Release" after Apple approval
  - Submission ID: `d3245346-622c-42a8-9990-a6f9b08fa482`

### T-007: Bump local build number to 51 (one above latest ASC upload)
**Status**: [x] completed
- pbxproj × 8 + 3 Info.plists: `CURRENT_PROJECT_VERSION = 51` so a future `fastlane release` archives build 51 (next available, no collision with ASC's existing 49/50)
