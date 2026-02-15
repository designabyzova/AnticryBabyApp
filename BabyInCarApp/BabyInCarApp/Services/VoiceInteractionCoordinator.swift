//
//  VoiceInteractionCoordinator.swift
//  BabyInCarApp
//
//  Wires VoiceInteractionService to cry detection, CarPlay events,
//  and cry stop detection. Subscribes to system events and triggers
//  voice prompts or falls back to touch UI as appropriate.
//

import Foundation
import Combine

// MARK: - Voice-Related Notification Names

extension Notification.Name {
    /// Posted when voice interaction returns .fallbackToUI for a cry type change prompt.
    /// userInfo contains "from" (CryType), "to" (CryType), "confidence" (Double).
    static let showCryTypeChangePrompt = Notification.Name("showCryTypeChangePrompt")

    /// Posted when voice interaction returns .fallbackToUI for a cry stopped prompt.
    static let showCryStoppedPrompt = Notification.Name("showCryStoppedPrompt")
}

// MARK: - VoiceInteractionCoordinator

/// Coordinates voice interactions between VoiceInteractionService and the
/// cry detection pipeline (CryTypeStabilizer, CryStopAutoDetector).
///
/// Responsibilities:
/// - Subscribes to CryTypeStabilizer.eventPublisher for stabilized/changed events
/// - Subscribes to CryStopAutoDetector.eventPublisher for cryingStoppedDetected events
/// - Triggers voice prompts when voice mode is active
/// - Falls back to UI notifications when voice mode is inactive
@MainActor
class VoiceInteractionCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = VoiceInteractionCoordinator()

    // MARK: - Dependencies

    private let voiceService = VoiceInteractionService.shared
    private let cryTypeStabilizer = CryTypeStabilizer.shared
    private let cryStopDetector = CryStopAutoDetector.shared
    private let feedbackService = FeedbackCollectionService.shared
    private let playlistBuilder = SmartPlaylistBuilder.shared

    // MARK: - State

    /// Whether the coordinator is currently handling a voice interaction.
    /// Prevents overlapping prompts.
    @Published private(set) var isHandlingInteraction: Bool = false

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupSubscriptions()
        print("[VoiceInteractionCoordinator] Initialized and listening for events")
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        // Subscribe to CryTypeStabilizer events
        cryTypeStabilizer.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .stabilized(let cryType, let confidence):
                    Task { @MainActor in
                        await self.handleInitialDetection(cryType: cryType, confidence: confidence)
                    }
                case .changed(let from, let to, let confidence):
                    Task { @MainActor in
                        await self.handleCryTypeChange(from: from, to: to, confidence: confidence)
                    }
                case .unstable, .possibleChange:
                    // No voice interaction needed for these events
                    break
                }
            }
            .store(in: &cancellables)

        // Subscribe to CryStopAutoDetector events
        cryStopDetector.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .cryingStoppedDetected:
                    Task { @MainActor in
                        await self.handleCryStoppedDetection()
                    }
                default:
                    // quietPeriodStarted, quietPeriodProgress, cryingResumed,
                    // confirmedHelped, dismissed — handled by UI or CryStopAutoDetector itself
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - T-013: Announce Initial Cry Detection

    /// Announces the initial cry detection when a stable cry type is confirmed.
    /// This is announcement-only (no response expected).
    func handleInitialDetection(cryType: CryType, confidence: Double) async {
        guard voiceService.isVoiceModeActive else { return }
        guard !isHandlingInteraction else { return }

        isHandlingInteraction = true
        defer { isHandlingInteraction = false }

        let announcement = VoicePromptTemplates.initialDetectionAnnouncement(cryType: cryType)
        await voiceService.speak(announcement)

        // If pain cry detected, add extra alert
        if cryType == .pain {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms pause
            await voiceService.speak(VoicePromptTemplates.painAlertAnnouncement())
        }

        print("[VoiceInteractionCoordinator] Announced initial detection: \(cryType.displayName) (confidence: \(Int(confidence * 100))%)")
    }

    // MARK: - T-011: Handle Cry Type Change

    /// Handles a stabilized cry type change by asking the user via voice
    /// whether to switch playlists. Falls back to UI if voice mode is inactive.
    func handleCryTypeChange(from: CryType, to: CryType, confidence: Double) async {
        guard !isHandlingInteraction else { return }

        isHandlingInteraction = true
        defer { isHandlingInteraction = false }

        guard voiceService.isVoiceModeActive else {
            // Fall back to touch UI
            NotificationCenter.default.post(
                name: .showCryTypeChangePrompt,
                object: nil,
                userInfo: [
                    "from": from,
                    "to": to,
                    "confidence": confidence
                ]
            )
            print("[VoiceInteractionCoordinator] Voice mode inactive, posted UI notification for cry type change")
            return
        }

        let prompt = VoicePromptTemplates.cryTypeChangePrompt(newType: to)
        let response = await voiceService.askYesNoQuestion(prompt: prompt)

        switch response {
        case .yes:
            await voiceService.speak(VoicePromptTemplates.confirmSwitchAnnouncement())
            await regeneratePlaylist(from: from, to: to)
            print("[VoiceInteractionCoordinator] User confirmed playlist switch: \(from.displayName) -> \(to.displayName)")

        case .no:
            await voiceService.speak(VoicePromptTemplates.confirmKeepAnnouncement())
            print("[VoiceInteractionCoordinator] User declined playlist switch")

        case .timeout:
            // Already announced by askYesNoQuestion
            print("[VoiceInteractionCoordinator] Timeout on cry type change prompt")

        case .fallbackToUI:
            NotificationCenter.default.post(
                name: .showCryTypeChangePrompt,
                object: nil,
                userInfo: [
                    "from": from,
                    "to": to,
                    "confidence": confidence
                ]
            )
            print("[VoiceInteractionCoordinator] Falling back to UI for cry type change")
        }
    }

    // MARK: - T-012: Handle Cry Stopped Detection

    /// Handles cry stopped detection by asking the user via voice whether
    /// the music helped. Falls back to UI if voice mode is inactive.
    func handleCryStoppedDetection() async {
        guard !isHandlingInteraction else { return }

        isHandlingInteraction = true
        defer { isHandlingInteraction = false }

        guard voiceService.isVoiceModeActive else {
            // Fall back to touch UI
            NotificationCenter.default.post(
                name: .showCryStoppedPrompt,
                object: nil
            )
            print("[VoiceInteractionCoordinator] Voice mode inactive, posted UI notification for cry stopped")
            return
        }

        let prompt = VoicePromptTemplates.cryStoppedPrompt()
        let response = await voiceService.askYesNoQuestion(prompt: prompt)

        switch response {
        case .yes:
            feedbackService.recordAutoDetectedStop(confirmed: true)
            await voiceService.speak(VoicePromptTemplates.musicHelpedConfirmation())
            print("[VoiceInteractionCoordinator] User confirmed music helped")

        case .no:
            feedbackService.recordAutoDetectedStop(confirmed: false)
            print("[VoiceInteractionCoordinator] User said music did not help")

        case .timeout:
            // Already announced by askYesNoQuestion; treat as dismissal
            print("[VoiceInteractionCoordinator] Timeout on cry stopped prompt")

        case .fallbackToUI:
            NotificationCenter.default.post(
                name: .showCryStoppedPrompt,
                object: nil
            )
            print("[VoiceInteractionCoordinator] Falling back to UI for cry stopped prompt")
        }
    }

    // MARK: - Playlist Regeneration

    /// Regenerates the playlist for a new cry type and loads it into the AudioEngine.
    private func regeneratePlaylist(from previousType: CryType, to newType: CryType) async {
        let babyAge = currentBabyAge

        // End current feedback session and start new one
        feedbackService.endSession(outcome: .cryTypeChanged)
        feedbackService.startSession(cryType: newType, babyAge: babyAge)

        let newPlaylist = await playlistBuilder.buildPlaylistForCryTypeChange(
            newCryType: newType,
            previousCryType: previousType,
            babyAge: babyAge
        )

        // Load the new playlist into AudioEngine
        AudioEngine.shared.play(
            playlist: Playlist(
                name: newPlaylist.name,
                tracks: newPlaylist.tracks,
                createdAt: Date()
            )
        )

        print("[VoiceInteractionCoordinator] Regenerated playlist for \(newType.displayName): \(newPlaylist.tracks.count) tracks")
    }

    // MARK: - Helpers

    /// Reads baby age from persisted profile, defaults to 6 months.
    private var currentBabyAge: Int {
        if let babyData = UserDefaults.standard.data(forKey: "currentBaby"),
           let baby = try? JSONDecoder().decode(Baby.self, from: babyData) {
            return baby.ageInMonths
        }
        return 6
    }
}
