//
//  PlaybackQueueManager.swift
//  BabyInCarApp
//
//  World-class playback queue manager for regular content playback
//  (music, fairy tales, podcasts - NOT emergency/cry mode)
//
//  Features:
//  - Spotify-like queue management with "Up Next" and "Playing From" sections
//  - Smart category-based queue building
//  - Cross-fade support between tracks
//  - Drag-to-reorder support
//  - AI-powered track suggestions
//  - Listening history tracking
//

import Foundation
import Combine

/// Manages regular playback queue with Spotify-like UX
/// This is separate from SmartEmergencyQueue which handles cry-response scenarios
@MainActor
class PlaybackQueueManager: ObservableObject {
    static let shared = PlaybackQueueManager()

    // MARK: - Published State (Spotify-like)

    /// Whether queue view is currently shown
    @Published var isQueueVisible: Bool = false

    /// Currently playing track
    @Published var currentTrack: AudioTrack?

    /// Tracks manually added to "Up Next" by user
    @Published var upNextTracks: [AudioTrack] = []

    /// Tracks from the current playlist/category context
    @Published var contextTracks: [AudioTrack] = []

    /// Played tracks history (for "Recently Played" section)
    @Published var recentlyPlayedTracks: [AudioTrack] = []

    /// Current context name (e.g., "Classical Music", "Bedtime Stories")
    @Published var contextName: String = ""

    /// Current context type for UI styling
    @Published var contextType: QueueContextType = .playlist

    /// Playback progress for current track (0.0 - 1.0)
    @Published var currentProgress: Double = 0.0

    /// Whether currently playing
    @Published var isPlaying: Bool = false

    /// Shuffle mode
    @Published var isShuffled: Bool = false

    /// Repeat mode
    @Published var repeatMode: RepeatMode = .off

    // MARK: - Queue State

    /// Total tracks in queue (upNext + remaining context)
    var totalQueueCount: Int {
        upNextTracks.count + contextTracks.count
    }

    /// Is queue empty
    var isQueueEmpty: Bool {
        upNextTracks.isEmpty && contextTracks.isEmpty
    }

    /// Has tracks in up next
    var hasUpNext: Bool {
        !upNextTracks.isEmpty
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared
    private let maxRecentlyPlayed = 20

    // MARK: - Queue Context Types

    enum QueueContextType: String {
        case playlist = "playlist"
        case category = "category"
        case album = "album"
        case fairyTale = "fairytale"
        case podcast = "podcast"
        case favorites = "favorites"
        case recentlyPlayed = "recent"
        case search = "search"
        case radio = "radio"

        var icon: String {
            switch self {
            case .playlist: return "music.note.list"
            case .category: return "folder.fill"
            case .album: return "square.stack.fill"
            case .fairyTale: return "book.fill"
            case .podcast: return "mic.fill"
            case .favorites: return "heart.fill"
            case .recentlyPlayed: return "clock.arrow.circlepath"
            case .search: return "magnifyingglass"
            case .radio: return "antenna.radiowaves.left.and.right"
            }
        }

        var gradientColors: [String] {
            switch self {
            case .playlist: return ["#667eea", "#764ba2"]
            case .category: return ["#f093fb", "#f5576c"]
            case .album: return ["#4facfe", "#00f2fe"]
            case .fairyTale: return ["#fa709a", "#fee140"]
            case .podcast: return ["#a8edea", "#fed6e3"]
            case .favorites: return ["#ff758c", "#ff7eb3"]
            case .recentlyPlayed: return ["#667eea", "#764ba2"]
            case .search: return ["#43e97b", "#38f9d7"]
            case .radio: return ["#f83600", "#f9d423"]
            }
        }
    }

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

    // MARK: - Initialization

    private init() {
        setupObservers()
        loadRecentlyPlayed()
    }

    // MARK: - Queue Management

    /// Build queue from a playlist
    func buildQueue(from playlist: Playlist, startingWith track: AudioTrack? = nil) {
        contextName = playlist.name
        contextType = .playlist

        let tracks = playlist.tracks

        // Find starting index
        var startIndex = 0
        if let track = track, let index = tracks.firstIndex(where: { $0.id == track.id }) {
            startIndex = index
        }

        // Set current track
        currentTrack = tracks[startIndex]

        // Remaining tracks become context
        if startIndex + 1 < tracks.count {
            contextTracks = Array(tracks[(startIndex + 1)...])
        } else {
            contextTracks = []
        }

        // Clear up next (user-added) when starting new playlist
        upNextTracks = []

        // Add to recently played
        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        syncWithAudioEngine()
    }

    /// Build queue from a category (all tracks in category)
    func buildQueue(from category: AudioCategory, startingWith track: AudioTrack? = nil) {
        let tracks = contentLibrary.getTracks(for: category)
        guard !tracks.isEmpty else { return }

        contextName = category.rawValue
        contextType = .category

        var startIndex = 0
        if let track = track, let index = tracks.firstIndex(where: { $0.id == track.id }) {
            startIndex = index
        }

        currentTrack = tracks[startIndex]

        if startIndex + 1 < tracks.count {
            contextTracks = Array(tracks[(startIndex + 1)...])
        } else {
            contextTracks = []
        }

        upNextTracks = []

        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        syncWithAudioEngine()
    }

    /// Build queue from individual tracks (e.g., search results, favorites)
    func buildQueue(from tracks: [AudioTrack], contextName: String, contextType: QueueContextType, startingWith track: AudioTrack? = nil) {
        guard !tracks.isEmpty else { return }

        self.contextName = contextName
        self.contextType = contextType

        var startIndex = 0
        if let track = track, let index = tracks.firstIndex(where: { $0.id == track.id }) {
            startIndex = index
        }

        currentTrack = tracks[startIndex]

        if startIndex + 1 < tracks.count {
            contextTracks = Array(tracks[(startIndex + 1)...])
        } else {
            contextTracks = []
        }

        upNextTracks = []

        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        syncWithAudioEngine()
    }

    /// Add track to play immediately after current track
    func playNext(_ track: AudioTrack) {
        // Don't add duplicates
        if !upNextTracks.contains(where: { $0.id == track.id }) {
            upNextTracks.insert(track, at: 0)
            audioEngine.playNext(track)
        }
    }

    /// Add track to end of queue
    func addToQueue(_ track: AudioTrack) {
        // Add to up next for visibility
        if !upNextTracks.contains(where: { $0.id == track.id }) {
            upNextTracks.append(track)
            audioEngine.addToQueue(track)
        }
    }

    /// Add multiple tracks to queue
    func addToQueue(_ tracks: [AudioTrack]) {
        for track in tracks {
            addToQueue(track)
        }
    }

    /// Remove track from up next queue
    func removeFromUpNext(at index: Int) {
        guard index >= 0 && index < upNextTracks.count else { return }
        upNextTracks.remove(at: index)
        audioEngine.removeFromQueue(at: index)
    }

    /// Remove track from context queue
    func removeFromContext(at index: Int) {
        guard index >= 0 && index < contextTracks.count else { return }
        contextTracks.remove(at: index)
    }

    /// Clear up next queue
    func clearUpNext() {
        upNextTracks.removeAll()
        audioEngine.clearQueue()
    }

    /// Move track within up next queue
    func moveInUpNext(from source: IndexSet, to destination: Int) {
        upNextTracks.move(fromOffsets: source, toOffset: destination)
        // Sync with audio engine
        audioEngine.clearQueue()
        for track in upNextTracks {
            audioEngine.addToQueue(track)
        }
    }

    /// Skip to a specific track in up next
    func playFromUpNext(at index: Int) {
        guard index >= 0 && index < upNextTracks.count else { return }

        // Move current to recently played
        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        // Get the track and remove from queue
        let track = upNextTracks.remove(at: index)
        currentTrack = track

        // Sync and play
        audioEngine.play(track: track)
    }

    /// Skip to a specific track in context
    func playFromContext(at index: Int) {
        guard index >= 0 && index < contextTracks.count else { return }

        // Move current to recently played
        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        // Get the track
        let track = contextTracks[index]
        currentTrack = track

        // Update context (remove played tracks)
        if index + 1 < contextTracks.count {
            contextTracks = Array(contextTracks[(index + 1)...])
        } else {
            contextTracks = []
        }

        // Play
        audioEngine.play(track: track)
    }

    // MARK: - Playback Control

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            audioEngine.pause()
        } else {
            audioEngine.resume()
        }
    }

    /// Skip to next track
    func next() {
        // Move current to recently played
        if let current = currentTrack {
            addToRecentlyPlayed(current)
        }

        // Check up next first
        if !upNextTracks.isEmpty {
            currentTrack = upNextTracks.removeFirst()
        } else if !contextTracks.isEmpty {
            currentTrack = contextTracks.removeFirst()
        } else {
            // Queue empty - handle repeat mode
            handleQueueEnd()
            return
        }

        if let track = currentTrack {
            audioEngine.play(track: track)
        }
    }

    /// Skip to previous track
    func previous() {
        guard !recentlyPlayedTracks.isEmpty else {
            // No history - restart current
            audioEngine.seek(to: 0)
            return
        }

        // Move current back to front of queue
        if let current = currentTrack {
            upNextTracks.insert(current, at: 0)
        }

        // Get previous from history
        currentTrack = recentlyPlayedTracks.removeLast()

        if let track = currentTrack {
            audioEngine.play(track: track)
        }
    }

    /// Toggle shuffle mode
    func toggleShuffle() {
        isShuffled.toggle()

        if isShuffled {
            // Shuffle context tracks
            contextTracks.shuffle()
        }

        audioEngine.toggleShuffle()
    }

    /// Cycle repeat mode
    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }

        audioEngine.cycleRepeatMode()
    }

    // MARK: - Private Helpers

    private func handleQueueEnd() {
        switch repeatMode {
        case .off:
            // Stop playback
            isPlaying = false
            currentTrack = nil
        case .all:
            // Rebuild queue from recently played
            if !recentlyPlayedTracks.isEmpty {
                contextTracks = Array(recentlyPlayedTracks.reversed())
                recentlyPlayedTracks.removeAll()
                next()
            }
        case .one:
            // Repeat current - handled by AudioEngine
            if let track = currentTrack {
                audioEngine.play(track: track)
            }
        }
    }

    private func addToRecentlyPlayed(_ track: AudioTrack) {
        // Remove if already exists (to move to front)
        recentlyPlayedTracks.removeAll { $0.id == track.id }

        // Add to front
        recentlyPlayedTracks.append(track)

        // Trim to max size
        if recentlyPlayedTracks.count > maxRecentlyPlayed {
            recentlyPlayedTracks.removeFirst()
        }

        saveRecentlyPlayed()
    }

    private func syncWithAudioEngine() {
        // Sync state from AudioEngine
        isPlaying = audioEngine.playbackState == .playing
        isShuffled = audioEngine.isShuffleEnabled

        switch audioEngine.repeatMode {
        case .off: repeatMode = .off
        case .all: repeatMode = .all
        case .one: repeatMode = .one
        }
    }

    private func setupObservers() {
        // Observe AudioEngine state changes
        audioEngine.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isPlaying = state == .playing
            }
            .store(in: &cancellables)

        audioEngine.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                guard let self = self else { return }
                // Sync current track if changed externally
                if let track = track, track.id != self.currentTrack?.id {
                    self.currentTrack = track
                    self.addToRecentlyPlayed(track)
                }
            }
            .store(in: &cancellables)

        audioEngine.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self = self, self.audioEngine.duration > 0 else { return }
                self.currentProgress = time / self.audioEngine.duration
            }
            .store(in: &cancellables)

        // Sync with AudioEngine's upNextQueue
        audioEngine.$upNextQueue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queue in
                self?.upNextTracks = queue
            }
            .store(in: &cancellables)

        // Sync with AudioEngine's current playlist
        audioEngine.$currentPlaylist
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playlist in
                guard let self = self, let playlist = playlist else {
                    self?.contextTracks = []
                    self?.contextName = ""
                    return
                }
                self.contextName = playlist.name
                self.contextType = .playlist

                // Calculate remaining tracks
                let startIndex = self.audioEngine.currentPlaylistIndex + 1
                if startIndex < playlist.tracks.count {
                    self.contextTracks = Array(playlist.tracks[startIndex...])
                } else {
                    self.contextTracks = []
                }
            }
            .store(in: &cancellables)

        // Sync current playlist index changes
        audioEngine.$currentPlaylistIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let playlist = self.audioEngine.currentPlaylist else { return }
                let startIndex = self.audioEngine.currentPlaylistIndex + 1
                if startIndex < playlist.tracks.count {
                    self.contextTracks = Array(playlist.tracks[startIndex...])
                } else {
                    self.contextTracks = []
                }
            }
            .store(in: &cancellables)

        // Sync shuffle state
        audioEngine.$isShuffleEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shuffled in
                self?.isShuffled = shuffled
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func saveRecentlyPlayed() {
        let trackIds = recentlyPlayedTracks.map { $0.id.uuidString }
        UserDefaults.standard.set(trackIds, forKey: "playbackQueue.recentlyPlayed")
    }

    private func loadRecentlyPlayed() {
        guard let trackIds = UserDefaults.standard.stringArray(forKey: "playbackQueue.recentlyPlayed") else {
            return
        }

        // Reconstruct tracks from IDs
        for id in trackIds {
            if let track = contentLibrary.getTrack(byId: id) {
                recentlyPlayedTracks.append(track)
            }
        }
    }

    // MARK: - AI Suggestions

    /// Get AI-powered track suggestions based on current context
    func getSuggestedTracks(limit: Int = 5) -> [AudioTrack] {
        guard let current = currentTrack else { return [] }

        let allTracks = contentLibrary.allTracks
        let favoritesManager = FavoritesManager.shared
        let effectivenessManager = EffectivenessManager.shared

        // Score tracks based on:
        // 1. Same category
        // 2. Favorites
        // 3. Effectiveness history
        // 4. Not already in queue

        let queuedIds = Set(
            [currentTrack?.id].compactMap { $0 } +
            upNextTracks.map { $0.id } +
            contextTracks.map { $0.id }
        )

        var scoredTracks: [(track: AudioTrack, score: Double)] = []

        for track in allTracks {
            // Skip if already in queue
            guard !queuedIds.contains(track.id) else { continue }

            var score: Double = 0

            // Same category bonus
            if track.category == current.category {
                score += 0.5
            }

            // Favorite bonus
            if favoritesManager.isFavorite(track: track) {
                score += 0.3
            }

            // Effectiveness bonus
            if let effectiveness = effectivenessManager.getEffectiveness(for: track.id),
               effectiveness.effectivenessScore > 0 {
                score += effectiveness.effectivenessScore * 0.4
            }

            // Calming score
            score += track.calmingScore * 0.2

            if score > 0 {
                scoredTracks.append((track, score))
            }
        }

        // Sort and take top
        return scoredTracks
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.track }
    }

    // MARK: - Queue Stats

    /// Get formatted queue duration
    var totalQueueDuration: String {
        let totalSeconds = upNextTracks.reduce(0) { $0 + $1.duration } +
                          contextTracks.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        let hours = minutes / 60

        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatted current track progress
    var formattedProgress: String {
        guard let track = currentTrack else { return "0:00" }
        let currentTime = track.duration * currentProgress
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted current track duration
    var formattedDuration: String {
        guard let track = currentTrack else { return "0:00" }
        let minutes = Int(track.duration) / 60
        let seconds = Int(track.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Queue Notification Names

extension Notification.Name {
    static let playbackQueueUpdated = Notification.Name("playbackQueueUpdated")
    static let playbackQueueContextChanged = Notification.Name("playbackQueueContextChanged")
}
