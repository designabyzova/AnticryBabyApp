//
//  WatchConnectivityTests.swift
//  BabyInCarAppTests
//
//  Unit tests for Watch connectivity and command handling
//

import Testing
import Foundation
@testable import BabyInCarApp

// MARK: - Watch Command Tests

@Suite("Watch Commands")
struct WatchCommandTests {

    @Test("All commands encode and decode correctly")
    func commandsCodable() throws {
        let commands: [WatchCommand] = [
            .play,
            .pause,
            .togglePlayPause,
            .skipNext,
            .skipPrevious,
            .setVolume(0.5),
            .setSleepTimer(minutes: 30),
            .cancelSleepTimer,
            .startSoothingMusic(playlistId: nil),
            .startSoothingMusic(playlistId: "lullabies"),
            .requestStateSync,
            .playTrack(trackId: "track-123"),
            .playCategory(categoryId: "Classical Music"),
            .requestLibrarySync
        ]

        for command in commands {
            let encoded = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(WatchCommand.self, from: encoded)
            #expect(decoded == command, "Command \(command) should encode/decode correctly")
        }
    }

    @Test("Volume command preserves value")
    func volumeCommandValue() throws {
        let testVolumes: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for volume in testVolumes {
            let command = WatchCommand.setVolume(volume)
            let encoded = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(WatchCommand.self, from: encoded)

            if case .setVolume(let decodedVolume) = decoded {
                #expect(decodedVolume == volume, "Volume \(volume) should be preserved")
            } else {
                Issue.record("Decoded command should be setVolume")
            }
        }
    }

    @Test("Sleep timer command preserves minutes")
    func sleepTimerMinutes() throws {
        let testMinutes = [15, 30, 45, 60, 120]

        for minutes in testMinutes {
            let command = WatchCommand.setSleepTimer(minutes: minutes)
            let encoded = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(WatchCommand.self, from: encoded)

            if case .setSleepTimer(let decodedMinutes) = decoded {
                #expect(decodedMinutes == minutes, "Minutes \(minutes) should be preserved")
            } else {
                Issue.record("Decoded command should be setSleepTimer")
            }
        }
    }

    @Test("Track command preserves ID")
    func trackCommandId() throws {
        let trackId = "test-track-uuid-123"
        let command = WatchCommand.playTrack(trackId: trackId)
        let encoded = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(WatchCommand.self, from: encoded)

        if case .playTrack(let decodedId) = decoded {
            #expect(decodedId == trackId, "Track ID should be preserved")
        } else {
            Issue.record("Decoded command should be playTrack")
        }
    }

    @Test("Category command preserves ID")
    func categoryCommandId() throws {
        let categoryId = "Classical Music"
        let command = WatchCommand.playCategory(categoryId: categoryId)
        let encoded = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(WatchCommand.self, from: encoded)

        if case .playCategory(let decodedId) = decoded {
            #expect(decodedId == categoryId, "Category ID should be preserved")
        } else {
            Issue.record("Decoded command should be playCategory")
        }
    }
}

// MARK: - Playback State Tests

@Suite("Playback State")
struct PlaybackStateTests {

    @Test("Idle state has correct defaults")
    func idleState() {
        let idle = PlaybackState.idle

        #expect(idle.isPlaying == false)
        #expect(idle.currentTrackId == nil)
        #expect(idle.currentTrackTitle == nil)
        #expect(idle.currentTrackArtist == nil)
        #expect(idle.progress == 0)
        #expect(idle.volume == 0.5)
        #expect(idle.sleepTimerRemaining == nil)
    }

    @Test("Playback state encodes and decodes")
    func playbackStateCodable() throws {
        let state = PlaybackState(
            isPlaying: true,
            currentTrackId: "track-123",
            currentTrackTitle: "Brahms Lullaby",
            currentTrackArtist: "Classical Baby",
            progress: 0.45,
            volume: 0.8,
            sleepTimerRemaining: 1200,
            timestamp: Date()
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PlaybackState.self, from: encoded)

        #expect(decoded.isPlaying == true)
        #expect(decoded.currentTrackId == "track-123")
        #expect(decoded.currentTrackTitle == "Brahms Lullaby")
        #expect(decoded.currentTrackArtist == "Classical Baby")
        #expect(abs(decoded.progress - 0.45) < 0.01)
        #expect(abs(decoded.volume - 0.8) < 0.01)
        #expect(decoded.sleepTimerRemaining == 1200)
    }

    @Test("State equality check works")
    func stateEquality() {
        let state1 = PlaybackState(
            isPlaying: true,
            currentTrackId: "track-1",
            currentTrackTitle: "Title",
            currentTrackArtist: "Artist",
            progress: 0.5,
            volume: 0.7,
            sleepTimerRemaining: nil,
            timestamp: Date()
        )

        let state2 = PlaybackState(
            isPlaying: true,
            currentTrackId: "track-1",
            currentTrackTitle: "Title",
            currentTrackArtist: "Artist",
            progress: 0.5,
            volume: 0.7,
            sleepTimerRemaining: nil,
            timestamp: Date()
        )

        #expect(state1 == state2)
    }
}

// MARK: - Cry Type Tests

@Suite("Cry Type")
struct CryTypeTests {

    @Test("All cry types have display names")
    func cryTypeDisplayNames() {
        for cryType in CryType.allCases {
            #expect(!cryType.displayName.isEmpty, "\(cryType) should have display name")
        }
    }

    @Test("All cry types have icon names")
    func cryTypeIcons() {
        for cryType in CryType.allCases {
            #expect(!cryType.iconName.isEmpty, "\(cryType) should have icon name")
        }
    }

    @Test("All cry types have suggested actions")
    func cryTypeSuggestedActions() {
        for cryType in CryType.allCases {
            #expect(!cryType.suggestedAction.isEmpty, "\(cryType) should have suggested action")
        }
    }

    @Test("Cry type raw values are unique")
    func cryTypeRawValues() {
        var rawValues = Set<String>()
        for cryType in CryType.allCases {
            #expect(!rawValues.contains(cryType.rawValue), "Duplicate raw value: \(cryType.rawValue)")
            rawValues.insert(cryType.rawValue)
        }
    }
}

// MARK: - Watch Track Tests

@Suite("Watch Track")
struct WatchTrackTests {

    @Test("Track initializes correctly")
    func trackInitialization() {
        let track = WatchTrack(
            id: "track-123",
            title: "Ocean Waves",
            artist: "Nature Sounds",
            duration: 180,
            category: "Nature Sounds"
        )

        #expect(track.id == "track-123")
        #expect(track.title == "Ocean Waves")
        #expect(track.artist == "Nature Sounds")
        #expect(track.duration == 180)
        #expect(track.category == "Nature Sounds")
        #expect(track.localURL == nil)
        #expect(track.isSynced == false)
    }

    @Test("Track formatted duration is correct")
    func trackFormattedDuration() {
        let testCases: [(duration: TimeInterval, expected: String)] = [
            (60, "1:00"),
            (90, "1:30"),
            (180, "3:00"),
            (125, "2:05"),
            (0, "0:00"),
            (3599, "59:59")
        ]

        for (duration, expected) in testCases {
            let track = WatchTrack(
                id: "test",
                title: "Test",
                artist: "Test",
                duration: duration,
                category: "Test"
            )

            #expect(track.formattedDuration == expected, "Duration \(duration)s should format as \(expected)")
        }
    }

    @Test("Track encodes and decodes")
    func trackCodable() throws {
        let track = WatchTrack(
            id: "track-456",
            title: "Lullaby",
            artist: "Baby Music",
            duration: 240,
            category: "Lullabies",
            localURL: nil,
            artworkData: nil
        )

        let encoded = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(WatchTrack.self, from: encoded)

        #expect(decoded.id == "track-456")
        #expect(decoded.title == "Lullaby")
        #expect(decoded.artist == "Baby Music")
        #expect(decoded.duration == 240)
        #expect(decoded.category == "Lullabies")
    }

    @Test("Track Hashable conformance")
    func trackHashable() {
        let track1 = WatchTrack(id: "1", title: "A", artist: "B", duration: 100, category: "C")
        let track2 = WatchTrack(id: "1", title: "A", artist: "B", duration: 100, category: "C")
        let track3 = WatchTrack(id: "2", title: "A", artist: "B", duration: 100, category: "C")

        #expect(track1 == track2)
        #expect(track1 != track3)
    }
}

// MARK: - Watch Category Tests

@Suite("Watch Category")
struct WatchCategoryTests {

    @Test("Category initializes correctly")
    func categoryInitialization() {
        let category = WatchCategory(
            id: "classical",
            name: "Classical Music",
            icon: "music.note",
            trackCount: 25,
            description: "Soothing classical music for babies"
        )

        #expect(category.id == "classical")
        #expect(category.name == "Classical Music")
        #expect(category.icon == "music.note")
        #expect(category.trackCount == 25)
        #expect(category.description == "Soothing classical music for babies")
    }

    @Test("Category encodes and decodes")
    func categoryCodable() throws {
        let category = WatchCategory(
            id: "lullabies",
            name: "Lullabies",
            icon: "moon.zzz",
            trackCount: 15,
            description: "Gentle lullabies"
        )

        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(WatchCategory.self, from: encoded)

        #expect(decoded.id == "lullabies")
        #expect(decoded.name == "Lullabies")
        #expect(decoded.icon == "moon.zzz")
        #expect(decoded.trackCount == 15)
    }
}

// MARK: - Watch Library State Tests

@Suite("Watch Library State")
struct WatchLibraryStateTests {

    @Test("Empty state has no content")
    func emptyState() {
        let empty = WatchLibraryState.empty

        #expect(empty.categories.isEmpty)
        #expect(empty.recentTracks.isEmpty)
        #expect(empty.topCalmingTracks.isEmpty)
    }

    @Test("Library state encodes and decodes")
    func libraryStateCodable() throws {
        let categories = [
            WatchCategory(id: "1", name: "Category 1", icon: "music.note", trackCount: 10),
            WatchCategory(id: "2", name: "Category 2", icon: "leaf", trackCount: 5)
        ]

        let tracks = [
            WatchTrack(id: "t1", title: "Track 1", artist: "Artist", duration: 120, category: "1"),
            WatchTrack(id: "t2", title: "Track 2", artist: "Artist", duration: 180, category: "2")
        ]

        let state = WatchLibraryState(
            categories: categories,
            recentTracks: tracks,
            topCalmingTracks: tracks,
            timestamp: Date()
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchLibraryState.self, from: encoded)

        #expect(decoded.categories.count == 2)
        #expect(decoded.recentTracks.count == 2)
        #expect(decoded.topCalmingTracks.count == 2)
    }
}

// MARK: - Watch Message Type Tests

@Suite("Watch Message Types")
struct WatchMessageTypeTests {

    @Test("All message types have raw values")
    func messageTypesRawValues() {
        let messageTypes: [WatchMessage] = [
            .playbackState,
            .command,
            .favoritesUpdate,
            .fileTransferComplete,
            .requestSync,
            .libraryState
        ]

        for messageType in messageTypes {
            #expect(!messageType.rawValue.isEmpty, "\(messageType) should have raw value")
        }
    }

    @Test("Message type raw values are unique")
    func uniqueRawValues() {
        var rawValues = Set<String>()
        let messageTypes: [WatchMessage] = [
            .playbackState, .command, .favoritesUpdate,
            .fileTransferComplete, .requestSync, .libraryState
        ]

        for messageType in messageTypes {
            #expect(!rawValues.contains(messageType.rawValue), "Duplicate raw value: \(messageType.rawValue)")
            rawValues.insert(messageType.rawValue)
        }
    }
}

// MARK: - AudioTrack to WatchTrack Conversion Tests

@Suite("AudioTrack to WatchTrack Conversion")
struct AudioTrackConversionTests {

    @Test("AudioTrack converts to WatchTrack correctly")
    func conversionPreservesData() {
        let audioTrack = AudioTrack(
            title: "Ocean Waves",
            artist: "Nature Sounds",
            category: .natureSounds,
            duration: 240,
            audioSourceType: .bundled
        )

        let watchTrack = audioTrack.toWatchTrack()

        #expect(watchTrack.title == "Ocean Waves")
        #expect(watchTrack.artist == "Nature Sounds")
        #expect(watchTrack.duration == 240)
        #expect(watchTrack.category == AudioCategory.natureSounds.rawValue)
        #expect(watchTrack.localURL == nil)
        #expect(watchTrack.isSynced == false)
    }

    @Test("Conversion preserves UUID as string")
    func conversionPreservesUUID() {
        let audioTrack = AudioTrack(
            title: "Test",
            artist: "Test",
            category: .lullabies,
            duration: 100,
            audioSourceType: .bundled
        )

        let watchTrack = audioTrack.toWatchTrack()

        #expect(watchTrack.id == audioTrack.id.uuidString)
    }
}
