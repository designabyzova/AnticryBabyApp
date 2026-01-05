//
//  SmartCarPlayController.swift
//  BabyInCarApp
//
//  Intelligent CarPlay controller that adapts music based on baby sounds
//  AND environmental signals (car engine, road noise, motion patterns).
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

// MARK: - Smart Mode Decision

struct SmartModeDecision: Codable {
    let timestamp: Date
    let recommendedVolume: Float
    let reason: String
    let environmentScore: Double
    let babyState: BabyAudioState
    let motionType: MotionType
    let actionTaken: SmartModeAction
}

enum SmartModeAction: String, Codable {
    case reduceVolume = "reduce_volume"        // Environment is soothing, reduce music
    case increaseVolume = "increase_volume"    // Environment quiet, increase music
    case changeTrack = "change_track"          // Need different sound type
    case enableCarSound = "enable_car_sound"   // Use car engine sound
    case maintain = "maintain"                 // Keep current settings
    case alert = "alert"                       // Alert parent (distress detected)
}

enum BabyAudioState: String, Codable {
    case calm = "calm"
    case fussy = "fussy"
    case crying = "crying"
    case sleeping = "sleeping"
    case unknown = "unknown"
}

// MARK: - Smart CarPlay Controller

@MainActor
class SmartCarPlayController: ObservableObject {
    static let shared = SmartCarPlayController()

    // MARK: - Dependencies

    private let cryDetectionService = CryDetectionService.shared
    private let environmentDetector = EnvironmentSoundDetector.shared
    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared
    private let researchKnowledge = ResearchKnowledgeBase.shared

    // Optional BabyMIM integration - commented out until file is added to project
    // private var babyMoodIntelligence: BabyMoodIntelligence? {
    //     BabyMoodIntelligence.shared
    // }

    // MARK: - Published State

    @Published var isSmartModeEnabled: Bool = false
    @Published var isActive: Bool = false
    @Published var currentDecision: SmartModeDecision?
    @Published var currentVolumeMultiplier: Float = 1.0
    @Published var decisionHistory: [SmartModeDecision] = []
    @Published var statusMessage: String = "Smart Mode Ready"
    @Published var lastVoiceFeedback: String?

    // MARK: - Configuration

    var enableVoiceFeedback: Bool = true
    var voiceFeedbackVolume: Float = 0.3
    var minVolume: Float = 0.2
    var maxVolume: Float = 1.0
    var decisionInterval: TimeInterval = 5.0 // seconds between decisions

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var decisionTimer: Timer?
    private var speechSynthesizer: AVSpeechSynthesizer?

    // Thresholds
    private let cryDetectionThreshold: Double = 0.6
    private let environmentSoothingThreshold: Double = 0.5
    private let volumeReductionFactor: Float = 0.6

    // MARK: - Initialization

    private init() {
        setupSpeechSynthesizer()
    }

    private func setupSpeechSynthesizer() {
        speechSynthesizer = AVSpeechSynthesizer()
    }

    // MARK: - Smart Mode Control

    func enableSmartMode() async throws {
        guard !isActive else { return }

        // Start environment detection
        try await environmentDetector.startMonitoring()

        // Start cry detection if not already
        if !cryDetectionService.isMonitoring {
            try await cryDetectionService.startMonitoring()
        }

        // Subscribe to updates
        setupSubscriptions()

        // Start decision timer
        startDecisionLoop()

        isSmartModeEnabled = true
        isActive = true
        statusMessage = "Smart Mode Active"

        speakFeedback("Smart car mode activated")
    }

    func disableSmartMode() {
        decisionTimer?.invalidate()
        decisionTimer = nil

        environmentDetector.stopMonitoring()

        cancellables.removeAll()

        isSmartModeEnabled = false
        isActive = false
        currentVolumeMultiplier = 1.0
        statusMessage = "Smart Mode Disabled"

        speakFeedback("Smart car mode disabled")
    }

    // MARK: - Decision Making

    private func setupSubscriptions() {
        // Listen to environment updates
        environmentDetector.$currentState
            .compactMap { $0 }
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleEnvironmentUpdate(state)
                }
            }
            .store(in: &cancellables)

        // Listen to cry detection
        cryDetectionService.$isCryDetected
            .sink { [weak self] isCrying in
                Task { @MainActor in
                    self?.handleCryStateChange(isCrying: isCrying)
                }
            }
            .store(in: &cancellables)
    }

    private func startDecisionLoop() {
        decisionTimer = Timer.scheduledTimer(withTimeInterval: decisionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.makeDecision()
            }
        }
    }

    private func handleEnvironmentUpdate(_ state: EnvironmentState) {
        // Update status message with environment info
        statusMessage = state.summary
    }

    private func handleCryStateChange(isCrying: Bool) {
        if isCrying {
            // Immediate response to crying
            Task {
                await makeDecision()
            }
        }
    }

    private func makeDecision() async {
        guard isActive else { return }

        let environmentState = environmentDetector.currentState
        let environmentScore = Double(environmentState?.soothingScore ?? 0)
        let motionType = environmentState?.motionType ?? .unknown

        let babyState = determineBabyState()
        let cryType = cryDetectionService.cryType
        let cryIntensity = cryDetectionService.cryIntensity

        // Calculate recommended volume
        let (recommendedVolume, action, reason) = calculateVolumeAndAction(
            environmentScore: environmentScore,
            babyState: babyState,
            cryType: cryType,
            cryIntensity: cryIntensity,
            motionType: motionType
        )

        // Create decision record
        let decision = SmartModeDecision(
            timestamp: Date(),
            recommendedVolume: recommendedVolume,
            reason: reason,
            environmentScore: environmentScore,
            babyState: babyState,
            motionType: motionType,
            actionTaken: action
        )

        // Apply decision
        applyDecision(decision)

        // Store decision
        currentDecision = decision
        decisionHistory.append(decision)
        if decisionHistory.count > 100 {
            decisionHistory.removeFirst()
        }
    }

    private func determineBabyState() -> BabyAudioState {
        if cryDetectionService.isCryDetected {
            let intensity = cryDetectionService.cryIntensity
            if intensity > 0.7 {
                return .crying
            } else {
                return .fussy
            }
        }

        // Check if baby has been quiet for a while
        // Note: quietDuration not available in current CryPatternMetrics, using averagePauseDuration as proxy
        if let latestPatterns = cryDetectionService.latestPatternMetrics {
            if latestPatterns.averagePauseDuration > 300 { // 5 minutes of quiet
                return .sleeping
            }
        }

        return .calm
    }

    private func calculateVolumeAndAction(
        environmentScore: Double,
        babyState: BabyAudioState,
        cryType: CryType,
        cryIntensity: Double,
        motionType: MotionType
    ) -> (Float, SmartModeAction, String) {

        var volume = currentVolumeMultiplier
        var action: SmartModeAction = .maintain
        var reason: String = ""

        switch babyState {
        case .crying:
            // Baby is crying - need active soothing
            // Environment helps, but we need music too
            let envHelp = Float(environmentScore) * 0.3
            volume = max(0.7, 1.0 - envHelp)
            action = .increaseVolume
            reason = "Baby is crying - keeping soothing sounds audible"

            // Consider changing track if current isn't working
            if cryIntensity > 0.8 && shouldChangeTrack() {
                action = .changeTrack
                reason = "High distress detected - trying a different sound"
            }

        case .fussy:
            // Baby is fussy - environment can help
            if environmentScore > environmentSoothingThreshold {
                volume = Float(max(0.4, 1.0 - environmentScore * 0.5))
                action = .reduceVolume
                reason = "Baby is fussy but car sounds are helping"
            } else {
                volume = 0.8
                action = .maintain
                reason = "Baby is fussy - maintaining soothing level"
            }

        case .calm, .sleeping:
            // Baby is calm - let environment do the work if possible
            if environmentScore > 0.7 {
                volume = max(minVolume, Float(1.0 - environmentScore * Double(volumeReductionFactor)))
                action = .reduceVolume
                reason = "Baby is calm - car sounds providing soothing"
            } else if environmentScore > 0.4 {
                volume = 0.6
                action = .maintain
                reason = "Baby is calm - gentle background music"
            } else {
                volume = 0.5
                action = .maintain
                reason = "Quiet environment - maintaining gentle sounds"
            }

        case .unknown:
            // Default behavior
            if environmentScore > 0.6 {
                volume = Float(1.0 - environmentScore * 0.4)
                action = .reduceVolume
                reason = "Good car environment detected"
            } else {
                volume = 0.7
                action = .maintain
                reason = "Monitoring baby sounds"
            }
        }

        // Clamp volume
        volume = max(minVolume, min(maxVolume, volume))

        // Add motion context to reason
        if motionType == .highway && environmentScore > 0.7 {
            reason += " (highway cruise providing excellent soothing)"
        } else if motionType == .stopped && environmentScore < 0.3 {
            reason += " (car stopped - using more music)"
        }

        return (volume, action, reason)
    }

    private func shouldChangeTrack() -> Bool {
        // Check if we've been playing the same sound for a while without success
        // This would integrate with BabyMIM effectiveness tracking
        return false // Placeholder - implement with BabyMIM
    }

    private func applyDecision(_ decision: SmartModeDecision) {
        // Update volume multiplier
        let volumeChange = decision.recommendedVolume - currentVolumeMultiplier
        currentVolumeMultiplier = decision.recommendedVolume

        // Update status
        statusMessage = decision.reason

        // Apply volume to audio engine
        audioEngine.setVolume(decision.recommendedVolume)

        // Voice feedback for significant changes
        if abs(volumeChange) > 0.2 {
            let feedbackMessage: String
            if volumeChange < 0 {
                feedbackMessage = "Lowering music - car sounds are helping"
            } else {
                feedbackMessage = "Increasing soothing sounds"
            }
            speakFeedback(feedbackMessage)
        }

        // Handle track change if needed
        if decision.actionTaken == .changeTrack {
            Task {
                await handleTrackChange(for: cryDetectionService.cryType)
            }
        }

        // Alert for urgent situations
        if decision.actionTaken == .alert {
            speakFeedback("Baby seems distressed. Consider pulling over when safe.")
        }
    }

    private func handleTrackChange(for cryType: CryType) async {
        // Get recommendation based on cry type
        let strategy = cryType.soothingStrategy
        var newTrack: AudioTrack?

        switch strategy {
        case .urgent:
            // Use attention-grabbing sounds
            newTrack = contentLibrary.allTracks.first { $0.generatorType == .shushing }
        case .sleepInduction:
            // Use sleep-promoting sounds
            newTrack = contentLibrary.allTracks.first { $0.generatorType == .womb }
        case .distraction:
            // Use engaging sounds
            newTrack = contentLibrary.allTracks.first { $0.generatorType == .musicBox }
        default:
            // Use high-calming-score sound
            newTrack = contentLibrary.getTopCalmingTracks(limit: 1).first
        }

        if let track = newTrack {
            audioEngine.play(track: track)
            speakFeedback("Trying \(track.title)")
        }
    }

    // MARK: - Voice Feedback

    private func speakFeedback(_ message: String) {
        guard enableVoiceFeedback else { return }

        lastVoiceFeedback = message

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = voiceFeedbackVolume

        speechSynthesizer?.speak(utterance)
    }

    // MARK: - Analytics & Reporting

    func getSessionSummary() -> String {
        guard !decisionHistory.isEmpty else {
            return "No smart mode activity recorded"
        }

        let volumeReductions = decisionHistory.filter { $0.actionTaken == .reduceVolume }.count
        let volumeIncreases = decisionHistory.filter { $0.actionTaken == .increaseVolume }.count
        let trackChanges = decisionHistory.filter { $0.actionTaken == .changeTrack }.count

        let avgEnvironmentScore = decisionHistory.reduce(0) { $0 + $1.environmentScore } / Double(decisionHistory.count)

        return """
        Smart Mode Session Summary:
        • Decisions made: \(decisionHistory.count)
        • Volume reductions: \(volumeReductions)
        • Volume increases: \(volumeIncreases)
        • Track changes: \(trackChanges)
        • Avg environment soothing: \(Int(avgEnvironmentScore * 100))%
        """
    }

    /// Get explanation for current state (for parent display)
    func getCurrentExplanation() -> String {
        guard let decision = currentDecision else {
            return "Smart mode is analyzing the environment..."
        }

        let envExplanation = researchKnowledge.getCarEnvironmentExplanation(soothingScore: decision.environmentScore)

        return """
        **Current Status**
        \(decision.reason)

        **Environment Analysis**
        \(envExplanation)

        **Volume Level**
        \(Int(decision.recommendedVolume * 100))% of maximum
        """
    }
}

// MARK: - CarPlay Template Support

extension SmartCarPlayController {

    /// Get compact status for CarPlay display
    var carPlayStatus: String {
        if !isActive {
            return "Smart Mode Off"
        }

        let envScore = environmentDetector.currentState?.soothingScore ?? 0
        let volumePercent = Int(currentVolumeMultiplier * 100)

        if envScore > 0.7 {
            return "🚗 Car soothing • \(volumePercent)%"
        } else if envScore > 0.4 {
            return "🎵 Playing • \(volumePercent)%"
        } else {
            return "🔊 Full soothing • \(volumePercent)%"
        }
    }

    /// Get baby state indicator for CarPlay
    var babyStateIndicator: String {
        let state = determineBabyState()
        switch state {
        case .calm:
            return "😊 Calm"
        case .sleeping:
            return "😴 Sleeping"
        case .fussy:
            return "😟 Fussy"
        case .crying:
            return "😢 Crying"
        case .unknown:
            return "👶 Monitoring"
        }
    }

    /// Get environment state indicator for CarPlay
    var environmentIndicator: String {
        guard let state = environmentDetector.currentState else {
            return "📊 Analyzing..."
        }

        let score = Int(state.soothingScore * 100)
        switch state.motionType {
        case .highway:
            return "🛣️ Highway \(score)%"
        case .city:
            return "🏙️ City \(score)%"
        case .stopped:
            return "🅿️ Parked \(score)%"
        default:
            return "🚗 Driving \(score)%"
        }
    }
}

// MARK: - Voice Control Integration

extension SmartCarPlayController {

    /// Enable voice control (enabled by default for CarPlay)
    func enableVoiceControl() {
        // Voice control is automatically enabled when app launches in CarPlay
        // Subscribe to voice command notifications
        setupVoiceCommandListeners()
        speakFeedback("Voice control ready. Say commands like 'play fairy tales' or 'emergency mode'.")
    }

    private func setupVoiceCommandListeners() {
        // Listen for voice commands and process them with LLM
        NotificationCenter.default.addObserver(
            forName: .voiceCommandExecuted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let _ = userInfo["command"] as? String,
                  let success = userInfo["success"] as? Bool,
                  let message = userInfo["message"] as? String else { return }

            Task { @MainActor in
                // Provide voice feedback in CarPlay
                if self?.enableVoiceFeedback == true {
                    if success {
                        self?.speakFeedback(message)
                    } else {
                        self?.speakFeedback("Sorry, \(message)")
                    }
                }
            }
        }

        // Listen for unrecognized commands and try to help
        NotificationCenter.default.addObserver(
            forName: .voiceCommandNotRecognized,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let text = notification.userInfo?["text"] as? String else { return }

            Task { @MainActor in
                // Provide helpful feedback
                self?.speakFeedback("I didn't understand '\(text)'. Try saying 'play lullabies' or 'emergency mode'.")
            }
        }
    }

    /// Process a voice command directly (for Siri/CarPlay integration)
    func processVoiceCommand(_ text: String) async {
        let parsedCommand = await VoiceCommandLLMService.shared.parseCommand(text)

        // Log the parsed command
        print("🎤 CarPlay Voice Command: \(text) → \(parsedCommand.intent) (\(Int(parsedCommand.confidence * 100))% confident)")

        // Provide feedback about what was understood
        switch parsedCommand.intent {
        case .playCategory(let category):
            speakFeedback("Playing \(category.rawValue)")
        case .playMood(let mood):
            speakFeedback("Setting mood to \(mood.rawValue)")
        case .playTrack(let title):
            speakFeedback("Playing \(title)")
        case .emergency:
            speakFeedback("Activating emergency mode")
        case .unknown:
            speakFeedback("I didn't understand. Try 'play classical' or 'next track'.")
        default:
            break
        }
    }

    /// Get available voice commands for CarPlay help display
    static var availableVoiceCommands: [String] {
        return [
            // Playback
            "Play / Pause / Stop",
            "Next / Previous track",
            "Volume up / down",

            // Content
            "Play fairy tales",
            "Play classical music",
            "Play piano music",
            "Play lullabies",
            "Play white noise",
            "Play podcasts",
            "Play nature sounds",

            // Moods
            "Baby is sleepy",
            "Baby is crying",
            "Calm mode",

            // Special
            "Emergency mode",
            "Shuffle on / off",
            "Repeat this song",
            "Set sleep timer for 30 minutes",

            // Search
            "Play [song name]",
            "Find [search query]"
        ]
    }
}
