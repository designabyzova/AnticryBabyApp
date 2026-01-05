//
//  EffectivenessManager.swift
//  BabyInCarApp
//
//  Manages effectiveness feedback persistence and queries
//  Tracks what audio content works for calming the baby
//

import Foundation
import Combine

/// Manages track effectiveness data - what works for calming the baby
@MainActor
class EffectivenessManager: ObservableObject {
    static let shared = EffectivenessManager()

    // MARK: - Published Properties

    /// All effectiveness data keyed by track ID
    @Published private(set) var effectivenessData: [UUID: TrackEffectiveness] = [:]

    /// Recent feedback records for analytics
    @Published private(set) var recentFeedback: [EffectivenessFeedbackRecord] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let effectivenessKey = "TrackEffectiveness"
    private let feedbackHistoryKey = "EffectivenessFeedbackHistory"
    private let maxFeedbackHistory = 100

    // Debounce tracking to prevent duplicate play counts
    private var lastPlayRecorded: [UUID: Date] = [:]
    private let playDebounceInterval: TimeInterval = 30 // 30 seconds

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Persistence

    private func loadData() {
        // Load effectiveness data
        if let data = userDefaults.data(forKey: effectivenessKey),
           let decoded = try? JSONDecoder().decode([UUID: TrackEffectiveness].self, from: data) {
            effectivenessData = decoded
        }

        // Load feedback history
        if let data = userDefaults.data(forKey: feedbackHistoryKey),
           let decoded = try? JSONDecoder().decode([EffectivenessFeedbackRecord].self, from: data) {
            recentFeedback = decoded
        }
    }

    private func saveData() {
        // Save effectiveness data
        if let data = try? JSONEncoder().encode(effectivenessData) {
            userDefaults.set(data, forKey: effectivenessKey)
        }

        // Save feedback history (trimmed to max)
        let trimmedHistory = Array(recentFeedback.suffix(maxFeedbackHistory))
        if let data = try? JSONEncoder().encode(trimmedHistory) {
            userDefaults.set(data, forKey: feedbackHistoryKey)
        }
    }

    // MARK: - Recording Methods

    /// Record that a track was played
    /// - Parameters:
    ///   - track: The audio track that was played
    ///   - cryType: Optional cry type if detected
    func recordPlay(track: AudioTrack, cryType: CryType? = nil) {
        // Debounce: don't count repeated plays within short window
        if let lastPlay = lastPlayRecorded[track.id],
           Date().timeIntervalSince(lastPlay) < playDebounceInterval {
            return
        }

        lastPlayRecorded[track.id] = Date()

        var effectiveness = effectivenessData[track.id] ?? TrackEffectiveness(trackId: track.id)
        effectiveness.recordPlay(cryType: cryType)
        effectivenessData[track.id] = effectiveness

        saveData()
    }

    /// Record that a track helped calm the baby ("It Helped!" feedback)
    /// - Parameters:
    ///   - track: The audio track that helped
    ///   - cryType: Optional cry type if detected
    ///   - playDuration: Optional duration of playback before feedback
    func recordHelped(track: AudioTrack, cryType: CryType? = nil, playDuration: TimeInterval? = nil) {
        var effectiveness = effectivenessData[track.id] ?? TrackEffectiveness(trackId: track.id)
        effectiveness.recordHelped(cryType: cryType)
        effectivenessData[track.id] = effectiveness

        // Add to feedback history
        let record = EffectivenessFeedbackRecord(
            trackId: track.id,
            helped: true,
            cryType: cryType,
            playDuration: playDuration
        )
        recentFeedback.append(record)

        saveData()
    }

    /// Record negative feedback (didn't help) - optional, for detailed tracking
    /// - Parameters:
    ///   - track: The audio track that didn't help
    ///   - cryType: Optional cry type if detected
    func recordDidNotHelp(track: AudioTrack, cryType: CryType? = nil) {
        // Only record if we have existing data for this track
        guard effectivenessData[track.id] != nil else { return }

        let record = EffectivenessFeedbackRecord(
            trackId: track.id,
            helped: false,
            cryType: cryType,
            playDuration: nil
        )
        recentFeedback.append(record)

        saveData()
    }

    // MARK: - Query Methods

    /// Get effectiveness data for a specific track
    /// - Parameter trackId: The track ID to query
    /// - Returns: Effectiveness data if available
    func getEffectiveness(for trackId: UUID) -> TrackEffectiveness? {
        return effectivenessData[trackId]
    }

    /// Get effectiveness score for a track (0-100%)
    /// - Parameter trackId: The track ID to query
    /// - Returns: Effectiveness score or nil if no data
    func getEffectivenessScore(for trackId: UUID) -> Double? {
        guard let data = effectivenessData[trackId], data.totalPlays > 0 else {
            return nil
        }
        return data.effectivenessScore
    }

    /// Get top effective tracks sorted by effectiveness score
    /// - Parameters:
    ///   - limit: Maximum number of tracks to return
    ///   - cryType: Optional filter by cry type
    ///   - minPlays: Minimum plays required (default 2 for statistical relevance)
    /// - Returns: Array of track IDs sorted by effectiveness
    func getTopEffectiveTrackIds(limit: Int = 10, cryType: CryType? = nil, minPlays: Int = 2) -> [UUID] {
        var filtered = effectivenessData.values
            .filter { $0.totalPlays >= minPlays && $0.helpedCount > 0 }

        if let cryType = cryType {
            // Filter by cry type effectiveness
            filtered = filtered.filter { effectiveness in
                guard let stats = effectiveness.cryTypeBreakdown[cryType.rawValue],
                      stats.totalCount >= 1 else {
                    return false
                }
                return stats.helpedCount > 0
            }

            // Sort by cry-type-specific effectiveness
            return filtered
                .sorted { first, second in
                    let firstScore = first.effectivenessForCryType(cryType) ?? 0
                    let secondScore = second.effectivenessForCryType(cryType) ?? 0
                    return firstScore > secondScore
                }
                .prefix(limit)
                .map { $0.id }
        }

        // Sort by overall effectiveness
        return filtered
            .sorted { $0.effectivenessScore > $1.effectivenessScore }
            .prefix(limit)
            .map { $0.id }
    }

    /// Get top effective tracks as AudioTrack objects
    /// - Parameters:
    ///   - limit: Maximum number of tracks to return
    ///   - cryType: Optional filter by cry type
    /// - Returns: Array of AudioTrack objects
    func getTopEffectiveTracks(limit: Int = 10, cryType: CryType? = nil) -> [AudioTrack] {
        let trackIds = getTopEffectiveTrackIds(limit: limit, cryType: cryType)
        let library = ContentLibraryService.shared
        return trackIds.compactMap { library.getTrack(by: $0) }
    }

    /// Check if there's any effectiveness data
    var hasEffectivenessData: Bool {
        return effectivenessData.values.contains { $0.helpedCount > 0 }
    }

    /// Get count of tracks with positive feedback
    var tracksWithPositiveFeedback: Int {
        return effectivenessData.values.filter { $0.helpedCount > 0 }.count
    }

    /// Alias for tracksWithPositiveFeedback (for freemium comparison view)
    var effectiveTracksCount: Int {
        tracksWithPositiveFeedback
    }

    // MARK: - Insights Methods

    /// Get most effective category
    func getMostEffectiveCategory() -> AudioCategory? {
        var categoryStats: [AudioCategory: (helped: Int, total: Int)] = [:]
        let library = ContentLibraryService.shared

        for (trackId, effectiveness) in effectivenessData {
            guard let track = library.getTrack(by: trackId) else { continue }
            let category = track.category

            var stats = categoryStats[category] ?? (helped: 0, total: 0)
            stats.helped += effectiveness.helpedCount
            stats.total += effectiveness.totalPlays
            categoryStats[category] = stats
        }

        return categoryStats
            .filter { $0.value.total >= 3 }
            .max { first, second in
                let firstRate = Double(first.value.helped) / Double(first.value.total)
                let secondRate = Double(second.value.helped) / Double(second.value.total)
                return firstRate < secondRate
            }?.key
    }

    /// Get effectiveness statistics by category
    func getCategoryStatistics() -> [(category: AudioCategory, score: Double, count: Int)] {
        var categoryStats: [AudioCategory: (helped: Int, total: Int)] = [:]
        let library = ContentLibraryService.shared

        for (trackId, effectiveness) in effectivenessData {
            guard let track = library.getTrack(by: trackId) else { continue }
            let category = track.category

            var stats = categoryStats[category] ?? (helped: 0, total: 0)
            stats.helped += effectiveness.helpedCount
            stats.total += effectiveness.totalPlays
            categoryStats[category] = stats
        }

        return categoryStats
            .filter { $0.value.total > 0 }
            .map { category, stats in
                let score = Double(stats.helped) / Double(stats.total) * 100
                return (category: category, score: score, count: stats.helped)
            }
            .sorted { $0.score > $1.score }
    }

    /// Get total "It Helped!" count
    var totalHelpedCount: Int {
        return effectivenessData.values.reduce(0) { $0 + $1.helpedCount }
    }

    // MARK: - Reset Methods

    /// Clear all effectiveness data (for testing or user request)
    func clearAllData() {
        effectivenessData.removeAll()
        recentFeedback.removeAll()
        lastPlayRecorded.removeAll()
        saveData()
    }

    /// Clear data for a specific track
    func clearData(for trackId: UUID) {
        effectivenessData.removeValue(forKey: trackId)
        recentFeedback.removeAll { $0.trackId == trackId }
        saveData()
    }
}
