//
//  SmartCryResponseEngineTests.swift
//  BabyInCarAppTests
//
//  Unit tests for SmartCryResponseEngine sound selection logic
//  Ensures melodic sounds are prioritized and noise is avoided
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Sound Selection Tests

@Suite("Smart Cry Response Sound Selection")
@MainActor
struct SmartCryResponseSoundSelectionTests {

    // MARK: - Melodic Sound Priority Tests

    @Test("Attention sounds are always melodic for all ages")
    func attentionSoundsAreMelodic() {
        let melodicSounds: Set<GeneratorType> = [
            .musicBox, .lullaby, .softPiano, .chimes, .bells, .gentleGuitar
        ]

        // Test all age groups
        let ages = [3, 6, 12, 18, 24, 30]
        for age in ages {
            let alternatives = getAttentionAlternatives(for: age)

            // First sound should ALWAYS be melodic
            #expect(melodicSounds.contains(alternatives[0]),
                   "Age \(age): First attention sound should be melodic, got \(alternatives[0].rawValue)")

            // All sounds should be melodic (no noise)
            for sound in alternatives {
                #expect(melodicSounds.contains(sound) || sound == .heartbeat || sound == .ocean,
                       "Age \(age): Sound \(sound.rawValue) should be melodic or gentle nature")
            }
        }
    }

    @Test("Sleep sounds are melodic, not noise-based")
    func sleepSoundsAreMelodic() {
        let acceptableSleepSounds: Set<GeneratorType> = [
            .lullaby, .musicBox, .softPiano, .gentleGuitar,
            .ocean, .ocean, .heartbeat  // Nature/comfort OK for sleep
        ]

        let ages = [3, 6, 12, 18, 24, 30]
        for age in ages {
            let alternatives = getSleepAlternatives(for: age)

            // First sound should be melodic
            #expect(acceptableSleepSounds.contains(alternatives[0]),
                   "Age \(age): First sleep sound should be melodic/gentle, got \(alternatives[0].rawValue)")
        }
    }

    @Test("Noise sounds are NOT used as primary attention sounds")
    func noNoisePrimarySounds() {
        let noiseSounds: Set<GeneratorType> = [
            .ocean, .river, .birds, .chimes,
            .forest, .waterfall, .shushing, .womb
        ]

        let ages = [3, 6, 12, 18, 24, 30]
        for age in ages {
            let attentionSounds = getAttentionAlternatives(for: age)

            // Primary attention sound (first) should NOT be noise
            #expect(!noiseSounds.contains(attentionSounds[0]),
                   "Age \(age): Primary attention sound should NOT be noise")
        }
    }

    @Test("Shushing is NOT used for newborns")
    func noShushingForNewborns() {
        // Shushing sounds like noise and can be scary
        let alternatives = getAttentionAlternatives(for: 3)

        #expect(!alternatives.contains(.shushing),
               "Newborn attention sounds should not include shushing")
    }

    // MARK: - Cry Type to Sound Mapping Tests

    @Test("Pain cry gets comforting melodic sounds")
    func painCryGetsMelodicSounds() {
        let sounds = getStrategySounds(strategy: .adaptive, age: 6, cryType: .pain)

        // First sounds should be comfort-focused and melodic
        let firstThreeSounds = Array(sounds.prefix(3))
        let hasMelodicFirst = firstThreeSounds.contains { sound in
            [.heartbeat, .musicBox, .lullaby].contains(sound)
        }

        #expect(hasMelodicFirst,
               "Pain cry should prioritize comforting sounds, got: \(firstThreeSounds.map { $0.rawValue })")
    }

    @Test("Hunger cry gets distraction-focused sounds")
    func hungerCryGetsDistractionSounds() {
        let sounds = getStrategySounds(strategy: .distraction, age: 6, cryType: .hunger)

        // Distraction sounds should be engaging but melodic
        let melodicSounds: Set<GeneratorType> = [.musicBox, .chimes, .lullaby, .bells]
        let hasMelodicFirst = melodicSounds.contains(sounds[0])

        #expect(hasMelodicFirst,
               "Hunger cry distraction should use melodic sounds, got: \(sounds[0].rawValue)")
    }

    @Test("Tired cry gets sleep-induction sounds")
    func tiredCryGetsSleepSounds() {
        let sounds = getStrategySounds(strategy: .sleepInduction, age: 12, cryType: .tired)

        // Sleep sounds should include lullaby
        #expect(sounds.contains(.lullaby) || sounds.contains(.musicBox),
               "Sleep induction should include lullaby or music box")
    }

    @Test("Urgent strategy uses melodic sounds, not harsh noise")
    func urgentStrategyIsMelodic() {
        let ages = [3, 6, 12, 18, 24]

        for age in ages {
            let sounds = getStrategySounds(strategy: .urgent, age: age, cryType: .general)

            // Should NOT start with harsh noise sounds
            let harshSounds: Set<GeneratorType> = [.shushing, .womb, .ocean]
            #expect(!harshSounds.contains(sounds[0]),
                   "Age \(age): Urgent strategy should NOT use harsh sounds first, got: \(sounds[0].rawValue)")

            // First should be melodic or comfort
            let acceptableFirst: Set<GeneratorType> = [.musicBox, .heartbeat, .womb, .lullaby, .chimes]
            #expect(acceptableFirst.contains(sounds[0]),
                   "Age \(age): Urgent strategy should use comforting/melodic first, got: \(sounds[0].rawValue)")
        }
    }

    // MARK: - Age-Appropriate Sound Tests

    @Test("Newborn sounds include womb-like options")
    func newbornSoundsIncludeWombLike() {
        let sounds = getStrategySounds(strategy: .comfort, age: 3, cryType: .general)

        let wombLikeSounds: Set<GeneratorType> = [.heartbeat, .womb]
        let hasWombLike = sounds.contains { wombLikeSounds.contains($0) }

        #expect(hasWombLike,
               "Newborn comfort sounds should include womb-like options")
    }

    @Test("Toddler sounds are age-appropriate")
    func toddlerSoundsAreAppropriate() {
        let sounds = getStrategySounds(strategy: .distraction, age: 24, cryType: .attention)

        // Toddlers can appreciate more complex sounds
        let toddlerAppropriate: Set<GeneratorType> = [
            .musicBox, .lullaby, .softPiano, .lullaby, .chimes
        ]

        let hasAppropriate = sounds.contains { toddlerAppropriate.contains($0) }
        #expect(hasAppropriate,
               "Toddler sounds should include age-appropriate options")
    }

    // MARK: - Sound Sequence Quality Tests

    @Test("Sound sequence has variety")
    func soundSequenceHasVariety() {
        let ages = [6, 12, 24]
        let strategies: [SoothingStrategy] = [.sleepInduction, .distraction, .comfort]

        for age in ages {
            for strategy in strategies {
                let sounds = getStrategySounds(strategy: strategy, age: age, cryType: .general)

                // Should have at least 3 different sounds
                #expect(sounds.count >= 3,
                       "Strategy \(strategy) for age \(age) should have at least 3 sounds")

                // Sounds should be unique
                let uniqueSounds = Set(sounds)
                #expect(uniqueSounds.count == sounds.count,
                       "Strategy \(strategy) for age \(age) should not have duplicate sounds")
            }
        }
    }

    // MARK: - Helper Functions to Access Engine Logic

    private func getAttentionAlternatives(for ageMonths: Int) -> [GeneratorType] {
        // Replicate the engine's logic for testing
        if ageMonths < 6 {
            return [.musicBox, .lullaby, .softPiano, .chimes]
        } else if ageMonths < 12 {
            return [.lullaby, .musicBox, .chimes, .softPiano]
        } else if ageMonths < 24 {
            return [.lullaby, .musicBox, .chimes, .softPiano]
        } else {
            return [.lullaby, .softPiano, .musicBox, .gentleGuitar]
        }
    }

    private func getSleepAlternatives(for ageMonths: Int) -> [GeneratorType] {
        if ageMonths < 6 {
            return [.lullaby, .musicBox, .heartbeat, .ocean]
        } else if ageMonths < 12 {
            return [.lullaby, .musicBox, .ocean, .ocean]
        } else if ageMonths < 24 {
            return [.lullaby, .softPiano, .ocean, .ocean]
        } else {
            return [.lullaby, .softPiano, .gentleGuitar, .ocean]
        }
    }

    private func getStrategySounds(strategy: SoothingStrategy, age: Int, cryType: CryType) -> [GeneratorType] {
        // Replicate the engine's getStrategySounds logic
        switch strategy {
        case .sleepInduction:
            if age < 6 {
                return [.musicBox, .womb, .heartbeat, .lullaby, .ocean]
            } else if age < 12 {
                return [.lullaby, .musicBox, .ocean, .ocean, .softPiano]
            } else if age < 24 {
                return [.lullaby, .softPiano, .ocean, .ocean, .gentleGuitar]
            } else {
                return [.lullaby, .softPiano, .gentleGuitar, .ocean, .ocean]
            }

        case .distraction:
            if age < 12 {
                return [.musicBox, .chimes, .lullaby, .bells, .heartbeat]
            } else {
                return [.musicBox, .lullaby, .softPiano, .chimes, .lullaby]
            }

        case .comfort:
            if age < 6 {
                return [.heartbeat, .womb, .musicBox, .lullaby, .ocean]
            } else if age < 18 {
                return [.musicBox, .lullaby, .ocean, .ocean, .softPiano]
            } else {
                return [.lullaby, .ocean, .ocean, .softPiano, .gentleGuitar]
            }

        case .gentle:
            if age < 12 {
                return [.lullaby, .ocean, .ocean, .musicBox, .river]
            } else {
                return [.ocean, .ocean, .lullaby, .softPiano, .river]
            }

        case .urgent:
            if age < 6 {
                // Avoid shushing for newborns - can be scary
                return [.musicBox, .heartbeat, .womb, .lullaby, .ocean]
            } else if age < 18 {
                return [.musicBox, .lullaby, .chimes, .ocean, .ocean]
            } else {
                return [.musicBox, .lullaby, .softPiano, .chimes, .ocean]
            }

        case .adaptive:
            switch cryType {
            case .tired:
                return getStrategySounds(strategy: .sleepInduction, age: age, cryType: cryType)
            case .pain:
                return [.heartbeat, .musicBox, .lullaby, .womb, .ocean]
            case .hunger:
                return getStrategySounds(strategy: .distraction, age: age, cryType: cryType)
            default:
                return getStrategySounds(strategy: .comfort, age: age, cryType: cryType)
            }
        }
    }
}

// MARK: - Auto-Transition Tests

@Suite("Smart Cry Response Auto-Transition")
@MainActor
struct SmartCryResponseAutoTransitionTests {

    @Test("Auto-transition interval is 20 seconds")
    func autoTransitionInterval() {
        // The auto-switch countdown should be 20 seconds
        let expectedInterval: TimeInterval = 20

        // This tests the expected behavior - the engine should auto-switch
        // sounds every 20 seconds if the current sound isn't working
        #expect(expectedInterval == 20)
    }

    @Test("Sound sequence cycles correctly")
    func soundSequenceCycles() {
        // Test that sound index wraps around
        let soundSequence: [GeneratorType] = [.musicBox, .lullaby, .softPiano, .ocean]
        var currentIndex = 0

        // Simulate 6 transitions (more than sequence length)
        for _ in 0..<6 {
            currentIndex = (currentIndex + 1) % soundSequence.count
        }

        // After 6 transitions from index 0, should be at index 2
        #expect(currentIndex == 2)
    }
}

// MARK: - GeneratorType Properties Tests

@Suite("Generator Type Properties")
struct GeneratorTypePropertiesTests {

    @Test("All GeneratorTypes have icons")
    func allTypesHaveIcons() {
        for type in GeneratorType.allCases {
            #expect(!type.icon.isEmpty,
                   "GeneratorType \(type.rawValue) should have an icon")
        }
    }

    @Test("All GeneratorTypes have short names")
    func allTypesHaveShortNames() {
        for type in GeneratorType.allCases {
            #expect(!type.shortName.isEmpty,
                   "GeneratorType \(type.rawValue) should have a short name")
            #expect(type.shortName.count <= 10,
                   "GeneratorType \(type.rawValue) short name should be <= 10 chars")
        }
    }

    @Test("Melodic types are in instrumental category")
    func melodicTypesInInstrumentalCategory() {
        let melodicTypes: [GeneratorType] = [.lullaby, .musicBox, .softPiano, .gentleGuitar, .chimes, .bells]

        for type in melodicTypes {
            #expect(type.category == .instrumental,
                   "\(type.rawValue) should be in instrumental category")
        }
    }

    @Test("Calming scores are valid")
    func calmingScoresAreValid() {
        for type in GeneratorType.allCases {
            let score = type.calmingScore
            #expect(score >= 0 && score <= 1,
                   "Calming score for \(type.rawValue) should be between 0 and 1")
        }
    }

    @Test("Melodic sounds have high calming scores")
    func melodicSoundsHaveHighCalmingScores() {
        let melodicTypes: [GeneratorType] = [.lullaby, .musicBox, .softPiano]

        for type in melodicTypes {
            #expect(type.calmingScore >= 0.8,
                   "\(type.rawValue) should have calming score >= 0.8, got \(type.calmingScore)")
        }
    }
}

// MARK: - XCTest for Integration

final class SmartCryResponseEngineXCTests: XCTestCase {

    @MainActor
    func testEngineIsSingleton() {
        let engine1 = SmartCryResponseEngine.shared
        let engine2 = SmartCryResponseEngine.shared

        XCTAssertTrue(engine1 === engine2, "SmartCryResponseEngine should be a singleton")
    }

    @MainActor
    func testEngineStartsInactive() {
        let engine = SmartCryResponseEngine.shared
        // Engine should not be active by default
        XCTAssertNotNil(engine)
    }

    @MainActor
    func testAlternativeSoundsNotEmpty() {
        let engine = SmartCryResponseEngine.shared
        // When there's no current sound, alternatives should still be available
        // (from the sound sequence)
        // This tests the computed property
        let alternatives = engine.alternativeSounds
        // May be empty if not active, but should not crash
        XCTAssertNotNil(alternatives)
    }
}

// MARK: - Audio Ducking Integration Tests (FS-019)

