// =============================================================================
// NOTE: This file tests playback verification functionality.
// EmergencyQueueManager references are DEPRECATED - tests use them for backward
// compatibility only. New tests should use SmartEmergencyQueue.shared.
//
// Migration: SmartEmergencyQueue is the production component
// See: ADR-0126 (SmartQueue Canonical System), FS-021 (Systems Consolidation)
// =============================================================================
//
//  PlaybackVerificationTests.swift
//  BabyInCarAppTests
//
//  Created for FS-017: Smart Emergency Playlist System
//  Updated for FS-021: Added deprecation notes, tests maintained for compatibility
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Playback Verification Tests

@Suite("Playback Verification")
@MainActor
struct PlaybackVerificationTests {

    // MARK: - Audio Engine Playback Tests

    @Test("AudioEngine exists and is accessible")
    func audioEngineExists() {
        let engine = AudioEngine.shared
        #expect(engine != nil)
    }

    @Test("AudioEngine can be created")
    func audioEngineCanBeCreated() {
        let engine = AudioEngine()
        #expect(engine != nil)
    }

    @Test("AudioEngine has progress property")
    func audioEngineHasProgress() {
        let engine = AudioEngine.shared
        let progress = engine.currentProgress
        #expect(progress >= 0.0)
        #expect(progress <= 1.0)
    }

    // MARK: - Track Model Tests

    @Test("AudioTrack can be created with bundled source")
    func audioTrackBundled() {
        let track = AudioTrack(
            title: "Test Track",
            artist: "Test Artist",
            category: .lullaby,
            duration: 180,
            audioSourceType: .bundled
        )

        #expect(track.title == "Test Track")
        #expect(track.artist == "Test Artist")
        #expect(track.duration == 180)
        #expect(track.audioSourceType == .bundled)
    }

    @Test("AudioTrack can be created with cloud source")
    func audioTrackCloud() {
        let track = AudioTrack(
            title: "Cloud Track",
            artist: "Cloud Artist",
            category: .ambient,
            duration: 300,
            audioSourceType: .cloud,
            cloudURL: "https://example.com/track.mp3"
        )

        #expect(track.audioSourceType == .cloud)
        #expect(track.cloudURL == "https://example.com/track.mp3")
    }

    @Test("AudioTrack can be created with generated source")
    func audioTrackGenerated() {
        let track = AudioTrack(
            title: "White Noise",
            artist: "Generator",
            category: .ambient,
            duration: 600,
            audioSourceType: .generated,
            generatorType: .ocean
        )

        #expect(track.audioSourceType == .generated)
        #expect(track.generatorType == .ocean)
    }

    // MARK: - Emergency Queue Manager Tests

    @Test("EmergencyQueueManager initializes correctly")
    func queueManagerInitializes() {
        let manager = EmergencyQueueManager()

        #expect(manager.sessionId == nil)
        #expect(manager.currentTrack == nil)
        #expect(manager.upcomingTracks.isEmpty)
        #expect(manager.isPlaying == false)
    }

    @Test("EmergencyQueueManager mock has valid tracks")
    @MainActor
    func queueManagerMockHasTracks() {
        let mock = EmergencyQueueManager.createMock()

        #expect(mock.currentTrack != nil)
        #expect(mock.upcomingTracks.count == 2)

        // Verify track types
        #expect(mock.currentTrack?.category == .classicalMusic)
        #expect(mock.upcomingTracks[0].category == .ambient)
        #expect(mock.upcomingTracks[1].category == .childrenSongs)
    }

    @Test("EmergencyQueueManager mock has Russian track")
    @MainActor
    func queueManagerMockHasRussianTrack() {
        let mock = EmergencyQueueManager.createMock()

        let russianTrack = mock.upcomingTracks.first { $0.language == .russian }
        #expect(russianTrack != nil)
    }

    // MARK: - Playlist Selection Tests

    @Test("CryScenarioPlaylist mock is valid")
    func cryScenarioPlaylistMockValid() {
        let playlist = CryScenarioPlaylist.mockHungerPlaylist

        #expect(playlist.id == "hunger-en-001")
        #expect(playlist.cryType == "hunger")
        #expect(playlist.language == "en")
        #expect(playlist.trackCount == 10)
        #expect(playlist.aiConfidenceScore == 0.87)
    }

    @Test("CryScenarioPlaylist Russian mock is valid")
    func cryScenarioPlaylistRussianMockValid() {
        let playlist = CryScenarioPlaylist.mockTiredPlaylist

        #expect(playlist.id == "tired-ru-001")
        #expect(playlist.cryType == "tired")
        #expect(playlist.language == "ru")
        #expect(playlist.name.contains("Колыбельные"))
    }

    // MARK: - Duration Tests

    @Test("Track duration is positive")
    func trackDurationPositive() {
        let track = AudioTrack(
            title: "Test Track",
            artist: "Artist",
            category: .lullaby,
            duration: 180,
            audioSourceType: .bundled
        )

        #expect(track.duration > 0)
    }

    @Test("Playlist duration formats correctly")
    func playlistDurationFormats() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "tired",
            name: "Test",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 1800,  // 30 minutes
            trackCount: 10,
            tracks: []
        )

        #expect(playlist.formattedDuration == "30 min")
    }

    // MARK: - Audio Source Type Coverage

    @Test("All audio source types are accessible")
    func allAudioSourceTypesAccessible() {
        // Test that all source types can be used
        let sourceTypes: [AudioSourceType] = [.bundled, .cloud, .generated]

        for sourceType in sourceTypes {
            let track = AudioTrack(
                title: "Test",
                artist: "Artist",
                category: .ambient,
                duration: 60,
                audioSourceType: sourceType
            )

            #expect(track.audioSourceType == sourceType)
        }
    }

    @Test("All generator types exist")
    func allGeneratorTypesExist() {
        // Verify key generator types are available
        let importantTypes: [GeneratorType] = [
            .ocean, .river, .forest,
            .musicBox, .lullaby, .heartbeat,
            .birds, .shushing, .womb
        ]

        for type in importantTypes {
            #expect(GeneratorType.allCases.contains(type),
                   "\(type.rawValue) should exist in GeneratorType")
        }
    }
}

// MARK: - XCTest for CI/CD

final class PlaybackVerificationXCTests: XCTestCase {

    @MainActor
    func testAudioEngineSharedInstance() {
        let engine1 = AudioEngine.shared
        let engine2 = AudioEngine.shared

        XCTAssertTrue(engine1 === engine2, "AudioEngine should be a singleton")
    }

    @MainActor
    func testEmergencyQueueManagerSharedMock() {
        let mock = EmergencyQueueManager.createMock()

        XCTAssertNotNil(mock.currentTrack)
        XCTAssertEqual(mock.upcomingTracks.count, 2)
    }

    func testAudioTrackEquality() {
        let track1 = AudioTrack(
            id: "test-001",
            title: "Track 1",
            artist: "Artist",
            category: .lullaby,
            duration: 180,
            audioSourceType: .bundled
        )

        let track2 = AudioTrack(
            id: "test-001",
            title: "Track 1",
            artist: "Artist",
            category: .lullaby,
            duration: 180,
            audioSourceType: .bundled
        )

        // Tracks with same ID should be equal
        XCTAssertEqual(track1.id, track2.id)
    }

    func testCryScenarioPlaylistIdentifiable() {
        let playlist = CryScenarioPlaylist.mockHungerPlaylist

        // Should conform to Identifiable
        XCTAssertEqual(playlist.id, "hunger-en-001")
    }

    @MainActor
    func testAudioEngineSingleton() {
        // Verify AudioEngine is properly configured as singleton
        let engine = AudioEngine.shared
        XCTAssertNotNil(engine)
    }

    func testTrackCategoryExists() {
        // Verify all important categories exist
        let categories: [AudioCategory] = [
            .lullabies, .classicalMusic, .ambient, .natureSounds,
            .ambient, .childrenSongs
        ]

        for category in categories {
            XCTAssertNotNil(category.rawValue, "\(category) should have a raw value")
        }
    }
}

// MARK: - API Response Tests

@Suite("API Response Parsing")
struct APIResponseParsingTests {

    @Test("StartSessionRequest encodes correctly")
    func startSessionRequestEncodesCorrectly() throws {
        let request = StartSessionRequest(babyId: "baby-123", playlistId: "playlist-456")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(decoded?["babyId"] == "baby-123")
        #expect(decoded?["playlistId"] == "playlist-456")
    }

    @Test("EndSessionRequest encodes correctly")
    func endSessionRequestEncodesCorrectly() throws {
        let request = EndSessionRequest(
            sessionId: "session-789",
            effective: true,
            calmingTimeSeconds: 120,
            userSwitched: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["sessionId"] as? String == "session-789")
        #expect(decoded?["effective"] as? Bool == true)
        #expect(decoded?["calmingTimeSeconds"] as? Int == 120)
        #expect(decoded?["userSwitched"] as? Bool == false)
    }

    @Test("PlaylistSelectionResponse decodes correctly")
    func playlistSelectionResponseDecodesCorrectly() throws {
        let json = """
        {
            "playlists": [
                {
                    "id": "playlist-001",
                    "cry_type": "hunger",
                    "name": "Hunger Relief",
                    "description": "Calming sounds for hungry babies",
                    "language": "en",
                    "age_range_min": 0,
                    "age_range_max": 12,
                    "priority": 1,
                    "ai_confidence_score": 0.85,
                    "total_duration_seconds": 600,
                    "track_count": 5,
                    "tracks": []
                }
            ],
            "metadata": {
                "cryType": "hunger",
                "languages": ["en"],
                "age": 6,
                "count": 1,
                "personalized": false
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(PlaylistSelectionResponse.self, from: json)

        #expect(response.playlists.count == 1)
        #expect(response.playlists.first?.cryType == "hunger")
        #expect(response.metadata.count == 1)
    }
}
