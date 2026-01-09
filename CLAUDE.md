<!-- SW:META template="claude" version="1.0.110" sections="header,start,autodetect,metarule,rules,workflow,reflect,context,lsp,structure,taskformat,secrets,syncing,mapping,testing,api,limits,troubleshooting,principles,linking,mcp,autoexecute,auto,docs" -->

<!-- SW:SECTION:header version="1.0.110" -->
**Framework**: SpecWeave | **Truth**: `spec.md` + `tasks.md`
<!-- SW:END:header -->

<!-- SW:SECTION:start version="1.0.110" -->
## Getting Started

**Initial increment**: `0001-project-setup` (auto-created by `specweave init`)

**Options**:
1. **Start fresh**: `rm -rf .specweave/increments/0001-project-setup` → `/sw:increment "your-feature"`
2. **Customize**: Edit spec.md and use for setup tasks
<!-- SW:END:start -->

<!-- SW:SECTION:autodetect version="1.0.110" -->
## Auto-Detection

SpecWeave auto-detects product descriptions and routes to `/sw:increment`:

**Signals** (5+ = auto-route): Project name | Features list (3+) | Tech stack | Timeline/MVP | Problem statement | Business model

**Opt-out phrases**: "Just brainstorm first" | "Don't plan yet" | "Quick discussion" | "Let's explore ideas"
<!-- SW:END:autodetect -->

<!-- SW:SECTION:metarule version="1.0.110" -->
## Meta-Rule: Think-Before-Act

**Satisfy dependencies BEFORE dependent operations.**

```
❌ node script.js → Error → npm run build
✅ npm run build → node script.js → Success
```
<!-- SW:END:metarule -->

<!-- SW:SECTION:rules version="1.0.110" -->
## Rules

1. **Files** → `.specweave/increments/####-name/` (spec.md, plan.md, tasks.md at root; reports/, scripts/, logs/ subfolders)
2. **Update immediately**: `Edit("tasks.md", "[ ] pending", "[x] completed")` + `Edit("spec.md", "[ ] AC-", "[x] AC-")`
3. **Unique IDs**: Check `ls .specweave/increments/ | grep "^[0-9]" | tail -5`
4. **Emergency**: "emergency mode" → 1 edit, 50 lines max, no agents
5. **Root clean**: NEVER create .md/reports/scripts in project root → use increment folders
6. **⛔ Increment cleanliness**: ONLY 4 files at increment root (metadata.json, spec.md, plan.md, tasks.md). ALL other .md files → `reports/`, logs → `logs/`, scripts → `scripts/`
7. **⛔ Initialization guard**: `.specweave/` folders MUST ONLY exist where `specweave init` was run. NEVER create `.specweave/` in parent, nested, or unrelated directories. Check `config.json` exists before creating ANY `.specweave/` subfolders.
8. **⛔ Marketplace refresh**: ALWAYS use `specweave refresh-marketplace` CLI command. NEVER suggest `scripts/refresh-marketplace.sh` - end users don't have the scripts folder (npm global install).
<!-- SW:END:rules -->

<!-- SW:SECTION:workflow version="1.0.110" -->
## Workflow

`/sw:increment "X"` → `/sw:do` → `/sw:progress` → `/sw:done 0001`

| Cmd | Action |
|-----|--------|
| `/sw:increment` | Plan feature |
| `/sw:do` | Execute tasks |
| `/sw:auto` | Autonomous execution |
| `/sw:auto-status` | Check auto session |
| `/sw:cancel-auto` | ⚠️ EMERGENCY ONLY manual cancel |
| `/sw:validate` | Quality check |
| `/sw:done` | Close |
| `/sw-github:sync` | GitHub sync |
| `/sw-jira:sync` | Jira sync |

**Natural language**: "Let's build X" → `/sw:increment` | "What's status?" → `/sw:progress` | "We're done" → `/sw:done` | "Ship while sleeping" → `/sw:auto`
<!-- SW:END:workflow -->

<!-- SW:SECTION:reflect version="1.0.110" -->
## Self-Improving Skills (Reflect)

**Learn once, never repeat.** Claude learns from corrections and patterns across sessions.

| Cmd | Action |
|-----|--------|
| `/sw:reflect` | Analyze session, extract learnings |
| `/sw:reflect-on` | Enable auto-reflection on session end |
| `/sw:reflect-off` | Disable auto-reflection |
| `/sw:reflect-status` | Show memory status |

**How it works**:
1. User corrects Claude → Reflect captures learning
2. Learning saved to centralized memory files (by category)
3. Future sessions apply learned patterns automatically

**CRITICAL - Memory Loading**: Before starting work, **check centralized memory** for learned patterns:
```bash
# Check if memory exists and read relevant categories
ls .specweave/memory/*.md 2>/dev/null && cat .specweave/memory/*.md
# Also check global memory
ls ~/.specweave/memory/*.md 2>/dev/null
```

**Centralized Memory Files** (no skill copies needed!):
```
.specweave/memory/                  # Project learnings
├── component-usage.md              # UI patterns
├── api-patterns.md                 # API patterns
├── testing.md                      # Test patterns
├── deployment.md                   # Deploy patterns
└── general.md                      # Misc patterns

~/.specweave/memory/                # Global learnings (all projects)
```

**Signals detected**:
- **Corrections** (high confidence): "No, use X instead", "Wrong, always do Y"
- **Approvals** (medium confidence): "Perfect!", "That's exactly right"

**Enable auto-learning**: `/sw:reflect-on` → Stop hook analyzes sessions automatically
<!-- SW:END:reflect -->

<!-- SW:SECTION:context version="1.0.110" -->
## Living Docs Context

**Before implementing features**: Check existing docs for patterns and decisions.

```bash
# Search for related docs
grep -ril "keyword" .specweave/docs/internal/

# Key locations
.specweave/docs/internal/specs/       # Feature specifications
.specweave/docs/internal/architecture/adr/  # Architecture decisions (ADRs)
.specweave/docs/internal/architecture/      # System design
```

**Always check ADRs** before making design decisions to avoid contradicting past choices.

**Use `/sw:context <topic>`** to load relevant living docs into conversation.
<!-- SW:END:context -->

<!-- SW:SECTION:lsp version="1.0.110" -->
## LSP-Enhanced Exploration

**USE LSP ACTIVELY** for semantic code understanding (100x faster than grep).

**Key operations**: `findReferences` (before refactoring) | `goToDefinition` (navigate) | `documentSymbol` (structure) | `hover` (types) | `getDiagnostics` (errors)

**Install**:
```bash
npm install -g typescript-language-server typescript  # TS/JS
pip install python-lsp-server  # Python
go install golang.org/x/tools/gopls@latest  # Go
```

**Best Practices**: ALWAYS use `findReferences` before refactoring | Use `goToDefinition` instead of grep | Combine with Explore agent
<!-- SW:END:lsp -->

<!-- SW:SECTION:structure version="1.0.110" -->
## Structure

```
.specweave/
├── increments/####-name/     # metadata.json, spec.md, tasks.md
├── docs/internal/specs/      # Living docs (check before implementing!)
│   └── architecture/adr/     # ADRs (check before design decisions!)
└── config.json
```

### ⛔ INCREMENT FOLDER ORGANIZATION (CRITICAL!)

**Increment folders MUST stay clean. NEVER pollute them with random files!**

**ONLY these 4 files at increment root**:
- `metadata.json` (required)
- `spec.md` (required)
- `plan.md` (optional)
- `tasks.md` (required)

**EVERYTHING ELSE → subfolders**:
| File Type | Destination Folder |
|-----------|-------------------|
| Reports, analysis, summaries (*.md) | `reports/` |
| Validation reports, QA reports | `reports/` |
| Session reports, completion reports | `reports/` |
| Logs, execution output | `logs/{YYYY-MM-DD}/` |
| Helper scripts, automation | `scripts/` |
| Domain-specific docs | `docs/domain/` |
| Backup files | `backups/` |

**Examples**:
```bash
# ✅ CORRECT
.specweave/increments/0021-feature/
├── metadata.json
├── spec.md
├── tasks.md
├── reports/
│   ├── validation-report.md
│   ├── completion-report.md
│   └── auto-session-summary.md
└── logs/
    └── 2026-01-04/
        └── execution.log

# ❌ WRONG - polluted increment folder!
.specweave/increments/0021-feature/
├── metadata.json
├── spec.md
├── tasks.md
├── completion-report.md      # WRONG! → reports/
├── auto-session-summary.md   # WRONG! → reports/
└── analysis.md               # WRONG! → reports/
```

**Multi-repo projects**: Create in `repositories/` folder (NEVER project root!)
```
my-project/
├── repositories/     # All repos here: frontend/, backend/, shared/
└── .specweave/
```

**Permissions** (`.claude/settings.json`):
```json
{"permissions":{"allow":["Write(//**)","Edit(//**)"],"additionalDirectories":["repositories"]}}
```
<!-- SW:END:structure -->

<!-- SW:SECTION:taskformat version="1.0.110" -->
## Task Format

```markdown
### T-001: Title
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given [X] → When [Y] → Then [Z]
```
<!-- SW:END:taskformat -->

<!-- SW:SECTION:secrets version="1.0.110" -->
## Secrets Check

**BEFORE CLI tools**: Check existing config first!
```bash
grep -E "(GITHUB_TOKEN|JIRA_|ADO_)" .env 2>/dev/null
cat .specweave/config.json | grep -A5 '"sync"'
gh auth status
```
<!-- SW:END:secrets -->

<!-- SW:SECTION:syncing version="1.0.110" -->
## External Sync (GitHub/JIRA/ADO)

**After increment creation**: Run `/sw-github:sync {id}` to create issues!

Living docs sync ≠ External sync. They are separate:
1. `/sw:sync-specs` → Living docs only
2. `/sw-github:sync` → GitHub issues (MUST run explicitly!)

**Required config** (`.specweave/config.json`):
```json
"sync": {
  "settings": {
    "canUpsertInternalItems": true,
    "canUpdateExternalItems": true,
    "autoSyncOnCompletion": true
  },
  "github": {
    "enabled": true,
    "owner": "your-org",
    "repo": "your-repo"
  }
}
```

**Verify tokens**: `grep GITHUB_TOKEN .env` | `gh auth status`
<!-- SW:END:syncing -->

<!-- SW:SECTION:mapping version="1.0.110" -->
## GitHub Mapping

| SpecWeave | GitHub |
|-----------|--------|
| Feature FS-XXX | Milestone |
| Story US-XXX | Issue `[FS-XXX][US-YYY] Title` |
| Task T-XXX | Checkbox |
<!-- SW:END:mapping -->

<!-- SW:SECTION:testing version="1.0.110" -->
## Testing

BDD in tasks.md | Unit >80% | `.test.ts` (Vitest)

```typescript
// Vitest pattern: vi.fn() not jest.fn(), import not require
import { vi } from 'vitest';
vi.mock('fs', () => ({ readFile: vi.fn() }));
```
<!-- SW:END:testing -->

## Emergency System Architecture

**Canonical System**: SmartQueue (SmartEmergencyQueue + SmartQueueView)

The emergency cry response uses a single system:
- `SmartEmergencyQueue.swift` - AI-powered queue management
- `SmartQueueView.swift` - Spotify-like queue UI

Legacy files (EmergencyQueueManager, EmergencyQueueView) are deprecated.
See ADR-0126 for details.

## Voice Control (DEPRECATED)

**Status**: Custom voice control is DEPRECATED and does NOT work for CarPlay.

### Why Current Implementation Doesn't Work

The custom voice control system (SpeechRecognitionService + VoiceCommandLLMService) has fundamental limitations:

1. **CarPlay uses Siri** - CarPlay routes voice through Siri Intents, not custom speech recognition
2. **Microphone unavailable** - Custom SFSpeechRecognizer requires app's microphone permission, unavailable in CarPlay
3. **Foreground only** - Custom speech recognition only works when app is active in foreground

### Deprecated Files (DO NOT USE)

- `VoiceCommandLLMService.swift` - Custom command parsing (broken)
- `VoiceCommandMLService.swift` - CoreML classifier (never worked, not compiled)
- `SpeechRecognitionService.swift` - Custom speech recognition (CarPlay incompatible)

### Proper CarPlay Voice Integration (TODO)

For voice control to work in CarPlay, implement **SiriKit Media Intents**:

#### Required Implementation

1. **Add Intents Extension** to Xcode project
2. **Create Intents.intentdefinition** with supported intents
3. **Implement IntentHandler** for each intent
4. **Configure Info.plist** with supported intents

#### Supported Media Intents

| Intent | User Says | Handler |
|--------|-----------|---------|
| `INPlayMediaIntent` | "Hey Siri, play lullabies in Lulla" | Start playback |
| `INPauseMediaIntent` | "Hey Siri, pause Lulla" | Pause playback |
| `INSearchForMediaIntent` | "Hey Siri, find Mozart in Lulla" | Search tracks |
| `INAddMediaIntent` | "Hey Siri, add this to favorites" | Add to playlist |

#### Example IntentHandler

```swift
import Intents

class IntentHandler: INExtension, INPlayMediaIntentHandling {
    func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
        // Parse mediaSearch for category/mood/track
        if let mediaItems = intent.mediaItems {
            // Route to AudioEngine
        }
        return INPlayMediaIntentResponse(code: .success, userActivity: nil)
    }
}
```

#### Info.plist Configuration

```xml
<key>INIntentsSupported</key>
<array>
    <string>INPlayMediaIntent</string>
    <string>INPauseMediaIntent</string>
    <string>INSearchForMediaIntent</string>
</array>
```

### Resources

- [SiriKit Media Documentation](https://developer.apple.com/documentation/sirikit/media)
- [INPlayMediaIntent](https://developer.apple.com/documentation/sirikit/inplaymediaintent)
- [WWDC 2019: Introducing SiriKit Media Intents](https://developer.apple.com/videos/play/wwdc2019/207/)

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

<!-- SW:SECTION:api version="1.0.110" -->
## API Development (OpenAPI-First)

**For API projects only.** OpenAPI = source of truth → Postman derived from it.

**Config** (`.specweave/config.json`):
```json
{"apiDocs":{"enabled":true,"openApiPath":"openapi.yaml","generatePostman":true,"generateOn":"on-increment-done"}}
```

**Frameworks**: NestJS (`@nestjs/swagger`) | FastAPI (built-in) | Express (`swagger-jsdoc`) | Spring Boot (`springdoc-openapi`)

**Commands**: `/sw:api-docs --all` (OpenAPI + Postman) | `--openapi` | `--postman` | `--env` | `--validate`

**Flow**: Code decorators → `openapi.yaml` → `/sw:done` or `/sw:api-docs` → Postman collection + env

**Import**: Postman → Import collection + env → Fill secrets → Select env
<!-- SW:END:api -->

<!-- SW:SECTION:limits version="1.0.110" -->
## Limits

**Max 1500 lines/file** — extract before adding
<!-- SW:END:limits -->

<!-- SW:SECTION:troubleshooting version="1.0.110" -->
## Troubleshooting

| Issue | Fix |
|-------|-----|
| Skills missing | Restart Claude Code |
| Plugins outdated | `specweave refresh-marketplace` (NEVER use `scripts/refresh-marketplace.sh` - that's for contributors only!) |
| Commands gone | `/plugin list --installed` |
| Out of sync | `/sw:sync-tasks` |
| Find increment | `/sw:status` |
| Root polluted | Move files to `.specweave/increments/####/reports/` |
| Duplicate IDs | `/sw:fix-duplicates` |
| GitHub not syncing | Check `sync.github.enabled: true` AND `canUpdateExternalItems: true` in config.json |
| GitHub issues not updating | Run `/sw-github:sync {id}` explicitly; check `.specweave/logs/throttle.log` |
| Permission denied | Set `canUpsertInternalItems: true` AND `canUpdateExternalItems: true` in config.json |
| No GITHUB_TOKEN | Check `.env` file or run `gh auth login` |
| Edits blocked in repositories/ | Add `"additionalDirectories":["repositories"]` + `Write(//**)`, `Edit(//**)` to `.claude/settings.json` |
| Path patterns not working | `//path` = absolute, `/path` = relative to settings file, `additionalDirectories` for explicit working dirs |
<!-- SW:END:troubleshooting -->

<!-- SW:SECTION:principles version="1.0.110" -->
## Principles

1. **Spec-first**: `/sw:increment` before coding
2. **Docs = truth**: Specs guide implementation
3. **Incremental**: Small, validated increments
4. **Traceable**: All work → specs → ACs
5. **Clean**: All files in increment folders
<!-- SW:END:principles -->

<!-- SW:SECTION:linking version="1.0.110" -->
## Bidirectional Linking

Tasks ↔ User Stories auto-linked via AC-IDs: `AC-US1-01` → `US-001`

Task format: `**AC**: AC-US1-01, AC-US1-02` (CRITICAL for linking)
<!-- SW:END:linking -->

<!-- SW:SECTION:mcp version="1.0.110" -->
## External Service Connection

**Priority**: MCP Server → REST API → CLI → Direct Connection

**Setup**:
```bash
# MCP (restart Claude Code after)
npx @anthropic-ai/claude-code-mcp add supabase

# CLI Auth
wrangler login && vercel login && supabase login
```

**Supabase**: Use REST API or pooler (port 6543), AVOID direct `psql`
**Cloudflare**: `wrangler login` once, then `wrangler deploy/secret put/kv:key put`

**Check credentials before ops**:
```bash
grep -E "SUPABASE_|DATABASE_URL|CF_API" .env 2>/dev/null
wrangler whoami 2>/dev/null
```
<!-- SW:END:mcp -->

<!-- SW:SECTION:autoexecute version="1.0.110" -->
## Auto-Execute Rule

**NEVER** output "Manual Step Required" when credentials exist. **EXECUTE DIRECTLY.**

**Flow**: Check `.env` → If exists, EXECUTE | If missing, ASK for credentials → Save → EXECUTE

**Check before ops**:
```bash
grep -E "(SUPABASE_|DATABASE_URL|CF_API_|GITHUB_TOKEN)" .env 2>/dev/null
wrangler whoami 2>/dev/null && gh auth status 2>/dev/null
```
<!-- SW:END:autoexecute -->

<!-- SW:SECTION:auto version="1.0.110" -->
## Auto Mode (Autonomous Execution)

**Continuous execution until all tasks complete.**

### Zero Manual Steps

**NEVER ask user to**: Open dashboards | Copy/paste | Run commands manually

**Instead**: Check `.env` → Use CLI (`wrangler`, `gh`, `aws`) → Use MCP → If missing, ASK → Save → EXECUTE

### Test Loop (MANDATORY)

**After EVERY task**: `npm test` → If E2E exists: `npx playwright test` → Fail? FIX → Rerun (max 3x) → Pass → Next

**Pattern**: IMPLEMENT → TEST → FAIL? → FIX → TEST → PASS → NEXT

**MVP paths**: Auth (login/logout) | Core CRUD | Payments | Data integrity

### Pragmatic Completion

**Don't blindly follow 100%!** Specs have bugs, requirements change, some tasks become irrelevant.

**MUST**: MVP paths | Security flows | Data integrity | User-facing errors
**SHOULD**: Edge cases | Performance | Nice-to-haves
**CAN SKIP**: Conflicts (ask user) | Over-engineered cases | Obsolete tasks

**STOP & ASK** if: Spec conflicts | Task seems unnecessary | Requirement ambiguous

### Test User Strategy

**Multiple users**: RBAC | Subscription tiers | User states | Multi-user interactions
**One user**: CRUD | Form validation | Component tests | Mocked auth

**E2E**: Seed DB with known users → Use fixtures → `storageState` (auth once, reuse)

### E2E Authentication

**Auth = #1 flaky test cause.** Use `storageState` (login ONCE, reuse) | API auth (UI unstable) | UI login (only for login tests)

**Setup**: Global auth.setup.ts → Save to `playwright/.auth/user.json` → Reuse in config

**Fixes**: Session expires? Increase TTL | Rate limited? API auth | Captcha? Disable in test env

**Checklist**: Seed users | Gen auth state | Tests DON'T login | Disable captcha/2FA

### Refactoring & Reporting

**Every 3-5 tasks**: Extract fixtures | Remove duplication | Split if >300 lines | Clean imports

**Triggers**: Test >200 lines? Split | Duplicate setup? Extract | Same assertion 3x? Helper

**Report after EVERY task**: Pass/Total | Coverage | Failing tests | Next steps

### Local-First & Infrastructure

**No deploy instructions?** Build locally → Test all → Verify → ASK user about deploy target

**Infra Decision Tree**:
- **Cron**: <1/hr → Vercel/GitHub Actions | ≥1/hr → Railway/Render
- **Storage**: KV → Upstash/Vercel KV | SQL → Supabase/Neon | Docs → MongoDB | Files → R2/S3

**Process**: Ultrathink options → Research costs → Propose 2-3 → Build local → User confirms → Deploy

### Implementation

**Claude Code**: `/sw:auto` (autonomous mode) | `/sw:auto-status` (progress)

**To pause**: Just close Claude Code session, resume with `/sw:do`

**Emergency cancel**: `/sw:cancel-auto` (rarely needed - prefer closing session)

**Other AI**: Loop check tasks.md `[x]` status → Max 100 iter → Human gates for: publish, force-push, prod deploy, migrations

**Circuit Breaker**: External API fails 3x? Queue & continue
<!-- SW:END:auto -->

<!-- SW:SECTION:docs version="1.0.110" -->
## Docs

[spec-weave.com](https://spec-weave.com) | `.specweave/docs/internal/`
<!-- SW:END:docs -->
