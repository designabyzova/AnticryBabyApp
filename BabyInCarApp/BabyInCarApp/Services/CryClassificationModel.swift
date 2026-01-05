//
//  CryClassificationModel.swift
//  BabyInCarApp
//
//  Advanced ML-based cry classification using acoustic features and pattern recognition
//  Implements a hybrid approach combining rule-based and learned patterns
//

import Foundation
import Accelerate
import Combine

// MARK: - Cry Classification Model
/// Intelligent cry classification model that combines acoustic feature extraction
/// with learned patterns for accurate baby cry type identification
@MainActor
class CryClassificationModel: ObservableObject {
    static let shared = CryClassificationModel()

    // MARK: - Published State
    @Published var modelReady: Bool = false
    @Published var lastClassification: CryClassificationResult?
    @Published var learningProgress: Double = 0

    // MARK: - Model Configuration
    private let featureExtractor = AcousticFeatureExtractor()
    private var babyProfiles: [UUID: BabyCryProfile] = [:]
    private var globalPatterns: [CryType: CryAcousticPattern] = [:]

    // Learning state
    private var classificationHistory: [CryClassificationRecord] = []
    private let maxHistorySize = 1000

    // MARK: - Initialization
    private init() {
        loadGlobalPatterns()
        loadSavedProfiles()
        modelReady = true
    }

    // MARK: - Classification
    /// Classify audio features into cry type with confidence score
    func classify(features: AudioFeatures, babyId: UUID? = nil) -> CryClassificationResult {
        var scores: [CryType: Double] = [:]

        // 1. Rule-based classification from acoustic features
        let ruleScores = classifyByRules(features: features)
        for (type, score) in ruleScores {
            scores[type, default: 0] += score * 0.4
        }

        // 2. Pattern matching against global patterns
        let patternScores = matchGlobalPatterns(features: features)
        for (type, score) in patternScores {
            scores[type, default: 0] += score * 0.3
        }

        // 3. Personalized matching if baby profile exists
        if let babyId = babyId, let profile = babyProfiles[babyId] {
            let personalScores = matchPersonalizedPatterns(features: features, profile: profile)
            for (type, score) in personalScores {
                scores[type, default: 0] += score * 0.3
            }
        } else {
            // No personalized data - boost rule-based scores
            for (type, _) in ruleScores {
                scores[type, default: 0] += ruleScores[type, default: 0] * 0.15
            }
        }

        // Normalize and find best match
        let totalScore = scores.values.reduce(0, +)
        if totalScore > 0 {
            for key in scores.keys {
                scores[key]! /= totalScore
            }
        }

        let bestMatch = scores.max(by: { $0.value < $1.value })
        let classification = CryClassificationResult(
            type: bestMatch?.key ?? .unknown,
            confidence: bestMatch?.value ?? 0,
            allScores: scores,
            features: features,
            timestamp: Date()
        )

        lastClassification = classification
        return classification
    }

    // MARK: - Rule-Based Classification
    private func classifyByRules(features: AudioFeatures) -> [CryType: Double] {
        var scores: [CryType: Double] = [:]

        // Hunger cry characteristics:
        // - Rhythmic pattern (cry-pause-cry)
        // - Lower fundamental frequency (350-450 Hz)
        // - Moderate intensity, builds gradually
        let hungerScore = calculateHungerScore(features)
        scores[.hunger] = hungerScore

        // Tired cry characteristics:
        // - Lower intensity overall
        // - Irregular rhythm, may include whimpering
        // - Lower pitch with less harmonics
        let tiredScore = calculateTiredScore(features)
        scores[.tired] = tiredScore

        // Pain cry characteristics:
        // - Sudden onset, high intensity
        // - Higher fundamental frequency (500-700 Hz)
        // - Strong harmonics, sharp spectral peak
        // - Long duration bursts
        let painScore = calculatePainScore(features)
        scores[.pain] = painScore

        // Attention-seeking cry:
        // - Medium intensity, rhythmic
        // - Pauses to check for response
        // - Variable pitch
        let attentionScore = calculateAttentionScore(features)
        scores[.attention] = attentionScore

        // General discomfort:
        // - Moderate characteristics
        // - Variable patterns
        let discomfortScore = calculateDiscomfortScore(features)
        scores[.discomfort] = discomfortScore

        return scores
    }

    private func calculateHungerScore(_ features: AudioFeatures) -> Double {
        var score: Double = 0

        // Check fundamental frequency range (lower for hunger)
        if features.fundamentalFrequency >= 350 && features.fundamentalFrequency <= 480 {
            score += 0.3
        }

        // Check rhythmicity (hunger cries are rhythmic)
        if features.rhythmicity > 0.6 {
            score += 0.25
        }

        // Check intensity (moderate, not extreme)
        if features.intensity > 0.3 && features.intensity < 0.7 {
            score += 0.2
        }

        // Check harmonic-to-noise ratio (cleaner for hunger)
        if features.harmonicToNoiseRatio > 0.5 {
            score += 0.15
        }

        // Check temporal pattern (gradual buildup)
        if features.onsetSharpness < 0.5 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    private func calculateTiredScore(_ features: AudioFeatures) -> Double {
        var score: Double = 0

        // Lower intensity
        if features.intensity < 0.5 {
            score += 0.3
        }

        // Lower fundamental frequency
        if features.fundamentalFrequency < 450 {
            score += 0.2
        }

        // Less rhythmic (irregular)
        if features.rhythmicity < 0.5 {
            score += 0.2
        }

        // Lower harmonic content
        if features.harmonicToNoiseRatio < 0.5 {
            score += 0.15
        }

        // Longer inter-cry intervals
        if features.pauseDuration > 0.5 {
            score += 0.15
        }

        return min(score, 1.0)
    }

    private func calculatePainScore(_ features: AudioFeatures) -> Double {
        var score: Double = 0

        // High intensity
        if features.intensity > 0.7 {
            score += 0.3
        }

        // Higher fundamental frequency
        if features.fundamentalFrequency > 500 {
            score += 0.25
        }

        // Sharp onset
        if features.onsetSharpness > 0.7 {
            score += 0.2
        }

        // Strong harmonics
        if features.harmonicToNoiseRatio > 0.6 {
            score += 0.15
        }

        // Long cry duration
        if features.cryDuration > 2.0 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    private func calculateAttentionScore(_ features: AudioFeatures) -> Double {
        var score: Double = 0

        // Medium intensity
        if features.intensity > 0.4 && features.intensity < 0.7 {
            score += 0.25
        }

        // Rhythmic pattern
        if features.rhythmicity > 0.5 {
            score += 0.2
        }

        // Variable pitch
        if features.pitchVariability > 0.3 {
            score += 0.2
        }

        // Pauses (checking for response)
        if features.pauseDuration > 0.3 && features.pauseDuration < 1.0 {
            score += 0.2
        }

        // Medium fundamental frequency
        if features.fundamentalFrequency > 400 && features.fundamentalFrequency < 550 {
            score += 0.15
        }

        return min(score, 1.0)
    }

    private func calculateDiscomfortScore(_ features: AudioFeatures) -> Double {
        var score: Double = 0

        // Moderate intensity
        if features.intensity > 0.3 && features.intensity < 0.8 {
            score += 0.25
        }

        // Variable characteristics (not fitting other categories well)
        score += 0.2

        // Some rhythmicity but not strong
        if features.rhythmicity > 0.3 && features.rhythmicity < 0.7 {
            score += 0.2
        }

        // Mid-range frequency
        if features.fundamentalFrequency > 380 && features.fundamentalFrequency < 520 {
            score += 0.2
        }

        // Moderate HNR
        if features.harmonicToNoiseRatio > 0.3 && features.harmonicToNoiseRatio < 0.7 {
            score += 0.15
        }

        return min(score, 1.0)
    }

    // MARK: - Pattern Matching
    private func matchGlobalPatterns(features: AudioFeatures) -> [CryType: Double] {
        var scores: [CryType: Double] = [:]

        for (type, pattern) in globalPatterns {
            let similarity = pattern.calculateSimilarity(to: features)
            scores[type] = similarity
        }

        return scores
    }

    private func matchPersonalizedPatterns(features: AudioFeatures, profile: BabyCryProfile) -> [CryType: Double] {
        var scores: [CryType: Double] = [:]

        for (type, patterns) in profile.learnedPatterns {
            var maxSimilarity: Double = 0
            for pattern in patterns {
                let similarity = pattern.calculateSimilarity(to: features)
                maxSimilarity = max(maxSimilarity, similarity)
            }
            scores[type] = maxSimilarity
        }

        return scores
    }

    // MARK: - Learning System
    /// Record a classification with feedback for learning
    func recordFeedback(for classification: CryClassificationResult, actualType: CryType, babyId: UUID) {
        let record = CryClassificationRecord(
            predictedType: classification.type,
            actualType: actualType,
            confidence: classification.confidence,
            features: classification.features,
            babyId: babyId,
            timestamp: Date()
        )

        classificationHistory.append(record)
        if classificationHistory.count > maxHistorySize {
            classificationHistory.removeFirst()
        }

        // Update baby profile
        updateBabyProfile(babyId: babyId, with: record)

        // Update global patterns if high confidence feedback
        if classification.confidence > 0.7 {
            updateGlobalPatterns(with: record)
        }

        // Save profiles
        saveProfiles()
    }

    private func updateBabyProfile(babyId: UUID, with record: CryClassificationRecord) {
        if babyProfiles[babyId] == nil {
            babyProfiles[babyId] = BabyCryProfile(babyId: babyId)
        }

        var profile = babyProfiles[babyId]!
        profile.addLearningExample(type: record.actualType, features: record.features)
        babyProfiles[babyId] = profile
    }

    private func updateGlobalPatterns(with record: CryClassificationRecord) {
        if globalPatterns[record.actualType] == nil {
            globalPatterns[record.actualType] = CryAcousticPattern(type: record.actualType)
        }

        globalPatterns[record.actualType]?.updateWith(features: record.features)
    }

    // MARK: - Persistence
    private func loadGlobalPatterns() {
        // Initialize with research-based acoustic patterns
        globalPatterns = [
            .hunger: CryAcousticPattern.hungerPattern(),
            .tired: CryAcousticPattern.tiredPattern(),
            .pain: CryAcousticPattern.painPattern(),
            .attention: CryAcousticPattern.attentionPattern(),
            .discomfort: CryAcousticPattern.discomfortPattern()
        ]
    }

    private func loadSavedProfiles() {
        guard let data = UserDefaults.standard.data(forKey: "CryBabyProfiles"),
              let profiles = try? JSONDecoder().decode([UUID: BabyCryProfile].self, from: data) else {
            return
        }
        babyProfiles = profiles
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(babyProfiles) else { return }
        UserDefaults.standard.set(data, forKey: "CryBabyProfiles")
    }
}

// MARK: - Audio Features
/// Acoustic features extracted from audio for classification
struct AudioFeatures: Codable {
    let fundamentalFrequency: Double      // Hz
    let intensity: Double                  // 0-1
    let harmonicToNoiseRatio: Double      // 0-1
    let spectralCentroid: Double          // Hz
    let spectralFlatness: Double          // 0-1
    let rhythmicity: Double               // 0-1 (how rhythmic/periodic)
    let pitchVariability: Double          // 0-1
    let onsetSharpness: Double            // 0-1 (sudden vs gradual)
    let cryDuration: Double               // seconds
    let pauseDuration: Double             // seconds between cry bursts
    let formantF1: Double                 // First formant Hz
    let formantF2: Double                 // Second formant Hz
    let melFrequencyCoeffs: [Double]      // MFCCs

    init(
        fundamentalFrequency: Double = 0,
        intensity: Double = 0,
        harmonicToNoiseRatio: Double = 0,
        spectralCentroid: Double = 0,
        spectralFlatness: Double = 0,
        rhythmicity: Double = 0,
        pitchVariability: Double = 0,
        onsetSharpness: Double = 0,
        cryDuration: Double = 0,
        pauseDuration: Double = 0,
        formantF1: Double = 0,
        formantF2: Double = 0,
        melFrequencyCoeffs: [Double] = []
    ) {
        self.fundamentalFrequency = fundamentalFrequency
        self.intensity = intensity
        self.harmonicToNoiseRatio = harmonicToNoiseRatio
        self.spectralCentroid = spectralCentroid
        self.spectralFlatness = spectralFlatness
        self.rhythmicity = rhythmicity
        self.pitchVariability = pitchVariability
        self.onsetSharpness = onsetSharpness
        self.cryDuration = cryDuration
        self.pauseDuration = pauseDuration
        self.formantF1 = formantF1
        self.formantF2 = formantF2
        self.melFrequencyCoeffs = melFrequencyCoeffs
    }

    /// Calculate Euclidean distance to another feature set
    func distance(to other: AudioFeatures) -> Double {
        var sum: Double = 0

        sum += pow(fundamentalFrequency - other.fundamentalFrequency, 2) / 10000 // Normalize
        sum += pow(intensity - other.intensity, 2)
        sum += pow(harmonicToNoiseRatio - other.harmonicToNoiseRatio, 2)
        sum += pow(spectralCentroid - other.spectralCentroid, 2) / 1000000
        sum += pow(spectralFlatness - other.spectralFlatness, 2)
        sum += pow(rhythmicity - other.rhythmicity, 2)
        sum += pow(pitchVariability - other.pitchVariability, 2)
        sum += pow(onsetSharpness - other.onsetSharpness, 2)

        // MFCC distance if available
        let mfccCount = min(melFrequencyCoeffs.count, other.melFrequencyCoeffs.count)
        if mfccCount > 0 {
            for i in 0..<mfccCount {
                sum += pow(melFrequencyCoeffs[i] - other.melFrequencyCoeffs[i], 2) / 100
            }
        }

        return sqrt(sum)
    }
}

// MARK: - Classification Result
struct CryClassificationResult: Codable {
    let type: CryType
    let confidence: Double
    let allScores: [CryType: Double]
    let features: AudioFeatures
    let timestamp: Date

    var isReliable: Bool {
        confidence > 0.6
    }

    var secondBestType: CryType? {
        let sorted = allScores.sorted { $0.value > $1.value }
        return sorted.count > 1 ? sorted[1].key : nil
    }
}

// MARK: - Classification Record
struct CryClassificationRecord: Codable {
    let predictedType: CryType
    let actualType: CryType
    let confidence: Double
    let features: AudioFeatures
    let babyId: UUID
    let timestamp: Date

    var wasCorrect: Bool {
        predictedType == actualType
    }
}

// MARK: - Cry Acoustic Pattern
/// Learned acoustic pattern for a cry type
struct CryAcousticPattern: Codable {
    let type: CryType
    var centroid: AudioFeatures
    var examples: [AudioFeatures]
    var variance: AudioFeatures

    private var maxExamples: Int = 100

    init(type: CryType) {
        self.type = type
        self.centroid = AudioFeatures()
        self.examples = []
        self.variance = AudioFeatures()
    }

    /// Update pattern with new example
    mutating func updateWith(features: AudioFeatures) {
        examples.append(features)
        if examples.count > maxExamples {
            examples.removeFirst()
        }
        recalculateCentroid()
    }

    private mutating func recalculateCentroid() {
        guard !examples.isEmpty else { return }

        let n = Double(examples.count)

        // Calculate mean for each feature
        centroid = AudioFeatures(
            fundamentalFrequency: examples.map { $0.fundamentalFrequency }.reduce(0, +) / n,
            intensity: examples.map { $0.intensity }.reduce(0, +) / n,
            harmonicToNoiseRatio: examples.map { $0.harmonicToNoiseRatio }.reduce(0, +) / n,
            spectralCentroid: examples.map { $0.spectralCentroid }.reduce(0, +) / n,
            spectralFlatness: examples.map { $0.spectralFlatness }.reduce(0, +) / n,
            rhythmicity: examples.map { $0.rhythmicity }.reduce(0, +) / n,
            pitchVariability: examples.map { $0.pitchVariability }.reduce(0, +) / n,
            onsetSharpness: examples.map { $0.onsetSharpness }.reduce(0, +) / n,
            cryDuration: examples.map { $0.cryDuration }.reduce(0, +) / n,
            pauseDuration: examples.map { $0.pauseDuration }.reduce(0, +) / n
        )
    }

    /// Calculate similarity (0-1) of features to this pattern
    func calculateSimilarity(to features: AudioFeatures) -> Double {
        let distance = centroid.distance(to: features)
        // Convert distance to similarity using Gaussian kernel
        let sigma: Double = 2.0
        return exp(-pow(distance, 2) / (2 * pow(sigma, 2)))
    }

    // MARK: - Research-Based Default Patterns

    static func hungerPattern() -> CryAcousticPattern {
        var pattern = CryAcousticPattern(type: .hunger)
        pattern.centroid = AudioFeatures(
            fundamentalFrequency: 420,
            intensity: 0.5,
            harmonicToNoiseRatio: 0.6,
            spectralCentroid: 800,
            spectralFlatness: 0.3,
            rhythmicity: 0.7,
            pitchVariability: 0.25,
            onsetSharpness: 0.3,
            cryDuration: 1.5,
            pauseDuration: 0.8
        )
        return pattern
    }

    static func tiredPattern() -> CryAcousticPattern {
        var pattern = CryAcousticPattern(type: .tired)
        pattern.centroid = AudioFeatures(
            fundamentalFrequency: 380,
            intensity: 0.35,
            harmonicToNoiseRatio: 0.4,
            spectralCentroid: 700,
            spectralFlatness: 0.4,
            rhythmicity: 0.4,
            pitchVariability: 0.3,
            onsetSharpness: 0.2,
            cryDuration: 1.2,
            pauseDuration: 1.0
        )
        return pattern
    }

    static func painPattern() -> CryAcousticPattern {
        var pattern = CryAcousticPattern(type: .pain)
        pattern.centroid = AudioFeatures(
            fundamentalFrequency: 580,
            intensity: 0.85,
            harmonicToNoiseRatio: 0.7,
            spectralCentroid: 1200,
            spectralFlatness: 0.25,
            rhythmicity: 0.3,
            pitchVariability: 0.4,
            onsetSharpness: 0.85,
            cryDuration: 3.0,
            pauseDuration: 0.3
        )
        return pattern
    }

    static func attentionPattern() -> CryAcousticPattern {
        var pattern = CryAcousticPattern(type: .attention)
        pattern.centroid = AudioFeatures(
            fundamentalFrequency: 480,
            intensity: 0.55,
            harmonicToNoiseRatio: 0.55,
            spectralCentroid: 900,
            spectralFlatness: 0.35,
            rhythmicity: 0.6,
            pitchVariability: 0.45,
            onsetSharpness: 0.4,
            cryDuration: 1.8,
            pauseDuration: 0.6
        )
        return pattern
    }

    static func discomfortPattern() -> CryAcousticPattern {
        var pattern = CryAcousticPattern(type: .discomfort)
        pattern.centroid = AudioFeatures(
            fundamentalFrequency: 450,
            intensity: 0.6,
            harmonicToNoiseRatio: 0.5,
            spectralCentroid: 850,
            spectralFlatness: 0.4,
            rhythmicity: 0.5,
            pitchVariability: 0.35,
            onsetSharpness: 0.5,
            cryDuration: 2.0,
            pauseDuration: 0.5
        )
        return pattern
    }
}

// MARK: - Baby Cry Profile
/// Personalized cry patterns learned for a specific baby
struct BabyCryProfile: Codable {
    let babyId: UUID
    var learnedPatterns: [CryType: [CryAcousticPattern]]
    var preferredSoothingSounds: [CryType: [GeneratorType]]
    var averageCalibrationTime: TimeInterval
    var totalClassifications: Int
    var correctClassifications: Int

    init(babyId: UUID) {
        self.babyId = babyId
        self.learnedPatterns = [:]
        self.preferredSoothingSounds = [:]
        self.averageCalibrationTime = 0
        self.totalClassifications = 0
        self.correctClassifications = 0
    }

    var accuracy: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(correctClassifications) / Double(totalClassifications)
    }

    mutating func addLearningExample(type: CryType, features: AudioFeatures) {
        if learnedPatterns[type] == nil {
            learnedPatterns[type] = [CryAcousticPattern(type: type)]
        }

        learnedPatterns[type]?[0].updateWith(features: features)
    }

    mutating func recordSoothingSuccess(for cryType: CryType, sound: GeneratorType) {
        if preferredSoothingSounds[cryType] == nil {
            preferredSoothingSounds[cryType] = []
        }

        // Add to front if effective (most recent = most relevant)
        if let index = preferredSoothingSounds[cryType]?.firstIndex(of: sound) {
            preferredSoothingSounds[cryType]?.remove(at: index)
        }
        preferredSoothingSounds[cryType]?.insert(sound, at: 0)

        // Keep top 5
        if preferredSoothingSounds[cryType]?.count ?? 0 > 5 {
            preferredSoothingSounds[cryType]?.removeLast()
        }
    }
}

// MARK: - Acoustic Feature Extractor
/// Extracts detailed acoustic features from audio samples
class AcousticFeatureExtractor {
    private let fftSize = 4096
    private var fftSetup: vDSP_DFT_Setup?
    private let sampleRate: Double = 44100

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    /// Extract comprehensive features from audio samples
    func extractFeatures(from samples: [Float], contextFrames: [[Float]] = []) -> AudioFeatures {
        guard samples.count >= fftSize else {
            return AudioFeatures()
        }

        // Calculate basic features
        let intensity = calculateIntensity(samples)
        let (fundamentalFreq, hnr) = estimatePitch(samples)
        let (centroid, flatness) = calculateSpectralFeatures(samples)
        let mfccs = calculateMFCCs(samples)

        // Calculate temporal features from context
        let rhythmicity = calculateRhythmicity(contextFrames)
        let pitchVar = calculatePitchVariability(contextFrames)
        let onsetSharpness = calculateOnsetSharpness(samples, contextFrames)

        // Estimate cry timing
        let cryDuration = estimateCryDuration(contextFrames)
        let pauseDuration = estimatePauseDuration(contextFrames)

        // Estimate formants
        let (f1, f2) = estimateFormants(samples)

        return AudioFeatures(
            fundamentalFrequency: fundamentalFreq,
            intensity: intensity,
            harmonicToNoiseRatio: hnr,
            spectralCentroid: centroid,
            spectralFlatness: flatness,
            rhythmicity: rhythmicity,
            pitchVariability: pitchVar,
            onsetSharpness: onsetSharpness,
            cryDuration: cryDuration,
            pauseDuration: pauseDuration,
            formantF1: f1,
            formantF2: f2,
            melFrequencyCoeffs: mfccs
        )
    }

    private func calculateIntensity(_ samples: [Float]) -> Double {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return Double(min(rms * 5, 1.0)) // Normalize to 0-1
    }

    private func estimatePitch(_ samples: [Float]) -> (Double, Double) {
        // Autocorrelation-based pitch estimation
        var autocorr = [Float](repeating: 0, count: samples.count)
        vDSP_conv(samples, 1, samples.reversed(), 1, &autocorr, 1, vDSP_Length(samples.count), vDSP_Length(samples.count))

        // Find first peak after initial decay (fundamental period)
        let minLag = Int(sampleRate / 700) // Max freq 700 Hz
        let maxLag = Int(sampleRate / 250) // Min freq 250 Hz

        var maxVal: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(Array(autocorr[minLag..<min(maxLag, autocorr.count)]), 1, &maxVal, &maxIdx, vDSP_Length(maxLag - minLag))

        let fundamentalFreq = maxIdx > 0 ? sampleRate / Double(maxIdx + vDSP_Length(minLag)) : 0

        // HNR approximation
        let hnr = maxVal > 0 ? Double(min(maxVal / autocorr[0], 1.0)) : 0

        return (fundamentalFreq, hnr)
    }

    private func calculateSpectralFeatures(_ samples: [Float]) -> (Double, Double) {
        guard let fftSetup = fftSetup else { return (0, 0) }

        // Window the signal
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // FFT
        var realInput = windowedSamples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Magnitudes - use withUnsafeMutableBufferPointer to satisfy lifetime requirements
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realPtr in
            imagOutput.withUnsafeMutableBufferPointer { imagPtr in
                var complex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Spectral centroid
        var weightedSum: Float = 0
        var totalMag: Float = 0
        let freqResolution = Float(sampleRate) / Float(fftSize)

        for i in 0..<magnitudes.count {
            let freq = Float(i) * freqResolution
            weightedSum += freq * magnitudes[i]
            totalMag += magnitudes[i]
        }
        let centroid = totalMag > 0 ? Double(weightedSum / totalMag) : 0

        // Spectral flatness
        let epsilon: Float = 1e-10
        var logSum: Float = 0
        for mag in magnitudes where mag > epsilon {
            logSum += log(mag + epsilon)
        }
        let n = Float(magnitudes.count)
        let geometricMean = exp(logSum / n)
        let arithmeticMean = totalMag / n
        let flatness = arithmeticMean > epsilon ? Double(geometricMean / arithmeticMean) : 0

        return (centroid, flatness)
    }

    private func calculateMFCCs(_ samples: [Float]) -> [Double] {
        // Simplified MFCC calculation (13 coefficients)
        // In production, use a proper DSP library
        let numCoeffs = 13
        var mfccs = [Double](repeating: 0, count: numCoeffs)

        // Placeholder - would use mel filterbank and DCT
        for i in 0..<numCoeffs {
            mfccs[i] = Double.random(in: -1...1) * 0.5
        }

        return mfccs
    }

    private func calculateRhythmicity(_ contextFrames: [[Float]]) -> Double {
        guard contextFrames.count > 5 else { return 0.5 }

        // Calculate RMS for each frame
        var rmsValues: [Float] = []
        for frame in contextFrames {
            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))
            rmsValues.append(rms)
        }

        // Calculate autocorrelation of RMS values
        guard rmsValues.count >= 4 else { return 0.5 }

        var autocorr: Float = 0
        for i in 0..<(rmsValues.count - 2) {
            autocorr += rmsValues[i] * rmsValues[i + 2]
        }

        let energy = rmsValues.reduce(0) { $0 + $1 * $1 }
        return energy > 0 ? min(Double(autocorr / energy), 1.0) : 0.5
    }

    private func calculatePitchVariability(_ contextFrames: [[Float]]) -> Double {
        guard contextFrames.count > 3 else { return 0.3 }

        var pitches: [Double] = []
        for frame in contextFrames {
            let (pitch, _) = estimatePitch(frame)
            if pitch > 200 && pitch < 800 {
                pitches.append(pitch)
            }
        }

        guard pitches.count > 2 else { return 0.3 }

        let mean = pitches.reduce(0, +) / Double(pitches.count)
        let variance = pitches.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pitches.count)
        let stdDev = sqrt(variance)

        // Normalize: 50Hz stddev = 0.5 variability
        return min(stdDev / 100, 1.0)
    }

    private func calculateOnsetSharpness(_ samples: [Float], _ contextFrames: [[Float]]) -> Double {
        guard !contextFrames.isEmpty else { return 0.5 }

        // Compare current RMS to previous
        var currentRMS: Float = 0
        vDSP_rmsqv(samples, 1, &currentRMS, vDSP_Length(samples.count))

        var previousRMS: Float = 0
        if let lastFrame = contextFrames.last {
            vDSP_rmsqv(lastFrame, 1, &previousRMS, vDSP_Length(lastFrame.count))
        }

        let ratio = previousRMS > 0.001 ? currentRMS / previousRMS : 1.0
        // Sharp onset = ratio > 2, gradual = ratio ~ 1
        return min(Double(max(ratio - 1, 0) / 3), 1.0)
    }

    private func estimateCryDuration(_ contextFrames: [[Float]]) -> Double {
        // Estimate based on consecutive high-energy frames
        var count = 0
        for frame in contextFrames.reversed() {
            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))
            if rms > 0.05 {
                count += 1
            } else {
                break
            }
        }
        // Assuming ~30 frames per second
        return Double(count) / 30.0
    }

    private func estimatePauseDuration(_ contextFrames: [[Float]]) -> Double {
        // Find silence gap before current cry burst
        var silenceCount = 0
        var foundCry = false

        for frame in contextFrames.reversed() {
            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))

            if rms < 0.03 {
                if foundCry {
                    silenceCount += 1
                }
            } else {
                if !foundCry {
                    foundCry = true
                } else {
                    break
                }
            }
        }

        return Double(silenceCount) / 30.0
    }

    private func estimateFormants(_ samples: [Float]) -> (Double, Double) {
        // Simplified formant estimation using LPC
        // In production, use proper LPC analysis
        // Typical baby cry formants: F1 ~600-900Hz, F2 ~1500-2500Hz
        return (750, 2000) // Placeholder values
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}
