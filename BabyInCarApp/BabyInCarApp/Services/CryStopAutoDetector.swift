//
//  CryStopAutoDetector.swift
//  BabyInCarApp
//
//  Auto-detects when baby stops crying during soothing playback
//  Shows prompt: "Baby seems calmer! Did the music help?"
//

import Foundation
import Combine

// MARK: - CryStopEvent

/// Events published when crying stops during playback
enum CryStopEvent {
    /// Initial detection of quiet period
    case quietPeriodStarted

    /// Progress update during quiet period (0.0 - 1.0)
    case quietPeriodProgress(progress: Double)

    /// Crying stopped for required duration - ready to show prompt
    case cryingStoppedDetected

    /// Crying resumed before confirmation
    case cryingResumed

    /// User confirmed "It Helped!"
    case confirmedHelped

    /// User dismissed prompt
    case dismissed
}

// MARK: - CryStopConfiguration

/// Configuration for cry stop detection
struct CryStopConfiguration {
    /// Duration of quiet period required before showing prompt (seconds)
    var quietPeriodDuration: TimeInterval = 60.0

    /// Threshold below which audio is considered "quiet" (0.0 - 1.0)
    var quietThreshold: Double = 0.15

    /// Minimum active soothing duration before enabling detection (seconds)
    var minimumSoothingDuration: TimeInterval = 30.0

    /// Cooldown after user dismisses prompt before re-detecting (seconds)
    var dismissCooldown: TimeInterval = 120.0

    /// Confidence threshold for cry classification (cry below this = quiet)
    var cryConfidenceThreshold: Double = 0.50

    /// Number of consecutive quiet samples needed
    var consecutiveQuietSamplesRequired: Int = 10

    /// Interval between audio level checks (seconds)
    var checkInterval: TimeInterval = 3.0

    /// Default configuration
    static let `default` = CryStopConfiguration()
}

// MARK: - CryStopAutoDetector

/// Service that monitors audio during playback to detect when crying stops
@MainActor
class CryStopAutoDetector: ObservableObject {

    // MARK: - Singleton

    static let shared = CryStopAutoDetector()

    // MARK: - Published State

    /// Whether detection is currently active
    @Published private(set) var isMonitoring: Bool = false

    /// Whether we're in a quiet period
    @Published private(set) var isInQuietPeriod: Bool = false

    /// Progress toward showing prompt (0.0 - 1.0)
    @Published private(set) var quietPeriodProgress: Double = 0.0

    /// Whether the prompt should be shown
    @Published private(set) var shouldShowPrompt: Bool = false

    /// Current audio level (for UI visualization)
    @Published private(set) var currentAudioLevel: Float = 0.0

    // MARK: - Event Publisher

    /// Publisher for cry stop events
    let eventPublisher = PassthroughSubject<CryStopEvent, Never>()

    // MARK: - Configuration

    /// Current configuration
    var configuration = CryStopConfiguration.default

    // MARK: - Private State

    /// Start time of current soothing session
    private var soothingStartTime: Date?

    /// Start time of current quiet period
    private var quietPeriodStartTime: Date?

    /// Last time prompt was dismissed
    private var lastDismissTime: Date?

    /// Consecutive quiet sample count
    private var consecutiveQuietSamples: Int = 0

    /// Timer for periodic checks
    private var checkTimer: Timer?

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let audioCaptureService = AudioCaptureService.shared
    private let cryClassificationService = CryClassificationService.shared
    private let feedbackCollectionService = FeedbackCollectionService.shared

    // MARK: - Initialization

    private init() {
        setupAudioLevelObserver()
    }

    // MARK: - Public API

    /// Start monitoring for cry stop during playback
    /// - Parameter sessionStartTime: When the soothing session started
    func startMonitoring(sessionStartTime: Date = Date()) {
        guard !isMonitoring else { return }

        soothingStartTime = sessionStartTime
        isMonitoring = true
        consecutiveQuietSamples = 0
        isInQuietPeriod = false
        quietPeriodProgress = 0.0
        shouldShowPrompt = false
        quietPeriodStartTime = nil

        startCheckTimer()

        print("[CryStopAutoDetector] 🎧 Started monitoring for cry stop")
    }

    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        stopCheckTimer()
        resetQuietPeriod()

        print("[CryStopAutoDetector] 🛑 Stopped monitoring")
    }

    /// Handle user confirming "It Helped!"
    func confirmHelped() {
        shouldShowPrompt = false

        // Record to feedback service
        feedbackCollectionService.recordAutoDetectedStop(confirmed: true)

        eventPublisher.send(.confirmedHelped)

        print("[CryStopAutoDetector] ✅ User confirmed: It Helped!")

        // Stop monitoring after confirmation
        stopMonitoring()
    }

    /// Handle user dismissing the prompt
    func dismissPrompt() {
        shouldShowPrompt = false
        lastDismissTime = Date()

        // Don't record as negative - user might just be waiting longer
        feedbackCollectionService.recordAutoDetectedStop(confirmed: false)

        eventPublisher.send(.dismissed)

        print("[CryStopAutoDetector] 🔄 Prompt dismissed, cooldown started")

        // Reset quiet period to allow re-detection after cooldown
        resetQuietPeriod()
    }

    /// Manually report that crying has resumed
    func reportCryingResumed() {
        if isInQuietPeriod || shouldShowPrompt {
            shouldShowPrompt = false
            resetQuietPeriod()

            eventPublisher.send(.cryingResumed)

            print("[CryStopAutoDetector] 😢 Crying resumed detected")
        }
    }

    // MARK: - Private Methods

    private func setupAudioLevelObserver() {
        // Observe audio level changes from AudioCaptureService
        audioCaptureService.$currentLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.currentAudioLevel = level
            }
            .store(in: &cancellables)
    }

    private func startCheckTimer() {
        stopCheckTimer()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAudioStatus()
            }
        }
    }

    private func stopCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func checkAudioStatus() async {
        guard isMonitoring else { return }

        // Check if we've been soothing long enough
        if let startTime = soothingStartTime {
            let soothingDuration = Date().timeIntervalSince(startTime)
            guard soothingDuration >= configuration.minimumSoothingDuration else {
                return
            }
        }

        // Check cooldown after dismiss
        if let dismissTime = lastDismissTime {
            let cooldownElapsed = Date().timeIntervalSince(dismissTime)
            guard cooldownElapsed >= configuration.dismissCooldown else {
                return
            }
        }

        // Check if audio level is below quiet threshold
        let isQuiet = await isAudioLevelQuiet()

        if isQuiet {
            handleQuietSample()
        } else {
            handleLoudSample()
        }
    }

    private func isAudioLevelQuiet() async -> Bool {
        let level = Double(currentAudioLevel)

        // Primary check: Audio level below threshold
        if level < configuration.quietThreshold {
            return true
        }

        // Secondary check: If audio is detected but cry confidence is low
        // (baby might be awake but not crying)
        if audioCaptureService.isAudioDetected {
            // Get classification confidence from recent predictions
            let cryType = cryClassificationService.currentCryType
            let confidence = cryClassificationService.confidence

            // If we can classify but confidence is below threshold, consider quiet
            if cryType != .unknown && confidence < configuration.cryConfidenceThreshold {
                return true
            }
        }

        return false
    }

    private func handleQuietSample() {
        consecutiveQuietSamples += 1

        // Check if we have enough consecutive quiet samples
        if consecutiveQuietSamples >= configuration.consecutiveQuietSamplesRequired {
            if !isInQuietPeriod {
                // Start quiet period
                isInQuietPeriod = true
                quietPeriodStartTime = Date()

                eventPublisher.send(.quietPeriodStarted)

                print("[CryStopAutoDetector] 🤫 Quiet period started")
            }

            // Update progress
            if let startTime = quietPeriodStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(1.0, elapsed / configuration.quietPeriodDuration)
                quietPeriodProgress = progress

                eventPublisher.send(.quietPeriodProgress(progress: progress))

                // Check if we've reached the threshold
                if progress >= 1.0 && !shouldShowPrompt {
                    triggerPrompt()
                }
            }
        }
    }

    private func handleLoudSample() {
        // Reset consecutive quiet samples
        if consecutiveQuietSamples > 0 {
            print("[CryStopAutoDetector] 🔊 Audio detected, resetting quiet count")
        }
        consecutiveQuietSamples = 0

        // If we were in a quiet period but not showing prompt yet, reset
        if isInQuietPeriod && !shouldShowPrompt {
            resetQuietPeriod()
            eventPublisher.send(.cryingResumed)
        }
    }

    private func triggerPrompt() {
        shouldShowPrompt = true

        eventPublisher.send(.cryingStoppedDetected)

        print("[CryStopAutoDetector] 🎉 Quiet period complete - showing prompt!")

        // Post notification for UI
        NotificationCenter.default.post(
            name: .cryStopDetected,
            object: nil
        )
    }

    private func resetQuietPeriod() {
        isInQuietPeriod = false
        quietPeriodProgress = 0.0
        quietPeriodStartTime = nil
        consecutiveQuietSamples = 0
    }

    // MARK: - Debug

    func debugSummary() -> String {
        """
        CryStopAutoDetector State:
          Monitoring: \(isMonitoring)
          In Quiet Period: \(isInQuietPeriod)
          Progress: \(Int(quietPeriodProgress * 100))%
          Show Prompt: \(shouldShowPrompt)
          Audio Level: \(Int(currentAudioLevel * 100))%
          Consecutive Quiet: \(consecutiveQuietSamples)/\(configuration.consecutiveQuietSamplesRequired)
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when cry stop is detected and prompt should be shown
    static let cryStopDetected = Notification.Name("cryStopDetected")
}

// MARK: - Testing Support

#if DEBUG
extension CryStopAutoDetector {
    /// Simulate quiet audio level for testing
    func simulateQuietAudio(duration: TimeInterval = 60) async {
        startMonitoring()

        // Force quiet state
        for _ in 0..<Int(duration / configuration.checkInterval) {
            consecutiveQuietSamples = configuration.consecutiveQuietSamplesRequired
            handleQuietSample()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    /// Force show prompt for testing
    func forceShowPrompt() {
        shouldShowPrompt = true
        eventPublisher.send(.cryingStoppedDetected)
    }

    /// Reset all state for testing
    func resetForTesting() {
        stopMonitoring()
        lastDismissTime = nil
        shouldShowPrompt = false
    }
}
#endif
