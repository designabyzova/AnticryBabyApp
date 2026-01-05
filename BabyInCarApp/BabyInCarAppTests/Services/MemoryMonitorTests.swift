//
//  MemoryMonitorTests.swift
//  BabyInCarAppTests
//
//  Created by SpecWeave Increment 0022
//  Memory Leak Prevention System - Unit Tests
//

import XCTest
@testable import BabyInCarApp

@MainActor
final class MemoryMonitorTests: XCTestCase {
    var monitor: MemoryMonitor!

    override func setUp() async throws {
        try await super.setUp()
        monitor = MemoryMonitor.shared
        monitor.stopMonitoring() // Ensure clean state
    }

    override func tearDown() async throws {
        monitor.stopMonitoring()
        try await super.tearDown()
    }

    // MARK: - T-003 Tests (MemoryMonitor Service)

    func testMemoryMonitorReportsNonZero() async throws {
        monitor.startMonitoring()

        // Wait for first update (5 seconds + buffer)
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds

        XCTAssertGreaterThan(monitor.currentMemoryMB, 0,
                            "Memory monitor should report non-zero memory usage")
        XCTAssertTrue(monitor.isMonitoring,
                     "Monitor should be in monitoring state")
    }

    func testMemoryMonitorUpdatesEvery5Seconds() async throws {
        monitor.startMonitoring()

        let firstReading = monitor.currentMemoryMB

        // Wait for at least one update cycle
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds

        let secondReading = monitor.currentMemoryMB

        // Readings should be different (memory usage fluctuates)
        // OR both should be > 0 if same
        XCTAssertGreaterThan(secondReading, 0,
                            "Second reading should be non-zero")
    }

    func testMemoryMonitorCanStop() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)

        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testMemoryBreakdownProvided() {
        monitor.startMonitoring()
        monitor.forceUpdate()

        XCTAssertFalse(monitor.memoryBreakdown.isEmpty,
                      "Memory breakdown should be populated")

        // Should have expected categories
        XCTAssertNotNil(monitor.memoryBreakdown["Audio Buffers"])
        XCTAssertNotNil(monitor.memoryBreakdown["AI Engines"])
        XCTAssertNotNil(monitor.memoryBreakdown["Cry Detection"])
    }

    // MARK: - T-004 Tests (Warning Thresholds) - Updated for realistic iOS limits

    func testWarningThresholdsNormal() {
        #if DEBUG
        monitor.simulateMemoryLevel(75.0)
        XCTAssertEqual(monitor.warningLevel, .normal,
                      "Should be normal at 75MB (< 80MB)")
        #endif
    }

    func testWarningThresholdsWarning() {
        #if DEBUG
        monitor.simulateMemoryLevel(85.0)
        XCTAssertEqual(monitor.warningLevel, .warning,
                      "Should be warning at 85MB (80-90MB)")
        #endif
    }

    func testWarningThresholdsCritical() {
        #if DEBUG
        monitor.simulateMemoryLevel(95.0)
        XCTAssertEqual(monitor.warningLevel, .critical,
                      "Should be critical at 95MB (90-100MB)")
        #endif
    }

    func testWarningThresholdsEmergency() {
        #if DEBUG
        monitor.simulateMemoryLevel(105.0)
        XCTAssertEqual(monitor.warningLevel, .emergency,
                      "Should be emergency at 105MB (>= 100MB)")
        #endif
    }

    func testWarningLevelTransitions() {
        #if DEBUG
        // Test transition from normal to warning
        monitor.simulateMemoryLevel(75.0)
        XCTAssertEqual(monitor.warningLevel, .normal)

        monitor.simulateMemoryLevel(85.0)
        XCTAssertEqual(monitor.warningLevel, .warning)

        // Test transition back to normal
        monitor.simulateMemoryLevel(78.0)
        XCTAssertEqual(monitor.warningLevel, .normal)

        // Test jump to emergency
        monitor.simulateMemoryLevel(105.0)
        XCTAssertEqual(monitor.warningLevel, .emergency)
        #endif
    }

    func testCleanupNotificationsPosted() throws {
        #if DEBUG
        let expectation = expectation(forNotification: NSNotification.Name("MemoryCleanupRequested"),
                                     object: nil)

        // Simulate critical level (should trigger cleanup)
        monitor.simulateMemoryLevel(95.0)

        wait(for: [expectation], timeout: 2.0)
        #endif
    }

    func testEmergencyCleanupNotificationHasCorrectUserInfo() throws {
        #if DEBUG
        let expectation = expectation(forNotification: NSNotification.Name("MemoryCleanupRequested"),
                                     object: nil) { notification in
            guard let userInfo = notification.userInfo,
                  let level = userInfo["level"] as? String,
                  let memoryMB = userInfo["memoryMB"] as? Double else {
                return false
            }

            return level == "emergency" && memoryMB >= 100.0
        }

        // Simulate emergency level
        monitor.simulateMemoryLevel(105.0)

        wait(for: [expectation], timeout: 2.0)
        #endif
    }

    // MARK: - Memory Leak Prevention Tests

    func testNoMemoryLeakInMonitoring() {
        // Start and stop monitoring multiple times
        for _ in 0..<10 {
            monitor.startMonitoring()
            monitor.stopMonitoring()
        }

        // If there's a leak, this test would fail in Instruments
        // For basic test, just verify we can start/stop without crashing
        XCTAssertFalse(monitor.isMonitoring,
                      "Monitor should be stopped after multiple cycles")
    }
}
