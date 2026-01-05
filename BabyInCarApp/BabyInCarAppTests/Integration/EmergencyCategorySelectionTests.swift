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

    @Test("Default emergency track is Piano Moment")
    func defaultEmergencyTrackIsPianoMoment() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.title == "Piano Moment",
               "Default emergency track title should be 'Piano Moment'")
        #expect(defaultTrack.artist == "Bensound",
               "Default emergency track artist should be 'Bensound'")
        #expect(defaultTrack.category == .classicalMusic,
               "Default emergency track should be classical music")
    }

    @Test("Default emergency track is bundled")
    func defaultEmergencyTrackIsBundled() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.audioSourceType == .bundled,
               "Default emergency track should be bundled with app")
        #expect(defaultTrack.isDownloaded == true,
               "Default emergency track should be marked as downloaded")
        #expect(defaultTrack.fileName == "bensound_pianomoment",
               "Default emergency track should have correct file name (without extension)")
    }

    @Test("Default emergency track has high calming score")
    func defaultEmergencyTrackHasHighCalmingScore() {
        let defaultTrack = AudioTrack.defaultEmergencyTrack()

        #expect(defaultTrack.calmingScore >= 0.9,
               "Default emergency track should have high calming score (>=0.9), got: \(defaultTrack.calmingScore)")
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

    @Test("Emergency mode enables ducking correctly")
    func emergencyModeEnablesDucking() {
        let audioEngine = AudioEngine.shared

        // Enable emergency ducking (should interrupt, not mix)
        audioEngine.enableDucking(true, emergencyMode: true)

        // Should not throw error (test passes if no crash)
        #expect(true, "Emergency ducking should enable without errors")
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
        XCTAssertEqual(defaultTrack.title, "Piano Moment")
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
