//
//  MelSpectrogramGeneratorTests.swift
//  BabyInCarAppTests
//
//  Unit tests for MelSpectrogramGenerator - DeepInfant V2 audio preprocessing
//

import XCTest
@testable import BabyInCarApp

final class MelSpectrogramGeneratorTests: XCTestCase {

    var generator: MelSpectrogramGenerator!

    override func setUp() {
        super.setUp()
        generator = MelSpectrogramGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDeepInfantV2Constants() {
        // Verify constants match DeepInfant V2 specifications
        XCTAssertEqual(MelSpectrogramGenerator.numMelBands, 80, "Mel bands should be 80")
        XCTAssertEqual(MelSpectrogramGenerator.fftSize, 1024, "FFT size should be 1024")
        XCTAssertEqual(MelSpectrogramGenerator.hopLength, 256, "Hop length should be 256")
        XCTAssertEqual(MelSpectrogramGenerator.fMin, 20.0, "fMin should be 20Hz")
        XCTAssertEqual(MelSpectrogramGenerator.fMax, 8000.0, "fMax should be 8000Hz")
        XCTAssertEqual(MelSpectrogramGenerator.sampleRate, 16000.0, "Sample rate should be 16kHz")
        XCTAssertEqual(MelSpectrogramGenerator.requiredSamples, 112_000, "Required samples should be 112,000 (7 seconds)")
    }

    // MARK: - Output Shape Tests

    func testMelSpectrogramShape() {
        // Given: 7 seconds of silence (112,000 samples)
        let samples = [Float](repeating: 0, count: MelSpectrogramGenerator.requiredSamples)

        // When: Generate mel-spectrogram
        let spectrogram = generator.generate(from: samples)

        // Then: Shape should be (80, 431)
        XCTAssertEqual(spectrogram.count, MelSpectrogramGenerator.numMelBands, "Should have 80 mel bands")
        XCTAssertEqual(spectrogram.first?.count, MelSpectrogramGenerator.numTimeFrames, "Should have 431 time frames")
    }

    func testMelSpectrogramShapeWithShorterInput() {
        // Given: Only 2 seconds of audio (32,000 samples)
        let samples = [Float](repeating: 0.1, count: 32_000)

        // When: Generate mel-spectrogram (should pad to 7 seconds)
        let spectrogram = generator.generate(from: samples)

        // Then: Shape should still be (80, 431) due to padding
        XCTAssertEqual(spectrogram.count, MelSpectrogramGenerator.numMelBands)
        XCTAssertEqual(spectrogram.first?.count, MelSpectrogramGenerator.numTimeFrames)
    }

    func testMelSpectrogramShapeWithLongerInput() {
        // Given: 10 seconds of audio (160,000 samples)
        let samples = [Float](repeating: 0.1, count: 160_000)

        // When: Generate mel-spectrogram (should trim to 7 seconds)
        let spectrogram = generator.generate(from: samples)

        // Then: Shape should still be (80, 431) due to trimming
        XCTAssertEqual(spectrogram.count, MelSpectrogramGenerator.numMelBands)
        XCTAssertEqual(spectrogram.first?.count, MelSpectrogramGenerator.numTimeFrames)
    }

    // MARK: - Normalization Tests

    func testMelSpectrogramNormalization() {
        // Given: Audio with varying amplitudes
        var samples = [Float](repeating: 0, count: MelSpectrogramGenerator.requiredSamples)
        for i in 0..<samples.count {
            samples[i] = Float.random(in: -1...1)
        }

        // When: Generate mel-spectrogram
        let spectrogram = generator.generate(from: samples)

        // Then: All values should be in [0, 1]
        for band in spectrogram {
            for value in band {
                XCTAssertGreaterThanOrEqual(value, 0.0, "Value should be >= 0")
                XCTAssertLessThanOrEqual(value, 1.0, "Value should be <= 1")
            }
        }
    }

    func testSilenceProducesValidSpectrogram() {
        // Given: Pure silence
        let samples = [Float](repeating: 0, count: MelSpectrogramGenerator.requiredSamples)

        // When: Generate mel-spectrogram
        let spectrogram = generator.generate(from: samples)

        // Then: Should produce valid output (no NaN or Inf)
        for band in spectrogram {
            for value in band {
                XCTAssertFalse(value.isNaN, "Value should not be NaN")
                XCTAssertFalse(value.isInfinite, "Value should not be Infinite")
            }
        }
    }

    // MARK: - Signal Processing Tests

    func testSineWaveProducesEnergy() {
        // Given: 440Hz sine wave (A4 note)
        var samples = [Float](repeating: 0, count: MelSpectrogramGenerator.requiredSamples)
        let frequency: Float = 440.0
        for i in 0..<samples.count {
            samples[i] = sin(2 * .pi * frequency * Float(i) / Float(MelSpectrogramGenerator.sampleRate))
        }

        // When: Generate mel-spectrogram
        let spectrogram = generator.generate(from: samples)

        // Then: Should have non-zero energy in some bands
        var hasEnergy = false
        for band in spectrogram {
            for value in band {
                if value > 0.1 {  // Significant energy threshold
                    hasEnergy = true
                    break
                }
            }
            if hasEnergy { break }
        }

        XCTAssertTrue(hasEnergy, "440Hz tone should produce energy in mel-spectrogram")
    }

    // MARK: - Flat Array Tests

    func testGenerateFlatArray() {
        // Given: Test samples
        let samples = [Float](repeating: 0.1, count: MelSpectrogramGenerator.requiredSamples)

        // When: Generate flat array
        let flat = generator.generateFlat(from: samples)

        // Then: Should have correct size (80 * 431 = 34,480)
        let expectedSize = MelSpectrogramGenerator.numMelBands * MelSpectrogramGenerator.numTimeFrames
        XCTAssertEqual(flat.count, expectedSize, "Flat array should have \(expectedSize) elements")
    }

    // MARK: - Performance Tests

    func testMelSpectrogramGenerationPerformance() {
        let samples = [Float](repeating: 0.1, count: MelSpectrogramGenerator.requiredSamples)

        // Measure performance
        measure {
            _ = generator.generate(from: samples)
        }
    }

    // MARK: - Verification Helpers Tests

    #if DEBUG
    func testVerifyShapeHelper() {
        let spectrogram = MelSpectrogramGenerator.generateTestSpectrogram()
        XCTAssertTrue(MelSpectrogramGenerator.verifyShape(spectrogram), "Test spectrogram should have correct shape")
    }

    func testVerifyNormalizedHelper() {
        let spectrogram = MelSpectrogramGenerator.generateTestSpectrogram()
        XCTAssertTrue(MelSpectrogramGenerator.verifyNormalized(spectrogram), "Test spectrogram should be normalized")
    }
    #endif
}
