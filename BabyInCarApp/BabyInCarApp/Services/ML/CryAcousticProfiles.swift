//
//  CryAcousticProfiles.swift
//  BabyInCarApp
//
//  Research-based acoustic profiles for infant cry classification
//  Based on:
//  - Barr et al. (1988) - Hunger cry patterns
//  - Wasz-Höckert et al. (1985) - Cry differentiation
//  - Fuller & Horii (1986) - Pain cry acoustics
//  - Porter et al. (1988) - Cry fundamental frequency analysis
//  - LaGasse et al. (2005) - Infant cry acoustics
//

import Foundation

// MARK: - Cry Acoustic Profile

/// Research-validated acoustic profile for a specific cry type
struct CryAcousticProfile {
    /// The cry type this profile describes
    let cryType: CryType

    /// Fundamental frequency (F0) range in Hz
    let fundamentalFrequencyRange: ClosedRange<Float>

    /// Optimal F0 for this cry type
    let optimalF0: Float

    /// Expected intensity range (0-1)
    let intensityRange: ClosedRange<Double>

    /// Expected rhythmicity (0-1, higher = more rhythmic)
    let rhythmicityRange: ClosedRange<Double>

    /// Expected onset sharpness (0-1, higher = more sudden)
    let onsetSharpnessRange: ClosedRange<Double>

    /// Expected spectral centroid range in Hz
    let spectralCentroidRange: ClosedRange<Float>

    /// Expected cry bout duration in seconds
    let typicalBoutDuration: ClosedRange<Double>

    /// Expected pause duration between bouts in seconds
    let typicalPauseDuration: ClosedRange<Double>

    /// Feature weights for multi-feature scoring (must sum to 1.0)
    let featureWeights: CryFeatureWeights

    /// Verbal description for debugging/display
    let description: String

    /// Urgency level (for response prioritization)
    let urgencyLevel: UrgencyLevel

    enum UrgencyLevel: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4

        static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

/// Weights for each acoustic feature in classification
struct CryFeatureWeights {
    let fundamentalFrequency: Double
    let intensity: Double
    let rhythmicity: Double
    let onsetSharpness: Double
    let spectralCentroid: Double
    let harmonicToNoiseRatio: Double
    let duration: Double

    /// Total should equal 1.0
    var total: Double {
        fundamentalFrequency + intensity + rhythmicity + onsetSharpness +
        spectralCentroid + harmonicToNoiseRatio + duration
    }

    /// Balanced weights
    static let balanced = CryFeatureWeights(
        fundamentalFrequency: 0.20,
        intensity: 0.15,
        rhythmicity: 0.20,
        onsetSharpness: 0.15,
        spectralCentroid: 0.10,
        harmonicToNoiseRatio: 0.10,
        duration: 0.10
    )
}

// MARK: - Research-Based Profiles

/// Collection of research-validated cry profiles
enum CryAcousticProfiles {

    /// Hunger cry profile (Barr et al., 1988)
    /// Characterized by rhythmic, rising-falling pattern
    static let hunger = CryAcousticProfile(
        cryType: .hunger,
        fundamentalFrequencyRange: 350...480,
        optimalF0: 400,
        intensityRange: 0.25...0.65,  // Moderate, not extreme
        rhythmicityRange: 0.70...1.0,  // VERY rhythmic - key feature
        onsetSharpnessRange: 0.1...0.4, // Gradual buildup
        spectralCentroidRange: 500...1100,
        typicalBoutDuration: 2.0...4.0,
        typicalPauseDuration: 1.0...2.5,
        featureWeights: CryFeatureWeights(
            fundamentalFrequency: 0.20,
            intensity: 0.10,
            rhythmicity: 0.35,  // Rhythmicity is KEY for hunger
            onsetSharpness: 0.10,
            spectralCentroid: 0.10,
            harmonicToNoiseRatio: 0.10,
            duration: 0.05
        ),
        description: "Rhythmic, moderate intensity, gradual onset. Neh-neh pattern.",
        urgencyLevel: .medium
    )

    /// Tired/Sleepy cry profile (Wasz-Höckert et al., 1985)
    /// Lower intensity, irregular, trailing off
    static let tired = CryAcousticProfile(
        cryType: .tired,
        fundamentalFrequencyRange: 280...400,  // Lowest range
        optimalF0: 340,
        intensityRange: 0.05...0.35,  // LOW intensity - key feature
        rhythmicityRange: 0.0...0.45,  // Irregular - key feature
        onsetSharpnessRange: 0.0...0.3, // Soft onset
        spectralCentroidRange: 400...900,  // Lower brightness
        typicalBoutDuration: 1.0...3.0,
        typicalPauseDuration: 2.0...5.0,  // Longer pauses, fading
        featureWeights: CryFeatureWeights(
            fundamentalFrequency: 0.15,
            intensity: 0.35,  // LOW intensity is KEY for tired
            rhythmicity: 0.20,  // Irregular is important
            onsetSharpness: 0.10,
            spectralCentroid: 0.05,
            harmonicToNoiseRatio: 0.05,
            duration: 0.10
        ),
        description: "Low intensity, irregular pattern, breathy, trailing off.",
        urgencyLevel: .low
    )

    /// Pain cry profile (Fuller & Horii, 1986; Porter et al., 1988)
    /// Sudden, high-pitched, sustained, intense
    static let pain = CryAcousticProfile(
        cryType: .pain,
        fundamentalFrequencyRange: 500...800,  // Highest range
        optimalF0: 600,
        intensityRange: 0.70...1.0,  // Very HIGH - key feature
        rhythmicityRange: 0.0...0.30,  // NOT rhythmic - sustained
        onsetSharpnessRange: 0.70...1.0,  // SUDDEN onset - key feature
        spectralCentroidRange: 1200...2500,  // Bright/piercing
        typicalBoutDuration: 4.0...10.0,  // Long sustained cries
        typicalPauseDuration: 0.0...1.0,  // Minimal pauses
        featureWeights: CryFeatureWeights(
            fundamentalFrequency: 0.25,
            intensity: 0.25,  // High intensity critical
            rhythmicity: 0.10,
            onsetSharpness: 0.25,  // Sudden onset critical
            spectralCentroid: 0.10,
            harmonicToNoiseRatio: 0.0,
            duration: 0.05
        ),
        description: "Sudden onset, high-pitched, sustained, piercing. Emergency signal.",
        urgencyLevel: .critical
    )

    /// Discomfort cry (wet diaper, temperature, position)
    /// Mid-range characteristics, fussy pattern
    static let discomfort = CryAcousticProfile(
        cryType: .discomfort,
        fundamentalFrequencyRange: 380...520,
        optimalF0: 450,
        intensityRange: 0.30...0.70,  // Moderate
        rhythmicityRange: 0.30...0.60,  // Some pattern but variable
        onsetSharpnessRange: 0.20...0.50,  // Gradual to moderate
        spectralCentroidRange: 700...1400,
        typicalBoutDuration: 1.5...4.0,
        typicalPauseDuration: 1.0...3.0,
        featureWeights: CryFeatureWeights(
            fundamentalFrequency: 0.15,
            intensity: 0.20,
            rhythmicity: 0.20,
            onsetSharpness: 0.15,
            spectralCentroid: 0.15,
            harmonicToNoiseRatio: 0.10,
            duration: 0.05
        ),
        description: "Moderate characteristics, fussy, starts and stops. General discomfort.",
        urgencyLevel: .medium
    )

    /// Attention-seeking cry
    /// Escalating pattern, pauses to listen for response
    static let attention = CryAcousticProfile(
        cryType: .attention,
        fundamentalFrequencyRange: 400...550,
        optimalF0: 480,
        intensityRange: 0.20...0.60,  // Starts low, escalates
        rhythmicityRange: 0.40...0.70,  // Somewhat rhythmic but with variation
        onsetSharpnessRange: 0.10...0.40,
        spectralCentroidRange: 600...1200,
        typicalBoutDuration: 1.0...3.0,
        typicalPauseDuration: 2.0...5.0,  // Long pauses waiting for response
        featureWeights: CryFeatureWeights(
            fundamentalFrequency: 0.15,
            intensity: 0.15,
            rhythmicity: 0.20,
            onsetSharpness: 0.10,
            spectralCentroid: 0.10,
            harmonicToNoiseRatio: 0.10,
            duration: 0.20  // Pause pattern important
        ),
        description: "Escalating pattern, pauses to listen. Wants interaction.",
        urgencyLevel: .low
    )

    /// General/Unknown cry (catch-all)
    static let general = CryAcousticProfile(
        cryType: .general,
        fundamentalFrequencyRange: 300...700,
        optimalF0: 450,
        intensityRange: 0.2...0.8,
        rhythmicityRange: 0.2...0.8,
        onsetSharpnessRange: 0.2...0.6,
        spectralCentroidRange: 500...1500,
        typicalBoutDuration: 1.0...5.0,
        typicalPauseDuration: 0.5...3.0,
        featureWeights: .balanced,
        description: "General crying pattern, cause unclear.",
        urgencyLevel: .medium
    )

    /// All profiles for iteration
    static let allProfiles: [CryAcousticProfile] = [
        hunger, tired, pain, discomfort, attention, general
    ]

    /// Get profile for a cry type
    static func profile(for type: CryType) -> CryAcousticProfile {
        switch type {
        case .hunger: return hunger
        case .tired: return tired
        case .pain: return pain
        case .discomfort: return discomfort
        case .attention: return attention
        case .general, .unknown: return general
        }
    }
}

// MARK: - Multi-Feature Cry Scorer

/// Scores audio features against research-based profiles
class CryMultiFeatureScorer {

    /// Score features against all cry type profiles
    /// Returns scores for each type (0-1) and confidence levels
    func scoreAllTypes(features: ExtendedAudioFeatures, temporalPattern: TemporalCryPattern?) -> CryScoreResult {
        var scores: [CryType: Double] = [:]
        var confidences: [CryType: Double] = [:]

        // Score against each profile
        for profile in CryAcousticProfiles.allProfiles {
            let (score, confidence) = scoreAgainstProfile(features: features, pattern: temporalPattern, profile: profile)
            scores[profile.cryType] = score
            confidences[profile.cryType] = confidence
        }

        // Normalize scores
        let total = scores.values.reduce(0, +)
        if total > 0 {
            for key in scores.keys {
                scores[key]! /= total
            }
        }

        // Find best match
        let bestMatch = scores.max(by: { $0.value < $1.value })
        let bestType = bestMatch?.key ?? .unknown
        let bestScore = bestMatch?.value ?? 0
        let bestConfidence = confidences[bestType] ?? 0

        // Determine if classification is reliable
        let isReliable = bestConfidence > 0.6 && bestScore > 0.3

        // Check for ambiguity (close second)
        let sortedScores = scores.sorted { $0.value > $1.value }
        let isAmbiguous = sortedScores.count >= 2 &&
                         (sortedScores[0].value - sortedScores[1].value) < 0.15

        return CryScoreResult(
            scores: scores,
            confidences: confidences,
            bestType: bestType,
            bestScore: bestScore,
            confidence: bestConfidence,
            isReliable: isReliable,
            isAmbiguous: isAmbiguous,
            secondBestType: sortedScores.count >= 2 ? sortedScores[1].key : nil
        )
    }

    /// Score features against a specific profile
    private func scoreAgainstProfile(features: ExtendedAudioFeatures, pattern: TemporalCryPattern?, profile: CryAcousticProfile) -> (score: Double, confidence: Double) {
        let weights = profile.featureWeights
        var score: Double = 0
        var matchCount = 0
        var totalWeight: Double = 0

        // 1. Fundamental Frequency
        let f0Score = scoreF0(Float(features.fundamentalFrequency), profile: profile)
        score += f0Score * weights.fundamentalFrequency
        if f0Score > 0.5 { matchCount += 1 }
        totalWeight += weights.fundamentalFrequency

        // 2. Intensity
        let intensityScore = scoreIntensity(features.intensity, profile: profile)
        score += intensityScore * weights.intensity
        if intensityScore > 0.5 { matchCount += 1 }
        totalWeight += weights.intensity

        // 3. Rhythmicity (from pattern if available, otherwise estimate)
        let rhythmicityValue = pattern?.rhythmicityScore ?? estimateRhythmicity(from: features)
        let rhythmicityScore = scoreRhythmicity(rhythmicityValue, profile: profile)
        score += rhythmicityScore * weights.rhythmicity
        if rhythmicityScore > 0.5 { matchCount += 1 }
        totalWeight += weights.rhythmicity

        // 4. Onset Sharpness
        let onsetScore = scoreOnsetSharpness(features.onsetSharpness, profile: profile)
        score += onsetScore * weights.onsetSharpness
        if onsetScore > 0.5 { matchCount += 1 }
        totalWeight += weights.onsetSharpness

        // 5. Spectral Centroid
        let centroidScore = scoreSpectralCentroid(Float(features.spectralCentroid), profile: profile)
        score += centroidScore * weights.spectralCentroid
        if centroidScore > 0.5 { matchCount += 1 }
        totalWeight += weights.spectralCentroid

        // 6. Harmonic-to-Noise Ratio
        let hnrScore = scoreHNR(features.harmonicToNoiseRatio, profile: profile)
        score += hnrScore * weights.harmonicToNoiseRatio
        totalWeight += weights.harmonicToNoiseRatio

        // 7. Duration (from pattern)
        if let pattern = pattern, weights.duration > 0 {
            let durationScore = scoreDuration(pattern.averageBoutDuration, pauseDuration: pattern.averagePauseDuration, profile: profile)
            score += durationScore * weights.duration
            if durationScore > 0.5 { matchCount += 1 }
            totalWeight += weights.duration
        }

        // Normalize score
        let normalizedScore = totalWeight > 0 ? score / totalWeight : 0

        // Calculate confidence based on how many features matched well
        let featureCount = 7
        let confidence = Double(matchCount) / Double(featureCount)

        return (normalizedScore, confidence)
    }

    // MARK: - Individual Feature Scoring

    private func scoreF0(_ f0: Float, profile: CryAcousticProfile) -> Double {
        guard f0 > 0 else { return 0 }

        let range = profile.fundamentalFrequencyRange
        let optimal = profile.optimalF0

        // Perfect score if at optimal
        if abs(f0 - optimal) < 30 { return 1.0 }

        // High score if within range
        if range.contains(f0) {
            let distanceFromOptimal = abs(f0 - optimal)
            let rangeSize = range.upperBound - range.lowerBound
            return max(0.5, 1.0 - Double(distanceFromOptimal / rangeSize))
        }

        // Partial score if close to range
        let distanceFromRange: Float
        if f0 < range.lowerBound {
            distanceFromRange = range.lowerBound - f0
        } else {
            distanceFromRange = f0 - range.upperBound
        }

        // Decay score based on distance (100 Hz = 0.3 penalty)
        return max(0, 0.4 - Double(distanceFromRange / 100) * 0.4)
    }

    private func scoreIntensity(_ intensity: Double, profile: CryAcousticProfile) -> Double {
        let range = profile.intensityRange

        if range.contains(intensity) {
            // Within range - perfect
            return 1.0
        }

        // Calculate distance from range
        let distance: Double
        if intensity < range.lowerBound {
            distance = range.lowerBound - intensity
        } else {
            distance = intensity - range.upperBound
        }

        // For tired cry, being ABOVE intensity range is a strong disqualifier
        if profile.cryType == .tired && intensity > range.upperBound {
            return max(0, 0.3 - distance * 2)
        }

        // For pain cry, being BELOW intensity range is a strong disqualifier
        if profile.cryType == .pain && intensity < range.lowerBound {
            return max(0, 0.3 - distance * 2)
        }

        return max(0, 0.5 - distance)
    }

    private func scoreRhythmicity(_ rhythmicity: Double, profile: CryAcousticProfile) -> Double {
        let range = profile.rhythmicityRange

        if range.contains(rhythmicity) {
            return 1.0
        }

        let distance: Double
        if rhythmicity < range.lowerBound {
            distance = range.lowerBound - rhythmicity
        } else {
            distance = rhythmicity - range.upperBound
        }

        // Hunger cry requires high rhythmicity
        if profile.cryType == .hunger && rhythmicity < 0.5 {
            return max(0, 0.2 - distance)
        }

        // Pain cry should NOT be rhythmic
        if profile.cryType == .pain && rhythmicity > 0.5 {
            return max(0, 0.3 - distance)
        }

        return max(0, 0.5 - distance)
    }

    private func scoreOnsetSharpness(_ onset: Double, profile: CryAcousticProfile) -> Double {
        let range = profile.onsetSharpnessRange

        if range.contains(onset) {
            return 1.0
        }

        // Pain cry REQUIRES sudden onset
        if profile.cryType == .pain && onset < 0.6 {
            return max(0, onset * 0.5)
        }

        let distance: Double
        if onset < range.lowerBound {
            distance = range.lowerBound - onset
        } else {
            distance = onset - range.upperBound
        }

        return max(0, 0.5 - distance)
    }

    private func scoreSpectralCentroid(_ centroid: Float, profile: CryAcousticProfile) -> Double {
        let range = profile.spectralCentroidRange

        if range.contains(centroid) {
            return 1.0
        }

        let distance: Float
        if centroid < range.lowerBound {
            distance = range.lowerBound - centroid
        } else {
            distance = centroid - range.upperBound
        }

        return max(0, 0.5 - Double(distance / 500))
    }

    private func scoreHNR(_ hnr: Double, profile: CryAcousticProfile) -> Double {
        // Higher HNR = more tonal (cry-like)
        // Lower HNR = more breathy (could be tired)
        if profile.cryType == .tired {
            // Tired cries are often breathy (lower HNR)
            return hnr < 0.4 ? 1.0 : max(0, 1.0 - hnr)
        }

        // Other cries benefit from tonal quality
        return min(hnr + 0.3, 1.0)
    }

    private func scoreDuration(_ boutDuration: Double, pauseDuration: Double, profile: CryAcousticProfile) -> Double {
        let boutRange = profile.typicalBoutDuration
        let pauseRange = profile.typicalPauseDuration

        var score: Double = 0

        if boutRange.contains(boutDuration) {
            score += 0.5
        }

        if pauseRange.contains(pauseDuration) {
            score += 0.5
        }

        return score
    }

    /// Estimate rhythmicity from features when temporal pattern not available
    private func estimateRhythmicity(from features: ExtendedAudioFeatures) -> Double {
        // Use spectral flux and pitch variability as proxy
        let stabilityScore = 1.0 - Double(min(features.pitchVariability, 1.0))
        return stabilityScore * 0.7  // Conservative estimate
    }
}

/// Result of multi-feature cry scoring
struct CryScoreResult {
    let scores: [CryType: Double]
    let confidences: [CryType: Double]
    let bestType: CryType
    let bestScore: Double
    let confidence: Double
    let isReliable: Bool
    let isAmbiguous: Bool
    let secondBestType: CryType?
}

/// Temporal pattern extracted from cry analysis over time
struct TemporalCryPattern {
    let rhythmicityScore: Double
    let averageBoutDuration: Double
    let averagePauseDuration: Double
    let intensityEvolution: IntensityEvolution
    let totalDuration: Double

    enum IntensityEvolution {
        case increasing   // Getting louder (escalating)
        case decreasing   // Getting quieter (calming)
        case stable       // Consistent
        case variable     // Unpredictable
    }

    /// Create from CryPatternMetrics (bridges CryPatternTracker to multi-feature scorer)
    static func from(metrics: CryPatternMetrics) -> TemporalCryPattern {
        // Map intensity trend to evolution
        let evolution: IntensityEvolution
        switch metrics.intensityTrend {
        case .increasing:
            evolution = .increasing
        case .decreasing:
            evolution = .decreasing
        case .stable:
            evolution = .stable
        case .fluctuating:
            evolution = .variable
        }

        return TemporalCryPattern(
            rhythmicityScore: metrics.rhythmicity,
            averageBoutDuration: metrics.averageBurstDuration,
            averagePauseDuration: metrics.averagePauseDuration,
            intensityEvolution: evolution,
            totalDuration: metrics.totalCryDuration
        )
    }
}
