//
//  ContentView.swift
//  BabyInCarApp
//
//  Main content view with navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var voiceHandler = VoiceCommandHandler.shared

    var body: some View {
        Group {
            if appState.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            voiceHandler.configure(with: appState)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var selectedTab = 0

    // Calculate the total height of bottom overlay for proper insets
    // Tab bar: ~60pt (8 top padding + 44 content + 6 bottom padding)
    // Mini player: ALWAYS 72 (always visible now, ready for cry detection playback)
    private var bottomOverlayHeight: CGFloat {
        let tabBarHeight: CGFloat = 60 // Tab bar content height (not including safe area)
        let miniPlayerHeight: CGFloat = 72 // Always visible - default playlist loaded on app start
        return tabBarHeight + miniPlayerHeight
    }

    var body: some View {
        // Main content - each view handles its own scrolling
        Group {
            switch selectedTab {
            case 0:
                HomeView()
            case 1:
                LibraryView()
            case 2:
                FavoritesView()
            case 3:
                ProfileView()
            default:
                HomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Use safeAreaInset to properly push content above the tab bar
        // This ensures content never overlaps with the tab bar
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                // Mini Player - ALWAYS visible (floats above tab bar)
                // Default playlist is loaded on app start, player ready for cry detection or manual play
                MiniPlayerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))

                // Premium Tab Bar - pinned to very bottom
                CustomTabBar(selectedTab: $selectedTab)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioEngine.playbackState)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Configure audio session on app launch
            audioEngine.configureAudioSession()
        }
        // Pass bottom padding to child views via environment (for manual adjustments if needed)
        .environment(\.bottomSafeAreaPadding, bottomOverlayHeight)
    }
}

// Environment key for bottom padding
private struct BottomSafeAreaPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 120
}

extension EnvironmentValues {
    var bottomSafeAreaPadding: CGFloat {
        get { self[BottomSafeAreaPaddingKey.self] }
        set { self[BottomSafeAreaPaddingKey.self] = newValue }
    }
}

// MARK: - World-Class Premium Tab Bar

/// A world-class floating tab bar that pins to the very bottom of the screen
/// with proper safe area handling, elegant animations, and premium visual design.
///
/// Key features:
/// - Proper intrinsic sizing for safeAreaInset compatibility
/// - Pins content within safe area, background extends to screen edge
/// - Premium frosted glass with subtle gradient
/// - Smooth spring animations with haptic feedback
/// - Accessibility-ready with proper labels
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabBarNamespace
    @Environment(\.colorScheme) private var colorScheme

    // Haptic feedback generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("house", "house.fill", "Home"),
        ("books.vertical", "books.vertical.fill", "Library"),
        ("heart", "heart.fill", "Favorites"),
        ("person", "person.fill", "Profile")
    ]

    var body: some View {
        // Tab buttons row with proper safe area handling
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                WorldClassTabButton(
                    icon: tabs[index].icon,
                    selectedIcon: tabs[index].selectedIcon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    namespace: tabBarNamespace
                ) {
                    if selectedTab != index {
                        impactFeedback.impactOccurred(intensity: 0.6)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedTab = index
                        }
                    }
                }
                .accessibilityIdentifier(tabs[index].label)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        // First background is for layout (respects safe area)
        .background(Color.clear)
        // Second background extends into the bottom safe area (home indicator)
        .background(
            tabBarBackground
                .ignoresSafeArea(edges: .bottom)
        )
        .onAppear {
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }

    private var tabBarBackground: some View {
        ZStack {
            // Ultra-premium frosted glass base
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay for depth and premium feel
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            (colorScheme == .dark ? Color.black : Color.white).opacity(0.88),
                            (colorScheme == .dark ? Color.black : Color.white).opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.overlay)

            // Premium top edge highlight
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appPrimary.opacity(0.1),
                                Color.appPrimary.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 20, y: -8)
    }
}

/// Individual world-class tab button with premium micro-interactions
struct WorldClassTabButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    // Animated selection pill background
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.appPrimary.opacity(0.18),
                                        Color.appPrimary.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 28)
                            .matchedGeometryEffect(id: "tabPill", in: namespace)
                    }

                    // Icon with smooth morph and scale
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.appPrimary, .appPrimary.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                : AnyShapeStyle(Color.appTextSecondary)
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        // Note: symbolEffect removed - iOS 17+ only
                }
                .frame(height: 28)

                // Label with elegant opacity fade
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)
                    .opacity(isSelected ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(TabButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Custom button style that tracks press state for animations
struct TabButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - Legacy Tab Bar Button (Kept for compatibility)

/// Premium tab bar button with animated states and selection indicator
/// @note Consider using WorldClassTabButton for new implementations
struct PremiumTabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        Button {
            // Bounce animation on tap
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                bounceScale = 0.85
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceScale = 1.1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    bounceScale = 1.0
                }
            }
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Selection indicator background
                    if isSelected {
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.15))
                            .frame(width: 56, height: 32)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                    }

                    // Icon with morph animation
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ?
                            LinearGradient(
                                colors: [.appPrimary, .appPrimary.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                colors: [.appTextSecondary, .appTextSecondary],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .frame(height: 32)

                // Label with fade animation
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)

                // Active dot indicator
                Circle()
                    .fill(isSelected ? Color.appPrimary : Color.clear)
                    .frame(width: 4, height: 4)
                    .animation(.spring(response: 0.3), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(bounceScale)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ScaleButtonStyle moved to ButtonStyles.swift to avoid redeclaration

// MARK: - Premium Mini Player View

/// Floating pill-style mini player with progress ring and fluid animations
/// ALWAYS visible - displays default playlist track ready for cry detection or manual play
struct MiniPlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @ObservedObject private var smartQueue = SmartEmergencyQueue.shared
    @State private var showingFullPlayer = false
    @State private var dragOffset: CGFloat = 0
    @State private var playButtonScale: CGFloat = 1.0
    @State private var isDragging = false
    @State private var isTransitioning = false // Track when opening full player

    // Haptic feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    // Display track - uses current track or a default fallback for always-visible player
    private var displayTrack: AudioTrack {
        audioEngine.currentTrack ?? AudioTrack.defaultEmergencyTrack()
    }

    // Calculate progress for ring animation
    private var progress: Double {
        guard audioEngine.duration > 0 else { return 0 }
        return audioEngine.currentTime / audioEngine.duration
    }

    var body: some View {
        ZStack {
            miniPlayerContent
                .offset(y: dragOffset)
                .opacity(isTransitioning ? 0.7 : 1.0)
                .scaleEffect(isTransitioning ? 0.98 : 1.0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            isDragging = true
                            // Allow dragging down to dismiss
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height * 0.5
                            } else {
                                // Drag up to expand
                                dragOffset = value.translation.height * 0.3
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            if value.translation.height < -50 {
                                // Swipe up - open full player
                                openFullPlayer()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                )

            // Loading overlay when transitioning to full player
            if isTransitioning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    Text("Opening...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTransitioning)
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
        }
        .fullScreenCover(isPresented: $showingFullPlayer, onDismiss: {
            // Reset transition state when dismissed
            isTransitioning = false
        }) {
            // CONSOLIDATED PLAYER LOGIC: Show SmartQueueView when emergency is active, otherwise PlayerView
            if smartQueue.isActive {
                // Emergency mode active - show SmartQueueView with purple interface
                SmartQueueView(queue: smartQueue)
                    .environmentObject(audioEngine)
                    .interactiveDismissDisabled(false)
                    .onAppear {
                        isTransitioning = false
                    }
            } else {
                // Normal library playback - show green PlayerView
                PlayerView()
                    .environmentObject(audioEngine)
                    .interactiveDismissDisabled(false)
                    .onAppear {
                        // Player appeared, clear transition state
                        isTransitioning = false
                    }
            }
        }
    }

    /// Opens full player with guard against double-presentation
    private func openFullPlayer() {
        guard !showingFullPlayer, !isTransitioning else { return }
        impactMedium.impactOccurred()

        // Show loading state briefly before presenting
        withAnimation {
            isTransitioning = true
        }

        // Small delay to show the loading feedback, then present
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingFullPlayer = true
        }
    }

    private var miniPlayerContent: some View {
        HStack(spacing: 12) {
            // Tappable area (artwork + track info) opens full player
            HStack(spacing: 12) {
                // Artwork with progress ring
                artworkWithProgressRing

                // Track Info with marquee effect for long titles
                trackInfo
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture()
                    .onEnded {
                        openFullPlayer()
                    }
            )

            Spacer(minLength: 8)

            // Playback Controls (not inside the tappable area)
            playbackControls
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(miniPlayerBackground)
        .padding(.horizontal, 12)
        .accessibilityIdentifier("miniPlayer")
    }

    // MARK: - Artwork with Progress Ring
    private var artworkWithProgressRing: some View {
        ZStack {
            // Background circle with category color
            Circle()
                .fill(Color.forCategory(displayTrack.category).opacity(0.15))
                .frame(width: 52, height: 52)

            // Progress ring (shows playback progress OR buffer progress when loading)
            Circle()
                .stroke(Color.appTextSecondary.opacity(0.2), lineWidth: 3)
                .frame(width: 52, height: 52)

            // Buffer progress ring (shows when buffering)
            if audioEngine.isBuffering && audioEngine.bufferProgress > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(audioEngine.bufferProgress))
                    .stroke(
                        Color.appTextSecondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: audioEngine.bufferProgress)
            }

            // Playback progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.forCategory(displayTrack.category),
                            Color.forCategory(displayTrack.category).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)

            // Category icon OR loading spinner
            if audioEngine.isBuffering {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.forCategory(displayTrack.category))
            } else {
                Image(systemName: displayTrack.category.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.forCategory(displayTrack.category),
                                Color.forCategory(displayTrack.category).opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Playing indicator animation
            if audioEngine.playbackState.isPlaying && !audioEngine.isBuffering {
                MiniEqualizerView()
                    .frame(width: 16, height: 12)
                    .offset(y: 18)
            }
        }
    }

    // MARK: - Track Info
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(displayTrack.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appText)
                .lineLimit(1)

            HStack(spacing: 4) {
                // Show "Loading..." when buffering, otherwise show artist
                if audioEngine.isBuffering {
                    Text("Loading...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                } else {
                    Text(displayTrack.artist)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)

                    if let language = displayTrack.language {
                        Text(language.flag)
                            .font(.system(size: 11))
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 12) {
            // Play/Pause button with animation
            Button {
                impactMedium.impactOccurred()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    playButtonScale = 0.85
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        playButtonScale = 1.0
                    }
                }

                if audioEngine.playbackState.isPlaying {
                    audioEngine.pause()
                } else if audioEngine.playbackState == .paused {
                    audioEngine.resume()
                } else {
                    // Stopped state - play the display track (current or default)
                    audioEngine.play(track: displayTrack)
                }
            } label: {
                ZStack {
                    // Glow effect when playing
                    if audioEngine.playbackState.isPlaying {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .blur(radius: 4)
                    }

                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 4, y: 2)

                    Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .offset(x: audioEngine.playbackState.isPlaying ? 0 : 1)
                }
                .scaleEffect(playButtonScale)
            }
            .buttonStyle(PlainButtonStyle())

            // Next button
            Button {
                impactLight.impactOccurred()
                audioEngine.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Background
    private var miniPlayerBackground: some View {
        ZStack {
            // Frosted glass effect
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appCardBackground.opacity(0.8),
                            Color.appCardBackground.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border highlight
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

// MARK: - Mini Equalizer View
struct MiniEqualizerView: View {
    @State private var heights: [CGFloat] = [0.4, 0.6, 0.5]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.appPrimary.opacity(0.8))
                    .frame(width: 2, height: 12 * heights[index])
            }
        }
        .onAppear {
            animateBars()
        }
    }

    private func animateBars() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: Double.random(in: 0.3...0.5))
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1)
            ) {
                heights[index] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}

// MARK: - Mini Player Button Style
struct MiniPlayerButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AudioEngine.shared)
        .environmentObject(SubscriptionManager.shared)
}
