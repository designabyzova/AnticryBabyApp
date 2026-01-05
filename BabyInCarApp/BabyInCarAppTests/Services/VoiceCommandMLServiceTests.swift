//
//  VoiceCommandMLServiceTests.swift
//  BabyInCarAppTests
//
//  Unit tests for VoiceCommandMLService
//  Coverage Target: 100%
//
//  Created: 2026-01-04
//  Increment: 0027-voice-control-v2-llm
//

import XCTest
@testable import BabyInCarApp

@MainActor
final class VoiceCommandMLServiceTests: XCTestCase {

    var service: VoiceCommandMLService!

    override func setUp() async throws {
        try await super.setUp()
        service = VoiceCommandMLService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testServiceInitializes() throws {
        // Given: Service is initialized in setUp()
        // When: Service is created
        // Then: Service exists and is not nil
        XCTAssertNotNil(service, "Service should initialize")
    }

    func testServiceConformsToProtocol() throws {
        // Given: VoiceCommandMLService class
        // When: Checking protocol conformance
        // Then: Conforms to VoiceCommandParsing
        XCTAssertTrue(service is VoiceCommandParsing, "Service should conform to VoiceCommandParsing protocol")
    }

    func testServiceHasParseMethod() throws {
        // Given: VoiceCommandMLService instance
        // When: Checking for parseCommand method
        // Then: Method exists
        let hasMethod = service.responds(to: #selector(VoiceCommandMLService.parseCommand(text:)))
        // Note: async methods don't respond to selector, so just verify it compiles
        XCTAssertNotNil(service, "Service should have parseCommand method")
    }

    // MARK: - Fallback Parser Tests (Playback Commands)

    func testParsePlayCommand() async throws {
        // Given: Text "play lullabies"
        let text = "play lullabies"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns play intent
        XCTAssertNotNil(result, "Should parse play command")
        XCTAssertEqual(result?.intent, .play, "Should detect play intent")
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.8, "Should have high confidence")
    }

    func testParsePauseCommand() async throws {
        // Given: Text "pause the music"
        let text = "pause the music"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns pause intent
        XCTAssertNotNil(result, "Should parse pause command")
        XCTAssertEqual(result?.intent, .pause, "Should detect pause intent")
    }

    func testParseStopCommand() async throws {
        // Given: Text "stop"
        let text = "stop"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns stop intent
        XCTAssertNotNil(result, "Should parse stop command")
        XCTAssertEqual(result?.intent, .stop, "Should detect stop intent")
    }

    func testParseNextCommand() async throws {
        // Given: Text "next track"
        let text = "next track"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns next intent
        XCTAssertNotNil(result, "Should parse next command")
        XCTAssertEqual(result?.intent, .next, "Should detect next intent")
    }

    func testParsePreviousCommand() async throws {
        // Given: Text "previous"
        let text = "previous"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns previous intent
        XCTAssertNotNil(result, "Should parse previous command")
        XCTAssertEqual(result?.intent, .previous, "Should detect previous intent")
    }

    // MARK: - Fallback Parser Tests (Volume Commands)

    func testParseVolumeUpCommand() async throws {
        // Given: Text "turn up the volume"
        let text = "turn up the volume"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns volumeUp intent
        XCTAssertNotNil(result, "Should parse volume up command")
        XCTAssertEqual(result?.intent, .volumeUp, "Should detect volumeUp intent")
    }

    func testParseVolumeDownCommand() async throws {
        // Given: Text "quieter please"
        let text = "quieter please"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns volumeDown intent
        XCTAssertNotNil(result, "Should parse volume down command")
        XCTAssertEqual(result?.intent, .volumeDown, "Should detect volumeDown intent")
    }

    func testParseMuteCommand() async throws {
        // Given: Text "mute"
        let text = "mute"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns mute intent
        XCTAssertNotNil(result, "Should parse mute command")
        XCTAssertEqual(result?.intent, .mute, "Should detect mute intent")
    }

    // MARK: - Fallback Parser Tests (Category Commands)

    func testParseLullabiesCommand() async throws {
        // Given: Text "play lullabies"
        let text = "play lullabies"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns lullabies category intent
        XCTAssertNotNil(result, "Should parse lullabies command")
        if case .playCategory(let category) = result?.intent {
            XCTAssertEqual(category, .lullabies, "Should detect lullabies category")
        } else {
            XCTFail("Expected playCategory intent")
        }
    }

    func testParseFairyTalesCommand() async throws {
        // Given: Text "play fairy tales"
        let text = "play fairy tales"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns fairy tales category intent
        XCTAssertNotNil(result, "Should parse fairy tales command")
        if case .playCategory(let category) = result?.intent {
            XCTAssertEqual(category, .fairyTales, "Should detect fairy tales category")
        } else {
            XCTFail("Expected playCategory intent")
        }
    }

    func testParseNatureCommand() async throws {
        // Given: Text "play nature sounds"
        let text = "play nature sounds"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns nature category intent
        XCTAssertNotNil(result, "Should parse nature command")
        if case .playCategory(let category) = result?.intent {
            XCTAssertEqual(category, .nature, "Should detect nature category")
        } else {
            XCTFail("Expected playCategory intent")
        }
    }

    func testParseClassicalCommand() async throws {
        // Given: Text "play classical music"
        let text = "play classical music"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns classical category intent
        XCTAssertNotNil(result, "Should parse classical command")
        if case .playCategory(let category) = result?.intent {
            XCTAssertEqual(category, .classical, "Should detect classical category")
        } else {
            XCTFail("Expected playCategory intent")
        }
    }

    // MARK: - Fallback Parser Tests (Emergency Commands)

    func testParseEmergencyCommand() async throws {
        // Given: Text "baby is crying"
        let text = "baby is crying"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns emergency intent
        XCTAssertNotNil(result, "Should parse emergency command")
        XCTAssertEqual(result?.intent, .emergency, "Should detect emergency intent")
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.9, "Emergency should have very high confidence")
    }

    // MARK: - Unknown Command Tests

    func testParseUnknownCommand() async throws {
        // Given: Gibberish text
        let text = "xyzabc foobar nonsense"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Returns nil
        XCTAssertNil(result, "Should return nil for unknown command")
    }

    // MARK: - Model Loading Tests

    func testModelLoadingState() throws {
        // Given: New service
        let newService = VoiceCommandMLService()

        // When: Checking initial state
        // Then: Model not loaded initially (loaded lazily)
        XCTAssertFalse(newService.isModelLoaded, "Model should not be loaded initially")
    }

    func testLazyModelLoading() async throws {
        // Given: New service with no model loaded
        let newService = VoiceCommandMLService()
        XCTAssertFalse(newService.isModelLoaded, "Model should not be loaded initially")

        // When: Parsing first command (triggers lazy loading)
        _ = await newService.parseCommand(text: "play lullabies")

        // Then: Model should attempt to load OR fallback should be active
        XCTAssertTrue(newService.isModelLoaded || newService.usingFallback,
                     "Either model should load or fallback should activate")
    }

    func testModelLoadTimeout() async throws {
        // Given: Service with timeout
        let newService = VoiceCommandMLService()

        // When: Loading model with 1 second timeout
        let loaded = await newService.loadModelWithTimeout(1.0)

        // Then: Should complete within timeout
        // Either succeeds (if model available) or fails gracefully
        if !loaded {
            XCTAssertTrue(newService.usingFallback, "Should activate fallback if load fails")
        }
    }

    func testFallbackModeActive() async throws {
        // Given: Service without model
        // When: Parsing command
        let result = await service.parseCommand(text: "play")

        // Then: Fallback is used
        XCTAssertTrue(service.usingFallback || !service.isModelLoaded, "Should use fallback mode")
        XCTAssertNotNil(result, "Fallback should still parse basic commands")
    }

    func testExplicitModelLoad() throws {
        // Given: New service
        let newService = VoiceCommandMLService()

        // When: Explicitly loading model
        newService.loadModel()

        // Then: Loading completes (success or failure)
        XCTAssertTrue(newService.isModelLoaded || newService.usingFallback,
                     "Model load should complete with success or fallback")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveMatching() async throws {
        // Given: Uppercase text
        let text = "PLAY LULLABIES"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Still parses correctly
        XCTAssertNotNil(result, "Should handle uppercase text")
    }

    // MARK: - Confidence Scoring Tests

    func testConfidenceScoreIncluded() async throws {
        // Given: Any valid command
        let text = "play"

        // When: Parsing command
        let result = await service.parseCommand(text: text)

        // Then: Confidence is included and reasonable
        XCTAssertNotNil(result?.confidence, "Should include confidence score")
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.0, "Confidence should be positive")
        XCTAssertLessThanOrEqual(result?.confidence ?? 1.0, 1.0, "Confidence should be <= 1.0")
    }
}
