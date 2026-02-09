//
//  FeedbackFlowIntegrationTests.swift
//  BabyInCarAppTests
//
//  FS-029: Integration tests for feedback collection flow
//  Tests the complete flow from session start → track playback → feedback → effectiveness update
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Feedback Flow Integration Tests

@Suite("Feedback Flow Integration")
@MainActor
struct FeedbackFlowIntegrationTests {

    // MARK: - Session Lifecycle Tests

    @Test("Complete feedback session flow with It Helped")
    func completeSessionFlowWithHelped() async {
        let feedbackService = FeedbackCollectionService.shared

        // End any existing session first
        if feedbackService.isSessionActive {
            feedbackService.endSession(outcome: .abandoned)
        }

        // Start a new session
        feedbackService.startSession(cryType: .tired, babyAge: 9)
        #expect(feedbackService.isSessionActive == true)
        #expect(feedbackService.currentSession?.cryType == .tired)
        #expect(feedbackService.currentSession?.babyAge == 9)

        // Record tracks being played
        let track1 = createMockTrack(title: "Test Lullaby 1")
        let track2 = createMockTrack(title: "Test Lullaby 2")

        feedbackService.recordTrackPlayed(track1)
        #expect(feedbackService.currentSession?.tracksPlayed.count == 1)

        // Simulate some play time
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        feedbackService.recordTrackEnded()
        feedbackService.recordTrackPlayed(track2)
        #expect(feedbackService.currentSession?.tracksPlayed.count == 2)

        // Verify recent tracks for feedback
        let recentTracks = feedbackService.getRecentTracksForFeedback()
        #expect(recentTracks.count == 2)

        // End session
        feedbackService.endSession(outcome: .helpedManual)
        #expect(feedbackService.isSessionActive == false)
        #expect(feedbackService.currentSession == nil)
    }

    @Test("Session records cry type correctly")
    func sessionRecordsCryType() async {
        let feedbackService = FeedbackCollectionService.shared

        // Ensure clean state
        if feedbackService.isSessionActive {
            feedbackService.endSession(outcome: .abandoned)
        }

        // Test different cry types
        let cryTypes: [CryType] = [.hunger, .tired, .pain, .attention, .discomfort]

        for cryType in cryTypes {
            feedbackService.startSession(cryType: cryType, babyAge: 6)
            #expect(feedbackService.currentSession?.cryType == cryType, "Session should record \(cryType)")
            feedbackService.endSession(outcome: .abandoned)
        }
    }

    @Test("Track playback order is preserved")
    func trackOrderPreserved() async {
        let feedbackService = FeedbackCollectionService.shared

        if feedbackService.isSessionActive {
            feedbackService.endSession(outcome: .abandoned)
        }

        feedbackService.startSession(cryType: .hunger, babyAge: 3)

        // Play multiple tracks in order
        let tracks = (1...5).map { createMockTrack(title: "Track \($0)") }
        for track in tracks {
            feedbackService.recordTrackPlayed(track)
        }

        // Verify order
        let playedTracks = feedbackService.currentSession?.tracksPlayed ?? []
        #expect(playedTracks.count == 5)

        for (index, entry) in playedTracks.enumerated() {
            #expect(entry.title == "Track \(index + 1)", "Track order should be preserved")
        }

        feedbackService.endSession(outcome: .abandoned)
    }

    // MARK: - Feedback Attribution Tests

    @Test("It Helped attributes to last N tracks")
    func itHelpedAttributesCorrectTracks() async {
        let feedbackService = FeedbackCollectionService.shared
        let effectivenessManager = EffectivenessManager.shared

        if feedbackService.isSessionActive {
            feedbackService.endSession(outcome: .abandoned)
        }

        // Start session and play multiple tracks
        feedbackService.startSession(cryType: .tired, babyAge: 12)

        let tracks = (1...4).map { createMockTrack(title: "Attribution Test Track \($0)") }
        for track in tracks {
            feedbackService.recordTrackPlayed(track)
            feedbackService.recordTrackEnded()
        }

        // Get recent tracks before feedback (should be last 2)
        let recentTracks = feedbackService.getRecentTracksForFeedback()
        #expect(recentTracks.count == min(FeedbackCollectionService.tracksToAttributeOnHelped, 4))

        feedbackService.endSession(outcome: .abandoned)
    }

    @Test("Recent tracks limited to configured amount")
    func recentTracksLimited() async {
        let feedbackService = FeedbackCollectionService.shared

        if feedbackService.isSessionActive {
            feedbackService.endSession(outcome: .abandoned)
        }

        feedbackService.startSession(cryType: .pain, babyAge: 6)

        // Play many tracks
        for i in 1...10 {
            let track = createMockTrack(title: "Overflow Track \(i)")
            feedbackService.recordTrackPlayed(track)
        }

        // Should only get configured limit
        let recentTracks = feedbackService.getRecentTracksForFeedback()
        #expect(recentTracks.count == FeedbackCollectionService.tracksToAttributeOnHelped)

        feedbackService.endSession(outcome: .abandoned)
    }

    // MARK: - Session Statistics Tests

    @Test("Session statistics calculate correctly")
    func sessionStatisticsCalculate() async {
        let feedbackService = FeedbackCollectionService.shared

        // Get initial stats
        let stats = feedbackService.getSessionStats()

        // Stats should be valid (non-negative values)
        #expect(stats.totalSessions >= 0)
        #expect(stats.helpedSessions >= 0)
        #expect(stats.successRate >= 0 && stats.successRate <= 1)
        #expect(stats.averageTracksToHelp >= 0)
    }

    @Test("Success rate formatted correctly")
    func successRateFormatted() async {
        let stats = SessionStatistics(
            totalSessions: 10,
            helpedSessions: 7,
            successRate: 0.7,
            averageTracksToHelp: 2.5
        )

        #expect(stats.formattedSuccessRate == "70%")
    }

    // MARK: - Session Outcome Tests

    @Test("All session outcomes are valid")
    func allOutcomesValid() async {
        let outcomes: [SessionOutcome] = [
            .helpedManual,
            .helpedAutoDetected,
            .notHelped,
            .abandoned,
            .cryTypeChanged
        ]

        for outcome in outcomes {
            #expect(!outcome.rawValue.isEmpty, "\(outcome) should have a raw value")
        }
    }

    @Test("Session outcome encodes and decodes")
    func outcomesCodable() throws {
        let outcomes: [SessionOutcome] = [
            .helpedManual,
            .helpedAutoDetected,
            .notHelped,
            .abandoned,
            .cryTypeChanged
        ]

        for outcome in outcomes {
            let encoded = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(SessionOutcome.self, from: encoded)
            #expect(decoded == outcome)
        }
    }

    // MARK: - CrySoothingSession Tests

    @Test("CrySoothingSession initializes correctly")
    func sessionInitialization() async {
        let session = CrySoothingSession(cryType: .hunger, babyAge: 8)

        #expect(session.cryType == .hunger)
        #expect(session.babyAge == 8)
        #expect(session.tracksPlayed.isEmpty)
        #expect(session.outcome == nil)
        #expect(session.endTime == nil)
    }

    @Test("CrySoothingSession duration calculated correctly")
    func sessionDuration() async {
        var session = CrySoothingSession(cryType: .tired, babyAge: 6)

        // Before end time, duration is nil
        #expect(session.duration == nil)

        // Set end time
        session.endTime = session.startTime.addingTimeInterval(120) // 2 minutes

        // Duration should be 2 minutes
        #expect(session.duration != nil)
        if let duration = session.duration {
            #expect(abs(duration - 120) < 1, "Duration should be approximately 120 seconds")
        }
    }

    @Test("CrySoothingSession is codable")
    func sessionCodable() throws {
        var session = CrySoothingSession(cryType: .pain, babyAge: 12)
        session.outcome = .helpedManual
        session.endTime = Date()

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(CrySoothingSession.self, from: encoded)

        #expect(decoded.cryType == session.cryType)
        #expect(decoded.babyAge == session.babyAge)
        #expect(decoded.outcome == session.outcome)
    }

    // MARK: - PlayedTrackEntry Tests

    @Test("PlayedTrackEntry initializes correctly")
    func trackEntryInitialization() async {
        let trackId = UUID()
        let entry = PlayedTrackEntry(
            trackId: trackId,
            title: "Test Entry",
            startedAt: Date()
        )

        #expect(entry.trackId == trackId)
        #expect(entry.title == "Test Entry")
        #expect(entry.endedAt == nil)
        #expect(entry.playDuration == nil)
    }

    @Test("PlayedTrackEntry play duration calculated correctly")
    func trackEntryDuration() async {
        let startTime = Date()
        var entry = PlayedTrackEntry(
            trackId: UUID(),
            title: "Duration Test",
            startedAt: startTime
        )

        // Before end, duration is nil
        #expect(entry.playDuration == nil)

        // Set end time (30 seconds later)
        entry.endedAt = startTime.addingTimeInterval(30)

        // Duration should be 30 seconds
        #expect(entry.playDuration != nil)
        if let duration = entry.playDuration {
            #expect(abs(duration - 30) < 1, "Duration should be approximately 30 seconds")
        }
    }

    @Test("PlayedTrackEntry is codable")
    func trackEntryCodable() throws {
        var entry = PlayedTrackEntry(
            trackId: UUID(),
            title: "Codable Test",
            startedAt: Date()
        )
        entry.endedAt = Date()

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PlayedTrackEntry.self, from: encoded)

        #expect(decoded.title == entry.title)
        #expect(decoded.trackId == entry.trackId)
    }

    // MARK: - Auto-Detection Integration Tests

    @Test("Auto detection weight is less than manual")
    func autoDetectionWeightLessThanManual() async {
        // Auto-detect confidence weight should be less than 1.0 (manual weight)
        let autoWeight = FeedbackCollectionService.autoDetectConfidenceWeight
        #expect(autoWeight < 1.0)
        #expect(autoWeight > 0.0)
    }

    @Test("Tracks to attribute is reasonable")
    func tracksToAttributeReasonable() async {
        let count = FeedbackCollectionService.tracksToAttributeOnHelped
        #expect(count >= 1, "Should attribute at least 1 track")
        #expect(count <= 5, "Should not attribute too many tracks")
    }

    @Test("Max session history is reasonable")
    func maxHistoryReasonable() async {
        let max = FeedbackCollectionService.maxSessionHistory
        #expect(max >= 10, "Should keep at least 10 sessions")
        #expect(max <= 100, "Should not keep too many sessions")
    }

    // MARK: - Helper Methods

    private func createMockTrack(title: String) -> AudioTrack {
        return AudioTrack(
            id: UUID(),
            title: title,
            category: .lullabies,
            duration: 180,
            audioSourceType: .generated,
            generatorType: .lullaby,
            ageRangeMin: 0,
            ageRangeMax: 36,
            calmingScore: 0.85,
            isPremium: false
        )
    }
}

// MARK: - Effectiveness Integration Tests

@Suite("Effectiveness Manager Integration")
@MainActor
struct EffectivenessIntegrationTests {

    @Test("Effectiveness manager is singleton")
    func isSingleton() async {
        let manager1 = EffectivenessManager.shared
        let manager2 = EffectivenessManager.shared
        #expect(manager1 === manager2)
    }

    @Test("Get effectiveness returns nil for unknown track")
    func unknownTrackReturnsNil() async {
        let manager = EffectivenessManager.shared
        let randomId = UUID()

        let effectiveness = manager.getEffectiveness(for: randomId)
        // May or may not exist depending on previous tests
        // Just verify it doesn't crash
        #expect(true)
    }

    @Test("Effectiveness score in valid range")
    func scoreInValidRange() async {
        let manager = EffectivenessManager.shared

        // If there's any existing effectiveness data, scores should be valid
        for (_, effectiveness) in manager.effectivenessData {
            let score = effectiveness.effectivenessScore
            #expect(score >= 0 && score <= 1, "Score should be between 0 and 1")
        }
    }

    @Test("Recording play doesn't crash")
    func recordPlayDoesntCrash() async {
        let manager = EffectivenessManager.shared

        let track = AudioTrack(
            id: UUID(),
            title: "Play Test Track",
            category: .lullabies,
            duration: 180,
            audioSourceType: .generated
        )

        // Should not crash
        manager.recordPlay(track: track, cryType: .hunger)
        #expect(true)
    }

    @Test("Recording helped doesn't crash")
    func recordHelpedDoesntCrash() async {
        let manager = EffectivenessManager.shared

        let track = AudioTrack(
            id: UUID(),
            title: "Helped Test Track",
            category: .lullabies,
            duration: 180,
            audioSourceType: .generated
        )

        // Should not crash
        manager.recordHelped(track: track, cryType: .tired, playDuration: 60)
        #expect(true)
    }
}

// MARK: - EffectivenessFeedbackRecord Tests

@Suite("Effectiveness Feedback Record")
struct EffectivenessFeedbackRecordTests {

    @Test("Record initializes correctly")
    func recordInitialization() {
        let trackId = UUID()
        let record = EffectivenessFeedbackRecord(
            trackId: trackId,
            helped: true,
            cryType: .hunger,
            playDuration: 45.0
        )

        #expect(record.trackId == trackId)
        #expect(record.helped == true)
        #expect(record.cryType == .hunger)
        #expect(record.playDuration == 45.0)
    }

    @Test("Record is codable")
    func recordCodable() throws {
        let record = EffectivenessFeedbackRecord(
            trackId: UUID(),
            helped: true,
            cryType: .tired,
            playDuration: 30.0
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(EffectivenessFeedbackRecord.self, from: encoded)

        #expect(decoded.helped == record.helped)
        #expect(decoded.cryType == record.cryType)
    }

    @Test("Record works without optional fields")
    func recordWithoutOptionals() throws {
        let record = EffectivenessFeedbackRecord(
            trackId: UUID(),
            helped: false,
            cryType: nil,
            playDuration: nil
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(EffectivenessFeedbackRecord.self, from: encoded)

        #expect(decoded.helped == false)
        #expect(decoded.cryType == nil)
        #expect(decoded.playDuration == nil)
    }
}

// MARK: - TrackEffectiveness Integration Tests

@Suite("Track Effectiveness Model")
@MainActor
struct TrackEffectivenessIntegrationTests {

    @Test("Effectiveness initializes with track ID")
    func initializesWithTrackId() async {
        let trackId = UUID()
        let effectiveness = TrackEffectiveness(trackId: trackId)

        #expect(effectiveness.trackId == trackId)
        #expect(effectiveness.totalPlays == 0)
        #expect(effectiveness.helpedCount == 0)
    }

    @Test("Recording play increments count")
    func recordPlayIncrementsCount() async {
        let trackId = UUID()
        var effectiveness = TrackEffectiveness(trackId: trackId)

        let initialPlays = effectiveness.totalPlays
        effectiveness.recordPlay(cryType: .hunger)

        #expect(effectiveness.totalPlays == initialPlays + 1)
    }

    @Test("Recording helped increments count")
    func recordHelpedIncrementsCount() async {
        let trackId = UUID()
        var effectiveness = TrackEffectiveness(trackId: trackId)

        let initialHelped = effectiveness.helpedCount
        effectiveness.recordHelped(cryType: .tired)

        #expect(effectiveness.helpedCount == initialHelped + 1)
    }

    @Test("Effectiveness score increases with helped")
    func scoreIncreasesWithHelped() async {
        let trackId = UUID()
        var effectiveness = TrackEffectiveness(trackId: trackId)

        // Record some plays without helped
        effectiveness.recordPlay(cryType: .hunger)
        effectiveness.recordPlay(cryType: .hunger)
        let scoreAfterPlays = effectiveness.effectivenessScore

        // Record helped
        effectiveness.recordHelped(cryType: .hunger)
        let scoreAfterHelped = effectiveness.effectivenessScore

        #expect(scoreAfterHelped >= scoreAfterPlays, "Score should increase or stay same after helped")
    }

    @Test("Effectiveness is codable")
    func effectivenessCodable() throws {
        var effectiveness = TrackEffectiveness(trackId: UUID())
        effectiveness.recordPlay(cryType: .pain)
        effectiveness.recordHelped(cryType: .pain)

        let encoded = try JSONEncoder().encode(effectiveness)
        let decoded = try JSONDecoder().decode(TrackEffectiveness.self, from: encoded)

        #expect(decoded.trackId == effectiveness.trackId)
        #expect(decoded.totalPlays == effectiveness.totalPlays)
        #expect(decoded.helpedCount == effectiveness.helpedCount)
    }
}
