//
//  LibraryChatbotService.swift
//  BabyInCarApp
//
//  AI-powered natural language interface for library search and discovery.
//  Integrates with BabyMIM for personalized recommendations and provides
//  research-backed explanations for sound choices.
//

import Foundation
import Combine

// MARK: - Chat Intent

enum ChatIntent: String {
    case search = "search"                  // User wants to find specific content
    case recommend = "recommend"            // User wants personalized recommendations
    case explain = "explain"                // User wants to understand why something works
    case history = "history"                // User wants to know what worked before
    case play = "play"                      // User wants to play something now
    case carMode = "carMode"                // User asking about car/environment features
    case help = "help"                      // User needs guidance
    case unknown = "unknown"
}

// MARK: - Entity Extraction

struct ChatEntities {
    var cryType: CryType?
    var category: AudioCategory?
    var soundType: GeneratorType?
    var mood: String?
    var timePeriod: String?           // "today", "this week", "last time"
    var language: Language?
    var action: String?               // "play", "find", "show"
}

// MARK: - Library Chatbot Service

@MainActor
class LibraryChatbotService: ObservableObject {
    static let shared = LibraryChatbotService()

    // MARK: - Dependencies

    private let libraryService = ContentLibraryService.shared
    private let researchKnowledge = ResearchKnowledgeBase.shared
    private let chatHistory = ChatHistory.shared

    // BabyMIM dependencies (not available - file not in project)
    // private var babyMoodIntelligence: BabyMoodIntelligence? {
    //     BabyMoodIntelligence.shared
    // }

    // MARK: - State

    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Main Query Processing

    func processQuery(_ query: String) async -> ChatMessage {
        isProcessing = true
        defer { isProcessing = false }

        // Add user message to history
        let userMessage = ChatMessage.userMessage(query)
        chatHistory.addMessage(userMessage)

        // Classify intent and extract entities
        let intent = classifyIntent(query)
        let entities = extractEntities(from: query)

        // Generate response based on intent
        let response: ChatMessage

        switch intent {
        case .search:
            response = await handleSearchIntent(query: query, entities: entities)
        case .recommend:
            response = await handleRecommendIntent(entities: entities)
        case .explain:
            response = await handleExplainIntent(query: query, entities: entities)
        case .history:
            response = await handleHistoryIntent(entities: entities)
        case .play:
            response = await handlePlayIntent(query: query, entities: entities)
        case .carMode:
            response = handleCarModeIntent(query: query)
        case .help:
            response = handleHelpIntent()
        case .unknown:
            response = await handleUnknownIntent(query: query, entities: entities)
        }

        chatHistory.addMessage(response)
        return response
    }

    // MARK: - Intent Classification

    private func classifyIntent(_ query: String) -> ChatIntent {
        let lowercased = query.lowercased()

        // Play intent
        if lowercased.contains("play") || lowercased.contains("start") || lowercased.contains("put on") {
            return .play
        }

        // Search intent
        if lowercased.contains("find") || lowercased.contains("search") || lowercased.contains("look for") ||
           lowercased.contains("show me") || lowercased.contains("where is") {
            return .search
        }

        // Explain intent
        if lowercased.contains("why") || lowercased.contains("how does") || lowercased.contains("explain") ||
           lowercased.contains("what makes") || lowercased.contains("reason") || lowercased.contains("science") {
            return .explain
        }

        // History intent
        if lowercased.contains("worked") || lowercased.contains("last time") || lowercased.contains("before") ||
           lowercased.contains("history") || lowercased.contains("what helped") || lowercased.contains("best for") {
            return .history
        }

        // Car mode intent
        if lowercased.contains("car") || lowercased.contains("drive") || lowercased.contains("carplay") ||
           lowercased.contains("smart mode") || lowercased.contains("environment") {
            return .carMode
        }

        // Help intent
        if lowercased.contains("help") || lowercased.contains("how to") || lowercased.contains("what can") {
            return .help
        }

        // Recommend intent (if asking about baby state)
        if lowercased.contains("tired") || lowercased.contains("sleepy") || lowercased.contains("hungry") ||
           lowercased.contains("crying") || lowercased.contains("fussy") || lowercased.contains("upset") ||
           lowercased.contains("recommend") || lowercased.contains("suggest") || lowercased.contains("what should") {
            return .recommend
        }

        return .unknown
    }

    // MARK: - Entity Extraction

    private func extractEntities(from query: String) -> ChatEntities {
        var entities = ChatEntities()
        let lowercased = query.lowercased()

        // Extract cry type
        if lowercased.contains("hungry") || lowercased.contains("hunger") {
            entities.cryType = .hunger
            entities.mood = "hungry"
        } else if lowercased.contains("tired") || lowercased.contains("sleepy") || lowercased.contains("sleep") {
            entities.cryType = .tired
            entities.mood = "tired"
        } else if lowercased.contains("pain") || lowercased.contains("hurt") || lowercased.contains("uncomfortable") {
            entities.cryType = .pain
            entities.mood = "in pain"
        } else if lowercased.contains("fussy") || lowercased.contains("upset") || lowercased.contains("crying") {
            entities.cryType = .general
            entities.mood = "fussy"
        } else if lowercased.contains("attention") || lowercased.contains("bored") {
            entities.cryType = .attention
            entities.mood = "wants attention"
        }

        // Extract audio category (NO rain or white noise!)
        if lowercased.contains("ambient") || lowercased.contains("womb") || lowercased.contains("heartbeat") {
            entities.category = .ambient
        } else if lowercased.contains("nature") || lowercased.contains("ocean") {
            entities.category = .natureSounds
        } else if lowercased.contains("classical") || lowercased.contains("music") || lowercased.contains("piano") {
            entities.category = .classicalMusic
        } else if lowercased.contains("lullaby") || lowercased.contains("lullabies") {
            entities.category = .lullabies
        } else if lowercased.contains("song") || lowercased.contains("children") {
            entities.category = .childrenSongs
        } else if lowercased.contains("story") || lowercased.contains("fairy tale") || lowercased.contains("fairytale") {
            entities.category = .fairyTales
        }

        // Extract specific sound types (gentle sounds only!)
        if lowercased.contains("womb") {
            entities.soundType = .womb
        } else if lowercased.contains("heartbeat") {
            entities.soundType = .heartbeat
        } else if lowercased.contains("shush") {
            entities.soundType = .shushing
        } else if lowercased.contains("ocean") {
            entities.soundType = .aquarium
        } else if lowercased.contains("forest") {
            entities.soundType = .bells
        }

        // Extract time period
        if lowercased.contains("today") {
            entities.timePeriod = "today"
        } else if lowercased.contains("this week") || lowercased.contains("week") {
            entities.timePeriod = "week"
        } else if lowercased.contains("last time") || lowercased.contains("before") {
            entities.timePeriod = "recent"
        }

        // Extract language
        if lowercased.contains("russian") || lowercased.contains("русск") {
            entities.language = .russian
        } else if lowercased.contains("english") {
            entities.language = .english
        } else if lowercased.contains("spanish") {
            entities.language = .spanish
        }

        return entities
    }

    // MARK: - Intent Handlers

    private func handleSearchIntent(query: String, entities: ChatEntities) async -> ChatMessage {
        var tracks: [AudioTrack] = []
        var searchDescription = ""

        // Search by category if specified
        if let category = entities.category {
            tracks = libraryService.getTracks(for: category)
            searchDescription = "in \(category.rawValue)"
        }
        // Search by sound type
        else if let soundType = entities.soundType {
            tracks = libraryService.allTracks.filter { $0.generatorType == soundType }
            searchDescription = "for \(soundType.rawValue)"
        }
        // Search by language
        else if let language = entities.language {
            tracks = libraryService.getTracks(for: language)
            searchDescription = "in \(language.rawValue)"
        }
        // General text search
        else {
            tracks = libraryService.searchTracks(query: query)
            searchDescription = "matching '\(query)'"
        }

        if tracks.isEmpty {
            return ChatMessage.assistantMessage(
                "I couldn't find any tracks \(searchDescription). Try searching for a category like 'nature sounds', 'lullabies', or 'classical music'."
            )
        }

        let recommendations = tracks.prefix(5).map { track in
            TrackRecommendation(
                trackId: track.id.uuidString,
                title: track.title,
                category: track.category.rawValue,
                reason: "Found in search results",
                confidenceScore: 0.8,
                historicalSuccessRate: nil
            )
        }

        return ChatMessage.withRecommendations(
            "I found \(tracks.count) tracks \(searchDescription). Here are the top results:",
            recommendations: Array(recommendations)
        )
    }

    private func handleRecommendIntent(entities: ChatEntities) async -> ChatMessage {
        // BabyMIM not available - skip profile-based recommendations
        // let babyProfile = babyMoodIntelligence?.babyProfile

        var recommendations: [TrackRecommendation] = []
        var responseText = ""

        // Get cry-type specific recommendations
        if let cryType = entities.cryType {
            responseText = "For a \(entities.mood ?? cryType.rawValue) baby, I recommend:\n\n"

            // BabyMIM not available - skip profile-based recommendations
            // if let profile = babyProfile { ... }

            // Fill with research-based recommendations if needed
            if recommendations.count < 3 {
                let researchBased = getResearchBasedRecommendations(for: cryType)
                for rec in researchBased where recommendations.count < 5 {
                    if !recommendations.contains(where: { $0.title == rec.title }) {
                        recommendations.append(rec)
                    }
                }
            }
        } else {
            // General recommendations based on calming score
            responseText = "Here are some highly effective soothing sounds:\n\n"
            let topTracks = libraryService.getTopCalmingTracks(limit: 5)
            recommendations = topTracks.map { track in
                TrackRecommendation(
                    trackId: track.id.uuidString,
                    title: track.title,
                    category: track.category.rawValue,
                    reason: "High calming effectiveness (\(Int(track.calmingScore * 100))%)",
                    confidenceScore: track.calmingScore,
                    researchBacking: track.generatorType.flatMap { getResearchReason(for: $0) }
                )
            }
        }

        if recommendations.isEmpty {
            return ChatMessage.assistantMessage(
                "I don't have enough data yet to make personalized recommendations. Try playing some sounds and I'll learn what works best for your baby!"
            )
        }

        return ChatMessage.withRecommendations(responseText, recommendations: recommendations)
    }

    private func handleExplainIntent(query: String, entities: ChatEntities) async -> ChatMessage {
        // Explain specific sound type
        if let soundType = entities.soundType {
            let explanation = researchKnowledge.getParentFriendlyExplanation(
                soundType: soundType,
                cryType: entities.cryType ?? .general,
                babyAge: 6 // babyMoodIntelligence?.babyProfile?.ageInMonths ?? 6
            )

            if let researchExplanation = researchKnowledge.getExplanation(for: soundType) {
                let citations = researchKnowledge.getCitations(for: researchExplanation.topic)
                return ChatMessage(
                    sender: .assistant,
                    text: explanation,
                    citations: citations.isEmpty ? nil : Array(citations.prefix(2))
                )
            }

            return ChatMessage.assistantMessage(explanation)
        }

        // Explain cry types
        if let cryType = entities.cryType {
            let explanation = getCryTypeExplanation(cryType)
            return ChatMessage.assistantMessage(explanation)
        }

        // General explanation about the app
        return ChatMessage.assistantMessage(
            "Our app uses scientifically-proven techniques to soothe babies:\n\n" +
            "• **Womb sounds** recreate intrauterine environment (90% of babies calm in 3 minutes)\n" +
            "• **Nature sounds** like ocean waves sync with relaxed breathing patterns\n" +
            "• **Lullabies** at 60-80 BPM match baby's resting heart rate\n" +
            "• We learn your baby's preferences over time for personalized recommendations\n\n" +
            "Ask me about any specific sound type to learn more!"
        )
    }

    private func handleHistoryIntent(entities: ChatEntities) async -> ChatMessage {
        // BabyMIM not available - always show placeholder message
        // guard let profile = babyMoodIntelligence?.babyProfile else { ... }
        return ChatMessage.assistantMessage(
            "I don't have enough history yet. Keep using the app and I'll learn what works best for your baby!"
        )

        // Original code when BabyMIM is available:
        /*
        guard let profile = babyMoodIntelligence?.babyProfile else {
            return ChatMessage.assistantMessage(
                "I don't have enough history yet. Keep using the app and I'll learn what works best for your baby!"
            )
        }
        var responseText = "Based on history:\n\n"

        // Get overall best sounds
        let overallBest = profile.getOverallBestSounds(limit: 3)
        if !overallBest.isEmpty {
            responseText += "**Top sounds overall:**\n"
            for (i, pref) in overallBest.enumerated() {
                responseText += "\(i + 1). \(pref.sound.displayName) - \(Int(pref.successRate * 100))% success rate\n"
            }
            responseText += "\n"
        }

        // Get best per cry type if specified
        if let cryType = entities.cryType {
            let typeBest = profile.getBestSounds(for: cryType, limit: 3)
            if !typeBest.isEmpty {
                responseText += "**Best for \(cryType.rawValue) cries:**\n"
                for (i, pref) in typeBest.enumerated() {
                    if let sound = pref.generatorType {
                        responseText += "\(i + 1). \(sound.displayName) - \(Int(pref.successRate * 100))% success\n"
                    }
                }
            }
        }

        // Add profile stats
        responseText += "\nTotal soothing sessions: \(profile.totalSessions)"
        responseText += "\nOverall success rate: \(Int(profile.successRate * 100))%"

        return ChatMessage.assistantMessage(responseText)
        */
    }

    private func handlePlayIntent(query: String, entities: ChatEntities) async -> ChatMessage {
        var trackToPlay: AudioTrack?
        var playReason = ""

        // Play specific sound type
        if let soundType = entities.soundType {
            trackToPlay = libraryService.allTracks.first { $0.generatorType == soundType }
            playReason = "Playing \(soundType.rawValue) as requested"
        }
        // Play for mood/cry type
        else if let cryType = entities.cryType {
            // BabyMIM not available - skip profile-based recommendations
            // if let profile = babyMoodIntelligence?.babyProfile { ... }

            // Fallback to research-based
            if trackToPlay == nil {
                let recommended = getResearchBasedRecommendations(for: cryType).first
                if let rec = recommended {
                    trackToPlay = libraryService.allTracks.first { $0.id.uuidString == rec.trackId }
                    playReason = rec.reason
                }
            }
        }
        // Play category
        else if let category = entities.category {
            let categoryTracks = libraryService.getTracks(for: category).sorted { $0.calmingScore > $1.calmingScore }
            trackToPlay = categoryTracks.first
            playReason = "Playing top-rated \(category.rawValue) track"
        }

        guard let track = trackToPlay else {
            return ChatMessage.assistantMessage(
                "I'm not sure what to play. Try saying:\n" +
                "• 'Play womb sounds'\n" +
                "• 'Play something for a tired baby'\n" +
                "• 'Play nature sounds'"
            )
        }

        return ChatMessage(
            sender: .assistant,
            text: "🎵 **\(track.title)**\n\n\(playReason)",
            action: .playTrack(trackId: track.id.uuidString, trackTitle: track.title)
        )
    }

    private func handleCarModeIntent(query: String) -> ChatMessage {
        let explanation = """
        **Smart Car Mode** uses your car's natural sounds to help soothe your baby!

        🚗 **How it works:**
        • Detects car engine rumble and road noise
        • When the car provides good soothing sounds (highway driving), I lower the music
        • When it's quiet (parked, electric vehicle), I increase soothing sounds
        • Motion detection adjusts to stop-and-go vs. smooth cruising

        📊 **Why car sounds work:**
        Honda research found that 11 out of 12 babies calmed down when hearing car engine sounds. The low-frequency rumble is similar to sounds in the womb!

        To enable Smart Car Mode, go to Settings > CarPlay > Enable Smart Mode
        """

        let citations = researchKnowledge.getCitations(for: .carSounds)
        return ChatMessage(
            sender: .assistant,
            text: explanation,
            citations: citations.isEmpty ? nil : Array(citations.prefix(1))
        )
    }

    private func handleHelpIntent() -> ChatMessage {
        return ChatMessage.assistantMessage(
            "I can help you find the perfect sounds for your baby! Try asking:\n\n" +
            "**Find sounds:**\n" +
            "• \"Find lullabies\"\n" +
            "• \"Show me nature sounds\"\n" +
            "• \"Search for womb sounds\"\n\n" +
            "**Get recommendations:**\n" +
            "• \"My baby is tired, what should I play?\"\n" +
            "• \"What works best for hungry cries?\"\n" +
            "• \"Recommend something calming\"\n\n" +
            "**Learn why things work:**\n" +
            "• \"Why do womb sounds help?\"\n" +
            "• \"How do lullabies calm babies?\"\n\n" +
            "**Check history:**\n" +
            "• \"What worked last time?\"\n" +
            "• \"What's best for my baby?\""
        )
    }

    private func handleUnknownIntent(query: String, entities: ChatEntities) async -> ChatMessage {
        // Try to be helpful even if we don't understand
        if entities.cryType != nil || entities.mood != nil {
            return await handleRecommendIntent(entities: entities)
        }

        if entities.category != nil || entities.soundType != nil {
            return await handleSearchIntent(query: query, entities: entities)
        }

        // Default to help
        return ChatMessage.assistantMessage(
            "I'm not sure I understood that. Here's what I can help with:\n\n" +
            "• Finding and playing sounds\n" +
            "• Recommending tracks for your baby's mood\n" +
            "• Explaining why certain sounds work\n" +
            "• Showing what worked best in the past\n\n" +
            "Try asking something like \"Play womb sounds\" or \"What helps with a tired baby?\""
        )
    }

    // MARK: - Helper Methods

    private func getResearchReason(for soundType: GeneratorType) -> String? {
        switch soundType {
        case .womb, .heartbeat:
            return "Mimics sounds baby heard for 9 months in the womb - 90% calm in 3 minutes"
        case .shushing:
            return "Dr. Karp's 5 S's - recreates intrauterine blood flow sounds"
        case .aquarium, .aquarium:
            return "Consistent rhythmic patterns promote relaxation"
        case .lullaby, .musicBox:
            return "60-80 BPM matches baby's resting heart rate"
        case .bells, .chimes:
            return "Nature sounds reduce anxiety by up to 33%"
        default:
            return nil
        }
    }

    private func getResearchBasedRecommendations(for cryType: CryType) -> [TrackRecommendation] {
        let strategy = cryType.soothingStrategy
        let sounds: [GeneratorType]

        switch strategy {
        case .sleepInduction:
            sounds = [.aquarium, .aquarium]
        case .urgent:
            sounds = [.aquarium, .aquarium]
        case .distraction:
            sounds = [.musicBox, .chimes]
        case .comfort:
            sounds = [.aquarium, .aquarium]
        case .gentle:
            sounds = [.aquarium, .aquarium]
        case .adaptive:
            sounds = [.aquarium, .aquarium]
        }

        return sounds.compactMap { sound in
            guard let track = libraryService.allTracks.first(where: { $0.generatorType == sound }) else {
                return nil
            }
            return TrackRecommendation(
                trackId: track.id.uuidString,
                title: track.title,
                category: track.category.rawValue,
                reason: getResearchReason(for: sound) ?? "Effective for \(cryType.rawValue) cries",
                confidenceScore: 0.75,
                researchBacking: getResearchReason(for: sound)
            )
        }
    }

    private func getCryTypeExplanation(_ cryType: CryType) -> String {
        let citations = researchKnowledge.getCitations(for: .cryClassification)
        let baseExplanation: String

        switch cryType {
        case .hunger:
            baseExplanation = "**Hunger cries** are typically rhythmic, repetitive, and at a lower pitch. They follow a pattern: cry → pause → cry → pause."
        case .tired:
            baseExplanation = "**Tired cries** are monotonous with a falling melody. They may include rubbing eyes, yawning, or looking away."
        case .pain:
            baseExplanation = "**Pain/discomfort cries** are sudden, high-pitched, and more intense. They're often continuous without the rhythmic pauses of hunger cries."
        case .attention:
            baseExplanation = "**Attention-seeking cries** often build gradually and may include cooing or other sounds. Baby may calm quickly when picked up."
        case .discomfort:
            baseExplanation = "**Discomfort cries** are variable and may include squirming. Check diaper, temperature, or if clothing is too tight."
        default:
            baseExplanation = "Baby cries can be complex and may combine multiple needs. Our AI analyzes the acoustic patterns to help identify the most likely cause."
        }

        return baseExplanation + "\n\n" + (citations.first?.summary ?? "Research shows AI can classify baby cries with 90-96% accuracy based on acoustic patterns.")
    }
}
