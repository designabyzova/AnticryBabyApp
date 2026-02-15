//
//  EffectivenessSyncService.swift
//  BabyInCarApp
//
//  FS-029: Syncs cry-type effectiveness data with cloud API
//  Enables personalized playlists across devices
//

import Foundation
import Combine

// MARK: - Sync Models

/// Cry-type effectiveness record for API sync
struct CryTypeEffectivenessRecord: Codable {
    let trackId: String
    let cryType: String
    let helpedCount: Int
    let notHelpedCount: Int
    let totalPlayDurationSeconds: Int
    let avgEffectivenessScore: Double
    let autoDetectedHelped: Int
    let autoDetectedWeight: Double
    let lastPlayedAt: String?
}

/// Feedback session record for API sync
struct FeedbackSessionSyncRecord: Codable {
    let id: String
    let babyId: String?
    let cryType: String
    let startTime: String
    let endTime: String?
    let outcome: String?
    let tracksPlayed: [String]
    let sessionDurationSeconds: Int
    let tracksCount: Int
}

/// Track feedback event for API sync
struct TrackFeedbackEventSyncRecord: Codable {
    let sessionId: String
    let trackId: String
    let cryType: String
    let eventType: String
    let playDurationSeconds: Int
    let positionInSession: Int
    let autoDetectionConfidence: Double?
}

/// API response for effectiveness sync
struct EffectivenessSyncResponse: Codable {
    let success: Bool
    let synced: Int?
    let errors: Int?
    let syncedAt: String?
    let records: [CloudEffectivenessRecord]?
    let count: Int?
    let fetchedAt: String?
}

/// Cloud effectiveness record (from API)
struct CloudEffectivenessRecord: Codable {
    let id: String
    let userId: String
    let trackId: String
    let cryType: String
    let helpedCount: Int
    let notHelpedCount: Int
    let totalPlayDurationSeconds: Int
    let avgEffectivenessScore: Double
    let autoDetectedHelped: Int
    let autoDetectedWeight: Double
    let lastPlayedAt: String?
    let createdAt: String
    let updatedAt: String
}

// MARK: - Effectiveness Sync Service

/// Service for syncing cry-type effectiveness data with cloud API
@MainActor
class EffectivenessSyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = EffectivenessSyncService()

    // MARK: - Published State

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var lastSyncError: String?
    @Published private(set) var pendingUploadCount: Int = 0

    // MARK: - Configuration

    /// Minimum interval between automatic syncs (5 minutes)
    private let autoSyncInterval: TimeInterval = 300

    /// Batch size for uploads
    private let batchSize: Int = 50

    // MARK: - Private State

    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "EffectivenessLastSync"
    private let pendingUploadsKey = "EffectivenessPendingUploads"

    private var cancellables = Set<AnyCancellable>()
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Dependencies

    private let apiClient = APIClient.shared
    private let apiHelper = EffectivenessAPIHelper.shared
    private let effectivenessManager = EffectivenessManager.shared
    private let feedbackService = FeedbackCollectionService.shared

    // MARK: - Initialization

    private init() {
        loadLastSyncTime()
        setupObservers()
    }

    // MARK: - Setup

    private func loadLastSyncTime() {
        if let timestamp = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncTime = timestamp
        }
    }

    private func saveLastSyncTime() {
        lastSyncTime = Date()
        userDefaults.set(lastSyncTime, forKey: lastSyncKey)
    }

    private func setupObservers() {
        // Auto-sync when user logs in
        apiClient.$isAuthenticated
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.performFullSync()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Sync Methods

    /// Perform a full sync (push local changes, then pull cloud data)
    func performFullSync() async {
        guard apiClient.isAuthenticated else {
            print("[EffectivenessSync] ⚠️ Not authenticated, skipping sync")
            return
        }

        guard !isSyncing else {
            print("[EffectivenessSync] ⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        lastSyncError = nil

        print("[EffectivenessSync] 🔄 Starting full sync...")

        do {
            // 1. Push local effectiveness data
            try await pushEffectivenessData()

            // 2. Pull cloud effectiveness data
            try await pullEffectivenessData()

            saveLastSyncTime()
            print("[EffectivenessSync] ✅ Full sync completed")

        } catch {
            lastSyncError = error.localizedDescription
            print("[EffectivenessSync] ❌ Sync failed: \(error)")
        }

        isSyncing = false
    }

    /// Push local effectiveness data to cloud
    func pushEffectivenessData() async throws {
        let records = buildEffectivenessRecords()

        guard !records.isEmpty else {
            print("[EffectivenessSync] 📤 No local data to push")
            return
        }

        print("[EffectivenessSync] 📤 Pushing \(records.count) effectiveness records...")

        // Batch upload
        for batch in records.chunked(into: batchSize) {
            let data = try await apiHelper.postEffectiveness(batch)

            if let response = try? JSONDecoder().decode(EffectivenessSyncResponse.self, from: data) {
                print("[EffectivenessSync] 📤 Batch synced: \(response.synced ?? 0) records")
            }
        }

        pendingUploadCount = 0
    }

    /// Pull cloud effectiveness data and merge with local
    func pullEffectivenessData() async throws {
        print("[EffectivenessSync] 📥 Pulling effectiveness data...")

        let sinceDate = lastSyncTime.map { dateFormatter.string(from: $0) }
        let data = try await apiHelper.getEffectiveness(since: sinceDate)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(EffectivenessSyncResponse.self, from: data)

        guard let cloudRecords = response.records else {
            print("[EffectivenessSync] 📥 No cloud records to merge")
            return
        }

        print("[EffectivenessSync] 📥 Received \(cloudRecords.count) cloud records")

        // Merge cloud data with local data
        mergeCloudData(cloudRecords)
    }

    /// Sync a single feedback session
    func syncSession(_ session: CrySoothingSession) async {
        guard apiClient.isAuthenticated else { return }

        let record = FeedbackSessionSyncRecord(
            id: session.id.uuidString,
            babyId: nil, // Can be linked later
            cryType: session.cryType.rawValue,
            startTime: dateFormatter.string(from: session.startTime),
            endTime: session.endTime.map { dateFormatter.string(from: $0) },
            outcome: session.outcome?.rawValue,
            tracksPlayed: session.tracksPlayed.map { $0.trackId.uuidString },
            sessionDurationSeconds: Int(session.duration ?? 0),
            tracksCount: session.tracksPlayed.count
        )

        do {
            try await apiHelper.postFeedbackSession(record)
            print("[EffectivenessSync] 📤 Session synced: \(session.id)")
        } catch {
            print("[EffectivenessSync] ⚠️ Session sync failed: \(error)")
        }
    }

    // MARK: - Auto-Sync

    /// Check if auto-sync is due and perform if needed
    func checkAndSyncIfNeeded() async {
        guard apiClient.isAuthenticated else { return }

        let shouldSync: Bool
        if let last = lastSyncTime {
            shouldSync = Date().timeIntervalSince(last) >= autoSyncInterval
        } else {
            shouldSync = true
        }

        if shouldSync {
            await performFullSync()
        }
    }

    // MARK: - Private Methods

    /// Build effectiveness records from local EffectivenessManager data
    private func buildEffectivenessRecords() -> [CryTypeEffectivenessRecord] {
        var records: [CryTypeEffectivenessRecord] = []

        for (trackId, effectiveness) in effectivenessManager.effectivenessData {
            // Build per-cry-type records
            for (cryTypeKey, stats) in effectiveness.cryTypeBreakdown {
                let record = CryTypeEffectivenessRecord(
                    trackId: trackId.uuidString,
                    cryType: cryTypeKey,
                    helpedCount: stats.helpedCount,
                    notHelpedCount: stats.totalCount - stats.helpedCount,
                    totalPlayDurationSeconds: 0, // Not tracked at this level currently
                    avgEffectivenessScore: stats.successRate / 100.0, // Convert to 0-1 range
                    autoDetectedHelped: 0, // Would need separate tracking
                    autoDetectedWeight: 0.7,
                    lastPlayedAt: effectiveness.lastHelped.map { dateFormatter.string(from: $0) }
                )
                records.append(record)
            }

            // If no cry type breakdown, create a "general" record
            if effectiveness.cryTypeBreakdown.isEmpty && effectiveness.totalPlays > 0 {
                let record = CryTypeEffectivenessRecord(
                    trackId: trackId.uuidString,
                    cryType: "general",
                    helpedCount: effectiveness.helpedCount,
                    notHelpedCount: effectiveness.totalPlays - effectiveness.helpedCount,
                    totalPlayDurationSeconds: 0,
                    avgEffectivenessScore: effectiveness.effectivenessScore / 100.0,
                    autoDetectedHelped: 0,
                    autoDetectedWeight: 0.7,
                    lastPlayedAt: effectiveness.lastHelped.map { dateFormatter.string(from: $0) }
                )
                records.append(record)
            }
        }

        return records
    }

    /// Merge cloud data into local EffectivenessManager
    private func mergeCloudData(_ cloudRecords: [CloudEffectivenessRecord]) {
        // Group by track ID
        let groupedByTrack = Dictionary(grouping: cloudRecords) { $0.trackId }

        var mergedData: [UUID: TrackEffectiveness] = [:]

        for (trackIdString, records) in groupedByTrack {
            guard let trackId = UUID(uuidString: trackIdString) else { continue }

            // Get or create local effectiveness data
            var localData = effectivenessManager.effectivenessData[trackId]
                ?? TrackEffectiveness(trackId: trackId)

            // Merge each cry-type record
            for record in records {
                var stats = localData.cryTypeBreakdown[record.cryType] ?? CryTypeStats()

                // Take the maximum of local and cloud counts (simple conflict resolution)
                stats.helpedCount = max(stats.helpedCount, record.helpedCount)
                stats.totalCount = max(stats.totalCount, record.helpedCount + record.notHelpedCount)

                localData.cryTypeBreakdown[record.cryType] = stats
            }

            // Recalculate totals from breakdown
            let totalHelped = localData.cryTypeBreakdown.values.reduce(0) { $0 + $1.helpedCount }
            let totalPlays = localData.cryTypeBreakdown.values.reduce(0) { $0 + $1.totalCount }

            localData.helpedCount = max(localData.helpedCount, totalHelped)
            localData.totalPlays = max(localData.totalPlays, totalPlays)

            mergedData[trackId] = localData
            print("[EffectivenessSync] 📥 Merged data for track: \(trackId)")
        }

        // Persist merged data via EffectivenessManager
        if !mergedData.isEmpty {
            effectivenessManager.mergeEffectivenessData(mergedData)
            print("[EffectivenessSync] 💾 Saved \(mergedData.count) merged records")
        }
    }
}

// MARK: - Effectiveness API Helper

/// Helper class for effectiveness API requests (avoids conflicting with APIClient's private makeRequest)
class EffectivenessAPIHelper {
    static let shared = EffectivenessAPIHelper()

    private let baseURL = APIConfig.baseURL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private init() {}

    /// POST /effectiveness - Sync effectiveness records
    func postEffectiveness(_ records: [CryTypeEffectivenessRecord]) async throws -> Data {
        return try await performRequest(
            path: "/effectiveness",
            method: "POST",
            body: ["records": records]
        )
    }

    /// GET /effectiveness - Fetch effectiveness data
    func getEffectiveness(since: String? = nil) async throws -> Data {
        var path = "/effectiveness"
        if let since = since {
            path += "?since=\(since)"
        }
        return try await performRequest(path: path, method: "GET", body: nil as [String: String]?)
    }

    /// GET /effectiveness/summary - Get effectiveness summary
    func getEffectivenessSummary() async throws -> Data {
        return try await performRequest(path: "/effectiveness/summary", method: "GET", body: nil as [String: String]?)
    }

    /// POST /effectiveness/sessions - Record feedback session
    func postFeedbackSession(_ session: FeedbackSessionSyncRecord) async throws {
        _ = try await performRequest(
            path: "/effectiveness/sessions",
            method: "POST",
            body: session
        )
    }

    /// POST /effectiveness/events - Record feedback events
    func postFeedbackEvents(_ events: [TrackFeedbackEventSyncRecord]) async throws {
        _ = try await performRequest(
            path: "/effectiveness/events",
            method: "POST",
            body: ["events": events]
        )
    }

    /// Internal helper for API requests
    private func performRequest<T: Encodable>(
        path: String,
        method: String,
        body: T?
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if let token = KeychainHelper.get(key: "access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(statusCode)
        }

        return data
    }
}

// MARK: - Array Extension

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
