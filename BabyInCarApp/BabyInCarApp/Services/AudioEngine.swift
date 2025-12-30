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
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffleEnabled: Bool = false

    enum RepeatMode {
        case off
        case all
        case one
    }

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

    // MARK: - Repeat & Shuffle

    func setRepeatMode(_ mode: RepeatMode) {
        repeatMode = mode
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled, var playlist = currentPlaylist {
            // Shuffle the remaining tracks
            var shuffledTracks = playlist.tracks
            shuffledTracks.shuffle()
            // Keep current track in position
            if let currentTrack = currentTrack,
               let currentIndex = shuffledTracks.firstIndex(where: { $0.id == currentTrack.id }) {
                shuffledTracks.remove(at: currentIndex)
                shuffledTracks.insert(currentTrack, at: currentPlaylistIndex)
            }
            currentPlaylist = Playlist(
                id: playlist.id,
                name: playlist.name,
                description: playlist.description,
                tracks: shuffledTracks,
                category: playlist.category,
                targetAgeMonths: playlist.targetAgeMonths,
                isSystemGenerated: playlist.isSystemGenerated,
                createdAt: playlist.createdAt,
                artworkName: playlist.artworkName
            )
        }
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
              let fileExtension = track.fileExtension else {
            playbackState = .error("No audio file specified")
            return
        }

        // Try multiple paths to find the audio file
        var url: URL?

        // Try direct bundle lookup
        url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)

        // Try with subdirectory based on category
        if url == nil {
            let subdirectory: String
            switch track.category {
            case .classicalMusic:
                subdirectory = "Audio/classical"
            case .childrenSongs:
                subdirectory = "Audio/lullabies"
            case .natureSounds:
                subdirectory = "Audio/nature"
            case .whiteNoise:
                subdirectory = "Audio/whitenoise"
            default:
                subdirectory = "Audio"
            }
            url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory)
        }

        // Try Resources/Audio path
        if url == nil {
            url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Resources/Audio")
        }

        guard let audioURL = url else {
            print("Audio file not found: \(fileName).\(fileExtension)")
            // Fallback to generated audio if file not found
            if let generatorType = track.generatorType {
                var fallbackTrack = track
                fallbackTrack.generatorType = generatorType
                playGeneratedAudio(track: fallbackTrack)
            } else {
                playbackState = .error("Audio file not found: \(fileName)")
            }
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.volume = isMuted ? 0 : volume
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            duration = audioPlayer?.duration ?? track.duration
            playbackState = .playing
            startProgressTimer()
            print("Playing bundled audio: \(audioURL.lastPathComponent)")
        } catch {
            print("Failed to play audio: \(error)")
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

    // Additional state variables for complex generators
    private var blueNoiseState: Double = 0
    private var secondaryPhase: Double = 0
    private var tertiaryValue: Double = 0

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

        case .blueNoise:
            // Blue noise - high-pass filtered white noise (opposite of brown)
            // Emphasizes higher frequencies, good for older toddlers
            let white = Double.random(in: -1...1)
            let filtered = white - previousValue
            previousValue = white * 0.5
            return filtered * 0.6

        case .violetNoise:
            // Violet noise - even more high-frequency emphasis (differentiated blue)
            // Creates a "brighter" sound profile
            let white = Double.random(in: -1...1)
            let diff1 = white - previousValue
            let diff2 = diff1 - blueNoiseState
            previousValue = white
            blueNoiseState = diff1
            return diff2 * 0.4

        case .greyNoise:
            // Grey noise - psychoacoustically balanced (equal loudness curve)
            // Sounds equally loud across all frequencies to human ear
            phase += 1.0 / 44100.0
            let white = Double.random(in: -1...1)
            // Apply A-weighting approximation
            let lowBoost = sin(phase * 2 * .pi * 100) * 0.15
            let midCut = sin(phase * 2 * .pi * 1000) * 0.05
            previousValue = 0.85 * previousValue + 0.15 * white
            return (previousValue + lowBoost - midCut) * 0.5

        case .velvetNoise:
            // Velvet noise - sparse impulse noise, very smooth sounding
            // Great for toddlers as it's less harsh than continuous noise
            phase += 1.0 / 44100.0
            let impulseRate = 0.02 // Sparse impulses
            if Double.random(in: 0...1) < impulseRate {
                previousValue = Double.random(in: -1...1)
            }
            // Smooth decay between impulses
            previousValue *= 0.9995
            return previousValue * 0.7

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

        case .rainOnRoof:
            // Rain on roof - more muffled, cozy feeling
            phase += 1.0 / 44100.0
            let noise = Double.random(in: -1...1)
            previousValue = 0.92 * previousValue + 0.08 * noise // More filtering = muffled
            // Occasional heavier drops on roof
            let roofDrop = Double.random(in: 0...1) > 0.998 ? Double.random(in: 0.2...0.4) : 0
            // Low rumble of continuous rain
            let rumble = sin(phase * 2 * .pi * 40) * 0.08
            return (previousValue * 0.4 + roofDrop + rumble)

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

        case .forest:
            // Forest ambience - layered birds, wind, rustling leaves
            phase += 1.0 / 44100.0
            secondaryPhase += 1.0 / 44100.0
            // Base wind/leaves rustling
            let rustling = Double.random(in: -1...1)
            previousValue = 0.9 * previousValue + 0.1 * rustling
            // Occasional bird chirps (multiple frequencies)
            var birdChirp = 0.0
            if Double.random(in: 0...1) > 0.9997 {
                tertiaryValue = 1.0 // Start chirp
            }
            if tertiaryValue > 0.01 {
                let birdFreq = 2000 + sin(secondaryPhase * 50) * 500
                birdChirp = sin(phase * 2 * .pi * birdFreq) * tertiaryValue * 0.3
                tertiaryValue *= 0.995
            }
            // Gentle breeze modulation
            let breeze = sin(phase * 2 * .pi * 0.15) * 0.2 + 0.8
            return (previousValue * breeze * 0.4 + birdChirp)

        case .waterfall:
            // Waterfall - consistent rushing water
            let noise = Double.random(in: -1...1)
            previousValue = 0.75 * previousValue + 0.25 * noise
            // Add low rumble
            phase += 1.0 / 44100.0
            let rumble = sin(phase * 2 * .pi * 50) * 0.15
            return (previousValue * 0.6 + rumble)

        case .campfire:
            // Campfire at night - crackling + crickets
            phase += 1.0 / 44100.0
            // Base crackle
            let crackle = Double.random(in: -1...1)
            previousValue = 0.8 * previousValue + 0.2 * crackle
            // Occasional pop
            let pop = Double.random(in: 0...1) > 0.9995 ? Double.random(in: 0.4...0.7) : 0
            // Subtle cricket background
            let cricketFreq = 4000 + sin(phase * 3) * 200
            let cricket = sin(phase * 2 * .pi * cricketFreq) * 0.05 * (sin(phase * 8) > 0 ? 1 : 0)
            return (previousValue * 0.35 + pop + cricket)

        case .trainRide:
            // Train ride - rhythmic clacking + engine drone
            phase += 1.0 / 44100.0
            // Rhythmic wheel clacking (about 1.5 Hz for realistic train speed)
            let clackPhase = fmod(phase * 1.5, 1.0)
            var clack = 0.0
            if clackPhase < 0.05 || (clackPhase > 0.5 && clackPhase < 0.55) {
                clack = (1.0 - clackPhase * 10) * 0.4
            }
            // Engine drone
            let drone = sin(phase * 2 * .pi * 80) * 0.2 + sin(phase * 2 * .pi * 120) * 0.1
            // Subtle vibration noise
            let noise = Double.random(in: -1...1)
            previousValue = 0.95 * previousValue + 0.05 * noise
            return (drone + clack + previousValue * 0.15)

        case .airplaneCabin:
            // Airplane cabin - consistent engine drone + air circulation
            phase += 1.0 / 44100.0
            // Low engine drone (multiple harmonics)
            let engine = sin(phase * 2 * .pi * 100) * 0.25
                + sin(phase * 2 * .pi * 200) * 0.1
                + sin(phase * 2 * .pi * 150) * 0.08
            // Air circulation noise
            let airNoise = Double.random(in: -1...1)
            previousValue = 0.92 * previousValue + 0.08 * airNoise
            // Subtle pressure variation
            let pressure = sin(phase * 2 * .pi * 0.03) * 0.05
            return (engine + previousValue * 0.25 + pressure)

        case .thunderRumble:
            // Distant thunder rumble - low frequency with occasional louder moments
            phase += 1.0 / 44100.0
            // Base low rumble
            let rumble = sin(phase * 2 * .pi * 25) * 0.3
                + sin(phase * 2 * .pi * 40) * 0.15
            // Filtered noise for texture
            let noise = Double.random(in: -1...1)
            previousValue = 0.98 * previousValue + 0.02 * noise
            // Occasional thunder swell
            secondaryPhase *= 0.9995
            if Double.random(in: 0...1) > 0.9999 {
                secondaryPhase = 1.0
            }
            let swell = secondaryPhase * 0.4
            return (rumble + previousValue * 0.2) * (0.6 + swell)

        case .cityAmbience:
            // City night - distant traffic, occasional sounds
            phase += 1.0 / 44100.0
            // Base traffic hum
            let traffic = Double.random(in: -1...1)
            previousValue = 0.96 * previousValue + 0.04 * traffic
            // Distant car pass-by effect
            secondaryPhase *= 0.9999
            if Double.random(in: 0...1) > 0.9998 {
                secondaryPhase = 1.0
            }
            let passby = sin(phase * 2 * .pi * 80) * secondaryPhase * 0.2
            // Subtle urban tone
            let tone = sin(phase * 2 * .pi * 60) * 0.05
            return (previousValue * 0.3 + passby + tone)

        case .aquarium:
            // Aquarium bubbles - gentle, rhythmic bubbling
            phase += 1.0 / 44100.0
            // Base water ambience
            let water = Double.random(in: -1...1)
            previousValue = 0.92 * previousValue + 0.08 * water
            // Bubble sounds at varying rates
            var bubble = 0.0
            if Double.random(in: 0...1) > 0.997 {
                tertiaryValue = Double.random(in: 0.3...0.8)
            }
            if tertiaryValue > 0.01 {
                let bubbleFreq = 800 + Double.random(in: -200...200)
                bubble = sin(phase * 2 * .pi * bubbleFreq) * tertiaryValue
                tertiaryValue *= 0.97
            }
            // Gentle filter pump hum
            let pump = sin(phase * 2 * .pi * 60) * 0.05
            return (previousValue * 0.2 + bubble * 0.4 + pump)

        case .lullaby, .musicBox:
            // Simple music box melody
            phase += 1.0 / 44100.0
            let noteFreq: Double = [262, 294, 330, 349, 392][Int(phase * 0.5) % 5]
            let tone = sin(phase * 2 * .pi * noteFreq)
            let envelope = 0.5 + 0.5 * sin(phase * 2 * .pi * 0.2)
            return tone * envelope * 0.3

        case .softPiano:
            // Soft piano - gentle chord progressions
            phase += 1.0 / 44100.0
            // Simple chord (C major arpeggio with harmonics)
            let chordIndex = Int(phase * 0.3) % 4
            let baseFreqs: [[Double]] = [
                [262, 330, 392], // C major
                [220, 277, 330], // A minor
                [196, 247, 294], // G major
                [262, 330, 392]  // C major
            ]
            let freqs = baseFreqs[chordIndex]
            var chord = 0.0
            for (i, freq) in freqs.enumerated() {
                let harmonic = sin(phase * 2 * .pi * freq) * (1.0 - Double(i) * 0.2)
                chord += harmonic
            }
            // Piano-like envelope with soft attack
            let notePhase = fmod(phase * 0.3, 1.0)
            let envelope = exp(-notePhase * 2) * 0.8
            return chord / 3.0 * envelope * 0.4

        case .gentleGuitar:
            // Gentle acoustic guitar - fingerpicking pattern
            phase += 1.0 / 44100.0
            // Guitar strings with harmonics
            let stringIndex = Int(phase * 2) % 6
            let guitarFreqs: [Double] = [196, 247, 294, 330, 392, 440] // G chord pattern
            let freq = guitarFreqs[stringIndex]
            // Guitar tone with harmonics
            let fundamental = sin(phase * 2 * .pi * freq)
            let harmonic2 = sin(phase * 2 * .pi * freq * 2) * 0.3
            let harmonic3 = sin(phase * 2 * .pi * freq * 3) * 0.1
            let tone = fundamental + harmonic2 + harmonic3
            // Pluck envelope
            let pluckPhase = fmod(phase * 2, 1.0)
            let envelope = exp(-pluckPhase * 4)
            return tone * envelope * 0.25

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

// MARK: - Sound Mixer (for combining multiple sounds)
class SoundMixer: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var generators: [String: (node: AVAudioSourceNode, volume: Float, type: GeneratorType)] = [:]
    private var isRunning: Bool = false
    private let sampleRate: Double = 44100

    // Generator states (separate for each channel)
    private var generatorStates: [String: GeneratorState] = [:]

    struct GeneratorState {
        var phase: Double = 0
        var previousValue: Double = 0
        var secondaryPhase: Double = 0
        var tertiaryValue: Double = 0
        var blueNoiseState: Double = 0
    }

    @Published var activeChannels: [MixerChannel] = []

    struct MixerChannel: Identifiable, Equatable {
        let id: String
        let type: GeneratorType
        var volume: Float
        var isActive: Bool

        static func == (lhs: MixerChannel, rhs: MixerChannel) -> Bool {
            lhs.id == rhs.id
        }
    }

    init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()

        guard let engine = audioEngine, let mixer = mixerNode else { return }

        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }

    func addSound(_ type: GeneratorType, volume: Float = 0.5) -> String {
        let channelId = UUID().uuidString
        guard let engine = audioEngine, let mixer = mixerNode else { return channelId }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // Initialize state for this generator
        generatorStates[channelId] = GeneratorState()

        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self,
                  var state = self.generatorStates[channelId],
                  let channelVolume = self.generators[channelId]?.volume else {
                return noErr
            }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSampleForType(type, state: &state)
                let scaledSample = Float(sample) * channelVolume

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = scaledSample
                }
            }

            self.generatorStates[channelId] = state
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mixer, format: format)

        generators[channelId] = (sourceNode, volume, type)
        activeChannels.append(MixerChannel(id: channelId, type: type, volume: volume, isActive: true))

        if isRunning {
            // If mixer is already running, the new node will start automatically
        }

        return channelId
    }

    func removeSound(_ channelId: String) {
        guard let engine = audioEngine,
              let generator = generators[channelId] else { return }

        engine.detach(generator.node)
        generators.removeValue(forKey: channelId)
        generatorStates.removeValue(forKey: channelId)
        activeChannels.removeAll { $0.id == channelId }
    }

    func setChannelVolume(_ channelId: String, volume: Float) {
        if var generator = generators[channelId] {
            generator.volume = min(volume, 0.7) // Safety limit
            generators[channelId] = generator
        }

        if let index = activeChannels.firstIndex(where: { $0.id == channelId }) {
            activeChannels[index].volume = min(volume, 0.7)
        }
    }

    func setMasterVolume(_ volume: Float) {
        mixerNode?.outputVolume = min(volume, 0.7)
    }

    func start() {
        guard !isRunning, let engine = audioEngine else { return }

        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start sound mixer: \(error)")
        }
    }

    func stop() {
        audioEngine?.stop()
        isRunning = false
    }

    func removeAllSounds() {
        for channelId in generators.keys {
            removeSound(channelId)
        }
    }

    // Simplified sample generation for mixer (reuses main generator logic)
    private func generateSampleForType(_ type: GeneratorType, state: inout GeneratorState) -> Double {
        switch type {
        case .whiteNoise:
            return Double.random(in: -1...1)

        case .pinkNoise:
            let white = Double.random(in: -1...1)
            state.previousValue = 0.99 * state.previousValue + 0.01 * white
            return state.previousValue * 3

        case .brownNoise:
            let step = Double.random(in: -0.1...0.1)
            state.previousValue = max(-1, min(1, state.previousValue + step))
            return state.previousValue

        case .blueNoise:
            let white = Double.random(in: -1...1)
            let filtered = white - state.previousValue
            state.previousValue = white * 0.5
            return filtered * 0.6

        case .violetNoise:
            let white = Double.random(in: -1...1)
            let diff1 = white - state.previousValue
            let diff2 = diff1 - state.blueNoiseState
            state.previousValue = white
            state.blueNoiseState = diff1
            return diff2 * 0.4

        case .greyNoise:
            state.phase += 1.0 / sampleRate
            let white = Double.random(in: -1...1)
            let lowBoost = sin(state.phase * 2 * .pi * 100) * 0.15
            let midCut = sin(state.phase * 2 * .pi * 1000) * 0.05
            state.previousValue = 0.85 * state.previousValue + 0.15 * white
            return (state.previousValue + lowBoost - midCut) * 0.5

        case .velvetNoise:
            state.phase += 1.0 / sampleRate
            if Double.random(in: 0...1) < 0.02 {
                state.previousValue = Double.random(in: -1...1)
            }
            state.previousValue *= 0.9995
            return state.previousValue * 0.7

        case .rain:
            let noise = Double.random(in: -1...1)
            state.previousValue = 0.7 * state.previousValue + 0.3 * noise
            let drop = Double.random(in: 0...1) > 0.999 ? Double.random(in: 0.3...0.6) : 0
            return (state.previousValue * 0.5 + drop)

        case .rainOnRoof:
            state.phase += 1.0 / sampleRate
            let noise = Double.random(in: -1...1)
            state.previousValue = 0.92 * state.previousValue + 0.08 * noise
            let roofDrop = Double.random(in: 0...1) > 0.998 ? Double.random(in: 0.2...0.4) : 0
            let rumble = sin(state.phase * 2 * .pi * 40) * 0.08
            return (state.previousValue * 0.4 + roofDrop + rumble)

        case .ocean:
            state.phase += 1.0 / sampleRate
            let wavePhase = sin(state.phase * 2 * .pi * 0.1) * 0.5 + 0.5
            let noise = Double.random(in: -1...1)
            state.previousValue = 0.8 * state.previousValue + 0.2 * noise
            return state.previousValue * wavePhase * 0.7

        case .forest:
            state.phase += 1.0 / sampleRate
            state.secondaryPhase += 1.0 / sampleRate
            let rustling = Double.random(in: -1...1)
            state.previousValue = 0.9 * state.previousValue + 0.1 * rustling
            var birdChirp = 0.0
            if Double.random(in: 0...1) > 0.9997 {
                state.tertiaryValue = 1.0
            }
            if state.tertiaryValue > 0.01 {
                let birdFreq = 2000 + sin(state.secondaryPhase * 50) * 500
                birdChirp = sin(state.phase * 2 * .pi * birdFreq) * state.tertiaryValue * 0.3
                state.tertiaryValue *= 0.995
            }
            let breeze = sin(state.phase * 2 * .pi * 0.15) * 0.2 + 0.8
            return (state.previousValue * breeze * 0.4 + birdChirp)

        case .campfire:
            state.phase += 1.0 / sampleRate
            let crackle = Double.random(in: -1...1)
            state.previousValue = 0.8 * state.previousValue + 0.2 * crackle
            let pop = Double.random(in: 0...1) > 0.9995 ? Double.random(in: 0.4...0.7) : 0
            let cricketFreq = 4000 + sin(state.phase * 3) * 200
            let cricket = sin(state.phase * 2 * .pi * cricketFreq) * 0.05 * (sin(state.phase * 8) > 0 ? 1 : 0)
            return (state.previousValue * 0.35 + pop + cricket)

        default:
            // Fallback to filtered white noise
            let noise = Double.random(in: -1...1)
            state.previousValue = 0.8 * state.previousValue + 0.2 * noise
            return state.previousValue * 0.5
        }
    }

    // MARK: - Preset Mixes

    static func createSleepMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.greyNoise, 0.4), (.rainOnRoof, 0.3), (.softPiano, 0.2)]
        } else if ageMonths >= 12 {
            return [(.velvetNoise, 0.4), (.ocean, 0.3), (.chimes, 0.15)]
        } else if ageMonths >= 6 {
            return [(.pinkNoise, 0.4), (.rain, 0.3)]
        } else {
            return [(.womb, 0.4), (.heartbeat, 0.3)]
        }
    }

    static func createCalmMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.forest, 0.35), (.softPiano, 0.25), (.greyNoise, 0.2)]
        } else if ageMonths >= 12 {
            return [(.ocean, 0.35), (.birds, 0.2), (.velvetNoise, 0.25)]
        } else {
            return [(.pinkNoise, 0.4), (.ocean, 0.3)]
        }
    }

    static func createFocusMix(for ageMonths: Int) -> [(GeneratorType, Float)] {
        if ageMonths >= 18 {
            return [(.blueNoise, 0.3), (.aquarium, 0.25), (.forest, 0.2)]
        } else if ageMonths >= 12 {
            return [(.greyNoise, 0.35), (.river, 0.25)]
        } else {
            return [(.pinkNoise, 0.4), (.fan, 0.25)]
        }
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
