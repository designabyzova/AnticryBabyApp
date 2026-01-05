//
//  EmergencyActivationTests.swift
//  BabyInCarAppTests
//
//  Unit tests for emergency activation with AI monitoring (Increment 0026)
//  Verifies that emergency button automatically enables cry detection monitoring
//

import XCTest
import Testing
@testable import BabyInCarApp

@Suite("Emergency Activation with AI Monitoring")
@MainActor
struct EmergencyActivationTests {

    @Test("Emergency activate() enables AI monitoring automatically")
    func activateEnablesAIMonitoring() async {
        // Given: Emergency service with AI monitoring disabled
        let emergencyService = EmergencyCryStopService.shared

        // Ensure we start with monitoring disabled
        if emergencyService.isAIMonitoringEnabled {
            emergencyService.disableAIMonitoring()
        }

        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        )

        // When: activate() is called
        emergencyService.activate(for: baby)

        // Wait for async enableAIMonitoring() to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: AI monitoring should be enabled
        #expect(emergencyService.isAIMonitoringEnabled, "AI monitoring should be automatically enabled after emergency activation")
        #expect(emergencyService.isEmergencyModeActive, "Emergency mode should be active")

        // Cleanup
        emergencyService.deactivate()
        emergencyService.disableAIMonitoring()
    }

    @Test("Emergency activate() does not duplicate monitoring if already enabled")
    func activateDoesNotDuplicateMonitoring() async {
        // Given: AI monitoring is already enabled
        let emergencyService = EmergencyCryStopService.shared
        let cryDetection = CryDetectionService.shared

        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -8, to: Date())!
        )

        // Enable AI monitoring first
        try? await emergencyService.enableAIMonitoring(for: baby)
        #expect(emergencyService.isAIMonitoringEnabled, "AI monitoring should be enabled")

        let wasMonitoring = cryDetection.isMonitoring

        // When: activate() is called while monitoring already active
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: Monitoring state should remain true, no errors
        #expect(emergencyService.isAIMonitoringEnabled, "AI monitoring should still be enabled")
        #expect(cryDetection.isMonitoring == wasMonitoring, "Cry detection service should not be re-initialized")
        #expect(emergencyService.isEmergencyModeActive, "Emergency mode should be active")

        // Cleanup
        emergencyService.deactivate()
        emergencyService.disableAIMonitoring()
    }

    @Test("Emergency and AI monitoring work together")
    func emergencyAndAIMonitoringWorkTogether() async {
        // Given: App is idle
        let emergencyService = EmergencyCryStopService.shared
        let cryDetection = CryDetectionService.shared
        let smartEngine = SmartCryResponseEngine.shared

        // Ensure clean state
        if emergencyService.isAIMonitoringEnabled {
            emergencyService.disableAIMonitoring()
        }

        let baby = Baby(
            id: UUID(),
            name: "Test Baby",
            birthDate: Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        )

        // When: Emergency button is tapped
        emergencyService.activate(for: baby)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: Both emergency response AND monitoring should be active
        #expect(emergencyService.isEmergencyModeActive, "Emergency mode should be active")
        #expect(emergencyService.isAIMonitoringEnabled, "AI monitoring should be enabled")
        #expect(smartEngine.isActive, "Smart cry response engine should be active")
        #expect(cryDetection.isMonitoring, "Cry detection service should be monitoring")

        // Cleanup
        emergencyService.deactivate()
        emergencyService.disableAIMonitoring()
    }
}
