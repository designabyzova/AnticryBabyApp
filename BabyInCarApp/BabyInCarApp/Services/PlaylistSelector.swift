//
//  PlaylistSelector.swift
//  BabyInCarApp
//
//  Created for FS-017: Smart Emergency Playlist System
//  AI-driven playlist selection using metadata and learning data
//

import Foundation

/// Service for selecting optimal playlists based on cry scenario, baby age, and language preferences
@MainActor
class PlaylistSelector: ObservableObject {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Select optimal playlist for a given cry scenario
    /// - Parameters:
    ///   - cryType: Type of cry detected (hunger, tired, pain, etc.)
    ///   - babyAge: Baby's age in months
    ///   - languages: Preferred language codes (e.g., ["en", "ru"])
    ///   - babyId: Optional baby ID for personalized selection
    /// - Returns: Array of ranked playlists (top 3)
    func selectOptimalPlaylist(
        cryType: CryType,
        babyAge: Int,
        languages: [String],
        babyId: String?
    ) async throws -> [CryScenarioPlaylist] {
        // Build query parameters
        let languageParam = languages.joined(separator: ",")

        var components = URLComponents(string: "\(apiClient.baseURL)/playlists/emergency/\(cryType.rawValue)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: languageParam),
            URLQueryItem(name: "age", value: "\(babyAge)")
        ]

        if let babyId = babyId {
            components.queryItems?.append(URLQueryItem(name: "babyId", value: babyId))
        }

        guard let url = components.url else {
            throw PlaylistSelectorError.invalidURL
        }

        // Make API request
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaylistSelectorError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PlaylistSelectorError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let playlistResponse = try decoder.decode(PlaylistSelectionResponse.self, from: data)

        return playlistResponse.playlists
    }

    /// Quick selection with default parameters (current baby context)
    func selectForCurrentBaby(cryType: CryType) async throws -> CryScenarioPlaylist? {
        // Get current baby context (from UserDefaults or app state)
        let babyAge = UserDefaults.standard.integer(forKey: "currentBabyAge")
        let babyId = UserDefaults.standard.string(forKey: "currentBabyId")

        // Get language preferences (default to English if not set)
        let languagePrefs = await getLanguagePreferences()

        let playlists = try await selectOptimalPlaylist(
            cryType: cryType,
            babyAge: babyAge > 0 ? babyAge : 12,  // Default to 12 months
            languages: languagePrefs.isEmpty ? ["en"] : languagePrefs,
            babyId: babyId
        )

        return playlists.first
    }

    /// Get user's language preferences
    private func getLanguagePreferences() async -> [String] {
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            return ["en"]
        }

        do {
            let url = URL(string: "\(apiClient.baseURL)/preferences/language/\(userId)")!
            let (data, _) = try await URLSession.shared.data(from: url)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let prefs = try decoder.decode(UserLanguagePreference.self, from: data)
            return prefs.parsedLanguages
        } catch {
            print("Failed to fetch language preferences, using default: \(error)")
            return ["en"]
        }
    }
}

// MARK: - Response Models

struct PlaylistSelectionResponse: Codable {
    let playlists: [CryScenarioPlaylist]
    let metadata: SelectionMetadata
}

struct SelectionMetadata: Codable {
    let cryType: String
    let languages: [String]
    let age: Int
    let count: Int
    let personalized: Bool
}

// MARK: - Errors

enum PlaylistSelectorError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "Server error (status code: \(statusCode))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Shared Instance

extension PlaylistSelector {
    /// Shared instance for convenience
    @MainActor
    static let shared = PlaylistSelector(apiClient: .shared)

    /// Preview/mock instance for SwiftUI previews
    @MainActor
    static let preview = PlaylistSelector(apiClient: .shared)
}
