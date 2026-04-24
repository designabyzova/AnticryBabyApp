import Foundation
import WatchKit
import AVFoundation
import Combine

/// Audio player for Apple Watch using AVAudioPlayer (modern API)
/// Handles local audio playback with basic controls
/// Enhanced with standalone mode for when iPhone is not connected
@MainActor
final class WatchAudioPlayer: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchAudioPlayer()

    // MARK: - Published Properties

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrack: WatchTrack?
    @Published private(set) var progress: Double = 0  // 0.0 - 1.0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 0.7  // 0.0 - 1.0

    // Sleep timer
    @Published private(set) var sleepTimerActive = false
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0

    // MARK: - Standalone Mode Properties

    /// Whether playing standalone generated audio (no iPhone needed)
    @Published private(set) var isStandaloneMode = false

    /// Current standalone sound type being played
    @Published private(set) var currentStandaloneSound: StandaloneSoundType?

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Playlist management
    private var playlist: [WatchTrack] = []
    private var currentIndex: Int = 0
    private var shuffleEnabled = false
    private var repeatMode: RepeatMode = .none

    enum RepeatMode {
        case none
        case all
        case one
    }

    /// Standalone sound types (inline definition for simplicity)
    /// ⚠️ UPDATED (2026-01-09): Removed oceanWaves - too noisy for babies!
    enum StandaloneSoundType: String, CaseIterable, Identifiable {
        case heartbeat = "Heartbeat"
        case lullaby = "Lullaby"
        case musicBox = "Music Box"
        case gentleChimes = "Gentle Chimes"
        case softPiano = "Soft Piano"  // Replacement for ocean waves

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .heartbeat: return "heart.fill"
            case .lullaby: return "music.note"
            case .musicBox: return "music.note.house"
            case .gentleChimes: return "bell"
            case .softPiano: return "pianokeys"
            }
        }

        var description: String {
            switch self {
            case .heartbeat: return "Soothing heartbeat rhythm"
            case .lullaby: return "Gentle lullaby melody"
            case .musicBox: return "Classic music box tune"
            case .gentleChimes: return "Soft wind chimes"
            case .softPiano: return "Relaxing piano melody"
            }
        }

        var loopDuration: TimeInterval {
            switch self {
            case .heartbeat: return 4.0
            case .lullaby: return 8.0
            case .musicBox: return 6.0
            case .gentleChimes: return 5.0
            case .softPiano: return 8.0
            }
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        // Note: watchOS has limited audio session capabilities
        // Audio plays through the watch speaker or connected Bluetooth headphones
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("[WatchAudioPlayer] Audio session configured")
        } catch {
            print("[WatchAudioPlayer] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Standalone Mode API

    /// Play standalone generated sound (works without iPhone)
    /// FIXED: Audio generation now runs on background thread to prevent UI hang
    func playStandalone(_ soundType: StandaloneSoundType) {
        // Stop any current playback
        stop()

        isStandaloneMode = true
        currentStandaloneSound = soundType

        // Create a virtual track for UI display
        currentTrack = WatchTrack(
            id: "standalone-\(soundType.rawValue)",
            title: soundType.rawValue,
            artist: "Soothbee Watch",
            duration: soundType.loopDuration,
            category: "Generated"
        )
        duration = soundType.loopDuration

        // Show immediate feedback to user
        isPlaying = true
        WKInterfaceDevice.current().play(.start)
        print("[WatchAudioPlayer] Starting standalone: \(soundType.rawValue)")

        // Generate audio on BACKGROUND thread to prevent UI hang
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                // Heavy CPU work happens OFF MainActor
                let audioData = try self?.generateAudioBackground(for: soundType)

                // Switch back to MainActor for playback
                await MainActor.run {
                    guard let self = self, let audioData = audioData else { return }

                    // Only proceed if still in standalone mode (user might have cancelled)
                    guard self.isStandaloneMode && self.currentStandaloneSound == soundType else {
                        print("[WatchAudioPlayer] Standalone mode cancelled during generation")
                        return
                    }

                    do {
                        try self.playGeneratedAudioSync(audioData, soundType: soundType)
                        print("[WatchAudioPlayer] Playing standalone: \(soundType.rawValue)")
                    } catch {
                        print("[WatchAudioPlayer] Failed to play standalone: \(error)")
                        self.isPlaying = false
                        self.currentStandaloneSound = nil
                        self.isStandaloneMode = false
                        WKInterfaceDevice.current().play(.failure)
                    }
                }
            } catch {
                await MainActor.run {
                    print("[WatchAudioPlayer] Failed to generate audio: \(error)")
                    self?.isPlaying = false
                    self?.currentStandaloneSound = nil
                    self?.isStandaloneMode = false
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }

    /// Generate audio on background thread (non-isolated)
    private nonisolated func generateAudioBackground(for soundType: StandaloneSoundType) throws -> Data {
        let sampleRate: Double = 44100
        let duration = soundType.loopDuration
        let numSamples = Int(sampleRate * duration)

        var samples = [Float](repeating: 0, count: numSamples)

        switch soundType {
        case .heartbeat:
            generateHeartbeatBackground(into: &samples, sampleRate: sampleRate)
        case .lullaby:
            generateLullabyBackground(into: &samples, sampleRate: sampleRate)
        case .musicBox:
            generateMusicBoxBackground(into: &samples, sampleRate: sampleRate)
        case .gentleChimes:
            generateChimesBackground(into: &samples, sampleRate: sampleRate)
        case .softPiano:
            generateSoftPianoBackground(into: &samples, sampleRate: sampleRate)
        }

        // Apply soft envelope to avoid clicks
        applyEnvelopeBackground(to: &samples, attackSamples: 1000, releaseSamples: 1000)

        // Normalize and convert to 16-bit PCM
        return createWAVDataBackground(from: samples, sampleRate: Int(sampleRate))
    }

    /// Play default standalone sound
    func playDefaultStandalone() {
        playStandalone(.lullaby)
    }

    /// Play emergency standalone sound (best for quick calming)
    func playEmergencyStandalone() {
        playStandalone(.heartbeat)
    }

    /// Get available standalone sounds
    var availableStandaloneSounds: [StandaloneSoundType] {
        StandaloneSoundType.allCases
    }

    // MARK: - Public API

    /// Play a single track
    func play(track: WatchTrack) {
        guard let url = track.localURL else {
            print("[WatchAudioPlayer] No local URL for track: \(track.title)")
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[WatchAudioPlayer] File not found: \(url.path)")
            return
        }

        // Stop current playback
        stop()

        do {
            // Create AVAudioPlayer for file playback
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()

            // Update state
            currentTrack = track
            duration = audioPlayer?.duration ?? track.duration
            currentTime = 0
            progress = 0

            // Start playback
            audioPlayer?.play()
            isPlaying = true

            // Start progress tracking
            startProgressTimer()

            // Haptic feedback
            WKInterfaceDevice.current().play(.start)

            print("[WatchAudioPlayer] Playing: \(track.title)")
        } catch {
            print("[WatchAudioPlayer] Failed to create player: \(error)")
        }
    }

    /// Play from playlist
    func playPlaylist(_ tracks: [WatchTrack], startIndex: Int = 0) {
        playlist = tracks
        currentIndex = startIndex

        if let track = tracks[safe: startIndex] {
            play(track: track)
        }
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
        WKInterfaceDevice.current().play(.stop)
        print("[WatchAudioPlayer] Paused")
    }

    /// Resume playback
    /// FIXED: If audioPlayer is nil but we have standalone sound, restart it
    func resume() {
        // If we have an audioPlayer, just resume it
        if let player = audioPlayer {
            player.play()
            isPlaying = true
            startProgressTimer()
            WKInterfaceDevice.current().play(.start)
            print("[WatchAudioPlayer] Resumed")
            return
        }

        // If audioPlayer is nil but we were in standalone mode, restart the sound
        if let soundType = currentStandaloneSound {
            print("[WatchAudioPlayer] Restarting standalone sound: \(soundType.rawValue)")
            playStandalone(soundType)
            return
        }

        // If we have a current track (from playlist), try to replay it
        if let track = currentTrack {
            print("[WatchAudioPlayer] Replaying track: \(track.title)")
            play(track: track)
            return
        }

        print("[WatchAudioPlayer] Nothing to resume")
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Stop playback completely
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTrack = nil
        currentTime = 0
        progress = 0
        duration = 0
        isStandaloneMode = false
        currentStandaloneSound = nil
        stopProgressTimer()
        print("[WatchAudioPlayer] Stopped")
    }

    /// Skip to next track
    func skipNext() {
        guard !playlist.isEmpty else { return }

        if repeatMode == .one {
            // Restart current track
            if let track = currentTrack {
                play(track: track)
            }
            return
        }

        var nextIndex = currentIndex + 1

        if nextIndex >= playlist.count {
            if repeatMode == .all {
                nextIndex = 0
            } else {
                stop()
                return
            }
        }

        currentIndex = nextIndex
        if let track = playlist[safe: nextIndex] {
            play(track: track)
        }
    }

    /// Skip to previous track
    func skipPrevious() {
        guard !playlist.isEmpty else { return }

        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            if let track = currentTrack {
                play(track: track)
            }
            return
        }

        var prevIndex = currentIndex - 1

        if prevIndex < 0 {
            if repeatMode == .all {
                prevIndex = playlist.count - 1
            } else {
                prevIndex = 0
            }
        }

        currentIndex = prevIndex
        if let track = playlist[safe: prevIndex] {
            play(track: track)
        }
    }

    /// Seek to position (0.0 - 1.0)
    func seek(to position: Double) {
        guard let audioPlayer = audioPlayer else { return }

        let targetTime = duration * position
        audioPlayer.currentTime = targetTime
        currentTime = targetTime
        progress = position
    }

    // MARK: - Sleep Timer

    /// Set sleep timer
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()

        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimerActive = true

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.sleepTimerRemaining -= 1

                if self.sleepTimerRemaining <= 0 {
                    self.handleSleepTimerExpired()
                }
            }
        }

        WKInterfaceDevice.current().play(.success)
        print("[WatchAudioPlayer] Sleep timer set for \(minutes) minutes")
    }

    /// Cancel sleep timer
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerActive = false
        sleepTimerRemaining = 0
        print("[WatchAudioPlayer] Sleep timer cancelled")
    }

    private func handleSleepTimerExpired() {
        cancelSleepTimer()
        pause()
        WKInterfaceDevice.current().play(.notification)
        print("[WatchAudioPlayer] Sleep timer expired")
    }

    // MARK: - Volume Control (Digital Crown)

    /// Adjust volume (for Digital Crown integration)
    func adjustVolume(by delta: Float) {
        volume = max(0, min(1, volume + delta))
        // Note: Watch volume is system-controlled
        // This is for UI display purposes
    }

    // MARK: - Private Helpers

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying, duration > 0 else { return }

        if let audioPlayer = audioPlayer {
            currentTime = audioPlayer.currentTime
            progress = min(1.0, currentTime / duration)
        } else if isStandaloneMode {
            // For standalone mode, increment time manually
            currentTime += 0.5
            if currentTime >= duration {
                currentTime = 0 // Loop
            }
            progress = min(1.0, currentTime / duration)
        }
    }

    private func handleTrackEnded() {
        print("[WatchAudioPlayer] Track ended")
        skipNext()
    }

    // MARK: - Audio Generation (for standalone mode)

    /// Generate audio data for a sound type
    private func generateAudio(for soundType: StandaloneSoundType) throws -> Data {
        let sampleRate: Double = 44100
        let duration = soundType.loopDuration
        let numSamples = Int(sampleRate * duration)

        var samples = [Float](repeating: 0, count: numSamples)

        switch soundType {
        case .heartbeat:
            generateHeartbeat(into: &samples, sampleRate: sampleRate)
        case .lullaby:
            generateLullaby(into: &samples, sampleRate: sampleRate)
        case .musicBox:
            generateMusicBox(into: &samples, sampleRate: sampleRate)
        case .gentleChimes:
            generateChimes(into: &samples, sampleRate: sampleRate)
        case .softPiano:
            generateSoftPiano(into: &samples, sampleRate: sampleRate)
        }

        // Apply soft envelope to avoid clicks
        applyEnvelope(to: &samples, attackSamples: 1000, releaseSamples: 1000)

        // Normalize and convert to 16-bit PCM
        return createWAVData(from: samples, sampleRate: Int(sampleRate))
    }

    /// Play generated audio data with looping (async version - DEPRECATED)
    private func playGeneratedAudio(_ data: Data, soundType: StandaloneSoundType) async throws {
        try playGeneratedAudioSync(data, soundType: soundType)
    }

    /// Play generated audio data with looping (synchronous, must be called on MainActor)
    private func playGeneratedAudioSync(_ data: Data, soundType: StandaloneSoundType) throws {
        // Create temp file for AVAudioPlayer
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("standalone_\(soundType.rawValue).wav")
        try data.write(to: tempURL)

        audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
        audioPlayer?.delegate = self
        audioPlayer?.numberOfLoops = -1 // Infinite loop
        audioPlayer?.volume = volume
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        startProgressTimer()
    }

    // MARK: - Sound Generators

    /// Generate heartbeat sound (two thumps per beat)
    private func generateHeartbeat(into samples: inout [Float], sampleRate: Double) {
        let bpm: Double = 65
        let beatInterval = 60.0 / bpm
        let numBeats = Int(Double(samples.count) / sampleRate / beatInterval) + 1

        for beat in 0..<numBeats {
            let beatStart = Int(Double(beat) * beatInterval * sampleRate)
            addPulse(to: &samples, startSample: beatStart, frequency: 45, duration: 0.12, sampleRate: sampleRate, amplitude: 0.7)
            let dubStart = beatStart + Int(0.15 * sampleRate)
            addPulse(to: &samples, startSample: dubStart, frequency: 55, duration: 0.08, sampleRate: sampleRate, amplitude: 0.5)
        }
    }

    /// Generate simple lullaby melody
    private func generateLullaby(into samples: inout [Float], sampleRate: Double) {
        let notes: [(frequency: Double, duration: Double, startTime: Double)] = [
            (261.63, 0.5, 0.0), (329.63, 0.5, 0.5), (392.00, 0.5, 1.0), (329.63, 0.5, 1.5),
            (261.63, 0.5, 2.0), (293.66, 0.5, 2.5), (329.63, 0.75, 3.0), (261.63, 0.75, 3.75),
            (261.63, 0.5, 4.5), (329.63, 0.5, 5.0), (392.00, 0.5, 5.5), (329.63, 0.5, 6.0),
            (261.63, 1.0, 6.5),
        ]
        for note in notes {
            addSineNote(to: &samples, startTime: note.startTime, duration: note.duration,
                       frequency: note.frequency, sampleRate: sampleRate, amplitude: 0.4)
        }
    }

    /// Generate music box sound
    private func generateMusicBox(into samples: inout [Float], sampleRate: Double) {
        let notes: [(frequency: Double, duration: Double, startTime: Double)] = [
            (523.25, 0.3, 0.0), (587.33, 0.3, 0.4), (659.25, 0.3, 0.8), (523.25, 0.3, 1.2),
            (698.46, 0.3, 1.6), (659.25, 0.3, 2.0), (587.33, 0.3, 2.4), (523.25, 0.4, 2.8),
            (392.00, 0.3, 3.3), (440.00, 0.3, 3.7), (493.88, 0.3, 4.1), (523.25, 0.5, 4.5),
        ]
        for note in notes {
            addMusicBoxNote(to: &samples, startTime: note.startTime, duration: note.duration,
                           frequency: note.frequency, sampleRate: sampleRate, amplitude: 0.35)
        }
    }

    /// Generate soft piano melody (replaced ocean waves - too noisy!)
    private func generateSoftPiano(into samples: inout [Float], sampleRate: Double) {
        // Gentle chord progression in C major - very soothing for babies
        // I - vi - IV - V pattern at 60 BPM (very slow, relaxing)
        let chords: [[(frequency: Double, amplitude: Double)]] = [
            // C major
            [(261.63, 0.5), (329.63, 0.4), (392.00, 0.35)],
            // A minor
            [(220.00, 0.5), (261.63, 0.4), (329.63, 0.35)],
            // F major
            [(174.61, 0.5), (261.63, 0.4), (349.23, 0.35)],
            // G major
            [(196.00, 0.5), (246.94, 0.4), (392.00, 0.35)],
        ]

        let chordDuration = 2.0  // 2 seconds per chord

        for (chordIndex, chord) in chords.enumerated() {
            let startTime = Double(chordIndex) * chordDuration
            for note in chord {
                addPianoNote(to: &samples, startTime: startTime, duration: chordDuration - 0.1,
                            frequency: note.frequency, sampleRate: sampleRate, amplitude: Float(note.amplitude) * 0.5)
            }
        }
    }

    /// Add a soft piano note with realistic envelope
    private func addPianoNote(to samples: inout [Float], startTime: Double, duration: Double,
                              frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)

        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Piano-like envelope: fast attack, slow decay
            var envelope: Float = 1.0
            if progress < 0.02 { envelope = Float(progress / 0.02) }  // Quick attack
            else { envelope = Float(exp(-progress * 2.0)) }  // Slow exponential decay

            // Piano has rich harmonics
            let fundamental = sin(2 * .pi * frequency * t)
            let harmonic2 = sin(2 * .pi * frequency * 2 * t) * 0.3
            let harmonic3 = sin(2 * .pi * frequency * 3 * t) * 0.15
            let tone = fundamental + harmonic2 + harmonic3

            samples[sampleIndex] += Float(tone) * amplitude * envelope
        }
    }

    /// Generate gentle chimes
    private func generateChimes(into samples: inout [Float], sampleRate: Double) {
        let chimeNotes: [Double] = [523.25, 587.33, 659.25, 784.00, 880.00]
        let hits: [(frequency: Double, startTime: Double, amplitude: Double)] = [
            (chimeNotes[0], 0.0, 0.6), (chimeNotes[2], 0.3, 0.5), (chimeNotes[4], 0.8, 0.4),
            (chimeNotes[1], 1.5, 0.5), (chimeNotes[3], 2.0, 0.55), (chimeNotes[0], 2.8, 0.45),
            (chimeNotes[4], 3.2, 0.5), (chimeNotes[2], 3.8, 0.4), (chimeNotes[3], 4.2, 0.35),
        ]
        for hit in hits {
            addChimeNote(to: &samples, startTime: hit.startTime, frequency: hit.frequency,
                        sampleRate: sampleRate, amplitude: Float(hit.amplitude))
        }
    }

    // MARK: - Sound Primitives

    private func addPulse(to samples: inout [Float], startSample: Int, frequency: Double,
                         duration: Double, sampleRate: Double, amplitude: Float) {
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 15))
            let sample = sin(2 * .pi * frequency * t) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private func addSineNote(to samples: inout [Float], startTime: Double, duration: Double,
                            frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let progress = t / duration
            var envelope: Float = 1.0
            if progress < 0.1 { envelope = Float(progress / 0.1) }
            else if progress > 0.7 { envelope = Float(1 - (progress - 0.7) / 0.3) }
            let sample = sin(2 * .pi * frequency * t) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private func addMusicBoxNote(to samples: inout [Float], startTime: Double, duration: Double,
                                frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 5))
            let fundamental = sin(2 * .pi * frequency * t)
            let harmonic2 = sin(2 * .pi * frequency * 2 * t) * 0.3
            let harmonic3 = sin(2 * .pi * frequency * 3 * t) * 0.1
            let sample = (fundamental + harmonic2 + harmonic3) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private func addChimeNote(to samples: inout [Float], startTime: Double, frequency: Double,
                             sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let decayTime: Double = 2.0
        let numSamples = Int(decayTime * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 1.5))
            let detune = 1.002
            let wave1 = sin(2 * .pi * frequency * t)
            let wave2 = sin(2 * .pi * frequency * detune * t) * 0.5
            let sample = (wave1 + wave2) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private func applyEnvelope(to samples: inout [Float], attackSamples: Int, releaseSamples: Int) {
        for i in 0..<min(attackSamples, samples.count) {
            let envelope = Float(i) / Float(attackSamples)
            samples[i] *= envelope
        }
        let releaseStart = samples.count - releaseSamples
        for i in max(0, releaseStart)..<samples.count {
            let envelope = Float(samples.count - i) / Float(releaseSamples)
            samples[i] *= envelope
        }
    }

    private func createWAVData(from samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample) / 8)
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let int16Sample = Int16(clamped * 32767)
            data.append(contentsOf: withUnsafeBytes(of: int16Sample.littleEndian) { Array($0) })
        }
        return data
    }

    // MARK: - Background Sound Generators (nonisolated for off-main-thread execution)

    /// Generate heartbeat sound (background thread safe)
    private nonisolated func generateHeartbeatBackground(into samples: inout [Float], sampleRate: Double) {
        let bpm: Double = 65
        let beatInterval = 60.0 / bpm
        let numBeats = Int(Double(samples.count) / sampleRate / beatInterval) + 1

        for beat in 0..<numBeats {
            let beatStart = Int(Double(beat) * beatInterval * sampleRate)
            addPulseBackground(to: &samples, startSample: beatStart, frequency: 45, duration: 0.12, sampleRate: sampleRate, amplitude: 0.7)
            let dubStart = beatStart + Int(0.15 * sampleRate)
            addPulseBackground(to: &samples, startSample: dubStart, frequency: 55, duration: 0.08, sampleRate: sampleRate, amplitude: 0.5)
        }
    }

    /// Generate lullaby melody (background thread safe)
    private nonisolated func generateLullabyBackground(into samples: inout [Float], sampleRate: Double) {
        let notes: [(frequency: Double, duration: Double, startTime: Double)] = [
            (261.63, 0.5, 0.0), (329.63, 0.5, 0.5), (392.00, 0.5, 1.0), (329.63, 0.5, 1.5),
            (261.63, 0.5, 2.0), (293.66, 0.5, 2.5), (329.63, 0.75, 3.0), (261.63, 0.75, 3.75),
            (261.63, 0.5, 4.5), (329.63, 0.5, 5.0), (392.00, 0.5, 5.5), (329.63, 0.5, 6.0),
            (261.63, 1.0, 6.5),
        ]
        for note in notes {
            addSineNoteBackground(to: &samples, startTime: note.startTime, duration: note.duration,
                       frequency: note.frequency, sampleRate: sampleRate, amplitude: 0.4)
        }
    }

    /// Generate music box sound (background thread safe)
    private nonisolated func generateMusicBoxBackground(into samples: inout [Float], sampleRate: Double) {
        let notes: [(frequency: Double, duration: Double, startTime: Double)] = [
            (523.25, 0.3, 0.0), (587.33, 0.3, 0.4), (659.25, 0.3, 0.8), (523.25, 0.3, 1.2),
            (698.46, 0.3, 1.6), (659.25, 0.3, 2.0), (587.33, 0.3, 2.4), (523.25, 0.4, 2.8),
            (392.00, 0.3, 3.3), (440.00, 0.3, 3.7), (493.88, 0.3, 4.1), (523.25, 0.5, 4.5),
        ]
        for note in notes {
            addMusicBoxNoteBackground(to: &samples, startTime: note.startTime, duration: note.duration,
                           frequency: note.frequency, sampleRate: sampleRate, amplitude: 0.35)
        }
    }

    /// Generate soft piano (background thread safe)
    private nonisolated func generateSoftPianoBackground(into samples: inout [Float], sampleRate: Double) {
        let chords: [[(frequency: Double, amplitude: Double)]] = [
            [(261.63, 0.5), (329.63, 0.4), (392.00, 0.35)],
            [(220.00, 0.5), (261.63, 0.4), (329.63, 0.35)],
            [(174.61, 0.5), (261.63, 0.4), (349.23, 0.35)],
            [(196.00, 0.5), (246.94, 0.4), (392.00, 0.35)],
        ]

        let chordDuration = 2.0

        for (chordIndex, chord) in chords.enumerated() {
            let startTime = Double(chordIndex) * chordDuration
            for note in chord {
                addPianoNoteBackground(to: &samples, startTime: startTime, duration: chordDuration - 0.1,
                            frequency: note.frequency, sampleRate: sampleRate, amplitude: Float(note.amplitude) * 0.5)
            }
        }
    }

    /// Generate chimes (background thread safe)
    private nonisolated func generateChimesBackground(into samples: inout [Float], sampleRate: Double) {
        let chimeNotes: [Double] = [523.25, 587.33, 659.25, 784.00, 880.00]
        let hits: [(frequency: Double, startTime: Double, amplitude: Double)] = [
            (chimeNotes[0], 0.0, 0.6), (chimeNotes[2], 0.3, 0.5), (chimeNotes[4], 0.8, 0.4),
            (chimeNotes[1], 1.5, 0.5), (chimeNotes[3], 2.0, 0.55), (chimeNotes[0], 2.8, 0.45),
            (chimeNotes[4], 3.2, 0.5), (chimeNotes[2], 3.8, 0.4), (chimeNotes[3], 4.2, 0.35),
        ]
        for hit in hits {
            addChimeNoteBackground(to: &samples, startTime: hit.startTime, frequency: hit.frequency,
                        sampleRate: sampleRate, amplitude: Float(hit.amplitude))
        }
    }

    // MARK: - Background Sound Primitives

    private nonisolated func addPulseBackground(to samples: inout [Float], startSample: Int, frequency: Double,
                         duration: Double, sampleRate: Double, amplitude: Float) {
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 15))
            let sample = sin(2 * .pi * frequency * t) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private nonisolated func addSineNoteBackground(to samples: inout [Float], startTime: Double, duration: Double,
                            frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let progress = t / duration
            var envelope: Float = 1.0
            if progress < 0.1 { envelope = Float(progress / 0.1) }
            else if progress > 0.7 { envelope = Float(1 - (progress - 0.7) / 0.3) }
            let sample = sin(2 * .pi * frequency * t) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private nonisolated func addMusicBoxNoteBackground(to samples: inout [Float], startTime: Double, duration: Double,
                                frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 5))
            let fundamental = sin(2 * .pi * frequency * t)
            let harmonic2 = sin(2 * .pi * frequency * 2 * t) * 0.3
            let harmonic3 = sin(2 * .pi * frequency * 3 * t) * 0.1
            let sample = (fundamental + harmonic2 + harmonic3) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private nonisolated func addPianoNoteBackground(to samples: inout [Float], startTime: Double, duration: Double,
                              frequency: Double, sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let numSamples = Int(duration * sampleRate)

        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let progress = t / duration

            var envelope: Float = 1.0
            if progress < 0.02 { envelope = Float(progress / 0.02) }
            else { envelope = Float(exp(-progress * 2.0)) }

            let fundamental = sin(2 * .pi * frequency * t)
            let harmonic2 = sin(2 * .pi * frequency * 2 * t) * 0.3
            let harmonic3 = sin(2 * .pi * frequency * 3 * t) * 0.15
            let tone = fundamental + harmonic2 + harmonic3

            samples[sampleIndex] += Float(tone) * amplitude * envelope
        }
    }

    private nonisolated func addChimeNoteBackground(to samples: inout [Float], startTime: Double, frequency: Double,
                             sampleRate: Double, amplitude: Float) {
        let startSample = Int(startTime * sampleRate)
        let decayTime: Double = 2.0
        let numSamples = Int(decayTime * sampleRate)
        for i in 0..<numSamples {
            let sampleIndex = startSample + i
            guard sampleIndex < samples.count else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 1.5))
            let detune = 1.002
            let wave1 = sin(2 * .pi * frequency * t)
            let wave2 = sin(2 * .pi * frequency * detune * t) * 0.5
            let sample = (wave1 + wave2) * Double(amplitude * envelope)
            samples[sampleIndex] += Float(sample)
        }
    }

    private nonisolated func applyEnvelopeBackground(to samples: inout [Float], attackSamples: Int, releaseSamples: Int) {
        for i in 0..<min(attackSamples, samples.count) {
            let envelope = Float(i) / Float(attackSamples)
            samples[i] *= envelope
        }
        let releaseStart = samples.count - releaseSamples
        for i in max(0, releaseStart)..<samples.count {
            let envelope = Float(samples.count - i) / Float(releaseSamples)
            samples[i] *= envelope
        }
    }

    private nonisolated func createWAVDataBackground(from samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample) / 8)
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let int16Sample = Int16(clamped * 32767)
            data.append(contentsOf: withUnsafeBytes(of: int16Sample.littleEndian) { Array($0) })
        }
        return data
    }
}

// MARK: - AVAudioPlayerDelegate

extension WatchAudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag && !isStandaloneMode {
                handleTrackEnded()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("[WatchAudioPlayer] Decode error: \(error?.localizedDescription ?? "unknown")")
            stop()
        }
    }
}

// MARK: - Convenience Extensions

extension WatchAudioPlayer {
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var formattedSleepTimer: String {
        formatTime(sleepTimerRemaining)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
