import SwiftUI
import WatchKit

/// Shows current track and playback controls
/// Supports both local watch playback and remote iPhone control
struct NowPlayingView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    @State private var showingModeSelector = false
    @State private var controlMode: ControlMode = .remote
    @State private var crownVolume: Double = 0.7

    enum ControlMode {
        case local   // Playing on watch
        case remote  // Controlling iPhone
    }

    var body: some View {
        VStack(spacing: 8) {
            // Mode indicator
            HStack {
                Image(systemName: controlMode == .local ? "applewatch" : "iphone")
                    .font(.caption2)
                Text(controlMode == .local ? "Watch" : "iPhone")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .onTapGesture {
                showingModeSelector = true
            }

            if controlMode == .local {
                localPlaybackView
            } else {
                remoteControlView
            }
        }
        .focusable()
        .digitalCrownRotation($crownVolume, from: 0, through: 1, by: 0.05, sensitivity: .medium)
        .onChange(of: crownVolume) { _, newValue in
            audioPlayer.volume = Float(newValue)
        }
        .sheet(isPresented: $showingModeSelector) {
            modeSelectorSheet
        }
    }

    // MARK: - Local Playback View (Watch Audio)

    private var localPlaybackView: some View {
        VStack(spacing: 8) {
            // Track info
            if let track = audioPlayer.currentTrack {
                trackInfoView(title: track.title, artist: track.artist)
            } else {
                emptyStateView
            }

            // Progress bar
            if audioPlayer.currentTrack != nil {
                progressBar(
                    progress: audioPlayer.progress,
                    currentTime: audioPlayer.formattedCurrentTime,
                    duration: audioPlayer.formattedDuration
                )
            }

            // Controls
            playbackControls(
                isPlaying: audioPlayer.isPlaying,
                onPlayPause: { audioPlayer.togglePlayPause() },
                onPrevious: { audioPlayer.skipPrevious() },
                onNext: { audioPlayer.skipNext() }
            )

            // Volume indicator
            volumeIndicator
        }
    }

    // MARK: - Remote Control View (iPhone Audio)

    private var remoteControlView: some View {
        VStack(spacing: 8) {
            // Connection status
            if !connectivityManager.isPhoneReachable {
                connectionWarning
            }

            // Track info from iPhone
            let state = connectivityManager.iPhonePlaybackState
            if let title = state.currentTrackTitle {
                trackInfoView(title: title, artist: state.currentTrackArtist ?? "")
            } else {
                emptyStateView
            }

            // Progress bar
            if state.currentTrackId != nil {
                progressBar(
                    progress: state.progress,
                    currentTime: formatTime(state.progress * 180), // Approximate
                    duration: "3:00"
                )
            }

            // Remote controls
            playbackControls(
                isPlaying: state.isPlaying,
                onPlayPause: { connectivityManager.togglePlayPause() },
                onPrevious: { connectivityManager.sendSkipPreviousCommand() },
                onNext: { connectivityManager.sendSkipNextCommand() }
            )
        }
    }

    // MARK: - Shared Components

    private func trackInfoView(title: String, artist: String) -> some View {
        VStack(spacing: 4) {
            // Artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundColor(.blue)
                )

            // Title
            Text(title)
                .font(.headline)
                .lineLimit(1)

            // Artist
            Text(artist)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Track Playing")
                .font(.caption)
                .foregroundColor(.secondary)

            if controlMode == .local {
                Text("Select from Favorites")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }

    private func progressBar(progress: Double, currentTime: String, duration: String) -> some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .cornerRadius(2)
            }
            .frame(height: 4)

            HStack {
                Text(currentTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(duration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func playbackControls(
        isPlaying: Bool,
        onPlayPause: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            // Previous
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            // Next
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    private var volumeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.caption2)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * crownVolume, height: 3)
                }
                .cornerRadius(1.5)
            }
            .frame(height: 3)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }

    private var connectionWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("iPhone not connected")
                .font(.caption2)
        }
    }

    private var modeSelectorSheet: some View {
        List {
            Button {
                controlMode = .local
                showingModeSelector = false
            } label: {
                HStack {
                    Image(systemName: "applewatch")
                    Text("Play on Watch")
                    if controlMode == .local {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                controlMode = .remote
                showingModeSelector = false
            } label: {
                HStack {
                    Image(systemName: "iphone")
                    Text("Control iPhone")
                    if controlMode == .remote {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(WatchAudioPlayer.shared)
}
