//
//  FavoritesView.swift
//  BabyInCarApp
//
//  Favorites and listening history
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    TabButton(title: "Favorites", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }

                    TabButton(title: "Recently Played", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Content
                ScrollView {
                    if selectedTab == 0 {
                        favoritesContent
                    } else {
                        recentlyPlayedContent
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Favorites")
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
                        Button {
                            let playlist = Playlist(
                                name: "My Favorites",
                                tracks: favoriteTracks
                            )
                            audioEngine.play(playlist: playlist)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play All Favorites")
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
                        .padding(.horizontal, 20)

                        LazyVStack(spacing: 8) {
                            ForEach(favoriteTracks) { track in
                                TrackRow(track: track)
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
        .padding(.bottom, 100)
    }

    // MARK: - Recently Played Content
    private var recentlyPlayedContent: some View {
        VStack(spacing: 16) {
            // This would be populated from listening history
            emptyRecentlyPlayedView
        }
        .padding(.vertical, 20)
        .padding(.bottom, 100)
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
