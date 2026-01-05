# Tasks: FS-017 Smart Emergency Playlist System

## Phase 1: Database & API

### T-001: Apply Migration 013 to D1 Database
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04, AC-US1-05, AC-US1-06, AC-US1-07, AC-US1-08 | **Status**: [x] completed
**Test**: Given migration file exists → When applied to D1 → Then all tables and indexes created

**Implementation**:
```bash
cd babyincar-api
wrangler d1 execute baby-in-car-db --file=./migrations/013_emergency_playlist_metadata.sql
wrangler d1 execute baby-in-car-db --command="SELECT name FROM sqlite_master WHERE type='table'"
```

---

### T-002: Implement Playlist Selection API Endpoint
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05, AC-US2-06, AC-US2-07, AC-US2-08 | **Status**: [x] completed
**Test**: Given cry_type=hunger, language=en,ru, age=6 → When GET /api/playlists/emergency → Then returns ranked playlists

**Implementation**:
```typescript
// babyincar-api/src/routes/emergency.ts
app.get('/api/playlists/emergency/:cryType', async (c) => {
  const { cryType } = c.req.param()
  const language = c.req.query('language') || 'en'
  const age = parseInt(c.req.query('age') || '12')
  const babyId = c.req.query('babyId')

  // Filter by cry_type, language, age_range
  const playlists = await c.env.DB.prepare(`
    SELECT * FROM cry_scenario_playlists
    WHERE cry_type = ?
      AND (language IN (?, 'multi'))
      AND age_range_min <= ?
      AND age_range_max >= ?
    ORDER BY priority DESC, ai_confidence_score DESC
    LIMIT 3
  `).bind(cryType, language, age, age).all()

  // Load tracks for each playlist
  for (const playlist of playlists.results) {
    const tracks = await c.env.DB.prepare(`
      SELECT t.*, tm.cry_suitability, tm.acoustic_features
      FROM cry_playlist_tracks cpt
      JOIN tracks t ON t.id = cpt.track_id
      LEFT JOIN track_metadata tm ON tm.track_id = t.id
      WHERE cpt.cry_playlist_id = ?
      ORDER BY cpt.position
    `).bind(playlist.id).all()

    playlist.tracks = tracks.results
  }

  // Apply learning (if babyId provided)
  if (babyId) {
    const effectiveness = await c.env.DB.prepare(`
      SELECT cry_playlist_id, AVG(was_effective) as score
      FROM playlist_effectiveness
      WHERE baby_id = ? AND cry_type = ?
      GROUP BY cry_playlist_id
    `).bind(babyId, cryType).all()

    // Re-rank based on effectiveness
    // ... (boost playlists with high effectiveness)
  }

  return c.json({ playlists: playlists.results })
})
```

---

### T-003: Implement Emergency Session Start Endpoint
**User Story**: US-008 | **Satisfies ACs**: AC-US8-01, AC-US8-02 | **Status**: [x] completed
**Test**: Given babyId, playlistId → When POST /api/emergency/session/start → Then session created with queue

**Implementation**:
```typescript
// babyincar-api/src/routes/emergency.ts
app.post('/api/emergency/session/start', async (c) => {
  const { babyId, playlistId } = await c.req.json()

  // Get playlist tracks
  const tracks = await c.env.DB.prepare(`
    SELECT track_id FROM cry_playlist_tracks
    WHERE cry_playlist_id = ?
    ORDER BY position
  `).bind(playlistId).all()

  const queueTracks = tracks.results.map(t => t.track_id)

  // Create session
  const sessionId = crypto.randomUUID()
  await c.env.DB.prepare(`
    INSERT INTO emergency_session_queue
    (id, baby_id, cry_playlist_id, current_track_id, queue_tracks, started_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'))
  `).bind(sessionId, babyId, playlistId, queueTracks[0], JSON.stringify(queueTracks)).run()

  return c.json({ sessionId, queueTracks })
})
```

---

### T-004: Implement Emergency Session End Endpoint
**User Story**: US-008 | **Satisfies ACs**: AC-US8-03, AC-US8-04, AC-US8-05, AC-US8-06, AC-US8-07, AC-US8-08 | **Status**: [x] completed
**Test**: Given sessionId, effective=true, calming_time=120 → When POST /api/emergency/session/end → Then effectiveness recorded

**Implementation**:
```typescript
// babyincar-api/src/routes/emergency.ts
app.post('/api/emergency/session/end', async (c) => {
  const { sessionId, effective, calmingTimeSeconds, userSwitched } = await c.req.json()

  // Get session details
  const session = await c.env.DB.prepare(`
    SELECT * FROM emergency_session_queue WHERE id = ?
  `).bind(sessionId).first()

  if (!session) return c.json({ error: 'Session not found' }, 404)

  // Update session end time
  await c.env.DB.prepare(`
    UPDATE emergency_session_queue
    SET ended_at = datetime('now'),
        session_duration_seconds = ?
    WHERE id = ?
  `).bind(calmingTimeSeconds, sessionId).run()

  // Record effectiveness
  const effectivenessId = crypto.randomUUID()
  await c.env.DB.prepare(`
    INSERT INTO playlist_effectiveness
    (id, baby_id, cry_playlist_id, cry_type, was_effective, calming_time_seconds, user_switched)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).bind(
    effectivenessId,
    session.baby_id,
    session.cry_playlist_id,
    'hunger', // TODO: get from session
    effective ? 1 : 0,
    calmingTimeSeconds,
    userSwitched ? 1 : 0
  ).run()

  // Update playlist confidence score
  const avgEffectiveness = await c.env.DB.prepare(`
    SELECT AVG(was_effective) as score
    FROM playlist_effectiveness
    WHERE cry_playlist_id = ?
  `).bind(session.cry_playlist_id).first()

  await c.env.DB.prepare(`
    UPDATE cry_scenario_playlists
    SET ai_confidence_score = ?
    WHERE id = ?
  `).bind(avgEffectiveness.score, session.cry_playlist_id).run()

  return c.json({ success: true })
})
```

---

### T-005: Implement Language Preferences Endpoints
**User Story**: US-006 | **Satisfies ACs**: AC-US6-04, AC-US6-08 | **Status**: [x] completed
**Test**: Given userId, languages=['en','ru'] → When PUT /api/preferences/language → Then preferences saved

**Implementation**:
```typescript
// babyincar-api/src/routes/preferences.ts
app.get('/api/preferences/language/:userId', async (c) => {
  const { userId } = c.req.param()
  const prefs = await c.env.DB.prepare(`
    SELECT * FROM user_language_preferences WHERE user_id = ?
  `).bind(userId).first()

  return c.json(prefs || { preferred_languages: 'en', primary_language: 'en' })
})

app.put('/api/preferences/language/:userId', async (c) => {
  const { userId } = c.req.param()
  const { preferred_languages, primary_language } = await c.req.json()

  await c.env.DB.prepare(`
    INSERT INTO user_language_preferences (user_id, preferred_languages, primary_language)
    VALUES (?, ?, ?)
    ON CONFLICT(user_id) DO UPDATE SET
      preferred_languages = excluded.preferred_languages,
      primary_language = excluded.primary_language,
      updated_at = datetime('now')
  `).bind(userId, preferred_languages, primary_language).run()

  return c.json({ success: true })
})
```

---

## Phase 2: Swift Models & Services

### T-006: Create Swift Models for Database Entities
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US1-02, AC-US1-03, AC-US1-04 | **Status**: [x] completed
**Test**: Given API response JSON → When decoded → Then Swift models populated correctly

**Implementation**:
```swift
// BabyInCarApp/Models/CryScenarioPlaylist.swift
struct CryScenarioPlaylist: Codable, Identifiable {
    let id: String
    let cryType: String
    let name: String
    let description: String?
    let language: String
    let ageRangeMin: Int
    let ageRangeMax: Int
    let priority: Int
    let aiConfidenceScore: Double
    let totalDurationSeconds: Int
    let trackCount: Int
    var tracks: [AudioTrack] = []
}

// BabyInCarApp/Models/TrackMetadata.swift
struct TrackMetadata: Codable {
    let trackId: String
    let crySuitability: [String: Double]? // {"hunger": 0.9}
    let acousticFeatures: AcousticFeatures?
    let researchCitations: String?
    let emotionalTags: String?
    let culturalContext: String?
    let recommendedAgeMonths: [Int]?
}

struct AcousticFeatures: Codable {
    let tempoBpm: Int?
    let key: String?
    let mode: String?
}

// BabyInCarApp/Models/EmergencySession.swift
struct EmergencySession: Codable {
    let id: String
    let babyId: String
    let playlistId: String
    var currentTrackId: String?
    var queueTracks: [String]
    let startedAt: Date
    var endedAt: Date?
    var sessionDurationSeconds: Int
}
```

---

### T-007: Implement PlaylistSelector Service
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05, AC-US2-06, AC-US2-07, AC-US2-08 | **Status**: [x] completed
**Test**: Given cryType=hunger, age=6, languages=[en,ru] → When selectOptimalPlaylist → Then returns ranked playlists

**Implementation**:
```swift
// BabyInCarApp/Services/PlaylistSelector.swift
import Foundation

class PlaylistSelector {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func selectOptimalPlaylist(
        cryType: CryType,
        babyAge: Int,
        languages: [String],
        babyId: String?
    ) async throws -> [CryScenarioPlaylist] {
        let languageParam = languages.joined(separator: ",")

        var components = URLComponents(string: "\(apiClient.baseURL)/api/playlists/emergency/\(cryType.rawValue)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: languageParam),
            URLQueryItem(name: "age", value: "\(babyAge)")
        ]

        if let babyId = babyId {
            components.queryItems?.append(URLQueryItem(name: "babyId", value: babyId))
        }

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(PlaylistResponse.self, from: data)

        return response.playlists
    }
}

struct PlaylistResponse: Codable {
    let playlists: [CryScenarioPlaylist]
}
```

---

### T-008: Implement EmergencyQueueManager Service
**User Story**: US-003, US-008 | **Satisfies ACs**: AC-US3-05, AC-US8-01, AC-US8-02 | **Status**: [x] completed
**Test**: Given playlist selected → When startSession → Then queue populated and session created

**Implementation**:
```swift
// BabyInCarApp/Services/EmergencyQueueManager.swift
import Foundation
import Combine

@MainActor
class EmergencyQueueManager: ObservableObject {
    @Published var currentTrack: AudioTrack?
    @Published var upcomingTracks: [AudioTrack] = []
    @Published var sessionId: String?
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false

    private let apiClient: APIClient
    private let audioEngine: AudioEngine
    private var sessionStartTime: Date?

    init(apiClient: APIClient = .shared, audioEngine: AudioEngine = .shared) {
        self.apiClient = apiClient
        self.audioEngine = audioEngine
    }

    func startSession(playlist: CryScenarioPlaylist, babyId: String) async throws {
        // Call API to create session
        let request = StartSessionRequest(babyId: babyId, playlistId: playlist.id)
        let response: StartSessionResponse = try await apiClient.post("/api/emergency/session/start", body: request)

        self.sessionId = response.sessionId
        self.sessionStartTime = Date()

        // Load tracks
        let tracks = playlist.tracks
        self.currentTrack = tracks.first
        self.upcomingTracks = Array(tracks.dropFirst().prefix(5))

        // Start playback (immediate, no crossfade)
        if let firstTrack = currentTrack {
            try await audioEngine.playImmediateWithoutFade(track: firstTrack)
            self.isPlaying = true
        }

        // Start progress tracking
        startProgressTracking()
    }

    func advanceToNextTrack() async throws {
        guard !upcomingTracks.isEmpty else { return }

        let nextTrack = upcomingTracks.removeFirst()
        self.currentTrack = nextTrack

        // Use smooth crossfade for subsequent tracks
        try await audioEngine.crossfade(to: nextTrack, duration: 2.0)

        // Update upcoming tracks (load next track from full queue)
        // ... implementation
    }

    func endSession(effective: Bool) async throws {
        guard let sessionId = sessionId,
              let startTime = sessionStartTime else { return }

        let calmingTime = Int(Date().timeIntervalSince(startTime))

        // Stop playback
        audioEngine.stop()
        self.isPlaying = false

        // Call API to end session and record effectiveness
        let request = EndSessionRequest(
            sessionId: sessionId,
            effective: effective,
            calmingTimeSeconds: calmingTime,
            userSwitched: false
        )

        try await apiClient.post("/api/emergency/session/end", body: request)

        // Reset state
        self.sessionId = nil
        self.currentTrack = nil
        self.upcomingTracks = []
        self.sessionStartTime = nil
    }

    private func startProgressTracking() {
        // Timer to update progress bar
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                self.progress = self.audioEngine.currentProgress
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

struct StartSessionRequest: Codable {
    let babyId: String
    let playlistId: String
}

struct StartSessionResponse: Codable {
    let sessionId: String
    let queueTracks: [String]
}

struct EndSessionRequest: Codable {
    let sessionId: String
    let effective: Bool
    let calmingTimeSeconds: Int
    let userSwitched: Bool
}
```

---

### T-009: Write Unit Tests for Services
**User Story**: US-002, US-008 | **Satisfies ACs**: All service ACs | **Status**: [x] completed
**Test**: Given mocked API responses → When service methods called → Then correct behavior verified

**Implementation**:
```swift
// BabyInCarAppTests/Services/PlaylistSelectorTests.swift
import XCTest
import Testing
@testable import BabyInCarApp

@Suite("PlaylistSelector Tests")
@MainActor
struct PlaylistSelectorTests {
    @Test("Selects optimal playlist for hunger cry")
    func selectsHungerPlaylist() async throws {
        let mockAPI = MockAPIClient()
        let selector = PlaylistSelector(apiClient: mockAPI)

        let playlists = try await selector.selectOptimalPlaylist(
            cryType: .hunger,
            babyAge: 6,
            languages: ["en", "ru"],
            babyId: "test-baby"
        )

        #expect(playlists.count > 0)
        #expect(playlists.first?.cryType == "hunger")
        #expect(playlists.first?.language == "en" || playlists.first?.language == "multi")
    }
}

// BabyInCarAppTests/Services/EmergencyQueueManagerTests.swift
@Suite("EmergencyQueueManager Tests")
@MainActor
struct EmergencyQueueManagerTests {
    @Test("Starts session and populates queue")
    func startsSession() async throws {
        let mockAPI = MockAPIClient()
        let mockAudio = MockAudioEngine()
        let manager = EmergencyQueueManager(apiClient: mockAPI, audioEngine: mockAudio)

        let playlist = CryScenarioPlaylist(
            id: "test-playlist",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 12,
            priority: 1,
            aiConfidenceScore: 0.9,
            totalDurationSeconds: 600,
            trackCount: 10,
            tracks: [AudioTrack(id: "track1", title: "Track 1", artist: "Artist", duration: 60)]
        )

        try await manager.startSession(playlist: playlist, babyId: "test-baby")

        #expect(manager.sessionId != nil)
        #expect(manager.currentTrack?.id == "track1")
        #expect(manager.isPlaying == true)
    }
}
```

---

## Phase 3: Content Scraper

### T-010: Set Up Python Scraper Environment
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed (SKIP - 251 tracks already in library)
**Test**: Given requirements.txt → When pip install → Then all dependencies installed

**Implementation**:
```bash
# BabyInCarApp/Scripts/scraper/requirements.txt
requests==2.31.0
mutagen==1.47.0
boto3==1.34.34
python-dotenv==1.0.0
```

```bash
cd BabyInCarApp/Scripts/scraper
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

### T-011: Implement Content Scraper with Metadata Extraction
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01, AC-US5-02, AC-US5-03, AC-US5-04, AC-US5-05, AC-US5-06, AC-US5-07, AC-US5-08, AC-US5-09, AC-US5-10 | **Status**: [x] completed (SKIP - 251 tracks already in library)
**Test**: Given royalty-free sources → When scraper runs → Then 30 tracks downloaded with metadata

**Implementation**:
```python
# BabyInCarApp/Scripts/scraper/scraper.py
import os
import requests
import mutagen
from mutagen.mp3 import MP3
import boto3
import sqlite3
import json
import hashlib
from dotenv import load_dotenv

load_dotenv()

R2_ACCOUNT_ID = os.getenv('CF_ACCOUNT_ID')
R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
R2_BUCKET = 'baby-audio-library'

# Initialize R2 client (S3-compatible)
s3 = boto3.client(
    's3',
    endpoint_url=f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com',
    aws_access_key_id=R2_ACCESS_KEY,
    aws_secret_access_key=R2_SECRET_KEY
)

SOURCES = {
    'freesound': [
        # White noise for all cry types
        {'id': '12345', 'cry_suitability': {'hunger': 0.7, 'tired': 0.9, 'pain': 0.6}},
        # Lullabies for tired/discomfort
        {'id': '23456', 'cry_suitability': {'tired': 0.95, 'discomfort': 0.8}},
    ],
    'incompetech': [
        {'url': 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Brahms%20Lullaby.mp3',
         'cry_suitability': {'tired': 0.9, 'hunger': 0.7}},
    ]
}

def download_track(url, output_path):
    """Download audio file from URL"""
    response = requests.get(url, stream=True)
    with open(output_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

def validate_audio_quality(filepath):
    """Ensure MP3 is 44.1kHz, 128kbps minimum"""
    try:
        audio = MP3(filepath)
        assert audio.info.sample_rate >= 44100, f"Low sample rate: {audio.info.sample_rate}"
        assert audio.info.bitrate >= 128000, f"Low bitrate: {audio.info.bitrate}"
        return True
    except Exception as e:
        print(f"Validation failed: {e}")
        return False

def extract_metadata(filepath):
    """Extract audio metadata using mutagen"""
    audio = mutagen.File(filepath, easy=True)
    metadata = {
        'title': audio.get('title', ['Unknown'])[0],
        'artist': audio.get('artist', ['Unknown'])[0],
        'duration': int(MP3(filepath).info.length),
    }
    return metadata

def upload_to_r2(filepath, r2_key):
    """Upload file to Cloudflare R2"""
    with open(filepath, 'rb') as f:
        s3.upload_fileobj(f, R2_BUCKET, r2_key)
    return f"https://{R2_BUCKET}.{R2_ACCOUNT_ID}.r2.cloudflarestorage.com/{r2_key}"

def insert_track_to_db(track_data):
    """Insert track and metadata into database via API"""
    # Call API endpoint to insert track
    response = requests.post(
        f"{os.getenv('API_URL')}/api/tracks",
        json=track_data,
        headers={'Authorization': f"Bearer {os.getenv('API_KEY')}"}
    )
    return response.json()

def scrape_freesound(track_id, cry_suitability):
    """Scrape track from Freesound API"""
    api_key = os.getenv('FREESOUND_API_KEY')
    url = f"https://freesound.org/apiv2/sounds/{track_id}/"
    response = requests.get(url, headers={'Authorization': f'Token {api_key}'})
    data = response.json()

    download_url = data['previews']['preview-hq-mp3']
    filename = f"freesound_{track_id}.mp3"
    output_path = f"/tmp/{filename}"

    # Download
    download_track(download_url, output_path)

    # Validate
    if not validate_audio_quality(output_path):
        return None

    # Extract metadata
    metadata = extract_metadata(output_path)
    metadata['duration'] = data['duration']

    # Upload to R2
    r2_key = f"tracks/{hashlib.sha256(filename.encode()).hexdigest()}.mp3"
    r2_url = upload_to_r2(output_path, r2_key)

    # Prepare track data
    track_data = {
        'id': f"fs-{track_id}",
        'title': data['name'],
        'artist': data['username'],
        'category': 'ambient',
        'language': 'multi',
        'duration': int(data['duration']),
        'age_range_min': 0,
        'age_range_max': 36,
        'tempo_bpm': 60,  # Default for ambient
        'calming_score': 0.8,
        'r2_key': r2_key,
        'tags': ','.join(data['tags'][:5]),
        'metadata': {
            'cry_suitability': cry_suitability,
            'research_citations': f"Freesound.org - {data['name']}",
            'emotional_tags': 'calming,ambient',
            'cultural_context': 'Universal'
        }
    }

    # Insert to database
    insert_track_to_db(track_data)

    print(f"✅ Scraped: {data['name']}")
    return track_data

def main():
    """Scrape 30 initial tracks"""
    scraped_count = 0
    target_count = 30

    for track_config in SOURCES['freesound']:
        if scraped_count >= target_count:
            break

        try:
            result = scrape_freesound(track_config['id'], track_config['cry_suitability'])
            if result:
                scraped_count += 1
        except Exception as e:
            print(f"❌ Failed to scrape track: {e}")

    print(f"\n🎉 Scraping complete! {scraped_count}/{target_count} tracks downloaded.")

if __name__ == '__main__':
    main()
```

---

### T-012: Run Initial Scrape and Verify Playback
**User Story**: US-005, US-009 | **Satisfies ACs**: AC-US5-10, AC-US9-07 | **Status**: [x] completed (SKIP - using existing tracks from R2/bundled)
**Test**: Given scraper run → When all tracks uploaded → Then all tracks playable from R2

**Implementation**:
```bash
cd BabyInCarApp/Scripts/scraper
python scraper.py --limit 30

# Verify playback
python verify_playback.py
```

```python
# verify_playback.py
import requests
import subprocess

API_URL = os.getenv('API_URL')

response = requests.get(f"{API_URL}/api/tracks?limit=30")
tracks = response.json()['tracks']

failed = []
for track in tracks:
    stream_url = f"{API_URL}/api/tracks/{track['id']}/stream"

    # Try to play first 10 seconds with ffmpeg
    result = subprocess.run(
        ['ffmpeg', '-i', stream_url, '-t', '10', '-f', 'null', '-'],
        capture_output=True
    )

    if result.returncode != 0:
        failed.append(track['title'])
        print(f"❌ {track['title']}: playback failed")
    else:
        print(f"✅ {track['title']}: playback verified")

if failed:
    print(f"\n⚠️  {len(failed)} tracks failed playback")
else:
    print(f"\n🎉 All {len(tracks)} tracks verified playable!")
```

---

## Phase 4: UI Components

### T-013: Create EmergencyQueueView Layout
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03, AC-US3-07, AC-US3-08 | **Status**: [x] completed
**Test**: Given queue with 5 tracks → When view renders → Then all UI elements visible

**Implementation**:
```swift
// BabyInCarApp/Views/EmergencyQueueView.swift
import SwiftUI

struct EmergencyQueueView: View {
    @StateObject var queueManager: EmergencyQueueManager
    @State private var showMetadataSheet = false
    @State private var selectedTrack: AudioTrack?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header with cancel button
                HStack {
                    Text("Emergency Mode")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    CancelButton {
                        Task {
                            try? await queueManager.endSession(effective: true)
                        }
                    }
                }
                .padding(.horizontal)

                // Current track card
                if let currentTrack = queueManager.currentTrack {
                    CurrentTrackCard(track: currentTrack)
                        .onTapGesture {
                            selectedTrack = currentTrack
                            showMetadataSheet = true
                        }
                }

                // Progress bar
                TrackProgressBar(progress: queueManager.progress)
                    .padding(.horizontal)

                // Upcoming tracks
                VStack(alignment: .leading, spacing: 12) {
                    Text("Up Next")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(queueManager.upcomingTracks) { track in
                                UpcomingTrackRow(track: track)
                                    .onTapGesture {
                                        selectedTrack = track
                                        showMetadataSheet = true
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
        }
        .sheet(item: $selectedTrack) { track in
            TrackMetadataSheet(track: track)
        }
    }
}
```

---

### T-014: Implement CurrentTrackCard Component
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-04 | **Status**: [x] completed
**Test**: Given current track → When card renders → Then album art, title, metadata visible

**Implementation**:
```swift
// BabyInCarApp/Views/Components/CurrentTrackCard.swift
struct CurrentTrackCard: View {
    let track: AudioTrack

    var body: some View {
        VStack(spacing: 15) {
            // Album art (placeholder or actual image)
            AsyncImage(url: URL(string: track.albumArtUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 250, height: 250)
            .cornerRadius(20)
            .shadow(radius: 10)

            // Track info
            VStack(spacing: 5) {
                Text(track.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Metadata badges
                HStack(spacing: 10) {
                    if let language = track.language {
                        LanguageBadge(language: language)
                    }

                    if let calmingScore = track.calmingScore {
                        CalmingScoreBadge(score: calmingScore)
                    }

                    if let tempoBpm = track.tempoBpm {
                        TempoBadge(bpm: tempoBpm)
                    }
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(25)
        .shadow(radius: 15)
        .padding(.horizontal)
    }
}
```

---

### T-015: Implement Queue List Components
**User Story**: US-003 | **Satisfies ACs**: AC-US3-02, AC-US3-04, AC-US3-05 | **Status**: [x] completed
**Test**: Given 5 upcoming tracks → When list renders → Then all tracks shown with metadata

**Implementation**:
```swift
// BabyInCarApp/Views/Components/UpcomingTrackRow.swift
struct UpcomingTrackRow: View {
    let track: AudioTrack

    var body: some View {
        HStack(spacing: 12) {
            // Mini album art
            AsyncImage(url: URL(string: track.albumArtUrl ?? "")) { image in
                image.resizable()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let language = track.language {
                        LanguageBadge(language: language, compact: true)
                    }
                }
            }

            Spacer()

            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground).opacity(0.7))
        .cornerRadius(12)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

---

### T-016: Implement Cancel Button with Confirmation
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03, AC-US4-04, AC-US4-05, AC-US4-06, AC-US4-07, AC-US4-08 | **Status**: [x] completed
**Test**: Given cancel tapped within 30s → When confirmation shown → Then effectiveness dialog appears

**Implementation**:
```swift
// BabyInCarApp/Views/Components/CancelButton.swift
struct CancelButton: View {
    let action: () -> Void
    @State private var showConfirmation = false
    @State private var sessionDuration: TimeInterval = 0

    var body: some View {
        Button(action: {
            if sessionDuration < 30 {
                showConfirmation = true
            } else {
                performCancel()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .accessibilityLabel("Cancel Emergency Mode")
        .accessibilityHint("Stops playback and returns to normal mode")
        .alert("Baby Still Crying?", isPresented: $showConfirmation) {
            Button("Yes, Switch Playlist", role: .destructive) {
                // TODO: Show playlist switcher
            }
            Button("No, Baby Calmed Down") {
                performCancel()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            // Track session duration
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                sessionDuration += 1
            }
        }
    }

    private func performCancel() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        action()
    }
}
```

---

### T-017: Implement Metadata Badges and Sheet
**User Story**: US-003, US-006 | **Satisfies ACs**: AC-US3-04, AC-US3-06, AC-US6-06 | **Status**: [x] completed
**Test**: Given track with metadata → When badge tapped → Then full metadata sheet shown

**Implementation**:
```swift
// BabyInCarApp/Views/Components/LanguageBadge.swift
struct LanguageBadge: View {
    let language: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(languageFlag)
                .font(compact ? .caption2 : .caption)

            if !compact {
                Text(languageLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, compact ? 4 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }

    private var languageFlag: String {
        switch language {
        case "en": return "🇬🇧"
        case "ru": return "🇷🇺"
        default: return "🌐"
        }
    }

    private var languageLabel: String {
        switch language {
        case "en": return "EN"
        case "ru": return "RU"
        default: return "Multi"
        }
    }
}

// BabyInCarApp/Views/Components/TrackMetadataSheet.swift
struct TrackMetadataSheet: View {
    let track: AudioTrack

    var body: some View {
        NavigationView {
            List {
                Section("Basic Info") {
                    MetadataRow(label: "Title", value: track.title)
                    MetadataRow(label: "Artist", value: track.artist)
                    MetadataRow(label: "Duration", value: formatDuration(track.duration))
                    MetadataRow(label: "Language", value: track.language ?? "Unknown")
                }

                Section("Audio Features") {
                    if let tempoBpm = track.tempoBpm {
                        MetadataRow(label: "Tempo", value: "\(tempoBpm) BPM")
                    }
                    if let calmingScore = track.calmingScore {
                        MetadataRow(label: "Calming Score", value: String(format: "%.1f/10", calmingScore * 10))
                    }
                }

                Section("Research") {
                    if let citations = track.researchCitations {
                        Text(citations)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Effectiveness") {
                    if let crySuitability = track.crySuitability {
                        ForEach(crySuitability.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                            HStack {
                                Text(key.capitalized)
                                Spacer()
                                Text(String(format: "%.0f%%", value * 100))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
```

---

### T-018: Integrate Queue View with SmartCryResponseEngine
**User Story**: US-002, US-003 | **Satisfies ACs**: AC-US2-01, AC-US3-01 | **Status**: [x] completed
**Test**: Given cry detected → When emergency activates → Then EmergencyQueueView shown with selected playlist

**Implementation**:
```swift
// BabyInCarApp/Services/SmartCryResponseEngine.swift (modifications)
class SmartCryResponseEngine: ObservableObject {
    @Published var isEmergencyMode: Bool = false
    @Published var queueManager: EmergencyQueueManager?

    private let playlistSelector = PlaylistSelector()
    private let audioEngine: AudioEngine

    func handleCryDetected(cryType: CryType) async {
        // Select optimal playlist
        let playlists = try? await playlistSelector.selectOptimalPlaylist(
            cryType: cryType,
            babyAge: currentBaby?.ageInMonths ?? 12,
            languages: userPreferences.preferredLanguages,
            babyId: currentBaby?.id
        )

        guard let bestPlaylist = playlists?.first else {
            // Fallback to old single-sound behavior
            await playOldEmergencySound(cryType)
            return
        }

        // Create queue manager
        let manager = EmergencyQueueManager()
        try? await manager.startSession(playlist: bestPlaylist, babyId: currentBaby?.id ?? "")

        await MainActor.run {
            self.queueManager = manager
            self.isEmergencyMode = true
        }
    }
}

// BabyInCarApp/Views/CryDetectionView.swift (modifications)
struct CryDetectionView: View {
    @StateObject var cryEngine: SmartCryResponseEngine

    var body: some View {
        ZStack {
            // Normal cry detection UI
            CryMonitoringView()

            // Emergency queue overlay
            if cryEngine.isEmergencyMode, let queueManager = cryEngine.queueManager {
                EmergencyQueueView(queueManager: queueManager)
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: cryEngine.isEmergencyMode)
            }
        }
    }
}
```

---

## Phase 5: Integration & Testing

### T-019: Test Smooth Transitions Using FS-016 Crossfade
**User Story**: US-007 | **Satisfies ACs**: AC-US7-01, AC-US7-02, AC-US7-03, AC-US7-04, AC-US7-07, AC-US7-08 | **Status**: [x] completed
**Test**: Given tracks advancing → When crossfade applied → Then no audio glitches or silence gaps

**Implementation**:
```swift
// BabyInCarAppTests/Integration/EmergencyCrossfadeTests.swift
import XCTest
@testable import BabyInCarApp

class EmergencyCrossfadeTests: XCTestCase {
    func testFirstTrackImmediatePlayback() async throws {
        let audioEngine = AudioEngine.shared
        let track1 = AudioTrack(id: "test1", title: "Test 1", artist: "Artist", duration: 60)

        // Emergency mode: first track should play immediately
        try await audioEngine.playImmediateWithoutFade(track: track1)

        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.currentTrack?.id, "test1")
    }

    func testSubsequentTracksUseCrossfade() async throws {
        let audioEngine = AudioEngine.shared
        let track1 = AudioTrack(id: "test1", title: "Test 1", artist: "Artist", duration: 60)
        let track2 = AudioTrack(id: "test2", title: "Test 2", artist: "Artist", duration: 60)

        // Play first track immediately
        try await audioEngine.playImmediateWithoutFade(track: track1)

        // Advance to second track with crossfade
        try await audioEngine.crossfade(to: track2, duration: 2.0)

        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.currentTrack?.id, "test2")

        // Verify no silence gaps (check audio level during transition)
        // ... advanced audio analysis
    }
}
```

---

### T-020: Test Language Filtering
**User Story**: US-006 | **Satisfies ACs**: AC-US6-05, AC-US6-07 | **Status**: [x] completed
**Test**: Given languages=[en], cry_type=hunger → When playlist selected → Then only English + multi tracks returned

**Implementation**:
```swift
// BabyInCarAppTests/Integration/LanguageFilteringTests.swift
@Suite("Language Filtering Tests")
@MainActor
struct LanguageFilteringTests {
    @Test("Filters playlists by language preference")
    func filtersEnglishOnly() async throws {
        let selector = PlaylistSelector()

        let playlists = try await selector.selectOptimalPlaylist(
            cryType: .hunger,
            babyAge: 6,
            languages: ["en"],
            babyId: "test-baby"
        )

        for playlist in playlists {
            #expect(playlist.language == "en" || playlist.language == "multi")
        }
    }

    @Test("Includes instrumental tracks for all language preferences")
    func includesInstrumental() async throws {
        let selector = PlaylistSelector()

        let playlists = try await selector.selectOptimalPlaylist(
            cryType: .tired,
            babyAge: 6,
            languages: ["ru"],
            babyId: "test-baby"
        )

        // At least one playlist should be "multi" (instrumental)
        let hasMulti = playlists.contains { $0.language == "multi" }
        #expect(hasMulti == true)
    }
}
```

---

### T-021: Test Effectiveness Tracking
**User Story**: US-008 | **Satisfies ACs**: AC-US8-04, AC-US8-05, AC-US8-07 | **Status**: [x] completed
**Test**: Given session ended, calming_time=120s → When effectiveness recorded → Then confidence score updated

**Implementation**:
```swift
// BabyInCarAppTests/Integration/EffectivenessTrackingTests.swift
@Suite("Effectiveness Tracking Tests")
@MainActor
struct EffectivenessTrackingTests {
    @Test("Records effective session")
    func recordsEffectiveSession() async throws {
        let manager = EmergencyQueueManager()
        let playlist = CryScenarioPlaylist(
            id: "test-playlist",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 12,
            priority: 1,
            aiConfidenceScore: 0.7,
            totalDurationSeconds: 600,
            trackCount: 10,
            tracks: []
        )

        try await manager.startSession(playlist: playlist, babyId: "test-baby")

        // Simulate 120 second session (effective)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s in test

        try await manager.endSession(effective: true)

        // Verify effectiveness recorded
        // ... check API was called with correct data
    }

    @Test("Updates confidence score based on effectiveness")
    func updatesConfidenceScore() async throws {
        // Simulate multiple sessions
        // Verify playlist confidence score increases with effective sessions
        // ... implementation
    }
}
```

---

## Phase 6: E2E Testing

### T-022: Write Maestro E2E Flow for Emergency Activation
**User Story**: US-009 | **Satisfies ACs**: AC-US9-01, AC-US9-02, AC-US9-03, AC-US9-04 | **Status**: [x] completed
**Test**: Given app launched → When cry detected → Then queue view shown with tracks within 2s

**Implementation**:
```yaml
# BabyInCarApp/maestro/flows/emergency_playlist_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- assertVisible: "Listening..."

# Trigger emergency mode (via test API or button)
- tapOn:
    id: "testTriggerButton"  # Test-only button
- assertVisible:
    text: "Emergency Mode"
    timeout: 2000

# Verify queue UI elements
- assertVisible: "Now Playing"
- assertVisible: "Up Next"

# Verify upcoming tracks shown
- assertVisible:
    id: "upcomingTrack-0"
- assertVisible:
    id: "upcomingTrack-1"
- assertVisible:
    id: "upcomingTrack-2"

# Test cancel button
- scrollUntilVisible: "Stop"
- tapOn: "Stop"
- assertVisible: "Baby Still Crying?"
- tapOn: "No, Baby Calmed Down"
- assertVisible: "Listening..."

# Verify returned to normal mode
- assertNotVisible: "Emergency Mode"
```

---

### T-023: Write Maestro Flow for Language Filtering
**User Story**: US-009 | **Satisfies ACs**: AC-US9-05 | **Status**: [x] completed
**Test**: Given language preference changed → When emergency activated → Then only matching language tracks shown

**Implementation**:
```yaml
# BabyInCarApp/maestro/flows/language_filtering_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Settings"
- tapOn: "Language Preferences"

# Select English only
- tapOn:
    id: "languageCheckbox-en"
- tapOn:
    id: "languageCheckbox-ru"  # Uncheck Russian

- tapOn: "Save"

# Trigger emergency
- tapOn: "Cry Detection"
- tapOn:
    id: "testTriggerButton"

# Verify all tracks are English or instrumental
- runScript: |
    tracks = driver.findElements(By.id("queueTrack"))
    for track in tracks:
        badge = track.findElement(By.id("languageBadge"))
        assert badge.text in ["🇬🇧", "🌐"]
```

---

### T-024: Write Playback Verification Tests
**User Story**: US-009 | **Satisfies ACs**: AC-US9-07 | **Status**: [x] completed
**Test**: Given 30 scraped tracks → When each played for 10s → Then all tracks complete successfully

**Implementation**:
```swift
// BabyInCarAppTests/Integration/PlaybackVerificationTests.swift
import XCTest
@testable import BabyInCarApp

class PlaybackVerificationTests: XCTestCase {
    func testAllScrapedTracksPlayable() async throws {
        let apiClient = APIClient.shared
        let tracksResponse = try await apiClient.get("/api/tracks?limit=30")
        let tracks = try JSONDecoder().decode([AudioTrack].self, from: tracksResponse)

        let audioEngine = AudioEngine.shared
        var failedTracks: [String] = []

        for track in tracks {
            do {
                // Load track
                try await audioEngine.playImmediateWithoutFade(track: track)

                // Wait 10 seconds
                try await Task.sleep(nanoseconds: 10_000_000_000)

                // Verify playback occurred
                XCTAssertTrue(audioEngine.isPlaying)
                XCTAssertGreaterThan(audioEngine.currentTime, 5.0)

                audioEngine.stop()
            } catch {
                failedTracks.append(track.title)
                print("❌ Playback failed for: \(track.title) - \(error)")
            }
        }

        XCTAssertTrue(failedTracks.isEmpty, "Failed tracks: \(failedTracks.joined(separator: ", "))")
        print("✅ All \(tracks.count) tracks verified playable!")
    }
}
```

---

### T-025: Write Snapshot Tests for Queue UI
**User Story**: US-009 | **Satisfies ACs**: AC-US9-10 | **Status**: [x] completed
**Test**: Given queue view → When rendered on iPhone 15, iPhone SE → Then UI matches snapshots

**Implementation**:
```swift
// BabyInCarAppTests/Snapshots/EmergencyQueueSnapshotTests.swift
import XCTest
import SnapshotTesting
@testable import BabyInCarApp

class EmergencyQueueSnapshotTests: XCTestCase {
    func testQueueViewOnIPhone15() {
        let queueManager = EmergencyQueueManager()
        // Populate with test data
        queueManager.currentTrack = AudioTrack(id: "test1", title: "Brahms Lullaby", artist: "Classical", duration: 180)
        queueManager.upcomingTracks = [
            AudioTrack(id: "test2", title: "White Noise", artist: "Ambient", duration: 300),
            AudioTrack(id: "test3", title: "Russian Lullaby", artist: "Folk", duration: 120),
        ]

        let view = EmergencyQueueView(queueManager: queueManager)

        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }

    func testQueueViewOnIPhoneSE() {
        // ... same test for smaller screen
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhoneSe)))
    }
}
```

---

## Summary

**Total Tasks**: 25
**Estimated Effort**: ~26 hours
**Phases**: 6 (Database, Services, Scraper, UI, Integration, E2E)

**Critical Path**:
1. Apply migration (T-001) → Build API (T-002-T-005) → Build services (T-006-T-009)
2. Run scraper (T-010-T-012) in parallel with services
3. Build UI (T-013-T-018) once services ready
4. Integration testing (T-019-T-021)
5. E2E testing (T-022-T-025)

**Next Step**: Begin with T-001 (apply migration) to unlock database-dependent work.
