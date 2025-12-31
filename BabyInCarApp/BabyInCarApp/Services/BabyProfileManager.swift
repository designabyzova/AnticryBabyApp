//
//  BabyProfileManager.swift
//  BabyInCarApp
//
//  Manages personalized baby listening profiles with ML learning
//  Tracks what tracks work for each baby and cry type
//

import Foundation

// MARK: - Baby Listening Profile

/// Personalized listening profile learned for a specific baby
struct BabyListeningProfile: Codable {
    /// Baby identifier
    let babyId: UUID

    /// Effectiveness score per track (0-1, learned over time)
    var trackEffectiveness: [UUID: Double]

    /// Most effective tracks for each cry type
    var effectiveTracksForCryType: [CryType: [UUID]]

    /// Preferred audio categories based on usage
    var preferredCategories: [AudioCategory]?

    /// Preferred generator types based on effectiveness
    var preferredGeneratorTypes: [GeneratorType]?

    /// Average time to calm baby (seconds)
    var averageCalmingTime: TimeInterval

    /// Total listening time tracked (seconds)
    var totalListeningTime: TimeInterval

    /// Recent cry patterns for analysis
    var cryPatterns: [CryPatternRecord]

    /// Profile creation date
    let createdAt: Date

    /// Last update date
    var lastUpdated: Date

    // MARK: - Nested Types

    /// Record of a cry event and response
    struct CryPatternRecord: Codable {
        let timestamp: Date
        let cryType: CryType
        let duration: TimeInterval
        let intensity: Double
        let trackUsed: UUID?
        let wasEffective: Bool
        let calmingTime: TimeInterval?
    }

    // MARK: - Computed Properties

    /// Total number of recorded interactions
    var interactionCount: Int {
        cryPatterns.count
    }

    /// Success rate of soothing attempts
    var soothingSuccessRate: Double {
        let attempts = cryPatterns.filter { $0.trackUsed != nil }
        guard !attempts.isEmpty else { return 0 }
        let successes = attempts.filter { $0.wasEffective }.count
        return Double(successes) / Double(attempts.count)
    }

    /// Most common cry type for this baby
    var mostCommonCryType: CryType {
        var typeCounts: [CryType: Int] = [:]
        for pattern in cryPatterns {
            typeCounts[pattern.cryType, default: 0] += 1
        }
        return typeCounts.max(by: { $0.value < $1.value })?.key ?? .unknown
    }

    // MARK: - Initialization

    init(babyId: UUID) {
        self.babyId = babyId
        self.trackEffectiveness = [:]
        self.effectiveTracksForCryType = [:]
        self.preferredCategories = nil
        self.preferredGeneratorTypes = nil
        self.averageCalmingTime = 0
        self.totalListeningTime = 0
        self.cryPatterns = []
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

// MARK: - Baby Profile Manager

/// Manages personalized baby profiles with learning capabilities
@MainActor
class BabyProfileManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BabyProfileManager()

    // MARK: - Published State

    /// Currently active profile
    @Published var currentProfile: BabyListeningProfile?

    /// All profiles
    @Published var allProfiles: [UUID: BabyListeningProfile] = [:]

    // MARK: - Configuration

    /// Learning rate for effectiveness updates (0-1)
    private let learningRate: Double = 0.3

    /// Maximum cry patterns to keep per profile
    private let maxPatternsPerProfile = 100

    /// Maximum effective tracks per cry type
    private let maxTracksPerCryType = 10

    // MARK: - Storage

    private let userDefaults = UserDefaults.standard
    private let profilesKey = "BabyListeningProfiles"

    // MARK: - Initialization

    private init() {
        loadProfiles()
    }

    // MARK: - Profile Management

    /// Get profile for a baby, creating if needed
    func getOrCreateProfile(for babyId: UUID) -> BabyListeningProfile {
        if let existing = allProfiles[babyId] {
            return existing
        }

        let newProfile = BabyListeningProfile(babyId: babyId)
        allProfiles[babyId] = newProfile
        saveProfiles()
        return newProfile
    }

    /// Get profile for a baby (nil if not exists)
    func getProfile(for babyId: UUID) -> BabyListeningProfile? {
        return allProfiles[babyId]
    }

    /// Set current active profile
    func setCurrentProfile(for babyId: UUID) {
        currentProfile = getOrCreateProfile(for: babyId)
    }

    /// Delete profile for a baby
    func deleteProfile(for babyId: UUID) {
        allProfiles.removeValue(forKey: babyId)
        if currentProfile?.babyId == babyId {
            currentProfile = nil
        }
        saveProfiles()
    }

    // MARK: - Effectiveness Recording

    /// Record track effectiveness for learning
    /// - Parameters:
    ///   - babyId: Baby identifier
    ///   - trackId: Track that was played
    ///   - cryType: Type of cry being soothed
    ///   - wasEffective: Whether the track helped calm the baby
    ///   - calmingTimeSeconds: Time it took to calm (if effective)
    func recordTrackEffectiveness(
        babyId: UUID,
        trackId: UUID,
        cryType: CryType,
        wasEffective: Bool,
        calmingTimeSeconds: Int
    ) {
        var profile = getOrCreateProfile(for: babyId)

        // Update effectiveness score using exponential moving average
        let currentScore = profile.trackEffectiveness[trackId] ?? 0.5
        let newObservation: Double = wasEffective ? 1.0 : 0.0
        let updatedScore = currentScore * (1 - learningRate) + newObservation * learningRate
        profile.trackEffectiveness[trackId] = updatedScore

        // Update effective tracks for cry type
        if wasEffective {
            updateEffectiveTracks(
                profile: &profile,
                cryType: cryType,
                trackId: trackId,
                score: updatedScore
            )
        }

        // Update average calming time
        if wasEffective && calmingTimeSeconds > 0 {
            let totalPatterns = Double(profile.cryPatterns.count + 1)
            let currentAvg = profile.averageCalmingTime
            profile.averageCalmingTime = currentAvg + (TimeInterval(calmingTimeSeconds) - currentAvg) / totalPatterns
        }

        profile.lastUpdated = Date()
        allProfiles[babyId] = profile
        saveProfiles()

        // Update current profile if applicable
        if currentProfile?.babyId == babyId {
            currentProfile = profile
        }
    }

    /// Update the list of effective tracks for a cry type
    private func updateEffectiveTracks(
        profile: inout BabyListeningProfile,
        cryType: CryType,
        trackId: UUID,
        score: Double
    ) {
        if profile.effectiveTracksForCryType[cryType] == nil {
            profile.effectiveTracksForCryType[cryType] = []
        }

        // Remove if already exists (to re-add at front)
        profile.effectiveTracksForCryType[cryType]?.removeAll { $0 == trackId }

        // Add to front (most recent = most relevant)
        profile.effectiveTracksForCryType[cryType]?.insert(trackId, at: 0)

        // Keep top tracks only
        if (profile.effectiveTracksForCryType[cryType]?.count ?? 0) > maxTracksPerCryType {
            profile.effectiveTracksForCryType[cryType]?.removeLast()
        }
    }

    // MARK: - Pattern Recording

    /// Record a cry pattern for learning
    func recordCryPattern(
        babyId: UUID,
        cryType: CryType,
        duration: TimeInterval,
        intensity: Double,
        trackUsed: UUID?,
        wasEffective: Bool,
        calmingTime: TimeInterval?
    ) {
        var profile = getOrCreateProfile(for: babyId)

        let record = BabyListeningProfile.CryPatternRecord(
            timestamp: Date(),
            cryType: cryType,
            duration: duration,
            intensity: intensity,
            trackUsed: trackUsed,
            wasEffective: wasEffective,
            calmingTime: calmingTime
        )

        profile.cryPatterns.append(record)

        // Keep recent patterns only
        if profile.cryPatterns.count > maxPatternsPerProfile {
            profile.cryPatterns.removeFirst()
        }

        // Update preferred categories based on effective tracks
        updatePreferredCategories(profile: &profile)

        profile.lastUpdated = Date()
        allProfiles[babyId] = profile
        saveProfiles()

        if currentProfile?.babyId == babyId {
            currentProfile = profile
        }
    }

    /// Update preferred categories based on effective track distribution
    private func updatePreferredCategories(profile: inout BabyListeningProfile) {
        // This would need access to track metadata to determine categories
        // For now, we just mark as needing update
        profile.lastUpdated = Date()
    }

    // MARK: - Listening Time

    /// Add listening time to profile
    func addListeningTime(babyId: UUID, duration: TimeInterval) {
        guard var profile = allProfiles[babyId] else { return }

        profile.totalListeningTime += duration
        profile.lastUpdated = Date()
        allProfiles[babyId] = profile
        saveProfiles()

        if currentProfile?.babyId == babyId {
            currentProfile = profile
        }
    }

    // MARK: - Recommendations Support

    /// Get effectiveness score for a track with a specific baby
    func getEffectiveness(babyId: UUID, trackId: UUID) -> Double? {
        return allProfiles[babyId]?.trackEffectiveness[trackId]
    }

    /// Get best tracks for a cry type
    func getBestTracks(babyId: UUID, cryType: CryType, limit: Int = 5) -> [UUID] {
        guard let profile = allProfiles[babyId],
              let tracks = profile.effectiveTracksForCryType[cryType] else {
            return []
        }
        return Array(tracks.prefix(limit))
    }

    /// Get overall best tracks for a baby (across all cry types)
    func getBestOverallTracks(babyId: UUID, limit: Int = 10) -> [UUID] {
        guard let profile = allProfiles[babyId] else { return [] }

        return profile.trackEffectiveness
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Analytics

    /// Get profile statistics for display
    func getProfileStats(babyId: UUID) -> ProfileStats? {
        guard let profile = allProfiles[babyId] else { return nil }

        return ProfileStats(
            totalListeningMinutes: Int(profile.totalListeningTime / 60),
            interactionCount: profile.interactionCount,
            successRate: profile.soothingSuccessRate,
            averageCalmingSeconds: Int(profile.averageCalmingTime),
            mostCommonCryType: profile.mostCommonCryType,
            trackedSince: profile.createdAt
        )
    }

    struct ProfileStats {
        let totalListeningMinutes: Int
        let interactionCount: Int
        let successRate: Double
        let averageCalmingSeconds: Int
        let mostCommonCryType: CryType
        let trackedSince: Date
    }

    // MARK: - Persistence

    private func loadProfiles() {
        guard let data = userDefaults.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([UUID: BabyListeningProfile].self, from: data) else {
            return
        }
        allProfiles = profiles
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(allProfiles) else { return }
        userDefaults.set(data, forKey: profilesKey)
    }

    /// Export profile data
    func exportProfile(babyId: UUID) -> Data? {
        guard let profile = allProfiles[babyId] else { return nil }
        return try? JSONEncoder().encode(profile)
    }

    /// Import profile data
    func importProfile(data: Data) throws {
        let profile = try JSONDecoder().decode(BabyListeningProfile.self, from: data)
        allProfiles[profile.babyId] = profile
        saveProfiles()
    }
}
