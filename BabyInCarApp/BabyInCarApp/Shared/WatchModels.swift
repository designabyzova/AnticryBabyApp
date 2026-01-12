import Foundation

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

/// Cry detection alert sent from iPhone to Watch
struct CryAlert: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let cryType: CryType
    let confidence: Double
    let suggestedAction: String
    let suggestedPlaylistId: String?

    init(cryType: CryType, confidence: Double, suggestedAction: String, suggestedPlaylistId: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.cryType = cryType
        self.confidence = confidence
        self.suggestedAction = suggestedAction
        self.suggestedPlaylistId = suggestedPlaylistId
    }
}

/// Cry types detected by the ML model
/// Note: This is shared between iPhone and Watch
enum CryType: String, Codable, CaseIterable, Hashable {
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
        case .hunger: return "Baby might be hungry. Consider feeding."
        case .tired: return "Baby seems tired. Try soothing lullabies."
        case .pain: return "Baby may be in discomfort. Check diaper or temperature."
        case .attention: return "Baby wants attention. Try gentle interaction."
        case .discomfort: return "Baby is uncomfortable. Check clothing or position."
        case .general: return "Try playing calming music."
        case .unknown: return "Play soothing sounds to calm baby."
        }
    }

    /// Recommended soothing strategy for this cry type
    var soothingStrategy: SoothingStrategy {
        switch self {
        case .hunger:
            return .distraction // Temporary until feeding
        case .tired:
            return .sleepInduction
        case .pain:
            return .urgent // Needs attention first
        case .attention:
            return .comfort
        case .discomfort:
            return .gentle
        case .general:
            return .adaptive
        case .unknown:
            return .adaptive
        }
    }
}

// MARK: - Soothing Strategy
enum SoothingStrategy: String, Codable {
    case sleepInduction = "Sleep Induction"
    case distraction = "Distraction"
    case comfort = "Comfort"
    case gentle = "Gentle Calming"
    case urgent = "Urgent Response"
    case adaptive = "Adaptive"

    var phases: [SoothingPhase] {
        switch self {
        case .sleepInduction:
            return [.gentleStart, .deepCalming, .sleepTransition]
        case .distraction:
            return [.attentionGrab, .engagement, .gentleCalm]
        case .comfort:
            return [.warmStart, .steadyComfort, .maintenance]
        case .gentle:
            return [.softStart, .gradualCalming, .maintenance]
        case .urgent:
            return [.immediateResponse, .intensiveCalming, .recovery]
        case .adaptive:
            return [.attentionGrab, .evaluation, .adaptiveResponse]
        }
    }
}

enum SoothingPhase: String {
    case gentleStart = "Gentle Start"
    case attentionGrab = "Getting Attention"
    case warmStart = "Warm Start"
    case softStart = "Soft Start"
    case immediateResponse = "Immediate Response"
    case deepCalming = "Deep Calming"
    case sleepTransition = "Sleep Transition"
    case engagement = "Engagement"
    case gentleCalm = "Gentle Calm"
    case steadyComfort = "Steady Comfort"
    case maintenance = "Maintenance"
    case gradualCalming = "Gradual Calming"
    case intensiveCalming = "Intensive Calming"
    case recovery = "Recovery"
    case evaluation = "Evaluation"
    case adaptiveResponse = "Adaptive Response"
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
    // New commands for Library and Emergency
    case playCategory(categoryId: String)
    case startEmergencyMode           // Start emergency mode with cry detection + music
    case startEmergencyModeWithCryDetection  // Explicitly start cry detection monitoring
    case stopEmergencyMode
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
        case "startEmergencyMode": self = .startEmergencyMode
        case "startEmergencyModeWithCryDetection": self = .startEmergencyModeWithCryDetection
        case "stopEmergencyMode": self = .stopEmergencyMode
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
        case .startEmergencyMode:
            try container.encode("startEmergencyMode", forKey: .type)
        case .startEmergencyModeWithCryDetection:
            try container.encode("startEmergencyModeWithCryDetection", forKey: .type)
        case .stopEmergencyMode:
            try container.encode("stopEmergencyMode", forKey: .type)
        case .requestLibrarySync:
            try container.encode("requestLibrarySync", forKey: .type)
        }
    }
}

/// Message types for WatchConnectivity
enum WatchMessage: String {
    case playbackState = "playbackState"
    case command = "command"
    case cryAlert = "cryAlert"
    case favoritesUpdate = "favoritesUpdate"
    case fileTransferComplete = "fileTransferComplete"
    case requestSync = "requestSync"
    case libraryState = "libraryState"
    case emergencyState = "emergencyState"
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

extension CryAlert {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
