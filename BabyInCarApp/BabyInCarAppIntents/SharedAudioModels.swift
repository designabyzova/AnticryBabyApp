//
//  SharedAudioModels.swift
//  BabyInCarAppIntents
//
//  Lightweight models shared between main app and Intents Extension.
//  These models avoid importing heavy frameworks (SwiftUI, AVFoundation)
//  to keep extension memory footprint small.
//
//  NOTE: This is a minimal subset for intent handling.
//  The main app has the full AudioTrack model with all features.
//

import Foundation

/// Lightweight category representation for intent handling
/// Matches AudioCategory.rawValue from main app
enum IntentAudioCategory: String {
    case classicalMusic = "Classical Music"
    case fairyTales = "Fairy Tales"
    case natureSounds = "Nature Sounds"
    case instrumental = "Instrumental"
    case childrenSongs = "Children's Songs"
    case podcasts = "Podcasts"
    case lullabies = "Lullabies"
    case ambient = "Ambient"

    /// For passing to main app via user activity
    var identifier: String {
        switch self {
        case .classicalMusic: return "classicalMusic"
        case .fairyTales: return "fairyTales"
        case .natureSounds: return "natureSounds"
        case .instrumental: return "instrumental"
        case .childrenSongs: return "childrenSongs"
        case .podcasts: return "podcasts"
        case .lullabies: return "lullabies"
        case .ambient: return "ambient"
        }
    }
}

/// Intent action types for main app routing
/// NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter, not intents
enum IntentAction: String {
    case playCategory
    case search
    case emergency
    case addToFavorites
}

/// Shared user activity type identifiers
/// NOTE: Pause/Resume/Skip are handled by MPRemoteCommandCenter, not user activities
struct IntentActivityType {
    static let playMedia = "com.soothbee.playMedia"
    static let searchMedia = "com.soothbee.searchMedia"
    static let addToFavorites = "com.soothbee.addToFavorites"
}
