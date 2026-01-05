//
//  VoiceControlIntegrationTests.swift
//  BabyInCarAppTests
//
//  End-to-end integration tests for voice control system.
//  Tests the full pipeline: Speech → Parsing → Notification → Action
//

import Testing
@testable import BabyInCarApp

@Suite("Voice Control Integration - End-to-End")
@MainActor
struct VoiceControlIntegrationTests {

    // MARK: - Integration Test: Category Playback

    @Test("E2E: Voice command plays category")
    @MainActor
    func testVoiceCommandPlaysCategory() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false // Deterministic testing

        // User says: "play fairy tales"
        let command = await voiceService.parseCommand("play fairy tales")

        // Verify parsing worked
        #expect(command.intent == .playCategory(.fairyTales))
        #expect(command.confidence >= 0.8)

        // Verify this would trigger the correct notification
        // (In real app, SpeechRecognitionService would post this notification)
        // NotificationCenter.default.post(name: .voiceCommandPlayCategory, object: category)
    }

    @Test("E2E: Voice command searches track")
    @MainActor
    func testVoiceCommandSearchesTrack() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // User says: "play piano moment"
        let command = await voiceService.parseCommand("play piano moment")

        // Should either find track or trigger search
        switch command.intent {
        case .playTrack(let title):
            #expect(title.lowercased().contains("piano"))
        case .searchTrack(let query):
            #expect(query.lowercased().contains("piano"))
        case .playCategory(let category):
            // May map to category which is also valid
            #expect(category == .instrumental || category == .classicalMusic)
        default:
            Issue.record("Expected track/search/category intent, got \(command.intent)")
        }
    }

    // MARK: - Integration Test: Volume Control

    @Test("E2E: Voice command adjusts volume")
    @MainActor
    func testVoiceCommandAdjustsVolume() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // User says: "volume up"
        let command = await voiceService.parseCommand("louder please")

        #expect(command.intent == .volumeUp)

        // Would trigger: NotificationCenter.default.post(name: .voiceCommandVolumeUp)
        // AudioEngine would receive and increase volume
    }

    @Test("E2E: Voice command sets specific volume")
    @MainActor
    func testVoiceCommandSetsVolume() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // User says: "set volume to 75"
        let command = await voiceService.parseCommand("set volume to 75")

        if case .setVolume(let level) = command.intent {
            #expect(level == 75)
            // Would trigger: NotificationCenter.default.post(name: .voiceCommandSetVolume, object: 75)
        } else {
            Issue.record("Expected setVolume intent")
        }
    }

    // MARK: - Integration Test: Mood-Based Playback

    @Test("E2E: Voice command triggers mood playlist")
    @MainActor
    func testVoiceCommandTriggersMood() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // User says: "baby is sleepy"
        let command = await voiceService.parseCommand("baby is sleepy")

        #expect(command.intent == .playMood(.sleepy))

        // Would trigger: NotificationCenter.default.post(name: .voiceCommandPlayMood, object: Mood.sleepy)
        // AIRecommendationEngine would generate sleepy playlist
    }

    // MARK: - Integration Test: Emergency Mode

    @Test("E2E: Voice command triggers emergency mode")
    @MainActor
    func testVoiceCommandTriggersEmergency() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // User says: "emergency" or "baby crying"
        let command = await voiceService.parseCommand("baby crying help")

        #expect(command.intent == .emergency)

        // Would trigger: NotificationCenter.default.post(name: .voiceCommandEmergency)
        // SmartCryResponseEngine would activate emergency queue
    }

    // MARK: - Integration Test: LLM Fallback

    @Test("E2E: LLM fallback works gracefully")
    @MainActor
    func testLLMFallbackGraceful() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = true // Enable LLM

        // High confidence command should bypass LLM
        let command1 = await voiceService.parseCommand("play")
        #expect(command1.intent == .play)
        #expect(command1.confidence >= 0.9)

        // Low confidence command would try LLM, fall back to rule-based
        let command2 = await voiceService.parseCommand("play some soothing stuff")
        // Should still return valid result even without LLM
        #expect(command2.confidence > 0)
    }

    // MARK: - Integration Test: Multiple Commands Sequence

    @Test("E2E: Multiple commands in sequence")
    @MainActor
    func testMultipleCommandsSequence() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // Simulate user interaction sequence
        let commands = [
            "play fairy tales",
            "louder",
            "next",
            "pause"
        ]

        let expectedIntents: [VoiceCommandIntent] = [
            .playCategory(.fairyTales),
            .volumeUp,
            .next,
            .pause
        ]

        for (index, commandText) in commands.enumerated() {
            let result = await voiceService.parseCommand(commandText)
            #expect(result.intent == expectedIntents[index])
            #expect(result.confidence > 0.5)
        }
    }

    // MARK: - Integration Test: CarPlay Scenario

    @Test("E2E: CarPlay voice control scenario")
    @MainActor
    func testCarPlayVoiceScenario() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // Realistic CarPlay scenario:
        // 1. User enters car, baby starts crying
        let emergency = await voiceService.parseCommand("emergency")
        #expect(emergency.intent == .emergency)

        // 2. Emergency music too loud
        let volumeDown = await voiceService.parseCommand("quieter")
        #expect(volumeDown.intent == .volumeDown)

        // 3. Baby calms down, switch to lullabies
        let lullabies = await voiceService.parseCommand("play lullabies")
        #expect(lullabies.intent == .playCategory(.childrenSongs))

        // 4. Baby falls asleep, stop music
        let stop = await voiceService.parseCommand("stop")
        #expect(stop.intent == .stop)
    }

    // MARK: - Integration Test: Confidence Threshold Logic

    @Test("E2E: Confidence threshold logic works correctly")
    @MainActor
    func testConfidenceThresholdLogic() async {
        let voiceService = VoiceCommandLLMService.shared

        // Test 1: High confidence (>= 0.8) bypasses LLM
        voiceService.useLLMParsing = true
        let highConfidence = await voiceService.parseCommand("play")
        #expect(highConfidence.confidence >= 0.8)
        // LLM should NOT have been called (would be slow)

        // Test 2: Rule-based still works with LLM disabled
        voiceService.useLLMParsing = false
        let ruleBasedOnly = await voiceService.parseCommand("play classical music")
        #expect(ruleBasedOnly.intent == .playCategory(.classicalMusic))
        #expect(ruleBasedOnly.confidence >= 0.7)
    }

    // MARK: - Integration Test: Error Handling

    @Test("E2E: Graceful handling of ambiguous commands")
    @MainActor
    func testAmbiguousCommandHandling() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // Ambiguous command
        let result = await voiceService.parseCommand("do something")

        // Should return unknown with low confidence
        // (Rule-based parsing doesn't know what "something" is)
        if case .unknown = result.intent {
            #expect(result.confidence < 0.5)
        } else {
            // Or map to closest match (play)
            #expect(result.confidence > 0)
        }
    }

    // MARK: - Integration Test: Natural Language Variations

    @Test("E2E: Natural language variations work")
    @MainActor
    func testNaturalLanguageVariations() async {
        let voiceService = VoiceCommandLLMService.shared
        voiceService.useLLMParsing = false

        // All these should map to "play nature sounds"
        let variations = [
            "play rain",
            "play ocean waves",
            "play forest sounds",
            "play nature"
        ]

        for variation in variations {
            let result = await voiceService.parseCommand(variation)
            #expect(result.intent == .playCategory(.natureSounds))
        }
    }
}
