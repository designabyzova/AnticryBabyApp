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
    private let ultraSmartSelector = UltraSmartPlaylistSelector.shared
    private let spotifyEngine = SpotifyQueueEngine.shared
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

        // Use UltraSmartPlaylistSelector for intelligent track selection
        let tracks = await ultraSmartSelector.buildSmartPlaylist(
            cryType: cryType,
            babyAge: babyAge,
            language: language,
            maxTracks: maxTracks
        )

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
            minQueueSize: 3,           // Replenish when <3 tracks remain
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

        // Use Spotify-style selection engine
        return await spotifyEngine.selectNextTracks(
            count: count,
            cryType: cryType,
            babyAge: context.babyAge,
            language: context.language,
            excludeRecent: true  // Avoid repetition
        )
    }
}
