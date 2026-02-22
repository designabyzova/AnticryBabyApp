//
//  SoundAnalysisCryDetector.swift
//  BabyInCarApp
//
//  Unified cry detection service using Apple's Sound Analysis framework.
//  Replaces the manual AudioCaptureService + CryClassificationService + CircularAudioBuffer pipeline.
//
//  Architecture:
//    Microphone → AVAudioEngine tap → SNAudioStreamAnalyzer (handles resampling + windowing)
//    → SNClassifySoundRequest(mlModel:) → SNResultsObserving callback
//    → MainActor dispatch → CryClassificationResult → CryTypeStabilizer
//
//  Key advantages:
//    - No manual sample rate conversion (Sound Analysis handles 48kHz → 16kHz internally)
//    - No CircularAudioBuffer (Sound Analysis handles audio windowing)
//    - No Timer-based polling (push-based callbacks via SNResultsObserving)
//    - Native integration with Create ML Sound Classifier models
//

import Foundation
import AVFoundation
import SoundAnalysis
import CoreML
import Combine
import UIKit

// MARK: - AudioCaptureState

/// Current state of audio capture
enum AudioCaptureState: Equatable {
    case idle
    case preparing
    case capturing
    case paused
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

// MARK: - CryClassificationResult

/// Result of a single cry classification inference
struct CryClassificationResult: Equatable {
    let cryType: CryType
    let confidence: Double
    let probabilities: [CryType: Double]
    let timestamp: Date

    /// Whether the result meets minimum confidence threshold
    var isConfident: Bool {
        confidence >= 0.40
    }
}

// MARK: - CryClassificationError

enum CryClassificationError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case predictionFailed(Error)
    case invalidAudioFormat
    case insufficientAudioSamples
    case audioSessionError(Error)
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "DeepInfant V2 model not loaded"
        case .modelLoadFailed(let error):
            return "Failed to load DeepInfant V2 model: \(error.localizedDescription)"
        case .predictionFailed(let error):
            return "Prediction failed: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format - requires 16kHz mono Float32"
        case .insufficientAudioSamples:
            return "Insufficient audio samples for classification"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        }
    }
}

// MARK: - SoundAnalysisCryDetector

/// Unified cry detection service using Apple's Sound Analysis framework.
/// Replaces AudioCaptureService + CryClassificationService + CircularAudioBuffer.
@MainActor
final class SoundAnalysisCryDetector: ObservableObject {

    // MARK: - Singleton

    static let shared = SoundAnalysisCryDetector()

    // MARK: - Constants

    /// Minimum confidence threshold for accepting a prediction
    static let minimumConfidenceThreshold: Double = 0.40

    /// Noise gate threshold in dB (for UI indicator and classification gating)
    static let noiseGateThresholdDB: Float = -50.0

    // MARK: - Published State (Audio Capture)

    /// Current capture state
    @Published private(set) var state: AudioCaptureState = .idle

    /// Current audio level (0.0 - 1.0) for UI waveform visualization
    @Published private(set) var currentLevel: Float = 0.0

    /// Whether audio is above noise gate threshold
    @Published private(set) var isAudioDetected: Bool = false

    // MARK: - Published State (Classification)

    /// Whether the service is actively listening
    @Published private(set) var isListening: Bool = false

    /// Current cry type from latest classification
    @Published private(set) var currentCryType: CryType = .unknown

    /// Confidence of current cry type
    @Published private(set) var confidence: Double = 0.0

    /// Whether the model is loaded and ready
    @Published private(set) var isModelReady: Bool = false

    /// Whether classification is stable
    @Published private(set) var isStable: Bool = false

    /// Last classification result
    @Published private(set) var lastResult: CryClassificationResult?

    /// Error state if any
    @Published private(set) var error: CryClassificationError?

    // MARK: - Callbacks

    /// Called when audio level updates (for waveform visualization)
    var onAudioLevelUpdate: ((Float) -> Void)?

    /// Called when a new classification result is produced
    var onClassificationResult: ((CryClassificationResult) -> Void)?

    // MARK: - Private Properties

    /// AVAudioEngine for microphone capture
    private var audioEngine: AVAudioEngine?

    /// Sound Analysis stream analyzer
    private var analyzer: SNAudioStreamAnalyzer?

    /// The classification request wrapping our CoreML model
    private var classificationRequest: SNClassifySoundRequest?

    /// Results observer (NSObject bridge for SNResultsObserving)
    private var resultsObserver: CryDetectionResultsObserver?

    /// The loaded CoreML model (for memory management)
    private var mlModel: MLModel?

    /// Model configuration
    private let modelConfiguration: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }()

    /// Dedicated queue for Sound Analysis (Apple requires consistent queue)
    private let analysisQueue = DispatchQueue(
        label: "com.babyincar.soundanalysis",
        qos: .userInitiated
    )

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Reference to audio session manager
    private let audioSessionManager = AudioSessionManager.shared

    // MARK: - Initialization

    private init() {
        setupNotifications()
        setupMemoryPressureHandling()
    }

    deinit {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
    }

    // MARK: - Public API: Lifecycle

    /// Start cry detection (microphone capture + Sound Analysis classification)
    func startDetection() async throws {
        guard state != .capturing else { return }

        state = .preparing

        // 1. Check microphone permission
        let granted = await checkMicrophonePermission()
        guard granted else {
            state = .error(.microphonePermissionDenied)
            throw AudioCaptureError.microphonePermissionDenied
        }

        // 2. Setup audio session
        do {
            try setupAudioSession()
        } catch {
            state = .error(.audioSessionSetupFailed(error))
            throw AudioCaptureError.audioSessionSetupFailed(error)
        }

        // 3. Load model if needed
        if mlModel == nil {
            try await loadModel()
        }

        // 4. Setup AVAudioEngine + SNAudioStreamAnalyzer
        do {
            try setupAudioPipeline()
        } catch {
            state = .error(.audioEngineSetupFailed(error))
            throw AudioCaptureError.audioEngineSetupFailed(error)
        }

        // 5. Start engine
        do {
            try audioEngine?.start()
            state = .capturing
            isListening = true
            print("[SoundAnalysisCryDetector] Started detection")
        } catch {
            state = .error(.audioEngineStartFailed(error))
            throw AudioCaptureError.audioEngineStartFailed(error)
        }
    }

    /// Stop cry detection and release all resources
    func stopDetection() {
        guard state != .idle else { return }

        // Remove tap and stop engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        // Remove request from analyzer
        if let request = classificationRequest {
            analyzer?.remove(request)
        }

        // Release resources — setting to nil deallocates the AVAudioEngine,
        // which releases its HAL resources asynchronously
        audioEngine = nil
        analyzer = nil
        classificationRequest = nil
        resultsObserver = nil

        // Clear callbacks to break retain cycles
        onAudioLevelUpdate = nil
        onClassificationResult = nil

        // Reset state
        state = .idle
        currentLevel = 0.0
        isAudioDetected = false
        isListening = false

        // CRITICAL FIX: Switch audio session from .playAndRecord → .playback
        // setupAudioSession() set .playAndRecord directly (bypassing AudioSessionManager).
        // We must explicitly transition to .playback so AVPlayer can produce sound.
        // Without this, the session stays in .playAndRecord + .measurement mode,
        // which can cause AVPlayer to buffer without outputting audio.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            print("[SoundAnalysisCryDetector] Audio session transitioned to .playback")
        } catch {
            print("[SoundAnalysisCryDetector] ⚠️ Failed to transition audio session: \(error)")
        }

        // Unload model to save ~5MB
        unloadModel()

        print("[SoundAnalysisCryDetector] Stopped detection - resources released")
    }

    /// Unload the ML model to free ~5MB memory
    func unloadModel() {
        mlModel = nil
        isModelReady = false
    }

    /// Pause detection (e.g., during audio interruption)
    func pauseDetection() {
        audioEngine?.pause()
        state = .paused
    }

    /// Resume detection after pause
    func resumeDetection() throws {
        guard state == .paused else { return }
        try audioEngine?.start()
        state = .capturing
    }

    // MARK: - Public API: State Management

    /// Reset classification state
    func reset() {
        currentCryType = .unknown
        confidence = 0.0
        isStable = false
        lastResult = nil
        error = nil
    }

    /// Update stable classification state (called by CryTypeStabilizer)
    func updateStableClassification(cryType: CryType, confidence: Double) {
        currentCryType = cryType
        self.confidence = confidence
        isStable = true
    }

    /// Get the ActionCategory for current classification
    var currentActionCategory: ActionCategory {
        ActionCategory.from(currentCryType)
    }

    // MARK: - Private: Audio Session

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // playAndRecord for simultaneous music + microphone
        // .measurement mode for accurate audio capture
        // .defaultToSpeaker routes to speaker (not earpiece)
        // NO .mixWithOthers — exclusive control per CLAUDE.md rules
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
        print("[SoundAnalysisCryDetector] Audio session: playAndRecord @ \(session.sampleRate)Hz")
    }

    // MARK: - Private: Microphone Permission

    private func checkMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return true
            case .denied: return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default: return false
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted: return true
            case .denied: return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default: return false
            }
        }
    }

    // MARK: - Private: Model Loading

    private func loadModel() async throws {
        guard mlModel == nil else {
            isModelReady = true
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Load the model URL from the compiled .mlmodelc in the bundle
            guard let modelURL = Bundle.main.url(forResource: "DeepInfant_V2", withExtension: "mlmodelc") else {
                throw CryClassificationError.modelNotLoaded
            }

            let model = try await MLModel.load(
                contentsOf: modelURL,
                configuration: modelConfiguration
            )

            self.mlModel = model
            isModelReady = true

            let loadTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("[SoundAnalysisCryDetector] Model loaded in \(Int(loadTime))ms")
        } catch {
            self.error = .modelLoadFailed(error)
            isModelReady = false
            throw error
        }
    }

    // MARK: - Private: Audio Pipeline Setup

    private func setupAudioPipeline() throws {
        guard let model = mlModel else {
            throw CryClassificationError.modelNotLoaded
        }

        // 1. Create audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("[SoundAnalysisCryDetector] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        // 2. Create SNAudioStreamAnalyzer at the NATIVE input format
        //    Sound Analysis handles resampling to 16kHz internally
        let streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)

        // 3. Create SNClassifySoundRequest from our CoreML model
        let request = try SNClassifySoundRequest(mlModel: model)

        // 4. Create results observer (NSObject bridge → MainActor dispatch)
        let observer = CryDetectionResultsObserver(
            onResult: { [weak self] snResult in
                Task { @MainActor [weak self] in
                    self?.handleClassificationResult(snResult)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleClassificationError(error)
                }
            }
        )

        // 5. Add request to analyzer with observer
        try streamAnalyzer.add(request, withObserver: observer)

        // 6. Install tap on input node
        //    ~100ms buffers at native sample rate
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, time in
            guard let self = self else { return }

            // A. Compute audio level for UI (lightweight, no allocation)
            self.computeAudioLevel(buffer: buffer)

            // B. Feed buffer to Sound Analysis on the dedicated analysis queue
            self.analysisQueue.async {
                streamAnalyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }

        // 7. Prepare engine
        engine.prepare()

        // Store references
        self.audioEngine = engine
        self.analyzer = streamAnalyzer
        self.classificationRequest = request
        self.resultsObserver = observer
    }

    // MARK: - Private: Audio Level Metering

    /// Compute RMS audio level from buffer (called on audio thread)
    private nonisolated func computeAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let ptr = floatData[0]
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = ptr[i]
            sumSquares += s * s
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        let dbLevel = 20 * log10(max(rms, 0.00001))
        let normalizedLevel = max(0, min(1, (dbLevel + 60) / 60))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevel = normalizedLevel
            self.isAudioDetected = dbLevel > Self.noiseGateThresholdDB
            self.onAudioLevelUpdate?(normalizedLevel)
        }
    }

    // MARK: - Private: Classification Result Handling

    /// Handle classification result from Sound Analysis (called on MainActor)
    private func handleClassificationResult(_ snResult: SNClassificationResult) {
        let result = parseClassificationResult(snResult)

        lastResult = result
        if result.isConfident {
            currentCryType = result.cryType
            confidence = result.confidence
        }

        onClassificationResult?(result)
    }

    /// Parse SNClassificationResult into CryClassificationResult
    private func parseClassificationResult(_ snResult: SNClassificationResult) -> CryClassificationResult {
        let classifications = snResult.classifications

        guard let top = classifications.first else {
            return CryClassificationResult(
                cryType: .unknown,
                confidence: 0.0,
                probabilities: [:],
                timestamp: Date()
            )
        }

        let cryType = mapToCryType(top.identifier)

        // Build probabilities dictionary
        // Multiple model classes can map to same CryType — accumulate confidence
        var probabilities: [CryType: Double] = [:]
        for classification in classifications {
            let type = mapToCryType(classification.identifier)
            probabilities[type, default: 0] += classification.confidence
        }

        return CryClassificationResult(
            cryType: cryType,
            confidence: top.confidence,
            probabilities: probabilities,
            timestamp: Date()
        )
    }

    /// Map model output string to CryType enum
    /// DeepInfant V2 outputs 9 classes: belly_pain, burping, cold_hot, discomfort,
    /// hungry, lonely, scared, tired, unknown
    private func mapToCryType(_ modelOutput: String) -> CryType {
        switch modelOutput.lowercased() {
        case "hungry", "hunger":
            return .hunger
        case "tired", "sleepy", "fatigue":
            return .tired
        case "belly_pain", "bellypain":
            return .pain
        case "discomfort", "uncomfortable", "cold_hot":
            return .discomfort
        case "burping", "needs_burping", "needsburping":
            return .discomfort
        case "lonely", "attention", "bored":
            return .attention
        case "scared":
            return .pain
        case "unknown":
            return .unknown
        default:
            return .unknown
        }
    }

    /// Handle classification error from Sound Analysis
    private func handleClassificationError(_ snError: Error) {
        print("[SoundAnalysisCryDetector] Classification error: \(snError)")
        error = .predictionFailed(snError)
    }

    // MARK: - Private: Notifications

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .audioSessionInterrupted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pauseDetection() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .audioSessionResumed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in try? self?.resumeDetection() }
            .store(in: &cancellables)
    }

    // MARK: - Private: Memory Pressure

    private func setupMemoryPressureHandling() {
        NotificationCenter.default.publisher(for: NSNotification.Name("MemoryCleanupRequested"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let level = notification.userInfo?["level"] as? String ?? "unknown"
                if level == "emergency" && !self.isListening {
                    self.unloadModel()
                    print("[SoundAnalysisCryDetector] Memory pressure (emergency): unloaded model")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.isListening {
                    self.unloadModel()
                    print("[SoundAnalysisCryDetector] System memory warning: unloaded model")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - CryDetectionResultsObserver

/// NSObject bridge for SNResultsObserving protocol.
/// Required because SNResultsObserving requires NSObject conformance,
/// which is incompatible with @MainActor final classes.
/// Callbacks are dispatched to MainActor via closures.
private final class CryDetectionResultsObserver: NSObject, SNResultsObserving {

    private let onResult: (SNClassificationResult) -> Void
    private let onError: (Error) -> Void

    init(
        onResult: @escaping (SNClassificationResult) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onResult = onResult
        self.onError = onError
        super.init()
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }
        onResult(classificationResult)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        onError(error)
    }

    func requestDidComplete(_ request: SNRequest) {
        // Stream ended — lifecycle managed by stopDetection()
    }
}

// MARK: - Testing Support

#if DEBUG
extension SoundAnalysisCryDetector {
    /// Simulate a classification result for testing
    func simulateClassification(cryType: CryType, confidence: Double = 0.85) {
        let result = CryClassificationResult(
            cryType: cryType,
            confidence: confidence,
            probabilities: [cryType: confidence],
            timestamp: Date()
        )
        lastResult = result
        if result.isConfident {
            currentCryType = result.cryType
            self.confidence = result.confidence
        }
        onClassificationResult?(result)
    }

    /// Create mock classification result
    static func mockResult(
        cryType: CryType,
        confidence: Double = 0.85
    ) -> CryClassificationResult {
        CryClassificationResult(
            cryType: cryType,
            confidence: confidence,
            probabilities: [cryType: confidence],
            timestamp: Date()
        )
    }
}
#endif
