//
//  HomeView.swift
//  BabyInCarApp
//
//  Premium home dashboard with elegant design and animations
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    // FIX: Use @ObservedObject for singletons - prevents recreation on orientation change
    // @StateObject creates new wrapper on view rebuild, @ObservedObject reuses existing singleton
    @ObservedObject private var aiEngine = AIRecommendationEngine.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var effectivenessManager = EffectivenessManager.shared
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var quickPickPlaylists: [Playlist] = []
    @State private var isLoading = true
    @State private var showingSubscription = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignTokens.spacingL) {
                    // Hero header with time-aware greeting
                    // Spacer for safe area is handled by contentMargins
                    heroHeader

                    // Favorites Section (if user has favorites)
                    if !favoritesManager.favoriteTracks.isEmpty {
                        favoritesSection
                    }

                    // What Works Section (if user has effectiveness data)
                    if effectivenessManager.hasEffectivenessData {
                        WhatWorksSection()
                            .environmentObject(appState)
                            .environmentObject(audioEngine)
                    }

                    // Quick Picks
                    quickPicksSection

                    // Categories
                    categoriesSection
                }
                // Extra content padding at the bottom for comfortable scrolling.
                // The safeAreaInset in MainTabView handles the tab bar + mini player space.
                // This adds breathing room to prevent the mini player bar from hiding content.
                .padding(.bottom, 100)
            }
            .scrollIndicators(.visible)
            .scrollContentBackground(.hidden)
            .background(
                // Subtle gradient background
                LinearGradient(
                    colors: [Color.appBackground, Color.appWarmCream.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .id(languageManager.refreshID) // Force refresh when language changes
        .task {
            await loadQuickPicks()
        }
        .onChange(of: appState.selectedLanguages) { _ in
            // Reload quick picks when language selection changes
            Task {
                await loadQuickPicks()
            }
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - Hero Header with Time-Aware Greeting
    private var heroHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(timeBasedGreeting)
                        .font(.appTitle)
                        .foregroundColor(.appText)

                    if let baby = appState.currentBaby {
                        HStack(spacing: DesignTokens.spacingS) {
                            Text(baby.displayName)
                                .font(.appBodyMedium)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appPrimary, .appSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("•")
                                .foregroundColor(.appTextTertiary)

                            Text(baby.formattedAge)
                                .font(.appBody)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }

                Spacer()

                // Animated settings button
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color.appCardBackground)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Time indicator pill
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: timeIcon)
                    .font(.system(size: 12))
                Text(timeOfDayText)
                    .font(.appCaption)
            }
            .foregroundColor(.appTextSecondary)
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.vertical, DesignTokens.spacingXS)
            .background(
                Capsule()
                    .fill(Color.appPrimary.opacity(0.1))
            )
            .padding(.top, DesignTokens.spacingS)
        }
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return languageManager.localizedString("home.greeting.morning")
        case 12..<17: return languageManager.localizedString("home.greeting.afternoon")
        case 17..<21: return languageManager.localizedString("home.greeting.evening")
        default: return languageManager.localizedString("home.greeting.night")
        }
    }

    private var timeIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var timeOfDayText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return languageManager.localizedString("home.morningTime")
        case 12..<17: return languageManager.localizedString("home.afternoonNapTime")
        case 17..<21: return languageManager.localizedString("home.eveningWindDown")
        default: return languageManager.localizedString("home.bedtimeMode")
        }
    }

    // MARK: - Favorites Section
    private var favoritesSection: some View {
        let favoriteTracks = favoritesManager.getFavoriteTracks()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.appSecondary)

                Text(languageManager.localizedString("home.yourFavorites"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)

                Spacer()

                NavigationLink(destination: FavoritesView()) {
                    Text(languageManager.localizedString("home.seeAll"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 20)

            // Smart queue: pass all favorites as context so next/previous work
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoriteTracks.prefix(6)) { track in
                        FavoriteTrackCard(track: track, contextTracks: favoriteTracks)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Quick Picks Section
    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let baby = appState.currentBaby {
                    Text(String(format: languageManager.localizedString("home.quickPicksFor"), baby.formattedAge))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                } else {
                    Text(languageManager.localizedString("home.quickPicks"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(quickPickPlaylists.prefix(6)) { playlist in
                        QuickPickCard(playlist: playlist) {
                            audioEngine.play(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(languageManager.localizedString("home.categories"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AudioCategory.allCases) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryCard(category: category)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Load Data
    private func loadQuickPicks() async {
        isLoading = true
        if let baby = appState.currentBaby {
            // Pass selected languages to filter content by user's language preferences
            let languages = appState.selectedLanguages.isEmpty ? nil : appState.selectedLanguages
            quickPickPlaylists = await aiEngine.getQuickPicks(for: baby, languages: languages)
        }
        isLoading = false
    }
}

// MARK: - Favorite Track Card
struct FavoriteTrackCard: View {
    let track: AudioTrack
    /// Context tracks for smart queue - enables next/previous through favorites
    var contextTracks: [AudioTrack]?
    @EnvironmentObject var audioEngine: AudioEngine
    // FIX: Use @ObservedObject for singletons - @StateObject causes crash when views recreate
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    var body: some View {
        Button {
            // Smart queue: if we have context, enable next/previous navigation
            if let tracks = contextTracks, !tracks.isEmpty {
                audioEngine.play(track: track, fromTracks: tracks, contextName: "Favorites")
            } else {
                audioEngine.play(track: track)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.forCategory(track.category).opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: track.category.icon)
                            .font(.system(size: 32))
                            .foregroundColor(Color.forCategory(track.category))
                    }

                    // Favorite indicator
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appSecondary)
                        .padding(6)
                }

                Text(track.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 100)
        }
    }
}

// MARK: - Quick Pick Card
struct QuickPickCard: View {
    let playlist: Playlist
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.forCategory(playlist.category ?? .instrumental).opacity(0.15))
                        .frame(height: 80)

                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 28))
                        .foregroundColor(Color.forCategory(playlist.category ?? .instrumental))
                }

                Text(playlist.category?.rawValue ?? playlist.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundColor(Color.forCategory(category))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.forCategory(category).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(category.description)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
    }
}

// MARK: - Premium Section Header
struct PremiumSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .appPrimary
    var showSeeAll: Bool = false
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: DesignTokens.spacingS) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundColor(.appText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }

            Spacer()

            if showSeeAll, let action = seeAllAction {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.appSubheadline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Premium Quick Pick Card
struct PremiumQuickPickCard: View {
    let playlist: Playlist
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignTokens.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.forCategory(playlist.category ?? .instrumental).opacity(0.2),
                                    Color.forCategory(playlist.category ?? .instrumental).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)

                    // Category icon
                    Image(systemName: playlist.category?.icon ?? "music.note.list")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color.forCategory(playlist.category ?? .instrumental))

                    // Play indicator on hover
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.3 : 0))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.forCategory(playlist.category ?? .instrumental))
                                .opacity(isPressed ? 1 : 0)
                        )
                }

                Text(playlist.category?.rawValue ?? playlist.name)
                    .font(.appCaption)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(CardPressStyle())
    }
}

// CardPressStyle moved to ButtonStyles.swift to avoid redeclaration

// MARK: - Premium Category Card
struct PremiumCategoryCard: View {
    let category: AudioCategory

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Category icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.forCategory(category).opacity(0.2),
                                Color.forCategory(category).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.forCategory(category))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.appBodyMedium)
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(category.description)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextTertiary)
        }
        .padding(DesignTokens.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Now Playing Card (Fixed Scrubbing)
/// Properly handles progress bar dragging without causing UI hang
struct NowPlayingCard: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @ObservedObject private var languageManager = LanguageManager.shared

    /// Local scrubbing state to prevent continuous seek calls
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localizedString("player.nowPlaying").uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                // Album art / category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .instrumental).opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                        .font(.system(size: 28))
                        .foregroundColor(Color.forCategory(audioEngine.currentTrack?.category ?? .instrumental))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(audioEngine.currentTrack?.title ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text(audioEngine.currentTrack?.category.rawValue ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)

                    // Progress bar - FIXED: Only seek on drag END, not every frame
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(height: 4)

                            // Progress fill - use scrubTime when scrubbing, otherwise currentTime
                            let displayTime = isScrubbing ? scrubTime : audioEngine.currentTime
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary)
                                .frame(width: geometry.size.width * CGFloat(displayTime / max(1, audioEngine.duration)), height: 4)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Mark as scrubbing to prevent timer updates
                                    if !isScrubbing {
                                        isScrubbing = true
                                        audioEngine.isScrubbing = true
                                    }
                                    // Update local state only (not seek yet)
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    scrubTime = progress * audioEngine.duration
                                }
                                .onEnded { value in
                                    // Seek only ONCE when drag ends
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    let newTime = progress * audioEngine.duration
                                    audioEngine.seek(to: newTime)

                                    // Clear scrubbing state
                                    isScrubbing = false
                                    audioEngine.isScrubbing = false
                                }
                        )
                    }
                    .frame(height: 4)
                }

                Spacer()

                // Play/Pause button
                Button {
                    if audioEngine.playbackState.isPlaying {
                        audioEngine.pause()
                    } else if audioEngine.playbackState == .paused {
                        audioEngine.resume()
                    } else if let track = audioEngine.currentTrack {
                        audioEngine.play(track: track)
                    } else {
                        audioEngine.resume()
                    }
                } label: {
                    Image(systemName: audioEngine.playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8)
            )
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
}
