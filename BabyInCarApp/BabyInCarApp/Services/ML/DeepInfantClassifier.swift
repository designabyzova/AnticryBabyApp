//
//  DeepInfantClassifier.swift
//  BabyInCarApp
//
//  CoreML wrapper for DeepInfant V2 pre-trained cry classification model
//  Source: https://github.com/skytells-research/DeepInfant
//  License: Apache 2.0
//

import Foundation
import CoreML

/// DeepInfant V2 cry classification result
struct DeepInfantResult: DeepInfantResultProtocol {
    let cryType: CryType
    let confidence: Double
    let allProbabilities: [String: Double]
    let processingTimeMs: Double

    /// Map DeepInfant classes to app's CryType
    static func mapToCryType(_ deepInfantClass: String) -> CryType {
        switch deepInfantClass.lowercased() {
        case "hungry", "hunger":
            return .hunger
        case "tired", "sleepy":
            return .tired
        case "belly_pain", "pain", "colic":
            return .pain
        case "discomfort", "uncomfortable":
            return .discomfort
        case "lonely", "attention", "bored":
            return .attention
        case "burping", "burp":
            return .discomfort  // Map to closest
        case "cold_hot", "temperature":
            return .discomfort  // Map to closest
        case "scared", "fear":
            return .pain  // Map to closest (urgent)
        default:
            return .general
        }
    }
}

/// DeepInfant V2 CoreML model wrapper
/// Achieves ~89% accuracy on cry type classification
class DeepInfantClassifier: DeepInfantClassifierProtocol {

    // MARK: - Model

    private var model: MLModel?
    private let modelName = "DeepInfant_V2"
    private let spectrogramGenerator = MelSpectrogramGenerator()

    /// Whether model is loaded
    var isModelLoaded: Bool {
        model != nil
    }

    // MARK: - DeepInfant Output Classes (9 categories)

    private let classLabels = [
        "belly_pain",
        "burping",
        "cold_hot",
        "discomfort",
        "hungry",
        "lonely",
        "scared",
        "tired",
        "unknown"
    ]

    // MARK: - Initialization

    init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        do {
            // Try compiled model first
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                try loadFromURL(modelURL)
                return
            }

            // Try uncompiled model (Xcode will compile on first run)
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
                // Compile the model
                let compiledURL = try MLModel.compileModel(at: modelURL)
                try loadFromURL(compiledURL)
                print("DeepInfantClassifier: Compiled and loaded \(modelName)")
                return
            }

            print("DeepInfantClassifier: ⚠️ Model file not found (\(modelName)) - using fallback classification")
        } catch {
            print("DeepInfantClassifier: ⚠️ Model load failed - \(error)")
            print("  Will use rule-based cry classification instead")
        }
    }

    private func loadFromURL(_ url: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        model = try MLModel(contentsOf: url, configuration: config)
        print("DeepInfantClassifier: ✅ Loaded \(modelName) successfully")
    }

    // MARK: - Classification

    /// Classify cry from raw audio samples
    /// - Parameters:
    ///   - samples: Audio samples (any sample rate, will be resampled)
    ///   - sampleRate: Current sample rate
    /// - Returns: Classification result or nil if model unavailable
    func classify(samples: [Float], sampleRate: Float) -> DeepInfantResultProtocol? {
        guard let model = model else {
            // Model not loaded - fail silently (this is expected if model file missing)
            return nil
        }

        // CRITICAL: Validate sufficient audio data
        // DeepInfant needs at least 2 seconds of audio at 16kHz = 32000 samples
        let minSamples = Int(sampleRate * 2.0)  // 2 seconds
        guard samples.count >= minSamples else {
            // Not enough audio data yet - fail silently
            return nil
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Generate mel spectrogram
        guard let melSpec = spectrogramGenerator.generateFixed(
            from: samples,
            sampleRate: sampleRate,
            targetFrames: 128  // DeepInfant expects ~128 frames for ~4-7 second audio
        ) else {
            // Failed to generate spectrogram - fail silently
            return nil
        }

        // CRITICAL: Validate mel spectrogram shape before feeding to model
        // Expected shape: [128, 40] or [1, 128, 40, 1] depending on model
        guard validateSpectrogramShape(melSpec) else {
            // Invalid shape - log once and fail silently to prevent spam
            logShapeError(melSpec)
            return nil
        }

        do {
            // Create input provider
            let inputProvider = try createInputProvider(melSpectrogram: melSpec)

            // Run inference with error handling
            let output = try model.prediction(from: inputProvider)

            // Parse output
            let result = parseOutput(output)

            let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            return DeepInfantResult(
                cryType: result.cryType,
                confidence: result.confidence,
                allProbabilities: result.probabilities,
                processingTimeMs: processingTime
            )

        } catch let error as NSError {
            // Log detailed CoreML errors ONCE to prevent spam
            logInferenceError(error)
            return nil
        } catch {
            // Generic error - fail silently
            return nil
        }
    }

    // MARK: - Shape Validation

    /// Track if we've already logged shape errors to prevent spam
    private var hasLoggedShapeError = false

    /// Validate mel spectrogram shape matches model expectations
    private func validateSpectrogramShape(_ melSpec: MLMultiArray) -> Bool {
        // Get model input description
        guard let description = model?.modelDescription,
              let inputDesc = description.inputDescriptionsByName.values.first,
              let multiArrayConstraint = inputDesc.multiArrayConstraint else {
            return true  // Can't validate, allow it through
        }

        let shape = multiArrayConstraint.shape.map { $0.intValue }
        let actualShape = melSpec.shape.map { $0.intValue }

        // Check if shapes match
        return shape == actualShape
    }

    /// Log shape error ONCE to prevent spam
    private func logShapeError(_ melSpec: MLMultiArray) {
        guard !hasLoggedShapeError else { return }
        hasLoggedShapeError = true

        let actualShape = melSpec.shape.map { $0.intValue }
        print("DeepInfantClassifier: ⚠️ Invalid input shape: \(actualShape)")

        if let description = model?.modelDescription,
           let inputDesc = description.inputDescriptionsByName.values.first,
           let constraint = inputDesc.multiArrayConstraint {
            let expectedShape = constraint.shape.map { $0.intValue }
            print("  Expected shape: \(expectedShape)")
            print("  This error will only be logged once to prevent spam")
        }
    }

    /// Track if we've already logged inference errors
    private var hasLoggedInferenceError = false

    /// Log inference error ONCE to prevent spam
    private func logInferenceError(_ error: NSError) {
        guard !hasLoggedInferenceError else { return }
        hasLoggedInferenceError = true

        print("DeepInfantClassifier: Inference failed - \(error)")
        print("  Domain: \(error.domain)")
        print("  Code: \(error.code)")
        if let underlyingError = error.userInfo["NSUnderlyingError"] as? NSError {
            print("  UnderlyingError: \(underlyingError)")
        }
        print("  This error will only be logged once to prevent spam")
    }

    // MARK: - Input/Output Handling

    private func createInputProvider(melSpectrogram: MLMultiArray) throws -> MLFeatureProvider {
        // Get model description to find actual input name
        if let description = model?.modelDescription {
            if let inputName = description.inputDescriptionsByName.keys.first {
                return try MLDictionaryFeatureProvider(dictionary: [inputName: melSpectrogram])
            }
        }

        // Fallback to common input name used by most audio ML models
        return try MLDictionaryFeatureProvider(dictionary: ["input": melSpectrogram])
    }

    private func parseOutput(_ output: MLFeatureProvider) -> (cryType: CryType, confidence: Double, probabilities: [String: Double]) {
        var probabilities: [String: Double] = [:]

        // Try dictionary output (classProbability)
        if let dictValue = output.featureValue(for: "classProbability")?.dictionaryValue {
            for (key, value) in dictValue {
                if let keyString = key as? String, let prob = value as? Double {
                    probabilities[keyString] = prob
                }
            }
        }

        // Try array output
        if probabilities.isEmpty {
            let possibleOutputNames = ["output", "probabilities", "predictions", "classLabel_probs"]
            for outputName in possibleOutputNames {
                if let arrayValue = output.featureValue(for: outputName)?.multiArrayValue {
                    for (i, label) in classLabels.enumerated() where i < arrayValue.count {
                        probabilities[label] = Double(truncating: arrayValue[i])
                    }
                    if !probabilities.isEmpty { break }
                }
            }
        }

        // Try direct class label output
        if let classLabel = output.featureValue(for: "classLabel")?.stringValue {
            let confidence = probabilities[classLabel] ?? 0.8
            return (
                cryType: DeepInfantResult.mapToCryType(classLabel),
                confidence: confidence,
                probabilities: probabilities
            )
        }

        // Find best match from probabilities
        let bestMatch = probabilities.max(by: { $0.value < $1.value })
        let cryType = DeepInfantResult.mapToCryType(bestMatch?.key ?? "unknown")
        let confidence = bestMatch?.value ?? 0

        return (cryType: cryType, confidence: confidence, probabilities: probabilities)
    }

    // MARK: - Integration with existing ExtendedAudioFeatures

    /// Classify using ExtendedAudioFeatures (compatibility method)
    /// Note: This is less accurate than using raw audio, as we need to reconstruct
    func classify(features: ExtendedAudioFeatures) -> CryClassification? {
        // DeepInfant needs raw audio, not features
        // Return nil to signal caller should use rule-based fallback
        return nil
    }
}

// MARK: - Integration Extension

extension CryClassifierMLModel {

    /// Try DeepInfant model first, fall back to rule-based
    /// GRACEFUL DEGRADATION: If ML model fails, returns low-confidence general classification
    func classifyWithDeepInfant(samples: [Float], sampleRate: Float) -> CryClassification {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Try DeepInfant classification
        let deepInfant = DeepInfantClassifier()

        // Only attempt classification if model is loaded
        if deepInfant.isModelLoaded {
            if let result = deepInfant.classify(samples: samples, sampleRate: sampleRate) {
                // Convert to CryClassification format
                var allProbs: [CryType: Double] = [:]
                for (key, value) in result.allProbabilities {
                    let cryType = DeepInfantResult.mapToCryType(key)
                    allProbs[cryType, default: 0] += value
                }

                return CryClassification(
                    type: result.cryType,
                    confidence: result.confidence,
                    allProbabilities: allProbs,
                    processingTimeMs: result.processingTimeMs,
                    usedMLModel: true
                )
            }
        } else {
            print("DeepInfantClassifier: Model not available, using fallback classification")
        }

        // Fall back to feature-based classification
        // Return low-confidence general type - caller should use rule-based classifier
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        return CryClassification(
            type: .general,
            confidence: 0.3,
            allProbabilities: [:],
            processingTimeMs: processingTime,
            usedMLModel: false
        )
    }
}
