// =============================================================================
// DEPRECATED: This file is deprecated as of FS-021 (Emergency Systems Consolidation)
//
// Migration: Use SmartEmergencyQueue.shared instead of EmergencyQueueManager
//
// Reason: Duplicate functionality. SmartQueue provides superior Spotify-like UX
//         with AI-powered track selection.
//
// See: ADR-0125 (Deprecation Strategy), ADR-0126 (SmartQueue Canonical System)
// =============================================================================
//
//  EmergencyQueueManager.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//  Manages emergency session queue and playback state
//

import Foundation
import Combine

/// Manages emergency cry response session with queue and playback tracking
@available(*, deprecated, message: "Use SmartEmergencyQueue.shared instead. See ADR-0125.")
@MainActor
class EmergencyQueueManager: ObservableObject {
    // MARK: - Published State

    @Published var currentTrack: AudioTrack?
    @Published var upcomingTracks: [AudioTrack] = []
    @Published var sessionId: String?
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var currentPlaylist: CryScenarioPlaylist?

    // MARK: - Private Properties

    private let apiClient: APIClient
    private let audioEngine: AudioEngine
    private var sessionStartTime: Date?
    private var allQueueTracks: [AudioTrack] = []
    private var currentTrackIndex: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    nonisolated init(apiClient: APIClient, audioEngine: AudioEngine) {
        self.apiClient = apiClient
        self.audioEngine = audioEngine
    }

    convenience init() {
        self.init(apiClient: .shared, audioEngine: .shared)
        setupAudioEngineObservers()
    }

    // MARK: - Session Management

    /// Start emergency session with selected playlist
    func startSession(playlist: CryScenarioPlaylist, babyId: String) async throws {
        print("🚨 Starting emergency session with playlist: \(playlist.name)")

        // Call API to create session
        let request = StartSessionRequest(babyId: babyId, playlistId: playlist.id)
        let requestData = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: URL(string: "\(apiClient.baseURL)/emergency/session/start")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EmergencyQueueError.sessionStartFailed
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sessionResponse = try decoder.decode(StartSessionResponse.self, from: data)

        // Update state
        self.sessionId = sessionResponse.sessionId
        self.sessionStartTime = Date()
        self.currentPlaylist = playlist
        self.allQueueTracks = playlist.tracks
        self.currentTrackIndex = 0

        // Set current and upcoming tracks
        if !playlist.tracks.isEmpty {
            self.currentTrack = playlist.tracks[0]
            self.upcomingTracks = Array(playlist.tracks.dropFirst().prefix(5))

            // Start playback (immediate, no crossfade for emergency)
            audioEngine.playImmediateWithoutFade(track: playlist.tracks[0])
            self.isPlaying = true

            // Start progress tracking
            startProgressTracking()
        }

        print("✅ Emergency session started: \(sessionResponse.sessionId)")
    }

    /// Advance to next track in queue
    func advanceToNextTrack() async throws {
        guard currentTrackIndex < allQueueTracks.count - 1 else {
            print("⚠️ End of queue reached")
            return
        }

        currentTrackIndex += 1
        let nextTrack = allQueueTracks[currentTrackIndex]

        print("⏭️ Advancing to track: \(nextTrack.title)")

        // Update current track
        self.currentTrack = nextTrack

        // Update upcoming tracks (next 5)
        let remainingTracks = Array(allQueueTracks.dropFirst(currentTrackIndex + 1))
        self.upcomingTracks = Array(remainingTracks.prefix(5))

        // Use smooth crossfade for subsequent tracks
        try await audioEngine.crossfade(to: nextTrack, duration: 2.0)
    }

    /// End session and record effectiveness
    func endSession(effective: Bool) async throws {
        guard let sessionId = sessionId,
              let startTime = sessionStartTime else {
            throw EmergencyQueueError.noActiveSession
        }

        let calmingTime = Int(Date().timeIntervalSince(startTime))

        print("🛑 Ending emergency session (effective: \(effective), duration: \(calmingTime)s)")

        // Stop playback
        audioEngine.stop()
        self.isPlaying = false

        // Call API to end session
        let request = EndSessionRequest(
            sessionId: sessionId,
            effective: effective,
            calmingTimeSeconds: calmingTime,
            userSwitched: false
        )

        let requestData = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: URL(string: "\(apiClient.baseURL)/emergency/session/end")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EmergencyQueueError.sessionEndFailed
        }

        let decoder = JSONDecoder()
        let endResponse = try decoder.decode(EndSessionResponse.self, from: data)

        print("✅ Session ended successfully. Updated confidence score: \(endResponse.updatedConfidenceScore ?? 0)")

        // Reset state
        resetState()
    }

    /// Cancel session without recording effectiveness (quick exit)
    func cancelSession() async throws {
        guard sessionId != nil else { return }

        print("❌ Canceling emergency session")

        // Record as ineffective
        try await endSession(effective: false)
    }

    // MARK: - Private Methods

    private func setupAudioEngineObservers() {
        // Listen for track completion
        NotificationCenter.default.publisher(for: .audioTrackDidFinish)
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await self?.advanceToNextTrack()
                }
            }
            .store(in: &cancellables)
    }

    private func startProgressTracking() {
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                self.progress = self.audioEngine.currentProgress
            }
            .store(in: &cancellables)
    }

    private func resetState() {
        self.sessionId = nil
        self.currentTrack = nil
        self.upcomingTracks = []
        self.sessionStartTime = nil
        self.currentPlaylist = nil
        self.allQueueTracks = []
        self.currentTrackIndex = 0
        self.progress = 0.0
        self.isPlaying = false
    }

    // MARK: - Computed Properties

    /// Formatted session duration
    var sessionDuration: String {
        guard let startTime = sessionStartTime else { return "0:00" }
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Progress through queue (0.0 - 1.0)
    var queueProgress: Double {
        guard !allQueueTracks.isEmpty else { return 0.0 }
        return Double(currentTrackIndex) / Double(allQueueTracks.count)
    }

    /// Remaining tracks count
    var remainingTracksCount: Int {
        return max(0, allQueueTracks.count - currentTrackIndex - 1)
    }
}

// MARK: - Errors

enum EmergencyQueueError: LocalizedError {
    case sessionStartFailed
    case sessionEndFailed
    case noActiveSession
    case invalidPlaylist

    var errorDescription: String? {
        switch self {
        case .sessionStartFailed:
            return "Failed to start emergency session"
        case .sessionEndFailed:
            return "Failed to end emergency session"
        case .noActiveSession:
            return "No active emergency session"
        case .invalidPlaylist:
            return "Invalid playlist data"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioTrackDidFinish = Notification.Name("audioTrackDidFinish")
}

// MARK: - Mock for Testing

extension EmergencyQueueManager {
    @available(*, deprecated, message: "Use SmartEmergencyQueue.createMock() instead. See ADR-0125.")
    @MainActor
    static func createMock() -> EmergencyQueueManager {
        let manager = EmergencyQueueManager()
        manager.currentTrack = AudioTrack(
            title: "Brahms Lullaby",
            artist: "Classical Collection",
            category: .classicalMusic,
            duration: 180,
            audioSourceType: .bundled
        )
        manager.upcomingTracks = [
            AudioTrack(
                title: "Ocean Waves",
                artist: "Nature Sounds",
                category: .natureSounds,
                duration: 300,
                audioSourceType: .generated,
                generatorType: .ocean
            ),
            AudioTrack(
                title: "Russian Lullaby",
                artist: "Folk",
                category: .childrenSongs,
                language: .russian,
                duration: 120,
                audioSourceType: .bundled
            ),
        ]
        manager.isPlaying = true
        manager.progress = 0.45
        return manager
    }
}
