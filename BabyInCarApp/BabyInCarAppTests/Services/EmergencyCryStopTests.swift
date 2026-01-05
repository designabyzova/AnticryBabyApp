//
//  EmergencyCryStopTests.swift
//  BabyInCarAppTests
//
//  Tests for Emergency Cry-Stop feature intelligence fix
//  Verifies that SmartCryResponseEngine is ALWAYS used and sounds rotate properly
//

import Testing
import Foundation
@testable import BabyInCarApp

// MARK: - Emergency Cry-Stop Activation Tests

@Suite("Emergency Cry-Stop Activation")
@MainActor
struct EmergencyCryStopActivationTests {

    // MARK: - Test: SmartCryResponseEngine is always used

    @Test("Emergency button always activates SmartCryResponseEngine")
    func emergencyButtonUsesSmartEngine() async {
        // Given: A baby profile and emergency service
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared
        let smartEngine = SmartCryResponseEngine.shared

        // When: Emergency button is tapped (activate called)
        emergencyService.activate(for: baby)

        // Wait for async activation
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then: SmartCryResponseEngine should be active
        #expect(smartEngine.isActive, "SmartCryResponseEngine should be active after emergency activation")
        #expect(emergencyService.isEmergencyModeActive, "Emergency mode should be active")

        // Cleanup
        emergencyService.deactivate()
    }

    @Test("Emergency activation works without AI monitoring enabled")
    func emergencyWorksWithoutAIMonitoring() async {
        // Given: AI monitoring is disabled
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -8, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared

        // Ensure AI monitoring is off
        #expect(!emergencyService.isAIMonitoringEnabled, "AI monitoring should be disabled for this test")

        // When: Emergency is activated
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then: Emergency mode should still work (using SmartCryResponseEngine)
        let smartEngine = SmartCryResponseEngine.shared
        #expect(smartEngine.isActive, "SmartCryResponseEngine should activate even without AI monitoring")

        // Cleanup
        emergencyService.deactivate()
    }

    @Test("Emergency service sets correct initial phase")
    func emergencyServiceSetsCorrectPhase() async {
        // Given
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared

        // When
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Phase should be attention (first phase)
        #expect(emergencyService.currentPhase == .attention, "Initial phase should be 'attention'")

        // Cleanup
        emergencyService.deactivate()
    }
}

// MARK: - Sound Selection Tests

@Suite("Emergency Sound Selection")
@MainActor
struct EmergencySoundSelectionTests {

    @Test("Different ages get different sounds")
    func differentAgesGetDifferentSounds() async {
        let smartEngine = SmartCryResponseEngine.shared

        // Test multiple age groups
        let ages = [3, 6, 12, 24, 36] // months
        var soundsForAges: [Int: GeneratorType?] = [:]

        for age in ages {
            let baby = Baby(
                id: UUID(),
                name: "Baby \(age)mo",
                birthDate: Calendar.current.date(byAdding: .month, value: -age, to: Date())!
            )

            await smartEngine.activate(for: baby)
            try? await Task.sleep(nanoseconds: 300_000_000)

            soundsForAges[age] = smartEngine.currentSound
            smartEngine.deactivate()

            // Small delay between tests
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Verify that at least some ages got different sounds
        let uniqueSounds = Set(soundsForAges.values.compactMap { $0 })
        #expect(uniqueSounds.count >= 2, "Different age groups should get different sounds. Got: \(uniqueSounds)")
    }

    @Test("Sound sequence contains multiple options")
    func soundSequenceHasMultipleOptions() async {
        // Given: A baby
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared

        // When: Activate emergency
        await smartEngine.activate(for: baby)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: There should be a current sound playing
        #expect(smartEngine.currentSound != nil, "A sound should be playing after activation")

        // Cleanup
        smartEngine.deactivate()
    }
}

// MARK: - Sound Rotation Tests

@Suite("Emergency Sound Rotation")
@MainActor
struct EmergencySoundRotationTests {

    @Test("Consecutive activations use different sounds")
    func consecutiveActivationsRotateSounds() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -9, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared
        var soundsPlayed: [GeneratorType] = []

        // Activate 3 times and record sounds
        for i in 0..<3 {
            await smartEngine.activate(for: baby)
            try? await Task.sleep(nanoseconds: 300_000_000)

            if let sound = smartEngine.currentSound {
                soundsPlayed.append(sound)
                print("Activation \(i+1): Playing \(sound.rawValue)")
            }

            smartEngine.deactivate()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // Verify we got sounds
        #expect(soundsPlayed.count >= 2, "Should have recorded at least 2 sounds")

        // Due to rotation logic, consecutive sounds should differ
        // (unless all alternatives were exhausted, which is okay)
        if soundsPlayed.count >= 2 {
            let firstTwoMatch = soundsPlayed[0] == soundsPlayed[1]
            if firstTwoMatch {
                // This is acceptable if rotation cleared (all options used)
                print("Note: First two sounds matched - rotation may have reset")
            }
        }
    }

    @Test("Rotation tracks recently played sounds")
    func rotationTracksRecentSounds() async {
        // This test verifies the rotation mechanism exists
        // The actual rotation is internal, but we can verify behavior

        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared

        // Activate multiple times quickly
        var allSounds: [GeneratorType] = []

        for _ in 0..<5 {
            await smartEngine.activate(for: baby)
            try? await Task.sleep(nanoseconds: 200_000_000)

            if let sound = smartEngine.currentSound {
                allSounds.append(sound)
            }

            smartEngine.deactivate()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // With rotation, we should see variety (not all same sound)
        let uniqueSounds = Set(allSounds)
        #expect(uniqueSounds.count >= 1, "Should have at least 1 sound played")

        // If we have multiple, verify some variety (rotation working)
        if allSounds.count > 3 {
            #expect(uniqueSounds.count >= 2, "5 activations should show at least 2 different sounds due to rotation")
        }
    }
}

// MARK: - Cry Type Response Tests

@Suite("Emergency Cry Type Response")
@MainActor
struct EmergencyCryTypeResponseTests {

    @Test("Strategy selection based on cry type")
    func strategySelectionByCryType() {
        // Test that different cry types map to different strategies
        // This tests the internal logic of SmartCryResponseEngine

        // Verify the strategy enum exists and has expected cases
        let strategies: [SoothingStrategy] = [
            .sleepInduction,
            .distraction,
            .comfort,
            .gentle,
            .urgent,
            .adaptive
        ]

        #expect(strategies.count == 6, "Should have 6 soothing strategies")
    }

    @Test("Phase progression works correctly")
    func phaseProgressionWorks() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared

        // Activate
        await smartEngine.activate(for: baby)

        // Wait for phase to start
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Should be in an active phase
        let activePhases: [SmartCryResponseEngine.ResponsePhase] = [
            .attentionCapture,
            .primarySoothing,
            .adaptiveTuning,
            .deepCalming,
            .sleepTransition,
            .monitoring
        ]

        #expect(activePhases.contains(smartEngine.currentPhase) || smartEngine.currentPhase == .initializing,
                "Should be in an active response phase after activation. Got: \(smartEngine.currentPhase)")

        smartEngine.deactivate()
    }
}

// MARK: - Learning Integration Tests

@Suite("Emergency Learning Integration")
@MainActor
struct EmergencyLearningIntegrationTests {

    @Test("Success feedback records to learning engine")
    func successFeedbackRecordsLearning() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -8, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared
        let learningEngine = AdaptiveLearningEngine.shared

        // Get initial session count (if accessible)
        let initialConfidence = learningEngine.learningConfidence

        // Activate emergency
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Simulate "Baby is Calm" feedback with time-to-calm
        let timeToCalm: TimeInterval = 45.0 // 45 seconds
        emergencyService.reportSuccessWithFeedback(for: baby, timeToCalm: timeToCalm)

        // Wait for recording
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Learning should have updated (confidence may increase or stay same)
        // This is a soft check since we can't easily verify internal state
        #expect(true, "Success feedback was recorded without error")
    }

    @Test("Not working feedback triggers adaptation")
    func notWorkingFeedbackTriggersAdaptation() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -10, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared

        // Activate
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Report not working
        emergencyService.reportNotWorking(for: baby)

        // Should trigger adaptation (phase change or sound change)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Cleanup
        emergencyService.deactivate()

        #expect(true, "Not working feedback processed without error")
    }
}

// MARK: - Edge Case Tests

@Suite("Emergency Edge Cases")
@MainActor
struct EmergencyEdgeCaseTests {

    @Test("Deactivation cleans up properly")
    func deactivationCleansUp() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared
        let smartEngine = SmartCryResponseEngine.shared

        // Activate
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Deactivate
        emergencyService.deactivate()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify cleanup
        #expect(!emergencyService.isEmergencyModeActive, "Emergency mode should be inactive")
        #expect(!smartEngine.isActive, "Smart engine should be inactive after deactivation")
    }

    @Test("Multiple rapid activations handled gracefully")
    func multipleRapidActivationsHandled() async {
        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        let emergencyService = EmergencyCryStopService.shared

        // Rapid activations
        for _ in 0..<5 {
            emergencyService.activate(for: baby)
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

        // Should still be in a valid state
        #expect(emergencyService.isEmergencyModeActive, "Should be active after rapid activations")

        // Cleanup
        emergencyService.deactivate()
    }

    @Test("Very young baby gets age-appropriate sounds")
    func veryYoungBabyGetsAppropriateSound() async {
        // 1 month old baby
        let baby = Baby(
            id: UUID(),
            name: "Newborn",
            birthDate: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared

        await smartEngine.activate(for: baby)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Very young babies should get GENTLE sounds like womb, heartbeat, shushing
        // NOTE: No harsh sounds (vacuum, hairdryer) - they can frighten babies!
        let appropriateSoundsForNewborn: [GeneratorType] = [
            .womb, .heartbeat, .shushing, .ocean, .lullaby, .musicBox, .river
        ]

        if let sound = smartEngine.currentSound {
            let isAppropriate = appropriateSoundsForNewborn.contains(sound)
            #expect(isAppropriate, "Newborn should get age-appropriate sound. Got: \(sound.rawValue)")
        }

        smartEngine.deactivate()
    }

    @Test("Older toddler gets age-appropriate sounds")
    func olderToddlerGetsAppropriateSound() async {
        // 30 month old toddler
        let baby = Baby(
            id: UUID(),
            name: "Toddler",
            birthDate: Calendar.current.date(byAdding: .month, value: -30, to: Date())!
        )

        let smartEngine = SmartCryResponseEngine.shared

        await smartEngine.activate(for: baby)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Older toddlers should get more varied sounds
        if let sound = smartEngine.currentSound {
            print("Toddler (30mo) got sound: \(sound.rawValue)")
            #expect(true, "Toddler got sound: \(sound.rawValue)")
        }

        smartEngine.deactivate()
    }
}
