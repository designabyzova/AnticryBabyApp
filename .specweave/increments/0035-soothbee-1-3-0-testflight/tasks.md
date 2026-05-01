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

## Phase B: Upload (BLOCKED — requires user execution)

### T-005: Archive + TestFlight upload
**Satisfies ACs**: AC-US1-04 | **Status**: [ ] blocked
- User-run command: `cd BabyInCarApp && fastlane build_and_upload`
- Harness blocked autonomous execution citing irreversible production publish

### T-006: ASC metadata + screenshot push
**Satisfies ACs**: AC-US1-05 | **Status**: [ ] blocked
- Pre-step: archive stale iPad screenshots — `cd BabyInCarApp/fastlane/screenshots/en-US && mkdir -p _archive_pre_soothbee && mv APP_IPAD_PRO_3GEN_129_*.png _archive_pre_soothbee/`
- User-run commands:
  - `cd BabyInCarApp && fastlane metadata` (push release notes + version)
  - `cd BabyInCarApp && fastlane screenshots` (push 10 fresh PNGs)
  - `asc apps builds list --bundle-id com.babyincar.app --limit 5` (verify build 14 in ASC)
- Hold for App Store submission (`fastlane submit`) — user-triggered after TestFlight verification
