//
//  EnvironmentSoundDetector.swift
//  BabyInCarApp
//
//  Parallel audio analysis for car environment sounds.
//  Detects engine rumble, road noise, and motion patterns to determine
//  how much natural soothing the car is providing.
//

import Foundation
import AVFoundation
import Accelerate
import CoreMotion
import Combine

// MARK: - Environment Sound Detector

@MainActor
class EnvironmentSoundDetector: ObservableObject {
    static let shared = EnvironmentSoundDetector()

    // MARK: - Published State

    @Published var isMonitoring: Bool = false
    @Published var currentState: EnvironmentState?
    @Published var soothingScore: Double = 0.0
    @Published var motionType: MotionType = .unknown
    @Published var isCarEnvironmentDetected: Bool = false

    // MARK: - Audio Components

    private var audioEngine: AVAudioEngine?
    private let analysisQueue = DispatchQueue(label: "com.babyincar.environmentdetector", qos: .userInteractive)

    // FFT Configuration - focused on low frequencies for engine/road
    private let fftSize: Int = 4096
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []

    // Frequency bands for analysis
    private let lowFreqRange: ClosedRange<Float> = 20...200      // Engine rumble
    private let midFreqRange: ClosedRange<Float> = 200...1000    // Road/tire noise
    private let highFreqRange: ClosedRange<Float> = 1000...4000  // Wind, rattles

    // Analysis state
    private let sampleRate: Float = 44100
    private var spectralHistory: [[Float]] = []
    private let spectralHistorySize = 30 // ~1 second of history

    // MARK: - Motion Components

    private let motionManager = CMMotionManager()
    private var currentAcceleration: CMAcceleration?
    private var accelerationHistory: [CMAcceleration] = []
    private let accelerationHistorySize = 50

    // MARK: - Callbacks

    var onEnvironmentStateUpdated: ((EnvironmentState) -> Void)?

    // MARK: - Initialization

    private init() {
        setupFFT()
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Monitoring Control

    func startMonitoring() async throws {
        guard !isMonitoring else { return }

        // Setup audio tap
        try setupAudioTap()

        // Start motion detection
        startMotionDetection()

        isMonitoring = true
    }

    func stopMonitoring() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        motionManager.stopAccelerometerUpdates()

        isMonitoring = false
        currentState = nil
        spectralHistory.removeAll()
        accelerationHistory.removeAll()
    }

    // MARK: - Audio Setup

    private func setupAudioTap() throws {
        // Check if CryDetectionService already has the audio engine running
        // We need to share the audio session, not create a new one

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw EnvironmentDetectorError.engineSetupFailed
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for environment analysis
        // Use a separate bus or share with CryDetectionService
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(fftSize)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Configure audio session - exclusive playback (pauses other apps)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)

        try engine.start()
    }

    // MARK: - Motion Detection

    private func startMotionDetection() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.1 // 10Hz

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.currentAcceleration = data.acceleration
            self.accelerationHistory.append(data.acceleration)
            if self.accelerationHistory.count > self.accelerationHistorySize {
                self.accelerationHistory.removeFirst()
            }
        }
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // Capture needed values
        let fftSizeLocal = fftSize
        let windowLocal = window
        let sampleRateLocal = sampleRate
        let currentAccel = currentAcceleration
        let accelHistory = accelerationHistory

        analysisQueue.async { [weak self] in
            self?.analyzeEnvironmentSound(
                samples: samples,
                fftSize: fftSizeLocal,
                window: windowLocal,
                sampleRate: sampleRateLocal,
                acceleration: currentAccel,
                accelerationHistory: accelHistory
            )
        }
    }

    private nonisolated func analyzeEnvironmentSound(
        samples: [Float],
        fftSize: Int,
        window: [Float],
        sampleRate: Float,
        acceleration: CMAcceleration?,
        accelerationHistory: [CMAcceleration]
    ) {
        guard samples.count >= fftSize else { return }

        // 1. Apply window and perform FFT
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var windowCopy = window
        vDSP_vmul(samples, 1, &windowCopy, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        performFFT(samples: windowedSamples, fftSize: fftSize, magnitudes: &magnitudes)

        let frequencyResolution = sampleRate / Float(fftSize)

        // 2. Analyze frequency bands
        let lowPower = calculateBandPower(magnitudes: magnitudes, range: 20...200, resolution: frequencyResolution)
        let midPower = calculateBandPower(magnitudes: magnitudes, range: 200...1000, resolution: frequencyResolution)
        let highPower = calculateBandPower(magnitudes: magnitudes, range: 1000...4000, resolution: frequencyResolution)

        // 3. Calculate overall RMS
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // 4. Determine engine sound level (based on low frequency power)
        let engineLevel = min(1.0, lowPower * 10) // Normalize
        let engineCategory = categorizeEngineSound(power: lowPower, rms: rms)

        // 5. Determine road noise (based on mid frequency)
        let roadLevel = min(1.0, midPower * 10)
        let roadCategory = categorizeRoadNoise(power: midPower, consistency: calculateSpectralConsistency(magnitudes: magnitudes))

        // 6. Determine motion type from accelerometer
        let motionType = classifyMotion(acceleration: acceleration, history: accelerationHistory)

        // 7. Calculate spectral consistency (steady sounds are more soothing)
        let consistency = calculateSpectralConsistency(magnitudes: magnitudes)

        // 8. Create environment state
        let state = EnvironmentState(
            engineSoundLevel: engineLevel,
            roadNoiseLevel: roadLevel,
            cabinNoiseLevel: rms,
            engineCategory: engineCategory,
            roadNoiseCategory: roadCategory,
            motionType: motionType,
            lowFrequencyPower: lowPower,
            midFrequencyPower: midPower,
            highFrequencyPower: highPower,
            spectralConsistency: consistency,
            acceleration: acceleration
        )

        // Update on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentState = state
            self.soothingScore = state.soothingScore
            self.motionType = state.motionType
            self.isCarEnvironmentDetected = state.soothingScore > 0.3

            EnvironmentStateHistory.shared.addState(state)
            self.onEnvironmentStateUpdated?(state)
        }
    }

    // MARK: - FFT Helper

    private nonisolated func performFFT(samples: [Float], fftSize: Int, magnitudes: inout [Float]) {
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

    private nonisolated func calculateBandPower(magnitudes: [Float], range: ClosedRange<Float>, resolution: Float) -> Float {
        let startBin = Int(range.lowerBound / resolution)
        let endBin = min(Int(range.upperBound / resolution), magnitudes.count - 1)
        guard startBin < endBin && startBin >= 0 else { return 0 }

        var power: Float = 0
        let bandMagnitudes = Array(magnitudes[startBin...endBin])
        vDSP_sve(bandMagnitudes, 1, &power, vDSP_Length(endBin - startBin + 1))
        return power / Float(endBin - startBin + 1)
    }

    private nonisolated func calculateSpectralConsistency(magnitudes: [Float]) -> Float {
        // Calculate how "flat" vs "peaky" the spectrum is
        // Consistent engine rumble = flatter low-frequency spectrum

        guard !magnitudes.isEmpty else { return 0 }

        let lowBins = Array(magnitudes.prefix(100)) // First 100 bins (~1kHz)
        guard !lowBins.isEmpty else { return 0 }

        var mean: Float = 0
        vDSP_meanv(lowBins, 1, &mean, vDSP_Length(lowBins.count))

        var variance: Float = 0
        for mag in lowBins {
            variance += pow(mag - mean, 2)
        }
        variance /= Float(lowBins.count)

        // Lower variance = more consistent
        let consistency = 1.0 - min(1.0, sqrt(variance) / (mean + 0.001))
        return max(0, consistency)
    }

    // MARK: - Categorization

    private nonisolated func categorizeEngineSound(power: Float, rms: Float) -> EngineSoundLevel {
        // Combine low-frequency power with overall RMS
        let combinedLevel = power * 0.7 + rms * 0.3

        switch combinedLevel {
        case ..<0.02:
            return .quiet
        case 0.02..<0.05:
            return .low
        case 0.05..<0.1:
            return .moderate
        case 0.1..<0.2:
            return .loud
        default:
            return .veryLoud
        }
    }

    private nonisolated func categorizeRoadNoise(power: Float, consistency: Float) -> RoadNoiseType {
        if power < 0.01 {
            return .silent
        }

        // High consistency + moderate power = smooth road
        if consistency > 0.7 && power < 0.1 {
            return .smooth
        }

        // Low consistency = variable/rough
        if consistency < 0.4 {
            return power > 0.1 ? .rough : .variable
        }

        return .moderate
    }

    private nonisolated func classifyMotion(
        acceleration: CMAcceleration?,
        history: [CMAcceleration]
    ) -> MotionType {
        guard let accel = acceleration else { return .unknown }

        // Calculate magnitude of acceleration
        let magnitude = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))

        // Very low magnitude = stopped or very smooth
        if magnitude < 1.02 { // Gravity is ~1.0
            // Check if we were recently moving
            if history.count > 10 {
                let recentMagnitudes = history.suffix(10).map { sqrt(pow($0.x, 2) + pow($0.y, 2) + pow($0.z, 2)) }
                let avgMagnitude = recentMagnitudes.reduce(0, +) / Double(recentMagnitudes.count)
                if avgMagnitude < 1.02 {
                    return .stopped
                }
            }
            return .highway // Very smooth = highway cruise
        }

        // Calculate variance to detect stop-and-go
        if history.count >= 20 {
            let recentMagnitudes = history.suffix(20).map { sqrt(pow($0.x, 2) + pow($0.y, 2) + pow($0.z, 2)) }
            let mean = recentMagnitudes.reduce(0, +) / Double(recentMagnitudes.count)
            let variance = recentMagnitudes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recentMagnitudes.count)

            if variance > 0.05 {
                return .city // High variance = stop-and-go
            }

            if variance > 0.02 {
                return .roughRoad
            }
        }

        // Check for acceleration/deceleration
        if history.count >= 5 {
            let recent = history.suffix(5).map { $0.x } // Assume x is forward
            let trend = recent.last! - recent.first!

            if trend > 0.1 {
                return .acceleration
            }
            if trend < -0.1 {
                return .deceleration
            }
        }

        return magnitude < 1.1 ? .highway : .city
    }

    // MARK: - Cleanup

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}

// MARK: - Errors

enum EnvironmentDetectorError: Error, LocalizedError {
    case engineSetupFailed
    case audioSessionError(String)

    var errorDescription: String? {
        switch self {
        case .engineSetupFailed:
            return "Failed to setup environment audio analysis"
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        }
    }
}
