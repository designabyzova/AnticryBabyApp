//
//  MockCryDetectionService.swift
//  BabyInCarAppTests
//
//  Mock implementation of CryDetectionService for unit testing
//

import Foundation
@testable import BabyInCarApp

/// Protocol for dependency injection and testability
protocol CryDetectable: AnyObject {
    var isMonitoring: Bool { get }
    var isCryDetected: Bool { get }
    var cryIntensity: Double { get }
    var cryType: CryType { get }
    var confidenceLevel: Double { get }
    var currentAudioLevel: Float { get }

    func startMonitoring() async throws
    func stopMonitoring()
}

/// Mock implementation for testing cry detection logic
@MainActor
class MockCryDetectionService: CryDetectable, ObservableObject {

    // MARK: - Published State (matching real service)
    @Published var isMonitoring: Bool = false
    @Published var isCryDetected: Bool = false
    @Published var cryIntensity: Double = 0
    @Published var cryType: CryType = .unknown
    @Published var confidenceLevel: Double = 0
    @Published var currentAudioLevel: Float = 0

    // MARK: - Test Verification
    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0
    var simulatedError: Error?

    // MARK: - Test Callbacks
    var onCryDetected: ((CryType, Double) -> Void)?
    var onCryEnded: (() -> Void)?

    // MARK: - CryDetectable Protocol

    func startMonitoring() async throws {
        startMonitoringCallCount += 1

        if let error = simulatedError {
            throw error
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
        isMonitoring = false
        isCryDetected = false
        cryIntensity = 0
        confidenceLevel = 0
    }

    // MARK: - Test Helpers

    /// Simulate a cry detection event
    func simulateCryDetection(
        type: CryType = .general,
        confidence: Double = 0.85,
        intensity: Double = 0.7
    ) {
        isCryDetected = true
        cryType = type
        confidenceLevel = confidence
        cryIntensity = intensity
        onCryDetected?(type, confidence)
    }

    /// Simulate cry ending
    func simulateCryEnded() {
        isCryDetected = false
        cryType = .unknown
        confidenceLevel = 0
        cryIntensity = 0
        onCryEnded?()
    }

    /// Simulate audio level changes
    func simulateAudioLevel(_ level: Float) {
        currentAudioLevel = level
    }

    /// Reset all state for fresh test
    func reset() {
        isMonitoring = false
        isCryDetected = false
        cryIntensity = 0
        cryType = .unknown
        confidenceLevel = 0
        currentAudioLevel = 0
        startMonitoringCallCount = 0
        stopMonitoringCallCount = 0
        simulatedError = nil
    }

    // MARK: - Factory Methods for Common Test Scenarios

    /// Create mock in "detected" state
    static func detected(type: CryType = .hunger, confidence: Double = 0.9) -> MockCryDetectionService {
        let mock = MockCryDetectionService()
        mock.isMonitoring = true
        mock.isCryDetected = true
        mock.cryType = type
        mock.confidenceLevel = confidence
        mock.cryIntensity = 0.75
        return mock
    }

    /// Create mock in "monitoring" state (no cry)
    static func monitoring() -> MockCryDetectionService {
        let mock = MockCryDetectionService()
        mock.isMonitoring = true
        mock.isCryDetected = false
        mock.currentAudioLevel = 0.05 // ambient noise
        return mock
    }

    /// Create mock in "idle" state
    static func idle() -> MockCryDetectionService {
        return MockCryDetectionService()
    }
}

// MARK: - Test Audio Features

/// Mock audio features for testing ML models
struct MockAudioFeatures {

    /// Create features that simulate a crying baby
    static func cryingBaby(type: CryType = .general) -> ExtendedAudioFeatures {
        switch type {
        case .hunger:
            return ExtendedAudioFeatures(
                spectralCentroid: 550,
                spectralSpread: 200,
                spectralFlatness: 0.25,
                spectralRolloff: 1800,
                mfcc: [Float](repeating: 0.5, count: 13),
                zeroCrossingRate: 0.15,
                rmsEnergy: 0.4,
                fundamentalFrequency: 450,
                harmonicRatio: 0.7,
                temporalEnvelope: [0.3, 0.5, 0.7, 0.8, 0.6, 0.4],
                onsetStrength: 0.6,
                pitchVariability: 0.2,
                energyEntropy: 0.4,
                deltaEnergy: 0.1
            )
        case .pain:
            return ExtendedAudioFeatures(
                spectralCentroid: 1400,
                spectralSpread: 400,
                spectralFlatness: 0.15,
                spectralRolloff: 3500,
                mfcc: [Float](repeating: 0.7, count: 13),
                zeroCrossingRate: 0.25,
                rmsEnergy: 0.8,
                fundamentalFrequency: 600,
                harmonicRatio: 0.8,
                temporalEnvelope: [0.8, 0.9, 0.95, 0.9, 0.85, 0.8],
                onsetStrength: 0.9,
                pitchVariability: 0.35,
                energyEntropy: 0.3,
                deltaEnergy: 0.3
            )
        case .tired:
            return ExtendedAudioFeatures(
                spectralCentroid: 650,
                spectralSpread: 150,
                spectralFlatness: 0.3,
                spectralRolloff: 1500,
                mfcc: [Float](repeating: 0.35, count: 13),
                zeroCrossingRate: 0.1,
                rmsEnergy: 0.25,
                fundamentalFrequency: 380,
                harmonicRatio: 0.55,
                temporalEnvelope: [0.2, 0.3, 0.25, 0.2, 0.15, 0.1],
                onsetStrength: 0.3,
                pitchVariability: 0.15,
                energyEntropy: 0.5,
                deltaEnergy: -0.05
            )
        default:
            return ExtendedAudioFeatures(
                spectralCentroid: 800,
                spectralSpread: 250,
                spectralFlatness: 0.2,
                spectralRolloff: 2200,
                mfcc: [Float](repeating: 0.5, count: 13),
                zeroCrossingRate: 0.18,
                rmsEnergy: 0.5,
                fundamentalFrequency: 480,
                harmonicRatio: 0.65,
                temporalEnvelope: [0.4, 0.6, 0.7, 0.65, 0.5, 0.4],
                onsetStrength: 0.6,
                pitchVariability: 0.25,
                energyEntropy: 0.4,
                deltaEnergy: 0.1
            )
        }
    }

    /// Create features that simulate ambient noise (not a cry)
    static func ambientNoise() -> ExtendedAudioFeatures {
        return ExtendedAudioFeatures(
            spectralCentroid: 2500,
            spectralSpread: 800,
            spectralFlatness: 0.75, // High flatness = noise-like
            spectralRolloff: 5000,
            mfcc: [Float](repeating: 0.1, count: 13),
            zeroCrossingRate: 0.5,
            rmsEnergy: 0.08,
            fundamentalFrequency: 0, // No clear fundamental
            harmonicRatio: 0.1, // Low harmonicity
            temporalEnvelope: [0.08, 0.07, 0.09, 0.08, 0.07, 0.08],
            onsetStrength: 0.1,
            pitchVariability: 0.8, // High variability = no pitch
            energyEntropy: 0.9, // High entropy = noise
            deltaEnergy: 0.01
        )
    }

    /// Create features that simulate car engine noise
    static func carEngineNoise() -> ExtendedAudioFeatures {
        return ExtendedAudioFeatures(
            spectralCentroid: 150,
            spectralSpread: 100,
            spectralFlatness: 0.4,
            spectralRolloff: 500,
            mfcc: [Float](repeating: 0.2, count: 13),
            zeroCrossingRate: 0.05,
            rmsEnergy: 0.3,
            fundamentalFrequency: 80, // Low engine hum
            harmonicRatio: 0.5,
            temporalEnvelope: [0.3, 0.31, 0.29, 0.3, 0.3, 0.31],
            onsetStrength: 0.05,
            pitchVariability: 0.1,
            energyEntropy: 0.3,
            deltaEnergy: 0.0
        )
    }

    /// Create features that simulate music playback
    static func musicPlayback() -> ExtendedAudioFeatures {
        return ExtendedAudioFeatures(
            spectralCentroid: 1200,
            spectralSpread: 600,
            spectralFlatness: 0.15, // Tonal
            spectralRolloff: 4000,
            mfcc: [Float](repeating: 0.6, count: 13),
            zeroCrossingRate: 0.2,
            rmsEnergy: 0.4,
            fundamentalFrequency: 260, // Musical pitch
            harmonicRatio: 0.85, // Strong harmonics
            temporalEnvelope: [0.3, 0.5, 0.4, 0.6, 0.5, 0.4],
            onsetStrength: 0.5,
            pitchVariability: 0.3,
            energyEntropy: 0.35,
            deltaEnergy: 0.15
        )
    }
}
