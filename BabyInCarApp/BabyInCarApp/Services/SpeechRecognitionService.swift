//
//  SpeechRecognitionService.swift
//  BabyInCarApp
//
//  ⚠️ DEPRECATED - Custom voice control does NOT work for CarPlay.
//
//  This service uses SFSpeechRecognizer which requires:
//  - Microphone permission (not available in CarPlay context)
//  - App in foreground with active audio session
//
//  FOR CARPLAY VOICE: Use Siri Intents instead (see VoiceCommandLLMService.swift)
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self?.isAuthorized = true
                    case .denied, .restricted, .notDetermined:
                        self?.isAuthorized = false
                        self?.errorMessage = "Speech recognition is not authorized"
                    @unknown default:
                        self?.isAuthorized = false
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Voice Recognition

    func startListening() {
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }

        // Stop any existing recognition
        stopListening()

        do {
            // TECHNICAL DEBT FIX: Use centralized AudioSessionManager instead of direct session manipulation
            // This prevents audio session conflicts with CryDetectionService and AudioEngine
            let sessionManager = AudioSessionManager.shared
            let success = sessionManager.requestSession(
                mode: .recordOnly,
                priority: .recording,  // Highest priority - voice commands need immediate response
                serviceId: "SpeechRecognitionService"
            )

            guard success else {
                errorMessage = "Audio session unavailable - please try again"
                return
            }

            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode

            // Get the native format and validate it
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Check if format is valid (sample rate > 0 and channels > 0)
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                errorMessage = "Invalid audio format - microphone may not be available"
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            recognizedText = ""

            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    if let result = result {
                        self?.recognizedText = result.bestTranscription.formattedString

                        // Process commands if final result
                        if result.isFinal {
                            self?.processVoiceCommand(result.bestTranscription.formattedString)
                        }
                    }

                    if error != nil || result?.isFinal == true {
                        self?.stopListening()
                    }
                }
            }
        } catch {
            errorMessage = "Failed to start speech recognition: \(error.localizedDescription)"
            stopListening()
        }
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // TECHNICAL DEBT FIX: Release audio session through centralized manager
        // The manager will automatically switch to the next highest priority request
        AudioSessionManager.shared.releaseSession(serviceId: "SpeechRecognitionService")

        // NOTE: restorePlaybackSession() is no longer needed - AudioSessionManager handles transitions
    }

    /// Restore audio session for playback after speech recognition
    private func restorePlaybackSession() {
        // Small delay to ensure speech recognition fully releases the audio session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                let session = AVAudioSession.sharedInstance()
                // Exclusive playback - pauses other apps (like Spotify, YouTube)
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
                print("🎙️ Audio session restored to exclusive playback mode")

                // Notify AudioEngine to reconfigure if needed
                NotificationCenter.default.post(name: .audioSessionRestored, object: nil)
            } catch {
                print("❌ Failed to restore audio session: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Voice Command Processing

    private func processVoiceCommand(_ text: String) {
        print("🎤 Processing voice command: '\(text)'")
        let lowercased = text.lowercased()

        // Age extraction (special case - doesn't go through LLM)
        if let age = extractAge(from: lowercased) {
            print("✅ Age command recognized: \(age) months")
            NotificationCenter.default.post(
                name: .voiceAgeRecognized,
                object: nil,
                userInfo: ["age": age]
            )
            return
        }

        // Use LLM-powered parser for intelligent command recognition
        Task {
            let parsedCommand = await VoiceCommandLLMService.shared.parseCommand(text)
            await MainActor.run {
                handleParsedCommand(parsedCommand)
            }
        }
    }

    /// Handle the parsed command from LLM service
    private func handleParsedCommand(_ command: ParsedVoiceCommand) {
        print("🧠 Parsed command: \(command.intent) (confidence: \(command.confidence))")

        switch command.intent {
        // Basic playback
        case .play:
            print("✅ Play command recognized - POSTING NOTIFICATION")
            print("🔔 Posting to notification: .voiceCommandPlay")
            print("🔔 Main thread? \(Thread.isMainThread)")
            NotificationCenter.default.post(name: .voiceCommandPlay, object: nil)
            print("🔔 Notification POSTED! Waiting for observers...")

        case .pause, .stop:
            print("✅ Pause/Stop command recognized")
            NotificationCenter.default.post(name: .voiceCommandPause, object: nil)

        case .next:
            print("✅ Next command recognized")
            NotificationCenter.default.post(name: .voiceCommandNext, object: nil)

        case .previous:
            print("✅ Previous command recognized")
            NotificationCenter.default.post(name: .voiceCommandPrevious, object: nil)

        // Volume
        case .volumeUp:
            print("✅ Volume up command recognized")
            NotificationCenter.default.post(name: .voiceCommandVolumeUp, object: nil)

        case .volumeDown:
            print("✅ Volume down command recognized")
            NotificationCenter.default.post(name: .voiceCommandVolumeDown, object: nil)

        case .mute:
            print("✅ Mute command recognized")
            NotificationCenter.default.post(name: .voiceCommandMute, object: nil)

        case .unmute:
            print("✅ Unmute command recognized")
            NotificationCenter.default.post(name: .voiceCommandMute, object: nil)

        case .setVolume(let level):
            print("✅ Set volume to \(level)% command recognized")
            NotificationCenter.default.post(
                name: .voiceCommandSetVolume,
                object: nil,
                userInfo: ["level": level]
            )

        // Emergency
        case .emergency:
            print("✅ Emergency command recognized")
            NotificationCenter.default.post(name: .voiceCommandEmergency, object: nil)

        // Quit
        case .quit:
            print("✅ Quit command recognized")
            NotificationCenter.default.post(name: .voiceCommandQuit, object: nil)

        // Category playback
        case .playCategory(let category):
            print("✅ Category command recognized: \(category.rawValue)")
            NotificationCenter.default.post(
                name: .voiceCommandCategory,
                object: nil,
                userInfo: ["category": category]
            )

        // Mood playback
        case .playMood(let mood):
            print("✅ Mood command recognized: \(mood.rawValue)")
            NotificationCenter.default.post(
                name: .voiceCommandMood,
                object: nil,
                userInfo: ["mood": mood]
            )

        // Track search/play
        case .playTrack(let trackTitle):
            print("✅ Play track command recognized: \(trackTitle)")
            NotificationCenter.default.post(
                name: .voiceCommandPlayTrack,
                object: nil,
                userInfo: ["trackTitle": trackTitle]
            )

        case .searchTrack(let query):
            print("✅ Search track command recognized: \(query)")
            NotificationCenter.default.post(
                name: .voiceCommandSearchTrack,
                object: nil,
                userInfo: ["query": query]
            )

        case .playPlaylist(let name):
            print("✅ Play playlist command recognized: \(name)")
            NotificationCenter.default.post(
                name: .voiceCommandPlayPlaylist,
                object: nil,
                userInfo: ["playlistName": name]
            )

        // Playback modes
        case .shuffleOn:
            print("✅ Shuffle on command recognized")
            NotificationCenter.default.post(name: .voiceCommandShuffleOn, object: nil)

        case .shuffleOff:
            print("✅ Shuffle off command recognized")
            NotificationCenter.default.post(name: .voiceCommandShuffleOff, object: nil)

        case .repeatOff:
            print("✅ Repeat off command recognized")
            NotificationCenter.default.post(
                name: .voiceCommandRepeatMode,
                object: nil,
                userInfo: ["mode": AudioEngine.RepeatMode.off]
            )

        case .repeatOne:
            print("✅ Repeat one command recognized")
            NotificationCenter.default.post(
                name: .voiceCommandRepeatMode,
                object: nil,
                userInfo: ["mode": AudioEngine.RepeatMode.one]
            )

        case .repeatAll:
            print("✅ Repeat all command recognized")
            NotificationCenter.default.post(
                name: .voiceCommandRepeatMode,
                object: nil,
                userInfo: ["mode": AudioEngine.RepeatMode.all]
            )

        case .sleepTimer(let minutes):
            print("✅ Sleep timer command recognized: \(minutes) minutes")
            NotificationCenter.default.post(
                name: .voiceCommandSleepTimer,
                object: nil,
                userInfo: ["minutes": minutes]
            )

        // Unknown - try alternatives or report not recognized
        case .unknown(let text):
            // Check if there are any alternative intents
            if let alternative = command.alternativeIntents.first {
                let altCommand = ParsedVoiceCommand(
                    originalText: command.originalText,
                    intent: alternative,
                    confidence: command.confidence * 0.8,
                    parameters: command.parameters,
                    alternativeIntents: []
                )
                handleParsedCommand(altCommand)
            } else {
                print("❌ No command recognized in: '\(text)'")
                NotificationCenter.default.post(
                    name: .voiceCommandNotRecognized,
                    object: nil,
                    userInfo: ["text": text]
                )
            }
        }
    }

    // MARK: - Age Extraction

    func extractAge(from text: String) -> Int? {
        let lowercased = text.lowercased()

        // Common patterns for age input
        let patterns: [(String, (String) -> Int?)] = [
            // "X months old"
            (#"(\d+)\s*months?\s*old"#, { match in Int(match) }),

            // "X month old"
            (#"(\d+)\s*month\s*old"#, { match in Int(match) }),

            // "X weeks old" (convert to months)
            (#"(\d+)\s*weeks?\s*old"#, { match in
                guard let weeks = Int(match) else { return nil }
                return weeks / 4
            }),

            // "newborn" / "just born"
            (#"newborn|just\s*born|new\s*born"#, { _ in 0 }),

            // "one year" / "1 year"
            (#"one\s*year|1\s*year"#, { _ in 12 }),

            // "two years" / "2 years"
            (#"two\s*years?|2\s*years?"#, { _ in 24 }),

            // "three years" / "3 years"
            (#"three\s*years?|3\s*years?"#, { _ in 36 }),

            // Word numbers
            (#"one\s*months?"#, { _ in 1 }),
            (#"two\s*months?"#, { _ in 2 }),
            (#"three\s*months?"#, { _ in 3 }),
            (#"four\s*months?"#, { _ in 4 }),
            (#"five\s*months?"#, { _ in 5 }),
            (#"six\s*months?"#, { _ in 6 }),
            (#"seven\s*months?"#, { _ in 7 }),
            (#"eight\s*months?"#, { _ in 8 }),
            (#"nine\s*months?"#, { _ in 9 }),
            (#"ten\s*months?"#, { _ in 10 }),
            (#"eleven\s*months?"#, { _ in 11 }),
            (#"twelve\s*months?"#, { _ in 12 }),

            // Simple number mention
            (#"(\d+)"#, { match in
                guard let num = Int(match) else { return nil }
                // Assume months if under 37, otherwise might be weeks
                return num <= 36 ? num : nil
            })
        ]

        for (pattern, converter) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if let match = regex.firstMatch(in: lowercased, options: [], range: range) {
                    if match.numberOfRanges > 1,
                       let matchRange = Range(match.range(at: 1), in: lowercased) {
                        let matchedString = String(lowercased[matchRange])
                        if let age = converter(matchedString) {
                            return max(0, min(36, age))
                        }
                    } else {
                        // Pattern without capture group (like "newborn")
                        if let age = converter("") {
                            return max(0, min(36, age))
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Date Extraction (for birthday input)

    func extractBirthDate(from text: String) -> Date? {
        let lowercased = text.lowercased()

        // Try to extract "born in [month] [year]" or "[month] [year]"
        let months = [
            "january": 1, "february": 2, "march": 3, "april": 4,
            "may": 5, "june": 6, "july": 7, "august": 8,
            "september": 9, "october": 10, "november": 11, "december": 12
        ]

        for (monthName, monthNumber) in months {
            if lowercased.contains(monthName) {
                // Look for year
                let yearPattern = #"20(2[0-5])"# // 2020-2025
                if let regex = try? NSRegularExpression(pattern: yearPattern),
                   let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                   let yearRange = Range(match.range(at: 0), in: lowercased) {
                    let yearString = String(lowercased[yearRange])
                    if let year = Int(yearString) {
                        var components = DateComponents()
                        components.year = year
                        components.month = monthNumber
                        components.day = 15 // Default to middle of month
                        return Calendar.current.date(from: components)
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    // Basic playback
    static let voiceAgeRecognized = Notification.Name("voiceAgeRecognized")
    static let voiceCommandPlay = Notification.Name("voiceCommandPlay")
    static let voiceCommandPause = Notification.Name("voiceCommandPause")
    static let voiceCommandNext = Notification.Name("voiceCommandNext")
    static let voiceCommandPrevious = Notification.Name("voiceCommandPrevious")
    static let voiceCommandEmergency = Notification.Name("voiceCommandEmergency")
    static let voiceCommandQuit = Notification.Name("voiceCommandQuit")

    // Volume
    static let voiceCommandVolumeUp = Notification.Name("voiceCommandVolumeUp")
    static let voiceCommandVolumeDown = Notification.Name("voiceCommandVolumeDown")
    static let voiceCommandMute = Notification.Name("voiceCommandMute")
    static let voiceCommandSetVolume = Notification.Name("voiceCommandSetVolume")

    // Content selection
    static let voiceCommandCategory = Notification.Name("voiceCommandCategory")
    static let voiceCommandMood = Notification.Name("voiceCommandMood")
    static let voiceCommandPlayTrack = Notification.Name("voiceCommandPlayTrack")
    static let voiceCommandSearchTrack = Notification.Name("voiceCommandSearchTrack")
    static let voiceCommandPlayPlaylist = Notification.Name("voiceCommandPlayPlaylist")

    // Playback modes
    static let voiceCommandShuffleOn = Notification.Name("voiceCommandShuffleOn")
    static let voiceCommandShuffleOff = Notification.Name("voiceCommandShuffleOff")
    static let voiceCommandRepeatMode = Notification.Name("voiceCommandRepeatMode")
    static let voiceCommandSleepTimer = Notification.Name("voiceCommandSleepTimer")

    // Feedback notifications
    static let voiceCommandExecuted = Notification.Name("voiceCommandExecuted")
    static let voiceCommandNotRecognized = Notification.Name("voiceCommandNotRecognized")

    // Audio session management
    static let audioSessionRestored = Notification.Name("audioSessionRestored")
}

// MARK: - Voice Command Result
struct VoiceCommandResult {
    let command: String
    let success: Bool
    let message: String
}

// MARK: - Voice Command Handler
@MainActor
class VoiceCommandHandler: ObservableObject {
    static let shared = VoiceCommandHandler()

    @Published var lastCommandResult: VoiceCommandResult?

    private var appState: AppState?
    private let audioEngine = AudioEngine.shared
    private let aiEngine = AIRecommendationEngine.shared
    private let emergencyService = EmergencyCryStopService.shared

    /// CRITICAL: Store observer tokens to prevent immediate deallocation
    /// NotificationCenter.addObserver(forName:) returns a token that MUST be retained
    /// Otherwise observers are deallocated and never receive notifications
    private var notificationObservers: [Any] = []

    /// Public property to check if handler is configured with AppState
    var isConfigured: Bool {
        return appState != nil
    }

    private init() {
        setupNotificationObservers()
        print("🔔 VoiceCommandHandler: Initialized with \(notificationObservers.count) observers")
    }

    func configure(with appState: AppState) {
        print("🔔 VoiceCommandHandler: Configuring with AppState")
        self.appState = appState
        print("🔔 VoiceCommandHandler: Configured! isConfigured = \(isConfigured)")
    }

    private func postCommandExecuted(command: String, success: Bool, message: String) {
        lastCommandResult = VoiceCommandResult(command: command, success: success, message: message)
        NotificationCenter.default.post(
            name: .voiceCommandExecuted,
            object: nil,
            userInfo: ["command": command, "success": success, "message": message]
        )
    }

    private func setupNotificationObservers() {
        print("🔔 VoiceCommandHandler: Setting up notification observers")
        print("🔔 VoiceCommandHandler: Main thread = \(Thread.isMainThread)")

        // CRITICAL FIX: Store observer tokens to prevent deallocation
        // NotificationCenter.addObserver(forName:) returns an object that MUST be retained
        // Without storing these, observers are immediately deallocated and never fire!

        let playObserver = NotificationCenter.default.addObserver(
            forName: .voiceCommandPlay,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔔🔔🔔 VoiceCommandHandler: ✅ RECEIVED Play notification!")
            print("🔔 Notification object: \(String(describing: notification.object))")
            print("🔔 Self is nil? \(self == nil)")
            Task { @MainActor in
                self?.handlePlay()
                self?.postCommandExecuted(command: "play", success: true, message: "Playing audio")
            }
        }

        notificationObservers.append(playObserver)
        print("🔔 VoiceCommandHandler: Registered Play observer (token: \(playObserver))")

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandPause,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                print("🔔 VoiceCommandHandler: Received Pause notification")
                Task { @MainActor in
                    self?.handlePause()
                    self?.postCommandExecuted(command: "pause", success: true, message: "Audio paused")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandNext,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                print("🔔 VoiceCommandHandler: Received Next notification")
                Task { @MainActor in
                    self?.audioEngine.next()
                    self?.postCommandExecuted(command: "next", success: true, message: "Skipped to next track")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandPrevious,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.audioEngine.previous()
                    self?.postCommandExecuted(command: "previous", success: true, message: "Back to previous track")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandEmergency,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleEmergency()
                    self?.postCommandExecuted(command: "emergency", success: true, message: "Emergency mode activated")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandVolumeUp,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    let currentVolume = self?.audioEngine.volume ?? 0.5
                    let newVolume = min(1.0, currentVolume + 0.15)
                    self?.audioEngine.setVolume(newVolume)
                    let percent = Int(newVolume * 100)
                    self?.postCommandExecuted(command: "volume up", success: true, message: "Volume: \(percent)%")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandVolumeDown,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    let currentVolume = self?.audioEngine.volume ?? 0.5
                    let newVolume = max(0, currentVolume - 0.15)
                    self?.audioEngine.setVolume(newVolume)
                    let percent = Int(newVolume * 100)
                    self?.postCommandExecuted(command: "volume down", success: true, message: "Volume: \(percent)%")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandMute,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.audioEngine.toggleMute()
                    let isMuted = self?.audioEngine.isMuted ?? false
                    self?.postCommandExecuted(command: "mute", success: true, message: isMuted ? "Audio muted" : "Audio unmuted")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandCategory,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let category = notification.userInfo?["category"] as? AudioCategory {
                        await self?.handleCategoryCommand(category)
                        self?.postCommandExecuted(command: "category", success: true, message: "Playing \(category.rawValue)")
                    }
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandMood,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let mood = notification.userInfo?["mood"] as? AIRecommendationEngine.Mood {
                        await self?.handleMoodCommand(mood)
                        self?.postCommandExecuted(command: "mood", success: true, message: "Playing \(mood.rawValue) playlist")
                    }
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceAgeRecognized,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let age = notification.userInfo?["age"] as? Int {
                        self?.handleAgeRecognized(age)
                        self?.postCommandExecuted(command: "age", success: true, message: "Baby age set to \(age) months")
                    }
                }
            }
        )

        // Track search/play
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandPlayTrack,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let trackTitle = notification.userInfo?["trackTitle"] as? String {
                        await self?.handlePlayTrack(trackTitle)
                    }
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandSearchTrack,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let query = notification.userInfo?["query"] as? String {
                        await self?.handleSearchTrack(query)
                    }
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandPlayPlaylist,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let playlistName = notification.userInfo?["playlistName"] as? String {
                        await self?.handlePlayPlaylist(playlistName)
                    }
                }
            }
        )

        // Volume control
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandSetVolume,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let level = notification.userInfo?["level"] as? Float {
                        self?.audioEngine.setVolume(level / 100.0)
                        self?.postCommandExecuted(command: "set volume", success: true, message: "Volume set to \(Int(level))%")
                    }
                }
            }
        )

        // Shuffle controls
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandShuffleOn,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.audioEngine.isShuffleEnabled = true
                    self?.postCommandExecuted(command: "shuffle", success: true, message: "Shuffle enabled")
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandShuffleOff,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.audioEngine.isShuffleEnabled = false
                    self?.postCommandExecuted(command: "shuffle", success: true, message: "Shuffle disabled")
                }
            }
        )

        // Repeat mode
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandRepeatMode,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let mode = notification.userInfo?["mode"] as? AudioEngine.RepeatMode {
                        self?.audioEngine.setRepeatMode(mode)
                        let modeText = switch mode {
                        case .off: "Repeat off"
                        case .one: "Repeat one"
                        case .all: "Repeat all"
                        }
                        self?.postCommandExecuted(command: "repeat", success: true, message: modeText)
                    }
                }
            }
        )

        // Sleep timer
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandSleepTimer,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let minutes = notification.userInfo?["minutes"] as? Int {
                        // Convert minutes to SleepTimer enum, use closest match or default to .thirtyMinutes
                        let timer: SleepTimer = SleepTimer(rawValue: minutes) ?? .thirtyMinutes
                        self?.audioEngine.setSleepTimer(timer)
                        self?.postCommandExecuted(command: "sleep timer", success: true, message: "Sleep timer set for \(minutes) minutes")
                    }
                }
            }
        )

        // Quit command
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .voiceCommandQuit,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.audioEngine.stop()
                    self?.postCommandExecuted(command: "quit", success: true, message: "Playback stopped")
                }
            }
        )

        print("🔔 VoiceCommandHandler: ✅ Registered \(notificationObservers.count) observers")
        print("🔔 VoiceCommandHandler: Observer tokens stored in array to prevent deallocation")
        print("🔔 VoiceCommandHandler: Ready to receive notifications!")
    }

    private func handlePlay() {
        print("🎵 VoiceCommandHandler: Handling Play command")
        print("   - Playback state: \(audioEngine.playbackState)")
        print("   - Current track: \(audioEngine.currentTrack?.title ?? "nil")")
        print("   - AppState configured: \(appState != nil)")

        if audioEngine.playbackState == .paused {
            print("   → Resuming paused track")
            audioEngine.resume()
        } else if audioEngine.playbackState == .stopped || audioEngine.currentTrack == nil {
            print("   → Playing recommended playlist")
            // Play recommended playlist
            Task {
                if let baby = appState?.currentBaby {
                    print("   → Getting personalized playlist for baby: \(baby.name)")
                    let playlist = await aiEngine.getPersonalizedPlaylist(for: baby)
                    audioEngine.play(playlist: playlist)
                } else {
                    // Fallback: play general content without baby profile
                    print("   → No baby profile, playing general playlist")
                    let allTracks = ContentLibraryService.shared.getAllTracks()
                    if !allTracks.isEmpty {
                        let playlist = Playlist(
                            id: UUID(),
                            name: "Quick Play",
                            tracks: Array(allTracks.shuffled().prefix(20)),
                            createdAt: Date()
                        )
                        audioEngine.play(playlist: playlist)
                    } else {
                        print("   ⚠️ No tracks available in library!")
                        postCommandExecuted(command: "play", success: false, message: "No tracks available")
                    }
                }
            }
        } else {
            // Already playing - resume anyway in case it's buffering
            print("   → Resuming playback")
            audioEngine.resume()
        }
    }

    private func handlePause() {
        if audioEngine.playbackState.isPlaying {
            audioEngine.pause()
        } else {
            audioEngine.stop()
        }
    }

    private func handleEmergency() {
        if let baby = appState?.currentBaby {
            emergencyService.activate(for: baby)
        } else {
            // Fallback: play calming ambient sounds immediately
            let calmingTracks = ContentLibraryService.shared.getTracks(for: .ambient)
            if !calmingTracks.isEmpty {
                let playlist = Playlist(
                    id: UUID(),
                    name: "Emergency Calm",
                    tracks: Array(calmingTracks.shuffled().prefix(10)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
            }
        }
    }

    private func handleCategoryCommand(_ category: AudioCategory) async {
        // Get tracks for category - works without baby profile
        let tracks = ContentLibraryService.shared.getTracks(for: category)
        if !tracks.isEmpty {
            // If we have a baby, get personalized playlist
            if let baby = appState?.currentBaby {
                let playlist = await aiEngine.getPersonalizedPlaylist(for: baby, category: category)
                audioEngine.play(playlist: playlist)
            } else {
                // Fallback: just play category tracks
                let playlist = Playlist(
                    id: UUID(),
                    name: category.rawValue,
                    tracks: Array(tracks.shuffled().prefix(20)),
                    createdAt: Date()
                )
                audioEngine.play(playlist: playlist)
            }
        } else {
            postCommandExecuted(command: "category", success: false, message: "No \(category.rawValue) tracks available")
        }
    }

    private func handleMoodCommand(_ mood: AIRecommendationEngine.Mood) async {
        if let baby = appState?.currentBaby {
            let playlist = await aiEngine.getPlaylistForMood(mood, baby: baby)
            audioEngine.play(playlist: playlist)
        } else {
            // Fallback: map mood to category and play
            let category: AudioCategory = switch mood {
            case .sleepy: .ambient
            case .crying: .ambient
            case .playful: .childrenSongs
            case .calm: .classicalMusic
            case .fussy: .natureSounds
            case .restless: .instrumental
            case .overtired: .lullabies
            }
            await handleCategoryCommand(category)
        }
    }

    private func handleAgeRecognized(_ ageMonths: Int) {
        // Update baby's age or create new baby profile
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .month, value: -ageMonths, to: Date()) ?? Date()

        if let baby = appState?.currentBaby {
            // Create new baby with updated birth date
            let updatedBaby = Baby(
                id: baby.id,
                name: baby.name,
                birthDate: birthDate,
                photoData: baby.photoData
            )
            appState?.updateBaby(updatedBaby)
        }
    }

    // MARK: - Track and Playlist Handlers

    private func handlePlayTrack(_ trackTitle: String) async {
        let allTracks = ContentLibraryService.shared.getAllTracks()

        // Find exact or best match
        if let track = findBestMatchingTrack(query: trackTitle, in: allTracks) {
            audioEngine.play(track: track)
            postCommandExecuted(command: "play track", success: true, message: "Playing \(track.title)")
        } else {
            postCommandExecuted(command: "play track", success: false, message: "Couldn't find '\(trackTitle)'")
        }
    }

    private func handleSearchTrack(_ query: String) async {
        let allTracks = ContentLibraryService.shared.getAllTracks()

        // Search for matching tracks
        let matches = allTracks.filter { track in
            track.title.lowercased().contains(query.lowercased()) ||
            track.artist.lowercased().contains(query.lowercased())
        }

        if !matches.isEmpty {
            // Play the best match
            let playlist = Playlist(
                id: UUID(),
                name: "Search: \(query)",
                tracks: Array(matches.prefix(10)),
                createdAt: Date()
            )
            audioEngine.play(playlist: playlist)
            postCommandExecuted(command: "search", success: true, message: "Found \(matches.count) tracks for '\(query)'")
        } else {
            postCommandExecuted(command: "search", success: false, message: "No tracks found for '\(query)'")
        }
    }

    private func handlePlayPlaylist(_ playlistName: String) async {
        let playlists = ContentLibraryService.shared.playlists

        // Find matching playlist
        if let playlist = playlists.first(where: {
            $0.name.lowercased().contains(playlistName.lowercased())
        }) {
            audioEngine.play(playlist: playlist)
            postCommandExecuted(command: "play playlist", success: true, message: "Playing \(playlist.name)")
        } else {
            postCommandExecuted(command: "play playlist", success: false, message: "Couldn't find playlist '\(playlistName)'")
        }
    }

    private func findBestMatchingTrack(query: String, in tracks: [AudioTrack]) -> AudioTrack? {
        let normalizedQuery = query.lowercased()

        // Exact title match
        if let exact = tracks.first(where: { $0.title.lowercased() == normalizedQuery }) {
            return exact
        }

        // Contains match
        if let contains = tracks.first(where: { $0.title.lowercased().contains(normalizedQuery) }) {
            return contains
        }

        // Word overlap match
        let queryWords = Set(normalizedQuery.split(separator: " ").map { String($0) })
        var bestMatch: AudioTrack?
        var bestScore = 0

        for track in tracks {
            let titleWords = Set(track.title.lowercased().split(separator: " ").map { String($0) })
            let overlap = queryWords.intersection(titleWords).count
            if overlap > bestScore {
                bestScore = overlap
                bestMatch = track
            }
        }

        return bestScore > 0 ? bestMatch : nil
    }
}
