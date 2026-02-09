//
//  BatteryMonitor.swift
//  BabyInCarApp
//
//  FS-029: Battery usage monitoring for <5%/hour target
//  Tracks battery consumption during cry detection and playback
//

import Foundation
import UIKit
import Combine

// MARK: - Battery Usage Session

/// Represents a monitoring session with battery usage data
struct BatteryUsageSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let startBatteryLevel: Float
    var endBatteryLevel: Float?
    var features: Set<ActiveFeature>

    /// Duration of the session in seconds
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    /// Battery drain percentage (0.0 - 1.0)
    var batteryDrain: Float? {
        guard let end = endBatteryLevel else { return nil }
        return max(0, startBatteryLevel - end)
    }

    /// Battery drain per hour (percentage/hour)
    var drainPerHour: Double? {
        guard let drain = batteryDrain,
              let duration = duration,
              duration > 0 else { return nil }
        let hours = duration / 3600.0
        return Double(drain) / hours * 100 // Convert to percentage
    }

    /// Whether this session meets the <5%/hour target
    var meetsTarget: Bool {
        guard let rate = drainPerHour else { return true }
        return rate < 5.0
    }

    init(startBatteryLevel: Float, features: Set<ActiveFeature> = []) {
        self.id = UUID()
        self.startTime = Date()
        self.startBatteryLevel = startBatteryLevel
        self.features = features
    }
}

/// Features that can affect battery usage
enum ActiveFeature: String, Codable {
    case cryDetection = "cry_detection"
    case audioPlayback = "audio_playback"
    case backgroundMode = "background_mode"
    case cryTypeChange = "cry_type_change"
}

// MARK: - Battery Monitor

/// Service for monitoring battery usage during app operation
@MainActor
class BatteryMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = BatteryMonitor()

    // MARK: - Published State

    @Published private(set) var currentBatteryLevel: Float = 1.0
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var currentSession: BatteryUsageSession?
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var currentDrainRate: Double = 0.0

    /// Warning state when drain exceeds target
    @Published private(set) var isExceedingTarget: Bool = false

    // MARK: - Configuration

    /// Target maximum battery drain per hour (5%)
    static let targetDrainPerHour: Double = 5.0

    /// Update interval for battery checks (30 seconds)
    private let updateInterval: TimeInterval = 30.0

    /// Minimum session duration for valid measurements (5 minutes)
    private let minimumSessionDuration: TimeInterval = 300.0

    // MARK: - Private State

    private var updateTimer: Timer?
    private var sessionHistory: [BatteryUsageSession] = []
    private let maxHistorySize = 50
    private var cancellables = Set<AnyCancellable>()

    // For rate calculation
    private var batteryReadings: [(time: Date, level: Float)] = []
    private let maxReadings = 20

    // UserDefaults keys
    private let sessionHistoryKey = "BatteryMonitor_SessionHistory"

    // MARK: - Initialization

    private init() {
        setupBatteryMonitoring()
        loadSessionHistory()
    }

    // MARK: - Setup

    private func setupBatteryMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Get initial state
        currentBatteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

        // Observe battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)

        // Observe battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBatteryState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Management

    /// Start a new battery monitoring session
    /// - Parameter features: Set of features active during this session
    func startSession(features: Set<ActiveFeature> = []) {
        guard !isMonitoring else {
            // Add features to existing session
            currentSession?.features.formUnion(features)
            return
        }

        let level = UIDevice.current.batteryLevel
        guard level > 0 else {
            print("[BatteryMonitor] ⚠️ Cannot read battery level")
            return
        }

        currentSession = BatteryUsageSession(startBatteryLevel: level, features: features)
        isMonitoring = true
        batteryReadings.removeAll()
        batteryReadings.append((Date(), level))

        startUpdateTimer()

        print("[BatteryMonitor] 🔋 Started session at \(Int(level * 100))% with features: \(features)")
    }

    /// End the current monitoring session
    func endSession() {
        guard var session = currentSession else { return }

        stopUpdateTimer()

        let endLevel = UIDevice.current.batteryLevel
        session.endTime = Date()
        session.endBatteryLevel = endLevel

        // Add to history
        sessionHistory.append(session)
        if sessionHistory.count > maxHistorySize {
            sessionHistory.removeFirst()
        }
        saveSessionHistory()

        // Log results
        if let rate = session.drainPerHour {
            let meetsTarget = rate < Self.targetDrainPerHour
            print("[BatteryMonitor] 🔋 Session ended: \(String(format: "%.1f", rate))%/hour (\(meetsTarget ? "✅ within target" : "⚠️ exceeds target"))")
        }

        currentSession = nil
        isMonitoring = false
        isExceedingTarget = false
    }

    /// Add a feature to the current session
    func addFeature(_ feature: ActiveFeature) {
        currentSession?.features.insert(feature)
    }

    /// Remove a feature from the current session
    func removeFeature(_ feature: ActiveFeature) {
        currentSession?.features.remove(feature)
    }

    // MARK: - Battery Updates

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBatteryLevel()
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateBatteryLevel() {
        let level = UIDevice.current.batteryLevel
        guard level > 0 else { return }

        currentBatteryLevel = level

        // Record reading
        batteryReadings.append((Date(), level))
        if batteryReadings.count > maxReadings {
            batteryReadings.removeFirst()
        }

        // Calculate current drain rate
        calculateDrainRate()
    }

    private func updateBatteryState() {
        let state = UIDevice.current.batteryState
        isCharging = state == .charging || state == .full
    }

    /// Calculate current drain rate from recent readings
    private func calculateDrainRate() {
        guard batteryReadings.count >= 2 else {
            currentDrainRate = 0
            return
        }

        let oldest = batteryReadings.first!
        let newest = batteryReadings.last!

        let duration = newest.time.timeIntervalSince(oldest.time)
        guard duration > 60 else { return } // Need at least 1 minute of data

        let drain = oldest.level - newest.level
        guard drain > 0 else {
            currentDrainRate = 0
            isExceedingTarget = false
            return
        }

        let hours = duration / 3600.0
        currentDrainRate = Double(drain) / hours * 100 // Percentage per hour

        // Check target
        isExceedingTarget = currentDrainRate > Self.targetDrainPerHour

        if isExceedingTarget {
            print("[BatteryMonitor] ⚠️ Current drain rate: \(String(format: "%.1f", currentDrainRate))%/hr exceeds target")
        }
    }

    // MARK: - Statistics

    /// Get overall battery statistics
    func getStatistics() -> BatteryStatistics {
        let validSessions = sessionHistory.filter { $0.duration ?? 0 >= minimumSessionDuration }

        guard !validSessions.isEmpty else {
            return BatteryStatistics(
                averageDrainPerHour: 0,
                sessionsCount: 0,
                sessionsWithinTarget: 0,
                totalMonitoringHours: 0,
                featureBreakdown: [:]
            )
        }

        let rates = validSessions.compactMap { $0.drainPerHour }
        let averageRate = rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)

        let withinTarget = validSessions.filter { $0.meetsTarget }.count

        let totalHours = validSessions.compactMap { $0.duration }.reduce(0, +) / 3600.0

        // Calculate feature breakdown
        var featureBreakdown: [ActiveFeature: Double] = [:]
        for feature in ActiveFeature.allCases {
            let sessionsWithFeature = validSessions.filter { $0.features.contains(feature) }
            let featureRates = sessionsWithFeature.compactMap { $0.drainPerHour }
            if !featureRates.isEmpty {
                featureBreakdown[feature] = featureRates.reduce(0, +) / Double(featureRates.count)
            }
        }

        return BatteryStatistics(
            averageDrainPerHour: averageRate,
            sessionsCount: validSessions.count,
            sessionsWithinTarget: withinTarget,
            totalMonitoringHours: totalHours,
            featureBreakdown: featureBreakdown
        )
    }

    /// Get session history
    func getSessionHistory() -> [BatteryUsageSession] {
        return sessionHistory
    }

    // MARK: - Persistence

    private func saveSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: sessionHistoryKey)
        }
    }

    private func loadSessionHistory() {
        if let data = UserDefaults.standard.data(forKey: sessionHistoryKey),
           let history = try? JSONDecoder().decode([BatteryUsageSession].self, from: data) {
            sessionHistory = history
        }
    }

    // MARK: - Debug

    func debugSummary() -> String {
        """
        BatteryMonitor State:
          Monitoring: \(isMonitoring)
          Current Level: \(Int(currentBatteryLevel * 100))%
          Charging: \(isCharging)
          Drain Rate: \(String(format: "%.1f", currentDrainRate))%/hr
          Exceeds Target: \(isExceedingTarget)
          Sessions: \(sessionHistory.count)
        """
    }
}

// MARK: - ActiveFeature Extension

extension ActiveFeature: CaseIterable {}

// MARK: - Battery Statistics

struct BatteryStatistics {
    let averageDrainPerHour: Double
    let sessionsCount: Int
    let sessionsWithinTarget: Int
    let totalMonitoringHours: Double
    let featureBreakdown: [ActiveFeature: Double]

    var targetComplianceRate: Double {
        guard sessionsCount > 0 else { return 1.0 }
        return Double(sessionsWithinTarget) / Double(sessionsCount)
    }

    var formattedAverage: String {
        String(format: "%.1f%%/hr", averageDrainPerHour)
    }

    var formattedCompliance: String {
        String(format: "%.0f%%", targetComplianceRate * 100)
    }
}
