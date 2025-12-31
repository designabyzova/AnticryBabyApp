//
//  SpeechRecognitionService.swift
//  BabyInCarApp
//
//  Voice input service for hands-free control
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
            // Configure audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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

        // Restore audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Voice Command Processing

    private func processVoiceCommand(_ text: String) {
        let lowercased = text.lowercased()
        var commandRecognized = false

        // Age extraction
        if let age = extractAge(from: lowercased) {
            NotificationCenter.default.post(
                name: .voiceAgeRecognized,
                object: nil,
                userInfo: ["age": age]
            )
            return
        }

        // Category commands (check first for more specific matches)
        for category in AudioCategory.allCases {
            if lowercased.contains(category.rawValue.lowercased()) {
                NotificationCenter.default.post(
                    name: .voiceCommandCategory,
                    object: nil,
                    userInfo: ["category": category]
                )
                return
            }
        }

        // Mood commands
        for mood in AIRecommendationEngine.Mood.allCases {
            if lowercased.contains(mood.rawValue.lowercased()) {
                NotificationCenter.default.post(
                    name: .voiceCommandMood,
                    object: nil,
                    userInfo: ["mood": mood]
                )
                return
            }
        }

        // Playback commands
        if lowercased.contains("play") || lowercased.contains("start") {
            NotificationCenter.default.post(name: .voiceCommandPlay, object: nil)
            commandRecognized = true
        } else if lowercased.contains("pause") || lowercased.contains("stop") {
            NotificationCenter.default.post(name: .voiceCommandPause, object: nil)
            commandRecognized = true
        } else if lowercased.contains("next") || lowercased.contains("skip") {
            NotificationCenter.default.post(name: .voiceCommandNext, object: nil)
            commandRecognized = true
        } else if lowercased.contains("previous") || lowercased.contains("back") {
            NotificationCenter.default.post(name: .voiceCommandPrevious, object: nil)
            commandRecognized = true
        } else if lowercased.contains("emergency") || lowercased.contains("cry stop") || lowercased.contains("help") {
            NotificationCenter.default.post(name: .voiceCommandEmergency, object: nil)
            commandRecognized = true
        } else if lowercased.contains("louder") || lowercased.contains("volume up") || lowercased.contains("turn up") {
            NotificationCenter.default.post(name: .voiceCommandVolumeUp, object: nil)
            commandRecognized = true
        } else if lowercased.contains("quieter") || lowercased.contains("volume down") || lowercased.contains("turn down") || lowercased.contains("softer") {
            NotificationCenter.default.post(name: .voiceCommandVolumeDown, object: nil)
            commandRecognized = true
        } else if lowercased.contains("mute") || lowercased.contains("silence") {
            NotificationCenter.default.post(name: .voiceCommandMute, object: nil)
            commandRecognized = true
        }

        // Notify if no command was recognized
        if !commandRecognized {
            NotificationCenter.default.post(
                name: .voiceCommandNotRecognized,
                object: nil,
                userInfo: ["text": text]
            )
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
    static let voiceAgeRecognized = Notification.Name("voiceAgeRecognized")
    static let voiceCommandPlay = Notification.Name("voiceCommandPlay")
    static let voiceCommandPause = Notification.Name("voiceCommandPause")
    static let voiceCommandNext = Notification.Name("voiceCommandNext")
    static let voiceCommandPrevious = Notification.Name("voiceCommandPrevious")
    static let voiceCommandEmergency = Notification.Name("voiceCommandEmergency")
    static let voiceCommandVolumeUp = Notification.Name("voiceCommandVolumeUp")
    static let voiceCommandVolumeDown = Notification.Name("voiceCommandVolumeDown")
    static let voiceCommandMute = Notification.Name("voiceCommandMute")
    static let voiceCommandCategory = Notification.Name("voiceCommandCategory")
    static let voiceCommandMood = Notification.Name("voiceCommandMood")
    // Feedback notifications
    static let voiceCommandExecuted = Notification.Name("voiceCommandExecuted")
    static let voiceCommandNotRecognized = Notification.Name("voiceCommandNotRecognized")
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

    private init() {
        setupNotificationObservers()
    }

    func configure(with appState: AppState) {
        self.appState = appState
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
        NotificationCenter.default.addObserver(
            forName: .voiceCommandPlay,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlay()
                self?.postCommandExecuted(command: "play", success: true, message: "Playing audio")
            }
        }

        NotificationCenter.default.addObserver(
            forName: .voiceCommandPause,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePause()
                self?.postCommandExecuted(command: "pause", success: true, message: "Audio paused")
            }
        }

        NotificationCenter.default.addObserver(
            forName: .voiceCommandNext,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.audioEngine.next()
                self?.postCommandExecuted(command: "next", success: true, message: "Skipped to next track")
            }
        }

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
    }

    private func handlePlay() {
        if audioEngine.playbackState == .paused {
            audioEngine.resume()
        } else if audioEngine.currentTrack == nil {
            // Play recommended playlist
            Task {
                if let baby = appState?.currentBaby {
                    let playlist = await aiEngine.getPersonalizedPlaylist(for: baby)
                    audioEngine.play(playlist: playlist)
                }
            }
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
        guard let baby = appState?.currentBaby else { return }
        emergencyService.activate(for: baby)
    }

    private func handleCategoryCommand(_ category: AudioCategory) async {
        guard let baby = appState?.currentBaby else { return }
        let playlist = await aiEngine.getPersonalizedPlaylist(for: baby, category: category)
        audioEngine.play(playlist: playlist)
    }

    private func handleMoodCommand(_ mood: AIRecommendationEngine.Mood) async {
        guard let baby = appState?.currentBaby else { return }
        let playlist = await aiEngine.getPlaylistForMood(mood, baby: baby)
        audioEngine.play(playlist: playlist)
    }

    private func handleAgeRecognized(_ ageMonths: Int) {
        // Update baby's age or create new baby profile
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .month, value: -ageMonths, to: Date()) ?? Date()

        if var baby = appState?.currentBaby {
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
}
