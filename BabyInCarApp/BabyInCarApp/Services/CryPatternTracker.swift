//
//  CryPatternTracker.swift
//  BabyInCarApp
//
//  Tracks cry patterns over time for temporal analysis
//  Monitors burst patterns, intensity trends, and cry type stability
//

import Foundation

// MARK: - Cry Pattern Metrics

/// Comprehensive metrics about crying patterns over time
struct CryPatternMetrics: Codable {
    /// Total duration of crying in current session
    let totalCryDuration: TimeInterval

    /// Duration of current cry burst (0 if not currently crying)
    let currentBurstDuration: TimeInterval

    /// Average duration of cry bursts
    let averageBurstDuration: TimeInterval

    /// Average pause duration between cry bursts
    let averagePauseDuration: TimeInterval

    /// Total number of cry bursts in session
    let cryBurstCount: Int

    /// Trend of cry intensity over time
    let intensityTrend: IntensityTrend

    /// How rhythmic/periodic the crying pattern is (0-1)
    let rhythmicity: Double

    /// Most common cry type detected
    let dominantType: CryType

    /// How stable/consistent the cry type classification is (0-1)
    let typeStability: Double

    /// Peak intensity reached in current session
    let peakIntensity: Double

    /// Time since last cry started (nil if never cried)
    let timeSinceLastCry: TimeInterval?

    /// Whether currently in an active cry burst
    let isCurrentlyCrying: Bool

    // MARK: - Intensity Trend

    enum IntensityTrend: String, Codable {
        case increasing = "Increasing"
        case decreasing = "Decreasing"
        case stable = "Stable"
        case fluctuating = "Fluctuating"

        var emoji: String {
            switch self {
            case .increasing: return "📈"
            case .decreasing: return "📉"
            case .stable: return "➡️"
            case .fluctuating: return "📊"
            }
        }
    }

    // MARK: - Pattern Assessment

    /// Overall assessment of the crying pattern
    var patternAssessment: PatternAssessment {
        // High urgency indicators
        if intensityTrend == .increasing && currentBurstDuration > 30 {
            return .escalating
        }
        if peakIntensity > 0.8 && dominantType == .pain {
            return .severe
        }

        // Moderate indicators
        if cryBurstCount > 5 && averageBurstDuration > 15 {
            return .persistent
        }
        if rhythmicity > 0.6 && dominantType == .hunger {
            return .rhythmicHunger
        }

        // Mild indicators
        if intensityTrend == .decreasing {
            return .calming
        }
        if averageBurstDuration < 10 && averagePauseDuration > 5 {
            return .intermittent
        }

        return .normal
    }

    enum PatternAssessment: String, Codable {
        case normal = "Normal crying pattern"
        case intermittent = "Intermittent fussing"
        case persistent = "Persistent crying"
        case escalating = "Escalating distress"
        case severe = "Severe distress"
        case rhythmicHunger = "Rhythmic hunger pattern"
        case calming = "Calming down"
    }

    // MARK: - Static

    static var zero: CryPatternMetrics {
        CryPatternMetrics(
            totalCryDuration: 0,
            currentBurstDuration: 0,
            averageBurstDuration: 0,
            averagePauseDuration: 0,
            cryBurstCount: 0,
            intensityTrend: .stable,
            rhythmicity: 0.5,
            dominantType: .unknown,
            typeStability: 0,
            peakIntensity: 0,
            timeSinceLastCry: nil,
            isCurrentlyCrying: false
        )
    }
}

// MARK: - Cry Pattern Tracker

/// Tracks crying patterns over time for comprehensive temporal analysis
/// Thread-safe: Uses serial queue for all state mutations
class CryPatternTracker {

    // MARK: - Thread Safety

    /// Serial queue for thread-safe access to mutable state
    private let stateQueue = DispatchQueue(label: "com.babyincar.CryPatternTracker", qos: .userInitiated)

    // MARK: - Configuration

    /// Minimum gap between bursts to consider them separate (seconds)
    private let minBurstGap: TimeInterval = 0.5

    /// Maximum history of bursts to keep (MEMORY SAFETY: AGGRESSIVELY reduced)
    /// 10 bursts is enough to detect patterns without memory bloat
    private let maxBurstHistory = 10  // REDUCED from 20

    /// Maximum intensity history samples (MEMORY SAFETY: AGGRESSIVELY reduced)
    /// 30 samples = ~1 second of trend data at 30fps, still sufficient
    private let maxIntensityHistory = 30  // REDUCED from 60

    /// Maximum type history samples (MEMORY SAFETY: AGGRESSIVELY reduced)
    private let maxTypeHistory = 15  // REDUCED from 30

    /// Maximum intensity samples PER BURST (MEMORY SAFETY - CRITICAL!)
    /// 50 samples = ~1.7 seconds, enough for cry pattern detection
    /// CRITICAL: Prevents unbounded memory growth during long continuous crying
    private let maxIntensitySamplesPerBurst = 50  // REDUCED from 100

    // MARK: - Internal State (accessed only via stateQueue)

    /// Recorded cry bursts
    private var bursts: [CryBurst] = []

    /// Current active burst (if crying)
    private var currentBurst: CryBurst?

    /// Recent intensity measurements
    private var intensityHistory: [(timestamp: Date, intensity: Double)] = []

    /// Recent cry type classifications
    private var typeHistory: [CryType] = []

    /// Session start time
    private var sessionStartTime: Date?

    /// Last update timestamp
    private var lastUpdateTime: Date?

    // MARK: - Cry Burst Structure

    private struct CryBurst {
        let startTime: Date
        var endTime: Date?
        var peakIntensity: Double
        var dominantType: CryType
        var intensitySamples: [Double]

        var duration: TimeInterval {
            (endTime ?? Date()).timeIntervalSince(startTime)
        }

        var averageIntensity: Double {
            guard !intensitySamples.isEmpty else { return 0 }
            return intensitySamples.reduce(0, +) / Double(intensitySamples.count)
        }
    }

    // MARK: - Initialization

    init() {
        reset()
    }

    // MARK: - Public Methods

    /// Reset tracker state for new session
    /// MEMORY SAFETY: Keep array capacities to avoid repeated allocations
    func reset() {
        stateQueue.sync {
            bursts.removeAll(keepingCapacity: true)
            currentBurst = nil
            intensityHistory.removeAll(keepingCapacity: true)
            typeHistory.removeAll(keepingCapacity: true)
            sessionStartTime = Date()
            lastUpdateTime = nil
        }
    }

    /// Update tracker with new analysis frame
    /// - Parameters:
    ///   - isCrying: Whether cry was detected in this frame
    ///   - intensity: Cry intensity (0-1)
    ///   - type: Classified cry type
    ///   - timestamp: Time of this analysis
    /// - Returns: Updated pattern metrics
    func update(isCrying: Bool, intensity: Double, type: CryType, timestamp: Date) -> CryPatternMetrics {
        return stateQueue.sync {
            // Initialize session if needed
            if sessionStartTime == nil {
                sessionStartTime = timestamp
            }

            lastUpdateTime = timestamp

            // Track intensity history
            intensityHistory.append((timestamp, intensity))
            if intensityHistory.count > maxIntensityHistory {
                intensityHistory.removeFirst()
            }

            // Handle crying state
            if isCrying {
                handleCryingFrameUnsafe(intensity: intensity, type: type, timestamp: timestamp)
            } else {
                handleQuietFrameUnsafe(timestamp: timestamp)
            }

            return calculateMetricsUnsafe(currentTime: timestamp)
        }
    }

    /// Get current metrics without updating state
    func getCurrentMetrics() -> CryPatternMetrics {
        return stateQueue.sync {
            return calculateMetricsUnsafe(currentTime: lastUpdateTime ?? Date())
        }
    }

    // MARK: - Private Methods - Frame Handling (Unsafe - must be called within stateQueue)

    private func handleCryingFrameUnsafe(intensity: Double, type: CryType, timestamp: Date) {
        // Track type history
        if type != .unknown {
            typeHistory.append(type)
            if typeHistory.count > maxTypeHistory {
                typeHistory.removeFirst()
            }   
        }

        if var burst = currentBurst {
            // Update existing burst - use local copy to avoid exclusive access issues
            burst.peakIntensity = max(burst.peakIntensity, intensity)
            burst.intensitySamples.append(intensity)

            // MEMORY SAFETY: Enforce maximum samples per burst
            if burst.intensitySamples.count > maxIntensitySamplesPerBurst {
                burst.intensitySamples.removeFirst(burst.intensitySamples.count - maxIntensitySamplesPerBurst)
            }

            // Update dominant type if we have a valid classification
            if type != .unknown {
                burst.dominantType = type
            }

            // Write back the modified burst
            currentBurst = burst
        } else {
            // Start new burst
            currentBurst = CryBurst(
                startTime: timestamp,
                endTime: nil,
                peakIntensity: intensity,
                dominantType: type,
                intensitySamples: [intensity]
            )
        }
    }

    private func handleQuietFrameUnsafe(timestamp: Date) {
        guard var burst = currentBurst else { return }

        // Check if this is the end of a burst
        let silenceDuration = timestamp.timeIntervalSince(burst.startTime.addingTimeInterval(burst.duration))

        if silenceDuration > minBurstGap {
            // End the burst
            burst.endTime = timestamp.addingTimeInterval(-silenceDuration)
            bursts.append(burst)
            currentBurst = nil

            // Trim history
            if bursts.count > maxBurstHistory {
                bursts.removeFirst()
            }
        }
    }

    // MARK: - Private Methods - Metrics Calculation (Unsafe - must be called within stateQueue)

    private func calculateMetricsUnsafe(currentTime: Date) -> CryPatternMetrics {
        // Total cry duration
        let completedDuration = bursts.reduce(0.0) { $0 + $1.duration }
        let currentDuration = currentBurst?.duration ?? 0
        let totalDuration = completedDuration + currentDuration

        // Average burst duration
        let avgBurst: TimeInterval
        if !bursts.isEmpty {
            avgBurst = bursts.reduce(0.0) { $0 + $1.duration } / Double(bursts.count)
        } else if currentBurst != nil {
            avgBurst = currentDuration
        } else {
            avgBurst = 0
        }

        // Average pause duration
        let avgPause = calculateAveragePauseDuration()

        // Intensity trend
        let trend = calculateIntensityTrend()

        // Rhythmicity
        let rhythmicity = calculateRhythmicity()

        // Dominant type and stability
        let (dominantType, typeStability) = calculateDominantType()

        // Peak intensity
        let allPeaks = bursts.map { $0.peakIntensity }
        let currentPeak = currentBurst?.peakIntensity ?? 0
        let peakIntensity = max(allPeaks.max() ?? 0, currentPeak)

        // Time since last cry
        let timeSinceLastCry: TimeInterval?
        if currentBurst != nil {
            timeSinceLastCry = 0
        } else if let lastBurst = bursts.last, let endTime = lastBurst.endTime {
            timeSinceLastCry = currentTime.timeIntervalSince(endTime)
        } else {
            timeSinceLastCry = nil
        }

        return CryPatternMetrics(
            totalCryDuration: totalDuration,
            currentBurstDuration: currentDuration,
            averageBurstDuration: avgBurst,
            averagePauseDuration: avgPause,
            cryBurstCount: bursts.count + (currentBurst != nil ? 1 : 0),
            intensityTrend: trend,
            rhythmicity: rhythmicity,
            dominantType: dominantType,
            typeStability: typeStability,
            peakIntensity: peakIntensity,
            timeSinceLastCry: timeSinceLastCry,
            isCurrentlyCrying: currentBurst != nil
        )
    }

    private func calculateAveragePauseDuration() -> TimeInterval {
        guard bursts.count > 1 else { return 0 }

        var totalPause: TimeInterval = 0
        var pauseCount = 0

        for i in 1..<bursts.count {
            guard let prevEnd = bursts[i - 1].endTime else { continue }
            let pauseDuration = bursts[i].startTime.timeIntervalSince(prevEnd)
            if pauseDuration > 0 {
                totalPause += pauseDuration
                pauseCount += 1
            }
        }

        return pauseCount > 0 ? totalPause / Double(pauseCount) : 0
    }

    private func calculateIntensityTrend() -> CryPatternMetrics.IntensityTrend {
        guard intensityHistory.count >= 5 else { return .stable }

        let recentSamples = Array(intensityHistory.suffix(20))
        let firstHalf = recentSamples.prefix(recentSamples.count / 2).map { $0.intensity }
        let secondHalf = recentSamples.suffix(recentSamples.count / 2).map { $0.intensity }

        guard !firstHalf.isEmpty && !secondHalf.isEmpty else { return .stable }

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        // Calculate variance to detect fluctuation
        let allValues = recentSamples.map { $0.intensity }
        let overallMean = allValues.reduce(0, +) / Double(allValues.count)
        let variance = allValues.map { ($0 - overallMean) * ($0 - overallMean) }
            .reduce(0, +) / Double(allValues.count)

        // High variance indicates fluctuation
        if variance > 0.1 {
            return .fluctuating
        }

        // Check trend
        let changeRatio = secondAvg / max(firstAvg, 0.001)

        if changeRatio > 1.2 {
            return .increasing
        } else if changeRatio < 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }

    private func calculateRhythmicity() -> Double {
        guard bursts.count >= 3 else { return 0.5 }

        // Calculate intervals between burst starts
        var intervals: [TimeInterval] = []
        for i in 1..<bursts.count {
            let interval = bursts[i].startTime.timeIntervalSince(bursts[i - 1].startTime)
            intervals.append(interval)
        }

        guard !intervals.isEmpty else { return 0.5 }

        // Calculate coefficient of variation (lower = more rhythmic)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)

        let cv = mean > 0 ? stdDev / mean : 1

        // Convert to 0-1 scale (0 = not rhythmic, 1 = very rhythmic)
        return max(0, min(1 - cv, 1))
    }

    private func calculateDominantType() -> (CryType, Double) {
        guard !typeHistory.isEmpty else { return (.unknown, 0) }

        // Count occurrences of each type
        var typeCounts: [CryType: Int] = [:]
        for type in typeHistory {
            typeCounts[type, default: 0] += 1
        }

        // Find dominant type
        let dominant = typeCounts.max(by: { $0.value < $1.value })
        let stability = Double(dominant?.value ?? 0) / Double(typeHistory.count)

        return (dominant?.key ?? .unknown, stability)
    }
}

// MARK: - Cry Session Summary

/// Summary of a completed cry analysis session
struct CrySessionSummary: Codable {
    let sessionId: UUID
    let startTime: Date
    let endTime: Date
    let totalDuration: TimeInterval
    let totalCryDuration: TimeInterval
    let cryBurstCount: Int
    let dominantCryType: CryType
    let averageIntensity: Double
    let peakIntensity: Double
    let patternAssessment: CryPatternMetrics.PatternAssessment

    /// Percentage of session spent crying
    var cryPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (totalCryDuration / totalDuration) * 100
    }
}

// MARK: - Pattern History Manager

/// Manages history of cry patterns for learning and analysis
class CryPatternHistoryManager {

    private let maxSessionHistory = 100
    private var sessionHistory: [CrySessionSummary] = []
    private let userDefaults = UserDefaults.standard
    private let historyKey = "CryPatternHistory"

    init() {
        loadHistory()
    }

    /// Add a completed session summary to history
    func addSession(_ summary: CrySessionSummary) {
        sessionHistory.append(summary)

        // Trim to max size
        if sessionHistory.count > maxSessionHistory {
            sessionHistory.removeFirst()
        }

        saveHistory()
    }

    /// Get recent sessions for a baby
    func getRecentSessions(limit: Int = 10) -> [CrySessionSummary] {
        return Array(sessionHistory.suffix(limit))
    }

    /// Analyze patterns across sessions
    func analyzePatterns() -> CrossSessionAnalysis {
        guard !sessionHistory.isEmpty else {
            return CrossSessionAnalysis.empty
        }

        let recentSessions = sessionHistory.suffix(20)

        // Most common cry type
        var typeCounts: [CryType: Int] = [:]
        for session in recentSessions {
            typeCounts[session.dominantCryType, default: 0] += 1
        }
        let mostCommonType = typeCounts.max(by: { $0.value < $1.value })?.key ?? .unknown

        // Average session metrics
        let avgCryDuration = recentSessions.map { $0.totalCryDuration }.reduce(0, +) / Double(recentSessions.count)
        let avgIntensity = recentSessions.map { $0.averageIntensity }.reduce(0, +) / Double(recentSessions.count)
        let avgBurstCount = Double(recentSessions.map { $0.cryBurstCount }.reduce(0, +)) / Double(recentSessions.count)

        // Trend in cry duration
        let firstHalf = Array(recentSessions.prefix(recentSessions.count / 2))
        let secondHalf = Array(recentSessions.suffix(recentSessions.count / 2))

        let firstHalfAvg = firstHalf.isEmpty ? 0 : firstHalf.map { $0.totalCryDuration }.reduce(0, +) / Double(firstHalf.count)
        let secondHalfAvg = secondHalf.isEmpty ? 0 : secondHalf.map { $0.totalCryDuration }.reduce(0, +) / Double(secondHalf.count)

        let durationTrend: CryPatternMetrics.IntensityTrend
        if secondHalfAvg > firstHalfAvg * 1.2 {
            durationTrend = .increasing
        } else if secondHalfAvg < firstHalfAvg * 0.8 {
            durationTrend = .decreasing
        } else {
            durationTrend = .stable
        }

        return CrossSessionAnalysis(
            sessionCount: sessionHistory.count,
            mostCommonCryType: mostCommonType,
            averageCryDurationPerSession: avgCryDuration,
            averageIntensity: avgIntensity,
            averageBurstCount: avgBurstCount,
            durationTrend: durationTrend
        )
    }

    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CrySessionSummary].self, from: data) else {
            return
        }
        sessionHistory = history
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(sessionHistory) else { return }
        userDefaults.set(data, forKey: historyKey)
    }
}

// MARK: - Cross-Session Analysis

/// Analysis across multiple cry sessions
struct CrossSessionAnalysis: Codable {
    let sessionCount: Int
    let mostCommonCryType: CryType
    let averageCryDurationPerSession: TimeInterval
    let averageIntensity: Double
    let averageBurstCount: Double
    let durationTrend: CryPatternMetrics.IntensityTrend

    static var empty: CrossSessionAnalysis {
        CrossSessionAnalysis(
            sessionCount: 0,
            mostCommonCryType: .unknown,
            averageCryDurationPerSession: 0,
            averageIntensity: 0,
            averageBurstCount: 0,
            durationTrend: .stable
        )
    }
}
