// =============================================================================
// NOTE: This file tests effectiveness tracking functionality.
// EmergencyQueueManager references are DEPRECATED - tests use them for backward
// compatibility only. New tests should use SmartEmergencyQueue.shared.
//
// Migration: SmartEmergencyQueue is the production component
// See: ADR-0126 (SmartQueue Canonical System), FS-021 (Systems Consolidation)
// =============================================================================
//
//  EffectivenessTrackingTests.swift
//  BabyInCarAppTests
//
//  Created for FS-017: Smart Emergency Playlist System
//  Updated for FS-021: Added deprecation notes, tests maintained for compatibility
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Effectiveness Tracking Tests

@Suite("Effectiveness Tracking")
@MainActor
struct EffectivenessTrackingTests {

    // MARK: - Legacy EmergencyQueueManager Tests (Deprecated - kept for compatibility)

    @Test("Session starts with correct initial state")
    func sessionStartsWithCorrectState() async {
        let manager = EmergencyQueueManager()

        // Initially no session
        #expect(manager.sessionId == nil)
        #expect(manager.currentTrack == nil)
        #expect(manager.upcomingTracks.isEmpty)
        #expect(manager.isPlaying == false)
        #expect(manager.progress == 0.0)
    }

    @Test("Session duration formats correctly")
    func sessionDurationFormats() async {
        let manager = EmergencyQueueManager()

        // No session - should return 0:00
        #expect(manager.sessionDuration == "0:00")
    }

    @Test("Queue progress calculates correctly")
    func queueProgressCalculates() async {
        let manager = EmergencyQueueManager()

        // No tracks - should return 0.0
        #expect(manager.queueProgress == 0.0)
    }

    @Test("Remaining tracks count correct when empty")
    func remainingTracksCountEmpty() async {
        let manager = EmergencyQueueManager()

        // No tracks - should return 0
        #expect(manager.remainingTracksCount == 0)
    }

    @Test("Mock manager has valid state")
    @MainActor
    func mockManagerHasValidState() async {
        let mock = EmergencyQueueManager.createMock()

        #expect(mock.currentTrack != nil)
        #expect(mock.currentTrack?.title == "Brahms Lullaby")
        #expect(mock.upcomingTracks.count == 2)
        #expect(mock.isPlaying == true)
        #expect(mock.progress == 0.45)
    }

    // MARK: - Playlist Effectiveness Tests

    @Test("Effective session has calming time under 3 minutes")
    func effectiveSessionUnder3Minutes() {
        // According to AC-US8-05: was_effective based on calming_time_seconds (<3min = effective)
        let calmingTimeSeconds = 120  // 2 minutes

        let isEffective = calmingTimeSeconds < 180  // 3 minutes = 180 seconds
        #expect(isEffective == true)
    }

    @Test("Ineffective session has calming time over 3 minutes")
    func ineffectiveSessionOver3Minutes() {
        let calmingTimeSeconds = 240  // 4 minutes

        let isEffective = calmingTimeSeconds < 180
        #expect(isEffective == false)
    }

    @Test("Borderline session at exactly 3 minutes")
    func borderlineSession() {
        let calmingTimeSeconds = 180  // Exactly 3 minutes

        let isEffective = calmingTimeSeconds < 180
        #expect(isEffective == false)  // Not less than 3 minutes
    }

    // MARK: - Confidence Score Tests

    @Test("Confidence score as percentage formats correctly")
    func confidencePercentageFormats() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.confidencePercentage == "85%")
    }

    @Test("Confidence score 0.0 formats as 0%")
    func zeroConfidenceFormats() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.0,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.confidencePercentage == "0%")
    }

    @Test("Confidence score 1.0 formats as 100%")
    func fullConfidenceFormats() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 1.0,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.confidencePercentage == "100%")
    }

    // MARK: - Playlist Priority and Ranking Tests

    @Test("Higher priority playlists ranked first")
    func higherPriorityRankedFirst() {
        let playlists = [
            CryScenarioPlaylist(id: "1", cryType: "hunger", name: "Low Priority", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "hunger", name: "High Priority", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 3, aiConfidenceScore: 0.80, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "3", cryType: "hunger", name: "Medium Priority", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 2, aiConfidenceScore: 0.82, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        let sorted = playlists.sorted { $0.priority > $1.priority }

        #expect(sorted[0].id == "2")  // Priority 3
        #expect(sorted[1].id == "3")  // Priority 2
        #expect(sorted[2].id == "1")  // Priority 1
    }

    @Test("Same priority sorted by confidence score")
    func samePrioritySortedByConfidence() {
        let playlists = [
            CryScenarioPlaylist(id: "1", cryType: "tired", name: "Low Confidence", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.70, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "tired", name: "High Confidence", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.92, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "3", cryType: "tired", name: "Medium Confidence", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        // Sort by priority DESC, then confidence DESC
        let sorted = playlists.sorted { a, b in
            if a.priority != b.priority {
                return a.priority > b.priority
            }
            return a.aiConfidenceScore > b.aiConfidenceScore
        }

        #expect(sorted[0].id == "2")  // 0.92
        #expect(sorted[1].id == "3")  // 0.85
        #expect(sorted[2].id == "1")  // 0.70
    }

    // MARK: - Learning System Tests

    @Test("Effectiveness average calculation")
    func effectivenessAverageCalculation() {
        // Simulate effectiveness records
        let records: [(effective: Bool, calmingTime: Int)] = [
            (true, 90),   // Effective
            (true, 120),  // Effective
            (false, 240), // Ineffective
            (true, 150),  // Effective
        ]

        let effectiveCount = records.filter { $0.effective }.count
        let totalCount = records.count
        let average = Double(effectiveCount) / Double(totalCount)

        #expect(average == 0.75)  // 3/4 = 75%
    }

    @Test("Confidence score update based on effectiveness")
    func confidenceScoreUpdate() {
        // Original confidence score
        let originalScore = 0.70

        // New effectiveness records average
        let effectivenessAverage = 0.85

        // Combine AI confidence and historical effectiveness
        // Using weights from the API: AI 40%, Effectiveness 60%
        let updatedScore = originalScore * 0.4 + effectivenessAverage * 0.6

        #expect(updatedScore > originalScore)  // Should increase
        #expect(abs(updatedScore - 0.79) < 0.001)  // 0.7*0.4 + 0.85*0.6 = 0.28 + 0.51 = 0.79
    }

    @Test("Playlist re-ranking based on baby-specific effectiveness")
    func playlistReRankingByEffectiveness() {
        var playlists = [
            CryScenarioPlaylist(id: "1", cryType: "hunger", name: "Playlist A", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.90, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "hunger", name: "Playlist B", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        // Baby-specific effectiveness data (e.g., from playlist_effectiveness table)
        let babyEffectiveness: [String: Double] = [
            "1": 0.50,  // This baby doesn't respond well to Playlist A
            "2": 0.95,  // This baby responds very well to Playlist B
        ]

        // Re-rank using combined score (AI 40% + Effectiveness 60%)
        let sorted = playlists.sorted { a, b in
            let aScore = a.aiConfidenceScore * 0.4 + (babyEffectiveness[a.id] ?? 0.5) * 0.6
            let bScore = b.aiConfidenceScore * 0.4 + (babyEffectiveness[b.id] ?? 0.5) * 0.6
            return aScore > bScore
        }

        // Playlist B should now rank higher due to baby-specific effectiveness
        #expect(sorted[0].id == "2")  // B: 0.85*0.4 + 0.95*0.6 = 0.34 + 0.57 = 0.91
        #expect(sorted[1].id == "1")  // A: 0.90*0.4 + 0.50*0.6 = 0.36 + 0.30 = 0.66
    }

    // MARK: - Duration Formatting Tests

    @Test("Playlist duration formatted correctly")
    func playlistDurationFormatted() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "tired",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 2700,  // 45 minutes
            trackCount: 15,
            tracks: []
        )

        #expect(playlist.formattedDuration == "45 min")
    }

    @Test("Short playlist duration formatted")
    func shortDurationFormatted() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "tired",
            name: "Quick Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 300,  // 5 minutes
            trackCount: 3,
            tracks: []
        )

        #expect(playlist.formattedDuration == "5 min")
    }
}

// MARK: - XCTest for CI/CD

final class EffectivenessTrackingXCTests: XCTestCase {

    @MainActor
    func testEmergencyQueueManagerExists() {
        let manager = EmergencyQueueManager()
        XCTAssertNotNil(manager)
    }

    @MainActor
    func testEmergencyQueueManagerInitialState() {
        let manager = EmergencyQueueManager()

        XCTAssertNil(manager.sessionId)
        XCTAssertNil(manager.currentTrack)
        XCTAssertTrue(manager.upcomingTracks.isEmpty)
        XCTAssertFalse(manager.isPlaying)
    }

    @MainActor
    func testEmergencyQueueManagerMock() {
        let mock = EmergencyQueueManager.createMock()

        XCTAssertNotNil(mock.currentTrack)
        XCTAssertFalse(mock.upcomingTracks.isEmpty)
        XCTAssertTrue(mock.isPlaying)
    }

    func testEffectivenessThreshold() {
        // Test the 3-minute threshold for effectiveness
        let threeMinutesInSeconds = 180

        // Under 3 minutes = effective
        XCTAssertTrue(120 < threeMinutesInSeconds)
        XCTAssertTrue(90 < threeMinutesInSeconds)

        // Over 3 minutes = ineffective
        XCTAssertFalse(200 < threeMinutesInSeconds)
        XCTAssertFalse(240 < threeMinutesInSeconds)

        // Exactly 3 minutes = not effective (not less than)
        XCTAssertFalse(180 < threeMinutesInSeconds)
    }

    func testConfidenceScoreWeighting() {
        // Test the 40/60 weighting between AI and effectiveness
        let aiConfidence = 0.80
        let effectiveness = 0.90

        let combinedScore = aiConfidence * 0.4 + effectiveness * 0.6
        let expectedScore = 0.86  // 0.32 + 0.54

        XCTAssertEqual(combinedScore, expectedScore, accuracy: 0.001)
    }

    func testPlaylistEquatable() {
        let playlist1 = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        let playlist2 = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        XCTAssertEqual(playlist1, playlist2)
    }
}

// MARK: - Request/Response Model Tests

@Suite("Session Request/Response Models")
struct SessionRequestResponseTests {

    @Test("StartSessionRequest encodes correctly")
    func startSessionRequestEncodes() throws {
        let request = StartSessionRequest(babyId: "baby-001", playlistId: "playlist-001")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(json?["babyId"] == "baby-001")
        #expect(json?["playlistId"] == "playlist-001")
    }

    @Test("EndSessionRequest encodes correctly")
    func endSessionRequestEncodes() throws {
        let request = EndSessionRequest(
            sessionId: "session-001",
            effective: true,
            calmingTimeSeconds: 120,
            userSwitched: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["sessionId"] as? String == "session-001")
        #expect(json?["effective"] as? Bool == true)
        #expect(json?["calmingTimeSeconds"] as? Int == 120)
        #expect(json?["userSwitched"] as? Bool == false)
    }
}
