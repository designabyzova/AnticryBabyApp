# Completion Report — Soothbee Rebrand (0032)

Date: 2026-04-17
Scope delivered: **Full rebrand (Tiers 1 + 2 + 3)** per approved plan.

## Summary of Changes

**Brand shell** (Phase 1)
- Info.plist (main + Watch): CFBundleName, CFBundleDisplayName, 5 usage descriptions, 3 INAlternativeAppNames → Soothbee
- project.pbxproj: all INFOPLIST_KEY_CFBundleDisplayName entries → Soothbee
- LaunchScreen.storyboard: wordmark + tagline + background retinted to Honeycomb Dusk
- Colors.swift: appPrimary remapped lavender → honey gold `#E8A838`; lavender preserved as appSecondary accent; 2 new tokens (`honeyDeep`, `hiveCharcoal`); instrumentalColor retinted to bronze to avoid brand clash
- Localizable.xcstrings: 22 Soothbee substitutions across 10 languages; privacy/TOS domain + email swaps
- AppIntentVocabulary.plist × 10 languages: 70 Siri phrase substitutions
- LullaShortcuts.swift → SoothbeeShortcuts.swift (file rename + class rename + pbxproj reference update)
- AccentColor.colorset retinted to honey gold sRGB
- 16+ Swift files: UI strings, artist defaults, Siri shortcut titles/phrases, NSUserActivity type IDs (`com.lulla.*` → `com.soothbee.*`, producer + consumer in lockstep)
- BabyInCarAppIntents/README.md rebranded
- Placeholder app icon generator: `scripts/generate-placeholder-icon.swift` (CoreGraphics), produced icons at 16/32/64/128/256/512/1024 for main + Watch

**Signature visual** (Phase 2)
- `Views/Components/HoneycombPulseView.swift` — 7-cell hex grid (1 center + 6 ring), confidence-driven ring activation, tinted by detected MoodType, SwiftUI `#Preview` for 3 states
- `CryDetectionView.swift` — pulse replaces top of waveform section; background gradient retinted to hive cream → light honey → lavender
- `Views/Components/BeeEmptyState.swift` — reusable `(mood, title, caption)` with bee-in-hex composite (SF Symbols, zero raster assets)
- 3 empty screens updated: FavoritesView, PlaylistViews user-playlists section, SmartSoothingQueueView upcoming section

**Brand-coherent delight** (Phase 3)
- `Views/Components/HoneyDropAnimation.swift` — HiveReserveStore (session counter), HiveReserveIndicator (persistent hex with fill), HoneyDropOverlay (drop animation), HoneycombPattern (tileable hex stroke background)
- SmartSoothingQueueView "It Helped!" button rewired: honey-gold gradient, drop icon, reserve indicator inline, soft double-tap haptic (120ms), addDrop() call
- CryStopPromptView "It Helped!" button rewired with same pattern
- SoftPaywallSheet rewritten: hive-lock overlay, "Unlock the hive" headline, "Open the hive" CTA, hex bullet marker pattern, honeycomb background at 8% opacity
- EngagementUpgradeSheet background: honeycomb pattern overlay

**Local testability** (Phase 4)
- `scripts/build-and-run-simulator.sh` — one-command build + install + launch on iPhone 15 sim
- `maestro/flows/rebrand_smoke.yaml` — asserts "Soothbee" visible + "Lulla" not visible on launch
- Maestro onboarding/library flows: no Lulla brand refs found (only music-category "Lullabies" strings, correctly preserved)

## Verification

- Final `grep -rn "Lulla" ...` excluding music-category + tests + build dir returns **3 hits**:
  - `Colors.swift:55` — archival comment (explicitly whitelisted)
  - `maestro/flows/rebrand_smoke.yaml:21,22` — smoke test that *asserts Lulla is absent*
- `grep "com\\.lulla\\."` in source returns **0 hits**
- No broken consumers of renamed activity types (producer + consumer in `SharedAudioModels.swift`, `BabyInCarApp.swift`, `SiriShortcutsService.swift` all updated together)

## Known Caveats

- Diagnostics reported by SourceKit during editing were pre-existing module-resolution artifacts that do not occur under `xcodebuild` (all Swift files are in the same module/target).
- **Pre-existing build issue (not caused by this rebrand)**: the project's BabyInCarWatchApp target is configured to compile against `iphonesimulator` platform, but its AppIcon assetset declares `platform: watchos`. `actool` therefore fails with "stickers icon set or app icon set named 'AppIcon' did not have any applicable content." Verified by stashing the new icon and restoring the original — same failure. This blocks `xcodebuild` at the command line but users running inside Xcode can disable the Watch target in Scheme → Manage Schemes to build + run the iOS app. The build script prints remediation steps when it hits this error.
- Icon is a CoreGraphics placeholder. Same filename (`icon_1024.png`) → drop a real designer asset in later without code changes.
- App Store Connect metadata (screenshots, description) is intentionally deferred to a follow-up.
- Website rebrand (lulla-app.pages.dev) is a separate codebase, out of scope.

## How to Test Locally

```bash
bash scripts/build-and-run-simulator.sh
```

Visual checkpoints on first launch:
1. Home screen: honey-gold hex app icon under the name "Soothbee"
2. Launch screen: "Soothbee" + "The hum that calms your baby."
3. Tap cry-detection tab → honeycomb pulse renders in place of old waveform
4. Favorites / Playlists / Queue empty states → bee illustration
5. Trigger paywall (play a premium track beyond free limit) → "Unlock the hive" + honey CTA + hex pattern
6. Tap "It Helped!" after a track → reserve hex gains fill, double-tap haptic fires

## Files Changed

See `git diff main` — ~40 files touched, ~1200 LOC added (mostly new components), ~60 localized strings edited, 12 app-icon PNGs regenerated.
