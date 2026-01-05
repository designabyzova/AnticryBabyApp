//
//  MemoryPressureMonitor.swift
//  BabyInCarApp
//
//  Monitors memory usage and triggers cleanup when approaching limits
//  Prevents iOS from killing the app due to excessive memory usage
//

import Foundation
import UIKit
import os.log

/// Memory pressure levels based on available memory
enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"      // > 80MB - start reducing
    case critical = "Critical"    // > 100MB - aggressive cleanup
    case emergency = "Emergency"  // > 130MB - iOS will kill VERY soon!
}

/// Monitors app memory usage and triggers cleanup actions
/// Use this to prevent iOS from killing the app due to memory pressure
@MainActor
class MemoryPressureMonitor: ObservableObject {
    static let shared = MemoryPressureMonitor()

    // MARK: - Published State
    @Published var currentMemoryMB: Double = 0
    @Published var pressureLevel: MemoryPressureLevel = .normal
    @Published var isMonitoring: Bool = false

    // MARK: - Configuration
    // Memory thresholds adjusted for realistic iOS limits
    // Modern iOS allows 150-200MB for foreground media apps
    // Original thresholds (80/100/130) were too aggressive and stopped audio unnecessarily
    private let warningThresholdMB: Double = 150   // 150 MB - start monitoring closely
    private let criticalThresholdMB: Double = 180  // 180 MB - reduce ML features
    private let emergencyThresholdMB: Double = 220 // 220 MB - aggressive ML cleanup (but KEEP audio!)

    // MARK: - Callbacks
    var onWarningLevel: (() -> Void)?
    var onCriticalLevel: (() -> Void)?
    var onEmergencyLevel: (() -> Void)?

    // MARK: - Private
    private var monitoringTimer: Timer?
    private let logger = Logger(subsystem: "com.babyincar", category: "MemoryMonitor")

    private init() {
        setupMemoryWarningObserver()
    }

    // MARK: - Setup
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemMemoryWarning()
            }
        }
    }

    // MARK: - Monitoring Control
    /// Start periodic memory monitoring
    func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }

        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // FIX: Use DispatchQueue.main.async to prevent "Publishing changes from within view updates"
            DispatchQueue.main.async {
                self?.checkMemoryUsage()
            }
        }

        // Initial check
        checkMemoryUsage()
        logger.info("Memory monitoring started")
    }

    /// Stop periodic memory monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        logger.info("Memory monitoring stopped")
    }

    // MARK: - Memory Checking
    /// Check current memory usage and update state
    func checkMemoryUsage() {
        let memoryMB = getAppMemoryUsageMB()
        currentMemoryMB = memoryMB

        let previousLevel = pressureLevel
        pressureLevel = calculatePressureLevel(memoryMB: memoryMB)

        // Log level changes
        if pressureLevel != previousLevel {
            logger.warning("Memory pressure changed: \(previousLevel.rawValue) → \(self.pressureLevel.rawValue) (\(Int(memoryMB))MB)")
        }

        // Trigger callbacks based on level
        switch pressureLevel {
        case .normal:
            break
        case .warning:
            if previousLevel == .normal {
                logger.warning("⚠️ Memory warning: \(Int(memoryMB))MB used")
                onWarningLevel?()
            }
        case .critical:
            if previousLevel != .critical && previousLevel != .emergency {
                logger.error("🔴 Memory critical: \(Int(memoryMB))MB used - triggering cleanup")
                onCriticalLevel?()
            }
        case .emergency:
            if previousLevel != .emergency {
                logger.fault("🚨 Memory emergency: \(Int(memoryMB))MB used - aggressive cleanup needed!")
                onEmergencyLevel?()
            }
        }
    }

    private func calculatePressureLevel(memoryMB: Double) -> MemoryPressureLevel {
        if memoryMB >= emergencyThresholdMB {
            return .emergency
        } else if memoryMB >= criticalThresholdMB {
            return .critical
        } else if memoryMB >= warningThresholdMB {
            return .warning
        } else {
            return .normal
        }
    }

    // MARK: - Memory Usage Retrieval
    /// Get current app memory usage in megabytes
    func getAppMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        }
        return 0
    }

    // MARK: - System Memory Warning Handler
    private func handleSystemMemoryWarning() {
        let memoryMB = getAppMemoryUsageMB()
        logger.fault("🚨 SYSTEM MEMORY WARNING received! Current usage: \(Int(memoryMB))MB")

        // Force emergency level
        pressureLevel = .emergency
        currentMemoryMB = memoryMB

        // Trigger emergency cleanup
        onEmergencyLevel?()

        // Post notification for other components
        NotificationCenter.default.post(
            name: Notification.Name("MemoryPressureEmergency"),
            object: nil,
            userInfo: ["memoryMB": memoryMB]
        )
    }

    // MARK: - Cleanup Helpers
    /// Suggest cleanup actions based on current memory usage
    func getSuggestedCleanupActions() -> [String] {
        var actions: [String] = []

        switch pressureLevel {
        case .normal:
            break
        case .warning:
            actions.append("Clear audio caches")
            actions.append("Reduce pattern history")
        case .critical:
            actions.append("Stop ML enhancement")
            actions.append("Clear all audio buffers")
            actions.append("Reduce analysis frequency")
        case .emergency:
            actions.append("Stop cry detection")
            actions.append("Clear all caches immediately")
            actions.append("Disable all background processing")
        }

        return actions
    }
}

// MARK: - Memory Cleanup Protocol
/// Protocol for components that can clean up memory on demand
protocol MemoryCleanable {
    /// Perform light cleanup (warning level)
    func performLightCleanup()

    /// Perform aggressive cleanup (critical/emergency level)
    func performAggressiveCleanup()
}

// MARK: - CryDetectionService Memory Cleanup Extension
extension CryDetectionService: MemoryCleanable {
    nonisolated func performLightCleanup() {
        Task { @MainActor in
            // Reduce ML enhancement temporarily
            self.useMLEnhancement = false
            print("[CryDetection] Light cleanup: Disabled ML enhancement")
        }
    }

    nonisolated func performAggressiveCleanup() {
        Task { @MainActor in
            // Disable heavy features
            self.useMLEnhancement = false
            self.useDeepInfant = false

            // Clear buffers (this will be called via stopMonitoring if needed)
            print("[CryDetection] Aggressive cleanup: Disabled all ML features")
        }
    }
}

// MARK: - Global Memory Cleanup Functions

/// Perform app-wide memory cleanup based on pressure level
/// Call this from MemoryPressureMonitor callbacks
@MainActor
func performGlobalMemoryCleanup(level: MemoryPressureLevel) {
    let logger = Logger(subsystem: "com.babyincar", category: "MemoryCleanup")

    switch level {
    case .normal:
        return

    case .warning:
        logger.warning("⚠️ Memory cleanup: WARNING level")
        // Disable ML features
        CryDetectionService.shared.useMLEnhancement = false
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()

    case .critical:
        logger.error("🔴 Memory cleanup: CRITICAL level")
        // Disable all ML
        CryDetectionService.shared.useMLEnhancement = false
        CryDetectionService.shared.useDeepInfant = false
        // Stop cry response engine if not essential
        SmartCryResponseEngine.shared.performLightCleanup()
        // Clear all caches
        URLCache.shared.removeAllCachedResponses()

    case .emergency:
        logger.fault("🚨 Memory cleanup: EMERGENCY level")
        // Stop ML services but NEVER stop audio playback
        // CRITICAL: Audio is the primary purpose - baby calming MUST continue
        CryDetectionService.shared.useMLEnhancement = false
        CryDetectionService.shared.useDeepInfant = false

        // Reduce AI features but KEEP audio playing
        SmartCryResponseEngine.shared.performAggressiveCleanup()

        // Clear audio caches for FUTURE tracks, not currently playing
        // NOTE: AudioCacheService.clearAllCache should NOT interrupt current playback
        Task {
            // Only clear cache if we have room - don't interrupt playback
            // Skip aggressive cache clear during active playback
            if SmartEmergencyQueue.shared.isActive {
                logger.warning("⚠️ Skipping cache clear - emergency audio is playing")
            } else {
                await AudioCacheService.shared.clearAllCache()
            }
        }
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - SmartCryResponseEngine Memory Cleanup Extension
extension SmartCryResponseEngine: MemoryCleanable {
    nonisolated func performLightCleanup() {
        Task { @MainActor in
            print("[SmartCryResponse] Light cleanup: Reducing features")
            // Continue playing but disable AI mode
            self.useBabyMIMMode = false
        }
    }

    nonisolated func performAggressiveCleanup() {
        Task { @MainActor in
            // CRITICAL FIX: NEVER stop audio during emergency playback!
            // Audio is the PRIMARY PURPOSE of the app - baby calming.
            // Memory cleanup should NOT stop audio - just reduce AI/ML features.
            print("[SmartCryResponse] Aggressive cleanup: Reducing AI features (KEEPING AUDIO)")

            // Disable AI features to save memory, but KEEP audio playing
            self.useBabyMIMMode = false
            // Keep isEmergencyMode = true (already set) - simple playlist mode continues

            // DO NOT call self.deactivate() - that stops audio!
            // The parent is using emergency mode because baby needs calming.
        }
    }
}
