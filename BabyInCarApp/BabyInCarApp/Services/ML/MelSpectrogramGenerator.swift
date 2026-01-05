//
//  MelSpectrogramGenerator.swift
//  BabyInCarApp
//
//  Generates mel spectrograms for DeepInfant ML model input
//  Uses Accelerate framework for efficient DSP operations
//

import Foundation
import Accelerate
import CoreML

/// Generates mel spectrograms compatible with DeepInfant V2 model
/// Input: Raw audio samples at 16kHz
/// Output: MLMultiArray suitable for CoreML inference
class MelSpectrogramGenerator {

    // MARK: - Configuration (matches DeepInfant V2)

    /// Target sample rate for DeepInfant
    static let targetSampleRate: Float = 16000

    /// FFT size for STFT
    private let nFFT: Int = 2048

    /// Hop length between frames
    private let hopLength: Int = 512

    /// Number of mel frequency bins
    private let nMels: Int = 128

    /// Minimum frequency for mel filterbank
    private let fMin: Float = 0

    /// Maximum frequency for mel filterbank
    private let fMax: Float = 8000  // Nyquist for 16kHz

    // MARK: - DSP Resources

    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var melFilterbank: [[Float]]

    // MARK: - Initialization

    init() {
        // Create FFT setup
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(nFFT), .FORWARD)

        // Create Hann window
        self.window = [Float](repeating: 0, count: nFFT)
        vDSP_hann_window(&window, vDSP_Length(nFFT), Int32(vDSP_HANN_NORM))

        // Create mel filterbank
        self.melFilterbank = Self.createMelFilterbank(
            sampleRate: Self.targetSampleRate,
            nFFT: nFFT,
            nMels: nMels,
            fMin: fMin,
            fMax: fMax
        )
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }

    // MARK: - Public API

    /// Generate mel spectrogram from audio samples
    /// - Parameters:
    ///   - samples: Audio samples (mono, should be resampled to 16kHz)
    ///   - sampleRate: Current sample rate of input audio
    /// - Returns: MLMultiArray shaped [1, nMels, nFrames] for CoreML
    func generate(from samples: [Float], sampleRate: Float) -> MLMultiArray? {
        // Resample if needed
        let resampledSamples: [Float]
        if abs(sampleRate - Self.targetSampleRate) > 100 {
            resampledSamples = resample(samples, from: sampleRate, to: Self.targetSampleRate)
        } else {
            resampledSamples = samples
        }

        // Calculate STFT
        let stftMagnitudes = computeSTFT(samples: resampledSamples)

        guard !stftMagnitudes.isEmpty else { return nil }

        // Apply mel filterbank
        let melSpec = applyMelFilterbank(stftMagnitudes)

        // Convert to log scale (dB)
        let logMelSpec = toLogScale(melSpec)

        // Normalize
        let normalized = normalize(logMelSpec)

        // Convert to MLMultiArray
        return toMLMultiArray(normalized)
    }

    /// Generate mel spectrogram with fixed time dimension for model input
    /// - Parameters:
    ///   - samples: Audio samples
    ///   - sampleRate: Sample rate
    ///   - targetFrames: Target number of time frames (pad/truncate)
    func generateFixed(from samples: [Float], sampleRate: Float, targetFrames: Int = 128) -> MLMultiArray? {
        guard let melSpec = generate(from: samples, sampleRate: sampleRate) else {
            return nil
        }

        // Resize to fixed time dimension if needed
        return resizeToFixed(melSpec, targetFrames: targetFrames)
    }

    // MARK: - STFT Computation

    private func computeSTFT(samples: [Float]) -> [[Float]] {
        guard let fftSetup = fftSetup else { return [] }
        guard samples.count >= nFFT else { return [] }

        let numFrames = (samples.count - nFFT) / hopLength + 1
        var stftResult: [[Float]] = []

        for frame in 0..<numFrames {
            let startIdx = frame * hopLength
            let endIdx = startIdx + nFFT

            guard endIdx <= samples.count else { break }

            // Extract frame and apply window
            var windowedFrame = [Float](repeating: 0, count: nFFT)
            let frameSlice = Array(samples[startIdx..<endIdx])
            vDSP_vmul(frameSlice, 1, window, 1, &windowedFrame, 1, vDSP_Length(nFFT))

            // Perform FFT
            var realInput = windowedFrame
            var imagInput = [Float](repeating: 0, count: nFFT)
            var realOutput = [Float](repeating: 0, count: nFFT)
            var imagOutput = [Float](repeating: 0, count: nFFT)

            vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

            // Calculate magnitudes (only positive frequencies)
            let specSize = nFFT / 2 + 1
            var magnitudes = [Float](repeating: 0, count: specSize)

            realOutput.withUnsafeMutableBufferPointer { realBuffer in
                imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                    var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                    vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(specSize))
                }
            }

            // Normalize
            var scale: Float = 2.0 / Float(nFFT)
            vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(specSize))

            stftResult.append(magnitudes)
        }

        return stftResult
    }

    // MARK: - Mel Filterbank Application

    private func applyMelFilterbank(_ stft: [[Float]]) -> [[Float]] {
        var melSpec: [[Float]] = []

        for frame in stft {
            var melFrame = [Float](repeating: 0, count: nMels)

            for (melIdx, filter) in melFilterbank.enumerated() {
                var energy: Float = 0
                let filterLen = min(filter.count, frame.count)
                vDSP_dotpr(frame, 1, filter, 1, &energy, vDSP_Length(filterLen))
                melFrame[melIdx] = energy
            }

            melSpec.append(melFrame)
        }

        return melSpec
    }

    // MARK: - Post-processing

    private func toLogScale(_ melSpec: [[Float]]) -> [[Float]] {
        let epsilon: Float = 1e-10

        return melSpec.map { frame in
            frame.map { value in
                10 * log10(max(value, epsilon))
            }
        }
    }

    private func normalize(_ melSpec: [[Float]]) -> [[Float]] {
        guard !melSpec.isEmpty else { return [] }

        // Find global min/max
        var globalMin: Float = Float.greatestFiniteMagnitude
        var globalMax: Float = -Float.greatestFiniteMagnitude

        for frame in melSpec {
            if let frameMin = frame.min(), let frameMax = frame.max() {
                globalMin = min(globalMin, frameMin)
                globalMax = max(globalMax, frameMax)
            }
        }

        let range = globalMax - globalMin
        guard range > 0 else { return melSpec }

        // Normalize to [0, 1]
        return melSpec.map { frame in
            frame.map { value in
                (value - globalMin) / range
            }
        }
    }

    // MARK: - MLMultiArray Conversion

    private func toMLMultiArray(_ melSpec: [[Float]]) -> MLMultiArray? {
        guard !melSpec.isEmpty, let firstFrame = melSpec.first else { return nil }

        let nFrames = melSpec.count
        let nMelBins = firstFrame.count

        do {
            // Shape: [1, nMels, nFrames] - batch, frequency, time
            let shape = [1, nMelBins, nFrames] as [NSNumber]
            let array = try MLMultiArray(shape: shape, dataType: .float32)

            for (frameIdx, frame) in melSpec.enumerated() {
                for (melIdx, value) in frame.enumerated() {
                    let index = [0, melIdx, frameIdx] as [NSNumber]
                    array[index] = NSNumber(value: value)
                }
            }

            return array
        } catch {
            print("MelSpectrogramGenerator: Failed to create MLMultiArray - \(error)")
            return nil
        }
    }

    private func resizeToFixed(_ array: MLMultiArray, targetFrames: Int) -> MLMultiArray? {
        guard array.shape.count == 3 else { return array }

        let currentFrames = array.shape[2].intValue
        let nMelBins = array.shape[1].intValue

        if currentFrames == targetFrames {
            return array
        }

        do {
            let newShape = [1, nMelBins, targetFrames] as [NSNumber]
            let newArray = try MLMultiArray(shape: newShape, dataType: .float32)

            for melIdx in 0..<nMelBins {
                for frameIdx in 0..<targetFrames {
                    let srcFrameIdx = frameIdx * currentFrames / targetFrames
                    let clampedSrc = min(srcFrameIdx, currentFrames - 1)

                    let srcIndex = [0, melIdx, clampedSrc] as [NSNumber]
                    let dstIndex = [0, melIdx, frameIdx] as [NSNumber]
                    newArray[dstIndex] = array[srcIndex]
                }
            }

            return newArray
        } catch {
            print("MelSpectrogramGenerator: Failed to resize - \(error)")
            return array
        }
    }

    // MARK: - Resampling

    private func resample(_ samples: [Float], from sourceSR: Float, to targetSR: Float) -> [Float] {
        let ratio = targetSR / sourceSR
        let outputLength = Int(Float(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)

        // Linear interpolation resampling
        for i in 0..<outputLength {
            let srcIndex = Float(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let frac = srcIndex - Float(srcIndexInt)

            if srcIndexInt + 1 < samples.count {
                output[i] = samples[srcIndexInt] * (1 - frac) + samples[srcIndexInt + 1] * frac
            } else if srcIndexInt < samples.count {
                output[i] = samples[srcIndexInt]
            }
        }

        return output
    }

    // MARK: - Mel Filterbank Creation

    private static func hzToMel(_ hz: Float) -> Float {
        return 2595 * log10(1 + hz / 700)
    }

    private static func melToHz(_ mel: Float) -> Float {
        return 700 * (pow(10, mel / 2595) - 1)
    }

    private static func createMelFilterbank(
        sampleRate: Float,
        nFFT: Int,
        nMels: Int,
        fMin: Float,
        fMax: Float
    ) -> [[Float]] {
        let specSize = nFFT / 2 + 1

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        // Create mel points
        var melPoints = [Float]()
        for i in 0...(nMels + 1) {
            let mel = melMin + Float(i) * (melMax - melMin) / Float(nMels + 1)
            melPoints.append(melToHz(mel))
        }

        // Convert to bin indices
        let binPoints = melPoints.map { hz -> Int in
            Int(hz * Float(nFFT) / sampleRate)
        }

        // Create triangular filters
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: specSize), count: nMels)

        for i in 0..<nMels {
            let startBin = binPoints[i]
            let centerBin = binPoints[i + 1]
            let endBin = binPoints[i + 2]

            // Rising edge
            if centerBin > startBin {
                for j in startBin..<centerBin {
                    if j < specSize {
                        filterbank[i][j] = Float(j - startBin) / Float(centerBin - startBin)
                    }
                }
            }

            // Falling edge
            if endBin > centerBin {
                for j in centerBin..<endBin {
                    if j < specSize {
                        filterbank[i][j] = Float(endBin - j) / Float(endBin - centerBin)
                    }
                }
            }
        }

        return filterbank
    }
}
