//
//  CryClassificationService.swift
//  BabyInCarApp
//
//  Wrapper service for DeepInfant V2 CoreML model inference
//  Handles cry type classification from audio input
//
//  DeepInfant V2 Model Input:
//    - audioSamples: MLMultiArray [15600] Float32 (raw audio at 16kHz, ~975ms)
//    - The model has INTERNAL feature extraction — it expects raw waveform, NOT mel-spectrograms
//
//  Pipeline (Increment 0031):
//    Microphone → AVAudioEngine → CircularAudioBuffer (7s/112K samples)
//    → Extract last 15,600 samples → Normalize → DeepInfant_V2 model → CryType
//
//  Note: MelSpectrogramGenerator exists for future model upgrades that may accept
//  spectrogram input. It is NOT used in the current inference pipeline.
//

import Foundation
import CoreML
import AVFoundation
import Combine
import UIKit

// MARK: - CryClassificationResult

/// Result of a single cry classification inference
struct CryClassificationResult: Equatable {
    let cryType: CryType
    let confidence: Double
    let probabilities: [CryType: Double]
    let timestamp: Date

    /// Whether the result meets minimum confidence threshold
    var isConfident: Bool {
        confidence >= CryClassificationService.minimumConfidenceThreshold
    }
}

// MARK: - CryClassificationError

enum CryClassificationError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case predictionFailed(Error)
    case invalidAudioFormat
    case insufficientAudioSamples
    case audioSessionError(Error)
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "DeepInfant V2 model not loaded"
        case .modelLoadFailed(let error):
            return "Failed to load DeepInfant V2 model: \(error.localizedDescription)"
        case .predictionFailed(let error):
            return "Prediction failed: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format - requires 16kHz mono Float32"
        case .insufficientAudioSamples:
            return "Insufficient audio samples for classification"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        }
    }
}

// MARK: - CryClassificationService

/// Service wrapper for DeepInfant V2 CoreML model
/// Handles model loading, audio capture, and cry type prediction
@MainActor
class CryClassificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = CryClassificationService()

    // MARK: - Constants

    /// Minimum confidence threshold for accepting a prediction
    static let minimumConfidenceThreshold: Double = 0.40

    /// Sample rate required by the model (16kHz)
    static let requiredSampleRate: Double = 16000.0

    /// Number of audio samples required by the model
    static let requiredSampleCount = 15600

    /// Duration of audio needed for one prediction (~975ms)
    static var predictionDuration: TimeInterval {
        Double(requiredSampleCount) / requiredSampleRate
    }

    // MARK: - Published State

    /// Current cry type from latest stable classification
    @Published private(set) var currentCryType: CryType = .unknown

    /// Confidence of current cry type
    @Published private(set) var confidence: Double = 0.0

    /// Whether the service is actively listening
    @Published private(set) var isListening: Bool = false

    /// Whether classification is stable (meets temporal stability requirements)
    @Published private(set) var isStable: Bool = false

    /// Whether the model is loaded and ready
    @Published private(set) var isModelReady: Bool = false

    /// Last classification result
    @Published private(set) var lastResult: CryClassificationResult?

    /// Error state if any
    @Published private(set) var error: CryClassificationError?

    // MARK: - Private Properties

    /// The loaded DeepInfant V2 CoreML model
    private var model: DeepInfant_V2?

    /// Model configuration for Neural Engine optimization
    private let modelConfiguration: MLModelConfiguration = {
        let config = MLModelConfiguration()
        // Use CPU + Neural Engine only — avoids GPU memory overhead (MTLTexture allocations)
        // Neural Engine is optimal for small audio models and leaves GPU free for UI rendering
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }()

    /// Preallocated MLMultiArray for inference (avoids allocation overhead)
    private var reusableInputArray: MLMultiArray?

    /// Thread safety lock for reusable array access
    private let arrayLock = NSLock()

    /// Performance metrics
    private var inferenceTimeHistory: [Double] = []
    private let maxHistorySize = 100

    /// Average inference time in milliseconds
    var averageInferenceTime: Double {
        guard !inferenceTimeHistory.isEmpty else { return 0 }
        return inferenceTimeHistory.reduce(0, +) / Double(inferenceTimeHistory.count)
    }

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    // MEMORY FIX (0030): Don't load model eagerly on init - saves ~5MB when cry detection is off
    // Model loads lazily on first classify() call (~45ms)
    private init() {
        // Model loaded on demand via ensureModelLoaded()
        setupMemoryPressureHandling()
    }

    // MARK: - Memory Pressure Handling

    /// Listen for memory pressure notifications and unload model when critical
    private func setupMemoryPressureHandling() {
        // Listen for centralized memory cleanup requests (from MemoryMonitor/MemoryPressureMonitor)
        NotificationCenter.default.publisher(for: NSNotification.Name("MemoryCleanupRequested"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let level = notification.userInfo?["level"] as? String ?? "unknown"
                self.handleMemoryPressure(level: level)
            }
            .store(in: &cancellables)

        // Listen for iOS system memory warnings directly
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.handleMemoryPressure(level: "emergency")
            }
            .store(in: &cancellables)
    }

    /// Handle memory pressure by reducing memory footprint
    /// - Parameter level: Pressure level ("warning", "critical", "emergency")
    private func handleMemoryPressure(level: String) {
        switch level {
        case "critical":
            // At critical level, clear inference history to save memory
            inferenceTimeHistory.removeAll(keepingCapacity: false)
            print("[CryClassificationService] Memory pressure (critical): cleared inference history")

        case "emergency":
            // At emergency level, unload model if not actively classifying
            // The model will lazy-load again on next classify() call
            if !isListening {
                unloadModel()
                print("[CryClassificationService] Memory pressure (emergency): unloaded model (~5MB freed)")
            } else {
                // If actively listening, at least clear non-essential data
                inferenceTimeHistory.removeAll(keepingCapacity: false)
                print("[CryClassificationService] Memory pressure (emergency): active — cleared history only")
            }

        default:
            // Warning level: just trim history
            if inferenceTimeHistory.count > 20 {
                inferenceTimeHistory = Array(inferenceTimeHistory.suffix(20))
            }
        }
    }

    // MARK: - Model Management

    /// Load the DeepInfant V2 CoreML model
    func loadModel() async {
        // Skip if already loaded
        guard model == nil else {
            isModelReady = true
            return
        }

        do {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Load model asynchronously
            model = try await DeepInfant_V2.load(configuration: modelConfiguration)

            let loadTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("[CryClassificationService] DeepInfant V2 model loaded in \(Int(loadTime))ms")

            // Preallocate reusable input array for better inference performance
            await preallocateInputArray()

            // Warm up model with a dummy prediction for consistent first-inference performance
            await warmUpModel()

            isModelReady = true
            error = nil
        } catch {
            print("Failed to load DeepInfant V2 model: \(error)")
            self.error = .modelLoadFailed(error)
            isModelReady = false
        }
    }

    /// Unload the model to free memory
    func unloadModel() {
        model = nil
        reusableInputArray = nil
        isModelReady = false
        inferenceTimeHistory.removeAll()
    }

    /// Preallocate MLMultiArray to avoid allocation overhead during inference
    private func preallocateInputArray() async {
        do {
            reusableInputArray = try MLMultiArray(
                shape: [NSNumber(value: Self.requiredSampleCount)],
                dataType: .float32
            )
            print("[CryClassificationService] Input array preallocated")
        } catch {
            print("[CryClassificationService] Failed to preallocate input array: \(error)")
        }
    }

    /// Warm up the model with a dummy prediction
    /// First inference is often slower due to JIT compilation on ANE
    private func warmUpModel() async {
        guard let model = model, let warmupArray = reusableInputArray else { return }

        do {
            // Zero out the preallocated array (reuse instead of allocating a new one)
            let ptr = UnsafeMutablePointer<Float>(OpaquePointer(warmupArray.dataPointer))
            memset(ptr, 0, Self.requiredSampleCount * MemoryLayout<Float>.stride)

            let startTime = CFAbsoluteTimeGetCurrent()
            // Wrap in autoreleasepool to prevent ObjC object accumulation
            _ = try autoreleasepool {
                try model.prediction(audioSamples: warmupArray)
            }
            let warmUpTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            print("[CryClassificationService] Model warm-up completed in \(Int(warmUpTime))ms")
        } catch {
            print("[CryClassificationService] Warm-up failed: \(error)")
        }
    }

    /// Record inference time for performance monitoring
    private func recordInferenceTime(_ timeMs: Double) {
        inferenceTimeHistory.append(timeMs)
        if inferenceTimeHistory.count > maxHistorySize {
            inferenceTimeHistory.removeFirst()
        }

        // Log warning if inference is consistently slow
        if inferenceTimeHistory.count >= 10 {
            let recentAverage = inferenceTimeHistory.suffix(10).reduce(0, +) / 10.0
            if recentAverage > 50 {
                print("[CryClassificationService] ⚠️ Average inference time is \(Int(recentAverage))ms (target: <50ms)")
            }
        }
    }

    // MARK: - Prediction API

    /// Classify cry type from raw audio samples
    /// - Parameter audioSamples: Array of 15600 Float audio samples at 16kHz
    /// - Returns: Classification result with cry type and confidence
    func classify(audioSamples: [Float]) async throws -> CryClassificationResult {
        // MEMORY FIX (0030): Lazy model loading - loads on first classify() call
        if model == nil {
            await loadModel()
        }
        guard let model = model else {
            throw CryClassificationError.modelNotLoaded
        }

        guard audioSamples.count == Self.requiredSampleCount else {
            throw CryClassificationError.insufficientAudioSamples
        }

        do {
            // THREAD SAFETY: Lock during array preparation and inference
            // Prevents data races when multiple predictions happen simultaneously
            arrayLock.lock()
            defer { arrayLock.unlock() }

            // Use preallocated array if available (faster), otherwise create new one
            let multiArray: MLMultiArray
            if let reusable = reusableInputArray {
                // Copy samples directly using pointer for maximum speed
                let ptr = UnsafeMutablePointer<Float>(OpaquePointer(reusable.dataPointer))
                audioSamples.withUnsafeBufferPointer { buffer in
                    ptr.assign(from: buffer.baseAddress!, count: Self.requiredSampleCount)
                }
                multiArray = reusable
            } else {
                // Fallback: create new array
                multiArray = try MLMultiArray(shape: [NSNumber(value: Self.requiredSampleCount)], dataType: .float32)
                let ptr = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))
                audioSamples.withUnsafeBufferPointer { buffer in
                    ptr.assign(from: buffer.baseAddress!, count: Self.requiredSampleCount)
                }
            }

            // Run inference (still under lock to prevent array reuse during prediction)
            // CRITICAL: autoreleasepool prevents CoreML's internal ObjC allocations from accumulating
            let startTime = CFAbsoluteTimeGetCurrent()
            let output = try autoreleasepool {
                try model.prediction(audioSamples: multiArray)
            }
            let inferenceTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            // Record performance metrics
            recordInferenceTime(inferenceTime)

            // Log performance warning if over target
            if inferenceTime > 50 {
                print("[CryClassificationService] ⚠️ Inference took \(Int(inferenceTime))ms (target: <50ms)")
            }

            // Parse output
            let result = parseModelOutput(output)

            // Update published state
            await MainActor.run {
                self.lastResult = result
                if result.isConfident {
                    self.currentCryType = result.cryType
                    self.confidence = result.confidence
                }
            }

            return result

        } catch {
            throw CryClassificationError.predictionFailed(error)
        }
    }

    /// Classify cry type from MLMultiArray (for direct use with audio buffers)
    /// - Parameter audioSamples: MLMultiArray of 15600 Float audio samples
    /// - Returns: Classification result with cry type and confidence
    func classify(audioSamples: MLMultiArray) async throws -> CryClassificationResult {
        guard let model = model else {
            throw CryClassificationError.modelNotLoaded
        }

        guard audioSamples.count == Self.requiredSampleCount else {
            throw CryClassificationError.insufficientAudioSamples
        }

        do {
            // CRITICAL: autoreleasepool prevents CoreML's internal ObjC allocations from accumulating
            let startTime = CFAbsoluteTimeGetCurrent()
            let output = try autoreleasepool {
                try model.prediction(audioSamples: audioSamples)
            }
            let inferenceTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            // Record performance metrics
            recordInferenceTime(inferenceTime)

            if inferenceTime > 50 {
                print("[CryClassificationService] ⚠️ Inference took \(Int(inferenceTime))ms (target: <50ms)")
            }

            let result = parseModelOutput(output)

            await MainActor.run {
                self.lastResult = result
                if result.isConfident {
                    self.currentCryType = result.cryType
                    self.confidence = result.confidence
                }
            }

            return result

        } catch {
            throw CryClassificationError.predictionFailed(error)
        }
    }

    /// Get performance statistics
    func getPerformanceStats() -> (average: Double, min: Double, max: Double, count: Int) {
        guard !inferenceTimeHistory.isEmpty else {
            return (0, 0, 0, 0)
        }
        let average = inferenceTimeHistory.reduce(0, +) / Double(inferenceTimeHistory.count)
        let min = inferenceTimeHistory.min() ?? 0
        let max = inferenceTimeHistory.max() ?? 0
        return (average, min, max, inferenceTimeHistory.count)
    }

    // MARK: - State Management

    /// Reset classification state
    func reset() {
        currentCryType = .unknown
        confidence = 0.0
        isStable = false
        lastResult = nil
        error = nil
    }

    /// Update stable classification state
    /// Called by CryTypeStabilizer when stability is reached
    func updateStableClassification(cryType: CryType, confidence: Double) {
        currentCryType = cryType
        self.confidence = confidence
        isStable = true
    }

    // MARK: - Private Methods

    /// Parse model output into classification result
    private func parseModelOutput(_ output: DeepInfant_V2Output) -> CryClassificationResult {
        // Get the predicted cry type string from model
        let targetString = output.target

        // Map to CryType enum
        let cryType = mapToCryType(targetString)

        // Get probability for the predicted class
        let targetProbability = output.targetProbability[targetString] ?? 0.0

        // Convert all probabilities to CryType keys
        var probabilities: [CryType: Double] = [:]
        for (key, value) in output.targetProbability {
            let mappedType = mapToCryType(key)
            probabilities[mappedType] = value
        }

        return CryClassificationResult(
            cryType: cryType,
            confidence: targetProbability,
            probabilities: probabilities,
            timestamp: Date()
        )
    }

    /// Map model output string to CryType enum
    /// DeepInfant V2 outputs 9 classes: belly_pain, burping, cold_hot, discomfort,
    /// hungry, lonely, scared, tired, unknown
    private func mapToCryType(_ modelOutput: String) -> CryType {
        switch modelOutput.lowercased() {
        case "hungry", "hunger":
            return .hunger
        case "tired", "sleepy", "fatigue":
            return .tired
        case "belly_pain", "bellypain":
            return .pain
        case "discomfort", "uncomfortable", "cold_hot":
            return .discomfort
        case "burping", "needs_burping", "needsburping":
            return .discomfort
        case "lonely", "attention", "bored":
            return .attention
        case "scared":
            return .pain
        case "unknown":
            return .unknown
        default:
            return .unknown
        }
    }

    // MARK: - Action Category Bridge

    /// Get the ActionCategory for the current stable classification
    /// Maps the legacy CryType to the 3-category ActionCategory system (hungry/uncomfortable/tired)
    var currentActionCategory: ActionCategory {
        ActionCategory.from(currentCryType)
    }

    /// Convert a CryClassificationResult to a DeepInfantClassificationResult with action category
    /// Returns nil if the model output string doesn't map to a DeepInfantCryType (e.g., scared, lonely)
    func toDeepInfantResult(_ result: CryClassificationResult) -> DeepInfantClassificationResult? {
        return DeepInfantClassificationResult(
            cryTypeString: result.cryType.rawValue,
            confidence: result.confidence,
            probabilityStrings: result.probabilities.reduce(into: [:]) { dict, pair in
                dict[pair.key.rawValue] = pair.value
            }
        )
    }
}

// MARK: - Testing Support

#if DEBUG
extension CryClassificationService {
    /// Create mock classification result for testing
    static func mockResult(
        cryType: CryType,
        confidence: Double = 0.85
    ) -> CryClassificationResult {
        CryClassificationResult(
            cryType: cryType,
            confidence: confidence,
            probabilities: [cryType: confidence],
            timestamp: Date()
        )
    }

    /// Simulate a classification for testing
    func simulateClassification(cryType: CryType, confidence: Double = 0.85) {
        let result = CryClassificationResult(
            cryType: cryType,
            confidence: confidence,
            probabilities: [cryType: confidence],
            timestamp: Date()
        )

        lastResult = result
        if result.isConfident {
            currentCryType = result.cryType
            self.confidence = result.confidence
        }
    }
}
#endif
