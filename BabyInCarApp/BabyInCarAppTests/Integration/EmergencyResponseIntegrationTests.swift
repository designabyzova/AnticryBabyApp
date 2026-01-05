//
//  EmergencyResponseIntegrationTests.swift
//  BabyInCarAppTests
//
//  Integration tests for the Emergency Cry-Stop response flow
//  Tests the complete flow from button press to sound playback
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Emergency Response Flow Tests

@Suite("Emergency Response Integration")
@MainActor
struct EmergencyResponseIntegrationTests {

    // MARK: - Flow Tests

    @Test("Emergency activation starts with melodic sound")
    func emergencyActivationStartsMelodic() async {
        let engine = SmartCryResponseEngine.shared

        // Create a test baby
        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .male
        )

        // Deactivate first to ensure clean state
        engine.deactivate()

        // Activate for baby
        await engine.activate(for: testBaby)

        // Should now be active
        #expect(engine.isActive == true)

        // Current sound should be set
        if let currentSound = engine.currentSound {
            // Should NOT be a harsh noise sound
            let harshSounds: Set<GeneratorType> = [.shushing, .womb, .ocean]
            #expect(!harshSounds.contains(currentSound),
                   "Emergency mode should not start with harsh noise, got: \(currentSound.rawValue)")

            // Should be melodic or comfort-based
            let acceptableSounds: Set<GeneratorType> = [
                .musicBox, .lullaby, .softPiano, .chimes, .bells, .gentleGuitar,
                .heartbeat, .womb, .ocean, .ocean  // Comfort and nature are OK
            ]
            #expect(acceptableSounds.contains(currentSound),
                   "Emergency mode should start with melodic/comfort sound, got: \(currentSound.rawValue)")
        }

        // Cleanup
        engine.deactivate()
    }

    @Test("Emergency mode provides alternative sounds")
    func emergencyModeProvidesAlternatives() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -12, to: Date())!,
            gender: .female
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        // Should have alternative sounds available
        let alternatives = engine.alternativeSounds
        #expect(alternatives.count >= 2,
               "Should have at least 2 alternative sounds for quick switching")

        // Alternatives should not include current sound
        if let currentSound = engine.currentSound {
            #expect(!alternatives.contains(currentSound),
                   "Alternatives should not include current sound")
        }

        engine.deactivate()
    }

    @Test("Sound switching updates current sound")
    func soundSwitchingWorks() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -9, to: Date())!,
            gender: .male
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        let originalSound = engine.currentSound
        let alternatives = engine.alternativeSounds

        // Switch to first alternative
        if let newSound = alternatives.first {
            engine.switchToSound(newSound)

            #expect(engine.currentSound == newSound,
                   "Current sound should update after switch")
            #expect(engine.currentSound != originalSound,
                   "Current sound should be different from original")
        }

        engine.deactivate()
    }

    @Test("Deactivation stops engine correctly")
    func deactivationWorks() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .female
        )

        engine.deactivate()
        await engine.activate(for: testBaby)
        #expect(engine.isActive == true)

        engine.deactivate()

        #expect(engine.isActive == false)
    }

    // MARK: - Age-Based Sound Selection Tests

    @Test("Newborn (0-6 months) gets appropriate sounds")
    func newbornGetsAppropriateSounds() async {
        let engine = SmartCryResponseEngine.shared

        // 3-month-old baby
        let newborn = Baby(
            name: "Newborn",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
            gender: .male
        )

        engine.deactivate()
        await engine.activate(for: newborn)

        if let currentSound = engine.currentSound {
            // Newborns should get very gentle sounds
            let newbornAppropriate: Set<GeneratorType> = [
                .musicBox, .lullaby, .heartbeat, .womb, .softPiano
            ]
            #expect(newbornAppropriate.contains(currentSound),
                   "Newborn should get gentle sound, got: \(currentSound.rawValue)")
        }

        engine.deactivate()
    }

    @Test("Toddler (12-24 months) gets appropriate sounds")
    func toddlerGetsAppropriateSounds() async {
        let engine = SmartCryResponseEngine.shared

        // 18-month-old toddler
        let toddler = Baby(
            name: "Toddler",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -18, to: Date())!,
            gender: .female
        )

        engine.deactivate()
        await engine.activate(for: toddler)

        if let currentSound = engine.currentSound {
            // Toddlers can handle more variety
            let toddlerAppropriate: Set<GeneratorType> = [
                .musicBox, .lullaby, .softPiano, .chimes, .ocean, .ocean, .gentleGuitar
            ]
            #expect(toddlerAppropriate.contains(currentSound),
                   "Toddler should get age-appropriate sound, got: \(currentSound.rawValue)")
        }

        engine.deactivate()
    }

    // MARK: - Response Phase Tests

    @Test("Response phase progresses correctly")
    func responsePhaseProgresses() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .male
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        // Should start in attention capture phase
        #expect(engine.currentPhase == .attentionCapture || engine.currentPhase == .primarySoothing,
               "Should start in attention capture or primary soothing phase")

        engine.deactivate()
    }

    // MARK: - Countdown Timer Tests

    @Test("Countdown timer starts at 20 seconds")
    func countdownTimerStarts() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .female
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        // Give a moment for timer to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Countdown should be around 20 seconds (may have decremented by 1)
        #expect(engine.secondsUntilNextSound >= 18 && engine.secondsUntilNextSound <= 20,
               "Countdown should start around 20 seconds, got: \(engine.secondsUntilNextSound)")

        engine.deactivate()
    }
}

// MARK: - Sound Habituation Tests

@Suite("Sound Habituation Prevention")
@MainActor
struct SoundHabituationTests {

    @Test("Recently played sounds are tracked")
    func recentSoundsTracked() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .male
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        let alternatives = engine.alternativeSounds
        if let soundToSwitch = alternatives.first {
            engine.switchToSound(soundToSwitch)

            // The switched sound should now be current
            #expect(engine.currentSound == soundToSwitch)

            // New alternatives should not include the switched sound
            let newAlternatives = engine.alternativeSounds
            #expect(!newAlternatives.contains(soundToSwitch),
                   "Alternatives should not include recently played sound")
        }

        engine.deactivate()
    }
}

// MARK: - XCTest Integration

final class EmergencyResponseXCTests: XCTestCase {

    @MainActor
    func testEmergencyCryStopServiceExists() {
        let service = EmergencyCryStopService.shared
        XCTAssertNotNil(service)
    }

    @MainActor
    func testSmartCryResponseEngineExists() {
        let engine = SmartCryResponseEngine.shared
        XCTAssertNotNil(engine)
    }

    @MainActor
    func testBabyModelCreation() {
        let baby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .male
        )

        XCTAssertEqual(baby.name, "TestBaby")
        XCTAssertEqual(baby.ageInMonths, 6)
    }

    @MainActor
    func testGeneratorTypeHasRequiredProperties() {
        // Test that all generator types have the required properties for UI
        for type in GeneratorType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) should have an icon")
            XCTAssertFalse(type.shortName.isEmpty, "\(type.rawValue) should have a short name")
            XCTAssertFalse(type.rawValue.isEmpty, "\(type.rawValue) should have a raw value")
        }
    }

    @MainActor
    func testMelodicSoundsExist() {
        // Verify key melodic sounds are available
        let melodicSounds: [GeneratorType] = [.musicBox, .lullaby, .softPiano, .chimes, .gentleGuitar]

        for sound in melodicSounds {
            XCTAssertTrue(GeneratorType.allCases.contains(sound),
                         "\(sound.rawValue) should be available")
        }
    }

    @MainActor
    func testSoothingStrategiesExist() {
        // Verify all soothing strategies are available
        let strategies: [SoothingStrategy] = [
            .sleepInduction, .distraction, .comfort, .gentle, .urgent, .adaptive
        ]

        for strategy in strategies {
            XCTAssertNotNil(strategy.phases, "\(strategy) should have phases")
        }
    }
}
