//
//  NowPlayingService.swift
//  BabyInCarApp
//
//  Manages MPRemoteCommandCenter and MPNowPlayingInfoCenter
//  for Control Center/Lock Screen integration and Siri control.
//

import Foundation
import MediaPlayer
import UIKit

/// Service for managing Now Playing info and remote command center
/// Enables Control Center, Lock Screen, and CarPlay playback controls
@MainActor
class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()

    private let audioEngine = AudioEngine.shared
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var isSetup = false

    private init() {
        // Setup is deferred until first track plays
    }

    // MARK: - Setup

    /// Setup remote command center handlers
    /// Call this once when audio playback begins
    func setupRemoteCommands() {
        guard !isSetup else { return }
        isSetup = true

        print("[NowPlaying] Setting up remote command center")

        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.resume()
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.pause()
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.audioEngine.playbackState == .playing {
                    self.audioEngine.pause()
                } else {
                    self.audioEngine.resume()
                }
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Stop command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.stop()
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.next()
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.previous()
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Seek to position
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            DispatchQueue.main.async {
                self?.audioEngine.seek(to: positionEvent.positionTime)
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Skip forward (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.skipForward(seconds: 15)
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Skip backward (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.audioEngine.skipBackward(seconds: 15)
            }
            return MPRemoteCommandHandlerStatus.success
        }

        // Like/dislike commands (for favorites)
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.localizedTitle = "Add to Favorites"
        commandCenter.likeCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      let track = self.audioEngine.currentTrack else {
                    return
                }
                if !FavoritesManager.shared.isFavorite(track: track) {
                    FavoritesManager.shared.toggleFavorite(track: track)
                }
                print("[NowPlaying] Added '\(track.title)' to favorites")
            }
            return MPRemoteCommandHandlerStatus.success
        }

        print("[NowPlaying] Remote command center setup complete")
    }

    // MARK: - Now Playing Info Updates

    /// Update the Now Playing info center with current track details
    func updateNowPlayingInfo(track: AudioTrack) {
        setupRemoteCommands() // Ensure setup is done

        var nowPlayingInfo = [String: Any]()

        // Track metadata
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.category.rawValue
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration

        // Playback state
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = audioEngine.playbackState == .playing ? 1.0 : 0.0

        // Media type
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // Queue info
        let currentIndex = audioEngine.currentPlaylistIndex
        if let playlistCount = audioEngine.currentPlaylist?.tracks.count {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = playlistCount
        }

        // Artwork - try to load category-specific artwork or use default
        loadArtwork(for: track) { artwork in
            if let artwork = artwork {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }

        // Set immediately without artwork, will update when artwork loads
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        print("[NowPlaying] Updated info for '\(track.title)'")
    }

    /// Update only the playback time (call from progress timer)
    func updatePlaybackTime() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = audioEngine.playbackState == .playing ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Update playback rate when play/pause state changes
    func updatePlaybackRate(isPlaying: Bool) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Clear Now Playing info when playback stops
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("[NowPlaying] Cleared now playing info")
    }

    // MARK: - Artwork Loading

    /// Load artwork for a track (from bundle or generate placeholder)
    private func loadArtwork(for track: AudioTrack, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        // Try to load category-specific artwork
        let categoryImageName = "category_\(track.category.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"

        if let image = UIImage(named: categoryImageName) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            completion(artwork)
            return
        }

        // Try default artwork
        if let image = UIImage(named: "DefaultTrackArtwork") ?? UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            completion(artwork)
            return
        }

        // Generate placeholder artwork based on category color
        let placeholderImage = generatePlaceholderArtwork(for: track.category)
        let artwork = MPMediaItemArtwork(boundsSize: placeholderImage.size) { _ in placeholderImage }
        completion(artwork)
    }

    /// Generate a colored placeholder artwork for a category
    private func generatePlaceholderArtwork(for category: AudioCategory) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background gradient based on category
            let colors: [UIColor]
            switch category {
            case .lullabies:
                colors = [UIColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 1),
                          UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1)]
            case .classicalMusic:
                colors = [UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1),
                          UIColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1)]
            case .natureSounds:
                colors = [UIColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1),
                          UIColor(red: 0.3, green: 0.6, blue: 0.5, alpha: 1)]
            case .fairyTales:
                colors = [UIColor(red: 0.6, green: 0.4, blue: 0.5, alpha: 1),
                          UIColor(red: 0.7, green: 0.5, blue: 0.6, alpha: 1)]
            case .ambient:
                colors = [UIColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1),
                          UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)]
            default:
                colors = [UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1),
                          UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)]
            }

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: [0, 1]
            )!

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Draw music note icon
            let iconFont = UIFont.systemFont(ofSize: 120, weight: .light)
            let icon = "♫"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: iconFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]

            let iconSize = icon.size(withAttributes: attributes)
            let iconPoint = CGPoint(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2
            )

            icon.draw(at: iconPoint, withAttributes: attributes)
        }
    }
}
