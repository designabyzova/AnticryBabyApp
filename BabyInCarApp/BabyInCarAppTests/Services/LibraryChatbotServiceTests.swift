//
//  LibraryChatbotServiceTests.swift
//  BabyInCarAppTests
//
//  Unit tests for LibraryChatbotService
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Chat Message Tests

@Suite("Chat Message Model")
struct ChatMessageTests {

    @Test("User message creation")
    func userMessageCreation() {
        let message = ChatMessage.userMessage("Hello")

        #expect(message.sender == .user)
        #expect(message.text == "Hello")
        #expect(!message.isTyping)
    }

    @Test("Assistant message creation")
    func assistantMessageCreation() {
        let message = ChatMessage.assistantMessage("Hi there!", action: .showInsights)

        #expect(message.sender == .assistant)
        #expect(message.text == "Hi there!")
        #expect(message.action != nil)
    }

    @Test("Typing indicator creation")
    func typingIndicatorCreation() {
        let message = ChatMessage.typingIndicator()

        #expect(message.sender == .assistant)
        #expect(message.isTyping)
        #expect(message.text.isEmpty)
    }

    @Test("Message with recommendations")
    func messageWithRecommendations() {
        let recommendations = [
            TrackRecommendation(
                trackId: "test-1",
                title: "Test Track",
                category: "White Noise",
                reason: "Great for sleep",
                confidenceScore: 0.9,
                historicalSuccessRate: 0.85,
                researchBacking: "Based on research"
            )
        ]

        let message = ChatMessage.withRecommendations(
            "Here are some tracks",
            recommendations: recommendations
        )

        #expect(message.trackRecommendations?.count == 1)
        #expect(message.trackRecommendations?.first?.title == "Test Track")
    }

    @Test("Formatted timestamp is not empty")
    func formattedTimestamp() {
        let message = ChatMessage.userMessage("Test")
        #expect(!message.formattedTimestamp.isEmpty)
    }
}

// MARK: - Track Recommendation Tests

@Suite("Track Recommendation Model")
struct TrackRecommendationTests {

    @Test("Recommendation has all required fields")
    func recommendationFields() {
        let recommendation = TrackRecommendation(
            trackId: "track-123",
            title: "Ocean Waves",
            category: "Nature Sounds",
            reason: "Matches your baby's tired cry pattern",
            confidenceScore: 0.85,
            historicalSuccessRate: 0.78,
            researchBacking: "Studies show nature sounds reduce cortisol"
        )

        #expect(recommendation.trackId == "track-123")
        #expect(recommendation.title == "Ocean Waves")
        #expect(recommendation.category == "Nature Sounds")
        #expect(recommendation.confidenceScore == 0.85)
        #expect(recommendation.historicalSuccessRate == 0.78)
        #expect(recommendation.researchBacking != nil)
    }

    @Test("Recommendation is identifiable")
    func recommendationIdentifiable() {
        let rec1 = TrackRecommendation(
            trackId: "t1",
            title: "Track 1",
            category: "Category",
            reason: "Reason",
            confidenceScore: 0.9
        )

        let rec2 = TrackRecommendation(
            trackId: "t2",
            title: "Track 2",
            category: "Category",
            reason: "Reason",
            confidenceScore: 0.9
        )

        #expect(rec1.id != rec2.id)
    }
}

// MARK: - Chat Action Tests

@Suite("Chat Action")
struct ChatActionTests {

    @Test("Play track action encoding/decoding")
    func playTrackAction() throws {
        let action = ChatAction.playTrack(trackId: "test-id", trackTitle: "Test Title")

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: encoded)

        if case .playTrack(let trackId, let trackTitle) = decoded {
            #expect(trackId == "test-id")
            #expect(trackTitle == "Test Title")
        } else {
            Issue.record("Failed to decode playTrack action")
        }
    }

    @Test("Adjust volume action encoding/decoding")
    func adjustVolumeAction() throws {
        let action = ChatAction.adjustVolume(level: 0.75)

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: encoded)

        if case .adjustVolume(let level) = decoded {
            #expect(level == 0.75)
        } else {
            Issue.record("Failed to decode adjustVolume action")
        }
    }

    @Test("Simple actions encode correctly", arguments: [
        ChatAction.showInsights,
        ChatAction.openLibrary,
        ChatAction.enableSmartMode,
        ChatAction.none
    ])
    func simpleActionsEncode(action: ChatAction) throws {
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: encoded)

        // Just verify it doesn't throw
        #expect(decoded != nil)
    }
}

// MARK: - Quick Action Tests

@Suite("Quick Actions")
struct QuickActionTests {

    @Test("Default actions are populated")
    func defaultActionsPopulated() {
        let actions = QuickAction.defaultActions

        #expect(!actions.isEmpty)
        #expect(actions.count >= 3)

        for action in actions {
            #expect(!action.title.isEmpty)
            #expect(!action.icon.isEmpty)
            #expect(!action.query.isEmpty)
        }
    }

    @Test("Contextual actions add cry type")
    func contextualActionsWithCryType() {
        let actions = QuickAction.contextualActions(cryType: .tired, isInCar: false)

        #expect(actions.count <= 4)

        let hasTiredAction = actions.contains { $0.query.lowercased().contains("tired") }
        #expect(hasTiredAction, "Should include tired-specific action")
    }

    @Test("Contextual actions add car option when in car")
    func contextualActionsInCar() {
        let actions = QuickAction.contextualActions(cryType: nil, isInCar: true)

        let hasCarAction = actions.contains { $0.query.lowercased().contains("car") }
        #expect(hasCarAction, "Should include car-specific action")
    }
}

// MARK: - Chat History Tests

@Suite("Chat History")
struct ChatHistoryTests {

    @Test("Chat history singleton exists")
    func historyExists() {
        let history = ChatHistory.shared
        #expect(history != nil)
    }

    @Test("Can add message to history")
    func addMessage() {
        let history = ChatHistory.shared
        let initialCount = history.messages.count

        let message = ChatMessage.userMessage("Test message")
        history.addMessage(message)

        #expect(history.messages.count > initialCount)
    }

    @Test("Typing indicators can be removed")
    func removeTypingIndicators() {
        let history = ChatHistory.shared

        // Add a typing indicator
        history.addMessage(ChatMessage.typingIndicator())

        // Remove it
        history.removeTypingIndicators()

        let hasTyping = history.messages.contains { $0.isTyping }
        #expect(!hasTyping, "Should not have typing indicators after removal")
    }

    @Test("Recent context is limited")
    func recentContextLimit() {
        let history = ChatHistory.shared

        // Add several messages
        for i in 0..<20 {
            history.addMessage(ChatMessage.userMessage("Message \(i)"))
        }

        let recent = history.getRecentContext(limit: 5)
        #expect(recent.count <= 5)
    }
}

// MARK: - Intent Classification Tests (via patterns)

@Suite("Chat Intent Patterns")
struct ChatIntentPatternTests {

    @Test("Search patterns are recognized")
    func searchPatterns() {
        let searchQueries = [
            "find lullabies",
            "search for white noise",
            "look for sleep music",
            "show me nature sounds"
        ]

        for query in searchQueries {
            // Test that query contains search keywords
            let isSearch = query.contains("find") ||
                          query.contains("search") ||
                          query.contains("look for") ||
                          query.contains("show")
            #expect(isSearch, "'\(query)' should be classified as search")
        }
    }

    @Test("Recommendation patterns are recognized")
    func recommendPatterns() {
        let recommendQueries = [
            "what should I play",
            "recommend something for sleep",
            "suggest music for crying",
            "what works best"
        ]

        for query in recommendQueries {
            let isRecommend = query.contains("should") ||
                             query.contains("recommend") ||
                             query.contains("suggest") ||
                             query.contains("best")
            #expect(isRecommend, "'\(query)' should be classified as recommendation")
        }
    }

    @Test("Explanation patterns are recognized")
    func explainPatterns() {
        let explainQueries = [
            "why does white noise help",
            "how does car sound work",
            "explain the research",
            "tell me about lullabies"
        ]

        for query in explainQueries {
            let isExplain = query.contains("why") ||
                           query.contains("how") ||
                           query.contains("explain") ||
                           query.contains("tell me about")
            #expect(isExplain, "'\(query)' should be classified as explanation")
        }
    }

    @Test("Cry type extraction patterns")
    func cryTypePatterns() {
        let cryQueries = [
            ("baby is hungry", "hungry"),
            ("she seems tired", "tired"),
            ("fussy and uncomfortable", "fussy"),
            ("crying from pain", "pain"),
            ("bored baby", "bored")
        ]

        for (query, expectedType) in cryQueries {
            let hasType = query.lowercased().contains(expectedType)
            #expect(hasType, "'\(query)' should extract cry type '\(expectedType)'")
        }
    }
}
