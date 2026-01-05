//
//  APIClient.swift
//  BabyInCarApp
//
//  API Client for Baby in Car backend
//

import Foundation

// MARK: - API Configuration

struct APIConfig {
    // Cloudflare Workers deployed API
    // Custom domain api.babyincar.app can be configured in Cloudflare dashboard
    static let baseURL = "https://babyincar-api.anton-abyzov.workers.dev"

    static let timeout: TimeInterval = 30
}

// MARK: - API Client

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false

    /// Base URL for API requests - instance property for FS-017 compatibility
    var baseURL: String {
        return APIConfig.baseURL
    }

    private var accessToken: String?
    private var refreshToken: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601

        // Load stored tokens
        loadStoredTokens()
    }

    // MARK: - Token Management

    private func loadStoredTokens() {
        accessToken = KeychainHelper.get(key: "access_token")
        refreshToken = KeychainHelper.get(key: "refresh_token")
        isAuthenticated = accessToken != nil
    }

    private func storeTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        KeychainHelper.set(key: "access_token", value: access)
        KeychainHelper.set(key: "refresh_token", value: refresh)
        isAuthenticated = true
    }

    private func clearTokens() {
        accessToken = nil
        refreshToken = nil
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "refresh_token")
        isAuthenticated = false
    }

    // MARK: - Request Helpers

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle token refresh
        if httpResponse.statusCode == 401 && authenticated {
            if await refreshAccessToken() {
                return try await makeRequest(path: path, method: method, body: body, authenticated: true)
            } else {
                clearTokens()
                throw APIError.unauthorized
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return data
    }

    private func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken else { return false }

        do {
            let body = ["refresh_token": refresh]
            let data = try await makeRequest(path: "/auth/refresh", method: "POST", body: body, authenticated: false)
            let response = try decoder.decode(TokenResponse.self, from: data)

            if let token = response.token, let newRefresh = response.refreshToken {
                storeTokens(access: token, refresh: newRefresh)
                return true
            }
        } catch {
            print("Token refresh failed: \(error)")
        }

        return false
    }
}

// MARK: - Authentication API

extension APIClient {
    struct RegisterRequest: Encodable {
        let email: String
        let password: String?
        let name: String?
        let authProvider: String
        let appleIdToken: String?
    }

    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    func register(email: String, password: String, name: String?) async throws -> User {
        let body = RegisterRequest(
            email: email,
            password: password,
            name: name,
            authProvider: "email",
            appleIdToken: nil
        )

        let data = try await makeRequest(path: "/auth/register", method: "POST", body: body, authenticated: false)
        let response = try decoder.decode(AuthResponse.self, from: data)

        if let token = response.token, let refresh = response.refreshToken {
            storeTokens(access: token, refresh: refresh)
        }

        guard let user = response.user else {
            throw APIError.invalidResponse
        }

        return user
    }

    func login(email: String, password: String) async throws -> User {
        let body = LoginRequest(email: email, password: password)
        let data = try await makeRequest(path: "/auth/login", method: "POST", body: body, authenticated: false)
        let response = try decoder.decode(AuthResponse.self, from: data)

        if let token = response.token, let refresh = response.refreshToken {
            storeTokens(access: token, refresh: refresh)
        }

        guard let user = response.user else {
            throw APIError.invalidResponse
        }

        return user
    }

    func loginWithApple(idToken: String) async throws -> User {
        let body = ["id_token": idToken]
        let data = try await makeRequest(path: "/auth/apple", method: "POST", body: body, authenticated: false)
        let response = try decoder.decode(AuthResponse.self, from: data)

        if let token = response.token, let refresh = response.refreshToken {
            storeTokens(access: token, refresh: refresh)
        }

        guard let user = response.user else {
            throw APIError.invalidResponse
        }

        return user
    }

    func logout() async {
        if let refresh = refreshToken {
            let body = ["refresh_token": refresh]
            _ = try? await makeRequest(path: "/auth/logout", method: "DELETE", body: body)
        }
        clearTokens()
    }
}

// MARK: - Babies API

extension APIClient {
    struct CreateBabyRequest: Encodable {
        let name: String
        let birthDate: String
        let photoData: String?
    }

    func getBabies() async throws -> [APIBaby] {
        let data = try await makeRequest(path: "/babies")
        let response = try decoder.decode(BabiesResponse.self, from: data)
        return response.babies
    }

    func createBaby(name: String, birthDate: Date, photoData: Data? = nil) async throws -> APIBaby {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let body = CreateBabyRequest(
            name: name,
            birthDate: formatter.string(from: birthDate),
            photoData: photoData?.base64EncodedString()
        )

        let data = try await makeRequest(path: "/babies", method: "POST", body: body)
        let response = try decoder.decode(BabyResponse.self, from: data)

        guard let baby = response.baby else {
            throw APIError.invalidResponse
        }

        return baby
    }

    func updateBaby(id: String, name: String? = nil, birthDate: Date? = nil) async throws -> APIBaby {
        var body: [String: String] = [:]

        if let name = name {
            body["name"] = name
        }

        if let birthDate = birthDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            body["birth_date"] = formatter.string(from: birthDate)
        }

        let data = try await makeRequest(path: "/babies/\(id)", method: "PUT", body: body)
        let response = try decoder.decode(BabyResponse.self, from: data)

        guard let baby = response.baby else {
            throw APIError.invalidResponse
        }

        return baby
    }

    func deleteBaby(id: String) async throws {
        _ = try await makeRequest(path: "/babies/\(id)", method: "DELETE")
    }
}

// MARK: - Content API

extension APIClient {
    /// R2 public base URL for podcast content
    static let r2PublicURL = "https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev"

    func getTracks(category: String? = nil, language: String? = nil, ageMonths: Int? = nil) async throws -> [APITrack] {
        var queryItems: [String] = []

        if let category = category {
            queryItems.append("category=\(category)")
        }
        if let language = language {
            queryItems.append("language=\(language)")
        }
        if let age = ageMonths {
            queryItems.append("age_min=\(age)")
            queryItems.append("age_max=\(age)")
        }

        let query = queryItems.isEmpty ? "" : "?\(queryItems.joined(separator: "&"))"
        let data = try await makeRequest(path: "/content/tracks\(query)")
        let response = try decoder.decode(TracksResponse.self, from: data)

        return response.tracks
    }

    /// Get podcasts only (fairy tales, stories for bedtime)
    func getPodcasts(language: String? = nil, search: String? = nil) async throws -> [APITrack] {
        var queryItems: [String] = ["category=fairy_tales"]

        if let language = language {
            queryItems.append("language=\(language)")
        }
        if let search = search {
            queryItems.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }

        let query = "?\(queryItems.joined(separator: "&"))"
        let data = try await makeRequest(path: "/content/tracks\(query)")
        let response = try decoder.decode(TracksResponse.self, from: data)

        return response.tracks
    }

    /// Get Russian fairy tales specifically
    func getRussianFairyTales() async throws -> [APITrack] {
        return try await getPodcasts(language: "ru")
    }

    /// Get English bedtime stories
    func getEnglishBedtimeStories() async throws -> [APITrack] {
        return try await getPodcasts(language: "en")
    }

    func getPlaylists(category: String? = nil) async throws -> [APIPlaylist] {
        var path = "/content/playlists"
        if let category = category {
            path += "?category=\(category)"
        }

        let data = try await makeRequest(path: path)
        let response = try decoder.decode(PlaylistsResponse.self, from: data)

        return response.playlists
    }

    func getPlaylist(id: String) async throws -> APIPlaylist {
        let data = try await makeRequest(path: "/content/playlists/\(id)")
        let response = try decoder.decode(PlaylistResponse.self, from: data)

        guard let playlist = response.playlist else {
            throw APIError.invalidResponse
        }

        return playlist
    }

    func getRecommendations(babyId: String, mood: String? = nil) async throws -> RecommendationsResponse {
        var path = "/content/recommendations?baby_id=\(babyId)"
        if let mood = mood {
            path += "&mood=\(mood)"
        }

        let data = try await makeRequest(path: path)
        return try decoder.decode(RecommendationsResponse.self, from: data)
    }
}

// MARK: - Analytics API

extension APIClient {
    struct PlaybackEventRequest: Encodable {
        let babyId: String?
        let trackId: String
        let eventType: String
        let positionSeconds: Int
        let sessionId: String
        let context: String
    }

    func recordPlayback(
        babyId: String?,
        trackId: String,
        eventType: String,
        positionSeconds: Int,
        sessionId: String,
        context: String = "home"
    ) async throws {
        let body = PlaybackEventRequest(
            babyId: babyId,
            trackId: trackId,
            eventType: eventType,
            positionSeconds: positionSeconds,
            sessionId: sessionId,
            context: context
        )

        _ = try await makeRequest(path: "/analytics/playback", method: "POST", body: body)
    }

    struct EffectivenessRequest: Encodable {
        let babyId: String
        let trackId: String
        let wasEffective: Bool
        let calmingTimeSeconds: Int
        let context: String
        let emergencyMode: Bool
    }

    func recordEffectiveness(
        babyId: String,
        trackId: String,
        wasEffective: Bool,
        calmingTimeSeconds: Int,
        context: String,
        emergencyMode: Bool = false
    ) async throws {
        let body = EffectivenessRequest(
            babyId: babyId,
            trackId: trackId,
            wasEffective: wasEffective,
            calmingTimeSeconds: calmingTimeSeconds,
            context: context,
            emergencyMode: emergencyMode
        )

        _ = try await makeRequest(path: "/analytics/effectiveness", method: "POST", body: body)
    }

    func getInsights(babyId: String) async throws -> InsightsResponse {
        let data = try await makeRequest(path: "/analytics/insights/\(babyId)")
        return try decoder.decode(InsightsResponse.self, from: data)
    }
}

// MARK: - Audio Streaming API

extension APIClient {
    /// Get stream URL for a track
    func getStreamURL(trackId: String) async throws -> AudioStreamResponse {
        let data = try await makeRequest(path: "/audio/stream/\(trackId)")
        return try decoder.decode(AudioStreamResponse.self, from: data)
    }

    /// Get download URL for a track (for offline caching)
    func getDownloadURL(trackId: String) async throws -> AudioDownloadResponse {
        let data = try await makeRequest(path: "/audio/download/\(trackId)")
        return try decoder.decode(AudioDownloadResponse.self, from: data)
    }

    /// Get multiple stream URLs for batch preloading
    func getStreamURLs(trackIds: [String]) async throws -> BatchStreamResponse {
        let body = ["track_ids": trackIds]
        let data = try await makeRequest(path: "/audio/batch-urls", method: "POST", body: body)
        return try decoder.decode(BatchStreamResponse.self, from: data)
    }

    /// Report audio playback for analytics
    func reportPlayback(trackId: String, event: PlaybackEvent) async throws {
        let body = PlaybackReportRequest(
            trackId: trackId,
            event: event.rawValue,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            position: event.position,
            duration: event.duration
        )
        _ = try await makeRequest(path: "/audio/playback", method: "POST", body: body)
    }

    /// Get audio file info (size, format, bitrate)
    func getAudioFileInfo(trackId: String) async throws -> AudioFileInfo {
        let data = try await makeRequest(path: "/audio/info/\(trackId)")
        return try decoder.decode(AudioFileInfo.self, from: data)
    }
}

// MARK: - Audio Streaming Response Types

struct AudioStreamResponse: Decodable {
    let success: Bool
    let streamUrl: String
    let expiresAt: String?
    let format: String?
    let bitrate: Int?
    let duration: Int?
}

struct AudioDownloadResponse: Decodable {
    let success: Bool
    let downloadUrl: String
    let expiresAt: String?
    let fileSize: Int64?
    let format: String?
    let checksum: String?
}

struct BatchStreamResponse: Decodable {
    let success: Bool
    let streams: [String: StreamInfo]

    struct StreamInfo: Decodable {
        let url: String
        let expiresAt: String?
    }
}

struct AudioFileInfo: Decodable {
    let success: Bool
    let trackId: String
    let format: String
    let bitrate: Int
    let sampleRate: Int
    let channels: Int
    let fileSize: Int64
    let duration: Int
}

struct PlaybackReportRequest: Encodable {
    let trackId: String
    let event: String
    let timestamp: String
    let position: TimeInterval?
    let duration: TimeInterval?
}

enum PlaybackEvent {
    case started
    case paused(position: TimeInterval)
    case resumed(position: TimeInterval)
    case completed(duration: TimeInterval)
    case seeked(position: TimeInterval)
    case error(message: String)

    var rawValue: String {
        switch self {
        case .started: return "started"
        case .paused: return "paused"
        case .resumed: return "resumed"
        case .completed: return "completed"
        case .seeked: return "seeked"
        case .error: return "error"
        }
    }

    var position: TimeInterval? {
        switch self {
        case .paused(let pos), .resumed(let pos), .seeked(let pos):
            return pos
        default:
            return nil
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .completed(let dur):
            return dur
        default:
            return nil
        }
    }
}

// MARK: - Search API

extension APIClient {
    /// Search tracks with full-text search and filters
    func searchTracks(
        query: String? = nil,
        category: String? = nil,
        language: String? = nil,
        origin: String? = nil,
        author: String? = nil,
        theme: String? = nil,
        ageMin: Int? = nil,
        ageMax: Int? = nil,
        durationMax: Int? = nil,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> SearchResponse {
        var queryItems: [String] = []

        if let q = query, !q.isEmpty {
            queryItems.append("q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        }
        if let category = category {
            queryItems.append("category=\(category)")
        }
        if let language = language {
            queryItems.append("language=\(language)")
        }
        if let origin = origin {
            queryItems.append("origin=\(origin)")
        }
        if let author = author {
            queryItems.append("author=\(author)")
        }
        if let theme = theme {
            queryItems.append("theme=\(theme)")
        }
        if let ageMin = ageMin {
            queryItems.append("age_min=\(ageMin)")
        }
        if let ageMax = ageMax {
            queryItems.append("age_max=\(ageMax)")
        }
        if let durationMax = durationMax {
            queryItems.append("duration_max=\(durationMax)")
        }
        queryItems.append("limit=\(limit)")
        queryItems.append("offset=\(offset)")

        // Add locale
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        queryItems.append("locale=\(locale)")

        let path = "/search?\(queryItems.joined(separator: "&"))"
        let data = try await makeRequest(path: path, authenticated: false)
        return try decoder.decode(SearchResponse.self, from: data)
    }

    /// Get taxonomy items (origins, authors, themes, sources)
    func getTaxonomy(type: TaxonomyType) async throws -> TaxonomyResponse {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        let data = try await makeRequest(path: "/search/taxonomy/\(type.rawValue)?locale=\(locale)", authenticated: false)
        return try decoder.decode(TaxonomyResponse.self, from: data)
    }

    /// Browse tracks by taxonomy
    func browseTaxonomy(type: TaxonomyType, value: String, limit: Int = 50, offset: Int = 0, sortBy: String = "calming_score") async throws -> BrowseResponse {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        let path = "/search/browse/\(type.rawValue)/\(value)?limit=\(limit)&offset=\(offset)&sort=\(sortBy)&locale=\(locale)"
        let data = try await makeRequest(path: path, authenticated: false)
        return try decoder.decode(BrowseResponse.self, from: data)
    }

    /// Get related tracks for a given track
    func getRelatedTracks(trackId: String, limit: Int = 10) async throws -> RelatedTracksResponse {
        let data = try await makeRequest(path: "/search/related/\(trackId)?limit=\(limit)", authenticated: false)
        return try decoder.decode(RelatedTracksResponse.self, from: data)
    }

    /// Get search suggestions (recent + popular + featured taxonomies)
    func getSearchSuggestions() async throws -> SearchSuggestionsResponse {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        let data = try await makeRequest(path: "/search/suggestions?locale=\(locale)", authenticated: false)
        return try decoder.decode(SearchSuggestionsResponse.self, from: data)
    }

    /// Clear search history
    func clearSearchHistory() async throws {
        _ = try await makeRequest(path: "/search/history", method: "DELETE")
    }
}

// MARK: - Search Response Types

enum TaxonomyType: String, CaseIterable {
    case origin
    case author
    case theme
    case source
    case collection

    var displayName: String {
        switch self {
        case .origin: return "Origin"
        case .author: return "Author"
        case .theme: return "Theme"
        case .source: return "Source"
        case .collection: return "Collection"
        }
    }

    var icon: String {
        switch self {
        case .origin: return "globe"
        case .author: return "person"
        case .theme: return "tag"
        case .source: return "archivebox"
        case .collection: return "folder"
        }
    }
}

struct SearchResponse: Decodable {
    let success: Bool
    let query: String?
    let normalizedQuery: String?
    let filters: SearchFilters?
    let tracks: [SearchTrack]
    let total: Int
    let hasMore: Bool
}

struct SearchFilters: Decodable {
    let category: String?
    let language: String?
    let origin: String?
    let author: String?
    let theme: String?
}

struct SearchTrack: Decodable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let category: String
    let language: String
    let duration: Int
    let ageRangeMin: Int
    let ageRangeMax: Int
    let calmingScore: Double
    let audioSourceType: String
    let streamUrl: String?
    let artworkUrl: String?
    let isPremium: Bool
    let isLocked: Bool?
    let relevanceScore: Double?
    let taxonomies: TrackTaxonomies?

    // Custom decoder to handle isPremium being either Bool or Int (0/1)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        category = try container.decode(String.self, forKey: .category)
        language = try container.decode(String.self, forKey: .language)
        duration = try container.decode(Int.self, forKey: .duration)
        ageRangeMin = try container.decode(Int.self, forKey: .ageRangeMin)
        ageRangeMax = try container.decode(Int.self, forKey: .ageRangeMax)
        calmingScore = try container.decode(Double.self, forKey: .calmingScore)
        audioSourceType = try container.decode(String.self, forKey: .audioSourceType)
        streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
        artworkUrl = try container.decodeIfPresent(String.self, forKey: .artworkUrl)

        // Handle isPremium as Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .isPremium) {
            isPremium = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isPremium) {
            isPremium = intValue != 0
        } else {
            isPremium = false
        }

        // Handle isLocked as Bool or Int (SQLite returns 0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isLocked) {
            isLocked = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isLocked) {
            isLocked = intValue != 0
        } else {
            isLocked = nil
        }
        relevanceScore = try container.decodeIfPresent(Double.self, forKey: .relevanceScore)
        taxonomies = try container.decodeIfPresent(TrackTaxonomies.self, forKey: .taxonomies)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, category, language, duration
        case ageRangeMin, ageRangeMax, calmingScore, audioSourceType
        case streamUrl, artworkUrl, isPremium, isLocked, relevanceScore, taxonomies
    }
}

struct TrackTaxonomies: Decodable {
    let origin: [String]?
    let author: [String]?
    let theme: [String]?
    let source: [String]?
}

struct TaxonomyResponse: Decodable {
    let success: Bool
    let taxonomyType: String
    let items: [TaxonomyItem]
}

struct TaxonomyItem: Decodable, Identifiable {
    var id: String { value }
    let value: String
    let displayName: String
    let icon: String?
    let color: String?
    let isFeatured: Bool
    let trackCount: Int
}

struct BrowseResponse: Decodable {
    let success: Bool
    let taxonomy: TaxonomyInfo
    let tracks: [SearchTrack]
    let total: Int
    let hasMore: Bool
}

struct TaxonomyInfo: Decodable {
    let type: String
    let value: String
    let displayName: String
    let icon: String?
    let color: String?
    let description: String?
}

struct RelatedTracksResponse: Decodable {
    let success: Bool
    let sourceTrack: SourceTrackInfo
    let relatedTracks: [SearchTrack]
}

struct SourceTrackInfo: Decodable {
    let id: String
    let title: String
    let category: String
}

struct SearchSuggestionsResponse: Decodable {
    let success: Bool
    let suggestions: SearchSuggestions
}

struct SearchSuggestions: Decodable {
    let recent: [RecentSearch]
    let popular: [PopularSearch]
    let featuredTaxonomies: [FeaturedTaxonomy]
}

struct RecentSearch: Decodable, Identifiable {
    var id: String { query }
    let query: String
    let resultsCount: Int
}

struct PopularSearch: Decodable, Identifiable {
    var id: String { query }
    let query: String
    let searchCount: Int
}

struct FeaturedTaxonomy: Decodable, Identifiable {
    var id: String { "\(taxonomyType)_\(taxonomyValue)" }
    let taxonomyType: String
    let taxonomyValue: String
    let displayName: String
    let icon: String?
    let color: String?
    let isFeatured: Int
    let trackCount: Int
}

// MARK: - Music Generation API

extension APIClient {
    /// Get available music generation presets
    func getMusicPresets(category: String? = nil, ageMonths: Int? = nil) async throws -> [MusicPreset] {
        var queryItems: [String] = []

        if let category = category {
            queryItems.append("category=\(category)")
        }
        if let age = ageMonths {
            queryItems.append("age=\(age)")
        }

        let query = queryItems.isEmpty ? "" : "?\(queryItems.joined(separator: "&"))"
        let data = try await makeRequest(path: "/music/presets\(query)", authenticated: false)
        let response = try decoder.decode(MusicPresetsResponse.self, from: data)

        return response.presets
    }

    /// Get details of a specific preset
    func getMusicPreset(id: String) async throws -> MusicPresetFull {
        let data = try await makeRequest(path: "/music/presets/\(id)", authenticated: false)
        let response = try decoder.decode(MusicPresetFullResponse.self, from: data)

        guard let preset = response.preset else {
            throw APIError.invalidResponse
        }

        return preset
    }

    /// Generate music from a custom prompt (admin only)
    func generateMusic(request: MusicGenerationRequest) async throws -> MusicGenerationResponse {
        let data = try await makeRequest(path: "/music/generate", method: "POST", body: request)
        return try decoder.decode(MusicGenerationResponse.self, from: data)
    }

    /// Generate music from a preset (admin only)
    func generateFromPreset(presetId: String) async throws -> MusicGenerationResponse {
        let data = try await makeRequest(path: "/music/generate/preset/\(presetId)", method: "POST", body: [:] as [String: String])
        return try decoder.decode(MusicGenerationResponse.self, from: data)
    }

    /// Check the status of a music generation task
    func getMusicStatus(taskId: String) async throws -> MusicTaskStatus {
        let data = try await makeRequest(path: "/music/status/\(taskId)")
        return try decoder.decode(MusicTaskStatus.self, from: data)
    }

    /// Get credit balance for music generation
    func getMusicCredits() async throws -> MusicCreditsResponse {
        let data = try await makeRequest(path: "/music/credits")
        return try decoder.decode(MusicCreditsResponse.self, from: data)
    }
}

// MARK: - Music Generation Response Types

struct MusicPreset: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let instrumental: Bool
    let language: String
    let targetAge: AgeRange

    struct AgeRange: Decodable {
        let min: Int
        let max: Int
    }
}

struct MusicPresetFull: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let instrumental: Bool
    let language: String
    let targetAge: MusicPreset.AgeRange
    let prompt: String
    let style: String
}

struct MusicPresetsResponse: Decodable {
    let success: Bool
    let presets: [MusicPreset]
}

struct MusicPresetFullResponse: Decodable {
    let success: Bool
    let preset: MusicPresetFull?
}

struct MusicGenerationRequest: Encodable {
    let prompt: String
    let lyrics: String?
    let style: String?
    let title: String?
    let instrumental: Bool
    let duration: Int?
    let model: String?

    init(
        prompt: String,
        lyrics: String? = nil,
        style: String? = nil,
        title: String? = nil,
        instrumental: Bool = true,
        duration: Int? = nil,
        model: String? = "v4.5"
    ) {
        self.prompt = prompt
        self.lyrics = lyrics
        self.style = style
        self.title = title
        self.instrumental = instrumental
        self.duration = duration
        self.model = model
    }
}

struct MusicGenerationResponse: Decodable {
    let success: Bool
    let taskId: String?
    let status: String?
    let tracks: [GeneratedTrack]?
    let credits: MusicCredits?

    struct MusicCredits: Decodable {
        let used: Int?
        let remaining: Int?
    }
}

struct GeneratedTrack: Decodable, Identifiable {
    let id: String
    let title: String
    let audioUrl: String
    let imageUrl: String?
    let duration: Double
    let lyrics: String?
    let style: String?
    let createdAt: String
}

struct MusicTaskStatus: Decodable {
    let success: Bool
    let taskId: String
    let status: String
    let progress: Int?
    let tracks: [GeneratedTrack]?
    let error: String?
}

struct MusicCreditsResponse: Decodable {
    let success: Bool
    let credits: Int?
    let plan: String?
}

// MARK: - Subscription API

extension APIClient {
    func verifyReceipt(receiptData: String, productId: String) async throws -> SubscriptionVerificationResponse {
        let body = [
            "receipt_data": receiptData,
            "product_id": productId
        ]

        let data = try await makeRequest(path: "/subscriptions/verify", method: "POST", body: body)
        return try decoder.decode(SubscriptionVerificationResponse.self, from: data)
    }

    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        let data = try await makeRequest(path: "/subscriptions/status")
        return try decoder.decode(SubscriptionStatusResponse.self, from: data)
    }
}

// MARK: - Response Types

struct AuthResponse: Decodable {
    let success: Bool
    let user: User?
    let token: String?
    let refreshToken: String?
}

struct TokenResponse: Decodable {
    let success: Bool
    let token: String?
    let refreshToken: String?
}

struct User: Decodable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let subscriptionStatus: String?
    let createdAt: String?
}

struct APIBaby: Decodable, Identifiable {
    let id: String
    let name: String
    let birthDate: String
    let ageMonths: Int
    let developmentalStage: String
    let photoUrl: String?
    let preferences: BabyPreferences?
}

struct BabyPreferences: Decodable {
    let favoriteCategories: [String]?
    let preferredLanguages: [String]?
    let effectiveTracks: [String]?
}

struct BabiesResponse: Decodable {
    let success: Bool
    let babies: [APIBaby]
}

struct BabyResponse: Decodable {
    let success: Bool
    let baby: APIBaby?
}

struct APITrack: Decodable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let category: String
    let language: String
    let duration: Int
    let ageRangeMin: Int
    let ageRangeMax: Int
    let calmingScore: Double
    let audioSourceType: String
    let generatorType: String?
    let streamUrl: String?
    let artworkUrl: String?
    let isPremium: Bool
    let isLocked: Bool?

    // Custom decoder to handle isPremium being either Bool or Int (0/1)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        category = try container.decode(String.self, forKey: .category)
        language = try container.decode(String.self, forKey: .language)
        duration = try container.decode(Int.self, forKey: .duration)
        ageRangeMin = try container.decode(Int.self, forKey: .ageRangeMin)
        ageRangeMax = try container.decode(Int.self, forKey: .ageRangeMax)
        calmingScore = try container.decode(Double.self, forKey: .calmingScore)
        audioSourceType = try container.decode(String.self, forKey: .audioSourceType)
        generatorType = try container.decodeIfPresent(String.self, forKey: .generatorType)
        streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
        artworkUrl = try container.decodeIfPresent(String.self, forKey: .artworkUrl)

        // Handle isPremium as Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .isPremium) {
            isPremium = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isPremium) {
            isPremium = intValue != 0
        } else {
            isPremium = false
        }

        // Handle isLocked as Bool or Int (SQLite returns 0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isLocked) {
            isLocked = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isLocked) {
            isLocked = intValue != 0
        } else {
            isLocked = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, category, language, duration
        case ageRangeMin, ageRangeMax, calmingScore, audioSourceType
        case generatorType, streamUrl, artworkUrl, isPremium, isLocked
    }
}

struct TracksResponse: Decodable {
    let success: Bool
    let tracks: [APITrack]
    let total: Int?
    let hasMore: Bool?
}

struct APIPlaylist: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String?
    let targetAgeMonths: Int?
    let artworkUrl: String?
    let isSystem: Bool
    let trackCount: Int?
    let totalDuration: Int?
    let tracks: [APITrack]?

    // Custom decoder to handle isSystem as both Int and Bool
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, targetAgeMonths, artworkUrl, isSystem, trackCount, totalDuration, tracks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        targetAgeMonths = try container.decodeIfPresent(Int.self, forKey: .targetAgeMonths)
        artworkUrl = try container.decodeIfPresent(String.self, forKey: .artworkUrl)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        totalDuration = try container.decodeIfPresent(Int.self, forKey: .totalDuration)
        tracks = try container.decodeIfPresent([APITrack].self, forKey: .tracks)

        // Handle isSystem as both Bool and Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isSystem) {
            isSystem = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isSystem) {
            isSystem = intValue != 0
        } else {
            isSystem = false // Default fallback
        }
    }
}

struct PlaylistsResponse: Decodable {
    let success: Bool
    let playlists: [APIPlaylist]
}

struct PlaylistResponse: Decodable {
    let success: Bool
    let playlist: APIPlaylist?
}

struct RecommendationsResponse: Decodable {
    let success: Bool
    let recommendedTracks: [APITrack]
    let emergencyTracks: [APITrack]
    let recommendedPlaylists: [APIPlaylist]
    let personalizationScore: Double
}

struct InsightsResponse: Decodable {
    let success: Bool
    let insights: BabyInsights
}

struct BabyInsights: Decodable {
    let totalListeningTimeMinutes: Int
    let mostEffectiveCategory: String?
    let averageCalmingTimeSeconds: Int
    let emergencyModeUsage: EmergencyUsage
}

struct EmergencyUsage: Decodable {
    let totalActivations: Int
    let successRate: Double
}

struct SubscriptionVerificationResponse: Decodable {
    let success: Bool
    let valid: Bool
    let subscription: SubscriptionInfo?
    let entitlements: [String]
}

struct SubscriptionInfo: Decodable {
    let productId: String
    let expiresAt: String
    let isTrial: Bool
    let willRenew: Bool
}

struct SubscriptionStatusResponse: Decodable {
    let success: Bool
    let subscription: SubscriptionStatus
}

struct SubscriptionStatus: Decodable {
    let status: String
    let isActive: Bool
    let expiresAt: String?
    let entitlements: [String]
}

struct APIErrorResponse: Decodable {
    let success: Bool
    let error: String?
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in again"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static func set(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AnyEncodable Helper

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
