//
//  AudioEngine.swift
//  BabyInCarApp
//
//  Core audio playback engine with real-time synthesis
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    // MARK: - Published Properties
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTrack: AudioTrack?
    @Published var currentPlaylist: Playlist?
    @Published var currentPlaylistIndex: Int = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.5
    @Published var isMuted: Bool = false
    @Published var sleepTimer: SleepTimer = .off
    @Published var sleepTimerRemaining: TimeInterval = 0

    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioPlayer: AVAudioPlayer?
    private var noiseGenerator: NoiseGenerator?
    private var toneGenerator: ToneGenerator?

    // MARK: - Timers
    private var progressTimer: Timer?
    private var sleepTimerInstance: Timer?
    private var fadeTimer: Timer?

    // MARK: - Settings
    private let maxSafeVolume: Float = 0.7 // ~50dB safety limit

    private init() {
        setupNotifications()
    }

    // MARK: - Audio Session Configuration
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }

    // MARK: - Playback Control
    func play(track: AudioTrack) {
        stopCurrentPlayback()

        currentTrack = track
        duration = track.duration
        playbackState = .loading

        switch track.audioSourceType {
        case .generated:
            playGeneratedAudio(track: track)
        case .bundled:
            playBundledAudio(track: track)
        case .streamed:
            playStreamedAudio(track: track)
        case .textToSpeech:
            playTextToSpeech(track: track)
        }
    }

    func play(playlist: Playlist, startIndex: Int = 0) {
        guard !playlist.tracks.isEmpty else { return }
        currentPlaylist = playlist
        currentPlaylistIndex = startIndex

        if startIndex < playlist.tracks.count {
            play(track: playlist.tracks[startIndex])
        }
    }

    func pause() {
        playerNode?.pause()
        audioPlayer?.pause()
        noiseGenerator?.stop()
        playbackState = .paused
        stopProgressTimer()
    }

    func resume() {
        playerNode?.play()
        audioPlayer?.play()
        if let track = currentTrack, track.audioSourceType == .generated {
            noiseGenerator?.start()
        }
        playbackState = .playing
        startProgressTimer()
    }

    func stop() {
        stopCurrentPlayback()
        currentTrack = nil
        currentPlaylist = nil
        currentTime = 0
        duration = 0
        playbackState = .stopped
    }

    func next() {
        guard let playlist = currentPlaylist else { return }
        let nextIndex = currentPlaylistIndex + 1

        if nextIndex < playlist.tracks.count {
            currentPlaylistIndex = nextIndex
            play(track: playlist.tracks[nextIndex])
        } else {
            // Loop back to beginning
            currentPlaylistIndex = 0
            play(track: playlist.tracks[0])
        }
    }

    func previous() {
        guard let playlist = currentPlaylist else { return }

        // If more than 3 seconds into track, restart current track
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        let previousIndex = currentPlaylistIndex - 1
        if previousIndex >= 0 {
            currentPlaylistIndex = previousIndex
            play(track: playlist.tracks[previousIndex])
        } else {
            // Go to last track
            currentPlaylistIndex = playlist.tracks.count - 1
            play(track: playlist.tracks[currentPlaylistIndex])
        }
    }

    func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, duration))
        // For generated audio, we don't actually seek - just update display
        audioPlayer?.currentTime = currentTime
    }

    func setVolume(_ newVolume: Float) {
        // Enforce safety limit
        volume = min(newVolume, maxSafeVolume)
        audioPlayer?.volume = volume
        playerNode?.volume = volume
        noiseGenerator?.setVolume(volume)
    }

    func toggleMute() {
        isMuted.toggle()
        let effectiveVolume = isMuted ? 0 : volume
        audioPlayer?.volume = effectiveVolume
        playerNode?.volume = effectiveVolume
        noiseGenerator?.setVolume(effectiveVolume)
    }

    // MARK: - Sleep Timer
    func setSleepTimer(_ timer: SleepTimer) {
        sleepTimer = timer
        sleepTimerInstance?.invalidate()

        guard timer != .off else {
            sleepTimerRemaining = 0
            return
        }

        sleepTimerRemaining = timer.seconds

        sleepTimerInstance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.sleepTimerRemaining -= 1

                if self.sleepTimerRemaining <= 0 {
                    self.fadeOutAndStop()
                }
            }
        }
    }

    // MARK: - Generated Audio Playback
    private func playGeneratedAudio(track: AudioTrack) {
        guard let generatorType = track.generatorType else {
            playbackState = .error("No generator type specified")
            return
        }

        noiseGenerator = NoiseGenerator(type: generatorType)
        noiseGenerator?.setVolume(isMuted ? 0 : volume)
        noiseGenerator?.start()

        playbackState = .playing
        startProgressTimer()

        // For infinite/looping sounds, set a long duration
        duration = track.duration > 0 ? track.duration : 3600
    }

    private func playBundledAudio(track: AudioTrack) {
        guard let fileName = track.fileName,
              let fileExtension = track.fileExtension,
              let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            playbackState = .error("Audio file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = isMuted ? 0 : volume
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            duration = audioPlayer?.duration ?? track.duration
            playbackState = .playing
            startProgressTimer()
        } catch {
            playbackState = .error("Failed to play audio: \(error.localizedDescription)")
        }
    }

    private func playStreamedAudio(track: AudioTrack) {
        // For online-first model, we use URL streaming
        guard let urlString = track.streamURL,
              let url = URL(string: urlString) else {
            // Fallback to generated if no URL
            if track.generatorType != nil {
                playGeneratedAudio(track: track)
            } else {
                playbackState = .error("No stream URL available")
            }
            return
        }

        // Use AVPlayer for streaming
        Task {
            do {
                let data = try await URLSession.shared.data(from: url).0
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.volume = isMuted ? 0 : volume
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()

                duration = audioPlayer?.duration ?? track.duration
                playbackState = .playing
                startProgressTimer()
            } catch {
                playbackState = .error("Failed to stream audio: \(error.localizedDescription)")
            }
        }
    }

    private func playTextToSpeech(track: AudioTrack) {
        // Text-to-speech will be handled by SpeechSynthesizer service
        // For now, play a placeholder or generated sound
        playGeneratedAudio(track: track)
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let player = self.audioPlayer {
                    self.currentTime = player.currentTime
                } else {
                    // For generated audio, just increment
                    self.currentTime += 0.5
                    if self.currentTime >= self.duration {
                        self.handleTrackEnd()
                    }
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func stopCurrentPlayback() {
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        playerNode?.stop()
        noiseGenerator?.stop()
        noiseGenerator = nil
        currentTime = 0
    }

    private func handleTrackEnd() {
        if let playlist = currentPlaylist {
            next()
        } else {
            stop()
        }
    }

    // MARK: - Fade Out
    private func fadeOutAndStop() {
        let fadeSteps = 20
        let stepDuration: TimeInterval = 0.5
        var currentStep = 0
        let initialVolume = volume

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let newVolume = initialVolume * Float(fadeSteps - currentStep) / Float(fadeSteps)
                self.setVolume(newVolume)

                if currentStep >= fadeSteps {
                    timer.invalidate()
                    self.stop()
                    self.setVolume(initialVolume) // Restore volume for next play
                    self.sleepTimer = .off
                }
            }
        }
    }

    // MARK: - Interruption Handling
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Pause if headphones/speaker disconnected
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
}

// MARK: - Audio Player Delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                AudioEngine.shared.next()
            }
        }
    }
}

// MARK: - Noise Generator
class NoiseGenerator {
    private var audioEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var volume: Float = 0.5
    private var isRunning: Bool = false
    private let type: GeneratorType

    // Noise generation parameters
    private var phase: Double = 0
    private var previousValue: Double = 0

    init(type: GeneratorType) {
        self.type = type
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        noiseNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSample()
                let scaledSample = Float(sample) * self.volume

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = scaledSample
                }
            }

            return noErr
        }

        if let node = noiseNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    private func generateSample() -> Double {
        switch type {
        case .whiteNoise:
            return Double.random(in: -1...1)

        case .pinkNoise:
            // Pink noise using Voss-McCartney algorithm (simplified)
            let white = Double.random(in: -1...1)
            previousValue = 0.99 * previousValue + 0.01 * white
            return previousValue * 3

        case .brownNoise:
            // Brown noise (random walk)
            let step = Double.random(in: -0.1...0.1)
            previousValue = max(-1, min(1, previousValue + step))
            return previousValue

        case .heartbeat:
            // Simulated heartbeat at ~70 BPM
            phase += 70.0 / 60.0 / 44100.0
            if phase >= 1.0 { phase -= 1.0 }
            let beat = sin(phase * 2 * .pi * 10) * exp(-phase * 15)
            return beat * 0.8

        case .womb:
            // Womb sound: low frequency rumble + muffled noise
            phase += 1.0 / 44100.0
            let rumble = sin(phase * 2 * .pi * 30) * 0.3
            let noise = Double.random(in: -0.2...0.2)
            // Low-pass filter effect
            previousValue = 0.95 * previousValue + 0.05 * noise
            return rumble + previousValue

        case .shushing:
            // Rhythmic shushing pattern
            phase += 1.0 / 44100.0
            let cycle = fmod(phase * 0.8, 1.0) // ~0.8 Hz shush rate
            let envelope = cycle < 0.5 ? sin(cycle * .pi) : 0
            let noise = Double.random(in: -1...1)
            return noise * envelope * 0.6

        case .rain:
            // Rain: filtered noise with varying intensity
            let noise = Double.random(in: -1...1)
            previousValue = 0.7 * previousValue + 0.3 * noise
            // Add occasional "drops"
            let drop = Double.random(in: 0...1) > 0.999 ? Double.random(in: 0.3...0.6) : 0
            return (previousValue * 0.5 + drop)

        case .ocean:
            // Ocean waves with slow modulation
            phase += 1.0 / 44100.0
            let wavePhase = sin(phase * 2 * .pi * 0.1) * 0.5 + 0.5 // Slow wave cycle
            let noise = Double.random(in: -1...1)
            previousValue = 0.8 * previousValue + 0.2 * noise
            return previousValue * wavePhase * 0.7

        case .fan:
            // Fan: continuous filtered noise with slight wobble
            phase += 1.0 / 44100.0
            let wobble = sin(phase * 2 * .pi * 3) * 0.05 + 1.0
            let noise = Double.random(in: -1...1)
            previousValue = 0.85 * previousValue + 0.15 * noise
            return previousValue * wobble * 0.5

        case .vacuum:
            // Vacuum: louder, harsher noise
            let noise = Double.random(in: -1...1)
            previousValue = 0.6 * previousValue + 0.4 * noise
            return previousValue * 0.7

        case .lullaby, .musicBox:
            // Simple music box melody
            phase += 1.0 / 44100.0
            let noteFreq: Double = [262, 294, 330, 349, 392][Int(phase * 0.5) % 5]
            let tone = sin(phase * 2 * .pi * noteFreq)
            let envelope = 0.5 + 0.5 * sin(phase * 2 * .pi * 0.2)
            return tone * envelope * 0.3

        default:
            // Default to white noise for unsupported types
            return Double.random(in: -1...1) * 0.5
        }
    }

    func start() {
        guard !isRunning, let engine = audioEngine else { return }

        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start noise generator: \(error)")
        }
    }

    func stop() {
        audioEngine?.stop()
        isRunning = false
    }

    func setVolume(_ volume: Float) {
        self.volume = volume
    }
}

// MARK: - Tone Generator (for musical content)
class ToneGenerator {
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var frequency: Double = 440
    private var volume: Float = 0.5
    private var phase: Double = 0

    init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = self.frequency / sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase * 2 * .pi)) * self.volume
                self.phase += phaseIncrement
                if self.phase >= 1.0 { self.phase -= 1.0 }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        if let node = sourceNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    func setFrequency(_ freq: Double) {
        frequency = freq
    }

    func setVolume(_ vol: Float) {
        volume = vol
    }

    func start() {
        try? audioEngine?.start()
    }

    func stop() {
        audioEngine?.stop()
    }
}
