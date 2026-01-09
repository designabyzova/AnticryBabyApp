import Foundation
import WatchConnectivity
import WatchKit
import UserNotifications
import Combine

/// Manages WatchConnectivity on the Apple Watch side
/// Handles state sync from iPhone, file transfers, and command sending
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published private(set) var isPhoneReachable = false
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var iPhonePlaybackState: PlaybackState = .idle
    @Published private(set) var favorites: [WatchTrack] = []
    @Published private(set) var pendingCryAlerts: [CryAlert] = []
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var libraryState: WatchLibraryState = .empty
    @Published private(set) var isEmergencyModeActive = false

    // MARK: - Private Properties

    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoggedCompanionNotInstalled = false

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
        loadCachedFavorites()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[WatchConnectivity] Not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[WatchConnectivity] Session activation requested")
    }

    // MARK: - Public API - Send Commands to iPhone

    /// Send a command to iPhone
    func sendCommand(_ command: WatchCommand) {
        guard let session = session else {
            print("[WatchConnectivity] No session available")
            return
        }

        // Check activation state first
        guard session.activationState == .activated else {
            print("[WatchConnectivity] Session not activated yet")
            return
        }

        // Check if iPhone app is installed (prevents 7018 error spam)
        #if os(watchOS)
        guard session.isCompanionAppInstalled else {
            // Only log once per session to avoid spam
            if !hasLoggedCompanionNotInstalled {
                print("[WatchConnectivity] ⚠️ iPhone companion app not installed or not paired")
                hasLoggedCompanionNotInstalled = true
            }
            return
        }
        #endif

        guard session.isReachable else {
            print("[WatchConnectivity] iPhone not reachable, cannot send command")
            return
        }

        do {
            let data = try JSONEncoder().encode(command)
            let message: [String: Any] = [
                "command": data
            ]

            session.sendMessage(message, replyHandler: { _ in
                print("[WatchConnectivity] Command sent successfully: \(command)")
                // Haptic feedback for confirmation
                WKInterfaceDevice.current().play(.click)
            }, errorHandler: { [weak self] error in
                let nsError = error as NSError
                // Silently ignore "companion not installed" errors (7018)
                if nsError.domain == "WCErrorDomain" && nsError.code == 7018 {
                    self?.hasLoggedCompanionNotInstalled = true
                    return
                }
                print("[WatchConnectivity] Failed to send command: \(error)")
                // Haptic feedback for error
                WKInterfaceDevice.current().play(.failure)
            })
        } catch {
            print("[WatchConnectivity] Failed to encode command: \(error)")
        }
    }

    /// Send play command
    func sendPlayCommand() {
        sendCommand(.play)
    }

    /// Send pause command
    func sendPauseCommand() {
        sendCommand(.pause)
    }

    /// Toggle play/pause
    func togglePlayPause() {
        // Optimistically update local state for immediate UI feedback
        iPhonePlaybackState = PlaybackState(
            isPlaying: !iPhonePlaybackState.isPlaying,
            currentTrackId: iPhonePlaybackState.currentTrackId,
            currentTrackTitle: iPhonePlaybackState.currentTrackTitle,
            currentTrackArtist: iPhonePlaybackState.currentTrackArtist,
            progress: iPhonePlaybackState.progress,
            volume: iPhonePlaybackState.volume,
            sleepTimerRemaining: iPhonePlaybackState.sleepTimerRemaining,
            timestamp: Date()
        )
        sendCommand(.togglePlayPause)
    }

    /// Send skip next command
    func sendSkipNextCommand() {
        sendCommand(.skipNext)
    }

    /// Send skip previous command
    func sendSkipPreviousCommand() {
        sendCommand(.skipPrevious)
    }

    /// Set sleep timer on iPhone
    func setSleepTimer(minutes: Int) {
        sendCommand(.setSleepTimer(minutes: minutes))
    }

    /// Cancel sleep timer on iPhone
    func cancelSleepTimer() {
        sendCommand(.cancelSleepTimer)
    }

    /// Request iPhone to start soothing music
    func startSoothingMusic(playlistId: String? = nil) {
        sendCommand(.startSoothingMusic(playlistId: playlistId))
    }

    /// Request state sync from iPhone
    func requestStateSync() {
        sendCommand(.requestStateSync)
    }

    /// Request iPhone to play specific track
    func playTrack(trackId: String) {
        sendCommand(.playTrack(trackId: trackId))
    }

    /// Request iPhone to play a category
    func playCategory(categoryId: String) {
        sendCommand(.playCategory(categoryId: categoryId))
    }

    /// Start emergency mode on iPhone (music only)
    func startEmergencyMode() {
        sendCommand(.startEmergencyMode)
        isEmergencyModeActive = true
        WKInterfaceDevice.current().play(.notification)
    }

    /// Start emergency mode on iPhone WITH cry detection monitoring enabled
    /// This is the full emergency experience - plays soothing music AND listens for baby cries
    func startEmergencyModeWithCryDetection() {
        sendCommand(.startEmergencyModeWithCryDetection)
        isEmergencyModeActive = true
        WKInterfaceDevice.current().play(.notification)
        print("[WatchConnectivity] 🚨🎤 Requesting emergency mode WITH cry detection")
    }

    /// Stop emergency mode on iPhone
    func stopEmergencyMode() {
        sendCommand(.stopEmergencyMode)
        isEmergencyModeActive = false
    }

    /// Request library sync from iPhone
    func requestLibrarySync() {
        sendCommand(.requestLibrarySync)
    }

    // MARK: - Cry Alert Management

    /// Dismiss a cry alert
    func dismissAlert(_ alert: CryAlert) {
        pendingCryAlerts.removeAll { $0.id == alert.id }
    }

    /// Dismiss all cry alerts
    func dismissAllAlerts() {
        pendingCryAlerts.removeAll()
    }

    // MARK: - Private Helpers

    private func loadCachedFavorites() {
        // Load favorites from local storage
        if let data = UserDefaults.standard.data(forKey: "watchFavorites"),
           let favorites = try? JSONDecoder().decode([WatchTrack].self, from: data) {
            self.favorites = favorites
            print("[WatchConnectivity] Loaded \(favorites.count) cached favorites")
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "watchFavorites")
        }
    }

    private func handleCryAlert(_ alert: CryAlert) {
        // Add to pending alerts
        pendingCryAlerts.insert(alert, at: 0)

        // Keep only last 20 alerts
        if pendingCryAlerts.count > 20 {
            pendingCryAlerts = Array(pendingCryAlerts.prefix(20))
        }

        // Play haptic notification
        WKInterfaceDevice.current().play(.notification)

        // Post local notification
        postCryAlertNotification(alert)
    }

    private func postCryAlertNotification(_ alert: CryAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Cry Detected: \(alert.cryType.displayName)"
        content.body = alert.suggestedAction
        content.categoryIdentifier = "CRY_ALERT"
        content.sound = .default

        // Add alert data for notification controller
        if let data = try? JSONEncoder().encode(alert) {
            content.userInfo = ["alertData": data]
        }

        // Add action button
        let playMusicAction = UNNotificationAction(
            identifier: "PLAY_MUSIC",
            title: "Play Soothing Music",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: "CRY_ALERT",
            actions: [playMusicAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[WatchConnectivity] Failed to post notification: \(error)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
            // Only consider reachable if companion app is installed AND session is reachable
            self.isPhoneReachable = session.isCompanionAppInstalled && session.isReachable

            if let error = error {
                print("[WatchConnectivity] Activation failed: \(error)")
            } else {
                print("[WatchConnectivity] Activation complete: \(activationState.rawValue)")
                print("[WatchConnectivity] Companion app installed: \(session.isCompanionAppInstalled)")
                print("[WatchConnectivity] Is reachable: \(session.isReachable)")

                if activationState == .activated && session.isCompanionAppInstalled {
                    self.hasLoggedCompanionNotInstalled = false  // Reset flag on successful activation
                    self.requestStateSync()
                }
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            // Only consider reachable if companion app is installed AND session is reachable
            self.isPhoneReachable = session.isCompanionAppInstalled && session.isReachable
            print("[WatchConnectivity] Reachability changed: \(session.isReachable), companion installed: \(session.isCompanionAppInstalled)")

            if session.isReachable && session.isCompanionAppInstalled {
                self.hasLoggedCompanionNotInstalled = false  // Reset flag
                self.requestStateSync()
            }
        }
    }

    // MARK: - Application Context

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleApplicationContext(applicationContext)
        }
    }

    @MainActor
    private func handleApplicationContext(_ context: [String: Any]) {
        // Handle playback state
        if let stateData = context["playbackState"] as? Data {
            do {
                let state = try JSONDecoder().decode(PlaybackState.self, from: stateData)
                self.iPhonePlaybackState = state
                print("[WatchConnectivity] Received playback state update")
            } catch {
                print("[WatchConnectivity] Failed to decode playback state: \(error)")
            }
        }

        // Handle favorites update
        if let favoritesData = context["favoritesUpdate"] as? Data {
            do {
                let favorites = try JSONDecoder().decode([WatchTrack].self, from: favoritesData)
                self.favorites = favorites
                self.saveFavorites()
                print("[WatchConnectivity] Received favorites update: \(favorites.count) tracks")
            } catch {
                print("[WatchConnectivity] Failed to decode favorites: \(error)")
            }
        }

        // Handle library state update
        if let libraryData = context["libraryState"] as? Data {
            do {
                let state = try JSONDecoder().decode(WatchLibraryState.self, from: libraryData)
                self.libraryState = state
                print("[WatchConnectivity] Received library state: \(state.categories.count) categories")
            } catch {
                print("[WatchConnectivity] Failed to decode library state: \(error)")
            }
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
        // Handle cry alert
        if let alertData = message["cryAlert"] as? Data {
            do {
                let alert = try JSONDecoder().decode(CryAlert.self, from: alertData)
                handleCryAlert(alert)
            } catch {
                print("[WatchConnectivity] Failed to decode cry alert: \(error)")
            }
        }

        // Handle emergency state
        if let isActive = message["emergencyState"] as? Bool {
            self.isEmergencyModeActive = isActive
            if isActive {
                WKInterfaceDevice.current().play(.notification)
            }
            print("[WatchConnectivity] Emergency mode: \(isActive)")
        }
    }

    // MARK: - File Transfer

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            handleReceivedFile(file)
        }
    }

    @MainActor
    private func handleReceivedFile(_ file: WCSessionFile) {
        guard let metadata = file.metadata,
              let trackId = metadata["trackId"] as? String,
              let trackMetadataData = metadata["metadata"] as? Data else {
            print("[WatchConnectivity] Invalid file transfer metadata")
            return
        }

        do {
            var track = try JSONDecoder().decode(WatchTrack.self, from: trackMetadataData)

            // Move file to permanent location
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioPath = documentsPath.appendingPathComponent("Audio", isDirectory: true)

            try? FileManager.default.createDirectory(at: audioPath, withIntermediateDirectories: true)

            let destinationURL = audioPath.appendingPathComponent("\(trackId).m4a")

            // Remove existing file if any
            try? FileManager.default.removeItem(at: destinationURL)

            // Copy file
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)

            // Update track with local URL
            track.localURL = destinationURL
            track.isSynced = true

            // Update favorites
            if let index = favorites.firstIndex(where: { $0.id == trackId }) {
                favorites[index] = track
            } else {
                favorites.append(track)
            }

            saveFavorites()
            print("[WatchConnectivity] File transfer complete for: \(track.title)")
        } catch {
            print("[WatchConnectivity] Failed to handle file transfer: \(error)")
        }
    }
}
