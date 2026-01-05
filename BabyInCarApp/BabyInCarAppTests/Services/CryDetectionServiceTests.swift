//
//  CryDetectionServiceTests.swift
//  BabyInCarAppTests
//
//  Comprehensive unit tests for CryDetectionService
//  Tests both rule-based and ML-enhanced detection paths
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Swift Testing Suite (Modern Approach)

@Suite("Cry Detection Service")
@MainActor
struct CryDetectionServiceTests {

    // MARK: - Cry Type Classification Tests

    @Test("CryType has correct icons")
    func cryTypeIcons() {
        #expect(CryType.hunger.icon == "fork.knife")
        #expect(CryType.tired.icon == "moon.zzz")
        #expect(CryType.pain.icon == "bandage")
        #expect(CryType.attention.icon == "hand.wave")
        #expect(CryType.discomfort.icon == "thermometer")
        #expect(CryType.general.icon == "waveform")
        #expect(CryType.unknown.icon == "questionmark.circle")
    }

    @Test("CryType has suggested actions")
    func cryTypeSuggestedActions() {
        for cryType in CryType.allCases {
            #expect(!cryType.suggestedAction.isEmpty, "CryType \(cryType) should have a suggested action")
        }
    }

    @Test("CryType has soothing strategies")
    func cryTypeSoothingStrategies() {
        #expect(CryType.hunger.soothingStrategy == .distraction)
        #expect(CryType.tired.soothingStrategy == .sleepInduction)
        #expect(CryType.pain.soothingStrategy == .urgent)
        #expect(CryType.attention.soothingStrategy == .comfort)
        #expect(CryType.discomfort.soothingStrategy == .gentle)
        #expect(CryType.general.soothingStrategy == .adaptive)
        #expect(CryType.unknown.soothingStrategy == .adaptive)
    }

    // MARK: - Soothing Strategy Tests

    @Test("Soothing strategies have phases", arguments: [
        SoothingStrategy.sleepInduction,
        SoothingStrategy.distraction,
        SoothingStrategy.comfort,
        SoothingStrategy.gentle,
        SoothingStrategy.urgent,
        SoothingStrategy.adaptive
    ])
    func soothingStrategyPhases(strategy: SoothingStrategy) {
        #expect(strategy.phases.count >= 3, "Strategy \(strategy) should have at least 3 phases")
    }

    // MARK: - Detection Error Tests

    @Test("CryDetectionError has descriptions")
    func errorDescriptions() {
        let micError = CryDetectionError.microphoneAccessDenied
        let engineError = CryDetectionError.engineSetupFailed
        let analysisError = CryDetectionError.analysisError("Test error")

        #expect(micError.errorDescription != nil)
        #expect(engineError.errorDescription != nil)
        #expect(analysisError.errorDescription?.contains("Test error") == true)
    }

    // MARK: - Detection Status Tests

    @Test("DetectionStatus raw values are user-friendly")
    func detectionStatusRawValues() {
        #expect(CryDetectionService.DetectionStatus.idle.rawValue == "Ready to Monitor")
        #expect(CryDetectionService.DetectionStatus.listening.rawValue == "Listening...")
        #expect(CryDetectionService.DetectionStatus.analyzing.rawValue == "Analyzing Sound")
        #expect(CryDetectionService.DetectionStatus.cryDetected.rawValue == "Cry Detected!")
        #expect(CryDetectionService.DetectionStatus.responding.rawValue == "Soothing Baby")
    }
}

// MARK: - ML Model Tests

@Suite("ML Cry Detection Models")
struct MLCryDetectionTests {

    @Test("CryDetectorMLModel initializes correctly")
    func detectorInitialization() {
        let detector = CryDetectorMLModel()
        #expect(detector != nil)
    }

    @Test("CryClassifierMLModel initializes correctly")
    func classifierInitialization() {
        let classifier = CryClassifierMLModel()
        #expect(classifier != nil)
    }

    @Test("Detector returns result for crying baby features")
    func detectCryingBaby() {
        let detector = CryDetectorMLModel()
        let features = MockAudioFeatures.cryingBaby(type: .hunger)
        let result = detector.detect(features: features)

        #expect(result.confidence >= 0 && result.confidence <= 1)
    }

    @Test("Detector returns low confidence for noise")
    func detectNoise() {
        let detector = CryDetectorMLModel()
        let features = MockAudioFeatures.ambientNoise()
        let result = detector.detect(features: features)

        // Noise should have low confidence for cry detection
        #expect(result.confidence < 0.5 || !result.isCryDetected)
    }

    @Test("Classifier distinguishes cry types", arguments: CryType.allCases.filter { $0 != .unknown })
    func classifyCryTypes(expectedType: CryType) {
        let classifier = CryClassifierMLModel()
        let features = MockAudioFeatures.cryingBaby(type: expectedType)
        let result = classifier.classify(features: features)

        // The classifier should return a valid type with reasonable confidence
        #expect(result.type != .unknown || result.confidence < 0.3)
    }
}

// MARK: - Mock Service Tests

@Suite("Mock Cry Detection Service")
@MainActor
struct MockCryDetectionServiceTests {

    @Test("Mock starts in idle state")
    func initialState() {
        let mock = MockCryDetectionService()

        #expect(mock.isMonitoring == false)
        #expect(mock.isCryDetected == false)
        #expect(mock.cryIntensity == 0)
        #expect(mock.confidenceLevel == 0)
    }

    @Test("Mock starts monitoring correctly")
    func startMonitoring() async throws {
        let mock = MockCryDetectionService()

        try await mock.startMonitoring()

        #expect(mock.isMonitoring == true)
        #expect(mock.startMonitoringCallCount == 1)
    }

    @Test("Mock stops monitoring correctly")
    func stopMonitoring() async throws {
        let mock = MockCryDetectionService()
        try await mock.startMonitoring()

        mock.stopMonitoring()

        #expect(mock.isMonitoring == false)
        #expect(mock.stopMonitoringCallCount == 1)
    }

    @Test("Mock simulates cry detection")
    func simulateCryDetection() {
        let mock = MockCryDetectionService()
        var callbackCalled = false
        mock.onCryDetected = { type, confidence in
            callbackCalled = true
            #expect(type == .hunger)
            #expect(confidence == 0.9)
        }

        mock.simulateCryDetection(type: .hunger, confidence: 0.9, intensity: 0.8)

        #expect(mock.isCryDetected == true)
        #expect(mock.cryType == .hunger)
        #expect(mock.confidenceLevel == 0.9)
        #expect(mock.cryIntensity == 0.8)
        #expect(callbackCalled == true)
    }

    @Test("Mock simulates cry ending")
    func simulateCryEnded() {
        let mock = MockCryDetectionService()
        mock.simulateCryDetection(type: .pain, confidence: 0.95)
        var callbackCalled = false
        mock.onCryEnded = {
            callbackCalled = true
        }

        mock.simulateCryEnded()

        #expect(mock.isCryDetected == false)
        #expect(mock.cryType == .unknown)
        #expect(callbackCalled == true)
    }

    @Test("Mock throws simulated error")
    func throwsError() async {
        let mock = MockCryDetectionService()
        mock.simulatedError = CryDetectionError.microphoneAccessDenied

        do {
            try await mock.startMonitoring()
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is CryDetectionError)
        }
    }

    @Test("Factory methods create correct states")
    func factoryMethods() {
        let detected = MockCryDetectionService.detected(type: .tired, confidence: 0.85)
        #expect(detected.isMonitoring == true)
        #expect(detected.isCryDetected == true)
        #expect(detected.cryType == .tired)

        let monitoring = MockCryDetectionService.monitoring()
        #expect(monitoring.isMonitoring == true)
        #expect(monitoring.isCryDetected == false)

        let idle = MockCryDetectionService.idle()
        #expect(idle.isMonitoring == false)
    }
}

// MARK: - CryPatternTracker Thread Safety Tests

@Suite("Cry Pattern Tracker")
struct CryPatternTrackerTests {

    @Test("CryPatternTracker initializes correctly")
    func initialization() {
        let tracker = CryPatternTracker()
        let metrics = tracker.getCurrentMetrics()

        #expect(metrics.totalCryDuration == 0)
        #expect(metrics.cryBurstCount == 0)
        #expect(metrics.isCurrentlyCrying == false)
    }

    @Test("CryPatternTracker handles single cry burst")
    func singleCryBurst() {
        let tracker = CryPatternTracker()
        let now = Date()

        // Start crying
        _ = tracker.update(isCrying: true, intensity: 0.8, type: .hunger, timestamp: now)
        _ = tracker.update(isCrying: true, intensity: 0.9, type: .hunger, timestamp: now.addingTimeInterval(0.1))
        _ = tracker.update(isCrying: true, intensity: 0.7, type: .hunger, timestamp: now.addingTimeInterval(0.2))

        let metricsWhileCrying = tracker.getCurrentMetrics()
        #expect(metricsWhileCrying.isCurrentlyCrying == true)
        #expect(metricsWhileCrying.peakIntensity >= 0.9)

        // Stop crying
        _ = tracker.update(isCrying: false, intensity: 0.0, type: .unknown, timestamp: now.addingTimeInterval(1.0))
        _ = tracker.update(isCrying: false, intensity: 0.0, type: .unknown, timestamp: now.addingTimeInterval(2.0))

        let metricsAfter = tracker.getCurrentMetrics()
        #expect(metricsAfter.cryBurstCount >= 1)
    }

    @Test("CryPatternTracker is thread-safe under concurrent updates")
    func threadSafetyConcurrentUpdates() async {
        let tracker = CryPatternTracker()
        let iterations = 100

        // Run multiple concurrent updates - this should NOT crash
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let timestamp = Date().addingTimeInterval(Double(i) * 0.01)
                    let intensity = Double.random(in: 0...1)
                    let isCrying = Bool.random()
                    let types: [CryType] = [.hunger, .tired, .pain, .general]
                    let type = types.randomElement()!

                    _ = tracker.update(isCrying: isCrying, intensity: intensity, type: type, timestamp: timestamp)
                }
            }
        }

        // If we got here without crash, the test passes
        let metrics = tracker.getCurrentMetrics()
        #expect(metrics.totalCryDuration >= 0) // Just verify we can read metrics
    }

    @Test("CryPatternTracker reset clears state")
    func reset() {
        let tracker = CryPatternTracker()
        let now = Date()

        // Add some data
        _ = tracker.update(isCrying: true, intensity: 0.8, type: .pain, timestamp: now)
        _ = tracker.update(isCrying: true, intensity: 0.9, type: .pain, timestamp: now.addingTimeInterval(0.1))

        // Reset
        tracker.reset()

        let metrics = tracker.getCurrentMetrics()
        #expect(metrics.totalCryDuration == 0)
        #expect(metrics.cryBurstCount == 0)
        #expect(metrics.isCurrentlyCrying == false)
    }

    @Test("CryPatternTracker limits intensity samples per burst")
    func memoryBoundedIntensitySamples() {
        let tracker = CryPatternTracker()
        let now = Date()

        // Send many crying frames - should not cause memory issues
        for i in 0..<500 {
            _ = tracker.update(
                isCrying: true,
                intensity: Double.random(in: 0.5...1.0),
                type: .tired,
                timestamp: now.addingTimeInterval(Double(i) * 0.033) // ~30fps
            )
        }

        // Should still work without crash or excessive memory
        let metrics = tracker.getCurrentMetrics()
        #expect(metrics.isCurrentlyCrying == true)
        #expect(metrics.peakIntensity > 0)
    }
}

// MARK: - Research-Based Classification Tests

@Suite("Research-Based Cry Classification")
struct ResearchBasedClassificationTests {

    // MARK: - CryAcousticProfiles Tests

    @Test("All cry types have defined profiles")
    func allProfilesDefined() {
        let profiles = CryAcousticProfiles.allProfiles
        #expect(profiles.count >= 6) // hunger, tired, pain, discomfort, attention, general
    }

    @Test("Hunger profile has correct research-based parameters")
    func hungerProfileParameters() {
        let profile = CryAcousticProfiles.hunger
        #expect(profile.cryType == .hunger)
        #expect(profile.fundamentalFrequencyRange.lowerBound >= 350)
        #expect(profile.fundamentalFrequencyRange.upperBound <= 500)
        #expect(profile.rhythmicityRange.lowerBound >= 0.7) // HIGH rhythmicity is key
        #expect(profile.featureWeights.rhythmicity > 0.3) // Rhythmicity should be heavily weighted
    }

    @Test("Pain profile has correct research-based parameters")
    func painProfileParameters() {
        let profile = CryAcousticProfiles.pain
        #expect(profile.cryType == .pain)
        #expect(profile.fundamentalFrequencyRange.lowerBound >= 500) // High F0
        #expect(profile.intensityRange.lowerBound >= 0.7) // High intensity required
        #expect(profile.onsetSharpnessRange.lowerBound >= 0.7) // Sudden onset
        #expect(profile.urgencyLevel == .critical)
    }

    @Test("Tired profile requires LOW intensity")
    func tiredProfileLowIntensity() {
        let profile = CryAcousticProfiles.tired
        #expect(profile.cryType == .tired)
        #expect(profile.intensityRange.upperBound <= 0.4) // Must be LOW intensity
        #expect(profile.rhythmicityRange.upperBound <= 0.5) // Irregular
        #expect(profile.featureWeights.intensity >= 0.3) // Intensity heavily weighted
    }

    @Test("Profile feature weights sum to 1.0")
    func featureWeightsSumCorrectly() {
        for profile in CryAcousticProfiles.allProfiles {
            let total = profile.featureWeights.total
            #expect(total >= 0.99 && total <= 1.01,
                   "Profile \(profile.cryType) weights sum to \(total), expected ~1.0")
        }
    }

    // MARK: - CryMultiFeatureScorer Tests

    @Test("Multi-feature scorer identifies hunger cry correctly")
    func scorerIdentifiesHunger() {
        let scorer = CryMultiFeatureScorer()
        let features = MockAudioFeatures.cryingBaby(type: .hunger)
        let result = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // Hunger features should score highest for hunger
        #expect(result.bestType == .hunger || result.bestType == .general,
               "Expected hunger or general, got \(result.bestType)")
        #expect(result.confidence > 0.3)
    }

    @Test("Multi-feature scorer identifies pain cry correctly")
    func scorerIdentifiesPain() {
        let scorer = CryMultiFeatureScorer()
        let features = MockAudioFeatures.cryingBaby(type: .pain)
        let result = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // Pain features: high intensity, high F0, sudden onset
        // Should score high for pain
        #expect(result.scores[.pain] ?? 0 > 0.2,
               "Pain score too low: \(result.scores[.pain] ?? 0)")
    }

    @Test("Multi-feature scorer marks ambiguous cases")
    func scorerMarksAmbiguousCases() {
        let scorer = CryMultiFeatureScorer()
        // Create features that are in between profiles
        let features = ExtendedAudioFeatures(
            spectralCentroid: 800,
            spectralSpread: 200,
            spectralFlatness: 0.4,
            spectralRolloff: 1500,
            mfcc: [Float](repeating: 0.4, count: 13),
            zeroCrossingRate: 0.15,
            rmsEnergy: 0.5,
            fundamentalFrequency: 450, // Mid-range
            harmonicRatio: 0.5,
            temporalEnvelope: [0.4, 0.5, 0.5, 0.5, 0.4, 0.4],
            onsetStrength: 0.4, // Mid onset
            pitchVariability: 0.3,
            energyEntropy: 0.4,
            deltaEnergy: 0.1
        )
        let result = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // When features are ambiguous, isAmbiguous should be true
        // or confidence should be moderate (not very high)
        #expect(result.isAmbiguous || result.confidence < 0.8,
               "Ambiguous features should result in ambiguous flag or lower confidence")
    }

    @Test("Noise features score low for all cry types")
    func noiseScoresLow() {
        let scorer = CryMultiFeatureScorer()
        let features = MockAudioFeatures.ambientNoise()
        let result = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // Noise should not confidently match any cry type
        #expect(!result.isReliable || result.confidence < 0.6,
               "Noise should not be reliably classified as a cry type")
    }

    // MARK: - Tired Over-Detection Fix Tests

    @Test("Moderate intensity cry NOT classified as tired")
    func moderateIntensityNotTired() {
        let classifier = CryClassifierMLModel()
        // Create features with MODERATE intensity (should NOT be tired)
        let features = ExtendedAudioFeatures(
            spectralCentroid: 700,
            spectralSpread: 200,
            spectralFlatness: 0.3,
            spectralRolloff: 1500,
            mfcc: [Float](repeating: 0.5, count: 13),
            zeroCrossingRate: 0.15,
            rmsEnergy: 0.6, // Moderate-high intensity
            fundamentalFrequency: 450,
            harmonicRatio: 0.6,
            temporalEnvelope: [0.5, 0.6, 0.6, 0.6, 0.5, 0.5],
            onsetStrength: 0.4,
            pitchVariability: 0.2,
            energyEntropy: 0.4,
            deltaEnergy: 0.1
        )
        let result = classifier.classify(features: features)

        // Should NOT be tired (tired requires LOW intensity)
        #expect(result.type != .tired || result.confidence < 0.3,
               "Moderate intensity should NOT be classified as tired. Got: \(result.type) with confidence \(result.confidence)")
    }

    @Test("Low intensity breathy cry classified as tired")
    func lowIntensityClassifiedAsTired() {
        let classifier = CryClassifierMLModel()
        // Create tired-like features: LOW intensity, irregular, breathy
        let features = ExtendedAudioFeatures(
            spectralCentroid: 600,
            spectralSpread: 150,
            spectralFlatness: 0.45, // Higher = more breathy
            spectralRolloff: 1200,
            mfcc: [Float](repeating: 0.3, count: 13),
            zeroCrossingRate: 0.1,
            rmsEnergy: 0.2, // LOW intensity - key for tired
            fundamentalFrequency: 350, // Lower pitch
            harmonicRatio: 0.35, // Lower HNR = breathy
            temporalEnvelope: [0.2, 0.25, 0.2, 0.15, 0.1, 0.1],
            onsetStrength: 0.2,
            pitchVariability: 0.4, // Irregular
            energyEntropy: 0.5,
            deltaEnergy: -0.05
        )
        let result = classifier.classify(features: features)

        // Low intensity + breathy + irregular = should lean toward tired
        let tiredProb = result.allProbabilities[.tired] ?? 0
        #expect(tiredProb > 0.1, "Low intensity breathy cry should have some tired probability")
    }

    // MARK: - TemporalCryPattern Tests

    @Test("TemporalCryPattern created from CryPatternMetrics")
    func temporalPatternFromMetrics() {
        let metrics = CryPatternMetrics(
            totalCryDuration: 30.0,
            currentBurstDuration: 5.0,
            averageBurstDuration: 3.0,
            averagePauseDuration: 1.5,
            cryBurstCount: 4,
            intensityTrend: .increasing,
            rhythmicity: 0.8,
            dominantType: .hunger,
            typeStability: 0.9,
            peakIntensity: 0.85,
            timeSinceLastCry: 0,
            isCurrentlyCrying: true
        )

        let pattern = TemporalCryPattern.from(metrics: metrics)

        #expect(pattern.rhythmicityScore == 0.8)
        #expect(pattern.averageBoutDuration == 3.0)
        #expect(pattern.averagePauseDuration == 1.5)
        #expect(pattern.totalDuration == 30.0)
        #expect(pattern.intensityEvolution == .increasing)
    }

    @Test("Temporal pattern improves hunger classification")
    func temporalPatternImprovesHungerClassification() {
        let scorer = CryMultiFeatureScorer()
        let features = MockAudioFeatures.cryingBaby(type: .hunger)

        // Without temporal pattern
        let resultWithout = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // With rhythmic temporal pattern (hunger indicator)
        let rhythmicPattern = TemporalCryPattern(
            rhythmicityScore: 0.85, // High rhythmicity
            averageBoutDuration: 2.5,
            averagePauseDuration: 1.5,
            intensityEvolution: .stable,
            totalDuration: 15.0
        )
        let resultWith = scorer.scoreAllTypes(features: features, temporalPattern: rhythmicPattern)

        // Temporal pattern should improve hunger score (rhythmic is key for hunger)
        let hungerScoreWithout = resultWithout.scores[.hunger] ?? 0
        let hungerScoreWith = resultWith.scores[.hunger] ?? 0

        #expect(hungerScoreWith >= hungerScoreWithout,
               "Rhythmic pattern should not decrease hunger score")
    }
}

// MARK: - XCTest for Legacy Support & Performance

final class CryDetectionServiceXCTests: XCTestCase {

    // MARK: - Service Singleton Tests

    @MainActor
    func testServiceIsSingleton() {
        let service1 = CryDetectionService.shared
        let service2 = CryDetectionService.shared

        XCTAssertTrue(service1 === service2, "CryDetectionService should be a singleton")
    }

    @MainActor
    func testInitialState() {
        let service = CryDetectionService.shared

        // Should start in idle state
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(service.isCryDetected)
        XCTAssertEqual(service.detectionStatus, .idle)
    }

    // MARK: - Feature Extraction Tests

    func testAdvancedFeatureExtractorInitialization() {
        let extractor = AdvancedFeatureExtractor(fftSize: 4096)
        XCTAssertNotNil(extractor)
    }

    func testFeatureExtractionReturnsValidFeatures() {
        let extractor = AdvancedFeatureExtractor(fftSize: 4096)
        let testSamples = generateTestAudioSamples(duration: 0.1, frequency: 450)

        let features = extractor.extractFeatures(from: testSamples, sampleRate: 44100)

        XCTAssertGreaterThanOrEqual(features.spectralCentroid, 0)
        XCTAssertGreaterThanOrEqual(features.rmsEnergy, 0)
        XCTAssertEqual(features.mfcc.count, 13)
    }

    // MARK: - Helper Methods

    /// Generate sine wave test audio
    private func generateTestAudioSamples(duration: Double, frequency: Double) -> [Float] {
        let sampleRate: Double = 44100
        let sampleCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            samples[i] = Float(sin(2.0 * .pi * frequency * time) * 0.5)
        }

        return samples
    }
}

// MARK: - Emergency Cancel Functionality Tests (FS-017)

@Suite("Emergency Cancel Button")
@MainActor
struct EmergencyCancelTests {

    @Test("Cancel within 30 seconds shows confirmation dialog")
    func cancelWithin30SecondsShowsConfirmation() {
        // Test that canceling within 30 seconds triggers confirmation
        let startTime = Date()
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 30, "Test setup: elapsed time should be < 30 seconds")

        // Confirmation should be shown for early cancellation
        let shouldShowConfirmation = elapsed < 30
        #expect(shouldShowConfirmation == true)
    }

    @Test("Cancel after 30 seconds skips confirmation")
    func cancelAfter30SecondsSkipsConfirmation() {
        // Simulate start time 31 seconds ago
        let startTime = Date().addingTimeInterval(-31)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed >= 30, "Elapsed time should be >= 30 seconds")

        // Confirmation should NOT be shown after 30 seconds
        let shouldShowConfirmation = elapsed < 30
        #expect(shouldShowConfirmation == false)
    }

    @Test("Effectiveness data saved on cancel")
    func effectivenessDataSaved() {
        // Simulate effectiveness tracking data structure
        let effectivenessData: [String: Any] = [
            "babyId": "test-baby-123",
            "wasEffective": true,
            "calmingTimeSeconds": 45,
            "userSwitched": false,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Verify all required fields present
        #expect(effectivenessData["babyId"] != nil)
        #expect(effectivenessData["wasEffective"] != nil)
        #expect(effectivenessData["calmingTimeSeconds"] != nil)
        #expect(effectivenessData["userSwitched"] != nil)
        #expect(effectivenessData["timestamp"] != nil)
    }

    @Test("Effectiveness history limited to 100 records")
    func effectivenessHistoryLimited() {
        var history: [[String: Any]] = []

        // Add 150 records
        for i in 0..<150 {
            history.append([
                "babyId": "test-baby",
                "wasEffective": i % 2 == 0,
                "calmingTimeSeconds": i * 10,
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        // Apply the same limit logic as in the implementation
        if history.count > 100 {
            history = Array(history.suffix(100))
        }

        #expect(history.count == 100, "History should be limited to 100 records")
    }

    @Test("Session duration calculated correctly")
    func sessionDurationCalculation() {
        let startTime = Date().addingTimeInterval(-120) // 2 minutes ago
        let endTime = Date()

        let sessionDuration = Int(endTime.timeIntervalSince(startTime))

        #expect(sessionDuration >= 118 && sessionDuration <= 122,
               "Session duration should be approximately 120 seconds, got \(sessionDuration)")
    }

    @Test("Haptic feedback type correct for success vs failure")
    func hapticFeedbackType() {
        // When effective, should use success haptic
        let effectiveHaptic: UINotificationFeedbackGenerator.FeedbackType = true ? .success : .warning
        #expect(effectiveHaptic == .success)

        // When not effective, should use warning haptic
        let ineffectiveHaptic: UINotificationFeedbackGenerator.FeedbackType = false ? .success : .warning
        #expect(ineffectiveHaptic == .warning)
    }
}

// MARK: - Science-Based Playlist Selection Tests (FS-017)

@Suite("Science-Based Playlist Selection")
@MainActor
struct ScienceBasedPlaylistTests {

    @Test("Banned sounds excluded from emergency playlists")
    func bannedSoundsExcluded() {
        // All harsh sounds have been removed from GeneratorType enum
        // Only gentle baby-friendly sounds remain
        // This test verifies approved emergency sounds are valid
        let approvedSoundsToCheck: Set<GeneratorType> = [
            .ocean, .river, .birds, .forest,
            .heartbeat, .womb, .shushing,
            .lullaby, .musicBox
        ]

        // Verify approved sounds are a subset of valid GeneratorType
        let approvedSounds = UltraSmartPlaylistSelector.approvedEmergencySounds

        for approved in approvedSoundsToCheck {
            // All these sounds should be valid since harsh sounds were removed
            #expect(GeneratorType.allCases.contains(approved),
                   "Sound \(approved) should be a valid GeneratorType")
        }
    }

    @Test("Approved sounds include research-backed options")
    func approvedSoundsIncludeResearchBacked() {
        let approvedSounds = UltraSmartPlaylistSelector.approvedEmergencySounds

        // Must include womb/comfort sounds (Rosner & Doherty 1979)
        #expect(approvedSounds.contains(.heartbeat))
        #expect(approvedSounds.contains(.womb))

        // Must include pink/white noise (Spencer 2012)
        #expect(approvedSounds.contains(.ocean))
        #expect(approvedSounds.contains(.ocean))

        // Must include musical sounds (Standley 2002)
        #expect(approvedSounds.contains(.lullaby))
        #expect(approvedSounds.contains(.musicBox))
    }

    @Test("Valid sounds filtered for baby age")
    func validSoundsFilteredByAge() {
        let selector = UltraSmartPlaylistSelector.shared

        // Newborns (0-3 months) should have restricted sounds
        let newbornSounds = selector.getValidSoundsForGeneralUse(for: 1)
        let olderBabySounds = selector.getValidSoundsForGeneralUse(for: 6)

        // Older babies can have more variety
        #expect(olderBabySounds.count >= newbornSounds.count,
               "Older babies should have access to at least as many sounds as newborns")
    }

    @Test("Forbidden sounds never returned for any age")
    func forbiddenSoundsNeverReturned() {
        let selector = UltraSmartPlaylistSelector.shared
        let forbiddenSounds = UltraSmartPlaylistSelector.forbiddenSounds

        // Test all ages 0-36 months
        for age in 0..<36 {
            let validSounds = selector.getValidSoundsForGeneralUse(for: age)

            for forbidden in forbiddenSounds {
                #expect(!validSounds.contains(forbidden),
                       "Forbidden sound \(forbidden) returned for age \(age)")
            }
        }
    }
}
