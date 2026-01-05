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

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
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
        print("[WatchSync] Received command from watch: \(command)")

        Task { @MainActor in
            switch command {
            case .play:
                AudioEngine.shared.resume()

            case .pause:
                AudioEngine.shared.pause()

            case .togglePlayPause:
                if AudioEngine.shared.isPlaying {
                    AudioEngine.shared.pause()
                } else {
                    AudioEngine.shared.resume()
                }

            case .skipNext:
                AudioEngine.shared.skipToNext()

            case .skipPrevious:
                AudioEngine.shared.skipToPrevious()

            case .setVolume(let volume):
                AudioEngine.shared.volume = volume

            case .setSleepTimer(let minutes):
                AudioEngine.shared.setSleepTimer(minutes: minutes)

            case .cancelSleepTimer:
                AudioEngine.shared.cancelSleepTimer()

            case .startSoothingMusic(let playlistId):
                // Start appropriate soothing playlist
                if let playlistId = playlistId {
                    // Load specific playlist
                    print("[WatchSync] Starting playlist: \(playlistId)")
                } else {
                    // Start default soothing music
                    print("[WatchSync] Starting default soothing music")
                }

            case .requestStateSync:
                sendCurrentState()

            case .playTrack(let trackId):
                // Find and play specific track
                print("[WatchSync] Playing track: \(trackId)")
            }
        }
    }

    // MARK: - Private Helpers

    private func sendCurrentState() {
        let state = PlaybackState(
            isPlaying: AudioEngine.shared.isPlaying,
            currentTrackId: AudioEngine.shared.currentTrack?.id.uuidString,
            currentTrackTitle: AudioEngine.shared.currentTrack?.title,
            currentTrackArtist: AudioEngine.shared.currentTrack?.artist,
            progress: AudioEngine.shared.progress,
            volume: AudioEngine.shared.volume,
            sleepTimerRemaining: AudioEngine.shared.sleepTimerRemaining,
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

// MARK: - AudioEngine Extension for Watch Compatibility

extension AudioEngine {
    var sleepTimerRemaining: TimeInterval? {
        // Return remaining sleep timer if set
        return nil // Implement based on existing sleep timer logic
    }

    func setSleepTimer(minutes: Int) {
        // Set sleep timer
        print("[AudioEngine] Sleep timer set for \(minutes) minutes")
    }

    func cancelSleepTimer() {
        // Cancel sleep timer
        print("[AudioEngine] Sleep timer cancelled")
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
