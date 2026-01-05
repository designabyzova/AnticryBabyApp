//
//  CryDetectorMLModel.swift
//  BabyInCarApp
//
//  Core ML wrapper for on-device cry detection
//  Uses Neural Engine when available for fast inference
//  Falls back to rule-based detection if model unavailable
//

import Foundation
import CoreML

// MARK: - Cry Detection Result

/// Result from cry detection model
struct CryDetectionResult {
    /// Whether a cry was detected
    let isCryDetected: Bool

    /// Confidence of detection (0-1)
    let confidence: Double

    /// Estimated intensity of cry (0-1)
    let intensity: Double

    /// Processing time in milliseconds
    let processingTimeMs: Double

    /// Whether result came from ML model or rule-based fallback
    let usedMLModel: Bool

    // MARK: - Convenience

    /// Is this a high-confidence detection?
    var isHighConfidence: Bool {
        confidence > 0.8
    }

    /// Is this likely a real cry (not just noise)?
    var isLikelyCry: Bool {
        isCryDetected && confidence > 0.6
    }

    static var noCry: CryDetectionResult {
        CryDetectionResult(
            isCryDetected: false,
            confidence: 0,
            intensity: 0,
            processingTimeMs: 0,
            usedMLModel: false
        )
    }
}

// MARK: - Cry Detector ML Model

/// Core ML wrapper for binary cry detection
/// Detects whether audio contains baby crying
class CryDetectorMLModel {

    // MARK: - Model

    private var model: MLModel?
    private let modelName = "BabyCryDetector"
    private static var didLogModelNotFound = false  // Static to prevent spam across instances

    /// Whether ML model is loaded and ready
    var isModelLoaded: Bool {
        model != nil
    }

    // MARK: - Configuration

    /// Expected input feature vector size
    private let expectedFeatureCount = 50

    /// Confidence threshold for cry detection (lowered for rule-based fallback)
    private let detectionThreshold: Double = 0.35

    // MARK: - Initialization

    init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        // Try to load compiled model from bundle
        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            do {
                let config = MLModelConfiguration()

                // Prefer Neural Engine for best performance
                config.computeUnits = .cpuAndNeuralEngine

                model = try MLModel(contentsOf: modelURL, configuration: config)
                print("CryDetectorMLModel: Loaded \(modelName) successfully")
            } catch {
                print("CryDetectorMLModel: Failed to load model - \(error.localizedDescription)")
                model = nil
            }
        } else {
            if !Self.didLogModelNotFound {
                print("CryDetectorMLModel: Model file not found, using rule-based fallback")
                Self.didLogModelNotFound = true
            }
            model = nil
        }
    }

    // MARK: - Detection

    /// Detect cry from extended audio features
    /// - Parameter features: Extracted audio features
    /// - Returns: Detection result with confidence
    func detect(features: ExtendedAudioFeatures) -> CryDetectionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Try ML model first
        if let model = model {
            do {
                let result = try runMLInference(model: model, features: features)
                let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                return CryDetectionResult(
                    isCryDetected: result.isCry,
                    confidence: result.confidence,
                    intensity: result.intensity,
                    processingTimeMs: processingTime,
                    usedMLModel: true
                )
            } catch {
                print("CryDetectorMLModel: ML inference failed - \(error.localizedDescription)")
            }
        }

        // Fallback to rule-based detection
        let result = ruleBasedDetection(features: features)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return CryDetectionResult(
            isCryDetected: result.isCry,
            confidence: result.confidence,
            intensity: result.intensity,
            processingTimeMs: processingTime,
            usedMLModel: false
        )
    }

    // MARK: - ML Inference

    private struct MLInferenceResult {
        let isCry: Bool
        let confidence: Double
        let intensity: Double
    }

    private func runMLInference(model: MLModel, features: ExtendedAudioFeatures) throws -> MLInferenceResult {
        // Prepare input array
        let featureVector = features.featureVector

        // Ensure we have the right number of features
        var paddedFeatures = featureVector
        if paddedFeatures.count < expectedFeatureCount {
            paddedFeatures.append(contentsOf: Array(repeating: Float(0), count: expectedFeatureCount - paddedFeatures.count))
        } else if paddedFeatures.count > expectedFeatureCount {
            paddedFeatures = Array(paddedFeatures.prefix(expectedFeatureCount))
        }

        // Create MLMultiArray
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: expectedFeatureCount)], dataType: .float32)

        for (i, value) in paddedFeatures.enumerated() {
            inputArray[i] = NSNumber(value: value)
        }

        // Create feature provider
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["features": inputArray])

        // Run prediction
        let output = try model.prediction(from: inputProvider)

        // Parse output
        // Expected outputs: "cry_probability" (Double), "intensity" (Double)
        let cryProbability: Double
        let intensityValue: Double

        if let prob = output.featureValue(for: "cry_probability")?.doubleValue {
            cryProbability = prob
        } else if let prob = output.featureValue(for: "output")?.doubleValue {
            // Alternative output name
            cryProbability = prob
        } else {
            // Try multiarray output
            if let outputArray = output.featureValue(for: "output")?.multiArrayValue {
                cryProbability = Double(truncating: outputArray[0])
            } else {
                throw MLModelError.outputParseFailed
            }
        }

        if let intensity = output.featureValue(for: "intensity")?.doubleValue {
            intensityValue = intensity
        } else {
            // Estimate intensity from features if model doesn't output it
            intensityValue = features.intensity
        }

        return MLInferenceResult(
            isCry: cryProbability > detectionThreshold,
            confidence: cryProbability,
            intensity: intensityValue
        )
    }

    // MARK: - Rule-Based Fallback

    /// Rule-based cry detection using acoustic characteristics
    /// Used when ML model is not available
    /// IMPORTANT: Thresholds are deliberately lenient for better recall
    private func ruleBasedDetection(features: ExtendedAudioFeatures) -> MLInferenceResult {
        var confidence: Double = 0

        // Baby cry fundamental frequency typically 250-800 Hz (widened range)
        let fundamentalInRange = features.fundamentalFrequency >= 250 && features.fundamentalFrequency <= 800
        if fundamentalInRange {
            confidence += 0.30  // Increased - frequency is strong indicator
        }

        // Cries have harmonics - check harmonic strength (more lenient)
        let harmonicsPresent = features.harmonicsStrength.count >= 1 &&
                               features.harmonicsStrength[0] > 0.05
        if harmonicsPresent {
            confidence += 0.20
        }

        // Cries are tonal (low spectral flatness) - more lenient
        let isTonal = features.spectralFlatness < 0.7
        if isTonal {
            confidence += 0.15
        }

        // Sufficient intensity (lowered threshold significantly)
        let sufficientIntensity = features.intensity > 0.03
        if sufficientIntensity {
            confidence += 0.20  // Increased - volume matters
        }

        // Spectral centroid in expected range (300-3000 Hz) - widened
        let centroidInRange = features.spectralCentroid > 300 && features.spectralCentroid < 3000
        if centroidInRange {
            confidence += 0.10
        }

        // Good harmonic-to-noise ratio (lowered threshold)
        let goodHNR = features.harmonicToNoiseRatio > 0.2
        if goodHNR {
            confidence += 0.10
        }

        // Voice characteristics - any voice-like signal
        if features.jitter < 0.2 || features.shimmer < 0.25 {
            confidence += 0.05
        }

        let isCry = confidence > detectionThreshold

        return MLInferenceResult(
            isCry: isCry,
            confidence: min(confidence, 1.0),
            intensity: features.intensity
        )
    }

    // MARK: - Model Update

    /// Update model from downloaded file
    /// - Parameter url: URL to new model file
    func updateModel(from url: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        let newModel = try MLModel(contentsOf: url, configuration: config)
        model = newModel
        print("CryDetectorMLModel: Model updated successfully")
    }
}

// MARK: - Errors

enum MLModelError: Error, LocalizedError {
    case modelNotLoaded
    case inputPreparationFailed
    case outputParseFailed
    case unexpectedOutputShape

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "ML model is not loaded"
        case .inputPreparationFailed:
            return "Failed to prepare input for ML model"
        case .outputParseFailed:
            return "Failed to parse ML model output"
        case .unexpectedOutputShape:
            return "ML model output has unexpected shape"
        }
    }
}
