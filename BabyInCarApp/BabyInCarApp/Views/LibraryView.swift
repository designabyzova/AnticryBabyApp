//
//  LibraryView.swift
//  BabyInCarApp
//
//  Library view with all content organized by category
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var contentLibrary = ContentLibraryService.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @State private var searchText = ""
    @State private var selectedCategory: AudioCategory?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Search bar
                    searchBar

                    // Category filter
                    categoryFilter

                    // Content
                    if searchText.isEmpty {
                        // Show playlists and tracks by category
                        if let category = selectedCategory {
                            categoryContent(category)
                        } else {
                            allPlaylistsContent
                        }
                    } else {
                        searchResults
                    }
                }
                .padding(.bottom, bottomPadding + 20)
            }
            .scrollIndicators(.visible)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appTextSecondary)

            TextField("Search sounds, stories, music...", text: $searchText)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    isSearchFocused = false
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All button
                FilterChip(
                    label: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(AudioCategory.allCases) { category in
                    FilterChip(
                        label: category.rawValue,
                        icon: category.icon,
                        color: Color.forCategory(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - All Playlists Content
    private var allPlaylistsContent: some View {
        VStack(spacing: 24) {
            // User Playlists Section
            UserPlaylistsSection()

            // Category sections
            ForEach(AudioCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 12) {
                    // Section header
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color.forCategory(category))

                        Text(category.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)

                        Spacer()

                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            Text("See All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Horizontal scroll of tracks
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(contentLibrary.getTracks(for: category).prefix(5)) { track in
                                TrackCard(track: track)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Category Content
    private func categoryContent(_ category: AudioCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color.forCategory(category))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.appText)

                    Text(category.description)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Tracks list
            LazyVStack(spacing: 8) {
                ForEach(contentLibrary.getTracks(for: category)) { track in
                    TrackRow(track: track)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Search Results
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            let tracks = contentLibrary.searchTracks(query: searchText)
            let playlists = contentLibrary.searchPlaylists(query: searchText)

            if tracks.isEmpty && playlists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.appTextSecondary)

                    Text("No results found")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.appText)

                    Text("Try a different search term")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                if !tracks.isEmpty {
                    Text("Tracks (\(tracks.count))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 20)

                    LazyVStack(spacing: 8) {
                        ForEach(tracks) { track in
                            TrackRow(track: track)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !playlists.isEmpty {
                    Text("Playlists (\(playlists.count))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    LazyVStack(spacing: 12) {
                        ForEach(playlists) { playlist in
                            PlaylistRow(playlist: playlist)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    var icon: String? = nil
    var color: Color = .appPrimary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }

                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.1))
            )
        }
    }
}

// MARK: - Track Card (Horizontal)
struct TrackCard: View {
    let track: AudioTrack
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        Button {
            audioEngine.play(track: track)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.forCategory(track.category).opacity(0.15))
                            .frame(width: 120, height: 120)

                        Image(systemName: track.category.icon)
                            .font(.system(size: 36))
                            .foregroundColor(Color.forCategory(track.category))

                        // Duration badge
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(track.formattedDuration)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.5))
                                    )
                                    .padding(8)
                            }
                        }
                    }

                    // Favorite button overlay
                    Button {
                        favoritesManager.toggleFavorite(track: track)
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(track: track) ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(favoritesManager.isFavorite(track: track) ? .appSecondary : .white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appText)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 120)
        }
    }
}

// MARK: - Track Row (List)
struct TrackRow: View {
    let track: AudioTrack
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var showingAddToPlaylist = false

    var isPlaying: Bool {
        audioEngine.currentTrack?.id == track.id && audioEngine.playbackState.isPlaying
    }

    var body: some View {
        Button {
            audioEngine.play(track: track)
        } label: {
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.forCategory(track.category).opacity(0.15))
                        .frame(width: 50, height: 50)

                    if isPlaying {
                        // Equalizer animation
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.forCategory(track.category))
                                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                            }
                        }
                    } else {
                        Image(systemName: track.category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(Color.forCategory(track.category))
                    }
                }

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isPlaying ? .appPrimary : .appText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(track.artist)
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)

                        Text("•")
                            .foregroundColor(.appTextSecondary)

                        Text(track.formattedDuration)
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)

                        if let language = track.language {
                            Text(language.flag)
                                .font(.system(size: 13))
                        }
                    }
                }

                Spacer()

                // Favorite button
                Button {
                    favoritesManager.toggleFavorite(track: track)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(track: track) ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(favoritesManager.isFavorite(track: track) ? .appSecondary : .appTextSecondary)
                }

                // Play button
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.appPrimary.opacity(0.1))
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPlaying ? Color.appPrimary.opacity(0.05) : Color.white)
                    .shadow(color: .black.opacity(0.03), radius: 2)
            )
        }
        .contextMenu {
            Button {
                audioEngine.play(track: track)
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                showingAddToPlaylist = true
            } label: {
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }

            Button {
                favoritesManager.toggleFavorite(track: track)
            } label: {
                if favoritesManager.isFavorite(track: track) {
                    Label("Remove from Favorites", systemImage: "heart.slash")
                } else {
                    Label("Add to Favorites", systemImage: "heart")
                }
            }
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            AddToPlaylistSheet(track: track)
        }
    }
}

// MARK: - Playlist Row
struct PlaylistRow: View {
    let playlist: Playlist
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        Button {
            audioEngine.play(playlist: playlist)
        } label: {
            HStack(spacing: 12) {
                // Playlist artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.forCategory(playlist.category ?? .whiteNoise).opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(Color.forCategory(playlist.category ?? .whiteNoise))
                }

                // Playlist info
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text("\(playlist.tracks.count) tracks • \(playlist.formattedTotalDuration)")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                // Favorite button
                Button {
                    favoritesManager.toggleFavorite(playlist: playlist)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(playlist: playlist) ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(favoritesManager.isFavorite(playlist: playlist) ? .appSecondary : .appTextSecondary)
                }
                .buttonStyle(.plain)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.appPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.03), radius: 2)
            )
        }
    }
}

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let category: AudioCategory
    @StateObject private var contentLibrary = ContentLibraryService.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.forCategory(category).opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: category.icon)
                            .font(.system(size: 44))
                            .foregroundColor(Color.forCategory(category))
                    }

                    Text(category.rawValue)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appText)

                    Text(category.description)
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Play all button
                    Button {
                        let tracks = contentLibrary.getTracks(for: category)
                        let playlist = Playlist(
                            name: "All \(category.rawValue)",
                            tracks: tracks,
                            category: category
                        )
                        audioEngine.play(playlist: playlist)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play All")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.forCategory(category))
                        )
                    }
                }
                .padding(.vertical, 24)

                // Tracks list
                LazyVStack(spacing: 8) {
                    ForEach(contentLibrary.getTracks(for: category)) { track in
                        TrackRow(track: track)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, bottomPadding + 20)
        }
        .scrollIndicators(.visible)
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LibraryView()
        .environmentObject(AudioEngine.shared)
}
