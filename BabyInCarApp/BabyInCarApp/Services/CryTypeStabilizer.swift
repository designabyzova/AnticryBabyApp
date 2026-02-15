//
//  CryTypeStabilizer.swift
//  BabyInCarApp
//
//  Temporal smoothing for cry type classification
//  Prevents rapid state changes and ensures stable classifications
//

import Foundation
import Combine

// MARK: - Stability Configuration

/// Configuration for cry type stability detection
struct StabilityConfiguration {
    /// Time window for initial detection (seconds)
    var initialDetectionWindow: TimeInterval = 10.0

    /// Time window for detecting changes after initial stability (seconds)
    var changeDetectionWindow: TimeInterval = 15.0

    /// Minimum percentage agreement required for stability (0.0-1.0)
    var minimumAgreement: Double = 0.55

    /// Minimum confidence threshold for counting predictions
    var minimumConfidence: Double = 0.40

    /// Minimum number of predictions needed before declaring stability
    var minimumPredictionCount: Int = 3

    /// Default configuration
    static let `default` = StabilityConfiguration()
}

// MARK: - StabilityEvent

/// Events published by the stabilizer
enum StabilityEvent {
    /// Initial cry type stability reached
    case stabilized(cryType: CryType, confidence: Double)

    /// Cry type has changed after being stable
    case changed(from: CryType, to: CryType, confidence: Double)

    /// Stability lost (predictions too varied)
    case unstable

    /// Possible change detected (for UI preview, not yet confirmed)
    case possibleChange(to: CryType, progress: Double)
}

// MARK: - Prediction Record

/// Record of a single prediction for history tracking
private struct PredictionRecord {
    let cryType: CryType
    let confidence: Double
    let timestamp: Date
}

// MARK: - CryTypeStabilizer

/// Implements temporal smoothing to prevent rapid cry type changes
/// Requires consistent predictions over a time window before accepting a classification
@MainActor
class CryTypeStabilizer: ObservableObject {

    // MARK: - Singleton

    static let shared = CryTypeStabilizer()

    // MARK: - Published State

    /// Current stable cry type (or .unknown if not yet stable)
    @Published private(set) var stableCryType: CryType = .unknown

    /// Average confidence of the stable cry type
    @Published private(set) var stableConfidence: Double = 0.0

    /// Whether a stable cry type has been reached
    @Published private(set) var isStable: Bool = false

    /// Progress toward stability (0.0 - 1.0)
    @Published private(set) var stabilityProgress: Double = 0.0

    /// Dominant cry type in current window (may not be stable yet)
    @Published private(set) var dominantCryType: CryType = .unknown

    /// Dominant cry type confidence
    @Published private(set) var dominantConfidence: Double = 0.0

    // MARK: - Event Publisher

    /// Publisher for stability events
    let eventPublisher = PassthroughSubject<StabilityEvent, Never>()

    // MARK: - Configuration

    /// Current stability configuration
    var configuration = StabilityConfiguration.default

    // MARK: - Private State

    /// History of predictions within the current window
    private var predictionHistory: [PredictionRecord] = []

    /// Time when stability was first reached
    private var stabilityStartTime: Date?

    /// Time when last change detection started
    private var changeDetectionStartTime: Date?

    /// Potential new cry type during change detection
    private var potentialNewType: CryType?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Add a new prediction from CryClassificationService
    /// - Parameters:
    ///   - cryType: The predicted cry type
    ///   - confidence: Confidence level (0.0-1.0)
    func addPrediction(_ cryType: CryType, confidence: Double) {
        let now = Date()

        // Always clean old predictions and re-evaluate (even for low-confidence inputs)
        // This ensures stale predictions age out when audio stops
        cleanOldPredictions(now: now)

        // Only add to history if above confidence threshold
        if confidence >= configuration.minimumConfidence {
            let record = PredictionRecord(cryType: cryType, confidence: confidence, timestamp: now)
            predictionHistory.append(record)
        }

        // Always evaluate — detects instability when predictions age out
        evaluateStability(now: now)
    }

    /// Add prediction from CryClassificationResult
    func addPrediction(from result: CryClassificationResult) {
        addPrediction(result.cryType, confidence: result.confidence)
    }

    /// Reset the stabilizer state
    func reset() {
        predictionHistory.removeAll()
        stableCryType = .unknown
        stableConfidence = 0.0
        isStable = false
        stabilityProgress = 0.0
        dominantCryType = .unknown
        dominantConfidence = 0.0
        stabilityStartTime = nil
        changeDetectionStartTime = nil
        potentialNewType = nil

        print("[CryTypeStabilizer] Reset")
    }

    /// Force a cry type (for manual override)
    func forceType(_ cryType: CryType) {
        stableCryType = cryType
        stableConfidence = 1.0
        isStable = true
        stabilityProgress = 1.0
        dominantCryType = cryType
        dominantConfidence = 1.0
        stabilityStartTime = Date()

        eventPublisher.send(.stabilized(cryType: cryType, confidence: 1.0))
        print("[CryTypeStabilizer] Forced type: \(cryType.displayName)")
    }

    // MARK: - Private Methods

    /// Remove predictions older than the current window
    private func cleanOldPredictions(now: Date) {
        let window = isStable ? configuration.changeDetectionWindow : configuration.initialDetectionWindow
        let cutoff = now.addingTimeInterval(-window)
        predictionHistory.removeAll { $0.timestamp < cutoff }
    }

    /// Evaluate stability based on current prediction history
    private func evaluateStability(now: Date) {
        guard predictionHistory.count >= configuration.minimumPredictionCount else {
            stabilityProgress = Double(predictionHistory.count) / Double(configuration.minimumPredictionCount) * 0.5
            // If we were stable but predictions aged out (e.g., crying stopped), mark unstable
            if isStable {
                handleUnstable()
            }
            return
        }

        // Count predictions by cry type
        var typeCounts: [CryType: (count: Int, totalConfidence: Double)] = [:]
        for record in predictionHistory {
            let existing = typeCounts[record.cryType] ?? (count: 0, totalConfidence: 0)
            typeCounts[record.cryType] = (
                count: existing.count + 1,
                totalConfidence: existing.totalConfidence + record.confidence
            )
        }

        // Find dominant type
        guard let (dominant, stats) = typeCounts.max(by: { $0.value.count < $1.value.count }) else {
            return
        }

        let agreement = Double(stats.count) / Double(predictionHistory.count)
        let avgConfidence = stats.totalConfidence / Double(stats.count)

        // Update dominant type (even if not stable)
        dominantCryType = dominant
        dominantConfidence = avgConfidence

        // Check if we have enough agreement
        if agreement >= configuration.minimumAgreement {
            if !isStable {
                // First time reaching stability
                handleInitialStability(cryType: dominant, confidence: avgConfidence, agreement: agreement)
            } else if dominant != stableCryType {
                // Potential type change
                handlePotentialChange(newType: dominant, confidence: avgConfidence, agreement: agreement, now: now)
            } else {
                // Still stable with same type
                stabilityProgress = 1.0
                changeDetectionStartTime = nil
                potentialNewType = nil
            }
        } else {
            // Agreement too low - not stable
            if isStable {
                // Lost stability
                handleUnstable()
            }

            stabilityProgress = 0.5 + (agreement / configuration.minimumAgreement * 0.5)
        }
    }

    /// Handle first time reaching stability
    private func handleInitialStability(cryType: CryType, confidence: Double, agreement: Double) {
        stableCryType = cryType
        stableConfidence = confidence
        isStable = true
        stabilityProgress = 1.0
        stabilityStartTime = Date()

        print("[CryTypeStabilizer] ✅ STABLE: \(cryType.displayName) @ \(Int(confidence * 100))% (agreement: \(Int(agreement * 100))%)")

        eventPublisher.send(.stabilized(cryType: cryType, confidence: confidence))

        // Post notification for other services
        NotificationCenter.default.post(
            name: .cryTypeStabilized,
            object: nil,
            userInfo: [
                "cryType": cryType,
                "confidence": confidence
            ]
        )
    }

    /// Handle potential cry type change during stable state
    private func handlePotentialChange(newType: CryType, confidence: Double, agreement: Double, now: Date) {
        if potentialNewType != newType {
            // New potential type - start fresh change detection
            changeDetectionStartTime = now
            potentialNewType = newType
            print("[CryTypeStabilizer] 🔄 Potential change detected: \(stableCryType.displayName) → \(newType.displayName)")
        }

        guard let changeStart = changeDetectionStartTime else { return }

        let changeDuration = now.timeIntervalSince(changeStart)
        let changeProgress = min(1.0, changeDuration / configuration.changeDetectionWindow)

        // Publish possible change for UI preview
        eventPublisher.send(.possibleChange(to: newType, progress: changeProgress))

        // Check if change detection window has elapsed
        if changeDuration >= configuration.changeDetectionWindow {
            // Confirm the type change
            let previousType = stableCryType
            stableCryType = newType
            stableConfidence = confidence
            stabilityStartTime = now
            changeDetectionStartTime = nil
            potentialNewType = nil

            print("[CryTypeStabilizer] ✅ TYPE CHANGED: \(previousType.displayName) → \(newType.displayName)")

            eventPublisher.send(.changed(from: previousType, to: newType, confidence: confidence))

            // Post notification
            NotificationCenter.default.post(
                name: .cryTypeChanged,
                object: nil,
                userInfo: [
                    "previousType": previousType,
                    "newType": newType,
                    "confidence": confidence
                ]
            )
        }
    }

    /// Handle loss of stability
    private func handleUnstable() {
        print("[CryTypeStabilizer] ⚠️ Stability lost")

        isStable = false
        stableCryType = .unknown
        stableConfidence = 0.0
        stabilityStartTime = nil
        changeDetectionStartTime = nil
        potentialNewType = nil

        eventPublisher.send(.unstable)
    }

    // MARK: - Debug

    /// Get current state summary for debugging
    func debugSummary() -> String {
        """
        CryTypeStabilizer State:
          Stable: \(isStable)
          Stable Type: \(stableCryType.displayName)
          Stable Confidence: \(Int(stableConfidence * 100))%
          Dominant Type: \(dominantCryType.displayName)
          Progress: \(Int(stabilityProgress * 100))%
          History Count: \(predictionHistory.count)
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when cry type becomes stable after initial detection
    static let cryTypeStabilized = Notification.Name("cryTypeStabilized")

    /// Posted when stable cry type changes to a different type
    static let cryTypeChanged = Notification.Name("cryTypeChanged")
}

// MARK: - Testing Support

#if DEBUG
extension CryTypeStabilizer {
    /// Simulate multiple predictions for testing
    func simulatePredictions(_ predictions: [(CryType, Double)], intervalSeconds: TimeInterval = 2.0) {
        var baseTime = Date()
        for (type, confidence) in predictions {
            let record = PredictionRecord(cryType: type, confidence: confidence, timestamp: baseTime)
            predictionHistory.append(record)
            baseTime = baseTime.addingTimeInterval(intervalSeconds)
        }
        evaluateStability(now: baseTime)
    }

    /// Access prediction history count for testing
    var historyCount: Int {
        predictionHistory.count
    }
}
#endif
