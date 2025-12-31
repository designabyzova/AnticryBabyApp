//
//  PlayerView.swift
//  BabyInCarApp
//
//  Full screen audio player
//

import SwiftUI
import UIKit

struct PlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var downloadManager = AudioDownloadManager.shared
    @StateObject private var babyProfileManager = BabyProfileManager.shared
    @StateObject private var cryDetectionService = CryDetectionService.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingTimerPicker = false
    @State private var showingPlaylist = false
    @State private var showingDownloads = false
    @State private var showingQueue = false
    @State private var showingEffectivenessFeedback = false

    // Track playback state for feedback prompt
    @State private var lastPlayedTrack: AudioTrack?
    @State private var playbackStartTime: Date?

    // Animation states for controls
    @State private var shuffleScale: CGFloat = 1.0
    @State private var repeatScale: CGFloat = 1.0
    @State private var playPauseScale: CGFloat = 1.0

    // Haptic feedback generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on category
                LinearGradient(
                    colors: [
                        Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.3),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header - with proper safe area padding
                    header
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : 20)

                    Spacer()

                    // Artwork
                    artwork

                    Spacer()

                    // Track info
                    trackInfo

                    // Progress bar
                    progressBar

                    // Controls
                    controls

                    // Additional controls
                    additionalControls

                    Spacer()
                        .frame(height: max(geometry.safeAreaInsets.bottom, 20))
                }
            }
        }
        .sheet(isPresented: $showingTimerPicker) {
            TimerPickerSheet()
        }
        .sheet(isPresented: $showingPlaylist) {
            PlaylistSheet()
        }
        .sheet(isPresented: $showingDownloads) {
            DownloadsManagerView()
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheet()
        }
        .sheet(isPresented: $showingEffectivenessFeedback) {
            if let track = lastPlayedTrack {
                EffectivenessFeedbackSheet(
                    track: track,
                    cryType: cryDetectionService.cryType,
                    playbackDuration: playbackStartTime.map { Date().timeIntervalSince($0) } ?? 0
                )
            }
        }
        .onAppear {
            // Prepare haptics
            impactLight.prepare()
            impactMedium.prepare()
            selectionFeedback.prepare()
        }
        .onChange(of: audioEngine.playbackState) { oldState, newState in
            // Track when playback starts
            if newState == .playing && oldState != .playing {
                playbackStartTime = Date()
                lastPlayedTrack = audioEngine.currentTrack
            }

            // Show effectiveness feedback when playback stops after significant duration
            if oldState == .playing && newState == .stopped {
                if let startTime = playbackStartTime,
                   Date().timeIntervalSince(startTime) > 30, // At least 30 seconds
                   lastPlayedTrack != nil {
                    // Delay slightly to let UI settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingEffectivenessFeedback = true
                    }
                }
            }
        }
    }

    // MARK: - Header
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
                    showingPlaylist = true
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
                    showingTimerPicker = true
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
                    showingDownloads = true
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
                .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.3))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(y: 20)

            // Main circle
            Circle()
                .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.15))
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
                Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                    .font(.system(size: 70))
                    .foregroundColor(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))
            }

            // Rotating ring animation when playing
            if audioEngine.playbackState.isPlaying {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise),
                                Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.3),
                                Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise)
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
            Text(audioEngine.currentTrack?.title ?? "Unknown Track")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text(audioEngine.currentTrack?.artist ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextSecondary)

                if let language = audioEngine.currentTrack?.language {
                    Text(language.flag)
                        .font(.system(size: 16))
                }
            }

            // Source and download indicator
            if let track = audioEngine.currentTrack {
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
            // Slider
            Slider(
                value: Binding(
                    get: { audioEngine.currentTime },
                    set: { audioEngine.seek(to: $0) }
                ),
                in: 0...max(1, audioEngine.duration)
            )
            .accentColor(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))

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
        HStack(spacing: 0) {
            // Shuffle - Spotify-style with dot indicator
            shuffleButton
                .frame(maxWidth: .infinity)

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

            // Play/Pause - Large center button with animation
            playPauseButton
                .frame(maxWidth: .infinity)

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

            // Repeat - Spotify-style with mode indicator
            repeatButton
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
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
            } else {
                audioEngine.resume()
            }
        } label: {
            ZStack {
                // Outer glow when playing
                if audioEngine.playbackState.isPlaying {
                    Circle()
                        .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.3))
                        .frame(width: 82, height: 82)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise).opacity(0.4),
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
                    in: 0...0.7
                )
                .accentColor(.appTextSecondary)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            // Bottom row: Queue, Timer
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

                // Sleep timer
                Button {
                    showingTimerPicker = true
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
                            QueueTrackRow(track: track, position: index + 1)
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
                                QueueTrackRow(track: track, position: index + 1)
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

struct QueueTrackRow: View {
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

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Effectiveness Feedback Sheet
/// Prompts user to rate how effective the track was at soothing their baby
/// This feedback trains the ML recommendation engine for personalized suggestions
struct EffectivenessFeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var babyProfileManager = BabyProfileManager.shared
    @StateObject private var analyticsCloudService = AnalyticsCloudService.shared

    let track: AudioTrack
    let cryType: CryType
    let playbackDuration: TimeInterval

    @State private var selectedRating: EffectivenessRating?
    @State private var showingThankYou = false

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
            .padding(.top, 16)
        }
    }

    private func submitFeedback(rating: EffectivenessRating) {
        // Get active baby ID from UserDefaults or BabyProfileManager
        guard let babyData = UserDefaults.standard.data(forKey: "activeBaby"),
              let baby = try? JSONDecoder().decode(Baby.self, from: babyData) else {
            // No baby configured - still show thank you
            withAnimation {
                showingThankYou = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
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

        // Auto dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
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

#Preview {
    PlayerView()
        .environmentObject(AudioEngine.shared)
}
