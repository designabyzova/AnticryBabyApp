//
//  FreemiumGatekeeper.swift
//  BabyInCarApp
//
//  Controls access to premium features with a generous free tier
//  Philosophy: Cry detection is ALWAYS free - it's our core value proposition
//

import Foundation
import Combine

/// Manages freemium access control and content gating
@MainActor
final class FreemiumGatekeeper: ObservableObject {
    static let shared = FreemiumGatekeeper()

    // MARK: - Configuration
    struct FreeTierConfig {
        /// Number of free tracks per category
        static let freeTracksPerCategory = 4

        /// Total free tracks across all categories
        static let totalFreeTracks = 25

        /// Days of effectiveness history for free users
        static let freeEffectivenessHistoryDays = 7

        /// Maximum upgrade prompts per session
        static let maxUpgradePromptsPerSession = 2

        /// Hours to wait before showing prompt for same track
        static let promptCooldownHours = 24

        /// Seconds of premium track preview allowed
        static let premiumPreviewSeconds: TimeInterval = 10

        /// Features that are ALWAYS free (never paywall these!)
        static let alwaysFreeFeatures: Set<Feature> = [
            .cryDetection,
            .cryClassification,
            .babyProfile,
            .favorites,
            .basicEffectiveness,
            .carPlayBasic,
            .itHelpedFeedback
        ]

        /// Premium-only features
        static let premiumFeatures: Set<Feature> = [
            .unlimitedContent,
            .offlineDownloads,
            .fullBabyMIMInsights,
            .llmRecommendations,
            .moodPredictions,
            .advancedAnalytics,
            .prioritySupport,
            .customSoundMixes
        ]
    }

    // MARK: - Feature Enum
    enum Feature: String, CaseIterable {
        // Always Free
        case cryDetection = "cry_detection"
        case cryClassification = "cry_classification"
        case babyProfile = "baby_profile"
        case favorites = "favorites"
        case basicEffectiveness = "basic_effectiveness"
        case carPlayBasic = "carplay_basic"
        case itHelpedFeedback = "it_helped_feedback"

        // Premium
        case unlimitedContent = "unlimited_content"
        case offlineDownloads = "offline_downloads"
        case fullBabyMIMInsights = "full_babymim_insights"
        case llmRecommendations = "llm_recommendations"
        case moodPredictions = "mood_predictions"
        case advancedAnalytics = "advanced_analytics"
        case prioritySupport = "priority_support"
        case customSoundMixes = "custom_sound_mixes"

        var displayName: String {
            switch self {
            case .cryDetection: return "Cry Detection"
            case .cryClassification: return "Cry Type Classification"
            case .babyProfile: return "Baby Profile"
            case .favorites: return "Favorites"
            case .basicEffectiveness: return "Basic Effectiveness Tracking"
            case .carPlayBasic: return "CarPlay Support"
            case .itHelpedFeedback: return "It Helped! Feedback"
            case .unlimitedContent: return "Unlimited Content"
            case .offlineDownloads: return "Offline Downloads"
            case .fullBabyMIMInsights: return "Full AI Insights"
            case .llmRecommendations: return "AI Recommendations"
            case .moodPredictions: return "Mood Predictions"
            case .advancedAnalytics: return "Advanced Analytics"
            case .prioritySupport: return "Priority Support"
            case .customSoundMixes: return "Custom Sound Mixes"
            }
        }

        var isPremium: Bool {
            FreeTierConfig.premiumFeatures.contains(self)
        }
    }

    // MARK: - Published Properties
    @Published private(set) var freeTrackIds: Set<UUID> = []
    @Published private(set) var promptsShownThisSession = 0
    @Published private(set) var lastFreeTrackRotation: Date?
    @Published private(set) var premiumTracksViewedCount = 0

    private let userDefaults: UserDefaults
    private var promptCooldowns: [UUID: Date] = [:]
    private var viewedPremiumTrackIds: Set<UUID> = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadState()
    }

    // For testing - use factory method
    static func createForTesting(userDefaults: UserDefaults) -> FreemiumGatekeeper {
        let gatekeeper = FreemiumGatekeeper(userDefaults: userDefaults)
        return gatekeeper
    }

    // MARK: - Access Control

    /// Check if user has access to a feature
    func hasAccess(to feature: Feature) -> Bool {
        // Always-free features
        if FreeTierConfig.alwaysFreeFeatures.contains(feature) {
            return true
        }

        // Premium or trial users have full access
        if hasPremiumAccess {
            return true
        }

        // Premium features blocked for free users
        return false
    }

    /// Check if user can play a specific track
    func canPlayTrack(_ track: AudioTrack) -> Bool {
        // During trial or with premium, all tracks accessible
        if hasPremiumAccess {
            return true
        }

        // Check if track is in free tier
        return isTrackFree(track)
    }

    /// Check if a track is in the free tier
    func isTrackFree(_ track: AudioTrack) -> Bool {
        // Non-premium tracks are always free
        if !track.isPremium {
            return true
        }

        // Check if it's in our rotating free selection
        if freeTrackIds.contains(track.id) {
            return true
        }

        return false
    }

    /// Get access type for a track
    func accessType(for track: AudioTrack) -> TrackAccessType {
        if !track.isPremium {
            return .free
        }

        if hasPremiumAccess {
            return .premium
        }

        if freeTrackIds.contains(track.id) {
            return .freeRotating
        }

        return .locked
    }

    enum TrackAccessType {
        case free           // Always free track
        case freeRotating   // Part of weekly free rotation
        case premium        // User has premium access
        case locked         // Requires upgrade

        var badge: String? {
            switch self {
            case .free: return nil
            case .freeRotating: return "FREE"
            case .premium: return nil
            case .locked: return "PREMIUM"
            }
        }

        var canPlay: Bool {
            self != .locked
        }
    }

    // MARK: - Premium Access Check

    var hasPremiumAccess: Bool {
        TrialManager.shared.hasPremiumAccess
    }

    // MARK: - Soft Paywall Logic

    /// Check if we should show an upgrade prompt for this action
    func shouldShowUpgradePrompt(for track: AudioTrack) -> Bool {
        // Don't prompt if user has access
        if canPlayTrack(track) {
            return false
        }

        // Check session limit
        if promptsShownThisSession >= FreeTierConfig.maxUpgradePromptsPerSession {
            return false
        }

        // Check per-track cooldown
        if let cooldownEnd = promptCooldowns[track.id], Date() < cooldownEnd {
            return false
        }

        return true
    }

    /// Record that we showed an upgrade prompt
    func recordPromptShown(for track: AudioTrack) {
        promptsShownThisSession += 1
        let cooldownEnd = Date().addingTimeInterval(TimeInterval(FreeTierConfig.promptCooldownHours * 3600))
        promptCooldowns[track.id] = cooldownEnd

        // Analytics
        NotificationCenter.default.post(
            name: .softPaywallShown,
            object: nil,
            userInfo: ["trackId": track.id.uuidString, "promptCount": promptsShownThisSession]
        )
    }

    /// Record prompt dismissal
    func recordPromptDismissed(for track: AudioTrack) {
        NotificationCenter.default.post(
            name: .softPaywallDismissed,
            object: nil,
            userInfo: ["trackId": track.id.uuidString]
        )
    }

    /// Track when user views/previews a premium track
    func recordPremiumTrackViewed(_ track: AudioTrack) {
        guard track.isPremium, !hasPremiumAccess else { return }

        if !viewedPremiumTrackIds.contains(track.id) {
            viewedPremiumTrackIds.insert(track.id)
            premiumTracksViewedCount = viewedPremiumTrackIds.count
            saveViewedPremiumTracks()
        }
    }

    /// Reset session prompt counter (call on app background/foreground)
    func resetSessionPrompts() {
        promptsShownThisSession = 0
    }

    // MARK: - Free Track Selection

    /// Select free tracks for the current period
    func selectFreeTracksFrom(_ allTracks: [AudioTrack]) {
        var selectedIds = Set<UUID>()
        let premiumTracks = allTracks.filter { $0.isPremium }

        // Group by category
        let byCategory = Dictionary(grouping: premiumTracks) { $0.category }

        // Select top tracks per category (prioritize high calming score)
        for (_, tracks) in byCategory {
            let sorted = tracks.sorted { $0.calmingScore > $1.calmingScore }
            let toSelect = min(FreeTierConfig.freeTracksPerCategory, sorted.count)
            for i in 0..<toSelect {
                selectedIds.insert(sorted[i].id)
            }
        }

        // If we haven't hit total limit, add more from highest calming scores
        if selectedIds.count < FreeTierConfig.totalFreeTracks {
            let remaining = premiumTracks
                .filter { !selectedIds.contains($0.id) }
                .sorted { $0.calmingScore > $1.calmingScore }

            for track in remaining {
                if selectedIds.count >= FreeTierConfig.totalFreeTracks { break }
                selectedIds.insert(track.id)
            }
        }

        freeTrackIds = selectedIds
        lastFreeTrackRotation = Date()
        saveFreeTrackIds()
    }

    /// Check if free tracks should be rotated (weekly)
    func shouldRotateFreeTracks() -> Bool {
        guard let lastRotation = lastFreeTrackRotation else { return true }
        let daysSinceRotation = Calendar.current.dateComponents([.day], from: lastRotation, to: Date()).day ?? 0
        return daysSinceRotation >= 7
    }

    // MARK: - Feature Comparison

    /// Get comparison data for subscription view
    struct TierComparison {
        let feature: String
        let freeValue: String
        let premiumValue: String
    }

    var tierComparisons: [TierComparison] {
        [
            TierComparison(feature: "Content Library", freeValue: "25 tracks", premiumValue: "Unlimited"),
            TierComparison(feature: "Cry Detection", freeValue: "✓ Full", premiumValue: "✓ Full"),
            TierComparison(feature: "Cry Classification", freeValue: "✓ Full", premiumValue: "✓ Full"),
            TierComparison(feature: "Baby Profile", freeValue: "✓ 1 baby", premiumValue: "✓ 3 babies"),
            TierComparison(feature: "Effectiveness Tracking", freeValue: "7 days", premiumValue: "Unlimited"),
            TierComparison(feature: "AI Insights", freeValue: "Basic", premiumValue: "Full BabyMIM"),
            TierComparison(feature: "Offline Downloads", freeValue: "—", premiumValue: "✓ Unlimited"),
            TierComparison(feature: "CarPlay", freeValue: "✓ Basic", premiumValue: "✓ Smart Mode"),
            TierComparison(feature: "Mood Predictions", freeValue: "—", premiumValue: "✓"),
            TierComparison(feature: "Priority Support", freeValue: "—", premiumValue: "✓")
        ]
    }

    // MARK: - Persistence

    private func loadState() {
        if let ids = userDefaults.array(forKey: "freeTrackIds") as? [String] {
            freeTrackIds = Set(ids.compactMap { UUID(uuidString: $0) })
        }
        lastFreeTrackRotation = userDefaults.object(forKey: "lastFreeTrackRotation") as? Date

        // Load viewed premium tracks
        if let viewedIds = userDefaults.array(forKey: "viewedPremiumTrackIds") as? [String] {
            viewedPremiumTrackIds = Set(viewedIds.compactMap { UUID(uuidString: $0) })
            premiumTracksViewedCount = viewedPremiumTrackIds.count
        }
    }

    private func saveFreeTrackIds() {
        let ids = freeTrackIds.map { $0.uuidString }
        userDefaults.set(ids, forKey: "freeTrackIds")
        userDefaults.set(lastFreeTrackRotation, forKey: "lastFreeTrackRotation")
    }

    private func saveViewedPremiumTracks() {
        let ids = viewedPremiumTrackIds.map { $0.uuidString }
        userDefaults.set(ids, forKey: "viewedPremiumTrackIds")
    }

    #if DEBUG
    func resetForTesting() {
        freeTrackIds = []
        promptsShownThisSession = 0
        promptCooldowns = [:]
        userDefaults.removeObject(forKey: "freeTrackIds")
        userDefaults.removeObject(forKey: "lastFreeTrackRotation")
    }
    #endif
}

// MARK: - Notification Names (Analytics Events)
extension Notification.Name {
    // Soft Paywall Events
    static let softPaywallShown = Notification.Name("softPaywallShown")
    static let softPaywallDismissed = Notification.Name("softPaywallDismissed")
    static let softPaywallConverted = Notification.Name("softPaywallConverted")

    // Content Events
    static let premiumContentPlayed = Notification.Name("premiumContentPlayed")
    static let premiumContentBlocked = Notification.Name("premiumContentBlocked")
    static let freeContentPlayed = Notification.Name("freeContentPlayed")

    // Feature Gating Events
    static let featureGated = Notification.Name("featureGated")
    static let featureUnlocked = Notification.Name("featureUnlocked")

    // Upgrade Flow Events
    static let upgradeViewShown = Notification.Name("upgradeViewShown")
    static let upgradeCompleted = Notification.Name("upgradeCompleted")
    static let upgradeAbandoned = Notification.Name("upgradeAbandoned")
}

// MARK: - Preview Helper
extension FreemiumGatekeeper {
    /// Get personalized upgrade message based on usage
    func personalizedUpgradeMessage(babyName: String?, unlockedTrackCount: Int) -> String {
        let name = babyName ?? "your baby"

        if unlockedTrackCount > 0 {
            return "Unlock \(unlockedTrackCount) more tracks \(name) might love"
        } else {
            return "Get unlimited soothing sounds for \(name)"
        }
    }

    /// Count how many premium tracks user is missing
    func countLockedTracks(in tracks: [AudioTrack]) -> Int {
        tracks.filter { !canPlayTrack($0) }.count
    }
}
