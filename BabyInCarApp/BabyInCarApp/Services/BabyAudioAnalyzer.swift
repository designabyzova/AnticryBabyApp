//
//  BabyAudioAnalyzer.swift
//  BabyInCarApp
//
//  Central coordinator for ultra-smart baby audio analytics
//  Orchestrates feature extraction, ML inference, voice analysis, and pattern tracking
//

import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Baby Audio Analyzer

/// Central coordinator for comprehensive baby audio analysis
/// Combines feature extraction, ML models, voice analysis, and pattern tracking
@MainActor
class BabyAudioAnalyzer: ObservableObject {

    // MARK: - Singleton

    static let shared = BabyAudioAnalyzer()

    // MARK: - Published State

    /// Current analysis state
    @Published var analysisState: AnalysisState = .idle

    /// Latest complete analysis result
    @Published var currentAnalysis: BabyAudioAnalysisResult?

    /// Current cry detection confidence (0-1)
    @Published var cryConfidence: Double = 0

    /// Detected cry type
    @Published var dominantCryType: CryType = .unknown

    /// Current cry intensity (0-1)
    @Published var cryIntensity: Double = 0

    /// Whether tremolo/voice trembling is detected
    @Published var tremoloDetected: Bool = false

    /// Current audio level (for UI meters)
    @Published var currentAudioLevel: Float = 0

    /// Whether ML models are loaded
    @Published var mlModelsReady: Bool = false

    /// Latest voice characteristics
    @Published var voiceCharacteristics: VoiceCharacteristics = .zero

    /// Current pattern metrics
    @Published var patternMetrics: CryPatternMetrics = .zero

    /// Whether processing is active
    @Published var isProcessing: Bool = false

    // MARK: - Analysis State

    enum AnalysisState: String {
        case idle = "Ready"
        case initializing = "Initializing..."
        case analyzing = "Analyzing"
        case paused = "Paused"
        case error = "Error"
    }

    // MARK: - Analysis Components

    /// Advanced feature extractor
    let featureExtractor: AdvancedFeatureExtractor

    /// Core ML cry detector
    let cryDetectorModel: CryDetectorMLModel

    /// Core ML cry classifier
    let cryClassifierModel: CryClassifierMLModel

    /// Voice characteristics analyzer
    let voiceAnalyzer: VoiceCharacteristicsAnalyzer

    /// Temporal pattern tracker
    let patternTracker: CryPatternTracker

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private let analysisQueue = DispatchQueue(label: "com.babyincar.audioanalyzer", qos: .userInteractive)

    // MARK: - Configuration

    private let bufferSize: AVAudioFrameCount = 4096
    private let sampleRate: Float = 44100

    /// Minimum confidence to trigger cry detection callback
    private let minCryConfidence: Double = 0.6

    /// Blend ratio for ML vs rule-based (0 = all rule-based, 1 = all ML)
    private let mlBlendRatio: Double = 0.6

    // MARK: - State

    private var currentBabyId: UUID?
    private var analysisStartTime: Date?
    private var frameCount: Int = 0

    // MARK: - Callbacks

    /// Called when cry is detected with analysis result
    var onCryDetected: ((CryAnalysisResult) -> Void)?

    /// Called when cry ends
    var onCryEnded: (() -> Void)?

    /// Called for every analysis frame (for detailed monitoring)
    var onAnalysisComplete: ((BabyAudioAnalysisResult) -> Void)?

    // MARK: - Initialization

    private init() {
        self.featureExtractor = AdvancedFeatureExtractor(fftSize: 4096)
        self.cryDetectorModel = CryDetectorMLModel()
        self.cryClassifierModel = CryClassifierMLModel()
        self.voiceAnalyzer = VoiceCharacteristicsAnalyzer()
        self.patternTracker = CryPatternTracker()

        // Check ML model status
        mlModelsReady = cryDetectorModel.isModelLoaded && cryClassifierModel.isModelLoaded
    }

    // MARK: - Public Methods

    /// Start audio analysis for a specific baby
    /// - Parameter babyId: UUID of the baby being monitored
    func startAnalysis(for babyId: UUID) async throws {
        guard analysisState == .idle || analysisState == .paused else { return }

        currentBabyId = babyId
        analysisState = .initializing
        isProcessing = true

        do {
            try await setupAudioEngine()
            try audioEngine?.start()

            analysisStartTime = Date()
            frameCount = 0
            patternTracker.reset()
            featureExtractor.reset()
            voiceAnalyzer.reset()

            analysisState = .analyzing
            print("BabyAudioAnalyzer: Started analysis for baby \(babyId)")
        } catch {
            analysisState = .error
            isProcessing = false
            throw error
        }
    }

    /// Stop audio analysis
    func stopAnalysis() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        analysisState = .idle
        isProcessing = false
        cryConfidence = 0
        cryIntensity = 0
        dominantCryType = .unknown
        tremoloDetected = false

        print("BabyAudioAnalyzer: Stopped analysis")
    }

    /// Pause analysis (keeps state)
    func pauseAnalysis() {
        audioEngine?.pause()
        analysisState = .paused
        isProcessing = false
    }

    /// Resume paused analysis
    func resumeAnalysis() throws {
        guard analysisState == .paused else { return }

        try audioEngine?.start()
        analysisState = .analyzing
        isProcessing = true
    }

    /// Get session summary for completed analysis
    func getSessionSummary() -> CrySessionSummary? {
        guard let startTime = analysisStartTime, currentBabyId != nil else {
            return nil
        }

        let metrics = patternTracker.getCurrentMetrics()

        return CrySessionSummary(
            sessionId: UUID(),
            startTime: startTime,
            endTime: Date(),
            totalDuration: Date().timeIntervalSince(startTime),
            totalCryDuration: metrics.totalCryDuration,
            cryBurstCount: metrics.cryBurstCount,
            dominantCryType: metrics.dominantType,
            averageIntensity: cryIntensity,
            peakIntensity: metrics.peakIntensity,
            patternAssessment: metrics.patternAssessment
        )
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() async throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AnalysisError.engineSetupFailed
        }

        // Request microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw AnalysisError.microphoneAccessDenied
        }

        // Configure audio session - exclusive playback (pauses other apps)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)

        // Install tap on input node
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Audio Processing Pipeline

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // Process on main actor to access MainActor-isolated properties
        Task { @MainActor [weak self] in
            self?.analyzeAudioSamples(samples, timestamp: Date())
        }
    }

    private func analyzeAudioSamples(_ samples: [Float], timestamp: Date) {
        frameCount += 1

        // Step 1: Calculate audio level
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Step 2: Extract comprehensive features
        let features = featureExtractor.extractFeatures(from: samples, sampleRate: sampleRate)

        // Step 3: Run ML cry detection
        let mlDetection = cryDetectorModel.detect(features: features)

        // Step 4: If cry likely, classify type
        var classification = CryClassification.unknown
        if mlDetection.isCryDetected || mlDetection.confidence > 0.4 {
            classification = cryClassifierModel.classify(features: features)
        }

        // Step 5: Analyze voice characteristics (tremolo, vibrato, etc.)
        let voiceChars = voiceAnalyzer.analyze(samples: samples, sampleRate: sampleRate)

        // Step 6: Update pattern tracker
        let patterns = patternTracker.update(
            isCrying: mlDetection.isCryDetected,
            intensity: mlDetection.intensity,
            type: classification.type,
            timestamp: timestamp
        )

        // Step 7: Build comprehensive result
        let result = BabyAudioAnalysisResult(
            timestamp: timestamp,
            frameNumber: frameCount,
            features: features,
            cryDetected: mlDetection.isCryDetected,
            cryConfidence: mlDetection.confidence,
            cryType: classification.type,
            cryTypeConfidence: classification.confidence,
            cryTypeProbabilities: classification.allProbabilities,
            intensity: mlDetection.intensity,
            voiceCharacteristics: voiceChars,
            patternMetrics: patterns,
            audioLevel: rms,
            usedMLModels: mlDetection.usedMLModel && classification.usedMLModel
        )

        // Step 8: Update published state on main thread
        Task { @MainActor in
            self.updatePublishedState(result: result, wasDetected: mlDetection.isCryDetected)
        }
    }

    private func updatePublishedState(result: BabyAudioAnalysisResult, wasDetected: Bool) {
        // Update basic state
        currentAudioLevel = result.audioLevel
        cryConfidence = result.cryConfidence
        cryIntensity = result.intensity
        dominantCryType = result.cryType
        tremoloDetected = result.voiceCharacteristics.hasTremolo
        voiceCharacteristics = result.voiceCharacteristics
        patternMetrics = result.patternMetrics
        currentAnalysis = result

        // Check for cry state transitions
        let previouslyCrying = patternMetrics.isCurrentlyCrying
        let nowCrying = wasDetected && result.cryConfidence >= minCryConfidence

        if nowCrying && !previouslyCrying {
            // Cry just started
            let cryResult = CryAnalysisResult(
                type: result.cryType,
                confidence: result.cryTypeConfidence,
                intensity: result.intensity,
                features: result.features,
                voiceCharacteristics: result.voiceCharacteristics
            )
            onCryDetected?(cryResult)
        } else if previouslyCrying && !nowCrying {
            // Cry ended
            onCryEnded?()
        }

        // Always call analysis complete callback
        onAnalysisComplete?(result)
    }
}

// MARK: - Complete Analysis Result

/// Complete result from one analysis frame
struct BabyAudioAnalysisResult: Codable {
    /// Timestamp of analysis
    let timestamp: Date

    /// Frame number in current session
    let frameNumber: Int

    /// Extracted audio features
    let features: ExtendedAudioFeatures

    /// Whether cry was detected
    let cryDetected: Bool

    /// Cry detection confidence (0-1)
    let cryConfidence: Double

    /// Classified cry type
    let cryType: CryType

    /// Confidence in cry type classification (0-1)
    let cryTypeConfidence: Double

    /// Probabilities for all cry types
    let cryTypeProbabilities: [CryType: Double]

    /// Cry intensity (0-1)
    let intensity: Double

    /// Voice analysis results
    let voiceCharacteristics: VoiceCharacteristics

    /// Temporal pattern metrics
    let patternMetrics: CryPatternMetrics

    /// Raw audio level
    let audioLevel: Float

    /// Whether ML models were used (vs fallback)
    let usedMLModels: Bool

    // MARK: - Convenience Properties

    /// Is this a high-confidence cry detection?
    var isConfidentCry: Bool {
        cryDetected && cryConfidence > 0.7
    }

    /// Is the baby showing signs of distress?
    var isDistressed: Bool {
        let distressFromVoice = voiceCharacteristics.distressIndicator > 0.5
        let distressFromPattern = patternMetrics.intensityTrend == .increasing
        let distressFromIntensity = intensity > 0.7

        return (cryDetected && distressFromIntensity) || distressFromVoice || distressFromPattern
    }

    /// Overall urgency level
    var urgencyLevel: UrgencyLevel {
        if cryType == .pain && intensity > 0.7 {
            return .critical
        }
        if isDistressed && patternMetrics.currentBurstDuration > 30 {
            return .high
        }
        if cryDetected && intensity > 0.5 {
            return .medium
        }
        if cryDetected {
            return .low
        }
        return .none
    }

    enum UrgencyLevel: String, Codable {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        var color: String {
            switch self {
            case .none: return "green"
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            case .critical: return "purple"
            }
        }
    }
}

// MARK: - Analysis Errors

enum AnalysisError: Error, LocalizedError {
    case engineSetupFailed
    case microphoneAccessDenied
    case analysisError(String)
    case modelLoadFailed

    var errorDescription: String? {
        switch self {
        case .engineSetupFailed:
            return "Failed to setup audio analysis engine"
        case .microphoneAccessDenied:
            return "Microphone access is required for cry detection"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        case .modelLoadFailed:
            return "Failed to load ML models"
        }
    }
}

// MARK: - Analysis Configuration

/// Configuration options for audio analysis
struct AnalysisConfiguration: Codable {
    /// Whether to use ML models (if available)
    var useMLModels: Bool = true

    /// Minimum confidence threshold for cry detection
    var cryConfidenceThreshold: Double = 0.6

    /// Whether to perform voice characteristics analysis
    var analyzeVoiceCharacteristics: Bool = true

    /// Whether to track temporal patterns
    var trackPatterns: Bool = true

    /// Sample rate for analysis
    var sampleRate: Float = 44100

    /// Buffer size for audio capture
    var bufferSize: Int = 4096

    static var `default`: AnalysisConfiguration {
        AnalysisConfiguration()
    }

    static var lowPower: AnalysisConfiguration {
        var config = AnalysisConfiguration()
        config.analyzeVoiceCharacteristics = false
        config.bufferSize = 2048
        return config
    }

    static var highAccuracy: AnalysisConfiguration {
        var config = AnalysisConfiguration()
        config.cryConfidenceThreshold = 0.5
        config.bufferSize = 8192
        return config
    }
}
