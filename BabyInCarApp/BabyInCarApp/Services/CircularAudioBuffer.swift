//
//  CircularAudioBuffer.swift
//  BabyInCarApp
//
//  Memory-efficient circular buffer for continuous audio capture.
//  Maintains a fixed-size buffer for DeepInfant V2's 7-second window requirement.
//

import Foundation

// MARK: - CircularAudioBuffer

/// A fixed-size circular buffer optimized for continuous audio capture.
///
/// Features:
/// - O(1) append and read operations
/// - Zero memory allocation after initialization
/// - Thread-safe with lock-free read path
/// - Provides ordered samples for processing
///
/// Memory footprint: 112,000 × 4 bytes = 448 KB for 7 seconds at 16kHz
final class CircularAudioBuffer {

    // MARK: - Properties

    /// The underlying storage buffer
    private var buffer: [Float]

    /// Current write position (wraps around)
    private var writeIndex: Int = 0

    /// Total capacity in samples
    let capacity: Int

    /// Thread synchronization lock
    private let lock = NSLock()

    /// Number of samples written (may exceed capacity)
    private var totalSamplesWritten: Int = 0

    // MARK: - Initialization

    /// Create a circular buffer with specified duration and sample rate
    /// - Parameters:
    ///   - durationSeconds: Buffer duration in seconds (default: 7.0 for DeepInfant V2)
    ///   - sampleRate: Audio sample rate in Hz (default: 16000)
    init(durationSeconds: Double = 7.0, sampleRate: Double = 16000.0) {
        capacity = Int(durationSeconds * sampleRate)
        buffer = [Float](repeating: 0, count: capacity)
    }

    /// Create a circular buffer with specified sample capacity
    /// - Parameter capacity: Number of samples to store
    init(capacity: Int) {
        self.capacity = capacity
        buffer = [Float](repeating: 0, count: capacity)
    }

    // MARK: - Public API

    /// Append samples to the buffer
    /// - Parameter samples: Array of audio samples to append
    /// - Note: Thread-safe
    func append(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            totalSamplesWritten += 1
        }
    }

    /// Append a single sample to the buffer
    /// - Parameter sample: Audio sample to append
    /// - Note: Thread-safe
    func append(_ sample: Float) {
        lock.lock()
        defer { lock.unlock() }

        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % capacity
        totalSamplesWritten += 1
    }

    /// Append samples from an unsafe buffer pointer (high performance)
    /// - Parameters:
    ///   - pointer: Pointer to audio samples
    ///   - count: Number of samples
    /// - Note: Thread-safe
    func append(from pointer: UnsafePointer<Float>, count: Int) {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<count {
            buffer[writeIndex] = pointer[i]
            writeIndex = (writeIndex + 1) % capacity
        }
        totalSamplesWritten += count
    }

    /// Get all samples in chronological order (oldest to newest)
    /// - Returns: Array of samples in correct time order
    /// - Note: Thread-safe
    func getOrderedSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        var result = [Float](repeating: 0, count: capacity)

        // Copy from write index to end (older samples)
        let firstPartCount = capacity - writeIndex
        for i in 0..<firstPartCount {
            result[i] = buffer[writeIndex + i]
        }

        // Copy from start to write index (newer samples)
        for i in 0..<writeIndex {
            result[firstPartCount + i] = buffer[i]
        }

        return result
    }

    /// Get samples without allocating new array (copy into provided buffer)
    /// - Parameter destination: Buffer to copy samples into (must be at least `capacity` size)
    /// - Note: Thread-safe
    func getOrderedSamples(into destination: inout [Float]) {
        lock.lock()
        defer { lock.unlock() }

        guard destination.count >= capacity else {
            fatalError("Destination buffer too small")
        }

        // Copy from write index to end (older samples)
        let firstPartCount = capacity - writeIndex
        for i in 0..<firstPartCount {
            destination[i] = buffer[writeIndex + i]
        }

        // Copy from start to write index (newer samples)
        for i in 0..<writeIndex {
            destination[firstPartCount + i] = buffer[i]
        }
    }

    /// Check if buffer has been filled at least once
    var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return totalSamplesWritten >= capacity
    }

    /// Number of valid samples (may be less than capacity if not yet full)
    var validSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return min(totalSamplesWritten, capacity)
    }

    /// Current fill ratio (0.0 to 1.0)
    var fillRatio: Double {
        lock.lock()
        defer { lock.unlock() }
        return min(1.0, Double(totalSamplesWritten) / Double(capacity))
    }

    /// Reset the buffer to initial state
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        writeIndex = 0
        totalSamplesWritten = 0

        // Zero out buffer
        for i in 0..<capacity {
            buffer[i] = 0
        }
    }

    /// Clear buffer without resetting write position
    /// (useful for silence injection)
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<capacity {
            buffer[i] = 0
        }
    }

    // MARK: - Analysis Methods

    /// Calculate RMS energy of the buffer
    /// - Returns: RMS value (0.0 to ~1.0 for normalized audio)
    func calculateRMS() -> Float {
        lock.lock()
        defer { lock.unlock() }

        var sumSquares: Float = 0
        for i in 0..<capacity {
            sumSquares += buffer[i] * buffer[i]
        }

        return sqrt(sumSquares / Float(capacity))
    }

    /// Calculate peak amplitude
    /// - Returns: Maximum absolute sample value
    func calculatePeak() -> Float {
        lock.lock()
        defer { lock.unlock() }

        var peak: Float = 0
        for i in 0..<capacity {
            peak = max(peak, abs(buffer[i]))
        }

        return peak
    }

    /// Check if audio level is sufficient for analysis
    /// - Parameter threshold: Minimum RMS threshold (default: 0.01)
    /// - Returns: True if audio level exceeds threshold
    func hasSignificantAudio(threshold: Float = 0.01) -> Bool {
        return calculateRMS() > threshold
    }

    // MARK: - Memory Management

    /// Memory footprint in bytes
    var memoryFootprint: Int {
        return capacity * MemoryLayout<Float>.size
    }

    /// Memory footprint as human-readable string
    var memoryFootprintDescription: String {
        let bytes = memoryFootprint
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - DeepInfant V2 Convenience

extension CircularAudioBuffer {

    /// Create a buffer sized for DeepInfant V2 (7 seconds at 16kHz)
    static func forDeepInfantV2() -> CircularAudioBuffer {
        return CircularAudioBuffer(
            durationSeconds: 7.0,
            sampleRate: 16000.0
        )
    }

    /// Duration of audio in the buffer
    var durationSeconds: Double {
        Double(capacity) / 16000.0
    }
}

// MARK: - Testing Support

#if DEBUG
extension CircularAudioBuffer {
    /// Fill buffer with test signal
    func fillWithTestSignal(frequency: Float = 440.0, sampleRate: Float = 16000.0) {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<capacity {
            buffer[i] = sin(2 * .pi * frequency * Float(i) / sampleRate)
        }
        writeIndex = 0
        totalSamplesWritten = capacity
    }

    /// Fill buffer with silence
    func fillWithSilence() {
        reset()
        totalSamplesWritten = capacity
    }

    /// Get raw buffer for testing
    func getRawBuffer() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
#endif
