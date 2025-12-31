//
//  AudioTrack.swift
//  BabyInCarApp
//
//  Data model for audio tracks - uses royalty-free audio sources
//

import Foundation
import AVFoundation

// MARK: - Audio Category
enum AudioCategory: String, Codable, CaseIterable, Identifiable {
    case classicalMusic = "Classical Music"
    case fairyTales = "Fairy Tales"
    case whiteNoise = "White Noise"
    case natureSounds = "Nature Sounds"
    case instrumental = "Instrumental"
    case childrenSongs = "Children's Songs"
    case podcasts = "Podcasts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .classicalMusic: return "music.note.list"
        case .fairyTales: return "book.fill"
        case .whiteNoise: return "waveform"
        case .natureSounds: return "leaf.fill"
        case .instrumental: return "pianokeys"
        case .childrenSongs: return "music.mic"
        case .podcasts: return "mic.fill"
        }
    }

    var color: String {
        switch self {
        case .classicalMusic: return "ClassicalColor"
        case .fairyTales: return "FairyTaleColor"
        case .whiteNoise: return "WhiteNoiseColor"
        case .natureSounds: return "NatureColor"
        case .instrumental: return "InstrumentalColor"
        case .childrenSongs: return "ChildrenSongsColor"
        case .podcasts: return "PodcastColor"
        }
    }

    var description: String {
        switch self {
        case .classicalMusic:
            return "Soothing classical compositions for relaxation"
        case .fairyTales:
            return "Gentle stories in multiple languages"
        case .whiteNoise:
            return "Calming background sounds for sleep"
        case .natureSounds:
            return "Peaceful sounds from nature"
        case .instrumental:
            return "Soft instrumental melodies"
        case .childrenSongs:
            return "Gentle lullabies and children's songs"
        case .podcasts:
            return "Calming content for parents and babies"
        }
    }
}

// MARK: - Language
enum Language: String, Codable, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case italian = "Italian"
    case portuguese = "Portuguese"
    case mandarin = "Mandarin"
    case japanese = "Japanese"
    case russian = "Russian"
    case arabic = "Arabic"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .mandarin: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .russian: return "🇷🇺"
        case .arabic: return "🇸🇦"
        }
    }

    var code: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .mandarin: return "zh"
        case .japanese: return "ja"
        case .russian: return "ru"
        case .arabic: return "ar"
        }
    }
}

// MARK: - Audio Track
struct AudioTrack: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let category: AudioCategory
    let language: Language?
    let duration: TimeInterval
    let ageRangeMin: Int  // months
    let ageRangeMax: Int  // months
    let optimalAgeMonths: [Int]
    let tempoBPM: Int?
    let calmingScore: Double // 0.0 - 1.0
    let isPremium: Bool
    var isDownloaded: Bool
    let audioSourceType: AudioSourceType

    // For generated/synthesized audio
    var generatorType: GeneratorType?

    // For file-based audio (royalty-free)
    var fileName: String?
    var fileExtension: String?

    // URL for streaming (royalty-free sources)
    var streamURL: String?

    // Server metadata
    var serverId: String?
    var artworkURL: String?
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Baby in Car",
        category: AudioCategory,
        language: Language? = nil,
        duration: TimeInterval,
        ageRangeMin: Int = 0,
        ageRangeMax: Int = 36,
        optimalAgeMonths: [Int] = [],
        tempoBPM: Int? = nil,
        calmingScore: Double = 0.8,
        isPremium: Bool = false,
        isDownloaded: Bool = false,
        audioSourceType: AudioSourceType,
        generatorType: GeneratorType? = nil,
        fileName: String? = nil,
        fileExtension: String? = nil,
        streamURL: String? = nil,
        serverId: String? = nil,
        artworkURL: String? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.category = category
        self.language = language
        self.duration = duration
        self.ageRangeMin = ageRangeMin
        self.ageRangeMax = ageRangeMax
        self.optimalAgeMonths = optimalAgeMonths
        self.tempoBPM = tempoBPM
        self.calmingScore = calmingScore
        self.isPremium = isPremium
        self.isDownloaded = isDownloaded
        self.audioSourceType = audioSourceType
        self.generatorType = generatorType
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.streamURL = streamURL
        self.serverId = serverId
        self.artworkURL = artworkURL
        self.isLocked = isLocked
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isAgeAppropriate: Bool {
        return true // Will be calculated based on current baby
    }

    func isOptimalFor(ageMonths: Int) -> Bool {
        if optimalAgeMonths.isEmpty {
            return ageMonths >= ageRangeMin && ageMonths <= ageRangeMax
        }
        return optimalAgeMonths.contains(ageMonths)
    }

    /// Check if track requires network to play
    var requiresNetwork: Bool {
        switch audioSourceType {
        case .generated:
            return false
        case .bundled:
            return false
        case .streamed:
            return !isDownloaded
        case .textToSpeech:
            return true // Usually needs network for TTS service
        }
    }

    /// Check if track can be played offline
    var canPlayOffline: Bool {
        return !requiresNetwork
    }

    /// Get the effective playback source description
    var sourceDescription: String {
        if isDownloaded {
            return "Downloaded"
        }
        switch audioSourceType {
        case .generated:
            return "Generated"
        case .bundled:
            return "Built-in"
        case .streamed:
            return "Streaming"
        case .textToSpeech:
            return "Text-to-Speech"
        }
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Audio Source Type
enum AudioSourceType: String, Codable {
    case generated      // Synthesized audio (white noise, pink noise, etc.)
    case bundled        // Bundled royalty-free audio files
    case streamed       // Streamed from royalty-free sources
    case textToSpeech   // Generated using text-to-speech for stories
}

// MARK: - Generator Type (for synthesized audio)
enum GeneratorType: String, Codable, CaseIterable {
    // White Noise variants
    case whiteNoise = "White Noise"
    case pinkNoise = "Pink Noise"
    case brownNoise = "Brown Noise"
    case blueNoise = "Blue Noise"
    case violetNoise = "Violet Noise"
    case greyNoise = "Grey Noise"
    case velvetNoise = "Velvet Noise"

    // Nature-like sounds
    case rain = "Rain"
    case ocean = "Ocean Waves"
    case river = "River Stream"
    case wind = "Gentle Wind"
    case thunderstorm = "Distant Thunder"
    case birds = "Birds Chirping"
    case crickets = "Crickets"
    case fireplace = "Fireplace"
    case forest = "Forest Ambience"
    case waterfall = "Waterfall"
    case campfire = "Campfire Night"

    // Baby-specific sounds
    case heartbeat = "Heartbeat"
    case womb = "Womb Sounds"
    case shushing = "Shushing"
    case vacuum = "Vacuum Cleaner"
    case hairDryer = "Hair Dryer"
    case fan = "Fan"
    case carEngine = "Car Engine"
    case washingMachine = "Washing Machine"

    // Toddler-focused sounds (12-36 months)
    case trainRide = "Train Ride"
    case airplaneCabin = "Airplane Cabin"
    case rainOnRoof = "Rain on Roof"
    case thunderRumble = "Thunder Rumble"
    case cityAmbience = "City Night"
    case aquarium = "Aquarium Bubbles"

    // Musical tones
    case lullaby = "Lullaby Melody"
    case musicBox = "Music Box"
    case chimes = "Wind Chimes"
    case bells = "Soft Bells"
    case softPiano = "Soft Piano"
    case gentleGuitar = "Gentle Guitar"

    var category: AudioCategory {
        switch self {
        case .whiteNoise, .pinkNoise, .brownNoise, .blueNoise, .violetNoise, .greyNoise, .velvetNoise,
             .vacuum, .hairDryer, .fan, .washingMachine:
            return .whiteNoise
        case .rain, .ocean, .river, .wind, .thunderstorm, .birds, .crickets, .fireplace,
             .forest, .waterfall, .campfire, .rainOnRoof:
            return .natureSounds
        case .heartbeat, .womb, .shushing, .carEngine:
            return .whiteNoise
        case .trainRide, .airplaneCabin, .thunderRumble, .cityAmbience, .aquarium:
            return .whiteNoise
        case .lullaby, .musicBox, .chimes, .bells, .softPiano, .gentleGuitar:
            return .instrumental
        }
    }

    var defaultDuration: TimeInterval {
        return 3600 // 1 hour default for generated sounds
    }

    var optimalAgeRange: ClosedRange<Int> {
        switch self {
        case .womb, .heartbeat, .shushing, .whiteNoise:
            return 0...6
        case .pinkNoise, .brownNoise, .vacuum, .hairDryer, .fan:
            return 0...12
        case .blueNoise, .violetNoise:
            return 12...36 // Better for toddlers - higher frequencies
        case .greyNoise, .velvetNoise:
            return 6...36 // Perceptually balanced - works for wide age range
        case .rain, .ocean, .river:
            return 3...36
        case .wind, .birds, .crickets:
            return 6...36
        case .forest, .waterfall, .campfire:
            return 12...36 // More complex sounds for older babies
        case .lullaby, .musicBox:
            return 0...24
        case .chimes, .bells:
            return 3...36
        case .softPiano, .gentleGuitar:
            return 9...36 // Musical instruments for older babies
        case .thunderstorm, .fireplace:
            return 6...36
        case .carEngine, .washingMachine:
            return 0...12
        case .trainRide, .airplaneCabin:
            return 12...36 // Travel sounds appealing to toddlers
        case .rainOnRoof, .thunderRumble:
            return 9...36 // Weather variations
        case .cityAmbience:
            return 18...36 // Complex ambient for older toddlers
        case .aquarium:
            return 6...36 // Gentle bubbling works for many ages
        }
    }

    var calmingScore: Double {
        switch self {
        case .womb, .heartbeat: return 0.95
        case .shushing, .pinkNoise: return 0.92
        case .whiteNoise, .brownNoise: return 0.88
        case .blueNoise: return 0.82 // Slightly energizing, good for focus
        case .violetNoise: return 0.78 // Higher frequencies, alerting
        case .greyNoise: return 0.90 // Perceptually balanced, very calming
        case .velvetNoise: return 0.91 // Smooth, highly soothing
        case .rain, .ocean: return 0.90
        case .lullaby, .musicBox: return 0.85
        case .softPiano: return 0.88
        case .gentleGuitar: return 0.86
        case .fan, .vacuum, .hairDryer: return 0.80
        case .river, .wind: return 0.85
        case .forest: return 0.87 // Rich nature soundscape
        case .waterfall: return 0.86 // Consistent flowing water
        case .campfire: return 0.84 // Crackling with night ambience
        case .carEngine, .washingMachine: return 0.78
        case .birds, .crickets: return 0.75
        case .chimes, .bells: return 0.82
        case .thunderstorm, .fireplace: return 0.78
        case .trainRide: return 0.83 // Rhythmic, soothing motion
        case .airplaneCabin: return 0.81 // Consistent drone
        case .rainOnRoof: return 0.89 // Cozy rain variant
        case .thunderRumble: return 0.76 // Low rumble, less calming
        case .cityAmbience: return 0.72 // Complex, less calming
        case .aquarium: return 0.85 // Gentle bubbles
        }
    }
}

// MARK: - Playlist
struct Playlist: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var tracks: [AudioTrack]
    var category: AudioCategory?
    var targetAgeMonths: Int?
    var isSystemGenerated: Bool
    var createdAt: Date
    var artworkName: String?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        tracks: [AudioTrack] = [],
        category: AudioCategory? = nil,
        targetAgeMonths: Int? = nil,
        isSystemGenerated: Bool = false,
        createdAt: Date = Date(),
        artworkName: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tracks = tracks
        self.category = category
        self.targetAgeMonths = targetAgeMonths
        self.isSystemGenerated = isSystemGenerated
        self.createdAt = createdAt
        self.artworkName = artworkName
        self.updatedAt = updatedAt
    }

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    var trackCount: Int {
        tracks.count
    }

    var isEmpty: Bool {
        tracks.isEmpty
    }

    /// Get dominant category based on track categories
    var dominantCategory: AudioCategory? {
        guard !tracks.isEmpty else { return category }

        // If category is set, use it
        if let cat = category { return cat }

        // Calculate dominant category from tracks
        var categoryCount: [AudioCategory: Int] = [:]
        for track in tracks {
            categoryCount[track.category, default: 0] += 1
        }

        return categoryCount.max(by: { $0.value < $1.value })?.key
    }

    /// Check if playlist contains a specific track
    func contains(_ track: AudioTrack) -> Bool {
        tracks.contains { $0.id == track.id }
    }

    /// Get index of a track in the playlist
    func index(of track: AudioTrack) -> Int? {
        tracks.firstIndex { $0.id == track.id }
    }

    /// Average calming score of all tracks
    var averageCalmingScore: Double {
        guard !tracks.isEmpty else { return 0 }
        return tracks.reduce(0) { $0 + $1.calmingScore } / Double(tracks.count)
    }

    /// Check if all tracks can play offline
    var canPlayOffline: Bool {
        tracks.allSatisfy { $0.canPlayOffline }
    }

    /// Get tracks that require network
    var tracksRequiringNetwork: [AudioTrack] {
        tracks.filter { $0.requiresNetwork }
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Playback State
enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
    case loading
    case error(String)

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

// MARK: - Sleep Timer
enum SleepTimer: Int, CaseIterable, Identifiable {
    case off = 0
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60
    case twoHours = 120

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .fortyFiveMinutes: return "45 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var defaultVolume: Float = 0.5
    var maxVolume: Float = 0.7 // Safety limit (50dB equivalent)
    var autoPlayOnLaunch: Bool = false
    var fadeOutDuration: TimeInterval = 10.0
    var preferredSleepTimerMinutes: Int = 0  // Store as Int for Codable
    var enableCryDetection: Bool = true
    var enableVoiceControl: Bool = true
    var downloadOnWiFiOnly: Bool = true
    var autoDownloadAgeContent: Bool = true
    var hapticFeedback: Bool = true
    var carPlayEnabled: Bool = true

    var preferredSleepTimer: SleepTimer {
        get { SleepTimer(rawValue: preferredSleepTimerMinutes) ?? .off }
        set { preferredSleepTimerMinutes = newValue.rawValue }
    }

    enum CodingKeys: String, CodingKey {
        case defaultVolume, maxVolume, autoPlayOnLaunch, fadeOutDuration
        case preferredSleepTimerMinutes, enableCryDetection, enableVoiceControl
        case downloadOnWiFiOnly, autoDownloadAgeContent, hapticFeedback, carPlayEnabled
    }
}

// MARK: - Listening History
struct ListeningSession: Codable, Identifiable {
    let id: UUID
    let trackId: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var completedSuccessfully: Bool
    var babyCalmedDown: Bool?

    init(trackId: UUID) {
        self.id = UUID()
        self.trackId = trackId
        self.startTime = Date()
        self.duration = 0
        self.completedSuccessfully = false
    }

    mutating func complete(calmedDown: Bool? = nil) {
        endTime = Date()
        duration = endTime?.timeIntervalSince(startTime) ?? 0
        completedSuccessfully = true
        babyCalmedDown = calmedDown
    }
}
