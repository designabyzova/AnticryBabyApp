//
//  VoiceInteractionService.swift
//  BabyInCarApp
//
//  Core voice interaction service for hands-free car mode.
//  Handles text-to-speech prompts and speech recognition for
//  yes/no voice responses while driving.
//

import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - Voice Response Types

/// Result of a yes/no voice interaction
enum VoiceResponse: Equatable {
    case yes
    case no
    case timeout
    case fallbackToUI
}

/// Categorization of recognized speech
enum ResponseCategory: Equatable {
    case yes
    case no
    case unknown
}

/// Errors that can occur during voice interaction
enum VoiceError: Error, LocalizedError {
    case speechRecognitionDenied
    case networkUnavailable
    case audioSessionFailed
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .speechRecognitionDenied:
            return "Speech recognition permission was denied"
        case .networkUnavailable:
            return "Network unavailable for speech recognition"
        case .audioSessionFailed:
            return "Failed to configure audio session for voice interaction"
        case .recognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        }
    }

    /// User-friendly spoken message for announcing errors
    var spokenMessage: String {
        switch self {
        case .speechRecognitionDenied:
            return "Speech recognition is not available. Please enable it in Settings."
        case .networkUnavailable:
            return "Voice recognition requires a network connection."
        case .audioSessionFailed:
            return "Audio system error. Switching to touch controls."
        case .recognitionFailed:
            return "I couldn't understand that. Please use touch controls."
        }
    }
}

// MARK: - Voice Interaction Service

/// Manages text-to-speech and speech recognition for hands-free voice interaction.
///
/// Used primarily in car/driving mode where the parent cannot touch the screen.
/// Coordinates with AudioEngine for volume ducking and AudioSessionManager for
/// audio session configuration.
@MainActor
final class VoiceInteractionService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = VoiceInteractionService()

    // MARK: - Published State

    /// Whether voice interaction is currently in progress (speaking or listening)
    @Published private(set) var isActive: Bool = false

    /// Whether TTS is currently speaking
    @Published private(set) var isSpeaking: Bool = false

    /// Whether speech recognition is currently listening
    @Published private(set) var isListening: Bool = false

    /// Last error that occurred
    @Published private(set) var lastError: VoiceError?

    // MARK: - Yes/No Word Lists

    private static let yesWords: Set<String> = [
        "yes", "yeah", "yep", "yup", "sure", "okay", "ok", "alright",
        "switch", "change", "do it", "please", "uh huh", "affirmative"
    ]

    private static let noWords: Set<String> = [
        "no", "nope", "nah", "negative", "don't", "keep", "stay",
        "cancel", "stop", "never", "not"
    ]

    // MARK: - Voice Mode Check

    /// Whether voice mode should be active (CarPlay, hands-free setting, or cry listening)
    var isVoiceModeActive: Bool {
        SmartCarPlayController.shared.isActive ||
        handsFreeModeEnabled ||
        CryClassificationService.shared.isListening
    }

    /// Reads the hands-free mode setting from UserDefaults
    private var handsFreeModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "handsFreeModeEnabled")
    }

    /// Explicitly refreshes the `isActive` flag based on the computed `isVoiceModeActive`.
    /// Call from trigger points (CarPlay connect/disconnect, settings changes, etc.)
    func updateVoiceModeStatus() {
        let shouldBeActive = isVoiceModeActive
        if isActive != shouldBeActive && !isSpeaking && !isListening {
            isActive = shouldBeActive
        }
        print("[VoiceInteractionService] Voice mode status updated: \(shouldBeActive)")
    }

    // MARK: - Private Properties

    /// AVSpeechSynthesizer for text-to-speech
    private let speechSynthesizer = AVSpeechSynthesizer()

    /// Speech delegate stored as property to prevent deallocation
    private var speechDelegate: SpeechDelegate?

    /// SFSpeechRecognizer for speech-to-text
    private let speechRecognizer: SFSpeechRecognizer?

    /// AVAudioEngine for capturing microphone input during recognition
    /// NOTE: This is a SEPARATE engine from AudioEngine.shared (the music playback engine)
    private var recognitionAudioEngine: AVAudioEngine?

    /// Current recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Current recognition task
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Volume level before ducking, so we can restore it
    private var preDuckVolume: Float?

    /// Service ID for AudioSessionManager requests
    private let serviceId = "VoiceInteractionService"

    // MARK: - TTS Configuration

    private let voiceRate: Float = 0.45
    private let voiceVolume: Float = 0.8
    private let voicePitch: Float = 1.0

    // MARK: - Initialization

    private override init() {
        // Initialize speech recognizer with device locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
    }

    // MARK: - Text-to-Speech (T-001)

    /// Speak the given text using AVSpeechSynthesizer.
    /// Blocks until speech completes using a continuation pattern.
    ///
    /// - Parameter text: The text to speak aloud
    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        isSpeaking = true
        isActive = true

        defer {
            isSpeaking = false
            if !isListening {
                isActive = false
            }
        }

        // Configure utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voiceRate
        utterance.volume = voiceVolume
        utterance.pitchMultiplier = voicePitch

        // Select voice matching device locale
        if let voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier) {
            utterance.voice = voice
        }

        // Use delegate + continuation to await completion
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = SpeechDelegate {
                continuation.resume()
            }
            self.speechDelegate = delegate
            self.speechSynthesizer.delegate = delegate
            self.speechSynthesizer.speak(utterance)
        }

        speechDelegate = nil
    }

    // MARK: - Audio Ducking (T-002)

    /// Duck the music volume to 20% before a voice prompt.
    /// Stores the previous volume for later restoration.
    private func duckAudio() {
        let engine = AudioEngine.shared
        preDuckVolume = engine.volume
        engine.setVolume(0.2)
    }

    /// Restore the music volume to the level before ducking.
    private func restoreAudio() {
        if let previousVolume = preDuckVolume {
            AudioEngine.shared.setVolume(previousVolume)
            preDuckVolume = nil
        }
    }

    // MARK: - Speech Recognition (T-004)

    /// Listen for a spoken response with a timeout.
    /// Returns the recognized text, or nil if timeout/failure.
    ///
    /// - Parameter timeout: Maximum seconds to wait for a response (default 5)
    /// - Returns: Recognized text string, or nil on timeout/failure
    func listenForResponse(timeout: TimeInterval = 5.0) async -> String? {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            lastError = .networkUnavailable
            return nil
        }

        isListening = true
        isActive = true

        defer {
            stopListening()
            isListening = false
            if !isSpeaking {
                isActive = false
            }
        }

        // Create a new audio engine for microphone capture
        let audioEngine = AVAudioEngine()
        self.recognitionAudioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = false
        }
        // Hint for short confirmation responses
        request.taskHint = .confirmation
        self.recognitionRequest = request

        // Install tap on the input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            lastError = .recognitionFailed(error)
            cleanupRecognition()
            return nil
        }

        // Listen with timeout, checking partial results for early exit
        let result: String? = await withTaskGroup(of: String?.self) { group in
            // Recognition task
            group.addTask { [weak self] in
                await self?.performRecognition(recognizer: recognizer, request: request)
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            // Return first non-nil result, or nil on timeout
            var bestResult: String?
            for await taskResult in group {
                if let text = taskResult {
                    bestResult = text
                    group.cancelAll()
                    break
                }
            }
            return bestResult
        }

        cleanupRecognition()
        return result
    }

    /// Perform speech recognition and return when a definitive result is available.
    /// Checks partial results for early exit on clear yes/no responses.
    private func performRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            var hasResumed = false

            self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString.lowercased()

                    // Check partial results for early exit on definitive yes/no
                    if !result.isFinal {
                        let category = VoiceInteractionService.categorizeResponse(text)
                        if category != .unknown {
                            hasResumed = true
                            continuation.resume(returning: text)
                            return
                        }
                    }

                    // Final result
                    if result.isFinal {
                        hasResumed = true
                        continuation.resume(returning: text)
                    }
                }

                if error != nil && !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Stop listening and clean up recognition resources.
    private func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    /// Clean up the recognition audio engine.
    private func cleanupRecognition() {
        if let engine = recognitionAudioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        recognitionAudioEngine = nil
        stopListening()
    }

    // MARK: - Response Categorization (T-005)

    /// Categorize a recognized speech text as yes, no, or unknown.
    ///
    /// Uses contains-based matching against known word lists.
    /// Case-insensitive.
    ///
    /// - Parameter text: The recognized text to categorize (nil returns .unknown)
    /// - Returns: The response category
    static func categorizeResponse(_ text: String?) -> ResponseCategory {
        guard let text = text?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .unknown
        }

        // Check for yes words (contains matching)
        for word in yesWords {
            if text.contains(word) {
                return .yes
            }
        }

        // Check for no words (contains matching)
        for word in noWords {
            if text.contains(word) {
                return .no
            }
        }

        return .unknown
    }

    // MARK: - Yes/No Question Flow (T-006)

    /// Ask a yes/no question via voice and get a categorized response.
    ///
    /// Flow: check voice mode -> request audio session -> duck audio -> speak prompt ->
    /// listen for response -> categorize -> retry on unknown -> restore audio -> release session
    ///
    /// - Parameters:
    ///   - prompt: The question to speak aloud
    ///   - retryCount: Maximum number of retries on unknown response (default 1)
    /// - Returns: The voice response (.yes, .no, .timeout, or .fallbackToUI)
    func askYesNoQuestion(prompt: String, retryCount: Int = 1) async -> VoiceResponse {
        // Check if voice mode is active; if not, fall back to UI
        guard isVoiceModeActive else {
            return .fallbackToUI
        }

        // Request audio session for voice interaction
        let sessionGranted = AudioSessionManager.shared.requestSession(
            mode: .voiceInteraction,
            priority: .playback,
            serviceId: serviceId
        )
        guard sessionGranted else {
            lastError = .audioSessionFailed
            return .fallbackToUI
        }

        defer {
            restoreAudio()
            AudioSessionManager.shared.releaseSession(serviceId: serviceId)
        }

        // Duck music volume
        duckAudio()

        // Small delay to let ducking take effect
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Speak the prompt
        await speak(prompt)

        // Listen for response
        let recognizedText = await listenForResponse(timeout: 5.0)
        let category = Self.categorizeResponse(recognizedText)

        switch category {
        case .yes:
            return .yes
        case .no:
            return .no
        case .unknown:
            // Retry logic
            if retryCount > 0 {
                await speak("I didn't catch that. Please say yes or no.")
                let retryText = await listenForResponse(timeout: 5.0)
                let retryCategory = Self.categorizeResponse(retryText)

                switch retryCategory {
                case .yes:
                    return .yes
                case .no:
                    return .no
                case .unknown:
                    // After all retries exhausted, treat as timeout
                    await speak("No response detected. Keeping current settings.")
                    return .timeout
                }
            } else {
                await speak("No response detected. Keeping current settings.")
                return .timeout
            }
        }
    }

    // MARK: - Permissions (T-007)

    /// Request speech recognition permission from the user.
    ///
    /// - Returns: true if permission was granted, false otherwise
    func requestSpeechRecognitionPermission() async -> Bool {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        switch currentStatus {
        case .authorized:
            return true

        case .denied, .restricted:
            lastError = .speechRecognitionDenied
            return false

        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    Task { @MainActor in
                        switch status {
                        case .authorized:
                            continuation.resume(returning: true)
                        default:
                            self.lastError = .speechRecognitionDenied
                            continuation.resume(returning: false)
                        }
                    }
                }
            }

        @unknown default:
            lastError = .speechRecognitionDenied
            return false
        }
    }

    // MARK: - Error Handling (T-017)

    /// Handle a voice error by announcing it and falling back appropriately.
    ///
    /// - Parameter error: The voice error to handle
    /// - Returns: .fallbackToUI for fatal errors that require touch interaction
    @discardableResult
    func handleError(_ error: VoiceError) async -> VoiceResponse {
        lastError = error
        print("[VoiceInteractionService] Error: \(error.localizedDescription)")

        switch error {
        case .speechRecognitionDenied:
            // Fatal - cannot use voice, must fall back to UI
            await speak(error.spokenMessage)
            return .fallbackToUI

        case .networkUnavailable:
            // Can still speak but cannot listen
            await speak(error.spokenMessage)
            return .fallbackToUI

        case .audioSessionFailed:
            // Cannot use audio at all
            // Don't try to speak since the session is broken
            return .fallbackToUI

        case .recognitionFailed:
            // Transient - announce and fall back
            await speak(error.spokenMessage)
            return .fallbackToUI
        }
    }
}

// MARK: - Speech Delegate

/// AVSpeechSynthesizer delegate that calls a completion handler when speech finishes.
/// Must be stored as a property on the service to prevent premature deallocation.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {

    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}
