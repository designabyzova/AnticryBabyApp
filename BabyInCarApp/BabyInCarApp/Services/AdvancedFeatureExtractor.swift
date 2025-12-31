//
//  AdvancedFeatureExtractor.swift
//  BabyInCarApp
//
//  Comprehensive audio feature extraction for ultra-smart baby cry analysis
//  Extracts 50+ acoustic features using Accelerate framework for real-time processing
//

import Foundation
import Accelerate

// MARK: - Extended Audio Features

/// Comprehensive audio features for ML-based cry analysis
/// Extends the basic AudioFeatures with full spectrum analysis
struct ExtendedAudioFeatures: Codable {
    // MARK: - Core Features (from existing AudioFeatures)
    let fundamentalFrequency: Double      // Hz - F0
    let intensity: Double                  // 0-1 normalized RMS
    let harmonicToNoiseRatio: Double      // 0-1 voice quality
    let spectralCentroid: Double          // Hz - brightness
    let spectralFlatness: Double          // 0-1 tonality (0=tonal, 1=noise)
    let rhythmicity: Double               // 0-1 periodicity
    let pitchVariability: Double          // 0-1 pitch variation
    let onsetSharpness: Double            // 0-1 attack transient
    let cryDuration: Double               // seconds
    let pauseDuration: Double             // seconds between bursts
    let formantF1: Double                 // Hz - first formant
    let formantF2: Double                 // Hz - second formant
    let melFrequencyCoeffs: [Double]      // 13 MFCCs

    // MARK: - Extended Spectral Features
    let spectralRolloff: Double           // Hz - frequency below 85% energy
    let spectralBandwidth: Double         // Hz - spread around centroid
    let spectralContrast: [Double]        // 6-band contrast values
    let spectralFlux: Double              // Frame-to-frame spectral change
    let spectralSlope: Double             // Overall spectral tilt

    // MARK: - Energy Features
    let zeroCrossingRate: Double          // Crossings per second
    let rmsEnergy: Double                 // Raw RMS value
    let loudnessDBFS: Double              // dB full scale (-100 to 0)
    let peakAmplitude: Double             // Maximum sample value

    // MARK: - Harmonic Features
    let harmonicsStrength: [Double]       // First 5 harmonic strengths
    let harmonicDeviation: Double         // Deviation from harmonic series
    let inharmonicity: Double             // Degree of inharmonicity

    // MARK: - Voice Quality Features
    let jitter: Double                    // Pitch perturbation (0-1)
    let shimmer: Double                   // Amplitude perturbation (0-1)
    let temporalModulation: Double        // Envelope modulation rate (Hz)

    // MARK: - Additional Formants
    let formantF3: Double                 // Hz - third formant
    let formantBandwidths: [Double]       // Bandwidths of F1, F2, F3

    // MARK: - Pitch Class Features
    let chromaFeatures: [Double]          // 12-bin pitch class

    // MARK: - Temporal Derivative Features
    let deltaCoeffs: [Double]             // Delta MFCCs (velocity)
    let deltaDeltaCoeffs: [Double]        // Delta-delta MFCCs (acceleration)

    // MARK: - ML Feature Vector

    /// Returns a normalized feature vector for ML inference (50 features)
    var featureVector: [Float] {
        var vector: [Float] = []

        // Core features (normalized)
        vector.append(Float(fundamentalFrequency / 1000))        // 0-1 range for typical F0
        vector.append(Float(intensity))                          // Already 0-1
        vector.append(Float(harmonicToNoiseRatio))               // Already 0-1
        vector.append(Float(spectralCentroid / 5000))            // Normalize to ~0-1
        vector.append(Float(spectralFlatness))                   // Already 0-1
        vector.append(Float(rhythmicity))                        // Already 0-1
        vector.append(Float(pitchVariability))                   // Already 0-1
        vector.append(Float(onsetSharpness))                     // Already 0-1

        // Extended spectral
        vector.append(Float(spectralRolloff / 5000))             // Normalize
        vector.append(Float(spectralBandwidth / 2000))           // Normalize
        vector.append(Float(spectralFlux))                       // 0-1 typical
        vector.append(Float((loudnessDBFS + 100) / 100))         // -100..0 -> 0..1

        // Voice quality
        vector.append(Float(jitter))                             // Already 0-1
        vector.append(Float(shimmer))                            // Already 0-1
        vector.append(Float(zeroCrossingRate / 1000))            // Normalize
        vector.append(Float(temporalModulation / 20))            // Normalize Hz

        // MFCCs (13 coefficients, normalized)
        for i in 0..<min(13, melFrequencyCoeffs.count) {
            vector.append(Float(melFrequencyCoeffs[i] / 100))    // Rough normalization
        }
        // Pad if needed
        while vector.count < 29 {
            vector.append(0)
        }

        // Harmonics (5 values)
        for i in 0..<min(5, harmonicsStrength.count) {
            vector.append(Float(harmonicsStrength[i]))
        }
        while vector.count < 34 {
            vector.append(0)
        }

        // Spectral contrast (6 bands)
        for i in 0..<min(6, spectralContrast.count) {
            vector.append(Float(spectralContrast[i] / 100))
        }
        while vector.count < 40 {
            vector.append(0)
        }

        // Chroma (12 bins)
        for i in 0..<min(12, chromaFeatures.count) {
            vector.append(Float(chromaFeatures[i]))
        }
        while vector.count < 52 {
            vector.append(0)
        }

        // Trim to exactly 50 features
        return Array(vector.prefix(50))
    }

    // MARK: - Zero/Default Instance

    static var zero: ExtendedAudioFeatures {
        ExtendedAudioFeatures(
            fundamentalFrequency: 0,
            intensity: 0,
            harmonicToNoiseRatio: 0,
            spectralCentroid: 0,
            spectralFlatness: 0,
            rhythmicity: 0.5,
            pitchVariability: 0.3,
            onsetSharpness: 0,
            cryDuration: 0,
            pauseDuration: 0,
            formantF1: 0,
            formantF2: 0,
            melFrequencyCoeffs: Array(repeating: 0, count: 13),
            spectralRolloff: 0,
            spectralBandwidth: 0,
            spectralContrast: Array(repeating: 0, count: 6),
            spectralFlux: 0,
            spectralSlope: 0,
            zeroCrossingRate: 0,
            rmsEnergy: 0,
            loudnessDBFS: -100,
            peakAmplitude: 0,
            harmonicsStrength: Array(repeating: 0, count: 5),
            harmonicDeviation: 0,
            inharmonicity: 0,
            jitter: 0,
            shimmer: 0,
            temporalModulation: 0,
            formantF3: 0,
            formantBandwidths: [100, 120, 150],
            chromaFeatures: Array(repeating: 0, count: 12),
            deltaCoeffs: Array(repeating: 0, count: 13),
            deltaDeltaCoeffs: Array(repeating: 0, count: 13)
        )
    }

    // MARK: - Conversion from basic AudioFeatures

    /// Create extended features from basic AudioFeatures with defaults for missing values
    init(from basic: AudioFeatures) {
        self.fundamentalFrequency = basic.fundamentalFrequency
        self.intensity = basic.intensity
        self.harmonicToNoiseRatio = basic.harmonicToNoiseRatio
        self.spectralCentroid = basic.spectralCentroid
        self.spectralFlatness = basic.spectralFlatness
        self.rhythmicity = basic.rhythmicity
        self.pitchVariability = basic.pitchVariability
        self.onsetSharpness = basic.onsetSharpness
        self.cryDuration = basic.cryDuration
        self.pauseDuration = basic.pauseDuration
        self.formantF1 = basic.formantF1
        self.formantF2 = basic.formantF2
        self.melFrequencyCoeffs = basic.melFrequencyCoeffs

        // Defaults for extended features
        self.spectralRolloff = basic.spectralCentroid * 1.5
        self.spectralBandwidth = 500
        self.spectralContrast = Array(repeating: 50, count: 6)
        self.spectralFlux = basic.onsetSharpness
        self.spectralSlope = -0.01
        self.zeroCrossingRate = 500
        self.rmsEnergy = basic.intensity * 0.2
        self.loudnessDBFS = -20 - (1 - basic.intensity) * 60
        self.peakAmplitude = basic.intensity
        self.harmonicsStrength = [0.5, 0.3, 0.2, 0.1, 0.05]
        self.harmonicDeviation = 0.1
        self.inharmonicity = 0.05
        self.jitter = 0.02
        self.shimmer = 0.03
        self.temporalModulation = 5
        self.formantF3 = basic.formantF2 * 1.5
        self.formantBandwidths = [100, 120, 150]
        self.chromaFeatures = Array(repeating: 0.083, count: 12)
        self.deltaCoeffs = Array(repeating: 0, count: 13)
        self.deltaDeltaCoeffs = Array(repeating: 0, count: 13)
    }
}

// MARK: - Advanced Feature Extractor

/// Comprehensive audio feature extraction using Accelerate framework
/// Designed for real-time processing with < 50ms latency per buffer
class AdvancedFeatureExtractor {

    // MARK: - FFT Configuration
    private let fftSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var magnitudes: [Float]
    private var phases: [Float]
    private var previousMagnitudes: [Float]

    // MARK: - Mel Filterbank
    private var melFilterbank: [[Float]]
    private let numMelFilters = 26
    private let numMFCCs = 13

    // MARK: - State for Temporal Features
    private var previousMFCCs: [Double] = []
    private var previousDeltaMFCCs: [Double] = []
    private var previousSamples: [Float] = []
    private var pitchHistory: [Float] = []
    private let maxPitchHistory = 30

    // MARK: - Initialization

    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        // Create Hann window
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Initialize magnitude arrays
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.phases = [Float](repeating: 0, count: fftSize / 2)
        self.previousMagnitudes = [Float](repeating: 0, count: fftSize / 2)

        // Create mel filterbank
        self.melFilterbank = Self.createMelFilterbank(
            sampleRate: 44100,
            fftSize: fftSize,
            numFilters: numMelFilters
        )
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }

    // MARK: - Main Feature Extraction

    /// Extract comprehensive features from audio samples
    /// - Parameters:
    ///   - samples: Audio samples (mono, float)
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Complete extended audio features
    func extractFeatures(from samples: [Float], sampleRate: Float) -> ExtendedAudioFeatures {
        guard samples.count >= fftSize else {
            return .zero
        }

        let freqResolution = sampleRate / Float(fftSize)

        // Perform FFT
        performFFT(on: samples)

        // Calculate all features
        let fundamentalFreq = estimateFundamentalFrequency(samples: samples, sampleRate: sampleRate)
        let intensity = calculateRMSEnergy(samples: samples)
        let hnr = calculateHNR(fundamentalFreq: fundamentalFreq, freqResolution: freqResolution)
        let centroid = calculateSpectralCentroid(freqResolution: freqResolution)
        let flatness = calculateSpectralFlatness()
        let rolloff = calculateSpectralRolloff(freqResolution: freqResolution)
        let bandwidth = calculateSpectralBandwidth(centroid: centroid, freqResolution: freqResolution)
        let contrast = calculateSpectralContrast()
        let flux = calculateSpectralFlux()
        let slope = calculateSpectralSlope(freqResolution: freqResolution)
        let zcr = calculateZeroCrossingRate(samples: samples, sampleRate: sampleRate)
        let loudness = calculateLoudnessDBFS(rms: intensity)
        let peak = calculatePeakAmplitude(samples: samples)
        let harmonics = extractHarmonics(fundamentalFreq: fundamentalFreq, freqResolution: freqResolution)
        let (harmonicDev, inharm) = calculateHarmonicDeviations(
            fundamentalFreq: fundamentalFreq,
            freqResolution: freqResolution
        )
        let (jitter, shimmer) = calculateJitterShimmer(samples: samples, sampleRate: sampleRate)
        let modulation = calculateTemporalModulation(samples: samples, sampleRate: sampleRate)
        let formants = estimateFormants(sampleRate: sampleRate)
        let mfccs = calculateMFCCs()
        let (deltas, deltaDeltas) = calculateDeltaCoefficients(mfccs: mfccs)
        let chroma = calculateChromaFeatures(sampleRate: sampleRate)

        // Calculate temporal features from history
        let rhythmicity = calculateRhythmicity()
        let pitchVar = calculatePitchVariability()
        let onsetSharp = calculateOnsetSharpness(samples: samples)

        // Update state for next frame
        previousMagnitudes = magnitudes
        previousMFCCs = mfccs
        previousDeltaMFCCs = deltas
        previousSamples = Array(samples.suffix(1024))
        if fundamentalFreq > 0 {
            pitchHistory.append(fundamentalFreq)
            if pitchHistory.count > maxPitchHistory {
                pitchHistory.removeFirst()
            }
        }

        return ExtendedAudioFeatures(
            fundamentalFrequency: Double(fundamentalFreq),
            intensity: Double(min(intensity * 5, 1.0)),
            harmonicToNoiseRatio: Double(hnr),
            spectralCentroid: Double(centroid),
            spectralFlatness: Double(flatness),
            rhythmicity: rhythmicity,
            pitchVariability: pitchVar,
            onsetSharpness: Double(onsetSharp),
            cryDuration: 0, // Tracked externally by CryPatternTracker
            pauseDuration: 0, // Tracked externally
            formantF1: Double(formants.f1),
            formantF2: Double(formants.f2),
            melFrequencyCoeffs: mfccs,
            spectralRolloff: Double(rolloff),
            spectralBandwidth: Double(bandwidth),
            spectralContrast: contrast.map { Double($0) },
            spectralFlux: Double(flux),
            spectralSlope: Double(slope),
            zeroCrossingRate: Double(zcr),
            rmsEnergy: Double(intensity),
            loudnessDBFS: Double(loudness),
            peakAmplitude: Double(peak),
            harmonicsStrength: harmonics.map { Double($0) },
            harmonicDeviation: Double(harmonicDev),
            inharmonicity: Double(inharm),
            jitter: Double(jitter),
            shimmer: Double(shimmer),
            temporalModulation: Double(modulation),
            formantF3: Double(formants.f3),
            formantBandwidths: formants.bandwidths.map { Double($0) },
            chromaFeatures: chroma.map { Double($0) },
            deltaCoeffs: deltas,
            deltaDeltaCoeffs: deltaDeltas
        )
    }

    /// Reset internal state (call when starting new analysis session)
    func reset() {
        previousMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        previousMFCCs = []
        previousDeltaMFCCs = []
        previousSamples = []
        pitchHistory = []
    }

    // MARK: - FFT

    private func performFFT(on samples: [Float]) {
        guard let fftSetup = fftSetup else { return }

        // Apply window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Prepare complex arrays
        var realInput = windowedSamples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Execute DFT
        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitudes
        var complex = DSPSplitComplex(realp: &realOutput, imagp: &imagOutput)
        vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Calculate phases
        for i in 0..<fftSize/2 {
            phases[i] = atan2(imagOutput[i], realOutput[i])
        }

        // Normalize magnitudes
        var scaleFactor: Float = 2.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(fftSize / 2))
    }

    // MARK: - Fundamental Frequency Estimation

    private func estimateFundamentalFrequency(samples: [Float], sampleRate: Float) -> Float {
        // Autocorrelation-based pitch estimation
        guard samples.count >= 1024 else { return 0 }

        let frameSize = min(1024, samples.count)
        let frame = Array(samples.prefix(frameSize))

        var autocorr = [Float](repeating: 0, count: frameSize)
        vDSP_conv(frame, 1, frame.reversed(), 1, &autocorr, 1,
                  vDSP_Length(frameSize), vDSP_Length(frameSize))

        // Search range: 200-700 Hz (baby cry range)
        let minLag = Int(sampleRate / 700)
        let maxLag = min(Int(sampleRate / 200), frameSize - 1)

        guard minLag < maxLag && maxLag < autocorr.count else { return 0 }

        var maxVal: Float = 0
        var maxIdx: vDSP_Length = 0
        let searchRange = Array(autocorr[minLag..<maxLag])
        vDSP_maxvi(searchRange, 1, &maxVal, &maxIdx, vDSP_Length(searchRange.count))

        let lag = Int(maxIdx) + minLag

        // Validate that we found a strong peak
        let threshold = autocorr[0] * 0.3
        guard maxVal > threshold && lag > 0 else { return 0 }

        return sampleRate / Float(lag)
    }

    // MARK: - Energy Features

    private func calculateRMSEnergy(samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    private func calculatePeakAmplitude(samples: [Float]) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        return peak
    }

    private func calculateLoudnessDBFS(rms: Float) -> Float {
        let epsilon: Float = 1e-10
        return 20 * log10(max(rms, epsilon))
    }

    private func calculateZeroCrossingRate(samples: [Float], sampleRate: Float) -> Float {
        var crossings: Int = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i - 1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count) * sampleRate
    }

    // MARK: - Spectral Features

    private func calculateSpectralCentroid(freqResolution: Float) -> Float {
        var weightedSum: Float = 0
        var totalMag: Float = 0

        for i in 0..<magnitudes.count {
            let freq = Float(i) * freqResolution
            weightedSum += freq * magnitudes[i]
            totalMag += magnitudes[i]
        }

        return totalMag > 0 ? weightedSum / totalMag : 0
    }

    private func calculateSpectralFlatness() -> Float {
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

        return arithmeticMean > epsilon ? geometricMean / arithmeticMean : 0
    }

    private func calculateSpectralRolloff(freqResolution: Float, percentile: Float = 0.85) -> Float {
        var totalEnergy: Float = 0
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))

        let threshold = totalEnergy * percentile
        var cumulative: Float = 0

        for i in 0..<magnitudes.count {
            cumulative += magnitudes[i]
            if cumulative >= threshold {
                return Float(i) * freqResolution
            }
        }

        return Float(magnitudes.count) * freqResolution
    }

    private func calculateSpectralBandwidth(centroid: Float, freqResolution: Float) -> Float {
        var weightedVariance: Float = 0
        var totalMag: Float = 0

        for i in 0..<magnitudes.count {
            let freq = Float(i) * freqResolution
            weightedVariance += magnitudes[i] * pow(freq - centroid, 2)
            totalMag += magnitudes[i]
        }

        return totalMag > 0 ? sqrt(weightedVariance / totalMag) : 0
    }

    private func calculateSpectralFlux() -> Float {
        guard magnitudes.count == previousMagnitudes.count else { return 0 }

        var flux: Float = 0
        for i in 0..<magnitudes.count {
            let diff = magnitudes[i] - previousMagnitudes[i]
            if diff > 0 {
                flux += diff * diff
            }
        }

        return sqrt(flux) / Float(magnitudes.count)
    }

    private func calculateSpectralSlope(freqResolution: Float) -> Float {
        var sumX: Float = 0
        var sumY: Float = 0
        var sumXY: Float = 0
        var sumX2: Float = 0
        let n = Float(magnitudes.count)
        let epsilon: Float = 1e-10

        for i in 0..<magnitudes.count {
            let x = Float(i) * freqResolution
            let y = log(max(magnitudes[i], epsilon))
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > epsilon else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
    }

    private func calculateSpectralContrast() -> [Float] {
        let numBands = 6
        var contrasts = [Float](repeating: 0, count: numBands)
        let bandSize = magnitudes.count / numBands

        for band in 0..<numBands {
            let start = band * bandSize
            let end = min(start + bandSize, magnitudes.count)
            let bandMags = Array(magnitudes[start..<end]).sorted()

            if bandMags.count >= 4 {
                let quarter = bandMags.count / 4
                let peakAvg = bandMags.suffix(quarter).reduce(0, +) / Float(quarter)
                let valleyAvg = bandMags.prefix(quarter).reduce(0, +) / Float(quarter)
                contrasts[band] = peakAvg - valleyAvg
            }
        }

        return contrasts
    }

    // MARK: - Harmonic Features

    private func calculateHNR(fundamentalFreq: Float, freqResolution: Float) -> Float {
        guard fundamentalFreq > 0 else { return 0 }

        var harmonicEnergy: Float = 0
        var totalEnergy: Float = 0

        // Sum energy at harmonic frequencies
        for harmonic in 1...5 {
            let harmonicFreq = fundamentalFreq * Float(harmonic)
            let binIndex = Int(harmonicFreq / freqResolution)

            // Sum energy in a small window around the harmonic
            let windowSize = 3
            for offset in -windowSize...windowSize {
                let idx = binIndex + offset
                if idx >= 0 && idx < magnitudes.count {
                    harmonicEnergy += magnitudes[idx] * magnitudes[idx]
                }
            }
        }

        vDSP_svesq(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))

        let noiseEnergy = max(totalEnergy - harmonicEnergy, 0.001)
        let hnr = 10 * log10(harmonicEnergy / noiseEnergy)

        // Normalize to 0-1 range (typical HNR range -10 to 30 dB)
        return min(max((hnr + 10) / 40, 0), 1)
    }

    private func extractHarmonics(fundamentalFreq: Float, freqResolution: Float) -> [Float] {
        var harmonics = [Float](repeating: 0, count: 5)
        guard fundamentalFreq > 0 else { return harmonics }

        for i in 0..<5 {
            let harmonicFreq = fundamentalFreq * Float(i + 1)
            let binIndex = Int(harmonicFreq / freqResolution)

            if binIndex < magnitudes.count {
                // Get max in small window around expected bin
                var maxMag: Float = 0
                for offset in -2...2 {
                    let idx = binIndex + offset
                    if idx >= 0 && idx < magnitudes.count {
                        maxMag = max(maxMag, magnitudes[idx])
                    }
                }
                harmonics[i] = maxMag
            }
        }

        // Normalize by fundamental
        let fundamental = max(harmonics[0], 0.001)
        for i in 0..<5 {
            harmonics[i] = min(harmonics[i] / fundamental, 1.0)
        }

        return harmonics
    }

    private func calculateHarmonicDeviations(fundamentalFreq: Float, freqResolution: Float) -> (Float, Float) {
        guard fundamentalFreq > 0 else { return (0, 0) }

        var deviationSum: Float = 0
        var inharmonicitySum: Float = 0
        var count: Float = 0

        for harmonic in 2...5 {
            let expectedFreq = fundamentalFreq * Float(harmonic)
            let expectedBin = Int(expectedFreq / freqResolution)

            // Find actual peak near expected
            var actualBin = expectedBin
            var maxMag: Float = 0
            for offset in -5...5 {
                let idx = expectedBin + offset
                if idx >= 0 && idx < magnitudes.count && magnitudes[idx] > maxMag {
                    maxMag = magnitudes[idx]
                    actualBin = idx
                }
            }

            let actualFreq = Float(actualBin) * freqResolution
            let deviation = abs(actualFreq - expectedFreq) / expectedFreq
            deviationSum += deviation
            inharmonicitySum += deviation * deviation
            count += 1
        }

        return (deviationSum / count, sqrt(inharmonicitySum / count))
    }

    // MARK: - Voice Quality Features

    private func calculateJitterShimmer(samples: [Float], sampleRate: Float) -> (Float, Float) {
        // Find pitch periods using zero crossings
        var pitchPeriods: [Int] = []
        var amplitudes: [Float] = []

        var lastZeroCrossing = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i - 1] >= 0) && samples[i] >= 0 {
                let period = i - lastZeroCrossing
                if period > Int(sampleRate / 700) && period < Int(sampleRate / 200) {
                    pitchPeriods.append(period)

                    // Find max amplitude in this period
                    var maxAmp: Float = 0
                    vDSP_maxmgv(Array(samples[lastZeroCrossing..<i]), 1, &maxAmp, vDSP_Length(i - lastZeroCrossing))
                    amplitudes.append(maxAmp)
                }
                lastZeroCrossing = i
            }
        }

        guard pitchPeriods.count >= 3 else { return (0.02, 0.03) }

        // Calculate jitter (pitch perturbation)
        var jitterSum: Float = 0
        for i in 1..<pitchPeriods.count {
            jitterSum += abs(Float(pitchPeriods[i] - pitchPeriods[i-1]))
        }
        let avgPeriod = Float(pitchPeriods.reduce(0, +)) / Float(pitchPeriods.count)
        let jitter = jitterSum / (Float(pitchPeriods.count - 1) * avgPeriod)

        // Calculate shimmer (amplitude perturbation)
        var shimmerSum: Float = 0
        for i in 1..<amplitudes.count {
            shimmerSum += abs(amplitudes[i] - amplitudes[i-1])
        }
        let avgAmp = amplitudes.reduce(0, +) / Float(amplitudes.count)
        let shimmer = shimmerSum / (Float(amplitudes.count - 1) * avgAmp)

        return (min(jitter, 0.2), min(shimmer, 0.3))
    }

    private func calculateTemporalModulation(samples: [Float], sampleRate: Float) -> Float {
        // Extract amplitude envelope
        var envelope = samples.map { abs($0) }

        // Low-pass filter envelope
        let filterSize = 20
        for _ in 0..<3 {
            var smoothed = envelope
            for i in filterSize..<(envelope.count - filterSize) {
                var sum: Float = 0
                for j in (i - filterSize)...(i + filterSize) {
                    sum += envelope[j]
                }
                smoothed[i] = sum / Float(2 * filterSize + 1)
            }
            envelope = smoothed
        }

        // Count peaks to estimate modulation rate
        var peakCount = 0
        for i in 1..<(envelope.count - 1) {
            if envelope[i] > envelope[i - 1] && envelope[i] > envelope[i + 1] {
                if envelope[i] > 0.1 * envelope.max()! {
                    peakCount += 1
                }
            }
        }

        // Convert to Hz
        let duration = Float(samples.count) / sampleRate
        return Float(peakCount) / duration
    }

    // MARK: - Formant Estimation

    private func estimateFormants(sampleRate: Float) -> (f1: Float, f2: Float, f3: Float, bandwidths: [Float]) {
        let freqResolution = sampleRate / Float(fftSize)

        // Smooth spectrum for formant detection
        let smoothedMags = smoothSpectrum(magnitudes, windowSize: 5)

        // Find peaks in typical formant ranges
        var peaks: [(freq: Float, mag: Float)] = []

        for i in 2..<(smoothedMags.count - 2) {
            let freq = Float(i) * freqResolution

            // Only look in speech/cry formant range (200-4000 Hz)
            guard freq > 200 && freq < 4000 else { continue }

            // Check if this is a local maximum
            if smoothedMags[i] > smoothedMags[i-1] &&
               smoothedMags[i] > smoothedMags[i+1] &&
               smoothedMags[i] > smoothedMags[i-2] &&
               smoothedMags[i] > smoothedMags[i+2] {
                peaks.append((freq, smoothedMags[i]))
            }
        }

        // Sort by magnitude and take top peaks
        peaks.sort { $0.mag > $1.mag }

        // Assign formants based on frequency order
        let sortedByFreq = peaks.prefix(6).sorted { $0.freq < $1.freq }

        let f1 = sortedByFreq.count > 0 ? sortedByFreq[0].freq : 500
        let f2 = sortedByFreq.count > 1 ? sortedByFreq[1].freq : 1500
        let f3 = sortedByFreq.count > 2 ? sortedByFreq[2].freq : 2500

        // Estimate bandwidths (simplified)
        let bandwidths: [Float] = [f1 * 0.15, f2 * 0.1, f3 * 0.08]

        return (f1, f2, f3, bandwidths)
    }

    private func smoothSpectrum(_ spectrum: [Float], windowSize: Int) -> [Float] {
        var smoothed = spectrum
        for i in windowSize..<(spectrum.count - windowSize) {
            var sum: Float = 0
            for j in (i - windowSize)...(i + windowSize) {
                sum += spectrum[j]
            }
            smoothed[i] = sum / Float(2 * windowSize + 1)
        }
        return smoothed
    }

    // MARK: - MFCC Calculation

    private func calculateMFCCs() -> [Double] {
        // Apply mel filterbank to magnitudes
        var melEnergies = [Float](repeating: 0, count: numMelFilters)

        for i in 0..<numMelFilters {
            var energy: Float = 0
            for j in 0..<min(magnitudes.count, melFilterbank[i].count) {
                energy += magnitudes[j] * melFilterbank[i][j]
            }
            melEnergies[i] = log(max(energy, 1e-10))
        }

        // Apply DCT to get MFCCs
        var mfccs = [Double](repeating: 0, count: numMFCCs)
        for i in 0..<numMFCCs {
            for j in 0..<numMelFilters {
                mfccs[i] += Double(melEnergies[j]) *
                    cos(Double.pi * Double(i) * (Double(j) + 0.5) / Double(numMelFilters))
            }
        }

        return mfccs
    }

    private func calculateDeltaCoefficients(mfccs: [Double]) -> ([Double], [Double]) {
        guard !previousMFCCs.isEmpty && previousMFCCs.count == mfccs.count else {
            return (mfccs, mfccs)
        }

        // Delta (velocity)
        var deltas = [Double](repeating: 0, count: mfccs.count)
        for i in 0..<mfccs.count {
            deltas[i] = mfccs[i] - previousMFCCs[i]
        }

        // Delta-delta (acceleration)
        var deltaDeltas = [Double](repeating: 0, count: mfccs.count)
        if !previousDeltaMFCCs.isEmpty && previousDeltaMFCCs.count == mfccs.count {
            for i in 0..<mfccs.count {
                deltaDeltas[i] = deltas[i] - previousDeltaMFCCs[i]
            }
        }

        return (deltas, deltaDeltas)
    }

    // MARK: - Chroma Features

    private func calculateChromaFeatures(sampleRate: Float) -> [Float] {
        var chroma = [Float](repeating: 0, count: 12)
        let freqResolution = sampleRate / Float(fftSize)

        for i in 1..<magnitudes.count {
            let freq = Float(i) * freqResolution
            guard freq > 20 else { continue }

            // Convert frequency to MIDI note number
            let midiNote = 12 * log2(freq / 440) + 69

            // Map to chroma bin (0-11)
            let chromaBin = Int(midiNote.truncatingRemainder(dividingBy: 12))
            if chromaBin >= 0 && chromaBin < 12 {
                chroma[chromaBin] += magnitudes[i] * magnitudes[i]
            }
        }

        // Normalize
        var maxChroma: Float = 0
        vDSP_maxv(chroma, 1, &maxChroma, vDSP_Length(12))
        if maxChroma > 0 {
            var scale: Float = 1.0 / maxChroma
            vDSP_vsmul(chroma, 1, &scale, &chroma, 1, vDSP_Length(12))
        }

        return chroma
    }

    // MARK: - Temporal Features

    private func calculateRhythmicity() -> Double {
        guard pitchHistory.count >= 5 else { return 0.5 }

        // Calculate autocorrelation of pitch history
        let pitchArray = pitchHistory.map { Double($0) }
        let mean = pitchArray.reduce(0, +) / Double(pitchArray.count)

        var autocorr: Double = 0
        var variance: Double = 0

        for i in 0..<pitchArray.count {
            variance += (pitchArray[i] - mean) * (pitchArray[i] - mean)
            if i < pitchArray.count - 2 {
                autocorr += (pitchArray[i] - mean) * (pitchArray[i + 2] - mean)
            }
        }

        guard variance > 0 else { return 0.5 }
        return min(max((autocorr / variance + 1) / 2, 0), 1)
    }

    private func calculatePitchVariability() -> Double {
        guard pitchHistory.count >= 3 else { return 0.3 }

        let pitchArray = pitchHistory.map { Double($0) }
        let mean = pitchArray.reduce(0, +) / Double(pitchArray.count)
        let variance = pitchArray.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(pitchArray.count)
        let stdDev = sqrt(variance)

        // Normalize: 50Hz stddev = 0.5 variability
        return min(stdDev / 100, 1.0)
    }

    private func calculateOnsetSharpness(samples: [Float]) -> Float {
        guard !previousSamples.isEmpty else { return 0.5 }

        var currentRMS: Float = 0
        vDSP_rmsqv(samples, 1, &currentRMS, vDSP_Length(min(samples.count, 1024)))

        var previousRMS: Float = 0
        vDSP_rmsqv(previousSamples, 1, &previousRMS, vDSP_Length(previousSamples.count))

        guard previousRMS > 0.001 else { return 0.5 }

        let ratio = currentRMS / previousRMS
        // Sharp onset = ratio > 2
        return min(max(ratio - 1, 0) / 3, 1.0)
    }

    // MARK: - Mel Filterbank Creation

    private static func createMelFilterbank(sampleRate: Float, fftSize: Int, numFilters: Int) -> [[Float]] {
        func hzToMel(_ hz: Float) -> Float {
            return 2595 * log10(1 + hz / 700)
        }

        func melToHz(_ mel: Float) -> Float {
            return 700 * (pow(10, mel / 2595) - 1)
        }

        let fMin: Float = 0
        let fMax = sampleRate / 2

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        // Create mel points
        var melPoints = [Float]()
        for i in 0...(numFilters + 1) {
            let mel = melMin + Float(i) * (melMax - melMin) / Float(numFilters + 1)
            melPoints.append(melToHz(mel))
        }

        // Convert to bin indices
        let binPoints = melPoints.map { Int($0 * Float(fftSize) / sampleRate) }

        // Create triangular filters
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftSize / 2), count: numFilters)

        for i in 0..<numFilters {
            let startBin = binPoints[i]
            let centerBin = binPoints[i + 1]
            let endBin = binPoints[i + 2]

            // Rising edge
            for j in startBin..<centerBin {
                if j < fftSize / 2 && centerBin > startBin {
                    filterbank[i][j] = Float(j - startBin) / Float(centerBin - startBin)
                }
            }

            // Falling edge
            for j in centerBin..<endBin {
                if j < fftSize / 2 && endBin > centerBin {
                    filterbank[i][j] = Float(endBin - j) / Float(endBin - centerBin)
                }
            }
        }

        return filterbank
    }
}
