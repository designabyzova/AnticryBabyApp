//
//  AudioSessionManager.swift
//  BabyInCarApp
//
//  Centralized audio session management to prevent conflicts between
//  CryDetectionService, AudioEngine, and SpeechRecognitionService.
//
//  TECHNICAL DEBT FIX: Eliminates audio session conflicts that cause hangs
//

import Foundation
import AVFoundation
import Combine

/// Priority levels for audio session requests
/// Higher priority wins when there's a conflict
enum AudioSessionPriority: Int, Comparable {
    case background = 0      // Normal playback
    case playback = 1        // Active music playback
    case monitoring = 2      // Cry detection monitoring
    case emergency = 3       // Emergency cry response (highest)
    case recording = 4       // Active voice recording (needs immediate response)

    static func < (lhs: AudioSessionPriority, rhs: AudioSessionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Audio session mode requested by different services
enum AudioSessionMode: Equatable {
    case playbackOnly           // AudioEngine normal playback
    case playAndRecord          // CryDetection monitoring while playing
    case recordOnly             // SpeechRecognition active recording
    case emergencyPlayback      // Emergency cry response (exclusive)
    case inactive               // No audio needed

    var category: AVAudioSession.Category {
        switch self {
        case .playbackOnly, .emergencyPlayback:
            return .playback
        case .playAndRecord:
            return .playAndRecord
        case .recordOnly:
            return .record
        case .inactive:
            return .ambient
        }
    }

    var mode: AVAudioSession.Mode {
        switch self {
        case .playbackOnly, .emergencyPlayback:
            return .default
        case .playAndRecord, .recordOnly:
            return .measurement
        case .inactive:
            return .default
        }
    }

    var options: AVAudioSession.CategoryOptions {
        switch self {
        case .playbackOnly, .emergencyPlayback:
            // Exclusive playback - pauses other apps
            return []
        case .playAndRecord:
            // Allow simultaneous play and record with speaker output
            return [.defaultToSpeaker, .mixWithOthers]
        case .recordOnly:
            // Duck other audio while recording
            return [.duckOthers]
        case .inactive:
            return []
        }
    }
}

/// Centralized audio session manager that coordinates all audio session changes
/// Prevents conflicts between CryDetection, AudioEngine, and SpeechRecognition
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
    func releaseSession(serviceId: String) {
        requestLock.lock()
        let removed = activeRequests.removeValue(forKey: serviceId)
        requestLock.unlock()

        if removed != nil {
            print("[AudioSessionManager] 📤 Released request from \(serviceId)")
            scheduleSessionUpdate()
        }
    }

    /// Force deactivate the audio session (emergency use only)
    func forceDeactivate() {
        pendingSessionChange?.cancel()

        sessionQueue.async { [weak self] in
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                Task { @MainActor in
                    self?.isSessionActive = false
                    self?.currentMode = .inactive
                    print("[AudioSessionManager] 🛑 Force deactivated audio session")
                }
            } catch {
                print("[AudioSessionManager] ⚠️ Force deactivate failed: \(error)")
            }
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
                    Task { @MainActor in
                        self.currentMode = mode
                        self.isSessionActive = true
                        self.lastError = nil
                        self.consecutiveFailures = 0

                        let route = session.currentRoute
                        let outputs = route.outputs.map { $0.portName }.joined(separator: ", ")
                        print("[AudioSessionManager] ✅ Session active: \(mode), route: \(outputs)")
                    }

                    continuation.resume()

                } catch {
                    Task { @MainActor in
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

                    Task { @MainActor in
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
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
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
