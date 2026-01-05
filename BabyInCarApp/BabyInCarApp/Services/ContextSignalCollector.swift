//
//  ContextSignalCollector.swift
//  BabyInCarApp
//
//  Collects contextual signals about the baby's current situation.
//  Provides rich context for intelligent soothing decisions.
//

import Foundation
import CoreMotion
import CoreLocation
import Combine

// MARK: - Context Signals

/// Comprehensive context about the baby's current situation
struct ContextSignals: Codable {
    let timestamp: Date

    // MARK: - Time Context

    /// Current time of day category
    let timeOfDay: TimeOfDay

    /// Time since last recorded feeding
    var timeSinceLastFeed: TimeInterval?

    /// Time since last recorded sleep
    var timeSinceLastSleep: TimeInterval?

    /// Time since last recorded diaper change
    var timeSinceLastDiaperChange: TimeInterval?

    /// Time since last cry episode
    var timeSinceLastCry: TimeInterval?

    // MARK: - Environment

    /// Current ambient noise level (0-1)
    let ambientNoiseLevel: Float

    /// Whether the device detects car motion
    let inCarMoving: Bool

    /// Motion intensity (0-1, higher = more movement)
    let motionIntensity: Float

    /// Whether motion appears to be rocking/swaying
    let isRockingMotion: Bool

    /// Approximate temperature if available (Celsius)
    let temperature: Float?

    /// Light level if available (0-1)
    let lightLevel: Float?

    // MARK: - Recent History

    /// Number of crying episodes today
    let cryingEpisodesToday: Int

    /// Last calming method used
    let lastCalmingMethod: GeneratorType?

    /// Whether last calming attempt was successful
    let lastCalmingSuccess: Bool

    /// How long last calming took (seconds)
    let lastCalmingDuration: TimeInterval?

    /// Current predicted mood
    let currentMood: BabyMood

    /// Mood confidence (0-1)
    let moodConfidence: Double

    // MARK: - Parent Input

    /// Any parent notes for current session
    let parentNotes: String?

    /// Active special circumstances
    let activeCircumstances: [CircumstanceType]

    /// Recent observation categories
    let recentObservationCategories: [ObservationCategory]

    // MARK: - Computed Properties

    /// Overall context urgency score (0-1)
    var urgencyScore: Double {
        var score = 0.0

        // High crying count today increases urgency
        score += min(Double(cryingEpisodesToday) / 10.0, 0.3)

        // Recent unsuccessful calming increases urgency
        if !lastCalmingSuccess {
            score += 0.2
        }

        // Special circumstances can increase urgency
        let urgentCircumstances: [CircumstanceType] = [.illness, .vaccination, .teething]
        if activeCircumstances.contains(where: { urgentCircumstances.contains($0) }) {
            score += 0.2
        }

        // Time without sleep/feed increases urgency
        if let sinceSleep = timeSinceLastSleep, sinceSleep > 4 * 3600 {
            score += 0.15
        }
        if let sinceFeed = timeSinceLastFeed, sinceFeed > 3 * 3600 {
            score += 0.15
        }

        return min(1.0, score)
    }

    /// Suggested soothing approach based on context
    var suggestedApproach: SoothingApproach {
        // Night time + long since sleep = sleep-focused
        if (timeOfDay == .night || timeOfDay == .lateNight) && (timeSinceLastSleep ?? 0) > 2 * 3600 {
            return .sleepFocused
        }

        // Car moving = use motion-synced sounds
        if inCarMoving {
            return .motionSynced
        }

        // Rocking detected = rhythm-focused
        if isRockingMotion {
            return .rhythmFocused
        }

        // High crying count = try novelty
        if cryingEpisodesToday > 5 && lastCalmingSuccess == false {
            return .novelty
        }

        // Recent failed attempts = escalate intensity
        if !lastCalmingSuccess && (lastCalmingDuration ?? 0) > 120 {
            return .escalated
        }

        return .standard
    }
}

/// Suggested soothing approach based on context
enum SoothingApproach: String, Codable {
    case standard = "Standard"
    case sleepFocused = "Sleep Focused"
    case motionSynced = "Motion Synced"
    case rhythmFocused = "Rhythm Focused"
    case novelty = "Try Something New"
    case escalated = "Escalated Response"
    case gentle = "Gentle"
}

// MARK: - Context Signal Collector Service

/// Collects and aggregates contextual signals for intelligent soothing decisions.
/// Designed to be battery-efficient and privacy-respecting.
class ContextSignalCollector: ObservableObject {
    static let shared = ContextSignalCollector()

    // MARK: - Published State

    @Published var currentContext: ContextSignals?
    @Published var isCollecting: Bool = false

    // MARK: - Dependencies

    private let motionManager = CMMotionManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Activity Tracking

    private var lastFeedTime: Date?
    private var lastSleepTime: Date?
    private var lastDiaperChangeTime: Date?
    private var lastCryTime: Date?
    private var cryCountToday: Int = 0
    private var lastCryCountReset: Date?

    // MARK: - Calming History

    private var lastCalmingMethod: GeneratorType?
    private var lastCalmingSuccess: Bool = false
    private var lastCalmingDuration: TimeInterval?

    // MARK: - Motion Detection

    private var recentMotionData: [CMDeviceMotion] = []
    private let motionBufferSize = 50
    private var currentMotionIntensity: Float = 0
    private var isCurrentlyMoving: Bool = false
    private var isRocking: Bool = false

    // MARK: - Audio Level

    private var currentAmbientLevel: Float = 0

    // MARK: - Parent Input

    private var currentParentNotes: String?

    // MARK: - Persistence Keys

    private let lastFeedKey = "ContextCollector_LastFeed"
    private let lastSleepKey = "ContextCollector_LastSleep"
    private let lastDiaperKey = "ContextCollector_LastDiaper"
    private let cryCountKey = "ContextCollector_CryCount"
    private let cryCountResetKey = "ContextCollector_CryCountReset"

    private init() {
        loadPersistedData()
        resetCryCountIfNeeded()
    }

    // MARK: - Collection Control

    /// Start collecting context signals
    func startCollecting() {
        guard !isCollecting else { return }
        isCollecting = true

        startMotionUpdates()
        subscribeToAudioLevel()
    }

    /// Stop collecting context signals
    func stopCollecting() {
        isCollecting = false
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
    }

    // MARK: - Get Current Context

    /// Collect and return current context signals
    func getCurrentContext(for profile: BabyMoodProfile? = nil) -> ContextSignals {
        resetCryCountIfNeeded()

        let context = ContextSignals(
            timestamp: Date(),
            timeOfDay: TimeOfDay.current,
            timeSinceLastFeed: lastFeedTime.map { Date().timeIntervalSince($0) },
            timeSinceLastSleep: lastSleepTime.map { Date().timeIntervalSince($0) },
            timeSinceLastDiaperChange: lastDiaperChangeTime.map { Date().timeIntervalSince($0) },
            timeSinceLastCry: lastCryTime.map { Date().timeIntervalSince($0) },
            ambientNoiseLevel: currentAmbientLevel,
            inCarMoving: detectCarMotion(),
            motionIntensity: currentMotionIntensity,
            isRockingMotion: isRocking,
            temperature: nil, // Would require external sensor
            lightLevel: nil,  // Would require camera access
            cryingEpisodesToday: cryCountToday,
            lastCalmingMethod: lastCalmingMethod,
            lastCalmingSuccess: lastCalmingSuccess,
            lastCalmingDuration: lastCalmingDuration,
            currentMood: predictCurrentMood(profile: profile),
            moodConfidence: calculateMoodConfidence(profile: profile),
            parentNotes: currentParentNotes,
            activeCircumstances: getActiveCircumstances(profile: profile),
            recentObservationCategories: getRecentObservationCategories(profile: profile)
        )

        currentContext = context
        return context
    }

    // MARK: - Activity Recording

    /// Record a feeding event
    func recordFeeding() {
        lastFeedTime = Date()
        UserDefaults.standard.set(lastFeedTime, forKey: lastFeedKey)
    }

    /// Record a sleep event (baby fell asleep or woke up)
    func recordSleep() {
        lastSleepTime = Date()
        UserDefaults.standard.set(lastSleepTime, forKey: lastSleepKey)
    }

    /// Record a diaper change
    func recordDiaperChange() {
        lastDiaperChangeTime = Date()
        UserDefaults.standard.set(lastDiaperChangeTime, forKey: lastDiaperKey)
    }

    /// Record a crying episode
    func recordCryingEpisode() {
        lastCryTime = Date()
        cryCountToday += 1
        UserDefaults.standard.set(cryCountToday, forKey: cryCountKey)
    }

    /// Record calming outcome
    func recordCalmingOutcome(method: GeneratorType, success: Bool, duration: TimeInterval) {
        lastCalmingMethod = method
        lastCalmingSuccess = success
        lastCalmingDuration = duration
    }

    /// Set parent notes for current session
    func setParentNotes(_ notes: String?) {
        currentParentNotes = notes
    }

    /// Update ambient audio level
    func updateAmbientLevel(_ level: Float) {
        currentAmbientLevel = level
    }

    // MARK: - Motion Detection

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.1 // 10 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        // Add to buffer
        recentMotionData.append(motion)
        if recentMotionData.count > motionBufferSize {
            recentMotionData.removeFirst()
        }

        // Calculate motion intensity
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(
            pow(acceleration.x, 2) +
            pow(acceleration.y, 2) +
            pow(acceleration.z, 2)
        )

        // Smooth intensity
        currentMotionIntensity = Float(currentMotionIntensity * 0.9 + Float(magnitude) * 0.1)

        // Detect if moving
        isCurrentlyMoving = currentMotionIntensity > 0.05

        // Detect rocking pattern (oscillating motion)
        isRocking = detectRockingPattern()
    }

    private func detectRockingPattern() -> Bool {
        guard recentMotionData.count >= 20 else { return false }

        // Look for oscillation in vertical or horizontal axis
        let recent = recentMotionData.suffix(20)
        var crossings = 0
        var lastSign = 0

        for motion in recent {
            let currentSign = motion.userAcceleration.y > 0 ? 1 : -1
            if lastSign != 0 && currentSign != lastSign {
                crossings += 1
            }
            lastSign = currentSign
        }

        // Rocking typically has 2-4 cycles per 2 seconds (at 10Hz = 20 samples)
        return crossings >= 4 && crossings <= 16
    }

    private func detectCarMotion() -> Bool {
        guard recentMotionData.count >= motionBufferSize else { return false }

        // Car motion characteristics:
        // 1. Sustained low-frequency vibration
        // 2. Gradual acceleration/deceleration changes
        // 3. Minimal sudden movements

        let avgIntensity = recentMotionData.reduce(0.0) { result, motion in
            let mag = sqrt(
                pow(motion.userAcceleration.x, 2) +
                pow(motion.userAcceleration.y, 2) +
                pow(motion.userAcceleration.z, 2)
            )
            return result + mag
        } / Double(recentMotionData.count)

        // Calculate variance
        var variance = 0.0
        for motion in recentMotionData {
            let mag = sqrt(
                pow(motion.userAcceleration.x, 2) +
                pow(motion.userAcceleration.y, 2) +
                pow(motion.userAcceleration.z, 2)
            )
            variance += pow(mag - avgIntensity, 2)
        }
        variance /= Double(recentMotionData.count)

        // Car: low average intensity, low variance (smooth motion)
        let isCarLike = avgIntensity < 0.3 && variance < 0.05 && avgIntensity > 0.01

        return isCarLike && isCurrentlyMoving
    }

    // MARK: - Audio Level Subscription

    private func subscribeToAudioLevel() {
        // Subscribe to CryDetectionService audio level on MainActor
        Task { @MainActor in
            CryDetectionService.shared.$currentAudioLevel
                .receive(on: DispatchQueue.main)
                .sink { [weak self] level in
                    self?.currentAmbientLevel = level
                }
                .store(in: &self.cancellables)
        }
    }

    // MARK: - Mood Prediction

    private func predictCurrentMood(profile: BabyMoodProfile?) -> BabyMood {
        // Use profile prediction if available
        if let profile = profile {
            let predicted = profile.predictCurrentMood()
            if predicted != .unknown {
                return predicted
            }
        }

        // Fallback: estimate based on context
        let timeOfDay = TimeOfDay.current

        // Night time = likely sleepy
        if timeOfDay == .night || timeOfDay == .lateNight {
            return .sleepy
        }

        // Long since feed = possibly hungry
        if let sinceFeed = lastFeedTime.map({ Date().timeIntervalSince($0) }),
           sinceFeed > 3 * 3600 {
            return .hungry
        }

        // Recent crying = fussy
        if let sinceCry = lastCryTime.map({ Date().timeIntervalSince($0) }),
           sinceCry < 600 { // Within 10 minutes
            return .fussy
        }

        // Default
        return .content
    }

    private func calculateMoodConfidence(profile: BabyMoodProfile?) -> Double {
        guard let profile = profile else { return 0.3 }

        // Confidence based on profile data quality
        var confidence = profile.profileConfidence

        // Recent activity data improves confidence
        if lastFeedTime != nil || lastSleepTime != nil {
            confidence = min(1.0, confidence + 0.1)
        }

        return confidence
    }

    // MARK: - Profile Queries

    private func getActiveCircumstances(profile: BabyMoodProfile?) -> [CircumstanceType] {
        guard let profile = profile else { return [] }
        return profile.specialCircumstances
            .filter { $0.isActive }
            .map { $0.type }
    }

    private func getRecentObservationCategories(profile: BabyMoodProfile?) -> [ObservationCategory] {
        guard let profile = profile else { return [] }

        // Get unique categories from last 24 hours
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        let recent = profile.parentObservations
            .filter { $0.timestamp > dayAgo }
            .map { $0.category }

        return Array(Set(recent))
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        lastFeedTime = UserDefaults.standard.object(forKey: lastFeedKey) as? Date
        lastSleepTime = UserDefaults.standard.object(forKey: lastSleepKey) as? Date
        lastDiaperChangeTime = UserDefaults.standard.object(forKey: lastDiaperKey) as? Date
        cryCountToday = UserDefaults.standard.integer(forKey: cryCountKey)
        lastCryCountReset = UserDefaults.standard.object(forKey: cryCountResetKey) as? Date
    }

    private func resetCryCountIfNeeded() {
        let now = Date()
        let calendar = Calendar.current

        // Reset if it's a new day
        if let lastReset = lastCryCountReset {
            if !calendar.isDate(lastReset, inSameDayAs: now) {
                cryCountToday = 0
                lastCryCountReset = now
                UserDefaults.standard.set(cryCountToday, forKey: cryCountKey)
                UserDefaults.standard.set(lastCryCountReset, forKey: cryCountResetKey)
            }
        } else {
            lastCryCountReset = now
            UserDefaults.standard.set(lastCryCountReset, forKey: cryCountResetKey)
        }
    }

    // MARK: - Context History

    /// Get summary of context changes over time
    func getContextTrend(hours: Int = 24) -> ContextTrend {
        // This would track context over time for pattern detection
        // Simplified implementation returns current snapshot
        return ContextTrend(
            averageCryingPerDay: Double(cryCountToday),
            mostCommonCryTime: TimeOfDay.current,
            averageCalmingTime: lastCalmingDuration ?? 60,
            successRate: lastCalmingSuccess ? 1.0 : 0.0,
            trendDirection: .stable
        )
    }
}

// MARK: - Context Trend

/// Summary of context patterns over time
struct ContextTrend: Codable {
    let averageCryingPerDay: Double
    let mostCommonCryTime: TimeOfDay
    let averageCalmingTime: TimeInterval
    let successRate: Double
    let trendDirection: TrendDirection

    enum TrendDirection: String, Codable {
        case improving = "Improving"
        case stable = "Stable"
        case worsening = "Worsening"
    }
}

// MARK: - Quick Actions

extension ContextSignalCollector {
    /// Quick action buttons for common activities
    enum QuickAction: String, CaseIterable {
        case fed = "Fed"
        case slept = "Slept"
        case diaper = "Diaper"
        case note = "Note"

        var icon: String {
            switch self {
            case .fed: return "fork.knife"
            case .slept: return "moon.zzz"
            case .diaper: return "rectangle.stack"
            case .note: return "note.text"
            }
        }

        func execute(collector: ContextSignalCollector) {
            switch self {
            case .fed: collector.recordFeeding()
            case .slept: collector.recordSleep()
            case .diaper: collector.recordDiaperChange()
            case .note: break // Handled separately with note text
            }
        }
    }
}
