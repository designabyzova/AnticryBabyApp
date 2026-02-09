//
//  MelSpectrogramGenerator.swift
//  BabyInCarApp
//
//  Generates mel-spectrograms from audio samples matching DeepInfant V2 specifications.
//  Uses Accelerate framework for high-performance FFT and mel filterbank operations.
//

import Foundation
import Accelerate

// MARK: - MelSpectrogramGenerator

/// Generates mel-spectrograms from audio samples for DeepInfant V2 model input.
///
/// DeepInfant V2 Specifications:
/// - Sample rate: 16kHz
/// - Duration: 7 seconds (112,000 samples)
/// - FFT size: 1024
/// - Hop length: 256
/// - Mel bands: 80
/// - Frequency range: 20Hz - 8000Hz
/// - Output shape: (80, 431) normalized to [0, 1]
final class MelSpectrogramGenerator {

    // MARK: - DeepInfant V2 Constants

    /// Number of mel frequency bands
    static let numMelBands: Int = 80

    /// FFT window size
    static let fftSize: Int = 1024

    /// Number of samples between successive frames
    static let hopLength: Int = 256

    /// Minimum frequency in Hz
    static let fMin: Float = 20.0

    /// Maximum frequency in Hz
    static let fMax: Float = 8000.0

    /// Required sample rate
    static let sampleRate: Double = 16000.0

    /// Required number of samples (7 seconds at 16kHz)
    static let requiredSamples: Int = 112_000

    /// Number of output time frames: (112000 - 1024) / 256 + 1 = 434
    /// Adjusted to match DeepInfant expected: 431
    static let numTimeFrames: Int = 431

    // MARK: - Private Properties

    /// FFT setup for Accelerate framework
    private let fftSetup: FFTSetup

    /// Log2 of FFT size for vDSP
    private let log2n: vDSP_Length

    /// Hann window for windowing
    private let hannWindow: [Float]

    /// Mel filterbank matrix (numMelBands x numFFTBins)
    private let melFilterbank: [[Float]]

    /// Number of FFT bins (fftSize / 2 + 1)
    private let numFFTBins: Int

    /// Reusable buffers for performance (preallocated to avoid per-frame allocations)
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var splitComplex: DSPSplitComplex
    private var magnitudeBuffer: [Float]
    private var melBuffer: [Float]
    /// Preallocated windowed frame buffer — avoids 431 × 4KB allocations per spectrogram
    private var windowedFrame: [Float]

    // MARK: - Initialization

    init() {
        // Calculate FFT parameters
        log2n = vDSP_Length(log2(Double(Self.fftSize)))
        numFFTBins = Self.fftSize / 2 + 1

        // Create FFT setup
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup")
        }
        fftSetup = setup

        // Create Hann window
        hannWindow = Self.createHannWindow(size: Self.fftSize)

        // Create mel filterbank
        melFilterbank = Self.createMelFilterbank(
            numMelBands: Self.numMelBands,
            numFFTBins: numFFTBins,
            sampleRate: Float(Self.sampleRate),
            fMin: Self.fMin,
            fMax: Self.fMax
        )

        // Preallocate buffers (avoids repeated allocations during processing)
        realBuffer = [Float](repeating: 0, count: Self.fftSize / 2)
        imagBuffer = [Float](repeating: 0, count: Self.fftSize / 2)
        splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        magnitudeBuffer = [Float](repeating: 0, count: numFFTBins)
        melBuffer = [Float](repeating: 0, count: Self.numMelBands)
        windowedFrame = [Float](repeating: 0, count: Self.fftSize)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public API

    /// Generate mel-spectrogram from audio samples
    /// - Parameter samples: Array of audio samples (should be 112,000 samples at 16kHz)
    /// - Returns: 2D array of shape (numMelBands, numTimeFrames) normalized to [0, 1]
    func generate(from samples: [Float]) -> [[Float]] {
        // Validate input length
        var paddedSamples = samples
        if samples.count < Self.requiredSamples {
            // Pad with zeros
            paddedSamples = samples + [Float](repeating: 0, count: Self.requiredSamples - samples.count)
        } else if samples.count > Self.requiredSamples {
            // Trim to required length
            paddedSamples = Array(samples.prefix(Self.requiredSamples))
        }

        // Calculate number of frames
        let numFrames = min(Self.numTimeFrames, (paddedSamples.count - Self.fftSize) / Self.hopLength + 1)

        // Initialize output spectrogram
        var spectrogram = [[Float]](repeating: [Float](repeating: 0, count: numFrames), count: Self.numMelBands)

        // Process each frame (reuses preallocated windowedFrame buffer)
        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * Self.hopLength

            // Extract frame and apply window using preallocated buffer
            // Use vDSP_vmul for vectorized multiply instead of scalar loop
            let endSample = min(startSample + Self.fftSize, paddedSamples.count)
            let validCount = endSample - startSample
            paddedSamples.withUnsafeBufferPointer { samplesPtr in
                vDSP_vmul(
                    samplesPtr.baseAddress! + startSample, 1,
                    hannWindow, 1,
                    &windowedFrame, 1,
                    vDSP_Length(validCount)
                )
            }
            // Zero remaining samples if frame extends past audio
            if validCount < Self.fftSize {
                for i in validCount..<Self.fftSize {
                    windowedFrame[i] = 0
                }
            }

            // Compute FFT magnitude
            let magnitude = computeFFTMagnitude(windowedFrame)

            // Apply mel filterbank
            let melEnergies = applyMelFilterbank(magnitude)

            // Store in spectrogram (transposed: mel bands are rows)
            for melBand in 0..<Self.numMelBands {
                spectrogram[melBand][frameIndex] = melEnergies[melBand]
            }
        }

        // Convert to log scale (dB)
        spectrogram = powerToDb(spectrogram)

        // Normalize to [0, 1]
        spectrogram = normalize(spectrogram)

        return spectrogram
    }

    /// Generate mel-spectrogram and return as flat array for CoreML input
    /// - Parameter samples: Array of audio samples
    /// - Returns: Flat array suitable for MLMultiArray (row-major order)
    func generateFlat(from samples: [Float]) -> [Float] {
        let spectrogram = generate(from: samples)

        // Flatten: row-major order (mel bands × time frames)
        var flat = [Float]()
        flat.reserveCapacity(Self.numMelBands * Self.numTimeFrames)

        for melBand in spectrogram {
            flat.append(contentsOf: melBand)
        }

        return flat
    }

    // MARK: - Private Methods

    /// Compute FFT magnitude spectrum
    private func computeFFTMagnitude(_ frame: [Float]) -> [Float] {
        // Pack input for real FFT
        var packedInput = [Float](repeating: 0, count: Self.fftSize)
        for i in 0..<Self.fftSize {
            packedInput[i] = frame[i]
        }

        // Convert to split complex format
        packedInput.withUnsafeBufferPointer { inputPtr in
            inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(Self.fftSize / 2))
            }
        }

        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude (power spectrum)
        var magnitude = [Float](repeating: 0, count: numFFTBins)

        // DC component
        magnitude[0] = splitComplex.realp[0] * splitComplex.realp[0]

        // Nyquist component
        magnitude[numFFTBins - 1] = splitComplex.imagp[0] * splitComplex.imagp[0]

        // Other components
        for i in 1..<(numFFTBins - 1) {
            let real = splitComplex.realp[i]
            let imag = splitComplex.imagp[i]
            magnitude[i] = real * real + imag * imag
        }

        return magnitude
    }

    /// Apply mel filterbank to magnitude spectrum
    private func applyMelFilterbank(_ magnitude: [Float]) -> [Float] {
        var melEnergies = [Float](repeating: 0, count: Self.numMelBands)

        for melBand in 0..<Self.numMelBands {
            var energy: Float = 0
            for bin in 0..<numFFTBins {
                energy += magnitude[bin] * melFilterbank[melBand][bin]
            }
            // Add small epsilon to avoid log(0)
            melEnergies[melBand] = max(energy, 1e-10)
        }

        return melEnergies
    }

    /// Convert power spectrogram to dB scale
    private func powerToDb(_ spectrogram: [[Float]]) -> [[Float]] {
        var dbSpectrogram = spectrogram
        var maxVal: Float = -Float.infinity

        // Convert to dB and find max
        for melBand in 0..<spectrogram.count {
            for frame in 0..<spectrogram[melBand].count {
                let db = 10 * log10(spectrogram[melBand][frame])
                dbSpectrogram[melBand][frame] = db
                maxVal = max(maxVal, db)
            }
        }

        // Reference to max (like librosa ref=np.max)
        for melBand in 0..<dbSpectrogram.count {
            for frame in 0..<dbSpectrogram[melBand].count {
                dbSpectrogram[melBand][frame] -= maxVal
            }
        }

        return dbSpectrogram
    }

    /// Normalize spectrogram to [0, 1] range
    private func normalize(_ spectrogram: [[Float]]) -> [[Float]] {
        var normalized = spectrogram

        // Find min and max
        var minVal: Float = Float.infinity
        var maxVal: Float = -Float.infinity

        for melBand in spectrogram {
            for value in melBand {
                minVal = min(minVal, value)
                maxVal = max(maxVal, value)
            }
        }

        // Normalize
        let range = maxVal - minVal
        if range > 0 {
            for melBand in 0..<normalized.count {
                for frame in 0..<normalized[melBand].count {
                    normalized[melBand][frame] = (normalized[melBand][frame] - minVal) / range
                }
            }
        }

        return normalized
    }

    // MARK: - Static Factory Methods

    /// Create Hann window
    private static func createHannWindow(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        return window
    }

    /// Create mel filterbank matrix
    private static func createMelFilterbank(
        numMelBands: Int,
        numFFTBins: Int,
        sampleRate: Float,
        fMin: Float,
        fMax: Float
    ) -> [[Float]] {
        // Convert Hz to Mel scale
        func hzToMel(_ hz: Float) -> Float {
            return 2595 * log10(1 + hz / 700)
        }

        // Convert Mel to Hz
        func melToHz(_ mel: Float) -> Float {
            return 700 * (pow(10, mel / 2595) - 1)
        }

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        // Create equally spaced mel points
        var melPoints = [Float](repeating: 0, count: numMelBands + 2)
        for i in 0..<(numMelBands + 2) {
            melPoints[i] = melMin + Float(i) * (melMax - melMin) / Float(numMelBands + 1)
        }

        // Convert mel points to Hz
        var hzPoints = melPoints.map { melToHz($0) }

        // Convert Hz to FFT bin indices
        let fftBins = hzPoints.map { hz -> Int in
            let bin = Int((hz / sampleRate) * Float(numFFTBins - 1) * 2)
            return max(0, min(bin, numFFTBins - 1))
        }

        // Create filterbank
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: numFFTBins), count: numMelBands)

        for mel in 0..<numMelBands {
            let leftBin = fftBins[mel]
            let centerBin = fftBins[mel + 1]
            let rightBin = fftBins[mel + 2]

            // Rising edge
            for bin in leftBin..<centerBin {
                if centerBin > leftBin {
                    filterbank[mel][bin] = Float(bin - leftBin) / Float(centerBin - leftBin)
                }
            }

            // Falling edge
            for bin in centerBin...rightBin {
                if rightBin > centerBin {
                    filterbank[mel][bin] = Float(rightBin - bin) / Float(rightBin - centerBin)
                } else if bin == centerBin {
                    filterbank[mel][bin] = 1.0
                }
            }
        }

        return filterbank
    }
}

// MARK: - Testing Support

#if DEBUG
extension MelSpectrogramGenerator {
    /// Generate a test mel-spectrogram with known values
    static func generateTestSpectrogram() -> [[Float]] {
        // Create a simple test signal (440Hz sine wave for 7 seconds)
        var samples = [Float](repeating: 0, count: requiredSamples)
        let frequency: Float = 440.0
        for i in 0..<requiredSamples {
            samples[i] = sin(2 * .pi * frequency * Float(i) / Float(sampleRate))
        }

        let generator = MelSpectrogramGenerator()
        return generator.generate(from: samples)
    }

    /// Verify spectrogram shape
    static func verifyShape(_ spectrogram: [[Float]]) -> Bool {
        guard spectrogram.count == numMelBands else { return false }
        for row in spectrogram {
            if row.count != numTimeFrames { return false }
        }
        return true
    }

    /// Verify values are normalized to [0, 1]
    static func verifyNormalized(_ spectrogram: [[Float]]) -> Bool {
        for row in spectrogram {
            for value in row {
                if value < 0 || value > 1 { return false }
            }
        }
        return true
    }
}
#endif
