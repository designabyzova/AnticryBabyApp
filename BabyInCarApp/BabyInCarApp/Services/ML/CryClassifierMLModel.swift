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
    private static var didLogModelNotFound = false  // Static to prevent spam across instances

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
            // Model file not bundled - this is EXPECTED (we use DeepInfant_V2 instead)
            // Silently fall back to rule-based classification without logging warning
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

    /// Research-based multi-feature cry classification
    /// Uses CryAcousticProfiles for scientifically-validated thresholds
    private func ruleBasedClassification(features: ExtendedAudioFeatures) -> MLClassificationResult {
        // Use new multi-feature scorer with research-based profiles
        let scorer = CryMultiFeatureScorer()
        let result = scorer.scoreAllTypes(features: features, temporalPattern: nil)

        // If result is unreliable or ambiguous, fall back to simpler heuristics
        if !result.isReliable {
            // Apply strict thresholds to avoid over-classification
            return fallbackClassification(features: features, preliminaryResult: result)
        }

        return MLClassificationResult(
            type: result.bestType,
            confidence: result.confidence,
            probabilities: result.scores
        )
    }

    /// Fallback classification when multi-feature scoring is inconclusive
    /// Uses STRICT thresholds to avoid false positives
    private func fallbackClassification(features: ExtendedAudioFeatures, preliminaryResult: CryScoreResult) -> MLClassificationResult {
        var scores = preliminaryResult.scores

        // PAIN CRY: Must have ALL of these (strict)
        // - High intensity (>0.7)
        // - High F0 (>500 Hz)
        // - Sudden onset (>0.6)
        let isPainLikely = features.intensity > 0.7 &&
                          features.fundamentalFrequency > 500 &&
                          features.onsetSharpness > 0.6
        if !isPainLikely {
            scores[.pain] = min(scores[.pain] ?? 0, 0.2)
        }

        // TIRED CRY: Must have LOW intensity (strict!)
        // This fixes the "always tired" bug
        // Tired cry is QUIET and IRREGULAR - not just "default"
        let isTiredLikely = features.intensity < 0.35 &&  // MUST be quiet
                           features.fundamentalFrequency < 420 &&  // Lower pitch
                           features.harmonicToNoiseRatio < 0.4  // More breathy
        if !isTiredLikely {
            scores[.tired] = min(scores[.tired] ?? 0, 0.15)  // Strongly penalize
        }

        // HUNGER CRY: Must be rhythmic
        // Rhythmicity estimated from pitch stability and harmonic structure
        let isRhythmic = features.pitchVariability < 0.3 &&
                        features.harmonicToNoiseRatio > 0.4
        let isHungerLikely = isRhythmic &&
                            features.fundamentalFrequency >= 350 &&
                            features.fundamentalFrequency <= 480 &&
                            features.intensity > 0.25 && features.intensity < 0.7
        if !isHungerLikely {
            scores[.hunger] = min(scores[.hunger] ?? 0, 0.25)
        }

        // ATTENTION CRY: Variable, pausing pattern
        // Often has higher pitch variability
        let isAttentionLikely = features.pitchVariability > 0.2 &&
                               features.intensity > 0.2 && features.intensity < 0.65

        if !isAttentionLikely {
            scores[.attention] = min(scores[.attention] ?? 0, 0.2)
        }

        // Normalize scores
        let total = scores.values.reduce(0, +)
        if total > 0 {
            for key in scores.keys {
                scores[key]! /= total
            }
        }

        let bestMatch = scores.max(by: { $0.value < $1.value })

        // If no clear winner, return general with low confidence
        if (bestMatch?.value ?? 0) < 0.35 {
            return MLClassificationResult(
                type: .general,
                confidence: 0.4,
                probabilities: scores
            )
        }

        return MLClassificationResult(
            type: bestMatch?.key ?? .general,
            confidence: bestMatch?.value ?? 0.4,
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
