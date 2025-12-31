//
//  CryDetectionService.swift
//  BabyInCarApp
//
//  AI-powered real-time cry detection with intelligent pattern recognition
//  Uses FFT analysis and machine learning for accurate baby cry classification
//

import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Cry Detection Service
/// Real-time audio analysis service that detects baby crying patterns using
/// frequency analysis and intelligent pattern recognition
/// Enhanced with ML-based detection blending for improved accuracy
@MainActor
class CryDetectionService: ObservableObject {
    static let shared = CryDetectionService()

    // MARK: - Published State
    @Published var isMonitoring: Bool = false
    @Published var isCryDetected: Bool = false
    @Published var cryIntensity: Double = 0 // 0.0 - 1.0
    @Published var cryType: CryType = .unknown
    @Published var confidenceLevel: Double = 0
    @Published var currentAudioLevel: Float = 0
    @Published var detectionStatus: DetectionStatus = .idle

    // MARK: - ML Integration
    /// Whether to use ML-enhanced detection
    var useMLEnhancement: Bool = true

    /// Blend ratio: 0 = all rule-based, 1 = all ML
    var mlBlendRatio: Double = 0.6

    /// Advanced feature extractor for ML
    private lazy var advancedFeatureExtractor = AdvancedFeatureExtractor(fftSize: fftSize)

    /// ML cry detector
    private lazy var mlCryDetector = CryDetectorMLModel()

    /// ML cry classifier
    private lazy var mlCryClassifier = CryClassifierMLModel()

    /// Voice characteristics analyzer
    private lazy var voiceAnalyzer = VoiceCharacteristicsAnalyzer()

    /// Pattern tracker for temporal analysis
    private let patternTracker = CryPatternTracker()

    /// Latest extended audio features (for external access)
    @Published var latestExtendedFeatures: ExtendedAudioFeatures?

    /// Latest voice characteristics
    @Published var latestVoiceCharacteristics: VoiceCharacteristics?

    /// Pattern metrics
    @Published var latestPatternMetrics: CryPatternMetrics?

    // MARK: - Detection State
    enum DetectionStatus: String {
        case idle = "Ready to Monitor"
        case listening = "Listening..."
        case analyzing = "Analyzing Sound"
        case cryDetected = "Cry Detected!"
        case responding = "Soothing Baby"
        case monitoring = "Monitoring"
        case error = "Error"
    }

    // MARK: - Audio Analysis Components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let analysisQueue = DispatchQueue(label: "com.babyincar.crydetection", qos: .userInteractive)

    // FFT Configuration
    private let fftSize: Int = 4096
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []
    private var magnitudes: [Float] = []

    // Cry Detection Parameters
    private let cryFrequencyRange: ClosedRange<Float> = 300...600 // Fundamental cry frequency Hz
    private let cryHarmonicsRange: ClosedRange<Float> = 600...2000 // Cry harmonics
    private let attentionFrequencyRange: ClosedRange<Float> = 2000...5000 // High harmonics

    // Rolling buffer for temporal analysis
    private var audioBuffer: [Float] = []
    private let bufferDuration: TimeInterval = 2.0 // seconds of audio to analyze
    private let sampleRate: Float = 44100

    // Pattern recognition state
    private var cryPatternBuffer: [CryFrame] = []
    private let patternBufferSize = 30 // ~1 second at 30fps
    private var consecutiveCryFrames: Int = 0
    private let minCryFramesForDetection = 10 // ~0.33 seconds

    // Adaptive thresholds
    private var ambientNoiseLevel: Float = 0
    private var adaptiveThreshold: Float = 0.15
    private let minCryConfidence: Double = 0.65

    // Cry type classification history
    private var cryTypeHistory: [CryType] = []
    private let cryTypeHistorySize = 15

    // Callbacks
    var onCryDetected: ((CryType, Double) -> Void)?
    var onCryEnded: (() -> Void)?

    // MARK: - Cry Analysis Frame
    private struct CryFrame {
        let timestamp: Date
        let fundamentalPower: Float
        let harmonicPower: Float
        let overallLevel: Float
        let spectralCentroid: Float
        let isCryLike: Bool
        let cryType: CryType
        let confidence: Double
    }

    private init() {
        setupFFT()
    }

    // MARK: - Setup
    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
    }

    // MARK: - Monitoring Control
    func startMonitoring() async throws {
        guard !isMonitoring else { return }

        // Request microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            detectionStatus = .error
            throw CryDetectionError.microphoneAccessDenied
        }

        try setupAudioEngine()
        try audioEngine?.start()

        isMonitoring = true
        detectionStatus = .listening

        // Start ambient noise calibration
        calibrateAmbientNoise()
    }

    func stopMonitoring() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        isMonitoring = false
        isCryDetected = false
        cryIntensity = 0
        detectionStatus = .idle
        consecutiveCryFrames = 0
        cryPatternBuffer.removeAll()
    }

    // MARK: - Permission
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Audio Engine Setup
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw CryDetectionError.engineSetupFailed
        }

        // Configure audio session for monitoring while playing
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)

        inputNode = engine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)

        // Install tap for audio analysis
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(fftSize)
        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
    }

    // MARK: - Audio Processing Pipeline
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // Convert to array for processing
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // Capture values needed for analysis
        let fftSizeLocal = fftSize
        let windowLocal = window
        let ambientNoiseLevelLocal = ambientNoiseLevel
        let adaptiveThresholdLocal = adaptiveThreshold
        let useMLEnhancementLocal = useMLEnhancement
        let mlBlendRatioLocal = mlBlendRatio
        let sampleRateLocal = sampleRate

        analysisQueue.async { [weak self] in
            self?.analyzeAudioNonIsolated(
                samples: samples,
                fftSize: fftSizeLocal,
                window: windowLocal,
                ambientNoiseLevel: ambientNoiseLevelLocal,
                adaptiveThreshold: adaptiveThresholdLocal,
                useMLEnhancement: useMLEnhancementLocal,
                mlBlendRatio: mlBlendRatioLocal,
                sampleRate: sampleRateLocal
            )
        }
    }

    /// Non-isolated audio analysis that can run on background queue
    private nonisolated func analyzeAudioNonIsolated(
        samples: [Float],
        fftSize: Int,
        window: [Float],
        ambientNoiseLevel: Float,
        adaptiveThreshold: Float,
        useMLEnhancement: Bool,
        mlBlendRatio: Double,
        sampleRate: Float
    ) {
        guard samples.count >= fftSize else { return }

        // 1. Calculate RMS level
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Update audio level on main thread
        Task { @MainActor [weak self] in
            self?.currentAudioLevel = rms
        }

        // Skip analysis if too quiet (likely just ambient noise)
        guard rms > ambientNoiseLevel * 1.5 else {
            Task { @MainActor [weak self] in
                self?.handleQuietFrame()
            }
            return
        }

        // 2. Apply window function
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var windowCopy = window
        vDSP_vmul(samples, 1, &windowCopy, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // 3. Perform FFT
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        performFFTNonIsolated(on: windowedSamples, fftSize: fftSize, magnitudes: &magnitudes)

        // 4. Analyze frequency spectrum for cry characteristics (rule-based)
        let cryAnalysis = analyzeCryCharacteristicsNonIsolated(
            magnitudes: magnitudes,
            sampleRate: sampleRate,
            fftSize: fftSize,
            adaptiveThreshold: adaptiveThreshold
        )

        // 5. Classify cry type (rule-based)
        var cryType = classifyCryTypeNonIsolated(analysis: cryAnalysis, adaptiveThreshold: adaptiveThreshold)

        // 6. Calculate confidence (rule-based)
        var confidence = calculateConfidenceNonIsolated(
            analysis: cryAnalysis,
            type: cryType,
            adaptiveThreshold: adaptiveThreshold
        )

        // Variables for ML enhancement
        var extendedFeatures: ExtendedAudioFeatures?
        var voiceChars: VoiceCharacteristics?
        var mlCryDetected = false
        var patterns: CryPatternMetrics?

        if useMLEnhancement {
            // Create feature extractor locally for thread safety
            let featureExtractor = AdvancedFeatureExtractor(fftSize: fftSize)
            let features = featureExtractor.extractFeatures(from: samples, sampleRate: sampleRate)
            extendedFeatures = features

            // Create detector/classifier locally
            let detector = CryDetectorMLModel()
            let mlDetection = detector.detect(features: features)
            mlCryDetected = mlDetection.isCryDetected
            let mlConfidence = mlDetection.confidence

            // If cry detected, classify type with ML
            if mlDetection.isCryDetected || mlDetection.confidence > 0.4 {
                let classifier = CryClassifierMLModel()
                let classification = classifier.classify(features: features)

                // Blend ML classification with rule-based
                if classification.confidence > confidence {
                    cryType = classification.type
                }
            }

            // Analyze voice characteristics
            let voiceAnalyzer = VoiceCharacteristicsAnalyzer()
            voiceChars = voiceAnalyzer.analyze(samples: samples, sampleRate: sampleRate)

            // Blend confidences
            let blendedConfidence = (mlConfidence * mlBlendRatio) + (confidence * (1.0 - mlBlendRatio))
            confidence = blendedConfidence

            // If ML detects cry but rule-based doesn't, use higher confidence
            if mlCryDetected && !cryAnalysis.isCryLike && mlConfidence > 0.7 {
                confidence = max(confidence, mlConfidence)
            }
        }

        // Determine if cry-like
        let isCryLike = useMLEnhancement ? (cryAnalysis.isCryLike || mlCryDetected) : cryAnalysis.isCryLike

        // Create frame
        let frame = CryFrame(
            timestamp: Date(),
            fundamentalPower: cryAnalysis.fundamentalPower,
            harmonicPower: cryAnalysis.harmonicPower,
            overallLevel: rms,
            spectralCentroid: cryAnalysis.spectralCentroid,
            isCryLike: isCryLike,
            cryType: cryType,
            confidence: confidence
        )

        // Update state on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Update ML state if applicable
            if useMLEnhancement {
                self.latestExtendedFeatures = extendedFeatures
                self.latestVoiceCharacteristics = voiceChars

                // Update pattern tracker on main thread
                let timestamp = Date()
                let updatedPatterns = self.patternTracker.update(
                    isCrying: isCryLike,
                    intensity: Double(rms),
                    type: cryType,
                    timestamp: timestamp
                )
                self.latestPatternMetrics = updatedPatterns
            }

            self.updatePatternBuffer(with: frame)
            self.evaluateDetection()
        }
    }

    /// Non-isolated FFT computation
    private nonisolated func performFFTNonIsolated(on samples: [Float], fftSize: Int, magnitudes: inout [Float]) {
        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else { return }
        defer { vDSP_DFT_DestroySetup(fftSetup) }

        var realInput = samples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        var scaleFactor: Float = 2.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(fftSize / 2))
    }

    /// Non-isolated cry characteristics analysis
    private nonisolated func analyzeCryCharacteristicsNonIsolated(
        magnitudes: [Float],
        sampleRate: Float,
        fftSize: Int,
        adaptiveThreshold: Float
    ) -> CryAnalysis {
        let frequencyResolution = sampleRate / Float(fftSize)
        let cryFrequencyRange: ClosedRange<Float> = 300...600
        let cryHarmonicsRange: ClosedRange<Float> = 600...2000

        let fundamentalPower = calculateBandPowerNonIsolated(magnitudes: magnitudes, range: cryFrequencyRange, resolution: frequencyResolution)
        let harmonicPower = calculateBandPowerNonIsolated(magnitudes: magnitudes, range: cryHarmonicsRange, resolution: frequencyResolution)
        let spectralCentroid = calculateSpectralCentroidNonIsolated(magnitudes: magnitudes, resolution: frequencyResolution)
        let spectralFlatness = calculateSpectralFlatnessNonIsolated(magnitudes: magnitudes)

        let isCryLike = fundamentalPower > adaptiveThreshold &&
                        harmonicPower > fundamentalPower * 0.3 &&
                        spectralCentroid > 500 && spectralCentroid < 2000 &&
                        spectralFlatness < 0.5

        return CryAnalysis(
            fundamentalPower: fundamentalPower,
            harmonicPower: harmonicPower,
            spectralCentroid: spectralCentroid,
            spectralFlatness: spectralFlatness,
            zeroCrossingRate: 0,
            isCryLike: isCryLike
        )
    }

    private nonisolated func calculateBandPowerNonIsolated(magnitudes: [Float], range: ClosedRange<Float>, resolution: Float) -> Float {
        let startBin = Int(range.lowerBound / resolution)
        let endBin = min(Int(range.upperBound / resolution), magnitudes.count - 1)
        guard startBin < endBin && startBin >= 0 else { return 0 }

        var power: Float = 0
        let bandMagnitudes = Array(magnitudes[startBin...endBin])
        vDSP_sve(bandMagnitudes, 1, &power, vDSP_Length(endBin - startBin + 1))
        return power / Float(endBin - startBin + 1)
    }

    private nonisolated func calculateSpectralCentroidNonIsolated(magnitudes: [Float], resolution: Float) -> Float {
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * resolution
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private nonisolated func calculateSpectralFlatnessNonIsolated(magnitudes: [Float]) -> Float {
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

    private nonisolated func classifyCryTypeNonIsolated(analysis: CryAnalysis, adaptiveThreshold: Float) -> CryType {
        guard analysis.isCryLike else { return .unknown }

        let fundamentalRatio = analysis.fundamentalPower / (analysis.harmonicPower + 0.001)
        let centroid = analysis.spectralCentroid

        if centroid < 700 && fundamentalRatio > 1.5 { return .hunger }
        if centroid > 1200 && analysis.fundamentalPower > adaptiveThreshold * 2 { return .pain }
        if analysis.fundamentalPower < adaptiveThreshold * 1.5 && centroid < 900 { return .tired }
        if centroid > 800 && centroid < 1200 { return .attention }
        if analysis.harmonicPower > analysis.fundamentalPower * 0.8 { return .discomfort }

        return .general
    }

    private nonisolated func calculateConfidenceNonIsolated(analysis: CryAnalysis, type: CryType, adaptiveThreshold: Float) -> Double {
        guard analysis.isCryLike else { return 0 }

        var confidence: Double = 0
        let powerScore = Double(min(analysis.fundamentalPower / (adaptiveThreshold * 3), 1.0))
        confidence += powerScore * 0.3

        let tonalScore = Double(1.0 - analysis.spectralFlatness)
        confidence += tonalScore * 0.25

        let harmonicScore = Double(min(analysis.harmonicPower / analysis.fundamentalPower, 1.0))
        confidence += harmonicScore * 0.2

        let centroidScore = analysis.spectralCentroid > 400 && analysis.spectralCentroid < 2000 ? 0.15 : 0.05
        confidence += centroidScore

        return min(confidence, 1.0)
    }

    // Keep the original method for compatibility but mark as deprecated
    @available(*, deprecated, message: "Use analyzeAudioNonIsolated instead")
    private func analyzeAudio(samples: [Float]) {
        guard samples.count >= fftSize else { return }

        // 1. Calculate RMS level
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Update audio level on main thread
        Task { @MainActor in
            self.currentAudioLevel = rms
        }

        // Skip analysis if too quiet (likely just ambient noise)
        guard rms > ambientNoiseLevel * 1.5 else {
            handleQuietFrame()
            return
        }

        // 2. Apply window function
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // 3. Perform FFT
        performFFT(on: windowedSamples)

        // 4. Analyze frequency spectrum for cry characteristics (rule-based)
        let cryAnalysis = analyzeCryCharacteristics()

        // 5. Classify cry type (rule-based)
        var cryType = classifyCryType(analysis: cryAnalysis)

        // 6. Calculate confidence (rule-based)
        var confidence = calculateConfidence(analysis: cryAnalysis, type: cryType)

        // ========== ML Enhancement ==========
        // Blend ML-based detection with rule-based for improved accuracy
        var mlCryDetected = false
        var mlConfidence: Double = 0

        if useMLEnhancement {
            // Extract comprehensive audio features for ML
            let features = advancedFeatureExtractor.extractFeatures(from: samples, sampleRate: sampleRate)

            // Run ML cry detection
            let mlDetection = mlCryDetector.detect(features: features)
            mlCryDetected = mlDetection.isCryDetected
            mlConfidence = mlDetection.confidence

            // If cry detected, classify type with ML
            if mlDetection.isCryDetected || mlDetection.confidence > 0.4 {
                let classification = mlCryClassifier.classify(features: features)

                // Blend ML classification with rule-based
                if classification.confidence > confidence {
                    cryType = classification.type
                }
            }

            // Analyze voice characteristics (tremolo, vibrato, distress)
            let voiceChars = voiceAnalyzer.analyze(samples: samples, sampleRate: sampleRate)

            // Update pattern tracker for temporal analysis
            let timestamp = Date()
            let patterns = patternTracker.update(
                isCrying: mlDetection.isCryDetected || cryAnalysis.isCryLike,
                intensity: mlDetection.intensity,
                type: cryType,
                timestamp: timestamp
            )

            // Blend confidences: ML weight = mlBlendRatio, rule-based = (1 - mlBlendRatio)
            let blendedConfidence = (mlConfidence * mlBlendRatio) + (confidence * (1.0 - mlBlendRatio))
            confidence = blendedConfidence

            // If ML detects cry but rule-based doesn't (or vice versa), use the higher confidence
            if mlCryDetected && !cryAnalysis.isCryLike && mlConfidence > 0.7 {
                // Trust ML detection for high-confidence cases
                confidence = max(confidence, mlConfidence)
            }

            // Update published ML state on main thread
            Task { @MainActor in
                self.latestExtendedFeatures = features
                self.latestVoiceCharacteristics = voiceChars
                self.latestPatternMetrics = patterns
            }
        }
        // ========== End ML Enhancement ==========

        // 7. Create frame and add to pattern buffer
        let isCryLike = useMLEnhancement ? (cryAnalysis.isCryLike || mlCryDetected) : cryAnalysis.isCryLike

        let frame = CryFrame(
            timestamp: Date(),
            fundamentalPower: cryAnalysis.fundamentalPower,
            harmonicPower: cryAnalysis.harmonicPower,
            overallLevel: rms,
            spectralCentroid: cryAnalysis.spectralCentroid,
            isCryLike: isCryLike,
            cryType: cryType,
            confidence: confidence
        )

        updatePatternBuffer(with: frame)

        // 8. Evaluate detection based on pattern
        evaluateDetection()
    }

    // MARK: - FFT Analysis
    private func performFFT(on samples: [Float]) {
        guard let fftSetup = fftSetup else { return }

        // Prepare split complex arrays
        var realInput = samples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Perform DFT
        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitudes using withUnsafeMutableBufferPointer to ensure pointer lifetime
        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imagOutput.withUnsafeMutableBufferPointer { imagBuffer in
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Normalize
        var scaleFactor: Float = 2.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(fftSize / 2))
    }

    // MARK: - Cry Characteristics Analysis
    private struct CryAnalysis {
        let fundamentalPower: Float
        let harmonicPower: Float
        let spectralCentroid: Float
        let spectralFlatness: Float
        let zeroCrossingRate: Float
        let isCryLike: Bool
    }

    private func analyzeCryCharacteristics() -> CryAnalysis {
        let frequencyResolution = sampleRate / Float(fftSize)

        // Calculate power in cry frequency ranges
        let fundamentalPower = calculateBandPower(range: cryFrequencyRange, resolution: frequencyResolution)
        let harmonicPower = calculateBandPower(range: cryHarmonicsRange, resolution: frequencyResolution)
        // High harmonic power calculated but not currently used - reserved for future enhancement
        _ = calculateBandPower(range: attentionFrequencyRange, resolution: frequencyResolution)

        // Calculate spectral centroid (brightness indicator)
        let spectralCentroid = calculateSpectralCentroid(resolution: frequencyResolution)

        // Calculate spectral flatness (tonality vs noise)
        let spectralFlatness = calculateSpectralFlatness()

        // Zero crossing rate approximation
        let zeroCrossingRate: Float = 0 // Would need time-domain analysis

        // Determine if this sounds like a cry
        // Baby cries have: strong fundamental (300-600Hz), harmonics present, tonal quality
        let isCryLike = fundamentalPower > adaptiveThreshold &&
                        harmonicPower > fundamentalPower * 0.3 &&
                        spectralCentroid > 500 && spectralCentroid < 2000 &&
                        spectralFlatness < 0.5 // More tonal than noise

        return CryAnalysis(
            fundamentalPower: fundamentalPower,
            harmonicPower: harmonicPower,
            spectralCentroid: spectralCentroid,
            spectralFlatness: spectralFlatness,
            zeroCrossingRate: zeroCrossingRate,
            isCryLike: isCryLike
        )
    }

    private func calculateBandPower(range: ClosedRange<Float>, resolution: Float) -> Float {
        let startBin = Int(range.lowerBound / resolution)
        let endBin = min(Int(range.upperBound / resolution), magnitudes.count - 1)

        guard startBin < endBin && startBin >= 0 else { return 0 }

        var power: Float = 0
        vDSP_sve(Array(magnitudes[startBin...endBin]), 1, &power, vDSP_Length(endBin - startBin + 1))
        return power / Float(endBin - startBin + 1)
    }

    private func calculateSpectralCentroid(resolution: Float) -> Float {
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0

        for i in 0..<magnitudes.count {
            let frequency = Float(i) * resolution
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }

        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private func calculateSpectralFlatness() -> Float {
        // Geometric mean / Arithmetic mean
        // Lower values = more tonal, Higher values = more noise-like

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

    // MARK: - Cry Type Classification
    private func classifyCryType(analysis: CryAnalysis) -> CryType {
        guard analysis.isCryLike else { return .unknown }

        // Classification based on spectral characteristics
        // Research shows different cry types have distinct acoustic signatures

        let fundamentalRatio = analysis.fundamentalPower / (analysis.harmonicPower + 0.001)
        let centroid = analysis.spectralCentroid

        // Hunger cry: rhythmic, lower pitch, moderate intensity
        if centroid < 700 && fundamentalRatio > 1.5 {
            return .hunger
        }

        // Pain/discomfort cry: sudden onset, higher pitch, intense
        if centroid > 1200 && analysis.fundamentalPower > adaptiveThreshold * 2 {
            return .pain
        }

        // Tired cry: lower intensity, somewhat irregular
        if analysis.fundamentalPower < adaptiveThreshold * 1.5 && centroid < 900 {
            return .tired
        }

        // Attention-seeking: moderate pitch, building intensity
        if centroid > 800 && centroid < 1200 {
            return .attention
        }

        // Discomfort: variable pitch, sustained
        if analysis.harmonicPower > analysis.fundamentalPower * 0.8 {
            return .discomfort
        }

        return .general
    }

    // MARK: - Confidence Calculation
    private func calculateConfidence(analysis: CryAnalysis, type: CryType) -> Double {
        guard analysis.isCryLike else { return 0 }

        var confidence: Double = 0

        // Base confidence from spectral analysis
        let powerScore = Double(min(analysis.fundamentalPower / (adaptiveThreshold * 3), 1.0))
        confidence += powerScore * 0.3

        // Tonal quality contribution
        let tonalScore = Double(1.0 - analysis.spectralFlatness)
        confidence += tonalScore * 0.25

        // Harmonic structure contribution
        let harmonicScore = Double(min(analysis.harmonicPower / analysis.fundamentalPower, 1.0))
        confidence += harmonicScore * 0.2

        // Spectral centroid in expected range
        let centroidScore = analysis.spectralCentroid > 400 && analysis.spectralCentroid < 2000 ? 0.15 : 0.05
        confidence += centroidScore

        // Pattern consistency bonus (from history)
        if cryTypeHistory.suffix(5).allSatisfy({ $0 == type || $0 == .unknown }) {
            confidence += 0.1
        }

        return min(confidence, 1.0)
    }

    // MARK: - Pattern Buffer Management
    private func updatePatternBuffer(with frame: CryFrame) {
        cryPatternBuffer.append(frame)

        // Maintain buffer size
        if cryPatternBuffer.count > patternBufferSize {
            cryPatternBuffer.removeFirst()
        }

        // Update cry type history
        if frame.isCryLike {
            cryTypeHistory.append(frame.cryType)
            if cryTypeHistory.count > cryTypeHistorySize {
                cryTypeHistory.removeFirst()
            }
        }
    }

    private func handleQuietFrame() {
        // Decrement consecutive cry frames when quiet
        if consecutiveCryFrames > 0 {
            consecutiveCryFrames -= 1
        }

        // Check if cry has ended
        if isCryDetected && consecutiveCryFrames < minCryFramesForDetection / 2 {
            Task { @MainActor in
                self.isCryDetected = false
                self.detectionStatus = .listening
                self.onCryEnded?()
            }
        }
    }

    // MARK: - Detection Evaluation
    private func evaluateDetection() {
        let recentFrames = cryPatternBuffer.suffix(15)
        let cryLikeFrames = recentFrames.filter { $0.isCryLike }

        if cryLikeFrames.count >= minCryFramesForDetection {
            consecutiveCryFrames += 1
        } else {
            consecutiveCryFrames = max(0, consecutiveCryFrames - 1)
        }

        // Calculate average confidence from recent cry frames
        let avgConfidence = cryLikeFrames.isEmpty ? 0 :
            cryLikeFrames.reduce(0.0) { $0 + $1.confidence } / Double(cryLikeFrames.count)

        // Calculate intensity
        let avgPower = cryLikeFrames.isEmpty ? 0 :
            cryLikeFrames.reduce(Float(0)) { $0 + $1.fundamentalPower } / Float(cryLikeFrames.count)
        let intensity = Double(min(avgPower / (adaptiveThreshold * 5), 1.0))

        // Determine dominant cry type
        let dominantType = determineDominantCryType()

        // Detection decision
        let shouldDetect = consecutiveCryFrames >= minCryFramesForDetection && avgConfidence >= minCryConfidence

        Task { @MainActor in
            self.confidenceLevel = avgConfidence
            self.cryIntensity = intensity
            self.cryType = dominantType

            if shouldDetect && !self.isCryDetected {
                self.isCryDetected = true
                self.detectionStatus = .cryDetected
                self.onCryDetected?(dominantType, avgConfidence)
            } else if !shouldDetect && self.isCryDetected && consecutiveCryFrames < minCryFramesForDetection / 3 {
                self.isCryDetected = false
                self.detectionStatus = .listening
            }
        }
    }

    private func determineDominantCryType() -> CryType {
        guard !cryTypeHistory.isEmpty else { return .unknown }

        var typeCounts: [CryType: Int] = [:]
        for type in cryTypeHistory {
            typeCounts[type, default: 0] += 1
        }

        return typeCounts.max(by: { $0.value < $1.value })?.key ?? .unknown
    }

    // MARK: - Ambient Noise Calibration
    private func calibrateAmbientNoise() {
        // Wait 2 seconds and measure ambient noise level
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.ambientNoiseLevel = self.currentAudioLevel * 1.2 // Add margin
            self.adaptiveThreshold = max(0.1, self.ambientNoiseLevel * 2)
        }
    }

    // MARK: - Cleanup
    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}

// MARK: - Cry Type Enum
enum CryType: String, Codable, CaseIterable {
    case hunger = "Hungry"
    case tired = "Tired"
    case pain = "Pain/Discomfort"
    case attention = "Wants Attention"
    case discomfort = "Uncomfortable"
    case general = "Crying"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .hunger: return "fork.knife"
        case .tired: return "moon.zzz"
        case .pain: return "bandage"
        case .attention: return "hand.wave"
        case .discomfort: return "thermometer"
        case .general: return "waveform"
        case .unknown: return "questionmark.circle"
        }
    }

    var suggestedAction: String {
        switch self {
        case .hunger:
            return "Baby might be hungry. Consider feeding."
        case .tired:
            return "Baby seems tired. Soothing sounds can help."
        case .pain:
            return "Baby may be in discomfort. Check for causes."
        case .attention:
            return "Baby wants interaction or comfort."
        case .discomfort:
            return "Check diaper, temperature, or position."
        case .general:
            return "Playing calming sounds to soothe."
        case .unknown:
            return "Monitoring for cry patterns..."
        }
    }

    /// Recommended soothing strategy for this cry type
    var soothingStrategy: SoothingStrategy {
        switch self {
        case .hunger:
            return .distraction // Temporary until feeding
        case .tired:
            return .sleepInduction
        case .pain:
            return .urgent // Needs attention first
        case .attention:
            return .comfort
        case .discomfort:
            return .gentle
        case .general:
            return .adaptive
        case .unknown:
            return .adaptive
        }
    }
}

// MARK: - Soothing Strategy
enum SoothingStrategy: String {
    case sleepInduction = "Sleep Induction"
    case distraction = "Distraction"
    case comfort = "Comfort"
    case gentle = "Gentle Calming"
    case urgent = "Urgent Response"
    case adaptive = "Adaptive"

    var phases: [SoothingPhase] {
        switch self {
        case .sleepInduction:
            return [.gentleStart, .deepCalming, .sleepTransition]
        case .distraction:
            return [.attentionGrab, .engagement, .gentleCalm]
        case .comfort:
            return [.warmStart, .steadyComfort, .maintenance]
        case .gentle:
            return [.softStart, .gradualCalming, .maintenance]
        case .urgent:
            return [.immediateResponse, .intensiveCalming, .recovery]
        case .adaptive:
            return [.attentionGrab, .evaluation, .adaptiveResponse]
        }
    }
}

enum SoothingPhase: String {
    case gentleStart = "Gentle Start"
    case attentionGrab = "Getting Attention"
    case warmStart = "Warm Start"
    case softStart = "Soft Start"
    case immediateResponse = "Immediate Response"
    case deepCalming = "Deep Calming"
    case engagement = "Engagement"
    case steadyComfort = "Steady Comfort"
    case gradualCalming = "Gradual Calming"
    case intensiveCalming = "Intensive Calming"
    case evaluation = "Evaluating Response"
    case adaptiveResponse = "Adaptive Response"
    case sleepTransition = "Sleep Transition"
    case gentleCalm = "Gentle Calm"
    case maintenance = "Maintenance"
    case recovery = "Recovery"
}

// MARK: - Errors
enum CryDetectionError: Error, LocalizedError {
    case microphoneAccessDenied
    case engineSetupFailed
    case analysisError(String)

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required for cry detection"
        case .engineSetupFailed:
            return "Failed to setup audio analysis engine"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        }
    }
}
