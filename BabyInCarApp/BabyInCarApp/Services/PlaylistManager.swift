//
//  PlaylistManager.swift
//  BabyInCarApp
//
//  Service for managing user-created playlists
//

import Foundation
import Combine

@MainActor
class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()

    @Published var userPlaylists: [Playlist] = []
    @Published var recentlyPlayed: [AudioTrack] = []

    private let userDefaults = UserDefaults.standard
    private let playlistsKey = "UserPlaylists"
    private let recentlyPlayedKey = "RecentlyPlayedTracks"
    private let maxRecentlyPlayed = 20

    private init() {
        loadPlaylists()
        loadRecentlyPlayed()
    }

    // MARK: - Persistence

    private func loadPlaylists() {
        if let data = userDefaults.data(forKey: playlistsKey),
           let playlists = try? JSONDecoder().decode([Playlist].self, from: data) {
            userPlaylists = playlists
        }
    }

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(userPlaylists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }

    private func loadRecentlyPlayed() {
        if let data = userDefaults.data(forKey: recentlyPlayedKey),
           let tracks = try? JSONDecoder().decode([AudioTrack].self, from: data) {
            recentlyPlayed = tracks
        }
    }

    private func saveRecentlyPlayed() {
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            userDefaults.set(data, forKey: recentlyPlayedKey)
        }
    }

    // MARK: - Playlist CRUD Operations

    /// Create a new playlist
    func createPlaylist(name: String, description: String = "", tracks: [AudioTrack] = [], category: AudioCategory? = nil) -> Playlist {
        let playlist = Playlist(
            name: name,
            description: description,
            tracks: tracks,
            category: category,
            isSystemGenerated: false,
            createdAt: Date()
        )

        userPlaylists.insert(playlist, at: 0)
        savePlaylists()

        return playlist
    }

    /// Update an existing playlist
    func updatePlaylist(_ playlist: Playlist) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            userPlaylists[index] = playlist
            savePlaylists()
        }
    }

    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        userPlaylists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    /// Delete playlist by ID
    func deletePlaylist(id: UUID) {
        userPlaylists.removeAll { $0.id == id }
        savePlaylists()
    }

    /// Rename a playlist
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            userPlaylists[index].name = newName
            savePlaylists()
        }
    }

    /// Update playlist description
    func updatePlaylistDescription(_ playlist: Playlist, description: String) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            userPlaylists[index].description = description
            savePlaylists()
        }
    }

    // MARK: - Track Management in Playlists

    /// Add a track to a playlist
    func addTrack(_ track: AudioTrack, to playlist: Playlist) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            // Avoid duplicates
            if !userPlaylists[index].tracks.contains(where: { $0.id == track.id }) {
                userPlaylists[index].tracks.append(track)
                savePlaylists()
            }
        }
    }

    /// Add multiple tracks to a playlist
    func addTracks(_ tracks: [AudioTrack], to playlist: Playlist) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            for track in tracks {
                if !userPlaylists[index].tracks.contains(where: { $0.id == track.id }) {
                    userPlaylists[index].tracks.append(track)
                }
            }
            savePlaylists()
        }
    }

    /// Remove a track from a playlist
    func removeTrack(_ track: AudioTrack, from playlist: Playlist) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            userPlaylists[index].tracks.removeAll { $0.id == track.id }
            savePlaylists()
        }
    }

    /// Remove track at specific index
    func removeTrack(at trackIndex: Int, from playlist: Playlist) {
        if let playlistIndex = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            guard trackIndex >= 0 && trackIndex < userPlaylists[playlistIndex].tracks.count else { return }
            userPlaylists[playlistIndex].tracks.remove(at: trackIndex)
            savePlaylists()
        }
    }

    /// Reorder tracks in a playlist
    func moveTrack(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        if let index = userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            userPlaylists[index].tracks.move(fromOffsets: source, toOffset: destination)
            savePlaylists()
        }
    }

    /// Reorder playlists
    func movePlaylists(from source: IndexSet, to destination: Int) {
        userPlaylists.move(fromOffsets: source, toOffset: destination)
        savePlaylists()
    }

    // MARK: - Query Operations

    /// Get a playlist by ID
    func getPlaylist(by id: UUID) -> Playlist? {
        return userPlaylists.first { $0.id == id }
    }

    /// Check if a track is in a playlist
    func isTrackInPlaylist(_ track: AudioTrack, playlist: Playlist) -> Bool {
        return playlist.tracks.contains { $0.id == track.id }
    }

    /// Get all playlists containing a track
    func getPlaylistsContaining(track: AudioTrack) -> [Playlist] {
        return userPlaylists.filter { playlist in
            playlist.tracks.contains { $0.id == track.id }
        }
    }

    /// Search user playlists
    func searchPlaylists(query: String) -> [Playlist] {
        let lowercasedQuery = query.lowercased()
        return userPlaylists.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - Recently Played Management

    /// Add a track to recently played
    func addToRecentlyPlayed(_ track: AudioTrack) {
        // Remove if already exists (to move to front)
        recentlyPlayed.removeAll { $0.id == track.id }

        // Add to front
        recentlyPlayed.insert(track, at: 0)

        // Limit size
        if recentlyPlayed.count > maxRecentlyPlayed {
            recentlyPlayed = Array(recentlyPlayed.prefix(maxRecentlyPlayed))
        }

        saveRecentlyPlayed()
    }

    /// Clear recently played
    func clearRecentlyPlayed() {
        recentlyPlayed.removeAll()
        saveRecentlyPlayed()
    }

    /// Get recently played as a playlist
    func getRecentlyPlayedPlaylist() -> Playlist {
        return Playlist(
            name: "Recently Played",
            description: "Your listening history",
            tracks: recentlyPlayed,
            isSystemGenerated: true
        )
    }

    // MARK: - Duplicate Playlist

    /// Duplicate an existing playlist
    func duplicatePlaylist(_ playlist: Playlist) -> Playlist {
        let newPlaylist = Playlist(
            name: "\(playlist.name) (Copy)",
            description: playlist.description,
            tracks: playlist.tracks,
            category: playlist.category,
            isSystemGenerated: false,
            createdAt: Date()
        )

        userPlaylists.insert(newPlaylist, at: 0)
        savePlaylists()

        return newPlaylist
    }

    // MARK: - Quick Create Playlists

    /// Create a playlist from favorites
    func createPlaylistFromFavorites(name: String = "My Favorites") -> Playlist {
        let favorites = FavoritesManager.shared.getFavoriteTracks()
        return createPlaylist(name: name, description: "Created from favorites", tracks: favorites)
    }

    /// Create a playlist from recently played
    func createPlaylistFromRecentlyPlayed(name: String = "Recently Played Collection") -> Playlist {
        return createPlaylist(name: name, description: "Created from listening history", tracks: recentlyPlayed)
    }
}
