//
//  BabyMoodLLMEngine.swift
//  BabyInCarApp
//
//  LLM-powered reasoning engine for intelligent soothing decisions.
//  Uses AI to analyze cry patterns, context, and history to recommend optimal strategies.
//

import Foundation
import UIKit

// MARK: - Soothing Recommendation

/// Comprehensive soothing recommendation from the LLM engine
struct SoothingRecommendation: Codable {
    let id: UUID
    let timestamp: Date

    /// Primary soothing strategy to use
    let primaryStrategy: SoothingStrategy

    /// Ordered sequence of sounds to play
    let soundSequence: [SoundSelection]

    /// Volume progression over time
    let volumeProgression: [Float]

    /// Estimated time to calm baby (seconds)
    let estimatedCalmingTime: TimeInterval

    /// Confidence in this recommendation (0-1)
    let confidenceScore: Double

    /// Human-readable reasoning for the recommendation
    let reasoning: String

    /// Key insights that led to this recommendation
    let insights: [String]

    /// Alternative recommendation if primary fails
    let alternativeIfFails: AlternativeRecommendation?

    /// Whether this is a novel/experimental recommendation
    let isNovelApproach: Bool

    /// Priority level (1-5, 5 being most urgent)
    let priorityLevel: Int
}

/// Single sound selection with timing and reasoning
struct SoundSelection: Codable {
    let sound: GeneratorType
    let duration: TimeInterval
    let volume: Float
    let pitchAdjustment: Float // -1 to 1
    let transitionStyle: TransitionStyle
    let reasonForChoice: String

    enum TransitionStyle: String, Codable {
        case immediate = "Immediate"
        case fade = "Fade"
        case crossfade = "Crossfade"
    }
}

/// Simplified alternative recommendation
struct AlternativeRecommendation: Codable {
    let strategy: SoothingStrategy
    let primarySound: GeneratorType
    let reason: String
}

// MARK: - Parent Insight

/// Natural language insight for parents
struct ParentInsight: Codable {
    let id: UUID
    let timestamp: Date
    let category: InsightCategory
    let title: String
    let message: String
    let actionSuggestion: String?
    let confidence: Double

    enum InsightCategory: String, Codable {
        case pattern = "Pattern Discovered"
        case preference = "Preference Learned"
        case prediction = "Prediction"
        case tip = "Helpful Tip"
        case milestone = "Milestone"
        case alert = "Important"
    }
}

// MARK: - LLM Engine Protocol

/// Protocol for LLM-based reasoning (supports both local and cloud implementations)
protocol BabyMoodLLMEngineProtocol {
    /// Analyze situation and generate soothing recommendation
    func analyzeSituation(
        cryEmbedding: CryAudioEmbedding,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) async -> SoothingRecommendation

    /// Generate insight for parents
    func generateInsight(
        profile: BabyMoodProfile,
        recentSessions: [SoothingSession]
    ) async -> ParentInsight?

    /// Predict upcoming mood based on patterns
    func predictMood(
        profile: BabyMoodProfile,
        context: ContextSignals
    ) async -> MoodPrediction
}

/// Mood prediction with timing
struct MoodPrediction: Codable {
    let predictedMood: BabyMood
    let timeToMoodChange: TimeInterval?
    let confidence: Double
    let factors: [String]
}

// MARK: - Baby Mood LLM Engine

/// Main LLM engine implementation that can use local rules or cloud AI
class BabyMoodLLMEngine: ObservableObject, BabyMoodLLMEngineProtocol {
    static let shared = BabyMoodLLMEngine()

    // MARK: - Configuration

    /// Whether to use cloud AI (requires API key)
    @Published var useCloudAI: Bool = false

    /// API endpoint for cloud AI (if enabled)
    var cloudAPIEndpoint: String?
    var cloudAPIKey: String?

    // MARK: - Learning Data

    /// Historical session outcomes for learning
    private var sessionHistory: [SoothingSession] = []

    // MEMORY OPTIMIZATION (Increment 0022): Reduced from 500 to 100 to prevent memory bloat
    // LRU eviction implemented in recordSessionOutcome() - oldest entries removed first
    private let maxHistorySize = 100

    // MARK: - Strategy Weights

    /// Learned effectiveness weights for different strategies
    private var strategyWeights: [String: [String: Double]] = [:]

    private init() {
        loadLearnedWeights()
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
            print("[BabyMoodLLM] ⚠️ Memory warning received - cleaning up")
            self?.cleanup()
        }

        // MEMORY OPTIMIZATION (Increment 0028): Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let level = notification.userInfo?["level"] as? String {
                print("[BabyMoodLLM] 🧹 Memory cleanup requested (\(level)) - cleaning up")
                self?.cleanup()
            }
        }
    }

    /// Clean up resources to reduce memory footprint
    private func cleanup() {
        print("[BabyMoodLLM] 🧹 Starting memory cleanup...")

        // Trim session history to 50 most recent (from 100 max)
        let trimCount = max(0, sessionHistory.count - 50)
        if trimCount > 0 {
            sessionHistory = Array(sessionHistory.suffix(50))
            print("[BabyMoodLLM] 🧹 Trimmed \(trimCount) old sessions (kept 50 most recent)")
        }

        // Clear strategy weights cache (will reload from disk if needed)
        let weightsCount = strategyWeights.count
        strategyWeights.removeAll()
        print("[BabyMoodLLM] 🧹 Cleared \(weightsCount) strategy weight caches")

        print("[BabyMoodLLM] ✅ Memory cleanup complete")
    }

    // MARK: - Main Analysis

    func analyzeSituation(
        cryEmbedding: CryAudioEmbedding,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) async -> SoothingRecommendation {
        // If cloud AI is enabled and configured, use it
        if useCloudAI, cloudAPIEndpoint != nil, cloudAPIKey != nil {
            if let cloudRecommendation = await getCloudRecommendation(
                embedding: cryEmbedding,
                context: context,
                profile: profile
            ) {
                return cloudRecommendation
            }
        }

        // Fall back to local intelligent reasoning
        return generateLocalRecommendation(
            embedding: cryEmbedding,
            context: context,
            profile: profile
        )
    }

    // MARK: - Local Reasoning Engine

    private func generateLocalRecommendation(
        embedding: CryAudioEmbedding,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) -> SoothingRecommendation {
        var insights: [String] = []

        // 1. Analyze cry characteristics
        let cryType = embedding.estimatedCryType
        let urgency = embedding.urgencyLevel
        let distress = embedding.distressScore

        insights.append("Cry type identified: \(cryType.rawValue)")

        if distress > 0.7 {
            insights.append("High distress level detected")
        }

        // 2. Consider context
        if context.inCarMoving {
            insights.append("Car motion detected - using motion-synced sounds")
        }

        if context.cryingEpisodesToday > 5 {
            insights.append("Multiple crying episodes today - trying fresh approach")
        }

        // 3. Select primary strategy
        let strategy = selectStrategy(
            cryType: cryType,
            urgency: urgency,
            context: context,
            profile: profile
        )

        insights.append("Selected strategy: \(strategy.rawValue)")

        // 4. Build sound sequence
        let soundSequence = buildSoundSequence(
            strategy: strategy,
            cryType: cryType,
            profile: profile,
            context: context
        )

        // 5. Calculate volume progression
        let volumeProgression = calculateVolumeProgression(
            strategy: strategy,
            intensity: Float(distress),
            profile: profile
        )

        // 6. Estimate calming time
        let estimatedTime = estimateCalmingTime(
            cryType: cryType,
            profile: profile,
            context: context
        )

        // 7. Generate reasoning
        let reasoning = generateReasoning(
            cryType: cryType,
            strategy: strategy,
            profile: profile,
            context: context
        )

        // 8. Calculate confidence
        let confidence = calculateConfidence(
            profile: profile,
            cryType: cryType,
            strategy: strategy
        )

        // 9. Determine if this is a novel approach
        let isNovel = shouldTryNovelApproach(context: context, profile: profile)

        // 10. Create alternative recommendation
        let alternative = createAlternative(
            currentStrategy: strategy,
            cryType: cryType,
            profile: profile
        )

        return SoothingRecommendation(
            id: UUID(),
            timestamp: Date(),
            primaryStrategy: strategy,
            soundSequence: soundSequence,
            volumeProgression: volumeProgression,
            estimatedCalmingTime: estimatedTime,
            confidenceScore: confidence,
            reasoning: reasoning,
            insights: insights,
            alternativeIfFails: alternative,
            isNovelApproach: isNovel,
            priorityLevel: calculatePriority(urgency: urgency, distress: distress)
        )
    }

    // MARK: - Strategy Selection

    private func selectStrategy(
        cryType: CryType,
        urgency: Double,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) -> SoothingStrategy {
        // Check if we have learned a successful strategy for this situation
        let key = "\(cryType.rawValue)_\(context.timeOfDay.rawValue)"

        if let weights = strategyWeights[key] {
            // Find highest weighted strategy
            if let best = weights.max(by: { $0.value < $1.value }),
               best.value > 0.6,
               let strategy = SoothingStrategy(rawValue: best.key) {
                return strategy
            }
        }

        // Use profile's historical best if available
        if let histStrategy = findBestHistoricalStrategy(
            cryType: cryType,
            profile: profile
        ) {
            return histStrategy
        }

        // Use context-suggested approach
        switch context.suggestedApproach {
        case .sleepFocused:
            return .sleepInduction
        case .motionSynced, .rhythmFocused:
            return .gentle
        case .novelty:
            return .adaptive
        case .escalated:
            return .urgent
        case .standard, .gentle:
            break
        }

        // Fall back to cry type default
        return cryType.soothingStrategy
    }

    private func findBestHistoricalStrategy(
        cryType: CryType,
        profile: BabyMoodProfile
    ) -> SoothingStrategy? {
        // Look at recent successful sessions
        let relevant = sessionHistory.filter {
            $0.cryType == cryType && $0.wasSuccessful
        }

        guard relevant.count >= 3 else { return nil }

        // Count strategy successes
        var strategyCounts: [SoothingStrategy: Int] = [:]
        for session in relevant {
            if let strategy = session.strategy {
                strategyCounts[strategy, default: 0] += 1
            }
        }

        return strategyCounts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Sound Sequence Building

    private func buildSoundSequence(
        strategy: SoothingStrategy,
        cryType: CryType,
        profile: BabyMoodProfile,
        context: ContextSignals
    ) -> [SoundSelection] {
        var sequence: [SoundSelection] = []

        // 1. Get baby's favorites for this cry type
        let favorites = profile.getBestSounds(for: cryType, limit: 3)

        // 2. Get strategy-appropriate sounds
        let strategySounds = getStrategySounds(
            strategy: strategy,
            ageMonths: profile.ageInMonths
        )

        // 3. Build sequence prioritizing favorites
        var usedSounds: Set<String> = []

        // First: Attention capture (shorter, engaging)
        let attentionSound = selectAttentionSound(
            favorites: favorites,
            strategy: strategySounds,
            age: profile.ageInMonths
        )
        sequence.append(SoundSelection(
            sound: attentionSound,
            duration: 15,
            volume: profile.optimalVolume,
            pitchAdjustment: Float(profile.pitchPreference) * 0.3,
            transitionStyle: .immediate,
            reasonForChoice: "Initial attention capture"
        ))
        usedSounds.insert(attentionSound.rawValue)

        // Second: Primary soothing (longer, calming)
        let primarySound = selectPrimarySound(
            favorites: favorites,
            strategy: strategySounds,
            excluding: usedSounds
        )
        sequence.append(SoundSelection(
            sound: primarySound,
            duration: 60,
            volume: profile.optimalVolume,
            pitchAdjustment: Float(profile.pitchPreference) * 0.3,
            transitionStyle: .crossfade,
            reasonForChoice: "Primary soothing based on baby's preferences"
        ))
        usedSounds.insert(primarySound.rawValue)

        // Third: Sustained calming (if needed)
        let sustainedSound = selectSustainedSound(
            favorites: favorites,
            strategy: strategySounds,
            excluding: usedSounds
        )
        sequence.append(SoundSelection(
            sound: sustainedSound,
            duration: 120,
            volume: profile.optimalVolume * 0.9,
            pitchAdjustment: Float(profile.pitchPreference) * 0.3,
            transitionStyle: .fade,
            reasonForChoice: "Sustained calming for deep relaxation"
        ))

        // Fourth: Sleep transition (if sleep-focused)
        if strategy == .sleepInduction {
            let sleepSound = selectSleepSound(age: profile.ageInMonths)
            sequence.append(SoundSelection(
                sound: sleepSound,
                duration: 300,
                volume: profile.optimalVolume * 0.7,
                pitchAdjustment: Float(profile.pitchPreference) * 0.2,
                transitionStyle: .fade,
                reasonForChoice: "Gentle transition to sleep"
            ))
        }

        return sequence
    }

    private func selectAttentionSound(
        favorites: [SoundPreference],
        strategy: [GeneratorType],
        age: Int
    ) -> GeneratorType {
        // Prefer a favorite that's engaging
        for fav in favorites {
            if let sound = fav.generatorType,
               sound.isEngaging {
                return sound
            }
        }

        // Age-appropriate engaging sound
        if age < 6 {
            return .shushing
        } else if age < 12 {
            return .musicBox
        } else {
            return .lullaby
        }
    }

    private func selectPrimarySound(
        favorites: [SoundPreference],
        strategy: [GeneratorType],
        excluding: Set<String>
    ) -> GeneratorType {
        // Best favorite not already used
        for fav in favorites {
            if let sound = fav.generatorType,
               !excluding.contains(sound.rawValue) {
                return sound
            }
        }

        // First strategy sound not used
        for sound in strategy where !excluding.contains(sound.rawValue) {
            return sound
        }

        return .aquarium
    }

    private func selectSustainedSound(
        favorites: [SoundPreference],
        strategy: [GeneratorType],
        excluding: Set<String>
    ) -> GeneratorType {
        // Prefer calming sounds for sustained phase
        let calmingSounds: [GeneratorType] = [.aquarium, .aquarium, .aquarium, .bells, .softPiano, .lullaby]

        for sound in calmingSounds where !excluding.contains(sound.rawValue) {
            return sound
        }

        return .aquarium
    }

    private func selectSleepSound(age: Int) -> GeneratorType {
        if age < 6 {
            return .womb
        } else if age < 12 {
            return .aquarium
        } else if age < 24 {
            return .aquarium
        } else {
            return .bells
        }
    }

    private func getStrategySounds(strategy: SoothingStrategy, ageMonths: Int) -> [GeneratorType] {
        // Sound selection based on soothing strategy and baby age
        switch strategy {
        case .sleepInduction:
            if ageMonths < 6 {
                return [.womb, .heartbeat, .shushing, .aquarium]
            } else if ageMonths < 12 {
                return [.aquarium, .aquarium, .womb, .aquarium]
            } else {
                return [.bells, .aquarium, .aquarium, .softPiano]
            }

        case .distraction:
            if ageMonths < 12 {
                return [.musicBox, .shushing, .chimes, .chimes]
            } else {
                return [.aquarium, .lullaby, .chimes, .musicBox]
            }

        case .comfort:
            if ageMonths < 6 {
                return [.heartbeat, .womb, .shushing]
            } else {
                return [.aquarium, .aquarium, .aquarium, .lullaby]
            }

        case .gentle:
            if ageMonths < 12 {
                return [.aquarium, .womb, .aquarium, .lullaby]
            } else {
                return [.aquarium, .bells, .aquarium, .softPiano]
            }

        case .urgent:
            if ageMonths < 6 {
                return [.shushing, .womb, .heartbeat, .aquarium]
            } else {
                return [.shushing, .aquarium, .womb, .aquarium]
            }

        case .adaptive:
            // Mix of engaging and calming
            return [.musicBox, .aquarium, .aquarium, .lullaby, .aquarium]
        }
    }

    // MARK: - Volume Progression

    private func calculateVolumeProgression(
        strategy: SoothingStrategy,
        intensity: Float,
        profile: BabyMoodProfile
    ) -> [Float] {
        let baseVolume = profile.optimalVolume

        switch strategy {
        case .sleepInduction:
            // Start moderate, gradually decrease
            return [baseVolume, baseVolume, baseVolume * 0.9, baseVolume * 0.8, baseVolume * 0.7]

        case .urgent:
            // Start higher to capture attention, then normalize
            return [baseVolume * 1.2, baseVolume * 1.1, baseVolume, baseVolume * 0.9, baseVolume * 0.85]

        case .gentle:
            // Consistently gentle
            return [baseVolume * 0.8, baseVolume * 0.8, baseVolume * 0.75, baseVolume * 0.7]

        default:
            // Standard progression
            return [baseVolume, baseVolume, baseVolume * 0.95, baseVolume * 0.9]
        }
    }

    // MARK: - Calming Time Estimation

    private func estimateCalmingTime(
        cryType: CryType,
        profile: BabyMoodProfile,
        context: ContextSignals
    ) -> TimeInterval {
        // Base estimate from profile
        var estimate = profile.averageCalmingTime

        // Adjust based on cry type
        switch cryType {
        case .pain:
            estimate *= 1.5 // Pain takes longer
        case .tired:
            estimate *= 0.8 // Often quicker if just tired
        case .hunger:
            estimate *= 1.2 // Won't fully resolve without feeding
        default:
            break
        }

        // Adjust based on context
        if context.cryingEpisodesToday > 5 {
            estimate *= 1.3 // More crying today = harder to calm
        }

        if !context.lastCalmingSuccess {
            estimate *= 1.2 // Recent failure increases estimate
        }

        // Adjust based on baby's responsiveness
        estimate *= (2.0 - profile.soothingResponsiveness)

        return max(30, min(300, estimate)) // Clamp between 30s and 5min
    }

    // MARK: - Reasoning Generation

    private func generateReasoning(
        cryType: CryType,
        strategy: SoothingStrategy,
        profile: BabyMoodProfile,
        context: ContextSignals
    ) -> String {
        var parts: [String] = []

        // Cry analysis
        parts.append("Based on the cry pattern, \(profile.babyName) appears to be \(cryType.rawValue.lowercased()).")

        // Historical success
        let favorites = profile.getBestSounds(for: cryType, limit: 1)
        if let topFav = favorites.first, let sound = topFav.generatorType {
            let successPercent = Int(topFav.successRate * 100)
            parts.append("\(sound.displayName) has worked \(successPercent)% of the time for this type of cry.")
        }

        // Context consideration
        if context.inCarMoving {
            parts.append("Since you're in the car, I'm using sounds that complement the motion.")
        }

        if context.timeOfDay == .night || context.timeOfDay == .lateNight {
            parts.append("Given the late hour, I'm focusing on sleep-inducing sounds.")
        }

        // Strategy explanation
        parts.append("Using a \(strategy.rawValue.lowercased()) approach.")

        return parts.joined(separator: " ")
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(
        profile: BabyMoodProfile,
        cryType: CryType,
        strategy: SoothingStrategy
    ) -> Double {
        var confidence = 0.5

        // Increase with profile data quality
        confidence += profile.profileConfidence * 0.2

        // Increase with historical success
        let favorites = profile.getBestSounds(for: cryType, limit: 3)
        if !favorites.isEmpty {
            let avgSuccess = favorites.reduce(0.0) { $0 + $1.successRate } / Double(favorites.count)
            confidence += avgSuccess * 0.2
        }

        // Increase with total sessions
        confidence += min(Double(profile.totalSessions) / 100.0, 0.1)

        return min(0.95, confidence)
    }

    // MARK: - Novel Approach Detection

    private func shouldTryNovelApproach(context: ContextSignals, profile: BabyMoodProfile) -> Bool {
        // Try something new if recent approaches haven't worked
        if !context.lastCalmingSuccess && context.cryingEpisodesToday > 3 {
            return true
        }

        // Occasionally try novelty based on baby's novelty preference
        if profile.noveltyPreference > 0.7 && Double.random(in: 0...1) < 0.2 {
            return true
        }

        return false
    }

    // MARK: - Alternative Recommendation

    private func createAlternative(
        currentStrategy: SoothingStrategy,
        cryType: CryType,
        profile: BabyMoodProfile
    ) -> AlternativeRecommendation {
        // Pick a different strategy
        let alternatives: [SoothingStrategy] = [.distraction, .urgent, .gentle, .comfort, .adaptive]
            .filter { $0 != currentStrategy }

        let altStrategy = alternatives.randomElement() ?? .adaptive

        // Pick a different sound
        let altSounds = getStrategySounds(strategy: altStrategy, ageMonths: profile.ageInMonths)
        let altSound = altSounds.first ?? .aquarium

        return AlternativeRecommendation(
            strategy: altStrategy,
            primarySound: altSound,
            reason: "Alternative approach if primary doesn't work within 2 minutes"
        )
    }

    // MARK: - Priority Calculation

    private func calculatePriority(urgency: Double, distress: Double) -> Int {
        let combined = (urgency + distress) / 2
        if combined > 0.8 { return 5 }
        if combined > 0.6 { return 4 }
        if combined > 0.4 { return 3 }
        if combined > 0.2 { return 2 }
        return 1
    }

    // MARK: - Parent Insights

    func generateInsight(
        profile: BabyMoodProfile,
        recentSessions: [SoothingSession]
    ) async -> ParentInsight? {
        // Pattern: Most effective time
        if let bestTime = findBestCalmingTime(sessions: recentSessions) {
            return ParentInsight(
                id: UUID(),
                timestamp: Date(),
                category: .pattern,
                title: "Best Soothing Time",
                message: "\(profile.babyName) calms fastest during \(bestTime.rawValue.lowercased()). Consider proactive soothing around this time.",
                actionSuggestion: "Try starting calming sounds a few minutes earlier during \(bestTime.rawValue.lowercased()).",
                confidence: 0.75
            )
        }

        // Preference: New favorite sound discovered
        if let newFavorite = findNewFavorite(profile: profile, sessions: recentSessions) {
            return ParentInsight(
                id: UUID(),
                timestamp: Date(),
                category: .preference,
                title: "New Favorite Sound!",
                message: "\(profile.babyName) really responds well to \(newFavorite.displayName). I've added it to the favorites.",
                actionSuggestion: nil,
                confidence: 0.8
            )
        }

        // Tip based on success rate
        if profile.successRate < 0.5 && profile.totalSessions >= 5 {
            return ParentInsight(
                id: UUID(),
                timestamp: Date(),
                category: .tip,
                title: "Try Something Different",
                message: "Recent soothing attempts have had mixed results. Try combining sounds with gentle rocking or change the volume level.",
                actionSuggestion: "Adjust volume or try a different sound category.",
                confidence: 0.6
            )
        }

        return nil
    }

    private func findBestCalmingTime(sessions: [SoothingSession]) -> TimeOfDay? {
        guard sessions.count >= 5 else { return nil }

        var successByTime: [TimeOfDay: (success: Int, total: Int)] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            let timeOfDay: TimeOfDay
            switch hour {
            case 5..<8: timeOfDay = .earlyMorning
            case 8..<12: timeOfDay = .morning
            case 12..<17: timeOfDay = .afternoon
            case 17..<20: timeOfDay = .evening
            case 20..<24: timeOfDay = .night
            default: timeOfDay = .lateNight
            }

            var record = successByTime[timeOfDay] ?? (0, 0)
            record.total += 1
            if session.wasSuccessful {
                record.success += 1
            }
            successByTime[timeOfDay] = record
        }

        return successByTime
            .filter { $0.value.total >= 2 }
            .max { a, b in
                Double(a.value.success) / Double(a.value.total) <
                Double(b.value.success) / Double(b.value.total)
            }?.key
    }

    private func findNewFavorite(profile: BabyMoodProfile, sessions: [SoothingSession]) -> GeneratorType? {
        // Find sounds that worked recently but aren't in top favorites
        let recentSuccesses = sessions
            .filter { $0.wasSuccessful }
            .flatMap { $0.soundsUsed }

        var soundCounts: [GeneratorType: Int] = [:]
        for sound in recentSuccesses {
            soundCounts[sound, default: 0] += 1
        }

        // Find one that appeared 3+ times recently
        for (sound, count) in soundCounts where count >= 3 {
            // Check if it's not already a top favorite
            let isTopFavorite = profile.getOverallBestSounds(limit: 3)
                .contains { $0.sound == sound }

            if !isTopFavorite {
                return sound
            }
        }

        return nil
    }

    // MARK: - Mood Prediction

    func predictMood(
        profile: BabyMoodProfile,
        context: ContextSignals
    ) async -> MoodPrediction {
        var factors: [String] = []
        var predictedMood = context.currentMood
        var timeToChange: TimeInterval? = nil

        // Check time-based patterns
        if profile.isTypicalCryingTime() {
            predictedMood = .fussy
            factors.append("Currently in typical fussy time")
            timeToChange = 0
        }

        // Check activity timing
        if let sinceFeed = context.timeSinceLastFeed, sinceFeed > 2.5 * 3600 {
            predictedMood = .hungry
            factors.append("Approaching feeding time")
            timeToChange = 3 * 3600 - sinceFeed
        }

        if let sinceSleep = context.timeSinceLastSleep, sinceSleep > 3 * 3600 {
            predictedMood = .sleepy
            factors.append("Approaching nap time")
            timeToChange = 4 * 3600 - sinceSleep
        }

        // Check special circumstances
        if context.activeCircumstances.contains(.teething) {
            factors.append("Teething may cause discomfort")
        }

        let confidence = min(0.9, 0.4 + profile.profileConfidence * 0.5)

        return MoodPrediction(
            predictedMood: predictedMood,
            timeToMoodChange: timeToChange,
            confidence: confidence,
            factors: factors
        )
    }

    // MARK: - Cloud AI Integration

    private func getCloudRecommendation(
        embedding: CryAudioEmbedding,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) async -> SoothingRecommendation? {
        guard let endpoint = cloudAPIEndpoint,
              let apiKey = cloudAPIKey else {
            return nil
        }

        // Prepare request payload
        let payload = CloudAIRequest(
            embedding: embedding,
            context: context,
            profile: profile
        )

        guard let requestData = try? JSONEncoder().encode(payload) else {
            return nil
        }

        // Make API request
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let cloudResponse = try JSONDecoder().decode(CloudAIResponse.self, from: data)
            return cloudResponse.recommendation
        } catch {
            print("Cloud AI request failed: \(error)")
            return nil
        }
    }

    // MARK: - Learning

    /// Record session outcome for learning
    func recordSessionOutcome(_ session: SoothingSession) {
        sessionHistory.append(session)

        // MEMORY OPTIMIZATION (Increment 0028): Proactive trimming at 50% capacity
        let proactiveTrimThreshold = maxHistorySize / 2 // 50 entries
        if sessionHistory.count >= proactiveTrimThreshold {
            let targetSize = Int(Double(proactiveTrimThreshold) * 0.8) // Trim to 40 entries (80% of threshold)
            if sessionHistory.count > targetSize {
                let trimCount = sessionHistory.count - targetSize
                sessionHistory.removeFirst(trimCount)
                print("[BabyMoodLLM] 🧹 Proactive trim: removed \(trimCount) old sessions (now \(sessionHistory.count)/\(maxHistorySize))")
            }
        }

        // Emergency trim if exceeded max
        if sessionHistory.count > maxHistorySize {
            sessionHistory.removeFirst(sessionHistory.count - maxHistorySize)
            print("[BabyMoodLLM] ⚠️ Emergency trim: capped at \(maxHistorySize) sessions")
        }

        // Update strategy weights
        if let cryType = session.cryType,
           let strategy = session.strategy {
            let key = "\(cryType.rawValue)_\(TimeOfDay.current.rawValue)"
            var weights = strategyWeights[key] ?? [:]

            let currentWeight = weights[strategy.rawValue] ?? 0.5
            let adjustment = session.wasSuccessful ? 0.1 : -0.05
            weights[strategy.rawValue] = max(0, min(1, currentWeight + adjustment))

            strategyWeights[key] = weights
        }

        saveLearnedWeights()
    }

    // MARK: - Persistence

    private func loadLearnedWeights() {
        if let data = UserDefaults.standard.data(forKey: "BabyMoodLLM_StrategyWeights"),
           let weights = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            strategyWeights = weights
        }
    }

    private func saveLearnedWeights() {
        if let data = try? JSONEncoder().encode(strategyWeights) {
            UserDefaults.standard.set(data, forKey: "BabyMoodLLM_StrategyWeights")
        }
    }
}

// MARK: - Cloud AI Types

private struct CloudAIRequest: Codable {
    let embedding: CryAudioEmbedding
    let context: ContextSignals
    let profile: BabyMoodProfile
}

private struct CloudAIResponse: Codable {
    let recommendation: SoothingRecommendation
}

// MARK: - Soothing Session (for history)

struct SoothingSession: Codable {
    let id: UUID
    let babyId: UUID
    let startTime: Date
    var endTime: Date?
    var cryType: CryType?
    var strategy: SoothingStrategy?
    var soundsUsed: [GeneratorType]
    var wasSuccessful: Bool
    var calmingDuration: TimeInterval?
    var feedback: SessionFeedback?

    init(babyId: UUID) {
        self.id = UUID()
        self.babyId = babyId
        self.startTime = Date()
        self.soundsUsed = []
        self.wasSuccessful = false
    }
}

struct SessionFeedback: Codable {
    let rating: Int // 1-5
    let comment: String?
}

// MARK: - Generator Type Extensions

extension GeneratorType {
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var isEngaging: Bool {
        switch self {
        case .musicBox, .shushing, .lullaby, .chimes, .aquarium:
            return true
        default:
            return false
        }
    }
}
