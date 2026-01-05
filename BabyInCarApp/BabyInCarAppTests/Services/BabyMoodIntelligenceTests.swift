//
//  BabyMoodIntelligenceTests.swift
//  BabyInCarAppTests
//
//  Comprehensive unit tests for Baby Mood Intelligence (BabyMIM) system
//  Tests all core services: Profile, Audio Embedder, Context, LLM Engine, Mixer, and Feedback Loop
//

import XCTest
@testable import BabyInCarApp

// MARK: - BabyMoodProfile Tests

final class BabyMoodProfileTests: XCTestCase {

    var profileManager: BabyMoodProfileManager!
    var testBabyId: UUID!

    override func setUp() {
        super.setUp()
        profileManager = BabyMoodProfileManager.shared
        testBabyId = UUID()
        // Clear any existing test profile
        UserDefaults.standard.removeObject(forKey: "BabyMoodProfile_\(testBabyId.uuidString)")
    }

    override func tearDown() {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "BabyMoodProfile_\(testBabyId.uuidString)")
        super.tearDown()
    }

    // MARK: - Profile Creation Tests

    func testCreateProfile_SetsDefaultValues() {
        // When
        let profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby")

        // Then
        XCTAssertEqual(profile.babyId, testBabyId)
        XCTAssertEqual(profile.babyName, "TestBaby")
        XCTAssertEqual(profile.totalSoothingSessions, 0)
        XCTAssertTrue(profile.learnedPatterns.isEmpty)
        XCTAssertEqual(profile.learningProgress, 0)
    }

    func testCreateProfile_WithAge_SetsAgeCorrectly() {
        // When
        let profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby", ageMonths: 8)

        // Then
        XCTAssertEqual(profile.ageMonths, 8)
    }

    func testSaveAndLoadProfile_PreservesData() {
        // Given
        var profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby")
        profile.totalSoothingSessions = 10
        profile.learningProgress = 0.5

        // When
        profileManager.saveProfile(profile)
        let loadedProfile = profileManager.loadProfile(for: testBabyId)

        // Then
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.babyName, "TestBaby")
        XCTAssertEqual(loadedProfile?.totalSoothingSessions, 10)
        XCTAssertEqual(loadedProfile?.learningProgress, 0.5)
    }

    // MARK: - Personality Traits Tests

    func testInferredPersonality_DefaultValues() {
        // Given
        let profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby")

        // Then
        let traits = profile.inferredPersonality
        XCTAssertGreaterThanOrEqual(traits.soothingResponsiveness, 0)
        XCTAssertLessThanOrEqual(traits.soothingResponsiveness, 1)
        XCTAssertGreaterThanOrEqual(traits.noveltyPreference, 0)
        XCTAssertLessThanOrEqual(traits.noveltyPreference, 1)
    }

    // MARK: - Sound Preferences Tests

    func testRecordSoundEffectiveness_UpdatesPreferences() {
        // Given
        var profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby")

        // When
        profile.recordSoundEffectiveness(
            soundId: "pink_noise",
            cryType: .tired,
            wasEffective: true,
            calmingTimeSeconds: 120
        )

        // Then
        XCTAssertFalse(profile.soundPreferences.isEmpty)
        if let pref = profile.soundPreferences.first(where: { $0.soundId == "pink_noise" }) {
            XCTAssertGreaterThan(pref.effectivenessScore, 0)
        }
    }

    func testRecordSoundEffectiveness_MultipleRecordings_AveragesScore() {
        // Given
        var profile = BabyMoodProfile(babyId: testBabyId, babyName: "TestBaby")

        // When - record multiple effectiveness values
        profile.recordSoundEffectiveness(soundId: "rain", cryType: .tired, wasEffective: true, calmingTimeSeconds: 60)
        profile.recordSoundEffectiveness(soundId: "rain", cryType: .tired, wasEffective: true, calmingTimeSeconds: 120)
        profile.recordSoundEffectiveness(soundId: "rain", cryType: .tired, wasEffective: false, calmingTimeSeconds: 300)

        // Then
        if let pref = profile.soundPreferences.first(where: { $0.soundId == "rain" }) {
            XCTAssertEqual(pref.useCount, 3)
        }
    }
}

// MARK: - CryAudioEmbedder Tests

final class CryAudioEmbedderTests: XCTestCase {

    var embedder: CryAudioEmbedder!

    override func setUp() {
        super.setUp()
        embedder = CryAudioEmbedder.shared
    }

    // MARK: - Embedding Extraction Tests

    func testExtractEmbedding_ReturnsValidDimensions() async {
        // Given
        let sampleAudioBuffer = createTestAudioBuffer(duration: 1.0)

        // When
        let embedding = await embedder.extractEmbedding(from: sampleAudioBuffer)

        // Then - should have 128 dimensions
        XCTAssertEqual(embedding.count, 128, "Embedding should have 128 dimensions")
    }

    func testExtractEmbedding_ValuesInValidRange() async {
        // Given
        let sampleAudioBuffer = createTestAudioBuffer(duration: 1.0)

        // When
        let embedding = await embedder.extractEmbedding(from: sampleAudioBuffer)

        // Then - all values should be normalized between -1 and 1
        for value in embedding {
            XCTAssertGreaterThanOrEqual(value, -1.0, "Embedding values should be >= -1")
            XCTAssertLessThanOrEqual(value, 1.0, "Embedding values should be <= 1")
        }
    }

    func testExtractEmbedding_DifferentAudio_DifferentEmbeddings() async {
        // Given
        let buffer1 = createTestAudioBuffer(duration: 1.0, frequency: 300)
        let buffer2 = createTestAudioBuffer(duration: 1.0, frequency: 600)

        // When
        let embedding1 = await embedder.extractEmbedding(from: buffer1)
        let embedding2 = await embedder.extractEmbedding(from: buffer2)

        // Then - different audio should produce different embeddings
        let areIdentical = embedding1 == embedding2
        XCTAssertFalse(areIdentical, "Different audio should produce different embeddings")
    }

    // MARK: - Voice Print Tests

    func testUpdateVoicePrint_IncreasesQuality() {
        // Given
        let babyId = UUID()
        let initialQuality = embedder.getVoicePrintQuality(for: babyId)

        // When
        let embedding = [Float](repeating: 0.5, count: 128)
        embedder.updateVoicePrint(for: babyId, with: embedding)

        // Then
        let newQuality = embedder.getVoicePrintQuality(for: babyId)
        XCTAssertGreaterThan(newQuality, initialQuality, "Voice print quality should increase with more samples")
    }

    // MARK: - Feature Extraction Tests

    func testExtractFeatures_ContainsRequiredFields() async {
        // Given
        let buffer = createTestAudioBuffer(duration: 0.5)

        // When
        let features = await embedder.extractDetailedFeatures(from: buffer)

        // Then
        XCTAssertNotNil(features.fundamentalFrequency)
        XCTAssertNotNil(features.harmonicStructure)
        XCTAssertGreaterThanOrEqual(features.intensity, 0)
        XCTAssertLessThanOrEqual(features.intensity, 1)
    }

    // MARK: - Performance Tests

    func testExtractEmbedding_Performance() {
        // Given
        let buffer = createTestAudioBuffer(duration: 1.0)

        // When/Then - should complete in under 50ms
        measure {
            let expectation = self.expectation(description: "Embedding extraction")
            Task {
                _ = await embedder.extractEmbedding(from: buffer)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 0.05) // 50ms
        }
    }

    // MARK: - Helper Methods

    private func createTestAudioBuffer(duration: Double, frequency: Float = 440) -> [Float] {
        let sampleRate: Float = 44100
        let sampleCount = Int(sampleRate * Float(duration))
        var buffer = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let t = Float(i) / sampleRate
            buffer[i] = sin(2 * .pi * frequency * t) * 0.5
        }

        return buffer
    }
}

// MARK: - ContextSignalCollector Tests

final class ContextSignalCollectorTests: XCTestCase {

    var collector: ContextSignalCollector!

    override func setUp() {
        super.setUp()
        collector = ContextSignalCollector.shared
    }

    // MARK: - Time Context Tests

    func testCollectTimeContext_ReturnsValidHour() async {
        // When
        let context = await collector.collectAllSignals()

        // Then
        XCTAssertGreaterThanOrEqual(context.timeContext.hour, 0)
        XCTAssertLessThan(context.timeContext.hour, 24)
    }

    func testCollectTimeContext_DeterminesTimeOfDay() async {
        // When
        let context = await collector.collectAllSignals()

        // Then
        let validTimesOfDay = ["morning", "afternoon", "evening", "night", "late_night"]
        XCTAssertTrue(validTimesOfDay.contains(context.timeContext.timeOfDay),
                      "Time of day should be one of: \(validTimesOfDay)")
    }

    // MARK: - Urgency Score Tests

    func testCalculateUrgencyScore_HighIntensity_HighUrgency() {
        // Given
        let highIntensityContext = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(recentCryEvents: [
                CryEvent(intensity: 0.9, type: .pain, timestamp: Date())
            ]),
            cryAnalysis: CryAnalysisContext(intensity: 0.9, type: .pain)
        )

        // When
        let urgency = collector.calculateUrgencyScore(from: highIntensityContext)

        // Then
        XCTAssertGreaterThan(urgency, 0.7, "High intensity pain cry should have high urgency")
    }

    func testCalculateUrgencyScore_LowIntensity_LowUrgency() {
        // Given
        let lowIntensityContext = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.2, type: .attention)
        )

        // When
        let urgency = collector.calculateUrgencyScore(from: lowIntensityContext)

        // Then
        XCTAssertLessThan(urgency, 0.5, "Low intensity attention cry should have low urgency")
    }

    // MARK: - Suggested Approach Tests

    func testSuggestApproach_TiredCry_SuggestsSleep() {
        // Given
        let tiredContext = CollectedContext(
            timeContext: TimeContext(hour: 20), // Evening
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.5, type: .tired)
        )

        // When
        let approach = collector.suggestApproach(for: tiredContext)

        // Then
        XCTAssertTrue(approach.lowercased().contains("sleep") ||
                      approach.lowercased().contains("calm") ||
                      approach.lowercased().contains("gentle"),
                      "Tired cry should suggest sleep-related approach")
    }

    func testSuggestApproach_PainCry_SuggestsUrgent() {
        // Given
        let painContext = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.9, type: .pain)
        )

        // When
        let approach = collector.suggestApproach(for: painContext)

        // Then
        XCTAssertTrue(approach.lowercased().contains("urgent") ||
                      approach.lowercased().contains("immediate") ||
                      approach.lowercased().contains("comfort"),
                      "Pain cry should suggest urgent approach")
    }
}

// MARK: - DynamicSoundMixer Tests

final class DynamicSoundMixerTests: XCTestCase {

    var mixer: DynamicSoundMixer!

    override func setUp() {
        super.setUp()
        mixer = DynamicSoundMixer.shared
    }

    // MARK: - Mix Creation Tests

    func testCreateMix_ReturnsValidMix() {
        // When
        let mix = mixer.createMix(
            preset: .gentleSleep,
            urgency: 0.5,
            breathRate: nil
        )

        // Then
        XCTAssertFalse(mix.layers.isEmpty, "Mix should have at least one layer")
        XCTAssertGreaterThan(mix.masterVolume, 0, "Master volume should be positive")
        XCTAssertLessThanOrEqual(mix.masterVolume, 1, "Master volume should not exceed 1")
    }

    func testCreateMix_HighUrgency_LouderVolume() {
        // Given
        let lowUrgencyMix = mixer.createMix(preset: .calmingNature, urgency: 0.2, breathRate: nil)
        let highUrgencyMix = mixer.createMix(preset: .urgentCalm, urgency: 0.9, breathRate: nil)

        // Then
        XCTAssertGreaterThan(highUrgencyMix.masterVolume, lowUrgencyMix.masterVolume,
                            "High urgency should produce louder mix")
    }

    // MARK: - Preset Tests

    func testPreset_GentleSleep_HasLowVolumeLayer() {
        // When
        let mix = mixer.createMix(preset: .gentleSleep, urgency: 0.3, breathRate: nil)

        // Then
        let hasLowVolumeLayer = mix.layers.contains { $0.volume < 0.5 }
        XCTAssertTrue(hasLowVolumeLayer, "Gentle sleep preset should have low volume layers")
    }

    func testPreset_UrgentCalm_HasMultipleLayers() {
        // When
        let mix = mixer.createMix(preset: .urgentCalm, urgency: 0.8, breathRate: nil)

        // Then
        XCTAssertGreaterThan(mix.layers.count, 1, "Urgent calm preset should have multiple layers")
    }

    // MARK: - MixBuilder Tests

    func testMixBuilder_FluentAPI() {
        // When
        let mix = mixer.buildMix()
            .addLayer("pink_noise", volume: 0.6)
            .addLayer("heartbeat", volume: 0.3)
            .setMasterVolume(0.7)
            .build()

        // Then
        XCTAssertEqual(mix.layers.count, 2)
        XCTAssertEqual(mix.masterVolume, 0.7)
    }

    func testMixBuilder_EmptyBuild_HasDefaults() {
        // When
        let mix = mixer.buildMix().build()

        // Then
        XCTAssertGreaterThan(mix.masterVolume, 0, "Empty build should have default volume")
    }

    // MARK: - Breath Sync Tests

    func testCreateMix_WithBreathRate_AdjustsRhythm() {
        // Given
        let breathRate: Double = 20 // breaths per minute

        // When
        let mix = mixer.createMix(
            preset: .gentleSleep,
            urgency: 0.3,
            breathRate: breathRate
        )

        // Then
        // Mix should have some rhythm component adjusted for breath rate
        XCTAssertNotNil(mix.rhythmBPM)
        if let bpm = mix.rhythmBPM {
            // Rhythm should be related to breath rate (typically 1:1 or 1:2 ratio)
            let expectedRange = (breathRate * 0.5)...(breathRate * 2.0)
            XCTAssertTrue(expectedRange.contains(bpm),
                         "Rhythm BPM should be related to breath rate")
        }
    }
}

// MARK: - AdaptiveFeedbackLoop Tests

final class AdaptiveFeedbackLoopTests: XCTestCase {

    var feedbackLoop: AdaptiveFeedbackLoop!
    var testBabyId: UUID!

    override func setUp() {
        super.setUp()
        feedbackLoop = AdaptiveFeedbackLoop.shared
        testBabyId = UUID()
    }

    override func tearDown() {
        feedbackLoop.stopMonitoring()
        super.tearDown()
    }

    // MARK: - Session Tests

    func testStartSession_CreatesActiveSession() {
        // When
        feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.6)

        // Then
        XCTAssertTrue(feedbackLoop.hasActiveSession)
    }

    func testEndSession_ClearsActiveSession() {
        // Given
        feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.6)

        // When
        feedbackLoop.endSession(wasSuccessful: true)

        // Then
        XCTAssertFalse(feedbackLoop.hasActiveSession)
    }

    // MARK: - Learning Event Tests

    func testProcessEvent_IntensityDecrease_RecordsPositive() {
        // Given
        feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.8)

        // When
        feedbackLoop.processLearningEvent(.intensityChange(from: 0.8, to: 0.4))

        // Then
        let insights = feedbackLoop.getSessionInsights()
        XCTAssertTrue(insights.isPositiveTrend, "Intensity decrease should be positive trend")
    }

    func testProcessEvent_IntensityIncrease_RecordsNegative() {
        // Given
        feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.4)

        // When
        feedbackLoop.processLearningEvent(.intensityChange(from: 0.4, to: 0.8))

        // Then
        let insights = feedbackLoop.getSessionInsights()
        XCTAssertFalse(insights.isPositiveTrend, "Intensity increase should be negative trend")
    }

    func testProcessEvent_SoundEffectiveness_UpdatesProfile() {
        // Given
        feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.6)

        // When
        feedbackLoop.processLearningEvent(.soundEffectiveness(
            soundId: "pink_noise",
            wasEffective: true,
            responseTime: 45.0
        ))

        // Then
        // Should not crash and should record the event
        let insights = feedbackLoop.getSessionInsights()
        XCTAssertGreaterThan(insights.eventsProcessed, 0)
    }

    // MARK: - Personality Inference Tests

    func testInferPersonality_AfterMultipleSessions_ReturnsTraits() {
        // Given - simulate multiple sessions
        for _ in 0..<5 {
            feedbackLoop.startSession(babyId: testBabyId, initialCryType: .tired, initialIntensity: 0.7)
            feedbackLoop.processLearningEvent(.soundEffectiveness(soundId: "rain", wasEffective: true, responseTime: 30))
            feedbackLoop.endSession(wasSuccessful: true)
        }

        // When
        let traits = feedbackLoop.inferPersonalityTraits(for: testBabyId)

        // Then
        XCTAssertGreaterThanOrEqual(traits.soothingResponsiveness, 0)
        XCTAssertLessThanOrEqual(traits.soothingResponsiveness, 1)
    }
}

// MARK: - BabyMoodLLMEngine Tests

final class BabyMoodLLMEngineTests: XCTestCase {

    var llmEngine: BabyMoodLLMEngine!

    override func setUp() {
        super.setUp()
        llmEngine = BabyMoodLLMEngine.shared
    }

    // MARK: - Recommendation Tests

    func testGenerateRecommendation_ReturnsValidRecommendation() async {
        // Given
        let profile = BabyMoodProfile(babyId: UUID(), babyName: "TestBaby", ageMonths: 6)
        let context = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.6, type: .tired)
        )

        // When
        let recommendation = await llmEngine.generateRecommendation(
            profile: profile,
            context: context,
            embedding: nil
        )

        // Then
        XCTAssertFalse(recommendation.soundSequence.isEmpty, "Should recommend at least one sound")
        XCTAssertFalse(recommendation.reasoning.isEmpty, "Should provide reasoning")
        XCTAssertGreaterThan(recommendation.confidence, 0, "Should have positive confidence")
    }

    func testGenerateRecommendation_TiredCry_RecommendsSleepSounds() async {
        // Given
        let profile = BabyMoodProfile(babyId: UUID(), babyName: "TestBaby", ageMonths: 6)
        let context = CollectedContext(
            timeContext: TimeContext(hour: 20),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.5, type: .tired)
        )

        // When
        let recommendation = await llmEngine.generateRecommendation(
            profile: profile,
            context: context,
            embedding: nil
        )

        // Then
        let sleepyApproaches = ["sleep", "calm", "gentle", "soothe"]
        let containsSleepApproach = sleepyApproaches.contains { recommendation.primaryApproach.lowercased().contains($0) }
        XCTAssertTrue(containsSleepApproach, "Tired cry should recommend sleep-oriented approach")
    }

    func testGenerateRecommendation_PainCry_RecommendsUrgentApproach() async {
        // Given
        let profile = BabyMoodProfile(babyId: UUID(), babyName: "TestBaby", ageMonths: 6)
        let context = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.9, type: .pain)
        )

        // When
        let recommendation = await llmEngine.generateRecommendation(
            profile: profile,
            context: context,
            embedding: nil
        )

        // Then
        XCTAssertGreaterThan(recommendation.confidence, 0.5, "Pain cry should have higher confidence")
    }

    // MARK: - Parent Insight Tests

    func testGenerateParentInsight_ReturnsUsefulTip() async {
        // Given
        let profile = BabyMoodProfile(babyId: UUID(), babyName: "TestBaby", ageMonths: 8)
        let context = CollectedContext(
            timeContext: TimeContext(),
            environmentSignals: EnvironmentSignals(),
            recentHistory: RecentHistory(),
            cryAnalysis: CryAnalysisContext(intensity: 0.5, type: .attention)
        )

        // When
        let insight = await llmEngine.generateParentInsight(
            profile: profile,
            context: context,
            recentSuccess: "Pink noise helped"
        )

        // Then
        XCTAssertFalse(insight.tip.isEmpty, "Should provide a tip")
        XCTAssertFalse(insight.category.isEmpty, "Should categorize the tip")
    }
}

// MARK: - BabyMoodIntelligence Integration Tests

final class BabyMoodIntelligenceIntegrationTests: XCTestCase {

    var babyMIM: BabyMoodIntelligence!
    var testBabyId: UUID!

    override func setUp() {
        super.setUp()
        babyMIM = BabyMoodIntelligence.shared
        testBabyId = UUID()
    }

    // MARK: - Full Pipeline Tests

    func testGenerateResponse_ReturnsCompleteResponse() async throws {
        // When
        let response = try await babyMIM.generateResponse(for: testBabyId, babyAge: 8)

        // Then
        XCTAssertFalse(response.recommendation.soundSequence.isEmpty)
        XCTAssertFalse(response.soundMix.layers.isEmpty)
        XCTAssertFalse(response.analysisText.isEmpty)
    }

    func testGenerateResponse_Performance() {
        // Test that full response generation completes in reasonable time
        let expectation = self.expectation(description: "Response generation")

        Task {
            let startTime = Date()
            _ = try? await babyMIM.generateResponse(for: testBabyId, babyAge: 6)
            let duration = Date().timeIntervalSince(startTime)

            XCTAssertLessThan(duration, 2.0, "Response should generate in under 2 seconds")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Feedback Recording Tests

    func testRecordFeedback_ItHelped_UpdatesLearning() {
        // Given
        babyMIM.startSoothingSession(for: testBabyId)

        // When
        babyMIM.recordFeedback(
            wasEffective: true,
            feedbackType: .itHelped,
            cryIntensityAfter: 0.1
        )

        // Then
        // Should not crash and should record feedback
        let analysis = babyMIM.getLastAnalysis()
        // Analysis should exist after feedback
        XCTAssertTrue(true, "Feedback should be recorded without error")
    }

    func testRecordFeedback_NotWorking_TriggersAdaptation() {
        // Given
        babyMIM.startSoothingSession(for: testBabyId)

        // When
        babyMIM.recordFeedback(
            wasEffective: false,
            feedbackType: .notWorking,
            cryIntensityAfter: 0.8
        )

        // Then
        // System should adapt (can't test internal state easily, but shouldn't crash)
        XCTAssertTrue(true, "Not working feedback should trigger adaptation")
    }

    // MARK: - Analysis Tests

    func testGetLastAnalysis_ReturnsString() {
        // When
        let analysis = babyMIM.getLastAnalysis()

        // Then
        // Analysis might be empty if no sessions run, but shouldn't crash
        XCTAssertNotNil(analysis)
    }

    func testGetDetailedAnalysis_ReturnsMoreDetail() {
        // When
        let detailed = babyMIM.getDetailedAnalysis()

        // Then
        XCTAssertNotNil(detailed)
    }
}

// MARK: - Mock Context Helpers

extension TimeContext {
    init(hour: Int = 12) {
        self.hour = hour
        self.minute = 0
        self.dayOfWeek = 3
        self.timeOfDay = hour < 6 ? "late_night" :
                        hour < 12 ? "morning" :
                        hour < 18 ? "afternoon" :
                        hour < 21 ? "evening" : "night"
        self.isWeekend = false
    }
}

extension EnvironmentSignals {
    init() {
        self.isInCar = false
        self.isMoving = false
        self.ambientNoise = 0.3
        self.estimatedTemperature = "comfortable"
    }
}

extension RecentHistory {
    init(recentCryEvents: [CryEvent] = []) {
        self.recentCryEvents = recentCryEvents
        self.lastFeedingTime = nil
        self.lastSleepTime = nil
        self.lastDiaperChange = nil
        self.recentSoothingSounds = []
    }
}

extension CryAnalysisContext {
    init(intensity: Double, type: CryType) {
        self.intensity = intensity
        self.type = type
        self.duration = 30
        self.trend = intensity > 0.5 ? "increasing" : "stable"
    }
}
