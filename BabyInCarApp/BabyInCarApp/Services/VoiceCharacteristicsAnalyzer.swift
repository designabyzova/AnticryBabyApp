//
//  VoiceCharacteristicsAnalyzer.swift
//  BabyInCarApp
//
//  Analyzes voice characteristics including tremolo, vibrato, voice breaks
//  These are key indicators of baby distress and emotional state
//

import Foundation
import Accelerate

// MARK: - Voice Characteristics

/// Comprehensive voice analysis results including trembling and vibrato detection
struct VoiceCharacteristics: Codable {
    /// Whether tremolo (amplitude modulation) was detected
    let hasTremolo: Bool

    /// Tremolo modulation rate in Hz (typically 4-12 Hz for distress)
    let tremoloRate: Double

    /// Tremolo depth/intensity (0-1 scale)
    let tremoloDepth: Double

    /// Whether vibrato (frequency modulation) was detected
    let hasVibrato: Bool

    /// Vibrato rate in Hz (typically 5-7 Hz)
    let vibratoRate: Double

    /// Vibrato extent in semitones
    let vibratoExtent: Double

    /// Number of voice breaks detected
    let voiceBreaks: Int

    /// Breathiness score (0-1, higher = more breathy/airy voice)
    let breathinessScore: Double

    /// Vocal tension indicator (0-1, higher = more tense)
    let tensionScore: Double

    /// Voice roughness/harshness (0-1)
    let roughnessScore: Double

    /// Overall distress indicator combining multiple factors (0-1)
    var distressIndicator: Double {
        var score: Double = 0

        // Tremolo contributes significantly to distress detection
        if hasTremolo && tremoloRate >= 4 && tremoloRate <= 12 {
            score += tremoloDepth * 0.3
        }

        // Voice breaks indicate distress
        score += min(Double(voiceBreaks) * 0.1, 0.2)

        // High tension indicates distress
        score += tensionScore * 0.25

        // Roughness can indicate crying
        score += roughnessScore * 0.15

        // High breathiness can indicate sobbing
        score += breathinessScore * 0.1

        return min(score, 1.0)
    }

    // MARK: - Zero/Default Instance

    static var zero: VoiceCharacteristics {
        VoiceCharacteristics(
            hasTremolo: false,
            tremoloRate: 0,
            tremoloDepth: 0,
            hasVibrato: false,
            vibratoRate: 0,
            vibratoExtent: 0,
            voiceBreaks: 0,
            breathinessScore: 0,
            tensionScore: 0,
            roughnessScore: 0
        )
    }
}

// MARK: - Voice Characteristics Analyzer

/// Analyzes voice trembling, vibrato, and other quality characteristics
/// Key for detecting baby distress beyond simple cry detection
class VoiceCharacteristicsAnalyzer {

    // MARK: - Configuration

    private let fftSize = 2048
    private var fftSetup: vDSP_DFT_Setup?

    /// Tremolo detection range (Hz) - distress typically 4-12 Hz
    private let tremoloMinRate: Float = 4.0
    private let tremoloMaxRate: Float = 12.0

    /// Vibrato detection range (Hz) - typically 5-7 Hz
    private let vibratoMinRate: Float = 5.0
    private let vibratoMaxRate: Float = 7.0

    /// Minimum modulation depth to consider tremolo present
    private let minTremoloDepth: Float = 0.1

    /// Minimum vibrato extent (semitones) to consider vibrato present
    private let minVibratoExtent: Float = 0.5

    // MARK: - State

    private var previousPitches: [Float] = []
    private var previousEnvelopes: [Float] = []
    private let maxHistorySize = 100

    // MARK: - Initialization

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }

    // MARK: - Main Analysis

    /// Analyze voice characteristics from audio samples
    /// - Parameters:
    ///   - samples: Audio samples (mono, float)
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Comprehensive voice characteristics
    func analyze(samples: [Float], sampleRate: Float) -> VoiceCharacteristics {
        guard samples.count >= fftSize else {
            return .zero
        }

        // 1. Extract amplitude envelope
        let envelope = extractAmplitudeEnvelope(samples: samples)

        // 2. Analyze tremolo (amplitude modulation)
        let (hasTremolo, tremoloRate, tremoloDepth) = analyzeTremolo(
            envelope: envelope,
            sampleRate: sampleRate
        )

        // 3. Extract pitch contour
        let pitchContour = extractPitchContour(samples: samples, sampleRate: sampleRate)

        // 4. Analyze vibrato (frequency modulation)
        let (hasVibrato, vibratoRate, vibratoExtent) = analyzeVibrato(
            pitchContour: pitchContour,
            sampleRate: sampleRate
        )

        // 5. Detect voice breaks
        let voiceBreaks = detectVoiceBreaks(
            envelope: envelope,
            pitchContour: pitchContour,
            sampleRate: sampleRate
        )

        // 6. Calculate breathiness
        let breathiness = calculateBreathiness(samples: samples, sampleRate: sampleRate)

        // 7. Calculate vocal tension
        let tension = calculateTension(samples: samples, sampleRate: sampleRate)

        // 8. Calculate roughness
        let roughness = calculateRoughness(samples: samples)

        // Update history for temporal analysis
        updateHistory(envelope: envelope, pitchContour: pitchContour)

        return VoiceCharacteristics(
            hasTremolo: hasTremolo,
            tremoloRate: Double(tremoloRate),
            tremoloDepth: Double(tremoloDepth),
            hasVibrato: hasVibrato,
            vibratoRate: Double(vibratoRate),
            vibratoExtent: Double(vibratoExtent),
            voiceBreaks: voiceBreaks,
            breathinessScore: Double(breathiness),
            tensionScore: Double(tension),
            roughnessScore: Double(roughness)
        )
    }

    /// Reset internal state
    func reset() {
        previousPitches = []
        previousEnvelopes = []
    }

    // MARK: - Amplitude Envelope Extraction

    /// Extract amplitude envelope using Hilbert transform approximation
    private func extractAmplitudeEnvelope(samples: [Float]) -> [Float] {
        // Half-wave rectification
        var envelope = samples.map { abs($0) }

        // Low-pass filter at ~30 Hz to get smooth envelope
        envelope = lowPassFilter(envelope, cutoffSamples: 50)

        return envelope
    }

    /// Simple moving average low-pass filter
    private func lowPassFilter(_ signal: [Float], cutoffSamples: Int) -> [Float] {
        var filtered = signal
        let halfWindow = cutoffSamples / 2

        for i in halfWindow..<(signal.count - halfWindow) {
            var sum: Float = 0
            for j in (i - halfWindow)...(i + halfWindow) {
                sum += signal[j]
            }
            filtered[i] = sum / Float(cutoffSamples + 1)
        }

        return filtered
    }

    // MARK: - Tremolo Analysis

    /// Analyze tremolo (amplitude modulation) in the envelope
    private func analyzeTremolo(envelope: [Float], sampleRate: Float) -> (Bool, Float, Float) {
        guard envelope.count >= fftSize, let fftSetup = fftSetup else {
            return (false, 0, 0)
        }

        // Downsample envelope to analyze modulation rates
        let downsampledEnvelope = downsample(envelope, factor: 16)

        guard downsampledEnvelope.count >= fftSize else {
            return (false, 0, 0)
        }

        // Perform FFT on envelope to find modulation frequency
        var realInput = Array(downsampledEnvelope.prefix(fftSize))
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Remove DC component
        let mean = realInput.reduce(0, +) / Float(realInput.count)
        for i in 0..<realInput.count {
            realInput[i] -= mean
        }

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Find peak in tremolo frequency range
        let freqResolution = (sampleRate / 256) / Float(fftSize)
        let minBin = max(1, Int(tremoloMinRate / freqResolution))
        let maxBin = min(Int(tremoloMaxRate / freqResolution), magnitudes.count - 1)

        guard minBin < maxBin else { return (false, 0, 0) }

        var maxMag: Float = 0
        var maxIdx: vDSP_Length = 0
        let searchRange = Array(magnitudes[minBin..<maxBin])
        vDSP_maxvi(searchRange, 1, &maxMag, &maxIdx, vDSP_Length(searchRange.count))

        let tremoloRate = Float(Int(maxIdx) + minBin) * freqResolution

        // Calculate depth relative to DC component (magnitudes[0])
        let dcComponent = max(magnitudes[0], 0.001)
        let tremoloDepth = min(maxMag / dcComponent, 1.0)

        let hasTremolo = tremoloDepth > minTremoloDepth &&
                         tremoloRate >= tremoloMinRate &&
                         tremoloRate <= tremoloMaxRate

        return (hasTremolo, tremoloRate, tremoloDepth)
    }

    /// Downsample signal by a factor
    private func downsample(_ signal: [Float], factor: Int) -> [Float] {
        var downsampled: [Float] = []
        for i in stride(from: 0, to: signal.count, by: factor) {
            downsampled.append(signal[i])
        }
        return downsampled
    }

    // MARK: - Pitch Contour Extraction

    /// Extract pitch values at regular intervals
    private func extractPitchContour(samples: [Float], sampleRate: Float) -> [Float] {
        let hopSize = 256
        var pitches: [Float] = []

        for i in stride(from: 0, to: samples.count - 1024, by: hopSize) {
            let frame = Array(samples[i..<(i + 1024)])
            let pitch = estimatePitch(frame: frame, sampleRate: sampleRate)
            pitches.append(pitch)
        }

        return pitches
    }

    /// Estimate pitch using autocorrelation
    private func estimatePitch(frame: [Float], sampleRate: Float) -> Float {
        guard frame.count >= 512 else { return 0 }

        var autocorr = [Float](repeating: 0, count: frame.count)
        vDSP_conv(frame, 1, frame.reversed(), 1, &autocorr, 1,
                  vDSP_Length(frame.count), vDSP_Length(frame.count))

        // Search in baby cry pitch range (200-700 Hz)
        let minLag = Int(sampleRate / 700)
        let maxLag = min(Int(sampleRate / 200), frame.count - 1)

        guard minLag < maxLag && maxLag < autocorr.count else { return 0 }

        var maxVal: Float = 0
        var maxIdx: vDSP_Length = 0
        let searchRange = Array(autocorr[minLag..<maxLag])
        vDSP_maxvi(searchRange, 1, &maxVal, &maxIdx, vDSP_Length(searchRange.count))

        let lag = Int(maxIdx) + minLag

        // Check if peak is strong enough
        guard maxVal > autocorr[0] * 0.3 && lag > 0 else { return 0 }

        return sampleRate / Float(lag)
    }

    // MARK: - Vibrato Analysis

    /// Analyze vibrato (frequency modulation) in pitch contour
    private func analyzeVibrato(pitchContour: [Float], sampleRate: Float) -> (Bool, Float, Float) {
        // Filter out zero pitches (unvoiced segments)
        let voicedPitches = pitchContour.filter { $0 > 0 }
        guard voicedPitches.count >= 32 else { return (false, 0, 0) }

        // Convert to semitones relative to median
        let sortedPitches = voicedPitches.sorted()
        let medianPitch = sortedPitches[sortedPitches.count / 2]

        var semitones = voicedPitches.map { pitch -> Float in
            guard pitch > 0, medianPitch > 0 else { return 0 }
            return 12 * log2(pitch / medianPitch)
        }

        guard let fftSetup = fftSetup else { return (false, 0, 0) }

        // Pad or truncate to fftSize
        while semitones.count < fftSize {
            semitones.append(0)
        }
        semitones = Array(semitones.prefix(fftSize))

        // Remove mean
        let mean = semitones.reduce(0, +) / Float(semitones.count)
        for i in 0..<semitones.count {
            semitones[i] -= mean
        }

        // FFT to find vibrato frequency
        var realInput = semitones
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Pitch contour sample rate (based on hop size)
        let pitchSampleRate = sampleRate / 256
        let freqResolution = pitchSampleRate / Float(fftSize)

        let minBin = max(1, Int(vibratoMinRate / freqResolution))
        let maxBin = min(Int(vibratoMaxRate / freqResolution), magnitudes.count - 1)

        guard minBin < maxBin else { return (false, 0, 0) }

        var maxMag: Float = 0
        var maxIdx: vDSP_Length = 0
        let searchRange = Array(magnitudes[minBin..<maxBin])
        vDSP_maxvi(searchRange, 1, &maxMag, &maxIdx, vDSP_Length(searchRange.count))

        let vibratoRate = Float(Int(maxIdx) + minBin) * freqResolution
        let vibratoExtent = maxMag * 2 // Peak-to-peak in semitones

        let hasVibrato = vibratoExtent > minVibratoExtent &&
                         vibratoRate >= vibratoMinRate &&
                         vibratoRate <= vibratoMaxRate

        return (hasVibrato, vibratoRate, vibratoExtent)
    }

    // MARK: - Voice Break Detection

    /// Detect voice breaks (sudden disruptions in voice)
    private func detectVoiceBreaks(envelope: [Float], pitchContour: [Float], sampleRate: Float) -> Int {
        var breaks = 0

        // Detect breaks from envelope drops
        let envelopeThreshold: Float = 0.3 // 70% drop
        for i in 1..<envelope.count {
            if envelope[i - 1] > 0.1 && envelope[i] < envelope[i - 1] * envelopeThreshold {
                breaks += 1
            }
        }

        // Detect breaks from pitch discontinuities
        let pitchJumpThreshold: Float = 1.5 // 50% frequency jump
        for i in 1..<pitchContour.count {
            if pitchContour[i - 1] > 0 && pitchContour[i] > 0 {
                let ratio = pitchContour[i] / pitchContour[i - 1]
                if ratio > pitchJumpThreshold || ratio < 1.0 / pitchJumpThreshold {
                    breaks += 1
                }
            }
        }

        // Detect voiced-to-unvoiced transitions
        var voicedToUnvoiced = 0
        for i in 1..<pitchContour.count {
            if pitchContour[i - 1] > 0 && pitchContour[i] == 0 {
                voicedToUnvoiced += 1
            }
        }
        // Only count if there are multiple quick transitions
        if voicedToUnvoiced > 3 {
            breaks += voicedToUnvoiced / 2
        }

        return breaks
    }

    // MARK: - Breathiness Analysis

    /// Calculate breathiness using harmonic-to-noise characteristics
    private func calculateBreathiness(samples: [Float], sampleRate: Float) -> Float {
        guard let fftSetup = fftSetup, samples.count >= fftSize else { return 0 }

        // Perform FFT
        var realInput = Array(samples.prefix(fftSize))
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Apply window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftSize))

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Spectral flatness as proxy for breathiness
        // Higher flatness = more noise-like = more breathy
        let epsilon: Float = 1e-10
        var logSum: Float = 0
        var sum: Float = 0
        var count: Int = 0

        for mag in magnitudes where mag > epsilon {
            logSum += log(mag + epsilon)
            sum += mag
            count += 1
        }

        guard count > 0 else { return 0 }

        let n = Float(count)
        let geometricMean = exp(logSum / n)
        let arithmeticMean = sum / n

        let flatness = arithmeticMean > epsilon ? geometricMean / arithmeticMean : 0

        // Scale to 0-1 range (flatness typically 0-0.5 for voice)
        return min(flatness * 2, 1.0)
    }

    // MARK: - Tension Analysis

    /// Calculate vocal tension indicator
    private func calculateTension(samples: [Float], sampleRate: Float) -> Float {
        // Tension indicators:
        // 1. Higher RMS energy
        // 2. Higher spectral centroid
        // 3. More energy in upper harmonics

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Higher intensity often correlates with tension
        let intensityScore = min(rms * 5, 1.0)

        // Also consider spectral energy distribution
        guard let fftSetup = fftSetup, samples.count >= fftSize else {
            return intensityScore
        }

        var realInput = Array(samples.prefix(fftSize))
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftSize))

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Calculate ratio of high-frequency energy to low-frequency energy
        let freqResolution = sampleRate / Float(fftSize)
        let splitBin = Int(1500 / freqResolution) // Split at 1500 Hz

        var lowEnergy: Float = 0
        var highEnergy: Float = 0

        for i in 0..<min(splitBin, magnitudes.count) {
            lowEnergy += magnitudes[i] * magnitudes[i]
        }
        for i in splitBin..<magnitudes.count {
            highEnergy += magnitudes[i] * magnitudes[i]
        }

        let highToLowRatio = lowEnergy > 0 ? highEnergy / lowEnergy : 0
        let spectralScore = min(highToLowRatio * 2, 1.0)

        // Combine scores
        return (intensityScore * 0.6 + spectralScore * 0.4)
    }

    // MARK: - Roughness Analysis

    /// Calculate voice roughness from rapid amplitude fluctuations
    private func calculateRoughness(samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }

        // Roughness from rapid amplitude changes
        var totalChange: Float = 0
        for i in 1..<samples.count {
            totalChange += abs(samples[i] - samples[i - 1])
        }

        let avgChange = totalChange / Float(samples.count - 1)

        // Also calculate variance in short windows
        let windowSize = 64
        var varianceSum: Float = 0
        var windowCount = 0

        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize / 2) {
            let window = Array(samples[i..<(i + windowSize)])
            let mean = window.reduce(0, +) / Float(windowSize)
            let variance = window.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(windowSize)
            varianceSum += sqrt(variance)
            windowCount += 1
        }

        let avgVariance = windowCount > 0 ? varianceSum / Float(windowCount) : 0

        // Combine metrics
        let changeScore = min(avgChange * 10, 1.0)
        let varianceScore = min(avgVariance * 5, 1.0)

        return (changeScore + varianceScore) / 2
    }

    // MARK: - History Management

    private func updateHistory(envelope: [Float], pitchContour: [Float]) {
        // Append to history
        previousEnvelopes.append(contentsOf: envelope.suffix(32))
        previousPitches.append(contentsOf: pitchContour.suffix(16))

        // Trim to max size
        if previousEnvelopes.count > maxHistorySize {
            previousEnvelopes.removeFirst(previousEnvelopes.count - maxHistorySize)
        }
        if previousPitches.count > maxHistorySize {
            previousPitches.removeFirst(previousPitches.count - maxHistorySize)
        }
    }
}

// MARK: - Voice Analysis Result

/// Complete voice analysis result combining characteristics with context
struct VoiceAnalysisResult: Codable {
    let characteristics: VoiceCharacteristics
    let timestamp: Date
    let durationAnalyzed: TimeInterval
    let confidenceScore: Double

    /// Whether this indicates a distressed baby based on voice characteristics
    var isDistressed: Bool {
        characteristics.distressIndicator > 0.5
    }

    /// Suggested urgency level based on voice characteristics
    var urgencyLevel: UrgencyLevel {
        let distress = characteristics.distressIndicator

        if distress > 0.8 {
            return .high
        } else if distress > 0.5 {
            return .medium
        } else if distress > 0.3 {
            return .low
        } else {
            return .none
        }
    }

    enum UrgencyLevel: String, Codable {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}
