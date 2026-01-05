//
//  BabyMoodIntelligence.swift
//  BabyInCarApp
//
//  Main orchestrator for the Baby Mood Intelligence (BabyMIM) system.
//  Coordinates all AI components to provide intelligent, personalized soothing.
//

import Foundation
import Combine

// MARK: - Soothing Response

/// Complete response from the BabyMIM system
struct BabyMIMResponse {
    let id: UUID
    let timestamp: Date

    /// The soothing recommendation from LLM engine
    let recommendation: SoothingRecommendation

    /// The sound mix to play
    let soundMix: DynamicSoundMix

    /// Current context that influenced the decision
    let context: ContextSignals

    /// Cry analysis that was performed
    let cryAnalysis: BabyMIMCryAnalysis

    /// Mood prediction for the baby
    let moodPrediction: MoodPrediction

    /// Human-readable summary for display
    let summary: String

    /// Actionable tips for the parent
    let parentTips: [String]
}

/// Simplified cry analysis result for BabyMIM system
struct BabyMIMCryAnalysis {
    let type: CryType
    let confidence: Double
    let intensity: Double
    let features: ExtendedAudioFeatures?
    let voiceCharacteristics: VoiceCharacteristics?
    let distressLevel: Double
    let urgencyLevel: Double
}

// MARK: - Baby Mood Intelligence Service

/// Main orchestrator that coordinates all BabyMIM components
@MainActor
class BabyMoodIntelligence: ObservableObject {
    static let shared = BabyMoodIntelligence()

    // MARK: - Dependencies

    private let cryEmbedder = CryAudioEmbedder.shared
    private let contextCollector = ContextSignalCollector.shared
    private let profileManager = BabyMoodProfileManager.shared
    private let llmEngine = BabyMoodLLMEngine.shared
    private let soundMixer = DynamicSoundMixer.shared
    private let feedbackLoop = AdaptiveFeedbackLoop.shared
    private let cryDetectionService = CryDetectionService.shared
    private let gatekeeper = FreemiumGatekeeper.shared
    private let trialManager = TrialManager.shared

    // MARK: - Freemium Configuration

    /// Limits for free tier "What Works" insights
    static let freeWhatWorksLimit = 5
    /// Limits for premium tier "What Works" insights
    static let premiumWhatWorksLimit = 20

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentResponse: BabyMIMResponse?
    @Published var currentMood: BabyMood = .unknown
    @Published var moodConfidence: Double = 0
    @Published var lastInsight: ParentInsight?
    @Published var isProcessing: Bool = false

    // MARK: - Configuration

    @Published var isEnabled: Bool = true
    @Published var autoActivate: Bool = true
    @Published var useCloudAI: Bool = false

    // MARK: - Session State

    private var currentBaby: Baby?

    /// Current baby's mood profile (convenience accessor)
    var babyProfile: BabyMoodProfile? {
        guard let baby = currentBaby else { return nil }
        return profileManager.getProfile(for: baby.id)
    }
    private var responseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Audio Buffer

    private var recentAudioSamples: [Float] = []
    private let audioBufferSize = 44100 * 2 // 2 seconds at 44.1kHz

    private init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to cry detection
        cryDetectionService.$isCryDetected
            .dropFirst()
            .sink { [weak self] isCrying in
                Task { @MainActor in
                    if isCrying && self?.autoActivate == true && self?.isEnabled == true {
                        await self?.handleCryDetected()
                    } else if !isCrying {
                        self?.handleCryEnded()
                    }
                }
            }
            .store(in: &cancellables)

        // Subscribe to audio level for sample collection
        // In a real implementation, we'd get actual samples from the audio engine
    }

    // MARK: - Main Entry Point

    /// Handle cry detection event
    func handleCryDetected() async {
        guard !isProcessing else { return }
        guard let baby = currentBaby ?? loadActiveBaby() else {
            print("BabyMIM: No active baby configured")
            return
        }

        isProcessing = true
        isActive = true
        responseStartTime = Date()

        do {
            let response = try await generateResponse(for: baby)
            currentResponse = response

            // Start feedback loop monitoring
            feedbackLoop.startSession(
                for: baby.id,
                cryType: response.cryAnalysis.type,
                initialIntensity: response.cryAnalysis.intensity,
                recommendation: response.recommendation
            )

            // Play the sound mix
            soundMixer.play(response.soundMix)

            // Record sound started
            if let firstSound = response.soundMix.layers.first {
                feedbackLoop.recordSoundStarted(firstSound.sound)
            }

        } catch {
            print("BabyMIM: Failed to generate response: \(error)")
        }

        isProcessing = false
    }

    /// Generate a complete soothing response
    func generateResponse(for baby: Baby) async throws -> BabyMIMResponse {
        // 1. Get or create baby profile
        let profile = profileManager.getOrCreateProfile(for: baby)

        // 2. Extract cry embedding
        let embedding = extractCryEmbedding()

        // 3. Collect context signals
        let context = contextCollector.getCurrentContext(for: profile)

        // 4. Create cry analysis
        let cryAnalysis = BabyMIMCryAnalysis(
            type: cryDetectionService.cryType,
            confidence: cryDetectionService.confidenceLevel,
            intensity: cryDetectionService.cryIntensity,
            features: cryDetectionService.latestExtendedFeatures,
            voiceCharacteristics: cryDetectionService.latestVoiceCharacteristics,
            distressLevel: embedding.distressScore,
            urgencyLevel: embedding.urgencyLevel
        )

        // 5. Get LLM recommendation
        let recommendation = await llmEngine.analyzeSituation(
            cryEmbedding: embedding,
            context: context,
            profile: profile
        )

        // 6. Create dynamic sound mix
        let soundMix = soundMixer.createPersonalizedMix(
            for: profile,
            cryType: cryAnalysis.type,
            recommendation: recommendation
        )

        // 7. Get mood prediction
        let moodPrediction = await llmEngine.predictMood(
            profile: profile,
            context: context
        )

        // Update published mood state
        currentMood = moodPrediction.predictedMood
        moodConfidence = moodPrediction.confidence

        // 8. Generate summary and tips
        let summary = generateSummary(
            cryType: cryAnalysis.type,
            strategy: recommendation.primaryStrategy,
            profile: profile
        )

        let tips = generateTips(
            cryType: cryAnalysis.type,
            context: context,
            profile: profile
        )

        // 9. Check for new insights
        Task {
            if let insight = await llmEngine.generateInsight(
                profile: profile,
                recentSessions: []
            ) {
                await MainActor.run {
                    self.lastInsight = insight
                }
            }
        }

        return BabyMIMResponse(
            id: UUID(),
            timestamp: Date(),
            recommendation: recommendation,
            soundMix: soundMix,
            context: context,
            cryAnalysis: cryAnalysis,
            moodPrediction: moodPrediction,
            summary: summary,
            parentTips: tips
        )
    }

    /// Handle cry ended event
    private func handleCryEnded() {
        if isActive {
            // Don't immediately stop - let the soothing continue briefly
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                await MainActor.run {
                    if !self.cryDetectionService.isCryDetected {
                        // Still not crying - success!
                        self.feedbackLoop.endSession(wasSuccessful: true)
                    }
                }
            }
        }
    }

    // MARK: - Manual Control

    /// Manually activate BabyMIM for a baby
    func activate(for baby: Baby) async {
        currentBaby = baby
        await handleCryDetected()
    }

    /// Manually deactivate BabyMIM
    func deactivate() {
        isActive = false
        soundMixer.stopCurrentMix()
        feedbackLoop.endSession(wasSuccessful: false)
        currentResponse = nil
    }

    /// Set the active baby
    func setActiveBaby(_ baby: Baby) {
        currentBaby = baby
        UserDefaults.standard.set(try? JSONEncoder().encode(baby), forKey: "activeBaby")

        // Initialize profile
        _ = profileManager.getOrCreateProfile(for: baby)
    }

    // MARK: - Feedback Methods

    /// Called when parent presses "It Helped!"
    func recordHelped() {
        feedbackLoop.recordHelped()

        // Generate success insight
        if let profile = profileManager.activeProfile {
            Task {
                if let insight = await llmEngine.generateInsight(
                    profile: profile,
                    recentSessions: []
                ) {
                    await MainActor.run {
                        self.lastInsight = insight
                    }
                }
            }
        }
    }

    /// Called when parent presses "Not Working"
    func recordNotWorking() {
        feedbackLoop.recordNotHelped()

        // Try alternative approach
        if let response = currentResponse,
           let alternative = response.recommendation.alternativeIfFails {

            Task {
                await tryAlternativeApproach(alternative)
            }
        }
    }

    /// Try an alternative soothing approach
    private func tryAlternativeApproach(_ alternative: AlternativeRecommendation) async {
        guard let baby = currentBaby else { return }

        let profile = profileManager.getOrCreateProfile(for: baby)

        // Create a simple mix with the alternative sound
        let mix = soundMixer.createSimpleMix(
            primary: alternative.primarySound,
            for: profile
        )

        // Transition to new mix
        soundMixer.stopCurrentMix()
        soundMixer.play(mix)

        // Record new sound
        feedbackLoop.recordSoundStarted(alternative.primarySound)
    }

    // MARK: - Cry Embedding

    private func extractCryEmbedding() -> CryAudioEmbedding {
        // In a real implementation, we'd get actual audio samples
        // For now, use the cry detection service's features
        if !recentAudioSamples.isEmpty {
            return cryEmbedder.extractEmbedding(
                from: recentAudioSamples,
                babyId: currentBaby?.id
            )
        }

        // Create embedding from available features
        return createEmbeddingFromDetectionService()
    }

    private func createEmbeddingFromDetectionService() -> CryAudioEmbedding {
        // Create a synthetic embedding from cry detection service data
        let features = cryDetectionService.latestExtendedFeatures
        let voiceChars = cryDetectionService.latestVoiceCharacteristics

        return CryAudioEmbedding(
            id: UUID(),
            timestamp: Date(),
            fundamentalF0: Float(features?.fundamentalFrequency ?? 400),
            f0Variability: Float(features?.pitchVariability ?? 20),
            intensityEnvelope: [],
            harmonicStructure: [],
            formants: [
                Float(features?.formantF1 ?? 700),
                Float(features?.formantF2 ?? 1500),
                Float(features?.formantF3 ?? 2500)
            ],
            tremoloIntensity: Float(voiceChars?.tremoloDepth ?? 0),
            breathPattern: [],
            onsetSharpness: Float(features?.onsetSharpness ?? 0.5),
            voiceBreaks: voiceChars?.voiceBreaks ?? 0,
            vocalTension: Float(voiceChars?.tensionScore ?? 0.5),
            roughness: Float(voiceChars?.roughnessScore ?? 0.3),
            burstDuration: Float(features?.cryDuration ?? 2.0),
            pauseDuration: Float(features?.pauseDuration ?? 0.5),
            rhythmicity: Float(features?.rhythmicity ?? 0.5),
            escalationTrend: 0,
            spectralCentroid: Float(features?.spectralCentroid ?? 1000),
            spectralFlatness: Float(features?.spectralFlatness ?? 0.3),
            spectralRolloff: Float(features?.spectralRolloff ?? 3000),
            zeroCrossingRate: Float(features?.zeroCrossingRate ?? 0.1),
            voicePrint: [Float](repeating: 0, count: 128)
        )
    }

    // MARK: - Summary Generation

    private func generateSummary(
        cryType: CryType,
        strategy: SoothingStrategy,
        profile: BabyMoodProfile
    ) -> String {
        var parts: [String] = []

        parts.append("\(profile.babyName) seems \(cryType.rawValue.lowercased()).")

        switch strategy {
        case .sleepInduction:
            parts.append("I'm using calming sounds to help them sleep.")
        case .distraction:
            parts.append("I'm using engaging sounds for distraction.")
        case .comfort:
            parts.append("I'm providing comforting sounds.")
        case .urgent:
            parts.append("I'm using intense calming to capture attention first.")
        case .gentle:
            parts.append("I'm using gentle sounds to soothe.")
        case .adaptive:
            parts.append("I'm adapting the sounds based on their response.")
        }

        if profile.hasReliableData {
            let successRate = Int(profile.successRate * 100)
            parts.append("This approach has worked \(successRate)% of the time for \(profile.babyName).")
        }

        return parts.joined(separator: " ")
    }

    private func generateTips(
        cryType: CryType,
        context: ContextSignals,
        profile: BabyMoodProfile
    ) -> [String] {
        var tips: [String] = []

        // Add cry-type specific tips
        switch cryType {
        case .hunger:
            tips.append("The sounds will help calm them until feeding is ready.")
        case .tired:
            tips.append("Dimming lights can help alongside the sounds.")
        case .pain:
            tips.append("Check for any physical discomfort while sounds play.")
        case .discomfort:
            tips.append("Check diaper, clothing, or temperature.")
        case .attention:
            tips.append("Your presence combined with sounds works best.")
        default:
            break
        }

        // Add context-based tips
        if context.inCarMoving {
            tips.append("The car motion helps - sounds complement the natural rocking.")
        }

        if let sinceFeed = context.timeSinceLastFeed, sinceFeed > 3 * 3600 {
            tips.append("It's been a while since the last feed - they might be hungry.")
        }

        // Add profile-based tips
        if profile.rhythmSensitivity > 0.7 {
            tips.append("Gentle rocking or patting in rhythm can enhance the effect.")
        }

        return tips
    }

    // MARK: - Baby Loading

    private func loadActiveBaby() -> Baby? {
        guard let data = UserDefaults.standard.data(forKey: "activeBaby"),
              let baby = try? JSONDecoder().decode(Baby.self, from: data) else {
            return nil
        }
        return baby
    }

    // MARK: - Mood Monitoring

    /// Get current mood assessment
    func getCurrentMoodAssessment() async -> MoodAssessment {
        guard let baby = currentBaby,
              let profile = profileManager.getProfile(for: baby.id) else {
            return MoodAssessment(
                mood: .unknown,
                confidence: 0,
                factors: [],
                prediction: nil
            )
        }

        let context = contextCollector.getCurrentContext(for: profile)
        let prediction = await llmEngine.predictMood(profile: profile, context: context)

        return MoodAssessment(
            mood: prediction.predictedMood,
            confidence: prediction.confidence,
            factors: prediction.factors,
            prediction: prediction.timeToMoodChange.map {
                MoodAssessment.Prediction(
                    expectedMood: prediction.predictedMood,
                    timeUntil: $0
                )
            }
        )
    }

    struct MoodAssessment {
        let mood: BabyMood
        let confidence: Double
        let factors: [String]
        let prediction: Prediction?

        struct Prediction {
            let expectedMood: BabyMood
            let timeUntil: TimeInterval
        }
    }

    // MARK: - Insights

    /// Check if premium AI insights are available
    var hasPremiumAIInsights: Bool {
        trialManager.trialState.isActive || gatekeeper.hasPremiumAccess
    }

    /// Check if full What Works data is available
    var hasFullWhatWorksAccess: Bool {
        trialManager.trialState.isActive || gatekeeper.hasPremiumAccess
    }

    /// Get recent insights for display (freemium-aware)
    /// - Returns insights limited for free users, full for premium
    func getRecentInsights(limit: Int = 5) async -> [ParentInsight] {
        guard let profile = profileManager.activeProfile else {
            return []
        }

        var insights: [ParentInsight] = []

        // LLM-generated insights are PREMIUM ONLY
        // Free users still get cry detection and basic stats
        if hasPremiumAIInsights {
            // Generate insight from LLM engine (PREMIUM)
            if let insight = await llmEngine.generateInsight(profile: profile, recentSessions: []) {
                insights.append(insight)
            }
        }

        // Add effectiveness-based insights (available to all, but limited for free)
        let topSoundsLimit = hasFullWhatWorksAccess ? 3 : 1
        let topSounds = profile.getOverallBestSounds(limit: topSoundsLimit)
        if !topSounds.isEmpty, let best = topSounds.first {
            insights.append(ParentInsight(
                id: UUID(),
                timestamp: Date(),
                category: .preference,
                title: "Top Sound",
                message: "\(best.sound.rawValue) has a \(Int(best.score * 100))% success rate for \(profile.babyName).",
                actionSuggestion: nil,
                confidence: 0.85
            ))
        }

        // Add pattern insight if available (PREMIUM)
        if hasPremiumAIInsights {
            if !profile.typicalCryingTimes.isEmpty,
               let mostCommon = profile.typicalCryingTimes.first {
                insights.append(ParentInsight(
                    id: UUID(),
                    timestamp: Date(),
                    category: .pattern,
                    title: "Common Fussy Time",
                    message: "\(profile.babyName) often gets fussy around \(mostCommon.displayTime).",
                    actionSuggestion: "Try proactive soothing a few minutes before.",
                    confidence: 0.7
                ))
            }
        }

        return Array(insights.prefix(limit))
    }

    /// Get "What Works" data respecting freemium limits
    /// - Free: Top 5 sounds only
    /// - Premium: Full history and recommendations
    func getWhatWorksData() -> WhatWorksData {
        guard let profile = profileManager.activeProfile else {
            return WhatWorksData(topSounds: [], isLimited: true, limitReason: nil)
        }

        let limit = hasFullWhatWorksAccess
            ? Self.premiumWhatWorksLimit
            : Self.freeWhatWorksLimit

        let topSounds = profile.getOverallBestSounds(limit: limit)

        let isLimited = !hasFullWhatWorksAccess
        let totalSounds = profile.soundEffectiveness.count
        let limitReason: String? = isLimited && totalSounds > Self.freeWhatWorksLimit
            ? "Upgrade to Premium to see all \(totalSounds) sound insights"
            : nil

        return WhatWorksData(
            topSounds: topSounds,
            isLimited: isLimited,
            limitReason: limitReason,
            totalSoundsAvailable: totalSounds
        )
    }

    /// What Works data structure (freemium-aware)
    struct WhatWorksData {
        /// Top performing sounds (limited for free users)
        let topSounds: [(sound: GeneratorType, score: Double)]
        /// Whether the data is limited due to free tier
        let isLimited: Bool
        /// Human-readable reason for limitation
        let limitReason: String?
        /// Total sounds with effectiveness data
        var totalSoundsAvailable: Int = 0
    }

    // MARK: - Statistics

    /// Get learning statistics
    func getLearningStats() -> LearningStats {
        let feedbackStats = feedbackLoop.getLearningStats()

        return LearningStats(
            totalSessions: profileManager.activeProfile?.totalSessions ?? 0,
            successfulSessions: profileManager.activeProfile?.successfulSessions ?? 0,
            profileConfidence: profileManager.activeProfile?.profileConfidence ?? 0,
            learningEvents: feedbackStats.totalEvents,
            insightsGenerated: feedbackStats.insightsGenerated
        )
    }

    struct LearningStats {
        let totalSessions: Int
        let successfulSessions: Int
        let profileConfidence: Double
        let learningEvents: Int
        let insightsGenerated: Int

        var successRate: Double {
            guard totalSessions > 0 else { return 0 }
            return Double(successfulSessions) / Double(totalSessions)
        }
    }

    // MARK: - Analysis Summaries for Dashboard

    /// Get last analysis summary for UI display
    func getLastAnalysis() -> String {
        guard let profile = profileManager.activeProfile else {
            return "No analysis available yet. Start monitoring to learn about your baby."
        }

        let confidence = Int(profile.profileConfidence * 100)
        let sessions = profile.totalSessions

        if sessions == 0 {
            return "Ready to start learning about your baby's patterns."
        } else if sessions < 5 {
            return "Building initial profile based on \(sessions) session(s). Confidence: \(confidence)%"
        } else {
            return "Profile established with \(confidence)% confidence from \(sessions) sessions."
        }
    }

    /// Get detailed analysis for expanded view
    func getDetailedAnalysis() -> String {
        guard let profile = profileManager.activeProfile else {
            return "No detailed analysis available. The AI learns from each soothing session to understand your baby's unique preferences and patterns."
        }

        var analysis = "BabyMIM Analysis:\n\n"

        // Top sounds
        let topSounds = profile.soundEffectiveness
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key): \(Int($0.value * 100))% effective" }
            .joined(separator: "\n")

        if !topSounds.isEmpty {
            analysis += "Top Effective Sounds:\n\(topSounds)\n\n"
        }

        // Session stats
        analysis += "Sessions: \(profile.totalSessions) total, \(profile.successfulSessions) successful\n"
        analysis += "Profile Confidence: \(Int(profile.profileConfidence * 100))%"

        return analysis
    }
}
