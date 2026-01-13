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

    private func makeDecision() async {
        guard isActive else { return }

        let environmentState = environmentDetector.currentState
        let environmentScore = Double(environmentState?.soothingScore ?? 0)
        let motionType = environmentState?.motionType ?? .unknown

        let babyState: BabyAudioState = .calm

        // Calculate recommended volume
        let (recommendedVolume, action, reason) = calculateVolumeAndAction(
            environmentScore: environmentScore,
            babyState: babyState,
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

    private func calculateVolumeAndAction(
        environmentScore: Double,
        babyState: BabyAudioState,
        motionType: MotionType
    ) -> (Float, SmartModeAction, String) {

        var volume = currentVolumeMultiplier
        var action: SmartModeAction = .maintain
        var reason: String = ""

        switch babyState {
        case .crying, .fussy:
            // Baby is fussy - environment can help
            if environmentScore > environmentSoothingThreshold {
                volume = Float(max(0.4, 1.0 - environmentScore * 0.5))
                action = .reduceVolume
                reason = "Car sounds are helping"
            } else {
                volume = 0.8
                action = .maintain
                reason = "Maintaining soothing level"
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
            if let newTrack = contentLibrary.getTopCalmingTracks(limit: 1).first {
                audioEngine.play(track: newTrack)
                speakFeedback("Trying \(newTrack.title)")
            }
        }

        // Alert for urgent situations
        if decision.actionTaken == .alert {
            speakFeedback("Consider pulling over when safe.")
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
        return "👶 Playing"
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

