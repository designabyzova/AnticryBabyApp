//
//  MemoryMonitor.swift
//  BabyInCarApp
//
//  Created by SpecWeave Increment 0022
//  Memory Leak Prevention System
//

import Foundation
import SwiftUI
import os.log

/// Real-time memory monitoring service with automatic cleanup triggers
/// Tracks app memory usage and prevents iOS OOM kills
@MainActor
class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()

    // MARK: - Published Properties

    @Published var currentMemoryMB: Double = 0.0
    @Published var memoryBreakdown: [String: Double] = [:]
    @Published var warningLevel: MemoryWarningLevel = .normal
    @Published var isMonitoring: Bool = false

    // MARK: - Memory Warning Levels

    enum MemoryWarningLevel: String {
        case normal      // < 150MB - healthy for modern iOS app with ML
        case warning     // 150-180MB - approaching limit, monitor closely
        case critical    // 180-220MB - reduce ML features
        case emergency   // > 220MB - aggressive cleanup needed

        var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .yellow
            case .critical: return .orange
            case .emergency: return .red
            }
        }

        var emoji: String {
            switch self {
            case .normal: return "✅"
            case .warning: return "⚠️"
            case .critical: return "🔴"
            case .emergency: return "🚨"
            }
        }
    }

    // MARK: - Callbacks (MEMORY FIX 0030: Merged from MemoryPressureMonitor)
    var onWarningLevel: (() -> Void)?
    var onCriticalLevel: (() -> Void)?
    var onEmergencyLevel: (() -> Void)?

    // MARK: - Private Properties

    private var timer: Timer?
    private let logger = Logger(subsystem: "com.anticry.babyincar", category: "MemoryMonitor")

    // Memory thresholds (in MB)
    private let normalThreshold: Double = 150.0
    private let warningThreshold: Double = 180.0
    private let criticalThreshold: Double = 220.0

    // MARK: - Initialization

    private init() {
        logger.info("MemoryMonitor initialized")
        setupSystemMemoryWarningObserver()
    }

    /// Listen for iOS system memory warnings (merged from MemoryPressureMonitor)
    private func setupSystemMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSystemMemoryWarning()
            }
        }
    }

    private func handleSystemMemoryWarning() {
        let memoryMB = getMemoryUsageMB()
        logger.fault("🚨 SYSTEM MEMORY WARNING received! Current usage: \(Int(memoryMB))MB")
        warningLevel = .emergency
        currentMemoryMB = memoryMB
        onEmergencyLevel?()
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            userInfo: ["level": "emergency", "memoryMB": memoryMB, "source": "SystemWarning"]
        )
    }

    // MARK: - Public Methods

    /// Start monitoring memory usage
    /// THERMAL FIX: Increased interval from 5s to 15s - memory doesn't change that fast, saves CPU cycles
    func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("MemoryMonitor already running")
            return
        }

        logger.info("Starting memory monitoring (15-second intervals)")
        isMonitoring = true

        // Initial reading
        updateMemoryUsage()

        // THERMAL FIX: Schedule timer for 15-second intervals (was 5s)
        // Memory changes slowly - checking every 5s was overkill and added unnecessary CPU load
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMemoryUsage()
                self?.checkThresholds()
            }
        }
    }

    /// Stop memory monitoring
    func stopMonitoring() {
        logger.info("Stopping memory monitoring")
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    /// Force an immediate memory check (for testing)
    func forceUpdate() {
        updateMemoryUsage()
        checkThresholds()
    }

    // MARK: - Private Methods

    private func updateMemoryUsage() {
        let usage = getMemoryUsageMB()
        currentMemoryMB = usage
        updateBreakdown()

        logger.debug("Memory: \(String(format: "%.1f", usage)) MB")
    }

    private func updateBreakdown() {
        // Estimate breakdown by component (heuristics based on profiling)
        // These are estimates - actual values would need Instruments
        let total = currentMemoryMB

        // Rough estimates based on memory profiling
        memoryBreakdown = [
            "Audio Buffers": min(total * 0.40, 35.0),      // ~40% or max 35MB
            "Learning Engine": min(total * 0.20, 15.0),    // ~20% or max 15MB
            "Content Library": min(total * 0.15, 10.0),    // ~15% or max 10MB
            "UI/System": min(total * 0.25, 20.0),          // ~25% or max 20MB
        ]
    }

    private func checkThresholds() {
        let previousLevel = warningLevel

        switch currentMemoryMB {
        case 0..<normalThreshold:
            warningLevel = .normal
            if previousLevel != .normal && previousLevel != .warning {
                notifyMemoryNormalized()
            }

        case normalThreshold..<warningThreshold:
            warningLevel = .warning
            if previousLevel != .warning {
                logWarning()
                onWarningLevel?()
            }
            if previousLevel == .critical || previousLevel == .emergency {
                notifyMemoryNormalized()
            }

        case warningThreshold..<criticalThreshold:
            warningLevel = .critical
            if previousLevel != .critical {
                triggerAutoCleanup()
                onCriticalLevel?()
            }

        default: // >= criticalThreshold
            warningLevel = .emergency
            if previousLevel != .emergency {
                triggerAggressiveCleanup()
                onEmergencyLevel?()
            }
        }
    }

    /// Notify services that memory pressure has normalized
    private func notifyMemoryNormalized() {
        logger.info("✅ Memory pressure normalized at \(String(format: "%.1f", self.currentMemoryMB)) MB")
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressureNormalized"),
            object: nil,
            userInfo: ["memoryMB": currentMemoryMB]
        )
    }

    private func logWarning() {
        logger.warning("⚠️ Memory warning: \(String(format: "%.1f", self.currentMemoryMB)) MB (threshold: \(self.normalThreshold) MB)")
        logger.warning("Breakdown: \(self.memoryBreakdown.description)")
    }

    private func triggerAutoCleanup() {
        let beforeCleanup = currentMemoryMB
        logger.error("🔴 Critical memory: \(String(format: "%.1f", beforeCleanup)) MB - triggering cleanup")

        // Post notification for cleanup delegates
        // Services listening: AudioEngine, DynamicSoundMixer, AdaptiveLearningEngine, BabyMoodLLMEngine
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            userInfo: ["level": "critical", "memoryMB": beforeCleanup]
        )

        // Schedule memory check after cleanup (give services 2 seconds to respond)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            let afterCleanup = self.currentMemoryMB
            let reduction = beforeCleanup - afterCleanup
            self.logger.info("🧹 Cleanup complete: \(String(format: "%.1f", beforeCleanup)) MB → \(String(format: "%.1f", afterCleanup)) MB (reduced \(String(format: "%.1f", reduction)) MB)")

            if afterCleanup < 35.0 {
                self.logger.info("✅ Memory successfully reduced below 35MB target")
            } else if reduction > 5.0 {
                self.logger.info("⚠️ Cleanup helped but memory still high: \(String(format: "%.1f", afterCleanup)) MB")
            } else {
                self.logger.warning("❌ Cleanup had minimal effect: \(String(format: "%.1f", reduction)) MB reduction")
            }
        }
    }

    private func triggerAggressiveCleanup() {
        let beforeCleanup = currentMemoryMB
        logger.error("🚨 EMERGENCY memory: \(String(format: "%.1f", beforeCleanup)) MB - AGGRESSIVE cleanup!")

        // Post notification for aggressive cleanup
        // Services listening: AudioEngine, DynamicSoundMixer, AdaptiveLearningEngine, BabyMoodLLMEngine
        // Expected actions:
        // - Stop all non-essential audio processing
        // - Release ALL buffers except currently playing track
        // - Reduce AI histories to minimum (10 entries)
        // - Clear all caches aggressively
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            userInfo: ["level": "emergency", "memoryMB": beforeCleanup]
        )

        // Schedule memory check after aggressive cleanup (give services 3 seconds to respond)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            let afterCleanup = self.currentMemoryMB
            let reduction = beforeCleanup - afterCleanup
            self.logger.info("🧹 AGGRESSIVE cleanup complete: \(String(format: "%.1f", beforeCleanup)) MB → \(String(format: "%.1f", afterCleanup)) MB (reduced \(String(format: "%.1f", reduction)) MB)")

            if afterCleanup < 30.0 {
                self.logger.info("✅ Emergency cleanup SUCCESSFUL - memory reduced below 30MB target")
            } else if afterCleanup < 40.0 {
                self.logger.warning("⚠️ Partial success - memory at \(String(format: "%.1f", afterCleanup)) MB (target: < 30MB)")
            } else {
                self.logger.error("❌ CRITICAL: Aggressive cleanup FAILED - memory still at \(String(format: "%.1f", afterCleanup)) MB")
                self.logger.error("⚠️ App may be killed by iOS if memory continues to grow")
            }
        }
    }

    // MARK: - task_info Memory Measurement

    /// Get current app memory usage in MB using task_info API
    /// Returns the resident memory size (physical memory used by the app)
    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            logger.error("Failed to get memory info: \(result)")
            return 0.0
        }

        let memoryBytes = Double(info.resident_size)
        let memoryMB = memoryBytes / 1024.0 / 1024.0

        return memoryMB
    }
}

// MARK: - Preview Helper

#if DEBUG
extension MemoryMonitor {
    /// Simulate memory usage for testing (SwiftUI Previews)
    func simulateMemoryLevel(_ mb: Double) {
        currentMemoryMB = mb
        updateBreakdown()
        checkThresholds()
    }
}
#endif
