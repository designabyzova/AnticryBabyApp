import Foundation

// MARK: - Baby Mood Types (Manual Selection)

/// Baby mood types for manual user selection and track recommendations.
/// Users can optionally specify the baby's mood when providing feedback
/// about whether a track helped calm their baby.
///
/// NOTE: This is purely for manual user input - there is NO automatic detection.
/// The app does NOT listen to or analyze baby sounds.
typealias CryType = MoodType

enum MoodType: String, Codable, CaseIterable, Hashable {
    case hunger = "hunger"
    case tired = "tired"
    case pain = "pain"
    case attention = "attention"
    case discomfort = "discomfort"
    case general = "general"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .hunger: return "Hungry"
        case .tired: return "Tired"
        case .pain: return "Pain/Discomfort"
        case .attention: return "Needs Attention"
        case .discomfort: return "Uncomfortable"
        case .general: return "General Fussiness"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .hunger: return "fork.knife"
        case .tired: return "moon.zzz"
        case .pain: return "cross.case"
        case .attention: return "hand.raised"
        case .discomfort: return "thermometer"
        case .general: return "figure.wave"
        case .unknown: return "questionmark.circle"
        }
    }

    var suggestedAction: String {
        switch self {
        case .hunger: return "Try feeding"
        case .tired: return "Try calming sounds"
        case .pain: return "Check for discomfort"
        case .attention: return "Give comfort"
        case .discomfort: return "Check temperature/diaper"
        case .general: return "Try soothing music"
        case .unknown: return "General soothing"
        }
    }
}

// MARK: - Shared Models for iPhone-Watch Communication

/// Represents a track that can be synced and played on Apple Watch
struct WatchTrack: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let category: String
    var localURL: URL?  // Set on watch after file transfer
    var artworkData: Data?
    var isSynced: Bool = false

    init(id: String, title: String, artist: String, duration: TimeInterval, category: String, localURL: URL? = nil, artworkData: Data? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.category = category
        self.localURL = localURL
        self.artworkData = artworkData
    }
}

/// Current playback state synchronized between iPhone and Watch
struct PlaybackState: Codable, Equatable {
    let isPlaying: Bool
    let currentTrackId: String?
    let currentTrackTitle: String?
    let currentTrackArtist: String?
    let progress: Double  // 0.0 - 1.0
    let volume: Float     // 0.0 - 1.0
    let sleepTimerRemaining: TimeInterval?
    let timestamp: Date

    static let idle = PlaybackState(
        isPlaying: false,
        currentTrackId: nil,
        currentTrackTitle: nil,
        currentTrackArtist: nil,
        progress: 0,
        volume: 0.5,
        sleepTimerRemaining: nil,
        timestamp: Date()
    )
}


/// Commands sent from Watch to iPhone
enum WatchCommand: Codable, Equatable {
    case play
    case pause
    case togglePlayPause
    case skipNext
    case skipPrevious
    case setVolume(Float)
    case setSleepTimer(minutes: Int)
    case cancelSleepTimer
    case startSoothingMusic(playlistId: String?)
    case requestStateSync
    case playTrack(trackId: String)
    case playCategory(categoryId: String)
    case requestLibrarySync

    // Custom coding for associated values
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "play": self = .play
        case "pause": self = .pause
        case "togglePlayPause": self = .togglePlayPause
        case "skipNext": self = .skipNext
        case "skipPrevious": self = .skipPrevious
        case "setVolume":
            let volume = try container.decode(Float.self, forKey: .value)
            self = .setVolume(volume)
        case "setSleepTimer":
            let minutes = try container.decode(Int.self, forKey: .value)
            self = .setSleepTimer(minutes: minutes)
        case "cancelSleepTimer": self = .cancelSleepTimer
        case "startSoothingMusic":
            let playlistId = try container.decodeIfPresent(String.self, forKey: .value)
            self = .startSoothingMusic(playlistId: playlistId)
        case "requestStateSync": self = .requestStateSync
        case "playTrack":
            let trackId = try container.decode(String.self, forKey: .value)
            self = .playTrack(trackId: trackId)
        case "playCategory":
            let categoryId = try container.decode(String.self, forKey: .value)
            self = .playCategory(categoryId: categoryId)
        case "requestLibrarySync": self = .requestLibrarySync
        default:
            self = .requestStateSync
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .play:
            try container.encode("play", forKey: .type)
        case .pause:
            try container.encode("pause", forKey: .type)
        case .togglePlayPause:
            try container.encode("togglePlayPause", forKey: .type)
        case .skipNext:
            try container.encode("skipNext", forKey: .type)
        case .skipPrevious:
            try container.encode("skipPrevious", forKey: .type)
        case .setVolume(let volume):
            try container.encode("setVolume", forKey: .type)
            try container.encode(volume, forKey: .value)
        case .setSleepTimer(let minutes):
            try container.encode("setSleepTimer", forKey: .type)
            try container.encode(minutes, forKey: .value)
        case .cancelSleepTimer:
            try container.encode("cancelSleepTimer", forKey: .type)
        case .startSoothingMusic(let playlistId):
            try container.encode("startSoothingMusic", forKey: .type)
            try container.encodeIfPresent(playlistId, forKey: .value)
        case .requestStateSync:
            try container.encode("requestStateSync", forKey: .type)
        case .playTrack(let trackId):
            try container.encode("playTrack", forKey: .type)
            try container.encode(trackId, forKey: .value)
        case .playCategory(let categoryId):
            try container.encode("playCategory", forKey: .type)
            try container.encode(categoryId, forKey: .value)
        case .requestLibrarySync:
            try container.encode("requestLibrarySync", forKey: .type)
        }
    }
}

/// Message types for WatchConnectivity
enum WatchMessage: String {
    case playbackState = "playbackState"
    case command = "command"
    case favoritesUpdate = "favoritesUpdate"
    case fileTransferComplete = "fileTransferComplete"
    case requestSync = "requestSync"
    case libraryState = "libraryState"
}

// MARK: - Watch Category for Library Sync
struct WatchCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let trackCount: Int
    let description: String

    init(id: String, name: String, icon: String, trackCount: Int, description: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.trackCount = trackCount
        self.description = description
    }
}

// MARK: - Watch Library State
struct WatchLibraryState: Codable {
    let categories: [WatchCategory]
    let recentTracks: [WatchTrack]
    let topCalmingTracks: [WatchTrack]
    let timestamp: Date

    static let empty = WatchLibraryState(
        categories: [],
        recentTracks: [],
        topCalmingTracks: [],
        timestamp: Date()
    )
}

// MARK: - Convenience Extensions

extension WatchTrack {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

