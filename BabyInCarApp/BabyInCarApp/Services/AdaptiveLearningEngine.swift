//
//  AdaptiveLearningEngine.swift
//  BabyInCarApp
//
//  Self-learning engine that adapts to each baby's unique cry patterns
//  Based on research: MFCC features + Random Forest achieves 96.39% accuracy
//  Reference: Frontiers in AI 2024, DeepInfant CoreML
//

import Foundation
import Combine
import Accelerate
import UIKit

// MARK: - Adaptive Learning Engine

/// Self-learning system that personalizes cry detection and soothing recommendations
/// Uses on-device learning with privacy-first approach
@MainActor
class AdaptiveLearningEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = AdaptiveLearningEngine()

    // MARK: - Published Properties

    /// Current learning confidence (0-1) - how well the model knows this baby
    @Published private(set) var learningConfidence: Double = 0.0

    /// Total learning sessions recorded
    @Published private(set) var totalLearningSessions: Int = 0

    /// Is the system actively learning?
    @Published private(set) var isLearning: Bool = false

    /// Last learning update timestamp
    @Published private(set) var lastLearningUpdate: Date?

    /// Top recommended sounds based on learning
    @Published private(set) var learnedRecommendations: [LearnedSoundRecommendation] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let effectivenessManager = EffectivenessManager.shared

    /// Cry-Sound effectiveness matrix
    private var effectivenessMatrix: CrySoundEffectivenessMatrix = .empty

    /// Session history for temporal pattern learning
    private var sessionHistory: [LearningSession] = []

    /// Feature vectors from successful sessions (for future ML training)
    private var successfulFeatureVectors: [CryFeatureVector] = []

    /// Decay factor for older feedback (recent feedback weighted more)
    private let recencyDecayFactor: Double = 0.95

    /// Minimum sessions before making confident recommendations
    private let minSessionsForConfidence: Int = 5

    /// Storage keys
    private let matrixKey = "CrySoundEffectivenessMatrix"
    private let sessionHistoryKey = "LearningSessionHistory"
    private let featureVectorsKey = "SuccessfulFeatureVectors"

    // MARK: - Initialization

    private init() {
        loadStoredData()
        updateLearningMetrics()
        setupMemoryObservers()
    }

    // MARK: - Memory Management

    /// Setup memory cleanup observers
    private func setupMemoryObservers() {
        // MEMORY OPTIMIZATION (Increment 0028): Clean up on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("[AdaptiveLearning] ⚠️ Memory warning received - cleaning up")
                self?.cleanup()
            }
        }

        // MEMORY OPTIMIZATION (Increment 0028): Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let level = notification.userInfo?["level"] as? String {
                    print("[AdaptiveLearning] 🧹 Memory cleanup requested (\(level)) - cleaning up")
                    self?.cleanup()
                }
            }
        }
    }

    /// Clean up resources to reduce memory footprint
    private func cleanup() {
        print("[AdaptiveLearning] 🧹 Starting memory cleanup...")

        // Trim session history to 50 most recent
        let trimCount = max(0, sessionHistory.count - 50)
        if trimCount > 0 {
            sessionHistory = Array(sessionHistory.suffix(50))
            print("[AdaptiveLearning] 🧹 Trimmed \(trimCount) old sessions (kept 50 most recent)")
        }

        // Trim feature vectors to 100 most recent
        let featureTrimCount = max(0, successfulFeatureVectors.count - 100)
        if featureTrimCount > 0 {
            successfulFeatureVectors = Array(successfulFeatureVectors.suffix(100))
            print("[AdaptiveLearning] 🧹 Trimmed \(featureTrimCount) old feature vectors (kept 100)")
        }

        // Clear learned recommendations (will regenerate if needed)
        let recCount = learnedRecommendations.count
        learnedRecommendations.removeAll()
        print("[AdaptiveLearning] 🧹 Cleared \(recCount) cached recommendations")

        print("[AdaptiveLearning] ✅ Memory cleanup complete")
    }

    // MARK: - Core Learning Methods

    /// Record a complete soothing session with outcome
    /// - Parameters:
    ///   - cryType: Detected cry type
    ///   - soundType: Generator/sound type used
    ///   - wasSuccessful: Did the baby calm down?
    ///   - timeToCalm: Time in seconds until baby calmed
    ///   - cryIntensity: Initial cry intensity (0-1)
    ///   - features: Optional audio features for ML training
    func recordSession(
        cryType: CryType,
        soundType: GeneratorType,
        wasSuccessful: Bool,
        timeToCalm: TimeInterval?,
        cryIntensity: Double,
        features: ExtendedAudioFeatures? = nil
    ) {
        isLearning = true
        defer { isLearning = false }

        // Create session record
        let session = LearningSession(
            cryType: cryType,
            soundType: soundType,
            wasSuccessful: wasSuccessful,
            timeToCalm: timeToCalm,
            cryIntensity: cryIntensity,
            timestamp: Date()
        )

        sessionHistory.append(session)

        // Update effectiveness matrix with recency weighting
        updateEffectivenessMatrix(session: session)

        // Store feature vectors for successful sessions (for future on-device training)
        if wasSuccessful, let features = features {
            let featureVector = CryFeatureVector(
                cryType: cryType,
                features: features,
                timestamp: Date()
            )
            successfulFeatureVectors.append(featureVector)

            // MEMORY OPTIMIZATION (Increment 0028): Proactive trimming at 50% capacity
            let maxVectors = 100
            let proactiveTrimThreshold = maxVectors / 2 // 50 entries
            if successfulFeatureVectors.count >= proactiveTrimThreshold {
                let targetSize = Int(Double(proactiveTrimThreshold) * 0.8) // Trim to 40 entries (80% of threshold)
                if successfulFeatureVectors.count > targetSize {
                    let trimCount = successfulFeatureVectors.count - targetSize
                    successfulFeatureVectors.removeFirst(trimCount)
                    print("[AdaptiveLearning] 🧹 Proactive trim: removed \(trimCount) old vectors (now \(successfulFeatureVectors.count)/\(maxVectors))")
                }
            }

            // MEMORY OPTIMIZATION (Increment 0022): Reduced from 500 to 100 for memory efficiency
            // Emergency trim if exceeded max
            if successfulFeatureVectors.count > 100 {
                successfulFeatureVectors.removeFirst(successfulFeatureVectors.count - 100)
                print("[AdaptiveLearning] ⚠️ Emergency trim: capped at 100 vectors")
            }
        }

        // MEMORY OPTIMIZATION (Increment 0022): Reduced session history from 1000 to 200
        // LRU eviction - oldest sessions removed first
        if sessionHistory.count > 200 {
            sessionHistory.removeFirst(sessionHistory.count - 200)
        }

        // Persist and update metrics
        saveData()
        updateLearningMetrics()
        generateRecommendations()

        lastLearningUpdate = Date()

        print("AdaptiveLearning: Recorded session - \(cryType.rawValue) + \(soundType.rawValue) = \(wasSuccessful ? "SUCCESS" : "FAILED")")
    }

    /// Get personalized sound recommendations for a cry type
    /// - Parameter cryType: The detected cry type
    /// - Returns: Ranked list of recommended generators
    func getRecommendedSounds(for cryType: CryType) -> [GeneratorType] {
        let scores = effectivenessMatrix.getScores(for: cryType)

        // If we have learned data, use it
        if !scores.isEmpty {
            return scores
                .sorted { $0.value > $1.value }
                .filter { $0.value > 0.3 } // Only recommend if >30% effective
                .map { $0.key }
        }

        // Fallback to scientific defaults based on research
        return getResearchBasedDefaults(for: cryType)
    }

    /// Get the best single sound for a cry type
    func getBestSound(for cryType: CryType) -> GeneratorType? {
        return getRecommendedSounds(for: cryType).first
    }

    /// Get effectiveness score for a specific combination
    func getEffectivenessScore(cryType: CryType, soundType: GeneratorType) -> Double {
        return effectivenessMatrix.getScore(cryType: cryType, soundType: soundType)
    }

    // MARK: - Analytics & Insights

    /// Get "What Works" insights for UI display
    func getWhatWorksInsights() -> [WhatWorksInsight] {
        var insights: [WhatWorksInsight] = []

        // Get top sounds per cry type
        for cryType in CryType.allCases where cryType != .unknown {
            let sounds = getRecommendedSounds(for: cryType)
            if let topSound = sounds.first {
                let score = getEffectivenessScore(cryType: cryType, soundType: topSound)
                let sessions = getSessionCount(cryType: cryType, soundType: topSound)

                if sessions > 0 {
                    insights.append(WhatWorksInsight(
                        cryType: cryType,
                        bestSound: topSound,
                        effectivenessScore: score,
                        sessionCount: sessions,
                        averageTimeToCalm: getAverageTimeToCalm(cryType: cryType, soundType: topSound)
                    ))
                }
            }
        }

        return insights.sorted { $0.effectivenessScore > $1.effectivenessScore }
    }

    /// Get overall statistics
    func getOverallStats() -> LearningStats {
        let successful = sessionHistory.filter { $0.wasSuccessful }.count
        let total = sessionHistory.count
        let avgTimeToCalm = sessionHistory
            .compactMap { $0.timeToCalm }
            .reduce(0, +) / Double(max(1, sessionHistory.filter { $0.timeToCalm != nil }.count))

        return LearningStats(
            totalSessions: total,
            successfulSessions: successful,
            overallSuccessRate: total > 0 ? Double(successful) / Double(total) : 0,
            averageTimeToCalm: avgTimeToCalm,
            learningConfidence: learningConfidence,
            featureVectorsCollected: successfulFeatureVectors.count
        )
    }

    /// Get session count for a specific combination
    func getSessionCount(cryType: CryType, soundType: GeneratorType) -> Int {
        return sessionHistory.filter {
            $0.cryType == cryType && $0.soundType == soundType
        }.count
    }

    /// Get average time to calm for a combination
    func getAverageTimeToCalm(cryType: CryType, soundType: GeneratorType) -> TimeInterval? {
        let times = sessionHistory
            .filter { $0.cryType == cryType && $0.soundType == soundType && $0.wasSuccessful }
            .compactMap { $0.timeToCalm }

        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }

    // MARK: - Private Methods

    private func updateEffectivenessMatrix(session: LearningSession) {
        let currentScore = effectivenessMatrix.getScore(
            cryType: session.cryType,
            soundType: session.soundType
        )

        // Calculate new score with exponential moving average
        let successValue = session.wasSuccessful ? 1.0 : 0.0

        // Weight by time-to-calm (faster = better, normalized to 0-1)
        let timeWeight: Double
        if let timeToCalm = session.timeToCalm, session.wasSuccessful {
            // 30 seconds or less = 1.0, 5 minutes = 0.5, 10 minutes = 0.25
            timeWeight = max(0.25, 1.0 - (timeToCalm / 600.0))
        } else {
            timeWeight = session.wasSuccessful ? 0.7 : 0.0
        }

        let weightedSuccess = successValue * timeWeight

        // Exponential moving average with recency bias
        let alpha = 0.3 // Learning rate
        let newScore: Double
        if currentScore == 0 && sessionHistory.filter({
            $0.cryType == session.cryType && $0.soundType == session.soundType
        }).count == 1 {
            // First session for this combination
            newScore = weightedSuccess
        } else {
            newScore = alpha * weightedSuccess + (1 - alpha) * currentScore
        }

        effectivenessMatrix.setScore(
            cryType: session.cryType,
            soundType: session.soundType,
            score: newScore
        )
    }

    private func updateLearningMetrics() {
        totalLearningSessions = sessionHistory.count

        // Calculate learning confidence based on data quantity and variety
        let cryTypesCovered = Set(sessionHistory.map { $0.cryType }).count
        let soundTypesCovered = Set(sessionHistory.map { $0.soundType }).count
        let successRate = sessionHistory.isEmpty ? 0 : Double(sessionHistory.filter { $0.wasSuccessful }.count) / Double(sessionHistory.count)

        // Confidence formula: combination of data volume, variety, and success rate
        let volumeScore = min(1.0, Double(sessionHistory.count) / 50.0) // Max at 50 sessions
        let varietyScore = min(1.0, Double(cryTypesCovered * soundTypesCovered) / 25.0)
        let successScore = successRate

        learningConfidence = (volumeScore * 0.4 + varietyScore * 0.3 + successScore * 0.3)
    }

    private func generateRecommendations() {
        var recommendations: [LearnedSoundRecommendation] = []

        for cryType in CryType.allCases where cryType != .unknown {
            let sounds = getRecommendedSounds(for: cryType)
            for sound in sounds.prefix(3) {
                let score = getEffectivenessScore(cryType: cryType, soundType: sound)
                if score > 0.3 {
                    recommendations.append(LearnedSoundRecommendation(
                        cryType: cryType,
                        soundType: sound,
                        score: score,
                        confidence: learningConfidence
                    ))
                }
            }
        }

        learnedRecommendations = recommendations.sorted { $0.score > $1.score }
    }

    private func getResearchBasedDefaults(for cryType: CryType) -> [GeneratorType] {
        // Based on scientific research (Frontiers in AI 2024, DeepInfant)
        switch cryType {
        case .hunger:
            return [.shushing, .womb, .heartbeat, .aquarium]
        case .tired:
            return [.aquarium, .aquarium, .aquarium, .bells]
        case .pain:
            return [.aquarium, .shushing, .womb, .heartbeat]
        case .discomfort:
            return [.bells, .womb, .aquarium, .aquarium]
        case .attention:
            return [.musicBox, .chimes, .aquarium, .chimes]
        case .general, .unknown:
            return [.aquarium, .shushing, .womb, .bells]
        }
    }

    // MARK: - Persistence

    private func loadStoredData() {
        // Load effectiveness matrix
        if let data = userDefaults.data(forKey: matrixKey),
           let decoded = try? JSONDecoder().decode(CrySoundEffectivenessMatrix.self, from: data) {
            effectivenessMatrix = decoded
        }

        // Load session history
        if let data = userDefaults.data(forKey: sessionHistoryKey),
           let decoded = try? JSONDecoder().decode([LearningSession].self, from: data) {
            sessionHistory = decoded
        }

        // Load feature vectors
        if let data = userDefaults.data(forKey: featureVectorsKey),
           let decoded = try? JSONDecoder().decode([CryFeatureVector].self, from: data) {
            successfulFeatureVectors = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(effectivenessMatrix) {
            userDefaults.set(data, forKey: matrixKey)
        }

        if let data = try? JSONEncoder().encode(sessionHistory) {
            userDefaults.set(data, forKey: sessionHistoryKey)
        }

        if let data = try? JSONEncoder().encode(successfulFeatureVectors) {
            userDefaults.set(data, forKey: featureVectorsKey)
        }
    }

    // MARK: - Reset Methods

    /// Reset all learning data
    func resetAllLearning() {
        effectivenessMatrix = .empty
        sessionHistory = []
        successfulFeatureVectors = []
        learnedRecommendations = []
        learningConfidence = 0
        totalLearningSessions = 0
        lastLearningUpdate = nil
        saveData()
    }
}

// MARK: - Supporting Types

/// Cry-Sound effectiveness matrix
struct CrySoundEffectivenessMatrix: Codable {
    private var scores: [String: [String: Double]]

    static var empty: CrySoundEffectivenessMatrix {
        CrySoundEffectivenessMatrix(scores: [:])
    }

    func getScore(cryType: CryType, soundType: GeneratorType) -> Double {
        return scores[cryType.rawValue]?[soundType.rawValue] ?? 0
    }

    mutating func setScore(cryType: CryType, soundType: GeneratorType, score: Double) {
        if scores[cryType.rawValue] == nil {
            scores[cryType.rawValue] = [:]
        }
        scores[cryType.rawValue]?[soundType.rawValue] = score
    }

    func getScores(for cryType: CryType) -> [GeneratorType: Double] {
        guard let cryScores = scores[cryType.rawValue] else { return [:] }

        var result: [GeneratorType: Double] = [:]
        for (soundKey, score) in cryScores {
            if let soundType = GeneratorType(rawValue: soundKey) {
                result[soundType] = score
            }
        }
        return result
    }
}

/// Individual learning session record
struct LearningSession: Codable, Identifiable {
    let id: UUID
    let cryType: CryType
    let soundType: GeneratorType
    let wasSuccessful: Bool
    let timeToCalm: TimeInterval?
    let cryIntensity: Double
    let timestamp: Date

    init(
        cryType: CryType,
        soundType: GeneratorType,
        wasSuccessful: Bool,
        timeToCalm: TimeInterval?,
        cryIntensity: Double,
        timestamp: Date
    ) {
        self.id = UUID()
        self.cryType = cryType
        self.soundType = soundType
        self.wasSuccessful = wasSuccessful
        self.timeToCalm = timeToCalm
        self.cryIntensity = cryIntensity
        self.timestamp = timestamp
    }
}

/// Feature vector for ML training (stored for future on-device training)
struct CryFeatureVector: Codable {
    let id: UUID
    let cryType: CryType
    let mfcc: [Double] // MFCC coefficients (from melFrequencyCoeffs)
    let spectralCentroid: Double
    let spectralFlux: Double
    let rmsEnergy: Double
    let zeroCrossingRate: Double
    let timestamp: Date

    init(cryType: CryType, features: ExtendedAudioFeatures, timestamp: Date) {
        self.id = UUID()
        self.cryType = cryType
        self.mfcc = features.melFrequencyCoeffs
        self.spectralCentroid = features.spectralCentroid
        self.spectralFlux = features.spectralFlux
        self.rmsEnergy = features.rmsEnergy
        self.zeroCrossingRate = features.zeroCrossingRate
        self.timestamp = timestamp
    }
}

/// Learned sound recommendation
struct LearnedSoundRecommendation: Identifiable {
    let id = UUID()
    let cryType: CryType
    let soundType: GeneratorType
    let score: Double
    let confidence: Double
}

/// "What Works" insight for UI
struct WhatWorksInsight: Identifiable {
    let id = UUID()
    let cryType: CryType
    let bestSound: GeneratorType
    let effectivenessScore: Double
    let sessionCount: Int
    let averageTimeToCalm: TimeInterval?

    var formattedTimeToCalm: String? {
        guard let time = averageTimeToCalm else { return nil }
        if time < 60 {
            return "\(Int(time))s"
        } else {
            return "\(Int(time / 60))m \(Int(time.truncatingRemainder(dividingBy: 60)))s"
        }
    }
}

/// Overall learning statistics
struct LearningStats {
    let totalSessions: Int
    let successfulSessions: Int
    let overallSuccessRate: Double
    let averageTimeToCalm: TimeInterval
    let learningConfidence: Double
    let featureVectorsCollected: Int

    var formattedSuccessRate: String {
        return "\(Int(overallSuccessRate * 100))%"
    }

    var formattedTimeToCalm: String {
        if averageTimeToCalm < 60 {
            return "\(Int(averageTimeToCalm))s"
        } else {
            return "\(Int(averageTimeToCalm / 60))m"
        }
    }
}
