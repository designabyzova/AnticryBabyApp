//
//  AudioTrack.swift
//  BabyInCarApp
//
//  Data model for audio tracks - uses royalty-free audio sources
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Audio Category
enum AudioCategory: String, CaseIterable, Identifiable {
    case classicalMusic = "Classical Music"
    case fairyTales = "Fairy Tales"
    case natureSounds = "Nature Sounds"
    case instrumental = "Instrumental"
    case childrenSongs = "Children's Songs"
    case podcasts = "Podcasts"
    case lullabies = "Lullabies"
    case ambient = "Ambient"

    var id: String { rawValue }

    // MARK: - JSON Key Mapping
    // Maps JSON category values (snake_case) to enum cases
    private static let jsonKeyMap: [String: AudioCategory] = [
        // Direct matches
        "lullabies": .lullabies,
        "ambient": .ambient,
        "classical": .classicalMusic,
        "classical_music": .classicalMusic,
        "nature": .natureSounds,
        "nature_sounds": .natureSounds,
        "instrumental": .instrumental,
        "modern_piano": .instrumental,  // Modern piano maps to instrumental
        "podcasts": .podcasts,
        "children_songs": .childrenSongs,
        // Fairy tales (multiple languages)
        "fairytales": .fairyTales,
        "fairytales_en": .fairyTales,
        "fairytales_ru": .fairyTales,
        "fairytales_es": .fairyTales,
        "fairytales_de": .fairyTales,
        "fairytales_fr": .fairyTales,
        // Legacy/alternative names
        "Classical Music": .classicalMusic,
        "Fairy Tales": .fairyTales,
        "Nature Sounds": .natureSounds,
        "Instrumental": .instrumental,
        "Children's Songs": .childrenSongs,
        "Podcasts": .podcasts,
        "Lullabies": .lullabies,
        "Ambient": .ambient
    ]

    /// Initialize from JSON category string
    static func fromJSONKey(_ key: String) -> AudioCategory {
        return jsonKeyMap[key] ?? jsonKeyMap[key.lowercased()] ?? .instrumental
    }
}

// MARK: - AudioCategory Codable
extension AudioCategory: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self = AudioCategory.fromJSONKey(stringValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

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

    var displayName: String {
        rawValue
    }

    var iconName: String {
        icon
    }

    var gradientStart: Color {
        switch self {
        case .classicalMusic:
            return Color(red: 0.4, green: 0.2, blue: 0.8) // Purple
        case .fairyTales:
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Pink
        case .natureSounds:
            return Color(red: 0.2, green: 0.7, blue: 0.4) // Green
        case .instrumental:
            return Color(red: 0.9, green: 0.5, blue: 0.2) // Orange
        case .childrenSongs:
            return Color(red: 0.3, green: 0.6, blue: 0.9) // Blue
        case .podcasts:
            return Color(red: 0.7, green: 0.3, blue: 0.5) // Magenta
        case .lullabies:
            return Color(red: 0.5, green: 0.3, blue: 0.8) // Violet
        case .ambient:
            return Color(red: 0.2, green: 0.5, blue: 0.7) // Teal
        }
    }

    var gradientEnd: Color {
        switch self {
        case .classicalMusic:
            return Color(red: 0.6, green: 0.3, blue: 0.9)
        case .fairyTales:
            return Color(red: 1.0, green: 0.6, blue: 0.8)
        case .natureSounds:
            return Color(red: 0.4, green: 0.9, blue: 0.6)
        case .instrumental:
            return Color(red: 1.0, green: 0.7, blue: 0.4)
        case .childrenSongs:
            return Color(red: 0.5, green: 0.8, blue: 1.0)
        case .podcasts:
            return Color(red: 0.9, green: 0.5, blue: 0.7)
        case .lullabies:
            return Color(red: 0.7, green: 0.5, blue: 1.0)
        case .ambient:
            return Color(red: 0.4, green: 0.7, blue: 0.9)
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
    case ukrainian = "Ukrainian"
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
        case .ukrainian: return "🇺🇦"
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
        case .ukrainian: return "uk"
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

    // Searchable tags (from tracks.json)
    var tags: [String]

    // Subcategory for finer classification
    var subcategory: String?

    // Cry type suitability scores (0.0 - 1.0) for smart playlist generation
    // Example: {"hunger": 0.8, "tired": 0.95, "pain": 0.6}
    var crySuitability: [String: Double]?

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
        isLocked: Bool = false,
        tags: [String] = [],
        subcategory: String? = nil,
        crySuitability: [String: Double]? = nil
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
        self.tags = tags
        self.subcategory = subcategory
        self.crySuitability = crySuitability
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

    /// Get suitability score for a specific cry type (0.0 - 1.0)
    /// Falls back to calmingScore * 0.7 if no cry-specific data available
    func suitabilityFor(_ cryType: CryType) -> Double {
        // First check explicit crySuitability scores
        if let scores = crySuitability, let score = scores[cryType.rawValue] {
            return score
        }

        // For generated sounds, check GeneratorType.bestForCryTypes
        if let generator = generatorType {
            if generator.bestForCryTypes.contains(cryType) {
                return generator.calmingScore
            } else {
                return generator.calmingScore * 0.6 // Lower score for non-optimal cry types
            }
        }

        // Fall back to calmingScore with a reduction factor
        return calmingScore * 0.7
    }

    /// Check if track is suitable for a given cry type (score >= threshold)
    func isSuitable(for cryType: CryType, threshold: Double = 0.7) -> Bool {
        return suitabilityFor(cryType) >= threshold
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
    /// Returns the default emergency track - REAL "Pianomoment" by Bensound from R2
    /// User preference: Real piano music, NOT AI-generated sounds
    /// NOTE: This requires network for first play but provides real music quality
    static func defaultEmergencyTrack() -> AudioTrack {
        // Real track from tracks.json: Pianomoment by Bensound
        // ID: 00c5de7b-c5bd-4214-9281-26ab232a64d8
        // Filename: ambient/bensound_pianomoment.mp3
        return AudioTrack(
            id: UUID(uuidString: "00c5de7b-c5bd-4214-9281-26ab232a64d8") ?? UUID(),
            title: "Pianomoment",
            artist: "Bensound",
            category: .ambient,
            language: nil,
            duration: 114.0,  // Real duration from tracks.json
            ageRangeMin: 0,
            ageRangeMax: 36,
            optimalAgeMonths: Array(0...36),
            tempoBPM: 60,
            calmingScore: 0.85,  // From tracks.json
            isPremium: false,
            isDownloaded: false,  // Streamed from R2
            audioSourceType: .streamed,  // REAL audio from R2 CDN
            generatorType: nil,  // NOT generated!
            fileName: nil,
            fileExtension: nil,
            streamURL: "https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/ambient/bensound_pianomoment.mp3",
            serverId: "00c5de7b-c5bd-4214-9281-26ab232a64d8",
            artworkURL: nil,
            isLocked: false,
            tags: ["ambient", "relaxing"],
            subcategory: "ambient"
        )
    }

    /// Alternative emergency track - REAL "Relaxing" by Bensound from R2
    /// Provides variety when Pianomoment doesn't suit the baby's preference
    static func alternativeEmergencyTrack() -> AudioTrack {
        // Real track from tracks.json: Relaxing by Bensound
        // ID: 2921bbe9-37f9-49fd-ab5a-b3afa9886214
        // Filename: ambient/bensound_relaxing.mp3
        return AudioTrack(
            id: UUID(uuidString: "2921bbe9-37f9-49fd-ab5a-b3afa9886214") ?? UUID(),
            title: "Relaxing",
            artist: "Bensound",
            category: .ambient,
            language: nil,
            duration: 288.1,  // Real duration from tracks.json
            ageRangeMin: 0,
            ageRangeMax: 36,
            optimalAgeMonths: Array(0...36),
            tempoBPM: 60,
            calmingScore: 0.85,  // From tracks.json
            isPremium: false,
            isDownloaded: false,  // Streamed from R2
            audioSourceType: .streamed,  // REAL audio from R2 CDN
            generatorType: nil,  // NOT generated!
            fileName: nil,
            fileExtension: nil,
            streamURL: "https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/ambient/bensound_relaxing.mp3",
            serverId: "2921bbe9-37f9-49fd-ab5a-b3afa9886214",
            artworkURL: nil,
            isLocked: false,
            tags: ["ambient", "relaxing"],
            subcategory: "ambient"
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
// ⚠️ WHITE NOISE AND NATURE SOUNDS REMOVED: User feedback indicates they are TOO NOISY for babies!
// Only gentle, melodic musical sounds remain.
// REMOVED (2026-01-09): ocean, forest, waterfall, campfire, birds, crickets, fireplace, river
// These sounds have unpredictable volume variations that startle babies.
enum GeneratorType: String, Codable, CaseIterable {
    // Baby-specific sounds (gentle only - NO harsh/variable sounds!)
    case heartbeat = "Heartbeat"
    case womb = "Womb Sounds"
    case shushing = "Shushing"
    case aquarium = "Aquarium Bubbles"

    // Musical tones (consistent, predictable, soothing)
    case lullaby = "Lullaby Melody"
    case musicBox = "Music Box"
    case chimes = "Wind Chimes"
    case bells = "Soft Bells"
    case softPiano = "Soft Piano"
    case gentleGuitar = "Gentle Guitar"

    var category: AudioCategory {
        switch self {
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
        case .lullaby, .musicBox:
            return 0...24
        case .chimes, .bells:
            return 3...36
        case .softPiano, .gentleGuitar:
            return 6...36 // Musical instruments for slightly older babies
        case .aquarium:
            return 6...36 // Gentle bubbling works for many ages
        }
    }

    var calmingScore: Double {
        switch self {
        case .womb, .heartbeat: return 0.95
        case .shushing: return 0.92
        case .softPiano: return 0.90
        case .gentleGuitar: return 0.88
        case .lullaby, .musicBox: return 0.87
        case .aquarium: return 0.85 // Gentle bubbles
        case .chimes, .bells: return 0.84
        }
    }

    // MARK: - Scientific Research Backing
    /// Research-backed explanation of why this sound works for baby soothing
    var scientificRationale: String {
        switch self {
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
        case .musicBox, .lullaby:
            return [.attention, .tired]
        case .softPiano, .gentleGuitar:
            return [.attention, .tired]
        case .aquarium:
            return [.tired, .general]
        case .chimes, .bells:
            return [.attention, .general]
        }
    }

    /// Cry suitability scores for smart playlist generation
    /// Returns a dictionary mapping cry type string to suitability score (0.0 - 1.0)
    var crySuitabilityScores: [String: Double] {
        // Base score is calmingScore reduced to allow room for differentiation
        let baseScore = calmingScore * 0.6

        // Define scores for all standard cry types
        var scores: [String: Double] = [
            CryType.hunger.rawValue: baseScore,
            CryType.tired.rawValue: baseScore,
            CryType.pain.rawValue: baseScore * 0.8,  // Pain requires special handling, lower default
            CryType.attention.rawValue: baseScore,
            CryType.discomfort.rawValue: baseScore,
            CryType.general.rawValue: baseScore
        ]

        // Boost scores for cry types this sound is best for
        for cryType in bestForCryTypes {
            scores[cryType.rawValue] = calmingScore  // Full calming score for best-fit types
        }

        // Clamp all values to 0.0 - 1.0
        return scores.mapValues { min(1.0, max(0.0, $0)) }
    }

    /// Get suitability score for a specific cry type
    func suitabilityFor(_ cryType: CryType) -> Double {
        return crySuitabilityScores[cryType.rawValue] ?? calmingScore * 0.5
    }

    /// Icon for UI display
    var icon: String {
        switch self {
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
        case .softPiano, .gentleGuitar:
            return [
                "Standley (2002) - Music therapy for premature infants in NICU",
                "Loewy et al. (2013) - Live music therapy reduces stress in premature infants"
            ]
        case .lullaby, .musicBox:
            return [
                "Trainor (2015) - Lullabies and infant-directed singing",
                "Trehub et al. (1993) - Maternal singing maintains infant attention"
            ]
        case .aquarium, .chimes, .bells:
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
        case preferredSleepTimerMinutes, enableVoiceControl
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

