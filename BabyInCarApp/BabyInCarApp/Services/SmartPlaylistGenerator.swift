//
//  SmartPlaylistGenerator.swift
//  BabyInCarApp
//
//  Multi-criteria track scoring and playlist generation for FS-029
//  Uses: cry type suitability, baby age, effectiveness history, favorites, rotation bonus
//

import Foundation

/// Smart playlist generator using multi-criteria scoring
/// Formula: Score = W1×Age + W2×CryType + W3×Effectiveness + W4×Favorites + Rotation - Recency
@MainActor
class SmartPlaylistGenerator: ObservableObject {

    // MARK: - Singleton

    static let shared = SmartPlaylistGenerator()

    // MARK: - Scoring Weights (from spec Section 5.1)

    struct Weights {
        static let age: Double = 0.20
        static let cryType: Double = 0.35
        static let effectiveness: Double = 0.30
        static let favorites: Double = 0.15
        static let rotationBonus: Double = 0.12
        static let recencyPenalty: Double = 0.10
    }

    // MARK: - Configuration

    /// Maximum tracks in a generated playlist
    static let defaultPlaylistSize = 10

    /// Maximum percentage of tracks from a single category (diversity constraint)
    static let maxCategoryPercentage = 0.25

    /// Minimum calm score for pain cry type
    static let painMinCalmScore: Double = 0.90

    // MARK: - Published State

    @Published private(set) var lastGeneratedPlaylist: [AudioTrack] = []
    @Published private(set) var generationReasoning: String = ""
    @Published private(set) var generationConfidence: Double = 0.0

    // MARK: - Dependencies

    private let effectivenessManager = EffectivenessManager.shared
    private let categoryRotationManager = CategoryRotationManager.shared

    // MARK: - Recently Played Tracking

    private var recentlyPlayedTrackIds: [UUID] = []
    private let maxRecentTracks = 30

    // MARK: - Performance Tracking

    private var generationTimeHistory: [Double] = []
    private let maxHistorySize = 50

    /// Average playlist generation time in milliseconds
    var averageGenerationTime: Double {
        guard !generationTimeHistory.isEmpty else { return 0 }
        return generationTimeHistory.reduce(0, +) / Double(generationTimeHistory.count)
    }

    private init() {}

    // MARK: - Public API

    /// Generate optimal playlist for a cry type
    /// - Parameters:
    ///   - cryType: Detected cry type
    ///   - babyAge: Baby's age in months
    ///   - allTracks: Pool of tracks to select from
    ///   - favoriteIds: Set of favorite track IDs
    ///   - isPremium: Whether user has premium access
    ///   - maxTracks: Maximum tracks to return
    /// - Returns: Ordered array of recommended tracks
    func generatePlaylist(
        for cryType: CryType,
        babyAge: Int,
        allTracks: [AudioTrack],
        favoriteIds: Set<UUID> = [],
        isPremium: Bool = false,
        maxTracks: Int = defaultPlaylistSize
    ) -> [AudioTrack] {
        let startTime = Date()
        print("[SmartPlaylistGenerator] 🧠 Generating playlist for \(cryType.rawValue), age=\(babyAge)mo")

        // Filter eligible tracks
        let eligibleTracks = filterEligibleTracks(
            allTracks,
            cryType: cryType,
            isPremium: isPremium
        )

        guard !eligibleTracks.isEmpty else {
            print("[SmartPlaylistGenerator] ⚠️ No eligible tracks found")
            generationReasoning = "No eligible tracks available"
            return []
        }

        // Score all eligible tracks
        var scoredTracks: [(track: AudioTrack, score: Double, reasoning: String)] = []

        for track in eligibleTracks {
            let (score, reasoning) = calculateTrackScore(
                track: track,
                cryType: cryType,
                babyAge: babyAge,
                favoriteIds: favoriteIds
            )
            scoredTracks.append((track, score, reasoning))
        }

        // Sort by score (highest first)
        scoredTracks.sort { $0.score > $1.score }

        // Apply category diversity constraint
        let diversePlaylist = applyCategoryDiversity(
            scoredTracks: scoredTracks,
            maxTracks: maxTracks
        )

        // Update state
        lastGeneratedPlaylist = diversePlaylist.map { $0.track }
        generationConfidence = diversePlaylist.first?.score ?? 0.0
        generationReasoning = buildPlaylistReasoning(cryType: cryType, topTrack: diversePlaylist.first)

        let elapsed = Date().timeIntervalSince(startTime) * 1000

        // Record performance metrics
        recordGenerationTime(elapsed)

        // Warn if exceeding target
        if elapsed > 200 {
            print("[SmartPlaylistGenerator] ⚠️ Generation took \(Int(elapsed))ms (target: <200ms)")
        } else {
            print("[SmartPlaylistGenerator] ✅ Generated \(lastGeneratedPlaylist.count) tracks in \(Int(elapsed))ms")
        }
        print("[SmartPlaylistGenerator] Top track: \(lastGeneratedPlaylist.first?.title ?? "none") (score: \(String(format: "%.2f", generationConfidence)))")

        return lastGeneratedPlaylist
    }

    /// Record generation time for performance monitoring
    private func recordGenerationTime(_ timeMs: Double) {
        generationTimeHistory.append(timeMs)
        if generationTimeHistory.count > maxHistorySize {
            generationTimeHistory.removeFirst()
        }
    }

    /// Get performance statistics
    func getPerformanceStats() -> (average: Double, min: Double, max: Double, count: Int) {
        guard !generationTimeHistory.isEmpty else {
            return (0, 0, 0, 0)
        }
        let average = generationTimeHistory.reduce(0, +) / Double(generationTimeHistory.count)
        let min = generationTimeHistory.min() ?? 0
        let max = generationTimeHistory.max() ?? 0
        return (average, min, max, generationTimeHistory.count)
    }

    /// Record that a track was played
    func recordTrackPlayed(_ trackId: UUID) {
        recentlyPlayedTrackIds.append(trackId)
        if recentlyPlayedTrackIds.count > maxRecentTracks {
            recentlyPlayedTrackIds.removeFirst()
        }
    }

    /// Clear recently played history
    func clearRecentlyPlayed() {
        recentlyPlayedTrackIds.removeAll()
    }

    /// Get generation insights for UI display
    func getGenerationInsights() -> PlaylistGenerationInsights {
        return PlaylistGenerationInsights(
            topTracks: Array(lastGeneratedPlaylist.prefix(3).map { $0.title }),
            confidence: String(format: "%.0f%%", generationConfidence * 100),
            reasoning: generationReasoning,
            rotationStats: categoryRotationManager.getRotationStats()
        )
    }

    // MARK: - Track Scoring

    /// Calculate composite score for a track
    private func calculateTrackScore(
        track: AudioTrack,
        cryType: CryType,
        babyAge: Int,
        favoriteIds: Set<UUID>
    ) -> (score: Double, reasoning: String) {
        var score: Double = 0.0
        var reasons: [String] = []

        // 1. Age Score (0.20 weight)
        let ageScore = calculateAgeScore(track: track, babyAge: babyAge)
        score += ageScore * Weights.age
        if ageScore > 0.9 {
            reasons.append("optimal for age")
        }

        // 2. Cry Type Score (0.35 weight - highest!)
        let cryScore = track.suitabilityFor(cryType)
        score += cryScore * Weights.cryType
        if cryScore > 0.8 {
            reasons.append("excellent for \(cryType.rawValue)")
        }

        // 3. Effectiveness Score (0.30 weight)
        let effectivenessScore = effectivenessManager.getScore(
            for: track.id.uuidString,
            cryType: cryType
        )
        score += effectivenessScore * Weights.effectiveness
        if effectivenessScore > 0.7 {
            reasons.append("proven effective")
        }

        // 4. Favorites Score (0.15 weight)
        let isFavorite = favoriteIds.contains(track.id)
        let favoritesScore = isFavorite ? 1.0 : 0.0
        score += favoritesScore * Weights.favorites
        if isFavorite {
            reasons.append("favorite")
        }

        // 5. Rotation Bonus (add up to 0.12)
        let rotationBonus = categoryRotationManager.getRotationBonus(for: track.category)
        score += rotationBonus * Weights.rotationBonus
        if rotationBonus > 0.1 {
            reasons.append("fresh category")
        }

        // 6. Recency Penalty (subtract up to 0.10)
        let recencyPenalty = calculateRecencyPenalty(trackId: track.id)
        score -= recencyPenalty * Weights.recencyPenalty
        if recencyPenalty > 0.5 {
            reasons.append("played recently")
        }

        // Clamp to 0-1 range
        score = max(0.0, min(1.0, score))

        let reasoning = reasons.isEmpty ? "general recommendation" : reasons.joined(separator: ", ")
        return (score, reasoning)
    }

    // MARK: - Individual Factor Calculations

    /// Calculate age appropriateness score (0-1)
    private func calculateAgeScore(track: AudioTrack, babyAge: Int) -> Double {
        // Check if within age range
        if babyAge < track.ageRangeMin {
            // Too young
            let distance = track.ageRangeMin - babyAge
            return max(0.3, 1.0 - Double(distance) * 0.15)
        }

        if babyAge > track.ageRangeMax {
            // Too old
            let distance = babyAge - track.ageRangeMax
            return max(0.4, 1.0 - Double(distance) * 0.1)
        }

        // Within range - check optimal ages if available
        if !track.optimalAgeMonths.isEmpty {
            if track.optimalAgeMonths.contains(babyAge) {
                return 1.0
            }
            // Find closest optimal age
            let closest = track.optimalAgeMonths.min(by: { abs($0 - babyAge) < abs($1 - babyAge) }) ?? babyAge
            let distance = abs(closest - babyAge)
            return max(0.7, 1.0 - Double(distance) * 0.05)
        }

        // Within range, no specific optimal ages
        return 0.9
    }

    /// Calculate recency penalty (0-1, higher = played more recently)
    private func calculateRecencyPenalty(trackId: UUID) -> Double {
        guard let index = recentlyPlayedTrackIds.lastIndex(of: trackId) else {
            return 0.0 // Not recently played
        }

        // Most recent = highest penalty
        let recencyIndex = recentlyPlayedTrackIds.count - 1 - index
        let penalty = max(0.0, 1.0 - Double(recencyIndex) * 0.1)
        return penalty
    }

    // MARK: - Track Filtering

    /// Filter tracks to eligible pool
    private func filterEligibleTracks(
        _ tracks: [AudioTrack],
        cryType: CryType,
        isPremium: Bool
    ) -> [AudioTrack] {
        return tracks.filter { track in
            // Exclude premium tracks if not premium user
            if track.isPremium && !isPremium {
                return false
            }

            // For pain cry type: only high calming score tracks
            if cryType == .pain && track.calmingScore < Self.painMinCalmScore {
                return false
            }

            // Exclude locked tracks
            if track.isLocked {
                return false
            }

            return true
        }
    }

    // MARK: - Category Diversity

    /// Apply category diversity constraint
    /// Ensures no single category exceeds maxCategoryPercentage of playlist
    private func applyCategoryDiversity(
        scoredTracks: [(track: AudioTrack, score: Double, reasoning: String)],
        maxTracks: Int
    ) -> [(track: AudioTrack, score: Double, reasoning: String)] {
        var result: [(track: AudioTrack, score: Double, reasoning: String)] = []
        var categoryCount: [AudioCategory: Int] = [:]
        let maxPerCategory = max(1, Int(ceil(Double(maxTracks) * Self.maxCategoryPercentage)))

        for item in scoredTracks {
            if result.count >= maxTracks {
                break
            }

            let category = item.track.category
            let currentCount = categoryCount[category] ?? 0

            if currentCount < maxPerCategory {
                result.append(item)
                categoryCount[category] = currentCount + 1

                // Record category play for rotation tracking
                categoryRotationManager.recordCategoryPlayed(category)
            }
        }

        return result
    }

    // MARK: - Reasoning

    /// Build human-readable reasoning for playlist generation
    private func buildPlaylistReasoning(
        cryType: CryType,
        topTrack: (track: AudioTrack, score: Double, reasoning: String)?
    ) -> String {
        guard let top = topTrack else {
            return "Unable to generate playlist"
        }

        var reasoning = "Selected for \(cryType.rawValue) cry"

        if !top.reasoning.isEmpty && top.reasoning != "general recommendation" {
            reasoning += ": \(top.reasoning)"
        }

        return reasoning
    }
}

// MARK: - Playlist Generation Insights

struct PlaylistGenerationInsights {
    let topTracks: [String]
    let confidence: String
    let reasoning: String
    let rotationStats: CategoryRotationStats
}
