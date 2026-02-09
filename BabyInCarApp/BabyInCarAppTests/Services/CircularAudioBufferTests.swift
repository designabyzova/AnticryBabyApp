//
//  CircularAudioBufferTests.swift
//  BabyInCarAppTests
//
//  Unit tests for CircularAudioBuffer - memory-efficient audio capture
//

import XCTest
@testable import BabyInCarApp

final class CircularAudioBufferTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitializationWithDuration() {
        // Given/When
        let buffer = CircularAudioBuffer(durationSeconds: 7.0, sampleRate: 16000.0)

        // Then
        XCTAssertEqual(buffer.capacity, 112_000, "7 seconds at 16kHz should be 112,000 samples")
        XCTAssertFalse(buffer.isFull, "New buffer should not be full")
        XCTAssertEqual(buffer.validSampleCount, 0, "New buffer should have 0 valid samples")
    }

    func testInitializationWithCapacity() {
        // Given/When
        let buffer = CircularAudioBuffer(capacity: 10000)

        // Then
        XCTAssertEqual(buffer.capacity, 10000)
        XCTAssertFalse(buffer.isFull)
    }

    func testDeepInfantV2Factory() {
        // Given/When
        let buffer = CircularAudioBuffer.forDeepInfantV2()

        // Then
        XCTAssertEqual(buffer.capacity, 112_000, "DeepInfant V2 buffer should be 112,000 samples")
        XCTAssertEqual(buffer.durationSeconds, 7.0, accuracy: 0.01)
    }

    // MARK: - Append Tests

    func testAppendSingleSample() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 10)

        // When
        buffer.append(0.5)

        // Then
        XCTAssertEqual(buffer.validSampleCount, 1)
        XCTAssertFalse(buffer.isFull)
    }

    func testAppendArray() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 100)
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        // When
        buffer.append(samples)

        // Then
        XCTAssertEqual(buffer.validSampleCount, 5)
    }

    func testBufferBecomesFull() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 10)

        // When
        for i in 0..<10 {
            buffer.append(Float(i) / 10.0)
        }

        // Then
        XCTAssertTrue(buffer.isFull)
        XCTAssertEqual(buffer.fillRatio, 1.0, accuracy: 0.01)
    }

    func testCircularOverwrite() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 5)

        // When: Write 8 samples to 5-capacity buffer
        for i in 0..<8 {
            buffer.append(Float(i))
        }

        // Then: Should have overwritten first 3 samples
        let samples = buffer.getOrderedSamples()
        XCTAssertEqual(samples.count, 5)

        // Oldest sample should be 3.0, newest should be 7.0
        XCTAssertEqual(Double(samples.first ?? 0), 3.0, accuracy: 0.01, "Oldest sample should be 3")
        XCTAssertEqual(Double(samples.last ?? 0), 7.0, accuracy: 0.01, "Newest sample should be 7")
    }

    // MARK: - Order Tests

    func testGetOrderedSamplesOrder() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 5)

        // When: Append samples [1, 2, 3, 4, 5]
        buffer.append([1, 2, 3, 4, 5])

        // Then: Should be in same order
        let ordered = buffer.getOrderedSamples()
        XCTAssertEqual(ordered, [1, 2, 3, 4, 5])
    }

    func testGetOrderedSamplesAfterWrap() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 5)

        // When: Append 7 samples (wraps around)
        buffer.append([1, 2, 3, 4, 5, 6, 7])

        // Then: Should return [3, 4, 5, 6, 7] in chronological order
        let ordered = buffer.getOrderedSamples()
        XCTAssertEqual(ordered.count, 5)
        XCTAssertEqual(ordered[0], 3.0, accuracy: 0.01)
        XCTAssertEqual(ordered[1], 4.0, accuracy: 0.01)
        XCTAssertEqual(ordered[2], 5.0, accuracy: 0.01)
        XCTAssertEqual(ordered[3], 6.0, accuracy: 0.01)
        XCTAssertEqual(ordered[4], 7.0, accuracy: 0.01)
    }

    // MARK: - Analysis Tests

    func testCalculateRMS() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 4)
        buffer.append([0.5, -0.5, 0.5, -0.5])  // RMS = 0.5

        // When
        let rms = buffer.calculateRMS()

        // Then
        XCTAssertEqual(rms, 0.5, accuracy: 0.01)
    }

    func testCalculatePeak() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 5)
        buffer.append([0.1, 0.3, -0.8, 0.5, 0.2])

        // When
        let peak = buffer.calculatePeak()

        // Then
        XCTAssertEqual(peak, 0.8, accuracy: 0.01)
    }

    func testHasSignificantAudio() {
        // Given: Buffer with silence
        let silentBuffer = CircularAudioBuffer(capacity: 100)
        silentBuffer.append([Float](repeating: 0, count: 100))

        // Given: Buffer with audio
        let audioBuffer = CircularAudioBuffer(capacity: 100)
        var audio = [Float](repeating: 0.1, count: 100)
        for i in 0..<100 {
            audio[i] = sin(Float(i) * 0.1) * 0.5
        }
        audioBuffer.append(audio)

        // Then
        XCTAssertFalse(silentBuffer.hasSignificantAudio(), "Silence should not have significant audio")
        XCTAssertTrue(audioBuffer.hasSignificantAudio(), "Audio should have significant audio")
    }

    // MARK: - Reset Tests

    func testReset() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 10)
        buffer.append([1, 2, 3, 4, 5])

        // When
        buffer.reset()

        // Then
        XCTAssertEqual(buffer.validSampleCount, 0)
        XCTAssertFalse(buffer.isFull)

        // All samples should be zero
        let samples = buffer.getOrderedSamples()
        for sample in samples {
            XCTAssertEqual(sample, 0, accuracy: 0.001)
        }
    }

    func testClear() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 10)
        buffer.append([1, 2, 3, 4, 5])

        // When
        buffer.clear()

        // Then: Samples zeroed but position maintained
        let samples = buffer.getOrderedSamples()
        for sample in samples {
            XCTAssertEqual(sample, 0, accuracy: 0.001)
        }
    }

    // MARK: - Memory Tests

    func testMemoryFootprint() {
        // Given
        let buffer = CircularAudioBuffer.forDeepInfantV2()

        // When
        let footprint = buffer.memoryFootprint

        // Then: 112,000 * 4 bytes = 448,000 bytes (~437 KB)
        XCTAssertEqual(footprint, 448_000, "Memory footprint should be 448KB")
    }

    func testMemoryFootprintDescription() {
        // Given
        let buffer = CircularAudioBuffer.forDeepInfantV2()

        // When
        let description = buffer.memoryFootprintDescription

        // Then
        XCTAssertTrue(description.contains("KB") || description.contains("MB"),
                      "Description should show KB or MB")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAppendAndRead() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 1000)
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 2

        // When: Concurrent writes and reads
        DispatchQueue.global().async {
            for i in 0..<500 {
                buffer.append(Float(i) / 500.0)
            }
            expectation.fulfill()
        }

        DispatchQueue.global().async {
            for _ in 0..<100 {
                _ = buffer.getOrderedSamples()
                _ = buffer.calculateRMS()
            }
            expectation.fulfill()
        }

        // Then: Should complete without crash
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(buffer.validSampleCount, 0)
    }

    // MARK: - Performance Tests

    func testAppendPerformance() {
        let buffer = CircularAudioBuffer.forDeepInfantV2()
        let samples = [Float](repeating: 0.5, count: 4096)

        measure {
            // Simulate filling buffer multiple times (like real-time audio)
            for _ in 0..<28 {  // ~28 chunks to fill 7 seconds
                buffer.append(samples)
            }
        }
    }

    func testGetOrderedSamplesPerformance() {
        let buffer = CircularAudioBuffer.forDeepInfantV2()
        buffer.fillWithTestSignal()

        measure {
            _ = buffer.getOrderedSamples()
        }
    }

    // MARK: - Debug Helpers Tests

    #if DEBUG
    func testFillWithTestSignal() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 1000)

        // When
        buffer.fillWithTestSignal(frequency: 440)

        // Then
        XCTAssertTrue(buffer.isFull)
        XCTAssertGreaterThan(buffer.calculateRMS(), 0)
    }

    func testFillWithSilence() {
        // Given
        let buffer = CircularAudioBuffer(capacity: 1000)

        // When
        buffer.fillWithSilence()

        // Then
        XCTAssertTrue(buffer.isFull)
        XCTAssertEqual(buffer.calculateRMS(), 0, accuracy: 0.001)
    }
    #endif
}
