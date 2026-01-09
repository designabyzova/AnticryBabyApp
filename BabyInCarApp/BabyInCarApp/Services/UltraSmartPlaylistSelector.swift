//
//  UltraSmartPlaylistSelector.swift
//  BabyInCarApp
//
//  Ultra-intelligent playlist selection using ML-style multi-factor scoring
//  CRITICAL: Rain sounds are BANNED - too loud and scary for babies!
//

import Foundation

/// Ultra-smart playlist selector using ML-style multi-factor scoring
/// Considers: cry type, baby age, time of day, historical effectiveness,
/// cry intensity, session context, and learned preferences
@MainActor
class UltraSmartPlaylistSelector: ObservableObject {
    static let shared = UltraSmartPlaylistSelector()

    // MARK: - BANNED SOUNDS
    /// All harsh, mechanical, and synthetic noise sounds have been REMOVED from the app entirely.
    /// The GeneratorType enum no longer contains: whiteNoise, pinkNoise, brownNoise, blueNoise,
    /// violetNoise, greyNoise, velvetNoise, vacuum, hairDryer, fan, carEngine, washingMachine,
    /// trainRide, airplaneCabin, cityAmbience.
    /// This set is now empty since all remaining sounds are gentle and appropriate.
    static let forbiddenSounds: Set<GeneratorType> = []

    /// Sounds to avoid for newborns (0-3 months) - too stimulating
    static let avoidForNewborns: Set<GeneratorType> = [
        .chimes,
        .chimes,
        .bells,
        .aquarium,
        .softPiano,
    ]

    // MARK: - APPROVED Sounds (Science-backed for infant soothing)
    /// Research-validated sounds for emergency cry response
    /// Based on: Womb sounds (Mirmiran 2003), Nature sounds (Alvarsson 2010),
    /// Lullabies (Shenfield 2003), Classical (Rauscher 1993)
    /// All sounds in the app are now gentle and approved - harsh sounds removed from codebase.
    static let approvedEmergencySounds: Set<GeneratorType> = [
        // Womb/Comfort sounds (0-12mo especially) - Research: Rosner & Doherty 1979
        .heartbeat,         // Most effective 0-3mo, mimics intrauterine
        .womb,              // 90% of newborns calm within 3 min
        .shushing,          // Dr. Harvey Karp's 5 S's research

        // Gentle nature sounds (all ages) - Research: Alvarsson 2010
        .aquarium,             // Rhythmic, matches relaxed breathing
        .aquarium,         // Reduces sleep onset by 25%
        .aquarium,             // Continuous, non-startling
        .bells,            // Complex nature soundscape
        .chimes,             // Signals safe environment
        .chimes,          // Relaxing night sounds

        // Musical sounds (all ages) - Research: Standley 2002
        .lullaby,           // Cross-cultural calming effect
        .musicBox,          // Classic 3-12mo favorite
        .softPiano,         // Reduces cortisol
        .gentleGuitar,      // Warm harmonics 200-2000Hz
        .chimes,            // Gentle, non-fatiguing
        .bells,             // Resonant, calming decay

        // Other gentle sounds
        .softPiano,         // Cozy, warm crackling
        .softPiano,          // Night ambience
        .aquarium,          // Gentle bubbles
    ]

    // MARK: - Scoring Weights (ML-style hyperparameters)
    private struct ScoringWeights {
        static let baseScore: Double = 0.5
        static let cryTypeMatch: Double = 0.25
        static let ageOptimality: Double = 0.15
        static let historicalEffectiveness: Double = 0.30
        static let timeOfDayMatch: Double = 0.10
        static let cryIntensityMatch: Double = 0.15
        static let recencyPenalty: Double = 0.10
        static let calmingScore: Double = 0.15
    }

    // MARK: - State
    @Published var lastSelectedSounds: [GeneratorType] = []
    @Published var selectionConfidence: Double = 0.0
    @Published var selectionReasoning: String = ""

    private var effectivenessHistory: [EffectivenessRecord] = []
    private var sessionHistory: [SessionRecord] = []

    private init() {
        loadHistory()
    }

    // MARK: - Main Selection Algorithm

    /// Select optimal sounds using ultra-smart multi-factor scoring
    /// - Parameters:
    ///   - cryType: Detected cry type
    ///   - babyAge: Baby's age in months
    ///   - cryIntensity: Current cry intensity (0-1)
    ///   - maxSounds: Maximum number of sounds to return
    /// - Returns: Ordered array of recommended sounds (best first)
    func selectOptimalSounds(
        cryType: CryType,
        babyAge: Int,
        cryIntensity: Double = 0.5,
        maxSounds: Int = 8
    ) -> [GeneratorType] {
        print("[UltraSmartSelector] 🧠 Analyzing: cry=\(cryType.rawValue), age=\(babyAge)mo, intensity=\(Int(cryIntensity * 100))%")

        // Get all valid sounds (excluding forbidden ones)
        let validSounds = getValidSounds(for: babyAge)

        // Score each sound
        var scoredSounds: [(sound: GeneratorType, score: Double, reasoning: String)] = []

        for sound in validSounds {
            let (score, reasoning) = calculateScore(
                sound: sound,
                cryType: cryType,
                babyAge: babyAge,
                cryIntensity: cryIntensity
            )
            scoredSounds.append((sound, score, reasoning))
        }

        // Sort by score (highest first)
        scoredSounds.sort { $0.score > $1.score }

        // Take top sounds
        let topSounds = Array(scoredSounds.prefix(maxSounds))

        // Update state
        lastSelectedSounds = topSounds.map { $0.sound }
        selectionConfidence = topSounds.first?.score ?? 0.0
        selectionReasoning = topSounds.first?.reasoning ?? "No sounds available"

        print("[UltraSmartSelector] ✅ Selected \(topSounds.count) sounds:")
        for (i, item) in topSounds.prefix(5).enumerated() {
            print("  \(i + 1). \(item.sound.rawValue) (score: \(String(format: "%.2f", item.score)))")
        }

        return lastSelectedSounds
    }

    // MARK: - Scoring Algorithm

    private func calculateScore(
        sound: GeneratorType,
        cryType: CryType,
        babyAge: Int,
        cryIntensity: Double
    ) -> (score: Double, reasoning: String) {
        var score = ScoringWeights.baseScore
        var reasons: [String] = []

        // 1. Cry Type Match (0.25 weight)
        let cryMatch = calculateCryTypeMatch(sound: sound, cryType: cryType)
        score += cryMatch * ScoringWeights.cryTypeMatch
        if cryMatch > 0.7 {
            reasons.append("excellent for \(cryType.rawValue) crying")
        }

        // 2. Age Optimality (0.15 weight)
        let ageMatch = calculateAgeMatch(sound: sound, age: babyAge)
        score += ageMatch * ScoringWeights.ageOptimality
        if ageMatch > 0.8 {
            reasons.append("optimal for \(babyAge)mo")
        }

        // 3. Historical Effectiveness (0.30 weight - highest!)
        let historyScore = calculateHistoricalScore(sound: sound, cryType: cryType)
        score += historyScore * ScoringWeights.historicalEffectiveness
        if historyScore > 0.7 {
            reasons.append("proven effective")
        }

        // 4. Time of Day Match (0.10 weight)
        let timeMatch = calculateTimeOfDayMatch(sound: sound)
        score += timeMatch * ScoringWeights.timeOfDayMatch

        // 5. Cry Intensity Match (0.15 weight)
        let intensityMatch = calculateIntensityMatch(sound: sound, intensity: cryIntensity)
        score += intensityMatch * ScoringWeights.cryIntensityMatch

        // 6. Recency Penalty (reduce score if played recently)
        let recencyPenalty = calculateRecencyPenalty(sound: sound)
        score -= recencyPenalty * ScoringWeights.recencyPenalty
        if recencyPenalty > 0.5 {
            reasons.append("played recently")
        }

        // 7. Base Calming Score (0.15 weight)
        score += sound.calmingScore * ScoringWeights.calmingScore

        // Clamp score to 0-1
        score = max(0, min(1, score))

        let reasoning = reasons.isEmpty ? "general recommendation" : reasons.joined(separator: ", ")

        return (score, reasoning)
    }

    // MARK: - Individual Factor Calculations

    /// Calculate cry type match score (0-1)
    private func calculateCryTypeMatch(sound: GeneratorType, cryType: CryType) -> Double {
        let bestForTypes = sound.bestForCryTypes

        if bestForTypes.contains(cryType) {
            // Check position in the list (first = best match)
            if let index = bestForTypes.firstIndex(of: cryType) {
                return 1.0 - (Double(index) * 0.15) // First = 1.0, second = 0.85, etc.
            }
            return 0.85
        }

        // Fallback: use research-based mappings
        switch cryType {
        case .tired:
            // For tired: prioritize sleep-inducing sounds
            switch sound {
            case .lullaby, .musicBox, .softPiano, .heartbeat, .womb:
                return 0.95
            case .aquarium, .aquarium, .aquarium:
                return 0.85
            case .gentleGuitar, .chimes:
                return 0.75
            default:
                return 0.4
            }

        case .hunger:
            // For hunger: engaging/distracting melodic sounds
            switch sound {
            case .musicBox, .chimes, .lullaby, .bells:
                return 0.90
            case .softPiano, .gentleGuitar:
                return 0.80
            case .heartbeat:
                return 0.70
            default:
                return 0.4
            }

        case .pain:
            // For pain: immediate comfort, familiar sounds
            switch sound {
            case .heartbeat, .womb, .musicBox:
                return 0.95
            case .lullaby, .aquarium:
                return 0.85
            case .aquarium, .softPiano:
                return 0.75
            default:
                return 0.3
            }

        case .discomfort:
            // For discomfort: soothing, consistent sounds
            switch sound {
            case .aquarium, .aquarium, .musicBox:
                return 0.90
            case .lullaby, .heartbeat, .womb:
                return 0.85
            case .aquarium, .softPiano:
                return 0.75
            default:
                return 0.4
            }

        case .attention:
            // For attention: engaging but calming
            switch sound {
            case .musicBox, .chimes, .lullaby:
                return 0.90
            case .softPiano, .gentleGuitar, .bells:
                return 0.85
            case .aquarium:
                return 0.70
            default:
                return 0.4
            }

        case .general, .unknown:
            // General: use calming score as proxy
            return sound.calmingScore
        }
    }

    /// Calculate age optimality score (0-1)
    private func calculateAgeMatch(sound: GeneratorType, age: Int) -> Double {
        let optimalRange = sound.optimalAgeRange

        // Perfect match if within optimal range
        if optimalRange.contains(age) {
            // Calculate how centered within the range
            let rangeMiddle = Double(optimalRange.lowerBound + optimalRange.upperBound) / 2
            let distanceFromMiddle = abs(Double(age) - rangeMiddle)
            let rangeHalf = Double(optimalRange.upperBound - optimalRange.lowerBound) / 2

            // Score: 1.0 at center, 0.8 at edges
            return 1.0 - (distanceFromMiddle / rangeHalf * 0.2)
        }

        // Outside range: calculate proximity penalty
        if age < optimalRange.lowerBound {
            let distance = optimalRange.lowerBound - age
            return max(0.2, 0.8 - Double(distance) * 0.1)
        } else {
            let distance = age - optimalRange.upperBound
            return max(0.2, 0.8 - Double(distance) * 0.05) // Less penalty for older
        }
    }

    /// Calculate historical effectiveness score (0-1)
    private func calculateHistoricalScore(sound: GeneratorType, cryType: CryType) -> Double {
        let relevantRecords = effectivenessHistory.filter {
            $0.sound == sound && $0.cryType == cryType
        }

        guard !relevantRecords.isEmpty else {
            return 0.5 // Neutral score if no history
        }

        // Calculate weighted average (recent records weighted more)
        var totalWeight = 0.0
        var weightedSum = 0.0

        let now = Date()
        for record in relevantRecords {
            let ageInDays = now.timeIntervalSince(record.timestamp) / 86400
            let weight = max(0.1, 1.0 - (ageInDays / 30)) // Decay over 30 days

            totalWeight += weight
            weightedSum += (record.wasEffective ? 1.0 : 0.0) * weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0.5
    }

    /// Calculate time of day match (0-1)
    private func calculateTimeOfDayMatch(sound: GeneratorType) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night time (8 PM - 6 AM): prefer sleep-inducing
        let isNightTime = hour >= 20 || hour < 6

        // Morning (6 AM - 10 AM): prefer gentle wake-up sounds
        let isMorning = hour >= 6 && hour < 10

        // Afternoon nap time (12 PM - 3 PM): prefer nap sounds
        let isNapTime = hour >= 12 && hour < 15

        if isNightTime {
            switch sound {
            case .lullaby, .musicBox, .womb, .heartbeat, .aquarium:
                return 1.0
            case .softPiano, .aquarium, .gentleGuitar:
                return 0.9
            case .aquarium:
                return 0.85
            case .chimes, .bells:
                return 0.6 // Might be too stimulating
            default:
                return 0.5
            }
        } else if isNapTime {
            switch sound {
            case .aquarium, .lullaby, .musicBox:
                return 0.95
            case .softPiano, .aquarium:
                return 0.85
            case .aquarium:
                return 0.80
            default:
                return 0.6
            }
        } else if isMorning {
            switch sound {
            case .musicBox, .softPiano, .gentleGuitar:
                return 0.90
            case .chimes, .bells:
                return 0.85
            case .lullaby:
                return 0.75
            default:
                return 0.6
            }
        }

        // Daytime: more flexible
        return 0.7
    }

    /// Calculate cry intensity match (0-1)
    /// High intensity → need stronger calming sounds
    private func calculateIntensityMatch(sound: GeneratorType, intensity: Double) -> Double {
        // High intensity (>0.7): need immediate comfort
        if intensity > 0.7 {
            switch sound {
            case .heartbeat, .womb, .musicBox:
                return 1.0 // Immediate comfort
            case .aquarium, .lullaby:
                return 0.9
            case .aquarium, .softPiano:
                return 0.8
            default:
                return 0.5
            }
        }

        // Medium intensity (0.4-0.7): balanced approach
        if intensity > 0.4 {
            switch sound {
            case .musicBox, .lullaby, .aquarium:
                return 0.95
            case .softPiano, .aquarium, .heartbeat:
                return 0.85
            case .aquarium, .gentleGuitar:
                return 0.75
            default:
                return 0.6
            }
        }

        // Low intensity (<0.4): gentle maintenance
        switch sound {
        case .musicBox, .softPiano, .gentleGuitar:
            return 0.95
        case .lullaby, .chimes:
            return 0.90
        case .aquarium:
            return 0.85
        default:
            return 0.7
        }
    }

    /// Calculate recency penalty (0-1, higher = more recent = more penalty)
    private func calculateRecencyPenalty(sound: GeneratorType) -> Double {
        let recentSessions = sessionHistory.suffix(10) // Last 10 sessions

        for (index, session) in recentSessions.enumerated().reversed() {
            if session.soundsPlayed.contains(sound) {
                // More recent = higher penalty
                let recencyIndex = recentSessions.count - 1 - index
                return max(0, 1.0 - (Double(recencyIndex) * 0.15))
            }
        }

        return 0 // Not played recently
    }

    // MARK: - Valid Sound Filtering

    /// Get all valid sounds for a given baby age (ONLY approved science-based sounds)
    private func getValidSounds(for babyAge: Int) -> [GeneratorType] {
        // ONLY use approved emergency sounds - NO banned/weird sounds!
        var validSounds = Array(Self.approvedEmergencySounds)

        // Additional filtering for newborns (0-3 months)
        if babyAge < 3 {
            validSounds = validSounds.filter { !Self.avoidForNewborns.contains($0) }
        }

        // Double-check: ensure no forbidden sounds slipped through
        validSounds = validSounds.filter { !Self.forbiddenSounds.contains($0) }

        return validSounds
    }

    /// Get valid sounds for general use (not emergency)
    func getValidSoundsForGeneralUse(for babyAge: Int) -> [GeneratorType] {
        var validSounds = GeneratorType.allCases.filter { sound in
            // Exclude forbidden sounds but allow more variety
            !Self.forbiddenSounds.contains(sound)
        }

        // Additional filtering for newborns
        if babyAge < 3 {
            validSounds = validSounds.filter { !Self.avoidForNewborns.contains($0) }
        }

        return validSounds
    }

    // MARK: - Learning & History

    /// Record effectiveness of a sound
    func recordEffectiveness(
        sound: GeneratorType,
        cryType: CryType,
        wasEffective: Bool,
        calmingTimeSeconds: Int
    ) {
        let record = EffectivenessRecord(
            sound: sound,
            cryType: cryType,
            wasEffective: wasEffective,
            calmingTimeSeconds: calmingTimeSeconds,
            timestamp: Date()
        )

        effectivenessHistory.append(record)

        // Keep last 500 records
        if effectivenessHistory.count > 500 {
            effectivenessHistory.removeFirst(100)
        }

        saveHistory()

        print("[UltraSmartSelector] 📊 Recorded: \(sound.rawValue) was \(wasEffective ? "effective" : "not effective") for \(cryType.rawValue)")
    }

    /// Record a session for recency tracking
    func recordSession(soundsPlayed: [GeneratorType]) {
        let session = SessionRecord(
            soundsPlayed: soundsPlayed,
            timestamp: Date()
        )

        sessionHistory.append(session)

        // Keep last 50 sessions
        if sessionHistory.count > 50 {
            sessionHistory.removeFirst(10)
        }

        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        if let effectivenessData = try? JSONEncoder().encode(effectivenessHistory) {
            UserDefaults.standard.set(effectivenessData, forKey: "UltraSmartSelector_Effectiveness")
        }

        if let sessionData = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(sessionData, forKey: "UltraSmartSelector_Sessions")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "UltraSmartSelector_Effectiveness"),
           let history = try? JSONDecoder().decode([EffectivenessRecord].self, from: data) {
            effectivenessHistory = history
        }

        if let data = UserDefaults.standard.data(forKey: "UltraSmartSelector_Sessions"),
           let sessions = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessionHistory = sessions
        }
    }

    // MARK: - Debug / Insights

    /// Get insights about sound selection for UI display
    func getSelectionInsights() -> SelectionInsights {
        let topSounds = lastSelectedSounds.prefix(3).map { $0.rawValue }
        let confidence = String(format: "%.0f%%", selectionConfidence * 100)

        return SelectionInsights(
            topSounds: Array(topSounds),
            confidence: confidence,
            reasoning: selectionReasoning,
            totalHistoryRecords: effectivenessHistory.count
        )
    }

    /// Check if a sound is forbidden
    func isSoundForbidden(_ sound: GeneratorType) -> Bool {
        return Self.forbiddenSounds.contains(sound)
    }

    /// Get list of forbidden sounds with reasons
    func getForbiddenSoundsInfo() -> [(sound: GeneratorType, reason: String)] {
        return [
            (.aquarium, "Too loud and scary for babies"),
            (.aquarium, "Sudden sounds startle babies"),
            (.aquarium, "Low rumble can be frightening"),
            (.shushing, "Often too harsh and loud"),
            (.womb, "Often too harsh and loud"),
        ]
    }
}

// MARK: - Supporting Types

struct EffectivenessRecord: Codable {
    let sound: GeneratorType
    let cryType: CryType
    let wasEffective: Bool
    let calmingTimeSeconds: Int
    let timestamp: Date
}

struct SessionRecord: Codable {
    let soundsPlayed: [GeneratorType]
    let timestamp: Date
}

struct SelectionInsights {
    let topSounds: [String]
    let confidence: String
    let reasoning: String
    let totalHistoryRecords: Int
}
