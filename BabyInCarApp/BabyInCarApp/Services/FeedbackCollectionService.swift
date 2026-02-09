//
//  FeedbackCollectionService.swift
//  BabyInCarApp
//
//  Tracks session context for "It Helped!" feedback (FS-029)
//  Records which tracks were playing when cry stopped
//

import Foundation
import Combine

/// Service for collecting "It Helped!" feedback during cry response sessions
/// Tracks session history to attribute effectiveness to specific tracks
@MainActor
class FeedbackCollectionService: ObservableObject {

    // MARK: - Singleton

    static let shared = FeedbackCollectionService()

    // MARK: - Published State

    @Published private(set) var currentSession: CrySoothingSession?
    @Published private(set) var isSessionActive: Bool = false

    // MARK: - Configuration

    /// Number of recent tracks to attribute when "It Helped!" is tapped
    static let tracksToAttributeOnHelped = 2

    /// Maximum session history to keep
    static let maxSessionHistory = 20

    /// Auto-detect weight (vs manual feedback weight of 1.0)
    static let autoDetectConfidenceWeight: Double = 0.7

    // MARK: - Private State

    private var sessionHistory: [CrySoothingSession] = []

    // MARK: - Dependencies

    private let effectivenessManager = EffectivenessManager.shared

    private init() {
        loadSessionHistory()
    }

    // MARK: - Session Lifecycle

    /// Start a new cry soothing session
    func startSession(cryType: CryType, babyAge: Int) {
        let session = CrySoothingSession(
            cryType: cryType,
            babyAge: babyAge
        )
        currentSession = session
        isSessionActive = true

        print("[FeedbackCollection] 🎬 Started session for \(cryType.displayName)")
    }

    /// End the current session
    func endSession(outcome: SessionOutcome) {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.outcome = outcome
        sessionHistory.append(session)

        // Trim history
        if sessionHistory.count > Self.maxSessionHistory {
            sessionHistory.removeFirst(sessionHistory.count - Self.maxSessionHistory)
        }

        saveSessionHistory()

        print("[FeedbackCollection] 🏁 Ended session: \(outcome.rawValue), \(session.tracksPlayed.count) tracks played")

        currentSession = nil
        isSessionActive = false
    }

    // MARK: - Track Recording

    /// Record that a track started playing
    func recordTrackPlayed(_ track: AudioTrack) {
        guard currentSession != nil else { return }

        let entry = PlayedTrackEntry(
            trackId: track.id,
            title: track.title,
            startedAt: Date()
        )

        currentSession?.tracksPlayed.append(entry)

        print("[FeedbackCollection] 🎵 Recorded track: \(track.title)")
    }

    /// Update the end time for the last played track
    func recordTrackEnded() {
        guard currentSession != nil,
              var lastTrack = currentSession?.tracksPlayed.last else { return }

        lastTrack.endedAt = Date()

        // Update the last track in the array
        if let lastIndex = currentSession?.tracksPlayed.indices.last {
            currentSession?.tracksPlayed[lastIndex] = lastTrack
        }
    }

    // MARK: - Feedback Recording

    /// Record "It Helped!" manual feedback
    /// Attributes positive effectiveness to the last N tracks
    func recordItHelped() {
        guard let session = currentSession else {
            print("[FeedbackCollection] ⚠️ No active session for feedback")
            return
        }

        // Get the last N tracks played
        let recentTracks = Array(session.tracksPlayed.suffix(Self.tracksToAttributeOnHelped))

        guard !recentTracks.isEmpty else {
            print("[FeedbackCollection] ⚠️ No tracks played to attribute")
            return
        }

        // Record effectiveness for each track
        for trackEntry in recentTracks {
            // Create a minimal AudioTrack for the effectiveness manager
            let track = AudioTrack(
                id: trackEntry.trackId,
                title: trackEntry.title,
                category: .lullabies,
                duration: 180,
                audioSourceType: .streamed
            )

            effectivenessManager.recordHelped(
                track: track,
                cryType: session.cryType,
                playDuration: trackEntry.playDuration
            )
        }

        print("[FeedbackCollection] ✅ Recorded 'It Helped!' for \(recentTracks.count) tracks")

        // Update session outcome
        endSession(outcome: .helpedManual)
    }

    /// Record "Still Crying" feedback
    func recordStillCrying() {
        guard let session = currentSession else { return }

        // Get the last track played (if any)
        if let lastTrack = session.tracksPlayed.last {
            let track = AudioTrack(
                id: lastTrack.trackId,
                title: lastTrack.title,
                category: .lullabies,
                duration: 180,
                audioSourceType: .streamed
            )

            effectivenessManager.recordDidNotHelp(
                track: track,
                cryType: session.cryType
            )
        }

        print("[FeedbackCollection] 😢 Recorded 'Still Crying'")

        // Don't end session - let user continue trying other tracks
    }

    /// Record auto-detected cry stop
    /// Called when audio monitoring detects crying has stopped
    func recordAutoDetectedStop(confirmed: Bool) {
        guard let session = currentSession else { return }

        if confirmed {
            // User confirmed the auto-detection
            let recentTracks = Array(session.tracksPlayed.suffix(Self.tracksToAttributeOnHelped))

            for trackEntry in recentTracks {
                let track = AudioTrack(
                    id: trackEntry.trackId,
                    title: trackEntry.title,
                    category: .lullabies,
                    duration: 180,
                    audioSourceType: .streamed
                )

                // Use lower confidence weight for auto-detected
                effectivenessManager.recordHelped(
                    track: track,
                    cryType: session.cryType,
                    playDuration: (trackEntry.playDuration ?? 0) * Self.autoDetectConfidenceWeight
                )
            }

            print("[FeedbackCollection] ✅ Recorded auto-detected stop (confirmed)")
            endSession(outcome: .helpedAutoDetected)
        } else {
            // User dismissed the auto-detection prompt
            print("[FeedbackCollection] 🔄 Auto-detected stop dismissed")
            // Continue session
        }
    }

    // MARK: - Query Methods

    /// Get recent tracks from current session for UI display
    func getRecentTracksForFeedback() -> [PlayedTrackEntry] {
        return Array(currentSession?.tracksPlayed.suffix(Self.tracksToAttributeOnHelped) ?? [])
    }

    /// Get session statistics
    func getSessionStats() -> SessionStatistics {
        let helpedSessions = sessionHistory.filter { $0.outcome == .helpedManual || $0.outcome == .helpedAutoDetected }
        let totalSessions = sessionHistory.count

        return SessionStatistics(
            totalSessions: totalSessions,
            helpedSessions: helpedSessions.count,
            successRate: totalSessions > 0 ? Double(helpedSessions.count) / Double(totalSessions) : 0,
            averageTracksToHelp: calculateAverageTracksToHelp()
        )
    }

    private func calculateAverageTracksToHelp() -> Double {
        let helpedSessions = sessionHistory.filter { $0.outcome == .helpedManual || $0.outcome == .helpedAutoDetected }
        guard !helpedSessions.isEmpty else { return 0 }

        let totalTracks = helpedSessions.reduce(0) { $0 + $1.tracksPlayed.count }
        return Double(totalTracks) / Double(helpedSessions.count)
    }

    // MARK: - Persistence

    private func saveSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: "FeedbackCollection_Sessions")
        }
    }

    private func loadSessionHistory() {
        if let data = UserDefaults.standard.data(forKey: "FeedbackCollection_Sessions"),
           let history = try? JSONDecoder().decode([CrySoothingSession].self, from: data) {
            sessionHistory = history
        }
    }
}

// MARK: - Supporting Types

/// A cry soothing session from detection to outcome
struct CrySoothingSession: Codable {
    let id: UUID
    let cryType: CryType
    let babyAge: Int
    let startTime: Date
    var endTime: Date?
    var tracksPlayed: [PlayedTrackEntry]
    var outcome: SessionOutcome?

    init(cryType: CryType, babyAge: Int) {
        self.id = UUID()
        self.cryType = cryType
        self.babyAge = babyAge
        self.startTime = Date()
        self.tracksPlayed = []
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}

/// A track that was played during a session
struct PlayedTrackEntry: Codable, Identifiable {
    let id: UUID
    let trackId: UUID
    let title: String
    let startedAt: Date
    var endedAt: Date?

    init(trackId: UUID, title: String, startedAt: Date) {
        self.id = UUID()
        self.trackId = trackId
        self.title = title
        self.startedAt = startedAt
    }

    var playDuration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}

/// Outcome of a cry soothing session
enum SessionOutcome: String, Codable {
    case helpedManual = "helped_manual"           // User tapped "It Helped!"
    case helpedAutoDetected = "helped_auto"       // Auto-detected and confirmed
    case notHelped = "not_helped"                 // User indicated still crying
    case abandoned = "abandoned"                  // Session ended without feedback
    case cryTypeChanged = "cry_type_changed"      // Cry type changed, new session started
}

/// Statistics about feedback sessions
struct SessionStatistics {
    let totalSessions: Int
    let helpedSessions: Int
    let successRate: Double
    let averageTracksToHelp: Double

    var formattedSuccessRate: String {
        return String(format: "%.0f%%", successRate * 100)
    }
}
