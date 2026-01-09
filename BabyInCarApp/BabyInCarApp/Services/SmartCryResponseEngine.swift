//
//  SmartCryResponseEngine.swift
//  BabyInCarApp
//
//  Intelligent adaptive response engine for baby cry soothing
//  Uses AI-driven sound selection and learns from effectiveness feedback
//

import Foundation
import Combine
import UIKit

// Note: SoothingRecommendation is defined in BabyMoodLLMEngine.swift
// Note: DynamicSoundMix is defined in DynamicSoundMixer.swift
// Note: EnvironmentSoundDetector is defined in EnvironmentSoundDetector.swift
// Note: BabyMoodProfileManager is defined in Models/BabyMoodProfile.swift
// Note: BabyMoodIntelligence is defined in Services/BabyMoodIntelligence.swift

// MARK: - Smart Cry Response Engine
/// AI-powered response engine that intelligently selects and adapts soothing strategies
/// based on cry type, baby's age, historical effectiveness, and real-time feedback
/// Enhanced with ML-based recommendations for personalized soothing
/// NOW POWERED BY: BabyMIM (Baby Mood Intelligence Model) for revolutionary AI-driven soothing
@MainActor
class SmartCryResponseEngine: ObservableObject {
    static let shared = SmartCryResponseEngine()

    // MARK: - Dependencies
    private let cryDetectionService = CryDetectionService.shared
    private let classificationModel = CryClassificationModel.shared
    private let audioEngine = AudioEngine.shared
    private let contentLibrary = ContentLibraryService.shared
    private let playbackSession = PlaybackSessionManager.shared

    // ML-Enhanced Components
    private let mlRecommendationEngine = MLRecommendationEngine.shared
    private let babyProfileManager = BabyProfileManager.shared
    private let analyticsCloudService = AnalyticsCloudService.shared

    // FS-017: Ultra-Smart Playlist Selection (replaces fixed sound arrays)
    private let ultraSmartSelector = UltraSmartPlaylistSelector.shared

    // FS-017: Smart Emergency Playlist System
    private let playlistSelector = PlaylistSelector.shared
    @Published var isEmergencyMode: Bool = true  // ENABLED BY DEFAULT for Spotify-like queue!

    // FS-017: Ultra-Smart Emergency Queue (Spotify-like experience)
    // This is the NEW queue system that uses REAL library tracks + generated sounds
    private let smartEmergencyQueue = SmartEmergencyQueue.shared

    // MARK: - AI Analysis State
    /// Whether to use advanced AI mode (to be integrated later)
    @Published var useBabyMIMMode: Bool = false

    /// Latest AI analysis and reasoning
    @Published var mimAnalysis: String = ""
    @Published var mimParentTip: String = ""
    @Published var mimConfidence: Double = 0

    // Note: BabyMoodIntelligence not available - file not in project
    // private let babyMoodIntelligence = BabyMoodIntelligence.shared

    // MARK: - Published State
    @Published var isActive: Bool = false
    @Published var currentStrategy: SoothingStrategy?
    @Published var currentPhase: ResponsePhase = .idle
    @Published var phaseProgress: Double = 0
    @Published var currentSound: GeneratorType?
    @Published var effectiveness: EffectivenessLevel = .unknown
    @Published var responseHistory: [ResponseSession] = []
    @Published var adaptationMessage: String = ""

    // MARK: - Sound Switching State (for UI)
    /// Seconds until the engine auto-switches to next sound (counts down)
    @Published var secondsUntilNextSound: TimeInterval = 30
    /// Timer for countdown display
    private var countdownTimer: Timer?

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

    // Sound rotation to prevent repetition across sessions
    private var recentlyPlayedSounds: [GeneratorType] = []
    private let maxRecentSounds = 5  // Remember last 5 sounds to avoid

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
        setupMemoryObservers()
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

    // MARK: - Memory Management

    /// Setup memory cleanup observers
    private func setupMemoryObservers() {
        // MEMORY OPTIMIZATION (Increment 0028): Clean up on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("[SmartCryResponse] ⚠️ Memory warning received - cleaning up")
                await self?.cleanup()
            }
        }

        // MEMORY OPTIMIZATION (Increment 0028): Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let level = notification.userInfo?["level"] as? String {
                    print("[SmartCryResponse] 🧹 Memory cleanup requested (\(level)) - cleaning up")
                    await self?.cleanup()
                }
            }
        }
    }

    /// Clean up resources to reduce memory footprint
    private func cleanup() async {
        print("[SmartCryResponse] 🧹 Starting memory cleanup...")

        // Trim session history to 20 most recent
        let trimCount = max(0, sessionHistory.count - 20)
        if trimCount > 0 {
            sessionHistory = Array(sessionHistory.suffix(20))
            print("[SmartCryResponse] 🧹 Trimmed \(trimCount) old sessions (kept 20 most recent)")
        }

        // Clear current session if not active
        if !isActive {
            currentSession = nil
            currentBaby = nil
            print("[SmartCryResponse] 🧹 Cleared inactive session data")
        }

        // Force cancellable cleanup
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        setupCryDetectionBinding() // Re-establish binding after cleanup
        print("[SmartCryResponse] 🧹 Reset Combine subscriptions")

        print("[SmartCryResponse] ✅ Memory cleanup complete")
    }

    // MARK: - Response Activation
    /// Activate emergency response for a baby
    func activate(for baby: Baby) async {
        guard !isActive else {
            print("[SmartCryResponse] ⚠️ Already active, skipping activation")
            return
        }

        print("[SmartCryResponse] 🚀 ACTIVATING for \(baby.displayName) (age: \(baby.ageInMonths) months)")

        currentBaby = baby
        isActive = true
        responseStartTime = Date()

        // CRITICAL: Configure audio session to INTERRUPT other audio (Spotify, YouTube, etc.)
        // This ensures the soothing sound plays loudly and clearly for the baby
        // Exclusive playback mode automatically pauses other apps
        audioEngine.configureAudioSession(interruptOtherAudio: true)

        // Initialize new session
        currentSession = ResponseSession(
            babyId: baby.id,
            babyAgeMonths: baby.ageInMonths,
            startTime: Date()
        )

        // CRITICAL FIX: Wait briefly for ML classification to complete
        // The cry detection triggers immediately but classification takes ~100-500ms
        // This prevents us from reading .unknown/.general before classification finishes
        var cryType = cryDetectionService.cryType

        // If initial cry type is generic, wait for classification
        if cryType == .unknown || cryType == .general {
            print("[SmartCryResponse] ⏳ Waiting for ML classification (initial: \(cryType.rawValue))...")

            // Wait up to 500ms for classification, checking every 100ms
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                let updatedType = cryDetectionService.cryType
                if updatedType != .unknown && updatedType != .general {
                    cryType = updatedType
                    print("[SmartCryResponse] ✅ ML classification ready: \(cryType.rawValue)")
                    break
                }

                // Also check confidence level - if classifier has run with decent confidence, use that type
                if cryDetectionService.confidenceLevel > 0.5 && updatedType != .unknown {
                    cryType = updatedType
                    print("[SmartCryResponse] ✅ Using confident classification: \(cryType.rawValue) (\(Int(cryDetectionService.confidenceLevel * 100))%)")
                    break
                }
            }

            // If still generic, use adaptive strategy with cry type monitoring
            if cryType == .unknown || cryType == .general {
                print("[SmartCryResponse] ⚠️ Classification timeout - using adaptive strategy, will update when classification available")
                // Subscribe to cry type updates for mid-response adaptation
                subscribeToCryTypeUpdates()
            }
        }

        // 🚨 EMERGENCY MODE: Play GENERATED lullaby IMMEDIATELY
        // Generated audio starts instantly with zero latency - no file loading, no network
        // This guarantees emergency mode ALWAYS has sound, even offline
        // CRITICAL: Use playImmediateWithoutFade() to bypass fade-in delay for instant sound!
        print("[SmartCryResponse] 🚨 Emergency mode: Playing generated lullaby (instant playback)")

        let defaultTrack = AudioTrack.defaultEmergencyTrack()
        audioEngine.playImmediateWithoutFade(track: defaultTrack)

        currentPhase = .primarySoothing
        adaptationMessage = "Playing soothing lullaby..."

        // Start monitoring for baby's response
        startMonitoringLoop()
    }

    /// Subscribe to cry type updates for mid-response adaptation
    private var cryTypeSubscription: AnyCancellable?

    private func subscribeToCryTypeUpdates() {
        // Cancel any existing subscription
        cryTypeSubscription?.cancel()

        cryTypeSubscription = cryDetectionService.$cryType
            .dropFirst() // Skip initial value
            .filter { $0 != .unknown && $0 != .general } // Only specific types
            .removeDuplicates() // Only react to actual changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newType in
                guard let self = self, self.isActive else { return }

                print("[SmartCryResponse] 🔄 Cry type classified: \(newType.rawValue) - adapting response!")

                // Update strategy based on new classification
                if let baby = self.currentBaby {
                    let newStrategy = self.selectStrategy(for: newType, baby: baby)
                    if newStrategy != self.currentStrategy {
                        self.currentStrategy = newStrategy
                        // Rebuild sequence with new cry type knowledge
                        self.soundSequence = self.buildSoundSequence(for: newType, baby: baby, strategy: newStrategy)
                        print("[SmartCryResponse] 📊 Updated strategy: \(newStrategy)")
                    }

                    // CRITICAL: Also update SmartEmergencyQueue if in playlist mode
                    // This allows the queue to adapt its upcoming tracks based on cry type!
                    if self.isEmergencyMode && self.smartEmergencyQueue.isActive {
                        Task {
                            await self.smartEmergencyQueue.adaptToCryType(newType, babyAge: baby.ageInMonths)
                        }
                    }
                }

                // Update session with correct cry type
                self.currentSession?.cryType = newType
            }
    }

    /// Deactivate response
    func deactivate() {
        print("[SmartCryResponse] Deactivating - stopping all audio...")

        // Stop the smart emergency queue if active
        if smartEmergencyQueue.isActive {
            Task {
                await smartEmergencyQueue.stop(wasEffective: effectiveness == .effective || effectiveness == .highlyEffective)
            }
        }

        // CRITICAL: Stop playback through session manager
        // This ensures proper cleanup and allows other sources to resume
        if isEmergencyMode {
            playbackSession.stopPlayback(from: .emergencyMode)
        } else {
            playbackSession.stopPlayback(from: .singleSound)
        }

        // CRITICAL: Restore normal audio session
        // This allows Spotify/YouTube to resume when we stop playing
        audioEngine.configureAudioSession(interruptOtherAudio: false)

        isActive = false
        currentPhase = .idle
        phaseProgress = 0
        phaseTimer?.invalidate()
        phaseTimer = nil
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        stopSoundCountdown()

        // Cancel cry type subscription
        cryTypeSubscription?.cancel()
        cryTypeSubscription = nil

        // Finalize session with ducking telemetry
        if var session = currentSession {
            session.endTime = Date()
            session.finalPhase = currentPhase
            session.wasSuccessful = effectiveness == .effective || effectiveness == .highlyEffective

            print("[SmartCryResponse] Session effectiveness: \(effectiveness.rawValue)")

            sessionHistory.append(session)
            saveSessionHistory()
        }

        currentSession = nil
        currentStrategy = nil
        currentSound = nil
        effectiveness = .unknown
        adaptationMessage = ""

        print("[SmartCryResponse] Deactivated - all audio stopped")
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

        // ========== PRIORITY 0: ULTRA-SMART SELECTOR (NEW - ML-style scoring) ==========
        // This is the PRIMARY selection method - uses multi-factor scoring
        // CRITICAL: This filters out BANNED sounds (rain, thunder, etc.)
        let ultraSmartSounds = ultraSmartSelector.selectOptimalSounds(
            cryType: cryType,
            babyAge: ageMonths,
            cryIntensity: cryDetectionService.cryIntensity,
            maxSounds: 8
        )

        // Ultra-smart sounds are our primary sequence
        sequence = ultraSmartSounds
        print("[SmartCryResponse] 🧠 Ultra-smart selected: \(sequence.map { $0.rawValue })")
        // ========== End Ultra-Smart Selection ==========

        // ========== PRIORITY 1: Adaptive Learning Engine (Self-Learning) ==========
        // Use learned preferences from AdaptiveLearningEngine (boost already-selected sounds)
        let adaptiveLearning = AdaptiveLearningEngine.shared
        let learnedSounds = adaptiveLearning.getRecommendedSounds(for: cryType)
            .filter { !ultraSmartSelector.isSoundForbidden($0) } // CRITICAL: Filter banned sounds!

        if !learnedSounds.isEmpty && adaptiveLearning.learningConfidence > 0.3 {
            // Insert learned sounds at the front if not already there
            for sound in learnedSounds.prefix(2).reversed() where !sequence.contains(sound) {
                sequence.insert(sound, at: 0)
            }
            print("[SmartCryResponse]: Boosted with \(learnedSounds.count) learned sounds (confidence: \(Int(adaptiveLearning.learningConfidence * 100))%)")
        }
        // ========== End Adaptive Learning ==========

        // ========== PRIORITY 2: ML-Enhanced Sound Selection ==========
        // Build cry analysis from current detection state for ML recommendations
        if let extendedFeatures = cryDetectionService.latestExtendedFeatures {
            let voiceChars = cryDetectionService.latestVoiceCharacteristics ?? .zero

            // Note: CryAnalysisResult available for future ML enhancements
            // Currently using individual parameters for ML recommendations
            _ = CryAnalysisResult(
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
                // CRITICAL: Filter out banned sounds!
                await MainActor.run {
                    for track in mlTracks.prefix(3) {
                        if let generator = track.generatorType,
                           !sequence.contains(generator),
                           !self.ultraSmartSelector.isSoundForbidden(generator) {
                            // Insert ML recommendations at the front
                            sequence.insert(generator, at: min(sequence.count, 0))
                        }
                    }
                }
            }
        }
        // ========== End ML Enhancement ==========

        // PRIORITY 3: Check baby's learned preferences from BabyProfileManager
        let profile = babyProfileManager.getProfile(for: baby.id)
        if let effectiveTracks = profile?.effectiveTracksForCryType[cryType] {
            // Get generator types from effective track IDs
            for trackId in effectiveTracks.prefix(3) {
                if let track = contentLibrary.getTrack(by: trackId),
                   let generator = track.generatorType,
                   !sequence.contains(generator),
                   !ultraSmartSelector.isSoundForbidden(generator) { // CRITICAL: Filter banned!
                    sequence.append(generator)
                }
            }
        }

        // PRIORITY 4: Fallback - Check legacy BabyCryProfile
        if let legacyProfile = loadBabyProfile(babyId: baby.id),
           let preferredSounds = legacyProfile.preferredSoothingSounds[cryType] {
            for sound in preferredSounds.prefix(3) {
                if !sequence.contains(sound) && !ultraSmartSelector.isSoundForbidden(sound) {
                    sequence.append(sound)
                }
            }
        }

        // NOTE: We NO LONGER add strategy sounds or age fallbacks here
        // The ultra-smart selector already handles this with multi-factor scoring

        // Apply rotation: deprioritize recently played sounds
        // Move recently played sounds to the end of the sequence
        let rotatedSequence = applySequenceRotation(sequence)

        // Record this session for learning
        ultraSmartSelector.recordSession(soundsPlayed: rotatedSequence)

        return rotatedSequence
    }

    /// Rotate sequence to deprioritize recently played sounds
    private func applySequenceRotation(_ sequence: [GeneratorType]) -> [GeneratorType] {
        guard !recentlyPlayedSounds.isEmpty else { return sequence }

        // Separate sounds into "not recently played" and "recently played"
        var fresh: [GeneratorType] = []
        var recent: [GeneratorType] = []

        for sound in sequence {
            if recentlyPlayedSounds.contains(sound) {
                recent.append(sound)
            } else {
                fresh.append(sound)
            }
        }

        // Add slight randomization to fresh sounds (shuffle first 3)
        if fresh.count >= 3 {
            var topThree = Array(fresh.prefix(3))
            topThree.shuffle()
            fresh = topThree + Array(fresh.dropFirst(3))
        }

        // Fresh sounds first, then recently played as fallback
        return fresh + recent
    }

    // MARK: - Research-Backed Sound Selection
    //
    // SOUND TYPES FOR BABY CALMING:
    //
    // MELODIC SOUNDS (Preferred - pleasant, engaging):
    // - Music Box, Lullaby, Soft Piano, Gentle Guitar, Chimes
    // - These are engaging, have recognizable patterns, and are pleasant to hear
    //
    // NATURE SOUNDS (Good variety - rhythmic, natural):
    // - Rain, Ocean, River, Waterfall - rhythmic water sounds
    // - Birds, Crickets, Forest - daytime ambience (older babies)
    //
    // COMFORT SOUNDS (0-6 months especially):
    // - Heartbeat, Womb - prenatal familiarity
    // - Shushing - mimics parent's voice
    //
    // WHITE NOISE VARIANTS (Use sparingly - can sound harsh):
    // - Pink Noise - softer than white, good for sleep
    // - Brown Noise - deep, rumbling, very calming
    // - AVOID: Vacuum, Hair Dryer, pure White Noise (can be scary/harsh)
    //
    // IMPORTANT: Mix melodic and rhythmic sounds for variety!

    /// DEPRECATED: This method is no longer the primary selection method.
    /// The UltraSmartPlaylistSelector now handles sound selection with ML-style scoring.
    /// This method is kept for backwards compatibility but all rain sounds are REMOVED.
    private func getStrategySounds(strategy: SoothingStrategy, age: Int, cryType: CryType) -> [GeneratorType] {
        // CRITICAL: All sounds must be filtered through forbidden list
        // Rain is BANNED - too loud and scary for babies!

        switch strategy {
        case .sleepInduction:
            // Goal: Transition from alert/crying to drowsy/asleep
            // INCLUDE MELODIC OPTIONS for pleasant experience
            // NO RAIN - replaced with ocean (gentler, rhythmic)
            if age < 6 {
                // Newborns: Gentle sounds, include music box for melody
                return [.musicBox, .womb, .heartbeat, .lullaby, .aquarium]
            } else if age < 12 {
                // 6-12 months: Mix of melodic and nature
                return [.lullaby, .musicBox, .aquarium, .softPiano, .aquarium]
            } else if age < 24 {
                // 1-2 years: More variety, melodic focus
                return [.lullaby, .softPiano, .aquarium, .gentleGuitar, .aquarium]
            } else {
                // 2+ years: Lullabies and soft music
                return [.lullaby, .softPiano, .gentleGuitar, .aquarium, .aquarium]
            }

        case .distraction:
            // Goal: Interrupt cry pattern with interesting, engaging sound
            // MELODIC FIRST - much more engaging than noise!
            if age < 12 {
                // Babies: Music box is perfect - melodic, engaging
                return [.musicBox, .chimes, .lullaby, .bells, .heartbeat]
            } else {
                // Toddlers: More complex melodic sounds
                return [.musicBox, .lullaby, .softPiano, .chimes, .lullaby]
            }

        case .comfort:
            // Goal: Provide soothing, safe-feeling soundscape
            // Mix melodic with comfort sounds - NO RAIN!
            if age < 6 {
                // Newborns: Prenatal + gentle melody
                return [.heartbeat, .womb, .musicBox, .lullaby, .aquarium]
            } else if age < 18 {
                // 6-18 months: Melodic + ocean (gentler than rain)
                return [.musicBox, .lullaby, .aquarium, .softPiano, .aquarium]
            } else {
                // 18+ months: Nature + music - ocean instead of rain
                return [.lullaby, .aquarium, .softPiano, .gentleGuitar, .aquarium]
            }

        case .gentle:
            // Goal: Low-intensity, sustained soothing
            // Gentle melodic and nature sounds - ocean/river instead of rain
            if age < 12 {
                return [.lullaby, .aquarium, .musicBox, .aquarium, .aquarium]
            } else {
                return [.aquarium, .lullaby, .softPiano, .aquarium, .aquarium]
            }

        case .urgent:
            // Goal: IMMEDIATE attention capture when baby is very upset
            // Use ENGAGING sounds that grab attention GENTLY
            // Music box and lullaby are MUCH better than harsh noise!
            // NO RAIN - replaced with ocean for urgent comfort
            if age < 6 {
                // Newborns: Familiar prenatal + gentle melody
                return [.musicBox, .heartbeat, .womb, .lullaby, .aquarium]
            } else if age < 18 {
                // Older babies: Melodic first, then ocean (gentler)
                return [.musicBox, .lullaby, .chimes, .aquarium, .softPiano]
            } else {
                // Toddlers: Engaging melodic sounds
                return [.musicBox, .lullaby, .softPiano, .chimes, .aquarium]
            }

        case .adaptive:
            // Goal: Match sound to cry type
            // ALWAYS include melodic options - NO RAIN!
            switch cryType {
            case .tired:
                return getStrategySounds(strategy: .sleepInduction, age: age, cryType: cryType)
            case .pain:
                // Pain needs immediate comfort - gentle, familiar sounds
                return [.heartbeat, .musicBox, .lullaby, .womb, .aquarium]
            case .hunger:
                // Hunger cries need engaging distraction until feeding
                return getStrategySounds(strategy: .distraction, age: age, cryType: cryType)
            case .attention:
                return getStrategySounds(strategy: .comfort, age: age, cryType: cryType)
            case .discomfort:
                // General discomfort - mix of comfort and melodic, ocean instead of rain
                return [.musicBox, .lullaby, .heartbeat, .aquarium, .aquarium]
            default:
                // Unknown cry type: Start with proven MELODIC calming sounds
                return getProvenCalmingSounds(for: age)
            }
        }
    }

    /// Research-backed sounds proven effective for baby calming
    /// PRIORITY: Melodic sounds FIRST, then nature, then noise
    /// IMPORTANT: Avoid harsh sounds that might scare the baby
    /// CRITICAL: NO RAIN - too loud and scary!
    private func getProvenCalmingSounds(for age: Int) -> [GeneratorType] {
        if age < 6 {
            // 0-6 months: Womb + gentle melody
            // Music box is MUCH more pleasant than pure noise!
            // NO RAIN - replaced with pinkNoise (gentler)
            return [.musicBox, .heartbeat, .womb, .lullaby, .aquarium]
        } else if age < 12 {
            // 6-12 months: Melodic + ocean (gentler than rain)
            return [.musicBox, .lullaby, .aquarium, .softPiano, .aquarium]
        } else if age < 24 {
            // 1-2 years: More melodic variety, ocean instead of rain
            return [.lullaby, .musicBox, .softPiano, .aquarium, .gentleGuitar]
        } else {
            // 2+ years: Music + ocean (not rain!)
            return [.lullaby, .softPiano, .gentleGuitar, .aquarium, .aquarium]
        }
    }

    private func getAgeFallbacks(age: Int) -> [GeneratorType] {
        // Fallbacks include melodic AND nature sounds
        // AVOID pure white noise as fallback - use softer variants
        // ❌ NO RAIN - ocean/river only!
        if age < 6 {
            return [.lullaby, .aquarium, .aquarium]
        } else if age < 12 {
            return [.softPiano, .aquarium, .aquarium]
        } else if age < 24 {
            return [.gentleGuitar, .aquarium, .aquarium]
        } else {
            return [.softPiano, .gentleGuitar, .aquarium]
        }
    }

    // MARK: - Response Sequence
    private func startResponseSequence() async {
        guard let _ = currentBaby, !soundSequence.isEmpty else {
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

        var sound: GeneratorType

        switch phase {
        case .attentionCapture:
            // Use attention-grabbing sound (with rotation)
            sound = selectAttentionSound(for: baby.ageInMonths)
            // Apply rotation - if this was recently played, pick alternative
            sound = applyRotation(to: sound, for: baby.ageInMonths, phase: phase)
        case .primarySoothing, .deepCalming:
            // Use current sequence sound
            sound = soundSequence[currentSoundIndex]
        case .adaptiveTuning:
            // Try next sound in sequence
            currentSoundIndex = (currentSoundIndex + 1) % soundSequence.count
            sound = soundSequence[currentSoundIndex]
        case .sleepTransition:
            // Quieter, sleep-inducing sound (with rotation)
            sound = selectSleepSound(for: baby.ageInMonths)
            sound = applyRotation(to: sound, for: baby.ageInMonths, phase: phase)
        default:
            sound = soundSequence.first ?? .aquarium
        }

        currentSound = sound
        adaptationMessage = "Playing: \(sound.rawValue)"

        // Track this sound for rotation (avoid repeating next time)
        trackRecentlyPlayedSound(sound)

        // Play the sound through centralized session manager
        // Emergency mode uses forceImmediate=true for instant response
        let track = createTrack(for: sound)
        print("[SmartCryResponse] ▶️ PLAYING: \(sound.rawValue) for phase: \(phase.rawValue)")
        playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)

        // Start countdown timer for UI display
        startSoundCountdown(duration: 30)

        // Record in session
        currentSession?.soundsUsed.append(sound)
    }

    /// Apply sound rotation to avoid playing the same sound on consecutive emergency activations
    private func applyRotation(to preferredSound: GeneratorType, for ageMonths: Int, phase: ResponsePhase) -> GeneratorType {
        // If preferred sound was recently played, find an alternative
        if recentlyPlayedSounds.contains(preferredSound) {
            // Get alternative sounds based on phase and age
            let alternatives: [GeneratorType]
            switch phase {
            case .attentionCapture:
                alternatives = getAttentionAlternatives(for: ageMonths)
            case .sleepTransition:
                alternatives = getSleepAlternatives(for: ageMonths)
            default:
                alternatives = getAgeFallbacks(age: ageMonths)
            }

            // Find first alternative not recently played
            for alternative in alternatives where !recentlyPlayedSounds.contains(alternative) {
                return alternative
            }

            // If all alternatives were recently played, clear history and use preferred
            recentlyPlayedSounds.removeAll()
        }

        return preferredSound
    }

    /// Track a sound as recently played for rotation purposes
    private func trackRecentlyPlayedSound(_ sound: GeneratorType) {
        // Add to recent list
        if !recentlyPlayedSounds.contains(sound) {
            recentlyPlayedSounds.append(sound)
        }

        // Keep only last N sounds
        if recentlyPlayedSounds.count > maxRecentSounds {
            recentlyPlayedSounds.removeFirst()
        }
    }

    /// Get alternative attention-grabbing sounds for rotation
    /// CRITICAL: All alternatives must be MELODIC - parents don't want noise!
    /// Noise-based sounds (shushing, white noise) can sound harsh and scary.
    private func getAttentionAlternatives(for ageMonths: Int) -> [GeneratorType] {
        if ageMonths < 6 {
            // Newborns: MELODIC sounds only - no harsh noise!
            return [.musicBox, .lullaby, .softPiano, .chimes]
        } else if ageMonths < 12 {
            // Babies: Melodic, rhythmic - music box is always great
            return [.lullaby, .musicBox, .chimes, .softPiano]
        } else if ageMonths < 24 {
            // Toddlers: Engaging melodic sounds
            return [.lullaby, .musicBox, .chimes, .softPiano]
        } else {
            // Older: Melodic variety
            return [.lullaby, .softPiano, .musicBox, .gentleGuitar]
        }
    }

    /// Get alternative sleep-inducing sounds for rotation
    /// Prioritize MELODIC sounds for sleep - lullabies are designed for this!
    /// Ocean is used instead of rain (rain is BANNED - too scary!)
    private func getSleepAlternatives(for ageMonths: Int) -> [GeneratorType] {
        if ageMonths < 6 {
            // Newborns: Lullabies are BEST for sleep, heartbeat for comfort
            // NO RAIN - replaced with pinkNoise
            return [.lullaby, .musicBox, .heartbeat, .aquarium]
        } else if ageMonths < 12 {
            // Babies: Melodic + ocean (gentler than rain)
            return [.lullaby, .musicBox, .aquarium, .aquarium]
        } else if ageMonths < 24 {
            // Toddlers: Lullabies and soft music + ocean
            return [.lullaby, .softPiano, .aquarium, .aquarium]
        } else {
            // Older: Musical options + ocean
            return [.lullaby, .softPiano, .gentleGuitar, .aquarium]
        }
    }

    private func selectAttentionSound(for ageMonths: Int) -> GeneratorType {
        // CRITICAL: ALWAYS use MELODIC sounds for attention capture!
        // Noise-based sounds (shushing, white noise) can sound scary and harsh.
        // Music box is universally calming and engaging for ALL ages.
        //
        // Research shows melodic sounds are more engaging and less startling than noise.
        // Parents consistently prefer melodic sounds over noise-based ones.
        if ageMonths < 6 {
            return .musicBox // Melodic, gentle, never scary - PERFECT for newborns
        } else if ageMonths < 12 {
            return .musicBox // Music box works great for all babies
        } else if ageMonths < 24 {
            return .lullaby // Familiar, soothing melody for toddlers
        } else {
            return .lullaby // Familiar melody for older toddlers
        }
    }

    private func selectSleepSound(for ageMonths: Int) -> GeneratorType {
        // CRITICAL: Prioritize MELODIC sounds for sleep transition!
        // Lullabies are specifically designed to induce sleep.
        // Parents universally prefer melodic sounds over noise.
        if ageMonths < 6 {
            return .lullaby // Lullabies are BEST for newborn sleep
        } else if ageMonths < 12 {
            return .lullaby // Familiar, soothing melody
        } else if ageMonths < 24 {
            return .lullaby // Still the best for toddler sleep
        } else {
            return .softPiano // Gentle piano for older toddlers
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
                // Prefer lower frequency sounds (ocean, not rain!)
                if [.aquarium, .aquarium].contains(sound) {
                    score += 0.1
                }
            } else if frequencyBias > 0 {
                // Prefer higher frequency sounds
                if [.chimes].contains(sound) {
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

        // THERMAL FIX: Increased from 5s to 8s - reduces monitoring overhead
        // Cry state changes slowly; 8s is still responsive enough for good UX
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.monitoringCheck()
            }
        }
    }

    private func monitoringCheck() async {
        evaluateEffectiveness()

        // Provide real-time feedback to SmartEmergencyQueue for dynamic reordering
        if isEmergencyMode && smartEmergencyQueue.isActive {
            let isCalmingDown = !cryDetectionService.isCryDetected ||
                                effectiveness == .partiallyEffective ||
                                effectiveness == .highlyEffective

            smartEmergencyQueue.adjustQueueForEffectiveness(isCalmingDown: isCalmingDown)
        }

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

        // Transition to sleep sound if appropriate (through session manager)
        if let baby = currentBaby {
            let sleepSound = selectSleepSound(for: baby.ageInMonths)
            if sleepSound != currentSound {
                currentSound = sleepSound
                let track = createTrack(for: sleepSound)
                playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)
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
        // CRITICAL FIX: Create fallback baby if none exists
        // Emergency mode MUST work even without a baby profile!
        // Use default 6-month baby for sound selection algorithms
        let baby: Baby
        if let existingBaby = currentBaby ?? loadActiveBaby() {
            baby = existingBaby
        } else {
            // Create a default baby profile for emergency mode
            // 6 months is a good middle ground for sound selection
            print("[SmartCryResponse] ⚠️ No baby profile found - using default (6 months)")
            baby = Baby(
                name: "Baby",
                birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            )
        }

        if !isActive {
            print("[SmartCryResponse] 🚨 CRY DETECTED! Activating emergency response...")

            // FS-017: Smart Emergency Playlist System
            // Try emergency playlist mode first if enabled
            if isEmergencyMode {
                await activateEmergencyPlaylistMode(for: baby)
            } else if useBabyMIMMode {
                // Use BabyMIM for intelligent, personalized response
                await activateWithBabyMIM(for: baby)
            } else {
                // Use traditional single-sound mode
                await activate(for: baby)
            }
        }
    }

    // MARK: - FS-017: Emergency Playlist Mode (Spotify-like Queue)

    /// Activate emergency playlist mode with SMART QUEUE (Spotify-like experience!)
    /// Uses SmartEmergencyQueue to build playlists from REAL library tracks + generated sounds
    /// NEVER plays rain - uses UltraSmartPlaylistSelector to filter banned sounds
    /// - Parameters:
    ///   - baby: The baby profile to activate emergency mode for
    ///   - preferredCategory: Optional single category to filter tracks by (legacy support)
    ///   - preferredCategories: Set of categories to combine for AI-smart playlist
    func activateEmergencyPlaylistMode(
        for baby: Baby,
        preferredCategory: AudioCategory? = nil,
        preferredCategories: Set<AudioCategory>? = nil
    ) async {
        guard !isActive else {
            print("[SmartCryResponse] ⚠️ Already active, skipping emergency activation")
            return
        }

        print("[SmartCryResponse] 🚨 ACTIVATING Smart Emergency Queue for \(baby.displayName)")

        currentBaby = baby
        isActive = true
        isEmergencyMode = true
        responseStartTime = Date()
        currentPhase = .initializing
        adaptationMessage = "Building smart playlist..."

        // CRITICAL: Configure audio session to INTERRUPT other audio (Spotify, YouTube, etc.)
        // This ensures the soothing sound plays loudly and clearly for the baby
        // Exclusive playback mode automatically pauses other apps
        audioEngine.configureAudioSession(interruptOtherAudio: true)

        // Wait for ML classification
        var cryType = cryDetectionService.cryType
        if cryType == .unknown || cryType == .general {
            print("[SmartCryResponse] ⏳ Waiting for ML classification...")
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                let updated = cryDetectionService.cryType
                if updated != .unknown && updated != .general {
                    cryType = updated
                    break
                }
            }
        }

        print("[SmartCryResponse] 🎯 Cry type: \(cryType.rawValue) - Building queue...")

        // CRITICAL: Subscribe to cry type updates for real-time adaptation!
        // When ML classification changes (e.g., unknown → tired → hungry),
        // the queue should adapt its upcoming tracks automatically
        subscribeToCryTypeUpdates()

        // Get user's preferred language
        let language = Locale.current.language.languageCode?.identifier ?? "en"

        // Determine categories to use:
        // 1. If multiple categories provided, use them (new multi-select feature)
        // 2. If single category provided, use it (legacy support)
        // 3. Otherwise, use nil for default AI selection
        let categoriesToUse: Set<AudioCategory>?
        if let multiCategories = preferredCategories, !multiCategories.isEmpty {
            categoriesToUse = multiCategories
            print("[SmartCryResponse] 🎯 Multi-category mode: \(multiCategories.map { $0.rawValue })")
            // Set manual category mode for user-selected categories
            smartEmergencyQueue.setPlaylistMode(.manualCategory)
        } else if let singleCategory = preferredCategory {
            categoriesToUse = [singleCategory]
            print("[SmartCryResponse] 🎯 Single category mode: \(singleCategory.rawValue)")
            smartEmergencyQueue.setPlaylistMode(.manualCategory)
        } else {
            categoriesToUse = nil
            print("[SmartCryResponse] 🎯 AI default mode")
            // Use AI detection mode when cry was detected by ML (not manual emergency)
            // This balances effectiveness with exploration for variety
            smartEmergencyQueue.setPlaylistMode(.aiDetection)
        }

        // Start SPOTIFY-STYLE queue using smart recommendation algorithm
        // This uses SpotifyQueueEngine which scores tracks based on:
        // - Cry stop success history (35%)
        // - Favorites (25%)
        // - Play counts (20%)
        // - Calming score (15%)
        // - Category match (5%)
        // Plus rotation policy to prevent repetition
        //
        // KEY FEATURE: Maintains 8 upcoming tracks at all times!
        // When a track finishes (7 remaining), auto-adds 1 more to replenish to 8
        await smartEmergencyQueue.startSpotifyMode(
            cryType: cryType,
            babyAge: baby.ageInMonths,
            language: language,
            preferredCategories: categoriesToUse
        )

        // Check if queue started successfully
        guard smartEmergencyQueue.isActive else {
            print("[SmartCryResponse] ⚠️ Spotify queue failed, using generated lullaby")
            // Use the generated lullaby as a single-track queue (instant, reliable)
            let defaultTrack = AudioTrack.defaultEmergencyTrack()
            await smartEmergencyQueue.startQueue(tracks: [defaultTrack])
            currentPhase = .primarySoothing
            adaptationMessage = "Playing: Soothing Lullaby"
            currentSession = ResponseSession(
                babyId: baby.id,
                babyAgeMonths: baby.ageInMonths,
                startTime: Date()
            )
            return
        }

        print("[SmartCryResponse] 🎧 SPOTIFY-STYLE queue started!")
        print("[SmartCryResponse] 📋 First 5: \(smartEmergencyQueue.upcomingTracks.prefix(5).map { $0.title })")

        currentPhase = .primarySoothing
        adaptationMessage = "Playing: \(smartEmergencyQueue.queueName)"

        // Initialize session for tracking
        currentSession = ResponseSession(
            babyId: baby.id,
            babyAgeMonths: baby.ageInMonths,
            startTime: Date()
        )
        currentSession?.cryType = cryType
    }

    /// Get the active SmartEmergencyQueue for UI display
    var activeQueue: SmartEmergencyQueue {
        return smartEmergencyQueue
    }

    /// Enable emergency playlist mode for next cry detection
    func enableEmergencyPlaylistMode() {
        isEmergencyMode = true
        print("[SmartCryResponse] ✅ Emergency playlist mode enabled")
    }

    /// Disable emergency playlist mode
    func disableEmergencyPlaylistMode() {
        isEmergencyMode = false
        print("[SmartCryResponse] 🔇 Emergency playlist mode disabled")
    }

    /// Cancel emergency playlist mode and return to normal
    func cancelEmergencyMode() async {
        // Stop the smart emergency queue
        await smartEmergencyQueue.stop(wasEffective: nil)

        // Reset state
        await MainActor.run {
            self.isActive = false
            self.currentPhase = .idle
        }

        // Stop audio through session manager (proper cleanup)
        playbackSession.stopPlayback(from: .emergencyMode)

        print("✅ Emergency mode canceled - smart queue stopped")
    }

    // MARK: - BabyMIM-Powered Response (Revolutionary AI)
    /// Activate response using BabyMIM's intelligent decision-making
    /// This is the primary recommended mode for personalized soothing
    private func activateWithBabyMIM(for baby: Baby) async {
        guard !isActive else { return }

        currentBaby = baby
        isActive = true
        responseStartTime = Date()
        currentPhase = .initializing
        adaptationMessage = "BabyMIM analyzing cry pattern..."

        // Initialize new session
        currentSession = ResponseSession(
            babyId: baby.id,
            babyAgeMonths: baby.ageInMonths,
            startTime: Date()
        )

        // BabyMIM not available - use fallback immediately
        print("BabyMIM not available. Using traditional mode.")
        await activate(for: baby)

        /* Original BabyMIM code:
        do {
            let mimResponse = try await babyMoodIntelligence.generateResponse(for: baby.id, babyAge: baby.ageInMonths)

            // Update UI with BabyMIM's analysis
            mimAnalysis = mimResponse.analysisText
            mimConfidence = mimResponse.recommendation.confidence
            if let tip = mimResponse.parentTip {
                mimParentTip = tip.tip
            }

            // Convert BabyMIM's recommendation to our sound sequence
            soundSequence = convertMIMRecommendationToSounds(mimResponse.recommendation)
            currentSoundIndex = 0

            // Set strategy based on MIM's analysis
            currentStrategy = mapMIMApproachToStrategy(mimResponse.recommendation.primaryApproach)

            // Update adaptation message with AI reasoning
            adaptationMessage = "BabyMIM: \(mimResponse.recommendation.reasoning)"

            // Build and play the intelligent sound mix
            await playBabyMIMSoundMix(mimResponse.soundMix, baby: baby)

            // Start BabyMIM monitoring loop
            startBabyMIMMonitoring(for: baby)

        } catch {
            // Fallback to traditional response if BabyMIM fails
            print("BabyMIM error: \(error). Falling back to traditional mode.")
            await activate(for: baby)
        }
        */
    }

    /// Convert BabyMIM recommendation to sound sequence
    private func convertMIMRecommendationToSounds(_ recommendation: SoothingRecommendation) -> [GeneratorType] {
        // SoundSelection already contains GeneratorType directly
        let sounds = recommendation.soundSequence.map { $0.sound }

        // Ensure we have at least some sounds (NO RAIN!)
        if sounds.isEmpty {
            return [.aquarium, .aquarium]
        }

        return sounds
    }

    /// Match BabyMIM sound name to GeneratorType
    private func matchSoundNameToGenerator(_ name: String) -> GeneratorType? {
        let lowercaseName = name.lowercased()

        // Direct matches (FORBIDDEN: rain, thunder, storm, wind, vacuum, fan, white/pink/brown noise)
        let mapping: [String: GeneratorType] = [
            // ❌ ALL noise generators REMOVED (scary for babies!)
            // ❌ "rain" REMOVED (scary, unpredictable)
            // ❌ "vacuum", "fan" REMOVED (harsh mechanical sounds)
            "ocean": .aquarium,
            "river": .aquarium,
            "music box": .musicBox,
            "lullaby": .musicBox,
            "gentle piano": .softPiano,
            "soft piano": .softPiano,
        ]

        for (key, value) in mapping {
            if lowercaseName.contains(key) {
                return value
            }
        }

        return nil
    }

    /// Map BabyMIM approach to SoothingStrategy
    private func mapMIMApproachToStrategy(_ approach: String) -> SoothingStrategy {
        let lowercased = approach.lowercased()

        if lowercased.contains("sleep") || lowercased.contains("drowsy") {
            return .sleepInduction
        } else if lowercased.contains("distract") || lowercased.contains("engage") {
            return .distraction
        } else if lowercased.contains("urgent") || lowercased.contains("immediate") || lowercased.contains("pain") {
            return .urgent
        } else if lowercased.contains("comfort") || lowercased.contains("reassure") {
            return .comfort
        } else if lowercased.contains("gentle") || lowercased.contains("calm") {
            return .gentle
        } else {
            return .adaptive
        }
    }

    /// Play BabyMIM's intelligent sound mix
    private func playBabyMIMSoundMix(_ mix: DynamicSoundMix, baby: Baby) async {
        currentPhase = .primarySoothing

        // Get the primary sound from the mix
        guard let primaryLayer = mix.layers.first else {
            // Fallback - immediate playback for emergency mode through session manager
            let track = createTrack(for: .aquarium)
            playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)
            return
        }

        // SoundLayer.sound is already a GeneratorType
        currentSound = primaryLayer.sound
        let track = createTrack(for: primaryLayer.sound)
        playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)

        // Apply volume from primary layer
        audioEngine.setVolume(primaryLayer.volume)

        currentSession?.soundsUsed.append(currentSound ?? .aquarium)
    }

    /// Start BabyMIM monitoring loop for continuous adaptation
    private func startBabyMIMMonitoring(for baby: Baby) {
        currentPhase = .monitoring

        // THERMAL FIX: Increased from 3s to 5s - reduces BabyMIM monitoring overhead by 40%
        // ML-based adaptation doesn't need 3s precision; 5s is sufficient for good UX
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.babyMIMMonitoringCheck(for: baby)
            }
        }
    }

    /// BabyMIM-powered monitoring check
    private func babyMIMMonitoringCheck(for baby: Baby) async {
        // Check cry state
        let isCrying = cryDetectionService.isCryDetected
        // Note: cryIntensity is evaluated in evaluateEffectiveness() below
        _ = cryDetectionService.cryIntensity

        if !isCrying {
            // Baby calmed down - success!
            await transitionToSuccessWithBabyMIM(for: baby)
            return
        }

        // Update effectiveness based on intensity change
        evaluateEffectiveness()

        // If not working well, ask BabyMIM for adaptation
        if effectiveness == .notWorking || effectiveness == .partiallyEffective {
            consecutiveIneffectivePhases += 1

            if consecutiveIneffectivePhases >= 2 {
                // BabyMIM not available - use traditional escalation
                adaptationMessage = "Adapting approach..."
                await escalateResponse()
                consecutiveIneffectivePhases = 0
            }
        } else {
            // Working - reset counter
            consecutiveIneffectivePhases = 0
            adaptationMessage = "BabyMIM: Current approach working well"
        }
    }

    /// Transition to success with BabyMIM learning
    private func transitionToSuccessWithBabyMIM(for baby: Baby) async {
        currentPhase = .success
        effectiveness = .highlyEffective
        adaptationMessage = "BabyMIM: Baby has calmed! Recording what worked..."

        // Record success with BabyMIM for learning
        if let sound = currentSound {
            recordSoothingSuccess(sound: sound, babyId: baby.id, cryType: cryDetectionService.cryType)

            // BabyMIM not available - skip feedback
            // babyMoodIntelligence.recordFeedback(
            //     wasEffective: true,
            //     feedbackType: .itHelped,
            //     cryIntensityAfter: 0
            // )
        }

        // Update parent tip
        mimParentTip = "Great! This combination worked. I'll remember this for next time."

        // Keep monitoring briefly then deactivate
        try? await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds

        if !cryDetectionService.isCryDetected {
            deactivate()
        }
    }

    // MARK: - Public BabyMIM Control Methods

    /// Toggle between BabyMIM mode and traditional mode
    func toggleBabyMIMMode() {
        useBabyMIMMode.toggle()
    }

    /// Record manual "It Helped!" feedback for BabyMIM learning
    func recordItHelped() {
        guard let baby = currentBaby else { return }

        // BabyMIM not available - skip feedback
        // babyMoodIntelligence.recordFeedback(
        //     wasEffective: true,
        //     feedbackType: .itHelped,
        //     cryIntensityAfter: cryDetectionService.cryIntensity
        // )

        // Also record in traditional system
        if let sound = currentSound {
            recordSoothingSuccess(sound: sound, babyId: baby.id, cryType: cryDetectionService.cryType)
        }

        adaptationMessage = "Thanks! Learning from this success."
    }

    /// Record manual "Not Working" feedback for BabyMIM learning
    func recordNotWorking() {
        // BabyMIM not available - skip feedback
        // babyMoodIntelligence.recordFeedback(
        //     wasEffective: false,
        //     feedbackType: .notWorking,
        //     cryIntensityAfter: cryDetectionService.cryIntensity
        // )

        adaptationMessage = "Got it. BabyMIM is trying a different approach..."

        // Trigger immediate adaptation
        if let baby = currentBaby {
            Task {
                await babyMIMMonitoringCheck(for: baby)
            }
        }
    }

    /// Get BabyMIM's current mood analysis for the baby
    func getBabyMoodInsights() -> (analysis: String, confidence: Double, tip: String) {
        return (mimAnalysis, mimConfidence, mimParentTip)
    }

    // MARK: - Sound Switching (UI Controls)

    /// Alternative sounds to display in UI for manual switching
    /// Returns sounds from the sequence that aren't currently playing
    var alternativeSounds: [GeneratorType] {
        guard let current = currentSound else {
            return Array(soundSequence.prefix(3))
        }
        // Return next sounds in sequence, excluding current
        return soundSequence.filter { $0 != current }.prefix(3).map { $0 }
    }

    /// Manually switch to a specific sound (user tapped alternative sound button)
    func switchToSound(_ sound: GeneratorType) {
        guard isActive else { return }

        print("[SmartCryResponse] 🔄 User switched to: \(sound.rawValue)")

        // Update state
        currentSound = sound
        adaptationMessage = "Switched to: \(sound.rawValue)"

        // Track this sound for rotation
        trackRecentlyPlayedSound(sound)

        // Reset countdown timer
        resetSoundCountdown()

        // Play the new sound through session manager (instant for emergency)
        let track = createTrack(for: sound)
        playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)

        // Record in session
        currentSession?.soundsUsed.append(sound)
    }

    /// Start countdown timer for auto-switch - 20 seconds for quick transitions
    /// If sound doesn't help within 20 seconds, automatically try the next one
    private func startSoundCountdown(duration: TimeInterval = 20) {
        secondsUntilNextSound = duration
        countdownTimer?.invalidate()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isActive else {
                    self?.countdownTimer?.invalidate()
                    return
                }

                if self.secondsUntilNextSound > 0 {
                    self.secondsUntilNextSound -= 1
                } else {
                    // AUTO-SWITCH TRIGGERED!
                    // Try the next sound in the sequence automatically
                    await self.autoSwitchToNextSound()
                    self.secondsUntilNextSound = 20 // Reset for next 20-second cycle
                }
            }
        }
    }

    /// Automatically switch to the next sound in the sequence
    /// Called when the 20-second timer expires
    private func autoSwitchToNextSound() async {
        guard isActive, !soundSequence.isEmpty else { return }

        // Move to next sound in sequence
        currentSoundIndex = (currentSoundIndex + 1) % soundSequence.count
        let nextSound = soundSequence[currentSoundIndex]

        print("[SmartCryResponse] ⏰ Auto-switch triggered: \(currentSound?.rawValue ?? "none") → \(nextSound.rawValue)")

        // Update state
        currentSound = nextSound
        adaptationMessage = "Trying: \(nextSound.rawValue)"

        // Track this sound
        trackRecentlyPlayedSound(nextSound)

        // Play the new sound through session manager (instant for emergency)
        let track = createTrack(for: nextSound)
        playbackSession.requestPlayback(track: track, from: .singleSound, forceImmediate: true)

        // Record in session
        currentSession?.soundsUsed.append(nextSound)
    }

    /// Reset countdown when sound changes (20-second cycles)
    private func resetSoundCountdown() {
        secondsUntilNextSound = 20
    }

    /// Stop countdown timer
    private func stopSoundCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        secondsUntilNextSound = 20
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
        // Record in ultra-smart selector for ML-style learning
        let calmingTime = Int(currentSession?.duration ?? 60)
        ultraSmartSelector.recordEffectiveness(
            sound: sound,
            cryType: cryType,
            wasEffective: true,
            calmingTimeSeconds: calmingTime
        )

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
