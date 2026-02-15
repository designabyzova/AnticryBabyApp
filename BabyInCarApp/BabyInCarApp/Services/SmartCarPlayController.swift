//
//  SmartCarPlayController.swift
//  BabyInCarApp
//
//  CarPlay controller for baby soothing music playback.
//  Provides simple volume control and track management for CarPlay interface.
//
//  NOTE: Audio capture / environment detection features have been removed.
//  This controller now provides basic CarPlay playback functionality only.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

// MARK: - Smart CarPlay Controller

@MainActor
class SmartCarPlayController: ObservableObject {
    static let shared = SmartCarPlayController()

    // MARK: - Dependencies

    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentVolumeMultiplier: Float = 1.0
    @Published var statusMessage: String = "CarPlay Ready"
    @Published var lastVoiceFeedback: String?

    // MARK: - Configuration

    var enableVoiceFeedback: Bool = true
    var voiceFeedbackVolume: Float = 0.3
    var minVolume: Float = 0.2
    var maxVolume: Float = 1.0

    // MARK: - Private State

    private var speechSynthesizer: AVSpeechSynthesizer?

    // MARK: - Initialization

    private init() {
        setupSpeechSynthesizer()
    }

    private func setupSpeechSynthesizer() {
        speechSynthesizer = AVSpeechSynthesizer()
    }

    // MARK: - CarPlay Control

    func activate() {
        guard !isActive else { return }

        isActive = true
        statusMessage = "CarPlay Active"

        // Update voice mode status and announce CarPlay connection
        VoiceInteractionService.shared.updateVoiceModeStatus()
        speakFeedback("CarPlay connected. Voice commands active.")

        // Ensure the VoiceInteractionCoordinator is initialized and listening
        _ = VoiceInteractionCoordinator.shared
    }

    func deactivate() {
        isActive = false
        currentVolumeMultiplier = 1.0
        statusMessage = "CarPlay Inactive"

        // Update voice mode status after CarPlay disconnects
        VoiceInteractionService.shared.updateVoiceModeStatus()
        speakFeedback("CarPlay mode deactivated")
    }

    func setVolume(_ volume: Float) {
        let clampedVolume = max(minVolume, min(maxVolume, volume))
        currentVolumeMultiplier = clampedVolume
        audioEngine.setVolume(clampedVolume)
    }

    func playNextTrack() {
        audioEngine.next()
    }

    func playPreviousTrack() {
        audioEngine.previous()
    }

    func togglePlayPause() {
        if audioEngine.playbackState.isPlaying {
            audioEngine.pause()
        } else {
            audioEngine.resume()
        }
    }

    // MARK: - Voice Feedback

    private func speakFeedback(_ message: String) {
        guard enableVoiceFeedback else { return }

        lastVoiceFeedback = message

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = voiceFeedbackVolume

        speechSynthesizer?.speak(utterance)
    }

    // MARK: - Analytics

    func getSessionSummary() -> String {
        return "CarPlay session active"
    }
}

// MARK: - CarPlay Template Support

extension SmartCarPlayController {

    /// Get compact status for CarPlay display
    var carPlayStatus: String {
        if !isActive {
            return "CarPlay Off"
        }

        let volumePercent = Int(currentVolumeMultiplier * 100)

        if audioEngine.playbackState.isPlaying {
            return "🎵 Playing • \(volumePercent)%"
        } else {
            return "⏸ Paused • \(volumePercent)%"
        }
    }

    /// Get baby state indicator for CarPlay
    var babyStateIndicator: String {
        return "👶 Playing"
    }

    /// Get current track info for CarPlay
    var currentTrackInfo: String {
        if let track = audioEngine.currentTrack {
            return track.title
        }
        return "No track selected"
    }
}
