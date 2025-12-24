//
//  APIClient.swift
//  BabyInCarApp
//
//  API Client for Baby in Car backend
//

import Foundation

// MARK: - API Configuration

struct APIConfig {
    #if DEBUG
    static let baseURL = "http://localhost:8787"
    #else
    static let baseURL = "https://api.babyincar.app"
    #endif

    static let timeout: TimeInterval = 30
}

// MARK: - API Client

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false

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
            try? await makeRequest(path: "/auth/logout", method: "DELETE", body: body)
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

    func recordEffectiveness(
        babyId: String,
        trackId: String,
        wasEffective: Bool,
        calmingTimeSeconds: Int,
        context: String,
        emergencyMode: Bool = false
    ) async throws {
        let body: [String: Any] = [
            "baby_id": babyId,
            "track_id": trackId,
            "was_effective": wasEffective,
            "calming_time_seconds": calmingTimeSeconds,
            "context": context,
            "emergency_mode": emergencyMode
        ]

        _ = try await makeRequest(path: "/analytics/effectiveness", method: "POST", body: body)
    }

    func getInsights(babyId: String) async throws -> InsightsResponse {
        let data = try await makeRequest(path: "/analytics/insights/\(babyId)")
        return try decoder.decode(InsightsResponse.self, from: data)
    }
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
