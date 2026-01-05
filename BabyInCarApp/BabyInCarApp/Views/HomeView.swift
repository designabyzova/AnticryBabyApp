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
    @StateObject private var aiEngine = AIRecommendationEngine.shared
    @StateObject private var emergencyService = EmergencyCryStopService.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var effectivenessManager = EffectivenessManager.shared
    @Environment(\.bottomSafeAreaPadding) private var bottomPadding

    @State private var quickPickPlaylists: [Playlist] = []
    @State private var isLoading = true
    @State private var showingEmergencyMode = false
    @State private var showingAdvancedCryDetection = false
    @State private var showingVoiceInput = false
    @State private var showingSubscription = false
    @State private var showingEmergencyCategorySelector = false
    @State private var selectedEmergencyCategory: AudioCategory?
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignTokens.spacingL) {
                    // Hero header with time-aware greeting
                    // Spacer for safe area is handled by contentMargins
                    heroHeader

                    // Emergency Cry-Stop Button with pulsing glow
                    emergencyButton

                    // Voice Control Button
                    voiceControlButton

                    // Now Playing (if something is playing)
                    if audioEngine.currentTrack != nil {
                        nowPlayingSection
                    }

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
        .task {
            await loadQuickPicks()
        }
        .onChange(of: appState.selectedLanguages) { _ in
            // Reload quick picks when language selection changes
            Task {
                await loadQuickPicks()
            }
        }
        .fullScreenCover(isPresented: $showingEmergencyMode) {
            // FS-017: Use SmartQueueView with REAL melodic library tracks!
            // NO generated sounds, NO white noise - ONLY real compositions!
            SmartQueueView(queue: SmartEmergencyQueue.shared)
                .onAppear {
                    // Activate emergency mode for the baby with saved category settings
                    if let baby = appState.currentBaby {
                        // Get the user's saved category preferences
                        let settings = EmergencyCategorySettings.shared
                        let categoriesToUse = settings.activeCategories

                        print("[HomeView] 🚨 Starting Emergency Mode with categories: \(categoriesToUse.map { $0.rawValue })")

                        Task {
                            // Always use activateEmergencyPlaylistMode for proper AI-smart queue building
                            // Pass the user's saved categories (either AI defaults or custom selection)
                            await SmartCryResponseEngine.shared.activateEmergencyPlaylistMode(
                                for: baby,
                                preferredCategories: categoriesToUse
                            )
                        }
                    }
                }
                .onDisappear {
                    // Reset selected category when emergency mode is dismissed
                    selectedEmergencyCategory = nil
                }
        }
        .sheet(isPresented: $showingAdvancedCryDetection) {
            CryDetectionView()
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceControlSheet()
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingEmergencyCategorySelector) {
            EmergencyCategorySelectorView(selectedCategory: $selectedEmergencyCategory) {
                // User confirmed category selection - activate emergency mode
                showingEmergencyMode = true
            }
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
        case 5..<12: return "Good Morning!"
        case 12..<17: return "Good Afternoon!"
        case 17..<21: return "Good Evening!"
        default: return "Sweet Dreams!"
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
        case 5..<12: return "Morning time"
        case 12..<17: return "Afternoon nap time"
        case 17..<21: return "Evening wind down"
        default: return "Bedtime mode"
        }
    }

    // MARK: - Emergency Button with Pulsing Glow
    private var emergencyButton: some View {
        VStack(spacing: 12) {
            // Main Emergency Button - Shows category selector first
            EmergencyPulsingButton {
                // Show category selector before activating emergency mode
                showingEmergencyCategorySelector = true
            }

            // AI Cry Detection Link - Opens advanced monitoring
            Button {
                showingAdvancedCryDetection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimary)

                    Text("AI Cry Detection & Insights")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appPrimary)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(emergencyService.isAIMonitoringEnabled ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text(emergencyService.isAIMonitoringEnabled ? "Active" : "Tap to start")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appPrimary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Voice Control Button
    private var voiceControlButton: some View {
        Button {
            showingVoiceInput = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)

                Text("Voice Control")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appText)

                Spacer()

                Text("Hands-free")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.1))
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4)
            )
        }
        .accessibilityIdentifier("voiceControlButton")
        .padding(.horizontal, 20)
    }

    // MARK: - Now Playing Section
    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOW PLAYING")
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

                    // Progress bar - DRAGGABLE!
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(height: 4)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appPrimary)
                                .frame(width: geometry.size.width * CGFloat(audioEngine.currentTime / max(1, audioEngine.duration)), height: 4)
                        }
                        .contentShape(Rectangle()) // Make entire area tappable
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    let newTime = progress * audioEngine.duration
                                    audioEngine.seek(to: newTime)
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

    // MARK: - Favorites Section
    private var favoritesSection: some View {
        let favoriteTracks = favoritesManager.getFavoriteTracks()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.appSecondary)

                Text("Your Favorites")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)

                Spacer()

                NavigationLink(destination: FavoritesView()) {
                    Text("See All")
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
                    Text("Quick Picks for \(baby.formattedAge)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                } else {
                    Text("Quick Picks")
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
            Text("Categories")
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
    @StateObject private var favoritesManager = FavoritesManager.shared

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

// MARK: - Emergency Mode View
struct EmergencyModeView: View {
    @StateObject private var emergencyService = EmergencyCryStopService.shared
    @StateObject private var learningEngine = AdaptiveLearningEngine.shared
    @StateObject private var smartResponseEngine = SmartCryResponseEngine.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    // Animation states for "Baby is Calm" feedback
    @State private var showingSuccessAnimation = false
    @State private var successScale: CGFloat = 1.0
    @State private var successOpacity: Double = 1.0
    @State private var confettiTrigger = false
    @State private var feedbackMessage = ""
    @State private var sessionStartTime = Date()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background - transitions to green on success
                LinearGradient(
                    colors: showingSuccessAnimation
                        ? [Color.green.opacity(0.9), Color.green]
                        : [Color.appDanger.opacity(0.9), Color.appDanger],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: showingSuccessAnimation)

                VStack(spacing: 32) {
                    // Top safe area spacer
                    Color.clear.frame(height: max(geometry.safeAreaInsets.top, 20))

                    Spacer()

                    // Success animation overlay OR normal phase indicator
                    if showingSuccessAnimation {
                        successAnimationView
                    } else {
                        phaseIndicatorView
                    }

                    // Phase description
                    Text(showingSuccessAnimation ? feedbackMessage : phaseDescription)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut, value: showingSuccessAnimation)

                    // Now Playing Section with sound switching
                    if !showingSuccessAnimation {
                        nowPlayingSection
                    }

                    Spacer()

                    // Action buttons
                    if !showingSuccessAnimation {
                        actionButtons(geometry: geometry)
                    }
                }
            }
        }
        .onAppear {
            sessionStartTime = Date()
        }
    }

    // MARK: - Phase Indicator View

    private var phaseIndicatorView: some View {
        VStack(spacing: 16) {
            Text(emergencyService.currentPhase.rawValue)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: emergencyService.phaseProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: emergencyService.phaseProgress)

                VStack {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)

                    Text("\(Int(emergencyService.phaseProgress * 100))%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Success Animation View

    private var successAnimationView: some View {
        VStack(spacing: 24) {
            // Animated checkmark
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(successScale)

                // Inner circle
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 150, height: 150)

                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(successScale)
            }

            Text("Baby is Calm!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .opacity(successOpacity)

            // Learning feedback
            VStack(spacing: 8) {
                Text("Learning saved")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text("We'll remember what worked!")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .opacity(successOpacity)
        }
    }

    // MARK: - Now Playing Section with Sound Switching

    private var nowPlayingSection: some View {
        VStack(spacing: 16) {
            // Current Sound Display
            if let currentSound = smartResponseEngine.currentSound {
                VStack(spacing: 12) {
                    // Now Playing Header
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                        Text("NOW PLAYING")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()

                        // Auto-switch countdown
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("Auto-switch: \(Int(smartResponseEngine.secondsUntilNextSound))s")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .foregroundColor(.white.opacity(0.8))

                    // Current Sound Card
                    HStack(spacing: 16) {
                        // Sound Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 56, height: 56)

                            Image(systemName: currentSound.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }

                        // Sound Name and Type
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentSound.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            Text(soundTypeDescription(for: currentSound))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        // Stop/Mute Button
                        Button {
                            audioEngine.pause()
                        } label: {
                            Image(systemName: audioEngine.playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                    )

                    // Alternative Sounds (Quick Switch)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try Different Sound:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            ForEach(smartResponseEngine.alternativeSounds.prefix(3), id: \.self) { sound in
                                Button {
                                    smartResponseEngine.switchToSound(sound)
                                    // Haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 48, height: 48)

                                            Image(systemName: sound.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                        }

                                        Text(sound.shortName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .buttonStyle(BounceButtonStyle())
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.2))
                )
                .padding(.horizontal, 24)
            }
        }
    }

    /// Get a user-friendly description for the sound type
    private func soundTypeDescription(for sound: GeneratorType) -> String {
        switch sound {
        case .musicBox, .lullaby, .softPiano, .gentleGuitar, .chimes, .bells:
            return "Melodic • Calming"
        case .ocean, .waterfall, .river, .forest:
            return "Nature • Soothing"
        case .heartbeat, .womb, .shushing:
            return "Comfort • Familiar"
        default:
            return "Ambient • Relaxing"
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Baby is Calm button with enhanced feedback
            Button {
                handleBabyIsCalm()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                    Text("Baby is Calm")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.appDanger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
            }
            .buttonStyle(BounceButtonStyle())

            // Cancel button
            Button {
                emergencyService.deactivate()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 20)
    }

    // MARK: - Handle Baby is Calm Action

    private func handleBabyIsCalm() {
        // 1. Haptic feedback - success pattern
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 2. Calculate session metrics
        let timeToCalm = Date().timeIntervalSince(sessionStartTime)

        // 3. Record learning data
        if let baby = appState.currentBaby {
            let cryType = emergencyService.detectedCryType
            let currentSound = SmartCryResponseEngine.shared.currentSound ?? .ocean

            // Record to adaptive learning engine
            learningEngine.recordSession(
                cryType: cryType,
                soundType: currentSound,
                wasSuccessful: true,
                timeToCalm: timeToCalm,
                cryIntensity: CryDetectionService.shared.cryIntensity,
                features: nil
            )

            // Also record to legacy system
            emergencyService.reportSuccessWithFeedback(
                for: baby,
                timeToCalm: timeToCalm
            )

            // 3b. Trigger engagement event for freemium upgrade prompts (after soothing)
            // This will show gentle upgrade prompts to free users who had a successful experience
            let trackTitle = audioEngine.currentTrack?.title ?? currentSound.rawValue
            EngagementTriggerService.shared.recordCryDetectionSuccess(
                trackTitle: trackTitle,
                timeToCalmSeconds: Int(timeToCalm)
            )
        }

        // 4. Set feedback message
        if timeToCalm < 60 {
            feedbackMessage = "Amazing! Calmed in \(Int(timeToCalm)) seconds"
        } else {
            let minutes = Int(timeToCalm / 60)
            feedbackMessage = "Great job! Calmed in \(minutes) minute\(minutes > 1 ? "s" : "")"
        }

        // 5. Start audio fade-out (graceful 2.5 second fade)
        audioEngine.fadeOutAndStop(duration: 2.5)

        // 6. Show success animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingSuccessAnimation = true
        }

        // 7. Animate success elements
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            successScale = 1.1
        }

        // 8. Second haptic for confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }

        // 9. Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismiss()
        }
    }

    // MARK: - Helper Properties

    private var phaseIcon: String {
        switch emergencyService.currentPhase {
        case .idle: return "play.circle"
        case .listening: return "ear.badge.waveform"
        case .detected: return "exclamationmark.triangle"
        case .attention: return "exclamationmark.circle"
        case .transition: return "arrow.down.circle"
        case .sustained: return "heart.circle"
        case .adapting: return "waveform.path"
        case .complete: return "checkmark.circle"
        }
    }

    private var phaseDescription: String {
        switch emergencyService.currentPhase {
        case .idle:
            return "Ready to start calming sequence"
        case .listening:
            return "Listening for baby's cry..."
        case .detected:
            return "Cry detected! Preparing response..."
        case .attention:
            return "Playing attention-grabbing sounds to interrupt crying"
        case .transition:
            return "Gradually transitioning to calming sounds"
        case .sustained:
            return "Sustained soothing for sleep transition"
        case .adapting:
            return "Adapting response to baby's needs"
        case .complete:
            return "Baby should be calm now"
        }
    }
}

// MARK: - Voice Control Sheet
struct VoiceControlSheet: View {
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var voiceHandler = VoiceCommandHandler.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    @State private var commandFeedback: String?
    @State private var showingSuccess = false
    @State private var continuousMode = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Microphone visualization with success/error state
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .fill(circleColor.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .scaleEffect(speechService.isListening ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.isListening)

                    // Main circle
                    Circle()
                        .fill(circleColor)
                        .frame(width: 120, height: 120)

                    Image(systemName: circleIcon)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }

                // Status text
                Text(statusText)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(circleColor)

                // Command feedback banner
                if let feedback = commandFeedback {
                    HStack(spacing: 12) {
                        Image(systemName: showingError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(circleColor)

                        Text(feedback)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(circleColor.opacity(0.15))
                    )
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                }

                // Recognized text
                if !speechService.recognizedText.isEmpty && !showingSuccess {
                    VStack(spacing: 8) {
                        Text("I heard:")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)

                        Text(speechService.recognizedText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appPrimary.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 32)
                }

                // Voice command suggestions (hide when listening or showing success)
                if !speechService.isListening && !showingSuccess {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try saying:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextSecondary)

                        VoiceCommandSuggestion(command: "\"Play\" or \"Pause\"")
                        VoiceCommandSuggestion(command: "\"Next\" or \"Previous\"")
                        VoiceCommandSuggestion(command: "\"Volume up\" or \"Louder\"")
                        VoiceCommandSuggestion(command: "\"Play lullabies\"")
                        VoiceCommandSuggestion(command: "\"Emergency mode\"")
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Continuous mode toggle
                Toggle(isOn: $continuousMode) {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.appPrimary)
                        Text("Continuous listening")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                .padding(.horizontal, 32)

                // Listen button
                Button {
                    if speechService.isListening {
                        speechService.stopListening()
                    } else {
                        startListening()
                    }
                } label: {
                    HStack {
                        Image(systemName: speechService.isListening ? "stop.fill" : "mic.fill")
                        Text(speechService.isListening ? "Stop Listening" : "Start Listening")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(speechService.isListening ? Color.appDanger : Color.appPrimary)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Voice Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        speechService.stopListening()
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandExecuted)) { notification in
                handleCommandExecuted(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandNotRecognized)) { notification in
                handleCommandNotRecognized(notification)
            }
            .onAppear {
                // Auto-start listening when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startListening()
                }
            }
        }
    }

    private var statusText: String {
        if showingSuccess {
            return "Done!"
        } else if showingError {
            return "Try again"
        } else if speechService.isListening {
            return "Listening..."
        } else {
            return "Tap to speak"
        }
    }

    private var circleColor: Color {
        if showingSuccess {
            return .green
        } else if showingError {
            return .orange
        } else {
            return .appPrimary
        }
    }

    private var circleIcon: String {
        if showingSuccess {
            return "checkmark"
        } else if showingError {
            return "xmark"
        } else {
            return "mic.fill"
        }
    }

    @State private var showingError = false

    private func startListening() {
        showingSuccess = false
        showingError = false
        commandFeedback = nil
        speechService.startListening()
    }

    private func handleCommandExecuted(_ notification: Notification) {
        guard let message = notification.userInfo?["message"] as? String,
              let success = notification.userInfo?["success"] as? Bool,
              success else { return }

        // Show success feedback
        withAnimation(.spring(response: 0.3)) {
            showingSuccess = true
            showingError = false
            commandFeedback = message
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Handle next action based on mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if continuousMode {
                // Restart listening for next command
                withAnimation {
                    showingSuccess = false
                    commandFeedback = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startListening()
                }
            } else {
                // Auto-dismiss after successful command
                dismiss()
            }
        }
    }

    private func handleCommandNotRecognized(_ notification: Notification) {
        // Show error feedback
        withAnimation(.spring(response: 0.3)) {
            showingError = true
            showingSuccess = false
            commandFeedback = "Command not recognized"
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Restart listening after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showingError = false
                commandFeedback = nil
            }
            if continuousMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startListening()
                }
            }
        }
    }
}

struct VoiceCommandSuggestion: View {
    let command: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appPrimary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(command)
                .font(.system(size: 14))
                .foregroundColor(.appText)
        }
    }
}

// MARK: - Emergency Pulsing Button
struct EmergencyPulsingButton: View {
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                // Outer glow pulse
                RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                    .fill(Color.appDanger.opacity(glowOpacity))
                    .scaleEffect(pulseScale)
                    .blur(radius: 8)

                // Main button
                HStack(spacing: DesignTokens.spacingM) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EMERGENCY CRY-STOP")
                            .font(.appBodyMedium)
                            .foregroundColor(.white)

                        Text("Tap for instant calming")
                            .font(.appCaption)
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(DesignTokens.spacingM)
                .background(
                    LinearGradient(
                        colors: [Color.appDanger, Color.appDanger.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusL))
                .shadow(color: Color.appDanger.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(EmergencyButtonPressStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.03
                glowOpacity = 0.5
            }
        }
    }
}

struct EmergencyButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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

// MARK: - Emergency Category Settings Manager
/// Manages user's emergency mode category preferences with persistence
class EmergencyCategorySettings: ObservableObject {
    static let shared = EmergencyCategorySettings()

    private let defaultsKey = "EmergencyCategorySettings"

    /// Default categories that AI Instant Calm uses (most effective for baby calming)
    static let defaultCategories: Set<AudioCategory> = [
        .classicalMusic,
        .instrumental,
        .natureSounds
    ]

    /// User's selected categories for emergency mode
    @Published var selectedCategories: Set<AudioCategory> {
        didSet {
            saveSettings()
        }
    }

    /// Whether user is using the AI default (true) or custom selection (false)
    @Published var useAIDefault: Bool {
        didSet {
            saveSettings()
        }
    }

    private init() {
        // Load saved settings or use defaults
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let settings = try? JSONDecoder().decode(EmergencySettings.self, from: data) {
            self.selectedCategories = settings.categories
            self.useAIDefault = settings.useAIDefault
        } else {
            self.selectedCategories = Self.defaultCategories
            self.useAIDefault = true
        }
    }

    /// Get the active categories (either AI defaults or user selection)
    var activeCategories: Set<AudioCategory> {
        useAIDefault ? Self.defaultCategories : selectedCategories
    }

    /// Reset to application defaults
    func resetToDefaults() {
        selectedCategories = Self.defaultCategories
        useAIDefault = true
    }

    private func saveSettings() {
        let settings = EmergencySettings(categories: selectedCategories, useAIDefault: useAIDefault)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private struct EmergencySettings: Codable {
        let categories: Set<AudioCategory>
        let useAIDefault: Bool

        init(categories: Set<AudioCategory>, useAIDefault: Bool) {
            // Convert Set to Array for encoding, then back to Set for decoding
            self.categories = categories
            self.useAIDefault = useAIDefault
        }

        enum CodingKeys: String, CodingKey {
            case categories, useAIDefault
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let categoriesArray = try container.decode([AudioCategory].self, forKey: .categories)
            self.categories = Set(categoriesArray)
            self.useAIDefault = try container.decode(Bool.self, forKey: .useAIDefault)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Array(categories), forKey: .categories)
            try container.encode(useAIDefault, forKey: .useAIDefault)
        }
    }
}

// MARK: - Emergency Category Selector
struct EmergencyCategorySelectorView: View {
    @Binding var selectedCategory: AudioCategory?
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var settings = EmergencyCategorySettings.shared

    /// Multi-select categories state
    @State private var selectedCategories: Set<AudioCategory> = []
    @State private var useAIDefault: Bool = true

    // Calming categories (research-backed for baby soothing)
    // NOTE: White Noise removed - only appears once below
    private let calmingCategories: [AudioCategory] = [
        .classicalMusic,
        .natureSounds,
        .instrumental,
        .childrenSongs
    ]

    // Other categories (can still be selected, but less recommended)
    private let otherCategories: [AudioCategory] = [
        .fairyTales,
        .podcasts
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emergency Cry-Stop Mode")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.appText)

                        Text("Select one or more categories to create a smart calming playlist. Your settings are saved automatically.")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // AI Instant Calm - Default option with multi-category
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("RECOMMENDED")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.appTextSecondary)

                            Spacer()

                            // Reset to defaults button
                            if !useAIDefault {
                                Button {
                                    resetToDefaults()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 11))
                                        Text("Reset")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(.appPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Button {
                            useAIDefault = true
                            selectedCategories = EmergencyCategorySettings.defaultCategories
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.appPrimary.opacity(0.2), Color.appPrimary.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)

                                    Image(systemName: "sparkles")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.appPrimary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("AI Instant Calm")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.appText)

                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }

                                    Text("AI-optimized mix: Classical + Instrumental + Nature")
                                        .font(.system(size: 14))
                                        .foregroundColor(.appTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                // Selection indicator
                                Image(systemName: useAIDefault ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(useAIDefault ? .appPrimary : .appTextTertiary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appCardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(useAIDefault ? Color.appPrimary : Color.clear, lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    // Calming Categories - Multi-select
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("CALMING CATEGORIES")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.appTextSecondary)

                            Spacer()

                            if !useAIDefault && !selectedCategories.isEmpty {
                                Text("\(selectedCategories.count) selected")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.horizontal, 20)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(calmingCategories) { category in
                                EmergencyMultiSelectCategoryCard(
                                    category: category,
                                    isSelected: selectedCategories.contains(category)
                                ) {
                                    toggleCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Other Categories
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OTHER CATEGORIES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(otherCategories) { category in
                                EmergencyMultiSelectCategoryCard(
                                    category: category,
                                    isSelected: selectedCategories.contains(category)
                                ) {
                                    toggleCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Selection summary
                    if !useAIDefault && !selectedCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR SELECTION")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.appTextSecondary)

                            Text(selectedCategories.map { $0.rawValue }.sorted().joined(separator: " + "))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appText)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 120) // Space for bottom button
            }
            .background(
                LinearGradient(
                    colors: [Color.appBackground, Color.appWarmCream.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Confirm button - always visible at bottom
                VStack(spacing: 8) {
                    Button {
                        // Save settings before confirming
                        saveSettings()

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                        onConfirm()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20, weight: .semibold))

                            Text("Start Emergency Mode")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.appDanger, Color.appDanger.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.appDanger.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(!useAIDefault && selectedCategories.isEmpty)
                    .opacity(!useAIDefault && selectedCategories.isEmpty ? 0.5 : 1.0)

                    if !useAIDefault && selectedCategories.isEmpty {
                        Text("Select at least one category")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Color.appBackground
                        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
                )
            }
            .onAppear {
                // Load saved settings
                loadSettings()
            }
        }
    }

    private func toggleCategory(_ category: AudioCategory) {
        useAIDefault = false

        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func loadSettings() {
        useAIDefault = settings.useAIDefault
        selectedCategories = settings.selectedCategories
    }

    private func saveSettings() {
        settings.useAIDefault = useAIDefault
        settings.selectedCategories = selectedCategories
    }

    private func resetToDefaults() {
        settings.resetToDefaults()
        useAIDefault = true
        selectedCategories = EmergencyCategorySettings.defaultCategories

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Multi-Select Emergency Category Card
struct EmergencyMultiSelectCategoryCard: View {
    let category: AudioCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.forCategory(category).opacity(isSelected ? 0.3 : 0.2),
                                    Color.forCategory(category).opacity(isSelected ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)

                    Image(systemName: category.icon)
                        .font(.system(size: 32))
                        .foregroundColor(Color.forCategory(category))

                    // Multi-select checkbox indicator
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.appPrimary : Color.white)
                                    .frame(width: 24, height: 24)
                                    .shadow(color: .black.opacity(0.1), radius: 2)

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.appTextTertiary, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }

                VStack(spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text(category.description)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4)
            )
        }
    }
}

// MARK: - Emergency Category Card
struct EmergencyCategoryCard: View {
    let category: AudioCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
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
                        .frame(height: 80)

                    Image(systemName: category.icon)
                        .font(.system(size: 32))
                        .foregroundColor(Color.forCategory(category))

                    // Selection indicator
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .appPrimary : .appTextTertiary)
                                .padding(8)
                        }
                        Spacer()
                    }
                }

                VStack(spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    Text(category.description)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4)
            )
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
}

#Preview("Emergency Category Selector") {
    EmergencyCategorySelectorView(
        selectedCategory: .constant(.classicalMusic),
        onConfirm: {}
    )
}
