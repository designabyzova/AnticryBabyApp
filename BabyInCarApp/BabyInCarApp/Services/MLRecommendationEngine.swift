//
//  MLRecommendationEngine.swift
//  BabyInCarApp
//
//  ML-powered personalized track recommendations
//  Learns what works for each baby and recommends appropriate melodies
//

import Foundation

// MARK: - Recommended Track

/// A track recommendation with score and reasoning
struct RecommendedTrack {
    /// The recommended track
    let track: AudioTrack

    /// Overall recommendation score (0-1)
    let score: Double

    /// Reasons for this recommendation
    let reasons: [RecommendationReason]

    /// Whether this is a high-confidence recommendation
    var isHighConfidence: Bool {
        score > 0.8
    }
}

// MARK: - Recommendation Reason

/// Reasons why a track was recommended
enum RecommendationReason: String, Codable {
    case historicallyEffective = "Worked well before"
    case ageOptimal = "Perfect for baby's age"
    case cryTypeMatch = "Matches current cry pattern"
    case profileMatch = "Matches baby's preferences"
    case highCalmingScore = "High calming potential"
    case similarToFavorite = "Similar to favorites"
    case timeBased = "Works well at this time"
    case categoryPreference = "Preferred category"

    var icon: String {
        switch self {
        case .historicallyEffective: return "checkmark.circle"
        case .ageOptimal: return "star"
        case .cryTypeMatch: return "waveform"
        case .profileMatch: return "person.fill"
        case .highCalmingScore: return "moon.zzz"
        case .similarToFavorite: return "heart"
        case .timeBased: return "clock"
        case .categoryPreference: return "folder"
        }
    }
}

// MARK: - Recommendation Context

/// Context for generating recommendations
enum RecommendationContext: String, Codable {
    case general = "General"
    case sleep = "Sleep Time"
    case crying = "Active Crying"
    case carRide = "Car Ride"
    case emergency = "Emergency"
}

// MARK: - ML Recommendation Engine

/// ML-powered engine for personalized track recommendations
@MainActor
class MLRecommendationEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = MLRecommendationEngine()

    // MARK: - Published State

    /// Current recommendations
    @Published var recommendations: [RecommendedTrack] = []

    /// Whether recommendations are being generated
    @Published var isProcessing: Bool = false

    /// Last recommendation context
    @Published var lastContext: RecommendationContext?

    // MARK: - Dependencies

    private let contentLibrary = ContentLibraryService.shared
    private let profileManager = BabyProfileManager.shared

    // MARK: - Configuration

    /// Minimum score threshold for recommendations
    private let minScoreThreshold: Double = 0.3

    /// Maximum recommendations to return
    private let maxRecommendations = 20

    // MARK: - Cry Type to Track Mapping

    /// Preferred generator types for each cry type at different ages
    private let cryTypePreferences: [CryType: (young: [GeneratorType], older: [GeneratorType])] = [
        .tired: (
            young: [.aquarium, .womb, .heartbeat, .shushing, .aquarium],
            older: [.aquarium, .bells, .aquarium, .aquarium, .lullaby]
        ),
        .hunger: (
            young: [.shushing, .musicBox, .aquarium, .heartbeat],
            older: [.shushing, .musicBox, .aquarium, .chimes]
        ),
        .pain: (
            young: [.shushing, .womb, .shushing, .aquarium, .womb],
            older: [.aquarium, .lullaby, .aquarium, .shushing]
        ),
        .attention: (
            young: [.musicBox, .chimes, .chimes, .heartbeat],
            older: [.aquarium, .bells, .softPiano, .musicBox]
        ),
        .discomfort: (
            young: [.aquarium, .womb, .shushing, .heartbeat],
            older: [.aquarium, .aquarium, .aquarium, .womb]
        ),
        .general: (
            young: [.aquarium, .womb, .heartbeat, .shushing],
            older: [.aquarium, .aquarium, .lullaby, .musicBox]
        )
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Main Recommendation Methods

    /// Get personalized recommendations for a baby
    /// - Parameters:
    ///   - babyId: Baby identifier
    ///   - babyAge: Baby's age in months
    ///   - cryAnalysis: Current cry analysis (optional)
    ///   - context: Recommendation context
    /// - Returns: Sorted list of recommended tracks
    func getRecommendations(
        for babyId: UUID,
        babyAge: Int,
        cryAnalysis: CryAnalysisResult? = nil,
        context: RecommendationContext = .general
    ) async -> [RecommendedTrack] {
        isProcessing = true
        defer { isProcessing = false }

        lastContext = context

        let profile = profileManager.getProfile(for: babyId)
        let allTracks = contentLibrary.getAllTracks()

        var scoredTracks: [RecommendedTrack] = []

        for track in allTracks {
            let (score, reasons) = calculateTrackScore(
                track: track,
                babyId: babyId,
                babyAge: babyAge,
                profile: profile,
                cryAnalysis: cryAnalysis,
                context: context
            )

            if score > minScoreThreshold {
                scoredTracks.append(RecommendedTrack(
                    track: track,
                    score: score,
                    reasons: reasons
                ))
            }
        }

        // Sort by score (highest first)
        scoredTracks.sort { $0.score > $1.score }

        // Take top recommendations
        let result = Array(scoredTracks.prefix(maxRecommendations))
        recommendations = result

        return result
    }

    /// Get emergency recommendations for active crying
    /// Optimized for quick response with highest-probability effective tracks
    func getEmergencyRecommendations(
        for babyId: UUID,
        babyAge: Int,
        cryType: CryType,
        cryIntensity: Double
    ) async -> [AudioTrack] {
        let profile = profileManager.getProfile(for: babyId)
        var candidates: [AudioTrack] = []

        // 1. Get historically effective tracks for this cry type
        if let effectiveTrackIds = profile?.effectiveTracksForCryType[cryType] {
            for trackId in effectiveTrackIds.prefix(3) {
                if let track = contentLibrary.getTrack(by: trackId) {
                    candidates.append(track)
                }
            }
        }

        // 2. Get overall best tracks for this baby
        if let profile = profile {
            let bestOverall = profile.trackEffectiveness
                .sorted { $0.value > $1.value }
                .prefix(3)
                .compactMap { contentLibrary.getTrack(by: $0.key) }

            for track in bestOverall {
                if !candidates.contains(where: { $0.id == track.id }) {
                    candidates.append(track)
                }
            }
        }

        // 3. Add high calming score age-appropriate tracks
        let highCalming = contentLibrary.getAllTracks()
            .filter { $0.ageRangeMin <= babyAge && $0.ageRangeMax >= babyAge }
            .filter { $0.calmingScore >= 0.85 }
            .sorted { $0.calmingScore > $1.calmingScore }

        for track in highCalming.prefix(5) {
            if !candidates.contains(where: { $0.id == track.id }) {
                candidates.append(track)
            }
        }

        // 4. Add cry-type specific tracks
        let typeSpecific = getTracksForCryType(cryType: cryType, babyAge: babyAge)
        for track in typeSpecific.prefix(3) {
            if !candidates.contains(where: { $0.id == track.id }) {
                candidates.append(track)
            }
        }

        // 5. If intensity is very high, prioritize proven soothers
        if cryIntensity > 0.8 {
            // Move womb/shushing/ocean to front for young babies
            if babyAge < 12 {
                let urgentSoothers = candidates.filter {
                    [GeneratorType.womb, .shushing, .heartbeat, .aquarium].contains($0.generatorType ?? .aquarium)
                }
                let others = candidates.filter {
                    ![GeneratorType.womb, .shushing, .heartbeat, .aquarium].contains($0.generatorType ?? .aquarium)
                }
                candidates = urgentSoothers + others
            }
        }

        return Array(candidates.prefix(10))
    }

    // MARK: - Score Calculation

    private func calculateTrackScore(
        track: AudioTrack,
        babyId: UUID,
        babyAge: Int,
        profile: BabyListeningProfile?,
        cryAnalysis: CryAnalysisResult?,
        context: RecommendationContext
    ) -> (Double, [RecommendationReason]) {
        var score: Double = 0
        var reasons: [RecommendationReason] = []

        // 1. Age appropriateness (0-0.2)
        if track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge {
            score += 0.15
            if track.isOptimalFor(ageMonths: babyAge) {
                score += 0.05
                reasons.append(.ageOptimal)
            }
        } else {
            // Not age appropriate - return 0
            return (0, [])
        }

        // 2. Base calming score (0-0.25)
        score += track.calmingScore * 0.25
        if track.calmingScore >= 0.85 {
            reasons.append(.highCalmingScore)
        }

        // 3. Historical effectiveness for this baby (0-0.3)
        if let profile = profile {
            if let effectiveness = profile.trackEffectiveness[track.id] {
                score += effectiveness * 0.3
                if effectiveness > 0.7 {
                    reasons.append(.historicallyEffective)
                }
            }

            // Category preference match
            if let preferredCategories = profile.preferredCategories,
               preferredCategories.contains(track.category) {
                score += 0.05
                reasons.append(.categoryPreference)
            }

            // Generator type preference
            if let preferredGenerators = profile.preferredGeneratorTypes,
               let trackGenerator = track.generatorType,
               preferredGenerators.contains(trackGenerator) {
                score += 0.05
                reasons.append(.profileMatch)
            }
        }

        // 4. Cry type match (0-0.2)
        if let cryAnalysis = cryAnalysis {
            let typeMatch = calculateCryTypeMatch(
                track: track,
                cryType: cryAnalysis.type,
                babyAge: babyAge
            )
            score += typeMatch * 0.2
            if typeMatch > 0.7 {
                reasons.append(.cryTypeMatch)
            }
        }

        // 5. Context-based adjustment
        score += contextBonus(track: track, context: context)

        return (min(score, 1.0), reasons)
    }

    /// Calculate how well a track matches a cry type
    private func calculateCryTypeMatch(track: AudioTrack, cryType: CryType, babyAge: Int) -> Double {
        guard let generator = track.generatorType else { return 0.5 }

        let isYoung = babyAge < 12
        guard let preferences = cryTypePreferences[cryType] else { return 0.5 }

        let preferredList = isYoung ? preferences.young : preferences.older

        if let index = preferredList.firstIndex(of: generator) {
            // Higher match for tracks earlier in the preference list
            return 1.0 - (Double(index) * 0.15)
        }

        return 0.3 // Base match for non-preferred tracks
    }

    /// Get additional score based on context
    private func contextBonus(track: AudioTrack, context: RecommendationContext) -> Double {
        switch context {
        case .sleep:
            if track.calmingScore >= 0.8 {
                if track.category == .ambient || track.category == .lullabies || track.generatorType == .lullaby {
                    return 0.1
                }
            }
            return 0

        case .crying, .emergency:
            if let generator = track.generatorType,
               [.shushing, .womb, .heartbeat, .aquarium, .aquarium].contains(generator) {
                return 0.1
            }
            return 0

        case .carRide:
            if let generator = track.generatorType,
               [.aquarium, .aquarium, .womb, .shushing].contains(generator) {
                return 0.05
            }
            return 0

        case .general:
            return 0
        }
    }

    /// Get tracks that match a specific cry type
    private func getTracksForCryType(cryType: CryType, babyAge: Int) -> [AudioTrack] {
        let isYoung = babyAge < 12
        guard let preferences = cryTypePreferences[cryType] else {
            return []
        }

        let preferredGenerators = isYoung ? preferences.young : preferences.older

        return contentLibrary.getAllTracks().filter { track in
            guard let generator = track.generatorType else { return false }
            return preferredGenerators.contains(generator)
        }
    }

    // MARK: - Feedback Integration

    /// Record that a recommendation was played
    func recordRecommendationPlayed(
        babyId: UUID,
        track: AudioTrack,
        context: RecommendationContext
    ) {
        // This would be integrated with analytics
        print("MLRecommendationEngine: Track \(track.title) played for baby \(babyId) in \(context.rawValue) context")
    }

    /// Record recommendation effectiveness
    func recordRecommendationEffectiveness(
        babyId: UUID,
        trackId: UUID,
        cryType: CryType,
        wasEffective: Bool,
        calmingTimeSeconds: Int
    ) {
        profileManager.recordTrackEffectiveness(
            babyId: babyId,
            trackId: trackId,
            cryType: cryType,
            wasEffective: wasEffective,
            calmingTimeSeconds: calmingTimeSeconds
        )
    }

    // MARK: - Quick Picks

    /// Get quick picks for a baby (best overall tracks)
    func getQuickPicks(for babyId: UUID, babyAge: Int, limit: Int = 5) -> [AudioTrack] {
        let profile = profileManager.getProfile(for: babyId)

        // Get historically effective tracks
        var candidates: [(track: AudioTrack, score: Double)] = []

        if let profile = profile {
            for (trackId, effectiveness) in profile.trackEffectiveness {
                if let track = contentLibrary.getTrack(by: trackId),
                   track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge {
                    candidates.append((track, effectiveness))
                }
            }
        }

        // Sort by effectiveness and take top
        candidates.sort { $0.score > $1.score }

        var result = candidates.prefix(limit).map { $0.track }

        // If not enough, add high calming score tracks
        if result.count < limit {
            let highCalming = contentLibrary.getAllTracks()
                .filter { $0.ageRangeMin <= babyAge && $0.ageRangeMax >= babyAge }
                .filter { track in !result.contains(where: { $0.id == track.id }) }
                .sorted { $0.calmingScore > $1.calmingScore }

            for track in highCalming {
                if result.count >= limit { break }
                result.append(track)
            }
        }

        return Array(result)
    }
}
