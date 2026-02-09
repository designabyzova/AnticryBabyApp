//
//  ActionCategoryTests.swift
//  BabyInCarAppTests
//
//  Unit tests for ActionCategory - DeepInfant V2 cry type mapping (5 → 3)
//

import XCTest
@testable import BabyInCarApp

final class ActionCategoryTests: XCTestCase {

    // MARK: - DeepInfantCryType Tests

    func testDeepInfantCryTypeAllCases() {
        // Verify all 5 DeepInfant V2 cry types
        let allTypes = DeepInfantCryType.allCases
        XCTAssertEqual(allTypes.count, 5, "DeepInfant V2 has 5 cry types")

        let expectedTypes: Set<String> = ["hungry", "needs_burping", "belly_pain", "discomfort", "tired"]
        let actualTypes = Set(allTypes.map { $0.rawValue })
        XCTAssertEqual(actualTypes, expectedTypes)
    }

    func testDeepInfantCryTypeDisplayNames() {
        XCTAssertEqual(DeepInfantCryType.hungry.displayName, "Hungry")
        XCTAssertEqual(DeepInfantCryType.needsBurping.displayName, "Needs Burping")
        XCTAssertEqual(DeepInfantCryType.bellyPain.displayName, "Belly Pain")
        XCTAssertEqual(DeepInfantCryType.discomfort.displayName, "Uncomfortable")
        XCTAssertEqual(DeepInfantCryType.tired.displayName, "Tired")
    }

    func testDeepInfantCryTypeIconNames() {
        // Verify all types have icons
        for cryType in DeepInfantCryType.allCases {
            XCTAssertFalse(cryType.iconName.isEmpty, "\(cryType) should have an icon")
        }
    }

    // MARK: - ActionCategory Tests

    func testActionCategoryAllCases() {
        // Verify 3 action categories
        let allCategories = ActionCategory.allCases
        XCTAssertEqual(allCategories.count, 3, "Should have 3 action categories")

        let expectedCategories: Set<String> = ["hungry", "uncomfortable", "tired"]
        let actualCategories = Set(allCategories.map { $0.rawValue })
        XCTAssertEqual(actualCategories, expectedCategories)
    }

    func testActionCategoryDisplayNames() {
        XCTAssertEqual(ActionCategory.hungry.displayName, "Hungry")
        XCTAssertEqual(ActionCategory.uncomfortable.displayName, "Uncomfortable")
        XCTAssertEqual(ActionCategory.tired.displayName, "Tired")
    }

    func testActionCategorySuggestedActions() {
        // All categories should have non-empty suggestions
        for category in ActionCategory.allCases {
            XCTAssertFalse(category.suggestedAction.isEmpty, "\(category) should have a suggested action")
            XCTAssertGreaterThan(category.suggestedAction.count, 10, "Suggested action should be descriptive")
        }
    }

    func testActionCategoryPlaylistCategories() {
        XCTAssertEqual(ActionCategory.hungry.playlistCategory, "distraction")
        XCTAssertEqual(ActionCategory.uncomfortable.playlistCategory, "soothing")
        XCTAssertEqual(ActionCategory.tired.playlistCategory, "lullaby")
    }

    // MARK: - Mapping Tests (5 → 3)

    func testMappingHungryToHungry() {
        let category = ActionCategory.from(.hungry)
        XCTAssertEqual(category, .hungry)
    }

    func testMappingNeedsBurpingToUncomfortable() {
        let category = ActionCategory.from(.needsBurping)
        XCTAssertEqual(category, .uncomfortable)
    }

    func testMappingBellyPainToUncomfortable() {
        let category = ActionCategory.from(.bellyPain)
        XCTAssertEqual(category, .uncomfortable)
    }

    func testMappingDiscomfortToUncomfortable() {
        let category = ActionCategory.from(DeepInfantCryType.discomfort)
        XCTAssertEqual(category, ActionCategory.uncomfortable)
    }

    func testMappingTiredToTired() {
        let category = ActionCategory.from(DeepInfantCryType.tired)
        XCTAssertEqual(category, ActionCategory.tired)
    }

    func testAllMappingsAreDefined() {
        // Verify every DeepInfantCryType maps to an ActionCategory
        for cryType in DeepInfantCryType.allCases {
            let category = ActionCategory.from(cryType)
            XCTAssertNotNil(category, "\(cryType) should map to a category")
        }
    }

    // MARK: - Convenience Property Tests

    func testDeepInfantCryTypeActionCategoryProperty() {
        // Test the convenience property on DeepInfantCryType
        XCTAssertEqual(DeepInfantCryType.hungry.actionCategory, .hungry)
        XCTAssertEqual(DeepInfantCryType.needsBurping.actionCategory, .uncomfortable)
        XCTAssertEqual(DeepInfantCryType.bellyPain.actionCategory, .uncomfortable)
        XCTAssertEqual(DeepInfantCryType.discomfort.actionCategory, .uncomfortable)
        XCTAssertEqual(DeepInfantCryType.tired.actionCategory, .tired)
    }

    // MARK: - Legacy MoodType Mapping Tests

    func testMappingFromLegacyMoodType() {
        // Verify legacy MoodType/CryType mapping
        XCTAssertEqual(ActionCategory.from(MoodType.hunger), ActionCategory.hungry)
        XCTAssertEqual(ActionCategory.from(MoodType.tired), ActionCategory.tired)
        XCTAssertEqual(ActionCategory.from(MoodType.pain), ActionCategory.uncomfortable)
        XCTAssertEqual(ActionCategory.from(MoodType.attention), ActionCategory.uncomfortable)
        XCTAssertEqual(ActionCategory.from(MoodType.discomfort), ActionCategory.uncomfortable)
        XCTAssertEqual(ActionCategory.from(MoodType.general), ActionCategory.uncomfortable)
        XCTAssertEqual(ActionCategory.from(MoodType.unknown), ActionCategory.uncomfortable)
    }

    // MARK: - String Parsing Tests

    func testFromStringDirectMatch() {
        XCTAssertEqual(ActionCategory.from(string: "hungry"), .hungry)
        XCTAssertEqual(ActionCategory.from(string: "uncomfortable"), .uncomfortable)
        XCTAssertEqual(ActionCategory.from(string: "tired"), .tired)
    }

    func testFromStringCaseInsensitive() {
        XCTAssertEqual(ActionCategory.from(string: "HUNGRY"), .hungry)
        XCTAssertEqual(ActionCategory.from(string: "Tired"), .tired)
        XCTAssertEqual(ActionCategory.from(string: "UnComfortaBle"), .uncomfortable)
    }

    func testFromStringDeepInfantTypes() {
        XCTAssertEqual(ActionCategory.from(string: "needs_burping"), .uncomfortable)
        XCTAssertEqual(ActionCategory.from(string: "belly_pain"), .uncomfortable)
        XCTAssertEqual(ActionCategory.from(string: "hunger"), .hungry)  // Legacy
    }

    func testFromStringInvalid() {
        XCTAssertNil(ActionCategory.from(string: "invalid"))
        XCTAssertNil(ActionCategory.from(string: ""))
        XCTAssertNil(ActionCategory.from(string: "random_string"))
    }

    // MARK: - Classification Result Tests

    func testDeepInfantClassificationResultInit() {
        let result = DeepInfantClassificationResult(
            rawCryType: .hungry,
            confidence: 0.85,
            probabilities: [.hungry: 0.85, .tired: 0.15]
        )

        XCTAssertEqual(result.rawCryType, .hungry)
        XCTAssertEqual(result.actionCategory, .hungry)  // Auto-mapped
        XCTAssertEqual(result.confidence, 0.85, accuracy: 0.01)
        XCTAssertTrue(result.isConfident)
    }

    func testDeepInfantClassificationResultIsConfident() {
        let confident = DeepInfantClassificationResult(
            rawCryType: .tired,
            confidence: 0.75,
            probabilities: [:]
        )
        XCTAssertTrue(confident.isConfident)

        let notConfident = DeepInfantClassificationResult(
            rawCryType: .tired,
            confidence: 0.65,
            probabilities: [:]
        )
        XCTAssertFalse(notConfident.isConfident)
    }

    func testDeepInfantClassificationResultFromStrings() {
        let result = DeepInfantClassificationResult(
            cryTypeString: "belly_pain",
            confidence: 0.80,
            probabilityStrings: ["belly_pain": 0.80, "hungry": 0.10, "tired": 0.10]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.rawCryType, .bellyPain)
        XCTAssertEqual(result?.actionCategory, .uncomfortable)
    }

    func testDeepInfantClassificationResultFromInvalidString() {
        let result = DeepInfantClassificationResult(
            cryTypeString: "invalid_type",
            confidence: 0.80,
            probabilityStrings: [:]
        )

        XCTAssertNil(result)
    }

    // MARK: - CryResponsePlaylist Tests

    func testCryResponsePlaylistForCategory() {
        let hungryPlaylist = CryResponsePlaylist.getPlaylist(for: .hungry)
        XCTAssertEqual(hungryPlaylist.category, .hungry)
        XCTAssertEqual(hungryPlaylist.playlistId, "distraction")

        let uncomfortablePlaylist = CryResponsePlaylist.getPlaylist(for: .uncomfortable)
        XCTAssertEqual(uncomfortablePlaylist.category, .uncomfortable)
        XCTAssertEqual(uncomfortablePlaylist.playlistId, "soothing")

        let tiredPlaylist = CryResponsePlaylist.getPlaylist(for: .tired)
        XCTAssertEqual(tiredPlaylist.category, .tired)
        XCTAssertEqual(tiredPlaylist.playlistId, "lullaby")
    }

    func testAllPlaylistsAvailable() {
        let allPlaylists = CryResponsePlaylist.allPlaylists
        XCTAssertEqual(allPlaylists.count, 3)

        let categories = Set(allPlaylists.map { $0.category })
        XCTAssertEqual(categories, Set(ActionCategory.allCases))
    }
}
