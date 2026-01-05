# Implementation Plan: FS-017 Smart Emergency Playlist System

## Technical Architecture

### 1. Database Layer (Cloudflare Workers + D1)

**Migration 013**: Emergency Playlist Metadata Schema
- **cry_scenario_playlists**: Pre-configured playlists per cry type
- **track_metadata**: Rich metadata for AI selection (cry_suitability, acoustic_features)
- **playlist_effectiveness**: Per-baby learning data
- **user_language_preferences**: Multi-language support (en, ru)
- **emergency_session_queue**: Current playback state

**API Endpoints** (babyincar-api):
```typescript
GET  /api/playlists/emergency/:cryType?language=en,ru&age=6
POST /api/emergency/session/start
POST /api/emergency/session/end
GET  /api/emergency/queue/:sessionId
POST /api/effectiveness/record
GET  /api/preferences/language/:userId
PUT  /api/preferences/language/:userId
```

### 2. Swift Service Layer

**PlaylistSelector.swift** - AI-driven playlist selection
```swift
class PlaylistSelector {
    func selectOptimalPlaylist(
        cryType: CryType,
        babyAge: Int,
        languages: [String],
        babyId: String
    ) async -> [CryScenarioPlaylist]

    private func filterByMetadata(...)
    private func rankByEffectiveness(...)
    private func applyLearning(...)
}
```

**EmergencyQueueManager.swift** - Queue state management
```swift
class EmergencyQueueManager: ObservableObject {
    @Published var currentTrack: AudioTrack?
    @Published var upcomingTracks: [AudioTrack] = []
    @Published var sessionId: String?

    func startSession(playlist: CryScenarioPlaylist)
    func advanceToNextTrack()
    func endSession(effective: Bool)
}
```

**EffectivenessTracker.swift** - Learning system
```swift
class EffectivenessTracker {
    func recordSessionStart(babyId: String, playlistId: String)
    func recordSessionEnd(calming_time: TimeInterval, effective: Bool)
    func updateConfidenceScore(playlistId: String)
}
```

### 3. Swift Models

**CryScenarioPlaylist.swift**
```swift
struct CryScenarioPlaylist: Codable, Identifiable {
    let id: String
    let cryType: CryType
    let name: String
    let description: String?
    let language: String // "en", "ru", "multi"
    let ageRangeMin: Int
    let ageRangeMax: Int
    let priority: Int
    let aiConfidenceScore: Double
    let totalDurationSeconds: Int
    let trackCount: Int
    let tracks: [AudioTrack]
}
```

**TrackMetadata.swift**
```swift
struct TrackMetadata: Codable {
    let trackId: String
    let crySuitability: [CryType: Double] // hunger: 0.9, tired: 0.7
    let acousticFeatures: AcousticFeatures
    let researchCitations: String?
    let emotionalTags: [String] // ["calming", "soothing"]
    let culturalContext: String?
    let recommendedAgeMonths: [Int]
}

struct AcousticFeatures: Codable {
    let tempoBpm: Int
    let key: String?
    let mode: String? // "major", "minor"
}
```

**EmergencySession.swift**
```swift
struct EmergencySession: Codable {
    let id: String
    let babyId: String
    let playlistId: String
    var currentTrackId: String?
    var queueTracks: [String] // Array of track IDs
    let startedAt: Date
    var endedAt: Date?
    var sessionDurationSeconds: Int
}
```

### 4. UI Components (SwiftUI)

**EmergencyQueueView.swift** - Spotify-like queue
```swift
struct EmergencyQueueView: View {
    @StateObject var queueManager: EmergencyQueueManager
    @State private var showMetadataSheet = false

    var body: some View {
        VStack {
            // Current track with album art
            CurrentTrackCard(track: queueManager.currentTrack)

            // Progress bar
            TrackProgressBar(progress: queueManager.progress)

            // Upcoming tracks list
            UpcomingTracksListView(tracks: queueManager.upcomingTracks)

            // Cancel button
            CancelButton(action: queueManager.endSession)
        }
    }
}
```

**Components**:
- `CurrentTrackCard`: Large album art + title + artist + metadata badges
- `TrackProgressBar`: Visual progress with time remaining
- `UpcomingTracksListView`: Scrollable list of next 5 tracks
- `TrackMetadataSheet`: Full metadata modal (research citations, etc.)
- `CancelButton`: Prominent X button with confirmation dialog
- `LanguageBadge`: 🇬🇧/🇷🇺 flag indicators

### 5. Content Scraper (Python)

**scraper.py** - Automated content acquisition
```python
import requests
import mutagen  # Audio metadata extraction
import boto3  # R2 upload via S3-compatible API
import sqlite3
import json

SOURCES = {
    "freesound": {
        "api_key": os.getenv("FREESOUND_API_KEY"),
        "queries": ["white noise baby", "nature sounds calm", "lullaby"]
    },
    "incompetech": {
        "categories": ["Lullabies", "Classical", "Ambient"]
    }
}

def scrape_track(source, query):
    # Download MP3
    # Extract metadata (mutagen)
    # Upload to R2
    # Insert into database
    pass

def validate_audio_quality(filepath):
    audio = mutagen.File(filepath)
    assert audio.info.sample_rate >= 44100
    assert audio.info.bitrate >= 128000

def assign_cry_suitability(title, tags):
    # AI-based classification
    # Returns {"hunger": 0.8, "tired": 0.9, ...}
    pass
```

**Run**: `python scraper.py --limit 30 --dry-run`

### 6. Integration Points

**SmartCryResponseEngine.swift** - Modified to use playlists
```swift
class SmartCryResponseEngine {
    private let playlistSelector = PlaylistSelector()
    private let queueManager = EmergencyQueueManager()

    func handleCryDetected(cryType: CryType) async {
        // Select optimal playlist
        let playlists = await playlistSelector.selectOptimalPlaylist(
            cryType: cryType,
            babyAge: currentBaby.ageInMonths,
            languages: userPreferences.languages,
            babyId: currentBaby.id
        )

        guard let bestPlaylist = playlists.first else { return }

        // Start emergency session
        await queueManager.startSession(playlist: bestPlaylist)

        // Show EmergencyQueueView
        self.isEmergencyMode = true
    }
}
```

## Implementation Phases

### Phase 1: Database & API (4 hours)
1. Apply migration 013 to D1 database
2. Implement API endpoints (playlist selection, session management)
3. Test API with Postman/curl

### Phase 2: Swift Models & Services (6 hours)
1. Create Swift models (CryScenarioPlaylist, TrackMetadata, etc.)
2. Implement PlaylistSelector service
3. Implement EmergencyQueueManager
4. Implement EffectivenessTracker
5. Unit tests for services

### Phase 3: Content Scraper (4 hours)
1. Set up Python environment (requests, mutagen, boto3)
2. Implement scraper for Freesound API
3. Implement R2 upload logic
4. Implement database insertion
5. Run initial scrape (30 tracks)
6. Verify playback of all tracks

### Phase 4: UI Components (8 hours)
1. Create EmergencyQueueView layout
2. Implement CurrentTrackCard with album art
3. Implement TrackProgressBar
4. Implement UpcomingTracksListView
5. Implement CancelButton with confirmation
6. Implement LanguageBadge components
7. Integrate with SmartCryResponseEngine

### Phase 5: Integration & Testing (4 hours)
1. Integrate queue view with existing emergency mode
2. Test smooth transitions (FS-016 crossfade)
3. Test language filtering
4. Test effectiveness tracking
5. Fix integration bugs

### Phase 6: E2E Testing (4 hours)
1. Write Maestro flow for emergency activation
2. Write Maestro flow for queue navigation
3. Write Maestro flow for cancel button
4. Write playback tests for all 30 tracks
5. Snapshot tests for queue UI
6. Run full test suite

## Testing Strategy

### Unit Tests
- `PlaylistSelectorTests.swift`: Test metadata filtering, ranking
- `EmergencyQueueManagerTests.swift`: Test queue state management
- `EffectivenessTrackerTests.swift`: Test learning calculations

### Integration Tests
- Test API endpoints with mock database
- Test Swift services with mock API responses

### E2E Tests (Maestro)
```yaml
# emergency_playlist_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- assertVisible: "Listening..."
# Simulate cry detection (via test API)
- runScript: curl -X POST http://localhost:8787/test/trigger-cry
- assertVisible: "Emergency Mode"
- assertVisible: "Now Playing"
- assertVisible: "Up Next"
- scrollUntilVisible: "Cancel"
- tapOn: "Cancel"
- assertVisible: "How effective was this?"
- tapOn: "Very Effective"
- assertVisible: "Listening..."
```

### Playback Tests
```swift
func testAllScrapedTracksPlayable() async throws {
    let tracks = try await apiClient.getTracks()

    for track in tracks {
        let audioUrl = try await apiClient.getStreamingUrl(trackId: track.id)
        let player = AVPlayer(url: audioUrl)

        player.play()
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

        XCTAssertTrue(player.currentItem?.status == .readyToPlay)
        XCTAssertGreaterThan(player.currentTime().seconds, 0)
    }
}
```

## Rollout Plan

1. **Deploy migration 013** to production D1 database
2. **Run scraper** to populate initial 30 tracks
3. **Deploy API changes** to Cloudflare Workers
4. **Release iOS app update** with new emergency queue UI
5. **Monitor effectiveness data** for first week
6. **Iterate on AI selection** based on real data

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| R2 upload failures | Retry logic + local cache |
| API rate limits (Freesound) | Exponential backoff + quota tracking |
| Scraped content quality | Manual curation + validation tests |
| iOS audio buffer underruns | Prefetch next 3 tracks in queue |
| Large bundle size | Stream audio, don't bundle |
| Language detection errors | Manual tagging + fallback to "multi" |

## Success Metrics

- **Scraper**: 30+ tracks downloaded, 100% playable
- **API**: <500ms response time for playlist selection
- **UI**: Queue loads within 2 seconds
- **Effectiveness**: >70% of sessions marked "effective" after 1 week
- **Crashes**: Zero crashes related to emergency mode
- **Tests**: >90% E2E test pass rate
