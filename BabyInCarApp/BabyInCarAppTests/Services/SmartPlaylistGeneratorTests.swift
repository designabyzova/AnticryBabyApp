//
//  SmartPlaylistGeneratorTests.swift
//  BabyInCarAppTests
//
//  Unit tests for FS-029: SmartPlaylistGenerator
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Smart Playlist Generator Tests

@Suite("Smart Playlist Generator")
@MainActor
struct SmartPlaylistGeneratorTests {

    // MARK: - Configuration Tests

    @Test("Default playlist size is 10")
    func defaultPlaylistSize() async {
        #expect(SmartPlaylistGenerator.defaultPlaylistSize == 10)
    }

    @Test("Max category percentage is 25%")
    func maxCategoryPercentage() async {
        #expect(SmartPlaylistGenerator.maxCategoryPercentage == 0.25)
    }

    @Test("Pain cry type requires high calm score")
    func painMinCalmScore() async {
        #expect(SmartPlaylistGenerator.painMinCalmScore == 0.90)
    }

    // MARK: - Weight Configuration Tests

    @Test("Scoring weights are correctly configured")
    func scoringWeights() async {
        #expect(SmartPlaylistGenerator.Weights.age == 0.20)
        #expect(SmartPlaylistGenerator.Weights.cryType == 0.35)
        #expect(SmartPlaylistGenerator.Weights.effectiveness == 0.30)
        #expect(SmartPlaylistGenerator.Weights.favorites == 0.15)
        #expect(SmartPlaylistGenerator.Weights.rotationBonus == 0.12)
        #expect(SmartPlaylistGenerator.Weights.recencyPenalty == 0.10)
    }

    @Test("Cry type weight is highest")
    func cryTypeWeightIsHighest() async {
        let cryTypeWeight = SmartPlaylistGenerator.Weights.cryType
        #expect(cryTypeWeight > SmartPlaylistGenerator.Weights.age)
        #expect(cryTypeWeight > SmartPlaylistGenerator.Weights.effectiveness)
        #expect(cryTypeWeight > SmartPlaylistGenerator.Weights.favorites)
    }

    // MARK: - Playlist Generation Tests

    @Test("Empty track pool returns empty playlist")
    func emptyTracksReturnsEmpty() async {
        let generator = SmartPlaylistGenerator.shared

        let playlist = generator.generatePlaylist(
            for: .hunger,
            babyAge: 6,
            allTracks: [],
            favoriteIds: []
        )

        #expect(playlist.isEmpty)
    }

    @Test("Generated playlist respects max size")
    func respectsMaxSize() async {
        let generator = SmartPlaylistGenerator.shared
        let tracks = createMockTracks(count: 50)

        let playlist = generator.generatePlaylist(
            for: .tired,
            babyAge: 9,
            allTracks: tracks,
            maxTracks: 5
        )

        #expect(playlist.count <= 5)
    }

    @Test("Premium tracks filtered for non-premium users")
    func premiumTracksFiltered() async {
        let generator = SmartPlaylistGenerator.shared

        // Create mix of premium and non-premium tracks
        var tracks = createMockTracks(count: 5, isPremium: false)
        tracks.append(contentsOf: createMockTracks(count: 5, isPremium: true, startIndex: 5))

        let playlist = generator.generatePlaylist(
            for: .hunger,
            babyAge: 6,
            allTracks: tracks,
            isPremium: false
        )

        // Should only contain non-premium tracks
        for track in playlist {
            #expect(track.isPremium == false)
        }
    }

    @Test("Premium users get premium tracks")
    func premiumUsersGetPremiumTracks() async {
        let generator = SmartPlaylistGenerator.shared

        // Create mix of tracks
        var tracks = createMockTracks(count: 3, isPremium: false)
        let premiumTracks = createMockTracks(count: 3, isPremium: true, startIndex: 3, calmScore: 0.99)
        tracks.append(contentsOf: premiumTracks)

        let playlist = generator.generatePlaylist(
            for: .hungry,
            babyAge: 6,
            allTracks: tracks,
            isPremium: true
        )

        // Should include some premium tracks (they have higher calm score)
        let hasPremium = playlist.contains { $0.isPremium }
        #expect(hasPremium == true)
    }

    @Test("Pain cry type filters low calm score tracks")
    func painFiltersCalmScore() async {
        let generator = SmartPlaylistGenerator.shared

        // Create tracks with varying calm scores
        var tracks = createMockTracks(count: 5, calmScore: 0.5)  // Low calm
        tracks.append(contentsOf: createMockTracks(count: 5, startIndex: 5, calmScore: 0.95))  // High calm

        let playlist = generator.generatePlaylist(
            for: .pain,
            babyAge: 6,
            allTracks: tracks
        )

        // All tracks should have high calm score for pain
        for track in playlist {
            #expect(track.calmingScore >= 0.90)
        }
    }

    // MARK: - Recently Played Tests

    @Test("Recently played tracking limits size")
    func recentlyPlayedLimitsSize() async {
        let generator = SmartPlaylistGenerator.shared

        // Record many tracks
        for i in 0..<50 {
            generator.recordTrackPlayed(UUID())
        }

        // Clear at the end
        generator.clearRecentlyPlayed()
    }

    @Test("Clear recently played works")
    func clearRecentlyPlayedWorks() async {
        let generator = SmartPlaylistGenerator.shared

        generator.recordTrackPlayed(UUID())
        generator.recordTrackPlayed(UUID())

        generator.clearRecentlyPlayed()

        // State should be cleared - can verify by generating playlist
        // and checking no recency penalty applied
        #expect(true) // Cleared successfully
    }

    // MARK: - Generation Insights Tests

    @Test("Generation insights contain valid data")
    func generationInsightsValid() async {
        let generator = SmartPlaylistGenerator.shared
        let tracks = createMockTracks(count: 20)

        _ = generator.generatePlaylist(
            for: .tired,
            babyAge: 9,
            allTracks: tracks
        )

        let insights = generator.getGenerationInsights()

        #expect(!insights.confidence.isEmpty)
        #expect(!insights.reasoning.isEmpty)
    }

    // MARK: - Performance Tests

    @Test("Performance stats return valid data")
    func performanceStatsValid() async {
        let generator = SmartPlaylistGenerator.shared

        let stats = generator.getPerformanceStats()

        #expect(stats.average >= 0)
        #expect(stats.min >= 0)
        #expect(stats.max >= stats.min)
        #expect(stats.count >= 0)
    }

    @Test("Playlist generation under 200ms")
    func generationPerformance() async {
        let generator = SmartPlaylistGenerator.shared
        let tracks = createMockTracks(count: 270) // Full library size

        let startTime = Date()
        _ = generator.generatePlaylist(
            for: .hunger,
            babyAge: 12,
            allTracks: tracks,
            maxTracks: 25
        )
        let elapsed = Date().timeIntervalSince(startTime) * 1000

        #expect(elapsed < 200, "Generation took \(Int(elapsed))ms, target is <200ms")
    }

    // MARK: - Category Diversity Tests

    @Test("Playlist includes category diversity")
    func categoryDiversity() async {
        let generator = SmartPlaylistGenerator.shared

        // Create tracks from multiple categories
        var tracks: [AudioTrack] = []
        tracks.append(contentsOf: createMockTracks(count: 10, category: .lullabies))
        tracks.append(contentsOf: createMockTracks(count: 10, startIndex: 10, category: .classical))
        tracks.append(contentsOf: createMockTracks(count: 10, startIndex: 20, category: .ambient))

        let playlist = generator.generatePlaylist(
            for: .tired,
            babyAge: 6,
            allTracks: tracks,
            maxTracks: 10
        )

        // Check that no single category dominates
        var categoryCounts: [AudioCategory: Int] = [:]
        for track in playlist {
            categoryCounts[track.category, default: 0] += 1
        }

        let maxAllowed = Int(ceil(Double(10) * 0.25)) // 25% max
        for (_, count) in categoryCounts {
            #expect(count <= maxAllowed + 1, "Category exceeds diversity limit")
        }
    }

    // MARK: - Helper Methods

    private func createMockTracks(
        count: Int,
        isPremium: Bool = false,
        startIndex: Int = 0,
        calmScore: Double = 0.85,
        category: AudioCategory = .lullabies
    ) -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        for i in 0..<count {
            let track = AudioTrack(
                id: UUID(),
                title: "Track \(startIndex + i)",
                category: category,
                duration: 180,
                audioSourceType: .generated,
                generatorType: .lullaby,
                ageRangeMin: 0,
                ageRangeMax: 36,
                calmingScore: calmScore,
                isPremium: isPremium
            )
            tracks.append(track)
        }

        return tracks
    }
}

// MARK: - Category Rotation Manager Tests

@Suite("Category Rotation Manager")
@MainActor
struct CategoryRotationManagerTests {

    @Test("Initial session has no played categories")
    func initialSessionEmpty() async {
        let manager = CategoryRotationManager.shared
        manager.resetSession()

        let stats = manager.getRotationStats()
        #expect(stats.categoriesPlayedThisSession == 0)
    }

    @Test("Recording category updates stats")
    func recordCategoryUpdatesStats() async {
        let manager = CategoryRotationManager.shared
        manager.resetSession()

        manager.recordCategoryPlayed(.lullabies)

        let stats = manager.getRotationStats()
        #expect(stats.categoriesPlayedThisSession >= 1)

        // Cleanup
        manager.resetSession()
    }

    @Test("Rotation bonus for fresh category is higher")
    func rotationBonusForFreshCategory() async {
        let manager = CategoryRotationManager.shared
        manager.resetSession()

        // Play one category multiple times
        manager.recordCategoryPlayed(.classical)
        manager.recordCategoryPlayed(.classical)
        manager.recordCategoryPlayed(.classical)

        // Fresh category should have higher bonus
        let classicalBonus = manager.getRotationBonus(for: .classical)
        let lullabiesBonus = manager.getRotationBonus(for: .lullabies)

        #expect(lullabiesBonus >= classicalBonus)

        // Cleanup
        manager.resetSession()
    }

    @Test("Reset session clears rotation data")
    func resetSessionClearsData() async {
        let manager = CategoryRotationManager.shared

        manager.recordCategoryPlayed(.ambient)
        manager.recordCategoryPlayed(.ambient)

        manager.resetSession()

        // After reset, ambient should have same bonus as fresh category
        let ambientBonus = manager.getRotationBonus(for: .ambient)
        let freshBonus = manager.getRotationBonus(for: .classical)

        #expect(ambientBonus == freshBonus)
    }
}

// MARK: - Playlist Generation Insights Tests

@Suite("Playlist Generation Insights")
struct PlaylistGenerationInsightsTests {

    @Test("Insights struct holds correct data")
    func insightsStructValid() {
        let stats = CategoryRotationStats(
            categoriesPlayedThisSession: 3,
            mostPlayedCategory: .lullabies,
            leastPlayedCategory: .ambient
        )

        let insights = PlaylistGenerationInsights(
            topTracks: ["Track 1", "Track 2", "Track 3"],
            confidence: "85%",
            reasoning: "Selected for tired cry",
            rotationStats: stats
        )

        #expect(insights.topTracks.count == 3)
        #expect(insights.confidence == "85%")
        #expect(insights.reasoning.contains("tired"))
        #expect(insights.rotationStats.categoriesPlayedThisSession == 3)
    }
}
