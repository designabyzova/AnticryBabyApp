//
//  SiriShortcutsService.swift
//  BabyInCarApp
//
//  Manages Siri Shortcuts for custom voice commands like
//  "calm baby", "cry again", "play lullabies".
//
//  These shortcuts allow users to create custom Siri phrases
//  that trigger specific app actions.
//

import Foundation
import Intents
import CoreSpotlight

/// Service for managing Siri Shortcuts and NSUserActivity donations
@MainActor
class SiriShortcutsService: ObservableObject {
    static let shared = SiriShortcutsService()

    // MARK: - Activity Types

    /// Activity type identifiers for Siri Shortcuts
    enum ActivityType: String {
        case playLullabies = "com.soothbee.playLullabies"
        case playClassical = "com.soothbee.playClassical"
        case playFairyTales = "com.soothbee.playFairyTales"
        case playNature = "com.soothbee.playNature"
        case emergencyMode = "com.soothbee.emergencyMode"
        case calmBaby = "com.soothbee.calmBaby"
        case cryAgain = "com.soothbee.cryAgain"
        case pausePlayback = "com.soothbee.pausePlayback"
        case resumePlayback = "com.soothbee.resumePlayback"

        var title: String {
            switch self {
            case .playLullabies: return "Play Lullabies in Soothbee"
            case .playClassical: return "Play Classical Music in Soothbee"
            case .playFairyTales: return "Play Fairy Tales in Soothbee"
            case .playNature: return "Play Nature Sounds in Soothbee"
            case .emergencyMode: return "Emergency Mode in Soothbee"
            case .calmBaby: return "Calm Baby Now"
            case .cryAgain: return "Baby Crying Again"
            case .pausePlayback: return "Pause Soothbee"
            case .resumePlayback: return "Resume Soothbee"
            }
        }

        var suggestedPhrase: String {
            switch self {
            case .playLullabies: return "Play lullabies"
            case .playClassical: return "Play classical for baby"
            case .playFairyTales: return "Play bedtime stories"
            case .playNature: return "Play nature sounds"
            case .emergencyMode: return "Baby emergency"
            case .calmBaby: return "Calm baby"
            case .cryAgain: return "Cry again"
            case .pausePlayback: return "Pause baby music"
            case .resumePlayback: return "Resume baby music"
            }
        }

        var category: AudioCategory? {
            switch self {
            case .playLullabies: return .lullabies
            case .playClassical: return .classicalMusic
            case .playFairyTales: return .fairyTales
            case .playNature: return .natureSounds
            default: return nil
            }
        }

        var isEmergency: Bool {
            switch self {
            case .emergencyMode, .calmBaby, .cryAgain:
                return true
            default:
                return false
            }
        }
    }

    private init() {}

    // MARK: - Donate Shortcuts

    /// Donate all common shortcuts to Siri for suggestions
    func donateAllShortcuts() {
        print("[SiriShortcuts] Donating all shortcuts to Siri")

        // Category shortcuts
        donateShortcut(.playLullabies)
        donateShortcut(.playClassical)
        donateShortcut(.playFairyTales)
        donateShortcut(.playNature)

        // Emergency shortcuts
        donateShortcut(.emergencyMode)
        donateShortcut(.calmBaby)
        donateShortcut(.cryAgain)

        // Control shortcuts
        donateShortcut(.pausePlayback)
        donateShortcut(.resumePlayback)
    }

    /// Donate a specific shortcut to Siri
    func donateShortcut(_ type: ActivityType) {
        let activity = createActivity(for: type)
        activity.becomeCurrent()

        print("[SiriShortcuts] Donated shortcut: \(type.title)")
    }

    /// Donate a category playback shortcut when user plays that category
    func donatePlaybackShortcut(for category: AudioCategory) {
        let activityType: ActivityType?
        switch category {
        case .lullabies: activityType = .playLullabies
        case .classicalMusic: activityType = .playClassical
        case .fairyTales: activityType = .playFairyTales
        case .natureSounds: activityType = .playNature
        default: activityType = nil
        }

        if let type = activityType {
            donateShortcut(type)
        }
    }

    // MARK: - Create Activity

    /// Create an NSUserActivity for a shortcut type
    private func createActivity(for type: ActivityType) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type.rawValue)

        activity.title = type.title
        activity.suggestedInvocationPhrase = type.suggestedPhrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(type.rawValue)

        // Set user info based on type
        var userInfo: [String: Any] = ["activityType": type.rawValue]

        if let category = type.category {
            userInfo["category"] = category.rawValue
        }

        if type.isEmergency {
            userInfo["isEmergency"] = true
        }

        switch type {
        case .pausePlayback:
            userInfo["action"] = "pause"
        case .resumePlayback:
            userInfo["action"] = "resume"
        default:
            userInfo["action"] = "play"
        }

        activity.userInfo = userInfo

        // Add search attributes for Spotlight
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = type.title
        attributes.contentDescription = "Control Soothbee with Siri"
        activity.contentAttributeSet = attributes

        return activity
    }

    // MARK: - Handle Shortcut Activation

    /// Handle when a Siri Shortcut is activated
    func handleShortcut(activityType: String, userInfo: [AnyHashable: Any]?) {
        print("[SiriShortcuts] Handling shortcut: \(activityType)")

        guard let type = ActivityType(rawValue: activityType) else {
            print("[SiriShortcuts] Unknown activity type: \(activityType)")
            return
        }

        Task { @MainActor in
            switch type {
            case .playLullabies:
                playCategory(.lullabies)
            case .playClassical:
                playCategory(.classicalMusic)
            case .playFairyTales:
                playCategory(.fairyTales)
            case .playNature:
                playCategory(.natureSounds)
            case .emergencyMode, .calmBaby, .cryAgain:
                triggerEmergencyMode()
            case .pausePlayback:
                AudioEngine.shared.pause()
            case .resumePlayback:
                AudioEngine.shared.resume()
            }
        }
    }

    // MARK: - Playback Actions

    /// Play a specific category
    private func playCategory(_ category: AudioCategory) {
        print("[SiriShortcuts] Playing category: \(category.rawValue)")

        let contentLibrary = ContentLibraryService.shared
        let tracks = contentLibrary.getTracks(for: category)

        guard !tracks.isEmpty else {
            print("[SiriShortcuts] No tracks for category: \(category.rawValue)")
            // Fallback to default content - play highest calming score tracks
            playDefaultContent()
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: \(category.rawValue)",
            tracks: Array(tracks.shuffled().prefix(20)),
            createdAt: Date()
        )

        AudioEngine.shared.play(playlist: playlist)
    }

    /// Play default content as fallback
    private func playDefaultContent() {
        let contentLibrary = ContentLibraryService.shared
        let tracks = contentLibrary.allTracks
            .sorted { $0.calmingScore > $1.calmingScore }

        guard !tracks.isEmpty else {
            AudioEngine.shared.play(track: AudioTrack.defaultEmergencyTrack())
            return
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Siri: Soothbee Music",
            tracks: Array(tracks.prefix(20)),
            createdAt: Date()
        )
        AudioEngine.shared.play(playlist: playlist)
    }

    /// Trigger calming playback
    private func triggerEmergencyMode() {
        print("[SiriShortcuts] Triggering calming playback")

        Task { @MainActor in
            let library = ContentLibraryService.shared
            let audioEngine = AudioEngine.shared

            // Play calming classical music
            let tracks = library.getTracks(for: .classicalMusic)
                .sorted { $0.calmingScore > $1.calmingScore }

            if !tracks.isEmpty {
                let playlist = Playlist(
                    name: "Siri: Calming Music",
                    tracks: Array(tracks.prefix(20)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
                print("[SiriShortcuts] Calming playlist started")
            } else {
                let fallbackTrack = AudioTrack.defaultEmergencyTrack()
                audioEngine.play(track: fallbackTrack)
            }
        }
    }

    // MARK: - Delete Shortcuts

    /// Delete all donated shortcuts (useful for logout/reset)
    func deleteAllShortcuts() {
        NSUserActivity.deleteAllSavedUserActivities {
            print("[SiriShortcuts] Deleted all shortcuts")
        }
    }
}
