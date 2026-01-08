//
//  VoiceCommandLLMService.swift
//  BabyInCarApp
//
//  ⚠️ DEPRECATED - This custom voice control system does NOT work for CarPlay.
//
//  WHY IT DOESN'T WORK:
//  1. CarPlay uses Siri for voice commands, not custom SFSpeechRecognizer
//  2. Custom speech recognition requires app's microphone - unavailable in CarPlay
//  3. This system only works when app is in foreground with microphone permission
//
//  PROPER CARPLAY VOICE INTEGRATION (TODO):
//  1. Implement SiriKit Intents (INPlayMediaIntent, INPauseMediaIntent, etc.)
//  2. Create Intents.intentdefinition in Xcode
//  3. Handle intents in IntentHandler extension
//  4. User says "Hey Siri, play lullabies in Lulla" -> Siri routes to app
//
//  See: https://developer.apple.com/documentation/sirikit/media
//

import Foundation

// MARK: - Voice Command Intent

enum VoiceCommandIntent {
    case play
    case pause
    case stop
    case next
    case previous
    case volumeUp
    case volumeDown
    case mute
    case unmute
    case emergency
    case quit

    // Content-specific
    case playCategory(AudioCategory)
    case playMood(AIRecommendationEngine.Mood)
    case playTrack(trackTitle: String)
    case searchTrack(query: String)
    case playPlaylist(name: String)

    // Complex commands
    case setVolume(level: Float)  // 0-100
    case sleepTimer(minutes: Int)
    case repeatOff
    case repeatOne
    case repeatAll
    case shuffleOn
    case shuffleOff

    case unknown(text: String)
}

// Manual Equatable conformance for VoiceCommandIntent
extension VoiceCommandIntent: Equatable {
    static func == (lhs: VoiceCommandIntent, rhs: VoiceCommandIntent) -> Bool {
        switch (lhs, rhs) {
        case (.play, .play),
             (.pause, .pause),
             (.stop, .stop),
             (.next, .next),
             (.previous, .previous),
             (.volumeUp, .volumeUp),
             (.volumeDown, .volumeDown),
             (.mute, .mute),
             (.unmute, .unmute),
             (.emergency, .emergency),
             (.quit, .quit),
             (.shuffleOn, .shuffleOn),
             (.shuffleOff, .shuffleOff):
            return true
        case let (.playCategory(lhsCategory), .playCategory(rhsCategory)):
            return lhsCategory == rhsCategory
        case let (.playMood(lhsMood), .playMood(rhsMood)):
            return lhsMood == rhsMood
        case let (.playTrack(lhsTitle), .playTrack(rhsTitle)):
            return lhsTitle == rhsTitle
        case let (.searchTrack(lhsQuery), .searchTrack(rhsQuery)):
            return lhsQuery == rhsQuery
        case let (.playPlaylist(lhsName), .playPlaylist(rhsName)):
            return lhsName == rhsName
        case let (.setVolume(lhsLevel), .setVolume(rhsLevel)):
            return lhsLevel == rhsLevel
        case let (.sleepTimer(lhsMinutes), .sleepTimer(rhsMinutes)):
            return lhsMinutes == rhsMinutes
        case (.repeatOff, .repeatOff),
             (.repeatOne, .repeatOne),
             (.repeatAll, .repeatAll):
            return true
        case let (.unknown(lhsText), .unknown(rhsText)):
            return lhsText == rhsText
        default:
            return false
        }
    }
}

// MARK: - Parsed Command

struct ParsedVoiceCommand {
    let originalText: String
    let intent: VoiceCommandIntent
    let confidence: Double
    let parameters: [String: Any]
    let alternativeIntents: [VoiceCommandIntent]
}

// MARK: - Voice Command LLM Service

@MainActor
class VoiceCommandLLMService: ObservableObject {
    static let shared = VoiceCommandLLMService()

    // MARK: - Configuration

    /// DISABLED: LLM parsing is not available on iOS (Ollama requires desktop)
    /// The VoiceIntentClassifier using Apple's NaturalLanguage framework is used instead
    @Published var useLLMParsing: Bool = false

    /// DEPRECATED: Ollama endpoint - not used on iOS
    var ollamaEndpoint: String = "http://localhost:11434/api/generate"

    /// DEPRECATED: Cloud API - not configured
    var cloudAPIEndpoint: String?
    var cloudAPIKey: String?

    /// DEPRECATED: Ollama model name
    var ollamaModel: String = "llama3.2"

    // MARK: - Dependencies

    private let contentLibrary = ContentLibraryService.shared

    private init() {
        print("🎯 VoiceCommandLLMService: Using simple keyword matching")
    }

    // MARK: - Main Parsing

    /// Parse voice command using SIMPLE keyword matching
    /// No ML, no LLM, no complex stuff - just works
    func parseCommand(_ text: String) async -> ParsedVoiceCommand {
        // Normalize: lowercase, trim whitespace, and remove trailing punctuation
        var normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove common trailing punctuation from speech recognition
        while let lastChar = normalizedText.last, ".!?,;:".contains(lastChar) {
            normalizedText.removeLast()
        }
        normalizedText = normalizedText.trimmingCharacters(in: .whitespaces)

        print("🎯 Voice: '\(text)' → '\(normalizedText)'")

        // SIMPLE keyword matching - no ML, no LLM, just works
        let result = parseSimple(normalizedText)
        print("🎯 Voice result: \(result.intent) (\(Int(result.confidence * 100))%)")
        return result
    }

    // MARK: - Simple Keyword Matching

    /// Dead simple keyword matching that actually works
    private func parseSimple(_ text: String) -> ParsedVoiceCommand {
        // PLAYBACK CONTROL - most common
        if text == "play" || text == "start" || text == "resume" || text == "go" ||
           text.hasPrefix("play music") || text.hasPrefix("play something") ||
           text.hasPrefix("play anything") || text.hasPrefix("start playing") {
            return ParsedVoiceCommand(originalText: text, intent: .play, confidence: 0.95, parameters: [:], alternativeIntents: [])
        }

        if text == "pause" || text == "stop" || text.contains("pause") || text.contains("stop") {
            return ParsedVoiceCommand(originalText: text, intent: .pause, confidence: 0.95, parameters: [:], alternativeIntents: [])
        }

        if text == "next" || text == "skip" || text.contains("next") || text.contains("skip") {
            return ParsedVoiceCommand(originalText: text, intent: .next, confidence: 0.95, parameters: [:], alternativeIntents: [])
        }

        if text == "previous" || text == "back" || text.contains("previous") || text.contains("go back") || text.contains("last track") {
            return ParsedVoiceCommand(originalText: text, intent: .previous, confidence: 0.95, parameters: [:], alternativeIntents: [])
        }

        // VOLUME
        if text.contains("louder") || text.contains("volume up") || text.contains("turn up") {
            return ParsedVoiceCommand(originalText: text, intent: .volumeUp, confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("quieter") || text.contains("softer") || text.contains("volume down") || text.contains("turn down") {
            return ParsedVoiceCommand(originalText: text, intent: .volumeDown, confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("mute") || text == "quiet" || text == "silence" {
            return ParsedVoiceCommand(originalText: text, intent: .mute, confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        // CATEGORIES - check these before generic play
        if text.contains("classical") || text.contains("mozart") || text.contains("beethoven") || text.contains("bach") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.classicalMusic), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("lullaby") || text.contains("lullabies") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.lullabies), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("fairy tale") || text.contains("story") || text.contains("stories") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.fairyTales), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("nature") || text.contains("ocean") || text.contains("waves") || text.contains("forest") || text.contains("birds") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.natureSounds), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("ambient") || text.contains("womb") || text.contains("heartbeat") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.ambient), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("instrumental") || text.contains("piano") || text.contains("guitar") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.instrumental), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("children") || text.contains("kids") || text.contains("nursery") {
            return ParsedVoiceCommand(originalText: text, intent: .playCategory(.childrenSongs), confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        // MOODS
        if text.contains("sleepy") || text.contains("sleep") || text.contains("bedtime") || text.contains("tired") {
            return ParsedVoiceCommand(originalText: text, intent: .playMood(.sleepy), confidence: 0.85, parameters: [:], alternativeIntents: [])
        }

        if text.contains("crying") || text.contains("upset") || text.contains("calm down") {
            return ParsedVoiceCommand(originalText: text, intent: .playMood(.crying), confidence: 0.85, parameters: [:], alternativeIntents: [])
        }

        if text.contains("playful") || text.contains("happy") || text.contains("awake") {
            return ParsedVoiceCommand(originalText: text, intent: .playMood(.playful), confidence: 0.85, parameters: [:], alternativeIntents: [])
        }

        // EMERGENCY - includes "cry again" to re-trigger emergency mode
        if text.contains("emergency") || text.contains("help") || text.contains("baby crying") ||
           text.contains("cry again") || text.contains("crying again") || text.contains("baby cry") {
            return ParsedVoiceCommand(originalText: text, intent: .emergency, confidence: 0.95, parameters: [:], alternativeIntents: [])
        }

        // SHUFFLE/REPEAT
        if text.contains("shuffle") {
            let intent: VoiceCommandIntent = text.contains("off") ? .shuffleOff : .shuffleOn
            return ParsedVoiceCommand(originalText: text, intent: intent, confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        if text.contains("repeat") {
            let intent: VoiceCommandIntent = text.contains("off") ? .repeatOff : (text.contains("one") || text.contains("this") ? .repeatOne : .repeatAll)
            return ParsedVoiceCommand(originalText: text, intent: intent, confidence: 0.9, parameters: [:], alternativeIntents: [])
        }

        // QUIT
        if text.contains("quit") || text.contains("exit") || text.contains("close") {
            return ParsedVoiceCommand(originalText: text, intent: .quit, confidence: 0.85, parameters: [:], alternativeIntents: [])
        }

        // If text starts with "play " and we haven't matched a category, treat as generic play
        if text.hasPrefix("play ") {
            return ParsedVoiceCommand(originalText: text, intent: .play, confidence: 0.8, parameters: [:], alternativeIntents: [])
        }

        // UNKNOWN - nothing matched
        return ParsedVoiceCommand(originalText: text, intent: .unknown(text: text), confidence: 0.0, parameters: [:], alternativeIntents: [])
    }

    // MARK: - Enhanced Rule-Based Parsing

    private func parseWithEnhancedRules(_ text: String) -> ParsedVoiceCommand {
        var intent: VoiceCommandIntent = .unknown(text: text)
        var confidence: Double = 0.0
        var alternatives: [VoiceCommandIntent] = []

        // 1. Check for special commands FIRST (emergency, quit, etc.)
        // These take priority over other commands
        if let specialIntent = parseSpecialCommand(text) {
            intent = specialIntent.intent
            confidence = specialIntent.confidence
        }

        // 2. Check for volume commands
        else if let volumeIntent = parseVolumeCommand(text) {
            intent = volumeIntent.intent
            confidence = volumeIntent.confidence
        }

        // 3. Check for category commands (fairy tales, classical, etc.)
        else if let categoryIntent = parseCategoryCommand(text) {
            intent = categoryIntent.intent
            confidence = categoryIntent.confidence
            alternatives = categoryIntent.alternatives
        }

        // 4. Check for mood commands
        else if let moodIntent = parseMoodCommand(text) {
            intent = moodIntent.intent
            confidence = moodIntent.confidence
        }

        // 5. Check for track search by title
        else if let trackIntent = parseTrackSearch(text) {
            intent = trackIntent.intent
            confidence = trackIntent.confidence
        }

        // 6. Check for basic playback commands LAST
        // (so specific commands like "play fairy tales" get matched first)
        else if let playbackIntent = parsePlaybackCommand(text) {
            intent = playbackIntent.intent
            confidence = playbackIntent.confidence
        }

        return ParsedVoiceCommand(
            originalText: text,
            intent: intent,
            confidence: confidence,
            parameters: [:],
            alternativeIntents: alternatives
        )
    }

    // MARK: - Playback Command Parsing

    private func parsePlaybackCommand(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double)? {
        // 🔧 FIX: Check "previous" BEFORE "play" to prevent "go back" matching "go" in play patterns

        // Previous commands - MUST check FIRST before play patterns
        if text.contains("previous") || text.contains("last track") || text.contains("last song") ||
           text.contains("before that") || text == "back" {
            return (.previous, 0.9)
        }

        // Special handling for "go back" to prevent matching "go" in play patterns
        if text.hasPrefix("go back") || text == "go back" || text.hasSuffix("go back") {
            return (.previous, 0.9)
        }

        // Pause/Stop commands - check BEFORE play to avoid "stop" matching "start"
        let pausePatterns = ["pause", "stop", "halt", "wait", "hold"]
        for pattern in pausePatterns {
            if text.contains(pattern) && !text.contains("don't stop") {
                return (pattern == "stop" ? .stop : .pause, 0.9)
            }
        }

        // Next commands
        let nextPatterns = ["next", "skip", "forward", "next track", "next song", "skip this"]
        for pattern in nextPatterns {
            if text.contains(pattern) {
                return (.next, 0.9)
            }
        }

        // 🔧 FIX: Generic play commands (with or without "music", "something", etc.)
        // "play", "play music", "play something", "play anything" -> all should trigger .play
        let playPatterns = ["play", "start", "resume", "continue", "begin"]
        for pattern in playPatterns {
            // Exact match: "play"
            if text == pattern {
                return (.play, 0.95)
            }

            // Play with generic content: "play music", "play something", "play anything"
            if text.hasPrefix("\(pattern) ") {
                let rest = String(text.dropFirst(pattern.count + 1))
                let genericKeywords = ["music", "something", "anything", "audio", "sound", "songs", "it"]
                if genericKeywords.contains(rest) || genericKeywords.contains(where: { rest.contains($0) && !containsSpecificContentKeyword(rest) }) {
                    return (.play, 0.9)
                }

                // If it contains specific content keywords, it will be handled by category/mood parsers
                // Don't return nil here - let it fall through
            }
        }

        // Special case: bare "go" (not "go back") can mean play
        if text == "go" {
            return (.play, 0.85)
        }

        return nil
    }

    /// Check if text contains SPECIFIC content keywords (not generic ones like "music")
    private func containsSpecificContentKeyword(_ text: String) -> Bool {
        let specificKeywords = [
            // Specific categories
            "classical", "lullaby", "lullabies", "fairy", "tale", "tales", "story", "stories",
            "nature", "ambient", "instrumental", "womb", "heartbeat",
            // Artists/composers
            "mozart", "beethoven", "bach", "chopin", "debussy",
            // Nature specifics
            "ocean", "waves", "forest", "birds", "river",
            // Mood-related
            "sleepy", "bedtime", "calm", "crying", "fussy", "playful"
        ]
        return specificKeywords.contains { text.contains($0) }
    }

    /// DEPRECATED: Old containsContentKeywords - too aggressive, blocks valid "play music" commands
    private func containsContentKeywords(_ text: String) -> Bool {
        // Now only returns true for SPECIFIC content that should route to category/mood
        return containsSpecificContentKeyword(text)
    }

    // MARK: - Volume Command Parsing

    private func parseVolumeCommand(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double)? {
        // Volume up
        let volumeUpPatterns = ["louder", "volume up", "turn up", "increase volume", "raise volume", "more volume", "higher"]
        for pattern in volumeUpPatterns {
            if text.contains(pattern) {
                return (.volumeUp, 0.9)
            }
        }

        // Volume down
        let volumeDownPatterns = ["quieter", "softer", "volume down", "turn down", "decrease volume", "lower volume", "less volume", "lower"]
        for pattern in volumeDownPatterns {
            if text.contains(pattern) {
                return (.volumeDown, 0.9)
            }
        }

        // Mute
        let mutePatterns = ["mute", "silence", "quiet", "shush"]
        for pattern in mutePatterns {
            if text.contains(pattern) {
                return (.mute, 0.85)
            }
        }

        // Unmute
        if text.contains("unmute") {
            return (.unmute, 0.9)
        }

        // Specific volume level: "set volume to 50" or "volume 80 percent"
        if let volumeLevel = extractVolumeLevel(from: text) {
            return (.setVolume(level: volumeLevel), 0.85)
        }

        return nil
    }

    private func extractVolumeLevel(from text: String) -> Float? {
        let patterns = [
            #"volume\s*(?:to|at)?\s*(\d+)"#,
            #"(\d+)\s*percent"#,
            #"set\s*(?:volume|sound)?\s*(?:to|at)?\s*(\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                for i in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: text),
                       let level = Float(text[range]) {
                        return min(100, max(0, level))
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Category Command Parsing

    private func parseCategoryCommand(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double, alternatives: [VoiceCommandIntent])? {
        // Direct category matches
        for category in AudioCategory.allCases {
            let categoryName = category.rawValue.lowercased()
            if text.contains(categoryName) {
                return (.playCategory(category), 0.95, [])
            }
        }

        // Fuzzy category matching with aliases
        let categoryAliases: [(patterns: [String], category: AudioCategory)] = [
            // Classical Music
            (["classical", "mozart", "beethoven", "bach", "piano music", "orchestra", "symphony"], .classicalMusic),

            // Fairy Tales
            (["fairy tale", "fairy tales", "stories", "story", "bedtime story", "tale", "tales", "reading"], .fairyTales),

            // Ambient Sounds (womb, heartbeat - NO white noise!)
            (["ambient", "womb", "womb sound", "heartbeat", "shushing"], .ambient),

            // Nature Sounds (ONLY gentle - NO rain/thunder/storm/wind!)
            (["nature", "ocean", "waves", "forest", "birds", "river", "water"], .natureSounds),

            // Instrumental
            (["instrumental", "piano", "guitar", "gentle music", "soft music", "music box", "chimes", "bells"], .instrumental),

            // Lullabies (dedicated category)
            (["lullaby", "lullabies"], .lullabies),

            // Children's Songs
            (["children song", "children's songs", "kids song", "nursery rhyme", "baby song", "twinkle"], .childrenSongs),

            // Podcasts
            (["podcast", "podcasts", "talk", "speaking", "voice"], .podcasts)
        ]

        for (patterns, category) in categoryAliases {
            for pattern in patterns {
                if text.contains(pattern) {
                    // Check if it's a "play" command
                    if text.contains("play") || text.hasPrefix("put on") || text.contains("start") {
                        return (.playCategory(category), 0.85, [])
                    }
                    // Just category mentioned might mean play it
                    return (.playCategory(category), 0.7, [.searchTrack(query: text)])
                }
            }
        }

        return nil
    }

    // MARK: - Mood Command Parsing

    private func parseMoodCommand(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double)? {
        let moodPatterns: [(patterns: [String], mood: AIRecommendationEngine.Mood)] = [
            (["sleepy", "sleep", "bedtime", "naptime", "tired", "drowsy"], .sleepy),
            (["crying", "upset", "distressed", "calm down", "soothe"], .crying),
            (["playful", "happy", "awake", "active", "energetic", "fun"], .playful),
            (["calm", "peaceful", "relaxed", "quiet time"], .calm),
            (["fussy", "cranky", "irritable", "grumpy"], .fussy),
            (["restless", "agitated", "unsettled"], .restless),
            (["overtired", "exhausted", "very tired"], .overtired)
        ]

        for (patterns, mood) in moodPatterns {
            for pattern in patterns {
                if text.contains(pattern) {
                    return (.playMood(mood), 0.8)
                }
            }
        }

        return nil
    }

    // MARK: - Track Search Parsing

    /// Common command words that should NOT be treated as track searches
    private static let commandKeywords: Set<String> = [
        "play", "pause", "stop", "start", "resume", "continue", "begin",
        "next", "skip", "previous", "back", "go", "forward",
        "louder", "quieter", "volume", "mute", "unmute",
        "emergency", "help", "quit", "exit", "close",
        "shuffle", "repeat", "loop"
    ]

    private func parseTrackSearch(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double)? {
        // 🔧 FIX: Don't match common command keywords as track searches
        // If the text is just a command keyword (like "play"), skip track search entirely
        if Self.commandKeywords.contains(text) {
            return nil
        }

        // Check for "play [track name]" patterns
        let playPrefixes = ["play ", "put on ", "start ", "find "]

        for prefix in playPrefixes {
            if text.hasPrefix(prefix) {
                let query = String(text.dropFirst(prefix.count))

                // Don't search if query is empty or just a command keyword
                guard !query.isEmpty && !Self.commandKeywords.contains(query) else {
                    return nil
                }

                // Search for matching tracks
                if let matchedTrack = findBestMatchingTrack(query: query) {
                    return (.playTrack(trackTitle: matchedTrack.title), 0.85)
                }

                // No exact match, but user clearly wants to search
                return (.searchTrack(query: query), 0.7)
            }
        }

        // Check if text matches a track title directly
        // But only for longer queries (3+ words or 10+ chars) to avoid false matches
        if text.count >= 10 || text.split(separator: " ").count >= 3 {
            if let matchedTrack = findBestMatchingTrack(query: text) {
                return (.playTrack(trackTitle: matchedTrack.title), 0.75)
            }
        }

        return nil
    }

    private func findBestMatchingTrack(query: String) -> AudioTrack? {
        let allTracks = contentLibrary.getAllTracks()
        let normalizedQuery = query.lowercased()

        // Exact title match
        if let exact = allTracks.first(where: { $0.title.lowercased() == normalizedQuery }) {
            return exact
        }

        // Contains match
        if let contains = allTracks.first(where: { $0.title.lowercased().contains(normalizedQuery) }) {
            return contains
        }

        // Fuzzy match using Levenshtein-like similarity
        var bestMatch: AudioTrack?
        var bestScore: Double = 0

        for track in allTracks {
            let score = calculateSimilarity(query: normalizedQuery, target: track.title.lowercased())
            if score > bestScore && score > 0.5 {
                bestScore = score
                bestMatch = track
            }
        }

        return bestMatch
    }

    private func calculateSimilarity(query: String, target: String) -> Double {
        // Simple word overlap similarity
        let queryWords = Set(query.split(separator: " ").map { String($0) })
        let targetWords = Set(target.split(separator: " ").map { String($0) })

        guard !queryWords.isEmpty else { return 0 }

        let intersection = queryWords.intersection(targetWords)
        return Double(intersection.count) / Double(queryWords.count)
    }

    // MARK: - Special Command Parsing

    private func parseSpecialCommand(_ text: String) -> (intent: VoiceCommandIntent, confidence: Double)? {
        // Emergency - includes "cry again" to re-trigger emergency mode
        let emergencyPatterns = ["emergency", "cry stop", "help", "baby crying", "calm baby", "soothe", "urgent",
                                 "cry again", "crying again", "baby cry"]
        for pattern in emergencyPatterns {
            if text.contains(pattern) {
                return (.emergency, pattern == "emergency" ? 0.95 : 0.85)
            }
        }

        // Quit/Exit
        let quitPatterns = ["quit", "exit", "close", "goodbye", "bye", "stop everything", "turn off"]
        for pattern in quitPatterns {
            if text.contains(pattern) {
                return (.quit, 0.8)
            }
        }

        // Shuffle
        if text.contains("shuffle") {
            if text.contains("off") || text.contains("disable") {
                return (.shuffleOff, 0.9)
            }
            return (.shuffleOn, 0.9)
        }

        // Repeat
        if text.contains("repeat") {
            if text.contains("off") {
                return (.repeatOff, 0.9)
            } else if text.contains("one") || text.contains("this") || text.contains("song") {
                return (.repeatOne, 0.9)
            } else {
                return (.repeatAll, 0.85)
            }
        }

        // Sleep timer
        if text.contains("sleep timer") || text.contains("timer") {
            if let minutes = extractMinutes(from: text) {
                return (.sleepTimer(minutes: minutes), 0.85)
            }
        }

        return nil
    }

    private func extractMinutes(from text: String) -> Int? {
        let patterns = [
            #"(\d+)\s*minutes?"#,
            #"(\d+)\s*mins?"#,
            #"timer\s*(?:for|to)?\s*(\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text),
                   let minutes = Int(text[range]) {
                    return minutes
                }
            }
        }
        return nil
    }

    // MARK: - LLM Parsing

    private func parseWithLLM(_ text: String) async -> ParsedVoiceCommand? {
        // Try Ollama first (local inference)
        if let ollamaResult = await parseWithOllama(text) {
            return ollamaResult
        }

        // Fall back to cloud API if configured
        if cloudAPIEndpoint != nil, cloudAPIKey != nil {
            return await parseWithCloudAPI(text)
        }

        return nil
    }

    private func parseWithOllama(_ text: String) async -> ParsedVoiceCommand? {
        let prompt = buildLLMPrompt(text: text)

        let requestBody: [String: Any] = [
            "model": ollamaModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1,
                "num_predict": 100
            ]
        ]

        guard let url = URL(string: ollamaEndpoint),
              let requestData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 5.0 // Quick timeout for voice commands

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Ollama request failed")
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseText = json["response"] as? String {
                return parseOllamaResponse(responseText, originalText: text)
            }
        } catch {
            print("⚠️ Ollama error: \(error.localizedDescription)")
        }

        return nil
    }

    private func buildLLMPrompt(text: String) -> String {
        let categories = AudioCategory.allCases.map { $0.rawValue }.joined(separator: ", ")
        let moods = AIRecommendationEngine.Mood.allCases.map { $0.rawValue }.joined(separator: ", ")

        return """
        You are a voice command parser for a baby soothing app. Parse the user's voice command and return a JSON response.

        Available categories: \(categories)
        Available moods: \(moods)
        Available commands: play, pause, stop, next, previous, volume_up, volume_down, mute, emergency, quit, shuffle, repeat

        User said: "\(text)"

        Return ONLY a JSON object like:
        {"intent": "play_category", "category": "Classical Music", "confidence": 0.9}
        or
        {"intent": "play", "confidence": 0.95}
        or
        {"intent": "search_track", "query": "piano moment", "confidence": 0.8}

        JSON response:
        """
    }

    private func parseOllamaResponse(_ response: String, originalText: String) -> ParsedVoiceCommand? {
        // Extract JSON from response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let intentString = json["intent"] as? String,
              let confidence = json["confidence"] as? Double else {
            return nil
        }

        let intent = mapLLMIntentToLocal(intentString, json: json)

        return ParsedVoiceCommand(
            originalText: originalText,
            intent: intent,
            confidence: confidence,
            parameters: json,
            alternativeIntents: []
        )
    }

    private func mapLLMIntentToLocal(_ intentString: String, json: [String: Any]) -> VoiceCommandIntent {
        switch intentString.lowercased() {
        case "play":
            return .play
        case "pause":
            return .pause
        case "stop":
            return .stop
        case "next":
            return .next
        case "previous":
            return .previous
        case "volume_up", "volumeup":
            return .volumeUp
        case "volume_down", "volumedown":
            return .volumeDown
        case "mute":
            return .mute
        case "emergency":
            return .emergency
        case "quit":
            return .quit
        case "shuffle_on":
            return .shuffleOn
        case "shuffle_off":
            return .shuffleOff
        case "play_category":
            if let categoryName = json["category"] as? String,
               let category = AudioCategory.allCases.first(where: { $0.rawValue == categoryName }) {
                return .playCategory(category)
            }
            return .play
        case "play_mood":
            if let moodName = json["mood"] as? String,
               let mood = AIRecommendationEngine.Mood.allCases.first(where: { $0.rawValue == moodName }) {
                return .playMood(mood)
            }
            return .play
        case "play_track":
            if let title = json["track"] as? String {
                return .playTrack(trackTitle: title)
            }
            return .play
        case "search_track":
            if let query = json["query"] as? String {
                return .searchTrack(query: query)
            }
            return .play
        default:
            return .unknown(text: intentString)
        }
    }

    private func parseWithCloudAPI(_ text: String) async -> ParsedVoiceCommand? {
        guard let endpoint = cloudAPIEndpoint,
              let apiKey = cloudAPIKey,
              let url = URL(string: endpoint) else {
            return nil
        }

        let requestBody: [String: Any] = [
            "text": text,
            "context": "baby_soothing_app"
        ]

        guard let requestData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let intentString = json["intent"] as? String,
                  let confidence = json["confidence"] as? Double else {
                return nil
            }

            let intent = mapLLMIntentToLocal(intentString, json: json)

            return ParsedVoiceCommand(
                originalText: text,
                intent: intent,
                confidence: confidence,
                parameters: json,
                alternativeIntents: []
            )
        } catch {
            print("⚠️ Cloud API error: \(error.localizedDescription)")
            return nil
        }
    }
}
