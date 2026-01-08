//
//  SmartPlaylistBuilder.swift
//  BabyInCarApp
//
//  Smart playlist generation service for unified player architecture
//  Extracts core logic from SmartEmergencyQueue for reusability
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

    // MARK: - Ambient Playlist Generation

    /// Build ambient playlist for proactive monitoring
    /// Uses ONLY real library tracks (no generated noise)
    func buildAmbientPlaylist(
        babyAge: Int,
        language: String = "en",
        maxTracks: Int = 30
    ) async -> Playlist {
        print("[SmartPlaylistBuilder] 🎵 Building ambient playlist, age \(babyAge)mo")

        // Filter for gentle, age-appropriate library tracks
        let allTracks = contentLibrary.getAllTracks()

        let suitableTracks = allTracks.filter { track in
            // Age appropriate
            guard track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge else {
                return false
            }

            // Only melodic categories (no noise)
            let melodicCategories: Set<AudioCategory> = [
                .classicalMusic, .lullabies, .ambient,
                .instrumental, .childrenSongs, .natureSounds
            ]
            guard melodicCategories.contains(track.category) else {
                return false
            }

            // No generated sounds - library only
            return track.audioSourceType != .generated

        }.sorted { track1, track2 in
            // Sort by calming score
            track1.calmingScore > track2.calmingScore
        }

        // Take top tracks
        let selectedTracks = Array(suitableTracks.prefix(maxTracks))

        let metadata = PlaylistGenerationMetadata(
            babyAge: babyAge,
            cryType: nil,  // No specific cry type for ambient
            language: language,
            allowGenerated: false  // Ambient mode: library-only
        )

        return Playlist(
            name: "Ambient Monitoring",
            description: "Gentle background music for continuous monitoring",
            tracks: selectedTracks,
            category: .ambient,
            targetAgeMonths: babyAge,
            isSystemGenerated: true,
            createdAt: Date(),
            artworkName: nil,
            updatedAt: nil,
            isAutoReplenishing: true,  // Enable infinite playback
            minQueueSize: 5,           // Longer buffer for ambient
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

        if let cryType = context.cryType {
            // Emergency mode replenishment
            return await generateEmergencyTracks(
                cryType: cryType,
                babyAge: context.babyAge,
                language: context.language,
                count: count
            )
        } else {
            // Ambient mode replenishment
            return await generateAmbientTracks(
                babyAge: context.babyAge,
                language: context.language,
                count: count
            )
        }
    }

    // MARK: - Private Helpers

    private func generateEmergencyTracks(
        cryType: CryType,
        babyAge: Int,
        language: String,
        count: Int
    ) async -> [AudioTrack] {
        // Use Spotify-style selection engine
        return await spotifyEngine.selectNextTracks(
            count: count,
            cryType: cryType,
            babyAge: babyAge,
            language: language,
            excludeRecent: true  // Avoid repetition
        )
    }

    private func generateAmbientTracks(
        babyAge: Int,
        language: String,
        count: Int
    ) async -> [AudioTrack] {
        // Filter library tracks for ambient suitability
        let allTracks = contentLibrary.getAllTracks()

        let suitable = allTracks.filter { track in
            track.ageRangeMin <= babyAge &&
            track.ageRangeMax >= babyAge &&
            track.audioSourceType != .generated
        }

        // Randomize for variety
        return Array(suitable.shuffled().prefix(count))
    }
}
