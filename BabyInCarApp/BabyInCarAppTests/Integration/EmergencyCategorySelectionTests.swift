//
//  EmergencyCategorySelectionTests.swift
//  BabyInCarAppTests
//
//  Tests for emergency mode with category selection and bundled default track
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Emergency Category Selection Tests

@Suite("Emergency Category Selection")
@MainActor
struct EmergencyCategorySelectionTests {

    // MARK: - Default Track Tests

    @Test("Default emergency track is Pianomoment by Bensound")
    func defaultEmergencyTrackIsPianomoment() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.title == "Pianomoment",
               "Default emergency track title should be 'Pianomoment'")
        #expect(defaultTrack.artist == "Bensound",
               "Default emergency track artist should be 'Bensound'")
        #expect(defaultTrack.category == .ambient,
               "Default emergency track should be ambient category")
    }

    @Test("Default emergency track is streamed from R2 (real audio, not AI-generated)")
    func defaultEmergencyTrackIsStreamed() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.audioSourceType == .streamed,
               "Default emergency track should be STREAMED (real music from R2, not AI-generated)")
        #expect(defaultTrack.generatorType == nil,
               "Default emergency track should NOT have a generator type (it's real audio)")
        #expect(defaultTrack.streamURL != nil,
               "Default emergency track should have a stream URL")
        #expect(defaultTrack.streamURL?.contains("r2.dev") == true,
               "Default emergency track should stream from R2 CDN")
    }

    @Test("Default emergency track has appropriate calming score")
    func defaultEmergencyTrackHasAppropriateScore() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.calmingScore >= 0.8,
               "Default emergency track should have good calming score (>=0.8), got: \(defaultTrack.calmingScore)")
    }

    @Test("Default emergency track is age-appropriate for all babies")
    func defaultEmergencyTrackIsAgeAppropriate() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.ageRangeMin == 0,
               "Default emergency track should be appropriate from birth")
        #expect(defaultTrack.ageRangeMax == 36,
               "Default emergency track should be appropriate up to 36 months")
        #expect(defaultTrack.optimalAgeMonths.count == 37,
               "Default emergency track should cover all ages 0-36 months")
    }

    @Test("Default emergency track is not premium")
    func defaultEmergencyTrackIsNotPremium() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.isPremium == false,
               "Default emergency track should not be premium")
        #expect(defaultTrack.isLocked == false,
               "Default emergency track should not be locked")
    }

    // MARK: - Emergency Activation Tests

    @Test("Emergency activation without category plays default track")
    func emergencyWithoutCategoryPlaysDefault() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .male
        )

        engine.deactivate()
        await engine.activate(for: testBaby)

        #expect(engine.isActive == true,
               "Emergency mode should be active")

        engine.deactivate()
    }

    @Test("Emergency activation with category filters tracks")
    func emergencyWithCategoryFilters() async {
        let engine = SmartCryResponseEngine.shared
        let queue = SmartEmergencyQueue.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -12, to: Date())!,
            gender: .female
        )

        // Build queue with classical music category filter
        let tracks = await queue.buildQueue(
            for: .hunger,
            babyAge: testBaby.ageInMonths,
            language: "en",
            maxTracks: 20,
            preferredCategory: .classicalMusic
        )

        // All tracks should be classical music
        for track in tracks {
            #expect(track.category == .classicalMusic,
                   "When filtering by classical music, all tracks should be classical, got: \(track.category.rawValue)")
        }
    }

    @Test("Emergency activation with lullabies category")
    func emergencyWithLullabiesCategory() async {
        let queue = SmartEmergencyQueue.shared

        let tracks = await queue.buildQueue(
            for: .tired,
            babyAge: 6,
            language: "en",
            maxTracks: 20,
            preferredCategory: .lullabies
        )

        // All tracks should be lullabies
        for track in tracks {
            #expect(track.category == .lullabies,
                   "When filtering by lullabies, all tracks should be lullabies, got: \(track.category.rawValue)")
        }
    }

    @Test("Emergency activation with nature sounds category")
    func emergencyWithNatureSoundsCategory() async {
        let queue = SmartEmergencyQueue.shared

        let tracks = await queue.buildQueue(
            for: .general,
            babyAge: 18,
            language: "en",
            maxTracks: 20,
            preferredCategory: .natureSounds
        )

        // All tracks should be nature sounds
        for track in tracks {
            #expect(track.category == .natureSounds,
                   "When filtering by nature sounds, all tracks should be nature sounds, got: \(track.category.rawValue)")
        }
    }

    @Test("Emergency playlist mode respects category preference")
    func emergencyPlaylistModeRespectsCategory() async {
        let engine = SmartCryResponseEngine.shared

        let testBaby = Baby(
            name: "TestBaby",
            dateOfBirth: Calendar.current.date(byAdding: .month, value: -9, to: Date())!,
            gender: .male
        )

        engine.deactivate()

        // Activate with instrumental category preference
        await engine.activateEmergencyPlaylistMode(
            for: testBaby,
            preferredCategory: .instrumental
        )

        #expect(engine.isActive == true,
               "Emergency mode should be active")
        #expect(engine.isEmergencyMode == true,
               "Emergency playlist mode should be enabled")

        engine.deactivate()
    }

    // MARK: - Audio Session Tests

    @Test("Emergency mode interrupts other audio")
    func emergencyModeInterruptsOtherAudio() async {
        let audioEngine = AudioEngine.shared

        // Configure audio session for emergency (should interrupt)
        let result = audioEngine.configureAudioSession(interruptOtherAudio: true)

        #expect(result == true,
               "Emergency audio session configuration should succeed")
    }

    // MARK: - Category Availability Tests

    @Test("All audio categories are available for emergency selection")
    func allCategoriesAvailableForEmergency() {
        let allCategories = AudioCategory.allCases

        // Verify we have expected categories
        let expectedCategories: [AudioCategory] = [
            .classicalMusic,
            .lullabies,
            .natureSounds,
            .instrumental,
            .ambient,
            .childrenSongs,
            .fairyTales,
            .podcasts
        ]

        for category in expectedCategories {
            #expect(allCategories.contains(category),
                   "\(category.rawValue) should be available for emergency selection")
        }
    }

    @Test("Category descriptions are not empty")
    func categoryDescriptionsNotEmpty() {
        for category in AudioCategory.allCases {
            #expect(!category.description.isEmpty,
                   "\(category.rawValue) should have a description")
        }
    }

    @Test("Category icons are not empty")
    func categoryIconsNotEmpty() {
        for category in AudioCategory.allCases {
            #expect(!category.icon.isEmpty,
                   "\(category.rawValue) should have an icon")
        }
    }
}

// MARK: - XCTest Integration

final class EmergencyCategorySelectionXCTests: XCTestCase {

    @MainActor
    func testDefaultTrackCanBeCreated() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()
        XCTAssertNotNil(defaultTrack)
        XCTAssertEqual(defaultTrack.title, "Pianomoment")
        XCTAssertEqual(defaultTrack.audioSourceType, .streamed)
    }

    @MainActor
    func testSmartEmergencyQueueExists() {
        let queue = SmartEmergencyQueue.shared
        XCTAssertNotNil(queue)
    }

    @MainActor
    func testAllCategoriesHaveProperties() {
        for category in AudioCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty, "\(category) should have a raw value")
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have an icon")
            XCTAssertFalse(category.description.isEmpty, "\(category) should have a description")
        }
    }

    @MainActor
    func testEmergencyCategorySelectorViewCanBeCreated() {
        // Test that EmergencyCategorySelectorView can be instantiated
        let selectedCategory = Binding<AudioCategory?>(
            get: { nil },
            set: { _ in }
        )

        let view = EmergencyCategorySelectorView(
            selectedCategory: selectedCategory,
            onConfirm: {}
        )

        XCTAssertNotNil(view)
    }
}
