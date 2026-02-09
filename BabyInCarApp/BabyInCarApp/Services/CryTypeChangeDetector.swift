//
//  CryTypeChangeDetector.swift
//  BabyInCarApp
//
//  Monitors cry type during soothing playback to detect changes
//  If cry type changes (e.g., hunger → tired), prompts user to switch playlist
//

import Foundation
import Combine

// MARK: - CryTypeChangeEvent

/// Events published when cry type changes during playback
enum CryTypeChangeEvent {
    /// Possible change detected (preview, not confirmed)
    case possibleChange(from: CryType, to: CryType, progress: Double)

    /// Change confirmed after sustained detection
    case changeConfirmed(from: CryType, to: CryType, confidence: Double)

    /// User accepted the change
    case userAccepted(newType: CryType)

    /// User rejected the change
    case userRejected(stayWith: CryType)

    /// Detection paused (after rejection)
    case paused(until: Date)

    /// Detection resumed
    case resumed
}

// MARK: - CryTypeChangeConfiguration

/// Configuration for cry type change detection
struct CryTypeChangeConfiguration {
    /// Interval between checks during playback (seconds)
    var checkInterval: TimeInterval = 5.0

    /// Window for change detection - how long new type must persist (seconds)
    var changeDetectionWindow: TimeInterval = 30.0

    /// Minimum agreement percentage for change detection
    var minimumAgreement: Double = 0.70

    /// Pause duration after user rejects change (seconds)
    var rejectionPauseDuration: TimeInterval = 300.0 // 5 minutes

    /// Minimum confidence threshold for change prediction
    var minimumConfidence: Double = 0.65

    /// Minimum predictions needed in window
    var minimumPredictions: Int = 5

    /// Default configuration
    static let `default` = CryTypeChangeConfiguration()
}

// MARK: - CryTypeChangeDetector

/// Service that monitors for cry type changes during soothing playback
@MainActor
class CryTypeChangeDetector: ObservableObject {

    // MARK: - Singleton

    static let shared = CryTypeChangeDetector()

    // MARK: - Published State

    /// Whether change detection is active
    @Published private(set) var isMonitoring: Bool = false

    /// Current stable cry type (being soothed)
    @Published private(set) var currentCryType: CryType = .unknown

    /// Potential new cry type (if change detected)
    @Published private(set) var potentialNewType: CryType?

    /// Progress toward change confirmation (0.0 - 1.0)
    @Published private(set) var changeProgress: Double = 0.0

    /// Whether a change prompt should be shown
    @Published private(set) var shouldShowChangePrompt: Bool = false

    /// Whether detection is paused (after rejection)
    @Published private(set) var isPaused: Bool = false

    /// Time until detection resumes (if paused)
    @Published private(set) var pauseEndTime: Date?

    // MARK: - Event Publisher

    /// Publisher for change events
    let eventPublisher = PassthroughSubject<CryTypeChangeEvent, Never>()

    // MARK: - Configuration

    var configuration = CryTypeChangeConfiguration.default

    // MARK: - Private State

    /// Prediction history during monitoring
    private var predictionHistory: [(cryType: CryType, confidence: Double, timestamp: Date)] = []

    /// Time when potential change was first detected
    private var changeDetectionStartTime: Date?

    /// Timer for periodic checks
    private var checkTimer: Timer?

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let audioCaptureService = AudioCaptureService.shared
    private let classificationService = CryClassificationService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Start monitoring for cry type changes during playback
    /// - Parameter initialCryType: The cry type that was initially detected
    func startMonitoring(initialCryType: CryType) {
        guard !isMonitoring else { return }

        currentCryType = initialCryType
        potentialNewType = nil
        changeProgress = 0.0
        shouldShowChangePrompt = false
        isPaused = false
        pauseEndTime = nil
        predictionHistory.removeAll()
        changeDetectionStartTime = nil

        isMonitoring = true
        startCheckTimer()

        print("[CryTypeChangeDetector] 🎧 Started monitoring for changes from: \(initialCryType.displayName)")
    }

    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        stopCheckTimer()
        resetChangeDetection()

        print("[CryTypeChangeDetector] 🛑 Stopped monitoring")
    }

    /// User accepted the cry type change
    func acceptChange() {
        guard let newType = potentialNewType else { return }

        let previousType = currentCryType
        currentCryType = newType
        shouldShowChangePrompt = false
        resetChangeDetection()

        eventPublisher.send(.userAccepted(newType: newType))

        // Post notification for UI
        NotificationCenter.default.post(
            name: .cryTypeChangeAccepted,
            object: nil,
            userInfo: [
                "previousType": previousType,
                "newType": newType
            ]
        )

        print("[CryTypeChangeDetector] ✅ User accepted change: \(previousType.displayName) → \(newType.displayName)")
    }

    /// User rejected the cry type change
    func rejectChange() {
        shouldShowChangePrompt = false

        // Pause detection for configured duration
        let pauseEnd = Date().addingTimeInterval(configuration.rejectionPauseDuration)
        isPaused = true
        pauseEndTime = pauseEnd

        eventPublisher.send(.userRejected(stayWith: currentCryType))
        eventPublisher.send(.paused(until: pauseEnd))

        resetChangeDetection()

        print("[CryTypeChangeDetector] 🚫 User rejected change, pausing for \(Int(configuration.rejectionPauseDuration / 60)) minutes")

        // Schedule resume
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.rejectionPauseDuration) { [weak self] in
            Task { @MainActor in
                self?.resumeFromPause()
            }
        }
    }

    // MARK: - Private Methods

    private func startCheckTimer() {
        stopCheckTimer()

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performCheck()
            }
        }
    }

    private func stopCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func performCheck() async {
        guard isMonitoring && !isPaused else { return }

        // Check if AudioCaptureService is active and has audio
        guard audioCaptureService.state == .capturing,
              audioCaptureService.isAudioDetected else {
            return
        }

        // Get current audio samples
        guard let samples = audioCaptureService.getCurrentSamples() else {
            return
        }

        // Classify
        do {
            let result = try await classificationService.classify(audioSamples: samples)

            // Only process high-confidence predictions
            guard result.confidence >= configuration.minimumConfidence else {
                return
            }

            // Add to history
            addPrediction(cryType: result.cryType, confidence: result.confidence)

            // Evaluate for potential change
            evaluateForChange()

        } catch {
            print("[CryTypeChangeDetector] Classification error: \(error)")
        }
    }

    private func addPrediction(cryType: CryType, confidence: Double) {
        let now = Date()
        predictionHistory.append((cryType, confidence, now))

        // Clean old predictions outside window
        let cutoff = now.addingTimeInterval(-configuration.changeDetectionWindow)
        predictionHistory.removeAll { $0.timestamp < cutoff }
    }

    private func evaluateForChange() {
        guard predictionHistory.count >= configuration.minimumPredictions else {
            return
        }

        // Count predictions by type
        var typeCounts: [CryType: Int] = [:]
        for (cryType, _, _) in predictionHistory {
            typeCounts[cryType, default: 0] += 1
        }

        // Find dominant type
        guard let (dominantType, count) = typeCounts.max(by: { $0.value < $1.value }) else {
            return
        }

        let agreement = Double(count) / Double(predictionHistory.count)

        // Check if dominant type is different from current
        if dominantType != currentCryType && agreement >= configuration.minimumAgreement {
            handlePotentialChange(newType: dominantType, agreement: agreement)
        } else if dominantType == currentCryType {
            // Reset if cry type returned to current
            resetChangeDetection()
        }
    }

    private func handlePotentialChange(newType: CryType, agreement: Double) {
        let now = Date()

        if potentialNewType != newType {
            // New potential type detected
            potentialNewType = newType
            changeDetectionStartTime = now

            print("[CryTypeChangeDetector] 🔄 Potential change: \(currentCryType.displayName) → \(newType.displayName)")
        }

        guard let startTime = changeDetectionStartTime else { return }

        // Calculate progress
        let elapsed = now.timeIntervalSince(startTime)
        let progress = min(1.0, elapsed / configuration.changeDetectionWindow)
        changeProgress = progress

        // Publish possible change event
        eventPublisher.send(.possibleChange(from: currentCryType, to: newType, progress: progress))

        // Check if window elapsed
        if elapsed >= configuration.changeDetectionWindow {
            confirmChange(newType: newType, confidence: agreement)
        }
    }

    private func confirmChange(newType: CryType, confidence: Double) {
        shouldShowChangePrompt = true

        eventPublisher.send(.changeConfirmed(from: currentCryType, to: newType, confidence: confidence))

        // Post notification for UI
        NotificationCenter.default.post(
            name: .cryTypeChangeDetected,
            object: nil,
            userInfo: [
                "currentType": currentCryType,
                "newType": newType,
                "confidence": confidence
            ]
        )

        print("[CryTypeChangeDetector] ✅ CHANGE CONFIRMED: \(currentCryType.displayName) → \(newType.displayName) @ \(Int(confidence * 100))%")
    }

    private func resetChangeDetection() {
        potentialNewType = nil
        changeProgress = 0.0
        changeDetectionStartTime = nil
        predictionHistory.removeAll()
    }

    private func resumeFromPause() {
        guard isPaused else { return }

        isPaused = false
        pauseEndTime = nil

        eventPublisher.send(.resumed)

        print("[CryTypeChangeDetector] ▶️ Resumed monitoring")
    }

    // MARK: - Debug

    func debugSummary() -> String {
        """
        CryTypeChangeDetector State:
          Monitoring: \(isMonitoring)
          Current Type: \(currentCryType.displayName)
          Potential New: \(potentialNewType?.displayName ?? "none")
          Progress: \(Int(changeProgress * 100))%
          Show Prompt: \(shouldShowChangePrompt)
          Paused: \(isPaused)
          History Count: \(predictionHistory.count)
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when cry type change is detected and confirmed
    static let cryTypeChangeDetected = Notification.Name("cryTypeChangeDetected")

    /// Posted when user accepts cry type change
    static let cryTypeChangeAccepted = Notification.Name("cryTypeChangeAccepted")
}

// MARK: - Testing Support

#if DEBUG
extension CryTypeChangeDetector {
    /// Simulate a cry type change for testing
    func simulateChange(to newType: CryType) {
        potentialNewType = newType
        changeProgress = 1.0
        shouldShowChangePrompt = true

        eventPublisher.send(.changeConfirmed(from: currentCryType, to: newType, confidence: 0.85))
    }

    /// Reset for testing
    func resetForTesting() {
        stopMonitoring()
        currentCryType = .unknown
        shouldShowChangePrompt = false
        isPaused = false
    }
}
#endif
