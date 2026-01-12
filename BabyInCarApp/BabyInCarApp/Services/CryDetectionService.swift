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
import UIKit

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
    /// MEMORY SAFETY: Auto-detected based on device RAM (4GB+ = enabled)
    /// Configured in configureMLBasedOnDeviceCapability() during init
    var useMLEnhancement: Bool = true  // FIXED: Auto-detect in init, default to true for modern devices

    /// Whether to use DeepInfant pre-trained model (more accurate but heavier)
    /// MEMORY SAFETY: Auto-detected based on device RAM (4GB+ = enabled)
    var useDeepInfant: Bool = true  // FIXED: Auto-detect in init, default to true for modern devices

    /// Blend ratio: 0 = all rule-based, 1 = all ML
    var mlBlendRatio: Double = 0.6

    // MEMORY FIX (Priority 1): REMOVED duplicate ML instance allocations
    // These were lazy-loaded but NEVER used - all processing uses shared singletons below!
    // Removing saves 18-27MB of permanent memory allocation
    // OLD (deleted):
    //   private lazy var advancedFeatureExtractor = AdvancedFeatureExtractor(fftSize: fftSize)
    //   private lazy var mlCryDetector = CryDetectorMLModel()
    //   private lazy var mlCryClassifier = CryClassifierMLModel()
    //   private lazy var deepInfantClassifier: DeepInfantClassifierProtocol = DeepInfantClassifier()

    /// DeepInfant V2 classifier (pre-trained model, ~89% accuracy)
    /// Uses DeepInfantClassifier from Services/ML/
    /// MEMORY: Shared singleton accessed via getSharedDeepInfant()
    private lazy var deepInfantClassifierInstance: DeepInfantClassifierProtocol = DeepInfantClassifier()

    /// Audio buffer for DeepInfant (needs ~2 seconds at 16kHz for reasonable accuracy)
    /// MEMORY SAFETY: Pre-allocated circular buffer to prevent unbounded growth
    /// REDUCED from 64KB to 32KB to save memory (2 seconds instead of 4)
    private var deepInfantBuffer: [Float] = []
    private let deepInfantBufferSize: Int = 32000  // 2 seconds at 16kHz (was 64000)
    private var deepInfantBufferWriteIndex: Int = 0  // Circular buffer write position
    private var deepInfantLastClassification: Date = .distantPast
    private let deepInfantClassificationInterval: TimeInterval = 3.0  // THERMAL FIX: Run every 3 seconds (was 2) - reduces ML CPU load by 33%

    // MEMORY FIX (Priority 4): Thread-safe buffer access
    // NSLock is Sendable - no nonisolated(unsafe) needed
    private let bufferLock = NSLock()

    /// MEMORY SAFETY: Reusable ML model instances (avoid per-frame allocation)
    /// These are created once and reused for thread-safe inference
    private let reusableCryDetector = CryDetectorMLModel()
    private let reusableCryClassifier = CryClassifierMLModel()
    private let reusableFeatureExtractor: AdvancedFeatureExtractor
    private let reusableVoiceAnalyzer = VoiceCharacteristicsAnalyzer()

    // MEMORY FIX: Thread-safe shared ML instances for background processing
    // These are stateless and can be safely shared across threads
    // Created once, used forever - prevents ~90 allocations/second memory leak!
    // NOTE: nonisolated(unsafe) required for @MainActor class with static properties accessed from nonisolated contexts
    private nonisolated(unsafe) static let sharedCryDetector = CryDetectorMLModel()
    private nonisolated(unsafe) static let sharedCryClassifier = CryClassifierMLModel()
    private nonisolated(unsafe) static let sharedVoiceAnalyzer = VoiceCharacteristicsAnalyzer()
    private nonisolated(unsafe) static var sharedFeatureExtractor: AdvancedFeatureExtractor?
    // NSLock requires nonisolated(unsafe) when accessed from nonisolated static functions in Swift 6
    private nonisolated(unsafe) static let featureExtractorLock = NSLock()

    // MEMORY FIX: Shared DeepInfant instance (singleton pattern)
    private nonisolated(unsafe) static var sharedDeepInfant: DeepInfantClassifierProtocol?
    // NSLock requires nonisolated(unsafe) when accessed from nonisolated static functions in Swift 6
    private nonisolated(unsafe) static let deepInfantLock = NSLock()

    /// Get or create shared feature extractor for background thread (thread-safe)
    private nonisolated static func getSharedFeatureExtractor(fftSize: Int) -> AdvancedFeatureExtractor {
        featureExtractorLock.lock()
        defer { featureExtractorLock.unlock() }

        if sharedFeatureExtractor == nil {
            sharedFeatureExtractor = AdvancedFeatureExtractor(fftSize: fftSize)
        }
        return sharedFeatureExtractor!
    }

    /// Get or create shared DeepInfant classifier (thread-safe)
    private nonisolated static func getSharedDeepInfant() -> DeepInfantClassifierProtocol {
        deepInfantLock.lock()
        defer { deepInfantLock.unlock() }

        if sharedDeepInfant == nil {
            sharedDeepInfant = DeepInfantClassifier()
        }
        return sharedDeepInfant!
    }

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

    /// Latest ML classification result (includes all probabilities)
    @Published var latestClassification: CryClassification?

    // MARK: - UI Update Throttling (THERMAL OPTIMIZATION)
    // Prevents main thread flooding AND reduces CPU usage
    // CRITICAL: Audio processing at 30Hz causes significant heat on sustained use
    // UI updates throttled to 5Hz max (was 10Hz) - still smooth, much cooler
    private var lastUIUpdateTime: Date = .distantPast
    private let minUIUpdateInterval: TimeInterval = 0.2  // 200ms = 5 updates/second max (was 0.1)

    /// Throttled audio level for UI (updated at 5Hz max)
    @Published var throttledAudioLevel: Float = 0

    /// Throttled confidence for UI (updated at 5Hz max)
    @Published var throttledConfidence: Double = 0

    // MARK: - Diagnostic Logging Throttling
    private nonisolated(unsafe) var lastQuietLog = Date.distantPast
    private nonisolated(unsafe) var lastAnalysisLog = Date.distantPast

    // MARK: - Audio Frame Throttling (THERMAL FIX)
    // Skip 50% of audio frames to reduce CPU usage - cry detection still works at 10Hz
    // At 44.1kHz with 2048 buffer = ~21 callbacks/sec; processing every other = ~10/sec (plenty for cry detection)
    private var audioFrameCounter: Int = 0
    private let processEveryNthFrame: Int = 2  // Process every 2nd frame = 50% CPU reduction

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
    // MEMORY SAFETY: Reduced from 4096 to 2048 to save ~50% FFT memory
    // 2048 samples at 44.1kHz = ~46ms window, still sufficient for cry detection
    // Frequency resolution: 44100/2048 = 21.5Hz (good enough for 200-600Hz cry fundamentals)
    private let fftSize: Int = 2048  // REDUCED from 4096
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []
    private var magnitudes: [Float] = []

    // MEMORY FIX: Thread-safe FFT setup for background processing
    // Created once and reused - prevents ~30 allocations/second memory leak!
    // NOTE: nonisolated(unsafe) required for @MainActor class with static properties accessed from nonisolated contexts
    private nonisolated(unsafe) static var sharedBackgroundFFTSetup: vDSP_DFT_Setup?
    // NSLock requires nonisolated(unsafe) when accessed from nonisolated static functions in Swift 6
    private nonisolated(unsafe) static let fftSetupLock = NSLock()

    /// Get or create shared FFT setup for background thread (thread-safe)
    private nonisolated static func getBackgroundFFTSetup(size: Int) -> vDSP_DFT_Setup? {
        fftSetupLock.lock()
        defer { fftSetupLock.unlock() }

        if sharedBackgroundFFTSetup == nil {
            sharedBackgroundFFTSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), .FORWARD)
        }
        return sharedBackgroundFFTSetup
    }

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
    private let patternBufferSize = 60 // FALSE POSITIVE FIX: Increased from 30 to 60 (~2s at 30fps) for sustained detection
    private var consecutiveCryFrames: Int = 0
    // AGGRESSIVE 2026-01-09: Relaxed from 12 to 8 frames (~0.27s)
    // Faster detection - speech filter is primary defense
    private let minCryFramesForDetection = 8 // ~0.27 second of consistent cry pattern

    // CRITICAL FIX: Require sustained cry detection to prevent false positives
    // Baby cries are SUSTAINED sounds, not brief vocalizations
    private var sustainedCryStartTime: Date?
    // AGGRESSIVE 2026-01-09: Relaxed from 1.5s to 0.8s for faster response
    // We want quick detection - speech filter handles false positives
    private let minSustainedCryDuration: TimeInterval = 0.8 // Require 0.8 seconds of sustained cry

    // Speech vs cry differentiation
    // Human speech typically has rapid spectral changes, cries are more monotonic
    // AGGRESSIVE 2026-01-09: Raised threshold from 0.6 to 0.8
    // Audio from speakers (YouTube) can have higher variance due to compression
    // Only filter very high variance speech patterns
    private var spectralVarianceHistory: [Float] = []
    private let speechVarianceThreshold: Float = 0.8 // Very high variance = likely speech

    // Adaptive thresholds - CONSERVATIVE defaults to prevent false positives
    private var ambientNoiseLevel: Float = 0.02  // Will be calibrated on start (RMS scale: 0-1)
    private var adaptiveThreshold: Float = 0.18  // RMS threshold for detection (0-1 scale)
    // CRITICAL FIX: FFT power threshold is much smaller than RMS!
    // FFT magnitudes after 2/N scaling are typically 0.0003-0.01 for audio
    // AGGRESSIVE 2026-01-09: Lowered from 0.001 to 0.0003
    // Logs showed real cries with power as low as 0.00045
    // Speech detection is the primary filter, not power threshold
    private var fftPowerThreshold: Float = 0.0003 // FFT power threshold (will be calibrated)
    // AGGRESSIVE 2026-01-09: Relaxed from 60% to 45%
    // Lower threshold for faster detection - speech filter handles false positives
    private let minCryConfidence: Double = 0.45  // 45% confidence minimum
    private var isCalibrated: Bool = false       // Track calibration status

    // Cry type classification history
    private var cryTypeHistory: [CryType] = []
    private let cryTypeHistorySize = 15
    private var detectionHistory: [Date] = []  // Track detection events for memory cleanup

    // STABLE CRY TYPE: Lock-in mechanism to prevent classification flip-flopping
    // Once a cry type is confidently detected, it stays locked for a minimum duration
    private var lockedCryType: CryType? = nil
    private var cryTypeLockTime: Date? = nil
    private let cryTypeLockDuration: TimeInterval = 3.0 // Keep same type for at least 3 seconds

    // CRY STATE TIMEOUT: Force reset cry detection state if no cry-like audio for too long
    // Prevents the "stuck in cry detected state" issue when baby stops crying but state persists
    // SILENCE FIX 2026-01-11: Reduced from 5s to 2s for much quicker state reset during silence
    // Users reported "CRY DETECTED" badge persisting during complete silence
    private var lastCryLikeFrameTime: Date? = nil
    private let cryStateTimeoutDuration: TimeInterval = 2.0 // Reset after 2 seconds of no cry-like audio

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
        // Initialize reusable feature extractor with FFT size
        reusableFeatureExtractor = AdvancedFeatureExtractor(fftSize: fftSize)

        // Pre-allocate DeepInfant buffer to prevent runtime allocation
        deepInfantBuffer.reserveCapacity(deepInfantBufferSize)

        setupFFT()

        // SMART ML AUTO-ENABLE: Only enable ML on devices with enough RAM
        // This prevents crashes on older devices while enabling better detection on newer ones
        configureMLBasedOnDeviceCapability()

        // MEMORY OPTIMIZATION (Increment 0028): Setup memory cleanup handlers
        setupMemoryObservers()
    }

    // MARK: - Memory Management

    /// Setup memory cleanup observers
    private func setupMemoryObservers() {
        // MEMORY OPTIMIZATION (Increment 0028, Enhanced 0029): Clean up on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("[CryDetection] ⚠️ Memory warning received - aggressive cleanup")
                self?.cleanup(aggressive: true)
            }
        }

        // MEMORY OPTIMIZATION (Increment 0028, Enhanced 0029): Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let level = notification.userInfo?["level"] as? String {
                    // Use aggressive cleanup for critical and emergency levels
                    let isAggressive = (level == "critical" || level == "emergency")
                    print("[CryDetection] 🧹 Memory cleanup requested (\(level), aggressive: \(isAggressive))")
                    self?.cleanup(aggressive: isAggressive)
                }
            }
        }

        // MEMORY OPTIMIZATION (Increment 0029): Restore ML when memory normalizes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryPressureNormalized"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restoreMLIfCapable()
            }
        }
    }

    /// Clean up resources to reduce memory footprint
    /// - Parameter aggressive: If true, performs more aggressive cleanup including ML model release
    private func cleanup(aggressive: Bool = false) {
        print("[CryDetection] 🧹 Starting memory cleanup (aggressive: \(aggressive))...")

        // MEMORY OPTIMIZATION (Increment 0029): Use autoreleasepool for immediate deallocation
        autoreleasepool {
            // Clear DeepInfant audio buffer
            let bufferSize = deepInfantBuffer.count
            if aggressive {
                // Aggressive: Release buffer entirely, will be reallocated when needed
                deepInfantBuffer = []
                print("[CryDetection] 🧹 Released DeepInfant buffer entirely (\(bufferSize) samples)")
            } else {
                // Normal: Keep capacity to avoid reallocation
                deepInfantBuffer.removeAll(keepingCapacity: true)
                print("[CryDetection] 🧹 Cleared DeepInfant buffer (\(bufferSize) samples)")
            }

            // Clear detection history
            let historyCount = detectionHistory.count
            if aggressive {
                // Aggressive: Clear all history
                detectionHistory.removeAll()
                print("[CryDetection] 🧹 Cleared all detection history (\(historyCount) entries)")
            } else if historyCount > 5 {
                // Normal: Keep last 5
                detectionHistory = Array(detectionHistory.suffix(5))
                print("[CryDetection] 🧹 Trimmed detection history (kept 5 most recent, removed \(historyCount - 5))")
            }

            // Clear cry type history
            if aggressive {
                let cryHistoryCount = cryTypeHistory.count
                cryTypeHistory.removeAll()
                print("[CryDetection] 🧹 Cleared cry type history (\(cryHistoryCount) entries)")
            }

            // Clear spectral variance history
            if aggressive {
                let varianceCount = spectralVarianceHistory.count
                spectralVarianceHistory.removeAll()
                print("[CryDetection] 🧹 Cleared spectral variance history (\(varianceCount) entries)")
            }

            // Clear pattern buffer
            if aggressive {
                let patternCount = cryPatternBuffer.count
                cryPatternBuffer.removeAll()
                print("[CryDetection] 🧹 Cleared cry pattern buffer (\(patternCount) frames)")
            }

            // MEMORY OPTIMIZATION (Increment 0029, Enhanced Priority 3): Disable ML and release models during aggressive cleanup
            if aggressive && useMLEnhancement {
                // Temporarily disable ML features to save memory
                useMLEnhancement = false
                useDeepInfant = false
                print("[CryDetection] 🧹 Disabled ML features due to memory pressure")

                // MEMORY FIX (Priority 3): Release shared ML model instances
                // These will be recreated when ML is re-enabled
                Self.featureExtractorLock.lock()
                Self.sharedFeatureExtractor = nil
                Self.featureExtractorLock.unlock()

                Self.deepInfantLock.lock()
                Self.sharedDeepInfant = nil
                Self.deepInfantLock.unlock()

                print("[CryDetection] 🧹 Released shared ML model instances (~20-30MB freed)")
                print("[CryDetection] ⚠️ ML will be re-enabled when memory normalizes")
            }

            // Reset transient state if not actively monitoring
            if !isMonitoring {
                currentAudioLevel = 0
                cryIntensity = 0
                consecutiveCryFrames = 0
                sustainedCryStartTime = nil
                print("[CryDetection] 🧹 Reset transient state (not monitoring)")
            }
        }

        print("[CryDetection] ✅ Memory cleanup complete")
    }

    /// Re-enable ML features after memory pressure subsides
    /// Called when MemoryPressureNormalized notification is received
    private func restoreMLIfCapable() {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let totalRAMGB = Double(totalRAM) / (1024 * 1024 * 1024)

        // Only restore if device has enough RAM
        if totalRAMGB >= 4.0 && !useMLEnhancement {
            useMLEnhancement = true
            useDeepInfant = true
            print("[CryDetection] ✅ Restored ML features after memory normalized")
        }
    }

    /// Configure ML features based on device RAM
    /// Enables ML only on devices with 4GB+ RAM (iPhone 11 and newer)
    private func configureMLBasedOnDeviceCapability() {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let totalRAMGB = Double(totalRAM) / (1024 * 1024 * 1024)

        // DIAGNOSTIC: Always log device info for troubleshooting
        let device = UIDevice.current
        print("[CryDetection] 📱 Device: \(device.model), iOS \(device.systemVersion)")
        print("[CryDetection] 💾 RAM: \(String(format: "%.1f", totalRAMGB))GB")

        // Enable ML features only on devices with 4GB+ RAM
        // iPhone 11 and newer have 4GB+, older devices have 2-3GB
        if totalRAMGB >= 4.0 {
            useMLEnhancement = true
            useDeepInfant = true
            print("[CryDetection] 🧠 ML ENABLED - sufficient RAM for ML classification")

            // DIAGNOSTIC: Check if DeepInfant model is actually available
            let classifier = Self.getSharedDeepInfant()
            let modelLoaded = classifier.isModelLoaded
            if modelLoaded {
                print("[CryDetection] ✅ DeepInfant CoreML model LOADED successfully")
            } else {
                print("[CryDetection] ⚠️ DeepInfant model NOT loaded - will use standard ML classifier only")
                print("[CryDetection]    Check if DeepInfant_V2.mlmodel is in the Xcode project")
                // Still keep ML enabled for the standard classifier
            }
        } else {
            useMLEnhancement = false
            useDeepInfant = false
            print("[CryDetection] ⚡ ML DISABLED - low RAM device (\(String(format: "%.1f", totalRAMGB))GB < 4GB threshold)")
            print("[CryDetection]    Using rule-based detection only")
        }
    }

    /// Manually enable/disable ML features
    /// Call this to override auto-detection
    func setMLEnabled(_ enabled: Bool) {
        useMLEnhancement = enabled
        useDeepInfant = enabled
        print("[CryDetection] ML manually set to: \(enabled)")
    }

    // MARK: - Memory Safety

    /// Thread-safe memory check using Darwin task_info
    /// Returns true if memory usage is high (> 120MB) and we should skip heavy processing
    nonisolated static func isMemoryConstrained() -> Bool {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return false }
        let memoryMB = Double(info.resident_size) / (1024 * 1024)
        return memoryMB > 120  // Skip heavy ML if > 120MB
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

        // FIX: Release any existing engine to prevent "invalid reuse after initialization failure"
        // This ensures we always start with a fresh engine
        if audioEngine != nil {
            audioEngine?.stop()
            audioEngine = nil
        }

        try setupAudioEngine()

        do {
            try audioEngine?.start()
        } catch {
            // FIX: If engine fails to start, release it to prevent invalid reuse
            print("[CryDetection] ❌ Failed to start audio engine: \(error)")
            audioEngine = nil
            detectionStatus = .error
            throw CryDetectionError.engineSetupFailed
        }

        isMonitoring = true
        detectionStatus = .listening

        // Start ambient noise calibration
        calibrateAmbientNoise()
    }

    func stopMonitoring() {
        // PERFORMANCE FIX: Update UI state IMMEDIATELY before blocking operations
        // This makes the UI feel responsive while cleanup happens in background
        isMonitoring = false
        isCryDetected = false
        cryIntensity = 0
        confidenceLevel = 0
        cryType = .unknown
        detectionStatus = .idle

        // Capture references for background cleanup
        let engineToStop = audioEngine
        audioEngine = nil

        // PERFORMANCE FIX: Release session with immediate=true to bypass 100ms debounce
        // This prevents the UI from appearing stuck while waiting for debounce timer
        AudioSessionManager.shared.releaseSession(serviceId: "CryDetectionService", immediate: true)

        // PERFORMANCE FIX: Move blocking I/O operations to background thread
        // removeTap() and engine.stop() are synchronous I/O that can block for 50-100ms
        Task.detached(priority: .userInitiated) {
            engineToStop?.stop()
            engineToStop?.inputNode.removeTap(onBus: 0)
            print("[CryDetection] ✅ Audio engine stopped in background")
        }

        // Reset state (fast in-memory operations)
        consecutiveCryFrames = 0
        cryPatternBuffer.removeAll()
        clearDeepInfantBuffer()

        // Reset sustained cry tracking
        sustainedCryStartTime = nil
        lastCryLikeFrameTime = nil  // Reset timeout tracker
        spectralVarianceHistory.removeAll()
        cryTypeHistory.removeAll()
        isCalibrated = false // Require re-calibration on next start

        // Reset cry type lock-in (fresh detection on next start)
        lockedCryType = nil
        cryTypeLockTime = nil
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

        // Use centralized AudioSessionManager for session configuration
        // This prevents conflicts with AudioEngine and other audio services
        // activateSessionSync bypasses debounce to ensure session is ready BEFORE accessing inputNode
        do {
            try AudioSessionManager.shared.activateSessionSync(
                mode: .playAndRecord,
                priority: .monitoring,
                serviceId: "CryDetectionService"
            )
            print("[CryDetection] ✅ Audio session configured via AudioSessionManager")
        } catch {
            print("[CryDetection] ❌ Audio session setup failed: \(error)")
            throw CryDetectionError.engineSetupFailed
        }

        inputNode = engine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)

        // Validate format before installing tap
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("[CryDetection] ❌ Invalid audio format: \(recordingFormat)")
            throw CryDetectionError.engineSetupFailed
        }

        // Install tap for audio analysis
        // MEMORY FIX: Wrap callback in autoreleasepool to prevent accumulation of temporary objects
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(fftSize)
        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            autoreleasepool {
                self?.processAudioBuffer(buffer)
            }
        }
    }

    // MARK: - Audio Processing Pipeline
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // THERMAL FIX: Skip frames to reduce CPU load
        // Processing at ~10Hz instead of ~21Hz is still plenty for cry detection
        audioFrameCounter += 1
        guard audioFrameCounter % processEveryNthFrame == 0 else {
            return  // Skip this frame
        }

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // Convert to array for processing
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // Capture values needed for analysis
        let fftSizeLocal = fftSize
        let windowLocal = window
        let ambientNoiseLevelLocal = ambientNoiseLevel
        let adaptiveThresholdLocal = adaptiveThreshold
        let fftPowerThresholdLocal = fftPowerThreshold  // CRITICAL: Separate FFT threshold
        let useMLEnhancementLocal = useMLEnhancement
        let mlBlendRatioLocal = mlBlendRatio
        let sampleRateLocal = sampleRate
        let isCalibrated = isCalibrated  // Capture calibration status

        analysisQueue.async { [weak self] in
            self?.analyzeAudioNonIsolated(
                samples: samples,
                fftSize: fftSizeLocal,
                window: windowLocal,
                ambientNoiseLevel: ambientNoiseLevelLocal,
                adaptiveThreshold: adaptiveThresholdLocal,
                fftPowerThreshold: fftPowerThresholdLocal,  // CRITICAL: Pass FFT threshold
                useMLEnhancement: useMLEnhancementLocal,
                mlBlendRatio: mlBlendRatioLocal,
                sampleRate: sampleRateLocal,
                isCalibrated: isCalibrated
            )
        }
    }

    /// Non-isolated audio analysis that can run on background queue
    /// MEMORY FIX: Consolidated into single Task to reduce Task allocation overhead
    private nonisolated func analyzeAudioNonIsolated(
        samples: [Float],
        fftSize: Int,
        window: [Float],
        ambientNoiseLevel: Float,
        adaptiveThreshold: Float,
        fftPowerThreshold: Float,  // CRITICAL: Separate FFT threshold for isCryLike detection
        useMLEnhancement: Bool,
        mlBlendRatio: Double,
        sampleRate: Float,
        isCalibrated: Bool
    ) {
        guard samples.count >= fftSize else { return }

        // 1. Calculate RMS level
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // CRITICAL FIX: ALWAYS update audio level FIRST for UI visualization
        // This ensures the Live Audio Analysis bars work even during calibration
        // We update the level BEFORE any early returns so the UI always reflects current audio

        // During calibration: still update audio level AND accumulate for DeepInfant
        // This allows ML to start analyzing while rule-based waits for calibration
        guard isCalibrated else {
            // CRITICAL FIX: Accumulate audio for DeepInfant even during calibration!
            // This allows ML detection to work faster once calibration completes
            Task { @MainActor [weak self] in
                self?.currentAudioLevel = rms
                // Accumulate audio for DeepInfant even during calibration period
                if useMLEnhancement {
                    self?.accumulateForDeepInfant(samples: samples, sampleRate: sampleRate)
                }
            }
            return
        }

        // CRITICAL DIAGNOSTIC: Temporarily DISABLE quiet threshold to debug FFT detection
        // This allows us to see FFT power values for all frames, even quiet ones
        // TODO: Re-enable after confirming FFT thresholds are correct
        // let quietThreshold = ambientNoiseLevel * 1.2
        // guard rms > quietThreshold else {
        //     // DIAGNOSTIC: Log when audio is too quiet (throttled to reduce spam)
        //     let now = Date()
        //     if now.timeIntervalSince(lastQuietLog) > 5.0 {
        //         print("[CryDetection] 🔇 Audio too quiet: RMS=\(String(format: "%.4f", rms)) < threshold=\(String(format: "%.4f", quietThreshold)) (ambient=\(String(format: "%.4f", ambientNoiseLevel)))")
        //         lastQuietLog = now
        //     }
        //
        //     // MEMORY FIX: Combined update - audio level + quiet frame handling in single Task
        //     // CRITICAL FIX: Still accumulate for DeepInfant - ML can detect patterns rule-based misses
        //     Task { @MainActor [weak self] in
        //         self?.currentAudioLevel = rms
        //         self?.handleQuietFrame()
        //         // Still accumulate for DeepInfant even when quiet - ML is more sensitive
        //         if useMLEnhancement {
        //             self?.accumulateForDeepInfant(samples: samples, sampleRate: sampleRate)
        //         }
        //     }
        //     return
        // }

        // DIAGNOSTIC: Log when audio is being analyzed (throttled)
        let now = Date()
        if now.timeIntervalSince(lastAnalysisLog) > 3.0 {
            print("[CryDetection] 🎤 Analyzing audio: RMS=\(String(format: "%.4f", rms)), ambient=\(String(format: "%.4f", ambientNoiseLevel)), ML=\(useMLEnhancement)")
            lastAnalysisLog = now
        }

        // 2. Apply window function
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var windowCopy = window
        vDSP_vmul(samples, 1, &windowCopy, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // 3. Perform FFT
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        performFFTNonIsolated(on: windowedSamples, fftSize: fftSize, magnitudes: &magnitudes)

        // 4. Analyze frequency spectrum for cry characteristics (rule-based)
        // CRITICAL: Use fftPowerThreshold (not adaptiveThreshold) for FFT magnitude comparison
        let cryAnalysis = analyzeCryCharacteristicsNonIsolated(
            magnitudes: magnitudes,
            sampleRate: sampleRate,
            fftSize: fftSize,
            fftPowerThreshold: fftPowerThreshold  // FIXED: Use FFT-scale threshold
        )

        // 5. Classify cry type (rule-based)
        // CRITICAL: Use fftPowerThreshold for FFT-based comparisons
        var cryType = classifyCryTypeNonIsolated(analysis: cryAnalysis, fftPowerThreshold: fftPowerThreshold)

        // 6. Calculate confidence (rule-based)
        var confidence = calculateConfidenceNonIsolated(
            analysis: cryAnalysis,
            type: cryType,
            fftPowerThreshold: fftPowerThreshold  // FIXED: Use FFT-scale threshold
        )

        // Variables for ML enhancement
        var extendedFeatures: ExtendedAudioFeatures?
        var voiceChars: VoiceCharacteristics?
        var mlCryDetected = false

        if useMLEnhancement {
            // MEMORY FIX: Use shared singleton instances instead of creating new ones per frame
            // This prevents ~90 object allocations per second (major memory leak!)

            // MEMORY OPTIMIZATION: Skip ML if memory pressure is high
            let skipHeavyML = Self.isMemoryConstrained()

            // MEMORY FIX: Use shared feature extractor instead of creating new one per frame
            let features: ExtendedAudioFeatures
            if skipHeavyML {
                features = ExtendedAudioFeatures.fromBasicAnalysis(
                    intensity: Double(rms),
                    spectralCentroid: Double(cryAnalysis.spectralCentroid),
                    spectralFlatness: Double(cryAnalysis.spectralFlatness)
                )
            } else {
                // MEMORY FIX: Use shared extractor (created once, reused forever)
                features = Self.getSharedFeatureExtractor(fftSize: fftSize).extractFeatures(from: samples, sampleRate: sampleRate)
            }
            extendedFeatures = features

            // MEMORY FIX: Use shared detector (created once, reused forever)
            let mlDetection = Self.sharedCryDetector.detect(features: features)
            mlCryDetected = mlDetection.isCryDetected
            let mlConfidence = mlDetection.confidence

            // If cry detected, classify type with ML
            if mlDetection.isCryDetected || mlDetection.confidence > 0.4 {
                // MEMORY FIX: Use shared classifier (created once, reused forever)
                let classification = Self.sharedCryClassifier.classify(features: features)

                if classification.confidence > confidence {
                    cryType = classification.type
                }
            }

            // MEMORY FIX: Use shared analyzer (created once, reused forever)
            if !skipHeavyML {
                voiceChars = Self.sharedVoiceAnalyzer.analyze(samples: samples, sampleRate: sampleRate)
            }

            // Blend confidences
            let blendedConfidence = (mlConfidence * mlBlendRatio) + (confidence * (1.0 - mlBlendRatio))
            confidence = blendedConfidence

            if mlCryDetected && !cryAnalysis.isCryLike && mlConfidence > 0.7 {
                confidence = max(confidence, mlConfidence)
            }

            // DeepInfant classification (runs asynchronously on accumulated buffer)
            // MEMORY: This Task is acceptable as it runs infrequently (2 second interval)
            Task { @MainActor [weak self] in
                self?.accumulateForDeepInfant(samples: samples, sampleRate: sampleRate)
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

        // MEMORY FIX: Single consolidated Task for ALL main actor updates
        // Reduces Task allocation overhead from 3-4 Tasks per frame to 1
        // TECHNICAL DEBT FIX: Added throttling to prevent main thread flooding
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // ALWAYS update internal state (needed for detection logic)
            self.currentAudioLevel = rms

            // THROTTLE UI updates to prevent main thread flooding
            // Internal detection runs at full 30Hz, but UI updates at 10Hz max
            let now = Date()
            let shouldUpdateUI = now.timeIntervalSince(self.lastUIUpdateTime) >= self.minUIUpdateInterval

            if shouldUpdateUI {
                self.lastUIUpdateTime = now

                // Update throttled values for UI consumption
                self.throttledAudioLevel = rms
                self.throttledConfidence = confidence

                // Update ML state if applicable (UI-facing, so throttled)
                if useMLEnhancement {
                    self.latestExtendedFeatures = extendedFeatures
                    self.latestVoiceCharacteristics = voiceChars

                    let timestamp = Date()
                    let updatedPatterns = self.patternTracker.update(
                        isCrying: isCryLike,
                        intensity: Double(rms),
                        type: cryType,
                        timestamp: timestamp
                    )
                    self.latestPatternMetrics = updatedPatterns
                }
            }

            // Detection logic ALWAYS runs at full speed (not throttled)
            self.updatePatternBuffer(with: frame)
            self.evaluateDetection()
        }
    }

    /// Non-isolated FFT computation
    /// MEMORY FIX: Uses shared FFT setup instead of creating new one each frame
    /// This prevents ~30 FFT setup allocations per second (major memory leak!)
    private nonisolated func performFFTNonIsolated(on samples: [Float], fftSize: Int, magnitudes: inout [Float]) {
        // MEMORY FIX: Use shared FFT setup (created once, reused forever)
        guard let fftSetup = Self.getBackgroundFFTSetup(size: fftSize) else { return }
        // NOTE: Do NOT destroy this setup - it's shared and reused!

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
    /// CRITICAL FIX: Use fftPowerThreshold (not RMS-based adaptiveThreshold)
    /// FFT magnitudes after 2/N scaling are ~100x smaller than RMS values!
    private nonisolated func analyzeCryCharacteristicsNonIsolated(
        magnitudes: [Float],
        sampleRate: Float,
        fftSize: Int,
        fftPowerThreshold: Float  // FIXED: Proper FFT-scale threshold
    ) -> CryAnalysis {
        let frequencyResolution = sampleRate / Float(fftSize)
        let cryFrequencyRange: ClosedRange<Float> = 300...600
        let cryHarmonicsRange: ClosedRange<Float> = 600...2000

        let fundamentalPower = calculateBandPowerNonIsolated(magnitudes: magnitudes, range: cryFrequencyRange, resolution: frequencyResolution)
        let harmonicPower = calculateBandPowerNonIsolated(magnitudes: magnitudes, range: cryHarmonicsRange, resolution: frequencyResolution)
        let spectralCentroid = calculateSpectralCentroidNonIsolated(magnitudes: magnitudes, resolution: frequencyResolution)
        let spectralFlatness = calculateSpectralFlatnessNonIsolated(magnitudes: magnitudes)

        // BALANCED 2026-01-09: Relaxed isCryLike criteria
        // Previous settings were too strict - real baby cries weren't passing
        //
        // RELAXED CRITERIA for isCryLike:
        // 1. Power just above threshold (1.0x, was 2x) - many real cries have lower power
        // 2. Spectral centroid in wide baby range (300-3000 Hz) - harmonics can be high
        // 3. Moderate harmonic content (0.2 ratio) - some cries have weaker harmonics
        // 4. Moderate spectral flatness (<0.6) - allows more variation
        let powerRatio = fundamentalPower / fftPowerThreshold
        let isCryLike = powerRatio > 1.0 &&  // Just above threshold (relaxed from 2x)
                        harmonicPower > fundamentalPower * 0.2 &&  // Relaxed from 0.3
                        spectralCentroid > 300 && spectralCentroid < 3000 &&  // Widened range
                        spectralFlatness < 0.6  // Relaxed from 0.5

        // CRITICAL DIAGNOSTIC: Always log FFT analysis to debug threshold issues
        // This helps identify if FFT power is lower than expected
        #if DEBUG
        struct DebugState { static var frameCount = 0 }
        DebugState.frameCount += 1
        // DIAGNOSTIC: Print EVERY frame (not throttled) to see ALL FFT power values
        print("[CryFFT] power=\(String(format: "%.5f", fundamentalPower)) (threshold=\(String(format: "%.5f", fftPowerThreshold))), centroid=\(String(format: "%.0f", spectralCentroid))Hz, flat=\(String(format: "%.2f", spectralFlatness)), cry=\(isCryLike)")
        #endif

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

    /// CRITICAL FIX: Use fftPowerThreshold (FFT-scale) instead of adaptiveThreshold (RMS-scale)
    /// FIXED: More strict classification to prevent false positives (especially "tired" for non-cry sounds)
    private nonisolated func classifyCryTypeNonIsolated(analysis: CryAnalysis, fftPowerThreshold: Float) -> CryType {
        guard analysis.isCryLike else { return .unknown }

        let fundamentalRatio = analysis.fundamentalPower / (analysis.harmonicPower + 0.001)
        let centroid = analysis.spectralCentroid
        let power = analysis.fundamentalPower

        // RESEARCH-BASED CLASSIFICATION (based on infant cry acoustics literature)
        // Uses scoring system to find BEST match rather than strict thresholds
        // Priority order: Pain > Hunger > Discomfort > Attention > Tired
        // CRITICAL: All power comparisons use fftPowerThreshold (not RMS threshold!)
        //
        // FALSE POSITIVE FIX: "Tired" was matching non-cry ambient sounds
        // Now requires MINIMUM power threshold for ALL cry types
        // If sound is too quiet, it's likely not a cry at all

        // MINIMUM POWER GATE: Sound must be loud enough to be a cry
        // This prevents quiet ambient sounds from being classified
        let minPowerForCry = fftPowerThreshold * 0.8
        guard power >= minPowerForCry else {
            return .unknown  // Too quiet to be a real cry
        }

        var scores: [(CryType, Float)] = []

        // PAIN: High-pitched, VERY loud, tonal baby cry
        // BALANCED FIX 2026-01-09: Previous fix was too strict (600-1000 Hz missed real pain cries)
        //
        // ACOUSTIC RESEARCH on baby pain cries:
        // - F0 (fundamental): 400-700 Hz (higher than other cry types)
        // - Spectral centroid: 600-1500 Hz (energy concentrated in harmonics)
        // - Very TONAL (flatness < 0.4)
        // - STRONG harmonics (>0.4 ratio) - babies have clear harmonic structure
        // - LOUD (3x+ threshold)
        //
        // KEY DIFFERENTIATOR from adult voice:
        // - Adult voice has weaker harmonic structure (< 0.4 ratio)
        // - Adult voice is less tonal (flatness > 0.4)
        // - Adult voice varies more in pitch (handled by speech detection)
        var painScore: Float = 0
        let isPainCentroid = centroid > 600 && centroid < 1500  // Baby pain range (widened from 600-1000)
        let isPainPower = power > fftPowerThreshold * 3.0  // Loud (relaxed from 5x to 3x)
        let isPainTonal = analysis.spectralFlatness < 0.4  // Must be tonal (relaxed from 0.35)
        let hasStrongHarmonics = analysis.harmonicPower > analysis.fundamentalPower * 0.4  // Strong harmonics

        if isPainCentroid && isPainPower && isPainTonal && hasStrongHarmonics {
            // Score based on how well characteristics match
            painScore = 0.6
            // Bonus for higher power (louder = more likely pain)
            painScore += min((power / (fftPowerThreshold * 5)), 1.0) * 0.2
            // Bonus for being very tonal (baby cries are very tonal)
            painScore += (0.4 - analysis.spectralFlatness) * 0.5
        }
        if painScore > 0.6 { scores.append((.pain, painScore)) }

        // HUNGER: Lower centroid, rhythmic (high fundamental ratio = more tonal/rhythmic)
        // Hunger cries are RHYTHMIC with moderate power
        var hungerScore: Float = 0
        if centroid < 1000 { hungerScore += (1.0 - centroid / 1000) * 0.3 }
        if fundamentalRatio > 1.0 { hungerScore += min(fundamentalRatio / 2.0, 1.0) * 0.4 }
        if power > fftPowerThreshold * 0.5 && power < fftPowerThreshold * 3.0 {
            hungerScore += 0.3
        }
        if hungerScore > 0.4 { scores.append((.hunger, hungerScore)) }

        // DISCOMFORT: Strong harmonics, mid-range centroid, sustained
        // BALANCED FIX 2026-01-09: Previous fix was too strict (500-900 Hz too narrow)
        //
        // ACOUSTIC RESEARCH on discomfort cries:
        // - Mid-range F0 (350-550 Hz)
        // - Spectral centroid: 500-1200 Hz
        // - Strong harmonic structure (>0.5 ratio)
        // - Tonal quality (flatness < 0.45)
        // - Moderate power (1.5x+ threshold)
        var discomfortScore: Float = 0
        let harmonicRatioDiscomfort = analysis.harmonicPower / (analysis.fundamentalPower + 0.001)
        let hasStrongHarmonicsDiscomfort = harmonicRatioDiscomfort > 0.5  // Relaxed from 0.7
        let hasDiscomfortCentroid = centroid > 500 && centroid < 1200  // Widened from 500-900
        let hasSufficientPowerDiscomfort = power > fftPowerThreshold * 1.5  // Relaxed from 2.0x
        let isTonalDiscomfort = analysis.spectralFlatness < 0.45  // Relaxed from 0.4

        if hasStrongHarmonicsDiscomfort && hasDiscomfortCentroid && hasSufficientPowerDiscomfort && isTonalDiscomfort {
            discomfortScore = 0.5
            // Bonus for stronger harmonics
            discomfortScore += min((harmonicRatioDiscomfort - 0.5) * 0.5, 0.25)
            // Bonus for being tonal
            discomfortScore += (0.45 - analysis.spectralFlatness) * 0.5
        }
        if discomfortScore > 0.5 { scores.append((.discomfort, discomfortScore)) }

        // ATTENTION: Mid-range centroid, moderate power
        var attentionScore: Float = 0
        if centroid > 600 && centroid < 1400 { attentionScore += 0.4 }
        if power > fftPowerThreshold * 0.5 && power < fftPowerThreshold * 2.5 {
            attentionScore += 0.4
        }
        if attentionScore > 0.4 { scores.append((.attention, attentionScore)) }

        // TIRED: STRICT REQUIREMENTS - must have cry characteristics, not just be quiet!
        // FALSE POSITIVE FIX: Added tonal requirement (low flatness = more tonal = more cry-like)
        // Tired cries are whimpery but still TONAL, not breathy ambient noise
        var tiredScore: Float = 0
        // Must have moderate power (not too quiet - that's just noise)
        if power > fftPowerThreshold * 0.8 && power < fftPowerThreshold * 1.5 {
            tiredScore += 0.3
        }
        // Low centroid (whimpery)
        if centroid > 400 && centroid < 900 {
            tiredScore += 0.3
        }
        // CRITICAL: Must be TONAL (low spectral flatness), not breathy/noisy
        // Old code added flatness > 0.25 which was WRONG - that's breathy noise!
        // Cries are tonal (flatness < 0.4), noise is flat (flatness > 0.5)
        if analysis.spectralFlatness < 0.4 {
            tiredScore += 0.4  // Bonus for tonal quality
        } else {
            tiredScore -= 0.3  // Penalty for noisy/breathy sound (NOT a cry)
        }
        // Only add if score is reasonably high
        if tiredScore > 0.5 { scores.append((.tired, tiredScore)) }

        // Return highest scoring type, or general if no good match
        // STRICT: Require score > 0.5 for confident classification
        if let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0.5 {
            return best.0
        }

        // FALSE POSITIVE FIX: Don't return weak classifications
        // If we can't confidently classify, return .general (not the weak best guess)
        // This prevents "tired" from being returned for random ambient sounds
        return .general
    }

    /// CRITICAL FIX: Use fftPowerThreshold (FFT-scale) instead of adaptiveThreshold (RMS-scale)
    private nonisolated func calculateConfidenceNonIsolated(analysis: CryAnalysis, type: CryType, fftPowerThreshold: Float) -> Double {
        guard analysis.isCryLike else { return 0 }

        var confidence: Double = 0
        // CRITICAL: Use FFT-scale threshold for power comparison
        let powerScore = Double(min(analysis.fundamentalPower / (fftPowerThreshold * 3), 1.0))
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
            // MEMORY FIX: Use reusable instance instead of deleted lazy property
            let features = reusableFeatureExtractor.extractFeatures(from: samples, sampleRate: sampleRate)

            // Run ML cry detection
            // MEMORY FIX: Use reusable instance instead of deleted lazy property
            let mlDetection = reusableCryDetector.detect(features: features)
            mlCryDetected = mlDetection.isCryDetected
            mlConfidence = mlDetection.confidence

            // If cry detected, classify type with ML
            var classificationResult: CryClassification?
            if mlDetection.isCryDetected || mlDetection.confidence > 0.4 {
                // MEMORY FIX: Use reusable instance instead of deleted lazy property
                let classification = reusableCryClassifier.classify(features: features)
                classificationResult = classification

                // Blend ML classification with rule-based
                if classification.confidence > confidence {
                    cryType = classification.type
                }
            }

            // Analyze voice characteristics (tremolo, vibrato, distress)
            // MEMORY FIX: Use reusable instance (already correct)
            let voiceChars = reusableVoiceAnalyzer.analyze(samples: samples, sampleRate: sampleRate)

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
                self.latestClassification = classificationResult
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

        // RESEARCH-BASED CLASSIFICATION
        // Based on infant cry acoustics literature:
        // - Barr et al. (1988) - Hunger patterns
        // - Fuller & Horii (1986) - Pain acoustics
        // - Wasz-Höckert et al. (1985) - Cry differentiation

        let fundamentalRatio = analysis.fundamentalPower / (analysis.harmonicPower + 0.001)
        let centroid = analysis.spectralCentroid
        let power = analysis.fundamentalPower

        // Priority order: Pain > Hunger > Discomfort > Attention > Tired > General
        // Pain is most urgent, tired is least likely (avoid over-detection)

        // PAIN CRY: High pitch, high intensity, piercing
        // Research: F0 typically 500-700+ Hz, sudden onset
        if centroid > 1200 && power > adaptiveThreshold * 2.5 {
            return .pain
        }

        // HUNGER CRY: Rhythmic, lower pitch, moderate intensity
        // Research: F0 350-480 Hz, rhythmic pattern (neh-neh)
        if centroid < 800 && fundamentalRatio > 1.3 &&
           power > adaptiveThreshold * 0.8 && power < adaptiveThreshold * 2.5 {
            return .hunger
        }

        // DISCOMFORT CRY: Strong harmonic structure
        // Wet diaper, temperature, position issues
        if analysis.harmonicPower > analysis.fundamentalPower * 0.7 &&
           centroid > 700 && centroid < 1400 {
            return .discomfort
        }

        // ATTENTION CRY: Mid-range, moderate power
        // Wants interaction, escalates if ignored
        if centroid > 700 && centroid < 1200 &&
           power > adaptiveThreshold * 0.6 && power < adaptiveThreshold * 2.0 {
            return .attention
        }

        // TIRED CRY: STRICT - Must be LOW intensity
        // Research: F0 300-400 Hz, irregular, whimpering, breathy
        // FIX: Previously defaulting to tired too often
        if power < adaptiveThreshold * 1.2 &&  // MUST be quiet
           centroid < 800 &&
           analysis.spectralFlatness > 0.3 {   // Breathy quality
            return .tired
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
        // SILENCE FIX 2026-01-11: More aggressive decrement during silence
        // Users reported "CRY DETECTED" persisting during complete silence
        // Decrement by 3 instead of 1 for faster reset when audio is quiet
        if consecutiveCryFrames > 0 {
            consecutiveCryFrames = max(0, consecutiveCryFrames - 3)
        }

        // SILENCE FIX: Also decay confidence quickly during silence
        // This ensures the UI updates promptly when audio stops
        Task { @MainActor in
            // Decay confidence by 20% per quiet frame for responsive UI
            if self.confidenceLevel > 0.1 {
                self.confidenceLevel = max(0, self.confidenceLevel - 0.2)
            } else {
                self.confidenceLevel = 0
            }
            // Also decay intensity
            if self.cryIntensity > 0.1 {
                self.cryIntensity = max(0, self.cryIntensity - 0.15)
            } else {
                self.cryIntensity = 0
            }
        }

        // Check if cry has ended - SILENCE FIX: use lower threshold (1 frame instead of 2)
        if isCryDetected && consecutiveCryFrames < 2 {
            Task { @MainActor in
                self.isCryDetected = false
                self.detectionStatus = .listening
                // CRITICAL FIX: Reset display values so UI clears the "cry detected" state
                self.confidenceLevel = 0
                self.cryIntensity = 0
                self.cryType = .unknown
                self.onCryEnded?()
            }
        }
    }

    // MARK: - Detection Evaluation
    private func evaluateDetection() {
        // Use larger window for temporal analysis
        // FALSE POSITIVE FIX: Increased from 30 to 60 frames (~2s window) to match sustained duration
        let recentFrames = cryPatternBuffer.suffix(60)
        // AGGRESSIVE 2026-01-09: Relaxed confidence filter from 0.4 to 0.25
        // Include more frames to improve detection
        let cryLikeFrames = recentFrames.filter { $0.isCryLike && $0.confidence >= 0.25 }

        // CRY STATE TIMEOUT: Track when we last saw cry-like audio
        let now = Date()
        if !cryLikeFrames.isEmpty {
            lastCryLikeFrameTime = now
        }

        // CRITICAL FIX: Require sustained pattern, not just frame count
        // Baby cries are sustained; speech is intermittent
        let cryFrameRatio = Double(cryLikeFrames.count) / Double(max(1, recentFrames.count))

        // Check for speech-like patterns (high spectral variance = likely speech)
        let isSpeechLike = checkIfSpeechLike(frames: Array(recentFrames))

        // AGGRESSIVE 2026-01-09: Very relaxed requirements for faster detection
        // Requirements:
        // - At least 3 cry-like frames in window
        // - At least 10% of frames are cry-like
        // - Not speech-like pattern
        if cryLikeFrames.count >= 3 && cryFrameRatio > 0.10 && !isSpeechLike {
            consecutiveCryFrames += 2  // Faster ramp up
        } else {
            consecutiveCryFrames = max(0, consecutiveCryFrames - 1)
        }

        // Calculate average confidence from recent cry frames
        let avgConfidence = cryLikeFrames.isEmpty ? 0 :
            cryLikeFrames.reduce(0.0) { $0 + $1.confidence } / Double(cryLikeFrames.count)

        // Calculate intensity
        // CRITICAL FIX: Use fftPowerThreshold (FFT-scale) for power comparison
        let avgPower = cryLikeFrames.isEmpty ? 0 :
            cryLikeFrames.reduce(Float(0)) { $0 + $1.fundamentalPower } / Float(cryLikeFrames.count)
        let intensity = Double(min(avgPower / (fftPowerThreshold * 5), 1.0))

        // Determine dominant cry type
        let dominantType = determineDominantCryType()

        // CRITICAL FIX: Sustained cry detection
        // Track how long we've been detecting cry-like sounds
        // Note: 'now' already declared at start of evaluateDetection()
        // AGGRESSIVE 2026-01-09: Match the relaxed threshold (3 frames, 10% ratio)
        if cryLikeFrames.count >= 3 && cryFrameRatio > 0.10 && !isSpeechLike {
            if sustainedCryStartTime == nil {
                sustainedCryStartTime = now
            }
        } else {
            sustainedCryStartTime = nil // Reset if detection breaks
        }

        // Calculate sustained duration
        let sustainedDuration = sustainedCryStartTime.map { now.timeIntervalSince($0) } ?? 0

        // Detection decision - AGGRESSIVE:
        // 1. Need frame count (8+ frames = ~0.27 seconds of pattern)
        // 2. Need low confidence (45%+)
        // 3. Need sustained detection (0.8+ seconds)
        // 4. Must NOT be speech-like (primary false positive filter)
        let shouldDetect = consecutiveCryFrames >= minCryFramesForDetection &&
                           avgConfidence >= minCryConfidence &&
                           sustainedDuration >= minSustainedCryDuration &&
                           !isSpeechLike

        Task { @MainActor in
            self.confidenceLevel = avgConfidence
            self.cryIntensity = intensity
            self.cryType = dominantType

            // Debug logging for cry detection troubleshooting
            if cryLikeFrames.count > 0 {
                print("[CryDetection] frames: \(cryLikeFrames.count)/\(recentFrames.count) (\(String(format: "%.0f%%", cryFrameRatio * 100))), sustained: \(String(format: "%.1fs", sustainedDuration)), conf: \(String(format: "%.0f%%", avgConfidence * 100)), speech: \(isSpeechLike), detect: \(shouldDetect)")
            }

            // CRY STATE TIMEOUT: Check if we should force-reset due to no cry-like audio
            let timeSinceLastCryFrame = self.lastCryLikeFrameTime.map { now.timeIntervalSince($0) } ?? 0
            let shouldTimeoutReset = self.isCryDetected && timeSinceLastCryFrame >= self.cryStateTimeoutDuration

            if shouldDetect && !self.isCryDetected {
                print("[CryDetection] 🔴 CRY DETECTED! Type: \(dominantType.rawValue), Confidence: \(String(format: "%.0f%%", avgConfidence * 100)), Duration: \(String(format: "%.1fs", sustainedDuration))")
                self.isCryDetected = true
                self.detectionStatus = .cryDetected
                self.onCryDetected?(dominantType, avgConfidence)
            } else if shouldTimeoutReset {
                // TIMEOUT RESET: Force reset after 2 seconds of no cry-like audio
                // SILENCE FIX 2026-01-11: Reduced from 10s to 2s for responsive UI
                print("[CryDetection] ⏰ Cry state TIMEOUT after \(String(format: "%.1fs", timeSinceLastCryFrame)) of silence - resetting")
                self.resetCryState()
            } else if !shouldDetect && self.isCryDetected && consecutiveCryFrames < 3 {
                // SILENCE FIX 2026-01-11: Lowered threshold from minCryFramesForDetection/4 (2) to 3
                // Combined with faster decrement, this allows quicker reset
                print("[CryDetection] ✅ Cry ended - baby calming down")
                self.resetCryState()
            }
        }
    }

    /// Check if the audio pattern is more like human speech/singing than a baby cry
    /// Speech has rapid spectral changes; baby cries are more sustained/monotonic
    /// SINGING FIX (2026-01-09): Also detect adult singing (lullaby) which is low-variance like baby cries
    private func checkIfSpeechLike(frames: [CryFrame]) -> Bool {
        guard frames.count >= 10 else { return false }

        // Calculate variance in spectral centroid (speech has high variance)
        let centroids = frames.map { $0.spectralCentroid }
        let mean = centroids.reduce(0, +) / Float(centroids.count)
        let variance = centroids.map { pow($0 - mean, 2) }.reduce(0, +) / Float(centroids.count)
        let normalizedVariance = sqrt(variance) / max(mean, 1.0) // Coefficient of variation

        // Track variance history for smoothing
        spectralVarianceHistory.append(normalizedVariance)
        if spectralVarianceHistory.count > 20 {
            spectralVarianceHistory.removeFirst()
        }

        // High variance = speech (talking changes pitch rapidly)
        // Low variance = cry (baby cries are sustained at similar pitch)
        let avgVariance = spectralVarianceHistory.reduce(0, +) / Float(max(1, spectralVarianceHistory.count))

        // Also check confidence consistency - cries have stable confidence, speech fluctuates
        let confidences = frames.map { Float($0.confidence) }
        let confMean = confidences.reduce(0, +) / Float(confidences.count)
        let confVariance = confidences.map { pow($0 - confMean, 2) }.reduce(0, +) / Float(confidences.count)

        // Speech: high spectral variance AND high confidence variance
        // BALANCED 2026-01-09: Changed from OR to AND
        // OR was too aggressive - catching real baby cries as speech
        // Now requires BOTH high spectral variance AND high confidence variance
        // This is more permissive for cry detection while still catching speech
        let isSpeech = avgVariance > speechVarianceThreshold && confVariance > 0.12

        // DISABLED 2026-01-09: Singing detection was filtering out real baby cries
        // from YouTube videos (centroid shifted by phone speakers)
        // Speech detection alone is sufficient for filtering adult speech
        // let isSinging = checkIfSinging(frames: frames, centroidMean: mean)
        let isSinging = false  // DISABLED

        if isSpeech && frames.filter({ $0.isCryLike }).count > 5 {
            print("[CryDetection] 🗣️ Speech detected (var: \(String(format: "%.3f", avgVariance)), confVar: \(String(format: "%.3f", confVariance))) - NOT a baby cry")
        }

        // Singing detection disabled - was causing false negatives
        // if isSinging && !isSpeech {
        //     print("[CryDetection] 🎵 SINGING detected (centroid: \(String(format: "%.0f", mean))Hz) - NOT a baby cry")
        // }

        return isSpeech  // Only check speech, not singing
    }

    /// Detect adult singing patterns (lullaby, humming)
    /// Adult singing has LOW spectral variance (like baby cries) but DIFFERENT characteristics:
    /// - Higher spectral centroid (~1200+ Hz) - adult voice is MUCH higher than baby
    /// - More controlled volume (less power variation between frames)
    /// - Often has musical pitch patterns (periodic, not chaotic like cries)
    ///
    /// BALANCED FIX 2026-01-09: Previous threshold of 700 Hz was too aggressive
    /// Baby pain cries can have centroid up to 1000-1200 Hz due to harmonics
    /// Adult singing typically has centroid > 1200 Hz
    private func checkIfSinging(frames: [CryFrame], centroidMean: Float) -> Bool {
        // Adult voice spectral centroid is typically 1200-2500 Hz
        // Baby cries: fundamental 300-600 Hz, with harmonics pushing centroid to 500-1000 Hz
        // If centroid is VERY HIGH (>1200), it's likely adult singing, not baby crying
        // RELAXED: Changed from 700 Hz to 1200 Hz to avoid false positives on baby pain cries
        let highCentroidThreshold: Float = 1200.0 // Hz - above this is likely adult voice

        // SINGING DETECTION: Adult singing has VERY HIGH spectral centroid
        let isHighCentroid = centroidMean > highCentroidThreshold

        if !isHighCentroid {
            return false // Centroid in baby range = likely baby cry
        }

        // Additional check: Singing has VERY CONTROLLED power variations
        // Baby cries have chaotic power patterns (gasping, pauses, escalation)
        let powers = frames.map { $0.fundamentalPower }
        let powerMean = powers.reduce(0, +) / Float(powers.count)
        let powerVariance = powers.map { pow($0 - powerMean, 2) }.reduce(0, +) / Float(powers.count)
        let normalizedPowerVar = sqrt(powerVariance) / max(powerMean, 0.001)

        // VERY low power variance = adult singing (they control volume precisely)
        // Relaxed from 0.6 to 0.4 - only flag as singing if VERY controlled
        let isControlledPower = normalizedPowerVar < 0.4

        // Final check: Overall level consistency
        // Singing maintains steady volume; baby cries fluctuate dramatically
        let levels = frames.map { $0.overallLevel }
        let levelMean = levels.reduce(0, +) / Float(levels.count)
        let levelVariance = levels.map { pow($0 - levelMean, 2) }.reduce(0, +) / Float(levels.count)
        let normalizedLevelVar = sqrt(levelVariance) / max(levelMean, 0.001)

        // VERY steady level = singing (relaxed from 0.5 to 0.3)
        let isSteadyLevel = normalizedLevelVar < 0.3

        // ALL THREE conditions must be true to classify as singing
        // This is stricter than before - requires high centroid AND controlled power AND steady level
        let isSinging = isHighCentroid && isControlledPower && isSteadyLevel

        return isSinging
    }

    /// Reset all cry detection state (used for timeout and normal cry-end)
    private func resetCryState() {
        isCryDetected = false
        detectionStatus = .listening
        sustainedCryStartTime = nil
        lastCryLikeFrameTime = nil
        consecutiveCryFrames = 0
        // Reset cry type lock-in for fresh detection on next cry
        lockedCryType = nil
        cryTypeLockTime = nil
        // CRITICAL FIX: Reset display values so UI clears the "cry detected" state
        confidenceLevel = 0
        cryIntensity = 0
        cryType = .unknown
        // Notify that cry has ended
        onCryEnded?()
    }

    private func determineDominantCryType() -> CryType {
        guard !cryTypeHistory.isEmpty else { return .unknown }

        var typeCounts: [CryType: Int] = [:]
        for type in cryTypeHistory {
            typeCounts[type, default: 0] += 1
        }

        // FALSE POSITIVE FIX: If most classifications are "unknown" or "general",
        // this is likely NOT a real cry - return unknown to lower confidence
        let unknownCount = (typeCounts[.unknown] ?? 0) + (typeCounts[.general] ?? 0)
        let totalCount = cryTypeHistory.count
        if totalCount > 0 && Float(unknownCount) / Float(totalCount) > 0.5 {
            // More than 50% of classifications are unknown/general = not a confident cry
            return .general
        }

        let rawDominantType = typeCounts.max(by: { $0.value < $1.value })?.key ?? .unknown

        // STABLE CRY TYPE: Use lock-in mechanism to prevent flip-flopping
        let now = Date()

        // Check if current lock is still valid
        if let lockedType = lockedCryType, let lockTime = cryTypeLockTime {
            if now.timeIntervalSince(lockTime) < cryTypeLockDuration {
                // Lock is still active - only override for urgent types (pain)
                if rawDominantType == .pain && lockedType != .pain {
                    // Pain is urgent - override the lock immediately
                    lockedCryType = .pain
                    cryTypeLockTime = now
                    print("[CryType] ⚠️ URGENT: Pain detected, overriding lock from \(lockedType.rawValue)")
                    return .pain
                }
                // Keep the locked type
                return lockedType
            }
        }

        // No valid lock - establish new lock if we have a specific type
        if rawDominantType != .unknown && rawDominantType != .general {
            lockedCryType = rawDominantType
            cryTypeLockTime = now
            print("[CryType] 🔒 Locked to \(rawDominantType.rawValue) for \(cryTypeLockDuration)s")
        }

        return rawDominantType
    }

    // MARK: - Ambient Noise Calibration
    private func calibrateAmbientNoise() {
        // Use Task-based calibration for proper MainActor isolation
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            var samples: [Float] = []
            let targetSamples = 30 // Collect 30 samples over 3 seconds

            // Collect samples every 100ms for 3 seconds
            for _ in 0..<targetSamples {
                samples.append(self.currentAudioLevel)
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            guard !samples.isEmpty else { return }

            // Use 75th percentile (not average) to handle brief noises during calibration
            let sorted = samples.sorted()
            let p75Index = Int(Double(sorted.count) * 0.75)
            let baseline = sorted[min(p75Index, sorted.count - 1)]

            // Set ambient noise with conservative margin
            self.ambientNoiseLevel = baseline * 1.5
            // Adaptive threshold is 3x ambient (more conservative) - used for RMS comparison
            self.adaptiveThreshold = max(0.15, self.ambientNoiseLevel * 3.0)

            // CRITICAL FIX: Set FFT power threshold (separate from RMS threshold!)
            // FFT magnitudes after 2/N scaling are ~100x smaller than RMS values
            // FALSE POSITIVE FIX 2026-01-09: Raised minimum from 0.0005 to 0.002
            // Previous 0.0005 was too sensitive - triggered on ambient noise
            // Baby cries typically have FFT power 0.003-0.02, well above 0.002 threshold
            // Use RMS-to-FFT ratio but with higher floor to prevent false positives
            self.fftPowerThreshold = max(0.002, self.ambientNoiseLevel / 15.0)  // Higher floor and ratio
            self.isCalibrated = true

            print("[CryDetection] Calibration complete: ambient=\(self.ambientNoiseLevel), rmsThreshold=\(self.adaptiveThreshold), fftThreshold=\(self.fftPowerThreshold)")
        }
    }

    // MARK: - DeepInfant Integration

    /// Accumulate audio samples for DeepInfant classification
    /// DeepInfant needs ~4 seconds of audio at 16kHz for best results
    /// MEMORY SAFETY: Uses circular buffer pattern to prevent unbounded growth
    private func accumulateForDeepInfant(samples: [Float], sampleRate: Float) {
        // MEMORY FIX (Priority 4): Thread-safe buffer access
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Use shared singleton instead of instance property
        let classifier = Self.getSharedDeepInfant()
        guard useDeepInfant, classifier.isModelLoaded else { return }

        // Resample to 16kHz if needed - MEMORY OPTIMIZATION: Only allocate when necessary
        let targetSR: Float = 16000
        let resampledSamples: [Float]
        if abs(sampleRate - targetSR) > 100 {
            let ratio = targetSR / sampleRate
            let outputLength = Int(Float(samples.count) * ratio)
            // MEMORY SAFETY: Pre-size the output array
            var output = [Float](repeating: 0, count: outputLength)
            for i in 0..<outputLength {
                let srcIndex = Float(i) / ratio
                let srcIndexInt = Int(srcIndex)
                if srcIndexInt < samples.count {
                    output[i] = samples[srcIndexInt]
                }
            }
            resampledSamples = output
        } else {
            resampledSamples = samples
        }

        // MEMORY FIX (Priority 2): STRICT buffer overflow protection
        // Prevent unbounded growth even if samples arrive faster than processed
        if deepInfantBuffer.count < deepInfantBufferSize {
            // Initial fill: grow buffer up to max size with STRICT bounds checking
            let spaceRemaining = deepInfantBufferSize - deepInfantBuffer.count
            let samplesToAdd = min(resampledSamples.count, spaceRemaining)

            // CRITICAL: Double-check we won't overflow even if calculation is wrong
            guard samplesToAdd > 0 && deepInfantBuffer.count + samplesToAdd <= deepInfantBufferSize else {
                // OVERFLOW PROTECTION: Switch to circular writes immediately
                for sample in resampledSamples {
                    if deepInfantBuffer.count < deepInfantBufferSize {
                        deepInfantBuffer.append(sample)
                    } else {
                        deepInfantBuffer[deepInfantBufferWriteIndex] = sample
                        deepInfantBufferWriteIndex = (deepInfantBufferWriteIndex + 1) % deepInfantBufferSize
                    }
                }
                return
            }

            deepInfantBuffer.append(contentsOf: resampledSamples.prefix(samplesToAdd))
        } else {
            // Buffer is full: overwrite oldest samples (circular write)
            for sample in resampledSamples {
                deepInfantBuffer[deepInfantBufferWriteIndex] = sample
                deepInfantBufferWriteIndex = (deepInfantBufferWriteIndex + 1) % deepInfantBufferSize
            }
        }

        // Run classification periodically (not every frame - too expensive)
        let now = Date()
        guard now.timeIntervalSince(deepInfantLastClassification) >= deepInfantClassificationInterval else {
            return
        }

        // CRITICAL FIX: Run DeepInfant classification PROACTIVELY during monitoring!
        // OLD BUG: Only classified when isCryDetected || confidenceLevel > 0.3
        //          This chicken-egg problem meant ML could never INITIATE detection!
        // NEW: Always classify when we have enough audio - ML should LEAD detection, not follow it
        guard deepInfantBuffer.count >= deepInfantBufferSize / 2 else {
            return
        }

        deepInfantLastClassification = now

        // Run DeepInfant classification on background queue
        let bufferCopy = deepInfantBuffer
        // COMPILER FIX: Reuse 'classifier' variable from earlier in function (line 1547)
        // let classifier = Self.getSharedDeepInfant() // REMOVED - already declared above
        Task {
            // Run classification on background thread (classify is synchronous but CPU-intensive)
            let result = await Task.detached {
                return classifier.classify(
                    samples: bufferCopy,
                    sampleRate: targetSR
                )
            }.value

            // CRITICAL FIX 2026-01-09: ML should NOT set confidence on its own!
            // PROBLEM: DeepInfant classifies ambient noise as "Pain 75%" or "Discomfort 70%"
            //          This causes the UI to show fake cry types when there's no actual cry!
            // SOLUTION: ML can only UPDATE cryType when:
            //   1. Rule-based detection ALREADY set confidence > 0 (we detected SOMETHING)
            //   2. AND ML result is better than current classification
            //   3. ML should NEVER set confidenceLevel directly - rule-based does that
            if let result = result, result.confidence > 0.4 {
                // GUARD: Only use ML if rule-based already detected something
                // If confidenceLevel is 0, we haven't detected anything real yet!
                guard self.confidenceLevel > 0.2 else {
                    print("[DeepInfant] 🔇 Ignoring ML result (\(result.cryType) \(Int(result.confidence * 100))%) - no cry detected yet (confidence=\(Int(self.confidenceLevel * 100))%)")
                    return
                }

                // Only update cry type if ML is more confident than rule-based classification
                // BUT don't update confidenceLevel - that comes from rule-based detection
                if result.confidence > 0.6 && (self.cryType == .unknown || self.cryType == .general) {
                    self.cryType = result.cryType
                    // NOTE: Do NOT update confidenceLevel here - rule-based detection sets that!
                    print("[DeepInfant] ML Classification: \(result.cryType) (ML: \(Int(result.confidence * 100))%, rule-based: \(Int(self.confidenceLevel * 100))%) in \(Int(result.processingTimeMs))ms")

                    // NOTE 2026-01-09: REMOVED ML-initiated cry detection!
                    // ML should NEVER trigger isCryDetected independently.
                    // The rule-based evaluateDetection() handles cry triggering.
                    // ML only provides better cry TYPE classification when rule-based already detected cry.
                }
            }
            // NOTE: Removed low-confidence logging - too noisy and not useful
        }
    }

    /// Clear DeepInfant buffer (call when stopping monitoring)
    /// MEMORY SAFETY: Reset circular buffer state
    private func clearDeepInfantBuffer() {
        deepInfantBuffer.removeAll(keepingCapacity: true)  // Keep capacity to avoid reallocation
        deepInfantBufferWriteIndex = 0
        deepInfantLastClassification = .distantPast
    }

    // MARK: - Cleanup
    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
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

// MARK: - DeepInfant Protocol
// Protocol for dependency injection and testability
// DeepInfantClassifier.swift conforms to this protocol

protocol DeepInfantClassifierProtocol {
    var isModelLoaded: Bool { get }
    func classify(samples: [Float], sampleRate: Float) -> DeepInfantResultProtocol?
}

protocol DeepInfantResultProtocol {
    var cryType: CryType { get }
    var confidence: Double { get }
    var processingTimeMs: Double { get }
    var allProbabilities: [String: Double] { get }
}
