import Foundation
import SwiftUI

/// Comprehensive tag system for multi-dimensional audio track filtering
/// Supports Spotify-level discovery with smart combinations and presets
struct FilterTag: Identifiable, Hashable, Codable {
    let id: UUID
    let type: FilterTagType
    let value: String
    let displayName: String
    let icon: String?
    let color: Color?

    init(
        id: UUID = UUID(),
        type: FilterTagType,
        value: String,
        displayName: String? = nil,
        icon: String? = nil,
        color: Color? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.displayName = displayName ?? value
        self.icon = icon
        self.color = color
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, type, value, displayName, icon, colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(FilterTagType.self, forKey: .type)
        value = try container.decode(String.self, forKey: .value)
        displayName = try container.decode(String.self, forKey: .displayName)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)

        if let hex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = Color(hex: hex)
        } else {
            color = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(color?.toHex(), forKey: .colorHex)
    }
}

/// Filter tag type hierarchy for multi-dimensional filtering
enum FilterTagType: String, Codable, CaseIterable {
    // Primary categorization
    case category       // Classical, Lullabies, Nature, etc.
    case subcategory    // Piano, Voice, Ocean, etc.

    // Content properties
    case instrument     // Piano, Guitar, Violin, Orchestra
    case mood           // Calming, Energetic, Playful, Soothing
    case tempo          // Slow (<60 BPM), Medium (60-120), Fast (>120)
    case theme          // Bedtime, Playtime, Learning, Magic

    // Metadata
    case language       // English, Russian, Spanish, etc.
    case ageRange       // 0-3mo, 3-6mo, 6-12mo, 12-24mo, 24-36mo
    case duration       // Short (<3min), Medium (3-10min), Long (>10min)

    // Taxonomy (backend-driven)
    case origin         // Russian Tales, English Classics, etc.
    case author         // Brothers Grimm, Afanasyev, Mozart, etc.
    case collection     // Album/collection name

    // Quality/Experience
    case calmingLevel   // Very Calming (0.8+), Calming (0.6-0.8), Moderate (<0.6)
    case contentType    // Music, Story, Sound, Podcast

    var displayName: String {
        switch self {
        case .category: return "Category"
        case .subcategory: return "Type"
        case .instrument: return "Instrument"
        case .mood: return "Mood"
        case .tempo: return "Tempo"
        case .theme: return "Theme"
        case .language: return "Language"
        case .ageRange: return "Age"
        case .duration: return "Duration"
        case .origin: return "Origin"
        case .author: return "Artist"
        case .collection: return "Collection"
        case .calmingLevel: return "Calming"
        case .contentType: return "Type"
        }
    }

    var icon: String {
        switch self {
        case .category: return "square.grid.2x2"
        case .subcategory: return "music.note.list"
        case .instrument: return "guitars"
        case .mood: return "face.smiling"
        case .tempo: return "metronome"
        case .theme: return "sparkles"
        case .language: return "globe"
        case .ageRange: return "figure.2.and.child.holdinghands"
        case .duration: return "clock"
        case .origin: return "mappin.and.ellipse"
        case .author: return "person.circle"
        case .collection: return "folder"
        case .calmingLevel: return "waveform.path.ecg"
        case .contentType: return "square.stack.3d.up"
        }
    }

    var color: Color {
        switch self {
        case .category: return .blue
        case .subcategory: return .purple
        case .instrument: return .orange
        case .mood: return .pink
        case .tempo: return .green
        case .theme: return .yellow
        case .language: return .indigo
        case .ageRange: return .cyan
        case .duration: return .teal
        case .origin: return .mint
        case .author: return .brown
        case .collection: return .gray
        case .calmingLevel: return Color(hex: "#FF6B9D")
        case .contentType: return .purple
        }
    }
}

// MARK: - Filter Tag Factory

extension FilterTag {

    /// Extract all possible filter tags from an audio track
    static func extractTags(from track: AudioTrack) -> [FilterTag] {
        var tags: [FilterTag] = []

        // Category
        tags.append(FilterTag(
            type: .category,
            value: track.category.rawValue,
            displayName: track.category.displayName,
            icon: nil,
            color: .blue
        ))

        // Language (if applicable)
        if let language = track.language {
            tags.append(FilterTag(
                type: .language,
                value: language.rawValue,
                displayName: language.nativeName,
                icon: language.flag,
                color: .indigo
            ))
        }

        // Age range
        if let ageMin = track.ageRangeMin, let ageMax = track.ageRangeMax {
            let ageTag = ageRangeTag(min: ageMin, max: ageMax)
            tags.append(ageTag)
        }

        // Calming level
        tags.append(calmingLevelTag(score: track.calmingScore))

        // Duration
        tags.append(durationTag(seconds: track.duration))

        // Tempo (if available)
        if let bpm = track.tempoBPM {
            tags.append(tempoTag(bpm: bpm))
        }

        // Content type
        tags.append(FilterTag(
            type: .contentType,
            value: track.sourceType.rawValue,
            displayName: track.sourceType == .generated ? "Generated" : "Recorded",
            icon: track.sourceType == .generated ? "waveform" : "music.note",
            color: .purple
        ))

        return tags
    }

    /// Extract tags from track metadata (JSON fields)
    static func extractMetadataTags(from metadata: [String: Any]) -> [FilterTag] {
        var tags: [FilterTag] = []

        // Subcategory
        if let subcategory = metadata["subcategory"] as? String {
            tags.append(FilterTag(
                type: .subcategory,
                value: subcategory,
                displayName: subcategory.capitalized,
                icon: "tag",
                color: .purple
            ))
        }

        // Tags array (instruments, moods, themes)
        if let tagArray = metadata["tags"] as? [String] {
            tags.append(contentsOf: parseTags(tagArray))
        }

        // Author
        if let author = metadata["author"] as? String, !author.isEmpty {
            tags.append(FilterTag(
                type: .author,
                value: author,
                displayName: author,
                icon: "person.circle",
                color: .brown
            ))
        }

        return tags
    }

    // MARK: - Tag Generators

    private static func ageRangeTag(min: Int, max: Int) -> FilterTag {
        let displayName: String
        if max <= 3 {
            displayName = "0-3 months"
        } else if max <= 6 {
            displayName = "3-6 months"
        } else if max <= 12 {
            displayName = "6-12 months"
        } else if max <= 24 {
            displayName = "12-24 months"
        } else {
            displayName = "24+ months"
        }

        return FilterTag(
            type: .ageRange,
            value: "\(min)-\(max)",
            displayName: displayName,
            icon: "figure.2.and.child.holdinghands",
            color: .cyan
        )
    }

    private static func calmingLevelTag(score: Double) -> FilterTag {
        let (value, displayName) = if score >= 0.8 {
            ("very-calming", "Very Calming")
        } else if score >= 0.6 {
            ("calming", "Calming")
        } else {
            ("moderate", "Moderate")
        }

        return FilterTag(
            type: .calmingLevel,
            value: value,
            displayName: displayName,
            icon: "waveform.path.ecg",
            color: Color(hex: "#FF6B9D")
        )
    }

    private static func durationTag(seconds: Double) -> FilterTag {
        let (value, displayName) = if seconds < 180 {
            ("short", "Short (<3 min)")
        } else if seconds < 600 {
            ("medium", "Medium (3-10 min)")
        } else {
            ("long", "Long (>10 min)")
        }

        return FilterTag(
            type: .duration,
            value: value,
            displayName: displayName,
            icon: "clock",
            color: .teal
        )
    }

    private static func tempoTag(bpm: Int) -> FilterTag {
        let (value, displayName) = if bpm < 60 {
            ("slow", "Slow (<60 BPM)")
        } else if bpm < 120 {
            ("medium", "Medium (60-120 BPM)")
        } else {
            ("fast", "Fast (>120 BPM)")
        }

        return FilterTag(
            type: .tempo,
            value: value,
            displayName: displayName,
            icon: "metronome",
            color: .green
        )
    }

    /// Parse tag strings into categorized FilterTags
    private static func parseTags(_ tags: [String]) -> [FilterTag] {
        var result: [FilterTag] = []

        let instruments = ["piano", "guitar", "violin", "orchestra", "flute", "harp", "voice"]
        let moods = ["calming", "soothing", "playful", "energetic", "peaceful", "gentle"]
        let themes = ["bedtime", "playtime", "learning", "magic", "animals", "nature"]

        for tag in tags {
            let lowercased = tag.lowercased()

            if instruments.contains(lowercased) {
                result.append(FilterTag(
                    type: .instrument,
                    value: lowercased,
                    displayName: tag.capitalized,
                    icon: "guitars",
                    color: .orange
                ))
            } else if moods.contains(lowercased) {
                result.append(FilterTag(
                    type: .mood,
                    value: lowercased,
                    displayName: tag.capitalized,
                    icon: "face.smiling",
                    color: .pink
                ))
            } else if themes.contains(lowercased) {
                result.append(FilterTag(
                    type: .theme,
                    value: lowercased,
                    displayName: tag.capitalized,
                    icon: "sparkles",
                    color: .yellow
                ))
            }
        }

        return result
    }
}

// MARK: - Filter Preset

/// Pre-configured filter combinations for common use cases
struct FilterPreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let description: String
    let tags: [FilterTag]
    let isPremium: Bool

    static let defaults: [FilterPreset] = [
        FilterPreset(
            id: UUID(),
            name: "Newborn Bedtime",
            icon: "moon.stars",
            description: "Gentle sounds for 0-3 month babies",
            tags: [
                FilterTag(type: .ageRange, value: "0-3", displayName: "0-3 months"),
                FilterTag(type: .calmingLevel, value: "very-calming", displayName: "Very Calming"),
                FilterTag(type: .tempo, value: "slow", displayName: "Slow")
            ],
            isPremium: false
        ),
        FilterPreset(
            id: UUID(),
            name: "Classical Piano",
            icon: "pianokeys",
            description: "Soothing piano compositions",
            tags: [
                FilterTag(type: .category, value: "classical", displayName: "Classical Music"),
                FilterTag(type: .instrument, value: "piano", displayName: "Piano"),
                FilterTag(type: .calmingLevel, value: "very-calming", displayName: "Very Calming")
            ],
            isPremium: false
        ),
        FilterPreset(
            id: UUID(),
            name: "Nature Sounds",
            icon: "leaf",
            description: "Gentle ocean and nature ambience",
            tags: [
                FilterTag(type: .category, value: "nature", displayName: "Nature Sounds"),
                FilterTag(type: .calmingLevel, value: "calming", displayName: "Calming")
            ],
            isPremium: false
        ),
        FilterPreset(
            id: UUID(),
            name: "Bedtime Stories (EN)",
            icon: "book",
            description: "English fairy tales for sleep",
            tags: [
                FilterTag(type: .category, value: "fairytales", displayName: "Fairy Tales"),
                FilterTag(type: .language, value: "en", displayName: "English"),
                FilterTag(type: .theme, value: "bedtime", displayName: "Bedtime")
            ],
            isPremium: true
        ),
        FilterPreset(
            id: UUID(),
            name: "Quick Calm",
            icon: "bolt.heart",
            description: "Short, highly calming tracks",
            tags: [
                FilterTag(type: .duration, value: "short", displayName: "Short"),
                FilterTag(type: .calmingLevel, value: "very-calming", displayName: "Very Calming")
            ],
            isPremium: false
        )
    ]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}
