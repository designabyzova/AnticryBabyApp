//
//  CryDetectionViewModel.swift
//  BabyInCarApp
//
//  Shared ViewModel for cry detection - enables inline card and full modal
//  to share state without duplication
//

import SwiftUI
import Combine

// MARK: - CryDetectionError

enum CryDetectionError: Error, LocalizedError {
    case microphonePermissionDenied
    case captureStartFailed(Error)
    case classificationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for cry detection. Please enable it in Settings."
        case .captureStartFailed(let error):
            return "Failed to start audio capture: \(error.localizedDescription)"
        case .classificationFailed(let error):
            return "Classification error: \(error.localizedDescription)"
        }
    }
}

// MARK: - CryDetectionState

/// High-level state for the cry detection UI
enum CryDetectionState: Equatable {
    case idle
    case listening
    case detecting(cryType: CryType, confidence: Double, progress: Double)
    case detected(cryType: CryType, confidence: Double)
    case playingSoothing(cryType: CryType, track: AudioTrack?)
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle, .error: return false
        default: return true
        }
    }

    static func == (lhs: CryDetectionState, rhs: CryDetectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.listening, .listening): return true
        case (.detecting(let t1, let c1, let p1), .detecting(let t2, let c2, let p2)):
            return t1 == t2 && c1 == c2 && p1 == p2
        case (.detected(let t1, let c1), .detected(let t2, let c2)):
            return t1 == t2 && c1 == c2
        case (.playingSoothing(let t1, let tr1), .playingSoothing(let t2, let tr2)):
            return t1 == t2 && tr1?.id == tr2?.id
        case (.error(let m1), .error(let m2)):
            return m1 == m2
        default: return false
        }
    }
}

// MARK: - CryDetectionViewModel

@MainActor
final class CryDetectionViewModel: ObservableObject {

    // MARK: - Singleton

    static let shared = CryDetectionViewModel()

    // MARK: - Published State

    @Published private(set) var state: CryDetectionState = .idle
    @Published private(set) var isListening = false
    @Published private(set) var isStable = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isAudioDetected = false

    @Published private(set) var stabilityProgress: Double = 0.0
    @Published private(set) var dominantCryType: CryType = .unknown
    @Published private(set) var dominantConfidence: Double = 0.0
    @Published private(set) var stableCryType: CryType = .unknown
    @Published private(set) var stableConfidence: Double = 0.0

    @Published private(set) var error: CryDetectionError?
    @Published var showManualOverride = false

    @Published var pulseScale: Double = 1.0

    /// When true, automatically starts soothing playlist when cry type is detected
    /// Set to false for display-only mode (tab view)
    var autoStartPlaylist: Bool = true

    // MARK: - Computed Properties

    var statusIcon: String {
        if error != nil { return "exclamationmark.circle.fill" }
        if isStable { return "checkmark.circle.fill" }
        if isListening { return "waveform" }
        return "mic.fill"
    }

    var statusColor: Color {
        if error != nil { return .orange }
        if isStable { return .green }
        if isListening { return .purple }
        return .gray
    }

    var statusText: String {
        if error != nil { return "Error" }
        if isStable { return "Detected" }
        if isListening { return "Listening" }
        return "Ready"
    }

    var statusDescription: String {
        if error != nil { return "Something went wrong" }
        if isStable { return "Cry type identified" }
        if isListening { return "Analyzing cry pattern..." }
        return "Tap to start detection"
    }

    // MARK: - Private Properties

    private let captureService = AudioCaptureService.shared
    private let classificationService = CryClassificationService.shared
    private let stabilizer = CryTypeStabilizer.shared

    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?

    /// Baby age in months, read from persisted baby profile
    private var currentBabyAge: Int {
        if let babyData = UserDefaults.standard.data(forKey: "currentBaby"),
           let baby = try? JSONDecoder().decode(Baby.self, from: babyData) {
            return baby.ageInMonths
        }
        return 6
    }

    // MARK: - Initialization

    private init() {
        setupSubscriptions()
    }

    // MARK: - Public Methods

    func startDetection() {
        guard !isListening else { return }

        error = nil
        stabilizer.reset()
        isStable = false
        state = .listening

        Task {
            do {
                // Start audio capture
                try await captureService.startCapture()
                isListening = true
                startPulseAnimation()

                // Set up audio samples callback
                captureService.onAudioSamplesReady = { [weak self] samples in
                    Task { @MainActor in
                        await self?.processAudioSamples(samples)
                    }
                }

                captureService.onAudioLevelUpdate = { [weak self] level in
                    Task { @MainActor in
                        self?.audioLevel = level
                    }
                }

            } catch let captureError as AudioCaptureError {
                switch captureError {
                case .microphonePermissionDenied:
                    error = .microphonePermissionDenied
                    state = .error("Microphone permission denied")
                default:
                    error = .captureStartFailed(captureError)
                    state = .error("Failed to start capture")
                }
            } catch {
                self.error = .captureStartFailed(error)
                self.state = .error("Failed to start capture")
            }
        }
    }

    func stopDetection() {
        captureService.stopCapture()
        isListening = false
        stopPulseAnimation()
        state = .idle
        // MEMORY FIX (0030): Unload CoreML model when not detecting to save ~5MB
        classificationService.unloadModel()
    }

    func retryDetection() {
        error = nil
        startDetection()
    }

    func selectCryType(_ cryType: CryType) {
        // Set state directly — don't call stabilizer.forceType() because
        // it emits a .stabilized event that would trigger startSoothingPlaylist() again
        stableCryType = cryType
        stableConfidence = 1.0
        isStable = true
        // Start music immediately for manual selection
        startSoothingPlaylist()
    }

    func toggleManualOverride() {
        showManualOverride.toggle()
    }

    func startSoothingPlaylist() {
        // Guard against double-calling (manual select + event handler)
        if case .playingSoothing = state { return }

        // Stop detection
        stopDetection()

        // Update state to playing
        state = .playingSoothing(cryType: stableCryType, track: nil)

        // Build and play emergency playlist directly (no notification needed)
        let cryType = stableCryType
        let confidence = stableConfidence
        let babyAge = currentBabyAge

        Task {
            print("[CryDetectionViewModel] Starting soothing playlist for \(cryType.displayName) (confidence: \(Int(confidence * 100))%)")

            let playlist = await SmartPlaylistBuilder.shared.buildEmergencyPlaylist(
                cryType: cryType,
                babyAge: babyAge,
                language: "en",
                maxTracks: 30
            )

            AudioEngine.shared.play(
                playlist: playlist,
                context: .emergencyCry(type: cryType, babyAge: babyAge)
            )
        }
    }

    /// Called when AudioEngine starts playing a track
    func updatePlayingTrack(_ track: AudioTrack?) {
        if case .playingSoothing(let cryType, _) = state {
            state = .playingSoothing(cryType: cryType, track: track)
        }
    }

    /// Reset to idle state
    func reset() {
        stopDetection()
        state = .idle
        stableCryType = .unknown
        stableConfidence = 0.0
        dominantCryType = .unknown
        stabilityProgress = 0.0
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // Subscribe to stabilizer events
        stabilizer.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleStabilityEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to capture service state
        captureService.$isAudioDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAudioDetected)

        // Subscribe to stabilizer progress
        stabilizer.$stabilityProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self else { return }
                self.stabilityProgress = progress
                if self.isListening && !self.isStable && self.dominantCryType != .unknown {
                    self.state = .detecting(
                        cryType: self.dominantCryType,
                        confidence: self.dominantConfidence,
                        progress: progress
                    )
                }
            }
            .store(in: &cancellables)

        stabilizer.$dominantCryType
            .receive(on: DispatchQueue.main)
            .assign(to: &$dominantCryType)

        stabilizer.$stableCryType
            .receive(on: DispatchQueue.main)
            .assign(to: &$stableCryType)

        stabilizer.$stableConfidence
            .receive(on: DispatchQueue.main)
            .assign(to: &$stableConfidence)

        // Subscribe to AudioEngine track changes
        AudioEngine.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.updatePlayingTrack(track)
            }
            .store(in: &cancellables)
    }

    private func processAudioSamples(_ samples: [Float]) async {
        // Gate: skip classification when no valid audio is detected (silence/ambient noise)
        // DeepInfant V2 has no "no_cry" class, so it always outputs a cry type —
        // feeding silence into the model produces false positives (e.g. "pain")
        guard captureService.isAudioDetected else {
            // Feed unknown/low-confidence to dilute any prior false predictions
            stabilizer.addPrediction(.unknown, confidence: 0.0)
            return
        }

        do {
            let result = try await classificationService.classify(audioSamples: samples)

            print("[CryDetectionViewModel] Prediction: \(result.cryType.displayName) @ \(Int(result.confidence * 100))%")

            stabilizer.addPrediction(from: result)
            dominantConfidence = result.confidence
        } catch {
            print("[CryDetectionViewModel] Classification error: \(error)")
        }
    }

    private func handleStabilityEvent(_ event: StabilityEvent) {
        switch event {
        case .stabilized(let cryType, let confidence):
            // Never treat "unknown" as a valid detection
            guard cryType != .unknown else { return }

            isStable = true
            stableCryType = cryType
            stableConfidence = confidence
            stopPulseAnimation()
            state = .detected(cryType: cryType, confidence: confidence)

            // AUTO-START: start soothing playlist when cry type is confirmed
            if autoStartPlaylist {
                print("[CryDetectionViewModel] Cry type stabilized - AUTO-STARTING soothing playlist")
                startSoothingPlaylist()
            } else {
                print("[CryDetectionViewModel] Cry type stabilized - display only mode, no playlist")
            }

        case .changed(_, let to, let confidence):
            stableCryType = to
            stableConfidence = confidence

        case .unstable:
            isStable = false

        case .possibleChange(let to, _):
            dominantCryType = to
        }
    }

    private func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 1.5)) {
                    self?.pulseScale = 2.0
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.pulseScale = 1.0
            }
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseScale = 1.0
    }
}
