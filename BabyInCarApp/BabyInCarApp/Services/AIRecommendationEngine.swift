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
    func getPersonalizedPlaylist(for baby: Baby, category: AudioCategory? = nil, count: Int = 10) async -> Playlist {
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
    func getQuickPicks(for baby: Baby) async -> [Playlist] {
        let stage = baby.developmentalStage
        var playlists: [Playlist] = []

        // Get recommended categories for this developmental stage
        for category in stage.recommendedCategories.prefix(6) {
            let playlist = await getPersonalizedPlaylist(for: baby, category: category, count: 5)
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

        var preferredCategories: [AudioCategory] {
            switch self {
            case .sleepy:
                return [.whiteNoise, .classicalMusic, .instrumental]
            case .crying:
                return [.whiteNoise, .natureSounds, .instrumental]
            case .playful:
                return [.childrenSongs, .fairyTales, .instrumental]
            case .calm:
                return [.classicalMusic, .natureSounds, .podcasts]
            case .fussy:
                return [.whiteNoise, .natureSounds, .classicalMusic]
            }
        }

        var preferredGenerators: [GeneratorType] {
            switch self {
            case .sleepy:
                return [.pinkNoise, .rain, .ocean, .lullaby]
            case .crying:
                return [.shushing, .womb, .heartbeat, .vacuum]
            case .playful:
                return [.musicBox, .birds, .chimes]
            case .calm:
                return [.rain, .ocean, .river, .wind]
            case .fussy:
                return [.pinkNoise, .brownNoise, .fan, .shushing]
            }
        }
    }

    func getPlaylistForMood(_ mood: Mood, baby: Baby) async -> Playlist {
        let ageMonths = baby.ageInMonths
        var tracks: [AudioTrack] = []

        // Add generated tracks for preferred sound types
        for generator in mood.preferredGenerators.prefix(3) {
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
                .prefix(2)
            tracks.append(contentsOf: categoryTracks)
        }

        return Playlist(
            name: "\(mood.rawValue) Mode",
            description: "Perfect sounds for when baby is \(mood.rawValue.lowercased())",
            tracks: tracks,
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

        // Add calming tracks
        let calmingGenerators: [GeneratorType] = [.pinkNoise, .rain, .ocean, .shushing, .womb]
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

        return Playlist(
            name: duration.rawValue,
            description: "Optimized for \(duration.rawValue.lowercased())s with \(baby.displayName)",
            tracks: Array(tracks.prefix(duration.trackCount)),
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
@MainActor
class EmergencyCryStopService: ObservableObject {
    static let shared = EmergencyCryStopService()

    @Published var isEmergencyModeActive: Bool = false
    @Published var currentPhase: CalmingPhase = .idle
    @Published var phaseProgress: Double = 0

    private var phaseTimer: Timer?
    private let audioEngine = AudioEngine.shared

    enum CalmingPhase: String {
        case idle = "Ready"
        case attention = "Getting Attention"      // Phase 1: 0-30 seconds
        case transition = "Calming Down"          // Phase 2: 30-90 seconds
        case sustained = "Sustained Soothing"     // Phase 3: 90+ seconds
        case complete = "Baby Calm"

        var duration: TimeInterval {
            switch self {
            case .idle, .complete: return 0
            case .attention: return 30
            case .transition: return 60
            case .sustained: return 300
            }
        }
    }

    private init() {}

    /// Activate emergency cry-stop mode
    func activate(for baby: Baby) {
        isEmergencyModeActive = true
        currentPhase = .attention

        // Get best calming tracks for this baby
        let emergencyTracks = AIRecommendationEngine.shared.getEmergencyTracks(for: baby)

        // Start with attention-grabbing phase
        startPhase(.attention, baby: baby)
    }

    func deactivate() {
        isEmergencyModeActive = false
        currentPhase = .idle
        phaseProgress = 0
        phaseTimer?.invalidate()
        phaseTimer = nil
    }

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

                    if self.phaseProgress >= 1.0 {
                        timer.invalidate()
                        self.advanceToNextPhase(baby: baby)
                    }
                }
            }
        }
    }

    private func advanceToNextPhase(baby: Baby) {
        switch currentPhase {
        case .attention:
            startPhase(.transition, baby: baby)
        case .transition:
            startPhase(.sustained, baby: baby)
        case .sustained:
            currentPhase = .complete
            // Continue playing sustained audio
        default:
            break
        }
    }

    private func getTrackForPhase(_ phase: CalmingPhase, baby: Baby) -> AudioTrack {
        let ageMonths = baby.ageInMonths

        switch phase {
        case .attention:
            // Sudden attention-grabber with specific frequencies
            let generator: GeneratorType = ageMonths < 6 ? .shushing : .musicBox
            return AudioTrack(
                title: "Attention Grabber",
                category: .whiteNoise,
                duration: 30,
                calmingScore: 0.9,
                audioSourceType: .generated,
                generatorType: generator
            )

        case .transition:
            // Gradual calming transition
            let generator: GeneratorType = ageMonths < 6 ? .womb : .pinkNoise
            return AudioTrack(
                title: "Calming Transition",
                category: .whiteNoise,
                duration: 60,
                calmingScore: 0.95,
                audioSourceType: .generated,
                generatorType: generator
            )

        case .sustained:
            // Sustained soothing for sleep transition
            let generator: GeneratorType = ageMonths < 6 ? .heartbeat : .ocean
            return AudioTrack(
                title: "Sustained Soothing",
                category: .natureSounds,
                duration: 300,
                calmingScore: 0.92,
                audioSourceType: .generated,
                generatorType: generator
            )

        default:
            return AudioTrack(
                title: "Pink Noise",
                category: .whiteNoise,
                duration: 600,
                calmingScore: 0.9,
                audioSourceType: .generated,
                generatorType: .pinkNoise
            )
        }
    }

    /// Report that baby has calmed down (for learning)
    func reportSuccess(for baby: Baby) {
        deactivate()

        // Record for future recommendations
        // This helps the AI learn what works for this specific baby
    }
}
