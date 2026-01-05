//
//  CryAudioEmbedder.swift
//  BabyInCarApp
//
//  Advanced audio feature extraction for creating rich cry embeddings.
//  Creates unique acoustic fingerprints for each baby's cry patterns.
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - Cry Audio Embedding

/// Rich audio embedding that captures the full acoustic signature of a cry
struct CryAudioEmbedding: Codable {
    let id: UUID
    let timestamp: Date

    // MARK: - Core Acoustic Signature

    /// Fundamental frequency (F0) in Hz - the pitch
    let fundamentalF0: Float

    /// F0 variability - how much pitch changes during cry
    let f0Variability: Float

    /// Intensity envelope - volume shape over time (normalized 0-1)
    let intensityEnvelope: [Float]

    /// Harmonic structure - overtone pattern (unique per baby)
    let harmonicStructure: [Float]

    /// Formant frequencies (F1, F2, F3) - vocal tract resonances
    let formants: [Float]

    // MARK: - Emotional Markers

    /// Tremolo intensity - amplitude modulation indicating distress
    let tremoloIntensity: Float

    /// Breath pattern - inhale/exhale timing
    let breathPattern: [Float]

    /// Onset sharpness - sudden (pain) vs gradual (tired)
    let onsetSharpness: Float

    /// Number of voice breaks during cry
    let voiceBreaks: Int

    /// Vocal tension level (0-1)
    let vocalTension: Float

    /// Roughness/hoarseness of voice (0-1)
    let roughness: Float

    // MARK: - Temporal Pattern

    /// Duration of cry burst in seconds
    let burstDuration: Float

    /// Duration of pauses between bursts
    let pauseDuration: Float

    /// Rhythmicity score (0-1, higher = more regular pattern)
    let rhythmicity: Float

    /// Escalation trend (-1 = decreasing, 0 = stable, 1 = increasing)
    let escalationTrend: Float

    // MARK: - Spectral Features

    /// Spectral centroid - "brightness" of the sound
    let spectralCentroid: Float

    /// Spectral flatness - tonality vs noise
    let spectralFlatness: Float

    /// Spectral rolloff - frequency below which 85% of energy lies
    let spectralRolloff: Float

    /// Zero crossing rate
    let zeroCrossingRate: Float

    // MARK: - Baby Voice Print

    /// 128-dimensional embedding of baby's unique cry signature
    /// This is learned over time and improves with more data
    let voicePrint: [Float]

    // MARK: - Computed Properties

    /// Overall distress score based on emotional markers (0-1)
    var distressScore: Double {
        let tremorContribution = Double(tremoloIntensity) * 0.3
        let tensionContribution = Double(vocalTension) * 0.25
        let roughnessContribution = Double(roughness) * 0.15
        let onsetContribution = Double(onsetSharpness) * 0.2
        let breakContribution = min(Double(voiceBreaks) / 5.0, 1.0) * 0.1

        return min(1.0, tremorContribution + tensionContribution + roughnessContribution + onsetContribution + breakContribution)
    }

    /// Estimated cry type based on acoustic features
    var estimatedCryType: CryType {
        // Pain: high pitch, sudden onset, high distress
        if fundamentalF0 > 500 && onsetSharpness > 0.7 && distressScore > 0.6 {
            return .pain
        }

        // Hunger: rhythmic, moderate pitch, gradual build
        if rhythmicity > 0.6 && fundamentalF0 < 450 && escalationTrend > 0.2 {
            return .hunger
        }

        // Tired: lower intensity, irregular, lower pitch
        if spectralCentroid < 1000 && rhythmicity < 0.4 && vocalTension < 0.5 {
            return .tired
        }

        // Attention: medium pitch, not high distress
        if distressScore < 0.4 && fundamentalF0 > 350 && fundamentalF0 < 500 {
            return .attention
        }

        // Discomfort: sustained, variable
        if burstDuration > 2.0 && f0Variability > 50 {
            return .discomfort
        }

        return .general
    }

    /// Urgency level based on acoustic features (0-1)
    var urgencyLevel: Double {
        let distressWeight = distressScore * 0.4
        let intensityWeight = Double(intensityEnvelope.max() ?? 0) * 0.3
        let escalationWeight = Double(max(0, escalationTrend)) * 0.2
        let durationWeight = min(Double(burstDuration) / 10.0, 1.0) * 0.1

        return min(1.0, distressWeight + intensityWeight + escalationWeight + durationWeight)
    }
}

// MARK: - Cry Audio Embedder Service

/// Service that extracts rich audio embeddings from baby cries.
/// Designed for real-time processing with <50ms latency.
class CryAudioEmbedder {
    static let shared = CryAudioEmbedder()

    // MARK: - Configuration

    private let sampleRate: Float = 44100
    private let fftSize: Int = 4096
    private let hopSize: Int = 1024
    private let voicePrintSize: Int = 128

    // MARK: - FFT Setup

    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []

    // MARK: - Voice Print Learning

    /// Accumulated voice prints for each baby (used for averaging)
    private var babyVoicePrints: [UUID: [[Float]]] = [:]
    private let maxVoicePrintSamples = 100

    private init() {
        setupFFT()
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Main Embedding Extraction

    /// Extract a comprehensive cry embedding from audio samples
    /// - Parameters:
    ///   - samples: Audio samples (mono, 44.1kHz)
    ///   - babyId: Optional baby ID for voice print learning
    /// - Returns: Rich cry audio embedding
    func extractEmbedding(from samples: [Float], babyId: UUID? = nil) -> CryAudioEmbedding {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Ensure we have enough samples
        guard samples.count >= fftSize else {
            return createEmptyEmbedding()
        }

        // 1. Extract fundamental frequency and variability
        let (f0, f0Var) = extractF0(from: samples)

        // 2. Calculate intensity envelope
        let intensityEnv = extractIntensityEnvelope(from: samples)

        // 3. Extract harmonic structure
        let harmonics = extractHarmonics(from: samples)

        // 4. Extract formants
        let formants = extractFormants(from: samples)

        // 5. Calculate emotional markers
        let tremolo = extractTremoloIntensity(from: samples)
        let breathPattern = extractBreathPattern(from: samples)
        let onsetSharpness = calculateOnsetSharpness(envelope: intensityEnv)
        let voiceBreaks = countVoiceBreaks(from: samples)
        let tension = calculateVocalTension(from: samples, f0: f0)
        let roughness = calculateRoughness(from: samples)

        // 6. Extract temporal patterns
        let (burstDur, pauseDur) = extractTemporalPattern(from: samples)
        let rhythmicity = calculateRhythmicity(from: intensityEnv)
        let escalation = calculateEscalationTrend(from: intensityEnv)

        // 7. Extract spectral features
        let magnitudes = computeFFTMagnitudes(from: samples)
        let centroid = calculateSpectralCentroid(magnitudes: magnitudes)
        let flatness = calculateSpectralFlatness(magnitudes: magnitudes)
        let rolloff = calculateSpectralRolloff(magnitudes: magnitudes)
        let zcr = calculateZeroCrossingRate(samples: samples)

        // 8. Generate or retrieve voice print
        let voicePrint = generateVoicePrint(
            f0: f0,
            harmonics: harmonics,
            formants: formants,
            centroid: centroid,
            babyId: babyId
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed > 0.05 {
            print("Warning: CryAudioEmbedder took \(elapsed * 1000)ms (target: <50ms)")
        }

        return CryAudioEmbedding(
            id: UUID(),
            timestamp: Date(),
            fundamentalF0: f0,
            f0Variability: f0Var,
            intensityEnvelope: intensityEnv,
            harmonicStructure: harmonics,
            formants: formants,
            tremoloIntensity: tremolo,
            breathPattern: breathPattern,
            onsetSharpness: onsetSharpness,
            voiceBreaks: voiceBreaks,
            vocalTension: tension,
            roughness: roughness,
            burstDuration: burstDur,
            pauseDuration: pauseDur,
            rhythmicity: rhythmicity,
            escalationTrend: escalation,
            spectralCentroid: centroid,
            spectralFlatness: flatness,
            spectralRolloff: rolloff,
            zeroCrossingRate: zcr,
            voicePrint: voicePrint
        )
    }

    // MARK: - F0 Extraction (Pitch Detection)

    private func extractF0(from samples: [Float]) -> (f0: Float, variability: Float) {
        // Use autocorrelation for pitch detection
        var f0Values: [Float] = []

        let frameSize = fftSize
        let hopSize = self.hopSize

        var offset = 0
        while offset + frameSize <= samples.count {
            let frame = Array(samples[offset..<(offset + frameSize)])
            if let f0 = detectPitchAutocorrelation(frame: frame) {
                f0Values.append(f0)
            }
            offset += hopSize
        }

        guard !f0Values.isEmpty else {
            return (400, 0) // Default to ~400Hz if no pitch detected
        }

        // Calculate mean F0
        var meanF0: Float = 0
        vDSP_meanv(f0Values, 1, &meanF0, vDSP_Length(f0Values.count))

        // Calculate F0 variability (standard deviation)
        var variance: Float = 0
        var mean = meanF0
        vDSP_normalize(f0Values, 1, nil, 1, &mean, &variance, vDSP_Length(f0Values.count))
        let stdDev = sqrt(variance)

        return (meanF0, stdDev)
    }

    private func detectPitchAutocorrelation(frame: [Float]) -> Float? {
        // Autocorrelation-based pitch detection
        let minLag = Int(sampleRate / 600) // Max 600 Hz
        let maxLag = Int(sampleRate / 80)  // Min 80 Hz

        guard maxLag < frame.count else { return nil }

        var autocorr = [Float](repeating: 0, count: maxLag - minLag + 1)

        for lag in minLag...maxLag {
            var sum: Float = 0
            for i in 0..<(frame.count - lag) {
                sum += frame[i] * frame[i + lag]
            }
            autocorr[lag - minLag] = sum
        }

        // Find peak
        guard let maxIdx = autocorr.indices.max(by: { autocorr[$0] < autocorr[$1] }) else {
            return nil
        }

        let lag = minLag + maxIdx
        let f0 = sampleRate / Float(lag)

        // Only return if we found a clear peak (energy above threshold)
        if autocorr[maxIdx] > autocorr.reduce(0, +) / Float(autocorr.count) * 1.5 {
            return f0
        }

        return nil
    }

    // MARK: - Intensity Envelope

    private func extractIntensityEnvelope(from samples: [Float], frameCount: Int = 50) -> [Float] {
        let frameSize = samples.count / frameCount
        var envelope = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let start = i * frameSize
            let end = min(start + frameSize, samples.count)
            let frame = Array(samples[start..<end])

            // RMS energy
            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))
            envelope[i] = rms
        }

        // Normalize
        if let maxVal = envelope.max(), maxVal > 0 {
            for i in 0..<envelope.count {
                envelope[i] /= maxVal
            }
        }

        return envelope
    }

    // MARK: - Harmonic Structure

    private func extractHarmonics(from samples: [Float], harmonicCount: Int = 10) -> [Float] {
        let magnitudes = computeFFTMagnitudes(from: samples)

        // Find fundamental
        let (f0, _) = extractF0(from: samples)
        let binWidth = sampleRate / Float(fftSize)
        let fundamentalBin = Int(f0 / binWidth)

        // Extract harmonic amplitudes
        var harmonics = [Float](repeating: 0, count: harmonicCount)

        for h in 1...harmonicCount {
            let harmonicBin = fundamentalBin * h
            if harmonicBin < magnitudes.count {
                // Get max in small window around expected harmonic
                let windowStart = max(0, harmonicBin - 2)
                let windowEnd = min(magnitudes.count - 1, harmonicBin + 2)
                harmonics[h - 1] = magnitudes[windowStart...windowEnd].max() ?? 0
            }
        }

        // Normalize to fundamental
        if harmonics[0] > 0 {
            let fundamental = harmonics[0]
            for i in 0..<harmonics.count {
                harmonics[i] /= fundamental
            }
        }

        return harmonics
    }

    // MARK: - Formant Extraction

    private func extractFormants(from samples: [Float]) -> [Float] {
        // Simplified formant extraction using LPC
        // Returns [F1, F2, F3] estimates

        // Apply pre-emphasis
        var preEmph = [Float](repeating: 0, count: samples.count)
        preEmph[0] = samples[0]
        for i in 1..<samples.count {
            preEmph[i] = samples[i] - 0.97 * samples[i - 1]
        }

        // Find spectral peaks in formant regions
        let magnitudes = computeFFTMagnitudes(from: preEmph)
        let binWidth = sampleRate / Float(fftSize)

        // F1: 300-1000 Hz, F2: 1000-2500 Hz, F3: 2500-4000 Hz
        let f1Range = Int(300 / binWidth)...Int(1000 / binWidth)
        let f2Range = Int(1000 / binWidth)...Int(2500 / binWidth)
        let f3Range = Int(2500 / binWidth)...Int(min(4000 / binWidth, Float(magnitudes.count - 1)))

        let f1 = findPeakFrequency(magnitudes: magnitudes, range: f1Range, binWidth: binWidth)
        let f2 = findPeakFrequency(magnitudes: magnitudes, range: f2Range, binWidth: binWidth)
        let f3 = findPeakFrequency(magnitudes: magnitudes, range: f3Range, binWidth: binWidth)

        return [f1, f2, f3]
    }

    private func findPeakFrequency(magnitudes: [Float], range: ClosedRange<Int>, binWidth: Float) -> Float {
        guard range.upperBound < magnitudes.count else { return 0 }

        var maxBin = range.lowerBound
        var maxVal: Float = 0

        for bin in range {
            if magnitudes[bin] > maxVal {
                maxVal = magnitudes[bin]
                maxBin = bin
            }
        }

        return Float(maxBin) * binWidth
    }

    // MARK: - Emotional Markers

    private func extractTremoloIntensity(from samples: [Float]) -> Float {
        // Tremolo: amplitude modulation at 4-12 Hz (distress indicator)
        let envelope = extractIntensityEnvelope(from: samples, frameCount: 100)

        // Look for oscillations in the envelope
        var changes: Float = 0
        for i in 1..<envelope.count {
            changes += abs(envelope[i] - envelope[i - 1])
        }

        // Normalize by length
        let avgChange = changes / Float(envelope.count - 1)

        // Convert to 0-1 score (typical range 0.05-0.3)
        return min(1.0, avgChange / 0.3)
    }

    private func extractBreathPattern(from samples: [Float]) -> [Float] {
        // Extract breath timing from low-frequency envelope
        let envelope = extractIntensityEnvelope(from: samples, frameCount: 20)

        // Find valleys (breath pauses)
        var pattern: [Float] = []
        for i in 1..<(envelope.count - 1) {
            if envelope[i] < envelope[i - 1] && envelope[i] < envelope[i + 1] {
                pattern.append(Float(i) / Float(envelope.count))
            }
        }

        return pattern
    }

    private func calculateOnsetSharpness(envelope: [Float]) -> Float {
        guard envelope.count > 5 else { return 0.5 }

        // Look at how quickly the cry reaches peak intensity
        guard let maxIdx = envelope.indices.max(by: { envelope[$0] < envelope[$1] }) else {
            return 0.5
        }

        // Sharp onset: reaches max quickly
        let riseSamples = maxIdx + 1
        let totalSamples = envelope.count

        // Invert: fewer samples to peak = sharper onset
        let sharpness = 1.0 - Float(riseSamples) / Float(totalSamples)
        return max(0, min(1, sharpness * 2)) // Scale to 0-1
    }

    private func countVoiceBreaks(from samples: [Float]) -> Int {
        let envelope = extractIntensityEnvelope(from: samples, frameCount: 100)

        // Count sudden drops in energy
        var breaks = 0
        let threshold: Float = 0.3

        for i in 1..<envelope.count {
            if envelope[i - 1] > threshold && envelope[i] < threshold * 0.5 {
                breaks += 1
            }
        }

        return breaks
    }

    private func calculateVocalTension(from samples: [Float], f0: Float) -> Float {
        // Higher harmonics relative to fundamental indicate tension
        let harmonics = extractHarmonics(from: samples)

        guard harmonics.count >= 5 else { return 0.5 }

        // Sum of higher harmonics (3-5) vs lower (1-2)
        let lowerSum = harmonics[0] + harmonics[1]
        let higherSum = harmonics[2] + harmonics[3] + harmonics[4]

        guard lowerSum > 0 else { return 0.5 }

        let ratio = higherSum / lowerSum
        return min(1.0, ratio / 2.0) // Normalize to 0-1
    }

    private func calculateRoughness(from samples: [Float]) -> Float {
        // Roughness: irregularity in waveform
        var irregularity: Float = 0

        // Calculate local variance
        let frameSize = 256
        var variances: [Float] = []

        var offset = 0
        while offset + frameSize <= samples.count {
            let frame = Array(samples[offset..<(offset + frameSize)])
            var mean: Float = 0
            var stdDev: Float = 0
            vDSP_normalize(frame, 1, nil, 1, &mean, &stdDev, vDSP_Length(frame.count))
            variances.append(stdDev)
            offset += frameSize
        }

        // Variance of variances = roughness indicator
        if !variances.isEmpty {
            var mean: Float = 0
            var stdDev: Float = 0
            vDSP_normalize(variances, 1, nil, 1, &mean, &stdDev, vDSP_Length(variances.count))
            irregularity = stdDev / mean
        }

        return min(1.0, irregularity * 5) // Scale to 0-1
    }

    // MARK: - Temporal Patterns

    private func extractTemporalPattern(from samples: [Float]) -> (burstDuration: Float, pauseDuration: Float) {
        let envelope = extractIntensityEnvelope(from: samples, frameCount: 100)
        let threshold: Float = 0.2
        let frameDuration = Float(samples.count) / sampleRate / Float(envelope.count)

        var inBurst = false
        var burstStart = 0
        var burstLengths: [Float] = []
        var pauseLengths: [Float] = []
        var pauseStart = 0

        for (i, val) in envelope.enumerated() {
            if val > threshold {
                if !inBurst {
                    // Start of burst
                    if i > pauseStart {
                        pauseLengths.append(Float(i - pauseStart) * frameDuration)
                    }
                    burstStart = i
                    inBurst = true
                }
            } else {
                if inBurst {
                    // End of burst
                    burstLengths.append(Float(i - burstStart) * frameDuration)
                    pauseStart = i
                    inBurst = false
                }
            }
        }

        // Average durations
        let avgBurst = burstLengths.isEmpty ? 1.0 : burstLengths.reduce(0, +) / Float(burstLengths.count)
        let avgPause = pauseLengths.isEmpty ? 0.5 : pauseLengths.reduce(0, +) / Float(pauseLengths.count)

        return (avgBurst, avgPause)
    }

    private func calculateRhythmicity(from envelope: [Float]) -> Float {
        guard envelope.count > 10 else { return 0.5 }

        // Autocorrelation of envelope to find periodicity
        var maxCorr: Float = 0
        let maxLag = min(envelope.count / 2, 25)

        for lag in 2..<maxLag {
            var corr: Float = 0
            for i in 0..<(envelope.count - lag) {
                corr += envelope[i] * envelope[i + lag]
            }
            corr /= Float(envelope.count - lag)
            maxCorr = max(maxCorr, corr)
        }

        // Normalize by self-correlation
        var selfCorr: Float = 0
        vDSP_dotpr(envelope, 1, envelope, 1, &selfCorr, vDSP_Length(envelope.count))
        selfCorr /= Float(envelope.count)

        guard selfCorr > 0 else { return 0.5 }

        return min(1.0, maxCorr / selfCorr)
    }

    private func calculateEscalationTrend(from envelope: [Float]) -> Float {
        guard envelope.count > 4 else { return 0 }

        // Compare first third to last third
        let thirdSize = envelope.count / 3

        let firstThird = Array(envelope.prefix(thirdSize))
        let lastThird = Array(envelope.suffix(thirdSize))

        var firstMean: Float = 0
        var lastMean: Float = 0

        vDSP_meanv(firstThird, 1, &firstMean, vDSP_Length(firstThird.count))
        vDSP_meanv(lastThird, 1, &lastMean, vDSP_Length(lastThird.count))

        guard firstMean > 0 else { return 0 }

        // Positive = escalating, negative = de-escalating
        let trend = (lastMean - firstMean) / firstMean
        return max(-1, min(1, trend))
    }

    // MARK: - Spectral Features

    private func computeFFTMagnitudes(from samples: [Float]) -> [Float] {
        guard let fftSetup = fftSetup, samples.count >= fftSize else {
            return [Float](repeating: 0, count: fftSize / 2)
        }

        // Apply window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var windowCopy = window
        vDSP_vmul(Array(samples.prefix(fftSize)), 1, &windowCopy, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Perform FFT
        var realInput = windowedSamples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Normalize
        var scaleFactor: Float = 2.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(fftSize / 2))

        return magnitudes
    }

    private func calculateSpectralCentroid(magnitudes: [Float]) -> Float {
        let binWidth = sampleRate / Float(fftSize)

        var weightedSum: Float = 0
        var totalMagnitude: Float = 0

        for i in 0..<magnitudes.count {
            let frequency = Float(i) * binWidth
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }

        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private func calculateSpectralFlatness(magnitudes: [Float]) -> Float {
        let epsilon: Float = 1e-10

        var logSum: Float = 0
        var sum: Float = 0

        for mag in magnitudes where mag > epsilon {
            logSum += log(mag + epsilon)
            sum += mag
        }

        let n = Float(magnitudes.count)
        let geometricMean = exp(logSum / n)
        let arithmeticMean = sum / n

        return arithmeticMean > epsilon ? geometricMean / arithmeticMean : 0
    }

    private func calculateSpectralRolloff(magnitudes: [Float], percentage: Float = 0.85) -> Float {
        let binWidth = sampleRate / Float(fftSize)

        var totalEnergy: Float = 0
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))

        let threshold = totalEnergy * percentage
        var cumulative: Float = 0

        for (i, mag) in magnitudes.enumerated() {
            cumulative += mag
            if cumulative >= threshold {
                return Float(i) * binWidth
            }
        }

        return Float(magnitudes.count) * binWidth
    }

    private func calculateZeroCrossingRate(samples: [Float]) -> Float {
        var crossings = 0

        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i - 1] < 0) ||
               (samples[i] < 0 && samples[i - 1] >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(samples.count)
    }

    // MARK: - Voice Print Generation

    private func generateVoicePrint(
        f0: Float,
        harmonics: [Float],
        formants: [Float],
        centroid: Float,
        babyId: UUID?
    ) -> [Float] {
        // Create a 128-dimensional embedding
        var print = [Float](repeating: 0, count: voicePrintSize)

        // Section 1: Pitch features (32 dims)
        print[0] = f0 / 1000.0 // Normalized F0
        for i in 0..<min(harmonics.count, 31) {
            print[1 + i] = harmonics[i]
        }

        // Section 2: Formant features (32 dims)
        for i in 0..<min(formants.count, 3) {
            print[32 + i] = formants[i] / 4000.0 // Normalized formants
        }
        // Fill rest with zeros (reserved for learned features)

        // Section 3: Spectral shape (32 dims)
        print[64] = centroid / 4000.0

        // Section 4: Reserved for baby-specific learned features (32 dims)
        // These would be populated by a trained model

        // If we have baby ID, incorporate learned voice print
        if let babyId = babyId, let accumulated = babyVoicePrints[babyId] {
            // Average the accumulated prints
            if !accumulated.isEmpty {
                for i in 96..<voicePrintSize {
                    var sum: Float = 0
                    for acc in accumulated {
                        if i < acc.count {
                            sum += acc[i]
                        }
                    }
                    print[i] = sum / Float(accumulated.count)
                }
            }

            // Add current observation to accumulator
            var current = babyVoicePrints[babyId] ?? []
            current.append(print)
            if current.count > maxVoicePrintSamples {
                current.removeFirst()
            }
            babyVoicePrints[babyId] = current
        }

        return print
    }

    // MARK: - Utility

    private func createEmptyEmbedding() -> CryAudioEmbedding {
        return CryAudioEmbedding(
            id: UUID(),
            timestamp: Date(),
            fundamentalF0: 0,
            f0Variability: 0,
            intensityEnvelope: [],
            harmonicStructure: [],
            formants: [],
            tremoloIntensity: 0,
            breathPattern: [],
            onsetSharpness: 0,
            voiceBreaks: 0,
            vocalTension: 0,
            roughness: 0,
            burstDuration: 0,
            pauseDuration: 0,
            rhythmicity: 0,
            escalationTrend: 0,
            spectralCentroid: 0,
            spectralFlatness: 0,
            spectralRolloff: 0,
            zeroCrossingRate: 0,
            voicePrint: [Float](repeating: 0, count: voicePrintSize)
        )
    }

    /// Clear accumulated voice print data for a baby
    func clearVoicePrint(for babyId: UUID) {
        babyVoicePrints.removeValue(forKey: babyId)
    }

    /// Get voice print similarity between two embeddings (0-1)
    func voicePrintSimilarity(_ a: CryAudioEmbedding, _ b: CryAudioEmbedding) -> Float {
        guard a.voicePrint.count == b.voicePrint.count else { return 0 }

        // Cosine similarity
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a.voicePrint, 1, b.voicePrint, 1, &dotProduct, vDSP_Length(a.voicePrint.count))
        vDSP_dotpr(a.voicePrint, 1, a.voicePrint, 1, &normA, vDSP_Length(a.voicePrint.count))
        vDSP_dotpr(b.voicePrint, 1, b.voicePrint, 1, &normB, vDSP_Length(b.voicePrint.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}
