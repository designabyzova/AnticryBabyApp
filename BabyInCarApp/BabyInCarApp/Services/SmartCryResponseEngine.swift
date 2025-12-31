//
//  SmartCryResponseEngine.swift
//  BabyInCarApp
//
//  Intelligent adaptive response engine for baby cry soothing
//  Uses AI-driven sound selection and learns from effectiveness feedback
//

import Foundation
import Combine

// MARK: - Smart Cry Response Engine
/// AI-powered response engine that intelligently selects and adapts soothing strategies
/// based on cry type, baby's age, historical effectiveness, and real-time feedback
/// Enhanced with ML-based recommendations for personalized soothing
@MainActor
class SmartCryResponseEngine: ObservableObject {
    static let shared = SmartCryResponseEngine()

    // MARK: - Dependencies
    private let cryDetectionService = CryDetectionService.shared
    private let classificationModel = CryClassificationModel.shared
    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared

    // ML-Enhanced Components
    private let mlRecommendationEngine = MLRecommendationEngine.shared
    private let babyProfileManager = BabyProfileManager.shared
    private let analyticsCloudService = AnalyticsCloudService.shared

    // MARK: - Published State
    @Published var isActive: Bool = false
    @Published var currentStrategy: SoothingStrategy?
    @Published var currentPhase: ResponsePhase = .idle
    @Published var phaseProgress: Double = 0
    @Published var currentSound: GeneratorType?
    @Published var effectiveness: EffectivenessLevel = .unknown
    @Published var responseHistory: [ResponseSession] = []
    @Published var adaptationMessage: String = ""

    // MARK: - Response State
    enum ResponsePhase: String {
        case idle = "Ready"
        case initializing = "Initializing Response"
        case attentionCapture = "Capturing Attention"
        case primarySoothing = "Primary Soothing"
        case adaptiveTuning = "Adapting Sound"
        case deepCalming = "Deep Calming"
        case sleepTransition = "Sleep Transition"
        case monitoring = "Monitoring"
        case success = "Baby Calmed"
        case escalating = "Trying Alternative"
    }

    enum EffectivenessLevel: String {
        case unknown = "Evaluating"
        case notWorking = "Adjusting"
        case partiallyEffective = "Partially Working"
        case effective = "Working Well"
        case highlyEffective = "Very Effective"
    }

    // MARK: - Configuration
    private var currentBaby: Baby?
    private var responseStartTime: Date?
    private var currentSession: ResponseSession?
    private var phaseTimer: Timer?
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Sound selection state
    private var currentSoundIndex: Int = 0
    private var soundSequence: [GeneratorType] = []
    private var soundEffectiveness: [GeneratorType: Double] = [:]

    // Adaptive parameters
    private var consecutiveIneffectivePhases: Int = 0
    private let maxIneffectiveBeforeEscalation = 3
    private var intensityLevel: Double = 0.5 // 0-1
    private var frequencyBias: Double = 0 // -1 (lower) to 1 (higher)

    // Learning data
    private var sessionHistory: [ResponseSession] = []
    private let maxSessionHistory = 50

    private init() {
        setupCryDetectionBinding()
    }

    // MARK: - Setup
    private func setupCryDetectionBinding() {
        // Automatically respond when cry is detected
        cryDetectionService.$isCryDetected
            .dropFirst()
            .sink { [weak self] isCrying in
                Task { @MainActor in
                    if isCrying {
                        await self?.handleCryDetected()
                    } else {
                        self?.handleCryEnded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Response Activation
    /// Activate emergency response for a baby
    func activate(for baby: Baby) async {
        guard !isActive else { return }

        currentBaby = baby
        isActive = true
        responseStartTime = Date()

        // Initialize new session
        currentSession = ResponseSession(
            babyId: baby.id,
            babyAgeMonths: baby.ageInMonths,
            startTime: Date()
        )

        // Determine initial strategy based on cry type
        let cryType = cryDetectionService.cryType
        let strategy = selectStrategy(for: cryType, baby: baby)
        currentStrategy = strategy

        adaptationMessage = "Analyzing cry pattern..."

        // Build intelligent sound sequence
        soundSequence = buildSoundSequence(for: cryType, baby: baby, strategy: strategy)
        currentSoundIndex = 0

        // Start response
        await startResponseSequence()
    }

    /// Deactivate response
    func deactivate() {
        isActive = false
        currentPhase = .idle
        phaseProgress = 0
        phaseTimer?.invalidate()
        monitoringTimer?.invalidate()

        // Finalize session
        if var session = currentSession {
            session.endTime = Date()
            session.finalPhase = currentPhase
            session.wasSuccessful = effectiveness == .effective || effectiveness == .highlyEffective
            sessionHistory.append(session)
            saveSessionHistory()
        }

        currentSession = nil
        currentStrategy = nil
        currentSound = nil
        effectiveness = .unknown
        adaptationMessage = ""
    }

    // MARK: - Strategy Selection
    private func selectStrategy(for cryType: CryType, baby: Baby) -> SoothingStrategy {
        let ageMonths = baby.ageInMonths

        // Check historical effectiveness for this baby
        let historicalBest = findBestHistoricalStrategy(for: cryType, babyId: baby.id)
        if let best = historicalBest, best.successRate > 0.7 {
            return best.strategy
        }

        // Age-adjusted strategy selection
        switch cryType {
        case .tired:
            return .sleepInduction
        case .hunger:
            // Distraction until feeding is possible
            return ageMonths < 6 ? .gentle : .distraction
        case .pain:
            return .urgent
        case .attention:
            return ageMonths < 12 ? .comfort : .gentle
        case .discomfort:
            return .gentle
        case .general, .unknown:
            return .adaptive
        }
    }

    private func findBestHistoricalStrategy(for cryType: CryType, babyId: UUID) -> (strategy: SoothingStrategy, successRate: Double)? {
        let relevantSessions = sessionHistory.filter { $0.babyId == babyId && $0.cryType == cryType }

        var strategySuccess: [SoothingStrategy: (successes: Int, total: Int)] = [:]

        for session in relevantSessions {
            guard let strategy = session.strategy else { continue }
            var record = strategySuccess[strategy] ?? (0, 0)
            record.total += 1
            if session.wasSuccessful {
                record.successes += 1
            }
            strategySuccess[strategy] = record
        }

        var bestStrategy: SoothingStrategy?
        var bestRate: Double = 0

        for (strategy, record) in strategySuccess where record.total >= 3 {
            let rate = Double(record.successes) / Double(record.total)
            if rate > bestRate {
                bestRate = rate
                bestStrategy = strategy
            }
        }

        if let strategy = bestStrategy {
            return (strategy, bestRate)
        }
        return nil
    }

    // MARK: - Sound Sequence Building
    private func buildSoundSequence(for cryType: CryType, baby: Baby, strategy: SoothingStrategy) -> [GeneratorType] {
        let ageMonths = baby.ageInMonths
        var sequence: [GeneratorType] = []

        // ========== ML-Enhanced Sound Selection ==========
        // Build cry analysis from current detection state for ML recommendations
        if let extendedFeatures = cryDetectionService.latestExtendedFeatures {
            let voiceChars = cryDetectionService.latestVoiceCharacteristics ?? .zero

            let cryAnalysis = CryAnalysisResult(
                type: cryType,
                confidence: cryDetectionService.confidenceLevel,
                intensity: cryDetectionService.cryIntensity,
                features: extendedFeatures,
                voiceCharacteristics: voiceChars
            )

            // Get ML emergency recommendations based on current cry analysis
            Task {
                let mlTracks = await mlRecommendationEngine.getEmergencyRecommendations(
                    for: baby.id,
                    babyAge: ageMonths,
                    cryType: cryType,
                    cryIntensity: cryDetectionService.cryIntensity
                )

                // Extract generator types from ML-recommended tracks
                await MainActor.run {
                    for track in mlTracks.prefix(3) {
                        if let generator = track.generatorType, !sequence.contains(generator) {
                            // Insert ML recommendations at the front
                            sequence.insert(generator, at: min(sequence.count, 0))
                        }
                    }
                }
            }
        }
        // ========== End ML Enhancement ==========

        // Check baby's learned preferences from BabyProfileManager
        let profile = babyProfileManager.getProfile(for: baby.id)
        if let effectiveTracks = profile?.effectiveTracksForCryType[cryType] {
            // Get generator types from effective track IDs
            for trackId in effectiveTracks.prefix(3) {
                if let track = contentLibrary.getTrack(byId: trackId),
                   let generator = track.generatorType,
                   !sequence.contains(generator) {
                    sequence.append(generator)
                }
            }
        }

        // Fallback: Check legacy BabyCryProfile
        if let legacyProfile = loadBabyProfile(babyId: baby.id),
           let preferredSounds = legacyProfile.preferredSoothingSounds[cryType] {
            for sound in preferredSounds.prefix(3) where !sequence.contains(sound) {
                sequence.append(sound)
            }
        }

        // Add strategy-appropriate sounds
        let strategySounds = getStrategySounds(strategy: strategy, age: ageMonths, cryType: cryType)
        for sound in strategySounds {
            if !sequence.contains(sound) {
                sequence.append(sound)
            }
        }

        // Add age-appropriate fallbacks
        let fallbacks = getAgeFallbacks(age: ageMonths)
        for sound in fallbacks {
            if !sequence.contains(sound) {
                sequence.append(sound)
            }
        }

        return sequence
    }

    private func getStrategySounds(strategy: SoothingStrategy, age: Int, cryType: CryType) -> [GeneratorType] {
        switch strategy {
        case .sleepInduction:
            if age < 6 {
                return [.womb, .heartbeat, .shushing, .pinkNoise]
            } else if age < 12 {
                return [.pinkNoise, .rain, .ocean, .velvetNoise]
            } else if age < 24 {
                return [.greyNoise, .rainOnRoof, .velvetNoise, .softPiano]
            } else {
                return [.campfire, .rainOnRoof, .greyNoise, .gentleGuitar]
            }

        case .distraction:
            if age < 12 {
                return [.musicBox, .shushing, .birds, .chimes]
            } else {
                return [.aquarium, .trainRide, .birds, .musicBox]
            }

        case .comfort:
            if age < 6 {
                return [.heartbeat, .womb, .shushing]
            } else if age < 18 {
                return [.pinkNoise, .ocean, .velvetNoise, .rain]
            } else {
                return [.greyNoise, .rainOnRoof, .forest, .campfire]
            }

        case .gentle:
            if age < 12 {
                return [.pinkNoise, .rain, .fan, .ocean]
            } else {
                return [.velvetNoise, .greyNoise, .rainOnRoof, .river]
            }

        case .urgent:
            // High-attention sounds first, then calming
            if age < 6 {
                return [.shushing, .vacuum, .womb, .heartbeat]
            } else if age < 18 {
                return [.vacuum, .pinkNoise, .hairDryer, .brownNoise]
            } else {
                return [.brownNoise, .trainRide, .greyNoise, .velvetNoise]
            }

        case .adaptive:
            // Mix based on cry type
            switch cryType {
            case .tired:
                return getStrategySounds(strategy: .sleepInduction, age: age, cryType: cryType)
            case .pain:
                return getStrategySounds(strategy: .urgent, age: age, cryType: cryType)
            default:
                return getStrategySounds(strategy: .comfort, age: age, cryType: cryType)
            }
        }
    }

    private func getAgeFallbacks(age: Int) -> [GeneratorType] {
        if age < 6 {
            return [.whiteNoise, .pinkNoise, .brownNoise]
        } else if age < 12 {
            return [.pinkNoise, .brownNoise, .rain, .fan]
        } else if age < 24 {
            return [.greyNoise, .velvetNoise, .ocean, .rain]
        } else {
            return [.greyNoise, .velvetNoise, .rainOnRoof, .forest]
        }
    }

    // MARK: - Response Sequence
    private func startResponseSequence() async {
        guard let baby = currentBaby, !soundSequence.isEmpty else {
            deactivate()
            return
        }

        // Phase 1: Attention Capture (0-15 seconds)
        await runPhase(.attentionCapture, duration: 15)

        // Check if still crying
        guard isActive && cryDetectionService.isCryDetected else {
            await transitionToSuccess()
            return
        }

        // Phase 2: Primary Soothing (15-60 seconds)
        await runPhase(.primarySoothing, duration: 45)

        // Evaluate effectiveness
        evaluateEffectiveness()

        if effectiveness == .notWorking {
            // Try next sound
            await escalateResponse()
        }

        // Phase 3: Deep Calming or Adaptation
        guard isActive else { return }

        if effectiveness == .effective || effectiveness == .highlyEffective {
            await runPhase(.deepCalming, duration: 60)
        } else {
            await runPhase(.adaptiveTuning, duration: 30)
            await tryAlternativeApproach()
        }

        // Phase 4: Monitoring / Sleep Transition
        guard isActive else { return }

        if cryDetectionService.isCryDetected {
            // Still crying - continue monitoring and adapting
            startMonitoringLoop()
        } else {
            await transitionToSuccess()
        }
    }

    private func runPhase(_ phase: ResponsePhase, duration: TimeInterval) async {
        currentPhase = phase
        phaseProgress = 0

        // Select and play appropriate sound for this phase
        await selectAndPlaySound(for: phase)

        // Animate progress
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < duration && isActive {
            let elapsed = Date().timeIntervalSince(startTime)
            phaseProgress = min(elapsed / duration, 1.0)

            // Check for early success
            if !cryDetectionService.isCryDetected && phase != .monitoring {
                return
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    private func selectAndPlaySound(for phase: ResponsePhase) async {
        guard let baby = currentBaby else { return }

        let sound: GeneratorType

        switch phase {
        case .attentionCapture:
            // Use attention-grabbing sound
            sound = selectAttentionSound(for: baby.ageInMonths)
        case .primarySoothing, .deepCalming:
            // Use current sequence sound
            sound = soundSequence[currentSoundIndex]
        case .adaptiveTuning:
            // Try next sound in sequence
            currentSoundIndex = (currentSoundIndex + 1) % soundSequence.count
            sound = soundSequence[currentSoundIndex]
        case .sleepTransition:
            // Quieter, sleep-inducing sound
            sound = selectSleepSound(for: baby.ageInMonths)
        default:
            sound = soundSequence.first ?? .pinkNoise
        }

        currentSound = sound
        adaptationMessage = "Playing: \(sound.rawValue)"

        // Play the sound
        let track = createTrack(for: sound)
        audioEngine.play(track: track)

        // Record in session
        currentSession?.soundsUsed.append(sound)
    }

    private func selectAttentionSound(for ageMonths: Int) -> GeneratorType {
        // Attention-grabbing but not startling
        if ageMonths < 6 {
            return .shushing // Familiar, attention-getting
        } else if ageMonths < 12 {
            return .musicBox // Novel, interesting
        } else if ageMonths < 24 {
            return .trainRide // Rhythmic, engaging
        } else {
            return .aquarium // Interesting, calming
        }
    }

    private func selectSleepSound(for ageMonths: Int) -> GeneratorType {
        if ageMonths < 6 {
            return .womb
        } else if ageMonths < 12 {
            return .pinkNoise
        } else if ageMonths < 24 {
            return .velvetNoise
        } else {
            return .greyNoise
        }
    }

    private func createTrack(for generator: GeneratorType) -> AudioTrack {
        AudioTrack(
            title: generator.rawValue,
            category: generator.category,
            duration: 600, // 10 minutes
            calmingScore: generator.calmingScore,
            audioSourceType: .generated,
            generatorType: generator
        )
    }

    // MARK: - Effectiveness Evaluation
    private func evaluateEffectiveness() {
        let cryIntensity = cryDetectionService.cryIntensity
        let isCrying = cryDetectionService.isCryDetected

        if !isCrying {
            effectiveness = .highlyEffective
            consecutiveIneffectivePhases = 0
        } else if cryIntensity < 0.3 {
            effectiveness = .effective
            consecutiveIneffectivePhases = 0
        } else if cryIntensity < 0.6 {
            effectiveness = .partiallyEffective
            consecutiveIneffectivePhases = 0
        } else {
            effectiveness = .notWorking
            consecutiveIneffectivePhases += 1
        }

        // Record effectiveness for current sound
        if let sound = currentSound {
            let score = effectiveness == .highlyEffective ? 1.0 :
                       effectiveness == .effective ? 0.8 :
                       effectiveness == .partiallyEffective ? 0.5 :
                       effectiveness == .notWorking ? 0.1 : 0.3

            soundEffectiveness[sound] = score
        }
    }

    // MARK: - Adaptation
    private func escalateResponse() async {
        currentPhase = .escalating
        adaptationMessage = "Trying different sound..."

        // Move to next sound
        currentSoundIndex = (currentSoundIndex + 1) % soundSequence.count

        // If we've tried all sounds, rebuild sequence with variations
        if currentSoundIndex == 0 {
            adjustParameters()
            soundSequence = buildAdaptedSequence()
        }

        await selectAndPlaySound(for: .primarySoothing)
    }

    private func tryAlternativeApproach() async {
        guard consecutiveIneffectivePhases >= maxIneffectiveBeforeEscalation else { return }

        adaptationMessage = "Switching approach..."

        // Try a completely different strategy
        let alternativeStrategies: [SoothingStrategy] = [.urgent, .distraction, .comfort, .gentle]
        for strategy in alternativeStrategies where strategy != currentStrategy {
            currentStrategy = strategy
            if let baby = currentBaby {
                soundSequence = buildSoundSequence(for: cryDetectionService.cryType, baby: baby, strategy: strategy)
                currentSoundIndex = 0
            }
            break
        }

        consecutiveIneffectivePhases = 0
    }

    private func adjustParameters() {
        // Adjust intensity based on results
        if effectiveness == .notWorking {
            // Try different intensity
            intensityLevel = intensityLevel > 0.5 ? 0.3 : 0.7
        }

        // Adjust frequency bias based on cry type
        if cryDetectionService.cryType == .pain {
            frequencyBias = -0.3 // Try lower frequencies
        } else if cryDetectionService.cryType == .tired {
            frequencyBias = 0 // Balanced
        }
    }

    private func buildAdaptedSequence() -> [GeneratorType] {
        guard let baby = currentBaby else { return soundSequence }

        // Sort by historical effectiveness for this baby
        var scoredSounds: [(GeneratorType, Double)] = []

        for sound in GeneratorType.allCases {
            // Check if age-appropriate
            let ageRange = sound.optimalAgeRange
            guard ageRange.contains(baby.ageInMonths) else { continue }

            var score = sound.calmingScore

            // Boost by historical effectiveness
            if let effectiveness = soundEffectiveness[sound] {
                score = score * 0.5 + effectiveness * 0.5
            }

            // Apply frequency bias
            if frequencyBias < 0 {
                // Prefer lower frequency sounds
                if [.brownNoise, .womb, .heartbeat, .rain].contains(sound) {
                    score += 0.1
                }
            } else if frequencyBias > 0 {
                // Prefer higher frequency sounds
                if [.whiteNoise, .shushing, .birds].contains(sound) {
                    score += 0.1
                }
            }

            scoredSounds.append((sound, score))
        }

        // Sort by score and return top sounds
        scoredSounds.sort { $0.1 > $1.1 }
        return scoredSounds.prefix(8).map { $0.0 }
    }

    // MARK: - Monitoring
    private func startMonitoringLoop() {
        currentPhase = .monitoring
        adaptationMessage = "Monitoring baby's state..."

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.monitoringCheck()
            }
        }
    }

    private func monitoringCheck() async {
        evaluateEffectiveness()

        if !cryDetectionService.isCryDetected {
            await transitionToSuccess()
        } else if effectiveness == .notWorking {
            await escalateResponse()
        }
    }

    private func transitionToSuccess() async {
        currentPhase = .success
        effectiveness = .highlyEffective
        adaptationMessage = "Baby has calmed down!"

        // Record successful sound
        if let sound = currentSound, let baby = currentBaby {
            recordSoothingSuccess(sound: sound, babyId: baby.id, cryType: cryDetectionService.cryType)
        }

        // Transition to sleep sound if appropriate
        if let baby = currentBaby {
            let sleepSound = selectSleepSound(for: baby.ageInMonths)
            if sleepSound != currentSound {
                currentSound = sleepSound
                let track = createTrack(for: sleepSound)
                audioEngine.play(track: track)
            }
        }

        // Keep monitoring briefly
        try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds

        if !cryDetectionService.isCryDetected {
            deactivate()
        }
    }

    // MARK: - Event Handlers
    private func handleCryDetected() async {
        guard let baby = currentBaby ?? loadActiveBaby() else { return }

        if !isActive {
            await activate(for: baby)
        }
    }

    private func handleCryEnded() {
        if isActive && currentPhase != .monitoring && currentPhase != .success {
            Task {
                await transitionToSuccess()
            }
        }
    }

    // MARK: - Learning & Persistence
    private func recordSoothingSuccess(sound: GeneratorType, babyId: UUID, cryType: CryType) {
        // Record in legacy BabyCryProfile
        var profile = loadBabyProfile(babyId: babyId) ?? BabyCryProfile(babyId: babyId)
        profile.recordSoothingSuccess(for: cryType, sound: sound)
        saveBabyProfile(profile)

        // ========== ML-Enhanced Learning ==========
        // Record effectiveness in new BabyProfileManager for ML recommendations
        // Find the track ID for this generator type
        let allTracks = contentLibrary.getAllTracks()
        if let matchingTrack = allTracks.first(where: { $0.generatorType == sound }) {
            let calmingTime = Int(currentSession?.duration ?? 60)

            // Record locally in BabyProfileManager
            babyProfileManager.recordTrackEffectiveness(
                babyId: babyId,
                trackId: matchingTrack.id,
                cryType: cryType,
                wasEffective: true,
                calmingTimeSeconds: calmingTime
            )

            // Optionally sync to cloud analytics
            Task {
                await analyticsCloudService.recordTrackEffectiveness(
                    babyId: babyId,
                    trackId: matchingTrack.id,
                    cryType: cryType,
                    wasEffective: true,
                    calmingTimeSeconds: calmingTime
                )
            }
        }
        // ========== End ML Enhancement ==========
    }

    private func loadBabyProfile(babyId: UUID) -> BabyCryProfile? {
        guard let data = UserDefaults.standard.data(forKey: "BabyCryProfile_\(babyId.uuidString)"),
              let profile = try? JSONDecoder().decode(BabyCryProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    private func saveBabyProfile(_ profile: BabyCryProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: "BabyCryProfile_\(profile.babyId.uuidString)")
    }

    private func saveSessionHistory() {
        guard let data = try? JSONEncoder().encode(sessionHistory) else { return }
        UserDefaults.standard.set(data, forKey: "CryResponseSessionHistory")
    }

    private func loadSessionHistory() {
        guard let data = UserDefaults.standard.data(forKey: "CryResponseSessionHistory"),
              let history = try? JSONDecoder().decode([ResponseSession].self, from: data) else {
            return
        }
        sessionHistory = history
    }

    private func loadActiveBaby() -> Baby? {
        // Load from your app's baby manager
        guard let data = UserDefaults.standard.data(forKey: "activeBaby"),
              let baby = try? JSONDecoder().decode(Baby.self, from: data) else {
            return nil
        }
        return baby
    }
}

// MARK: - Response Session
/// Records a complete cry response session for learning
struct ResponseSession: Codable {
    let id: UUID
    let babyId: UUID
    let babyAgeMonths: Int
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
    var cryType: CryType?
    var strategy: SoothingStrategy?
    var soundsUsed: [GeneratorType]
    var finalPhase: SmartCryResponseEngine.ResponsePhase?
    var wasSuccessful: Bool

    init(babyId: UUID, babyAgeMonths: Int, startTime: Date) {
        self.id = UUID()
        self.babyId = babyId
        self.babyAgeMonths = babyAgeMonths
        self.startTime = startTime
        self.soundsUsed = []
        self.wasSuccessful = false
    }
}

// MARK: - Extensions for Codable Enums
extension SmartCryResponseEngine.ResponsePhase: Codable {}
extension SoothingStrategy: Codable {}
