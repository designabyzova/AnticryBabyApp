import Foundation
import WatchConnectivity
import Combine

/// Manages bidirectional communication between iPhone and Apple Watch
/// Handles state sync, file transfers for audio, and real-time commands
@MainActor
final class WatchSyncManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchSyncManager()

    // MARK: - Published Properties

    @Published private(set) var isWatchReachable = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isPaired = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var pendingTransfers: [String: WCSessionFileTransfer] = [:]
    @Published private(set) var lastSyncDate: Date?

    // MARK: - Private Properties

    private var session: WCSession?
    private var queuedCryAlerts: [CryAlert] = []
    private var cancellables = Set<AnyCancellable>()

    // Storage limit for watch (50MB)
    private let maxWatchStorage: Int64 = 50 * 1024 * 1024

    // MARK: - Throttling (prevents Watch command flooding)

    /// Last time each command type was processed
    private var lastCommandTime: [String: Date] = [:]

    /// Minimum interval between same command types (300ms)
    private let commandThrottleInterval: TimeInterval = 0.3

    /// Track if a playback operation is in progress to prevent race conditions
    private var isPlaybackOperationInProgress = false

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
        observeFavorites()
    }

    /// Observe favorites changes and auto-sync to Watch
    private func observeFavorites() {
        FavoritesManager.shared.$favoriteTracks
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncFavoritesFromManager()
            }
            .store(in: &cancellables)
    }

    /// Sync current favorites to Watch
    func syncFavoritesFromManager() {
        let favorites = FavoritesManager.shared.getFavoriteTracks()
        let watchTracks = favorites.map { $0.toWatchTrack() }
        syncFavorites(watchTracks)
        print("[WatchSync] Auto-synced \(watchTracks.count) favorites to Watch")
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[WatchSync] WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[WatchSync] Session activation requested")
    }

    // MARK: - Public API

    /// Sync current playback state to watch
    func syncPlaybackState(_ state: PlaybackState) {
        guard let session = session, session.activationState == .activated else {
            print("[WatchSync] Cannot sync - session not activated")
            return
        }

        do {
            let data = try JSONEncoder().encode(state)
            let context: [String: Any] = [
                WatchMessage.playbackState.rawValue: data
            ]

            // Use application context for persistent state
            try session.updateApplicationContext(context)
            print("[WatchSync] Playback state synced to watch")
        } catch {
            print("[WatchSync] Failed to sync playback state: \(error)")
        }
    }

    /// Sync favorites list to watch (metadata only, files transferred separately)
    func syncFavorites(_ favorites: [WatchTrack]) {
        guard let session = session, session.activationState == .activated else {
            print("[WatchSync] Cannot sync favorites - session not activated")
            return
        }

        // Limit to 20 tracks for watch storage
        let limitedFavorites = Array(favorites.prefix(20))

        do {
            let data = try JSONEncoder().encode(limitedFavorites)
            let context: [String: Any] = [
                WatchMessage.favoritesUpdate.rawValue: data
            ]

            try session.updateApplicationContext(context)
            print("[WatchSync] Favorites list synced (\(limitedFavorites.count) tracks)")
        } catch {
            print("[WatchSync] Failed to sync favorites: \(error)")
        }
    }

    /// Send cry detection alert to watch
    func sendCryAlert(_ alert: CryAlert) {
        guard let session = session else {
            queuedCryAlerts.append(alert)
            return
        }

        guard session.isReachable else {
            queuedCryAlerts.append(alert)
            print("[WatchSync] Watch not reachable, alert queued")
            return
        }

        do {
            let data = try JSONEncoder().encode(alert)
            let message: [String: Any] = [
                WatchMessage.cryAlert.rawValue: data
            ]

            session.sendMessage(message, replyHandler: { _ in
                print("[WatchSync] Cry alert sent successfully")
            }, errorHandler: { error in
                print("[WatchSync] Failed to send cry alert: \(error)")
                self.queuedCryAlerts.append(alert)
            })
        } catch {
            print("[WatchSync] Failed to encode cry alert: \(error)")
        }
    }

    /// Transfer audio file to watch
    func transferAudioFile(trackId: String, fileURL: URL, metadata: WatchTrack) {
        guard let session = session, session.activationState == .activated else {
            print("[WatchSync] Cannot transfer - session not activated")
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[WatchSync] File does not exist: \(fileURL.path)")
            return
        }

        do {
            let metadataData = try JSONEncoder().encode(metadata)
            let transferMetadata: [String: Any] = [
                "trackId": trackId,
                "metadata": metadataData
            ]

            let transfer = session.transferFile(fileURL, metadata: transferMetadata)
            pendingTransfers[trackId] = transfer
            print("[WatchSync] Started file transfer for: \(metadata.title)")
        } catch {
            print("[WatchSync] Failed to start file transfer: \(error)")
        }
    }

    /// Cancel all pending file transfers
    func cancelAllTransfers() {
        for (trackId, transfer) in pendingTransfers {
            transfer.cancel()
            print("[WatchSync] Cancelled transfer for: \(trackId)")
        }
        pendingTransfers.removeAll()
    }

    /// Request sync from watch
    func requestSync() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            WatchMessage.requestSync.rawValue: true
        ]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSync] Sync request failed: \(error)")
        })
    }

    // MARK: - Command Handling

    func handleCommand(_ command: WatchCommand) {
        // THROTTLE: Prevent command flooding from Watch
        let commandKey = String(describing: command)
        let now = Date()

        if let lastTime = lastCommandTime[commandKey],
           now.timeIntervalSince(lastTime) < commandThrottleInterval {
            print("[WatchSync] ⏱️ Throttled duplicate command: \(commandKey)")
            return
        }
        lastCommandTime[commandKey] = now

        print("[WatchSync] Received command from watch: \(command)")

        Task { @MainActor in
            switch command {
            case .play:
                // If nothing is loaded, start a default playlist
                if AudioEngine.shared.currentTrack == nil {
                    startDefaultPlayback()
                } else {
                    AudioEngine.shared.resume()
                }

            case .pause:
                AudioEngine.shared.pause()

            case .togglePlayPause:
                if AudioEngine.shared.playbackState == .playing {
                    AudioEngine.shared.pause()
                } else if AudioEngine.shared.currentTrack == nil {
                    // Nothing loaded - start default playback
                    startDefaultPlayback()
                } else {
                    AudioEngine.shared.resume()
                }

            case .skipNext:
                AudioEngine.shared.next()

            case .skipPrevious:
                AudioEngine.shared.previous()

            case .setVolume(let volume):
                AudioEngine.shared.volume = volume

            case .setSleepTimer(let minutes):
                // Convert minutes to SleepTimer enum
                let timer: SleepTimer
                switch minutes {
                case 0: timer = .off
                case 15: timer = .fifteenMinutes
                case 30: timer = .thirtyMinutes
                case 45: timer = .fortyFiveMinutes
                case 60: timer = .oneHour
                case 120: timer = .twoHours
                default: timer = .thirtyMinutes  // Default if unsupported value
                }
                AudioEngine.shared.setSleepTimer(timer)

            case .cancelSleepTimer:
                AudioEngine.shared.setSleepTimer(.off)

            case .startSoothingMusic(let playlistId):
                // Start appropriate soothing playlist
                if let playlistId = playlistId {
                    // Load specific playlist
                    print("[WatchSync] Starting playlist: \(playlistId)")
                    playCategory(categoryId: playlistId)
                } else {
                    // Start default soothing music
                    print("[WatchSync] Starting default soothing music")
                    startDefaultPlayback()
                }

            case .requestStateSync:
                sendCurrentState()
                syncLibraryState()

            case .playTrack(let trackId):
                // Find and play specific track
                print("[WatchSync] Playing track: \(trackId)")
                if let track = ContentLibraryService.shared.getTrack(byId: trackId) {
                    AudioEngine.shared.play(track: track)
                    sendCurrentState()
                }

            case .playCategory(let categoryId):
                playCategory(categoryId: categoryId)

            case .startEmergencyMode:
                startEmergencyMode()

            case .startEmergencyModeWithCryDetection:
                startEmergencyModeWithCryDetection()

            case .stopEmergencyMode:
                stopEmergencyMode()

            case .requestLibrarySync:
                syncLibraryState()
            }
        }
    }

    // MARK: - Library Sync

    /// Last time library was synced (throttle to once per 2 seconds)
    private var lastLibrarySyncTime: Date?
    private let librarySyncThrottleInterval: TimeInterval = 2.0

    /// Sync library categories and tracks to Watch
    func syncLibraryState() {
        // THROTTLE: Prevent excessive library syncs
        let now = Date()
        if let lastSync = lastLibrarySyncTime,
           now.timeIntervalSince(lastSync) < librarySyncThrottleInterval {
            // Skip - synced recently
            return
        }
        lastLibrarySyncTime = now

        guard let session = session, session.activationState == .activated else {
            print("[WatchSync] Cannot sync library - session not activated")
            return
        }

        let library = ContentLibraryService.shared

        // Build categories with track counts
        let categories = AudioCategory.allCases.map { category in
            WatchCategory(
                id: category.rawValue,
                name: category.displayName,
                icon: category.iconName,
                trackCount: library.getTracks(for: category).count,
                description: category.description
            )
        }.filter { $0.trackCount > 0 }

        // Get top calming tracks (limit to 10 for Watch)
        let topCalming = library.getTopCalmingTracks(limit: 10).map { $0.toWatchTrack() }

        let libraryState = WatchLibraryState(
            categories: categories,
            recentTracks: [], // Could be populated from listening history
            topCalmingTracks: topCalming,
            timestamp: Date()
        )

        do {
            let data = try JSONEncoder().encode(libraryState)
            let context: [String: Any] = [
                WatchMessage.libraryState.rawValue: data
            ]

            try session.updateApplicationContext(context)
            print("[WatchSync] Library state synced (\(categories.count) categories)")
        } catch {
            print("[WatchSync] Failed to sync library state: \(error)")
        }
    }

    // MARK: - Default Playback

    /// Start default playback when nothing is loaded
    private func startDefaultPlayback() {
        // GUARD: Prevent concurrent playback operations
        guard !isPlaybackOperationInProgress else {
            print("[WatchSync] ⏱️ Playback operation already in progress - skipping")
            return
        }
        isPlaybackOperationInProgress = true

        print("[WatchSync] 🎵 Starting default playback from Watch")

        Task { @MainActor [weak self] in
            defer { self?.isPlaybackOperationInProgress = false }

            let library = ContentLibraryService.shared
            let audioEngine = AudioEngine.shared

            // Get calming tracks from classical music category
            let tracks = library.getTracks(for: .classicalMusic)
                .sorted { $0.calmingScore > $1.calmingScore }

            if tracks.isEmpty {
                print("[WatchSync] ⚠️ No tracks available - using fallback")
                let fallbackTrack = AudioTrack.defaultEmergencyTrack()
                audioEngine.play(track: fallbackTrack)
            } else {
                print("[WatchSync] 🎵 Starting queue with \(tracks.count) tracks")
                let playlist = Playlist(
                    name: "Watch Playback",
                    tracks: Array(tracks.prefix(20)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
            }

            self?.sendCurrentState()
        }
    }

    /// Play tracks from a specific category
    private func playCategory(categoryId: String) {
        // GUARD: Prevent concurrent playback operations
        guard !isPlaybackOperationInProgress else {
            print("[WatchSync] ⏱️ Playback operation already in progress - skipping category: \(categoryId)")
            return
        }
        isPlaybackOperationInProgress = true

        print("[WatchSync] 🎵 Playing category from Watch: \(categoryId)")

        Task { @MainActor [weak self] in
            defer { self?.isPlaybackOperationInProgress = false }

            let library = ContentLibraryService.shared
            let audioEngine = AudioEngine.shared
            let category = AudioCategory.fromJSONKey(categoryId)
            let tracks = library.getTracks(for: category)

            guard !tracks.isEmpty else {
                print("[WatchSync] ⚠️ No tracks in category: \(categoryId)")
                return
            }

            let playlist = Playlist(
                name: "Watch: \(category.rawValue)",
                tracks: tracks.shuffled(),
                createdAt: Date()
            )
            audioEngine.play(playlist: playlist)
            self?.sendCurrentState()
            print("[WatchSync] ✅ Started playing category: \(category.rawValue)")
        }
    }

    // MARK: - Calming Mode

    private func startEmergencyMode() {
        print("[WatchSync] 🎵 Starting calming mode from Watch")

        Task { @MainActor in
            let audioEngine = AudioEngine.shared
            let library = ContentLibraryService.shared

            // Get calming tracks from classical music
            let tracks = library.getTracks(for: .classicalMusic)
                .sorted { $0.calmingScore > $1.calmingScore }

            if tracks.isEmpty {
                print("[WatchSync] ⚠️ No calming tracks available - using default")
                let fallbackTrack = AudioTrack.defaultEmergencyTrack()
                audioEngine.play(track: fallbackTrack)
            } else {
                print("[WatchSync] 🎵 Starting calming playlist with \(tracks.count) tracks")
                let playlist = Playlist(
                    name: "Watch: Calming Music",
                    tracks: Array(tracks.prefix(15)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
            }

            // Send current state to Watch
            sendCurrentState()

            // Send calming state to Watch
            sendEmergencyState(isActive: true)
        }
    }

    /// Start calming mode WITH cry detection monitoring enabled
    private func startEmergencyModeWithCryDetection() {
        print("[WatchSync] 🎵🎤 Starting calming mode WITH cry detection from Watch")

        Task { @MainActor in
            // 1. Start cry detection monitoring FIRST
            let cryDetection = CryDetectionService.shared
            if !cryDetection.isMonitoring {
                do {
                    try await cryDetection.startMonitoring()
                    print("[WatchSync] ✅ Cry detection monitoring started from Watch request")
                } catch {
                    print("[WatchSync] ⚠️ Failed to start cry detection: \(error)")
                    // Continue anyway - at least play music
                }
            } else {
                print("[WatchSync] ℹ️ Cry detection already monitoring")
            }

            // 2. Start calming music playback
            let audioEngine = AudioEngine.shared
            let library = ContentLibraryService.shared

            let tracks = library.getTracks(for: .classicalMusic)
                .sorted { $0.calmingScore > $1.calmingScore }

            if tracks.isEmpty {
                print("[WatchSync] ⚠️ No calming tracks available - using default")
                let fallbackTrack = AudioTrack.defaultEmergencyTrack()
                audioEngine.play(track: fallbackTrack)
            } else {
                print("[WatchSync] 🎵 Starting calming playlist with \(tracks.count) tracks")
                let playlist = Playlist(
                    name: "Watch: Calming Music",
                    tracks: Array(tracks.prefix(15)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
            }

            // Send current state to Watch
            sendCurrentState()

            // Send calming state to Watch
            sendEmergencyState(isActive: true)
        }
    }

    private func stopEmergencyMode() {
        print("[WatchSync] 🛑 Stopping calming mode from Watch")

        Task { @MainActor in
            AudioEngine.shared.stop()

            sendEmergencyState(isActive: false)
            sendCurrentState()
        }
    }

    private func sendEmergencyState(isActive: Bool) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            WatchMessage.emergencyState.rawValue: isActive
        ]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSync] Failed to send emergency state: \(error)")
        })
    }

    // MARK: - Private Helpers

    /// Last time state was synced (throttle to once per 500ms)
    private var lastStateSyncTime: Date?
    private let stateSyncThrottleInterval: TimeInterval = 0.5

    private func sendCurrentState() {
        // THROTTLE: Prevent excessive state syncs
        let now = Date()
        if let lastSync = lastStateSyncTime,
           now.timeIntervalSince(lastSync) < stateSyncThrottleInterval {
            return // Skip - synced recently
        }
        lastStateSyncTime = now

        let engine = AudioEngine.shared
        // Calculate progress as ratio of currentTime/duration
        let progress = engine.duration > 0 ? engine.currentTime / engine.duration : 0
        // Convert sleepTimerRemaining: if > 0, pass value; otherwise nil
        let timerRemaining: TimeInterval? = engine.sleepTimerRemaining > 0 ? engine.sleepTimerRemaining : nil
        let state = PlaybackState(
            isPlaying: engine.playbackState == .playing,
            currentTrackId: engine.currentTrack?.id.uuidString,
            currentTrackTitle: engine.currentTrack?.title,
            currentTrackArtist: engine.currentTrack?.artist,
            progress: progress,
            volume: engine.volume,
            sleepTimerRemaining: timerRemaining,
            timestamp: Date()
        )
        syncPlaybackState(state)
    }

    private func sendQueuedAlerts() {
        guard !queuedCryAlerts.isEmpty else { return }

        let alerts = queuedCryAlerts
        queuedCryAlerts.removeAll()

        for alert in alerts {
            sendCryAlert(alert)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable

            if let error = error {
                print("[WatchSync] Activation failed: \(error)")
            } else {
                print("[WatchSync] Activation complete: \(activationState.rawValue)")
                if activationState == .activated {
                    self.sendCurrentState()
                    self.syncLibraryState()  // Sync library on activation
                    self.sendQueuedAlerts()
                }
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSync] Session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchSync] Session deactivated")
        // Reactivate session
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            print("[WatchSync] Reachability changed: \(session.isReachable)")

            if session.isReachable {
                self.sendCurrentState()
                self.syncLibraryState()  // Sync library when Watch reconnects
                self.sendQueuedAlerts()
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("[WatchSync] Watch state changed - paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
        }
    }

    // MARK: - Message Receiving

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }

    @MainActor
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Handle command from watch
        if let commandData = message[WatchMessage.command.rawValue] as? Data {
            do {
                let command = try JSONDecoder().decode(WatchCommand.self, from: commandData)
                handleCommand(command)
            } catch {
                print("[WatchSync] Failed to decode command: \(error)")
            }
        }

        // Handle sync request
        if message[WatchMessage.requestSync.rawValue] != nil {
            sendCurrentState()
        }
    }

    // MARK: - File Transfer

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            if let trackId = fileTransfer.file.metadata?["trackId"] as? String {
                self.pendingTransfers.removeValue(forKey: trackId)

                if let error = error {
                    print("[WatchSync] File transfer failed for \(trackId): \(error)")
                } else {
                    print("[WatchSync] File transfer complete for \(trackId)")
                    self.lastSyncDate = Date()
                }
            }
        }
    }
}


// MARK: - AudioTrack to WatchTrack Conversion

extension AudioTrack {
    /// Convert AudioTrack to WatchTrack for Apple Watch sync
    func toWatchTrack() -> WatchTrack {
        WatchTrack(
            id: id.uuidString,
            title: title,
            artist: artist,
            duration: duration,
            category: category.rawValue,
            localURL: nil,
            artworkData: nil
        )
    }
}

// MARK: - WatchSyncManager Convenience Methods

extension WatchSyncManager {
    /// Sync favorites from AudioTrack array
    func syncFavorites(from audioTracks: [AudioTrack]) {
        let watchTracks = audioTracks.map { $0.toWatchTrack() }
        syncFavorites(watchTracks)
    }

    /// Send cry alert from CryDetectionService
    func sendCryDetectionAlert(cryType: CryType, confidence: Double) {
        let alert = CryAlert(
            cryType: cryType,
            confidence: confidence,
            suggestedAction: cryType.suggestedAction,
            suggestedPlaylistId: nil
        )
        sendCryAlert(alert)
    }
}
