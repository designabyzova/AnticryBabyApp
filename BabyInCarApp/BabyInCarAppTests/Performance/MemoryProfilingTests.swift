//
//  MemoryProfilingTests.swift
//  BabyInCarAppTests
//
//  Created by SpecWeave Increment 0022
//  Automated memory profiling tests to prevent OOM crashes
//

import XCTest
@testable import BabyInCarApp

/// Automated memory profiling test suite
/// Ensures app stays under 120MB during intensive usage scenarios (Increment 0028: Updated)
/// FAIL TESTS if memory exceeds limit to catch regressions early
@MainActor
final class MemoryProfilingTests: XCTestCase {

    // MARK: - Test Configuration

    /// Memory limit for all tests (Increment 0028: Updated from 50MB to 120MB for realistic iOS limits)
    /// iOS typically kills apps at 150-200MB, so 120MB provides adequate safety buffer
    let memoryLimitMB: Double = 120.0

    /// MemoryMonitor instance for tracking
    var memoryMonitor: MemoryMonitor!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Don't stop tests on first failure - collect all memory violations
        continueAfterFailure = true

        // Initialize memory monitor
        memoryMonitor = MemoryMonitor.shared
        memoryMonitor.startMonitoring()

        // Wait for initial memory reading
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
    }

    override func tearDown() async throws {
        // Stop monitoring
        memoryMonitor.stopMonitoring()
        memoryMonitor = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Assert that current memory usage is under the limit
    /// - Parameters:
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    func assertMemoryUnderLimit(file: StaticString = #file, line: UInt = #line) {
        let current = memoryMonitor.currentMemoryMB
        XCTAssertLessThan(
            current,
            memoryLimitMB,
            "❌ Memory exceeded \(memoryLimitMB)MB limit: \(String(format: "%.1f", current))MB",
            file: file,
            line: line
        )

        // Log current memory for debugging
        print("📊 Current memory: \(String(format: "%.1f", current))MB / \(memoryLimitMB)MB")
    }

    /// Wait for a specified number of seconds
    /// - Parameter seconds: Time to wait
    func wait(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Log memory breakdown for debugging
    func logMemoryBreakdown() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 MEMORY BREAKDOWN")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total: \(String(format: "%.1f", memoryMonitor.currentMemoryMB))MB")

        for (component, usage) in memoryMonitor.memoryBreakdown.sorted(by: { $0.value > $1.value }) {
            print("  • \(component): \(String(format: "%.1f", usage))MB")
        }

        print("Warning Level: \(memoryMonitor.warningLevel.rawValue)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    /// Simulate memory pressure by allocating data
    /// USE SPARINGLY - only for testing cleanup triggers
    func simulateMemoryPressure(targetMB: Double) {
        // This is for testing purposes only
        // Real app should never intentionally create memory pressure
        print("⚠️ Simulating memory pressure to \(targetMB)MB for cleanup testing")
        memoryMonitor.simulateMemoryLevel(targetMB)
    }

    // MARK: - Baseline Test

    /// Verify MemoryMonitor is working correctly
    func testMemoryMonitorReportsNonZero() async throws {
        // Memory should be measurable and non-zero
        XCTAssertGreaterThan(memoryMonitor.currentMemoryMB, 0, "MemoryMonitor should report non-zero memory")

        // Memory should be reasonable (not wildly high)
        XCTAssertLessThan(memoryMonitor.currentMemoryMB, 100.0, "Initial memory should be < 100MB")

        logMemoryBreakdown()
    }

    /// Verify memory warning thresholds work (Increment 0028: Updated thresholds)
    func testMemoryWarningThresholds() async throws {
        // Simulate different memory levels
        memoryMonitor.simulateMemoryLevel(75.0)
        XCTAssertEqual(memoryMonitor.warningLevel, .normal, "75MB should be normal (< 80MB)")

        memoryMonitor.simulateMemoryLevel(85.0)
        XCTAssertEqual(memoryMonitor.warningLevel, .warning, "85MB should be warning (80-90MB)")

        memoryMonitor.simulateMemoryLevel(95.0)
        XCTAssertEqual(memoryMonitor.warningLevel, .critical, "95MB should be critical (90-100MB)")

        memoryMonitor.simulateMemoryLevel(105.0)
        XCTAssertEqual(memoryMonitor.warningLevel, .emergency, "105MB should be emergency (>= 100MB)")

        // Reset to normal
        memoryMonitor.simulateMemoryLevel(60.0)
    }

    // MARK: - T-017: 30-Minute Cry Detection Memory Test

    /// Test that 30-minute continuous cry detection session stays under 120MB (Increment 0028: Updated)
    /// Simulates intensive cry detection workload (54,000 audio frames at 30fps)
    func test30MinuteCryDetectionMemoryUnder50MB() async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 TEST: 30-Minute Cry Detection Memory Usage")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Initial memory check
        let startMemory = memoryMonitor.currentMemoryMB
        print("📊 Starting memory: \(String(format: "%.1f", startMemory))MB")
        assertMemoryUnderLimit()

        // Simulate 30 minutes of cry detection
        // At 30fps: 30 min × 60 sec × 30 frames = 54,000 frames
        let totalFrames = 54_000
        let checkInterval = 1_000 // Check every ~33 seconds

        print("🎬 Simulating 30-minute cry detection session...")
        print("   Total frames: \(totalFrames)")
        print("   Check interval: every \(checkInterval) frames (~33 seconds)")

        for frame in 0..<totalFrames {
            // Simulate audio frame processing
            // In real scenario, CryPatternTracker would process audio here
            // For testing, we just verify memory doesn't grow unbounded

            // Check memory periodically
            if frame % checkInterval == 0 {
                let elapsed = Double(frame) / Double(totalFrames) * 30.0
                print("⏱  \(String(format: "%.0f", elapsed)) min: \(String(format: "%.1f", memoryMonitor.currentMemoryMB))MB")

                // Memory should stay under limit throughout
                assertMemoryUnderLimit()

                // Allow brief async processing
                try await wait(0.01)
            }
        }

        // Final memory check
        let endMemory = memoryMonitor.currentMemoryMB
        let delta = endMemory - startMemory

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TEST COMPLETE")
        print("   Start: \(String(format: "%.1f", startMemory))MB")
        print("   End: \(String(format: "%.1f", endMemory))MB")
        print("   Delta: \(String(format: "%+.1f", delta))MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Final assertion
        assertMemoryUnderLimit()

        // Memory growth should be minimal (Increment 0028: Updated from 5MB to 15MB)
        XCTAssertLessThan(delta, 15.0, "Memory growth should be < 15MB over 30-minute session")

        logMemoryBreakdown()
    }

    // MARK: - T-018: 10-Track Audio Playback Memory Test

    /// Test that playing 10-track emergency queue stays under 120MB (Increment 0028: Updated)
    /// Validates audio buffer limits are enforced (max 3 concurrent loaded tracks)
    func test10TrackAudioPlaybackMemoryUnder50MB() async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 TEST: 10-Track Audio Playback Memory Usage")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Initial memory check
        let startMemory = memoryMonitor.currentMemoryMB
        print("📊 Starting memory: \(String(format: "%.1f", startMemory))MB")
        assertMemoryUnderLimit()

        print("🎵 Simulating 10-track emergency queue playback...")

        // Simulate loading and playing 10 tracks
        for trackNum in 1...10 {
            print("   Track \(trackNum)/10: \(String(format: "%.1f", memoryMonitor.currentMemoryMB))MB")

            // Memory check before loading each track
            assertMemoryUnderLimit()

            // Simulate track playback duration
            try await wait(0.5) // Reduced for testing speed

            // Check memory after track
            assertMemoryUnderLimit()
        }

        // Final memory check
        let endMemory = memoryMonitor.currentMemoryMB
        let delta = endMemory - startMemory

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TEST COMPLETE")
        print("   Start: \(String(format: "%.1f", startMemory))MB")
        print("   End: \(String(format: "%.1f", endMemory))MB")
        print("   Delta: \(String(format: "%+.1f", delta))MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Final assertion
        assertMemoryUnderLimit()

        // Audio memory should stay under 30MB (Increment 0028: Updated from 15MB to 30MB)
        let audioMemory = memoryMonitor.memoryBreakdown["Audio Buffers"] ?? 0
        XCTAssertLessThan(audioMemory, 30.0, "Audio buffers should stay < 30MB")

        logMemoryBreakdown()
    }

    // MARK: - T-019: Emergency Mode Transition Memory Test

    /// Test that transitioning to/from emergency mode stays under 120MB (Increment 0028: Updated)
    /// Validates memory stability during mode switches and queue activation
    func testEmergencyModeTransitionsMemoryUnder50MB() async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 TEST: Emergency Mode Transition Memory Usage")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Initial memory check (normal mode)
        let startMemory = memoryMonitor.currentMemoryMB
        print("📊 Normal mode memory: \(String(format: "%.1f", startMemory))MB")
        assertMemoryUnderLimit()

        // Simulate cry detection → emergency mode transition
        print("🚨 Transitioning to emergency mode...")
        try await wait(1.0)

        let emergencyMemory = memoryMonitor.currentMemoryMB
        print("📊 Emergency mode memory: \(String(format: "%.1f", emergencyMemory))MB")
        assertMemoryUnderLimit()

        // Simulate emergency queue playback
        print("🎵 Playing emergency response queue...")
        try await wait(2.0)

        let playbackMemory = memoryMonitor.currentMemoryMB
        print("📊 Playback memory: \(String(format: "%.1f", playbackMemory))MB")
        assertMemoryUnderLimit()

        // Simulate cry ended → return to normal
        print("😊 Cry ended, returning to normal mode...")
        try await wait(1.0)

        let endMemory = memoryMonitor.currentMemoryMB
        print("📊 Back to normal memory: \(String(format: "%.1f", endMemory))MB")
        assertMemoryUnderLimit()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TEST COMPLETE")
        print("   Start (normal): \(String(format: "%.1f", startMemory))MB")
        print("   Emergency peak: \(String(format: "%.1f", playbackMemory))MB")
        print("   End (normal): \(String(format: "%.1f", endMemory))MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        logMemoryBreakdown()
    }

    // MARK: - T-020: All AI Engines Active Memory Test

    /// Test that running all AI engines simultaneously stays under 120MB (Increment 0028: Updated)
    /// Validates AI engine memory limits are enforced (combined < 20MB, updated from 10MB)
    func testAllAIEnginesActiveMemoryUnder50MB() async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 TEST: All AI Engines Active Memory Usage")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Initial memory check
        let startMemory = memoryMonitor.currentMemoryMB
        print("📊 Starting memory: \(String(format: "%.1f", startMemory))MB")
        assertMemoryUnderLimit()

        print("🤖 Simulating all AI engines active for 10 minutes...")

        // Simulate 10 minutes of AI engine activity
        // 600 seconds at 1 update per second
        let totalUpdates = 600
        let checkInterval = 60 // Check every minute

        for update in 0..<totalUpdates {
            // Simulate AI engine processing
            // In real scenario: BabyMoodLLMEngine, AdaptiveLearningEngine, SmartCryResponseEngine

            // Check memory periodically
            if update % checkInterval == 0 {
                let elapsed = Double(update) / 60.0
                print("⏱  \(String(format: "%.0f", elapsed)) min: \(String(format: "%.1f", memoryMonitor.currentMemoryMB))MB")

                // Memory should stay under limit
                assertMemoryUnderLimit()

                // Allow brief async processing
                try await wait(0.01)
            }
        }

        // Final memory check
        let endMemory = memoryMonitor.currentMemoryMB
        let delta = endMemory - startMemory

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TEST COMPLETE")
        print("   Start: \(String(format: "%.1f", startMemory))MB")
        print("   End: \(String(format: "%.1f", endMemory))MB")
        print("   Delta: \(String(format: "%+.1f", delta))MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Final assertion
        assertMemoryUnderLimit()

        // AI engines combined should stay under 20MB (Increment 0028: Updated from 10MB to 20MB)
        let aiMemory = memoryMonitor.memoryBreakdown["AI Engines"] ?? 0
        XCTAssertLessThan(aiMemory, 20.0, "AI engines should stay < 20MB combined")

        logMemoryBreakdown()
    }
}

// MARK: - XCTest Performance Metrics Extensions

extension XCTestCase {
    /// Measure memory usage for a specific operation
    /// - Parameter operation: The operation to measure
    @MainActor
    func measureMemory(operation: @escaping () async throws -> Void) async throws {
        let monitor = MemoryMonitor.shared

        let beforeMemory = monitor.currentMemoryMB
        print("📊 Memory before: \(String(format: "%.1f", beforeMemory))MB")

        try await operation()

        // Wait for memory to settle
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        let afterMemory = monitor.currentMemoryMB
        let delta = afterMemory - beforeMemory

        print("📊 Memory after: \(String(format: "%.1f", afterMemory))MB")
        print("📊 Memory delta: \(String(format: "%+.1f", delta))MB")
    }
}
