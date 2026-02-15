//
//  VoicePromptTemplates.swift
//  BabyInCarApp
//
//  Voice prompt text templates for hands-free interaction
//

import Foundation

/// Provides text templates for all voice prompts used in hands-free mode.
/// These templates are spoken via AVSpeechSynthesizer when voice mode is active.
struct VoicePromptTemplates {

    // MARK: - Cry Detection Prompts

    /// Prompt when cry type changes, asking if user wants to switch playlists.
    static func cryTypeChangePrompt(newType: CryType) -> String {
        "The cry pattern has changed. It now sounds like your baby might be \(newType.displayName.lowercased()). Would you like me to switch to a \(newType.displayName.lowercased()) playlist? Say yes or no."
    }

    /// Prompt when the baby has calmed down, asking if the music helped.
    static func cryStoppedPrompt() -> String {
        "Your baby seems calmer now. Did the music help? Say yes or no."
    }

    /// Announcement when a cry is first detected and a playlist is starting.
    static func initialDetectionAnnouncement(cryType: CryType) -> String {
        "I've detected a \(cryType.displayName.lowercased()) cry. Starting soothing playlist."
    }

    /// Urgent announcement when a pain cry is detected.
    static func painAlertAnnouncement() -> String {
        "Your baby seems very distressed. Please check on them when safe."
    }

    // MARK: - Confirmation Announcements

    /// Confirmation that playlist is being switched.
    static func confirmSwitchAnnouncement() -> String {
        "Okay, switching now."
    }

    /// Confirmation that current playlist is being kept.
    static func confirmKeepAnnouncement() -> String {
        "Okay, keeping the current playlist."
    }

    /// Announcement when no voice response was detected.
    static func noResponseAnnouncement() -> String {
        "No response detected. Keeping current settings."
    }

    /// Announcement when speech was not recognized clearly.
    static func didntCatchThat() -> String {
        "I didn't catch that."
    }

    /// Positive confirmation when user says the music helped.
    static func musicHelpedConfirmation() -> String {
        "Great! I'll remember that for next time."
    }
}
