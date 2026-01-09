//
//  MemoryPressureMonitor.swift
//  BabyInCarApp
//
//  Monitors memory usage and triggers cleanup when approaching limits
//  Prevents iOS from killing the app due to excessive memory usage
//
//  NOTE (Increment 0029): This monitor is SECONDARY to MemoryMonitor.swift
//  MemoryMonitor is the PRIMARY source of truth for memory management.
//  This class is kept for backward compatibility and additional iOS memory warning handling.
//  Consider consolidating fully in a future refactor.
//

import Foundation
import UIKit
import os.log

/// Memory pressure levels based on available memory
enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"      // > 150MB - start monitoring
    case critical = "Critical"    // > 180MB - reduce ML features
    case emergency = "Emergency"  // > 220MB - aggressive cleanup
}

/// Monitors app memory usage and triggers cleanup actions
/// Use this to prevent iOS from killing the app due to memory pressure
/// NOTE: MemoryMonitor.swift is the PRIMARY monitor. This class provides iOS memory warning integration.
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
    /// THERMAL FIX: Default interval increased from 5s to 15s - reduces CPU overhead significantly
    /// NOTE: This monitor duplicates MemoryMonitor.swift - consider consolidating in future refactor
    func startMonitoring(interval: TimeInterval = 15.0) {
        guard !isMonitoring else { return }

        isMonitoring = true
        // THERMAL FIX: Reduced frequency from 5s to 15s (same as MemoryMonitor)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // FIX: Use DispatchQueue.main.async to prevent "Publishing changes from within view updates"
            DispatchQueue.main.async {
                self?.checkMemoryUsage()
            }
        }

        // Initial check
        checkMemoryUsage()
        logger.info("Memory monitoring started (interval: \(Int(interval))s)")
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

        // Post notification for other components (legacy)
        NotificationCenter.default.post(
            name: Notification.Name("MemoryPressureEmergency"),
            object: nil,
            userInfo: ["memoryMB": memoryMB]
        )

        // MEMORY OPTIMIZATION (Increment 0029): Also post to centralized cleanup system
        // This ensures all services receive the emergency cleanup request
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            userInfo: ["level": "emergency", "memoryMB": memoryMB, "source": "SystemWarning"]
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
        // Disable all ML (always safe)
        CryDetectionService.shared.useMLEnhancement = false
        CryDetectionService.shared.useDeepInfant = false

        // 🚨 CRITICAL FIX: Protect emergency audio from any cleanup
        if !SmartEmergencyQueue.shared.isActive {
            // Stop cry response engine if not essential
            SmartCryResponseEngine.shared.performLightCleanup()
            // Clear all caches
            URLCache.shared.removeAllCachedResponses()
        } else {
            logger.warning("⚠️ Skipping aggressive cleanup - emergency audio is playing")
        }

    case .emergency:
        logger.fault("🚨 Memory cleanup: EMERGENCY level")
        // 🚨 CRITICAL FIX: Check if emergency audio is playing FIRST!
        // If emergency audio is active, we MUST protect it from ANY disruption.
        // The "broken radio" sound was caused by cleanup interfering with audio.
        let isEmergencyAudioActive = SmartEmergencyQueue.shared.isActive

        if isEmergencyAudioActive {
            logger.warning("🚨 PROTECTING emergency audio - minimal cleanup only!")
            // ONLY disable ML features - absolutely NOTHING else
            CryDetectionService.shared.useMLEnhancement = false
            CryDetectionService.shared.useDeepInfant = false
            // Do NOT call SmartCryResponseEngine.performAggressiveCleanup() - it can affect audio
            // Do NOT clear ANY caches - this can cause audio buffer issues
            // Do NOT clear URL cache - this runs on main thread and can block audio callbacks
            logger.info("✅ Emergency audio protected - only ML disabled")
        } else {
            // No emergency audio - safe to do full cleanup
            // Stop ML services but NEVER stop audio playback
            // CRITICAL: Audio is the primary purpose - baby calming MUST continue
            CryDetectionService.shared.useMLEnhancement = false
            CryDetectionService.shared.useDeepInfant = false

            // Reduce AI features but KEEP audio playing
            SmartCryResponseEngine.shared.performAggressiveCleanup()

            // Clear audio caches for FUTURE tracks, not currently playing
            Task {
                await AudioCacheService.shared.clearAllCache()
            }
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
        }
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
