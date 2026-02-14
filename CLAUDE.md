<!-- SW:META template="claude" version="1.0.259" sections="header,lsp,start,autodetect,metarule,rules,workflow,reflect,context,structure,taskformat,secrets,syncing,testing,tdd,api,limits,troubleshooting,lazyloading,principles,linking,mcp,auto,docs" -->

<!-- SW:SECTION:header version="1.0.259" -->
**Framework**: SpecWeave | **Truth**: `spec.md` + `tasks.md`
<!-- SW:END:header -->

<!-- SW:SECTION:lsp version="1.0.259" -->
## LSP (Code Intelligence)

**Native LSP broken in v2.1.0+.** Use: `specweave lsp refs|def|hover src/file.ts SymbolName`
<!-- SW:END:lsp -->

<!-- SW:SECTION:start version="1.0.259" -->
## Getting Started

**Initial increment**: `0001-project-setup` (auto-created by `specweave init`)

**Options**:
1. **Start fresh**: `rm -rf .specweave/increments/0001-project-setup` → `/sw:increment "your-feature"`
2. **Customize**: Edit spec.md and use for setup tasks
<!-- SW:END:start -->

<!-- SW:SECTION:autodetect version="1.0.259" -->
## Auto-Detection

SpecWeave auto-detects product descriptions and routes to `/sw:increment`:

**Signals** (5+ = auto-route): Project name | Features list (3+) | Tech stack | Timeline/MVP | Problem statement | Business model

**Opt-out phrases**: "Just brainstorm first" | "Don't plan yet" | "Quick discussion" | "Let's explore ideas"
<!-- SW:END:autodetect -->

<!-- SW:SECTION:metarule version="1.0.259" -->
## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, **STOP and re-plan** - don't keep pushing
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context clean
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent for focused execution
- Append "use subagents" to requests for safe parallelization

### 3. Verification Before Done
- Never mark a task complete without proving it works
- Ask yourself: **"Would a staff engineer approve this?"**
- Run tests, check logs, demonstrate correctness

### 4. Think-Before-Act (Dependencies)
**Satisfy dependencies BEFORE dependent operations.**
```
Bad:  node script.js → Error → npm run build
Good: npm run build → node script.js → Success
```
<!-- SW:END:metarule -->

<!-- SW:SECTION:rules version="1.0.259" -->
## Rules

1. **Files** → `.specweave/increments/####-name/` (see Structure section for details)
2. **Update immediately**: `Edit("tasks.md", "[ ] pending", "[x] completed")` + `Edit("spec.md", "[ ] AC-", "[x] AC-")`
3. **Unique IDs**: Check ALL folders (active, archive, abandoned):
   ```bash
   find .specweave/increments -maxdepth 2 -type d -name "[0-9]*" | grep -oE '[0-9]{4}E?' | sort -u | tail -5
   ```
4. **Emergency**: "emergency mode" → 1 edit, 50 lines max, no agents
5. **Initialization guard**: `.specweave/` folders MUST ONLY exist where `specweave init` was run
6. **Marketplace refresh**: Use `specweave refresh-marketplace` CLI (not `scripts/refresh-marketplace.sh`)
7. **Numbered folder collisions**: Before creating `docs/NN-*` folders, CHECK existing prefixes
8. **Multi-repo**: ALL repos MUST be at `repositories/{org}/{repo-name}/` — NEVER directly under `repositories/`
<!-- SW:END:rules -->

<!-- SW:SECTION:workflow version="1.0.259" -->
## Workflow

`/sw:increment "X"` → `/sw:do` → `/sw:progress` → `/sw:done 0001`

| Cmd | Action |
|-----|--------|
| `/sw:increment` | Plan feature |
| `/sw:do` | Execute tasks |
| `/sw:auto` | Autonomous execution |
| `/sw:auto-status` | Check auto session |
| `/sw:cancel-auto` | EMERGENCY ONLY manual cancel |
| `/sw:validate` | Quality check |
| `/sw:done` | Close |
| `/sw:progress-sync` | Sync progress to all external tools |
| `/sw-github:push` | Push progress to GitHub |

**Natural language**: "Let's build X" → `/sw:increment` | "What's status?" → `/sw:progress` | "We're done" → `/sw:done` | "Ship while sleeping" → `/sw:auto`
<!-- SW:END:workflow -->

<!-- SW:SECTION:reflect version="1.0.259" -->
## Skill Memories

SpecWeave learns from corrections. Learnings saved here automatically. Edit or delete as needed.

**Disable**: Set `"reflect": { "enabled": false }` in `.specweave/config.json`
<!-- SW:END:reflect -->

<!-- SW:SECTION:context version="1.0.259" -->
## Context

**Before implementing**: Check ADRs at `.specweave/docs/internal/architecture/adr/`

**Load context**: `/sw:docs <topic>` loads relevant living docs into conversation
<!-- SW:END:context -->

<!-- SW:SECTION:structure version="1.0.259" -->
## Structure

```
.specweave/
├── increments/####-name/     # metadata.json, spec.md, plan.md, tasks.md
├── docs/internal/specs/      # Living docs
└── config.json
```

**Increment root**: ONLY `metadata.json`, `spec.md`, `plan.md`, `tasks.md`

**Everything else → subfolders**: `reports/` | `logs/` | `scripts/` | `backups/`
<!-- SW:END:structure -->

<!-- SW:SECTION:taskformat version="1.0.259" -->
## Task Format

```markdown
### T-001: Title
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given [X] → When [Y] → Then [Z]
```
<!-- SW:END:taskformat -->

<!-- SW:SECTION:secrets version="1.0.259" -->
## Secrets

Before CLI tools, check existing config (`grep -q` only — never display values).
<!-- SW:END:secrets -->

<!-- SW:SECTION:syncing version="1.0.259" -->
## External Sync

Primary: `/sw:progress-sync`. Individual: `/sw-github:push`, `/sw-github:close`. Mapping: Feature→Milestone | Story→Issue | Task→Checkbox.
<!-- SW:END:syncing -->

<!-- SW:SECTION:testing version="1.0.259" -->
## Testing

BDD in tasks.md | Unit >80% | `.test.ts` (Vitest) | ESM mocking: `vi.hoisted()` + `vi.mock()`
<!-- SW:END:testing -->

## Emergency System Architecture

**Canonical System**: SmartQueue (SmartEmergencyQueue + SmartQueueView)

The emergency cry response uses a single system:
- `SmartEmergencyQueue.swift` - AI-powered queue management
- `SmartQueueView.swift` - Spotify-like queue UI

Legacy files (EmergencyQueueManager, EmergencyQueueView) are deprecated.
See ADR-0126 for details.

## iOS Testing (BabyInCarApp)

This project uses a comprehensive iOS testing stack optimized for SwiftUI apps.

### Testing Stack Overview

| Layer | Tool | Purpose |
|-------|------|---------|
| **Unit Tests** | Swift Testing + XCTest | Service/Model logic testing |
| **Snapshot Tests** | swift-snapshot-testing | UI visual regression testing |
| **Performance Tests** | XCTest Metrics | Audio/ML latency benchmarks |
| **E2E Tests** | Maestro | Full user journey testing |

### Running Tests

```bash
# Unit Tests (Xcode)
xcodebuild test \
  -project BabyInCarApp/BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# E2E Tests (Maestro - install first)
curl -fsSL "https://get.maestro.mobile.dev" | bash
~/.maestro/bin/maestro test maestro/flows/

# Run specific E2E flow
~/.maestro/bin/maestro test maestro/flows/cry_detection_flow.yaml

# Record E2E flow (for debugging)
~/.maestro/bin/maestro record maestro/flows/onboarding_flow.yaml
```

### Test Directory Structure

```
BabyInCarApp/BabyInCarAppTests/
├── AudioEngineTests.swift      # Existing shuffle/repeat tests
├── PlayerViewTests.swift       # Player UI logic tests
├── Fixtures/                   # Test audio files (.gitkeep placeholder)
├── Mocks/
│   └── MockCryDetectionService.swift  # Mock service with test helpers
├── Performance/
│   └── PerformanceTests.swift  # FFT, ML inference benchmarks
├── Services/
│   └── CryDetectionServiceTests.swift  # Cry detection unit tests
└── Snapshots/
    └── ViewSnapshotTests.swift # UI snapshot tests

maestro/flows/
├── onboarding_flow.yaml        # New user onboarding E2E
├── playback_flow.yaml          # Audio playback E2E
├── cry_detection_flow.yaml     # Cry monitoring E2E
├── library_navigation_flow.yaml # Library browsing E2E
└── playlist_flow.yaml          # Playlist management E2E
```

### Writing New Tests

**Swift Testing (Modern - Preferred)**
```swift
import Testing
@testable import BabyInCarApp

@Suite("Cry Detection")
@MainActor
struct CryDetectionTests {
    @Test("Detects hunger cry correctly")
    func detectsHungerCry() async {
        let mock = MockCryDetectionService()
        mock.simulateCryDetection(type: .hunger, confidence: 0.9)
        #expect(mock.cryType == .hunger)
    }
}
```

**XCTest (For Performance/UI)**
```swift
func testMLInferencePerformance() throws {
    measure(metrics: [XCTClockMetric()]) {
        _ = detector.detect(features: features)
    }
}
```

**Maestro E2E**
```yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- assertVisible: "Listening..."
- takeScreenshot: "cry_detection_active"
```

### Mock Service Usage

```swift
// Create mock in specific state
let detected = MockCryDetectionService.detected(type: .tired, confidence: 0.85)
let monitoring = MockCryDetectionService.monitoring()
let idle = MockCryDetectionService.idle()

// Simulate events
mock.simulateCryDetection(type: .pain, confidence: 0.95)
mock.simulateCryEnded()

// Verify calls
#expect(mock.startMonitoringCallCount == 1)
```

### Performance Baselines

| Operation | Max Time | Why |
|-----------|----------|-----|
| FFT Processing | < 20ms | Real-time audio buffer |
| ML Inference | < 50ms | Detection latency |
| Full Pipeline | < 100ms | End-to-end response |

### Adding Accessibility Identifiers (for UI/E2E Tests)

```swift
Button("Play") { }
    .accessibilityIdentifier("playButton")

Toggle("Enable Monitoring", isOn: $isMonitoring)
    .accessibilityIdentifier("cryMonitoringToggle")
```

### Test Coverage Targets

| Area | Target | Current |
|------|--------|---------|
| CryDetectionService | 80% | ~30% |
| AudioEngine | 80% | ~40% |
| ML Models | 70% | ~20% |
| Views (Snapshots) | 60% | ~10% |
| E2E Critical Paths | 100% | 5 flows |

## Audio Content Guidelines (CRITICAL)

**App Size Optimization**: Target app size < 50MB. All audio content streams from Cloudflare R2.

### Emergency Mode Audio (ZERO LATENCY)
Emergency mode uses **GENERATED audio** (not bundled files) for instant, reliable playback:
- `AudioTrack.defaultEmergencyTrack()` → Generated lullaby melody
- `AudioTrack.alternativeEmergencyTrack()` → Generated music box
- **Why generated?** Zero file loading, zero network latency, works offline

### Streaming-First Architecture
All library audio content is streamed from R2:
```
┌─────────────────────────────────────────────────────────────┐
│  App Bundle (< 50MB)                                        │
│  └── NO bundled audio files (all generated or streamed)     │
├─────────────────────────────────────────────────────────────┤
│  Generated Audio (instant, offline)                         │
│  └── Lullaby, Music Box, Ocean, Heartbeat, etc.            │
├─────────────────────────────────────────────────────────────┤
│  Cloudflare R2 (all audio content)                          │
│  └── Progressive streaming via CDN                          │
├─────────────────────────────────────────────────────────────┤
│  Local Cache (~500MB max)                                   │
│  └── Downloaded favorites + emergency playlist              │
└─────────────────────────────────────────────────────────────┘
```

### Audio Session Configuration (CRITICAL)

**Exclusive Playback ONLY** - The app MUST pause other audio apps (Spotify, YouTube, Apple Music, etc.)

#### Implementation Rules

1. **ALWAYS use `.playback` category with empty options `[]`**
   ```swift
   try session.setCategory(.playback, mode: .default, options: [])
   ```

2. **NEVER use `.mixWithOthers` option** (would allow simultaneous playback)
   - ❌ WRONG: `options: [.mixWithOthers]` - allows mixing with Spotify
   - ✅ CORRECT: `options: []` - pauses Spotify completely

3. **NEVER use `.duckOthers` option** (deprecated, not needed)
   - Ducking reduces other app volume to ~20%
   - We want COMPLETE pause, not volume reduction
   - ❌ WRONG: `options: [.duckOthers]`
   - ✅ CORRECT: `options: []`

4. **playAndRecord mode** (for cry detection while playing)
   ```swift
   try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
   ```
   - Use `.defaultToSpeaker` to route audio to speaker (not earpiece)
   - NO `.mixWithOthers` - still pauses other apps

#### Bluetooth/AirPods Configuration

**NEVER use `.allowBluetooth` option** - it degrades audio quality:
- ❌ WRONG: `options: [.allowBluetooth]` - forces HFP (mono, phone quality)
- ✅ CORRECT: `options: []` - uses A2DP (stereo, music quality)

iOS automatically routes to Bluetooth A2DP when using `.playback` category.

#### Why Exclusive Playback?

1. **Baby safety** - Soothing sounds must be heard clearly without competing audio
2. **Parent expectation** - Like Spotify/Apple Music (stops other apps when playing)
3. **CarPlay UX** - Standard behavior for media apps in cars

#### AudioSessionManager Modes

| Mode | Category | Options | Use Case |
|------|----------|---------|----------|
| `playbackOnly` | `.playback` | `[]` | Normal music playback (pauses Spotify) |
| `emergencyPlayback` | `.playback` | `[]` | Cry response (pauses Spotify) |
| `playAndRecord` | `.playAndRecord` | `[.defaultToSpeaker]` | Cry monitoring + playback (pauses Spotify) |
| `recordOnly` | `.record` | `[]` | Voice commands (pauses Spotify) |
| `inactive` | `.ambient` | `[]` | No audio activity |

All modes use **exclusive playback** - no `.mixWithOthers`, no `.duckOthers`.

### FORBIDDEN Audio Types (NEVER download or generate)

**CLEANED: 35 forbidden tracks removed from tracks.json (2026-01-04)**
**GENERATED SOUNDS CLEANED: 8 noisy nature sounds removed (2026-01-09)**

| Type | Examples | Reason | Removed |
|------|----------|--------|---------|
| **Weather Sounds** | Rain, thunder, storm, wind | Too noisy, scary for babies | 14 tracks |
| **Mechanical/Harsh Sounds** | Vacuum cleaner, hair dryer, washing machine, car engine, fan | Too harsh for baby calming | 15 tracks |
| **Travel/City Sounds** | Train, airplane cabin, city ambience | Stimulating, not soothing | 0 tracks |
| **Synthetic Noise** | White noise, pink noise, brown noise (all whitenoise category) | User feedback: SCARY for babies | 13 tracks |
| **Other Loud Sounds** | Fanfare, loud music | Too stimulating | 3 tracks |
| **Generated Nature Sounds** | Ocean waves, forest, river, birds, crickets, fireplace, waterfall, campfire | **NEW 2026-01-09**: Unpredictable volume variations startle babies! | 8 generators |

### ALLOWED Audio Types (270 tracks remaining in tracks.json)

| Category | Count | Examples | Source |
|----------|-------|----------|--------|
| **Classical Music** | 117 | Mozart, Bach, Brahms, Chopin | Stream from R2 |
| **Fairy Tales (EN)** | 86 | English stories | Stream from R2 |
| **Fairy Tales (RU)** | 85 | Russian folk tales | Stream from R2 |
| **Lullabies** | 51 | Brahms Lullaby, real recordings | Stream from R2 |
| **Ambient** | 22 | Gentle background music | Stream from R2 |
| **Children's Songs** | 20 | Age-appropriate gentle songs | Stream from R2 |
| **Modern Piano** | 6 | Soft piano melodies | Stream from R2 |

### Generated Sounds (OK - Internal Audio Engine)
Only gentle, predictable musical sounds remain:
- **Baby-specific**: Womb sounds, Heartbeat, Gentle shushing, Aquarium bubbles
- **Musical tones**: Lullaby melody, Music box, Wind chimes, Soft bells, Soft piano, Gentle guitar

**REMOVED** (2026-01-09 - too noisy, unpredictable):
- ❌ Ocean waves, River stream, Birds chirping, Crickets
- ❌ Forest ambience, Waterfall, Campfire, Fireplace

### Content Addition Checklist
Before adding any new audio content:
1. ✅ Is it soothing for babies? (no harsh/mechanical sounds)
2. ✅ Does it stream from R2? (not bundled in app)
3. ✅ Is metadata in tracks.json? (with streamURL)
4. ✅ Is file size reasonable? (prefer < 10MB per track)
5. ❌ NEVER bundle large audio files in the app

<!-- SW:SECTION:tdd version="1.0.259" -->
## TDD

When `testing.defaultTestMode: "TDD"` in config.json: RED→GREEN→REFACTOR. Use `/sw:tdd-cycle`. Enforcement via `testing.tddEnforcement` (strict|warn|off).
<!-- SW:END:tdd -->

<!-- SW:SECTION:api version="1.0.259" -->
<!-- API: Enable `apiDocs` in config.json. Commands: /sw:api-docs -->
<!-- SW:END:api -->

<!-- SW:SECTION:limits version="1.0.259" -->
## Limits

**Max 1500 lines/file** — extract before adding
<!-- SW:END:limits -->

<!-- SW:SECTION:troubleshooting version="1.0.259" -->
## Troubleshooting

| Issue | Fix |
|-------|-----|
| Skills missing | Restart Claude Code |
| Plugins outdated | `specweave refresh-marketplace` |
| Out of sync | `/sw:sync-tasks` |
| Session stuck | `rm -f .specweave/state/*.lock` + restart |
<!-- SW:END:troubleshooting -->

<!-- SW:SECTION:lazyloading version="1.0.259" -->
## Plugin Auto-Loading

Plugins load automatically. Manual: `claude plugin install sw-frontend@specweave`. Disable: `export SPECWEAVE_DISABLE_AUTO_LOAD=1`
<!-- SW:END:lazyloading -->

<!-- SW:SECTION:principles version="1.0.259" -->
## Principles

1. **Spec-first**: `/sw:increment` before coding
2. **Docs = truth**: Specs guide implementation
3. **Simplicity First**: Minimal code, minimal impact
4. **No Laziness**: Root causes, senior standards
<!-- SW:END:principles -->

<!-- SW:SECTION:linking version="1.0.259" -->
## Bidirectional Linking

Tasks ↔ User Stories auto-linked via AC-IDs: `AC-US1-01` → `US-001`

Task format: `**AC**: AC-US1-01, AC-US1-02` (CRITICAL for linking)
<!-- SW:END:linking -->

<!-- SW:SECTION:mcp version="1.0.259" -->
## External Services

CLI tools first (`gh`, `wrangler`, `supabase`) → MCP for complex integrations.
<!-- SW:END:mcp -->

<!-- SW:SECTION:auto version="1.0.259" -->
## Auto Mode

`/sw:auto` (start) | `/sw:auto-status` (check) | `/sw:cancel-auto` (emergency)

Pattern: IMPLEMENT → TEST → FAIL? → FIX → PASS → NEXT. STOP & ASK if spec conflicts or ambiguity.
<!-- SW:END:auto -->

<!-- SW:SECTION:docs version="1.0.259" -->
## Docs

[spec-weave.com](https://spec-weave.com)
<!-- SW:END:docs -->
