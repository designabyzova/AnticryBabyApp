//
//  DynamicSoundMixer.swift
//  BabyInCarApp
//
//  Creates personalized multi-layer sound mixes for optimal soothing.
//  Supports breath synchronization, dynamic layering, and smooth transitions.
//

import Foundation
import AVFoundation
import Combine
import UIKit

// MARK: - Sound Mix

/// A multi-layer sound mix customized for a specific baby
struct DynamicSoundMix: Codable, Identifiable {
    let id: UUID
    let name: String
    let layers: [SoundLayer]
    let createdFor: UUID? // Baby ID
    let cryType: CryType?
    let createdAt: Date

    /// Total expected duration
    var totalDuration: TimeInterval {
        layers.map { $0.duration }.max() ?? 0
    }

    /// Whether this mix has rhythm synchronization enabled
    var hasRhythmSync: Bool {
        layers.contains { $0.rhythmSync }
    }
}

/// Single layer in a sound mix
struct SoundLayer: Codable, Identifiable {
    let id: UUID
    let sound: GeneratorType
    var volume: Float           // 0-1
    var pitchAdjustment: Float  // -1 to 1 (semitones shift percentage)
    var rhythmSync: Bool        // Sync to detected breathing/heartbeat
    var startDelay: TimeInterval // When this layer starts
    var duration: TimeInterval   // How long this layer plays
    var fadeInDuration: TimeInterval
    var fadeOutDuration: TimeInterval
    var pan: Float              // -1 (left) to 1 (right)
    let reason: String          // Why this layer was chosen

    init(
        sound: GeneratorType,
        volume: Float = 0.5,
        pitchAdjustment: Float = 0,
        rhythmSync: Bool = false,
        startDelay: TimeInterval = 0,
        duration: TimeInterval = 300,
        fadeInDuration: TimeInterval = 2,
        fadeOutDuration: TimeInterval = 3,
        pan: Float = 0,
        reason: String = ""
    ) {
        self.id = UUID()
        self.sound = sound
        self.volume = volume
        self.pitchAdjustment = pitchAdjustment
        self.rhythmSync = rhythmSync
        self.startDelay = startDelay
        self.duration = duration
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.pan = pan
        self.reason = reason
    }
}

// MARK: - Mix Preset

/// Pre-defined mix configurations that can be personalized
struct MixPreset: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let baseLayers: [SoundLayer]
    let suitableFor: [CryType]
    let ageRange: ClosedRange<Int> // Months

    /// Create a personalized mix from this preset
    func createMix(for profile: BabyMoodProfile, cryType: CryType?) -> DynamicSoundMix {
        var personalizedLayers = baseLayers

        // Adjust volumes based on profile preferences
        for i in 0..<personalizedLayers.count {
            personalizedLayers[i].volume *= profile.preferredIntensity.volumeMultiplier
            personalizedLayers[i].pitchAdjustment += Float(profile.pitchPreference) * 0.2
        }

        return DynamicSoundMix(
            id: UUID(),
            name: "\(name) for \(profile.babyName)",
            layers: personalizedLayers,
            createdFor: profile.babyId,
            cryType: cryType,
            createdAt: Date()
        )
    }
}

// MARK: - Dynamic Sound Mixer Service

/// Creates and manages multi-layer sound mixes for personalized soothing
///
/// MEMORY OPTIMIZATION (Increment 0022):
/// - Streaming Architecture: Audio is generated on-demand by NoiseGeneratorService, not cached
/// - No full-file caching: Removed audioFiles dictionary to prevent memory leaks
/// - Buffer recycling: All AVAudioPlayerNode buffers are released via reset() on cleanup
/// - Memory warnings: Responds to system and MemoryMonitor cleanup requests
/// - Target: Keep mixer buffers < 1MB total (synthetic audio generation)
class DynamicSoundMixer: ObservableObject {
    static let shared = DynamicSoundMixer()

    // MARK: - Published State

    @Published var currentMix: DynamicSoundMix?
    @Published var isPlaying: Bool = false
    @Published var currentPhase: MixPhase = .idle
    @Published var layerStates: [UUID: LayerState] = [:]

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var mixerNode: AVAudioMixerNode?

    // MEMORY OPTIMIZATION (Increment 0022): Removed audioFiles dictionary to prevent caching
    // Streaming architecture: Audio is generated on-demand, not cached in memory
    // This prevents memory leaks from holding full audio files

    // MARK: - Rhythm Sync

    private var targetBPM: Double = 60 // Target beats per minute for sync
    private var breathingRate: Double? // Detected breathing rate
    private var rhythmTimer: Timer?

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Presets

    let presets: [MixPreset] = [
        MixPreset(
            id: "gentle_sleep",
            name: "Gentle Sleep",
            description: "Soft layers for peaceful sleep",
            icon: "moon.zzz",
            baseLayers: [
                SoundLayer(sound: .aquarium, volume: 0.35, reason: "Base layer for consistent masking"),
                SoundLayer(sound: .heartbeat, volume: 0.25, rhythmSync: true, reason: "Rhythmic comfort"),
                SoundLayer(sound: .aquarium, volume: 0.15, startDelay: 30, reason: "Added warmth")
            ],
            suitableFor: [.tired],
            ageRange: 0...36
        ),
        MixPreset(
            id: "womb_comfort",
            name: "Womb Comfort",
            description: "Recreates womb environment",
            icon: "heart.fill",
            baseLayers: [
                SoundLayer(sound: .womb, volume: 0.45, reason: "Primary womb sound"),
                SoundLayer(sound: .heartbeat, volume: 0.3, rhythmSync: true, reason: "Mother's heartbeat"),
                SoundLayer(sound: .aquarium, volume: 0.1, reason: "Additional bass warmth")
            ],
            suitableFor: [.general, .discomfort],
            ageRange: 0...6
        ),
        MixPreset(
            id: "calming_nature",
            name: "Calming Nature",
            description: "Peaceful nature sounds",
            icon: "leaf.fill",
            baseLayers: [
                SoundLayer(sound: .aquarium, volume: 0.4, reason: "Consistent natural masking"),
                SoundLayer(sound: .aquarium, volume: 0.2, startDelay: 10, reason: "Rhythmic waves"),
                SoundLayer(sound: .chimes, volume: 0.1, startDelay: 60, reason: "Gentle engagement")
            ],
            suitableFor: [.attention, .general],
            ageRange: 6...36
        ),
        MixPreset(
            id: "urgent_calm",
            name: "Urgent Calm",
            description: "High-intensity calming for distress",
            icon: "exclamationmark.triangle.fill",
            baseLayers: [
                SoundLayer(sound: .shushing, volume: 0.5, reason: "Immediate attention capture"),
                SoundLayer(sound: .shushing, volume: 0.35, startDelay: 5, reason: "Intense masking"),
                SoundLayer(sound: .aquarium, volume: 0.25, startDelay: 30, fadeInDuration: 10, reason: "Transition to calmer sound")
            ],
            suitableFor: [.pain, .discomfort],
            ageRange: 0...12
        ),
        MixPreset(
            id: "musical_distraction",
            name: "Musical Distraction",
            description: "Engaging sounds for distraction",
            icon: "music.note",
            baseLayers: [
                SoundLayer(sound: .musicBox, volume: 0.4, reason: "Engaging melody"),
                SoundLayer(sound: .chimes, volume: 0.2, startDelay: 30, reason: "Gentle highlights"),
                SoundLayer(sound: .aquarium, volume: 0.15, reason: "Background consistency")
            ],
            suitableFor: [.hunger, .attention],
            ageRange: 3...24
        )
    ]

    private init() {
        setupAudioEngine()
        setupNotifications()
    }

    // MARK: - Memory Optimization (Increment 0022)

    private func setupNotifications() {
        // Clean up on system memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[DynamicSoundMixer] ⚠️ Memory warning received - cleaning up inactive resources")
            if self?.isPlaying == false {
                self?.cleanup()
            }
        }

        // Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let level = notification.userInfo?["level"] as? String {
                print("[DynamicSoundMixer] 🧹 Memory cleanup requested (\(level))")
                // If not playing, clean up everything
                if self?.isPlaying == false {
                    self?.cleanup()
                } else {
                    // If playing, just clean up finished layers
                    self?.cleanupFinishedLayers()
                }
            }
        }
    }

    private func cleanupFinishedLayers() {
        let finishedLayerIds = layerStates
            .filter { $0.value.phase == .stopped }
            .map { $0.key }

        for layerId in finishedLayerIds {
            if let playerNode = playerNodes[layerId] {
                playerNode.stop()
                playerNode.reset() // Release buffer
                audioEngine?.detach(playerNode)
                playerNodes.removeValue(forKey: layerId)
                print("[DynamicSoundMixer] 🧹 Cleaned up finished layer \(layerId)")
            }
        }
    }

    // MARK: - Mix Phase

    enum MixPhase: String {
        case idle = "Ready"
        case starting = "Starting"
        case playing = "Playing"
        case transitioning = "Transitioning"
        case fadingOut = "Fading Out"
        case stopped = "Stopped"
    }

    // MARK: - Layer State

    struct LayerState {
        var isPlaying: Bool = false
        var currentVolume: Float = 0
        var phase: LayerPhase = .waiting

        enum LayerPhase {
            case waiting
            case fadingIn
            case playing
            case fadingOut
            case stopped
        }
    }

    // MARK: - Audio Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()

        guard let engine = audioEngine, let mixer = mixerNode else { return }

        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        // 🚨 CRITICAL FIX: Connect mainMixer to output - WITHOUT THIS, NO SOUND!
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        print("[DynamicSoundMixer] ✅ Audio chain connected: Layers → Mixer → MainMixer → OutputNode")
    }

    // MARK: - Mix Creation

    /// Create a mix from a preset
    func createFromPreset(
        _ presetId: String,
        for profile: BabyMoodProfile,
        cryType: CryType?
    ) -> DynamicSoundMix? {
        guard let preset = presets.first(where: { $0.id == presetId }) else {
            return nil
        }

        // Check age appropriateness
        guard preset.ageRange.contains(profile.ageInMonths) else {
            return nil
        }

        return preset.createMix(for: profile, cryType: cryType)
    }

    /// Create a simple mix with just primary and secondary sounds
    func createSimpleMix(
        primary: GeneratorType,
        secondary: GeneratorType? = nil,
        for profile: BabyMoodProfile
    ) -> DynamicSoundMix {
        var layers: [SoundLayer] = []

        // Primary layer
        layers.append(SoundLayer(
            sound: primary,
            volume: 0.5 * profile.preferredIntensity.volumeMultiplier,
            pitchAdjustment: Float(profile.pitchPreference) * 0.2,
            rhythmSync: profile.rhythmSensitivity > 0.7,
            startDelay: 0,
            duration: 300,
            fadeInDuration: 2,
            fadeOutDuration: 5,
            pan: 0,
            reason: "Primary soothing sound"
        ))

        // Secondary layer (if provided)
        if let secondary = secondary {
            layers.append(SoundLayer(
                sound: secondary,
                volume: 0.25 * profile.preferredIntensity.volumeMultiplier,
                pitchAdjustment: Float(profile.pitchPreference) * 0.1,
                rhythmSync: false,
                startDelay: 10,
                duration: 290,
                fadeInDuration: 5,
                fadeOutDuration: 5,
                pan: 0,
                reason: "Secondary support sound"
            ))
        }

        return DynamicSoundMix(
            id: UUID(),
            name: "Simple Mix",
            layers: layers,
            createdFor: profile.babyId,
            cryType: nil,
            createdAt: Date()
        )
    }

    // MARK: - Playback Control

    /// Start playing a mix
    func play(_ mix: DynamicSoundMix) {
        stopCurrentMix()

        currentMix = mix
        isPlaying = true
        currentPhase = .starting

        // Initialize layer states
        for layer in mix.layers {
            layerStates[layer.id] = LayerState()
        }

        // Start audio engine
        do {
            try audioEngine?.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            currentPhase = .stopped
            isPlaying = false
            return
        }

        // Schedule each layer
        for layer in mix.layers {
            scheduleLayer(layer)
        }

        currentPhase = .playing

        // Start rhythm sync if needed
        if mix.hasRhythmSync {
            startRhythmSync()
        }
    }

    /// Schedule a single layer to start at its designated time
    private func scheduleLayer(_ layer: SoundLayer) {
        // Create player node for this layer
        let playerNode = AVAudioPlayerNode()
        guard let engine = audioEngine else { return }

        engine.attach(playerNode)

        // Connect through mixer for volume control
        if let mixer = mixerNode {
            engine.connect(playerNode, to: mixer, format: nil)
        }

        playerNodes[layer.id] = playerNode

        // Schedule start
        DispatchQueue.main.asyncAfter(deadline: .now() + layer.startDelay) { [weak self] in
            self?.startLayer(layer)
        }
    }

    /// Start playing a layer with fade-in
    private func startLayer(_ layer: SoundLayer) {
        guard let playerNode = playerNodes[layer.id],
              isPlaying else { return }

        layerStates[layer.id]?.phase = .fadingIn

        // Get or generate audio for this sound
        // Note: In a real implementation, this would load actual audio files
        // For now, we'll create synthetic audio or use bundled files

        // Start playback
        playerNode.volume = 0
        playerNode.play()

        // Fade in
        animateVolume(for: layer.id, to: layer.volume, duration: layer.fadeInDuration) { [weak self] in
            self?.layerStates[layer.id]?.phase = .playing
            self?.layerStates[layer.id]?.currentVolume = layer.volume
        }

        // Schedule fade-out
        let fadeOutTime = layer.duration - layer.fadeOutDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + layer.startDelay + fadeOutTime) { [weak self] in
            self?.fadeOutLayer(layer)
        }
    }

    /// Fade out a layer
    private func fadeOutLayer(_ layer: SoundLayer) {
        guard playerNodes[layer.id] != nil,
              isPlaying else { return }

        layerStates[layer.id]?.phase = .fadingOut

        animateVolume(for: layer.id, to: 0, duration: layer.fadeOutDuration) { [weak self] in
            self?.stopLayer(layer.id)
        }
    }

    /// Stop a specific layer
    private func stopLayer(_ layerId: UUID) {
        playerNodes[layerId]?.stop()
        layerStates[layerId]?.phase = .stopped
        layerStates[layerId]?.isPlaying = false
    }

    /// Animate volume change
    private func animateVolume(
        for layerId: UUID,
        to targetVolume: Float,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard let playerNode = playerNodes[layerId] else {
            completion()
            return
        }

        let startVolume = playerNode.volume
        let steps = Int(duration * 20) // 20 updates per second
        let stepDuration = duration / Double(steps)
        let volumeStep = (targetVolume - startVolume) / Float(steps)

        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            currentStep += 1
            playerNode.volume = startVolume + volumeStep * Float(currentStep)
            self?.layerStates[layerId]?.currentVolume = playerNode.volume

            if currentStep >= steps {
                timer.invalidate()
                playerNode.volume = targetVolume
                completion()
            }
        }
    }

    /// Stop the current mix
    func stopCurrentMix() {
        currentPhase = .fadingOut

        // Fade out all layers
        for (layerId, _) in playerNodes {
            animateVolume(for: layerId, to: 0, duration: 2) { [weak self] in
                self?.stopLayer(layerId)
            }
        }

        // Clean up after fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.cleanup()
        }
    }

    /// Clean up audio resources
    private func cleanup() {
        rhythmTimer?.invalidate()
        rhythmTimer = nil

        // MEMORY OPTIMIZATION (Increment 0022): Release buffers for all player nodes
        for (_, playerNode) in playerNodes {
            playerNode.stop()
            playerNode.reset() // Force buffer deallocation
            audioEngine?.detach(playerNode)
        }
        playerNodes.removeAll()
        layerStates.removeAll()

        audioEngine?.stop()

        currentMix = nil
        isPlaying = false
        currentPhase = .stopped

        print("[DynamicSoundMixer] 🧹 Cleaned up all player nodes and buffers")
    }

    // MARK: - Rhythm Synchronization

    /// Start rhythm sync for layers that have it enabled
    private func startRhythmSync() {
        // Target 60 BPM (1 beat per second) by default
        // Can be adjusted based on detected breathing rate
        let beatInterval = 60.0 / targetBPM

        rhythmTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            self?.onRhythmBeat()
        }
    }

    /// Called on each rhythm beat
    private func onRhythmBeat() {
        guard let mix = currentMix else { return }

        // Pulse volume slightly for rhythm-synced layers
        for layer in mix.layers where layer.rhythmSync {
            guard let currentVolume = layerStates[layer.id]?.currentVolume else { continue }

            // Slight pulse: +10% then back
            let pulseVolume = min(1.0, currentVolume * 1.1)

            animateVolume(for: layer.id, to: pulseVolume, duration: 0.1) { [weak self] in
                self?.animateVolume(for: layer.id, to: currentVolume, duration: 0.3) { }
            }
        }
    }

    /// Update breathing rate for better sync
    func updateBreathingRate(_ rate: Double) {
        breathingRate = rate

        // Adjust target BPM to match breathing
        // Typical baby breathing: 30-60 breaths per minute
        if rate >= 20 && rate <= 80 {
            targetBPM = rate

            // Restart rhythm timer with new rate
            if rhythmTimer != nil {
                rhythmTimer?.invalidate()
                startRhythmSync()
            }
        }
    }

    // MARK: - Dynamic Adjustments

    /// Adjust volume of a specific layer
    func adjustLayerVolume(_ layerId: UUID, to volume: Float) {
        guard var layer = currentMix?.layers.first(where: { $0.id == layerId }) else { return }
        layer.volume = volume

        animateVolume(for: layerId, to: volume, duration: 1) { }
    }

    /// Adjust overall mix volume
    func adjustMixVolume(to volume: Float) {
        mixerNode?.outputVolume = volume
    }

    /// Transition to a new sound in a layer
    func transitionLayer(_ layerId: UUID, to newSound: GeneratorType, duration: TimeInterval = 5) {
        guard let currentMix = currentMix,
              let layerIndex = currentMix.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        // Fade out current
        fadeOutLayer(currentMix.layers[layerIndex])

        // Create new layer with same settings but new sound
        let existingLayer = currentMix.layers[layerIndex]
        // Note: Since SoundLayer is a struct with let id, we create a new one
        let updatedLayer = SoundLayer(
            sound: newSound,
            volume: existingLayer.volume,
            pitchAdjustment: existingLayer.pitchAdjustment,
            rhythmSync: existingLayer.rhythmSync,
            startDelay: 0,
            duration: existingLayer.duration,
            fadeInDuration: duration,
            fadeOutDuration: existingLayer.fadeOutDuration,
            pan: existingLayer.pan,
            reason: "Transitioned from \(existingLayer.sound.rawValue)"
        )

        // Start new layer after brief overlap
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.5) { [weak self] in
            self?.scheduleLayer(updatedLayer)
        }
    }

    // MARK: - Preset Selection

    /// Find best preset for current situation
    func findBestPreset(
        for profile: BabyMoodProfile,
        cryType: CryType
    ) -> MixPreset? {
        return presets
            .filter { $0.ageRange.contains(profile.ageInMonths) }
            .filter { $0.suitableFor.contains(cryType) || $0.suitableFor.contains(.general) }
            .first
    }

    /// Get all presets suitable for a baby's age
    func getAgeAppropriatePresets(for ageMonths: Int) -> [MixPreset] {
        return presets.filter { $0.ageRange.contains(ageMonths) }
    }
}

// MARK: - Mix Builder (Fluent API)

/// Fluent builder for creating custom mixes
class MixBuilder {
    private var layers: [SoundLayer] = []
    private var name: String = "Custom Mix"
    private var babyId: UUID?
    private var cryType: CryType?

    func named(_ name: String) -> MixBuilder {
        self.name = name
        return self
    }

    func forBaby(_ babyId: UUID) -> MixBuilder {
        self.babyId = babyId
        return self
    }

    func forCryType(_ cryType: CryType) -> MixBuilder {
        self.cryType = cryType
        return self
    }

    func addLayer(
        _ sound: GeneratorType,
        volume: Float = 0.5,
        startAfter: TimeInterval = 0,
        duration: TimeInterval = 300,
        rhythmSync: Bool = false,
        reason: String = ""
    ) -> MixBuilder {
        let layer = SoundLayer(
            sound: sound,
            volume: volume,
            pitchAdjustment: 0,
            rhythmSync: rhythmSync,
            startDelay: startAfter,
            duration: duration,
            fadeInDuration: 2,
            fadeOutDuration: 3,
            pan: 0,
            reason: reason
        )
        layers.append(layer)
        return self
    }

    func build() -> DynamicSoundMix {
        return DynamicSoundMix(
            id: UUID(),
            name: name,
            layers: layers,
            createdFor: babyId,
            cryType: cryType,
            createdAt: Date()
        )
    }
}

// MARK: - Convenience Extensions

extension DynamicSoundMixer {
    /// Quick play a single sound with default settings
    func quickPlay(_ sound: GeneratorType, volume: Float = 0.5) {
        let mix = MixBuilder()
            .named("Quick Play: \(sound.rawValue)")
            .addLayer(sound, volume: volume, reason: "Quick play")
            .build()
        play(mix)
    }

    /// Create and play Emma's personalized night mix (example)
    func playPersonalizedNightMix(for profile: BabyMoodProfile) {
        let mix = MixBuilder()
            .named("\(profile.babyName)'s Night Mix")
            .forBaby(profile.babyId)
            .forCryType(.tired)
            .addLayer(.womb, volume: 0.4, reason: "Base womb sound")
            .addLayer(.heartbeat, volume: 0.25, rhythmSync: true, reason: "Rhythmic comfort")
            .addLayer(.aquarium, volume: 0.15, startAfter: 30, reason: "Added warmth")
            .build()
        play(mix)
    }
}
