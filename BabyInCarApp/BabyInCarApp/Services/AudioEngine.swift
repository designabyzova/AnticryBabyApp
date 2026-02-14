//
//  AudioEngine.swift
//  BabyInCarApp
//
//  Core audio playback engine with streaming support and real-time synthesis
//

import Foundation
@preconcurrency import AVFoundation
import Combine
import UIKit

@MainActor
class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    // MARK: - Published Properties
    @Published var playbackState: LocalPlaybackState = .stopped
    @Published var currentTrack: AudioTrack?
    @Published var currentPlaylist: Playlist?
    @Published var currentPlaylistIndex: Int = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    @Published var sleepTimer: SleepTimer = .off
    @Published var sleepTimerRemaining: TimeInterval = 0
    @Published var repeatMode: RepeatMode = .off {
        didSet { savePlaybackSettings() }
    }
    @Published var isShuffleEnabled: Bool = false {
        didSet { savePlaybackSettings() }
    }
    @Published var isBuffering: Bool = false
    @Published var bufferProgress: Double = 0
    /// True when user is actively dragging the progress slider - prevents time updates from overwriting user intent
    @Published var isScrubbing: Bool = false
    @Published var playbackRate: Float = 1.0 {
        didSet { applyPlaybackRate() }
    }

    /// Smooth audio transitions with crossfade (synced with AppState)
    /// Default: true - provides seamless track transitions
    @Published var smoothTransitionsEnabled: Bool = true {
        didSet { savePlaybackSettings() }
    }

    // MARK: - Unified Player Architecture
    /// Playback context - determines UI theme and smart queue behavior
    @Published var playbackContext: PlaybackContext?

    // MARK: - Soothing Mode Protection
    /// When true, playback is protected from interruptions (phone calls, Bluetooth disconnect, etc.)
    /// Only explicit user action can stop soothing mode playback
    /// This ensures baby-calming music continues playing no matter what
    @Published private(set) var isSoothingModeActive: Bool = false

    /// Tracks if we were playing before an interruption occurred (for auto-resume)
    private var wasPlayingBeforeInterruption: Bool = false

    // Playback rate options
    enum PlaybackRate: Float, CaseIterable {
        case half = 0.5
        case threeQuarters = 0.75
        case normal = 1.0
        case oneAndQuarter = 1.25
        case oneAndHalf = 1.5
        case double = 2.0

        var displayName: String {
            switch self {
            case .half: return "0.5x"
            case .threeQuarters: return "0.75x"
            case .normal: return "1x"
            case .oneAndQuarter: return "1.25x"
            case .oneAndHalf: return "1.5x"
            case .double: return "2x"
            }
        }
    }

    // Fast forward/rewind state
    @Published var isSeeking: Bool = false
    @Published var seekSpeed: Int = 1 // 1x, 2x, 5x, 10x

    // MARK: - Queue Management (Spotify-like)
    /// Original playlist order before shuffle
    private var originalPlaylistOrder: [AudioTrack] = []
    /// Queue of tracks to play next (inserted by "Play Next" feature)
    @Published var upNextQueue: [AudioTrack] = []
    /// History of played tracks for "previous" navigation (from app start)
    /// This queue is populated whenever a new track starts playing
    private var playbackHistory: [AudioTrack] = []
    private let maxHistorySize = 50

    /// Read-only access to playback history (most recent last)
    /// Use this to display "Recently Played" in the queue view
    var recentlyPlayedTracks: [AudioTrack] {
        playbackHistory
    }

    /// Number of tracks in playback history (for UI display)
    var playbackHistoryCount: Int {
        playbackHistory.count
    }

    /// Check if previous track is available in history
    var canGoToPrevious: Bool {
        !playbackHistory.isEmpty || currentPlaylist != nil
    }

    // MARK: - LRU Buffer Cache (Increment 0028, Enhanced 0029, Fixed 0030)
    /// LRU cache for recently played audio buffers
    /// Stores AVPlayer instances to avoid re-loading recently played tracks
    /// MEMORY FIX (0030): Reduced from 3→1 to save ~40-60MB (each AVPlayer buffers 10-30MB)
    private var recentlyPlayedBuffers: [(trackId: UUID, player: AVPlayer, timeObserver: Any?)] = []
    private var maxRecentBuffers = 1  // Dynamic - reduced under memory pressure
    private let defaultMaxRecentBuffers = 1
    private let emergencyMaxRecentBuffers = 0  // No cache under memory pressure

    /// Memory pressure level tracking for cache decisions
    private var isUnderMemoryPressure: Bool = false

    // MARK: - Shuffle State
    /// Tracks already played in shuffle mode (to avoid repeats until all played)
    private var shufflePlayedIndices: Set<Int> = []

    enum RepeatMode: String, CaseIterable {
        case off = "off"
        case all = "all"
        case one = "one"

        var icon: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }

        var isActive: Bool {
            self != .off
        }

        var displayName: String {
            switch self {
            case .off: return "Repeat Off"
            case .all: return "Repeat All"
            case .one: return "Repeat One"
            }
        }
    }

    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioPlayer: AVAudioPlayer?
    private var streamPlayer: AVPlayer?  // For progressive streaming
    private var playerItemObserver: Any?
    private var timeObserver: Any?
    private var noiseGenerator: NoiseGenerator?
    private var toneGenerator: ToneGenerator?

    // MARK: - Crossfade State
    /// True when actively crossfading between tracks - prevents premature cleanup of old stream
    private var isCrossfading: Bool = false
    /// Old stream player being faded out during crossfade
    private var crossfadeOldStreamPlayer: AVPlayer?
    /// Old time observer for crossfade cleanup
    private var crossfadeOldTimeObserver: Any?

    // MARK: - Timers
    private var progressTimer: Timer?
    private var sleepTimerInstance: Timer?
    private var fadeTimer: Timer?

    // MARK: - Notification Observers (MEMORY FIX 0030)
    /// Stored observer tokens for proper cleanup
    private var notificationObservers: [Any] = []

    // MARK: - Settings
    private let maxSafeVolume: Float = 1.0 // Full system volume

    // MARK: - Services
    private let downloadManager = AudioDownloadManager.shared
    private let cacheService = AudioCacheService.shared

    private init() {
        loadPlaybackSettings()
        setupNotifications()
    }

    // MARK: - Settings Persistence
    private func savePlaybackSettings() {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "audioEngine.repeatMode")
        UserDefaults.standard.set(isShuffleEnabled, forKey: "audioEngine.shuffleEnabled")
        UserDefaults.standard.set(smoothTransitionsEnabled, forKey: "audioEngine.smoothTransitions")
    }

    private func loadPlaybackSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "audioEngine.repeatMode"),
           let mode = RepeatMode(rawValue: modeString) {
            repeatMode = mode
        }
        isShuffleEnabled = UserDefaults.standard.bool(forKey: "audioEngine.shuffleEnabled")

        // Smooth transitions defaults to TRUE if not set
        if UserDefaults.standard.object(forKey: "audioEngine.smoothTransitions") == nil {
            smoothTransitionsEnabled = true  // Default ON
        } else {
            smoothTransitionsEnabled = UserDefaults.standard.bool(forKey: "audioEngine.smoothTransitions")
        }
    }

    // MARK: - Audio Session Configuration

    // 🚨 PERFORMANCE FIX: Throttle audio session reconfigurations
    // Multiple rapid reconfigurations cause audio glitches ("broken radio" sound)
    private var lastSessionConfigTime: Date = .distantPast
    private let sessionConfigThrottleInterval: TimeInterval = 0.5 // 500ms minimum between reconfigs

    @discardableResult
    func configureAudioSession(interruptOtherAudio: Bool = false) -> Bool {
        // 🚨 PERFORMANCE FIX (2026-01-09): Throttle session reconfigurations
        // Rapid reconfigurations (e.g., during emergency activation) cause audio glitches
        let now = Date()
        let timeSinceLastConfig = now.timeIntervalSince(lastSessionConfigTime)
        if timeSinceLastConfig < sessionConfigThrottleInterval {
            print("[AudioEngine] ⏱️ Throttling session config (\(Int(timeSinceLastConfig * 1000))ms since last)")
            return true // Assume session is still valid
        }

        // 🚨 CRITICAL FIX: Don't reconfigure during active emergency playback!
        // Audio session changes during playback cause glitches
        if false /* emergency queue removed */ && playbackState == .playing {
            print("[AudioEngine] 🚨 Skipping session reconfig - emergency playback active")
            return true
        }

        // CRITICAL FIX: Use SYNCHRONOUS activation instead of debounced request
        // The debounced requestSession() was causing a race condition:
        // 1. requestSession() schedules debounced activation (100ms delay)
        // 2. playStreamedAudio() is called immediately
        // 3. AVPlayer.play() is called BEFORE audio session is active
        // 4. Result: NO SOUND!
        //
        // Solution: Use activateSessionSync() for immediate activation
        let sessionManager = AudioSessionManager.shared

        // Determine priority based on context
        let priority: AudioSessionPriority = false /* emergency queue removed */ ? .emergency : .playback

        do {
            let success = try sessionManager.activateSessionSync(
                mode: .playbackOnly,
                priority: priority,
                serviceId: "AudioEngine"
            )

            if success {
                print("[AudioEngine] ✅ Audio session activated SYNCHRONOUSLY via AudioSessionManager")
                lastSessionConfigTime = now  // Update throttle timestamp on success
            }
            return success
        } catch {
            print("[AudioEngine] ⚠️ AudioSessionManager sync activation failed: \(error)")

            // FALLBACK: Try direct AVAudioSession activation
            // This ensures audio still works even if AudioSessionManager has issues
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
                print("[AudioEngine] ✅ Audio session activated via DIRECT fallback")
                lastSessionConfigTime = now  // Update throttle timestamp on success
                return true
            } catch {
                print("[AudioEngine] ❌ Direct audio session fallback also failed: \(error)")
                return false
            }
        }
    }

    /// Release audio session when stopping playback
    func releaseAudioSession() {
        AudioSessionManager.shared.releaseSession(serviceId: "AudioEngine")
        print("[AudioEngine] 📤 Released audio session via AudioSessionManager")
    }

    /// Ensure audio session is active - call this immediately before AVPlayer.play()
    /// This is a defensive measure that handles edge cases where the session might not be active
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()

        // Check if session is already active with correct category
        // .playAndRecord is ALSO valid for playback - it supports both input AND output
        if session.category == .playback || session.category == .playAndRecord {
            // Session appears to be configured correctly
            print("[AudioEngine] ✅ Audio session already configured: \(session.category.rawValue)")
            return
        }

        // Session not active or wrong category - activate it now!
        print("[AudioEngine] ⚠️ Audio session not active - activating now!")
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("[AudioEngine] ✅ Audio session activated in ensureAudioSessionActive()")
        } catch {
            print("[AudioEngine] ❌ Failed to activate audio session: \(error)")
        }
    }

    private func setupNotifications() {
        // MEMORY FIX (0030): Store observer tokens for proper cleanup
        let nc = NotificationCenter.default

        notificationObservers.append(nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            DispatchQueue.main.async {
                self?.handleInterruption(notification)
            }
        })

        notificationObservers.append(nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            DispatchQueue.main.async {
                self?.handleRouteChange(notification)
            }
        })

        notificationObservers.append(nc.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                print("[AudioEngine] ⚠️ Memory warning received - cleaning up")
                self?.cleanup()
            }
        })

        notificationObservers.append(nc.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            DispatchQueue.main.async {
                if let level = notification.userInfo?["level"] as? String {
                    let isAggressive = (level == "critical" || level == "emergency")
                    print("[AudioEngine] 🧹 Memory cleanup requested (\(level), aggressive: \(isAggressive))")
                    self?.cleanup(aggressive: isAggressive)
                }
            }
        })

        notificationObservers.append(nc.addObserver(
            forName: NSNotification.Name("MemoryPressureNormalized"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.restoreNormalCacheLimits()
            }
        })
    }

    // MARK: - Playback Control

    /// Play track with optional smooth crossfade transition
    /// Respects smoothTransitionsEnabled global setting
    /// NOTE: This is called directly by views AND by PlaybackSessionManager
    /// - Parameter addToPlaybackHistory: If true, adds current track to history before playing new one (default: true)
    func play(track: AudioTrack, crossfadeDuration: TimeInterval = 1.0, addToPlaybackHistory: Bool = true) {
        print("[AudioEngine] 🎵 Play request: \(track.title)")

        // PLAYBACK HISTORY: Add current track to history before switching
        // This enables the "previous" button to work from app start across ALL playback modes
        // Skip if same track (avoid duplicates) or if explicitly disabled (e.g., from previous() itself)
        if addToPlaybackHistory, let current = currentTrack, current.id != track.id {
            addToHistory(current)
        }

        // CRITICAL FIX (2026-01-09): Prevent dual track playback
        // If a crossfade is in progress, cancel it completely before starting new playback
        // This prevents the race condition where:
        // 1. Track A playing → tap Track B → crossfade starts (state = .loading)
        // 2. Tap Track C quickly → state is .loading, not .playing
        // 3. Goes to else branch, both B and C play simultaneously!
        if isCrossfading {
            print("[AudioEngine] ⚠️ Cancelling in-progress crossfade for new track")
            cancelCrossfade()
        }

        // If smooth transitions disabled, play immediately without fade
        guard smoothTransitionsEnabled else {
            playImmediate(track: track)
            return
        }

        // If already playing OR loading (during crossfade), crossfade to new track
        // CRITICAL FIX: Also check .loading state to handle rapid track changes
        if (playbackState == .playing || playbackState == .loading), let _ = currentTrack {
            crossfadeToTrack(track, duration: crossfadeDuration)
        } else {
            // No current playback, start with fade-in
            stopCurrentPlayback()
            currentTrack = track
            duration = track.duration
            playbackState = .loading
            startPlaybackWithFadeIn(track: track, fadeDuration: 0.5)
        }
    }

    /// Play track immediately without any fade (for emergency mode or when smooth transitions disabled)
    func playImmediateWithoutFade(track: AudioTrack) {
        playImmediate(track: track)
    }

    /// Legacy function for backward compatibility (no crossfade)
    private func playImmediate(track: AudioTrack) {
        // CRITICAL FIX (2026-01-09): Cancel any in-progress crossfade before immediate playback
        // This prevents dual track playback when emergency mode interrupts a crossfade
        if isCrossfading {
            print("[AudioEngine] ⚠️ Cancelling crossfade for immediate playback")
            cancelCrossfade()
        } else {
            stopCurrentPlayback()
        }

        currentTrack = track
        duration = track.duration
        playbackState = .loading

        // CRITICAL FIX: Configure audio session before playback
        // This ensures audio works after emergency mode stops
        // IMPORTANT: Check if emergency queue is active - if so, keep emergency audio session!
        let isEmergencyActive = false /* emergency queue removed */
        if !isEmergencyActive {
            // Only configure normal audio session if NOT in emergency mode
            configureAudioSession(interruptOtherAudio: false)
        } else {
            // In emergency mode - ensure we have an active audio session but DON'T reset it
            // The emergency session was already configured by cry response engine
            print("[AudioEngine] 🚨 Emergency mode active - preserving emergency audio session")
        }

        // Track recently played
        PlaylistManager.shared.addToRecentlyPlayed(track)

        // Update Now Playing info for Control Center / Lock Screen / CarPlay
        NowPlayingService.shared.updateNowPlayingInfo(track: track)

        switch track.audioSourceType {
        case .generated:
            playGeneratedAudio(track: track)
        case .bundled:
            playBundledAudio(track: track)
        case .streamed:
            playStreamedAudio(track: track)
        case .textToSpeech:
            playTextToSpeech(track: track)
        }
    }

    func play(playlist: Playlist, startIndex: Int = 0, context: PlaybackContext? = nil) {
        guard !playlist.tracks.isEmpty else { return }

        // Store original order before any shuffle
        originalPlaylistOrder = playlist.tracks
        shufflePlayedIndices.removeAll()
        playbackHistory.removeAll()

        currentPlaylist = playlist
        currentPlaylistIndex = startIndex

        // UNIFIED ARCHITECTURE: Set playback context
        playbackContext = context

        // SOOTHING MODE: Activate unstoppable playback for emergency cry response
        // When baby is crying, music MUST continue playing no matter what
        if case .emergencyCry = context {
            isSoothingModeActive = true
            print("[AudioEngine] 🛡️ SOOTHING MODE ACTIVATED - playback is now protected from interruptions")
        }

        // Mark the starting track as played for shuffle tracking
        shufflePlayedIndices.insert(startIndex)

        if currentPlaylistIndex < (currentPlaylist?.tracks.count ?? 0) {
            play(track: currentPlaylist!.tracks[currentPlaylistIndex])
        }

        // Start smart queue monitoring if auto-replenish enabled
        if playlist.isAutoReplenishing {
            monitorQueueForReplenishment()
        }
    }

    // MARK: - Smart Queue (Spotify-like behavior)

    /// Play a track within the context of a list of tracks (smart queue).
    /// This enables next/previous navigation like Spotify - when you tap a song
    /// in a category, the whole category becomes your queue.
    ///
    /// - Parameters:
    ///   - track: The track to start playing
    ///   - tracks: All tracks in the context (e.g., all tracks from a category)
    ///   - contextName: Name for the implicit playlist (e.g., "Classical Music")
    func play(track: AudioTrack, fromTracks tracks: [AudioTrack], contextName: String = "Queue") {
        guard !tracks.isEmpty else {
            // Fallback to single track play
            play(track: track)
            return
        }

        // Find the index of the selected track in the context
        guard let startIndex = tracks.firstIndex(where: { $0.id == track.id }) else {
            // Track not found in context, play as single track
            play(track: track)
            return
        }

        // Create an implicit playlist from the context
        let implicitPlaylist = Playlist(
            name: contextName,
            tracks: tracks,
            category: track.category
        )

        // Play as a playlist starting from the selected track
        play(playlist: implicitPlaylist, startIndex: startIndex)
    }

    /// Play a track within the context of a category.
    /// Automatically fetches all tracks from that category and creates a queue.
    ///
    /// - Parameters:
    ///   - track: The track to start playing
    ///   - category: The category to use as context for the queue
    func play(track: AudioTrack, fromCategory category: AudioCategory) {
        let categoryTracks = ContentLibraryService.shared.getTracks(for: category)
        play(track: track, fromTracks: categoryTracks, contextName: category.rawValue)
    }

    /// Play a playlist in shuffle mode starting with a random track
    func playShuffled(playlist: Playlist) {
        guard !playlist.tracks.isEmpty else { return }
        let randomIndex = Int.random(in: 0..<playlist.tracks.count)
        isShuffleEnabled = true
        play(playlist: playlist, startIndex: randomIndex)
    }

    func pause() {
        playerNode?.pause()
        audioPlayer?.pause()
        streamPlayer?.pause()
        noiseGenerator?.stop()
        playbackState = .paused
        stopProgressTimer()

        // Update Now Playing for Control Center / Lock Screen
        NowPlayingService.shared.updatePlaybackRate(isPlaying: false)

        // Report pause event
        if let track = currentTrack {
            Task {
                try? await APIClient.shared.reportPlayback(
                    trackId: track.id.uuidString,
                    event: .paused(position: currentTime)
                )
            }
        }
    }

    func resume() {
        playerNode?.play()
        audioPlayer?.play()
        streamPlayer?.play()
        if let track = currentTrack, track.audioSourceType == .generated {
            noiseGenerator?.start()
        }
        playbackState = .playing
        startProgressTimer()

        // Update Now Playing for Control Center / Lock Screen
        NowPlayingService.shared.updatePlaybackRate(isPlaying: true)

        // Report resume event
        if let track = currentTrack {
            Task {
                try? await APIClient.shared.reportPlayback(
                    trackId: track.id.uuidString,
                    event: .resumed(position: currentTime)
                )
            }
        }
    }

    func stop() {
        // CRITICAL FIX (2026-01-09): Cancel any in-progress crossfade
        // This prevents dual track playback when stop() is called during a crossfade
        if isCrossfading {
            print("[AudioEngine] ⚠️ Stopping during crossfade - cleaning up")
            // Clean up old stream player from crossfade
            if let oldStreamObserver = crossfadeOldTimeObserver {
                crossfadeOldStreamPlayer?.removeTimeObserver(oldStreamObserver)
            }
            crossfadeOldStreamPlayer?.pause()
            crossfadeOldStreamPlayer = nil
            crossfadeOldTimeObserver = nil
            isCrossfading = false
        }

        // Report completion if was playing
        if let track = currentTrack, playbackState == .playing {
            Task {
                try? await APIClient.shared.reportPlayback(
                    trackId: track.id.uuidString,
                    event: .completed(duration: currentTime)
                )
            }
        }

        stopCurrentPlayback()
        currentTrack = nil
        currentPlaylist = nil
        currentTime = 0
        duration = 0
        playbackState = .stopped
        isBuffering = false
        bufferProgress = 0

        // Clear Now Playing for Control Center / Lock Screen
        NowPlayingService.shared.clearNowPlayingInfo()

        // Clear soothing mode when fully stopped
        if isSoothingModeActive {
            isSoothingModeActive = false
            wasPlayingBeforeInterruption = false
            playbackContext = nil
            print("[AudioEngine] 🛡️ SOOTHING MODE DEACTIVATED - playback protection removed")
        }
    }

    /// Explicitly stop soothing mode and normal playback
    /// Call this when user deliberately wants to stop the baby-calming music
    /// This is the ONLY way to stop music during soothing mode (except for pause which still allows resume)
    func stopSoothingMode() {
        print("[AudioEngine] 🛡️ User explicitly stopped soothing mode")
        isSoothingModeActive = false
        wasPlayingBeforeInterruption = false
        stop()
    }

    func next() {
        // Check if there's a track in the "up next" queue first
        if !upNextQueue.isEmpty {
            let nextTrack = upNextQueue.removeFirst()
            // Note: play() now handles adding current track to history automatically
            play(track: nextTrack)

            // UNIFIED ARCHITECTURE: Check if we need to replenish queue
            checkAndReplenishQueue()
            return
        }

        guard let playlist = currentPlaylist else { return }

        // Handle repeat one mode - replay current track
        if repeatMode == .one {
            seek(to: 0)
            if playbackState != .playing {
                resume()
            }
            return
        }

        // Note: play() now handles adding current track to history automatically

        // Smart shuffle: pick random unplayed track
        if isShuffleEnabled {
            if let nextIndex = getNextShuffleIndex() {
                currentPlaylistIndex = nextIndex
                shufflePlayedIndices.insert(nextIndex)
                play(track: playlist.tracks[nextIndex])

                // UNIFIED ARCHITECTURE: Check if we need to replenish queue
                checkAndReplenishQueue()
            } else {
                // All tracks played in shuffle mode
                handleEndOfPlaylist()
            }
            return
        }

        // Normal sequential playback
        let nextIndex = currentPlaylistIndex + 1

        if nextIndex < playlist.tracks.count {
            currentPlaylistIndex = nextIndex
            play(track: playlist.tracks[nextIndex])

            // UNIFIED ARCHITECTURE: Check if we need to replenish queue
            checkAndReplenishQueue()
        } else {
            handleEndOfPlaylist()
        }
    }

    private func handleEndOfPlaylist() {
        guard let playlist = currentPlaylist else {
            stop()
            return
        }

        switch repeatMode {
        case .off:
            stop()
        case .all:
            // Reset shuffle state and start over
            shufflePlayedIndices.removeAll()
            if isShuffleEnabled {
                // Reshuffle and start fresh
                let randomIndex = Int.random(in: 0..<playlist.tracks.count)
                currentPlaylistIndex = randomIndex
                shufflePlayedIndices.insert(randomIndex)
                play(track: playlist.tracks[randomIndex])
            } else {
                currentPlaylistIndex = 0
                play(track: playlist.tracks[0])
            }
        case .one:
            // Should be handled before this
            break
        }
    }

    /// Get next random index that hasn't been played yet in shuffle mode
    private func getNextShuffleIndex() -> Int? {
        guard let playlist = currentPlaylist else { return nil }

        // Mark current track as played
        shufflePlayedIndices.insert(currentPlaylistIndex)

        // Get all unplayed indices
        let allIndices = Set(0..<playlist.tracks.count)
        let unplayedIndices = allIndices.subtracting(shufflePlayedIndices)

        if unplayedIndices.isEmpty {
            return nil // All tracks have been played
        }

        // Pick a random unplayed track
        return unplayedIndices.randomElement()
    }

    func previous() {
        // If more than 3 seconds into track, restart current track
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        // PLAYBACK HISTORY FIX: Use history for ALL modes, not just shuffle
        // This enables "previous" to work correctly regardless of how tracks were played:
        // - Manual selection from different categories
        // - AI recommendations ("More Like This")
        // - Smart queue suggestions
        // - Shuffle mode (original behavior)
        if !playbackHistory.isEmpty {
            let previousTrack = playbackHistory.removeLast()

            // Update shuffle tracking if in shuffle mode
            if isShuffleEnabled {
                if let playlist = currentPlaylist,
                   let index = playlist.tracks.firstIndex(where: { $0.id == previousTrack.id }) {
                    shufflePlayedIndices.remove(index)
                    currentPlaylistIndex = index
                }
            } else if let playlist = currentPlaylist,
                      let index = playlist.tracks.firstIndex(where: { $0.id == previousTrack.id }) {
                // Update playlist index if track is in current playlist
                currentPlaylistIndex = index
            }

            // Play WITHOUT adding to history (we're going backwards, not forwards)
            play(track: previousTrack, addToPlaybackHistory: false)
            return
        }

        // No history available - fall back to playlist navigation
        guard let playlist = currentPlaylist else { return }

        let previousIndex = currentPlaylistIndex - 1
        if previousIndex >= 0 {
            currentPlaylistIndex = previousIndex
            // Don't add to history - this is going backward in playlist
            play(track: playlist.tracks[previousIndex], addToPlaybackHistory: false)
        } else {
            // Go to last track (wrap around)
            currentPlaylistIndex = playlist.tracks.count - 1
            play(track: playlist.tracks[currentPlaylistIndex], addToPlaybackHistory: false)
        }
    }

    /// Add track to playback history
    private func addToHistory(_ track: AudioTrack?) {
        guard let track = track else { return }
        playbackHistory.append(track)
        // Keep history size manageable
        if playbackHistory.count > maxHistorySize {
            playbackHistory.removeFirst()
        }
    }

    func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, duration))
        // For generated audio, we don't actually seek - just update display
        audioPlayer?.currentTime = currentTime

        // Seek in stream player with proper tolerances for reliable seeking
        if let player = streamPlayer {
            // CRITICAL FIX: Use seek with tolerances for reliable seeking,
            // especially important immediately after playback starts.
            // Zero tolerance ensures frame-accurate seeking.
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

            // Check if player is ready to seek (has valid duration and loaded time ranges)
            guard let currentItem = player.currentItem,
                  currentItem.status == .readyToPlay else {
                print("[AudioEngine] ⚠️ Seek requested but player not ready, deferring...")
                // Player not ready - store the seek target and apply when ready
                pendingSeekTime = currentTime
                return
            }

            // Capture track before entering non-MainActor closure
            let trackToReport = currentTrack
            let targetTime = currentTime

            // Use zero tolerance for precise seeking, with completion handler
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                guard finished else {
                    print("[AudioEngine] ⚠️ Seek to \(targetTime)s was cancelled or failed")
                    return
                }

                // Report seek event
                if let track = trackToReport {
                    Task {
                        try? await APIClient.shared.reportPlayback(
                            trackId: track.id.uuidString,
                            event: .seeked(position: targetTime)
                        )
                    }
                }
            }
        }
    }

    /// Pending seek time when player wasn't ready - will be applied when player becomes ready
    private var pendingSeekTime: TimeInterval?

    func setVolume(_ newVolume: Float) {
        // Enforce safety limit
        volume = min(newVolume, maxSafeVolume)
        audioPlayer?.volume = volume
        playerNode?.volume = volume
        streamPlayer?.volume = volume
        noiseGenerator?.setVolume(volume)
    }

    // MARK: - Playback Rate Control
    func setPlaybackRate(_ rate: Float) {
        playbackRate = max(0.5, min(2.0, rate))
    }

    func cyclePlaybackRate() {
        let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
        if let currentIndex = rates.firstIndex(of: playbackRate) {
            let nextIndex = (currentIndex + 1) % rates.count
            playbackRate = rates[nextIndex]
        } else {
            playbackRate = 1.0
        }
    }

    private func applyPlaybackRate() {
        audioPlayer?.rate = playbackRate
        audioPlayer?.enableRate = true
        streamPlayer?.rate = playbackRate
    }

    // MARK: - Fast Forward / Rewind with Speed

    /// Timer for continuous seeking (retained to prevent leaks)
    private var seekTimer: Timer?

    /// Start fast forward/rewind at a given speed multiplier
    /// TECHNICAL DEBT FIX: Uses stored timer instead of untracked timer
    /// and DispatchQueue.main.async instead of Task to reduce allocations
    func startSeek(forward: Bool, speed: Int = 2) {
        // Stop any existing seek timer first
        seekTimer?.invalidate()

        isSeeking = true
        seekSpeed = speed
        let seekInterval: TimeInterval = 0.1 // Update every 100ms
        let seekAmount = TimeInterval(speed) * seekInterval

        // Start a timer for continuous seeking
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        seekTimer = Timer.scheduledTimer(withTimeInterval: seekInterval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                guard self.isSeeking else {
                    timer.invalidate()
                    self.seekTimer = nil
                    return
                }
                if forward {
                    let newTime = min(self.currentTime + seekAmount, self.duration)
                    self.seek(to: newTime)
                    if newTime >= self.duration {
                        self.stopSeek()
                    }
                } else {
                    let newTime = max(self.currentTime - seekAmount, 0)
                    self.seek(to: newTime)
                    if newTime <= 0 {
                        self.stopSeek()
                    }
                }
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode for smooth UI
        if let timer = seekTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopSeek() {
        isSeeking = false
        seekSpeed = 1
        seekTimer?.invalidate()
        seekTimer = nil
    }

    /// Skip forward by a fixed amount (default 15 seconds)
    func skipForward(seconds: TimeInterval = 15) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    /// Skip backward by a fixed amount (default 15 seconds)
    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    func toggleMute() {
        isMuted.toggle()
        let effectiveVolume = isMuted ? 0 : volume
        audioPlayer?.volume = effectiveVolume
        playerNode?.volume = effectiveVolume
        streamPlayer?.volume = effectiveVolume
        noiseGenerator?.setVolume(effectiveVolume)
    }

    // MARK: - Repeat & Shuffle

    func setRepeatMode(_ mode: RepeatMode) {
        repeatMode = mode
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()

        if isShuffleEnabled {
            // Turning shuffle ON
            if currentPlaylist != nil {
                // Reset shuffle state - current track is already "played"
                shufflePlayedIndices.removeAll()
                shufflePlayedIndices.insert(currentPlaylistIndex)
                playbackHistory.removeAll()
            }
        } else {
            // Turning shuffle OFF - restore original order
            restoreOriginalPlaylistOrder()
        }
    }

    /// Apply shuffle to playlist while keeping a specific track at the front
    private func applyShuffleToPlaylist(keepingTrackAt index: Int) {
        guard currentPlaylist != nil else { return }

        // The selected track becomes index 0
        shufflePlayedIndices.removeAll()
        shufflePlayedIndices.insert(index)
        currentPlaylistIndex = index
    }

    /// Restore the original playlist order when shuffle is turned off
    private func restoreOriginalPlaylistOrder() {
        guard !originalPlaylistOrder.isEmpty,
              let playlist = currentPlaylist,
              let currentTrack = currentTrack else { return }

        // Find where current track is in original order
        if let originalIndex = originalPlaylistOrder.firstIndex(where: { $0.id == currentTrack.id }) {
            // Restore original order
            currentPlaylist = Playlist(
                id: playlist.id,
                name: playlist.name,
                description: playlist.description,
                tracks: originalPlaylistOrder,
                category: playlist.category,
                targetAgeMonths: playlist.targetAgeMonths,
                isSystemGenerated: playlist.isSystemGenerated,
                createdAt: playlist.createdAt,
                artworkName: playlist.artworkName
            )
            currentPlaylistIndex = originalIndex
        }

        // Clear shuffle state
        shufflePlayedIndices.removeAll()
        playbackHistory.removeAll()
    }

    // MARK: - Queue Management (Spotify-like features)

    /// Add a track to play immediately after the current track
    func playNext(_ track: AudioTrack) {
        upNextQueue.insert(track, at: 0)
    }

    /// Add a track to the end of the queue
    func addToQueue(_ track: AudioTrack) {
        upNextQueue.append(track)
    }

    /// Add multiple tracks to the queue
    func addToQueue(_ tracks: [AudioTrack]) {
        upNextQueue.append(contentsOf: tracks)
    }

    /// Remove a track from the up next queue
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < upNextQueue.count else { return }
        upNextQueue.remove(at: index)
    }

    /// Clear the entire up next queue
    func clearQueue() {
        upNextQueue.removeAll()
    }

    /// Move a track within the queue
    func moveInQueue(from source: Int, to destination: Int) {
        guard source >= 0 && source < upNextQueue.count,
              destination >= 0 && destination < upNextQueue.count else { return }
        let track = upNextQueue.remove(at: source)
        upNextQueue.insert(track, at: destination)
    }

    // MARK: - Smart Queue Auto-Replenishment (Unified Architecture)

    /// Monitor queue and trigger replenishment when needed (Spotify-style infinite queue)
    private func monitorQueueForReplenishment() {
        // This is called periodically to check if we need more tracks
        print("[AudioEngine] 🔄 Smart queue monitoring enabled")
    }

    /// Check if queue needs replenishment and add more tracks
    private func checkAndReplenishQueue() {
        guard let playlist = currentPlaylist,
              playlist.isAutoReplenishing,
              let context = playlist.generationContext else {
            return
        }

        // Calculate how many tracks remain
        let remainingInPlaylist = playlist.tracks.count - (currentPlaylistIndex + 1)
        let remainingInQueue = upNextQueue.count
        let totalRemaining = remainingInPlaylist + remainingInQueue

        print("[AudioEngine] 🔍 Queue check: \(totalRemaining) tracks remaining (min: \(playlist.minQueueSize))")

        // If below threshold, replenish
        if totalRemaining < playlist.minQueueSize {
            print("[AudioEngine] 🎵 Queue below threshold - replenishing...")
            Task {
                await replenishQueue(context: context, tracksNeeded: playlist.minQueueSize - totalRemaining)
            }
        }
    }

    /// Generate and add more tracks to the queue
    private func replenishQueue(context: PlaylistGenerationMetadata, tracksNeeded: Int) async {
        print("[AudioEngine] 🔄 Generating \(tracksNeeded) more tracks for smart queue")

        let builder = SmartPlaylistBuilder.shared
        let newTracks = await builder.generateMoreTracks(context: context, count: tracksNeeded)

        // Add to queue
        await MainActor.run {
            addToQueue(newTracks)
            print("[AudioEngine] ✅ Added \(newTracks.count) tracks to queue")
        }
    }

    /// Get remaining tracks count (queue + remaining playlist)
    var remainingTracksCount: Int {
        var count = upNextQueue.count
        if let playlist = currentPlaylist {
            if isShuffleEnabled {
                let remaining = playlist.tracks.count - shufflePlayedIndices.count
                count += max(0, remaining)
            } else {
                count += max(0, playlist.tracks.count - currentPlaylistIndex - 1)
            }
        }
        return count
    }

    // MARK: - Sleep Timer
    func setSleepTimer(_ timer: SleepTimer) {
        sleepTimer = timer
        sleepTimerInstance?.invalidate()

        guard timer != .off else {
            sleepTimerRemaining = 0
            return
        }

        sleepTimerRemaining = timer.seconds

        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        sleepTimerInstance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sleepTimerRemaining -= 1

                if self.sleepTimerRemaining <= 0 {
                    self.fadeOutAndStop()
                }
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode for smooth UI
        if let timer = sleepTimerInstance {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - Generated Audio Playback
    private func playGeneratedAudio(track: AudioTrack) {
        guard let generatorType = track.generatorType else {
            playbackState = .error("No generator type specified")
            return
        }

        print("[AudioEngine] 🎛️ Starting generated audio: \(generatorType.rawValue)")
        print("[AudioEngine] 📢 Volume: \(volume), Muted: \(isMuted), Crossfading: \(isCrossfading)")

        // Use AudioSessionManager to configure audio session for playback.
        // This ensures exclusive playback mode (pauses other audio apps).
        do {
            try AudioSessionManager.shared.activateSessionSync(
                mode: .emergencyPlayback,
                priority: .emergency,
                serviceId: "AudioEngine-Generated"
            )
            print("[AudioEngine] ✅ Audio session activated via AudioSessionManager for generated audio")
        } catch {
            print("[AudioEngine] ⚠️ Failed to configure audio session: \(error)")
            // Continue anyway - the NoiseGenerator.start() will also try to activate
        }

        // Stop any existing noise generator (but not during crossfade - old one is managed separately)
        if noiseGenerator != nil && !isCrossfading {
            print("[AudioEngine] 🛑 Stopping existing noise generator")
            noiseGenerator?.stop()
            // 🚨 PERFORMANCE FIX: Brief delay to let the old engine fully stop
            // This prevents audio glitches when rapidly switching generators
            noiseGenerator = nil  // Release immediately to free resources
        }

        // Create and start new noise generator
        print("[AudioEngine] 🔨 Creating new NoiseGenerator for \(generatorType.rawValue)")
        let newGenerator = NoiseGenerator(type: generatorType)
        noiseGenerator = newGenerator

        // During crossfade, start at volume 0 for smooth fade-in
        let actualVolume: Float = isCrossfading ? 0 : (isMuted ? 0 : volume)
        print("[AudioEngine] 🔊 Setting volume to \(actualVolume)")
        noiseGenerator?.setVolume(actualVolume)
        print("[AudioEngine] ▶️ Starting NoiseGenerator...")
        noiseGenerator?.start()

        playbackState = .playing
        startProgressTimer()

        // For infinite/looping sounds, set a long duration
        duration = track.duration > 0 ? track.duration : 3600

        print("[AudioEngine] ✅ Generated audio pipeline complete - UI updated, timer started")
    }

    private func playBundledAudio(track: AudioTrack) {
        guard let fileName = track.fileName,
              let fileExtension = track.fileExtension else {
            playbackState = .error("No audio file specified")
            return
        }

        // CRITICAL FIX: Ensure audio session is active BEFORE creating AVAudioPlayer
        ensureAudioSessionActive()

        // Try multiple paths to find the audio file
        var url: URL?

        // Try direct bundle lookup
        url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)

        // Try with subdirectory based on category
        if url == nil {
            let subdirectories: [String]
            switch track.category {
            case .classicalMusic:
                subdirectories = ["Audio/classical"]
            case .childrenSongs:
                subdirectories = ["Audio/children", "Audio/lullabies"]
            case .natureSounds:
                subdirectories = ["Audio/nature"]
            case .ambient:
                subdirectories = ["Audio/ambient"]
            case .lullabies:
                subdirectories = ["Audio/lullabies"]
            case .instrumental:
                // Instrumental tracks are stored in lullabies folder (bells, harp, soft_guitar, dreamy_arp)
                subdirectories = ["Audio/lullabies", "Audio/ambient"]
            case .fairyTales:
                // Support both English and Russian fairytales
                if track.language == .russian {
                    subdirectories = ["Audio/fairytales/ru", "Audio/fairytales"]
                } else {
                    subdirectories = ["Audio/fairytales/en", "Audio/fairytales"]
                }
            default:
                subdirectories = ["Audio"]
            }
            for subdirectory in subdirectories {
                url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory)
                if url != nil { break }
            }
        }

        // Try Resources/Audio path
        if url == nil {
            url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Resources/Audio")
        }

        // Try all known audio subdirectories as a last resort
        if url == nil {
            let allSubdirectories = ["Audio/default", "Audio/children", "Audio/lullabies", "Audio/classical", "Audio/nature", "Audio/ambient", "Audio/podcasts", "Audio/meditation", "Audio/fairytales/en", "Audio/fairytales/ru", "Audio/acoustic"]
            for subdirectory in allSubdirectories {
                url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory)
                if url != nil {
                    print("Found audio file in \(subdirectory): \(fileName).\(fileExtension)")
                    break
                }
            }
        }

        guard let audioURL = url else {
            print("Audio file not found: \(fileName).\(fileExtension)")
            // Fallback to generated audio if file not found
            if let generatorType = track.generatorType {
                var fallbackTrack = track
                fallbackTrack.generatorType = generatorType
                playGeneratedAudio(track: fallbackTrack)
            } else {
                playbackState = .error("Audio file not found: \(fileName)")
            }
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            // During crossfade, start at volume 0 for smooth fade-in
            let initialVolume: Float = isCrossfading ? 0 : (isMuted ? 0 : volume)
            audioPlayer?.volume = initialVolume
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            duration = audioPlayer?.duration ?? track.duration
            playbackState = .playing
            startProgressTimer()
            print("Playing bundled audio: \(audioURL.lastPathComponent), volume: \(initialVolume)")
        } catch {
            print("Failed to play audio: \(error)")
            playbackState = .error("Failed to play audio: \(error.localizedDescription)")
        }
    }

    private func playStreamedAudio(track: AudioTrack) {
        // Use serverId for API calls if available, otherwise fall back to UUID string
        let trackId = track.serverId ?? track.id.uuidString

        // First, check if we have a cached version
        if let cachedURL = cacheService.getCachedURL(for: trackId) {
            playCachedAudio(url: cachedURL, track: track)
            cacheService.updateLastPlayed(trackId: trackId)
            return
        }

        // Get stream URL from track or fetch from API
        Task {
            do {
                let streamURL: URL

                if let urlString = track.streamURL, !urlString.isEmpty, let url = URL(string: urlString) {
                    streamURL = url
                    print("[AudioEngine] 🎵 Using existing streamURL: \(urlString.prefix(50))...")
                } else {
                    // Fetch stream URL from API using serverId
                    print("[AudioEngine] 🔄 Fetching stream URL for trackId: \(trackId)")
                    let response = try await APIClient.shared.getStreamURL(trackId: trackId)
                    guard let url = URL(string: response.streamUrl) else {
                        throw DownloadError.invalidURL
                    }
                    streamURL = url
                    print("[AudioEngine] ✅ Got stream URL: \(response.streamUrl.prefix(50))...")
                }

                // Use AVPlayer for progressive streaming
                playProgressiveStream(url: streamURL, track: track)

                // Start background download for caching
                startBackgroundDownload(track: track)

            } catch {
                print("[AudioEngine] ❌ Streaming failed for '\(track.title)': \(error)")
                // Fallback to generated audio if streaming fails
                if track.generatorType != nil {
                    print("[AudioEngine] 🔄 Falling back to generated audio")
                    playGeneratedAudio(track: track)
                } else {
                    playbackState = .error("Failed to stream: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Play audio using AVPlayer for progressive streaming
    private func playProgressiveStream(url: URL, track: AudioTrack) {
        // CRITICAL FIX: Ensure audio session is active BEFORE creating AVPlayer
        // Without an active audio session, AVPlayer will buffer but produce no sound!
        // This is a defensive measure in case configureAudioSession wasn't called earlier
        ensureAudioSessionActive()

        // During crossfade, DON'T clean up - the old stream is managed separately
        // Only clean up if NOT crossfading
        if !isCrossfading {
            cleanupStreamPlayer()
        }

        isBuffering = true
        bufferProgress = 0

        // During crossfade, start at volume 0 for smooth fade-in
        // Otherwise use normal volume
        let initialVolume: Float = isCrossfading ? 0 : (isMuted ? 0 : volume)

        // MEMORY OPTIMIZATION (Increment 0028): Check LRU cache first
        let playerItem: AVPlayerItem
        if let cachedPlayer = getCachedBuffer(for: track.id) {
            // Reuse cached player - just update the item
            playerItem = AVPlayerItem(url: url)
            cachedPlayer.replaceCurrentItem(with: playerItem)
            streamPlayer = cachedPlayer
            streamPlayer?.volume = initialVolume
            print("[AudioEngine] 🚀 Reusing cached AVPlayer for track \(track.title)")
        } else {
            // Create new player and cache it
            playerItem = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.volume = initialVolume
            streamPlayer = newPlayer

            // Add to LRU cache
            cacheBuffer(trackId: track.id, player: newPlayer)
        }

        // Observe buffering status
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.duration = item.duration.seconds.isNaN ? track.duration : item.duration.seconds

                    // CRITICAL FIX: If stream became ready AFTER crossfade completed,
                    // ensure volume is set to the user's desired level before playing
                    // During crossfade, the crossfade timer handles volume fading
                    if !self.isCrossfading {
                        // Crossfade is done - apply final volume
                        let targetVolume = self.isMuted ? 0 : self.volume
                        self.streamPlayer?.volume = targetVolume
                        print("[AudioEngine] 🔊 Stream ready (post-crossfade) - applied volume: \(targetVolume)")
                    } else {
                        // Crossfade in progress - crossfade timer will handle volume
                        print("[AudioEngine] 🎶 Stream ready during crossfade - volume controlled by crossfade timer")
                    }

                    self.streamPlayer?.play()
                    self.playbackState = .playing
                    self.setupStreamTimeObserver()

                    // Apply any pending seek that was requested before player was ready
                    if let pendingTime = self.pendingSeekTime {
                        self.pendingSeekTime = nil
                        print("[AudioEngine] ⏩ Applying deferred seek to \(pendingTime)s")
                        self.seek(to: pendingTime)
                    }

                    // Report playback started (this can stay as Task - it's async network call)
                    Task {
                        try? await APIClient.shared.reportPlayback(trackId: track.id.uuidString, event: .started)
                    }

                case .failed:
                    self.isBuffering = false
                    if let error = item.error {
                        self.playbackState = .error("Playback failed: \(error.localizedDescription)")
                    }

                default:
                    break
                }
            }
        }

        // Observe buffer progress
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isBuffering = true
            }
        }

        // Observe playback finished
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleTrackEnd()
            }
        }
    }

    /// Setup time observer for stream player
    private func setupStreamTimeObserver() {
        guard let player = streamPlayer else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // CRITICAL FIX: Use nil queue (fires on arbitrary queue) then dispatch to main
        // This avoids "Publishing changes from within view updates" warnings
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
            // Dispatch to main queue asynchronously to avoid view update conflicts
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // CRITICAL FIX: Don't update currentTime while user is scrubbing the slider
                // This prevents the slider from "jumping back" during seek operations
                if !self.isScrubbing {
                    self.currentTime = time.seconds
                }

                // Update buffer progress (always, even during scrubbing)
                if let item = player.currentItem {
                    let loadedRanges = item.loadedTimeRanges
                    if let firstRange = loadedRanges.first?.timeRangeValue {
                        let bufferedEnd = CMTimeGetSeconds(CMTimeAdd(firstRange.start, firstRange.duration))
                        let duration = CMTimeGetSeconds(item.duration)
                        if duration > 0 {
                            self.bufferProgress = bufferedEnd / duration
                        }
                    }
                }
            }
        }
    }

    /// Play cached audio file
    private func playCachedAudio(url: URL, track: AudioTrack) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            // During crossfade, start at volume 0 for smooth fade-in
            let initialVolume: Float = isCrossfading ? 0 : (isMuted ? 0 : volume)
            audioPlayer?.volume = initialVolume
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            duration = audioPlayer?.duration ?? track.duration
            playbackState = .playing
            startProgressTimer()

            // Report playback started
            Task {
                try? await APIClient.shared.reportPlayback(trackId: track.id.uuidString, event: .started)
            }

            print("Playing cached audio: \(url.lastPathComponent), volume: \(initialVolume)")
        } catch {
            print("Failed to play cached audio: \(error)")
            // Try streaming instead
            playProgressiveStream(url: url, track: track)
        }
    }

    /// Start background download for caching
    private func startBackgroundDownload(track: AudioTrack) {
        guard track.audioSourceType == .streamed else { return }

        Task {
            do {
                let localURL = try await downloadManager.downloadTrack(track)
                // Get file size for metadata
                let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                cacheService.saveTrackMetadata(track, fileSize: fileSize)
                print("Track cached for offline: \(track.title)")
            } catch {
                print("Background caching failed: \(error)")
            }
        }
    }

    /// Clean up stream player
    private func cleanupStreamPlayer() {
        if let observer = timeObserver {
            streamPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }

        playerItemObserver = nil
        streamPlayer?.pause()
        streamPlayer = nil

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func playTextToSpeech(track: AudioTrack) {
        // Text-to-speech will be handled by SpeechSynthesizer service
        // For now, play a placeholder or generated sound
        playGeneratedAudio(track: track)
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        progressTimer?.invalidate()
        // PERFORMANCE FIX: Reduced from 0.5s to 1.0s (industry standard like Spotify)
        // Reduces CPU usage by 50% and prevents phone overheating
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
            // to avoid "Publishing changes from within view updates" warnings
            // which cause UI freezes when timer fires during SwiftUI render cycle
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // CRITICAL FIX: Don't update currentTime while user is scrubbing
                // This prevents the slider from "fighting" with user input
                guard !self.isScrubbing else { return }

                // CRITICAL FIX: Only read from active players to prevent timeline flickering
                // Try bundled player first (AVAudioPlayer)
                if let player = self.audioPlayer, player.isPlaying {
                    self.currentTime = player.currentTime
                }
                // Try streamed player (AVPlayer)
                else if let player = self.streamPlayer, player.rate > 0 {
                    self.currentTime = CMTimeGetSeconds(player.currentTime())
                }
                // For generated audio or when no active player, increment manually
                else if self.playbackState == .playing {
                    self.currentTime += 1.0  // Changed from 0.5 to match new 1.0s interval
                    if self.currentTime >= self.duration {
                        self.handleTrackEnd()
                    }
                }

                // Update Now Playing time for Control Center / Lock Screen scrubber
                NowPlayingService.shared.updatePlaybackTime()
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode
        // This ensures timer fires during scrolling/gestures for smooth UI
        if let timer = progressTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func stopCurrentPlayback() {
        stopProgressTimer()

        // CRITICAL FIX (2026-01-09): Stop fade timer to prevent dual track playback
        // If a fade-in is in progress, cancel it immediately
        fadeTimer?.invalidate()
        fadeTimer = nil

        audioPlayer?.stop()
        audioPlayer = nil

        // MEMORY OPTIMIZATION (Increment 0022): Release AVAudioPlayerNode buffers
        if let player = playerNode {
            releaseBuffer(for: player)
        }

        cleanupStreamPlayer()
        noiseGenerator?.stop()
        noiseGenerator = nil
        currentTime = 0

        // Clear any pending seek when stopping playback
        pendingSeekTime = nil
    }

    // MARK: - Memory Optimization (Increment 0022)

    /// Release AVAudioPlayerNode buffers to free memory
    /// Call this when a track finishes playing to prevent buffer accumulation
    func releaseBuffer(for playerNode: AVAudioPlayerNode) {
        // Stop the player node
        playerNode.stop()

        // Force buffer release by resetting the node
        // This deallocates any AVAudioPCMBuffer objects held by the node
        playerNode.reset()

        print("[AudioEngine] 🗑️ Released buffer for player node")
    }

    /// Clean up inactive audio resources to reduce memory usage
    /// Should be called periodically or on memory warnings
    /// - Parameter aggressive: If true, performs more aggressive cleanup (for critical/emergency memory)
    func cleanup(aggressive: Bool = false) {
        // 🚨 CRITICAL FIX (2026-01-09): COMPREHENSIVE emergency mode protection
        // Memory cleanup was causing "broken radio" audio artifacts by:
        // 1. Interrupting NoiseGenerator's AVAudioSourceNode callback
        // 2. Triggering audio route reconfigurations
        // 3. Causing brief pauses that sound like static/interference
        //
        // Emergency audio is the app's PRIMARY PURPOSE - baby calming MUST continue.
        // The memory can wait - the crying baby cannot.
        //
        // EXPANDED GUARD: Check ALL emergency conditions, not just emergency queue
        let isEmergencyActive = false /* emergency queue removed */
        let hasNoiseGenerator = noiseGenerator != nil
        let isPlaying = playbackState == .playing
        let isStreamingEmergency = streamPlayer?.rate ?? 0 > 0 && isEmergencyActive

        if isEmergencyActive && (hasNoiseGenerator || isStreamingEmergency) {
            print("[AudioEngine] 🚨 SKIPPING cleanup - emergency audio is playing!")
            print("[AudioEngine] ℹ️ NoiseGen: \(hasNoiseGenerator), Streaming: \(isStreamingEmergency)")
            return
        }

        // Also skip if any audio is actively playing to prevent glitches
        if isPlaying && (hasNoiseGenerator || audioPlayer?.isPlaying == true || (streamPlayer?.rate ?? 0) > 0) {
            print("[AudioEngine] ⏸️ Deferring cleanup - audio actively playing")
            return
        }

        print("[AudioEngine] 🧹 Starting cleanup (aggressive: \(aggressive))")

        // MEMORY OPTIMIZATION (Increment 0029): Use autoreleasepool for immediate deallocation
        autoreleasepool {
            // Release player node if not playing AND not paused (allow resume from pause)
            if playbackState != .playing && playbackState != .paused, let player = playerNode {
                releaseBuffer(for: player)
                playerNode = nil
                print("[AudioEngine] 🧹 Cleaned up inactive player node")
            }

            // Clear cached audio player if not in use AND not paused
            if audioPlayer?.isPlaying == false && playbackState != .paused {
                audioPlayer = nil
                print("[AudioEngine] 🧹 Cleared inactive audio player")
            }

            // Clean up stream player if stopped (NOT if paused - need to resume!)
            // CRITICAL FIX: Don't clean up streamPlayer when paused, otherwise resume() won't work
            if streamPlayer?.rate == 0 && playbackState != .paused {
                cleanupStreamPlayer()
                print("[AudioEngine] 🧹 Cleaned up inactive stream player")
            }

            // MEMORY OPTIMIZATION (Increment 0029): Aggressive cache cleanup
            if aggressive {
                // Under memory pressure - reduce cache limit and clear aggressively
                isUnderMemoryPressure = true
                maxRecentBuffers = emergencyMaxRecentBuffers
                clearBufferCacheAggressive(keepCurrent: true)

                // Clear playback history to free memory
                let historyCount = playbackHistory.count
                playbackHistory.removeAll()
                print("[AudioEngine] 🧹 Cleared playback history (\(historyCount) entries)")

                // Clear up next queue if not actively playing
                if playbackState != .playing {
                    let queueCount = upNextQueue.count
                    upNextQueue.removeAll()
                    print("[AudioEngine] 🧹 Cleared up-next queue (\(queueCount) tracks)")
                }
            } else {
                // Normal cleanup - just clear the buffer cache
                clearBufferCache()
            }
        }

        // Listen for memory warnings and clean up automatically
        NotificationCenter.default.post(name: NSNotification.Name("AudioEngineDidCleanup"), object: nil)
        print("[AudioEngine] ✅ Cleanup complete")
    }

    /// Restore normal cache limits after memory pressure resolves
    func restoreNormalCacheLimits() {
        if isUnderMemoryPressure {
            isUnderMemoryPressure = false
            maxRecentBuffers = defaultMaxRecentBuffers
            print("[AudioEngine] ✅ Restored normal cache limits (max: \(maxRecentBuffers))")
        }
    }

    // MARK: - LRU Buffer Cache (Increment 0028)

    /// Check if a track's buffer is in the LRU cache
    /// - Parameter trackId: Track UUID
    /// - Returns: Cached AVPlayer if available
    private func getCachedBuffer(for trackId: UUID) -> AVPlayer? {
        if let index = recentlyPlayedBuffers.firstIndex(where: { $0.trackId == trackId }) {
            // Move to end (most recently used)
            let cached = recentlyPlayedBuffers.remove(at: index)
            recentlyPlayedBuffers.append(cached)
            print("[AudioEngine] 🎯 LRU cache HIT for track \(trackId)")
            // Restore the time observer reference so cleanup works properly
            if cached.timeObserver != nil {
                timeObserver = cached.timeObserver
            }
            return cached.player
        }
        print("[AudioEngine] ❌ LRU cache MISS for track \(trackId)")
        return nil
    }

    /// Add a player to the LRU cache, evicting oldest if needed
    /// - Parameters:
    ///   - trackId: Track UUID
    ///   - player: AVPlayer instance
    private func cacheBuffer(trackId: UUID, player: AVPlayer) {
        // MEMORY OPTIMIZATION (Increment 0029): Skip caching during memory pressure
        if isUnderMemoryPressure || maxRecentBuffers <= 0 {
            print("[AudioEngine] ⏭️ Skipping cache - under memory pressure or cache disabled")
            return
        }

        // Remove if already exists (to update position)
        if let index = recentlyPlayedBuffers.firstIndex(where: { $0.trackId == trackId }) {
            let old = recentlyPlayedBuffers.remove(at: index)
            // Clean up the old time observer if it exists
            if let observer = old.timeObserver {
                old.player.removeTimeObserver(observer)
            }
        }

        // Add to end (most recent) - capture current time observer
        recentlyPlayedBuffers.append((trackId: trackId, player: player, timeObserver: timeObserver))

        // Evict oldest if over limit (use autoreleasepool for immediate deallocation)
        autoreleasepool {
            while recentlyPlayedBuffers.count > maxRecentBuffers {
                let evicted = recentlyPlayedBuffers.removeFirst()
                // MEMORY FIX (0030): Remove time observer to prevent leak
                if let observer = evicted.timeObserver {
                    evicted.player.removeTimeObserver(observer)
                }
                // Clean up evicted player thoroughly
                evicted.player.pause()
                if let currentItem = evicted.player.currentItem {
                    // Remove all observers before releasing
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: currentItem)
                }
                evicted.player.replaceCurrentItem(with: nil)
                print("[AudioEngine] 🗑️ LRU cache EVICTED track \(evicted.trackId) (cache size: \(recentlyPlayedBuffers.count)/\(maxRecentBuffers))")
            }
        }

        print("[AudioEngine] 💾 LRU cache STORED track \(trackId) (cache size: \(recentlyPlayedBuffers.count)/\(maxRecentBuffers))")
    }

    /// Clear the entire LRU cache (called during memory cleanup)
    private func clearBufferCache() {
        guard !recentlyPlayedBuffers.isEmpty else { return }

        let count = recentlyPlayedBuffers.count
        autoreleasepool {
            for cached in recentlyPlayedBuffers {
                // MEMORY FIX (0030): Remove time observer to prevent leak
                if let observer = cached.timeObserver {
                    cached.player.removeTimeObserver(observer)
                }
                cached.player.pause()
                if let currentItem = cached.player.currentItem {
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: currentItem)
                }
                cached.player.replaceCurrentItem(with: nil)
            }
            recentlyPlayedBuffers.removeAll()
        }
        print("[AudioEngine] 🧹 Cleared LRU buffer cache (\(count) buffers released)")
    }

    /// Aggressive cache cleanup - keeps only current playing track's buffer
    /// - Parameter keepCurrent: If true, preserves the currently playing track's buffer
    private func clearBufferCacheAggressive(keepCurrent: Bool) {
        guard !recentlyPlayedBuffers.isEmpty else { return }

        let currentTrackId = currentTrack?.id
        var keptCount = 0
        var clearedCount = 0

        autoreleasepool {
            var buffersToKeep: [(trackId: UUID, player: AVPlayer, timeObserver: Any?)] = []

            for cached in recentlyPlayedBuffers {
                if keepCurrent && cached.trackId == currentTrackId {
                    // Keep the current track's buffer
                    buffersToKeep.append(cached)
                    keptCount += 1
                } else {
                    // MEMORY FIX (0030): Remove time observer to prevent leak
                    if let observer = cached.timeObserver {
                        cached.player.removeTimeObserver(observer)
                    }
                    // Release this buffer
                    cached.player.pause()
                    if let currentItem = cached.player.currentItem {
                        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: currentItem)
                    }
                    cached.player.replaceCurrentItem(with: nil)
                    clearedCount += 1
                }
            }

            recentlyPlayedBuffers = buffersToKeep
        }

        print("[AudioEngine] 🧹 Aggressive cache cleanup: cleared \(clearedCount), kept \(keptCount)")
    }

    private func handleTrackEnd() {
        handleTrackEndInternal()
    }

    /// Called by AudioPlayerDelegate when audio finishes playing
    func handleTrackEndFromDelegate() {
        handleTrackEndInternal()
    }

    private func handleTrackEndInternal() {
        // Handle repeat one mode - replay current track
        if repeatMode == .one {
            if let track = currentTrack {
                // Re-play the track from beginning
                play(track: track)
            } else {
                seek(to: 0)
                if playbackState != .playing {
                    resume()
                }
            }
            return
        }

        if currentPlaylist != nil {
            next()
        } else {
            // Single track playback - check repeat mode
            if repeatMode == .all {
                // Repeat the single track
                if let track = currentTrack {
                    play(track: track)
                } else {
                    seek(to: 0)
                    if playbackState != .playing {
                        resume()
                    }
                }
            } else {
                // Track ended, no playlist, no repeat - stop playback
                print("[AudioEngine] Track ended, no playlist, no repeat - stopping")
                stop()
            }
        }
    }

    // MARK: - Fade Out

    /// Gracefully fade out audio and stop playback
    /// - Parameter duration: Total fade duration in seconds (default 2.5s for "Baby is Calm")
    func fadeOutAndStop(duration: TimeInterval = 2.5) {
        let fadeSteps = 25  // Smooth fade with 25 steps
        let stepDuration: TimeInterval = duration / Double(fadeSteps)
        var currentStep = 0
        let initialVolume = volume

        // Cancel any existing fade
        fadeTimer?.invalidate()

        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        let newTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1

                // Exponential fade curve for more natural sound decay
                let progress = Float(currentStep) / Float(fadeSteps)
                let curve = 1.0 - pow(progress, 2) // Quadratic ease-out
                let newVolume = initialVolume * curve
                self.setVolume(max(0, newVolume))

                if currentStep >= fadeSteps {
                    timer.invalidate()
                    self.fadeTimer = nil
                    self.stop()
                    self.setVolume(initialVolume) // Restore volume for next play
                    self.sleepTimer = .off
                }
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode for smooth UI
        RunLoop.main.add(newTimer, forMode: .common)
        fadeTimer = newTimer
    }

    /// Legacy private method for sleep timer (calls public method)
    private func fadeOutForSleepTimer() {
        fadeOutAndStop(duration: 10.0) // Slower fade for sleep timer
    }

    // MARK: - Progress (for FS-017 Emergency Queue)

    /// Current playback progress as a value from 0.0 to 1.0
    var currentProgress: Double {
        guard duration > 0 else { return 0.0 }
        return currentTime / duration
    }

    // MARK: - Crossfade & Fade-In

    /// Public crossfade method for transitioning between tracks (FS-017 Emergency Queue)
    /// - Parameters:
    ///   - track: The new track to crossfade to
    ///   - duration: Duration of the crossfade in seconds (default 2.0)
    func crossfade(to track: AudioTrack, duration: TimeInterval = 2.0) async throws {
        crossfadeToTrack(track, duration: duration)
    }

    /// Crossfade from current track to new track
    private func crossfadeToTrack(_ newTrack: AudioTrack, duration: TimeInterval) {
        let fadeSteps = 20
        let stepDuration = duration / Double(fadeSteps)
        var currentStep = 0
        let initialVolume = volume

        print("[AudioEngine] 🎶 Starting crossfade to '\(newTrack.title)' over \(duration)s")

        // CRITICAL FIX: Configure audio session before crossfade
        // This ensures audio works after emergency mode stops
        // IMPORTANT: Check if emergency queue is active - if so, keep emergency audio session!
        let isEmergencyActive = false /* emergency queue removed */
        if !isEmergencyActive {
            // Only configure normal audio session if NOT in emergency mode
            configureAudioSession(interruptOtherAudio: false)
        } else {
            // In emergency mode - don't reset audio session, it was already configured
            print("[AudioEngine] 🚨 Emergency mode active - preserving emergency audio session (crossfade)")
        }

        // Store old playback components BEFORE setting crossfade flag
        var oldPlayer = audioPlayer
        var oldPlayerNode = playerNode
        var oldNoiseGenerator = noiseGenerator

        // CRITICAL: For stream players, store separately and keep playing during crossfade
        // The cleanupStreamPlayer() will check isCrossfading flag and skip cleanup
        if let oldStream = streamPlayer {
            crossfadeOldStreamPlayer = oldStream
            crossfadeOldTimeObserver = timeObserver
            timeObserver = nil  // Clear so new track gets its own observer
            streamPlayer = nil  // Clear so new track creates fresh player
        }

        // Set crossfade flag AFTER storing old components
        isCrossfading = true

        // Prepare new track (but don't start yet)
        currentTrack = newTrack
        self.duration = newTrack.duration

        // Update Now Playing info for Control Center / Lock Screen / CarPlay
        NowPlayingService.shared.updateNowPlayingInfo(track: newTrack)
        playbackState = .loading

        // DON'T set volume to 0 here - let each player type handle its own initial volume
        // The new player will be created at 0 volume and faded in

        switch newTrack.audioSourceType {
        case .generated:
            playGeneratedAudio(track: newTrack)
        case .bundled:
            playBundledAudio(track: newTrack)
        case .streamed:
            playStreamedAudio(track: newTrack)
        case .textToSpeech:
            playTextToSpeech(track: newTrack)
        }

        // Crossfade timer
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let progress = Float(currentStep) / Float(fadeSteps)

                // Fade out old track (quadratic ease-out for smooth decay)
                let fadeOutCurve = 1.0 - pow(progress, 2)
                let fadeOutVolume = initialVolume * fadeOutCurve
                oldPlayer?.volume = fadeOutVolume
                oldPlayerNode?.volume = fadeOutVolume
                self.crossfadeOldStreamPlayer?.volume = fadeOutVolume

                // Fade in new track (quadratic ease-in for smooth rise)
                let fadeInCurve = pow(progress, 2)
                let fadeInVolume = initialVolume * fadeInCurve

                // Apply fade-in to current players
                // NOTE: We set volume on each player individually, NOT on self.volume
                // self.volume represents the user's desired level and should NOT change during crossfade
                self.audioPlayer?.volume = fadeInVolume
                self.playerNode?.volume = fadeInVolume
                self.streamPlayer?.volume = fadeInVolume
                self.noiseGenerator?.setVolume(fadeInVolume)

                if currentStep >= fadeSteps {
                    timer.invalidate()
                    self.fadeTimer = nil
                    self.isCrossfading = false

                    // Stop old playback (AVPlayer uses pause, not stop)
                    oldPlayer?.pause()
                    oldPlayer?.stop()
                    oldPlayerNode?.stop()
                    oldNoiseGenerator?.stop()

                    // MEMORY FIX (0030): Clean up old stream player thoroughly
                    if let oldStreamObserver = self.crossfadeOldTimeObserver {
                        self.crossfadeOldStreamPlayer?.removeTimeObserver(oldStreamObserver)
                    }
                    self.crossfadeOldStreamPlayer?.pause()
                    self.crossfadeOldStreamPlayer?.replaceCurrentItem(with: nil)
                    self.crossfadeOldStreamPlayer = nil
                    self.crossfadeOldTimeObserver = nil

                    // CRITICAL FIX: Nullify old players to prevent audio overlap
                    // This ensures progress timer and audio engine don't access stale players
                    oldPlayer = nil
                    oldPlayerNode = nil
                    oldNoiseGenerator = nil

                    // Restore full volume
                    self.volume = initialVolume
                    self.audioPlayer?.volume = initialVolume
                    self.playerNode?.volume = initialVolume
                    self.streamPlayer?.volume = initialVolume
                    self.noiseGenerator?.setVolume(initialVolume)

                    print("[AudioEngine] ✅ Crossfade complete to '\(newTrack.title)'")
                }
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode for smooth UI
        if let timer = fadeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Cancel an in-progress crossfade and clean up all audio players
    /// CRITICAL FIX (2026-01-09): Prevents dual track playback when user rapidly switches tracks
    private func cancelCrossfade() {
        guard isCrossfading else { return }

        print("[AudioEngine] 🛑 Cancelling crossfade...")

        // Stop the crossfade timer
        fadeTimer?.invalidate()
        fadeTimer = nil

        // MEMORY FIX (0030): Thoroughly clean up the OLD stream player (fading out)
        if let oldStreamObserver = crossfadeOldTimeObserver {
            crossfadeOldStreamPlayer?.removeTimeObserver(oldStreamObserver)
        }
        crossfadeOldStreamPlayer?.pause()
        crossfadeOldStreamPlayer?.replaceCurrentItem(with: nil)
        crossfadeOldStreamPlayer = nil
        crossfadeOldTimeObserver = nil

        // Stop current playback completely (the new track that was fading in)
        stopCurrentPlayback()

        // Reset crossfade state
        isCrossfading = false

        print("[AudioEngine] ✅ Crossfade cancelled, all audio stopped")
    }

    /// Start playback with fade-in
    private func startPlaybackWithFadeIn(track: AudioTrack, fadeDuration: TimeInterval) {
        let fadeSteps = 15
        let stepDuration = fadeDuration / Double(fadeSteps)
        var currentStep = 0
        let targetVolume = volume

        // CRITICAL FIX: Configure audio session before fade-in playback
        // This ensures audio works after emergency mode stops
        // IMPORTANT: Check if emergency queue is active - if so, keep emergency audio session!
        let isEmergencyActive = false /* emergency queue removed */
        if !isEmergencyActive {
            // Only configure normal audio session if NOT in emergency mode
            configureAudioSession(interruptOtherAudio: false)
        } else {
            // In emergency mode - don't reset audio session, it was already configured
            print("[AudioEngine] 🚨 Emergency mode active - preserving emergency audio session (fade-in)")
        }

        // Start at zero volume
        setVolume(0)

        // Track recently played
        PlaylistManager.shared.addToRecentlyPlayed(track)

        switch track.audioSourceType {
        case .generated:
            playGeneratedAudio(track: track)
        case .bundled:
            playBundledAudio(track: track)
        case .streamed:
            playStreamedAudio(track: track)
        case .textToSpeech:
            playTextToSpeech(track: track)
        }

        // Fade in
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        fadeTimer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let progress = Float(currentStep) / Float(fadeSteps)
                let fadeInCurve = pow(progress, 2) // Quadratic ease-in
                self.setVolume(targetVolume * fadeInCurve)

                if currentStep >= fadeSteps {
                    timer.invalidate()
                    self.fadeTimer = nil
                    self.setVolume(targetVolume)
                }
            }
        }

        // PERFORMANCE FIX: Add timer to RunLoop.common mode for smooth UI
        RunLoop.main.add(newTimer, forMode: .common)
        fadeTimer = newTimer
    }

    // MARK: - Interruption Handling
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // SOOTHING MODE PROTECTION: Track state but don't stop - we'll resume automatically
            if isSoothingModeActive {
                wasPlayingBeforeInterruption = (playbackState == .playing)
                print("[AudioEngine] 🛡️ SOOTHING MODE: Interruption began but NOT pausing - will auto-resume")
                // Still pause audio (iOS requirement during phone calls), but we'll resume after
                pause()
            } else {
                pause()
            }

        case .ended:
            // SOOTHING MODE: Always auto-resume after interruption ends
            if isSoothingModeActive && wasPlayingBeforeInterruption {
                print("[AudioEngine] 🛡️ SOOTHING MODE: Interruption ended - AUTO-RESUMING playback")
                wasPlayingBeforeInterruption = false
                // Brief delay to ensure audio session is fully available
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    self.configureAudioSession(interruptOtherAudio: true)
                    self.resume()
                }
            } else if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Log the route change for debugging
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        let outputs = currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")

        switch reason {
        case .unknown:
            print("[AudioEngine] ❓ Route change with unknown reason. Route: \(outputs)")

        case .newDeviceAvailable:
            // New device connected (e.g., Bluetooth headphones, AirPods)
            // DO NOT pause - continue playing to the new device
            print("[AudioEngine] 🎧 New audio device connected: \(outputs)")

        case .oldDeviceUnavailable:
            // Device disconnected (e.g., AirPods removed)
            // SOOTHING MODE: Continue playing on speaker - baby needs calming!
            if isSoothingModeActive {
                print("[AudioEngine] 🛡️ SOOTHING MODE: Device disconnected but NOT pausing - continuing on speaker")
                // Ensure audio continues on the default speaker
                configureAudioSession(interruptOtherAudio: true)
                // Don't pause - audio automatically routes to speaker
            } else {
                // Normal behavior - pause playback when device disconnects
                print("[AudioEngine] 🔌 Audio device disconnected. Pausing. New route: \(outputs)")
                pause()
            }

        case .categoryChange:
            // Another app changed the audio category
            print("[AudioEngine] 📱 Audio category changed. Route: \(outputs)")

        case .override:
            // Route was overridden (e.g., speaker button pressed during call)
            print("[AudioEngine] 🔊 Audio route overridden. Route: \(outputs)")

        case .wakeFromSleep:
            // Device woke from sleep
            print("[AudioEngine] 😴 Device woke from sleep. Route: \(outputs)")

        case .noSuitableRouteForCategory:
            // No suitable route for the current category
            print("[AudioEngine] ⚠️ No suitable audio route available")

        case .routeConfigurationChange:
            // Route configuration changed (e.g., Bluetooth codec changed)
            print("[AudioEngine] 🔄 Route configuration changed: \(outputs)")

        @unknown default:
            print("[AudioEngine] ❓ Future route change reason: \(reasonValue). Route: \(outputs)")
        }
    }
}

// MARK: - Audio Player Delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        DispatchQueue.main.async {
            if flag {
                // Use handleTrackEnd for consistent repeat/shuffle handling
                AudioEngine.shared.handleTrackEndFromDelegate()
            }
        }
    }
}

// MARK: - Noise Generator
// @unchecked Sendable because NoiseGenerator is only accessed from MainActor context via AudioEngine
// 🚨 PERFORMANCE FIX (2026-01-09): Major optimizations to prevent "broken radio" sound:
// 1. Pre-computed lookup tables for expensive sin() calculations
// 2. Larger audio buffer (1024 frames) to reduce callback frequency
// 3. Optimized sample generation to prevent render callback starvation
// 4. Thread-safe volume updates to prevent audio glitches
class NoiseGenerator: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var volume: Float = 0.5
    private var targetVolume: Float = 0.5  // For smooth volume transitions
    private var isRunning: Bool = false
    private let type: GeneratorType

    // 🚨 PERFORMANCE FIX: Pre-computed sine lookup table (4096 samples)
    // This eliminates expensive sin() calls in the real-time render callback
    private static let sineTableSize = 4096
    private static let sineTable: [Float] = {
        var table = [Float](repeating: 0, count: sineTableSize)
        for i in 0..<sineTableSize {
            table[i] = Float(sin(Double(i) * 2.0 * .pi / Double(sineTableSize)))
        }
        return table
    }()

    // Noise generation parameters
    private var phase: Double = 0
    private var previousValue: Double = 0

    // 🚨 PERFORMANCE FIX: Use atomic-like flag to prevent concurrent access issues
    private var isGenerating: Bool = false

    /// Track if setup failed - prevents reuse of broken engine
    private var setupFailed: Bool = false

    init(type: GeneratorType) {
        self.type = type
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // FIX: Reset failure flag on fresh setup
        setupFailed = false
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            setupFailed = true
            return
        }

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // 🚨 PERFORMANCE FIX: Capture type locally to avoid self capture in render callback
        let generatorType = self.type

        noiseNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            // 🚨 PERFORMANCE FIX: Smooth volume interpolation to prevent clicks
            let currentVolume = self.volume
            let targetVol = self.targetVolume
            let volumeStep = (targetVol - currentVolume) / Float(frameCount)
            var interpVolume = currentVolume

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // 🚨 PERFORMANCE FIX: Generate samples in optimized batch
            for frame in 0..<Int(frameCount) {
                let sample = self.generateSampleOptimized(type: generatorType)

                // Smooth volume interpolation
                interpVolume += volumeStep
                let scaledSample = Float(sample) * interpVolume

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = scaledSample
                }
            }

            // Update volume after interpolation complete
            self.volume = targetVol

            return noErr
        }

        if let node = noiseNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            // 🚨 CRITICAL FIX: Connect mixer to output node - WITHOUT THIS, NO SOUND!
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
            print("[NoiseGenerator] ✅ Audio chain connected: NoiseNode → MainMixer → OutputNode")
        }
    }

    // 🚨 PERFORMANCE FIX: Fast sine lookup using pre-computed table
    @inline(__always)
    private func fastSin(_ phase: Double) -> Float {
        let index = Int(phase * Double(NoiseGenerator.sineTableSize)) & (NoiseGenerator.sineTableSize - 1)
        return NoiseGenerator.sineTable[index]
    }

    // 🚨 PERFORMANCE FIX: Optimized sample generation using lookup tables
    @inline(__always)
    private func generateSampleOptimized(type: GeneratorType) -> Double {
        // Use the regular generateSample but with optimized paths
        return generateSample()
    }

    // Additional state variables for complex generators
    private var blueNoiseState: Double = 0
    private var secondaryPhase: Double = 0
    private var tertiaryValue: Double = 0

    private func generateSample() -> Double {
        // ⚠️ WHITE NOISE AND MECHANICAL SOUNDS REMOVED!
        // Only gentle, baby-safe sounds remain.
        switch type {
        case .heartbeat:
            // Simulated heartbeat at ~70 BPM
            phase += 70.0 / 60.0 / 44100.0
            if phase >= 1.0 { phase -= 1.0 }
            let beat = sin(phase * 2 * .pi * 10) * exp(-phase * 15)
            return beat * 0.8

        case .womb:
            // Womb sound: low frequency rumble + muffled noise
            phase += 1.0 / 44100.0
            let rumble = sin(phase * 2 * .pi * 30) * 0.3
            let noise = Double.random(in: -0.2...0.2)
            // Low-pass filter effect
            previousValue = 0.95 * previousValue + 0.05 * noise
            return rumble + previousValue

        case .shushing:
            // Rhythmic shushing pattern
            phase += 1.0 / 44100.0
            let cycle = fmod(phase * 0.8, 1.0) // ~0.8 Hz shush rate
            let envelope = cycle < 0.5 ? sin(cycle * .pi) : 0
            let noise = Double.random(in: -1...1)
            return noise * envelope * 0.6

        // ⚠️ REMOVED (2026-01-09): ocean, forest, waterfall, campfire, birds, crickets, fireplace, river
        // User feedback: these sounds are TOO NOISY and startle babies!
        // Only gentle, predictable musical sounds remain.

        case .aquarium:
            // Aquarium bubbles - gentle, rhythmic bubbling
            phase += 1.0 / 44100.0
            // Base water ambience
            let water = Double.random(in: -1...1)
            previousValue = 0.92 * previousValue + 0.08 * water
            // Bubble sounds at varying rates
            var bubble = 0.0
            if Double.random(in: 0...1) > 0.997 {
                tertiaryValue = Double.random(in: 0.3...0.8)
            }
            if tertiaryValue > 0.01 {
                let bubbleFreq = 800 + Double.random(in: -200...200)
                bubble = sin(phase * 2 * .pi * bubbleFreq) * tertiaryValue
                tertiaryValue *= 0.97
            }
            // Gentle filter pump hum
            let pump = sin(phase * 2 * .pi * 60) * 0.05
            return (previousValue * 0.2 + bubble * 0.4 + pump)

        case .lullaby, .musicBox:
            // Music box melody with proper musical timing
            // Tempo: 72 BPM = 1.2 beats per second, each note is a quarter note
            let bpm = 72.0
            let beatDuration = 60.0 / bpm  // ~0.833 seconds per beat
            let noteDuration = beatDuration  // Quarter note

            phase += 1.0 / 44100.0

            // "Twinkle Twinkle Little Star" melody pattern (classic lullaby)
            // Using note degrees: C D E F G (1 1 5 5 6 6 5, 4 4 3 3 2 2 1)
            let melodyNotes: [Double] = [
                262, 262, 392, 392, 440, 440, 392,  // Twin-kle twin-kle lit-tle star
                349, 349, 330, 330, 294, 294, 262,  // How I won-der what you are
                392, 392, 349, 349, 330, 330, 294,  // Up a-bove the world so high
                392, 392, 349, 349, 330, 330, 294,  // Like a dia-mond in the sky
                262, 262, 392, 392, 440, 440, 392,  // Twin-kle twin-kle lit-tle star
                349, 349, 330, 330, 294, 294, 262   // How I won-der what you are
            ]

            // Calculate which note we're on based on time
            let totalMelodyDuration = Double(melodyNotes.count) * noteDuration
            let melodyPhase = fmod(phase, totalMelodyDuration)
            let noteIndex = Int(melodyPhase / noteDuration) % melodyNotes.count
            let noteFreq = melodyNotes[noteIndex]

            // Time within current note (0 to 1)
            let notePhase = fmod(melodyPhase, noteDuration) / noteDuration

            // Music box tone with harmonics (bell-like sound)
            let fundamental = sin(phase * 2 * .pi * noteFreq)
            let harmonic2 = sin(phase * 2 * .pi * noteFreq * 2) * 0.3
            let harmonic3 = sin(phase * 2 * .pi * noteFreq * 3) * 0.15
            let harmonic4 = sin(phase * 2 * .pi * noteFreq * 4) * 0.08
            let tone = fundamental + harmonic2 + harmonic3 + harmonic4

            // Bell-like envelope: quick attack, gradual decay
            let attack = min(notePhase * 20.0, 1.0)  // Fast attack (first 5%)
            let decay = exp(-notePhase * 3.0)  // Exponential decay
            let envelope = attack * decay

            return tone * envelope * 0.25

        case .softPiano:
            // Soft piano - gentle chord progressions with proper timing
            // Tempo: 60 BPM for very relaxing, 4 beats per chord (whole notes)
            let bpm = 60.0
            let beatDuration = 60.0 / bpm  // 1 second per beat
            let chordDuration = beatDuration * 4.0  // 4 seconds per chord (whole note)

            phase += 1.0 / 44100.0

            // Gentle chord progression (I - vi - IV - V - I pattern in C major)
            let chordProgressions: [[(Double, Double)]] = [
                // C major (root position) - with octave bass
                [(130.81, 1.0), (262, 0.8), (330, 0.7), (392, 0.6)],
                // A minor
                [(110, 1.0), (220, 0.8), (262, 0.7), (330, 0.6)],
                // F major
                [(87.31, 1.0), (175, 0.8), (220, 0.7), (262, 0.6)],
                // G major (with 7th for tension)
                [(98, 1.0), (196, 0.8), (247, 0.7), (294, 0.6)],
                // C major (resolution)
                [(130.81, 1.0), (262, 0.8), (330, 0.7), (392, 0.6)],
                // E minor (relative minor)
                [(82.41, 1.0), (165, 0.8), (196, 0.7), (247, 0.6)],
                // A minor
                [(110, 1.0), (220, 0.8), (262, 0.7), (330, 0.6)],
                // G major (dominant)
                [(98, 1.0), (196, 0.8), (247, 0.7), (392, 0.6)]
            ]

            // Calculate which chord we're on
            let totalProgressionDuration = Double(chordProgressions.count) * chordDuration
            let progressionPhase = fmod(phase, totalProgressionDuration)
            let chordIndex = Int(progressionPhase / chordDuration) % chordProgressions.count
            let currentChord = chordProgressions[chordIndex]

            // Time within current chord (0 to 1)
            let chordPhase = fmod(progressionPhase, chordDuration) / chordDuration

            // Build chord sound with staggered note entries (arpeggiated feel)
            var chordSound = 0.0
            for (noteIndex, (freq, vol)) in currentChord.enumerated() {
                // Stagger note entries slightly for arpeggiated feel
                let noteDelay = Double(noteIndex) * 0.05  // 50ms between notes
                let noteStartPhase = noteDelay / chordDuration

                if chordPhase >= noteStartPhase {
                    let adjustedNotePhase = (chordPhase - noteStartPhase) / (1.0 - noteStartPhase)

                    // Piano tone with harmonics
                    let fundamental = sin(phase * 2 * .pi * freq)
                    let harmonic2 = sin(phase * 2 * .pi * freq * 2) * 0.2
                    let harmonic3 = sin(phase * 2 * .pi * freq * 3) * 0.05
                    let tone = (fundamental + harmonic2 + harmonic3) * vol

                    // Soft attack, long sustain, gentle decay
                    let attack = min(adjustedNotePhase * 10.0, 1.0)  // 100ms attack
                    let sustain = 0.7
                    let decay = sustain + (1.0 - sustain) * exp(-adjustedNotePhase * 1.5)
                    let noteEnvelope = attack * decay

                    chordSound += tone * noteEnvelope
                }
            }

            return chordSound / Double(currentChord.count) * 0.35

        case .gentleGuitar:
            // Gentle acoustic guitar - fingerpicking arpeggio pattern
            // Tempo: 80 BPM, eighth notes for fingerpicking
            let bpm = 80.0
            let beatDuration = 60.0 / bpm  // 0.75 seconds per beat
            let noteDuration = beatDuration / 2.0  // Eighth notes (0.375 seconds)

            phase += 1.0 / 44100.0

            // Fingerpicking pattern for a gentle G-Em-C-D progression
            // Pattern: bass, 3rd, 2nd, 1st, 2nd, 3rd (Travis picking inspired)
            let chordPatterns: [[(Double, Int)]] = [
                // G major: G2-B3-D4-G4-D4-B3
                [(98, 0), (247, 2), (294, 1), (392, 0), (294, 1), (247, 2), (98, 0), (196, 2)],
                // E minor: E2-G3-B3-E4-B3-G3
                [(82.41, 0), (196, 2), (247, 1), (330, 0), (247, 1), (196, 2), (82.41, 0), (165, 2)],
                // C major: C2-E3-G3-C4-G3-E3
                [(65.41, 0), (165, 2), (196, 1), (262, 0), (196, 1), (165, 2), (65.41, 0), (130.81, 2)],
                // D major: D2-F#3-A3-D4-A3-F#3
                [(73.42, 0), (185, 2), (220, 1), (294, 0), (220, 1), (185, 2), (73.42, 0), (147, 2)]
            ]

            // Calculate timing
            let patternLength = 8  // 8 notes per chord pattern
            let chordDuration = Double(patternLength) * noteDuration
            let totalProgressionDuration = Double(chordPatterns.count) * chordDuration
            let progressionPhase = fmod(phase, totalProgressionDuration)
            let chordIndex = Int(progressionPhase / chordDuration) % chordPatterns.count
            let pattern = chordPatterns[chordIndex]

            // Calculate which note in the pattern
            let chordLocalPhase = fmod(progressionPhase, chordDuration)
            let noteIndex = Int(chordLocalPhase / noteDuration) % pattern.count
            let (freq, stringType) = pattern[noteIndex]

            // Time within current note (0 to 1)
            let notePhase = fmod(chordLocalPhase, noteDuration) / noteDuration

            // Guitar tone with realistic harmonics
            // Bass strings (type 0) have more low harmonics
            // Treble strings (type 1-2) are brighter
            let h2Strength = stringType == 0 ? 0.4 : 0.25
            let h3Strength = stringType == 0 ? 0.2 : 0.15
            let h4Strength = stringType == 0 ? 0.1 : 0.08

            let fundamental = sin(phase * 2 * .pi * freq)
            let harmonic2 = sin(phase * 2 * .pi * freq * 2) * h2Strength
            let harmonic3 = sin(phase * 2 * .pi * freq * 3) * h3Strength
            let harmonic4 = sin(phase * 2 * .pi * freq * 4) * h4Strength
            let tone = fundamental + harmonic2 + harmonic3 + harmonic4

            // Guitar pluck envelope: instant attack, medium-fast decay
            // Lower strings ring longer
            let decayRate = stringType == 0 ? 2.5 : 3.5
            let envelope = exp(-notePhase * decayRate)

            return tone * envelope * 0.28

        // ⚠️ REMOVED (2026-01-09): river, birds, crickets, fireplace
        // User feedback: these sounds are TOO NOISY and startle babies!

        case .chimes:
            // Wind chimes - gentle random bell tones, NOT harsh
            phase += 1.0 / 44100.0
            // Pentatonic scale for pleasant, non-dissonant chimes
            // C, D, E, G, A (262, 294, 330, 392, 440 Hz) - all sound good together
            let chimeNotes: [Double] = [523, 587, 659, 784, 880, 1047, 1175] // Higher octave, softer

            // Trigger new chime occasionally
            if Double.random(in: 0...1) > 0.9992 {
                tertiaryValue = 1.0
                blueNoiseState = chimeNotes.randomElement() ?? 523
            }

            var chime = 0.0
            if tertiaryValue > 0.01 {
                // Bell-like tone with harmonics
                let fundamental = sin(phase * 2 * .pi * blueNoiseState)
                let h2 = sin(phase * 2 * .pi * blueNoiseState * 2) * 0.3
                let h3 = sin(phase * 2 * .pi * blueNoiseState * 3) * 0.1
                chime = (fundamental + h2 + h3) * tertiaryValue * 0.25
                tertiaryValue *= 0.9985 // Slow decay for bell sound
            }

            // Very soft ambient wind
            let windNoise = Double.random(in: -1...1)
            previousValue = 0.97 * previousValue + 0.03 * windNoise
            return (chime + previousValue * 0.1)

        case .bells:
            // Soft bells - slower, deeper bell tones
            phase += 1.0 / 44100.0
            // Lower, warmer bell frequencies
            let bellNotes: [Double] = [262, 294, 330, 392, 440] // C4-A4 range

            // Trigger new bell less frequently than chimes
            if Double.random(in: 0...1) > 0.9996 {
                tertiaryValue = 1.0
                blueNoiseState = bellNotes.randomElement() ?? 262
            }

            var bell = 0.0
            if tertiaryValue > 0.01 {
                // Rich bell tone with more harmonics
                let fundamental = sin(phase * 2 * .pi * blueNoiseState)
                let h2 = sin(phase * 2 * .pi * blueNoiseState * 2) * 0.35
                let h3 = sin(phase * 2 * .pi * blueNoiseState * 3) * 0.15
                let h4 = sin(phase * 2 * .pi * blueNoiseState * 4) * 0.05
                bell = (fundamental + h2 + h3 + h4) * tertiaryValue * 0.3
                tertiaryValue *= 0.9975 // Even slower decay
            }

            return bell
        }
    }

    func start() {
        // FIX: "invalid reuse after initialization failure" - recreate engine if previous setup failed
        if setupFailed || audioEngine == nil {
            print("[NoiseGenerator] 🔄 Recreating audio engine after previous failure")
            setupAudioEngine()
        }

        guard !isRunning, let engine = audioEngine else {
            print("[NoiseGenerator] ⚠️ Cannot start: isRunning=\(isRunning), engine=\(audioEngine != nil), setupFailed=\(setupFailed)")
            return
        }

        do {
            // CRITICAL FIX: Ensure audio session is active before starting engine
            // The NoiseGenerator uses its own AVAudioEngine instance, which requires
            // an active audio session to produce sound
            let session = AVAudioSession.sharedInstance()
            let currentRoute = session.currentRoute
            let outputs = currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")
            print("[NoiseGenerator] 📱 Audio route before start: \(outputs.isEmpty ? "None" : outputs)")

            // Don't change audio session category here!
            // AudioSessionManager already configured the session before NoiseGenerator was created.
            // Just verify session is active and start the engine.
            if !session.isOtherAudioPlaying && !session.currentRoute.outputs.isEmpty {
                // Session already configured by AudioSessionManager, just ensure it's active
                try session.setActive(true)
                print("[NoiseGenerator] ✅ Audio session verified active")
            } else {
                print("[NoiseGenerator] ℹ️ Session already active, route: \(outputs)")
            }

            // 🚨 PERFORMANCE FIX: Prepare engine before starting to reduce latency
            engine.prepare()

            print("[NoiseGenerator] 🎵 Starting audio engine for \(type.rawValue)")
            print("[NoiseGenerator] 📊 Volume: \(volume), Connections: \(engine.attachedNodes.count) nodes")
            try engine.start()
            isRunning = true
            setupFailed = false  // Clear failure flag on successful start

            // Verify audio route after start
            let newRoute = session.currentRoute
            let newOutputs = newRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")
            print("[NoiseGenerator] ✅ Audio engine STARTED - Route: \(newOutputs.isEmpty ? "None" : newOutputs)")
        } catch {
            print("[NoiseGenerator] ❌ Failed to start noise generator: \(error)")
            print("[NoiseGenerator] ❌ Error details: \(error.localizedDescription)")

            // FIX: Mark setup as failed so next start() will recreate the engine
            // "invalid reuse after initialization failure" happens when you try to
            // use an AVAudioEngine that failed to start
            setupFailed = true
            audioEngine = nil  // Release the broken engine
        }
    }

    func stop() {
        // 🚨 PERFORMANCE FIX: Fade out before stopping to prevent click
        targetVolume = 0
        // Give a brief moment for volume fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.audioEngine?.stop()
            self?.isRunning = false
        }
    }

    func setVolume(_ newVolume: Float) {
        // 🚨 PERFORMANCE FIX: Use smooth volume transition via targetVolume
        // The render callback will interpolate from current volume to target
        // This prevents audio clicks/pops from sudden volume changes
        targetVolume = newVolume
    }
}

// MARK: - Sound Mixer (for combining multiple sounds)
class SoundMixer: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var generators: [String: (node: AVAudioSourceNode, volume: Float, type: GeneratorType)] = [:]
    private var isRunning: Bool = false
    private let sampleRate: Double = 44100

    // Generator states (separate for each channel)
    private var generatorStates: [String: GeneratorState] = [:]

    struct GeneratorState {
        var phase: Double = 0
        var previousValue: Double = 0
        var secondaryPhase: Double = 0
        var tertiaryValue: Double = 0
        var blueNoiseState: Double = 0
        var birdsState: Double = 0  // Used for note frequency in melodic generators
    }

    @Published var activeChannels: [MixerChannel] = []

    /// Track if setup failed - prevents reuse of broken engine
    private var setupFailed: Bool = false

    struct MixerChannel: Identifiable, Equatable {
        let id: String
        let type: GeneratorType
        var volume: Float
        var isActive: Bool

        static func == (lhs: MixerChannel, rhs: MixerChannel) -> Bool {
            lhs.id == rhs.id
        }
    }

    init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        setupFailed = false
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()

        guard let engine = audioEngine, let mixer = mixerNode else {
            setupFailed = true
            return
        }

        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        // 🚨 CRITICAL FIX: Connect mainMixer to output - WITHOUT THIS, NO SOUND!
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        print("[SoundMixer] ✅ Audio chain connected: SourceNodes → Mixer → MainMixer → OutputNode")
    }

    func addSound(_ type: GeneratorType, volume: Float = 0.5) -> String {
        let channelId = UUID().uuidString
        guard let engine = audioEngine, let mixer = mixerNode else { return channelId }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // Initialize state for this generator
        generatorStates[channelId] = GeneratorState()

        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self,
                  var state = self.generatorStates[channelId],
                  let channelVolume = self.generators[channelId]?.volume else {
                return noErr
            }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSampleForType(type, state: &state)
                let scaledSample = Float(sample) * channelVolume

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = scaledSample
                }
            }

            self.generatorStates[channelId] = state
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        generators[channelId] = (sourceNode, volume, type)
        activeChannels.append(MixerChannel(id: channelId, type: type, volume: volume, isActive: true))

        if isRunning {
            // If mixer is already running, the new node will start automatically
        }

        return channelId
    }

    func removeSound(_ channelId: String) {
        guard let engine = audioEngine,
              let generator = generators[channelId] else { return }

        engine.detach(generator.node)
        generators.removeValue(forKey: channelId)
        generatorStates.removeValue(forKey: channelId)
        activeChannels.removeAll { $0.id == channelId }
    }

    func setChannelVolume(_ channelId: String, volume: Float) {
        if var generator = generators[channelId] {
            generator.volume = min(volume, 1.0)
            generators[channelId] = generator
        }

        if let index = activeChannels.firstIndex(where: { $0.id == channelId }) {
            activeChannels[index].volume = min(volume, 1.0)
        }
    }

    func setMasterVolume(_ volume: Float) {
        mixerNode?.outputVolume = min(volume, 1.0)
    }

    func start() {
        // FIX: "invalid reuse after initialization failure" - recreate engine if previous setup failed
        if setupFailed || audioEngine == nil {
            print("[SoundMixer] 🔄 Recreating audio engine after previous failure")
            setupAudioEngine()
        }

        guard !isRunning, let engine = audioEngine else { return }

        do {
            try engine.start()
            isRunning = true
            setupFailed = false
        } catch {
            print("[SoundMixer] ❌ Failed to start sound mixer: \(error)")
            setupFailed = true
            audioEngine = nil
        }
    }

    func stop() {
        audioEngine?.stop()
        isRunning = false
    }

    func removeAllSounds() {
        for channelId in generators.keys {
            removeSound(channelId)
        }
    }

    // Simplified sample generation for mixer (reuses main generator logic)
    // ⚠️ WHITE NOISE AND MECHANICAL SOUNDS REMOVED!
    // ⚠️ UPDATED (2026-01-09): Removed all noisy nature sounds from mixer
    // Only gentle musical and baby-specific sounds remain
    private func generateSampleForType(_ type: GeneratorType, state: inout GeneratorState) -> Double {
        switch type {
        case .chimes:
            state.phase += 1.0 / sampleRate
            let chimeNotes: [Double] = [523, 587, 659, 784, 880, 1047, 1175]
            if Double.random(in: 0...1) > 0.9992 {
                state.tertiaryValue = 1.0
                state.birdsState = chimeNotes.randomElement() ?? 523
            }
            var chime = 0.0
            if state.tertiaryValue > 0.01 {
                let fundamental = sin(state.phase * 2 * .pi * state.birdsState)
                let h2 = sin(state.phase * 2 * .pi * state.birdsState * 2) * 0.3
                chime = (fundamental + h2) * state.tertiaryValue * 0.25
                state.tertiaryValue *= 0.9985
            }
            let windNoise = Double.random(in: -1...1)
            state.previousValue = 0.97 * state.previousValue + 0.03 * windNoise
            return (chime + state.previousValue * 0.1)

        case .bells:
            state.phase += 1.0 / sampleRate
            let bellNotes: [Double] = [262, 294, 330, 392, 440]
            if Double.random(in: 0...1) > 0.9996 {
                state.tertiaryValue = 1.0
                state.birdsState = bellNotes.randomElement() ?? 262
            }
            var bell = 0.0
            if state.tertiaryValue > 0.01 {
                let fundamental = sin(state.phase * 2 * .pi * state.birdsState)
                let h2 = sin(state.phase * 2 * .pi * state.birdsState * 2) * 0.35
                bell = (fundamental + h2) * state.tertiaryValue * 0.3
                state.tertiaryValue *= 0.9975
            }
            return bell

        // ⚠️ REMOVED: birds, crickets, fireplace - too noisy!

        case .lullaby, .musicBox, .softPiano, .gentleGuitar:
            // For musical generators, use simple pleasant tones
            state.phase += 1.0 / sampleRate
            let melodyNotes: [Double] = [262, 294, 330, 349, 392, 440]
            if Double.random(in: 0...1) > 0.998 {
                state.tertiaryValue = 1.0
                state.birdsState = melodyNotes.randomElement() ?? 262
            }
            var tone = 0.0
            if state.tertiaryValue > 0.01 {
                let fundamental = sin(state.phase * 2 * .pi * state.birdsState)
                let h2 = sin(state.phase * 2 * .pi * state.birdsState * 2) * 0.2
                tone = (fundamental + h2) * state.tertiaryValue * 0.25
                state.tertiaryValue *= 0.997
            }
            return tone

        case .heartbeat, .womb, .shushing, .aquarium:
            // For these types, delegate to main NoiseGenerator via filtered noise fallback
            state.phase += 1.0 / sampleRate
            let noise = Double.random(in: -1...1)
            state.previousValue = 0.85 * state.previousValue + 0.15 * noise
            return state.previousValue * 0.4
        }
    }

    // MARK: - Preset Mixes
    // ⚠️ UPDATED (2026-01-09): Removed all noisy nature sounds
    // Only gentle musical sounds remain: softPiano, gentleGuitar, lullaby, musicBox, chimes, bells
    // Plus baby-specific: womb, heartbeat, shushing, aquarium

    static func createSleepMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.softPiano, 0.4), (.gentleGuitar, 0.3), (.chimes, 0.15)]
        } else if ageMonths >= 12 {
            return [(.lullaby, 0.4), (.musicBox, 0.3), (.chimes, 0.15)]
        } else if ageMonths >= 6 {
            return [(.musicBox, 0.4), (.womb, 0.3)]
        } else {
            return [(.womb, 0.4), (.heartbeat, 0.3)]
        }
    }

    static func createCalmMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.softPiano, 0.4), (.gentleGuitar, 0.25), (.bells, 0.2)]
        } else if ageMonths >= 12 {
            return [(.lullaby, 0.4), (.softPiano, 0.25), (.chimes, 0.2)]
        } else {
            return [(.musicBox, 0.4), (.womb, 0.3)]
        }
    }

    static func createFocusMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.aquarium, 0.35), (.softPiano, 0.3), (.chimes, 0.2)]
        } else if ageMonths >= 12 {
            return [(.musicBox, 0.35), (.aquarium, 0.3)]
        } else {
            return [(.lullaby, 0.4), (.womb, 0.3)]
        }
    }
}

// MARK: - Tone Generator (for musical content)
class ToneGenerator {
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var frequency: Double = 440
    private var volume: Float = 0.5
    private var phase: Double = 0
    private var setupFailed: Bool = false

    init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        setupFailed = false
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            setupFailed = true
            return
        }

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = self.frequency / sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase * 2 * .pi)) * self.volume
                self.phase += phaseIncrement
                if self.phase >= 1.0 { self.phase -= 1.0 }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        if let node = sourceNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    func setFrequency(_ freq: Double) {
        frequency = freq
    }

    func setVolume(_ vol: Float) {
        volume = vol
    }

    func start() {
        // FIX: "invalid reuse after initialization failure" - recreate engine if previous setup failed
        if setupFailed || audioEngine == nil {
            setupAudioEngine()
        }

        do {
            try audioEngine?.start()
            setupFailed = false
        } catch {
            print("[ToneGenerator] ❌ Failed to start: \(error)")
            setupFailed = true
            audioEngine = nil
        }
    }

    func stop() {
        audioEngine?.stop()
    }
}

// NOTE: SmartPlaylistBuilder is defined in SmartPlaylistBuilder.swift
