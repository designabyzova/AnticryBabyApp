//
//  PlaybackQueueView.swift
//  BabyInCarApp
//
//  World-class Spotify-like queue view for regular content playback
//  (music, fairy tales, podcasts - NOT emergency/cry mode)
//
//  Design Principles:
//  - Spotify-inspired dark theme with vibrant accents
//  - Clear "Now Playing" hero section
//  - Distinct "Up Next" (user-added) and "Playing From" (context) sections
//  - Drag-to-reorder support
//  - Smooth animations and haptic feedback
//  - AI-powered track suggestions
//

import SwiftUI
import UIKit

// MARK: - Main Queue View

struct PlaybackQueueView: View {
    @ObservedObject var queueManager: PlaybackQueueManager
    @State private var showingSuggestions = false
    @State private var draggedTrack: AudioTrack?
    @State private var animateNowPlaying = false
    @Environment(\.dismiss) private var dismiss

    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        ZStack {
            // Animated gradient background
            QueueBackgroundGradient(contextType: queueManager.contextType)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                queueHeader
                    .padding(.bottom, 8)

                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Now Playing Hero
                        if let currentTrack = queueManager.currentTrack {
                            NowPlayingHeroCard(
                                track: currentTrack,
                                progress: queueManager.currentProgress,
                                isPlaying: queueManager.isPlaying,
                                onPlayPause: {
                                    impactMedium.impactOccurred()
                                    queueManager.togglePlayPause()
                                },
                                onPrevious: {
                                    impactLight.impactOccurred()
                                    queueManager.previous()
                                },
                                onNext: {
                                    impactLight.impactOccurred()
                                    queueManager.next()
                                }
                            )
                            .padding(.horizontal, 20)
                        }

                        // Up Next Section (User-added)
                        if queueManager.hasUpNext {
                            upNextSection
                        }

                        // Playing From Section (Context)
                        if !queueManager.contextTracks.isEmpty {
                            playingFromSection
                        }

                        // Suggestions Section
                        suggestionsSection

                        // Bottom padding
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestionsSheet(queueManager: queueManager)
        }
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
            selectionFeedback.prepare()
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateNowPlaying = true
            }
        }
    }

    // MARK: - Header

    private var queueHeader: some View {
        HStack {
            // Close button
            Button {
                impactLight.impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Title with context info
            VStack(spacing: 4) {
                Text("QUEUE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2)

                HStack(spacing: 6) {
                    Image(systemName: queueManager.contextType.icon)
                        .font(.system(size: 12))
                    Text(queueManager.contextName)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Options menu
            Menu {
                Button {
                    queueManager.clearUpNext()
                } label: {
                    Label("Clear Up Next", systemImage: "trash")
                }

                Button {
                    showingSuggestions = true
                } label: {
                    Label("Add Suggestions", systemImage: "sparkles")
                }

                Divider()

                // Shuffle toggle
                Button {
                    queueManager.toggleShuffle()
                } label: {
                    Label(
                        queueManager.isShuffled ? "Shuffle Off" : "Shuffle On",
                        systemImage: queueManager.isShuffled ? "shuffle.circle.fill" : "shuffle"
                    )
                }

                // Repeat mode
                Button {
                    queueManager.cycleRepeatMode()
                } label: {
                    Label(
                        queueManager.repeatMode.displayName,
                        systemImage: queueManager.repeatMode.icon
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appAccentCoral)

                    Text("Up Next")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Track count
                Text("\(queueManager.upNextTracks.count) tracks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                // Clear button
                Button {
                    impactLight.impactOccurred()
                    queueManager.clearUpNext()
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appAccentCoral)
                }
            }
            .padding(.horizontal, 20)

            // Track list
            LazyVStack(spacing: 4) {
                ForEach(Array(queueManager.upNextTracks.enumerated()), id: \.element.id) { index, track in
                    QueueTrackRowView(
                        track: track,
                        position: index + 1,
                        isUpNext: true,
                        onTap: {
                            impactLight.impactOccurred()
                            queueManager.playFromUpNext(at: index)
                        },
                        onRemove: {
                            impactLight.impactOccurred()
                            queueManager.removeFromUpNext(at: index)
                        }
                    )
                }
                .onMove { source, destination in
                    queueManager.moveInUpNext(from: source, to: destination)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Playing From Section

    private var playingFromSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: queueManager.contextType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playing From")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Text(queueManager.contextName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Queue stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(queueManager.contextTracks.count) tracks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Text(queueManager.totalQueueDuration)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)

            // Track list (show max 10, with "show more")
            LazyVStack(spacing: 4) {
                ForEach(Array(queueManager.contextTracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                    QueueTrackRowView(
                        track: track,
                        position: index + 1 + queueManager.upNextTracks.count,
                        isUpNext: false,
                        onTap: {
                            impactLight.impactOccurred()
                            queueManager.playFromContext(at: index)
                        },
                        onRemove: {
                            impactLight.impactOccurred()
                            queueManager.removeFromContext(at: index)
                        }
                    )
                }

                // Show more indicator
                if queueManager.contextTracks.count > 10 {
                    HStack {
                        Spacer()
                        Text("+ \(queueManager.contextTracks.count - 10) more tracks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)

                    Text("Suggested for You")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    showingSuggestions = true
                } label: {
                    Text("See All")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 20)

            // Horizontal scroll of suggestions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(queueManager.getSuggestedTracks(limit: 6)) { track in
                        SuggestionCard(track: track) {
                            impactLight.impactOccurred()
                            queueManager.addToQueue(track)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Now Playing Hero Card

struct NowPlayingHeroCard: View {
    let track: AudioTrack
    let progress: Double
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @EnvironmentObject var audioEngine: AudioEngine
    @State private var animatePulse = false
    @State private var isDraggingProgress = false

    var body: some View {
        VStack(spacing: 16) {
            // Album art with glow
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.forCategory(track.category).opacity(0.4))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .scaleEffect(animatePulse ? 1.1 : 1.0)

                // Album card
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)

                    VStack(spacing: 8) {
                        Image(systemName: track.category.icon)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.9))

                        // Animated equalizer when playing
                        if isPlaying {
                            MiniEqualizerView()
                                .frame(height: 16)
                        }
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            }

            // Track info
            VStack(spacing: 6) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)

                Text(track.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    if FavoritesManager.shared.isFavorite(track: track) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.pink)
                    }
                }
            }

            // Progress bar - Interactive with drag gesture
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(.white)
                            .frame(width: max(0, geo.size.width * progress), height: 4)

                        // Scrubber knob
                        Circle()
                            .fill(.white)
                            .frame(width: isDraggingProgress ? 14 : 10, height: isDraggingProgress ? 14 : 10)
                            .offset(x: max(0, geo.size.width * progress - (isDraggingProgress ? 7 : 5)))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDraggingProgress)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingProgress = true
                                let progress = min(max(0, value.location.x / geo.size.width), 1)
                                let time = progress * audioEngine.duration
                                audioEngine.seek(to: time)
                            }
                            .onEnded { _ in
                                isDraggingProgress = false
                            }
                    )
                }
                .frame(height: 14)

                // Time labels
                HStack {
                    Text(formatTime(audioEngine.currentTime))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Text("-\(formatTime(audioEngine.duration - audioEngine.currentTime))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)

            // Controls
            HStack(spacing: 32) {
                // Previous
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Play/Pause
                Button(action: onPlayPause) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 56, height: 56)
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 4)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }

                // Next
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Queue Track Row

struct QueueTrackRowView: View {
    let track: AudioTrack
    let position: Int
    let isUpNext: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Position number
            Text("\(position)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 28)

            // Track icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.forCategory(track.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: track.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.forCategory(track.category))
            }

            // Track info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if FavoritesManager.shared.isFavorite(track: track) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.pink)
                    }

                    if isUpNext {
                        Text("Up Next")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.appAccentCoral)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.appAccentCoral.opacity(0.2))
                            )
                    }
                }

                HStack(spacing: 6) {
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))

                    Text(track.formattedDuration)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Play indicator
            Image(systemName: "play.circle")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(isPressed ? 0.08 : 0.04))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) { isPressed = false }
                onTap()
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let track: AudioTrack
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Album art
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                Image(systemName: track.category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Info
            VStack(spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(width: 80)

            // Add button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appPrimary)
            }
        }
    }
}

// MARK: - Queue Background Gradient

struct QueueBackgroundGradient: View {
    let contextType: PlaybackQueueManager.QueueContextType

    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )

            // Overlay particles
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .offset(x: -80, y: -200)
                .blur(radius: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }

    private var gradientColors: [Color] {
        switch contextType {
        case .playlist:
            return [Color(red: 0.25, green: 0.3, blue: 0.5), Color(red: 0.15, green: 0.15, blue: 0.3)]
        case .category:
            return [Color(red: 0.5, green: 0.2, blue: 0.4), Color(red: 0.3, green: 0.1, blue: 0.25)]
        case .album:
            return [Color(red: 0.2, green: 0.4, blue: 0.5), Color(red: 0.1, green: 0.25, blue: 0.35)]
        case .fairyTale:
            return [Color(red: 0.6, green: 0.3, blue: 0.2), Color(red: 0.4, green: 0.15, blue: 0.1)]
        case .podcast:
            return [Color(red: 0.4, green: 0.5, blue: 0.35), Color(red: 0.25, green: 0.3, blue: 0.2)]
        case .favorites:
            return [Color(red: 0.6, green: 0.2, blue: 0.3), Color(red: 0.4, green: 0.1, blue: 0.2)]
        case .recentlyPlayed:
            return [Color(red: 0.3, green: 0.3, blue: 0.45), Color(red: 0.2, green: 0.2, blue: 0.3)]
        case .search:
            return [Color(red: 0.2, green: 0.45, blue: 0.4), Color(red: 0.1, green: 0.3, blue: 0.25)]
        case .radio:
            return [Color(red: 0.55, green: 0.25, blue: 0.15), Color(red: 0.35, green: 0.15, blue: 0.1)]
        }
    }
}

// MARK: - Suggestions Sheet

struct SuggestionsSheet: View {
    @ObservedObject var queueManager: PlaybackQueueManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(queueManager.getSuggestedTracks(limit: 20)) { track in
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.forCategory(track.category).opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: track.category.icon)
                                .font(.system(size: 20))
                                .foregroundColor(Color.forCategory(track.category))
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Text(track.artist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text(track.formattedDuration)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Add buttons
                        HStack(spacing: 12) {
                            Button {
                                queueManager.playNext(track)
                            } label: {
                                Image(systemName: "text.insert")
                                    .font(.system(size: 16))
                                    .foregroundColor(.appPrimary)
                            }

                            Button {
                                queueManager.addToQueue(track)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Suggested Tracks")
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

// MARK: - Previews

#Preview("Queue View") {
    PlaybackQueueView(queueManager: PlaybackQueueManager.shared)
}

#Preview("Now Playing Card") {
    ZStack {
        Color.black.ignoresSafeArea()

        NowPlayingHeroCard(
            track: AudioTrack(
                title: "Moonlight Sonata",
                artist: "Classical Collection",
                category: .classicalMusic,
                duration: 300,
                audioSourceType: .bundled
            ),
            progress: 0.35,
            isPlaying: true,
            onPlayPause: {},
            onPrevious: {},
            onNext: {}
        )
        .padding(20)
    }
}

#Preview("Queue Track Row") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 8) {
            QueueTrackRowView(
                track: AudioTrack(
                    title: "Brahms Lullaby",
                    artist: "Classical Masters",
                    category: .classicalMusic,
                    duration: 180,
                    audioSourceType: .bundled
                ),
                position: 1,
                isUpNext: true,
                onTap: {},
                onRemove: {}
            )

            QueueTrackRowView(
                track: AudioTrack(
                    title: "Ocean Waves",
                    artist: "Nature Sounds",
                    category: .natureSounds,
                    duration: 600,
                    audioSourceType: .bundled
                ),
                position: 2,
                isUpNext: false,
                onTap: {},
                onRemove: {}
            )
        }
        .padding()
    }
}
