//
//  LibraryView.swift
//  BabyInCarApp
//
//  Library view with all content organized by category
//

import SwiftUI

struct LibraryView: View {
    // FIX: Use @ObservedObject for singletons - prevents state recreation on orientation change
    @ObservedObject private var contentLibrary = ContentLibraryService.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var appState: AppState
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @State private var searchText = ""
    @State private var selectedCategory: AudioCategory?
    @State private var showAdvancedSearch = false
    @State private var featuredTaxonomies: [FeaturedTaxonomy] = []
    @State private var showSoftPaywall = false
    @State private var softPaywallTrack: AudioTrack?
    @FocusState private var isSearchFocused: Bool

    /// Categories that have language-specific content and should be filtered by user's language preferences
    private let languageFilteredCategories: Set<AudioCategory> = [.fairyTales, .childrenSongs, .podcasts]

    /// Get tracks filtered by language preferences when applicable
    private func getFilteredTracks(for category: AudioCategory) -> [AudioTrack] {
        let allTracks = contentLibrary.getTracks(for: category)

        // Only filter by language for categories that have language-specific content
        guard languageFilteredCategories.contains(category),
              !appState.selectedLanguages.isEmpty else {
            return allTracks
        }

        return allTracks.filter { track in
            // If track has no language (instrumental, etc.), include it
            guard let trackLanguage = track.language else { return true }
            // Otherwise, include only if it matches selected languages
            return appState.selectedLanguages.contains(trackLanguage)
        }
    }

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
                // Extra content padding at the bottom for comfortable scrolling.
                // The safeAreaInset in MainTabView handles the tab bar + mini player space.
                // This adds breathing room to prevent the mini player bar from hiding content.
                .padding(.bottom, 100)
            }
            .scrollIndicators(.visible)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdvancedSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17))
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                }
            }
            .sheet(isPresented: $showAdvancedSearch) {
                SearchView()
                    .environmentObject(audioEngine)
            }
            .sheet(isPresented: $showSoftPaywall) {
                if let track = softPaywallTrack {
                    SoftPaywallSheet(
                        track: track,
                        onUpgrade: {
                            // Navigate to subscription view
                        },
                        onDismiss: {
                            gatekeeper.recordPromptDismissed(for: track)
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .task {
                await loadFeaturedTaxonomies()
            }
        }
    }

    // MARK: - Handle Track Tap (with freemium logic)
    /// Creates a tap handler that respects freemium gating and uses smart queue
    private func createTrackTapHandler(contextTracks: [AudioTrack], contextName: String) -> (AudioTrack) -> Void {
        return { track in
            if gatekeeper.canPlayTrack(track) {
                // User can play - go ahead with smart queue context
                audioEngine.play(track: track, fromTracks: contextTracks, contextName: contextName)
            } else if gatekeeper.shouldShowUpgradePrompt(for: track) {
                // Show soft paywall
                softPaywallTrack = track
                gatekeeper.recordPromptShown(for: track)
                showSoftPaywall = true
            } else {
                // Rate limited - just show a brief message or do nothing
            }
        }
    }

    // Legacy handler for backward compatibility
    private func handleTrackTap(_ track: AudioTrack) {
        if gatekeeper.canPlayTrack(track) {
            // User can play - go ahead
            audioEngine.play(track: track)
        } else if gatekeeper.shouldShowUpgradePrompt(for: track) {
            // Show soft paywall
            softPaywallTrack = track
            gatekeeper.recordPromptShown(for: track)
            showSoftPaywall = true
        } else {
            // Rate limited - just show a brief message or do nothing
        }
    }

    // MARK: - Load Featured Taxonomies
    private func loadFeaturedTaxonomies() async {
        do {
            let response = try await APIClient.shared.getSearchSuggestions()
            featuredTaxonomies = response.suggestions.featuredTaxonomies
        } catch {
            print("Failed to load taxonomies: \(error)")
        }
    }

    // MARK: - Taxonomy Browse Section
    private var taxonomyBrowseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.appPrimary)

                Text("Discover")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)

                Spacer()

                Button {
                    showAdvancedSearch = true
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 20)

            // Group by taxonomy type
            let grouped = Dictionary(grouping: featuredTaxonomies) { $0.taxonomyType }

            // Origins (Russian, German, English tales)
            if let origins = grouped["origin"], !origins.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Origin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(origins) { item in
                                NavigationLink {
                                    TaxonomyBrowseView(
                                        type: .origin,
                                        value: item.taxonomyValue,
                                        displayName: item.displayName
                                    )
                                    .environmentObject(audioEngine)
                                } label: {
                                    TaxonomyBrowseChip(
                                        name: item.displayName,
                                        icon: item.icon ?? "globe",
                                        color: item.color,
                                        count: item.trackCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Themes (Animals, Magic, Bedtime)
            if let themes = grouped["theme"], !themes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Theme")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(themes) { item in
                                NavigationLink {
                                    TaxonomyBrowseView(
                                        type: .theme,
                                        value: item.taxonomyValue,
                                        displayName: item.displayName
                                    )
                                    .environmentObject(audioEngine)
                                } label: {
                                    TaxonomyBrowseChip(
                                        name: item.displayName,
                                        icon: item.icon ?? "tag",
                                        color: item.color,
                                        count: item.trackCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Authors (Brothers Grimm, Afanasyev)
            if let authors = grouped["author"], !authors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Author")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(authors) { item in
                                NavigationLink {
                                    TaxonomyBrowseView(
                                        type: .author,
                                        value: item.taxonomyValue,
                                        displayName: item.displayName
                                    )
                                    .environmentObject(audioEngine)
                                } label: {
                                    TaxonomyBrowseChip(
                                        name: item.displayName,
                                        icon: item.icon ?? "person",
                                        color: item.color,
                                        count: item.trackCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
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
            // Free content notice for non-premium users
            if !gatekeeper.hasPremiumAccess {
                FreeContentNotice(
                    freeTrackCount: contentLibrary.getTotalFreeTrackCount(),
                    refreshDate: contentLibrary.getNextFreeTrackRotationDate()
                )
                .padding(.horizontal, 20)
            }

            // Browse by Taxonomy section
            if !featuredTaxonomies.isEmpty {
                taxonomyBrowseSection
            }

            // User Playlists Section
            UserPlaylistsSection()

            // Category sections
            ForEach(AudioCategory.allCases) { category in
                let categoryTracks = getFilteredTracks(for: category)
                let tapHandler = createTrackTapHandler(contextTracks: categoryTracks, contextName: category.rawValue)
                VStack(alignment: .leading, spacing: 12) {
                    // Section header with free track count
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color.forCategory(category))

                        Text(category.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)

                        // Show free track count for non-premium users
                        if !gatekeeper.hasPremiumAccess {
                            let freeCount = contentLibrary.getFreeTrackCount(for: category)
                            Text("\(freeCount) free")
                                .font(.system(size: 12))
                                .foregroundColor(.appSuccess)
                        }

                        Spacer()

                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            Text("See All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Horizontal scroll of tracks (filtered by language for applicable categories)
                    // Smart queue: pass all category tracks as context for next/previous navigation
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categoryTracks.prefix(5)) { track in
                                TrackCard(
                                    track: track,
                                    onTap: tapHandler,
                                    contextTracks: categoryTracks,
                                    contextName: category.rawValue
                                )
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
        let categoryTracks = getFilteredTracks(for: category)
        return VStack(alignment: .leading, spacing: 16) {
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

            // Tracks list (filtered by language for applicable categories)
            // Smart queue: pass all category tracks as context for next/previous navigation
            LazyVStack(spacing: 8) {
                ForEach(categoryTracks) { track in
                    TrackRow(
                        track: track,
                        contextTracks: categoryTracks,
                        contextName: category.rawValue
                    )
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
    var onTap: ((AudioTrack) -> Void)?
    /// Context tracks for smart queue - when set, enables next/previous navigation
    var contextTracks: [AudioTrack]?
    var contextName: String?
    @EnvironmentObject var audioEngine: AudioEngine
    // FIX: Use @ObservedObject for singletons - @StateObject causes crash when views recreate
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared

    var body: some View {
        Button {
            if let onTap = onTap {
                onTap(track)
            } else if let tracks = contextTracks, !tracks.isEmpty {
                // Smart queue: play with context so next/previous work
                audioEngine.play(track: track, fromTracks: tracks, contextName: contextName ?? "Queue")
            } else {
                audioEngine.play(track: track)
            }
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

                        // Lock overlay for premium tracks
                        if !gatekeeper.canPlayTrack(track) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                        }

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

                    // Premium/Free badge at top-left
                    VStack {
                        HStack {
                            PremiumBadge(
                                accessType: gatekeeper.accessType(for: track),
                                size: .small
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)

                    // Favorite button overlay at top-right
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
    var onTap: ((AudioTrack) -> Void)?
    /// Context tracks for smart queue - when set, enables next/previous navigation
    var contextTracks: [AudioTrack]?
    var contextName: String?
    @EnvironmentObject var audioEngine: AudioEngine
    // FIX: Use @ObservedObject for singletons - @StateObject causes crash when views recreate
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared
    @State private var showingAddToPlaylist = false
    @State private var isToggling = false  // Debounce rapid taps

    var isPlaying: Bool {
        audioEngine.currentTrack?.id == track.id && audioEngine.playbackState.isPlaying
    }

    var isLocked: Bool {
        !gatekeeper.canPlayTrack(track)
    }

    var body: some View {
        Button {
            if let onTap = onTap {
                onTap(track)
            } else if let tracks = contextTracks, !tracks.isEmpty {
                // Smart queue: play with context so next/previous work
                audioEngine.play(track: track, fromTracks: tracks, contextName: contextName ?? "Queue")
            } else {
                audioEngine.play(track: track)
            }
        } label: {
            HStack(spacing: 12) {
                // Category icon with lock overlay
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
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                    } else {
                        Image(systemName: track.category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(Color.forCategory(track.category))
                    }
                }

                // Track info with badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isPlaying ? .appPrimary : (isLocked ? .appTextSecondary : .appText))
                            .lineLimit(1)

                        PremiumBadge(
                            accessType: gatekeeper.accessType(for: track),
                            size: .small
                        )
                    }

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
                .buttonStyle(BorderlessButtonStyle())

                // Play/Pause button with toggle logic
                Button {
                    guard !isToggling && !isLocked else { return }
                    isToggling = true

                    if isPlaying {
                        audioEngine.pause()
                    } else if let tracks = contextTracks, !tracks.isEmpty {
                        // Smart queue: play with context so next/previous work
                        audioEngine.play(track: track, fromTracks: tracks, contextName: contextName ?? "Queue")
                    } else {
                        audioEngine.play(track: track)
                    }

                    // Debounce: prevent rapid taps
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isToggling = false
                    }
                } label: {
                    Image(systemName: isLocked ? "lock.fill" : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: 14))
                        .foregroundColor(isLocked ? .appTextSecondary : .appPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isLocked ? Color.appTextSecondary.opacity(0.1) : Color.appPrimary.opacity(0.1))
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isToggling)
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
                if let tracks = contextTracks, !tracks.isEmpty {
                    audioEngine.play(track: track, fromTracks: tracks, contextName: contextName ?? "Queue")
                } else {
                    audioEngine.play(track: track)
                }
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                audioEngine.playNext(track)
            } label: {
                Label("Play Next", systemImage: "text.insert")
            }

            Button {
                audioEngine.addToQueue(track)
            } label: {
                Label("Add to Queue", systemImage: "text.append")
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
    // FIX: Use @ObservedObject for singletons - @StateObject causes crash when views recreate
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        Button {
            audioEngine.play(playlist: playlist)
        } label: {
            HStack(spacing: 12) {
                // Playlist artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.forCategory(playlist.category ?? .instrumental).opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(Color.forCategory(playlist.category ?? .instrumental))
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

// MARK: - Taxonomy Browse Chip
struct TaxonomyBrowseChip: View {
    let name: String
    let icon: String
    let color: String?
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Text("\(count) tracks")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(chipColor)
        )
    }

    private var chipColor: Color {
        if let hex = color {
            return Color(hex: hex)
        }
        return .appPrimary
    }
}

#Preview {
    LibraryView()
        .environmentObject(AudioEngine.shared)
        .environmentObject(AppState())
}
