//
//  AudioSessionManager.swift
//  BabyInCarApp
//
//  Centralized audio session management for music playback.
//  Handles playback-only audio sessions (no microphone access needed).
//
//  NOTE: Audio capture / cry detection has been removed from this app.
//  This manager now handles playback-only audio session modes.
//

import Foundation
import AVFoundation
import Combine

/// Priority levels for audio session requests
/// Higher priority wins when there's a conflict
enum AudioSessionPriority: Int, Comparable {
    case background = 0      // Normal playback
    case playback = 1        // Active music playback
    case emergency = 2       // Emergency playback (highest)

    static func < (lhs: AudioSessionPriority, rhs: AudioSessionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Audio session mode requested by different services
enum AudioSessionMode: Equatable {
    case playbackOnly           // Normal music playback
    case emergencyPlayback      // Emergency playback (same as playback, different priority)
    case voiceInteraction       // Voice prompts + speech recognition (TTS + mic)
    case inactive               // No audio needed

    // Legacy compatibility aliases
    static let playAndRecord = playbackOnly
    static let recordOnly = inactive

    var category: AVAudioSession.Category {
        switch self {
        case .playbackOnly, .emergencyPlayback:
            return .playback
        case .voiceInteraction:
            return .playAndRecord
        case .inactive:
            return .ambient
        }
    }

    var mode: AVAudioSession.Mode {
        switch self {
        case .voiceInteraction:
            return .voiceChat
        default:
            return .default
        }
    }

    var options: AVAudioSession.CategoryOptions {
        switch self {
        case .playbackOnly, .emergencyPlayback:
            // Exclusive playback - pauses other apps (like Spotify, YouTube)
            // No mixing, no ducking - we want full control
            return []
        case .voiceInteraction:
            // Voice interaction: .defaultToSpeaker routes audio to speaker (not earpiece)
            // CRITICAL: NO .allowBluetooth (degrades to HFP mono)
            // CRITICAL: NO .mixWithOthers (must pause other apps)
            // CRITICAL: NO .duckOthers (we want exclusive control)
            return [.defaultToSpeaker]
        case .inactive:
            return []
        }
    }
}

/// Centralized audio session manager that coordinates all audio session changes
@MainActor
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    // MARK: - Published State

    /// Current active audio session mode
    @Published private(set) var currentMode: AudioSessionMode = .inactive

    /// Whether the audio session is currently active
    @Published private(set) var isSessionActive: Bool = false

    /// Last error that occurred during session configuration
    @Published private(set) var lastError: Error?

    /// Circuit breaker state - if true, stop attempting session changes
    @Published private(set) var isCircuitBreakerOpen: Bool = false

    // MARK: - Private State

    /// Active session requests from different services
    private var activeRequests: [String: (mode: AudioSessionMode, priority: AudioSessionPriority)] = [:]

    /// Serial queue for audio session operations
    private let sessionQueue = DispatchQueue(label: "com.babyincar.audiosession", qos: .userInteractive)

    /// Circuit breaker: consecutive failure count
    private var consecutiveFailures: Int = 0
    private let maxConsecutiveFailures: Int = 3
    private var circuitBreakerResetTask: Task<Void, Never>?

    /// Debounce timer for session changes
    private var pendingSessionChange: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.1  // 100ms debounce

    /// Lock for thread-safe request management
    private let requestLock = NSLock()

    // MARK: - Initialization

    private init() {
        setupInterruptionHandling()
    }

    // MARK: - Public API

    /// Request an audio session mode for a specific service
    /// - Parameters:
    ///   - mode: The audio session mode needed
    ///   - priority: Priority level for this request
    ///   - serviceId: Unique identifier for the requesting service
    /// - Returns: True if the request was accepted (may be pending activation)
    @discardableResult
    func requestSession(
        mode: AudioSessionMode,
        priority: AudioSessionPriority,
        serviceId: String
    ) -> Bool {
        guard !isCircuitBreakerOpen else {
            print("[AudioSessionManager] ⚠️ Circuit breaker OPEN - rejecting request from \(serviceId)")
            return false
        }

        requestLock.lock()
        activeRequests[serviceId] = (mode: mode, priority: priority)
        requestLock.unlock()

        print("[AudioSessionManager] 📥 Request from \(serviceId): \(mode) @ priority \(priority.rawValue)")

        // Debounce session changes to prevent rapid switching
        scheduleSessionUpdate()

        return true
    }

    /// Release an audio session request for a specific service
    /// - Parameter serviceId: The service releasing its request
    /// - Parameter immediate: If true, bypasses debounce for instant UI response (default: false)
    func releaseSession(serviceId: String, immediate: Bool = false) {
        requestLock.lock()
        let removed = activeRequests.removeValue(forKey: serviceId)
        requestLock.unlock()

        if removed != nil {
            print("[AudioSessionManager] 📤 Released request from \(serviceId) (immediate: \(immediate))")
            if immediate {
                // Bypass debounce for instant responsiveness
                pendingSessionChange?.cancel()
                // Since updateSession() is async and @MainActor, it handles its own scheduling
                // No need for DispatchQueue.main.async wrapper
                Task { @MainActor [weak self] in
                    await self?.updateSession()
                }
            } else {
                scheduleSessionUpdate()
            }
        }
    }

    /// Force deactivate the audio session (emergency use only)
    func forceDeactivate() {
        pendingSessionChange?.cancel()

        sessionQueue.async { [weak self] in
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
                // to avoid "Publishing changes from within view updates" warnings
                DispatchQueue.main.async {
                    self?.isSessionActive = false
                    self?.currentMode = .inactive
                    print("[AudioSessionManager] 🛑 Force deactivated audio session")
                }
            } catch {
                print("[AudioSessionManager] ⚠️ Force deactivate failed: \(error)")
            }
        }
    }

    /// Synchronously activate session for a specific mode (bypasses debounce)
    /// Use this when you need the session ready IMMEDIATELY before accessing audio hardware
    /// Returns true if activation succeeded
    /// - Parameters:
    ///   - mode: The audio session mode to activate
    ///   - serviceId: Unique identifier for the requesting service
    ///   - priority: Priority level for this request
    @discardableResult
    func activateSessionSync(
        mode: AudioSessionMode,
        priority: AudioSessionPriority,
        serviceId: String
    ) throws -> Bool {
        guard !isCircuitBreakerOpen else {
            print("[AudioSessionManager] ⚠️ Circuit breaker OPEN - rejecting sync request from \(serviceId)")
            throw AudioSessionError.circuitBreakerOpen
        }

        // Register the request
        requestLock.lock()
        activeRequests[serviceId] = (mode: mode, priority: priority)
        requestLock.unlock()

        print("[AudioSessionManager] 🔒 Sync activation from \(serviceId): \(mode) @ priority \(priority.rawValue)")

        // Activate synchronously on current thread (NOT on sessionQueue to avoid deadlock)
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                mode.category,
                mode: mode.mode,
                options: mode.options
            )
            try session.setActive(true)

            // Update state
            currentMode = mode
            isSessionActive = true
            lastError = nil
            consecutiveFailures = 0

            let route = session.currentRoute
            let outputs = route.outputs.map { $0.portName }.joined(separator: ", ")
            print("[AudioSessionManager] ✅ Sync session active: \(mode), route: \(outputs)")

            return true
        } catch {
            handleSessionError(error)
            throw error
        }
    }

    /// Async version of activateSessionSync for use in async contexts
    /// Waits for session to be ready before returning
    func activateSessionAsync(
        mode: AudioSessionMode,
        priority: AudioSessionPriority,
        serviceId: String
    ) async throws {
        guard !isCircuitBreakerOpen else {
            print("[AudioSessionManager] ⚠️ Circuit breaker OPEN - rejecting async request from \(serviceId)")
            throw AudioSessionError.circuitBreakerOpen
        }

        // Register the request
        requestLock.lock()
        activeRequests[serviceId] = (mode: mode, priority: priority)
        requestLock.unlock()

        print("[AudioSessionManager] 🔄 Async activation from \(serviceId): \(mode) @ priority \(priority.rawValue)")

        // Cancel any pending debounced change
        pendingSessionChange?.cancel()

        // Activate the session
        await activateSession(mode: mode)

        // Verify activation succeeded
        guard isSessionActive && currentMode == mode else {
            if let error = lastError {
                throw error
            }
            throw AudioSessionError.activationFailed
        }
    }

    /// Reset the circuit breaker (call after user acknowledges audio issues)
    func resetCircuitBreaker() {
        consecutiveFailures = 0
        isCircuitBreakerOpen = false
        circuitBreakerResetTask?.cancel()
        print("[AudioSessionManager] ✅ Circuit breaker reset")
    }

    // MARK: - Private Methods

    /// Schedule a debounced session update
    private func scheduleSessionUpdate() {
        pendingSessionChange?.cancel()

        pendingSessionChange = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self.updateSession()
        }
    }

    /// Update the audio session based on current requests
    private func updateSession() async {
        // Determine the winning mode based on priority
        requestLock.lock()
        let requests = activeRequests
        requestLock.unlock()

        guard !requests.isEmpty else {
            // No active requests - deactivate if currently active
            if isSessionActive {
                await deactivateSession()
            }
            return
        }

        // Find highest priority request
        let sortedRequests = requests.sorted { $0.value.priority > $1.value.priority }
        guard let winner = sortedRequests.first else { return }

        let targetMode = winner.value.mode

        // Skip if already in the correct mode
        guard targetMode != currentMode || !isSessionActive else {
            print("[AudioSessionManager] ℹ️ Already in mode \(targetMode), skipping")
            return
        }

        print("[AudioSessionManager] 🎯 Activating mode \(targetMode) (winner: \(winner.key))")

        await activateSession(mode: targetMode)
    }

    /// Activate the audio session with the specified mode
    private func activateSession(mode: AudioSessionMode) async {
        // Run on session queue to serialize all audio session operations
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let session = AVAudioSession.sharedInstance()

                do {
                    // Configure category
                    try session.setCategory(
                        mode.category,
                        mode: mode.mode,
                        options: mode.options
                    )

                    // Activate session
                    try session.setActive(true)

                    // Success - update state on main thread
                    // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
                    // to avoid "Publishing changes from within view updates" warnings
                    let currentRoute = session.currentRoute
                    DispatchQueue.main.async {
                        self.currentMode = mode
                        self.isSessionActive = true
                        self.lastError = nil
                        self.consecutiveFailures = 0

                        let outputs = currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
                        print("[AudioSessionManager] ✅ Session active: \(mode), route: \(outputs)")
                    }

                    continuation.resume()

                } catch {
                    // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
                    DispatchQueue.main.async {
                        self.handleSessionError(error)
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// Deactivate the audio session
    private func deactivateSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                do {
                    try AVAudioSession.sharedInstance().setActive(
                        false,
                        options: .notifyOthersOnDeactivation
                    )

                    // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
                    // to avoid "Publishing changes from within view updates" warnings
                    DispatchQueue.main.async {
                        self?.currentMode = .inactive
                        self?.isSessionActive = false
                        print("[AudioSessionManager] ✅ Session deactivated")
                    }
                } catch {
                    // Deactivation failure is usually not critical
                    print("[AudioSessionManager] ⚠️ Deactivation warning: \(error)")
                }

                continuation.resume()
            }
        }
    }

    /// Handle session configuration errors with circuit breaker
    private func handleSessionError(_ error: Error) {
        lastError = error
        consecutiveFailures += 1

        print("[AudioSessionManager] ❌ Session error (\(consecutiveFailures)/\(maxConsecutiveFailures)): \(error)")

        if consecutiveFailures >= maxConsecutiveFailures {
            isCircuitBreakerOpen = true
            print("[AudioSessionManager] 🔴 CIRCUIT BREAKER OPEN - audio session failing repeatedly")

            // Auto-reset after 5 seconds
            circuitBreakerResetTask?.cancel()
            circuitBreakerResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }

                print("[AudioSessionManager] 🔄 Auto-resetting circuit breaker")
                self.resetCircuitBreaker()
            }

            // Post notification for UI to show error
            NotificationCenter.default.post(
                name: .audioSessionCircuitBreakerTripped,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }

    // MARK: - Interruption Handling

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
            // to avoid "Publishing changes from within view updates" warnings
            DispatchQueue.main.async {
                self?.handleInterruption(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
            // to avoid "Publishing changes from within view updates" warnings
            DispatchQueue.main.async {
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioSessionManager] ⏸️ Interruption began (phone call, etc.)")
            isSessionActive = false

            // Notify all services of interruption
            NotificationCenter.default.post(name: .audioSessionInterrupted, object: nil)

        case .ended:
            print("[AudioSessionManager] ▶️ Interruption ended")

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Re-evaluate and activate appropriate session
                    scheduleSessionUpdate()
                    NotificationCenter.default.post(name: .audioSessionResumed, object: nil)
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

        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map { $0.portName }.joined(separator: ", ")

        switch reason {
        case .oldDeviceUnavailable:
            print("[AudioSessionManager] 🔌 Device disconnected, route: \(outputs)")
            NotificationCenter.default.post(name: .audioRouteDeviceDisconnected, object: nil)

        case .newDeviceAvailable:
            print("[AudioSessionManager] 🎧 New device connected, route: \(outputs)")
            NotificationCenter.default.post(name: .audioRouteDeviceConnected, object: nil)

        default:
            print("[AudioSessionManager] 🔄 Route changed (\(reason.rawValue)), route: \(outputs)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioSessionCircuitBreakerTripped = Notification.Name("audioSessionCircuitBreakerTripped")
    static let audioSessionInterrupted = Notification.Name("audioSessionInterrupted")
    static let audioSessionResumed = Notification.Name("audioSessionResumed")
    static let audioRouteDeviceDisconnected = Notification.Name("audioRouteDeviceDisconnected")
    static let audioRouteDeviceConnected = Notification.Name("audioRouteDeviceConnected")
}

// MARK: - Audio Session Errors

enum AudioSessionError: Error, LocalizedError {
    case circuitBreakerOpen
    case activationFailed
    case modeConflict(requested: AudioSessionMode, current: AudioSessionMode)

    var errorDescription: String? {
        switch self {
        case .circuitBreakerOpen:
            return "Audio session circuit breaker is open due to repeated failures"
        case .activationFailed:
            return "Failed to activate audio session"
        case .modeConflict(let requested, let current):
            return "Audio session mode conflict: requested \(requested), current \(current)"
        }
    }
}
