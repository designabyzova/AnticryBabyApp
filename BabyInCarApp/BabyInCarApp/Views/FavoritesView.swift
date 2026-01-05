//
//  FavoritesView.swift
//  BabyInCarApp
//
//  Favorites, playlists, and listening history
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @State private var selectedTab = 0
    @State private var showingCreatePlaylist = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Tab selector (scrolls with content but stays at top)
                    HStack(spacing: 0) {
                        TabButton(title: "Favorites", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }

                        TabButton(title: "Playlists", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }

                        TabButton(title: "Recent", isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Content based on selected tab
                    switch selectedTab {
                    case 0:
                        favoritesContent
                    case 1:
                        playlistsContent
                    default:
                        recentlyPlayedContent
                    }
                }
                // Extra content padding at the bottom for comfortable scrolling.
                // The safeAreaInset in MainTabView handles the tab bar + mini player space.
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
            .background(Color.appBackground)
            .navigationTitle("Favorites")
            .toolbar {
                if selectedTab == 1 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingCreatePlaylist = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistSheet()
        }
    }

    // MARK: - Favorites Content
    private var favoritesContent: some View {
        VStack(spacing: 24) {
            let favoriteTracks = favoritesManager.getFavoriteTracks()
            let favoritePlaylists = favoritesManager.getFavoritePlaylists()

            if favoriteTracks.isEmpty && favoritePlaylists.isEmpty {
                emptyFavoritesView
            } else {
                // Favorite tracks
                if !favoriteTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Favorite Tracks")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appText)

                            Spacer()

                            Text("\(favoriteTracks.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.appTextSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.appPrimary.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)

                        // Play all button
                        HStack(spacing: 12) {
                            Button {
                                let playlist = Playlist(
                                    name: "My Favorites",
                                    tracks: favoriteTracks
                                )
                                audioEngine.play(playlist: playlist)
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play All")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.appPrimary)
                                )
                            }

                            Button {
                                let _ = playlistManager.createPlaylistFromFavorites()
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Save as Playlist")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(Color.appPrimary, lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        // Smart queue: pass all favorites as context for next/previous navigation
                        LazyVStack(spacing: 8) {
                            ForEach(favoriteTracks) { track in
                                TrackRow(
                                    track: track,
                                    contextTracks: favoriteTracks,
                                    contextName: "Favorites"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Favorite playlists
                if !favoritePlaylists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Playlists")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)
                            .padding(.horizontal, 20)

                        LazyVStack(spacing: 12) {
                            ForEach(favoritePlaylists) { playlist in
                                PlaylistRow(playlist: playlist)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Playlists Content
    private var playlistsContent: some View {
        VStack(spacing: 24) {
            if playlistManager.userPlaylists.isEmpty {
                emptyPlaylistsView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Playlists")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)

                        Spacer()

                        Text("\(playlistManager.userPlaylists.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.appPrimary.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 20)

                    LazyVStack(spacing: 12) {
                        ForEach(playlistManager.userPlaylists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist, isUserPlaylist: true)) {
                                UserPlaylistRow(playlist: playlist)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                playlistManager.deletePlaylist(playlistManager.userPlaylists[index])
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Recently Played Content
    private var recentlyPlayedContent: some View {
        VStack(spacing: 16) {
            if playlistManager.recentlyPlayed.isEmpty {
                emptyRecentlyPlayedView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recently Played")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)

                        Spacer()

                        Button {
                            playlistManager.clearRecentlyPlayed()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Play all recent
                    if playlistManager.recentlyPlayed.count > 1 {
                        HStack(spacing: 12) {
                            Button {
                                let playlist = playlistManager.getRecentlyPlayedPlaylist()
                                audioEngine.play(playlist: playlist)
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play All")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.appPrimary)
                                )
                            }

                            Button {
                                let _ = playlistManager.createPlaylistFromRecentlyPlayed()
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Save as Playlist")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(Color.appPrimary, lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Smart queue: pass recently played as context for next/previous navigation
                    LazyVStack(spacing: 8) {
                        ForEach(playlistManager.recentlyPlayed) { track in
                            TrackRow(
                                track: track,
                                contextTracks: playlistManager.recentlyPlayed,
                                contextName: "Recently Played"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Empty Views
    private var emptyFavoritesView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.appTextSecondary.opacity(0.5))

            Text("No favorites yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.appText)

            Text("Tap the heart icon on any track\nto add it to your favorites")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.top, 60)
    }

    private var emptyPlaylistsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.appTextSecondary.opacity(0.5))

            Text("No playlists yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.appText)

            Text("Create a playlist to organize\nyour favorite sounds")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreatePlaylist = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Playlist")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.appPrimary)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 60)
    }

    private var emptyRecentlyPlayedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.appTextSecondary.opacity(0.5))

            Text("No recent plays")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.appText)

            Text("Tracks you listen to will appear here")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.top, 60)
    }
}

// MARK: - User Playlist Row (for Favorites View)
struct UserPlaylistRow: View {
    let playlist: Playlist
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        HStack(spacing: 12) {
            // Playlist artwork
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.forCategory(playlist.dominantCategory ?? .instrumental).opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: playlist.dominantCategory?.icon ?? "music.note.list")
                    .font(.system(size: 26))
                    .foregroundColor(Color.forCategory(playlist.dominantCategory ?? .instrumental))
            }

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(playlist.trackCount) tracks")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)

                    Text("•")
                        .foregroundColor(.appTextSecondary)

                    Text(playlist.formattedTotalDuration)
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }

                if let updatedAt = playlist.updatedAt {
                    Text("Updated \(updatedAt, style: .relative) ago")
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary.opacity(0.7))
                }
            }

            Spacer()

            // Play button
            Button {
                audioEngine.play(playlist: playlist)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.appPrimary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 2)
        )
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)

                Rectangle()
                    .fill(isSelected ? Color.appPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AudioEngine.shared)
}
