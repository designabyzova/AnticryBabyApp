//
//  AIRecommendationEngine.swift
//  BabyInCarApp
//
//  AI-powered recommendation engine for age-personalized content
//

import Foundation
import Combine

@MainActor
class AIRecommendationEngine: ObservableObject {
    static let shared = AIRecommendationEngine()

    @Published var isLoading: Bool = false
    @Published var recommendations: [AudioTrack] = []
    @Published var emergencyTracks: [AudioTrack] = []

    private let contentLibrary = ContentLibraryService.shared

    private init() {}

    // MARK: - Age-Based Recommendations

    /// Get personalized playlist for baby's age
    func getPersonalizedPlaylist(for baby: Baby, category: AudioCategory? = nil, languages: [Language]? = nil, count: Int = 10) async -> Playlist {
        isLoading = true
        defer { isLoading = false }

        let ageMonths = baby.ageInMonths
        let stage = baby.developmentalStage
        let allTracks = contentLibrary.getAllTracks()

        var filteredTracks = allTracks.filter { track in
            // Filter by age appropriateness
            guard track.ageRangeMin <= ageMonths && track.ageRangeMax >= ageMonths else {
                return false
            }

            // Filter by category if specified
            if let category = category {
                guard track.category == category else { return false }
            }

            // Filter by language if specified and track has a language
            // (non-language content like ambient/nature sounds passes through)
            if let languages = languages, !languages.isEmpty {
                if let trackLanguage = track.language {
                    guard languages.contains(trackLanguage) else { return false }
                }
                // Tracks without language (instrumental, ambient, nature) are always included
            }

            return true
        }

        // Sort by relevance score
        filteredTracks.sort { track1, track2 in
            calculateRelevanceScore(track: track1, ageMonths: ageMonths, stage: stage) >
            calculateRelevanceScore(track: track2, ageMonths: ageMonths, stage: stage)
        }

        let selectedTracks = Array(filteredTracks.prefix(count))

        let playlistName: String
        if let category = category {
            playlistName = "\(category.rawValue) for \(baby.formattedAge)"
        } else {
            playlistName = "Perfect for \(baby.displayName)"
        }

        return Playlist(
            name: playlistName,
            description: stage.description,
            tracks: selectedTracks,
            category: category,
            targetAgeMonths: ageMonths,
            isSystemGenerated: true
        )
    }

    /// Get quick picks for home screen
    func getQuickPicks(for baby: Baby, languages: [Language]? = nil) async -> [Playlist] {
        let stage = baby.developmentalStage
        var playlists: [Playlist] = []

        // Get recommended categories for this developmental stage
        for category in stage.recommendedCategories.prefix(6) {
            let playlist = await getPersonalizedPlaylist(for: baby, category: category, languages: languages, count: 5)
            playlists.append(playlist)
        }

        return playlists
    }

    /// Get emergency cry-stop tracks (highest calming scores for age)
    func getEmergencyTracks(for baby: Baby) -> [AudioTrack] {
        let ageMonths = baby.ageInMonths
        let allTracks = contentLibrary.getAllTracks()

        return allTracks
            .filter { $0.ageRangeMin <= ageMonths && $0.ageRangeMax >= ageMonths }
            .sorted { $0.calmingScore > $1.calmingScore }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Relevance Scoring

    private func calculateRelevanceScore(track: AudioTrack, ageMonths: Int, stage: DevelopmentalStage) -> Double {
        var score: Double = 0

        // Base calming score (0-1)
        score += track.calmingScore * 0.4

        // Optimal age match bonus
        if track.isOptimalFor(ageMonths: ageMonths) {
            score += 0.3
        }

        // Category relevance for developmental stage
        if stage.recommendedCategories.contains(track.category) {
            score += 0.2
        }

        // Tempo match bonus
        if let trackTempo = track.tempoBPM {
            let stageCharacteristics = stage.audioCharacteristics
            if stageCharacteristics.tempoBPM.contains(trackTempo) {
                score += 0.1
            }
        }

        return score
    }

    // MARK: - Mood-Based Recommendations

    enum Mood: String, CaseIterable {
        case sleepy = "Sleepy"
        case crying = "Crying"
        case playful = "Playful"
        case calm = "Calm"
        case fussy = "Fussy"
        case restless = "Restless"
        case overtired = "Overtired"

        var preferredCategories: [AudioCategory] {
            switch self {
            case .sleepy:
                return [.ambient, .classicalMusic, .lullabies]
            case .crying:
                return [.ambient, .natureSounds, .instrumental]
            case .playful:
                return [.childrenSongs, .fairyTales, .instrumental]
            case .calm:
                return [.classicalMusic, .natureSounds, .podcasts]
            case .fussy:
                return [.ambient, .natureSounds, .classicalMusic]
            case .restless:
                return [.ambient, .natureSounds, .instrumental]
            case .overtired:
                return [.ambient, .lullabies, .classicalMusic]
            }
        }

        var preferredGenerators: [GeneratorType] {
            switch self {
            case .sleepy:
                return [.aquarium, .lullaby, .aquarium, .softPiano]
            case .crying:
                return [.shushing, .womb, .heartbeat, .aquarium]
            case .playful:
                return [.musicBox, .chimes, .chimes, .aquarium, .bells]
            case .calm:
                return [.aquarium, .aquarium, .softPiano, .bells]
            case .fussy:
                return [.shushing, .womb, .aquarium, .heartbeat]
            case .restless:
                return [.aquarium, .aquarium, .bells, .softPiano]
            case .overtired:
                return [.womb, .aquarium, .gentleGuitar, .softPiano]
            }
        }

        /// Get age-appropriate generators for this mood
        func preferredGeneratorsForAge(_ ageMonths: Int) -> [GeneratorType] {
            var generators = preferredGenerators

            // Adjust for toddlers (12+ months)
            if ageMonths >= 12 {
                switch self {
                case .sleepy:
                    generators = [.bells, .aquarium, .aquarium, .softPiano, .gentleGuitar, .softPiano]
                case .crying:
                    generators = [.aquarium, .bells, .lullaby, .softPiano, .aquarium]
                case .playful:
                    generators = [.bells, .chimes, .aquarium, .chimes, .musicBox]
                case .calm:
                    generators = [.bells, .softPiano, .bells, .softPiano, .gentleGuitar, .aquarium]
                case .fussy:
                    generators = [.aquarium, .bells, .lullaby, .aquarium, .aquarium]
                case .restless:
                    generators = [.lullaby, .softPiano, .bells, .bells, .chimes]
                case .overtired:
                    generators = [.aquarium, .bells, .aquarium, .softPiano, .softPiano]
                }
            }

            return generators
        }
    }

    func getPlaylistForMood(_ mood: Mood, baby: Baby) async -> Playlist {
        let ageMonths = baby.ageInMonths
        var tracks: [AudioTrack] = []

        // Get age-appropriate generators for this mood
        let ageAppropriateGenerators = mood.preferredGeneratorsForAge(ageMonths)

        // Add generated tracks for preferred sound types
        for generator in ageAppropriateGenerators.prefix(4) {
            let track = AudioTrack(
                title: generator.rawValue,
                category: generator.category,
                duration: 1800, // 30 minutes
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            )
            tracks.append(track)
        }

        // Add matching tracks from library
        for category in mood.preferredCategories {
            let categoryTracks = contentLibrary.getTracks(for: category)
                .filter { $0.ageRangeMin <= ageMonths && $0.ageRangeMax >= ageMonths }
                .sorted { $0.calmingScore > $1.calmingScore }
                .prefix(2)
            tracks.append(contentsOf: categoryTracks)
        }

        let ageDescription = ageMonths >= 12 ? "toddler" : "baby"
        return Playlist(
            name: "\(mood.rawValue) Mode",
            description: "Age-optimized sounds for when \(ageDescription) is \(mood.rawValue.lowercased())",
            tracks: tracks,
            targetAgeMonths: ageMonths,
            isSystemGenerated: true
        )
    }

    // MARK: - Trip Duration Recommendations

    enum TripDuration: String, CaseIterable {
        case quickTrip = "Quick Trip"      // 15-30 min
        case mediumTrip = "Medium Trip"    // 30-60 min
        case longTrip = "Long Trip"        // 1-2 hours
        case roadTrip = "Road Trip"        // 2+ hours

        var durationRange: ClosedRange<TimeInterval> {
            switch self {
            case .quickTrip: return 900...1800
            case .mediumTrip: return 1800...3600
            case .longTrip: return 3600...7200
            case .roadTrip: return 7200...14400
            }
        }

        var trackCount: Int {
            switch self {
            case .quickTrip: return 5
            case .mediumTrip: return 10
            case .longTrip: return 20
            case .roadTrip: return 40
            }
        }
    }

    func getPlaylistForTrip(_ duration: TripDuration, baby: Baby) async -> Playlist {
        let ageMonths = baby.ageInMonths
        let stage = baby.developmentalStage
        var tracks: [AudioTrack] = []

        // Mix of calming sounds and engaging content based on age
        let calmingRatio = ageMonths < 6 ? 0.8 : (ageMonths < 12 ? 0.6 : 0.4)
        let calmingCount = Int(Double(duration.trackCount) * calmingRatio)
        let engagingCount = duration.trackCount - calmingCount

        // Age-appropriate calming generators
        let calmingGenerators: [GeneratorType]
        if ageMonths >= 18 {
            // Toddlers prefer more complex, engaging sounds
            calmingGenerators = [.bells, .aquarium, .lullaby, .aquarium, .softPiano, .bells, .softPiano]
        } else if ageMonths >= 12 {
            // Older babies - transitioning to more varied sounds
            calmingGenerators = [.bells, .aquarium, .aquarium, .aquarium, .aquarium, .softPiano]
        } else if ageMonths >= 6 {
            // 6-12 months
            calmingGenerators = [.aquarium, .aquarium, .womb, .bells, .lullaby]
        } else {
            // Newborns - stick to womb-like sounds
            calmingGenerators = [.aquarium, .shushing, .womb, .heartbeat, .aquarium]
        }

        for i in 0..<calmingCount {
            let generator = calmingGenerators[i % calmingGenerators.count]
            let track = AudioTrack(
                title: generator.rawValue,
                category: generator.category,
                duration: 600, // 10 minutes each
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            )
            tracks.append(track)
        }

        // Add engaging content
        let engagingCategories: [AudioCategory] = stage.recommendedCategories
        for category in engagingCategories {
            let categoryTracks = contentLibrary.getTracks(for: category)
                .filter { $0.ageRangeMin <= ageMonths && $0.ageRangeMax >= ageMonths }
                .prefix(engagingCount / engagingCategories.count + 1)
            tracks.append(contentsOf: categoryTracks)
        }

        // Shuffle for variety
        tracks.shuffle()

        let ageDescription = ageMonths >= 12 ? "toddler" : "baby"
        return Playlist(
            name: duration.rawValue,
            description: "Age-optimized sounds for \(duration.rawValue.lowercased())s with your \(ageDescription)",
            tracks: Array(tracks.prefix(duration.trackCount)),
            targetAgeMonths: ageMonths,
            isSystemGenerated: true
        )
    }

    // MARK: - Learning & Adaptation

    /// Record effectiveness of a track for future recommendations
    func recordTrackEffectiveness(track: AudioTrack, baby: Baby, wasEffective: Bool) {
        // Store in UserDefaults or local database
        let key = "effectiveness_\(track.id.uuidString)_\(baby.ageInMonths)"
        UserDefaults.standard.set(wasEffective, forKey: key)

        // Update local recommendations cache
        if wasEffective {
            // Boost similar tracks
        } else {
            // Reduce weight of similar tracks
        }
    }

    /// Get track history for baby
    func getEffectiveTracks(for baby: Baby) -> [UUID] {
        var effectiveTrackIds: [UUID] = []

        // Retrieve from storage
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let prefix = "effectiveness_"
        let suffix = "_\(baby.ageInMonths)"

        for key in allKeys where key.hasPrefix(prefix) && key.hasSuffix(suffix) {
            if UserDefaults.standard.bool(forKey: key) {
                let uuidString = String(key.dropFirst(prefix.count).dropLast(suffix.count))
                if let uuid = UUID(uuidString: uuidString) {
                    effectiveTrackIds.append(uuid)
                }
            }
        }

        return effectiveTrackIds
    }
}

// MARK: - Emergency Cry-Stop Service
/// Enhanced emergency cry-stop service with AI-powered detection and adaptive response
@MainActor
class EmergencyCryStopService: ObservableObject {
    static let shared = EmergencyCryStopService()

    // MARK: - Published State
    @Published var isEmergencyModeActive: Bool = false
    @Published var currentPhase: CalmingPhase = .idle
    @Published var phaseProgress: Double = 0
    @Published var isAIMonitoringEnabled: Bool = false
    @Published var cryDetectionStatus: String = "Ready"
    @Published var detectedCryType: CryType = .unknown
    @Published var responseEffectiveness: String = ""

    // MARK: - Services
    private var phaseTimer: Timer?
    private let audioEngine = AudioEngine.shared
    private let cryDetectionService = CryDetectionService.shared
    private let smartResponseEngine = SmartCryResponseEngine.shared

    // MARK: - State
    private var currentBaby: Baby?
    private var sessionStartTime: Date?
    private var useSmartResponse: Bool = true

    enum CalmingPhase: String {
        case idle = "Ready"
        case listening = "Listening for Cry"
        case detected = "Cry Detected"
        case attention = "Getting Attention"
        case transition = "Calming Down"
        case sustained = "Sustained Soothing"
        case adapting = "Adapting Response"
        case complete = "Baby Calm"

        var duration: TimeInterval {
            switch self {
            case .idle, .complete, .listening, .detected: return 0
            case .attention: return 30
            case .transition: return 60
            case .sustained: return 300
            case .adapting: return 30
            }
        }

        var description: String {
            switch self {
            case .idle:
                return "Tap to activate emergency mode"
            case .listening:
                return "AI is listening for baby crying"
            case .detected:
                return "Cry detected! Starting response..."
            case .attention:
                return "Playing attention-grabbing sounds"
            case .transition:
                return "Transitioning to calming sounds"
            case .sustained:
                return "Maintaining soothing environment"
            case .adapting:
                return "AI is adjusting the response"
            case .complete:
                return "Baby has calmed down"
            }
        }
    }

    private init() {
        setupObservers()
    }

    // MARK: - Setup
    private func setupObservers() {
        // Observe cry detection
        cryDetectionService.$isCryDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.handleCryDetectionChange(detected)
            }
            .store(in: &cancellables)

        cryDetectionService.$cryType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                self?.detectedCryType = type
            }
            .store(in: &cancellables)

        cryDetectionService.$detectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.cryDetectionStatus = status.rawValue
            }
            .store(in: &cancellables)

        smartResponseEngine.$effectiveness
            .receive(on: DispatchQueue.main)
            .sink { [weak self] effectiveness in
                self?.responseEffectiveness = effectiveness.rawValue
            }
            .store(in: &cancellables)

        // Sync SmartCryResponseEngine phase with our phase for UI display
        smartResponseEngine.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] smartPhase in
                guard let self = self, self.isEmergencyModeActive else { return }
                // Map SmartCryResponseEngine phases to EmergencyCryStopService phases
                switch smartPhase {
                case .idle:
                    break // Don't update - let our state machine handle idle
                case .initializing:
                    self.currentPhase = .detected
                case .attentionCapture:
                    self.currentPhase = .attention
                case .primarySoothing, .deepCalming:
                    self.currentPhase = .sustained
                case .adaptiveTuning, .escalating:
                    self.currentPhase = .adapting
                case .sleepTransition, .monitoring:
                    self.currentPhase = .transition
                case .success:
                    self.currentPhase = .complete
                }
            }
            .store(in: &cancellables)

        // Sync phase progress
        smartResponseEngine.$phaseProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.phaseProgress = progress
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - AI Monitoring
    /// Enable AI-powered automatic cry detection and response
    func enableAIMonitoring(for baby: Baby) async throws {
        currentBaby = baby
        isAIMonitoringEnabled = true
        currentPhase = .listening

        try await cryDetectionService.startMonitoring()
        cryDetectionStatus = "AI monitoring active"
    }

    /// Disable AI monitoring
    func disableAIMonitoring() {
        print("[EmergencyCryStop] Disabling AI monitoring...")

        // Stop cry detection service first
        cryDetectionService.stopMonitoring()

        // ALWAYS stop smart response engine (stops audio)
        // Call regardless of isEmergencyModeActive flag - ensures audio stops
        smartResponseEngine.deactivate()

        // Stop any active emergency response
        if isEmergencyModeActive {
            deactivate()
        }

        // SAFETY: Explicitly stop audio engine as fallback
        // In case any audio is playing outside of smart response
        audioEngine.stop()

        // Always reset UI state
        isAIMonitoringEnabled = false
        currentPhase = .idle
        cryDetectionStatus = "Ready"
        detectedCryType = .unknown
        phaseProgress = 0

        // Cancel any pending timers
        phaseTimer?.invalidate()
        phaseTimer = nil

        print("[EmergencyCryStop] AI monitoring disabled - all audio stopped, state reset")
    }

    private func handleCryDetectionChange(_ detected: Bool) {
        // Only log when actually detecting a cry (reduces noise during startup/idle)
        if detected {
            print("[EmergencyCryStop] handleCryDetectionChange: detected=\(detected), isAIMonitoringEnabled=\(isAIMonitoringEnabled), isEmergencyModeActive=\(isEmergencyModeActive)")
        }

        guard isAIMonitoringEnabled, let baby = currentBaby else {
            // Only warn when cry is detected but we can't respond (not during routine false->false transitions)
            if detected {
                print("[EmergencyCryStop] ⚠️ Cry detected but AI monitoring not enabled or no baby set")
            }
            return
        }

        if detected && !isEmergencyModeActive {
            print("[EmergencyCryStop] 🔴 CRY DETECTED - Starting confirmation period for \(baby.displayName)")
            currentPhase = .detected
            Task {
                // FIXED: Reduced from 4s to 1.5s - speech detection now filters false positives
                // 1.5s is enough to filter brief noises while being responsive to real cries
                let confirmationDuration: Double = 1.5
                print("[EmergencyCryStop] ⏳ Confirming cry for \(String(format: "%.1f", confirmationDuration))s...")

                // Check every 0.5 seconds for 1.5 seconds (3 checks total)
                for check in 1...3 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // If cry stopped during confirmation, it was a false positive
                    if !cryDetectionService.isCryDetected {
                        print("[EmergencyCryStop] ℹ️ False positive at check \(check)/3 - cry stopped before confirmation")
                        currentPhase = isAIMonitoringEnabled ? .listening : .idle
                        return
                    }
                    print("[EmergencyCryStop] ⏳ Cry still detected at check \(check)/3...")
                }

                // Cry persisted for full confirmation period
                print("[EmergencyCryStop] 🎵 Confirmed cry after \(String(format: "%.1f", confirmationDuration))s - activating SmartCryResponseEngine")
                if useSmartResponse {
                    await smartResponseEngine.activate(for: baby)
                    isEmergencyModeActive = true
                } else {
                    activate(for: baby)
                }
            }
        } else if !detected && isEmergencyModeActive {
            // Baby stopped crying
            if smartResponseEngine.isActive {
                // Let smart engine handle it
            } else {
                reportSuccess(for: baby)
            }
        }
    }

    // MARK: - Manual Activation
    /// Manually activate emergency cry-stop mode
    /// Uses GENERATED SOUNDS (womb/heartbeat) via NoiseGenerator - NOT real audio files!
    /// This ensures instant playback with NO file loading delays
    func activate(for baby: Baby) {
        currentBaby = baby
        isEmergencyModeActive = true
        currentPhase = .attention
        sessionStartTime = Date()

        // 🚨 CRITICAL: Use single-sound mode with GENERATED sounds (womb/heartbeat)
        // This uses NoiseGenerator for instant audio without file loading
        // NEVER use activateEmergencyPlaylistMode() - that tries to load files from bundle!
        Task {
            await smartResponseEngine.activate(for: baby)

            // ✅ Auto-enable AI monitoring if not already active (Increment 0026)
            // This ensures both emergency and AI detection buttons provide consistent monitoring behavior
            if !isAIMonitoringEnabled {
                try? await enableAIMonitoring(for: baby)
            }
        }
    }

    func deactivate() {
        isEmergencyModeActive = false
        currentPhase = isAIMonitoringEnabled ? .listening : .idle
        phaseProgress = 0
        phaseTimer?.invalidate()
        phaseTimer = nil

        if smartResponseEngine.isActive {
            smartResponseEngine.deactivate()
        }
    }

    // MARK: - Phase Management
    private func startPhase(_ phase: CalmingPhase, baby: Baby) {
        currentPhase = phase
        phaseProgress = 0

        // Select appropriate audio for phase
        let track = getTrackForPhase(phase, baby: baby)
        audioEngine.play(track: track)

        // Update progress
        let phaseDuration = phase.duration
        phaseTimer?.invalidate()

        if phaseDuration > 0 {
            phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }

                    self.phaseProgress += 0.5 / phaseDuration

                    // Check if cry stopped
                    if self.isAIMonitoringEnabled && !self.cryDetectionService.isCryDetected {
                        timer.invalidate()
                        self.currentPhase = .complete
                        return
                    }

                    if self.phaseProgress >= 1.0 {
                        timer.invalidate()
                        self.advanceToNextPhase(baby: baby)
                    }
                }
            }
        }
    }

    private func advanceToNextPhase(baby: Baby) {
        // If AI monitoring, check if we should adapt
        if isAIMonitoringEnabled && cryDetectionService.isCryDetected {
            let intensity = cryDetectionService.cryIntensity
            if intensity > 0.6 && currentPhase == .transition {
                // Not working well, try adapting
                currentPhase = .adapting
                tryAdaptiveResponse(for: baby)
                return
            }
        }

        switch currentPhase {
        case .attention:
            startPhase(.transition, baby: baby)
        case .transition:
            startPhase(.sustained, baby: baby)
        case .sustained:
            currentPhase = .complete
            // Continue playing sustained audio
        case .adapting:
            startPhase(.transition, baby: baby)
        default:
            break
        }
    }

    private func tryAdaptiveResponse(for baby: Baby) {
        // Use cry type to select alternative approach
        let cryType = cryDetectionService.cryType
        let ageMonths = baby.ageInMonths

        let adaptedGenerator: GeneratorType
        switch cryType {
        case .tired:
            adaptedGenerator = ageMonths < 12 ? .aquarium : .aquarium
        case .hunger:
            adaptedGenerator = ageMonths < 12 ? .shushing : .aquarium
        case .pain:
            adaptedGenerator = ageMonths < 12 ? .shushing : .aquarium
        case .attention:
            adaptedGenerator = ageMonths < 18 ? .musicBox : .aquarium
        case .discomfort:
            adaptedGenerator = ageMonths < 12 ? .womb : .bells
        default:
            adaptedGenerator = ageMonths < 12 ? .womb : .aquarium
        }

        let track = AudioTrack(
            title: "Adapted: \(adaptedGenerator.rawValue)",
            category: .ambient,
            duration: 60,
            calmingScore: 0.9,
            audioSourceType: .generated,
            generatorType: adaptedGenerator
        )

        audioEngine.play(track: track)

        // Wait and re-evaluate
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.advanceToNextPhase(baby: baby)
            }
        }
    }

    // MARK: - Track Selection
    private func getTrackForPhase(_ phase: CalmingPhase, baby: Baby) -> AudioTrack {
        let ageMonths = baby.ageInMonths

        // If AI is available, use detected cry type for smarter selection
        let cryType = isAIMonitoringEnabled ? cryDetectionService.cryType : .unknown

        switch phase {
        case .attention:
            let generator = getAttentionGenerator(age: ageMonths, cryType: cryType)
            return AudioTrack(
                title: "Attention Grabber",
                category: .ambient,
                duration: 30,
                calmingScore: 0.9,
                audioSourceType: .generated,
                generatorType: generator
            )

        case .transition:
            let generator = getTransitionGenerator(age: ageMonths, cryType: cryType)
            return AudioTrack(
                title: "Calming Transition",
                category: .ambient,
                duration: 60,
                calmingScore: 0.95,
                audioSourceType: .generated,
                generatorType: generator
            )

        case .sustained:
            let generator = getSustainedGenerator(age: ageMonths, cryType: cryType)
            return AudioTrack(
                title: "Sustained Soothing",
                category: .natureSounds,
                duration: 300,
                calmingScore: 0.92,
                audioSourceType: .generated,
                generatorType: generator
            )

        default:
            let generator: GeneratorType = ageMonths >= 12 ? .aquarium : .womb
            return AudioTrack(
                title: generator.rawValue,
                category: .ambient,
                duration: 600,
                calmingScore: 0.9,
                audioSourceType: .generated,
                generatorType: generator
            )
        }
    }

    private func getAttentionGenerator(age: Int, cryType: CryType) -> GeneratorType {
        // Smarter selection based on cry type (NO harsh mechanical sounds!)
        switch cryType {
        case .pain:
            // Urgent - use soothing womb sounds
            return age < 12 ? .shushing : .womb
        case .tired:
            // Gentler approach
            return age < 12 ? .shushing : .lullaby
        default:
            // Standard approach
            if age < 6 {
                return .shushing
            } else if age < 12 {
                return .musicBox
            } else if age < 24 {
                return .chimes
            } else {
                return .aquarium
            }
        }
    }

    private func getTransitionGenerator(age: Int, cryType: CryType) -> GeneratorType {
        switch cryType {
        case .tired:
            return age < 12 ? .womb : .lullaby
        case .pain:
            return age < 12 ? .womb : .heartbeat
        default:
            if age < 6 {
                return .womb
            } else if age < 12 {
                return .heartbeat
            } else if age < 24 {
                return .lullaby
            } else {
                return .aquarium
            }
        }
    }

    private func getSustainedGenerator(age: Int, cryType: CryType) -> GeneratorType {
        switch cryType {
        case .tired:
            return age < 12 ? .heartbeat : .aquarium
        default:
            if age < 6 {
                return .heartbeat
            } else if age < 12 {
                return .aquarium
            } else if age < 24 {
                return .aquarium
            } else {
                return .softPiano
            }
        }
    }

    // MARK: - Feedback & Learning

    /// Report that baby has calmed down (for learning)
    func reportSuccess(for baby: Baby) {
        deactivate()

        // Record successful soothing session
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        recordSession(
            babyId: baby.id,
            duration: duration,
            cryType: detectedCryType,
            wasSuccessful: true
        )
    }

    /// Enhanced success report with time-to-calm metric (for "Baby is Calm" button)
    /// - Parameters:
    ///   - baby: The baby that was calmed
    ///   - timeToCalm: Measured time from emergency start to calm confirmation
    func reportSuccessWithFeedback(for baby: Baby, timeToCalm: TimeInterval) {
        // Don't deactivate here - caller handles that with fade-out

        // Record session with precise timing
        recordSession(
            babyId: baby.id,
            duration: timeToCalm,
            cryType: detectedCryType,
            wasSuccessful: true
        )

        // Deactivate after recording
        deactivate()

        print("EmergencyCryStop: Success recorded - \(detectedCryType.rawValue) calmed in \(Int(timeToCalm))s")
    }

    /// Report that the current approach isn't working
    func reportNotWorking(for baby: Baby) {
        if smartResponseEngine.isActive {
            // Let smart engine handle adaptation
            return
        }

        currentPhase = .adapting
        tryAdaptiveResponse(for: baby)
    }

    private func recordSession(babyId: UUID, duration: TimeInterval, cryType: CryType, wasSuccessful: Bool) {
        // Store for future learning
        var sessions = loadSessionHistory()
        let session = EmergencySession(
            babyId: babyId,
            timestamp: Date(),
            duration: duration,
            cryType: cryType,
            wasSuccessful: wasSuccessful
        )
        sessions.append(session)

        // Keep last 100 sessions
        if sessions.count > 100 {
            sessions.removeFirst(sessions.count - 100)
        }

        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "EmergencySessions")
        }
    }

    private func loadSessionHistory() -> [EmergencySession] {
        guard let data = UserDefaults.standard.data(forKey: "EmergencySessions"),
              let sessions = try? JSONDecoder().decode([EmergencySession].self, from: data) else {
            return []
        }
        return sessions
    }

    // MARK: - Configuration
    /// Toggle between smart AI response and basic response
    func setSmartResponseEnabled(_ enabled: Bool) {
        useSmartResponse = enabled
    }
}

// MARK: - Emergency Session Record
struct EmergencySession: Codable {
    let babyId: UUID
    let timestamp: Date
    let duration: TimeInterval
    let cryType: CryType
    let wasSuccessful: Bool
}

// Import Combine for observers
import Combine
