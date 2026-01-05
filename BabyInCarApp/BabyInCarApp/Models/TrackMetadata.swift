//
//  TrackMetadata.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import Foundation

/// Rich metadata for AI-driven playlist selection
struct TrackMetadata: Codable, Equatable {
    let trackId: String
    let crySuitability: [String: Double]?  // {"hunger": 0.9, "tired": 0.7, "pain": 0.6}
    let acousticFeatures: AcousticFeatures?
    let researchCitations: String?
    let emotionalTags: String?  // Comma-separated: "calming,soothing,peaceful"
    let culturalContext: String?  // "Russian lullaby", "Western classical", etc.
    let recommendedAgeMonths: [Int]?

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case crySuitability = "cry_suitability"
        case acousticFeatures = "acoustic_features"
        case researchCitations = "research_citations"
        case emotionalTags = "emotional_tags"
        case culturalContext = "cultural_context"
        case recommendedAgeMonths = "recommended_age_months"
    }

    /// Parsed emotional tags as array
    var parsedEmotionalTags: [String] {
        guard let tags = emotionalTags else { return [] }
        return tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// Get suitability score for a specific cry type (0.0 - 1.0)
    func suitabilityScore(for cryType: CryType) -> Double? {
        return crySuitability?[cryType.rawValue]
    }

    /// Check if track is suitable for a given cry type (score >= 0.7)
    func isSuitable(for cryType: CryType, threshold: Double = 0.7) -> Bool {
        guard let score = suitabilityScore(for: cryType) else { return false }
        return score >= threshold
    }

    /// Check if track is recommended for a given age
    func isRecommendedForAge(_ ageInMonths: Int) -> Bool {
        guard let ages = recommendedAgeMonths, !ages.isEmpty else { return true }
        // Find closest age range
        return ages.contains(where: { abs($0 - ageInMonths) <= 6 })
    }
}

/// Acoustic features extracted from audio analysis
struct AcousticFeatures: Codable, Equatable {
    let tempoBpm: Int?
    let key: String?  // "C", "D", "E", etc.
    let mode: String?  // "major", "minor"

    enum CodingKeys: String, CodingKey {
        case tempoBpm = "tempo_bpm"
        case key
        case mode
    }

    /// Formatted tempo string (e.g., "60 BPM - Slow")
    var formattedTempo: String? {
        guard let bpm = tempoBpm else { return nil }
        let category = tempoCategory(bpm: bpm)
        return "\(bpm) BPM - \(category)"
    }

    private func tempoCategory(bpm: Int) -> String {
        switch bpm {
        case 0..<60: return "Very Slow"
        case 60..<80: return "Slow"
        case 80..<120: return "Moderate"
        case 120..<160: return "Fast"
        default: return "Very Fast"
        }
    }
}

/// Extension for mock data
extension TrackMetadata {
    static let mockLullaby = TrackMetadata(
        trackId: "track-001",
        crySuitability: ["hunger": 0.7, "tired": 0.95, "pain": 0.6, "discomfort": 0.8, "attention": 0.5],
        acousticFeatures: AcousticFeatures(tempoBpm: 60, key: "C", mode: "major"),
        researchCitations: "Trehub et al. (2015) - Lullabies and infant affect regulation",
        emotionalTags: "calming,soothing,peaceful",
        culturalContext: "Traditional Western lullaby",
        recommendedAgeMonths: [0, 3, 6, 9, 12]
    )

    static let mockWhiteNoise = TrackMetadata(
        trackId: "track-002",
        crySuitability: ["hunger": 0.8, "tired": 0.9, "pain": 0.7, "discomfort": 0.85, "attention": 0.6],
        acousticFeatures: nil,
        researchCitations: "Spencer et al. (1990) - White noise and sleep induction in newborns",
        emotionalTags: "ambient,continuous,masking",
        culturalContext: "Universal sound therapy",
        recommendedAgeMonths: [0, 1, 2, 3]
    )
}
