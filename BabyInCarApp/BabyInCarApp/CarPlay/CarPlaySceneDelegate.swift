//
//  CarPlaySceneDelegate.swift
//  BabyInCarApp
//
//  CarPlay integration for hands-free audio control while driving
//  NOTE: CarPlay requires special Apple entitlements. This file is conditionally compiled.
//  To enable CarPlay:
//  1. Request CarPlay Audio entitlement from Apple at https://developer.apple.com/contact/carplay/
//  2. Add the entitlements to your provisioning profile
//  3. Define CARPLAY_ENABLED in Build Settings > Other Swift Flags: -DCARPLAY_ENABLED
//

import Foundation
import UIKit

#if CARPLAY_ENABLED
import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared
    private let aiEngine = AIRecommendationEngine.shared

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Set the root template
        let tabBarTemplate = createTabBarTemplate()
        interfaceController.setRootTemplate(tabBarTemplate, animated: true, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Tab Bar Template

    private func createTabBarTemplate() -> CPTabBarTemplate {
        let homeTab = createHomeTab()
        let categoriesTab = createCategoriesTab()
        let emergencyTab = createEmergencyTab()
        let nowPlayingTab = createNowPlayingTab()

        let tabBarTemplate = CPTabBarTemplate(templates: [
            homeTab,
            categoriesTab,
            emergencyTab,
            nowPlayingTab
        ])

        return tabBarTemplate
    }

    // MARK: - Home Tab

    private func createHomeTab() -> CPListTemplate {
        var sections: [CPListSection] = []

        // Quick Actions Section
        let quickActions = [
            createListItem(
                title: "Play Recommended",
                subtitle: "AI-personalized for your baby",
                image: UIImage(systemName: "sparkles")
            ) { [weak self] in
                self?.playRecommended()
            },
            createListItem(
                title: "Sleep Mode",
                subtitle: "Gentle sounds for sleeping",
                image: UIImage(systemName: "moon.fill")
            ) { [weak self] in
                self?.playSleepMode()
            },
            createListItem(
                title: "Resume Playback",
                subtitle: "Continue where you left off",
                image: UIImage(systemName: "play.fill")
            ) { [weak self] in
                self?.resumePlayback()
            }
        ]
        sections.append(CPListSection(items: quickActions, header: "Quick Actions", sectionIndexTitle: nil))

        // Recent Playlists Section
        let recentPlaylists = contentLibrary.playlists.prefix(4).map { playlist in
            createListItem(
                title: playlist.name,
                subtitle: "\(playlist.tracks.count) tracks",
                image: UIImage(systemName: "music.note.list")
            ) { [weak self] in
                self?.playPlaylist(playlist)
            }
        }
        sections.append(CPListSection(items: Array(recentPlaylists), header: "Playlists", sectionIndexTitle: nil))

        let template = CPListTemplate(title: "Baby in Car", sections: sections)
        template.tabImage = UIImage(systemName: "house.fill")

        return template
    }

    // MARK: - Categories Tab

    private func createCategoriesTab() -> CPListTemplate {
        let categories = AudioCategory.allCases.map { category in
            createListItem(
                title: category.rawValue,
                subtitle: category.carPlayDescription,
                image: UIImage(systemName: category.carPlayIconName)
            ) { [weak self] in
                self?.showCategoryTracks(category)
            }
        }

        let section = CPListSection(items: categories, header: nil, sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Categories", sections: [section])
        template.tabImage = UIImage(systemName: "square.grid.2x2.fill")

        return template
    }

    // MARK: - Emergency Tab

    private func createEmergencyTab() -> CPListTemplate {
        let emergencyItems = [
            createListItem(
                title: "EMERGENCY CRY-STOP",
                subtitle: "Activate calming sequence now",
                image: UIImage(systemName: "exclamationmark.triangle.fill")
            ) { [weak self] in
                self?.activateEmergencyMode()
            },
            createListItem(
                title: "Shushing Sound",
                subtitle: "Instant calming",
                image: UIImage(systemName: "waveform")
            ) { [weak self] in
                self?.playEmergencySound(.shushing)
            },
            createListItem(
                title: "Womb Sounds",
                subtitle: "Familiar comfort",
                image: UIImage(systemName: "heart.fill")
            ) { [weak self] in
                self?.playEmergencySound(.womb)
            },
            createListItem(
                title: "White Noise",
                subtitle: "Masking sound",
                image: UIImage(systemName: "speaker.wave.3.fill")
            ) { [weak self] in
                self?.playEmergencySound(.whiteNoise)
            }
        ]

        let section = CPListSection(items: emergencyItems, header: "Calming Tools", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Emergency", sections: [section])
        template.tabImage = UIImage(systemName: "exclamationmark.triangle.fill")

        return template
    }

    // MARK: - Now Playing Tab

    private func createNowPlayingTab() -> CPNowPlayingTemplate {
        let template = CPNowPlayingTemplate.shared

        // Add custom buttons
        let repeatButton = CPNowPlayingRepeatButton { [weak self] button in
            self?.toggleRepeat()
        }

        let shuffleButton = CPNowPlayingShuffleButton { [weak self] button in
            self?.toggleShuffle()
        }

        template.updateNowPlayingButtons([shuffleButton, repeatButton])

        return template
    }

    // MARK: - Helper Methods

    private func createListItem(
        title: String,
        subtitle: String?,
        image: UIImage?,
        handler: @escaping () -> Void
    ) -> CPListItem {
        let item = CPListItem(text: title, detailText: subtitle, image: image)
        item.handler = { _, completion in
            handler()
            completion()
        }
        return item
    }

    // MARK: - Category Tracks

    private func showCategoryTracks(_ category: AudioCategory) {
        let tracks = contentLibrary.getTracks(for: category)

        let trackItems = tracks.prefix(12).map { track in
            createListItem(
                title: track.title,
                subtitle: track.artist,
                image: UIImage(systemName: "music.note")
            ) { [weak self] in
                Task { @MainActor in
                    self?.audioEngine.play(track: track)
                }
            }
        }

        let section = CPListSection(items: Array(trackItems), header: nil, sectionIndexTitle: nil)
        let template = CPListTemplate(title: category.rawValue, sections: [section])

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Playback Actions

    private func playRecommended() {
        Task { @MainActor in
            // Get current baby from AppState if available
            let appState = await getAppState()
            if let baby = appState?.currentBaby {
                let playlist = await aiEngine.getPersonalizedPlaylist(for: baby)
                audioEngine.play(playlist: playlist)
            } else {
                // Play default calming playlist
                if let playlist = contentLibrary.playlists.first(where: { $0.name.contains("Sleep") }) {
                    audioEngine.play(playlist: playlist)
                }
            }
        }
    }

    private func playSleepMode() {
        Task { @MainActor in
            let sleepTracks = contentLibrary.allTracks
                .filter { $0.calmingScore >= 0.85 }
                .prefix(10)

            let playlist = Playlist(
                name: "Sleep Mode",
                description: "Gentle sounds for peaceful sleep",
                tracks: Array(sleepTracks),
                isSystemGenerated: true
            )

            audioEngine.play(playlist: playlist)
            audioEngine.setRepeatMode(.all)
        }
    }

    private func resumePlayback() {
        Task { @MainActor in
            if audioEngine.playbackState == .paused {
                audioEngine.resume()
            } else if let currentTrack = audioEngine.currentTrack {
                audioEngine.play(track: currentTrack)
            }
        }
    }

    private func playPlaylist(_ playlist: Playlist) {
        Task { @MainActor in
            audioEngine.play(playlist: playlist)
        }
    }

    private func activateEmergencyMode() {
        Task { @MainActor in
            let appState = await getAppState()
            if let baby = appState?.currentBaby {
                EmergencyCryStopService.shared.activate(for: baby)
            } else {
                // Create default baby profile for emergency
                let defaultBaby = Baby(name: "Baby", birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!)
                EmergencyCryStopService.shared.activate(for: defaultBaby)
            }

            // Show alert
            showEmergencyAlert()
        }
    }

    private func playEmergencySound(_ generator: GeneratorType) {
        Task { @MainActor in
            let track = AudioTrack(
                title: generator.rawValue,
                category: generator.category,
                duration: 1800,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            )
            audioEngine.play(track: track)
            audioEngine.setRepeatMode(.one)
        }
    }

    private func toggleRepeat() {
        Task { @MainActor in
            switch audioEngine.repeatMode {
            case .off:
                audioEngine.setRepeatMode(.all)
            case .all:
                audioEngine.setRepeatMode(.one)
            case .one:
                audioEngine.setRepeatMode(.off)
            }
        }
    }

    private func toggleShuffle() {
        Task { @MainActor in
            audioEngine.toggleShuffle()
        }
    }

    private func showEmergencyAlert() {
        let alertTemplate = CPAlertTemplate(
            titleVariants: ["Emergency Mode Active"],
            actions: [
                CPAlertAction(title: "OK", style: .default) { [weak self] _ in
                    self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                },
                CPAlertAction(title: "Stop", style: .cancel) { [weak self] _ in
                    Task { @MainActor in
                        EmergencyCryStopService.shared.deactivate()
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    }
                }
            ]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    @MainActor
    private func getAppState() async -> AppState? {
        // Access the shared app state
        // In a real app, this would be properly injected
        return nil
    }
}

// MARK: - AudioCategory CarPlay Extensions

extension AudioCategory {
    var carPlayIconName: String {
        switch self {
        case .classicalMusic: return "music.quarternote.3"
        case .fairyTales: return "book.fill"
        case .whiteNoise: return "waveform"
        case .natureSounds: return "leaf.fill"
        case .instrumental: return "pianokeys"
        case .childrenSongs: return "music.mic"
        case .podcasts: return "mic.fill"
        }
    }

    var carPlayDescription: String {
        switch self {
        case .classicalMusic: return "Soothing classical pieces"
        case .fairyTales: return "Stories in 10+ languages"
        case .whiteNoise: return "Calming background sounds"
        case .natureSounds: return "Peaceful nature ambience"
        case .instrumental: return "Gentle melodies"
        case .childrenSongs: return "Lullabies and songs"
        case .podcasts: return "Calming voice content"
        }
    }
}

#else
// CarPlay not enabled - provide empty placeholder
// To enable CarPlay, request entitlements from Apple and add -DCARPLAY_ENABLED to Swift flags
#endif
