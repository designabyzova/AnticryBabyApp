//
//  SpotifyQueueEngine.swift
//  BabyInCarApp
//
//  Spotify-like recommendation engine for smart queue population.
//  Uses multi-factor scoring: cry stop success, favorites, play counts, rotation policy.
//
//  Algorithm mirrors Spotify's "Radio" queue behavior:
//  - Maintains 8 upcoming tracks at all times
//  - When 1 track plays (7 remaining), adds 1 more to replenish to 8
//  - Scores tracks using weighted combination of signals
//  - Applies rotation policy to prevent repetition
//

import Foundation
import Combine

/// Spotify-like queue engine that populates smart playlists based on user behavior
@MainActor
class SpotifyQueueEngine: ObservableObject {
    static let shared = SpotifyQueueEngine()

    // MARK: - Configuration

    /// Target queue size - Spotify typically maintains ~8 upcoming tracks
    static let targetQueueSize = 8

    /// Minimum tracks before replenishment is triggered
    static let replenishThreshold = 7

    /// Maximum recently played tracks to remember (for rotation)
    private static let maxRecentlyPlayed = 50

    /// Decay factor for recency penalty (higher = faster decay)
    private static let recencyDecayFactor = 0.15

    // MARK: - Scoring Weights (Spotify-like)

    /// Weights for the scoring algorithm - these mirror Spotify's approach
    enum ScoreWeight {
        /// Cry stop success - tracks that successfully calmed the baby
        static let cryStopSuccess: Double = 0.35

        /// Favorite status - user explicitly liked the track
        static let favorite: Double = 0.25

        /// Play count popularity - frequently played = proven effective
        static let playCount: Double = 0.20

        /// Base calming score - inherent quality of the track
        static let calmingScore: Double = 0.15

        /// Category match bonus - matches current context
        static let categoryMatch: Double = 0.05

        // PENALTIES

        /// Maximum recency penalty (recently played tracks)
        static let recencyPenaltyMax: Double = 0.40

        /// Repetition penalty for same artist/category in a row
        static let repetitionPenalty: Double = 0.15
    }

    // MARK: - State

    /// Recently played track IDs for rotation (FIFO queue)
    @Published private(set) var recentlyPlayedIds: [UUID] = []

    /// Current scoring context (cry type, baby age, etc.)
    private var currentContext: QueueContext = QueueContext()

    /// Play count cache (track ID -> play count)
    private var playCountCache: [UUID: Int] = [:]

    // Dependencies
    private let effectivenessManager = EffectivenessManager.shared
    private let favoritesManager = FavoritesManager.shared
    private let contentLibrary = ContentLibraryService.shared

    // MARK: - Persistence

    private let userDefaults = UserDefaults.standard
    private let recentlyPlayedKey = "SpotifyQueueEngine.recentlyPlayed"
    private let playCountKey = "SpotifyQueueEngine.playCounts"

    // MARK: - Initialization

    private init() {
        loadPersistedData()
    }

    // MARK: - Persistence Methods

    private func loadPersistedData() {
        // Load recently played
        if let data = userDefaults.data(forKey: recentlyPlayedKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            recentlyPlayedIds = ids
        }

        // Load play counts
        if let data = userDefaults.data(forKey: playCountKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            // Convert string keys back to UUID
            playCountCache = Dictionary(uniqueKeysWithValues:
                counts.compactMap { key, value in
                    UUID(uuidString: key).map { ($0, value) }
                }
            )
        }
    }

    private func persistData() {
        // Save recently played
        if let data = try? JSONEncoder().encode(recentlyPlayedIds) {
            userDefaults.set(data, forKey: recentlyPlayedKey)
        }

        // Save play counts (convert UUID to String for JSON)
        let stringKeyCounts = Dictionary(uniqueKeysWithValues:
            playCountCache.map { ($0.key.uuidString, $0.value) }
        )
        if let data = try? JSONEncoder().encode(stringKeyCounts) {
            userDefaults.set(data, forKey: playCountKey)
        }
    }

    // MARK: - Context Management

    /// Set the current context for queue building
    func setContext(cryType: CryType, babyAge: Int, preferredCategories: Set<AudioCategory>? = nil) {
        currentContext = QueueContext(
            cryType: cryType,
            babyAge: babyAge,
            preferredCategories: preferredCategories
        )
    }

    // MARK: - Play Count Tracking

    /// Record that a track was played (for popularity scoring)
    func recordTrackPlayed(_ track: AudioTrack) {
        // Update play count
        playCountCache[track.id] = (playCountCache[track.id] ?? 0) + 1

        // Add to recently played (for rotation)
        recentlyPlayedIds.removeAll { $0 == track.id } // Remove if exists
        recentlyPlayedIds.insert(track.id, at: 0) // Add to front

        // Trim to max size
        if recentlyPlayedIds.count > SpotifyQueueEngine.maxRecentlyPlayed {
            recentlyPlayedIds = Array(recentlyPlayedIds.prefix(SpotifyQueueEngine.maxRecentlyPlayed))
        }

        persistData()
    }

    /// Get play count for a track
    func getPlayCount(for trackId: UUID) -> Int {
        return playCountCache[trackId] ?? 0
    }

    /// Get max play count (for normalization)
    private var maxPlayCount: Int {
        return playCountCache.values.max() ?? 1
    }

    // MARK: - Core Scoring Algorithm

    /// Calculate Spotify-like score for a track
    /// Higher score = more likely to be added to queue
    func calculateScore(for track: AudioTrack, queueContext: [AudioTrack] = []) -> TrackScore {
        var score: Double = 0.0
        var factors: [String: Double] = [:]

        // 1. CRY STOP SUCCESS (35%) - Most important signal!
        // Tracks that successfully calmed the baby get highest priority
        let cryStopScore = calculateCryStopScore(for: track)
        score += cryStopScore * ScoreWeight.cryStopSuccess
        factors["cryStopSuccess"] = cryStopScore

        // 2. FAVORITE STATUS (25%) - User explicitly likes this track
        let favoriteScore = favoritesManager.isFavorite(track: track) ? 1.0 : 0.0
        score += favoriteScore * ScoreWeight.favorite
        factors["favorite"] = favoriteScore

        // 3. PLAY COUNT POPULARITY (20%) - Frequently played = proven good
        let playCountScore = calculatePlayCountScore(for: track)
        score += playCountScore * ScoreWeight.playCount
        factors["playCount"] = playCountScore

        // 4. BASE CALMING SCORE (15%) - Inherent track quality
        let calmingScore = track.calmingScore
        score += calmingScore * ScoreWeight.calmingScore
        factors["calmingScore"] = calmingScore

        // 5. CATEGORY MATCH (5%) - Matches preferred categories
        let categoryScore = calculateCategoryMatchScore(for: track)
        score += categoryScore * ScoreWeight.categoryMatch
        factors["categoryMatch"] = categoryScore

        // PENALTIES

        // 6. RECENCY PENALTY - Don't repeat recently played tracks
        let recencyPenalty = calculateRecencyPenalty(for: track)
        score -= recencyPenalty * ScoreWeight.recencyPenaltyMax
        factors["recencyPenalty"] = -recencyPenalty

        // 7. REPETITION PENALTY - Avoid same artist/category in a row
        let repetitionPenalty = calculateRepetitionPenalty(for: track, inQueue: queueContext)
        score -= repetitionPenalty * ScoreWeight.repetitionPenalty
        factors["repetitionPenalty"] = -repetitionPenalty

        // Normalize to 0-1 range
        score = max(0, min(1, score))

        return TrackScore(track: track, score: score, factors: factors)
    }

    // MARK: - Individual Score Components

    /// Calculate cry stop success score (0-1)
    /// Based on how often this track helped calm the baby
    private func calculateCryStopScore(for track: AudioTrack) -> Double {
        guard let effectiveness = effectivenessManager.getEffectiveness(for: track.id) else {
            return 0.3 // Default score for unplayed tracks (give them a chance)
        }

        // If we have cry type context, use cry-specific effectiveness
        if let cryTypeScore = effectiveness.effectivenessForCryType(currentContext.cryType) {
            return cryTypeScore / 100.0 // Convert 0-100% to 0-1
        }

        // Fall back to overall effectiveness
        return effectiveness.effectivenessScore / 100.0
    }

    /// Calculate play count popularity score (0-1)
    /// Normalized by max play count in library
    private func calculatePlayCountScore(for track: AudioTrack) -> Double {
        let playCount = getPlayCount(for: track.id)
        guard maxPlayCount > 0 else { return 0 }

        // Use logarithmic scaling to prevent super-popular tracks from dominating
        let normalizedCount = log(Double(playCount + 1)) / log(Double(maxPlayCount + 1))
        return min(1.0, normalizedCount)
    }

    /// Calculate category match score (0-1)
    private func calculateCategoryMatchScore(for track: AudioTrack) -> Double {
        // If user selected specific categories, strongly prefer those
        if let preferred = currentContext.preferredCategories, !preferred.isEmpty {
            return preferred.contains(track.category) ? 1.0 : 0.2
        }

        // Otherwise use science-based category priorities
        let categoryPriorities: [AudioCategory: Double] = [
            .classicalMusic: 0.95,
            .lullabies: 0.90,
            .instrumental: 0.85,
            .ambient: 0.80,
            .childrenSongs: 0.75,
            .natureSounds: 0.70,
            .fairyTales: 0.60
        ]

        return categoryPriorities[track.category] ?? 0.5
    }

    /// Calculate recency penalty (0-1)
    /// Higher = track was played more recently = bigger penalty
    private func calculateRecencyPenalty(for track: AudioTrack) -> Double {
        guard let index = recentlyPlayedIds.firstIndex(of: track.id) else {
            return 0 // Never played recently, no penalty
        }

        // Exponential decay: penalty decreases as index increases
        // index 0 (just played) = full penalty
        // index 10 = ~22% penalty
        // index 20 = ~5% penalty
        let decay = exp(-SpotifyQueueEngine.recencyDecayFactor * Double(index))
        return decay
    }

    /// Calculate repetition penalty (0-1)
    /// Penalize same artist/category appearing consecutively in queue
    private func calculateRepetitionPenalty(for track: AudioTrack, inQueue: [AudioTrack]) -> Double {
        guard !inQueue.isEmpty else { return 0 }

        var penalty: Double = 0

        // Check last 3 tracks in queue for repetition
        for (index, queueTrack) in inQueue.suffix(3).enumerated() {
            let positionWeight = 1.0 - (Double(index) * 0.3) // Recent = higher weight

            // Same category penalty
            if queueTrack.category == track.category {
                penalty += 0.3 * positionWeight
            }

            // Same artist penalty (if not "Lulla" generated)
            if queueTrack.artist == track.artist && track.artist != "Lulla" {
                penalty += 0.4 * positionWeight
            }
        }

        return min(1.0, penalty)
    }

    // MARK: - Queue Building

    /// Build initial queue with targetQueueSize tracks
    /// Uses Spotify-like algorithm to select best tracks
    func buildInitialQueue(from candidates: [AudioTrack]) -> [AudioTrack] {
        return selectTracks(from: candidates, count: SpotifyQueueEngine.targetQueueSize)
    }

    /// Replenish queue to maintain target size
    /// Called when a track finishes playing
    func replenishQueue(
        currentQueue: [AudioTrack],
        from candidates: [AudioTrack]
    ) -> [AudioTrack] {
        let needed = SpotifyQueueEngine.targetQueueSize - currentQueue.count
        guard needed > 0 else { return [] }

        // Exclude tracks already in queue
        let queueIds = Set(currentQueue.map { $0.id })
        let availableCandidates = candidates.filter { !queueIds.contains($0.id) }

        return selectTracks(from: availableCandidates, count: needed, existingQueue: currentQueue)
    }

    /// Select N tracks from candidates using scoring algorithm
    private func selectTracks(
        from candidates: [AudioTrack],
        count: Int,
        existingQueue: [AudioTrack] = []
    ) -> [AudioTrack] {
        var selected: [AudioTrack] = []
        var currentQueue = existingQueue

        // Score all candidates
        var scoredCandidates = candidates.map { track in
            calculateScore(for: track, queueContext: currentQueue)
        }

        // Select tracks one by one, re-scoring after each selection
        // This ensures rotation policy works correctly
        for _ in 0..<count {
            guard !scoredCandidates.isEmpty else { break }

            // Apply weighted random selection (Spotify-style)
            // Higher scored tracks are more likely, but not guaranteed
            if let selectedScore = weightedRandomSelect(from: scoredCandidates) {
                selected.append(selectedScore.track)
                currentQueue.append(selectedScore.track)

                // Remove selected from candidates
                scoredCandidates.removeAll { $0.track.id == selectedScore.track.id }

                // Re-score remaining candidates (for repetition penalty)
                scoredCandidates = scoredCandidates.map { ts in
                    calculateScore(for: ts.track, queueContext: currentQueue)
                }
            }
        }

        return selected
    }

    /// Weighted random selection - Spotify-style
    /// Higher scored tracks are more likely to be selected, but there's randomness
    private func weightedRandomSelect(from scores: [TrackScore]) -> TrackScore? {
        guard !scores.isEmpty else { return nil }

        // Sort by score descending
        let sorted = scores.sorted { $0.score > $1.score }

        // 70% chance: Pick from top 3
        // 25% chance: Pick from top 10
        // 5% chance: Random pick (exploration)
        let random = Double.random(in: 0...1)

        if random < 0.70 {
            // Top 3
            let topN = min(3, sorted.count)
            return sorted[Int.random(in: 0..<topN)]
        } else if random < 0.95 {
            // Top 10
            let topN = min(10, sorted.count)
            return sorted[Int.random(in: 0..<topN)]
        } else {
            // Random exploration
            return sorted.randomElement()
        }
    }

    // MARK: - Debug & Analytics

    /// Get detailed scoring breakdown for a track (for debugging/UI)
    func getScoreBreakdown(for track: AudioTrack) -> TrackScore {
        return calculateScore(for: track)
    }

    /// Get top scored tracks (for debugging/preview)
    func getTopScoredTracks(from candidates: [AudioTrack], limit: Int = 10) -> [TrackScore] {
        return candidates
            .map { calculateScore(for: $0) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Reset

    /// Clear all tracking data
    func clearHistory() {
        recentlyPlayedIds.removeAll()
        playCountCache.removeAll()
        persistData()
    }
}

// MARK: - Supporting Types

/// Context for queue building
struct QueueContext {
    let cryType: CryType
    let babyAge: Int
    let preferredCategories: Set<AudioCategory>?

    init(
        cryType: CryType = .general,
        babyAge: Int = 12,
        preferredCategories: Set<AudioCategory>? = nil
    ) {
        self.cryType = cryType
        self.babyAge = babyAge
        self.preferredCategories = preferredCategories
    }
}

/// Track with its calculated score
struct TrackScore: Identifiable {
    let id: UUID
    let track: AudioTrack
    let score: Double
    let factors: [String: Double]

    init(track: AudioTrack, score: Double, factors: [String: Double]) {
        self.id = track.id
        self.track = track
        self.score = score
        self.factors = factors
    }

    /// Human-readable score percentage
    var scorePercentage: Int {
        return Int(score * 100)
    }

    /// Debug description of score factors
    var factorDescription: String {
        factors.map { "\($0.key): \(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")
    }
}
