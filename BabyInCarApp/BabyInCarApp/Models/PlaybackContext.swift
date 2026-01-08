//
//  PlaybackContext.swift
//  BabyInCarApp
//
//  Unified playback context system - Spotify-style smart playlists
//  Replaces dual AudioEngine/SmartEmergencyQueue architecture with single unified system
//

import Foundation
import SwiftUI

/// Playback context defines WHY audio is playing and HOW the UI should adapt
/// This enables single player with context-aware UI (purple for emergency, green for library)
enum PlaybackContext: Equatable, Hashable {
    /// Normal library browsing - user selected track/playlist manually
    case library(source: String)

    /// Emergency cry response - baby crying NOW, need immediate calming
    case emergencyCry(type: CryType, babyAge: Int)

    /// Ambient monitoring mode - proactive background music while monitoring
    case ambientMonitoring(babyAge: Int)

    /// AI-powered recommendations - "More Like This" or discovery
    case aiRecommendations(basedOn: UUID)

    /// CarPlay initiated playback
    case carPlay

    // MARK: - Context Properties

    /// Display name for session
    var displayName: String {
        switch self {
        case .library(let source):
            return source
        case .emergencyCry(let type, _):
            return "Emergency: \(type.displayName)"
        case .ambientMonitoring:
            return "Ambient Monitoring"
        case .aiRecommendations:
            return "Smart Recommendations"
        case .carPlay:
            return "CarPlay"
        }
    }

    /// Whether auto-replenish should be enabled (Spotify-style infinite queue)
    var autoReplenishEnabled: Bool {
        switch self {
        case .emergencyCry, .ambientMonitoring:
            return true  // Keep playing until baby calms down
        case .library, .aiRecommendations, .carPlay:
            return false  // Play playlist as-is
        }
    }

    /// Minimum queue size before triggering replenishment
    var minQueueSize: Int {
        switch self {
        case .emergencyCry:
            return 3  // Always keep 3 tracks ahead (emergency)
        case .ambientMonitoring:
            return 5  // Longer buffer for background mode
        default:
            return 0  // No auto-replenish
        }
    }

    /// Whether this is high-priority playback (interrupts normal playback)
    var isHighPriority: Bool {
        switch self {
        case .emergencyCry:
            return true
        default:
            return false
        }
    }

    /// UI theme for player
    var theme: PlayerTheme {
        switch self {
        case .emergencyCry(let type, _):
            return .emergency(cryType: type)
        case .ambientMonitoring:
            return .ambient
        default:
            return .standard
        }
    }
}

/// UI theme for adaptive player
enum PlayerTheme: Equatable {
    case standard
    case emergency(cryType: CryType)
    case ambient

    /// Primary gradient colors
    var gradientColors: [Color] {
        switch self {
        case .standard:
            return [Color.green.opacity(0.6), Color.green.opacity(0.2)]
        case .emergency(let cryType):
            // Different purple shades based on cry type
            switch cryType {
            case .hunger:
                return [Color.orange.opacity(0.6), Color.orange.opacity(0.2)]
            case .tired:
                return [Color.purple.opacity(0.6), Color.purple.opacity(0.2)]
            case .pain:
                return [Color.red.opacity(0.5), Color.red.opacity(0.2)]
            default:
                return [Color.purple.opacity(0.6), Color.purple.opacity(0.2)]
            }
        case .ambient:
            return [Color.blue.opacity(0.5), Color.blue.opacity(0.2)]
        }
    }

    /// Primary accent color
    var accentColor: Color {
        switch self {
        case .standard:
            return .green
        case .emergency(let cryType):
            switch cryType {
            case .hunger: return .orange
            case .tired: return .purple
            case .pain: return .red
            default: return .purple
            }
        case .ambient:
            return .blue
        }
    }

    /// Whether to show emergency-specific controls
    var showEmergencyControls: Bool {
        if case .emergency = self {
            return true
        }
        return false
    }

    /// Whether to show AI reasoning card
    var showAIReasoning: Bool {
        if case .emergency = self {
            return true
        }
        return false
    }
}

/// Metadata for smart playlist generation
struct PlaylistGenerationContext {
    let babyAge: Int
    let cryType: CryType?
    let language: String
    let maxTracks: Int
    let allowGenerated: Bool  // Allow generated sounds vs library-only

    init(
        babyAge: Int,
        cryType: CryType? = nil,
        language: String = "en",
        maxTracks: Int = 30,
        allowGenerated: Bool = true
    ) {
        self.babyAge = babyAge
        self.cryType = cryType
        self.language = language
        self.maxTracks = maxTracks
        self.allowGenerated = allowGenerated
    }
}
