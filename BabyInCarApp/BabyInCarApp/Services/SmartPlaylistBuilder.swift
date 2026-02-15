//
//  SmartPlaylistBuilder.swift
//  BabyInCarApp
//
//  Smart playlist generation service for unified player architecture
//

import Foundation

@MainActor
class SmartPlaylistBuilder {
    static let shared = SmartPlaylistBuilder()

    private let contentLibrary = ContentLibraryService.shared
    private let smartPlaylistGenerator = SmartPlaylistGenerator.shared
    private let effectivenessManager = EffectivenessManager.shared
    private let favoritesManager = FavoritesManager.shared

    private init() {}

    // MARK: - Emergency Playlist Generation

    /// Build emergency playlist for cry response
    /// Returns Playlist with auto-replenishment enabled and smart track selection
    func buildEmergencyPlaylist(
        cryType: CryType,
        babyAge: Int,
        language: String = "en",
        maxTracks: Int = 30
    ) async -> Playlist {
        print("[SmartPlaylistBuilder] 🚨 Building emergency playlist for \(cryType.displayName), age \(babyAge)mo")

        // Use SmartPlaylistGenerator for multi-criteria cry-type-specific selection (FS-029)
        let allTracks = contentLibrary.allTracks
        let favoriteIds = Set(favoritesManager.favoriteTracks)

        let tracks = smartPlaylistGenerator.generatePlaylist(
            for: cryType,
            babyAge: babyAge,
            allTracks: allTracks,
            favoriteIds: favoriteIds,
            isPremium: SubscriptionManager.shared.isPremium,
            maxTracks: maxTracks
        )

        // Log AI reasoning for debugging
        let insights = smartPlaylistGenerator.getGenerationInsights()
        print("[SmartPlaylistBuilder] AI reasoning: \(insights.reasoning) (confidence: \(insights.confidence))")

        // Create metadata for auto-replenishment
        let metadata = PlaylistGenerationMetadata(
            babyAge: babyAge,
            cryType: cryType,
            language: language,
            allowGenerated: true  // Emergency mode allows generated sounds
        )

        return Playlist(
            name: "Emergency: \(cryType.displayName)",
            description: "AI-selected tracks to soothe \(cryType.displayName) cry",
            tracks: tracks,
            category: nil,
            targetAgeMonths: babyAge,
            isSystemGenerated: true,
            createdAt: Date(),
            artworkName: nil,
            updatedAt: nil,
            isAutoReplenishing: true,  // Enable Spotify-style infinite queue
            minQueueSize: 6,           // Replenish when <6 tracks remain (always show 6 upcoming)
            generationContext: metadata
        )
    }

    // MARK: - Queue Replenishment

    /// Generate more tracks for auto-replenishing queue
    /// Called when queue runs low during playback
    func generateMoreTracks(
        context: PlaylistGenerationMetadata,
        count: Int
    ) async -> [AudioTrack] {
        print("[SmartPlaylistBuilder] 🔄 Generating \(count) more tracks")

        let cryType = context.cryType ?? .general

        // Use SmartPlaylistGenerator for consistent multi-criteria selection (FS-029)
        let allTracks = contentLibrary.allTracks
        let favoriteIds = Set(favoritesManager.favoriteTracks)

        let newTracks = smartPlaylistGenerator.generatePlaylist(
            for: cryType,
            babyAge: context.babyAge,
            allTracks: allTracks,
            favoriteIds: favoriteIds,
            isPremium: SubscriptionManager.shared.isPremium,
            maxTracks: count
        )

        return newTracks
    }

    // MARK: - Cry Type Change Handling (FS-029)

    /// Build new playlist when cry type changes during playback
    /// Maintains continuity by keeping current track position
    func buildPlaylistForCryTypeChange(
        newCryType: CryType,
        previousCryType: CryType,
        babyAge: Int,
        maxTracks: Int = 25
    ) async -> Playlist {
        print("[SmartPlaylistBuilder] 🔄 Rebuilding playlist: \(previousCryType.displayName) → \(newCryType.displayName)")

        // Record the playlist change in CategoryRotationManager
        CategoryRotationManager.shared.resetSession()

        // Use SmartPlaylistGenerator for new cry type
        let allTracks = contentLibrary.allTracks
        let favoriteIds = Set(favoritesManager.favoriteTracks)

        let tracks = smartPlaylistGenerator.generatePlaylist(
            for: newCryType,
            babyAge: babyAge,
            allTracks: allTracks,
            favoriteIds: favoriteIds,
            isPremium: SubscriptionManager.shared.isPremium,
            maxTracks: maxTracks
        )

        // Log the change
        let insights = smartPlaylistGenerator.getGenerationInsights()
        print("[SmartPlaylistBuilder] New playlist: \(tracks.count) tracks for \(newCryType.displayName) (reason: \(insights.reasoning))")

        // Create metadata for continued auto-replenishment
        let metadata = PlaylistGenerationMetadata(
            babyAge: babyAge,
            cryType: newCryType,
            language: "en",
            allowGenerated: true
        )

        return Playlist(
            name: "Soothing: \(newCryType.displayName)",
            description: "AI-adapted tracks for changed cry pattern",
            tracks: tracks,
            category: nil,
            targetAgeMonths: babyAge,
            isSystemGenerated: true,
            createdAt: Date(),
            artworkName: nil,
            updatedAt: nil,
            isAutoReplenishing: true,
            minQueueSize: 6,
            generationContext: metadata
        )
    }
}
