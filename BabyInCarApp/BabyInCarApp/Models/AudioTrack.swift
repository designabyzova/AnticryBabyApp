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
    case natureSounds = "Nature Sounds"
    case instrumental = "Instrumental"
    case childrenSongs = "Children's Songs"
    case podcasts = "Podcasts"
    case lullabies = "Lullabies"
    case ambient = "Ambient"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .classicalMusic: return "music.note.list"
        case .fairyTales: return "book.fill"
        case .natureSounds: return "leaf.fill"
        case .instrumental: return "pianokeys"
        case .childrenSongs: return "music.mic"
        case .podcasts: return "mic.fill"
        case .lullabies: return "moon.stars.fill"
        case .ambient: return "sparkles"
        }
    }

    var color: String {
        switch self {
        case .classicalMusic: return "ClassicalColor"
        case .fairyTales: return "FairyTaleColor"
        case .natureSounds: return "NatureColor"
        case .instrumental: return "InstrumentalColor"
        case .childrenSongs: return "ChildrenSongsColor"
        case .podcasts: return "PodcastColor"
        case .lullabies: return "LullabiesColor"
        case .ambient: return "AmbientColor"
        }
    }

    var description: String {
        switch self {
        case .classicalMusic:
            return "Soothing classical compositions for relaxation"
        case .fairyTales:
            return "Gentle stories in multiple languages"
        case .natureSounds:
            return "Peaceful sounds from nature"
        case .instrumental:
            return "Soft instrumental melodies"
        case .childrenSongs:
            return "Gentle lullabies and children's songs"
        case .podcasts:
            return "Calming content for parents and babies"
        case .lullabies:
            return "Traditional lullabies for peaceful sleep"
        case .ambient:
            return "Gentle ambient music for relaxation"
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
struct AudioTrack: Codable, Identifiable, Equatable, Hashable, Sendable {
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
        artist: String = "Lulla",
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

    // MARK: - Default Emergency Track
    /// Returns the default emergency track - uses GENERATED lullaby for instant, reliable playback
    /// Generated audio starts immediately with no file loading delays or network issues
    /// This guarantees emergency mode ALWAYS has sound, even offline
    static func defaultEmergencyTrack() -> AudioTrack {
        return AudioTrack(
            id: UUID(uuidString: "E7744FB8-6D21-4364-A000-000000000001") ?? UUID(),
            title: "Soothing Lullaby",
            artist: "Lulla",
            category: .lullabies,
            language: nil,
            duration: 300.0,  // 5 minutes of continuous lullaby
            ageRangeMin: 0,
            ageRangeMax: 36,
            optimalAgeMonths: Array(0...36),
            tempoBPM: 60,
            calmingScore: 0.95,  // Very high calming score
            isPremium: false,
            isDownloaded: true,  // Generated locally - always available!
            audioSourceType: .generated,  // CRITICAL: Use generated audio for reliability
            generatorType: .lullaby,  // Gentle lullaby melody
            fileName: nil,
            fileExtension: nil,
            streamURL: nil,
            serverId: "default-emergency-generated",
            artworkURL: nil,
            isLocked: false
        )
    }

    /// Alternative emergency track using Music Box sound
    /// Can be used if lullaby doesn't suit the baby's preference
    static func alternativeEmergencyTrack() -> AudioTrack {
        return AudioTrack(
            id: UUID(uuidString: "E7744FB8-6D21-4364-A000-000000000002") ?? UUID(),
            title: "Music Box",
            artist: "Lulla",
            category: .lullabies,
            language: nil,
            duration: 300.0,
            ageRangeMin: 0,
            ageRangeMax: 36,
            optimalAgeMonths: Array(0...36),
            tempoBPM: 50,
            calmingScore: 0.92,
            isPremium: false,
            isDownloaded: true,
            audioSourceType: .generated,
            generatorType: .musicBox,
            fileName: nil,
            fileExtension: nil,
            streamURL: nil,
            serverId: "default-emergency-musicbox",
            artworkURL: nil,
            isLocked: false
        )
    }
}

// MARK: - Audio Source Type
enum AudioSourceType: String, Codable {
    case generated      // Synthesized audio (womb sounds, heartbeat, etc.)
    case bundled        // Bundled royalty-free audio files
    case streamed       // Streamed from royalty-free sources
    case textToSpeech   // Generated using text-to-speech for stories
}

// MARK: - Generator Type (for synthesized audio)
// ⚠️ WHITE NOISE REMOVED: User feedback indicates white noise is SCARY for babies!
// Only gentle, melodic sounds remain.
enum GeneratorType: String, Codable, CaseIterable {
    // Nature-like sounds (ONLY gentle - NO rain/thunder/wind/noise!)
    case ocean = "Ocean Waves"
    case river = "River Stream"
    case birds = "Birds Chirping"
    case crickets = "Crickets"
    case fireplace = "Fireplace"
    case forest = "Forest Ambience"
    case waterfall = "Waterfall"
    case campfire = "Campfire Night"

    // Baby-specific sounds (gentle only - NO harsh mechanical sounds!)
    case heartbeat = "Heartbeat"
    case womb = "Womb Sounds"
    case shushing = "Shushing"
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
        case .ocean, .river, .birds, .crickets, .fireplace,
             .forest, .waterfall, .campfire:
            return .natureSounds
        case .heartbeat, .womb, .shushing, .aquarium:
            return .ambient
        case .lullaby, .musicBox, .chimes, .bells, .softPiano, .gentleGuitar:
            return .instrumental
        }
    }

    var defaultDuration: TimeInterval {
        return 3600 // 1 hour default for generated sounds
    }

    var optimalAgeRange: ClosedRange<Int> {
        switch self {
        case .womb, .heartbeat, .shushing:
            return 0...6
        case .ocean, .river:
            return 3...36
        case .birds, .crickets:
            return 6...36
        case .forest, .waterfall, .campfire:
            return 12...36 // More complex sounds for older babies
        case .lullaby, .musicBox:
            return 0...24
        case .chimes, .bells:
            return 3...36
        case .softPiano, .gentleGuitar:
            return 9...36 // Musical instruments for older babies
        case .fireplace:
            return 6...36
        case .aquarium:
            return 6...36 // Gentle bubbling works for many ages
        }
    }

    var calmingScore: Double {
        switch self {
        case .womb, .heartbeat: return 0.95
        case .shushing: return 0.92
        case .ocean: return 0.90
        case .lullaby, .musicBox: return 0.85
        case .softPiano: return 0.88
        case .gentleGuitar: return 0.86
        case .river: return 0.85
        case .forest: return 0.87 // Rich nature soundscape
        case .waterfall: return 0.86 // Consistent flowing water
        case .campfire: return 0.84 // Crackling with night ambience
        case .birds, .crickets: return 0.75
        case .chimes, .bells: return 0.82
        case .fireplace: return 0.78
        case .aquarium: return 0.85 // Gentle bubbles
        }
    }

    // MARK: - Scientific Research Backing
    /// Research-backed explanation of why this sound works for baby soothing
    var scientificRationale: String {
        switch self {
        case .ocean:
            return "Ocean waves create predictable rhythmic patterns at 12-14 cycles/minute matching relaxed breathing. Shown to synchronize brainwaves to theta state."
        case .river:
            return "Continuous water flow provides consistent masking without sudden changes. Water sounds activate parasympathetic response (Alvarsson et al., 2010)."
        case .birds:
            return "Birdsong signals safety in evolutionary terms ('safe environment' hypothesis). Best for daytime calming rather than sleep induction."
        case .crickets:
            return "Cricket sounds have regular rhythmic patterns at 2-4Hz matching relaxed delta brainwaves. Effective for older toddlers familiar with outdoor sounds."
        case .fireplace:
            return "Fire crackling provides random but gentle sound variations. Creates sense of warmth/security. Best combined with low-frequency ambient."
        case .forest:
            return "Complex forest ambience with layered sounds. Research shows 20+ minutes of nature sounds reduces anxiety by 33% (Largo-Wright et al., 2016)."
        case .waterfall:
            return "Waterfalls produce gentle broadband sounds with natural variation. Effective for extended masking without auditory fatigue."
        case .campfire:
            return "Combines fire crackle with night ambience. Multiple studies show fire sounds activate ancient 'safety' responses in humans."
        case .heartbeat:
            return "Heartbeat at 60-80 BPM mimics intrauterine environment. Reduces crying by 54% in newborns (Rosner & Doherty, 1979). Most effective 0-3 months."
        case .womb:
            return "Womb sounds combine heartbeat, blood flow, and muffled sounds. Studies show 90% of newborns calm within 3 minutes (Mirmiran et al., 2003)."
        case .shushing:
            return "Shushing recreates intrauterine blood flow sounds at 70-90dB. Dr. Harvey Karp's 5 S's research shows it activates calming reflex in 0-4 month babies."
        case .aquarium:
            return "Bubble sounds create gentle, random patterns. Visual + auditory combination in real aquariums reduces anxiety by 17% (Edwards & Beck, 2002)."
        case .lullaby:
            return "Lullabies in 6/8 time at 60-80 BPM match rocking motion. Cross-cultural research shows specific melodic contours universal for infant calming."
        case .musicBox:
            return "Music box tones in 440-880Hz range are non-threatening. Predictable melody + novel timbres capture attention then soothe. Classic for 3-12 months."
        case .chimes:
            return "Wind chimes provide gentle, intermittent high-frequency tones. Creates auditory interest without overstimulation. Best for alert-calm states."
        case .bells:
            return "Soft bells create resonant harmonics that naturally decay. The fade-out pattern mirrors breathing and promotes relaxation."
        case .softPiano:
            return "Solo piano at 60-80 BPM with simple melodies reduces cortisol. Classical music exposure linked to improved spatial-temporal reasoning."
        case .gentleGuitar:
            return "Acoustic guitar's warm harmonics in 200-2000Hz range are non-fatiguing. Fingerpicking patterns at 60 BPM match resting heart rate."
        }
    }

    /// Best cry type this sound helps with (based on research)
    var bestForCryTypes: [CryType] {
        switch self {
        case .womb, .heartbeat:
            return [.tired, .general, .discomfort]
        case .shushing:
            return [.hunger, .tired, .attention]
        case .ocean, .river:
            return [.tired, .attention]
        case .musicBox, .lullaby:
            return [.attention, .tired]
        case .softPiano, .gentleGuitar:
            return [.attention, .tired]
        case .aquarium:
            return [.tired, .general]
        default:
            return [.general]
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        // Nature-like sounds
        case .ocean: return "water.waves"
        case .river: return "drop.triangle"
        case .birds: return "bird"
        case .crickets: return "ant"
        case .fireplace: return "flame"
        case .forest: return "tree"
        case .waterfall: return "arrow.down.to.line"
        case .campfire: return "flame.fill"

        // Baby-specific sounds
        case .heartbeat: return "heart.fill"
        case .womb: return "circle.circle"
        case .shushing: return "mouth"
        case .aquarium: return "drop.halffull"

        // Musical tones
        case .lullaby: return "music.note"
        case .musicBox: return "music.note.house"
        case .chimes: return "bell"
        case .bells: return "bell.fill"
        case .softPiano: return "pianokeys"
        case .gentleGuitar: return "guitars"
        }
    }

    /// Short name for compact UI display (buttons, chips)
    var shortName: String {
        switch self {
        // Nature-like sounds
        case .ocean: return "Ocean"
        case .river: return "River"
        case .birds: return "Birds"
        case .crickets: return "Crickets"
        case .fireplace: return "Fire"
        case .forest: return "Forest"
        case .waterfall: return "Falls"
        case .campfire: return "Camp"

        // Baby-specific sounds
        case .heartbeat: return "Heart"
        case .womb: return "Womb"
        case .shushing: return "Shush"
        case .aquarium: return "Aqua"

        // Musical tones
        case .lullaby: return "Lullaby"
        case .musicBox: return "Music"
        case .chimes: return "Chimes"
        case .bells: return "Bells"
        case .softPiano: return "Piano"
        case .gentleGuitar: return "Guitar"
        }
    }

    /// Research citations for this sound type
    var researchCitations: [String] {
        switch self {
        case .womb, .heartbeat:
            return [
                "Mirmiran et al. (2003) - Intrauterine sounds and NICU outcomes",
                "Rosner & Doherty (1979) - Heartbeat sounds reduce newborn crying"
            ]
        case .shushing:
            return [
                "Karp, H. (2002) - The Happiest Baby on the Block",
                "Barr et al. (2006) - Effectiveness of infant soothing techniques"
            ]
        case .ocean, .river, .forest:
            return [
                "Gould van Praag et al. (2017) - Nature sounds and physiological stress reduction",
                "Alvarsson et al. (2010) - Stress recovery during nature sound exposure"
            ]
        default:
            return ["General pediatric sleep research and clinical observations"]
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

    // MARK: - Smart Queue Properties (Unified Player Architecture)
    /// Enable Spotify-style auto-replenishing queue (infinite playback)
    var isAutoReplenishing: Bool = false
    /// Minimum tracks in queue before triggering replenishment
    var minQueueSize: Int = 0
    /// Generation context for smart replenishment
    var generationContext: PlaylistGenerationMetadata?

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
        updatedAt: Date? = nil,
        isAutoReplenishing: Bool = false,
        minQueueSize: Int = 0,
        generationContext: PlaylistGenerationMetadata? = nil
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
        self.isAutoReplenishing = isAutoReplenishing
        self.minQueueSize = minQueueSize
        self.generationContext = generationContext
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
enum LocalPlaybackState: Equatable {
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

// MARK: - Playlist Generation Metadata (Unified Architecture)

/// Metadata for smart playlist auto-replenishment
/// Stores context needed to generate more tracks when queue runs low
struct PlaylistGenerationMetadata: Codable, Equatable, Hashable {
    let babyAge: Int
    let cryType: CryType?
    let language: String
    let allowGenerated: Bool  // Allow AI-generated sounds vs library-only

    init(
        babyAge: Int,
        cryType: CryType? = nil,
        language: String = "en",
        allowGenerated: Bool = true
    ) {
        self.babyAge = babyAge
        self.cryType = cryType
        self.language = language
        self.allowGenerated = allowGenerated
    }
}
