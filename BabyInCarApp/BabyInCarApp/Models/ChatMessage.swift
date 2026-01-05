//
//  ChatMessage.swift
//  BabyInCarApp
//
//  Model for AI chatbot conversation messages.
//

import Foundation

// MARK: - Chat Sender

enum ChatSender: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - Chat Action

enum ChatAction: Codable {
    case playTrack(trackId: String, trackTitle: String)
    case playCategory(category: String)
    case showInsights
    case openLibrary
    case enableSmartMode
    case showResearch(topic: ResearchTopic)
    case adjustVolume(level: Float)
    case none

    enum CodingKeys: String, CodingKey {
        case type
        case trackId
        case trackTitle
        case category
        case topic
        case level
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "playTrack":
            let trackId = try container.decode(String.self, forKey: .trackId)
            let trackTitle = try container.decode(String.self, forKey: .trackTitle)
            self = .playTrack(trackId: trackId, trackTitle: trackTitle)
        case "playCategory":
            let category = try container.decode(String.self, forKey: .category)
            self = .playCategory(category: category)
        case "showInsights":
            self = .showInsights
        case "openLibrary":
            self = .openLibrary
        case "enableSmartMode":
            self = .enableSmartMode
        case "showResearch":
            let topic = try container.decode(ResearchTopic.self, forKey: .topic)
            self = .showResearch(topic: topic)
        case "adjustVolume":
            let level = try container.decode(Float.self, forKey: .level)
            self = .adjustVolume(level: level)
        default:
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .playTrack(let trackId, let trackTitle):
            try container.encode("playTrack", forKey: .type)
            try container.encode(trackId, forKey: .trackId)
            try container.encode(trackTitle, forKey: .trackTitle)
        case .playCategory(let category):
            try container.encode("playCategory", forKey: .type)
            try container.encode(category, forKey: .category)
        case .showInsights:
            try container.encode("showInsights", forKey: .type)
        case .openLibrary:
            try container.encode("openLibrary", forKey: .type)
        case .enableSmartMode:
            try container.encode("enableSmartMode", forKey: .type)
        case .showResearch(let topic):
            try container.encode("showResearch", forKey: .type)
            try container.encode(topic, forKey: .topic)
        case .adjustVolume(let level):
            try container.encode("adjustVolume", forKey: .type)
            try container.encode(level, forKey: .level)
        case .none:
            try container.encode("none", forKey: .type)
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let sender: ChatSender
    let text: String
    let action: ChatAction?
    let citations: [ResearchCitation]?
    let trackRecommendations: [TrackRecommendation]?
    let isTyping: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sender: ChatSender,
        text: String,
        action: ChatAction? = nil,
        citations: [ResearchCitation]? = nil,
        trackRecommendations: [TrackRecommendation]? = nil,
        isTyping: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sender = sender
        self.text = text
        self.action = action
        self.citations = citations
        self.trackRecommendations = trackRecommendations
        self.isTyping = isTyping
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Convenience Constructors

    static func userMessage(_ text: String) -> ChatMessage {
        ChatMessage(sender: .user, text: text)
    }

    static func assistantMessage(_ text: String, action: ChatAction? = nil) -> ChatMessage {
        ChatMessage(sender: .assistant, text: text, action: action)
    }

    static func typingIndicator() -> ChatMessage {
        ChatMessage(sender: .assistant, text: "", isTyping: true)
    }

    static func withRecommendations(
        _ text: String,
        recommendations: [TrackRecommendation],
        citations: [ResearchCitation]? = nil
    ) -> ChatMessage {
        ChatMessage(
            sender: .assistant,
            text: text,
            citations: citations,
            trackRecommendations: recommendations
        )
    }

    // MARK: - Formatting

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Track Recommendation

struct TrackRecommendation: Codable, Identifiable {
    let id: UUID
    let trackId: String
    let title: String
    let category: String
    let reason: String
    let confidenceScore: Double
    let historicalSuccessRate: Double?
    let researchBacking: String?

    init(
        trackId: String,
        title: String,
        category: String,
        reason: String,
        confidenceScore: Double,
        historicalSuccessRate: Double? = nil,
        researchBacking: String? = nil
    ) {
        self.id = UUID()
        self.trackId = trackId
        self.title = title
        self.category = category
        self.reason = reason
        self.confidenceScore = confidenceScore
        self.historicalSuccessRate = historicalSuccessRate
        self.researchBacking = researchBacking
    }
}

// MARK: - Chat History

class ChatHistory: ObservableObject {
    static let shared = ChatHistory()

    @Published var messages: [ChatMessage] = []
    private let maxMessages = 100
    private let storageKey = "ChatHistory"

    private init() {
        loadHistory()
    }

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        saveHistory()
    }

    func removeTypingIndicators() {
        messages.removeAll { $0.isTyping }
    }

    func clearHistory() {
        messages.removeAll()
        saveHistory()
    }

    func getRecentContext(limit: Int = 10) -> [ChatMessage] {
        Array(messages.suffix(limit))
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let history = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            // Add welcome message if no history
            messages = [
                ChatMessage(
                    sender: .assistant,
                    text: "Hi! I'm your baby soothing assistant. Ask me things like:\n\n• \"What sounds work best for my baby?\"\n• \"Play something for a tired baby\"\n• \"Why does white noise help?\"\n\nI'll learn your baby's preferences over time!"
                )
            ]
            return
        }
        messages = history
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Quick Action

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let query: String

    static let defaultActions: [QuickAction] = [
        QuickAction(title: "What works best?", icon: "star.fill", query: "What sounds work best for my baby?"),
        QuickAction(title: "Sleepy baby", icon: "moon.zzz.fill", query: "My baby seems tired, what should I play?"),
        QuickAction(title: "Why this sound?", icon: "questionmark.circle.fill", query: "Why is the current sound playing?"),
        QuickAction(title: "Car mode tips", icon: "car.fill", query: "How does smart car mode work?")
    ]

    static func contextualActions(cryType: CryType?, isInCar: Bool) -> [QuickAction] {
        var actions = defaultActions

        if let cryType = cryType, cryType != .unknown {
            actions.insert(
                QuickAction(
                    title: "Help with \(cryType.rawValue.lowercased())",
                    icon: cryType.iconName,
                    query: "My baby seems \(cryType.rawValue.lowercased()), what should I play?"
                ),
                at: 0
            )
        }

        if isInCar {
            actions.insert(
                QuickAction(
                    title: "Use car sounds",
                    icon: "car.fill",
                    query: "Can the car help soothe my baby?"
                ),
                at: 1
            )
        }

        return Array(actions.prefix(4))
    }
}
