//
//  PlayerView.swift
//  BabyInCarApp
//
//  Premium full-screen audio player with breathing animations
//

import SwiftUI
import UIKit

struct PlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    // Use ObservedObject for shared singletons - faster initialization than StateObject
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var downloadManager = AudioDownloadManager.shared
    @ObservedObject private var babyProfileManager = BabyProfileManager.shared
    @ObservedObject private var cryDetectionService = CryDetectionService.shared
    @ObservedObject private var effectivenessManager = EffectivenessManager.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared
    @ObservedObject private var playbackQueueManager = PlaybackQueueManager.shared
    @Environment(\.dismiss) var dismiss

    // Display track - uses current track or a default fallback (same as mini player)
    private var displayTrack: AudioTrack {
        audioEngine.currentTrack ?? AudioTrack.defaultEmergencyTrack()
    }

    // Consolidated sheet state - prevents SwiftUI issues with multiple sheet modifiers
    enum PlayerSheet: Identifiable {
        case timer
        case playlist
        case downloads
        case effectivenessFeedback(track: AudioTrack, cryType: CryType, duration: TimeInterval)
        case cryTypePicker
        case moreLikeThis
        case softPaywall(track: AudioTrack)

        var id: String {
            switch self {
            case .timer: return "timer"
            case .playlist: return "playlist"
            case .downloads: return "downloads"
            case .effectivenessFeedback: return "effectivenessFeedback"
            case .cryTypePicker: return "cryTypePicker"
            case .moreLikeThis: return "moreLikeThis"
            case .softPaywall: return "softPaywall"
            }
        }
    }

    @State private var activeSheet: PlayerSheet?
    @State private var showingQueue = false // Keep separate as fullScreenCover
    @State private var showingItHelpedToast = false
    @State private var relatedTracks: [SearchTrack] = []
    @State private var isLoadingRelated = false
    @State private var isPremiumPreview = false
    @State private var previewTimeRemaining: TimeInterval = 10
    @State private var previewTimer: Timer?

    // Track playback state for feedback prompt
    @State private var lastPlayedTrack: AudioTrack?
    @State private var playbackStartTime: Date?
    @State private var previousPlaybackState: LocalPlaybackState = .stopped

    // Animation states for controls
    @State private var shuffleScale: CGFloat = 1.0
    @State private var repeatScale: CGFloat = 1.0
    @State private var playPauseScale: CGFloat = 1.0

    // Breathing animation state
    @State private var breathingScale: CGFloat = 1.0
    @State private var artworkRotation: Double = 0

    // Haptic feedback generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium animated background - UNIFIED ARCHITECTURE: context-aware
                PlayerBackground(
                    category: displayTrack.category,
                    theme: audioEngine.playbackContext?.theme
                )
                .ignoresSafeArea()

                // Main scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Premium header with frosted glass
                        premiumHeader
                            .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : 20)

                        // Premium preview banner
                        if isPremiumPreview {
                            premiumPreviewBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Breathing artwork animation
                        breathingArtwork
                            .padding(.top, 24)

                        // Track info with premium styling
                        premiumTrackInfo
                            .padding(.top, 16)

                        // Progress bar with haptics
                        premiumProgressBar

                        // Controls with enhanced animations
                        controls

                        // Additional controls (Queue, More, Timer)
                        additionalControls

                        // Bottom safe area padding
                        Spacer()
                            .frame(height: max(geometry.safeAreaInsets.bottom, 20) + 80)
                    }
                }

                // Floating "It Helped!" button - positioned bottom right
                // Quick tap: uses auto-detected cry type or unknown
                // Long press: shows manual cry type picker
                if audioEngine.currentTrack != nil && (audioEngine.playbackState.isPlaying || audioEngine.playbackState == .paused) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ItHelpedButton {
                                recordItHelped()
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Haptic feedback
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                activeSheet = .cryTypePicker
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 16)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Success toast overlay
                if showingItHelpedToast {
                    SuccessToast(
                        message: "Noted! We'll remember this worked",
                        isShowing: $showingItHelpedToast
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        // Consolidated sheet - single modifier for all sheets
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(isPresented: $showingQueue) {
            PlaybackQueueView(queueManager: playbackQueueManager)
        }
        .onAppear {
            // Prepare haptics
            impactLight.prepare()
            impactMedium.prepare()
            selectionFeedback.prepare()
        }
        .onChange(of: audioEngine.playbackState) { newState in
            let oldState = previousPlaybackState
            previousPlaybackState = newState

            // Track when playback starts
            if newState == .playing && oldState != .playing {
                playbackStartTime = Date()
                lastPlayedTrack = audioEngine.currentTrack

                // Record play in EffectivenessManager for analytics
                if let track = audioEngine.currentTrack {
                    let cryType = cryDetectionService.isMonitoring ? cryDetectionService.cryType : nil
                    effectivenessManager.recordPlay(track: track, cryType: cryType)

                    // Check if this is a premium track for free user
                    checkAndStartPremiumPreview(for: track)
                }
            }

            // Show effectiveness feedback when playback stops after significant duration
            if oldState == .playing && newState == .stopped {
                // Stop premium preview timer
                stopPreviewTimer()

                if let startTime = playbackStartTime,
                   Date().timeIntervalSince(startTime) > 30, // At least 30 seconds
                   let track = lastPlayedTrack {
                    // Delay slightly to let UI settle
                    let duration = Date().timeIntervalSince(startTime)
                    let cryType = cryDetectionService.cryType ?? .unknown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        activeSheet = .effectivenessFeedback(track: track, cryType: cryType, duration: duration)
                    }
                }
            }
        }
        .onChange(of: audioEngine.currentTrack?.id) { _ in
            // When track changes, reset premium preview state
            if let track = audioEngine.currentTrack {
                checkAndStartPremiumPreview(for: track)
            } else {
                stopPreviewTimer()
                withAnimation {
                    isPremiumPreview = false
                }
            }
        }
        .onDisappear {
            stopPreviewTimer()
        }
    }

    // MARK: - Premium Header with Frosted Glass
    private var premiumHeader: some View {
        HStack {
            // Dismiss button with frosted background
            Button {
                impactLight.impactOccurred()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                }
            }

            Spacer()

            // Now playing info with glass effect
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1.5)

                if let playlist = audioEngine.currentPlaylist {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.appText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )

            Spacer()

            // Actions with frosted background
            HStack(spacing: 8) {
                // Favorite button
                if let track = audioEngine.currentTrack {
                    Button {
                        impactLight.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            favoritesManager.toggleFavorite(track: track)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)

                            Image(systemName: favoritesManager.isFavorite(track: track) ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(favoritesManager.isFavorite(track: track) ? .appAccentCoral : .appText)
                                .scaleEffect(favoritesManager.isFavorite(track: track) ? 1.1 : 1.0)
                        }
                    }
                }

                // More options menu
                Menu {
                    Button {
                        activeSheet = .playlist
                    } label: {
                        Label("View Playlist", systemImage: "list.bullet")
                    }

                    Button {
                        showingQueue = true
                    } label: {
                        Label("Up Next Queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }

                    Divider()

                    Button {
                        activeSheet = .timer
                    } label: {
                        Label("Sleep Timer", systemImage: "moon.zzz")
                    }

                    if let track = audioEngine.currentTrack, track.audioSourceType == .streamed {
                        let downloadState = downloadManager.getDownloadState(for: track.id.uuidString)
                        if downloadState.isDownloaded {
                            Button(role: .destructive) {
                                downloadManager.deleteCachedTrack(trackId: track.id.uuidString)
                            } label: {
                                Label("Remove Download", systemImage: "trash")
                            }
                        } else if !downloadState.isDownloading {
                            Button {
                                Task {
                                    try? await downloadManager.downloadTrack(track)
                                }
                            } label: {
                                Label("Download for Offline", systemImage: "arrow.down.circle")
                            }
                        }
                    }

                    Button {
                        activeSheet = .downloads
                    } label: {
                        Label("Manage Downloads", systemImage: "arrow.down.circle.fill")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 40, height: 40)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appText)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Breathing Artwork Animation
    private var breathingArtwork: some View {
        ZStack {
            // Outer glow pulse
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.forCategory(displayTrack.category).opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 180
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(breathingScale * 1.1)
                .opacity(audioEngine.playbackState.isPlaying ? 0.8 : 0.3)

            // Shadow layer
            Circle()
                .fill(Color.forCategory(displayTrack.category).opacity(0.2))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(y: 20)
                .scaleEffect(breathingScale)

            // Main artwork circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.forCategory(displayTrack.category).opacity(0.3),
                            Color.forCategory(displayTrack.category).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(breathingScale)

            // Inner circle with frosted glass
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
                .scaleEffect(breathingScale)

            // Buffering or icon
            if audioEngine.isBuffering {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.8)
                        .tint(Color.forCategory(displayTrack.category))

                    Text("Loading...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                // Custom category icon or waveform
                ZStack {
                    if audioEngine.playbackState.isPlaying {
                        // Animated waveform bars
                        WaveformVisualization(category: displayTrack.category)
                    } else {
                        Image(systemName: displayTrack.category.icon)
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.forCategory(displayTrack.category),
                                        Color.forCategory(displayTrack.category).opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .scaleEffect(breathingScale)
            }

            // Rotating ring animation when playing
            if audioEngine.playbackState.isPlaying {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.forCategory(displayTrack.category),
                                Color.forCategory(displayTrack.category).opacity(0.1),
                                Color.forCategory(displayTrack.category).opacity(0.3),
                                Color.forCategory(displayTrack.category)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 270, height: 270)
                    .rotationEffect(.degrees(artworkRotation))
            }

            // Buffer progress ring
            if audioEngine.bufferProgress > 0 && audioEngine.bufferProgress < 1 {
                Circle()
                    .trim(from: 0, to: CGFloat(audioEngine.bufferProgress))
                    .stroke(
                        Color.appTextSecondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 275, height: 275)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(.horizontal, 40)
        // FIX: Use task with ID to prevent animation restart on rotation
        // Rotation causes view rebuild which triggers onAppear, restarting animations
        // Using task with stable ID ensures animation only starts once
        .task(id: "breathing-animation") {
            // Only start if not already animating (scale is still at initial value)
            if breathingScale == 1.0 {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    breathingScale = 1.03
                }
            }
        }
        .task(id: "rotation-animation") {
            // Only start if not already animating (rotation is still at initial value)
            if artworkRotation == 0 {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    artworkRotation = 360
                }
            }
        }
    }

    // Animation functions kept for potential future use but no longer called on every appear
    private func startBreathingAnimation() {
        guard breathingScale == 1.0 else { return } // Prevent restart
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathingScale = 1.03
        }
    }

    private func startRotationAnimation() {
        guard artworkRotation == 0 else { return } // Prevent restart
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            artworkRotation = 360
        }
    }

    // MARK: - Premium Track Info
    private var premiumTrackInfo: some View {
        VStack(spacing: 12) {
            // Track title with gradient
            Text(displayTrack.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appText, .appText.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Artist and language
            HStack(spacing: 8) {
                Text(displayTrack.artist)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)

                if let language = displayTrack.language {
                    Text(language.flag)
                        .font(.system(size: 16))
                }
            }

            // Track info badges
            HStack(spacing: 10) {
                // Age badge with gradient border
                PlayerInfoBadge(
                    icon: "person.crop.circle",
                    text: "\(displayTrack.ageRangeMin)-\(displayTrack.ageRangeMax)m",
                    color: .appPrimary
                )

                // Source badge
                let downloadState = downloadManager.getDownloadState(for: displayTrack.id.uuidString)
                if downloadState.isDownloaded {
                    PlayerInfoBadge(
                        icon: "checkmark.circle.fill",
                        text: "Offline",
                        color: .appAccentMint
                    )
                } else if case .downloading(let progress) = downloadState {
                    PlayerInfoBadge(
                        icon: "arrow.down.circle",
                        text: "\(Int(progress * 100))%",
                        color: .appSecondary
                    )
                } else {
                    PlayerInfoBadge(
                        icon: displayTrack.audioSourceType == .generated ? "waveform" : "wifi",
                        text: displayTrack.sourceDescription,
                        color: .appTextSecondary
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    // MARK: - Premium Progress Bar with Haptics
    private var premiumProgressBar: some View {
        VStack(spacing: 8) {
            // Custom progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.appTextSecondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.forCategory(displayTrack.category),
                                    Color.forCategory(displayTrack.category).opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(in: geometry), height: 6)

                    // Scrubber knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .offset(x: progressWidth(in: geometry) - 8)
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let time = progress * audioEngine.duration
                            audioEngine.seek(to: time)
                            selectionFeedback.selectionChanged()
                        }
                )
            }
            .frame(height: 16)

            // Time labels with premium styling
            HStack {
                Text(formatTime(audioEngine.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.appTextSecondary)

                Spacer()

                Text("-\(formatTime(audioEngine.duration - audioEngine.currentTime))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        let progress = audioEngine.duration > 0 ? audioEngine.currentTime / audioEngine.duration : 0
        return geometry.size.width * CGFloat(progress)
    }

    // MARK: - Legacy Header (keeping for reference)
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appTextSecondary)

                if let playlist = audioEngine.currentPlaylist {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appText)
                }
            }

            Spacer()

            // Favorite button - prominent placement
            if let track = audioEngine.currentTrack {
                Button {
                    favoritesManager.toggleFavorite(track: track)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(track: track) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(favoritesManager.isFavorite(track: track) ? .appSecondary : .appText)
                        .frame(width: 44, height: 44)
                }
            }

            Menu {
                Button {
                    activeSheet = .playlist
                } label: {
                    Label("View Playlist", systemImage: "list.bullet")
                }

                Button {
                    if let track = audioEngine.currentTrack {
                        favoritesManager.toggleFavorite(track: track)
                    }
                } label: {
                    if let track = audioEngine.currentTrack, favoritesManager.isFavorite(track: track) {
                        Label("Remove from Favorites", systemImage: "heart.slash")
                    } else {
                        Label("Add to Favorites", systemImage: "heart")
                    }
                }

                Button {
                    activeSheet = .timer
                } label: {
                    Label("Sleep Timer", systemImage: "timer")
                }

                Divider()

                if let track = audioEngine.currentTrack, track.audioSourceType == .streamed {
                    let downloadState = downloadManager.getDownloadState(for: track.id.uuidString)
                    if downloadState.isDownloaded {
                        Button(role: .destructive) {
                            downloadManager.deleteCachedTrack(trackId: track.id.uuidString)
                        } label: {
                            Label("Remove Download", systemImage: "trash")
                        }
                    } else if !downloadState.isDownloading {
                        Button {
                            Task {
                                try? await downloadManager.downloadTrack(track)
                            }
                        } label: {
                            Label("Download for Offline", systemImage: "arrow.down.circle")
                        }
                    }
                }

                Button {
                    activeSheet = .downloads
                } label: {
                    Label("Manage Downloads", systemImage: "arrow.down.circle.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Artwork
    private var artwork: some View {
        ZStack {
            // Shadow layer
            Circle()
                .fill(Color.forCategory(displayTrack.category).opacity(0.3))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(y: 20)

            // Main circle
            Circle()
                .fill(Color.forCategory(displayTrack.category).opacity(0.15))
                .frame(width: 260, height: 260)

            // Inner circle with icon
            Circle()
                .fill(Color.white)
                .frame(width: 180, height: 180)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Show buffering indicator or track icon
            if audioEngine.isBuffering {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Buffering...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: displayTrack.category.icon)
                    .font(.system(size: 70))
                    .foregroundColor(Color.forCategory(displayTrack.category))
            }

            // Rotating ring animation when playing
            if audioEngine.playbackState.isPlaying {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.forCategory(displayTrack.category),
                                Color.forCategory(displayTrack.category).opacity(0.3),
                                Color.forCategory(displayTrack.category)
                            ],
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 270, height: 270)
                    .rotationEffect(.degrees(audioEngine.currentTime.truncatingRemainder(dividingBy: 360)))
                    .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: audioEngine.currentTime)
            }

            // Buffer progress ring when streaming
            if audioEngine.bufferProgress > 0 && audioEngine.bufferProgress < 1 {
                Circle()
                    .trim(from: 0, to: CGFloat(audioEngine.bufferProgress))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 275, height: 275)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Track Info
    private var trackInfo: some View {
        VStack(spacing: 8) {
            Text(displayTrack.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text(displayTrack.artist)
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)

                if let language = displayTrack.language {
                    Text(language.flag)
                        .font(.system(size: 16))
                }
            }

            // Source and download indicator
            let track = displayTrack
            Group {
                HStack(spacing: 12) {
                    // Age appropriateness badge
                    Text("Ages \(track.ageRangeMin)-\(track.ageRangeMax) months")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appPrimary.opacity(0.1))
                        )

                    // Source indicator
                    HStack(spacing: 4) {
                        let downloadState = downloadManager.getDownloadState(for: track.id.uuidString)
                        if downloadState.isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                            Text("Offline")
                        } else if case .downloading(let progress) = downloadState {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 10))
                            Text("\(Int(progress * 100))%")
                        } else {
                            Image(systemName: track.audioSourceType == .generated ? "waveform" : "wifi")
                                .font(.system(size: 10))
                            Text(track.sourceDescription)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appTextSecondary.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            // Slider with scrubbing state management
            // CRITICAL FIX: Use onEditingChanged to prevent time observer from fighting with user drag
            Slider(
                value: Binding(
                    get: { audioEngine.currentTime },
                    set: { audioEngine.seek(to: $0) }
                ),
                in: 0...max(1, audioEngine.duration),
                onEditingChanged: { editing in
                    audioEngine.isScrubbing = editing
                }
            )
            .accentColor(Color.forCategory(displayTrack.category))

            // Time labels
            HStack {
                Text(formatTime(audioEngine.currentTime))
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)

                Spacer()

                Text("-\(formatTime(audioEngine.duration - audioEngine.currentTime))")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    // MARK: - Controls
    private var controls: some View {
        VStack(spacing: 16) {
            // Main playback controls row
            HStack(spacing: 0) {
                // Shuffle - Spotify-style with dot indicator
                shuffleButton
                    .frame(maxWidth: .infinity)

                // Skip backward 15s
                Button {
                    impactLight.impactOccurred()
                    audioEngine.skipBackward(seconds: 15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.appText)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("skipBackward15Button")

                // Previous
                Button {
                    impactLight.impactOccurred()
                    audioEngine.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.appText)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("previousButton")

                // Play/Pause - Large center button with animation
                playPauseButton
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("playPauseButton")

                // Next
                Button {
                    impactLight.impactOccurred()
                    audioEngine.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.appText)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("nextButton")

                // Skip forward 15s
                Button {
                    impactLight.impactOccurred()
                    audioEngine.skipForward(seconds: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.appText)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("skipForward15Button")

                // Repeat - Spotify-style with mode indicator
                repeatButton
                    .frame(maxWidth: .infinity)
            }

            // Playback speed control row
            HStack(spacing: 16) {
                Spacer()

                // Playback speed button
                Button {
                    selectionFeedback.selectionChanged()
                    audioEngine.cyclePlaybackRate()
                } label: {
                    HStack(spacing: 4) {
                        Text(formatPlaybackRate(audioEngine.playbackRate))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(audioEngine.playbackRate != 1.0 ? .appPrimary : .appTextSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(audioEngine.playbackRate != 1.0 ? Color.appPrimary.opacity(0.15) : Color.appTextSecondary.opacity(0.1))
                    )
                }
                .accessibilityIdentifier("playbackSpeedButton")

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private func formatPlaybackRate(_ rate: Float) -> String {
        if rate == 1.0 {
            return "1x"
        } else if rate == 0.75 {
            return "0.75x"
        } else if rate == 1.25 {
            return "1.25x"
        } else if rate == 1.5 {
            return "1.5x"
        } else if rate == 2.0 {
            return "2x"
        } else {
            return String(format: "%.2fx", rate)
        }
    }

    // MARK: - Shuffle Button (Spotify-style)
    private var shuffleButton: some View {
        Button {
            selectionFeedback.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                shuffleScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    shuffleScale = 1.0
                }
            }
            audioEngine.toggleShuffle()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: audioEngine.isShuffleEnabled ? .semibold : .regular))
                    .foregroundColor(audioEngine.isShuffleEnabled ? .appPrimary : .appTextSecondary)

                // Active dot indicator (Spotify-style)
                Circle()
                    .fill(audioEngine.isShuffleEnabled ? Color.appPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .scaleEffect(shuffleScale)
        }
        .disabled(audioEngine.currentPlaylist == nil)
        .opacity(audioEngine.currentPlaylist == nil ? 0.4 : 1)
        .accessibilityIdentifier("shuffleButton")
    }

    // MARK: - Play/Pause Button
    private var playPauseButton: some View {
        Button {
            impactMedium.impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                playPauseScale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    playPauseScale = 1.0
                }
            }
            if audioEngine.playbackState.isPlaying {
                audioEngine.pause()
            } else if audioEngine.playbackState == .paused {
                // Resume from paused state
                audioEngine.resume()
            } else if let track = audioEngine.currentTrack {
                // Stopped state with a track - replay it
                audioEngine.play(track: track)
            } else {
                // No track loaded, just try resume (will be no-op)
                audioEngine.resume()
            }
        } label: {
            ZStack {
                // Outer glow when playing
                if audioEngine.playbackState.isPlaying {
                    Circle()
                        .fill(Color.forCategory(displayTrack.category).opacity(0.3))
                        .frame(width: 82, height: 82)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(Color.forCategory(displayTrack.category))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.forCategory(displayTrack.category).opacity(0.4),
                            radius: 8, y: 4)

                Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: audioEngine.playbackState.isPlaying ? 0 : 2)
            }
            .scaleEffect(playPauseScale)
        }
    }

    // MARK: - Repeat Button (Spotify-style with all modes)
    private var repeatButton: some View {
        Button {
            selectionFeedback.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                repeatScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    repeatScale = 1.0
                }
            }
            audioEngine.cycleRepeatMode()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: audioEngine.repeatMode.icon)
                        .font(.system(size: 20, weight: audioEngine.repeatMode.isActive ? .semibold : .regular))
                        .foregroundColor(audioEngine.repeatMode.isActive ? .appPrimary : .appTextSecondary)

                    // "1" badge for repeat one mode (already in SF Symbol)
                }

                // Active dot indicator
                Circle()
                    .fill(audioEngine.repeatMode.isActive ? Color.appPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .scaleEffect(repeatScale)
        }
        .accessibilityIdentifier("repeatButton")
    }

    // MARK: - Additional Controls
    private var additionalControls: some View {
        VStack(spacing: 16) {
            // Volume slider
            HStack(spacing: 12) {
                Button {
                    audioEngine.toggleMute()
                } label: {
                    Image(systemName: audioEngine.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 14))
                        .foregroundColor(audioEngine.isMuted ? .appPrimary : .appTextSecondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(audioEngine.volume) },
                        set: { audioEngine.setVolume(Float($0)) }
                    ),
                    in: 0...1.0
                )
                .accentColor(.appTextSecondary)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            // Bottom row: Queue, More Like This, Timer
            HStack(spacing: 24) {
                Spacer()

                // Queue button with count badge
                Button {
                    showingQueue = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16))

                        if audioEngine.remainingTracksCount > 0 {
                            Text("\(audioEngine.remainingTracksCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.appPrimary)
                                )
                        }
                    }
                    .foregroundColor(.appTextSecondary)
                }

                // More Like This button
                Button {
                    loadRelatedTracks()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                        Text("More")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.appTextSecondary)
                }

                // Sleep timer
                Button {
                    activeSheet = .timer
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 16))

                        if audioEngine.sleepTimer != .off {
                            Text(formatTime(audioEngine.sleepTimerRemaining))
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .foregroundColor(audioEngine.sleepTimer == .off ? .appTextSecondary : .appPrimary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
    }

    // MARK: - Load Related Tracks

    /// Loads tracks similar to the current playing track
    private func loadRelatedTracks() {
        guard let track = audioEngine.currentTrack else { return }

        isLoadingRelated = true
        activeSheet = .moreLikeThis

        Task {
            do {
                let response = try await APIClient.shared.getRelatedTracks(trackId: track.id.uuidString, limit: 10)
                await MainActor.run {
                    relatedTracks = response.relatedTracks
                    isLoadingRelated = false
                }
            } catch {
                print("Failed to load related tracks: \(error)")
                await MainActor.run {
                    isLoadingRelated = false
                }
            }
        }
    }

    // MARK: - It Helped! Action

    /// Records that the current track helped calm the baby
    /// - Parameter withCryType: Manually selected cry type (nil = auto-detect from service)
    private func recordItHelped(withCryType manualCryType: CryType? = nil) {
        guard let track = audioEngine.currentTrack else { return }

        // Use manual cry type if provided, otherwise get from detection service
        let cryType: CryType?
        if let manual = manualCryType {
            cryType = manual
        } else {
            cryType = cryDetectionService.isMonitoring ? cryDetectionService.cryType : nil
        }

        // Record in EffectivenessManager
        effectivenessManager.recordHelped(track: track, cryType: cryType)

        // Trigger engagement event for freemium upgrade prompts
        // "Your baby loves this! Get more tracks like the ones that work"
        EngagementTriggerService.shared.recordItHelpedFeedback()

        // Show success toast
        withAnimation(.spring(response: 0.3)) {
            showingItHelpedToast = true
        }
    }

    // MARK: - Premium Preview Banner
    private var premiumPreviewBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Premium Preview")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Text("\(Int(previewTimeRemaining))s remaining")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Skip to free button
            Button {
                impactLight.impactOccurred()
                skipToNextFreeTrack()
            } label: {
                Text("Skip to Free")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.appPrimary, Color.appSecondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Premium Preview Logic

    /// Checks if track is premium and starts preview timer if needed
    private func checkAndStartPremiumPreview(for track: AudioTrack) {
        // Don't show preview during cry detection - safety first!
        guard !cryDetectionService.isMonitoring else {
            withAnimation {
                isPremiumPreview = false
            }
            return
        }

        // Check if this is a premium track that needs preview limiting
        if !gatekeeper.canPlayTrack(track) {
            // This is a premium track - start preview mode
            startPremiumPreview()
        } else {
            // Free track - no preview needed
            stopPreviewTimer()
            withAnimation {
                isPremiumPreview = false
            }
        }
    }

    /// Starts the 10-second premium preview timer
    private func startPremiumPreview() {
        previewTimeRemaining = 10
        withAnimation {
            isPremiumPreview = true
        }

        // Start countdown timer
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            previewTimeRemaining -= 1

            if previewTimeRemaining <= 0 {
                timer.invalidate()
                previewTimer = nil
                endPremiumPreview()
            }
        }
    }

    /// Stops the preview timer
    private func stopPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = nil
    }

    /// Called when preview ends - shows soft paywall
    private func endPremiumPreview() {
        // Pause playback
        audioEngine.pause()

        // Don't show paywall during cry detection!
        guard !cryDetectionService.isMonitoring else {
            skipToNextFreeTrack()
            return
        }

        // Show soft paywall
        if let track = audioEngine.currentTrack {
            activeSheet = .softPaywall(track: track)
        }

        withAnimation {
            isPremiumPreview = false
        }
    }

    /// Skips to the next available free track in the playlist
    private func skipToNextFreeTrack() {
        withAnimation {
            isPremiumPreview = false
        }
        stopPreviewTimer()

        // Find next free track in current playlist
        if let playlist = audioEngine.currentPlaylist {
            let currentIndex = audioEngine.currentPlaylistIndex
            let tracks = playlist.tracks

            // Search from current position forward
            for i in (currentIndex + 1)..<tracks.count {
                if gatekeeper.canPlayTrack(tracks[i]) {
                    audioEngine.play(playlist: playlist, startIndex: i)
                    return
                }
            }

            // Wrap around and search from beginning
            for i in 0..<currentIndex {
                if gatekeeper.canPlayTrack(tracks[i]) {
                    audioEngine.play(playlist: playlist, startIndex: i)
                    return
                }
            }
        }

        // No free tracks found, just go to next
        audioEngine.next()
    }

    // MARK: - Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for sheet: PlayerSheet) -> some View {
        switch sheet {
        case .timer:
            TimerPickerSheet()
        case .playlist:
            PlaylistSheet()
        case .downloads:
            DownloadsManagerView()
        case .effectivenessFeedback(let track, let cryType, let duration):
            EffectivenessFeedbackSheet(
                track: track,
                cryType: cryType,
                playbackDuration: duration
            )
        case .cryTypePicker:
            CryTypePickerSheet { selectedCryType in
                recordItHelped(withCryType: selectedCryType)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        case .moreLikeThis:
            MoreLikeThisSheet(
                relatedTracks: relatedTracks,
                isLoading: isLoadingRelated,
                currentTrack: audioEngine.currentTrack
            )
            .environmentObject(audioEngine)
        case .softPaywall(let track):
            SoftPaywallSheet(
                track: track,
                onUpgrade: {
                    // Navigate to subscription screen
                    activeSheet = nil
                },
                onDismiss: {
                    activeSheet = nil
                    // Skip to next free track
                    skipToNextFreeTrack()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timer Picker Sheet
struct TimerPickerSheet: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(SleepTimer.allCases) { timer in
                    Button {
                        audioEngine.setSleepTimer(timer)
                        dismiss()
                    } label: {
                        HStack {
                            Text(timer.displayName)
                                .foregroundColor(.appText)

                            Spacer()

                            if audioEngine.sleepTimer == timer {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Playlist Sheet
struct PlaylistSheet: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if let playlist = audioEngine.currentPlaylist {
                    List {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            Button {
                                audioEngine.play(playlist: playlist, startIndex: index)
                            } label: {
                                HStack(spacing: 12) {
                                    // Track number or playing indicator
                                    if audioEngine.currentPlaylistIndex == index {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appPrimary)
                                            .frame(width: 24)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appTextSecondary)
                                            .frame(width: 24)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.system(size: 15, weight: audioEngine.currentPlaylistIndex == index ? .semibold : .regular))
                                            .foregroundColor(audioEngine.currentPlaylistIndex == index ? .appPrimary : .appText)

                                        Text(track.formattedDuration)
                                            .font(.system(size: 12))
                                            .foregroundColor(.appTextSecondary)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.appTextSecondary)

                        Text("No playlist playing")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Queue Sheet (Spotify-style)
struct QueueSheet: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Now Playing Section
                if let currentTrack = audioEngine.currentTrack {
                    Section {
                        NowPlayingRow(track: currentTrack, isPlaying: audioEngine.playbackState.isPlaying)
                    } header: {
                        Text("Now Playing")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                    }
                }

                // Up Next Queue (manually added tracks)
                if !audioEngine.upNextQueue.isEmpty {
                    Section {
                        ForEach(Array(audioEngine.upNextQueue.enumerated()), id: \.element.id) { index, track in
                            SimpleQueueTrackRow(track: track, position: index + 1)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        audioEngine.removeFromQueue(at: index)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove { source, destination in
                            // Handle reordering
                            for index in source {
                                audioEngine.moveInQueue(from: index, to: destination > index ? destination - 1 : destination)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Next in Queue")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.appTextSecondary)

                            Spacer()

                            Button("Clear") {
                                audioEngine.clearQueue()
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.appPrimary)
                        }
                    }
                }

                // Next From Playlist
                if let playlist = audioEngine.currentPlaylist {
                    let remainingTracks = getRemainingPlaylistTracks(playlist: playlist)
                    if !remainingTracks.isEmpty {
                        Section {
                            ForEach(Array(remainingTracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                                SimpleQueueTrackRow(track: track, position: index + 1)
                                    .contextMenu {
                                        Button {
                                            audioEngine.playNext(track)
                                        } label: {
                                            Label("Play Next", systemImage: "text.insert")
                                        }
                                    }
                            }

                            if remainingTracks.count > 10 {
                                Text("+ \(remainingTracks.count - 10) more tracks")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appTextSecondary)
                            }
                        } header: {
                            HStack {
                                Text("Next from: \(playlist.name)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appTextSecondary)

                                if audioEngine.isShuffleEnabled {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 11))
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                    }
                }

                // Empty state
                if audioEngine.currentTrack == nil {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36))
                                .foregroundColor(.appTextSecondary)

                            Text("Nothing in queue")
                                .font(.system(size: 16))
                                .foregroundColor(.appTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func getRemainingPlaylistTracks(playlist: Playlist) -> [AudioTrack] {
        if audioEngine.isShuffleEnabled {
            // In shuffle mode, we don't know the exact order, just return remaining count
            // For display purposes, show tracks not yet played
            return []
        } else {
            let startIndex = audioEngine.currentPlaylistIndex + 1
            guard startIndex < playlist.tracks.count else { return [] }
            return Array(playlist.tracks[startIndex...])
        }
    }
}

// MARK: - Queue Row Components
struct NowPlayingRow: View {
    let track: AudioTrack
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Animated equalizer icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.forCategory(track.category).opacity(0.15))
                    .frame(width: 48, height: 48)

                if isPlaying {
                    EqualizerView()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: track.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color.forCategory(track.category))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Simple Queue Track Row (for PlayerView's QueueSheet)
/// Simple queue track row without effectiveness tracking (for up-next queue display)
struct SimpleQueueTrackRow: View {
    let track: AudioTrack
    let position: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text("\(track.artist) • \(track.formattedDuration)")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - Equalizer Animation View
struct EqualizerView: View {
    @State private var heights: [CGFloat] = [0.3, 0.5, 0.7, 0.4]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.appPrimary)
                    .frame(width: 3, height: 20 * heights[index])
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                heights = [0.7, 0.4, 0.5, 0.8]
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    heights = [0.4, 0.8, 0.3, 0.6]
                }
            }
        }
    }
}

// ScaleButtonStyle moved to ButtonStyles.swift to avoid redeclaration

// MARK: - Effectiveness Feedback Sheet
/// Prompts user to rate how effective the track was at soothing their baby
/// This feedback trains the ML recommendation engine for personalized suggestions
struct EffectivenessFeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var babyProfileManager = BabyProfileManager.shared
    @StateObject private var analyticsCloudService = AnalyticsCloudService.shared
    @StateObject private var effectivenessManager = EffectivenessManager.shared

    let track: AudioTrack
    let cryType: CryType
    let playbackDuration: TimeInterval

    @State private var selectedRating: EffectivenessRating?
    @State private var showingThankYou = false
    @State private var showingInsights = false

    enum EffectivenessRating: String, CaseIterable {
        case veryEffective = "Very Effective"
        case effective = "Worked Well"
        case partiallyEffective = "Somewhat Helped"
        case notEffective = "Didn't Help"

        var icon: String {
            switch self {
            case .veryEffective: return "star.fill"
            case .effective: return "hand.thumbsup.fill"
            case .partiallyEffective: return "hand.raised.fill"
            case .notEffective: return "hand.thumbsdown.fill"
            }
        }

        var color: Color {
            switch self {
            case .veryEffective: return .yellow
            case .effective: return .green
            case .partiallyEffective: return .orange
            case .notEffective: return .red
            }
        }

        var wasEffective: Bool {
            switch self {
            case .veryEffective, .effective: return true
            case .partiallyEffective, .notEffective: return false
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if showingThankYou {
                    thankYouView
                } else {
                    feedbackPromptView
                }
            }
            .padding()
            .navigationTitle("How Did It Work?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var feedbackPromptView: some View {
        VStack(spacing: 24) {
            // Track info
            VStack(spacing: 8) {
                Image(systemName: track.category.icon)
                    .font(.system(size: 40))
                    .foregroundColor(Color.forCategory(track.category))

                Text(track.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)

                Text("Played for \(formatDuration(playbackDuration))")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)

                if cryType != .unknown {
                    Text("During: \(cryType.rawValue) cry")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appPrimary.opacity(0.1))
                        )
                }
            }

            // Prompt text
            Text("Did this track help soothe your baby?")
                .font(.system(size: 16))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)

            // Rating buttons
            VStack(spacing: 12) {
                ForEach(EffectivenessRating.allCases, id: \.self) { rating in
                    Button {
                        selectedRating = rating
                        submitFeedback(rating: rating)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: rating.icon)
                                .font(.system(size: 20))
                                .foregroundColor(rating.color)
                                .frame(width: 32)

                            Text(rating.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.appText)

                            Spacer()

                            if selectedRating == rating {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedRating == rating ? Color.appPrimary.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedRating == rating ? Color.appPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }

            // Info text
            Text("Your feedback helps us recommend better tracks for your baby")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var thankYouView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.appPrimary)

            Text("Thank You!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)

            Text("Your feedback helps us learn what works best for your baby.")
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appPrimary)
                        )
                }

                if effectivenessManager.hasEffectivenessData {
                    Button {
                        showingInsights = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 14))
                            Text("View Insights")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.appPrimary)
                    }
                }
            }
            .padding(.top, 16)
        }
        .sheet(isPresented: $showingInsights) {
            InsightsView()
        }
    }

    private func submitFeedback(rating: EffectivenessRating) {
        // Record in EffectivenessManager (the new local effectiveness tracking system)
        if rating.wasEffective {
            effectivenessManager.recordHelped(track: track, cryType: cryType)
        }

        // Get active baby ID from UserDefaults or BabyProfileManager
        guard let babyData = UserDefaults.standard.data(forKey: "activeBaby"),
              let baby = try? JSONDecoder().decode(Baby.self, from: babyData) else {
            // No baby configured - still show thank you
            withAnimation {
                showingThankYou = true
            }
            return
        }

        let calmingTime = Int(playbackDuration)

        // Record locally in BabyProfileManager
        babyProfileManager.recordTrackEffectiveness(
            babyId: baby.id,
            trackId: track.id,
            cryType: cryType,
            wasEffective: rating.wasEffective,
            calmingTimeSeconds: calmingTime
        )

        // Optionally sync to cloud analytics
        Task {
            await analyticsCloudService.recordTrackEffectiveness(
                babyId: baby.id,
                trackId: track.id,
                cryType: cryType,
                wasEffective: rating.wasEffective,
                calmingTimeSeconds: calmingTime
            )
        }

        // Show thank you
        withAnimation {
            showingThankYou = true
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds) seconds"
    }
}

// MARK: - Player Background

/// Animated background for the player with category-specific colors
struct PlayerBackground: View {
    let category: AudioCategory
    let theme: PlayerTheme?  // UNIFIED ARCHITECTURE: Context-aware theming

    @State private var animateGradient = false
    @State private var floatingParticles: [FloatingParticle] = []

    init(category: AudioCategory, theme: PlayerTheme? = nil) {
        self.category = category
        self.theme = theme
    }

    var body: some View {
        ZStack {
            // Base gradient - uses theme if available, otherwise category color
            LinearGradient(
                colors: backgroundColors,
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )

            // Floating particles
            ForEach(floatingParticles) { particle in
                Circle()
                    .fill(Color.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: particle.blur)
            }

            // Soft overlay
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.1)],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
        }
        .onAppear {
            generateParticles()
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }

    private var backgroundColors: [Color] {
        // UNIFIED ARCHITECTURE: Use theme colors if available, otherwise category colors
        if let theme = theme {
            let gradient = theme.gradientColors
            return [
                Color.appBackground,
                gradient[0],
                Color.appBackground,
                gradient[1]
            ]
        } else {
            let baseColor = Color.forCategory(category)
            return [
                Color.appBackground,
                baseColor.opacity(0.15),
                Color.appBackground,
                baseColor.opacity(0.1)
            ]
        }
    }

    private func generateParticles() {
        floatingParticles = (0..<12).map { _ in
            FloatingParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                size: CGFloat.random(in: 20...80),
                opacity: Double.random(in: 0.02...0.08),
                blur: CGFloat.random(in: 10...30)
            )
        }
    }
}

struct FloatingParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var blur: CGFloat
}

// MARK: - Waveform Visualization

/// Animated waveform bars for playing state
struct WaveformVisualization: View {
    let category: AudioCategory

    @State private var heights: [CGFloat] = Array(repeating: 0.3, count: 7)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.forCategory(category),
                                Color.forCategory(category).opacity(0.6)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: 50 * heights[index])
            }
        }
        .frame(height: 50)
        .onAppear {
            animateBars()
        }
    }

    private func animateBars() {
        // Staggered animation for each bar
        for index in 0..<7 {
            let delay = Double(index) * 0.1
            withAnimation(
                .easeInOut(duration: Double.random(in: 0.4...0.8))
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                heights[index] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}

// MARK: - Player Info Badge

/// Reusable info badge component for player metadata display
/// Note: This is distinct from PremiumBadge in PremiumBadge.swift which handles freemium tier indicators
struct PlayerInfoBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))

            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Player View") {
    PlayerView()
        .environmentObject(AudioEngine.shared)
}

#Preview("Player Background") {
    PlayerBackground(category: .classicalMusic)
}

#Preview("Waveform Visualization") {
    ZStack {
        Color.appBackground
        WaveformVisualization(category: .instrumental)
    }
}

#Preview("Player Info Badge") {
    VStack(spacing: 16) {
        PlayerInfoBadge(icon: "person.crop.circle", text: "0-12m", color: .appPrimary)
        PlayerInfoBadge(icon: "checkmark.circle.fill", text: "Offline", color: .appAccentMint)
        PlayerInfoBadge(icon: "wifi", text: "Streaming", color: .appTextSecondary)
    }
    .padding()
    .background(Color.appBackground)
}

// MARK: - More Like This Sheet

/// Shows related tracks similar to the currently playing track
struct MoreLikeThisSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var audioEngine: AudioEngine

    let relatedTracks: [SearchTrack]
    let isLoading: Bool
    let currentTrack: AudioTrack?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finding similar tracks...")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if relatedTracks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundColor(.appTextSecondary)

                        Text("No similar tracks found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appText)

                        Text("Try playing a different track")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Info about what "similar" means
                            if let track = currentTrack {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 14))
                                    Text("Tracks similar to \"\(track.title)\"")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(.appTextSecondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }

                            // Track list
                            ForEach(relatedTracks) { track in
                                MoreLikeThisRow(track: track) {
                                    playTrack(track)
                                    dismiss()
                                } onAddToQueue: {
                                    addToQueue(track)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("More Like This")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func playTrack(_ track: SearchTrack) {
        // Convert SearchTrack to AudioTrack for playback
        let audioTrack = AudioTrack(
            id: UUID(uuidString: track.id) ?? UUID(),
            title: track.title,
            artist: track.artist,
            category: AudioCategory.fromJSONKey(track.category),
            language: Language(rawValue: track.language),
            duration: TimeInterval(track.duration),
            ageRangeMin: track.ageRangeMin,
            ageRangeMax: track.ageRangeMax,
            calmingScore: track.calmingScore,
            audioSourceType: AudioSourceType(rawValue: track.audioSourceType) ?? .streamed,
            streamURL: track.streamUrl,
            serverId: track.id  // Store original server ID for API calls
        )

        // Convert all related tracks to AudioTrack array for playlist context
        let allAudioTracks = relatedTracks.map { searchTrack in
            AudioTrack(
                id: UUID(uuidString: searchTrack.id) ?? UUID(),
                title: searchTrack.title,
                artist: searchTrack.artist,
                category: AudioCategory.fromJSONKey(searchTrack.category),
                language: Language(rawValue: searchTrack.language),
                duration: TimeInterval(searchTrack.duration),
                ageRangeMin: searchTrack.ageRangeMin,
                ageRangeMax: searchTrack.ageRangeMax,
                calmingScore: searchTrack.calmingScore,
                audioSourceType: AudioSourceType(rawValue: searchTrack.audioSourceType) ?? .streamed,
                streamURL: searchTrack.streamUrl,
                serverId: searchTrack.id
            )
        }

        // Play with AI recommendations as context for next/previous navigation
        audioEngine.play(track: audioTrack, fromTracks: allAudioTracks, contextName: "AI Recommendations")
    }

    private func addToQueue(_ track: SearchTrack) {
        let audioTrack = AudioTrack(
            id: UUID(uuidString: track.id) ?? UUID(),
            title: track.title,
            artist: track.artist,
            category: AudioCategory.fromJSONKey(track.category),
            language: Language(rawValue: track.language),
            duration: TimeInterval(track.duration),
            ageRangeMin: track.ageRangeMin,
            ageRangeMax: track.ageRangeMax,
            calmingScore: track.calmingScore,
            audioSourceType: AudioSourceType(rawValue: track.audioSourceType) ?? .streamed,
            streamURL: track.streamUrl,
            serverId: track.id  // Store original server ID for API calls
        )
        audioEngine.addToQueue(audioTrack)
    }
}

// MARK: - More Like This Row

struct MoreLikeThisRow: View {
    let track: SearchTrack
    let onPlay: () -> Void
    let onAddToQueue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Artwork placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor)
            }

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(.appTextSecondary)

                    Text(formatDuration(track.duration))
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }

                // Similarity indicators (themes)
                if let themes = track.taxonomies?.theme, !themes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(themes.prefix(2), id: \.self) { theme in
                            Text(theme)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.appPrimary.opacity(0.1))
                                )
                        }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Add to queue
                Button {
                    onAddToQueue()
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.appTextSecondary)
                }

                // Play button
                Button {
                    onPlay()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 2)
        )
    }

    private var categoryColor: Color {
        Color.forCategory(AudioCategory.fromJSONKey(track.category))
    }

    private var categoryIcon: String {
        AudioCategory.fromJSONKey(track.category).icon
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
