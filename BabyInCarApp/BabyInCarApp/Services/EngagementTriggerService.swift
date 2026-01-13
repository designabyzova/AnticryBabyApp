//
//  EngagementTriggerService.swift
//  BabyInCarApp
//
//  Triggers upgrade prompts at moments of delight, not frustration
//  Philosophy: Convert through positive experiences, not blocking
//

import Foundation
import Combine
import UIKit

/// Manages engagement-based upgrade triggers
@MainActor
final class EngagementTriggerService: ObservableObject {
    static let shared = EngagementTriggerService()

    // MARK: - Configuration
    private enum Config {
        // Milestone thresholds
        static let firstItHelpedMilestone = 3
        static let cryDetectionMilestone = 5
        static let weeklyUsageMilestone = 7 // days

        // Cooldowns
        static let milestonePromptCooldownHours = 48
        static let engagementPromptCooldownHours = 12

        // Session limits
        static let maxEngagementPromptsPerSession = 1
    }

    // MARK: - Engagement Events
    enum EngagementEvent {
        case itHelpedFeedback(totalCount: Int)
        case cryDetectionUsed(totalCount: Int)
        case cryDetectionSuccess(trackTitle: String, timeToCalmSeconds: Int) // Post-cry success
        case playlistCreatedWithPremium(playlistName: String)
        case weeklyMilestone(weeksUsed: Int)
        case trialEnding(daysLeft: Int)
        case favoritedPremiumTrack(trackTitle: String)
        case effectiveTrackDiscovered(trackTitle: String, effectiveness: Double)
        case babyProfileComplete

        var milestoneMessage: String? {
            switch self {
            case .itHelpedFeedback(let count):
                if count == Config.firstItHelpedMilestone {
                    return "You've found \(count) tracks that work!"
                }
                return nil

            case .cryDetectionUsed(let count):
                if count == Config.cryDetectionMilestone {
                    return "Cry detection has helped you \(count) times!"
                }
                return nil

            case .weeklyMilestone(let weeks):
                if weeks == 1 {
                    return "One week with AntiCry Baby!"
                } else if weeks == 4 {
                    return "One month together!"
                }
                return nil

            case .trialEnding(let days):
                if days == 1 {
                    return "Last day of your premium trial"
                } else if days == 3 {
                    return "3 days left in your trial"
                }
                return nil

            case .effectiveTrackDiscovered(let title, let effectiveness):
                if effectiveness > 0.8 {
                    return "\"\(title)\" works great for your baby!"
                }
                return nil

            case .cryDetectionSuccess(let trackTitle, let timeToCalmSeconds):
                // Show milestone for quick calming (under 2 minutes)
                if timeToCalmSeconds < 120 {
                    return "\"\(trackTitle)\" calmed your baby in \(timeToCalmSeconds / 60) min!"
                }
                return nil

            default:
                return nil
            }
        }

        var upgradePrompt: UpgradePrompt? {
            switch self {
            case .itHelpedFeedback(let count):
                if count >= Config.firstItHelpedMilestone {
                    return UpgradePrompt(
                        title: "Your baby loves this!",
                        message: "Get more tracks like the ones that work",
                        ctaText: "Unlock More",
                        style: .positive
                    )
                }

            case .cryDetectionUsed(let count):
                if count >= Config.cryDetectionMilestone {
                    return UpgradePrompt(
                        title: "Cry detection is helping!",
                        message: "Keep unlimited access + AI insights",
                        ctaText: "Stay Premium",
                        style: .positive
                    )
                }

            case .weeklyMilestone(let weeks):
                if weeks == 1 {
                    return UpgradePrompt(
                        title: "1 week with \(weeks > 1 ? "us" : "AntiCry")!",
                        message: "Special offer: 50% off your first month",
                        ctaText: "Claim Offer",
                        style: .celebration
                    )
                }

            case .trialEnding(let days):
                if days <= 3 {
                    return UpgradePrompt(
                        title: days == 1 ? "Trial ends today" : "\(days) days left",
                        message: "Don't lose your personalized experience",
                        ctaText: "Keep Features",
                        style: days == 1 ? .urgent : .gentle
                    )
                }

            case .effectiveTrackDiscovered(let title, _):
                return UpgradePrompt(
                    title: "Great discovery!",
                    message: "\"\(title)\" is perfect for your baby. Get more like it.",
                    ctaText: "Discover More",
                    style: .positive
                )

            case .favoritedPremiumTrack(let title):
                return UpgradePrompt(
                    title: "Love \"\(title)\"?",
                    message: "Upgrade to keep it in your library",
                    ctaText: "Unlock Track",
                    style: .gentle
                )

            case .cryDetectionSuccess(_, let timeToCalmSeconds):
                // Show upgrade prompt after successful soothing
                let message = timeToCalmSeconds < 120
                    ? "Your baby calmed quickly! Keep unlimited access."
                    : "Your baby loves AntiCry! Keep unlimited access."
                return UpgradePrompt(
                    title: "It worked!",
                    message: message,
                    ctaText: "Stay Premium",
                    style: .positive
                )

            default:
                return nil
            }
            return nil
        }
    }

    // MARK: - Upgrade Prompt Model
    struct UpgradePrompt: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let ctaText: String
        let style: Style
        let dismissText: String

        enum Style {
            case positive    // Green, celebratory
            case gentle      // Soft, informative
            case urgent      // Orange, time-sensitive
            case celebration // Confetti, special offer

            var accentColor: String {
                switch self {
                case .positive: return "appSuccess"
                case .gentle: return "appPrimary"
                case .urgent: return "appWarning"
                case .celebration: return "appPrimary"
                }
            }
        }

        init(
            title: String,
            message: String,
            ctaText: String,
            style: Style,
            dismissText: String = "Not Now"
        ) {
            self.title = title
            self.message = message
            self.ctaText = ctaText
            self.style = style
            self.dismissText = dismissText
        }
    }

    // MARK: - Published Properties
    @Published private(set) var currentPrompt: UpgradePrompt?
    @Published private(set) var milestoneMessage: String?
    @Published private(set) var showCelebration = false

    // Tracking
    @Published private(set) var itHelpedCount = 0
    @Published private(set) var cryDetectionCount = 0
    @Published private(set) var weeksUsed = 0

    private let userDefaults: UserDefaults
    private var lastPromptTimes: [String: Date] = [:]
    private var promptsShownThisSession = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCounts()
        setupListeners()
    }

    // MARK: - Public API

    /// Record an engagement event and potentially trigger a prompt
    func recordEvent(_ event: EngagementEvent) {
        // Don't trigger for premium users
        guard !SubscriptionManager.shared.isPremium else { return }

        // Update counts
        updateCounts(for: event)

        // Check for milestone message
        if let message = event.milestoneMessage {
            showMilestone(message)
        }

        // Check for upgrade prompt (with rate limiting)
        if shouldShowPrompt(for: event), let prompt = event.upgradePrompt {
            showPrompt(prompt, for: event)
        }
    }

    /// Record "It Helped!" feedback
    func recordItHelpedFeedback() {
        itHelpedCount += 1
        saveCount("itHelpedCount", value: itHelpedCount)
        recordEvent(.itHelpedFeedback(totalCount: itHelpedCount))
    }

    /// Record cry detection usage
    func recordCryDetectionUsed() {
        cryDetectionCount += 1
        saveCount("cryDetectionCount", value: cryDetectionCount)
        recordEvent(.cryDetectionUsed(totalCount: cryDetectionCount))
    }

    /// Record effective track discovery
    func recordEffectiveTrack(title: String, effectiveness: Double) {
        if effectiveness >= 0.8 {
            recordEvent(.effectiveTrackDiscovered(trackTitle: title, effectiveness: effectiveness))
        }
    }

    /// Record successful soothing (called after baby calms down)
    /// - Parameters:
    ///   - trackTitle: The track that successfully calmed the baby
    ///   - timeToCalmSeconds: Time in seconds to calm
    func recordCryDetectionSuccess(trackTitle: String, timeToCalmSeconds: Int) {
        recordEvent(.cryDetectionSuccess(trackTitle: trackTitle, timeToCalmSeconds: timeToCalmSeconds))
    }

    /// Check for weekly milestone
    func checkWeeklyMilestone() {
        guard let firstLaunchDate = userDefaults.object(forKey: "firstLaunchDate") as? Date else {
            userDefaults.set(Date(), forKey: "firstLaunchDate")
            return
        }

        let weeks = Calendar.current.dateComponents([.weekOfYear], from: firstLaunchDate, to: Date()).weekOfYear ?? 0
        if weeks > weeksUsed {
            weeksUsed = weeks
            saveCount("weeksUsed", value: weeksUsed)
            recordEvent(.weeklyMilestone(weeksUsed: weeksUsed))
        }
    }

    /// Dismiss current prompt
    func dismissCurrentPrompt() {
        currentPrompt = nil
    }

    /// Reset session counter (call on app foreground)
    func resetSession() {
        promptsShownThisSession = 0
    }

    // MARK: - Private Methods

    private func updateCounts(for event: EngagementEvent) {
        switch event {
        case .itHelpedFeedback(let count):
            itHelpedCount = count
        case .cryDetectionUsed(let count):
            cryDetectionCount = count
        case .weeklyMilestone(let weeks):
            weeksUsed = weeks
        default:
            break
        }
    }

    private func shouldShowPrompt(for event: EngagementEvent) -> Bool {
        // Session limit
        if promptsShownThisSession >= Config.maxEngagementPromptsPerSession {
            return false
        }

        // Check cooldown
        let eventKey = String(describing: event)
        if let lastTime = lastPromptTimes[eventKey] {
            let hoursSince = Date().timeIntervalSince(lastTime) / 3600
            let cooldown = isMilestoneEvent(event)
                ? Config.milestonePromptCooldownHours
                : Config.engagementPromptCooldownHours

            if hoursSince < Double(cooldown) {
                return false
            }
        }

        return true
    }

    private func isMilestoneEvent(_ event: EngagementEvent) -> Bool {
        switch event {
        case .weeklyMilestone, .cryDetectionUsed(Config.cryDetectionMilestone),
             .itHelpedFeedback(Config.firstItHelpedMilestone):
            return true
        default:
            return false
        }
    }

    private func showPrompt(_ prompt: UpgradePrompt, for event: EngagementEvent) {
        promptsShownThisSession += 1
        let eventKey = String(describing: event)
        lastPromptTimes[eventKey] = Date()

        // Show celebration for milestone events
        if prompt.style == .celebration {
            showCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showCelebration = false
            }
        }

        currentPrompt = prompt

        // Analytics
        NotificationCenter.default.post(
            name: .engagementPromptShown,
            object: nil,
            userInfo: ["event": eventKey, "style": String(describing: prompt.style)]
        )
    }

    private func showMilestone(_ message: String) {
        milestoneMessage = message

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.milestoneMessage == message {
                self?.milestoneMessage = nil
            }
        }
    }

    private func setupListeners() {
        // Listen for app becoming active to check weekly milestone
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkWeeklyMilestone()
                self?.resetSession()
            }
            .store(in: &cancellables)

        // Listen for trial status changes
        NotificationCenter.default.publisher(for: .trialEnding)
            .compactMap { $0.userInfo?["daysLeft"] as? Int }
            .sink { [weak self] daysLeft in
                self?.recordEvent(.trialEnding(daysLeft: daysLeft))
            }
            .store(in: &cancellables)
    }

    private func loadCounts() {
        itHelpedCount = userDefaults.integer(forKey: "itHelpedCount")
        cryDetectionCount = userDefaults.integer(forKey: "cryDetectionCount")
        weeksUsed = userDefaults.integer(forKey: "weeksUsed")
    }

    private func saveCount(_ key: String, value: Int) {
        userDefaults.set(value, forKey: key)
    }

    #if DEBUG
    func resetForTesting() {
        itHelpedCount = 0
        cryDetectionCount = 0
        weeksUsed = 0
        promptsShownThisSession = 0
        lastPromptTimes = [:]
        currentPrompt = nil
        milestoneMessage = nil
        userDefaults.removeObject(forKey: "itHelpedCount")
        userDefaults.removeObject(forKey: "cryDetectionCount")
        userDefaults.removeObject(forKey: "weeksUsed")
        userDefaults.removeObject(forKey: "firstLaunchDate")
    }
    #endif
}

// MARK: - Notification Names
extension Notification.Name {
    static let engagementPromptShown = Notification.Name("engagementPromptShown")
    static let engagementPromptConverted = Notification.Name("engagementPromptConverted")
}
