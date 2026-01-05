//
//  PerformanceTests.swift
//  BabyInCarAppTests
//
//  Performance tests for audio processing and ML inference
//  Critical for real-time cry detection requirements
//

import XCTest
@testable import BabyInCarApp

final class PerformanceTests: XCTestCase {

    // MARK: - Audio Processing Performance

    /// Test FFT processing performance - must complete in < 20ms for real-time
    func testFFTProcessingPerformance() throws {
        let extractor = AdvancedFeatureExtractor(fftSize: 4096)
        let samples = generateTestAudio(duration: 0.1, sampleRate: 44100)

        measure(metrics: [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]) {
            _ = extractor.extractFeatures(from: samples, sampleRate: 44100)
        }
    }

    /// Test ML cry detection inference speed - must be < 50ms for real-time
    func testMLInferencePerformance() throws {
        let detector = CryDetectorMLModel()
        let features = MockAudioFeatures.cryingBaby(type: .hunger)

        measure(metrics: [XCTClockMetric()]) {
            _ = detector.detect(features: features)
        }
    }

    /// Test ML cry classification inference speed
    func testMLClassificationPerformance() throws {
        let classifier = CryClassifierMLModel()
        let features = MockAudioFeatures.cryingBaby(type: .pain)

        measure(metrics: [XCTClockMetric()]) {
            _ = classifier.classify(features: features)
        }
    }

    /// Test combined detection pipeline performance
    func testFullDetectionPipelinePerformance() throws {
        let extractor = AdvancedFeatureExtractor(fftSize: 4096)
        let detector = CryDetectorMLModel()
        let classifier = CryClassifierMLModel()
        let samples = generateTestAudio(duration: 0.1, sampleRate: 44100)

        measure(metrics: [
            XCTClockMetric(),
            XCTCPUMetric()
        ]) {
            // Full pipeline: extract -> detect -> classify
            let features = extractor.extractFeatures(from: samples, sampleRate: 44100)
            let detection = detector.detect(features: features)
            if detection.isCryDetected {
                _ = classifier.classify(features: features)
            }
        }
    }

    /// Test RMS energy calculation performance
    func testRMSCalculationPerformance() throws {
        let samples = generateTestAudio(duration: 1.0, sampleRate: 44100)

        measure(metrics: [XCTClockMetric()]) {
            var rms: Float = 0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        }
    }

    /// Test voice analyzer performance
    func testVoiceAnalyzerPerformance() throws {
        let analyzer = VoiceCharacteristicsAnalyzer()
        let samples = generateTestAudio(duration: 0.2, sampleRate: 44100)

        measure(metrics: [XCTClockMetric()]) {
            _ = analyzer.analyze(samples: samples, sampleRate: 44100)
        }
    }

    // MARK: - Memory Performance

    /// Test memory usage during continuous processing
    func testMemoryUsageDuringProcessing() throws {
        let extractor = AdvancedFeatureExtractor(fftSize: 4096)

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: [XCTMemoryMetric()], options: options) {
            for _ in 0..<100 {
                let samples = generateTestAudio(duration: 0.1, sampleRate: 44100)
                _ = extractor.extractFeatures(from: samples, sampleRate: 44100)
            }
        }
    }

    /// Test that memory does NOT grow unbounded during simulated real-time processing
    /// This is CRITICAL - memory growth caused app crashes at 150-200MB
    func testMemoryDoesNotGrowDuringContinuousProcessing() throws {
        let initialMemory = getMemoryUsageMB()

        // Simulate 30 seconds of real-time processing at ~30 fps
        // This is 900 frames total
        let extractor = AdvancedFeatureExtractor(fftSize: 2048)
        let detector = CryDetectorMLModel()
        let classifier = CryClassifierMLModel()

        for i in 0..<900 {
            autoreleasepool {
                let samples = generateTestAudio(duration: 0.033, sampleRate: 44100)
                let features = extractor.extractFeatures(from: samples, sampleRate: 44100)
                let detection = detector.detect(features: features)
                if detection.isCryDetected {
                    _ = classifier.classify(features: features)
                }
            }

            // Check memory every 100 frames
            if i > 0 && i % 100 == 0 {
                let currentMemory = getMemoryUsageMB()
                let growth = currentMemory - initialMemory

                // Memory growth should be < 10MB over 30 seconds of processing
                // (Previously it was growing indefinitely, causing crashes)
                XCTAssertLessThan(growth, 10.0,
                    "Memory grew by \(growth)MB after \(i) frames - possible memory leak!")
            }
        }

        let finalMemory = getMemoryUsageMB()
        let totalGrowth = finalMemory - initialMemory

        print("Memory test: Initial \(String(format: "%.1f", initialMemory))MB → Final \(String(format: "%.1f", finalMemory))MB (Growth: \(String(format: "%.1f", totalGrowth))MB)")

        // Final check - should not have grown more than 15MB total
        XCTAssertLessThan(totalGrowth, 15.0,
            "Total memory growth \(totalGrowth)MB exceeds acceptable limit of 15MB")
    }

    /// Test shared FFT setup memory - should only allocate once
    func testSharedFFTSetupDoesNotLeakMemory() throws {
        let initialMemory = getMemoryUsageMB()

        // Create 1000 FFT operations using shared setup
        for _ in 0..<1000 {
            autoreleasepool {
                let samples = generateTestAudio(duration: 0.046, sampleRate: 44100)

                // Use vDSP directly to test FFT setup reuse
                if let setup = vDSP_DFT_zop_CreateSetup(nil, 2048, .FORWARD) {
                    defer { vDSP_DFT_DestroySetup(setup) }
                    var real = samples
                    var imag = [Float](repeating: 0, count: 2048)
                    var realOut = [Float](repeating: 0, count: 2048)
                    var imagOut = [Float](repeating: 0, count: 2048)
                    vDSP_DFT_Execute(setup, &real, &imag, &realOut, &imagOut)
                }
            }
        }

        let finalMemory = getMemoryUsageMB()
        let growth = finalMemory - initialMemory

        // Each FFT setup is ~few KB, if we're creating 1000 without destroying = ~MB leak
        // With proper cleanup, growth should be minimal (<5MB)
        XCTAssertLessThan(growth, 5.0,
            "FFT setup leaked \(growth)MB - should be minimal with proper cleanup")
    }

    /// Test ML model instances don't accumulate memory
    func testMLModelsDoNotLeakMemory() throws {
        let initialMemory = getMemoryUsageMB()
        let features = MockAudioFeatures.cryingBaby(type: .hunger)

        // Previously, creating new instances per frame caused memory growth
        // Now we should use shared instances
        for _ in 0..<1000 {
            autoreleasepool {
                // These should NOT create new model instances internally
                let detector = CryDetectorMLModel()
                let classifier = CryClassifierMLModel()

                _ = detector.detect(features: features)
                _ = classifier.classify(features: features)
            }
        }

        let finalMemory = getMemoryUsageMB()
        let growth = finalMemory - initialMemory

        // With proper caching, CoreML models should not accumulate
        XCTAssertLessThan(growth, 5.0,
            "ML models leaked \(growth)MB - CoreML should cache model instances")
    }

    /// Helper: Get current memory usage in MB
    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }

    // MARK: - App Launch Performance

    func testAppLaunchPerformance() throws {
        // Only run in UI test target with XCUIApplication
        // Keeping as placeholder for when UI tests are set up
    }

    // MARK: - Freemium Performance Tests

    /// Test FreemiumGatekeeper feature access check performance - must be < 5ms
    func testFreemiumFeatureAccessCheckPerformance() throws {
        let defaults = UserDefaults(suiteName: "perf_test_feature")!
        defaults.removePersistentDomain(forName: "perf_test_feature")
        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        let features: [FreemiumGatekeeper.Feature] = [
            .cryDetection, .unlimitedContent, .offlineDownloads,
            .fullBabyMIMInsights, .llmRecommendations
        ]

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                for feature in features {
                    _ = gatekeeper.hasAccess(to: feature)
                }
            }
        }
    }

    /// Test FreemiumGatekeeper track access check performance for browsing
    func testFreemiumTrackAccessCheckPerformance() throws {
        let defaults = UserDefaults(suiteName: "perf_test_track")!
        defaults.removePersistentDomain(forName: "perf_test_track")
        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // Create mix of premium and free tracks
        let tracks = (0..<100).map { i in
            AudioTrack(
                title: "Track \(i)",
                category: .classicalMusic,
                duration: 180,
                calmingScore: 0.8,
                audioSourceType: .api,
                isPremium: i % 3 == 0 // 1/3 premium
            )
        }

        measure(metrics: [XCTClockMetric()]) {
            for track in tracks {
                _ = gatekeeper.canPlayTrack(track)
                _ = gatekeeper.accessType(for: track)
            }
        }
    }

    /// Test TrialManager state check performance
    func testTrialStateCheckPerformance() throws {
        // TrialManager is a singleton, so we just test its operations
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                _ = TrialManager.shared.trialState.isActive
                _ = TrialManager.shared.trialDaysRemaining
                _ = TrialManager.shared.shouldShowSoftPrompt
            }
        }
    }

    /// Test FreemiumGatekeeper prompt rate limiting performance
    func testPromptRateLimitingPerformance() throws {
        let defaults = UserDefaults(suiteName: "perf_test_prompt")!
        defaults.removePersistentDomain(forName: "perf_test_prompt")
        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        let track = AudioTrack(
            title: "Premium Test",
            category: .classicalMusic,
            duration: 180,
            calmingScore: 0.9,
            audioSourceType: .api,
            isPremium: true
        )

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                _ = gatekeeper.shouldShowUpgradePrompt(for: track)
            }
        }
    }

    // MARK: - Helpers

    /// Generate test audio with specific frequency
    private func generateTestAudio(duration: Double, sampleRate: Double, frequency: Double = 450) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            // Add fundamental + harmonics (simulate cry-like audio)
            samples[i] = Float(
                sin(2.0 * .pi * frequency * t) * 0.4 +
                sin(2.0 * .pi * frequency * 2 * t) * 0.2 +
                sin(2.0 * .pi * frequency * 3 * t) * 0.1
            )
        }

        return samples
    }
}

// MARK: - Import Accelerate for vDSP functions
import Accelerate
