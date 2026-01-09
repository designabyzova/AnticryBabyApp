import SwiftUI
import WatchKit

/// Shows current track and playback controls
/// Supports local watch playback, remote iPhone control, and standalone mode
struct NowPlayingView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @EnvironmentObject var audioPlayer: WatchAudioPlayer

    @State private var showingModeSelector = false
    @State private var showingSoundPicker = false
    @State private var controlMode: ControlMode = .remote  // Default to remote (iPhone control)
    @State private var crownVolume: Double = 0.7
    @State private var hasInitialized = false

    enum ControlMode {
        case local      // Playing synced files on watch
        case remote     // Controlling iPhone
        case standalone // Playing generated audio (no iPhone needed)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Mode indicator
            modeIndicator

            // Content based on mode
            switch effectiveControlMode {
            case .standalone:
                standalonePlaybackView
            case .local:
                localPlaybackView
            case .remote:
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
        .sheet(isPresented: $showingSoundPicker) {
            standaloneSoundPicker
        }
        .onAppear {
            // Only set mode once on first appearance
            guard !hasInitialized else { return }
            hasInitialized = true

            // Default to remote (iPhone control) if connected
            // Only fallback to standalone if iPhone truly not available
            if connectivityManager.isPhoneReachable {
                controlMode = .remote
                // Request current state from iPhone
                connectivityManager.requestStateSync()
            } else if !audioPlayer.isPlaying {
                // Only suggest standalone if disconnected AND not already playing
                controlMode = .standalone
            }
        }
        .onChange(of: connectivityManager.isPhoneReachable) { _, isReachable in
            // When iPhone becomes reachable, switch to remote mode
            if isReachable && !audioPlayer.isStandaloneMode {
                controlMode = .remote
                connectivityManager.requestStateSync()
            }
        }
    }

    /// Determine effective control mode based on connectivity
    private var effectiveControlMode: ControlMode {
        // If currently playing standalone, stay in standalone
        if audioPlayer.isStandaloneMode {
            return .standalone
        }
        // If iPhone is reachable, always allow remote mode
        if connectivityManager.isPhoneReachable {
            return controlMode
        }
        // If iPhone not reachable and user explicitly chose remote, show remote with warning
        // This allows them to see what was playing and switch modes
        return controlMode
    }

    // MARK: - Mode Indicator

    private var modeIndicator: some View {
        HStack {
            Image(systemName: modeIcon)
                .font(.caption2)
            Text(modeText)
                .font(.caption2)
        }
        .foregroundColor(modeColor)
        .onTapGesture {
            showingModeSelector = true
        }
    }

    private var modeIcon: String {
        switch effectiveControlMode {
        case .standalone: return "sparkles"
        case .local: return "applewatch"
        case .remote: return "iphone"
        }
    }

    private var modeText: String {
        switch effectiveControlMode {
        case .standalone: return "Watch Only"
        case .local: return "Watch"
        case .remote: return "iPhone"
        }
    }

    private var modeColor: Color {
        switch effectiveControlMode {
        case .standalone: return .purple
        case .local: return .green
        case .remote: return .secondary
        }
    }

    // MARK: - Standalone Playback View (Generated Audio)

    private var standalonePlaybackView: some View {
        VStack(spacing: 12) {
            // No iPhone banner
            if !connectivityManager.isPhoneReachable {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Playing on Watch")
                        .font(.system(size: 10))
                }
                .foregroundColor(.purple)
            }

            // Current sound or picker
            if let soundType = audioPlayer.currentStandaloneSound, audioPlayer.isPlaying {
                // Show current playing sound
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 70, height: 70)

                        Image(systemName: soundType.icon)
                            .font(.title)
                            .foregroundColor(.purple)
                    }

                    Text(soundType.rawValue)
                        .font(.headline)
                        .lineLimit(1)

                    Text("Generated Audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Playback controls
                standaloneControls
            } else {
                // Show sound selection
                standaloneSoundSelection
            }

            // Volume indicator
            volumeIndicator
        }
    }

    private var standaloneSoundSelection: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(.purple)

            Text("Ready to Play")
                .font(.caption)
                .foregroundColor(.secondary)

            // Quick play buttons
            HStack(spacing: 12) {
                Button {
                    audioPlayer.playStandalone(.lullaby)
                } label: {
                    VStack {
                        Image(systemName: "music.note")
                            .font(.title3)
                        Text("Lullaby")
                            .font(.caption2)
                    }
                    .frame(width: 60)
                }
                .buttonStyle(.plain)
                .foregroundColor(.purple)

                Button {
                    audioPlayer.playStandalone(.heartbeat)
                } label: {
                    VStack {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                        Text("Heartbeat")
                            .font(.caption2)
                    }
                    .frame(width: 60)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }

            // More sounds button
            Button {
                showingSoundPicker = true
            } label: {
                Text("More Sounds")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var standaloneControls: some View {
        HStack(spacing: 20) {
            // Previous sound
            Button {
                playPreviousStandaloneSound()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                audioPlayer.togglePlayPause()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.purple)

            // Next sound
            Button {
                playNextStandaloneSound()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    private func playNextStandaloneSound() {
        let sounds = WatchAudioPlayer.StandaloneSoundType.allCases
        guard let current = audioPlayer.currentStandaloneSound,
              let currentIndex = sounds.firstIndex(of: current) else {
            audioPlayer.playStandalone(sounds.first ?? .lullaby)
            return
        }
        let nextIndex = (currentIndex + 1) % sounds.count
        audioPlayer.playStandalone(sounds[nextIndex])
    }

    private func playPreviousStandaloneSound() {
        let sounds = WatchAudioPlayer.StandaloneSoundType.allCases
        guard let current = audioPlayer.currentStandaloneSound,
              let currentIndex = sounds.firstIndex(of: current) else {
            audioPlayer.playStandalone(sounds.first ?? .lullaby)
            return
        }
        let prevIndex = currentIndex == 0 ? sounds.count - 1 : currentIndex - 1
        audioPlayer.playStandalone(sounds[prevIndex])
    }

    // MARK: - Standalone Sound Picker Sheet

    private var standaloneSoundPicker: some View {
        NavigationStack {
            List {
                ForEach(WatchAudioPlayer.StandaloneSoundType.allCases) { soundType in
                    Button {
                        audioPlayer.playStandalone(soundType)
                        showingSoundPicker = false
                    } label: {
                        HStack {
                            Image(systemName: soundType.icon)
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(soundType.rawValue)
                                    .font(.caption)
                                Text(soundType.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if audioPlayer.currentStandaloneSound == soundType {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Sounds")
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
            // Standalone mode (works without iPhone)
            Button {
                controlMode = .standalone
                showingModeSelector = false
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("Watch Only")
                            .font(.caption)
                        Text("Generated sounds")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if effectiveControlMode == .standalone {
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)

            // Local synced files
            Button {
                controlMode = .local
                showingModeSelector = false
            } label: {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Watch Files")
                            .font(.caption)
                        Text("Synced from iPhone")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if controlMode == .local && !audioPlayer.isStandaloneMode {
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)

            // Remote iPhone control
            Button {
                controlMode = .remote
                showingModeSelector = false
            } label: {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(connectivityManager.isPhoneReachable ? .blue : .gray)
                    VStack(alignment: .leading) {
                        Text("Control iPhone")
                            .font(.caption)
                        Text(connectivityManager.isPhoneReachable ? "Connected" : "Not connected")
                            .font(.caption2)
                            .foregroundColor(connectivityManager.isPhoneReachable ? .green : .orange)
                    }
                    if controlMode == .remote && connectivityManager.isPhoneReachable {
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!connectivityManager.isPhoneReachable)
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
