//
//  ActionCategory.swift
//  BabyInCarApp
//
//  Maps DeepInfant V2's 5 cry types to 3 actionable categories for playlist selection.
//  This simplifies the parent experience while maintaining model accuracy.
//

import Foundation

// MARK: - DeepInfantCryType

/// Raw cry types output by DeepInfant V2 model (5 classes)
enum DeepInfantCryType: String, Codable, CaseIterable {
    case hungry = "hungry"
    case needsBurping = "needs_burping"
    case bellyPain = "belly_pain"
    case discomfort = "discomfort"
    case tired = "tired"

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .hungry: return "Hungry"
        case .needsBurping: return "Needs Burping"
        case .bellyPain: return "Belly Pain"
        case .discomfort: return "Uncomfortable"
        case .tired: return "Tired"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .hungry: return "fork.knife"
        case .needsBurping: return "wind"
        case .bellyPain: return "stomach"
        case .discomfort: return "thermometer"
        case .tired: return "moon.zzz"
        }
    }

    /// Map to action category (5 → 3)
    var actionCategory: ActionCategory {
        ActionCategory.from(self)
    }
}

// MARK: - ActionCategory

/// Simplified action categories for playlist selection (3 categories)
///
/// Strategy: Keep DeepInfant's 5-class granularity for detection accuracy,
/// but map to 3 actionable categories for playlist selection.
///
/// Mapping:
/// - hungry → HUNGRY (Feed baby)
/// - needs_burping, belly_pain, discomfort → UNCOMFORTABLE (Check physical needs)
/// - tired → TIRED (Help baby sleep)
enum ActionCategory: String, Codable, CaseIterable {
    case hungry = "hungry"
    case uncomfortable = "uncomfortable"
    case tired = "tired"

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .hungry: return "Hungry"
        case .uncomfortable: return "Uncomfortable"
        case .tired: return "Tired"
        }
    }

    /// Short action description for parent
    var suggestedAction: String {
        switch self {
        case .hungry:
            return "Baby may be hungry - try feeding"
        case .uncomfortable:
            return "Baby seems uncomfortable - check diaper, temperature, or gas"
        case .tired:
            return "Baby is tired - try soothing to sleep"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .hungry: return "fork.knife"
        case .uncomfortable: return "hand.raised"
        case .tired: return "moon.zzz"
        }
    }

    /// Color for UI (system color names)
    var colorName: String {
        switch self {
        case .hungry: return "orange"
        case .uncomfortable: return "red"
        case .tired: return "purple"
        }
    }

    // MARK: - Playlist Mapping

    /// Playlist category ID for this action
    var playlistCategory: String {
        switch self {
        case .hungry: return "distraction"
        case .uncomfortable: return "soothing"
        case .tired: return "lullaby"
        }
    }

    /// Playlist description
    var playlistDescription: String {
        switch self {
        case .hungry:
            return "Calming music to distract while feeding"
        case .uncomfortable:
            return "Gentle sounds to soothe discomfort"
        case .tired:
            return "Soft lullabies to help baby sleep"
        }
    }

    // MARK: - Factory Methods

    /// Map from DeepInfant V2 model output (5 classes) to action category (3)
    /// - Parameter cryType: Raw cry type from model
    /// - Returns: Simplified action category
    static func from(_ cryType: DeepInfantCryType) -> ActionCategory {
        switch cryType {
        case .hungry:
            return .hungry
        case .needsBurping, .bellyPain, .discomfort:
            return .uncomfortable
        case .tired:
            return .tired
        }
    }

    /// Map from legacy CryType/MoodType to action category
    /// - Parameter moodType: Legacy mood type
    /// - Returns: Simplified action category
    static func from(_ moodType: MoodType) -> ActionCategory {
        switch moodType {
        case .hunger:
            return .hungry
        case .pain, .discomfort, .attention:
            return .uncomfortable
        case .tired:
            return .tired
        case .general, .unknown:
            // Default to uncomfortable for general/unknown
            return .uncomfortable
        }
    }

    /// Map from string (API response) to action category
    /// - Parameter string: String representation
    /// - Returns: Action category or nil if invalid
    static func from(string: String) -> ActionCategory? {
        // Try direct match
        if let category = ActionCategory(rawValue: string.lowercased()) {
            return category
        }

        // Try mapping from DeepInfant type strings
        switch string.lowercased() {
        case "hungry", "hunger":
            return .hungry
        case "needs_burping", "needsburping", "burping", "belly_pain", "bellypain", "discomfort", "uncomfortable":
            return .uncomfortable
        case "tired", "sleepy", "fatigue":
            return .tired
        default:
            return nil
        }
    }
}

// MARK: - Classification Result with Action Category

/// Extended classification result including action category
struct DeepInfantClassificationResult: Equatable {
    /// Raw cry type from model (5 classes)
    let rawCryType: DeepInfantCryType

    /// Simplified action category (3 categories)
    let actionCategory: ActionCategory

    /// Confidence score (0.0 to 1.0)
    let confidence: Double

    /// All probabilities from model
    let probabilities: [DeepInfantCryType: Double]

    /// Timestamp of classification
    let timestamp: Date

    /// Whether confidence meets threshold
    var isConfident: Bool {
        confidence >= 0.70
    }

    /// Initialize with all properties
    init(
        rawCryType: DeepInfantCryType,
        confidence: Double,
        probabilities: [DeepInfantCryType: Double],
        timestamp: Date = Date()
    ) {
        self.rawCryType = rawCryType
        self.actionCategory = ActionCategory.from(rawCryType)
        self.confidence = confidence
        self.probabilities = probabilities
        self.timestamp = timestamp
    }

    /// Convenience initializer from model output strings
    init?(
        cryTypeString: String,
        confidence: Double,
        probabilityStrings: [String: Double],
        timestamp: Date = Date()
    ) {
        // Map string to DeepInfantCryType
        guard let cryType = DeepInfantCryType.allCases.first(where: {
            $0.rawValue.lowercased() == cryTypeString.lowercased()
        }) else {
            return nil
        }

        // Convert probability strings to typed dictionary
        var typedProbabilities: [DeepInfantCryType: Double] = [:]
        for (key, value) in probabilityStrings {
            if let type = DeepInfantCryType.allCases.first(where: {
                $0.rawValue.lowercased() == key.lowercased()
            }) {
                typedProbabilities[type] = value
            }
        }

        self.init(
            rawCryType: cryType,
            confidence: confidence,
            probabilities: typedProbabilities,
            timestamp: timestamp
        )
    }
}

// MARK: - Playlist Response Helper

/// Helper for selecting playlist based on action category
struct CryResponsePlaylist {
    let category: ActionCategory
    let playlistId: String
    let description: String

    /// Get recommended playlist for action category
    static func getPlaylist(for category: ActionCategory) -> CryResponsePlaylist {
        return CryResponsePlaylist(
            category: category,
            playlistId: category.playlistCategory,
            description: category.playlistDescription
        )
    }

    /// Get all available response playlists
    static var allPlaylists: [CryResponsePlaylist] {
        ActionCategory.allCases.map { getPlaylist(for: $0) }
    }
}
