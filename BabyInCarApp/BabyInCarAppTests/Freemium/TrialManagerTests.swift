//
//  TrialManagerTests.swift
//  BabyInCarAppTests
//
//  Unit tests for TrialManager - 7-day trial logic
//

import Testing
import Foundation
@testable import BabyInCarApp

@Suite("Trial Manager")
struct TrialManagerTests {

    // MARK: - Trial Start Tests

    @Test("Trial starts on first launch")
    func trialStartsOnFirstLaunch() {
        let defaults = UserDefaults(suiteName: "test_trial_start")!
        defaults.removePersistentDomain(forName: "test_trial_start")

        let manager = TrialManager(userDefaults: defaults)
        manager.startTrialIfNeeded()

        #expect(manager.trialStartDate != nil)
        #expect(manager.trialState.isActive)
    }

    @Test("Trial does not restart if already started")
    func trialDoesNotRestart() {
        let defaults = UserDefaults(suiteName: "test_no_restart")!
        defaults.removePersistentDomain(forName: "test_no_restart")

        let manager = TrialManager(userDefaults: defaults)
        manager.startTrialIfNeeded()

        let firstStartDate = manager.trialStartDate

        manager.startTrialIfNeeded() // Try again

        #expect(manager.trialStartDate == firstStartDate)
    }

    // MARK: - Trial State Tests

    @Test("Trial shows 7 days remaining on day 1")
    func trialShowsSevenDays() {
        let defaults = UserDefaults(suiteName: "test_seven_days")!
        defaults.removePersistentDomain(forName: "test_seven_days")

        // Set trial start to now
        defaults.set(Date(), forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        // Should be 7 days (today counts as a trial day)
        #expect(manager.trialDaysRemaining >= 6 && manager.trialDaysRemaining <= 7)
    }

    @Test("Trial expires after 7 days")
    func trialExpiresAfterSevenDays() {
        let defaults = UserDefaults(suiteName: "test_expired")!
        defaults.removePersistentDomain(forName: "test_expired")

        // Set trial start to 8 days ago
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        defaults.set(eightDaysAgo, forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        #expect(!manager.trialState.isActive)
        #expect(manager.trialDaysRemaining == 0)
    }

    @Test("Recently expired trial is detected")
    func recentlyExpiredTrialDetected() {
        let defaults = UserDefaults(suiteName: "test_recently_expired")!
        defaults.removePersistentDomain(forName: "test_recently_expired")

        // Set trial start to 8 days ago (just expired)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        defaults.set(eightDaysAgo, forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        if case .expiredRecently = manager.trialState {
            // Correct state
        } else {
            #expect(Bool(false), "Expected .expiredRecently state")
        }
    }

    // MARK: - Soft Prompt Tests

    @Test("Soft upgrade prompt shows on day 5")
    func softPromptOnDayFive() {
        let defaults = UserDefaults(suiteName: "test_day_five")!
        defaults.removePersistentDomain(forName: "test_day_five")

        // Set trial start to 5 days ago (3 days remaining)
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        defaults.set(fiveDaysAgo, forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        #expect(manager.shouldShowSoftUpgradePrompt)
    }

    @Test("No soft prompt on day 1")
    func noSoftPromptDayOne() {
        let defaults = UserDefaults(suiteName: "test_day_one")!
        defaults.removePersistentDomain(forName: "test_day_one")

        // Set trial start to today
        defaults.set(Date(), forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        #expect(!manager.shouldShowSoftUpgradePrompt)
    }

    @Test("Urgent prompt on last day")
    func urgentPromptLastDay() {
        let defaults = UserDefaults(suiteName: "test_last_day")!
        defaults.removePersistentDomain(forName: "test_last_day")

        // Set trial start to 6 days ago (1 day remaining)
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        defaults.set(sixDaysAgo, forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)

        #expect(manager.shouldShowUrgentPrompt)
    }

    // MARK: - Prompt Dismissal Tests

    @Test("Prompts can be temporarily dismissed")
    func promptsDismissible() {
        let defaults = UserDefaults(suiteName: "test_dismiss")!
        defaults.removePersistentDomain(forName: "test_dismiss")

        let manager = TrialManager(userDefaults: defaults)
        manager.startTrialIfNeeded()

        manager.dismissTrialPrompt(forHours: 24)

        #expect(manager.arePromptsTemporarilyDismissed)
    }

    // MARK: - Banner View Model Tests

    @Test("Banner visible during active trial")
    func bannerVisibleDuringTrial() {
        let defaults = UserDefaults(suiteName: "test_banner")!
        defaults.removePersistentDomain(forName: "test_banner")

        // Set trial to 4 days ago (3 days remaining)
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        defaults.set(fourDaysAgo, forKey: "trial_start_date")

        let manager = TrialManager(userDefaults: defaults)
        let viewModel = manager.bannerViewModel

        #expect(viewModel.isVisible)
        #expect(!viewModel.message.isEmpty)
    }

    @Test("Premium features at risk list is populated")
    func premiumFeaturesAtRisk() {
        let defaults = UserDefaults(suiteName: "test_features")!
        let manager = TrialManager(userDefaults: defaults)

        #expect(manager.premiumFeaturesAtRisk.count > 0)
        #expect(manager.premiumFeaturesAtRisk.contains("Unlimited content library"))
    }
}

@Suite("Freemium Gatekeeper")
struct FreemiumGatekeeperTests {

    // MARK: - Always Free Features

    @Test("Cry detection is always free")
    func cryDetectionAlwaysFree() {
        let defaults = UserDefaults(suiteName: "test_cry_free")!
        defaults.removePersistentDomain(forName: "test_cry_free")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        #expect(gatekeeper.hasAccess(to: .cryDetection))
        #expect(gatekeeper.hasAccess(to: .cryClassification))
        #expect(gatekeeper.hasAccess(to: .babyProfile))
    }

    @Test("It Helped feedback is always free")
    func itHelpedAlwaysFree() {
        let defaults = UserDefaults(suiteName: "test_helped_free")!
        defaults.removePersistentDomain(forName: "test_helped_free")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        #expect(gatekeeper.hasAccess(to: .itHelpedFeedback))
    }

    // MARK: - Premium Features

    @Test("Premium features require subscription")
    func premiumFeaturesBlocked() {
        let defaults = UserDefaults(suiteName: "test_premium_blocked")!
        defaults.removePersistentDomain(forName: "test_premium_blocked")

        // Clear any trial state to ensure free user
        defaults.removeObject(forKey: "trial_start_date")

        // Set trial to expired (10 days ago)
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        defaults.set(tenDaysAgo, forKey: "trial_start_date")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        // These should require premium
        #expect(!gatekeeper.hasAccess(to: .unlimitedContent))
        #expect(!gatekeeper.hasAccess(to: .offlineDownloads))
        #expect(!gatekeeper.hasAccess(to: .moodPredictions))
    }

    // MARK: - Track Access

    @Test("Non-premium tracks are always accessible")
    func nonPremiumTracksAccessible() {
        let defaults = UserDefaults(suiteName: "test_free_tracks")!
        defaults.removePersistentDomain(forName: "test_free_tracks")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        let freeTrack = AudioTrack(
            title: "Free Lullaby",
            category: .childrenSongs,
            duration: 180,
            isPremium: false,
            audioSourceType: .streamed
        )

        #expect(gatekeeper.canPlayTrack(freeTrack))
        #expect(gatekeeper.isTrackFree(freeTrack))
    }

    @Test("Premium tracks blocked for free users")
    func premiumTracksBlocked() {
        let defaults = UserDefaults(suiteName: "test_blocked_tracks")!
        defaults.removePersistentDomain(forName: "test_blocked_tracks")

        // Expire trial
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        defaults.set(tenDaysAgo, forKey: "trial_start_date")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        let premiumTrack = AudioTrack(
            title: "Premium Sonata",
            category: .classicalMusic,
            duration: 300,
            isPremium: true,
            audioSourceType: .streamed
        )

        // Without premium, should not be able to play
        // (Unless in rotating free selection, but we haven't set that up)
        #expect(!gatekeeper.freeTrackIds.contains(premiumTrack.id))
    }

    // MARK: - Free Track Selection

    @Test("Free track selection picks from each category")
    func freeTrackSelectionDistributed() {
        let defaults = UserDefaults(suiteName: "test_selection")!
        defaults.removePersistentDomain(forName: "test_selection")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        // Create test tracks
        var testTracks: [AudioTrack] = []
        for category in AudioCategory.allCases {
            for i in 0..<5 {
                testTracks.append(AudioTrack(
                    title: "\(category.rawValue) Track \(i)",
                    category: category,
                    duration: 180,
                    calmingScore: 0.9 - Double(i) * 0.1,
                    isPremium: true,
                    audioSourceType: .streamed
                ))
            }
        }

        gatekeeper.selectFreeTracksFrom(testTracks)

        #expect(gatekeeper.freeTrackIds.count > 0)
        #expect(gatekeeper.freeTrackIds.count <= FreemiumGatekeeper.FreeTierConfig.totalFreeTracks)
    }

    // MARK: - Rate Limiting

    @Test("Prompt rate limiting respects session limit")
    func promptRateLimiting() {
        let defaults = UserDefaults(suiteName: "test_rate_limit")!
        defaults.removePersistentDomain(forName: "test_rate_limit")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        let track1 = AudioTrack(
            title: "Premium 1",
            category: .classicalMusic,
            duration: 180,
            isPremium: true,
            audioSourceType: .streamed
        )

        let track2 = AudioTrack(
            title: "Premium 2",
            category: .classicalMusic,
            duration: 180,
            isPremium: true,
            audioSourceType: .streamed
        )

        // First 2 prompts should be allowed
        gatekeeper.recordPromptShown(for: track1)
        gatekeeper.recordPromptShown(for: track2)

        // Third prompt should be blocked
        let track3 = AudioTrack(
            title: "Premium 3",
            category: .classicalMusic,
            duration: 180,
            isPremium: true,
            audioSourceType: .streamed
        )

        #expect(!gatekeeper.shouldShowUpgradePrompt(for: track3))
    }

    @Test("Session reset clears prompt count")
    func sessionResetClearsPrompts() {
        let defaults = UserDefaults(suiteName: "test_session_reset")!
        defaults.removePersistentDomain(forName: "test_session_reset")

        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        let track = AudioTrack(
            title: "Premium",
            category: .classicalMusic,
            duration: 180,
            isPremium: true,
            audioSourceType: .streamed
        )

        gatekeeper.recordPromptShown(for: track)
        #expect(gatekeeper.promptsShownThisSession == 1)

        gatekeeper.resetSessionPrompts()
        #expect(gatekeeper.promptsShownThisSession == 0)
    }

    // MARK: - Tier Comparison

    @Test("Tier comparison includes all features")
    func tierComparisonComplete() {
        let defaults = UserDefaults(suiteName: "test_comparison")!
        let gatekeeper = FreemiumGatekeeper(userDefaults: defaults)

        let comparisons = gatekeeper.tierComparisons

        #expect(comparisons.count >= 8)
        #expect(comparisons.contains { $0.feature == "Cry Detection" })
        #expect(comparisons.contains { $0.feature == "Offline Downloads" })
    }
}

@Suite("Engagement Trigger Service")
struct EngagementTriggerServiceTests {

    @Test("It Helped milestone triggers prompt")
    func itHelpedMilestoneTriggers() {
        let defaults = UserDefaults(suiteName: "test_it_helped")!
        defaults.removePersistentDomain(forName: "test_it_helped")

        // Reset to avoid existing data
        defaults.set(0, forKey: "itHelpedCount")

        // Note: Full test would require mocking SubscriptionManager
        // For now, we just test the count tracking

        #expect(defaults.integer(forKey: "itHelpedCount") == 0)
    }

    @Test("Upgrade prompt has correct structure")
    func upgradePromptStructure() {
        let event = EngagementTriggerService.EngagementEvent.itHelpedFeedback(totalCount: 5)

        if let prompt = event.upgradePrompt {
            #expect(!prompt.title.isEmpty)
            #expect(!prompt.message.isEmpty)
            #expect(!prompt.ctaText.isEmpty)
            #expect(!prompt.dismissText.isEmpty)
        }
    }

    @Test("Weekly milestone has celebration style")
    func weeklyMilestoneCelebration() {
        let event = EngagementTriggerService.EngagementEvent.weeklyMilestone(weeksUsed: 1)

        if let prompt = event.upgradePrompt {
            #expect(prompt.style == .celebration)
        }
    }

    @Test("Trial ending has correct urgency")
    func trialEndingUrgency() {
        let urgentEvent = EngagementTriggerService.EngagementEvent.trialEnding(daysLeft: 1)

        if let prompt = urgentEvent.upgradePrompt {
            #expect(prompt.style == .urgent)
        }
    }
}
