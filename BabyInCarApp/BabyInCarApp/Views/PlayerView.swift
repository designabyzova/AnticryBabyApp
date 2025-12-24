//
//  PlayerView.swift
//  BabyInCarApp
//
//  Full screen audio player
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingTimerPicker = false
    @State private var showingPlaylist = false

    var body: some View {
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
                // Header
                header

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
            }
        }
        .sheet(isPresented: $showingTimerPicker) {
            TimerPickerSheet()
        }
        .sheet(isPresented: $showingPlaylist) {
            PlaylistSheet()
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

            Image(systemName: audioEngine.currentTrack?.category.icon ?? "music.note")
                .font(.system(size: 70))
                .foregroundColor(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))

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

            // Age appropriateness badge
            if let track = audioEngine.currentTrack {
                Text("Ages \(track.ageRangeMin)-\(track.ageRangeMax) months")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.1))
                    )
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
            // Shuffle (placeholder for future)
            Button {
                // Shuffle functionality
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)

            // Previous
            Button {
                audioEngine.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.appText)
            }
            .frame(maxWidth: .infinity)

            // Play/Pause
            Button {
                if audioEngine.playbackState.isPlaying {
                    audioEngine.pause()
                } else {
                    audioEngine.resume()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.forCategory(audioEngine.currentTrack?.category ?? .whiteNoise))
                        .frame(width: 72, height: 72)

                    Image(systemName: audioEngine.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .offset(x: audioEngine.playbackState.isPlaying ? 0 : 2)
                }
            }
            .frame(maxWidth: .infinity)

            // Next
            Button {
                audioEngine.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.appText)
            }
            .frame(maxWidth: .infinity)

            // Repeat (placeholder)
            Button {
                // Repeat functionality
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 18))
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    // MARK: - Additional Controls
    private var additionalControls: some View {
        HStack(spacing: 32) {
            // Volume
            HStack(spacing: 8) {
                Image(systemName: audioEngine.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)

                Slider(
                    value: Binding(
                        get: { Double(audioEngine.volume) },
                        set: { audioEngine.setVolume(Float($0)) }
                    ),
                    in: 0...0.7
                )
                .frame(width: 100)
                .accentColor(.appTextSecondary)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            // Sleep timer
            Button {
                showingTimerPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 16))

                    if audioEngine.sleepTimer != .off {
                        Text(formatTime(audioEngine.sleepTimerRemaining))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(audioEngine.sleepTimer == .off ? .appTextSecondary : .appPrimary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
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

#Preview {
    PlayerView()
        .environmentObject(AudioEngine.shared)
}
