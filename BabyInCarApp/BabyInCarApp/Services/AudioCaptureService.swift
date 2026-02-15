//
//  AudioCaptureService.swift
//  BabyInCarApp
//
//  Audio capture pipeline for cry classification
//  Captures audio from microphone and provides samples for CryClassificationService
//
//  Increment 0031: Replaced manual ring buffer with CircularAudioBuffer for:
//  - Zero allocation after init (448 KB fixed footprint)
//  - Thread-safe O(1) append via NSLock
//  - 7-second window (112,000 samples) for better cry context
//

import Foundation
import AVFoundation
import Combine

// MARK: - AudioCaptureState

/// Current state of audio capture
enum AudioCaptureState: Equatable {
    case idle               // Not capturing
    case preparing          // Setting up audio session
    case capturing          // Actively capturing audio
    case paused             // Temporarily paused (e.g., interruption)
    case error(AudioCaptureError)

    static func == (lhs: AudioCaptureState, rhs: AudioCaptureState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.capturing, .capturing), (.paused, .paused):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - AudioCaptureError

enum AudioCaptureError: Error, LocalizedError {
    case microphonePermissionDenied
    case audioSessionSetupFailed(Error)
    case audioEngineSetupFailed(Error)
    case audioEngineStartFailed(Error)
    case invalidAudioFormat
    case captureInterrupted

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for cry detection"
        case .audioSessionSetupFailed(let error):
            return "Failed to setup audio session: \(error.localizedDescription)"
        case .audioEngineSetupFailed(let error):
            return "Failed to setup audio engine: \(error.localizedDescription)"
        case .audioEngineStartFailed(let error):
            return "Failed to start audio capture: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format for cry classification"
        case .captureInterrupted:
            return "Audio capture was interrupted"
        }
    }
}

// MARK: - AudioCaptureService

/// Service for capturing audio from microphone for cry classification
@MainActor
class AudioCaptureService: ObservableObject {

    // MARK: - Singleton

    static let shared = AudioCaptureService()

    // MARK: - Constants

    /// Required sample rate for DeepInfant V2 model (16kHz)
    static let targetSampleRate: Double = 16000.0

    /// Number of samples required per prediction (DeepInfant V2 expects 15,600)
    static let samplesPerPrediction = CryClassificationService.requiredSampleCount // 15600

    /// Interval between predictions in seconds
    static let predictionInterval: TimeInterval = 1.0

    /// Noise gate threshold in dB (for UI indicator only — does NOT block predictions)
    static let noiseGateThresholdDB: Float = -50.0

    // MARK: - Published State

    /// Current capture state
    @Published private(set) var state: AudioCaptureState = .idle

    /// Current audio level (0.0 - 1.0) for UI visualization
    @Published private(set) var currentLevel: Float = 0.0

    /// Whether audio is above noise gate threshold
    @Published private(set) var isAudioDetected: Bool = false

    /// Fill ratio of the circular buffer (0.0 - 1.0), for UI progress during warmup
    @Published private(set) var bufferFillRatio: Double = 0.0

    // MARK: - Callbacks

    /// Called when audio samples are ready for classification
    var onAudioSamplesReady: (([Float]) -> Void)?

    /// Called when audio level updates (for waveform visualization)
    var onAudioLevelUpdate: ((Float) -> Void)?

    // MARK: - Private Properties

    /// AVAudioEngine for capturing microphone input
    private var audioEngine: AVAudioEngine?

    /// Input node for microphone
    private var inputNode: AVAudioInputNode?

    /// Format converter for resampling
    private var formatConverter: AVAudioConverter?

    /// Circular buffer for continuous audio capture (7 seconds at 16kHz = 112,000 samples)
    /// Replaces the old Array-based ring buffer to eliminate per-append allocations.
    /// Memory footprint: 112,000 x 4 bytes = 448 KB (fixed, zero growth)
    private var circularBuffer: CircularAudioBuffer?

    /// Timer for periodic prediction callbacks
    private var predictionTimer: Timer?

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Reference to audio session manager
    private let audioSessionManager = AudioSessionManager.shared

    // MARK: - Initialization

    private init() {
        setupNotifications()
    }

    deinit {
        // Clean up audio resources synchronously without MainActor
        // Note: This is called on deallocation, timer and published state cleanup
        // happens naturally when the object is deallocated
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }

    // MARK: - Public API

    /// Start capturing audio from microphone
    func startCapture() async throws {
        guard state != .capturing else { return }

        state = .preparing

        // Check microphone permission
        let permissionGranted = await checkMicrophonePermission()
        guard permissionGranted else {
            state = .error(.microphonePermissionDenied)
            throw AudioCaptureError.microphonePermissionDenied
        }

        // Setup audio session for recording
        do {
            try setupAudioSession()
        } catch {
            state = .error(.audioSessionSetupFailed(error))
            throw AudioCaptureError.audioSessionSetupFailed(error)
        }

        // Initialize circular buffer (7 seconds at 16kHz for DeepInfant V2)
        circularBuffer = CircularAudioBuffer.forDeepInfantV2()
        print("[AudioCaptureService] CircularAudioBuffer initialized: \(circularBuffer?.memoryFootprintDescription ?? "?") for 7s window")

        // Setup audio engine
        do {
            try setupAudioEngine()
        } catch {
            state = .error(.audioEngineSetupFailed(error))
            throw AudioCaptureError.audioEngineSetupFailed(error)
        }

        // Start audio engine
        do {
            try audioEngine?.start()
            state = .capturing

            // Start prediction timer
            startPredictionTimer()

            print("[AudioCaptureService] Started capturing audio at \(Self.targetSampleRate)Hz")
        } catch {
            state = .error(.audioEngineStartFailed(error))
            throw AudioCaptureError.audioEngineStartFailed(error)
        }
    }

    /// Stop capturing audio
    func stopCapture() {
        predictionTimer?.invalidate()
        predictionTimer = nil

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        formatConverter = nil

        // Release circular buffer to free 448 KB
        circularBuffer = nil

        // CRITICAL: Clear Combine subscriptions to prevent memory leak
        cancellables.removeAll()

        // Clear callbacks to break potential retain cycles
        onAudioSamplesReady = nil
        onAudioLevelUpdate = nil

        state = .idle
        currentLevel = 0.0
        isAudioDetected = false
        bufferFillRatio = 0.0

        // Release audio session
        audioSessionManager.releaseSession(serviceId: "AudioCaptureService")

        print("[AudioCaptureService] Stopped capturing audio - memory cleaned up")
    }

    /// Pause capture temporarily (e.g., during interruption)
    func pauseCapture() {
        audioEngine?.pause()
        predictionTimer?.invalidate()
        state = .paused
        print("[AudioCaptureService] Paused capture")
    }

    /// Resume capture after pause
    func resumeCapture() throws {
        guard state == .paused else { return }

        try audioEngine?.start()
        startPredictionTimer()
        state = .capturing
        print("[AudioCaptureService] Resumed capture")
    }

    /// Get the most recent audio samples for classification from the circular buffer
    /// Returns the last `samplesPerPrediction` (15,600) samples from the 7-second window
    func getCurrentSamples() -> [Float]? {
        guard let buffer = circularBuffer else { return nil }

        // Need at least one prediction window of data
        guard buffer.validSampleCount >= Self.samplesPerPrediction else {
            return nil
        }

        // Get full ordered buffer and extract the most recent prediction window
        let ordered = buffer.getOrderedSamples()
        let validCount = buffer.validSampleCount
        let startIndex = validCount - Self.samplesPerPrediction
        return Array(ordered[startIndex..<validCount])
    }

    // MARK: - Private Methods

    /// Check microphone permission
    private func checkMicrophonePermission() async -> Bool {
        // Use iOS 17+ API if available, otherwise fallback to AVAudioSession
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        } else {
            // Fallback for iOS 16 and earlier
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
    }

    /// Setup audio session for recording
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Use playAndRecord category to allow simultaneous playback + recording
        // .defaultToSpeaker routes audio output to speaker (not earpiece)
        // NO .mixWithOthers - we want exclusive control
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(Self.targetSampleRate)
        try session.setActive(true)

        print("[AudioCaptureService] Audio session configured: playAndRecord @ \(session.sampleRate)Hz")
    }

    /// Setup AVAudioEngine for capture
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioCaptureError.audioEngineSetupFailed(NSError(domain: "AudioCaptureService", code: -1))
        }

        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw AudioCaptureError.audioEngineSetupFailed(NSError(domain: "AudioCaptureService", code: -2))
        }

        // Get input format
        let inputFormat = input.outputFormat(forBus: 0)
        print("[AudioCaptureService] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Create target format for model (16kHz mono Float32)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.invalidAudioFormat
        }

        // Create format converter if sample rates differ
        if inputFormat.sampleRate != Self.targetSampleRate {
            formatConverter = AVAudioConverter(from: inputFormat, to: targetFormat)
            print("[AudioCaptureService] Created format converter: \(inputFormat.sampleRate) -> \(targetFormat.sampleRate)")
        }

        // Calculate buffer size for tap (~100ms of audio)
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)

        // Install tap on input node
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, format: inputFormat, targetFormat: targetFormat)
        }

        // Prepare engine
        engine.prepare()
    }

    /// Process captured audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, targetFormat: AVAudioFormat) {
        // Convert to target format if needed
        let processedBuffer: AVAudioPCMBuffer
        if let converter = formatConverter {
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / format.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .error || error != nil {
                print("[AudioCaptureService] Conversion error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            processedBuffer = convertedBuffer
        } else {
            processedBuffer = buffer
        }

        // Extract Float samples
        guard let floatData = processedBuffer.floatChannelData else { return }
        let frameLength = Int(processedBuffer.frameLength)

        // Calculate RMS level for visualization (directly from pointer, no allocation)
        let ptr = floatData[0]
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = ptr[i]
            sumSquares += s * s
        }
        let rms = sqrt(sumSquares / max(Float(frameLength), 1))
        let dbLevel = 20 * log10(max(rms, 0.00001))
        let normalizedLevel = max(0, min(1, (dbLevel + 60) / 60)) // Normalize -60dB to 0dB -> 0.0 to 1.0

        // Append directly to CircularAudioBuffer using pointer (zero-copy, O(1) per sample)
        // CircularAudioBuffer is internally thread-safe via NSLock
        circularBuffer?.append(from: ptr, count: frameLength)

        // Capture fill ratio for UI
        let fillRatio = circularBuffer?.fillRatio ?? 0

        // Update published properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevel = normalizedLevel
            self.isAudioDetected = dbLevel > Self.noiseGateThresholdDB
            self.bufferFillRatio = fillRatio
            self.onAudioLevelUpdate?(normalizedLevel)
        }
    }

    /// Start timer for periodic prediction callbacks
    private func startPredictionTimer() {
        predictionTimer?.invalidate()

        predictionTimer = Timer.scheduledTimer(withTimeInterval: Self.predictionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerPredictionCallback()
            }
        }
    }

    /// Trigger callback with current audio samples
    /// Note: Does NOT gate on isAudioDetected — let the ML model and stabilizer
    /// handle filtering. The noise gate was blocking predictions for quiet but valid cries.
    private func triggerPredictionCallback() {
        guard state == .capturing else { return }

        guard let samples = getCurrentSamples() else {
            let validCount = circularBuffer?.validSampleCount ?? 0
            print("[AudioCaptureService] Not enough samples for prediction (\(validCount)/\(Self.samplesPerPrediction))")
            return
        }

        // Normalize audio to standard peak level before classification
        // This ensures the model gets consistent amplitude regardless of mic distance/volume
        let normalized = Self.normalizeAudio(samples)
        onAudioSamplesReady?(normalized)
    }

    /// Normalize audio samples to a target peak amplitude
    /// Boosts quiet audio so the ML model receives consistent signal levels
    private static func normalizeAudio(_ samples: [Float], targetPeak: Float = 0.9) -> [Float] {
        // Find peak absolute value
        var peak: Float = 0
        for sample in samples {
            let abs = sample < 0 ? -sample : sample
            if abs > peak { peak = abs }
        }

        // Skip normalization if effectively silent (below -60dB)
        guard peak > 0.001 else { return samples }

        let gain = targetPeak / peak
        // Cap gain to avoid amplifying pure noise excessively (max ~40dB boost)
        let clampedGain = min(gain, 100.0)

        return samples.map { $0 * clampedGain }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Handle audio session interruptions
        NotificationCenter.default.publisher(for: .audioSessionInterrupted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pauseCapture()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .audioSessionResumed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                try? self?.resumeCapture()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Testing Support

#if DEBUG
extension AudioCaptureService {
    /// Simulate audio input for testing by feeding samples into the circular buffer
    func simulateAudioSamples(_ samples: [Float]) {
        if circularBuffer == nil {
            circularBuffer = CircularAudioBuffer.forDeepInfantV2()
        }
        circularBuffer?.append(samples)
    }

    /// Force trigger prediction callback for testing
    func forceTriggerPrediction() {
        triggerPredictionCallback()
    }

    /// Get current buffer fill ratio (for test assertions)
    var testBufferFillRatio: Double {
        circularBuffer?.fillRatio ?? 0
    }

    /// Check if circular buffer has enough data for prediction
    var testHasSufficientSamples: Bool {
        (circularBuffer?.validSampleCount ?? 0) >= Self.samplesPerPrediction
    }
}
#endif
