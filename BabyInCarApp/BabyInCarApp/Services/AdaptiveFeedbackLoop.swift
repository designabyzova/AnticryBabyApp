//
//  AdaptiveFeedbackLoop.swift
//  BabyInCarApp
//
//  Continuous learning system that monitors soothing outcomes and
//  updates baby profiles to improve future recommendations.
//

import Foundation
import Combine

// MARK: - Feedback Loop State

/// Current state of an active soothing session
struct ActiveSoothingState {
    let sessionId: UUID
    let babyId: UUID
    let startTime: Date
    var cryType: CryType
    var initialIntensity: Double
    var currentIntensity: Double
    var soundsPlayed: [SoundPlayRecord]
    var recommendation: SoothingRecommendation?
    var phaseHistory: [PhaseRecord]

    struct SoundPlayRecord: Codable {
        let sound: GeneratorType
        let startTime: Date
        var endTime: Date?
        var effectivenessObserved: Double? // 0-1
    }

    struct PhaseRecord: Codable {
        let phase: String
        let timestamp: Date
        let intensity: Double
    }
}

// MARK: - Learning Event

/// Events that trigger learning updates
enum LearningEvent {
    case cryIntensityChanged(from: Double, to: Double)
    case soundStarted(GeneratorType)
    case soundEnded(GeneratorType, effectiveness: Double)
    case sessionEnded(success: Bool, duration: TimeInterval)
    case parentFeedback(rating: Int, comment: String?)
    case explicitHelped // "It Helped!" button
    case explicitNotHelped // "Not Working" button
}

// MARK: - Learning Outcome

/// Outcome of a learning update
struct LearningOutcome {
    let event: String
    let profileUpdates: [String]
    let confidenceChange: Double
    let newInsights: [ParentInsight]
}

// MARK: - Adaptive Feedback Loop Service

/// Monitors soothing sessions in real-time and learns from outcomes
@MainActor
class AdaptiveFeedbackLoop: ObservableObject {
    static let shared = AdaptiveFeedbackLoop()

    // MARK: - Dependencies

    private let profileManager = BabyMoodProfileManager.shared
    private let llmEngine = BabyMoodLLMEngine.shared
    private let cryDetectionService = CryDetectionService.shared
    private let effectivenessManager = EffectivenessManager.shared

    // MARK: - Published State

    @Published var isMonitoring: Bool = false
    @Published var currentSession: ActiveSoothingState?
    @Published var recentOutcomes: [LearningOutcome] = []
    @Published var currentEffectiveness: Double = 0

    // MARK: - Monitoring State

    private var monitoringTimer: Timer?
    private var intensityHistory: [Double] = []
    private let intensityHistorySize = 30 // THERMAL FIX: Reduced from 60 to 30 (1 min at 0.5Hz instead of 1Hz)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Learning Parameters

    private let intensityImprovementThreshold = 0.2 // 20% reduction = working
    private let successThreshold = 0.3 // Below 30% intensity = success
    private let learningRate = 0.1 // How much to adjust scores per event

    private init() {
        setupCryDetectionBinding()
    }

    // MARK: - Session Management

    /// Start monitoring a soothing session
    func startSession(
        for babyId: UUID,
        cryType: CryType,
        initialIntensity: Double,
        recommendation: SoothingRecommendation?
    ) {
        let session = ActiveSoothingState(
            sessionId: UUID(),
            babyId: babyId,
            startTime: Date(),
            cryType: cryType,
            initialIntensity: initialIntensity,
            currentIntensity: initialIntensity,
            soundsPlayed: [],
            recommendation: recommendation,
            phaseHistory: [
                ActiveSoothingState.PhaseRecord(
                    phase: "started",
                    timestamp: Date(),
                    intensity: initialIntensity
                )
            ]
        )

        currentSession = session
        isMonitoring = true
        intensityHistory = [initialIntensity]

        startMonitoringLoop()
    }

    /// End the current session
    func endSession(wasSuccessful: Bool) {
        guard var session = currentSession else { return }

        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        // Calculate session duration
        let duration = Date().timeIntervalSince(session.startTime)

        // Record final phase
        session.phaseHistory.append(ActiveSoothingState.PhaseRecord(
            phase: wasSuccessful ? "success" : "ended",
            timestamp: Date(),
            intensity: session.currentIntensity
        ))

        // Process learning
        let outcome = processSessionEnd(session: session, success: wasSuccessful, duration: duration)
        recentOutcomes.insert(outcome, at: 0)

        // Trim outcomes history
        if recentOutcomes.count > 20 {
            recentOutcomes = Array(recentOutcomes.prefix(20))
        }

        // Update LLM engine's session history
        let soothingSession = SoothingSession(babyId: session.babyId)
        var mutableSession = soothingSession
        mutableSession.endTime = Date()
        mutableSession.cryType = session.cryType
        mutableSession.strategy = session.recommendation?.primaryStrategy
        mutableSession.soundsUsed = session.soundsPlayed.map { $0.sound }
        mutableSession.wasSuccessful = wasSuccessful
        mutableSession.calmingDuration = duration

        llmEngine.recordSessionOutcome(mutableSession)

        currentSession = nil
    }

    // MARK: - Real-time Monitoring

    private func startMonitoringLoop() {
        // THERMAL FIX: Increased interval from 1s to 2s
        // Cry intensity changes slowly enough that 2s sampling is sufficient
        // This reduces CPU cycles by 50% during active soothing sessions
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.monitoringTick()
            }
        }
    }

    private func monitoringTick() {
        guard var session = currentSession else { return }

        // Get current cry intensity
        let currentIntensity = cryDetectionService.cryIntensity
        let previousIntensity = session.currentIntensity

        // Update session
        session.currentIntensity = currentIntensity
        currentSession = session

        // Add to history
        intensityHistory.append(currentIntensity)
        if intensityHistory.count > intensityHistorySize {
            intensityHistory.removeFirst()
        }

        // Calculate effectiveness
        updateEffectivenessScore()

        // Check for significant changes
        if abs(currentIntensity - previousIntensity) > 0.1 {
            processEvent(.cryIntensityChanged(from: previousIntensity, to: currentIntensity))
        }

        // Auto-detect success
        if currentIntensity < successThreshold && previousIntensity >= successThreshold {
            // Baby appears to have calmed
            session.phaseHistory.append(ActiveSoothingState.PhaseRecord(
                phase: "calmed",
                timestamp: Date(),
                intensity: currentIntensity
            ))
            currentSession = session
        }
    }

    private func updateEffectivenessScore() {
        guard let session = currentSession else {
            currentEffectiveness = 0
            return
        }

        // Calculate effectiveness based on intensity reduction
        let reduction = session.initialIntensity - session.currentIntensity
        let maxPossibleReduction = session.initialIntensity

        if maxPossibleReduction > 0 {
            currentEffectiveness = max(0, min(1, reduction / maxPossibleReduction))
        } else {
            currentEffectiveness = 0
        }
    }

    // MARK: - Sound Tracking

    /// Record when a sound starts playing
    func recordSoundStarted(_ sound: GeneratorType) {
        guard var session = currentSession else { return }

        let record = ActiveSoothingState.SoundPlayRecord(
            sound: sound,
            startTime: Date(),
            endTime: nil,
            effectivenessObserved: nil
        )

        session.soundsPlayed.append(record)
        currentSession = session

        processEvent(.soundStarted(sound))
    }

    /// Record when a sound stops playing
    func recordSoundEnded(_ sound: GeneratorType) {
        guard var session = currentSession else { return }

        if let index = session.soundsPlayed.lastIndex(where: { $0.sound == sound && $0.endTime == nil }) {
            let startIntensity = session.phaseHistory
                .filter { $0.timestamp <= session.soundsPlayed[index].startTime }
                .last?.intensity ?? session.initialIntensity

            let effectiveness = (startIntensity - session.currentIntensity) / max(startIntensity, 0.1)

            session.soundsPlayed[index].endTime = Date()
            session.soundsPlayed[index].effectivenessObserved = max(0, min(1, effectiveness))

            currentSession = session

            processEvent(.soundEnded(sound, effectiveness: effectiveness))
        }
    }

    // MARK: - Parent Feedback

    /// Record explicit "It Helped!" feedback
    func recordHelped() {
        processEvent(.explicitHelped)

        // Also record in effectiveness manager
        if let session = currentSession,
           let lastSound = session.soundsPlayed.last {
            // Create a mock track for effectiveness recording
            let track = AudioTrack(
                title: lastSound.sound.rawValue,
                category: lastSound.sound.category,
                duration: 300,
                calmingScore: 0.8,
                audioSourceType: .generated,
                generatorType: lastSound.sound
            )
            effectivenessManager.recordHelped(
                track: track,
                cryType: session.cryType,
                playDuration: Date().timeIntervalSince(lastSound.startTime)
            )
        }

        // End session as successful
        endSession(wasSuccessful: true)
    }

    /// Record explicit "Not Working" feedback
    func recordNotHelped() {
        processEvent(.explicitNotHelped)

        // Don't end session - continue trying
    }

    /// Record parent rating and comment
    func recordParentFeedback(rating: Int, comment: String?) {
        processEvent(.parentFeedback(rating: rating, comment: comment))
    }

    // MARK: - Event Processing

    private func processEvent(_ event: LearningEvent) {
        guard let session = currentSession,
              var profile = profileManager.profiles.values.first(where: { $0.babyId == session.babyId }) else {
            return
        }

        var updates: [String] = []
        var confidenceChange = 0.0

        switch event {
        case .cryIntensityChanged(let from, let to):
            if to < from - intensityImprovementThreshold {
                // Intensity decreased significantly - current approach working
                if let lastSound = session.soundsPlayed.last {
                    let key = lastSound.sound.rawValue
                    let currentScore = profile.soundEffectiveness[key] ?? 0.5
                    profile.soundEffectiveness[key] = min(1, currentScore + learningRate)
                    updates.append("Increased effectiveness of \(lastSound.sound.rawValue)")
                }
                confidenceChange = 0.01
            } else if to > from + intensityImprovementThreshold {
                // Intensity increased - approach not working well
                if let lastSound = session.soundsPlayed.last {
                    let key = lastSound.sound.rawValue
                    let currentScore = profile.soundEffectiveness[key] ?? 0.5
                    profile.soundEffectiveness[key] = max(0, currentScore - learningRate * 0.5)
                    updates.append("Decreased effectiveness of \(lastSound.sound.rawValue)")
                }
            }

        case .soundStarted(let sound):
            // Record that this sound was tried for this cry type
            profile.updateCryingPattern(at: Date())
            updates.append("Recorded \(sound.rawValue) attempt")

        case .soundEnded(let sound, let effectiveness):
            // Update sound effectiveness based on observed results
            let key = sound.rawValue
            let currentScore = profile.soundEffectiveness[key] ?? 0.5
            let newScore = currentScore * 0.7 + effectiveness * 0.3
            profile.soundEffectiveness[key] = newScore
            updates.append("Updated \(sound.rawValue) effectiveness to \(Int(newScore * 100))%")

        case .sessionEnded(let success, _):
            if success {
                profile.recordSession(
                    cryType: session.cryType,
                    soundsUsed: session.soundsPlayed.map { $0.sound },
                    wasSuccessful: true,
                    calmingTime: Date().timeIntervalSince(session.startTime),
                    intensity: session.initialIntensity
                )
                updates.append("Recorded successful session")
                confidenceChange = 0.02
            }

        case .parentFeedback(let rating, _):
            if rating >= 4 {
                // Positive feedback - boost recent sounds
                for record in session.soundsPlayed.suffix(3) {
                    let key = record.sound.rawValue
                    let currentScore = profile.soundEffectiveness[key] ?? 0.5
                    profile.soundEffectiveness[key] = min(1, currentScore + learningRate)
                }
                updates.append("Boosted effectiveness of recent sounds based on positive feedback")
            } else if rating <= 2 {
                // Negative feedback - reduce recent sounds
                for record in session.soundsPlayed.suffix(3) {
                    let key = record.sound.rawValue
                    let currentScore = profile.soundEffectiveness[key] ?? 0.5
                    profile.soundEffectiveness[key] = max(0, currentScore - learningRate)
                }
                updates.append("Reduced effectiveness of recent sounds based on negative feedback")
            }
            confidenceChange = 0.01

        case .explicitHelped:
            // Strong positive signal
            for record in session.soundsPlayed {
                let key = record.sound.rawValue
                let currentScore = profile.soundEffectiveness[key] ?? 0.5
                profile.soundEffectiveness[key] = min(1, currentScore + learningRate * 2)
            }
            profile.updatePersonalityTrait(.soothingResponsiveness, value: 0.6)
            updates.append("Strongly boosted all sounds from session")
            confidenceChange = 0.03

        case .explicitNotHelped:
            // Strong negative signal for current sound
            if let lastSound = session.soundsPlayed.last {
                let key = lastSound.sound.rawValue
                let currentScore = profile.soundEffectiveness[key] ?? 0.5
                profile.soundEffectiveness[key] = max(0, currentScore - learningRate * 1.5)
                updates.append("Reduced effectiveness of \(lastSound.sound.rawValue)")
            }
        }

        // Update profile confidence
        profile.profileConfidence = min(0.95, profile.profileConfidence + confidenceChange)

        // Save updated profile
        profileManager.updateProfile(profile)

        // Create learning outcome
        let outcome = LearningOutcome(
            event: describeEvent(event),
            profileUpdates: updates,
            confidenceChange: confidenceChange,
            newInsights: []
        )

        Task { @MainActor in
            self.recentOutcomes.insert(outcome, at: 0)
            if self.recentOutcomes.count > 20 {
                self.recentOutcomes = Array(self.recentOutcomes.prefix(20))
            }
        }
    }

    private func processSessionEnd(session: ActiveSoothingState, success: Bool, duration: TimeInterval) -> LearningOutcome {
        guard var profile = profileManager.profiles.values.first(where: { $0.babyId == session.babyId }) else {
            return LearningOutcome(
                event: "Session ended",
                profileUpdates: [],
                confidenceChange: 0,
                newInsights: []
            )
        }

        var updates: [String] = []
        var insights: [ParentInsight] = []

        if success {
            // Record successful session
            profile.recordSession(
                cryType: session.cryType,
                soundsUsed: session.soundsPlayed.map { $0.sound },
                wasSuccessful: true,
                calmingTime: duration,
                intensity: session.initialIntensity
            )
            updates.append("Recorded successful \(Int(duration))s session")

            // Update calming time estimate
            let oldAvg = profile.averageCalmingTime
            profile.averageCalmingTime = oldAvg * 0.8 + duration * 0.2
            updates.append("Updated average calming time to \(Int(profile.averageCalmingTime))s")

            // Check for new favorite sound
            for record in session.soundsPlayed {
                if let effectiveness = record.effectivenessObserved, effectiveness > 0.7 {
                    // This sound was very effective
                    let existingFavorites = profile.getBestSounds(for: session.cryType, limit: 3)
                    if !existingFavorites.contains(where: { $0.generatorType == record.sound }) {
                        insights.append(ParentInsight(
                            id: UUID(),
                            timestamp: Date(),
                            category: .preference,
                            title: "New Favorite Found!",
                            message: "\(record.sound.rawValue) worked really well for \(session.cryType.rawValue) crying.",
                            actionSuggestion: "I'll prioritize this sound next time.",
                            confidence: 0.8
                        ))
                    }
                }
            }
        } else {
            // Record failed session
            profile.recordSession(
                cryType: session.cryType,
                soundsUsed: session.soundsPlayed.map { $0.sound },
                wasSuccessful: false,
                calmingTime: duration,
                intensity: session.initialIntensity
            )
            updates.append("Recorded unsuccessful session")

            // Reduce confidence in used sounds
            for record in session.soundsPlayed {
                let key = record.sound.rawValue
                let currentScore = profile.soundEffectiveness[key] ?? 0.5
                profile.soundEffectiveness[key] = max(0.1, currentScore - learningRate * 0.5)
            }
            updates.append("Adjusted sound effectiveness based on outcome")
        }

        // Save profile
        profileManager.updateProfile(profile)

        return LearningOutcome(
            event: success ? "Session completed successfully" : "Session ended without success",
            profileUpdates: updates,
            confidenceChange: success ? 0.02 : 0,
            newInsights: insights
        )
    }

    private func describeEvent(_ event: LearningEvent) -> String {
        switch event {
        case .cryIntensityChanged(let from, let to):
            let direction = to < from ? "decreased" : "increased"
            return "Cry intensity \(direction) from \(Int(from * 100))% to \(Int(to * 100))%"
        case .soundStarted(let sound):
            return "Started playing \(sound.rawValue)"
        case .soundEnded(let sound, let effectiveness):
            return "Stopped \(sound.rawValue) (effectiveness: \(Int(effectiveness * 100))%)"
        case .sessionEnded(let success, let duration):
            return success ? "Session succeeded in \(Int(duration))s" : "Session ended after \(Int(duration))s"
        case .parentFeedback(let rating, _):
            return "Parent rated session \(rating)/5"
        case .explicitHelped:
            return "Parent confirmed 'It Helped!'"
        case .explicitNotHelped:
            return "Parent reported 'Not Working'"
        }
    }

    // MARK: - Cry Detection Binding

    private func setupCryDetectionBinding() {
        // Auto-monitor when cry detection is active
        cryDetectionService.$isCryDetected
            .dropFirst()
            .sink { [weak self] isCrying in
                Task { @MainActor in
                    if !isCrying && self?.currentSession != nil {
                        // Cry stopped - potential success
                        self?.handleCryStopped()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handleCryStopped() {
        guard let session = currentSession else { return }

        // Wait a bit to confirm it's really stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }

            if !self.cryDetectionService.isCryDetected {
                // Still not crying - mark as success
                var updatedSession = session
                updatedSession.phaseHistory.append(ActiveSoothingState.PhaseRecord(
                    phase: "cry_stopped",
                    timestamp: Date(),
                    intensity: self.cryDetectionService.cryIntensity
                ))
                self.currentSession = updatedSession
            }
        }
    }

    // MARK: - Analytics

    /// Get learning statistics
    func getLearningStats() -> LearningStats {
        let outcomes = recentOutcomes

        let totalEvents = outcomes.count
        let positiveEvents = outcomes.filter { $0.confidenceChange > 0 }.count
        let profileUpdates = outcomes.flatMap { $0.profileUpdates }.count
        let insights = outcomes.flatMap { $0.newInsights }.count

        return LearningStats(
            totalEvents: totalEvents,
            positiveEvents: positiveEvents,
            profileUpdates: profileUpdates,
            insightsGenerated: insights
        )
    }

    struct LearningStats {
        let totalEvents: Int
        let positiveEvents: Int
        let profileUpdates: Int
        let insightsGenerated: Int

        var positiveRate: Double {
            guard totalEvents > 0 else { return 0 }
            return Double(positiveEvents) / Double(totalEvents)
        }
    }

    // MARK: - Personality Learning

    /// Infer personality traits from behavior patterns
    func inferPersonalityTraits(for babyId: UUID) {
        guard var profile = profileManager.profiles.values.first(where: { $0.babyId == babyId }) else {
            return
        }

        // Analyze calming times
        if profile.averageCalmingTime < 45 {
            profile.updatePersonalityTrait(.soothingResponsiveness, value: 0.8)
        } else if profile.averageCalmingTime > 120 {
            profile.updatePersonalityTrait(.soothingResponsiveness, value: 0.3)
        }

        // Analyze sound variety
        let soundVariety = Set(profile.soundEffectiveness.keys).count
        if soundVariety > 10 && profile.successRate > 0.6 {
            // Responds to many different sounds - likes novelty
            profile.updatePersonalityTrait(.noveltyPreference, value: 0.7)
        } else if soundVariety < 5 && profile.successRate > 0.7 {
            // Prefers familiar sounds
            profile.updatePersonalityTrait(.noveltyPreference, value: 0.3)
        }

        // Analyze rhythm-synced sound effectiveness
        let rhythmicSounds: [GeneratorType] = [.heartbeat, .lullaby, .musicBox, .aquarium]
        let rhythmicEffectiveness = rhythmicSounds
            .compactMap { profile.soundEffectiveness[$0.rawValue] }
            .reduce(0, +) / Double(rhythmicSounds.count)

        if rhythmicEffectiveness > 0.6 {
            profile.updatePersonalityTrait(.rhythmSensitivity, value: 0.8)
        } else if rhythmicEffectiveness < 0.4 {
            profile.updatePersonalityTrait(.rhythmSensitivity, value: 0.3)
        }

        // Analyze pitch preference
        let lowPitchSounds: [GeneratorType] = [.womb, .aquarium, .aquarium]
        let highPitchSounds: [GeneratorType] = [.chimes, .chimes, .bells]

        let lowPitchScore = lowPitchSounds
            .compactMap { profile.soundEffectiveness[$0.rawValue] }
            .reduce(0, +)
        let highPitchScore = highPitchSounds
            .compactMap { profile.soundEffectiveness[$0.rawValue] }
            .reduce(0, +)

        if lowPitchScore > highPitchScore * 1.5 {
            profile.updatePersonalityTrait(.pitchPreference, value: -0.5)
        } else if highPitchScore > lowPitchScore * 1.5 {
            profile.updatePersonalityTrait(.pitchPreference, value: 0.5)
        }

        profileManager.updateProfile(profile)
    }
}
