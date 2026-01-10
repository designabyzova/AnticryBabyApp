//
//  LullaShortcuts.swift
//  BabyInCarApp
//
//  iOS 16+ App Shortcuts for voice commands WITHOUT saying "in Lulla"
//  Example: "Hey Siri, calm baby" instead of "Hey Siri, calm baby in Lulla"
//
//  This provides a more natural voice experience for parents in emergency situations.
//

import AppIntents

/// App Shortcuts provider - registers custom phrases with Siri
@available(iOS 16.0, *)
struct LullaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Emergency calming shortcut - highest priority for parents
        AppShortcut(
            intent: CalmBabyIntent(),
            phrases: [
                "Calm baby",
                "Calm my baby",
                "Baby crying",
                "Baby is crying",
                "Soothe baby",
                "Soothe my baby",
                "Help baby",
                "Help my baby",
                "Baby won't stop crying",
                "Calm down baby"
            ],
            shortTitle: "Calm Baby",
            systemImageName: "heart.fill"
        )

        // Play lullabies shortcut
        AppShortcut(
            intent: PlayLullabiesIntent(),
            phrases: [
                "Play lullabies",
                "Play baby lullabies",
                "Play lullaby music",
                "Baby lullabies",
                "Sleep music for baby"
            ],
            shortTitle: "Play Lullabies",
            systemImageName: "moon.stars.fill"
        )

        // Play classical music shortcut
        AppShortcut(
            intent: PlayClassicalIntent(),
            phrases: [
                "Play classical for baby",
                "Play Mozart for baby",
                "Baby classical music",
                "Calm music for baby"
            ],
            shortTitle: "Classical Music",
            systemImageName: "music.note"
        )
    }
}

// MARK: - Calm Baby Intent (Emergency Mode)

/// Triggers emergency calming mode - plays optimized soothing content
@available(iOS 16.0, *)
struct CalmBabyIntent: AppIntent {
    static var title: LocalizedStringResource = "Calm Baby"
    static var description = IntentDescription("Activate emergency calming mode with AI-selected soothing music")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("[AppShortcut] CalmBabyIntent triggered")

        // Get baby age if available, default to 12 months
        let babyAge = 12  // Default age for broad compatibility
        let language = Locale.current.language.languageCode?.identifier ?? "en"

        // Start Spotify-style emergency queue with smart track selection
        await SmartEmergencyQueue.shared.startSpotifyMode(
            cryType: .general,
            babyAge: babyAge,
            language: language
        )

        print("[AppShortcut] Emergency queue started")

        return .result(dialog: "Playing soothing music for your baby")
    }
}

// MARK: - Play Lullabies Intent

/// Plays lullaby category
@available(iOS 16.0, *)
struct PlayLullabiesIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Lullabies"
    static var description = IntentDescription("Play gentle lullaby music for your baby")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("[AppShortcut] PlayLullabiesIntent triggered")

        let tracks = ContentLibraryService.shared.getTracks(for: .lullabies)
        guard !tracks.isEmpty else {
            // Fallback to emergency track
            AudioEngine.shared.play(track: AudioTrack.defaultEmergencyTrack())
            return .result(dialog: "Playing lullaby music")
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Lullabies",
            tracks: Array(tracks.shuffled().prefix(20)),
            createdAt: Date()
        )

        AudioEngine.shared.play(playlist: playlist)
        SiriShortcutsService.shared.donatePlaybackShortcut(for: .lullabies)

        return .result(dialog: "Playing lullabies for your baby")
    }
}

// MARK: - Play Classical Intent

/// Plays classical music category
@available(iOS 16.0, *)
struct PlayClassicalIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Classical Music"
    static var description = IntentDescription("Play classical music for your baby")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("[AppShortcut] PlayClassicalIntent triggered")

        let tracks = ContentLibraryService.shared.getTracks(for: .classicalMusic)
        guard !tracks.isEmpty else {
            // Fallback to emergency track
            AudioEngine.shared.play(track: AudioTrack.defaultEmergencyTrack())
            return .result(dialog: "Playing classical music")
        }

        let playlist = Playlist(
            id: UUID(),
            name: "Classical Music",
            tracks: Array(tracks.shuffled().prefix(20)),
            createdAt: Date()
        )

        AudioEngine.shared.play(playlist: playlist)
        SiriShortcutsService.shared.donatePlaybackShortcut(for: .classicalMusic)

        return .result(dialog: "Playing classical music for your baby")
    }
}
