//
//  TrialManager.swift
//  BabyInCarApp
//
//  Manages 7-day premium trial for new users
//  Philosophy: Let users experience the magic before asking for money
//

import Foundation
import Combine

/// Manages the 7-day free trial experience
@MainActor
final class TrialManager: ObservableObject {
    static let shared = TrialManager()

    // MARK: - Configuration
    private enum Config {
        static let trialDurationDays = 7
        static let trialStartKey = "trial_start_date"
        static let hasSeenTrialEndKey = "has_seen_trial_end"
        static let trialDismissedUntilKey = "trial_dismissed_until"
        static let softPromptDay = 5 // Day to show first soft upgrade prompt
    }

    // MARK: - Published Properties
    @Published private(set) var trialState: TrialState = .unknown
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var trialStartDate: Date?
    @Published private(set) var trialEndDate: Date?

    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadTrialState()
        startDailyCheck()
    }

    // For testing - using internal convenience
    static func createForTesting(userDefaults: UserDefaults) -> TrialManager {
        let manager = TrialManager(userDefaults: userDefaults)
        return manager
    }

    // MARK: - Trial State

    enum TrialState: Equatable {
        case unknown
        case notStarted
        case active(daysRemaining: Int)
        case expiredRecently // Within 3 days of expiration
        case expired
        case converted // User purchased premium

        var isActive: Bool {
            if case .active = self { return true }
            return false
        }

        var shouldShowTrialBadge: Bool {
            switch self {
            case .active: return true
            case .expiredRecently: return true
            default: return false
            }
        }

        var displayMessage: String {
            switch self {
            case .unknown:
                return ""
            case .notStarted:
                return "Start your 7-day free trial"
            case .active(let days):
                if days == 1 {
                    return "Last day of your trial"
                } else if days <= 3 {
                    return "\(days) days left in your trial"
                } else {
                    return "Premium trial: \(days) days left"
                }
            case .expiredRecently:
                return "Your trial ended - keep your features?"
            case .expired:
                return "Upgrade to Premium"
            case .converted:
                return "Premium Member"
            }
        }
    }

    // MARK: - Public API

    /// Call on first app launch to start the trial
    func startTrialIfNeeded() {
        guard trialStartDate == nil else { return }

        let now = Date()
        userDefaults.set(now, forKey: Config.trialStartKey)
        trialStartDate = now
        trialEndDate = Calendar.current.date(byAdding: .day, value: Config.trialDurationDays, to: now)
        updateTrialState()

        // Analytics
        NotificationCenter.default.post(
            name: .trialStarted,
            object: nil,
            userInfo: ["startDate": now, "endDate": trialEndDate ?? now]
        )
    }

    /// Check if user has full premium access (trial or paid)
    var hasPremiumAccess: Bool {
        // Check if paid subscriber first
        if SubscriptionManager.shared.isPremium {
            return true
        }
        // Otherwise check trial
        return trialState.isActive
    }

    /// Check if we should show the soft upgrade prompt
    var shouldShowSoftUpgradePrompt: Bool {
        guard case .active(let days) = trialState else { return false }
        // Show on day 5 or later, but not on day 1 (too aggressive)
        return days <= (Config.trialDurationDays - Config.softPromptDay + 1) && days > 1
    }

    /// Check if we should show urgent upgrade prompt (last day)
    var shouldShowUrgentPrompt: Bool {
        guard case .active(let days) = trialState else { return false }
        return days == 1
    }

    /// Mark that user has seen the trial end message
    func markTrialEndSeen() {
        userDefaults.set(true, forKey: Config.hasSeenTrialEndKey)
    }

    /// Temporarily dismiss trial prompts (for X hours)
    func dismissTrialPrompt(forHours hours: Int = 24) {
        let dismissUntil = Date().addingTimeInterval(TimeInterval(hours * 3600))
        userDefaults.set(dismissUntil, forKey: Config.trialDismissedUntilKey)
    }

    /// Check if prompts are temporarily dismissed
    var arePromptsTemporarilyDismissed: Bool {
        guard let dismissedUntil = userDefaults.object(forKey: Config.trialDismissedUntilKey) as? Date else {
            return false
        }
        return Date() < dismissedUntil
    }

    /// Mark user as converted (called after successful purchase)
    func markAsConverted() {
        trialState = .converted
        NotificationCenter.default.post(name: .trialConverted, object: nil)
    }

    /// Get a friendly description of what the user will lose when trial ends
    var premiumFeaturesAtRisk: [String] {
        [
            "Unlimited content library",
            "Offline downloads",
            "Full AI insights",
            "Advanced mood predictions",
            "Priority support"
        ]
    }

    // MARK: - Private Methods

    private func loadTrialState() {
        // Check for premium first
        if SubscriptionManager.shared.isPremium {
            trialState = .converted
            return
        }

        // Load trial start date
        if let startDate = userDefaults.object(forKey: Config.trialStartKey) as? Date {
            trialStartDate = startDate
            trialEndDate = Calendar.current.date(byAdding: .day, value: Config.trialDurationDays, to: startDate)
            updateTrialState()
        } else {
            trialState = .notStarted
        }
    }

    private func updateTrialState() {
        guard let endDate = trialEndDate else {
            trialState = .notStarted
            return
        }

        let now = Date()
        let calendar = Calendar.current

        if now >= endDate {
            // Trial has ended
            let daysSinceEnd = calendar.dateComponents([.day], from: endDate, to: now).day ?? 0
            if daysSinceEnd <= 3 {
                trialState = .expiredRecently
            } else {
                trialState = .expired
            }
            trialDaysRemaining = 0
        } else {
            // Trial is active
            let daysRemaining = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
            // Add 1 because we count today as a trial day
            let adjustedDays = max(1, daysRemaining + 1)
            trialDaysRemaining = adjustedDays
            trialState = .active(daysRemaining: adjustedDays)
        }
    }

    private func startDailyCheck() {
        // Check trial status periodically (every hour)
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTrialState()
            }
            .store(in: &cancellables)
    }

    /// Reset trial (for testing only)
    #if DEBUG
    func resetTrial() {
        userDefaults.removeObject(forKey: Config.trialStartKey)
        userDefaults.removeObject(forKey: Config.hasSeenTrialEndKey)
        userDefaults.removeObject(forKey: Config.trialDismissedUntilKey)
        trialStartDate = nil
        trialEndDate = nil
        trialState = .notStarted
    }
    #endif
}

// MARK: - Notification Names
extension Notification.Name {
    static let trialStarted = Notification.Name("trialStarted")
    static let trialEnding = Notification.Name("trialEnding")
    static let trialEnded = Notification.Name("trialEnded")
    static let trialConverted = Notification.Name("trialConverted")
}

// MARK: - Trial Banner View Model
extension TrialManager {
    /// View model for trial countdown banner
    struct TrialBannerViewModel {
        let isVisible: Bool
        let message: String
        let urgency: Urgency
        let actionTitle: String

        enum Urgency {
            case low       // 4+ days remaining
            case medium    // 2-3 days remaining
            case high      // 1 day remaining
            case expired   // Trial ended

            var backgroundColor: String {
                switch self {
                case .low: return "appPrimary"
                case .medium: return "appWarning"
                case .high: return "appError"
                case .expired: return "appTextSecondary"
                }
            }
        }
    }

    var bannerViewModel: TrialBannerViewModel {
        // Don't show if premium or dismissed
        guard !SubscriptionManager.shared.isPremium else {
            return TrialBannerViewModel(isVisible: false, message: "", urgency: .low, actionTitle: "")
        }

        guard !arePromptsTemporarilyDismissed else {
            return TrialBannerViewModel(isVisible: false, message: "", urgency: .low, actionTitle: "")
        }

        switch trialState {
        case .active(let days):
            let urgency: TrialBannerViewModel.Urgency
            if days >= 4 {
                urgency = .low
            } else if days >= 2 {
                urgency = .medium
            } else {
                urgency = .high
            }
            return TrialBannerViewModel(
                isVisible: true,
                message: trialState.displayMessage,
                urgency: urgency,
                actionTitle: days == 1 ? "Keep Features" : "Learn More"
            )
        case .expiredRecently:
            return TrialBannerViewModel(
                isVisible: true,
                message: trialState.displayMessage,
                urgency: .expired,
                actionTitle: "Upgrade Now"
            )
        default:
            return TrialBannerViewModel(isVisible: false, message: "", urgency: .low, actionTitle: "")
        }
    }
}
