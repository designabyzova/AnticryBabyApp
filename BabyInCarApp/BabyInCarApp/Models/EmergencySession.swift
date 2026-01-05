//
//  EmergencySession.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import Foundation

/// Represents an active emergency cry response session for FS-017
struct EmergencyPlaylistSession: Codable, Identifiable {
    let id: String
    let babyId: String
    let playlistId: String
    var currentTrackId: String?
    var queueTracks: [String]  // Array of track IDs in order
    let startedAt: Date
    var endedAt: Date?
    var sessionDurationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id
        case babyId = "baby_id"
        case playlistId = "playlist_id"
        case currentTrackId = "current_track_id"
        case queueTracks = "queue_tracks"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case sessionDurationSeconds = "session_duration_seconds"
    }

    /// Calculate actual duration from start time
    var actualDuration: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    /// Formatted duration string (e.g., "2m 30s")
    var formattedDuration: String {
        let duration = Int(actualDuration)
        let minutes = duration / 60
        let seconds = duration % 60
        return "\(minutes)m \(seconds)s"
    }

    /// Check if session was effective (calmed within 3 minutes)
    var wasEffective: Bool {
        return actualDuration < 180  // 3 minutes
    }

    /// Remaining tracks in queue
    func remainingTracks(after currentIndex: Int) -> [String] {
        guard currentIndex < queueTracks.count else { return [] }
        return Array(queueTracks.dropFirst(currentIndex + 1))
    }

    /// Progress through queue (0.0 - 1.0)
    func progress(currentIndex: Int) -> Double {
        guard !queueTracks.isEmpty else { return 0.0 }
        return Double(currentIndex) / Double(queueTracks.count)
    }
}

/// Request/Response models for API
struct StartSessionRequest: Codable {
    let babyId: String
    let playlistId: String

    enum CodingKeys: String, CodingKey {
        case babyId = "baby_id"
        case playlistId = "playlist_id"
    }
}

struct StartSessionResponse: Codable {
    let sessionId: String
    let queueTracks: [String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case queueTracks = "queue_tracks"
    }
}

struct EndSessionRequest: Codable {
    let sessionId: String
    let effective: Bool
    let calmingTimeSeconds: Int
    let userSwitched: Bool

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case effective
        case calmingTimeSeconds = "calming_time_seconds"
        case userSwitched = "user_switched"
    }
}

struct EndSessionResponse: Codable {
    let success: Bool
    let updatedConfidenceScore: Double?

    enum CodingKeys: String, CodingKey {
        case success
        case updatedConfidenceScore = "updated_confidence_score"
    }
}

/// Extension for mock data
extension EmergencyPlaylistSession {
    static let mockActiveSession = EmergencyPlaylistSession(
        id: "session-001",
        babyId: "baby-001",
        playlistId: "hunger-en-001",
        currentTrackId: "track-001",
        queueTracks: ["track-001", "track-002", "track-003", "track-004", "track-005"],
        startedAt: Date().addingTimeInterval(-120),  // 2 minutes ago
        endedAt: nil,
        sessionDurationSeconds: 0
    )

    static let mockCompletedSession = EmergencyPlaylistSession(
        id: "session-002",
        babyId: "baby-001",
        playlistId: "tired-ru-001",
        currentTrackId: "track-010",
        queueTracks: ["track-008", "track-009", "track-010"],
        startedAt: Date().addingTimeInterval(-300),  // 5 minutes ago
        endedAt: Date().addingTimeInterval(-60),  // ended 1 minute ago
        sessionDurationSeconds: 240
    )
}
