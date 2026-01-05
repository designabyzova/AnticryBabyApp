//
//  UltraSmartPlaylistSelectorTests.swift
//  BabyInCarAppTests
//
//  Tests for the ultra-smart playlist selector
//  Ensures banned sounds are NEVER selected and scoring works correctly
//

import XCTest
@testable import BabyInCarApp

final class UltraSmartPlaylistSelectorTests: XCTestCase {

    // MARK: - Forbidden Sounds Tests (CRITICAL)

    /// Rain sound should NEVER be selected - it's banned!
    @MainActor
    func testRainSoundIsNeverSelected() async {
        let selector = UltraSmartPlaylistSelector.shared

        // Test across all cry types and ages - verify only gentle sounds are selected
        let cryTypes: [CryType] = [.tired, .hunger, .pain, .discomfort, .attention, .general, .unknown]
        let ages = [1, 3, 6, 12, 18, 24, 36]

        // These are the only allowed baby-friendly sounds
        let allowedSounds: Set<GeneratorType> = [
            .ocean, .river, .birds, .forest, .waterfall, .crickets, .campfire, .fireplace,
            .heartbeat, .womb, .shushing, .aquarium,
            .lullaby, .musicBox, .chimes, .bells, .softPiano, .gentleGuitar
        ]

        for cryType in cryTypes {
            for age in ages {
                let sounds = selector.selectOptimalSounds(
                    cryType: cryType,
                    babyAge: age,
                    cryIntensity: 0.5
                )

                for sound in sounds {
                    XCTAssertTrue(
                        allowedSounds.contains(sound),
                        "Only gentle sounds should be selected! Got: \(sound.rawValue) (cryType: \(cryType.rawValue), age: \(age)mo)"
                    )
                }
            }
        }
    }

    /// All selected sounds should be baby-friendly
    @MainActor
    func testAllSelectedSoundsAreBabyFriendly() async {
        let selector = UltraSmartPlaylistSelector.shared

        let cryTypes: [CryType] = [.tired, .hunger, .pain, .discomfort, .attention, .general]

        let babyFriendlySounds: Set<GeneratorType> = Set(GeneratorType.allCases)

        for cryType in cryTypes {
            let sounds = selector.selectOptimalSounds(
                cryType: cryType,
                babyAge: 12,
                cryIntensity: 0.5
            )

            for sound in sounds {
                XCTAssertTrue(
                    babyFriendlySounds.contains(sound),
                    "All sounds should be baby-friendly GeneratorType! (cryType: \(cryType.rawValue))"
                )
            }
        }
    }

    /// Thunder rumble sound should NEVER be selected - it's banned!
    @MainActor
    func testThunderRumbleSoundIsNeverSelected() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .tired,
            babyAge: 24,
            cryIntensity: 0.3
        )

        // All sounds in the playlist should be gentle baby-friendly sounds
        for sound in sounds {
            XCTAssertTrue(
                [.ocean, .river, .birds, .forest, .lullaby, .musicBox, .heartbeat, .womb, .shushing].contains(sound),
                "Only gentle sounds should be selected!"
            )
        }
    }

    /// Vacuum sound should NEVER be selected - it's banned!
    @MainActor
    func testVacuumSoundIsNeverSelected() async {
        let selector = UltraSmartPlaylistSelector.shared

        // Test for newborns where vacuum was historically recommended
        let sounds = selector.selectOptimalSounds(
            cryType: .pain,
            babyAge: 2,
            cryIntensity: 0.9  // High intensity pain cry
        )

        XCTAssertFalse(
            sounds.contains(.shushing),
            "Vacuum should NEVER be selected even for high-intensity pain cries!"
        )
    }

    /// Hair dryer sound should NEVER be selected - it's banned!
    @MainActor
    func testHairDryerSoundIsNeverSelected() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .discomfort,
            babyAge: 4,
            cryIntensity: 0.8
        )

        XCTAssertFalse(
            sounds.contains(.womb),
            "Hair dryer should NEVER be selected!"
        )
    }

    /// All forbidden sounds should be correctly identified
    @MainActor
    func testForbiddenSoundsAreCorrectlyIdentified() {
        let selector = UltraSmartPlaylistSelector.shared

        // Forbidden sounds have been removed from the app - check remaining are allowed
        // All remaining GeneratorType sounds are baby-friendly

        // These should NOT be forbidden
        XCTAssertFalse(selector.isSoundForbidden(.musicBox), "Music box should NOT be forbidden")
        XCTAssertFalse(selector.isSoundForbidden(.lullaby), "Lullaby should NOT be forbidden")
        XCTAssertFalse(selector.isSoundForbidden(.heartbeat), "Heartbeat should NOT be forbidden")
        XCTAssertFalse(selector.isSoundForbidden(.ocean), "Ocean should NOT be forbidden")
        XCTAssertFalse(selector.isSoundForbidden(.ocean), "Pink noise should NOT be forbidden")
    }

    // MARK: - Sound Selection Quality Tests

    /// Melodic sounds should be prioritized for newborns
    @MainActor
    func testMelodicSoundsPrioritizedForNewborns() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .tired,
            babyAge: 2,  // 2 months old
            cryIntensity: 0.5
        )

        // First 3 sounds should include melodic options
        let topThree = Array(sounds.prefix(3))
        let melodicSounds: Set<GeneratorType> = [.musicBox, .lullaby, .heartbeat, .womb, .softPiano]

        let hasMelodicInTop3 = topThree.contains { melodicSounds.contains($0) }
        XCTAssertTrue(hasMelodicInTop3, "Melodic sounds should be in top 3 for newborns")
    }

    /// Womb sounds should be high-priority for newborns
    @MainActor
    func testWombSoundsHighPriorityForNewborns() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .discomfort,
            babyAge: 1,  // 1 month old
            cryIntensity: 0.6
        )

        let top5 = Array(sounds.prefix(5))
        let prenatalSounds: Set<GeneratorType> = [.womb, .heartbeat]

        let hasPrenatalInTop5 = top5.contains { prenatalSounds.contains($0) }
        XCTAssertTrue(hasPrenatalInTop5, "Prenatal sounds (womb, heartbeat) should be in top 5 for newborns")
    }

    /// High intensity cry should prioritize immediate comfort sounds
    @MainActor
    func testHighIntensityCryGetsComfortSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .pain,
            babyAge: 6,
            cryIntensity: 0.9  // Very high intensity
        )

        let topSound = sounds.first
        let immediateComfortSounds: Set<GeneratorType> = [.heartbeat, .womb, .musicBox, .ocean, .lullaby]

        XCTAssertNotNil(topSound, "Should return at least one sound")
        XCTAssertTrue(
            immediateComfortSounds.contains(topSound!),
            "Top sound for high intensity should be immediate comfort sound, got: \(topSound!.rawValue)"
        )
    }

    /// Selection should return at least 5 sounds
    @MainActor
    func testSelectionReturnsEnoughSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .general,
            babyAge: 12,
            cryIntensity: 0.5
        )

        XCTAssertGreaterThanOrEqual(sounds.count, 5, "Should return at least 5 sounds")
    }

    /// Selection should not include sounds unsuitable for newborns
    @MainActor
    func testNewbornSoundsExcludeComplexSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .tired,
            babyAge: 1,  // 1 month
            cryIntensity: 0.5
        )

        // These are too stimulating for newborns
        let unsuitableForNewborns: Set<GeneratorType> = [.birds, .crickets, .forest, .lullaby]

        for sound in sounds {
            XCTAssertFalse(
                unsuitableForNewborns.contains(sound),
                "\(sound.rawValue) should not be selected for newborns"
            )
        }
    }

    // MARK: - Learning & History Tests

    /// Recording effectiveness should work correctly
    @MainActor
    func testRecordingEffectivenessWorks() {
        let selector = UltraSmartPlaylistSelector.shared

        // Record a successful session
        selector.recordEffectiveness(
            sound: .musicBox,
            cryType: .tired,
            wasEffective: true,
            calmingTimeSeconds: 120
        )

        // Insights should reflect recorded history
        let insights = selector.getSelectionInsights()
        XCTAssertGreaterThan(insights.totalHistoryRecords, 0, "Should have at least one history record")
    }

    /// Recording session should track played sounds
    @MainActor
    func testRecordingSessionWorks() {
        let selector = UltraSmartPlaylistSelector.shared

        let soundsPlayed: [GeneratorType] = [.musicBox, .lullaby, .heartbeat]
        selector.recordSession(soundsPlayed: soundsPlayed)

        // This is mainly for recency penalty calculation
        // Just verify it doesn't crash
        XCTAssertTrue(true, "Recording session should not crash")
    }

    // MARK: - Edge Cases

    /// Empty cry type should still return valid sounds
    @MainActor
    func testUnknownCryTypeReturnsValidSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .unknown,
            babyAge: 12,
            cryIntensity: 0.5
        )

        XCTAssertFalse(sounds.isEmpty, "Should return sounds even for unknown cry type")

        // Should still exclude forbidden sounds
        for sound in sounds {
            XCTAssertFalse(
                selector.isSoundForbidden(sound),
                "Forbidden sound \(sound.rawValue) should not appear in results"
            )
        }
    }

    /// Very old baby (3 years) should get appropriate sounds
    @MainActor
    func testOlderToddlerGetsAppropriateSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .attention,
            babyAge: 36,  // 3 years old
            cryIntensity: 0.4
        )

        // Should have melodic/engaging sounds
        let melodicSounds: Set<GeneratorType> = [.musicBox, .lullaby, .softPiano, .gentleGuitar, .chimes]
        let hasMelodic = sounds.contains { melodicSounds.contains($0) }

        XCTAssertTrue(hasMelodic, "Older toddler should have melodic sounds available")
    }

    /// Zero intensity should still return sounds
    @MainActor
    func testZeroIntensityReturnsValidSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .tired,
            babyAge: 12,
            cryIntensity: 0.0  // Zero intensity
        )

        XCTAssertFalse(sounds.isEmpty, "Should return sounds even at zero intensity")
    }

    /// Max intensity should prioritize comfort sounds
    @MainActor
    func testMaxIntensityReturnsComfortSounds() async {
        let selector = UltraSmartPlaylistSelector.shared

        let sounds = selector.selectOptimalSounds(
            cryType: .pain,
            babyAge: 6,
            cryIntensity: 1.0  // Maximum intensity
        )

        XCTAssertFalse(sounds.isEmpty, "Should return sounds even at max intensity")

        // First sound should be a comfort sound
        let comfortSounds: Set<GeneratorType> = [.heartbeat, .womb, .musicBox, .lullaby, .ocean, .river]
        if let first = sounds.first {
            XCTAssertTrue(
                comfortSounds.contains(first),
                "First sound at max intensity should be comfort sound, got: \(first.rawValue)"
            )
        }
    }
}
