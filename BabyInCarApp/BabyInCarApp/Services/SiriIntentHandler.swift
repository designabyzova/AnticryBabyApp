//
//  SiriIntentHandler.swift
//  BabyInCarApp
//
//  Handles Siri Media Intents for voice control.
//
//  Supported Commands (ALWAYS include "in Lulla" to avoid Spotify/other app conflicts):
//    - "Hey Siri, play lullabies in Lulla"
//    - "Hey Siri, play classical in Lulla"
//    - "Hey Siri, calm baby in Lulla"
//    - "Hey Siri, find Mozart in Lulla"
//    - "Hey Siri, add to favorites in Lulla"
//    - "Hey Siri, pause Lulla" (only works when Lulla is the Now Playing app)
//    - "Hey Siri, resume Lulla" (only works when Lulla is the Now Playing app)
//    - "Hey Siri, next in Lulla" / "Hey Siri, skip in Lulla"
//
//  IMPORTANT: Pause/Resume/Skip go to whichever app is currently "Now Playing".
//  If Spotify was playing last, "Hey Siri, pause" will pause Spotify, not Lulla.
//  Users should say "pause Lulla" or start playback in Lulla first.
//

import Foundation
import Intents
import MediaPlayer

/// Handles Siri Media Intents for voice-controlled playback
/// Implements: Play, Search, Add to Favorites
/// NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter, not here
@MainActor
class SiriIntentHandler: NSObject,
    INPlayMediaIntentHandling,
    INSearchForMediaIntentHandling,
    INAddMediaIntentHandling {

    static let shared = SiriIntentHandler()

    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared

    // Emergency phrases that trigger calming playback
    private let emergencyPhrases = ["emergency", "calm baby", "baby crying", "soothe",
                                    "help baby", "cry again", "crying again", "urgent"]

    // MARK: - INPlayMediaIntentHandling

    /// Handle the play media intent from Siri
    nonisolated func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
        print("🎤 Siri: Received INPlayMediaIntent")

        // Parse what the user wants to play
        let mediaItems = intent.mediaItems ?? []
        let mediaSearch = intent.mediaSearch

        // Debug: log what Siri understood
        print("🎤 Siri mediaItems: \(mediaItems.map { $0.title ?? "nil" })")
        print("🎤 Siri mediaSearch: \(mediaSearch?.mediaName ?? "nil")")

        // Check for emergency phrases first
        let searchText = (mediaSearch?.mediaName ?? "").lowercased()
        let isEmergency = await MainActor.run {
            emergencyPhrases.contains(where: { searchText.contains($0) })
        }

        if isEmergency {
            print("🎤 Siri: Emergency mode detected!")
            await MainActor.run {
                triggerEmergencyMode()
            }
            return INPlayMediaIntentResponse(code: .success, userActivity: nil)
        }

        // Determine what to play based on Siri's input
        let category = await MainActor.run { parseCategory(from: mediaSearch) }

        await MainActor.run {
            if let category = category {
                // Play specific category
                playCategory(category)
            } else if let searchTerm = mediaSearch?.mediaName {
                // Search for specific content
                playSearch(searchTerm)
            } else {
                // Default: play recommended/general content
                playDefault()
            }
        }

        return INPlayMediaIntentResponse(code: .success, userActivity: nil)
    }

    /// Resolve media items - tell Siri what content is available
    nonisolated func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
        // If no specific item requested, provide suggestions
        guard let mediaSearch = intent.mediaSearch,
              let searchTerm = mediaSearch.mediaName else {
            // Success with no specific item - will play default
            return [.success(with: INMediaItem(
                identifier: "default",
                title: "Lulla Music",
                type: .music,
                artwork: nil
            ))]
        }

        // Try to match the search term to a category
        let category = await MainActor.run { parseCategory(from: mediaSearch) }

        if let category = category {
            return [.success(with: INMediaItem(
                identifier: category.rawValue,
                title: category.rawValue,
                type: .musicStation,
                artwork: nil
            ))]
        }

        // Search for matching tracks
        let matches = await MainActor.run {
            contentLibrary.allTracks.filter { track in
                track.title.lowercased().contains(searchTerm.lowercased()) ||
                track.artist.lowercased().contains(searchTerm.lowercased())
            }
        }

        if !matches.isEmpty {
            return matches.prefix(5).map { track in
                .success(with: INMediaItem(
                    identifier: track.id.uuidString,
                    title: track.title,
                    type: .song,
                    artwork: nil,
                    artist: track.artist
                ))
            }
        }

        // No matches found, but still allow playback
        return [.success(with: INMediaItem(
            identifier: "search:\(searchTerm)",
            title: searchTerm,
            type: .music,
            artwork: nil
        ))]
    }

    // MARK: - INSearchForMediaIntentHandling

    /// Handle search intent from Siri - "Hey Siri, find Mozart in Lulla"
    nonisolated func handle(intent: INSearchForMediaIntent) async -> INSearchForMediaIntentResponse {
        print("🎤 Siri: Received INSearchForMediaIntent")

        guard let searchTerm = intent.mediaSearch?.mediaName else {
            return INSearchForMediaIntentResponse(code: .failure, userActivity: nil)
        }

        print("🎤 Siri: Searching for '\(searchTerm)'")

        // Search for matching tracks
        let results = await MainActor.run {
            contentLibrary.allTracks.filter { track in
                track.title.lowercased().contains(searchTerm.lowercased()) ||
                track.artist.lowercased().contains(searchTerm.lowercased()) ||
                track.category.rawValue.lowercased().contains(searchTerm.lowercased())
            }.prefix(10).map { track in
                INMediaItem(
                    identifier: track.id.uuidString,
                    title: track.title,
                    type: .song,
                    artwork: nil,
                    artist: track.artist
                )
            }
        }

        let response = INSearchForMediaIntentResponse(code: .success, userActivity: nil)
        response.mediaItems = Array(results)

        print("🎤 Siri: Found \(results.count) results for '\(searchTerm)'")
        return response
    }

    // MARK: - INAddMediaIntentHandling

    /// Handle add to favorites intent from Siri - "Hey Siri, add to favorites in Lulla"
    nonisolated func handle(intent: INAddMediaIntent) async -> INAddMediaIntentResponse {
        print("🎤 Siri: Received INAddMediaIntent")

        // Get the current playing track if no specific media item provided
        let trackToFavorite: AudioTrack? = await MainActor.run {
            if let mediaItem = intent.mediaItems?.first,
               let trackIdString = mediaItem.identifier,
               let trackId = UUID(uuidString: trackIdString) {
                // Find the specified track
                return contentLibrary.allTracks.first { $0.id == trackId }
            } else {
                // Use currently playing track
                return audioEngine.currentTrack
            }
        }

        guard let track = trackToFavorite else {
            print("🎤 Siri: No track to add to favorites")
            return INAddMediaIntentResponse(code: .failure, userActivity: nil)
        }

        // Add to favorites (toggleFavorite will add if not already favorited)
        await MainActor.run {
            if !FavoritesManager.shared.isFavorite(track: track) {
                FavoritesManager.shared.toggleFavorite(track: track)
            }
            print("🎤 Siri: Added '\(track.title)' to favorites")
        }

        return INAddMediaIntentResponse(code: .success, userActivity: nil)
    }

    /// Resolve media destination for add intent
    nonisolated func resolveMediaDestination(for intent: INAddMediaIntent) async -> INAddMediaMediaDestinationResolutionResult {
        // Always add to favorites
        return .success(with: INMediaDestination.library)
    }

    // NOTE: Pause, Resume, and Skip commands are handled by MPRemoteCommandCenter
    // in NowPlayingService.swift. When Siri receives "pause", "resume", "next", or
    // "previous" commands, iOS routes them to the Now Playing audio app's remote
    // command handlers. This provides seamless integration with Control Center,
    // Lock Screen, and CarPlay controls.

    // MARK: - Emergency Mode

    /// Trigger calming playback for baby
    private func triggerEmergencyMode() {
        print("🎤 Siri: Triggering calming playback")

        Task { @MainActor in
            // Play calming classical music
            let tracks = contentLibrary.getTracks(for: .classicalMusic)
            let calmingTracks = tracks.sorted { $0.calmingScore > $1.calmingScore }

            if !calmingTracks.isEmpty {
                let playlist = Playlist(
                    id: UUID(),
                    name: "Siri: Calming Music",
                    tracks: Array(calmingTracks.prefix(20)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
                print("🎤 Siri: Calming playlist started")
            } else {
                playDefault()
            }
        }
    }

    // MARK: - Playback Actions

    private func playCategory(_ category: AudioCategory) {
        print("🎤 Siri: Playing category \(category.rawValue)")

        let tracks = contentLibrary.getTracks(for: category)
        guard !tracks.isEmpty else {
            print("🎤 Siri: No tracks for category \(category.rawValue)")
            playDefault()
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: \(category.rawValue)",
            tracks: Array(tracks.shuffled().prefix(20)),
            createdAt: Date()
        )
        audioEngine.play(playlist: playlist)
    }

    private func playSearch(_ searchTerm: String) {
        print("🎤 Siri: Searching for '\(searchTerm)'")

        let matches = contentLibrary.allTracks.filter { track in
            track.title.lowercased().contains(searchTerm.lowercased()) ||
            track.artist.lowercased().contains(searchTerm.lowercased())
        }

        if !matches.isEmpty {
            let playlist = Playlist(
                id: UUID(),
                name: "Siri: \(searchTerm)",
                tracks: Array(matches.prefix(20)),
                createdAt: Date()
            )
            audioEngine.play(playlist: playlist)
        } else {
            // Fallback to default
            playDefault()
        }
    }

    private func playDefault() {
        print("🎤 Siri: Playing default content")

        // Get high calming score tracks
        let tracks = contentLibrary.allTracks
            .sorted { $0.calmingScore > $1.calmingScore }

        guard !tracks.isEmpty else {
            // Ultimate fallback: generated emergency track
            audioEngine.play(track: AudioTrack.defaultEmergencyTrack())
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: Lulla Music",
            tracks: Array(tracks.prefix(20)),
            createdAt: Date()
        )
        audioEngine.play(playlist: playlist)
    }

    // MARK: - Category Parsing

    private func parseCategory(from mediaSearch: INMediaSearch?) -> AudioCategory? {
        guard let search = mediaSearch else { return nil }

        // Check media name
        let searchText = (search.mediaName ?? "").lowercased()

        // Map Siri input to categories
        let categoryMappings: [(keywords: [String], category: AudioCategory)] = [
            (["lullaby", "lullabies", "bedtime song"], .lullabies),
            (["classical", "mozart", "beethoven", "bach", "piano"], .classicalMusic),
            (["fairy tale", "story", "stories", "bedtime story"], .fairyTales),
            (["nature", "ocean", "waves", "forest", "birds"], .natureSounds),
            (["ambient", "womb", "heartbeat"], .ambient),
            (["instrumental", "guitar", "ukulele"], .instrumental),
            (["children", "kids", "nursery", "nursery rhyme"], .childrenSongs),
        ]

        for (keywords, category) in categoryMappings {
            if keywords.contains(where: { searchText.contains($0) }) {
                return category
            }
        }

        // Check media type from Siri
        let mediaType = search.mediaType
        switch mediaType {
        case .music, .song:
            // Generic music - could be any category
            break
        case .station, .playlist:
            // User wants a playlist/station
            break
        default:
            break
        }

        return nil
    }

    // MARK: - Siri Donation

    /// Donate a playback activity to Siri for better suggestions
    func donatePlaybackActivity(track: AudioTrack) {
        let mediaItem = INMediaItem(
            identifier: track.id.uuidString,
            title: track.title,
            type: .song,
            artwork: nil,
            artist: track.artist
        )

        let intent = INPlayMediaIntent(
            mediaItems: [mediaItem],
            mediaContainer: nil,
            playShuffled: false,
            playbackRepeatMode: .none,
            resumePlayback: false,
            playbackQueueLocation: .now,
            playbackSpeed: 1.0,
            mediaSearch: nil
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("🎤 Siri donation error: \(error)")
            }
        }
    }

    /// Request Siri authorization
    /// NOTE: This should NOT be called on app launch due to MainActor isolation issues.
    /// iOS automatically prompts for Siri authorization when the user first invokes a Siri intent.
    nonisolated func requestSiriAuthorization() {
        // Run on main thread to avoid threading issues with INPreferences
        DispatchQueue.main.async {
            INPreferences.requestSiriAuthorization { status in
                switch status {
                case .authorized:
                    print("🎤 Siri: Authorized")
                case .denied:
                    print("🎤 Siri: Denied")
                case .restricted:
                    print("🎤 Siri: Restricted")
                case .notDetermined:
                    print("🎤 Siri: Not determined")
                @unknown default:
                    break
                }
            }
        }
    }
}

