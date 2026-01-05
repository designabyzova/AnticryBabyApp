//
//  UserLanguagePreference.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//

import Foundation

/// User's language preferences for content filtering
struct UserLanguagePreference: Codable {
    let userId: String
    let preferredLanguages: String  // Comma-separated: "en,ru"
    let primaryLanguage: String
    let excludeInstrumental: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case preferredLanguages = "preferred_languages"
        case primaryLanguage = "primary_language"
        case excludeInstrumental = "exclude_instrumental"
    }

    /// Parsed language codes as array
    var parsedLanguages: [String] {
        return preferredLanguages.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// Check if a language code is preferred
    func isPreferred(_ language: String) -> Bool {
        // Always include "multi" (instrumental) unless explicitly excluded
        if language == "multi" {
            return !excludeInstrumental
        }
        return parsedLanguages.contains(language)
    }

    /// User-friendly language names
    var languageNames: [String] {
        return parsedLanguages.compactMap { code in
            switch code {
            case "en": return "English"
            case "ru": return "Russian"
            case "es": return "Spanish"
            case "fr": return "French"
            case "de": return "German"
            default: return code.uppercased()
            }
        }
    }

    /// Formatted display string (e.g., "English, Russian")
    var formattedLanguages: String {
        return languageNames.joined(separator: ", ")
    }
}

/// Extension for SwiftUI state management
extension UserLanguagePreference {
    /// Update preferences with new language selection
    func with(languages: [String], primary: String? = nil, excludeInstrumental: Bool? = nil) -> UserLanguagePreference {
        return UserLanguagePreference(
            userId: userId,
            preferredLanguages: languages.joined(separator: ","),
            primaryLanguage: primary ?? primaryLanguage,
            excludeInstrumental: excludeInstrumental ?? self.excludeInstrumental
        )
    }
}

/// Extension for mock data
extension UserLanguagePreference {
    static let defaultEnglish = UserLanguagePreference(
        userId: "user-001",
        preferredLanguages: "en",
        primaryLanguage: "en",
        excludeInstrumental: false
    )

    static let bilingual = UserLanguagePreference(
        userId: "user-002",
        preferredLanguages: "en,ru",
        primaryLanguage: "en",
        excludeInstrumental: false
    )

    static let russianOnly = UserLanguagePreference(
        userId: "user-003",
        preferredLanguages: "ru",
        primaryLanguage: "ru",
        excludeInstrumental: false
    )
}
