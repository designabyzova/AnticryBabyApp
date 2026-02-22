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
    case warning = "Warning"      // > 350MB - start monitoring
    case critical = "Critical"    // > 450MB - reduce caches
    case emergency = "Emergency"  // > 550MB - aggressive cleanup
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
    // Modern iOS allows 500-700MB for foreground media apps
    // Previous thresholds (150/180/220) triggered false alarms at normal usage (~180MB)
    private let warningThresholdMB: Double = 350   // 350 MB - start monitoring closely
    private let criticalThresholdMB: Double = 450  // 450 MB - reduce caches
    private let emergencyThresholdMB: Double = 550 // 550 MB - aggressive cleanup (but KEEP audio!)

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
        // CRITICAL FIX: Use DispatchQueue.main.async instead of Task { @MainActor }
        // to avoid "Publishing changes from within view updates" warnings
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
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()

    case .critical:
        logger.error("🔴 Memory cleanup: CRITICAL level")
        // Only clear caches if audio is not playing
        if !AudioEngine.shared.playbackState.isPlaying {
            // Clear all caches
            URLCache.shared.removeAllCachedResponses()
        } else {
            logger.warning("⚠️ Skipping cache cleanup - audio is playing")
        }

    case .emergency:
        logger.fault("🚨 Memory cleanup: EMERGENCY level")
        // Check if audio is playing FIRST to protect it from ANY disruption
        let isAudioPlaying = AudioEngine.shared.playbackState.isPlaying

        if isAudioPlaying {
            logger.warning("🚨 PROTECTING audio - minimal cleanup only!")
            logger.info("✅ Audio protected")
        } else {
            // No audio playing - safe to do full cleanup
            // Clear audio caches for FUTURE tracks, not currently playing
            Task {
                await AudioCacheService.shared.clearAllCache()
            }
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
        }
    }
}
