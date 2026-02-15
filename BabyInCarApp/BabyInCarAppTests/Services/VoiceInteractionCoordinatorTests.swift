//
//  VoiceInteractionCoordinatorTests.swift
//  BabyInCarAppTests
//
//  Integration tests for FS-030: VoiceInteractionCoordinator
//  Tests coordinator singleton, notification names, and event handling setup.
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - VoiceInteractionCoordinator Tests

@Suite("VoiceInteractionCoordinator")
@MainActor
struct VoiceInteractionCoordinatorTests {

    @Test("Coordinator singleton is accessible and does not crash")
    func testCoordinatorSingleton() {
        let coordinator = VoiceInteractionCoordinator.shared
        // Accessing the singleton should not crash; verifies initialization path
        #expect(coordinator !== nil as AnyObject?)
    }

    @Test("Coordinator starts not handling an interaction")
    func testInitialState() {
        let coordinator = VoiceInteractionCoordinator.shared
        #expect(coordinator.isHandlingInteraction == false)
    }

    @Test("Coordinator is an ObservableObject")
    func testIsObservableObject() {
        // Verify the coordinator conforms to ObservableObject by accessing objectWillChange
        let coordinator = VoiceInteractionCoordinator.shared
        let _ = coordinator.objectWillChange
        // If this compiles and runs, the coordinator conforms to ObservableObject
    }
}

// MARK: - Voice Notification Names Tests

@Suite("Voice Notification Names")
struct VoiceNotificationNamesTests {

    @Test("showCryTypeChangePrompt notification name is defined")
    func testCryTypeChangeNotificationExists() {
        let name = Notification.Name.showCryTypeChangePrompt
        #expect(!name.rawValue.isEmpty)
    }

    @Test("showCryStoppedPrompt notification name is defined")
    func testCryStoppedNotificationExists() {
        let name = Notification.Name.showCryStoppedPrompt
        #expect(!name.rawValue.isEmpty)
    }

    @Test("Voice notification names are distinct from each other")
    func testNotificationNamesDistinct() {
        let cryTypeChange = Notification.Name.showCryTypeChangePrompt
        let cryStop = Notification.Name.showCryStoppedPrompt
        #expect(cryTypeChange != cryStop)
    }

    @Test("showCryTypeChangePrompt raw value matches expected string")
    func testCryTypeChangeRawValue() {
        let name = Notification.Name.showCryTypeChangePrompt
        #expect(name.rawValue == "showCryTypeChangePrompt")
    }

    @Test("showCryStoppedPrompt raw value matches expected string")
    func testCryStoppedRawValue() {
        let name = Notification.Name.showCryStoppedPrompt
        #expect(name.rawValue == "showCryStoppedPrompt")
    }
}

// MARK: - Voice Integration Flow Tests

@Suite("Voice Integration Flow")
@MainActor
struct VoiceIntegrationFlowTests {

    @Test("VoiceInteractionService singleton is accessible from coordinator context")
    func testVoiceServiceAccessible() {
        let service = VoiceInteractionService.shared
        // Verify the service initializes without crash
        #expect(service.isActive == false)
        #expect(service.isSpeaking == false)
        #expect(service.isListening == false)
    }

    @Test("VoiceInteractionService lastError is nil initially")
    func testInitialErrorState() {
        let service = VoiceInteractionService.shared
        #expect(service.lastError == nil)
    }

    @Test("CryTypeChangePrompt notification can be posted and observed")
    func testCryTypeChangeNotificationPostAndObserve() async {
        // Use async stream to observe notification without XCTestExpectation
        let notifications = NotificationCenter.default.notifications(
            named: .showCryTypeChangePrompt
        )

        // Post the notification with expected userInfo
        NotificationCenter.default.post(
            name: .showCryTypeChangePrompt,
            object: nil,
            userInfo: [
                "from": CryType.hunger,
                "to": CryType.tired,
                "confidence": 0.85
            ]
        )

        // Verify the notification was received
        var iterator = notifications.makeAsyncIterator()
        let notification = await iterator.next()
        #expect(notification != nil)
        #expect(notification?.userInfo?["from"] as? CryType == .hunger)
        #expect(notification?.userInfo?["to"] as? CryType == .tired)
        #expect(notification?.userInfo?["confidence"] as? Double == 0.85)
    }

    @Test("CryStoppedPrompt notification can be posted and observed")
    func testCryStoppedNotificationPostAndObserve() async {
        let notifications = NotificationCenter.default.notifications(
            named: .showCryStoppedPrompt
        )

        NotificationCenter.default.post(
            name: .showCryStoppedPrompt,
            object: nil
        )

        var iterator = notifications.makeAsyncIterator()
        let notification = await iterator.next()
        #expect(notification != nil)
    }
}
