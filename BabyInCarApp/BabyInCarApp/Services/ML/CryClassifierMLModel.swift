//
//  CryClassifierMLModel.swift
//  BabyInCarApp
//
//  Core ML wrapper for cry type classification
//  Classifies cries into: hunger, tired, pain, attention, discomfort, general
//  Falls back to rule-based classification if model unavailable
//

import Foundation
import CoreML

// MARK: - Cry Classification

/// Result from cry type classification
struct CryClassification: Codable {
    /// Most likely cry type
    let type: CryType

    /// Confidence in the classification (0-1)
    let confidence: Double

    /// Probabilities for all cry types
    let allProbabilities: [CryType: Double]

    /// Processing time in milliseconds
    let processingTimeMs: Double

    /// Whether result came from ML model or rule-based fallback
    let usedMLModel: Bool

    // MARK: - Convenience

    /// Is this a reliable classification?
    var isReliable: Bool {
        confidence > 0.6
    }

    /// Second most likely type (if any)
    var secondBestType: CryType? {
        let sorted = allProbabilities.sorted { $0.value > $1.value }
        return sorted.count > 1 ? sorted[1].key : nil
    }

    /// Second best probability
    var secondBestProbability: Double {
        let sorted = allProbabilities.sorted { $0.value > $1.value }
        return sorted.count > 1 ? sorted[1].value : 0
    }

    /// Is classification ambiguous (close between top 2)?
    var isAmbiguous: Bool {
        guard let second = secondBestProbability as Double? else { return false }
        return (confidence - second) < 0.15
    }

    static var unknown: CryClassification {
        CryClassification(
            type: .unknown,
            confidence: 0,
            allProbabilities: [:],
            processingTimeMs: 0,
            usedMLModel: false
        )
    }
}

// MARK: - Cry Classifier ML Model

/// Core ML wrapper for multi-class cry type classification
class CryClassifierMLModel {

    // MARK: - Model

    private var model: MLModel?
    private let modelName = "BabyCryClassifier"

    /// Whether ML model is loaded and ready
    var isModelLoaded: Bool {
        model != nil
    }

    // MARK: - Configuration

    /// Expected input feature vector size
    private let expectedFeatureCount = 50

    /// Classification labels in order
    private let classLabels: [CryType] = [
        .hunger,
        .tired,
        .pain,
        .attention,
        .discomfort,
        .general
    ]

    // MARK: - Initialization

    init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine

                model = try MLModel(contentsOf: modelURL, configuration: config)
                print("CryClassifierMLModel: Loaded \(modelName) successfully")
            } catch {
                print("CryClassifierMLModel: Failed to load model - \(error.localizedDescription)")
                model = nil
            }
        } else {
            print("CryClassifierMLModel: Model file not found, using rule-based fallback")
            model = nil
        }
    }

    // MARK: - Classification

    /// Classify cry type from extended audio features
    /// - Parameter features: Extracted audio features
    /// - Returns: Classification result with probabilities for all types
    func classify(features: ExtendedAudioFeatures) -> CryClassification {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Try ML model first
        if let model = model {
            do {
                let result = try runMLInference(model: model, features: features)
                let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                return CryClassification(
                    type: result.type,
                    confidence: result.confidence,
                    allProbabilities: result.probabilities,
                    processingTimeMs: processingTime,
                    usedMLModel: true
                )
            } catch {
                print("CryClassifierMLModel: ML inference failed - \(error.localizedDescription)")
            }
        }

        // Fallback to rule-based classification
        let result = ruleBasedClassification(features: features)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return CryClassification(
            type: result.type,
            confidence: result.confidence,
            allProbabilities: result.probabilities,
            processingTimeMs: processingTime,
            usedMLModel: false
        )
    }

    // MARK: - ML Inference

    private struct MLClassificationResult {
        let type: CryType
        let confidence: Double
        let probabilities: [CryType: Double]
    }

    private func runMLInference(model: MLModel, features: ExtendedAudioFeatures) throws -> MLClassificationResult {
        // Prepare input
        let featureVector = features.featureVector

        var paddedFeatures = featureVector
        if paddedFeatures.count < expectedFeatureCount {
            paddedFeatures.append(contentsOf: Array(repeating: Float(0), count: expectedFeatureCount - paddedFeatures.count))
        } else if paddedFeatures.count > expectedFeatureCount {
            paddedFeatures = Array(paddedFeatures.prefix(expectedFeatureCount))
        }

        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: expectedFeatureCount)], dataType: .float32)

        for (i, value) in paddedFeatures.enumerated() {
            inputArray[i] = NSNumber(value: value)
        }

        let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["features": inputArray])

        // Run prediction
        let output = try model.prediction(from: inputProvider)

        // Parse multi-class output
        var probabilities: [CryType: Double] = [:]

        // Try class-specific outputs first
        for (i, cryType) in classLabels.enumerated() {
            if let prob = output.featureValue(for: "class_\(i)")?.doubleValue {
                probabilities[cryType] = prob
            }
        }

        // If no class-specific outputs, try probability array
        if probabilities.isEmpty {
            if let outputArray = output.featureValue(for: "classProbability")?.dictionaryValue {
                for (key, value) in outputArray {
                    if let keyString = key as? String,
                       let cryType = CryType(rawValue: keyString),
                       let prob = value as? Double {
                        probabilities[cryType] = prob
                    }
                }
            } else if let outputArray = output.featureValue(for: "output")?.multiArrayValue {
                // Treat as probability vector
                for i in 0..<min(classLabels.count, outputArray.count) {
                    let prob = Double(truncating: outputArray[i])
                    probabilities[classLabels[i]] = prob
                }
            }
        }

        // Find best match
        let bestMatch = probabilities.max(by: { $0.value < $1.value })

        return MLClassificationResult(
            type: bestMatch?.key ?? .general,
            confidence: bestMatch?.value ?? 0,
            probabilities: probabilities
        )
    }

    // MARK: - Rule-Based Classification

    /// Rule-based cry classification using acoustic features
    /// Implements the same logic as existing CryClassificationModel
    private func ruleBasedClassification(features: ExtendedAudioFeatures) -> MLClassificationResult {
        var scores: [CryType: Double] = [:]

        // Calculate score for each type
        scores[.hunger] = calculateHungerScore(features)
        scores[.tired] = calculateTiredScore(features)
        scores[.pain] = calculatePainScore(features)
        scores[.attention] = calculateAttentionScore(features)
        scores[.discomfort] = calculateDiscomfortScore(features)

        // General gets remaining probability
        let specificTotal = scores.values.reduce(0, +)
        scores[.general] = max(0, 1.0 - specificTotal) * 0.5

        // Normalize to probabilities
        let totalScore = scores.values.reduce(0, +)
        if totalScore > 0 {
            for key in scores.keys {
                scores[key]! /= totalScore
            }
        }

        let bestMatch = scores.max(by: { $0.value < $1.value })

        return MLClassificationResult(
            type: bestMatch?.key ?? .general,
            confidence: bestMatch?.value ?? 0.5,
            probabilities: scores
        )
    }

    // MARK: - Individual Score Calculations

    /// Hunger cry: rhythmic, lower pitch, moderate intensity, gradual buildup
    private func calculateHungerScore(_ f: ExtendedAudioFeatures) -> Double {
        var score: Double = 0

        // Lower fundamental frequency (350-480 Hz)
        if f.fundamentalFrequency >= 350 && f.fundamentalFrequency <= 480 {
            score += 0.3
        }

        // Rhythmic pattern
        if f.rhythmicity > 0.6 {
            score += 0.25
        }

        // Moderate intensity (not extreme)
        if f.intensity > 0.3 && f.intensity < 0.7 {
            score += 0.2
        }

        // Clear harmonics (higher HNR)
        if f.harmonicToNoiseRatio > 0.5 {
            score += 0.15
        }

        // Gradual onset (not sharp)
        if f.onsetSharpness < 0.5 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    /// Tired cry: lower intensity, irregular, lower pitch, whimpering quality
    private func calculateTiredScore(_ f: ExtendedAudioFeatures) -> Double {
        var score: Double = 0

        // Lower intensity
        if f.intensity < 0.5 {
            score += 0.3
        }

        // Lower fundamental frequency
        if f.fundamentalFrequency < 450 {
            score += 0.2
        }

        // Less rhythmic (irregular)
        if f.rhythmicity < 0.5 {
            score += 0.2
        }

        // Lower harmonic content
        if f.harmonicToNoiseRatio < 0.5 {
            score += 0.15
        }

        // Longer pauses (from pattern tracker, but estimate here)
        if f.onsetSharpness < 0.3 {
            score += 0.15
        }

        return min(score, 1.0)
    }

    /// Pain cry: sudden onset, high intensity, higher pitch, sustained
    private func calculatePainScore(_ f: ExtendedAudioFeatures) -> Double {
        var score: Double = 0

        // High intensity
        if f.intensity > 0.7 {
            score += 0.3
        }

        // Higher fundamental frequency (500+ Hz)
        if f.fundamentalFrequency > 500 {
            score += 0.25
        }

        // Sharp/sudden onset
        if f.onsetSharpness > 0.7 {
            score += 0.2
        }

        // Strong harmonics
        if f.harmonicToNoiseRatio > 0.6 {
            score += 0.15
        }

        // High spectral centroid (brighter sound)
        if f.spectralCentroid > 1200 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    /// Attention cry: medium intensity, rhythmic with pauses, variable pitch
    private func calculateAttentionScore(_ f: ExtendedAudioFeatures) -> Double {
        var score: Double = 0

        // Medium intensity
        if f.intensity > 0.4 && f.intensity < 0.7 {
            score += 0.25
        }

        // Some rhythmicity
        if f.rhythmicity > 0.5 {
            score += 0.2
        }

        // Variable pitch
        if f.pitchVariability > 0.3 {
            score += 0.2
        }

        // Medium-range spectral centroid
        if f.spectralCentroid > 800 && f.spectralCentroid < 1200 {
            score += 0.2
        }

        // Medium fundamental frequency
        if f.fundamentalFrequency > 400 && f.fundamentalFrequency < 550 {
            score += 0.15
        }

        return min(score, 1.0)
    }

    /// Discomfort cry: moderate characteristics, variable patterns
    private func calculateDiscomfortScore(_ f: ExtendedAudioFeatures) -> Double {
        var score: Double = 0

        // Moderate intensity
        if f.intensity > 0.3 && f.intensity < 0.8 {
            score += 0.25
        }

        // Base score for "other" category
        score += 0.15

        // Some rhythmicity but not strong
        if f.rhythmicity > 0.3 && f.rhythmicity < 0.7 {
            score += 0.2
        }

        // Mid-range frequency
        if f.fundamentalFrequency > 380 && f.fundamentalFrequency < 520 {
            score += 0.2
        }

        // Moderate HNR
        if f.harmonicToNoiseRatio > 0.3 && f.harmonicToNoiseRatio < 0.7 {
            score += 0.15
        }

        // Some jitter/shimmer (voice instability)
        if f.jitter > 0.02 || f.shimmer > 0.03 {
            score += 0.05
        }

        return min(score, 1.0)
    }

    // MARK: - Model Update

    /// Update model from downloaded file
    func updateModel(from url: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        let newModel = try MLModel(contentsOf: url, configuration: config)
        model = newModel
        print("CryClassifierMLModel: Model updated successfully")
    }
}

// MARK: - Cry Analysis Result

/// Combined result from both detection and classification
struct CryAnalysisResult: Codable {
    let type: CryType
    let confidence: Double
    let intensity: Double
    let features: ExtendedAudioFeatures
    let voiceCharacteristics: VoiceCharacteristics

    /// Whether this is a confirmed cry detection
    var isCryConfirmed: Bool {
        confidence > 0.6 && intensity > 0.1
    }

    /// Urgency level based on cry type and intensity
    var urgency: UrgencyLevel {
        if type == .pain && intensity > 0.7 {
            return .high
        }
        if intensity > 0.8 {
            return .high
        }
        if type == .hunger || type == .tired {
            return .medium
        }
        if intensity > 0.5 {
            return .medium
        }
        return .low
    }

    enum UrgencyLevel: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}
