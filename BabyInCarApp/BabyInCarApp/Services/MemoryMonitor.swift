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
        case normal      // < 40MB  - healthy
        case warning     // 40-45MB - approaching limit
        case critical    // 45-48MB - cleanup needed
        case emergency   // > 48MB  - aggressive cleanup

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

    // MARK: - Private Properties

    private var timer: Timer?
    private let logger = Logger(subsystem: "com.anticry.babyincar", category: "MemoryMonitor")

    // Memory thresholds (in MB) - Updated for realistic iOS limits
    // iOS typically kills apps at 150-200MB for foreground apps
    // These thresholds provide adequate warning buffer before iOS termination
    private let normalThreshold: Double = 80.0
    private let warningThreshold: Double = 90.0
    private let criticalThreshold: Double = 100.0

    // MARK: - Initialization

    private init() {
        logger.info("MemoryMonitor initialized")
    }

    // MARK: - Public Methods

    /// Start monitoring memory usage every 5 seconds
    func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("MemoryMonitor already running")
            return
        }

        logger.info("Starting memory monitoring (5-second intervals)")
        isMonitoring = true

        // Initial reading
        updateMemoryUsage()

        // Schedule timer for 5-second intervals
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
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

        // Rough estimates based on increment 0022 analysis
        memoryBreakdown = [
            "Audio Buffers": min(total * 0.35, 30.0),      // ~35% or max 30MB
            "AI Engines": min(total * 0.25, 20.0),         // ~25% or max 20MB
            "Cry Detection": min(total * 0.10, 5.0),       // ~10% or max 5MB
            "UI/System": min(total * 0.20, 15.0),          // ~20% or max 15MB
            "Other": max(0, total - 70.0)                   // Remainder
        ]
    }

    private func checkThresholds() {
        let previousLevel = warningLevel

        switch currentMemoryMB {
        case 0..<normalThreshold:
            warningLevel = .normal

        case normalThreshold..<warningThreshold:
            warningLevel = .warning
            if previousLevel != .warning {
                logWarning()
            }

        case warningThreshold..<criticalThreshold:
            warningLevel = .critical
            if previousLevel != .critical {
                triggerAutoCleanup()
            }

        default: // >= criticalThreshold
            warningLevel = .emergency
            if previousLevel != .emergency {
                triggerAggressiveCleanup()
            }
        }
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
