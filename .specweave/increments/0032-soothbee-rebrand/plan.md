# Plan — Soothbee Rebrand

## Architecture Summary

**In-place rebrand**: bundle ID + App Store ID preserved. Single-file design token changes cascade via SwiftUI's static-property color pattern. New components are additive; existing views only modified for integration.

## Key Decisions

- **ADR-ref**: Colors remain hex-literal in `Extensions/Colors.swift` — don't migrate to asset catalog ColorSets mid-rebrand. Reason: 273 call sites work today; asset migration is a separate refactor.
- **Icon strategy**: Swift/CoreGraphics placeholder generator committed to repo. Same filename (`icon_1024.png`) means a later designer PNG drop doesn't touch code.
- **No GENERATE_INFOPLIST_FILE migration**: main app keeps `NO` (authoritative Info.plist). Watch + Intents keep `YES` (pbxproj drives it). Don't flip either flag — blast radius too high.
- **Honeycomb pulse uses SwiftUI `Path` + `TimelineView`**, not Canvas — easier previewing and test access.
- **Empty states use SF Symbols composites**, not raster assets — stays within 50MB app-size budget.

## Component Inventory

**New:**
- `HoneycombPulseView` — 7-cell hex grid with confidence-driven ring activation
- `BeeEmptyState` — hex + wing + mood overlay, drives 3 empty screens
- `HoneyDropAnimation` + `HiveReserveIndicator` — feedback micro-interaction + persistent honey counter
- `HexBulletList` — helper for paywall bullets (SF Symbol `hexagon.fill` + text)
- `HoneycombPattern` — canvas-drawn background pattern for paywall

**Modified:**
- `Colors.swift` — hex remap + 2 new tokens
- `Info.plist` × 2 (main, Watch) — display name + usage descriptions
- `project.pbxproj` — 4 INFOPLIST_KEY lines
- `LaunchScreen.storyboard` — label text + tagline
- `Localizable.xcstrings` — 4+ keys × 10 languages + privacy/TOS strings
- `LullaShortcuts.swift` → `SoothbeeShortcuts.swift` (git mv + class rename)
- `AccentColor.colorset/Contents.json` — fallback color update
- Existing cry-detection view — integrate `HoneycombPulseView`
- Existing paywall view — copy + visual pass
- 3 existing empty states — swap to `BeeEmptyState`

**Infra:**
- `scripts/generate-placeholder-icon.swift` — CoreGraphics icon renderer
- `scripts/build-and-run-simulator.sh` — one-command local launcher
- New unit/snapshot tests + `maestro/flows/rebrand_smoke.yaml`

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `actool` hangs on icon change | Script prints reboot hint; known mitigation documented in CLAUDE.md memory |
| Paywall/cry-detection view paths TBD | Phase 2.2 and 3.2 begin with a focused Grep/Glob before editing |
| Maestro onboarding test asserts "Lulla" text | Updated in same increment |
| Snapshot tests fail (expected) | None exist currently (verified in exploration) |
| 10-language translation quality for new tagline | Use Latin "Soothbee" everywhere except Arabic; tagline uses DeepL-style direct translations with clear English fallback — acceptable for v1.2.0 |
