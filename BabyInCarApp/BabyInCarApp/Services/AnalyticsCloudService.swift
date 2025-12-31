//
//  AnalyticsCloudService.swift
//  BabyInCarApp
//
//  Optional cloud sync for analytics and pattern learning
//  Privacy-first: audio never leaves device, only anonymized features
//

import Foundation

// MARK: - Analytics Cloud Service

/// Optional cloud sync service for analytics
/// All syncing is opt-in and privacy-preserving
@MainActor
class AnalyticsCloudService: ObservableObject {

    // MARK: - Singleton

    static let shared = AnalyticsCloudService()

    // MARK: - Published State

    /// Whether currently syncing
    @Published var isSyncing: Bool = false

    /// Last successful sync date
    @Published var lastSyncDate: Date?

    /// Cloud insights (if available)
    @Published var cloudInsights: CloudInsights?

    /// Pending events count
    @Published var pendingEventsCount: Int = 0

    // MARK: - Dependencies

    private let apiClient = APIClient.shared
    private let profileManager = BabyProfileManager.shared

    // MARK: - Configuration

    /// Maximum events to queue before forcing sync
    private let maxPendingEvents = 50

    /// Key for storing pending events
    private let pendingEventsKey = "PendingAnalyticsEvents"

    // MARK: - State

    private var pendingEvents: [AnalyticsEvent] = []

    // MARK: - Initialization

    private init() {
        loadPendingEvents()
    }

    // MARK: - Privacy Settings

    /// Check if user has opted into cloud analytics
    var isCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "EnableCloudAnalytics")
    }

    /// Enable/disable cloud sync
    func setCloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "EnableCloudAnalytics")

        if !enabled {
            // Clear pending events if disabled
            pendingEvents.removeAll()
            savePendingEvents()
        }
    }

    // MARK: - Event Recording

    /// Record a cry detection event (only if opted in)
    func recordCryDetection(
        babyId: UUID,
        cryType: CryType,
        confidence: Double,
        intensity: Double,
        features: ExtendedAudioFeatures
    ) {
        guard isCloudSyncEnabled else { return }

        // Only record anonymized feature metrics, never raw audio
        let anonymizedPayload: [String: Any] = [
            "cry_type": cryType.rawValue,
            "confidence": confidence,
            "intensity": intensity,
            // Only statistical features, nothing that could identify the baby's voice
            "fundamental_frequency_range": categorizeFundamental(features.fundamentalFrequency),
            "spectral_centroid_range": categorizeSpectralCentroid(features.spectralCentroid),
            "calming_score": features.intensity
        ]

        let event = AnalyticsEvent(
            id: UUID(),
            type: .cryDetected,
            babyId: babyId.uuidString,
            timestamp: Date(),
            payload: anonymizedPayload
        )

        queueEvent(event)
    }

    /// Record track effectiveness (only if opted in)
    func recordTrackEffectiveness(
        babyId: UUID,
        trackId: UUID,
        cryType: CryType,
        wasEffective: Bool,
        calmingTimeSeconds: Int
    ) async {
        // Always record locally
        profileManager.recordTrackEffectiveness(
            babyId: babyId,
            trackId: trackId,
            cryType: cryType,
            wasEffective: wasEffective,
            calmingTimeSeconds: calmingTimeSeconds
        )

        // Optionally sync to cloud
        guard isCloudSyncEnabled else { return }

        do {
            try await apiClient.recordEffectiveness(
                babyId: babyId.uuidString,
                trackId: trackId.uuidString,
                wasEffective: wasEffective,
                calmingTimeSeconds: calmingTimeSeconds,
                context: "in_app",
                emergencyMode: false
            )
        } catch {
            print("AnalyticsCloudService: Failed to sync effectiveness - \(error)")

            // Queue for later
            let event = AnalyticsEvent(
                id: UUID(),
                type: .trackEffectiveness,
                babyId: babyId.uuidString,
                timestamp: Date(),
                payload: [
                    "track_id": trackId.uuidString,
                    "cry_type": cryType.rawValue,
                    "was_effective": wasEffective,
                    "calming_time": calmingTimeSeconds
                ]
            )
            queueEvent(event)
        }
    }

    /// Record playback event
    func recordPlayback(
        babyId: UUID,
        trackId: UUID,
        event: PlaybackEventType,
        position: TimeInterval = 0
    ) {
        guard isCloudSyncEnabled else { return }

        let analyticsEvent = AnalyticsEvent(
            id: UUID(),
            type: .playback,
            babyId: babyId.uuidString,
            timestamp: Date(),
            payload: [
                "track_id": trackId.uuidString,
                "event_type": event.rawValue,
                "position": position
            ]
        )

        queueEvent(analyticsEvent)
    }

    // MARK: - Cloud Insights

    /// Fetch insights from cloud
    func fetchCloudInsights(for babyId: UUID) async throws -> CloudInsights {
        guard isCloudSyncEnabled else {
            throw CloudSyncError.notEnabled
        }

        let response = try await apiClient.getInsights(babyId: babyId.uuidString)

        let insights = CloudInsights(
            totalListeningMinutes: response.insights.totalListeningTimeMinutes,
            mostEffectiveCategory: response.insights.mostEffectiveCategory,
            averageCalmingTime: response.insights.averageCalmingTimeSeconds,
            emergencySuccessRate: response.insights.emergencyModeUsage.successRate,
            emergencyActivations: response.insights.emergencyModeUsage.totalActivations,
            lastUpdated: Date()
        )

        cloudInsights = insights
        return insights
    }

    // MARK: - Sync Management

    /// Sync all pending events to cloud
    func syncPendingEvents() async {
        guard isCloudSyncEnabled else { return }
        guard !pendingEvents.isEmpty else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        var failedEvents: [AnalyticsEvent] = []

        for event in pendingEvents {
            do {
                try await syncEvent(event)
            } catch {
                failedEvents.append(event)
            }
        }

        pendingEvents = failedEvents
        pendingEventsCount = pendingEvents.count
        savePendingEvents()

        if failedEvents.isEmpty {
            lastSyncDate = Date()
        }
    }

    /// Force immediate sync
    func forceSyncNow() async {
        await syncPendingEvents()
    }

    // MARK: - Private Methods

    private func queueEvent(_ event: AnalyticsEvent) {
        pendingEvents.append(event)
        pendingEventsCount = pendingEvents.count

        if pendingEvents.count > maxPendingEvents {
            pendingEvents.removeFirst()
        }

        savePendingEvents()

        // Try immediate sync if connected
        Task {
            await syncPendingEvents()
        }
    }

    private func syncEvent(_ event: AnalyticsEvent) async throws {
        switch event.type {
        case .cryDetected:
            // Cloud learning endpoint - simplified for now
            // In production, this would be a dedicated analytics endpoint
            break

        case .trackEffectiveness:
            guard let trackId = event.payload["track_id"] as? String,
                  let wasEffective = event.payload["was_effective"] as? Bool,
                  let calmingTime = event.payload["calming_time"] as? Int else {
                return
            }

            try await apiClient.recordEffectiveness(
                babyId: event.babyId,
                trackId: trackId,
                wasEffective: wasEffective,
                calmingTimeSeconds: calmingTime,
                context: "in_app",
                emergencyMode: false
            )

        case .playback:
            // Playback events are less critical, just log locally
            break
        }
    }

    // MARK: - Anonymization Helpers

    /// Categorize fundamental frequency to anonymize
    private func categorizeFundamental(_ freq: Double) -> String {
        if freq < 350 { return "low" }
        if freq < 450 { return "medium" }
        if freq < 550 { return "high" }
        return "very_high"
    }

    /// Categorize spectral centroid to anonymize
    private func categorizeSpectralCentroid(_ centroid: Double) -> String {
        if centroid < 600 { return "low" }
        if centroid < 1000 { return "medium" }
        if centroid < 1500 { return "high" }
        return "very_high"
    }

    // MARK: - Persistence

    private func loadPendingEvents() {
        guard let data = UserDefaults.standard.data(forKey: pendingEventsKey),
              let events = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return
        }
        pendingEvents = events
        pendingEventsCount = events.count
    }

    private func savePendingEvents() {
        guard let data = try? JSONEncoder().encode(pendingEvents) else { return }
        UserDefaults.standard.set(data, forKey: pendingEventsKey)
    }

    // MARK: - Data Export

    /// Export all local analytics data
    func exportLocalData() -> Data? {
        let exportData = AnalyticsExport(
            pendingEvents: pendingEvents,
            cloudInsights: cloudInsights,
            exportDate: Date()
        )
        return try? JSONEncoder().encode(exportData)
    }

    /// Clear all analytics data
    func clearAllData() {
        pendingEvents.removeAll()
        cloudInsights = nil
        savePendingEvents()
        UserDefaults.standard.removeObject(forKey: "EnableCloudAnalytics")
    }
}

// MARK: - Supporting Types

/// Analytics event for queuing
struct AnalyticsEvent: Codable {
    let id: UUID
    let type: AnalyticsEventType
    let babyId: String
    let timestamp: Date
    let payload: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, type, babyId, timestamp, payload
    }

    init(id: UUID, type: AnalyticsEventType, babyId: String, timestamp: Date, payload: [String: Any]) {
        self.id = id
        self.type = type
        self.babyId = babyId
        self.timestamp = timestamp
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(AnalyticsEventType.self, forKey: .type)
        babyId = try container.decode(String.self, forKey: .babyId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Decode payload as generic dictionary
        if let payloadData = try? container.decode(Data.self, forKey: .payload),
           let dict = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            payload = dict
        } else {
            payload = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(babyId, forKey: .babyId)
        try container.encode(timestamp, forKey: .timestamp)

        // Encode payload as data
        if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
            try container.encode(payloadData, forKey: .payload)
        }
    }
}

/// Types of analytics events
enum AnalyticsEventType: String, Codable {
    case cryDetected
    case trackEffectiveness
    case playback
}

/// Playback event types
enum PlaybackEventType: String, Codable {
    case started
    case paused
    case resumed
    case completed
    case skipped
}

/// Cloud-synced insights
struct CloudInsights: Codable {
    let totalListeningMinutes: Int
    let mostEffectiveCategory: String?
    let averageCalmingTime: Int
    let emergencySuccessRate: Double
    let emergencyActivations: Int
    let lastUpdated: Date
}

/// Export container
struct AnalyticsExport: Codable {
    let pendingEvents: [AnalyticsEvent]
    let cloudInsights: CloudInsights?
    let exportDate: Date
}

/// Cloud sync errors
enum CloudSyncError: Error, LocalizedError {
    case notEnabled
    case syncFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Cloud sync is not enabled"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}
