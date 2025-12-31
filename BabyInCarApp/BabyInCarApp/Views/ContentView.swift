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

    // Calculate bottom padding based on what's visible
    private var bottomPadding: CGFloat {
        let tabBarHeight: CGFloat = 85
        let miniPlayerHeight: CGFloat = audioEngine.currentTrack != nil ? 74 : 0
        return tabBarHeight + miniPlayerHeight
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Bottom overlay stack (mini player + tab bar)
            VStack(spacing: 0) {
                // Mini Player
                if audioEngine.currentTrack != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: audioEngine.currentTrack != nil)
                }

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Configure audio session on app launch
            audioEngine.configureAudioSession()
        }
        // Pass bottom padding to child views via environment
        .environment(\.bottomSafeAreaPadding, bottomPadding)
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

// MARK: - Premium Custom Tab Bar

/// Premium tab bar with animated selection indicator and micro-interactions
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabBarNamespace

    // Haptic feedback
    private let selectionFeedback = UISelectionFeedbackGenerator()

    let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("house", "house.fill", "Home"),
        ("books.vertical", "books.vertical.fill", "Library"),
        ("heart", "heart.fill", "Favorites"),
        ("person", "person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                PremiumTabBarButton(
                    icon: tabs[index].icon,
                    selectedIcon: tabs[index].selectedIcon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    namespace: tabBarNamespace
                ) {
                    if selectedTab != index {
                        selectionFeedback.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(tabBarBackground)
        .onAppear {
            selectionFeedback.prepare()
        }
    }

    private var tabBarBackground: some View {
        ZStack {
            // Frosted glass effect
            Rectangle()
                .fill(.ultraThinMaterial)

            // Gradient overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appCardBackground.opacity(0.9),
                            Color.appCardBackground.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top border highlight
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                Spacer()
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
    }
}

/// Premium tab bar button with animated states and selection indicator
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
struct MiniPlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var showingFullPlayer = false
    @State private var dragOffset: CGFloat = 0
    @State private var playButtonScale: CGFloat = 1.0
    @State private var isPressed = false

    // Haptic feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    // Calculate progress for ring animation
    private var progress: Double {
        guard audioEngine.duration > 0 else { return 0 }
        return audioEngine.currentTime / audioEngine.duration
    }

    var body: some View {
        ZStack {
            // Floating pill container
            miniPlayerContent
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Allow dragging down to dismiss
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height * 0.5
                            } else {
                                // Drag up to expand
                                dragOffset = value.translation.height * 0.3
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                // Swipe up - open full player
                                impactMedium.impactOccurred()
                                showingFullPlayer = true
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                )
        }
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            PlayerView()
                .environmentObject(audioEngine)
        }
    }

    private var miniPlayerContent: some View {
        Button {
            impactMedium.impactOccurred()
            showingFullPlayer = true
        } label: {
            HStack(spacing: 12) {
                // Artwork with progress ring
                artworkWithProgressRing

                // Track Info with marquee effect for long titles
                trackInfo

                Spacer(minLength: 8)

                // Playback Controls with animations
                playbackControls
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(miniPlayerBackground)
            .padding(.horizontal, 12)
        }
        .buttonStyle(MiniPlayerButtonStyle(isPressed: $isPressed))
    }

    // MARK: - Artwork with Progress Ring
    private var artworkWithProgressRing: some View {
        ZStack {
            // Background circle with category color
            Circle()
                .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.15))
                .frame(width: 52, height: 52)

            // Progress ring
            Circle()
                .stroke(Color.appTextSecondary.opacity(0.2), lineWidth: 3)
                .frame(width: 52, height: 52)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise),
                            Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)

            // Category icon
            Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise),
                            Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Playing indicator animation
            if audioEngine.playbackState.isPlaying {
                MiniEqualizerView()
                    .frame(width: 16, height: 12)
                    .offset(y: 18)
            }
        }
    }

    // MARK: - Track Info
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(audioEngine.currentTrack?.title ?? "Unknown")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appText)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(audioEngine.currentTrack?.artist ?? "")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)

                if let language = audioEngine.currentTrack?.language {
                    Text(language.flag)
                        .font(.system(size: 11))
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
                } else {
                    audioEngine.resume()
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
