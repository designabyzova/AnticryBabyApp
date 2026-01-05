//
//  FreemiumGatekeeperTests.swift
//  BabyInCarAppTests
//
//  Unit tests for FreemiumGatekeeper - access control and content gating
//

import Testing
import Foundation
@testable import BabyInCarApp

@Suite("Freemium Gatekeeper")
struct FreemiumGatekeeperTests {

    // MARK: - Feature Access Tests

    @Test("Always-free features are accessible without premium")
    func alwaysFreeFeatures() {
        let defaults = UserDefaults(suiteName: "test_free_features")!
        defaults.removePersistentDomain(forName: "test_free_features")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // These should always be accessible
        #expect(gatekeeper.hasAccess(to: .cryDetection))
        #expect(gatekeeper.hasAccess(to: .cryClassification))
        #expect(gatekeeper.hasAccess(to: .babyProfile))
        #expect(gatekeeper.hasAccess(to: .favorites))
        #expect(gatekeeper.hasAccess(to: .basicEffectiveness))
        #expect(gatekeeper.hasAccess(to: .carPlayBasic))
        #expect(gatekeeper.hasAccess(to: .itHelpedFeedback))
    }

    @Test("Premium features are blocked for free users")
    func premiumFeaturesBlocked() {
        let defaults = UserDefaults(suiteName: "test_premium_blocked")!
        defaults.removePersistentDomain(forName: "test_premium_blocked")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // These should be blocked for free users
        #expect(!gatekeeper.hasAccess(to: .unlimitedContent))
        #expect(!gatekeeper.hasAccess(to: .offlineDownloads))
        #expect(!gatekeeper.hasAccess(to: .fullBabyMIMInsights))
        #expect(!gatekeeper.hasAccess(to: .llmRecommendations))
        #expect(!gatekeeper.hasAccess(to: .moodPredictions))
        #expect(!gatekeeper.hasAccess(to: .advancedAnalytics))
        #expect(!gatekeeper.hasAccess(to: .prioritySupport))
        #expect(!gatekeeper.hasAccess(to: .customSoundMixes))
    }

    // MARK: - Track Access Tests

    @Test("Non-premium tracks are always playable")
    func nonPremiumTracksPlayable() {
        let defaults = UserDefaults(suiteName: "test_non_premium_tracks")!
        defaults.removePersistentDomain(forName: "test_non_premium_tracks")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // Create a non-premium track
        let freeTrack = AudioTrack(
            title: "Free Lullaby",
            category: .classicalMusic,
            duration: 180,
            calmingScore: 0.8,
            audioSourceType: .bundled,
            isPremium: false
        )

        #expect(gatekeeper.canPlayTrack(freeTrack))
        #expect(gatekeeper.accessType(for: freeTrack) == .free)
    }

    @Test("Premium tracks are locked for free users")
    func premiumTracksLocked() {
        let defaults = UserDefaults(suiteName: "test_premium_locked")!
        defaults.removePersistentDomain(forName: "test_premium_locked")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // Create a premium track (not in free rotation)
        let premiumTrack = AudioTrack(
            title: "Premium Melody",
            category: .classicalMusic,
            duration: 180,
            calmingScore: 0.9,
            audioSourceType: .api,
            isPremium: true
        )

        #expect(!gatekeeper.canPlayTrack(premiumTrack))
        #expect(gatekeeper.accessType(for: premiumTrack) == .locked)
    }

    // MARK: - Free Track Rotation Tests

    @Test("Free rotation includes tracks from multiple categories")
    func freeRotationMultipleCategories() {
        let defaults = UserDefaults(suiteName: "test_rotation_categories")!
        defaults.removePersistentDomain(forName: "test_rotation_categories")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // Create premium tracks from different categories
        let tracks = [
            AudioTrack(title: "Classical 1", category: .classicalMusic, duration: 180, calmingScore: 0.9, audioSourceType: .api, isPremium: true),
            AudioTrack(title: "Classical 2", category: .classicalMusic, duration: 180, calmingScore: 0.85, audioSourceType: .api, isPremium: true),
            AudioTrack(title: "Nature 1", category: .natureSounds, duration: 180, calmingScore: 0.88, audioSourceType: .api, isPremium: true),
            AudioTrack(title: "WhiteNoise 1", category: .ambient, duration: 180, calmingScore: 0.92, audioSourceType: .api, isPremium: true)
        ]

        gatekeeper.selectFreeTracksFrom(tracks)

        // Should have selected tracks from rotation
        #expect(gatekeeper.freeTrackIds.count > 0)
        #expect(gatekeeper.lastFreeTrackRotation != nil)
    }

    // MARK: - Soft Paywall Tests

    @Test("Prompt rate limiting respects session limit")
    func promptRateLimiting() {
        let defaults = UserDefaults(suiteName: "test_rate_limiting")!
        defaults.removePersistentDomain(forName: "test_rate_limiting")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        let premiumTrack = AudioTrack(
            title: "Premium Track",
            category: .classicalMusic,
            duration: 180,
            calmingScore: 0.9,
            audioSourceType: .api,
            isPremium: true
        )

        // First prompt should be allowed
        #expect(gatekeeper.shouldShowUpgradePrompt(for: premiumTrack))

        // Record showing prompt
        gatekeeper.recordPromptShown(for: premiumTrack)

        // Second prompt for same track should be blocked (cooldown)
        #expect(!gatekeeper.shouldShowUpgradePrompt(for: premiumTrack))
    }

    @Test("Session reset clears prompt counter")
    func sessionResetClearsCounter() {
        let defaults = UserDefaults(suiteName: "test_session_reset")!
        defaults.removePersistentDomain(forName: "test_session_reset")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        // Record multiple prompts
        let track = AudioTrack(title: "Premium", category: .classicalMusic, duration: 180, calmingScore: 0.9, audioSourceType: .api, isPremium: true)
        gatekeeper.recordPromptShown(for: track)
        gatekeeper.recordPromptShown(for: track)

        #expect(gatekeeper.promptsShownThisSession == 2)

        // Reset session
        gatekeeper.resetSessionPrompts()

        #expect(gatekeeper.promptsShownThisSession == 0)
    }

    // MARK: - Premium Tracks Viewed Tracking

    @Test("Tracks viewed premium tracks correctly")
    func tracksViewedPremiumTracks() {
        let defaults = UserDefaults(suiteName: "test_viewed_tracking")!
        defaults.removePersistentDomain(forName: "test_viewed_tracking")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        #expect(gatekeeper.premiumTracksViewedCount == 0)

        let premiumTrack1 = AudioTrack(title: "Premium 1", category: .classicalMusic, duration: 180, calmingScore: 0.9, audioSourceType: .api, isPremium: true)
        let premiumTrack2 = AudioTrack(title: "Premium 2", category: .natureSounds, duration: 180, calmingScore: 0.85, audioSourceType: .api, isPremium: true)

        gatekeeper.recordPremiumTrackViewed(premiumTrack1)
        #expect(gatekeeper.premiumTracksViewedCount == 1)

        gatekeeper.recordPremiumTrackViewed(premiumTrack2)
        #expect(gatekeeper.premiumTracksViewedCount == 2)

        // Same track shouldn't be counted twice
        gatekeeper.recordPremiumTrackViewed(premiumTrack1)
        #expect(gatekeeper.premiumTracksViewedCount == 2)
    }

    @Test("Non-premium tracks are not tracked as viewed")
    func nonPremiumNotTracked() {
        let defaults = UserDefaults(suiteName: "test_non_premium_not_tracked")!
        defaults.removePersistentDomain(forName: "test_non_premium_not_tracked")

        let gatekeeper = FreemiumGatekeeper.createForTesting(userDefaults: defaults)

        let freeTrack = AudioTrack(title: "Free", category: .classicalMusic, duration: 180, calmingScore: 0.8, audioSourceType: .bundled, isPremium: false)

        gatekeeper.recordPremiumTrackViewed(freeTrack)

        #expect(gatekeeper.premiumTracksViewedCount == 0)
    }

    // MARK: - Configuration Tests

    @Test("Free tier config values are correct")
    func freeTierConfigValues() {
        let config = FreemiumGatekeeper.FreeTierConfig.self

        // Verify config constants
        #expect(config.freeTracksPerCategory == 4)
        #expect(config.totalFreeTracks == 25)
        #expect(config.freeEffectivenessHistoryDays == 7)
        #expect(config.maxUpgradePromptsPerSession == 2)
        #expect(config.promptCooldownHours == 24)
        #expect(config.premiumPreviewSeconds == 10)
    }

    // MARK: - Access Type Tests

    @Test("Access type badge returns correct values")
    func accessTypeBadges() {
        #expect(FreemiumGatekeeper.TrackAccessType.free.badge == nil)
        #expect(FreemiumGatekeeper.TrackAccessType.freeRotating.badge == "FREE")
        #expect(FreemiumGatekeeper.TrackAccessType.premium.badge == nil)
        #expect(FreemiumGatekeeper.TrackAccessType.locked.badge == "PREMIUM")
    }

    @Test("Access type canPlay returns correct values")
    func accessTypeCanPlay() {
        #expect(FreemiumGatekeeper.TrackAccessType.free.canPlay == true)
        #expect(FreemiumGatekeeper.TrackAccessType.freeRotating.canPlay == true)
        #expect(FreemiumGatekeeper.TrackAccessType.premium.canPlay == true)
        #expect(FreemiumGatekeeper.TrackAccessType.locked.canPlay == false)
    }

    // MARK: - Feature Display Names

    @Test("Feature display names are descriptive")
    func featureDisplayNames() {
        #expect(FreemiumGatekeeper.Feature.cryDetection.displayName == "Cry Detection")
        #expect(FreemiumGatekeeper.Feature.unlimitedContent.displayName == "Unlimited Content")
        #expect(FreemiumGatekeeper.Feature.fullBabyMIMInsights.displayName == "Full AI Insights")
    }

    @Test("Feature premium status is correct")
    func featurePremiumStatus() {
        // Always free features
        #expect(!FreemiumGatekeeper.Feature.cryDetection.isPremium)
        #expect(!FreemiumGatekeeper.Feature.babyProfile.isPremium)

        // Premium features
        #expect(FreemiumGatekeeper.Feature.unlimitedContent.isPremium)
        #expect(FreemiumGatekeeper.Feature.offlineDownloads.isPremium)
        #expect(FreemiumGatekeeper.Feature.llmRecommendations.isPremium)
    }
}
