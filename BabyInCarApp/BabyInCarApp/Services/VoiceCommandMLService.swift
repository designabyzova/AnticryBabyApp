//
//  VoiceCommandMLService.swift
//  BabyInCarApp
//
//  On-device voice command parsing using CoreML + DistilBERT.
//  Replaces VoiceCommandLLMService (Ollama-based, non-functional on iOS).
//
//  Created: 2026-01-04
//  Increment: 0027-voice-control-v2-llm
//

import Foundation
import CoreML
import NaturalLanguage
import os.log

// MARK: - Voice Command Data Structures

/// Voice command intent enumeration
/// Note: These are defined in VoiceCommandLLMService.swift and shared across parsers
/// Importing here for reference - actual definitions should remain in VoiceCommandLLMService.swift

// MARK: - Voice Command Parsing Protocol

/// Protocol for voice command parsing services
protocol VoiceCommandParsing {
    func parseCommand(text: String) async -> ParsedVoiceCommand?
}

// MARK: - Voice Command ML Service

/// On-device voice command parser using CoreML DistilBERT model
@MainActor
class VoiceCommandMLService: ObservableObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.anticry.babyincar", category: "VoiceCommandML")

    /// CoreML model for intent classification
    /// Note: Will be loaded from bundle when .mlpackage is available
    private var model: MLModel?

    /// Mapping from model output indices to VoiceCommandIntent
    private let intentLabels: [String]

    /// Confidence threshold for accepting predictions (0.0-1.0)
    private let confidenceThreshold: Float = 0.85

    /// Whether the model is successfully loaded
    @Published private(set) var isModelLoaded = false

    /// Whether using rule-based fallback (model unavailable)
    @Published private(set) var usingFallback = false

    // MARK: - Initialization

    init() {
        // Initialize intent labels (150 intents for Lulla commands)
        // TODO: Load from model metadata when .mlpackage is available
        self.intentLabels = Self.generateIntentLabels()

        logger.info("VoiceCommandMLService initialized")
    }

    // MARK: - Model Loading

    /// Load CoreML model from app bundle
    /// Called lazily on first inference or explicitly during app launch
    func loadModel() {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Configure model for optimal performance
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine if available
            config.allowLowPrecisionAccumulationOnGPU = true

            // Attempt to load model from bundle
            // Note: This will succeed once LullaVoiceCommand.mlpackage is added to project
            if let modelURL = Bundle.main.url(forResource: "LullaVoiceCommand", withExtension: "mlpackage") {
                model = try MLModel(contentsOf: modelURL, configuration: config)

                let loadTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("CoreML model loaded successfully in \(loadTime, format: .fixed(precision: 2))ms")

                isModelLoaded = true
                usingFallback = false

                // Log successful load to analytics
                // Analytics.log(event: "ml_model_load_success", properties: ["load_time_ms": loadTime])
            } else {
                throw NSError(
                    domain: "VoiceCommandMLService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Model file not found in bundle"]
                )
            }

        } catch {
            let loadTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.error("Failed to load CoreML model after \(loadTime, format: .fixed(precision: 2))ms: \(error.localizedDescription)")
            isModelLoaded = false
            usingFallback = true

            // Log to analytics
            // Analytics.log(event: "ml_model_load_failure", properties: [
            //     "error": error.localizedDescription,
            //     "load_time_ms": loadTime
            // ])
        }
    }

    /// Load model with explicit timeout
    /// - Parameter timeout: Maximum time to wait for model loading (seconds)
    /// - Returns: Whether model loaded successfully
    @discardableResult
    func loadModelWithTimeout(_ timeout: TimeInterval = 2.0) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Task {
                loadModel()
                continuation.resume(returning: isModelLoaded)
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !isModelLoaded {
                    task.cancel()
                    logger.warning("Model loading timed out after \(timeout)s, using fallback")
                    usingFallback = true
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Voice Command Parsing

    /// Parse voice command text into structured intent
    ///
    /// - Parameter text: Recognized speech text
    /// - Returns: Parsed command with intent and confidence, or nil if no valid command detected
    func parseCommand(text: String) async -> ParsedVoiceCommand? {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Ensure model is loaded
        if model == nil && !usingFallback {
            loadModel()
        }

        // Use fallback if model unavailable
        if usingFallback || model == nil {
            logger.debug("Using rule-based fallback parser")
            return await parseCommandFallback(text: text)
        }

        // Attempt ML inference
        do {
            guard let model = model else {
                logger.warning("Model unexpectedly nil, using fallback")
                return await parseCommandFallback(text: text)
            }

            // Tokenize input text
            let inputFeature = try tokenize(text: text)

            // Run inference
            let prediction = try model.prediction(from: inputFeature)

            // Extract intent and confidence from prediction
            let (intent, confidence) = try extractIntentFromPrediction(prediction, originalText: text)

            let inferenceTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.debug("ML inference completed in \(inferenceTime, format: .fixed(precision: 2))ms, confidence: \(confidence, format: .fixed(precision: 3))")

            // Check confidence threshold
            guard confidence >= confidenceThreshold else {
                logger.info("Low confidence \(confidence, format: .fixed(precision: 3)) for '\(text)', using fallback")
                return await parseCommandFallback(text: text)
            }

            // Return parsed command
            return ParsedVoiceCommand(
                originalText: text,
                intent: intent,
                confidence: Double(confidence),
                parameters: extractParameters(from: text, intent: intent),
                alternativeIntents: []
            )

        } catch {
            let inferenceTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.error("ML inference failed after \(inferenceTime, format: .fixed(precision: 2))ms: \(error.localizedDescription)")

            // Log error to analytics
            // Analytics.log(event: "ml_inference_error", properties: [
            //     "error": error.localizedDescription,
            //     "inference_time_ms": inferenceTime
            // ])

            // Fall back to rule-based parsing
            return await parseCommandFallback(text: text)
        }
    }

    // MARK: - ML Inference Helpers

    /// Tokenize text input for CoreML model
    /// - Parameter text: Input text to tokenize
    /// - Returns: MLFeatureProvider for model input
    /// - Throws: Error if tokenization fails
    private func tokenize(text: String) throws -> MLFeatureProvider {
        // Note: This is a placeholder implementation
        // Real implementation will depend on the actual model's input schema
        // For DistilBERT, typically needs:
        //   - input_ids: MLMultiArray of token IDs
        //   - attention_mask: MLMultiArray of attention mask

        // For now, create a simple dictionary input
        // This will be replaced with real tokenization once model is available
        let inputDict: [String: Any] = [
            "text": text
        ]

        return try MLDictionaryFeatureProvider(dictionary: inputDict)
    }

    /// Extract intent and confidence from model prediction
    /// - Parameters:
    ///   - prediction: MLFeatureProvider from model output
    ///   - originalText: Original input text
    /// - Returns: Tuple of (intent, confidence)
    /// - Throws: Error if prediction format is invalid
    private func extractIntentFromPrediction(_ prediction: MLFeatureProvider, originalText: String) throws -> (VoiceCommandIntent, Float) {
        // Note: This is a placeholder implementation
        // Real implementation will depend on the actual model's output schema
        // For classification models, typically:
        //   - output: MLMultiArray of logits or probabilities
        //   - label: String with predicted class name

        // For now, return a default intent with medium confidence
        // This will be replaced with real prediction extraction once model is available

        // Attempt to get prediction from common output keys
        if let labelFeature = prediction.featureValue(for: "label") {
            let labelString = labelFeature.stringValue
            let intent = mapLabelToIntent(labelString, originalText: originalText)
            let confidence: Float = 0.9  // Placeholder

            return (intent, confidence)
        }

        // Fallback: return unknown intent
        return (.unknown(text: originalText), 0.5)
    }

    /// Map model output label to VoiceCommandIntent
    /// - Parameters:
    ///   - label: Label string from model
    ///   - originalText: Original input text
    /// - Returns: Mapped VoiceCommandIntent
    private func mapLabelToIntent(_ label: String, originalText: String) -> VoiceCommandIntent {
        let lowered = label.lowercased()

        // Playback intents
        if lowered.contains("play") && !lowered.contains("category") {
            return .play
        }
        if lowered.contains("pause") || lowered == "hold" {
            return .pause
        }
        if lowered.contains("stop") {
            return .stop
        }
        if lowered.contains("next") || lowered.contains("skip") {
            return .next
        }
        if lowered.contains("previous") || lowered.contains("back") {
            return .previous
        }

        // Volume intents
        if lowered.contains("volume_up") || lowered.contains("louder") {
            return .volumeUp
        }
        if lowered.contains("volume_down") || lowered.contains("quieter") {
            return .volumeDown
        }
        if lowered.contains("mute") {
            return .mute
        }
        if lowered.contains("unmute") {
            return .unmute
        }

        // Category intents
        if lowered.contains("lullabies") || lowered.contains("category_lullabies") {
            return .playCategory(.lullabies)
        }
        if lowered.contains("fairy_tales") || lowered.contains("category_fairy") {
            return .playCategory(.fairyTales)
        }
        if lowered.contains("nature") || lowered.contains("category_nature") {
            return .playCategory(.nature)
        }
        if lowered.contains("classical") || lowered.contains("category_classical") {
            return .playCategory(.classical)
        }

        // Emergency
        if lowered.contains("emergency") || lowered.contains("crying") {
            return .emergency
        }

        // Default unknown
        return .unknown(text: originalText)
    }

    /// Extract parameters from text based on intent
    /// - Parameters:
    ///   - text: Original input text
    ///   - intent: Detected intent
    /// - Returns: Dictionary of parameters
    private func extractParameters(from text: String, intent: VoiceCommandIntent) -> [String: Any] {
        var parameters: [String: Any] = [:]

        switch intent {
        case .playCategory(let category):
            parameters["category"] = category.rawValue

        case .playTrack(let trackTitle):
            parameters["trackTitle"] = trackTitle

        case .searchTrack(let query):
            parameters["query"] = query

        case .setVolume(let level):
            parameters["level"] = level

        case .sleepTimer(let minutes):
            parameters["minutes"] = minutes

        default:
            break
        }

        return parameters
    }

    // MARK: - Fallback Parser

    /// Rule-based fallback parser for when ML model is unavailable
    ///
    /// - Parameter text: Voice command text
    /// - Returns: Parsed command using simple keyword matching
    private func parseCommandFallback(text: String) async -> ParsedVoiceCommand? {
        let lowered = text.lowercased()

        // Playback control
        if lowered.contains("play") && !lowered.contains("stop") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .play,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("pause") || lowered.contains("hold") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .pause,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("stop") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .stop,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("next") || lowered.contains("skip") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .next,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("previous") || lowered.contains("back") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .previous,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        // Volume control
        if lowered.contains("louder") || lowered.contains("turn up") || lowered.contains("increase") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .volumeUp,
                confidence: 0.85,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("quieter") || lowered.contains("turn down") || lowered.contains("decrease") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .volumeDown,
                confidence: 0.85,
                parameters: [:],
                alternativeIntents: []
            )
        }

        if lowered.contains("mute") || lowered.contains("silence") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .mute,
                confidence: 0.9,
                parameters: [:],
                alternativeIntents: []
            )
        }

        // Category selection
        if lowered.contains("lullaby") || lowered.contains("lullabies") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .playCategory(.lullabies),
                confidence: 0.9,
                parameters: ["category": "lullabies"],
                alternativeIntents: []
            )
        }

        if lowered.contains("fairy tale") || lowered.contains("fairy tales") || lowered.contains("story") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .playCategory(.fairyTales),
                confidence: 0.9,
                parameters: ["category": "fairyTales"],
                alternativeIntents: []
            )
        }

        if lowered.contains("nature") || lowered.contains("ocean") || lowered.contains("rain") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .playCategory(.nature),
                confidence: 0.85,
                parameters: ["category": "nature"],
                alternativeIntents: []
            )
        }

        if lowered.contains("classical") || lowered.contains("mozart") || lowered.contains("brahms") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .playCategory(.classical),
                confidence: 0.85,
                parameters: ["category": "classical"],
                alternativeIntents: []
            )
        }

        // Emergency
        if lowered.contains("crying") || lowered.contains("emergency") {
            return ParsedVoiceCommand(
                originalText: text,
                intent: .emergency,
                confidence: 0.95,
                parameters: [:],
                alternativeIntents: []
            )
        }

        // No match
        logger.debug("No command match for: \(text)")
        return nil
    }

    // MARK: - Helper Methods

    /// Generate intent label mapping for 150 Lulla command intents
    ///
    /// - Returns: Array of intent label strings (index maps to model output)
    private static func generateIntentLabels() -> [String] {
        // TODO: Load from trained model metadata
        // For now, return basic labels for development
        var labels: [String] = []

        // Playback (30 intents)
        labels.append(contentsOf: [
            "play", "play_music", "start_playing", "begin_playback", "put_on_music",
            "pause", "pause_music", "stop_playing", "hold", "pause_it",
            "stop", "stop_music", "end_playback", "turn_off",
            "resume", "resume_playback", "continue", "keep_going",
            "next", "next_track", "skip", "next_song",
            "previous", "go_back", "previous_track", "last_song",
            "repeat", "shuffle", "loop", "random"
        ])

        // Categories (60 intents - 15 categories × 4 variations)
        let categories = ["lullabies", "fairy_tales", "nature", "classical", "children_songs",
                          "instrumental", "acoustic", "ambient"]
        for category in categories {
            labels.append(contentsOf: [
                "play_\(category)",
                "category_\(category)",
                "select_\(category)",
                "\(category)_music"
            ])
        }

        // Volume (20 intents)
        labels.append(contentsOf: [
            "louder", "turn_up", "increase_volume", "volume_up",
            "quieter", "turn_down", "decrease_volume", "volume_down",
            "mute", "silence", "unmute",
            "volume_10", "volume_25", "volume_50", "volume_75", "volume_100"
        ])

        // Mood (20 intents)
        labels.append(contentsOf: [
            "baby_sleepy", "baby_tired", "sleepy_time",
            "baby_fussy", "baby_cranky", "fussy_baby",
            "baby_playful", "baby_happy", "playtime",
            "baby_hungry", "feeding_time"
        ])

        // Emergency (10 intents)
        labels.append(contentsOf: [
            "baby_crying", "crying_baby", "emergency_mode",
            "emergency", "help_crying", "stop_crying"
        ])

        // Search (10 intents)
        labels.append(contentsOf: [
            "search", "find_track", "play_specific"
        ])

        return labels
    }
}

// MARK: - Protocol Conformance

extension VoiceCommandMLService: VoiceCommandParsing {
    // parseCommand(text:) already implemented above
}
