//
//  CryScenarioPlaylist.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import Foundation

/// Represents a pre-configured playlist optimized for specific cry scenarios
struct CryScenarioPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let cryType: String  // "hunger", "tired", "pain", "discomfort", "attention", "general"
    let name: String
    let description: String?
    let language: String  // "en", "ru", "multi"
    let ageRangeMin: Int
    let ageRangeMax: Int
    let priority: Int
    let aiConfidenceScore: Double
    let totalDurationSeconds: Int
    let trackCount: Int
    var tracks: [AudioTrack]

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, priority, tracks
        case cryType = "cry_type"
        case ageRangeMin = "age_range_min"
        case ageRangeMax = "age_range_max"
        case aiConfidenceScore = "ai_confidence_score"
        case totalDurationSeconds = "total_duration_seconds"
        case trackCount = "track_count"
    }

    /// Checks if this playlist is suitable for a given baby age
    func isSuitableForAge(_ ageInMonths: Int) -> Bool {
        return ageInMonths >= ageRangeMin && ageInMonths <= ageRangeMax
    }

    /// Checks if this playlist matches the language preference
    func matchesLanguage(_ preferredLanguages: [String]) -> Bool {
        return language == "multi" || preferredLanguages.contains(language)
    }

    /// Formatted total duration string (e.g., "45 min")
    var formattedDuration: String {
        let minutes = totalDurationSeconds / 60
        return "\(minutes) min"
    }

    /// Confidence score as percentage (e.g., "85%")
    var confidencePercentage: String {
        return String(format: "%.0f%%", aiConfidenceScore * 100)
    }
}

/// Extension for preview/mock data
extension CryScenarioPlaylist {
    static let mockHungerPlaylist = CryScenarioPlaylist(
        id: "hunger-en-001",
        cryType: "hunger",
        name: "Calm & Soothe - Hunger Relief",
        description: "Research-backed tracks proven effective for hunger-related crying",
        language: "en",
        ageRangeMin: 0,
        ageRangeMax: 12,
        priority: 1,
        aiConfidenceScore: 0.87,
        totalDurationSeconds: 1200,
        trackCount: 10,
        tracks: []
    )

    static let mockTiredPlaylist = CryScenarioPlaylist(
        id: "tired-ru-001",
        cryType: "tired",
        name: "Колыбельные для сна",
        description: "Russian lullabies for tired babies",
        language: "ru",
        ageRangeMin: 0,
        ageRangeMax: 24,
        priority: 2,
        aiConfidenceScore: 0.92,
        totalDurationSeconds: 900,
        trackCount: 8,
        tracks: []
    )
}
