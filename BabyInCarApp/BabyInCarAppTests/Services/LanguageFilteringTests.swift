//
//  LanguageFilteringTests.swift
//  BabyInCarAppTests
//
//  Created for FS-017: Smart Emergency Playlist System
//  Tests language filtering functionality for emergency playlists
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - User Language Preference Tests

@Suite("Language Filtering")
struct LanguageFilteringTests {

    // MARK: - UserLanguagePreference Tests

    @Test("Parses comma-separated languages correctly")
    func parsesLanguageString() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en,ru",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.parsedLanguages.count == 2)
        #expect(prefs.parsedLanguages.contains("en"))
        #expect(prefs.parsedLanguages.contains("ru"))
    }

    @Test("Single language parses correctly")
    func parsesSingleLanguage() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.parsedLanguages.count == 1)
        #expect(prefs.parsedLanguages.first == "en")
    }

    @Test("isPreferred returns true for preferred language")
    func isPreferredReturnsTrueForPreferred() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en,ru",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.isPreferred("en") == true)
        #expect(prefs.isPreferred("ru") == true)
    }

    @Test("isPreferred returns false for non-preferred language")
    func isPreferredReturnsFalseForNonPreferred() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.isPreferred("ru") == false)
        #expect(prefs.isPreferred("fr") == false)
        #expect(prefs.isPreferred("de") == false)
    }

    @Test("Multi (instrumental) always included unless excluded")
    func multiLanguageAlwaysIncluded() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        // Multi should be included even when only "en" is preferred
        #expect(prefs.isPreferred("multi") == true)
    }

    @Test("Multi excluded when excludeInstrumental is true")
    func multiExcludedWhenFlagSet() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en",
            primaryLanguage: "en",
            excludeInstrumental: true
        )

        // Multi should be excluded
        #expect(prefs.isPreferred("multi") == false)
    }

    @Test("Language names formatted correctly")
    func languageNamesFormatted() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en,ru",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.languageNames.contains("English"))
        #expect(prefs.languageNames.contains("Russian"))
    }

    @Test("Formatted languages string correct")
    func formattedLanguagesString() {
        let prefs = UserLanguagePreference(
            userId: "test-user",
            preferredLanguages: "en,ru",
            primaryLanguage: "en",
            excludeInstrumental: false
        )

        #expect(prefs.formattedLanguages == "English, Russian")
    }

    // MARK: - CryScenarioPlaylist Language Matching Tests

    @Test("Playlist matches when language is in preferences")
    func playlistMatchesPreferredLanguage() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.matchesLanguage(["en"]) == true)
        #expect(playlist.matchesLanguage(["en", "ru"]) == true)
    }

    @Test("Playlist does not match when language not in preferences")
    func playlistDoesNotMatchNonPreferred() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Test Playlist",
            description: nil,
            language: "ru",
            ageRangeMin: 0,
            ageRangeMax: 24,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.matchesLanguage(["en"]) == false)
        #expect(playlist.matchesLanguage(["fr", "de"]) == false)
    }

    @Test("Multi-language playlist matches all preferences")
    func multiPlaylistMatchesAll() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "hunger",
            name: "Instrumental Playlist",
            description: nil,
            language: "multi",
            ageRangeMin: 0,
            ageRangeMax: 36,
            priority: 1,
            aiConfidenceScore: 0.90,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        // Multi should always match
        #expect(playlist.matchesLanguage(["en"]) == true)
        #expect(playlist.matchesLanguage(["ru"]) == true)
        #expect(playlist.matchesLanguage(["fr"]) == true)
        #expect(playlist.matchesLanguage(["en", "ru"]) == true)
    }

    // MARK: - Age Range Filtering Tests

    @Test("Playlist suitable for baby within age range")
    func playlistSuitableForAgeInRange() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "tired",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 3,
            ageRangeMax: 18,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.isSuitableForAge(3) == true)   // Minimum
        #expect(playlist.isSuitableForAge(6) == true)   // Middle
        #expect(playlist.isSuitableForAge(12) == true)  // Middle
        #expect(playlist.isSuitableForAge(18) == true)  // Maximum
    }

    @Test("Playlist not suitable for baby outside age range")
    func playlistNotSuitableForAgeOutOfRange() {
        let playlist = CryScenarioPlaylist(
            id: "test-001",
            cryType: "tired",
            name: "Test Playlist",
            description: nil,
            language: "en",
            ageRangeMin: 6,
            ageRangeMax: 12,
            priority: 1,
            aiConfidenceScore: 0.85,
            totalDurationSeconds: 600,
            trackCount: 5,
            tracks: []
        )

        #expect(playlist.isSuitableForAge(3) == false)   // Too young
        #expect(playlist.isSuitableForAge(5) == false)   // Too young
        #expect(playlist.isSuitableForAge(18) == false)  // Too old
        #expect(playlist.isSuitableForAge(24) == false)  // Too old
    }

    // MARK: - Combined Filtering Tests

    @Test("Filters playlists by both language and age")
    func combinedFiltering() {
        let playlists = [
            CryScenarioPlaylist(id: "1", cryType: "hunger", name: "English Young", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 12, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "hunger", name: "English Old", description: nil, language: "en", ageRangeMin: 12, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.80, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "3", cryType: "hunger", name: "Russian", description: nil, language: "ru", ageRangeMin: 0, ageRangeMax: 24, priority: 1, aiConfidenceScore: 0.90, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "4", cryType: "hunger", name: "Instrumental", description: nil, language: "multi", ageRangeMin: 0, ageRangeMax: 36, priority: 2, aiConfidenceScore: 0.88, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        let preferredLanguages = ["en"]
        let babyAge = 6

        let filtered = playlists.filter { playlist in
            playlist.matchesLanguage(preferredLanguages) && playlist.isSuitableForAge(babyAge)
        }

        // Should match: English Young (en, 0-12) and Instrumental (multi, 0-36)
        // Should NOT match: English Old (age mismatch), Russian (language mismatch)
        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.id == "1" })  // English Young
        #expect(filtered.contains { $0.id == "4" })  // Instrumental
    }

    @Test("Russian-only user gets Russian and instrumental playlists")
    func russianOnlyFiltering() {
        let playlists = [
            CryScenarioPlaylist(id: "1", cryType: "tired", name: "English", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "tired", name: "Russian", description: nil, language: "ru", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.90, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "3", cryType: "tired", name: "Instrumental", description: nil, language: "multi", ageRangeMin: 0, ageRangeMax: 36, priority: 2, aiConfidenceScore: 0.88, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        let preferredLanguages = ["ru"]
        let babyAge = 12

        let filtered = playlists.filter { playlist in
            playlist.matchesLanguage(preferredLanguages) && playlist.isSuitableForAge(babyAge)
        }

        // Should match: Russian and Instrumental
        // Should NOT match: English
        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.id == "2" })  // Russian
        #expect(filtered.contains { $0.id == "3" })  // Instrumental
        #expect(!filtered.contains { $0.id == "1" }) // NOT English
    }

    @Test("Bilingual user gets all matching language playlists")
    func bilingualFiltering() {
        let playlists = [
            CryScenarioPlaylist(id: "1", cryType: "pain", name: "English", description: nil, language: "en", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.85, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "2", cryType: "pain", name: "Russian", description: nil, language: "ru", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.90, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "3", cryType: "pain", name: "French", description: nil, language: "fr", ageRangeMin: 0, ageRangeMax: 36, priority: 1, aiConfidenceScore: 0.82, totalDurationSeconds: 600, trackCount: 5, tracks: []),
            CryScenarioPlaylist(id: "4", cryType: "pain", name: "Instrumental", description: nil, language: "multi", ageRangeMin: 0, ageRangeMax: 36, priority: 2, aiConfidenceScore: 0.88, totalDurationSeconds: 600, trackCount: 5, tracks: []),
        ]

        let preferredLanguages = ["en", "ru"]
        let babyAge = 9

        let filtered = playlists.filter { playlist in
            playlist.matchesLanguage(preferredLanguages) && playlist.isSuitableForAge(babyAge)
        }

        // Should match: English, Russian, Instrumental
        // Should NOT match: French
        #expect(filtered.count == 3)
        #expect(filtered.contains { $0.id == "1" })  // English
        #expect(filtered.contains { $0.id == "2" })  // Russian
        #expect(filtered.contains { $0.id == "4" })  // Instrumental
        #expect(!filtered.contains { $0.id == "3" }) // NOT French
    }
}

// MARK: - XCTest for CI/CD

final class LanguageFilteringXCTests: XCTestCase {

    func testUserLanguagePreferenceDefaultPresets() {
        // Test default presets exist and are valid
        let englishOnly = UserLanguagePreference.defaultEnglish
        XCTAssertEqual(englishOnly.primaryLanguage, "en")
        XCTAssertEqual(englishOnly.parsedLanguages, ["en"])

        let bilingual = UserLanguagePreference.bilingual
        XCTAssertEqual(bilingual.primaryLanguage, "en")
        XCTAssertEqual(bilingual.parsedLanguages.count, 2)
        XCTAssertTrue(bilingual.parsedLanguages.contains("en"))
        XCTAssertTrue(bilingual.parsedLanguages.contains("ru"))

        let russianOnly = UserLanguagePreference.russianOnly
        XCTAssertEqual(russianOnly.primaryLanguage, "ru")
        XCTAssertEqual(russianOnly.parsedLanguages, ["ru"])
    }

    func testCryScenarioPlaylistMockPresets() {
        // Test mock presets exist and are valid
        let hungerPlaylist = CryScenarioPlaylist.mockHungerPlaylist
        XCTAssertEqual(hungerPlaylist.cryType, "hunger")
        XCTAssertEqual(hungerPlaylist.language, "en")

        let tiredPlaylist = CryScenarioPlaylist.mockTiredPlaylist
        XCTAssertEqual(tiredPlaylist.cryType, "tired")
        XCTAssertEqual(tiredPlaylist.language, "ru")
    }

    func testLanguagePreferenceUpdate() {
        let original = UserLanguagePreference.defaultEnglish

        // Update to bilingual
        let updated = original.with(languages: ["en", "ru"])

        XCTAssertEqual(updated.parsedLanguages.count, 2)
        XCTAssertTrue(updated.parsedLanguages.contains("en"))
        XCTAssertTrue(updated.parsedLanguages.contains("ru"))
        XCTAssertEqual(updated.primaryLanguage, "en")  // Kept from original
    }

    func testLanguagePreferenceUpdateWithPrimary() {
        let original = UserLanguagePreference.defaultEnglish

        // Update to Russian primary
        let updated = original.with(languages: ["ru"], primary: "ru")

        XCTAssertEqual(updated.parsedLanguages, ["ru"])
        XCTAssertEqual(updated.primaryLanguage, "ru")
    }
}
