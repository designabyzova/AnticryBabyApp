//
//  PlaybackSessionManager.swift
//  BabyInCarApp
//
//  Centralized playback session coordinator
//  Ensures only ONE audio source plays at a time with smooth transitions
//

import Foundation
import AVFoundation

/// Playback source identifier
enum PlaybackSource: Equatable {
    case userSelection          // User tapped a track in Library/Home/Playlist
    case emergencyMode          // Cry detected, emergency playlist active
    case singleSound            // Single generated sound (legacy emergency)
    case carPlay                // CarPlay initiated playback

    var priority: Int {
        switch self {
        case .emergencyMode: return 100      // Highest - baby crying!
        case .singleSound: return 90         // Emergency single sound
        case .carPlay: return 50             // CarPlay user action
        case .userSelection: return 10       // Regular user action
        }
    }

    var displayName: String {
        switch self {
        case .userSelection: return "Library"
        case .emergencyMode: return "Emergency Playlist"
        case .singleSound: return "Emergency Sound"
        case .carPlay: return "CarPlay"
        }
    }
}

/// Centralized playback session manager
/// Ensures smooth transitions between different playback sources
@MainActor
class PlaybackSessionManager: ObservableObject {
    static let shared = PlaybackSessionManager()

    // MARK: - Published State
    @Published private(set) var activeSource: PlaybackSource?
    @Published private(set) var isTransitioning: Bool = false

    // MARK: - Audio Engine
    private let audioEngine = AudioEngine.shared

    // MARK: - Transition Settings
    /// Default crossfade duration for smooth transitions
    private let defaultCrossfadeDuration: TimeInterval = 1.0

    /// Emergency mode uses instant transitions (no fade)
    private let emergencyCrossfadeDuration: TimeInterval = 0.0

    private init() {}

    // MARK: - Playback Request

    /// Request playback from a specific source with automatic transition handling
    /// - Parameters:
    ///   - track: The track to play
    ///   - source: The source requesting playback
    ///   - forceImmediate: Skip smooth transition (for emergencies)
    /// - Returns: True if playback started, false if rejected (lower priority)
    @discardableResult
    func requestPlayback(
        track: AudioTrack,
        from source: PlaybackSource,
        forceImmediate: Bool = false
    ) -> Bool {
        print("[PlaybackSession] 🎵 Playback request: \(track.title) from \(source.displayName)")

        // Check if we should allow this playback
        if let currentSource = activeSource {
            if source.priority < currentSource.priority {
                print("[PlaybackSession] ⛔️ Rejected - \(currentSource.displayName) has higher priority")
                return false
            }

            if source.priority > currentSource.priority {
                print("[PlaybackSession] 🔄 Interrupting \(currentSource.displayName) for \(source.displayName)")
            }
        }

        // Update active source
        activeSource = source

        // Determine transition type
        let shouldCrossfade = !forceImmediate && audioEngine.smoothTransitionsEnabled

        if shouldCrossfade {
            // Smooth crossfade transition
            isTransitioning = true
            audioEngine.play(track: track, crossfadeDuration: defaultCrossfadeDuration)

            // Reset transition flag after fade completes
            Task {
                try? await Task.sleep(nanoseconds: UInt64(defaultCrossfadeDuration * 1_000_000_000))
                isTransitioning = false
            }
        } else {
            // Immediate playback (emergency or smooth transitions disabled)
            audioEngine.playImmediateWithoutFade(track: track)
        }

        print("[PlaybackSession] ✅ Playing: \(track.title)")
        return true
    }

    /// Request playlist playback (for emergency mode or user playlists)
    /// - Parameters:
    ///   - playlist: The playlist to play
    ///   - source: The source requesting playback
    ///   - startIndex: Index to start from (default 0)
    @discardableResult
    func requestPlayback(
        playlist: Playlist,
        from source: PlaybackSource,
        startIndex: Int = 0
    ) -> Bool {
        print("[PlaybackSession] 📋 Playlist request: \(playlist.name) from \(source.displayName)")

        // Check priority
        if let currentSource = activeSource {
            if source.priority < currentSource.priority {
                print("[PlaybackSession] ⛔️ Rejected - \(currentSource.displayName) has higher priority")
                return false
            }
        }

        // Update active source
        activeSource = source

        // Play playlist through audio engine
        audioEngine.play(playlist: playlist, startIndex: startIndex)

        print("[PlaybackSession] ✅ Playing playlist: \(playlist.name)")
        return true
    }

    /// Stop playback from a specific source
    /// Only stops if the requesting source is the active source
    /// - Parameter source: The source requesting stop
    func stopPlayback(from source: PlaybackSource) {
        guard activeSource == source else {
            print("[PlaybackSession] ⚠️ Ignoring stop request from \(source.displayName) - not active source")
            return
        }

        print("[PlaybackSession] 🛑 Stopping playback from \(source.displayName)")
        audioEngine.stop()
        activeSource = nil
        isTransitioning = false
    }

    /// Force stop all playback (for app lifecycle events)
    func forceStopAll() {
        print("[PlaybackSession] ⛔️ Force stopping all playback")
        audioEngine.stop()
        activeSource = nil
        isTransitioning = false
    }

    // MARK: - Playback Control

    /// Pause current playback
    func pause() {
        audioEngine.pause()
    }

    /// Resume current playback
    func resume() {
        audioEngine.resume()
    }

    /// Check if a specific source is currently active
    func isActive(source: PlaybackSource) -> Bool {
        return activeSource == source
    }

    /// Get current playback state
    var playbackState: LocalPlaybackState {
        return audioEngine.playbackState
    }

    /// Get current track
    var currentTrack: AudioTrack? {
        return audioEngine.currentTrack
    }
}
