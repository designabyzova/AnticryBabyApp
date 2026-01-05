//
//  TrackEffectiveness.swift
//  BabyInCarApp
//
//  Data model for tracking track effectiveness feedback
//  Persists locally to help parents find what works for their baby
//

import Foundation

// MARK: - Track Effectiveness Model

/// Tracks how effective a specific audio track has been at calming the baby
struct TrackEffectiveness: Codable, Identifiable, Hashable {
    /// The track ID this effectiveness data relates to
    let id: UUID

    /// Number of times the user marked "It Helped!"
    var helpedCount: Int

    /// Total number of times this track was played
    var totalPlays: Int

    /// Breakdown of effectiveness by cry type
    var cryTypeBreakdown: [String: CryTypeStats]

    /// When the track last helped calm the baby
    var lastHelped: Date?

    /// When effectiveness tracking started for this track
    let firstRecorded: Date

    /// Calculated effectiveness score (0-100%)
    var effectivenessScore: Double {
        guard totalPlays > 0 else { return 0 }
        return min(100, Double(helpedCount) / Double(totalPlays) * 100)
    }

    /// Color tier based on effectiveness score
    var effectivenessTier: EffectivenessTier {
        switch effectivenessScore {
        case 70...100:
            return .high
        case 40..<70:
            return .medium
        default:
            return .low
        }
    }

    /// Human-readable effectiveness description
    var effectivenessDescription: String {
        if totalPlays == 0 {
            return "Not played yet"
        } else if helpedCount == 0 {
            return "No feedback yet"
        } else {
            return "Helped \(helpedCount) of \(totalPlays) times"
        }
    }

    init(
        trackId: UUID,
        helpedCount: Int = 0,
        totalPlays: Int = 0,
        cryTypeBreakdown: [String: CryTypeStats] = [:],
        lastHelped: Date? = nil,
        firstRecorded: Date = Date()
    ) {
        self.id = trackId
        self.helpedCount = helpedCount
        self.totalPlays = totalPlays
        self.cryTypeBreakdown = cryTypeBreakdown
        self.lastHelped = lastHelped
        self.firstRecorded = firstRecorded
    }

    // MARK: - Mutation Methods

    /// Record that the track was played
    mutating func recordPlay(cryType: CryType? = nil) {
        totalPlays += 1

        if let cryType = cryType {
            let key = cryType.rawValue
            var stats = cryTypeBreakdown[key] ?? CryTypeStats()
            stats.totalCount += 1
            cryTypeBreakdown[key] = stats
        }
    }

    /// Record that the track helped calm the baby
    mutating func recordHelped(cryType: CryType? = nil) {
        helpedCount += 1
        lastHelped = Date()

        if let cryType = cryType {
            let key = cryType.rawValue
            var stats = cryTypeBreakdown[key] ?? CryTypeStats()
            stats.helpedCount += 1
            // Also increment totalCount if this is the first record for this cry type
            if stats.totalCount < stats.helpedCount {
                stats.totalCount = stats.helpedCount
            }
            cryTypeBreakdown[key] = stats
        }
    }

    /// Get effectiveness for a specific cry type
    func effectivenessForCryType(_ cryType: CryType) -> Double? {
        guard let stats = cryTypeBreakdown[cryType.rawValue],
              stats.totalCount > 0 else {
            return nil
        }
        return stats.successRate
    }

    /// Get the cry types this track is most effective for
    func topCryTypes(limit: Int = 3) -> [(cryType: String, score: Double)] {
        cryTypeBreakdown
            .filter { $0.value.totalCount >= 2 && $0.value.successRate >= 50 }
            .map { ($0.key, $0.value.successRate) }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }
}

// MARK: - Cry Type Stats

/// Statistics for a specific cry type
struct CryTypeStats: Codable, Hashable {
    /// Number of times the track helped for this cry type
    var helpedCount: Int

    /// Total times played during this cry type
    var totalCount: Int

    /// Success rate for this cry type (0-100%)
    var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return min(100, Double(helpedCount) / Double(totalCount) * 100)
    }

    init(helpedCount: Int = 0, totalCount: Int = 0) {
        self.helpedCount = helpedCount
        self.totalCount = totalCount
    }
}

// MARK: - Effectiveness Tier

/// Visual tier for effectiveness display
enum EffectivenessTier: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .high:
            return "EffectivenessHigh"  // Green
        case .medium:
            return "EffectivenessMedium"  // Yellow/Orange
        case .low:
            return "EffectivenessLow"  // Gray
        }
    }

    var systemColor: String {
        switch self {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "gray"
        }
    }
}

// MARK: - Effectiveness Feedback Record

/// Individual feedback record for analytics and history
struct EffectivenessFeedbackRecord: Codable, Identifiable {
    let id: UUID
    let trackId: UUID
    let timestamp: Date
    let helped: Bool
    let cryType: String?
    let playDuration: TimeInterval?

    init(
        trackId: UUID,
        helped: Bool,
        cryType: CryType? = nil,
        playDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.trackId = trackId
        self.timestamp = Date()
        self.helped = helped
        self.cryType = cryType?.rawValue
        self.playDuration = playDuration
    }
}
