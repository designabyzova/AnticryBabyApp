import Foundation
import WatchKit
import AVFoundation
import Combine

/// Audio player for Apple Watch using WKAudioFilePlayer
/// Handles local audio playback with basic controls
@MainActor
final class WatchAudioPlayer: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchAudioPlayer()

    // MARK: - Published Properties

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrack: WatchTrack?
    @Published private(set) var progress: Double = 0  // 0.0 - 1.0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 0.7  // 0.0 - 1.0

    // Sleep timer
    @Published private(set) var sleepTimerActive = false
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0

    // MARK: - Private Properties

    private var player: WKAudioFilePlayer?
    private var playerItem: WKAudioFilePlayerItem?
    private var progressTimer: Timer?
    private var sleepTimer: Timer?

    // Playlist management
    private var playlist: [WatchTrack] = []
    private var currentIndex: Int = 0
    private var shuffleEnabled = false
    private var repeatMode: RepeatMode = .none

    enum RepeatMode {
        case none
        case all
        case one
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        // Note: watchOS has limited audio session capabilities
        // Audio plays through the watch speaker or connected Bluetooth headphones
    }

    // MARK: - Public API

    /// Play a single track
    func play(track: WatchTrack) {
        guard let url = track.localURL else {
            print("[WatchAudioPlayer] No local URL for track: \(track.title)")
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[WatchAudioPlayer] File not found: \(url.path)")
            return
        }

        // Stop current playback
        stop()

        // Create player item and player
        let asset = WKAudioFileAsset(url: url)
        playerItem = WKAudioFilePlayerItem(asset: asset)
        player = WKAudioFilePlayer(playerItem: playerItem!)

        // Update state
        currentTrack = track
        duration = track.duration
        currentTime = 0
        progress = 0

        // Start playback
        player?.play()
        isPlaying = true

        // Start progress tracking
        startProgressTimer()

        // Observe player status
        observePlayerStatus()

        // Haptic feedback
        WKInterfaceDevice.current().play(.start)

        print("[WatchAudioPlayer] Playing: \(track.title)")
    }

    /// Play from playlist
    func playPlaylist(_ tracks: [WatchTrack], startIndex: Int = 0) {
        playlist = tracks
        currentIndex = startIndex

        if let track = tracks[safe: startIndex] {
            play(track: track)
        }
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        WKInterfaceDevice.current().play(.stop)
        print("[WatchAudioPlayer] Paused")
    }

    /// Resume playback
    func resume() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
        startProgressTimer()
        WKInterfaceDevice.current().play(.start)
        print("[WatchAudioPlayer] Resumed")
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Stop playback completely
    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        currentTrack = nil
        currentTime = 0
        progress = 0
        duration = 0
        stopProgressTimer()
        print("[WatchAudioPlayer] Stopped")
    }

    /// Skip to next track
    func skipNext() {
        guard !playlist.isEmpty else { return }

        if repeatMode == .one {
            // Restart current track
            if let track = currentTrack {
                play(track: track)
            }
            return
        }

        var nextIndex = currentIndex + 1

        if nextIndex >= playlist.count {
            if repeatMode == .all {
                nextIndex = 0
            } else {
                stop()
                return
            }
        }

        currentIndex = nextIndex
        if let track = playlist[safe: nextIndex] {
            play(track: track)
        }
    }

    /// Skip to previous track
    func skipPrevious() {
        guard !playlist.isEmpty else { return }

        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            if let track = currentTrack {
                play(track: track)
            }
            return
        }

        var prevIndex = currentIndex - 1

        if prevIndex < 0 {
            if repeatMode == .all {
                prevIndex = playlist.count - 1
            } else {
                prevIndex = 0
            }
        }

        currentIndex = prevIndex
        if let track = playlist[safe: prevIndex] {
            play(track: track)
        }
    }

    /// Seek to position (0.0 - 1.0)
    func seek(to position: Double) {
        guard let player = player else { return }

        let targetTime = duration * position
        // Note: WKAudioFilePlayer has limited seek support
        // This is a simplified implementation
        currentTime = targetTime
        progress = position
    }

    // MARK: - Sleep Timer

    /// Set sleep timer
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()

        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimerActive = true

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.sleepTimerRemaining -= 1

                if self.sleepTimerRemaining <= 0 {
                    self.handleSleepTimerExpired()
                }
            }
        }

        WKInterfaceDevice.current().play(.success)
        print("[WatchAudioPlayer] Sleep timer set for \(minutes) minutes")
    }

    /// Cancel sleep timer
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerActive = false
        sleepTimerRemaining = 0
        print("[WatchAudioPlayer] Sleep timer cancelled")
    }

    private func handleSleepTimerExpired() {
        cancelSleepTimer()
        pause()
        WKInterfaceDevice.current().play(.notification)
        print("[WatchAudioPlayer] Sleep timer expired")
    }

    // MARK: - Volume Control (Digital Crown)

    /// Adjust volume (for Digital Crown integration)
    func adjustVolume(by delta: Float) {
        volume = max(0, min(1, volume + delta))
        // Note: Watch volume is system-controlled
        // This is for UI display purposes
    }

    // MARK: - Private Helpers

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying, duration > 0 else { return }

        // Increment time (simplified - WKAudioFilePlayer doesn't provide currentTime)
        currentTime += 0.5
        progress = min(1.0, currentTime / duration)

        // Check if track ended
        if currentTime >= duration {
            handleTrackEnded()
        }
    }

    private func handleTrackEnded() {
        print("[WatchAudioPlayer] Track ended")
        skipNext()
    }

    private func observePlayerStatus() {
        // Note: WKAudioFilePlayer has limited status observation
        // Real implementation would use KVO on player.status
    }
}

// MARK: - Convenience Extensions

extension WatchAudioPlayer {
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var formattedSleepTimer: String {
        formatTime(sleepTimerRemaining)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
