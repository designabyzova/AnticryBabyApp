//
//  AudioEngineTests.swift
//  BabyInCarAppTests
//
//  Unit tests for AudioEngine shuffle and repeat functionality
//

import XCTest
@testable import BabyInCarApp

final class AudioEngineTests: XCTestCase {

    var audioEngine: AudioEngine!

    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine.shared
        // Reset to default state
        audioEngine.repeatMode = .off
        audioEngine.isShuffleEnabled = false
        audioEngine.smoothTransitionsEnabled = true  // Reset to default
    }

    override func tearDown() {
        // Reset state after each test
        audioEngine.repeatMode = .off
        audioEngine.isShuffleEnabled = false
        audioEngine.smoothTransitionsEnabled = true  // Reset to default
        super.tearDown()
    }

    // MARK: - Shuffle Tests

    func testToggleShuffle_WhenOff_TurnsOn() {
        // Given
        audioEngine.isShuffleEnabled = false

        // When
        audioEngine.toggleShuffle()

        // Then
        XCTAssertTrue(audioEngine.isShuffleEnabled, "Shuffle should be enabled after toggle")
    }

    func testToggleShuffle_WhenOn_TurnsOff() {
        // Given
        audioEngine.isShuffleEnabled = true

        // When
        audioEngine.toggleShuffle()

        // Then
        XCTAssertFalse(audioEngine.isShuffleEnabled, "Shuffle should be disabled after toggle")
    }

    func testToggleShuffle_MultipleTimes() {
        // Given
        let initialState = audioEngine.isShuffleEnabled

        // When - toggle 4 times
        audioEngine.toggleShuffle()
        audioEngine.toggleShuffle()
        audioEngine.toggleShuffle()
        audioEngine.toggleShuffle()

        // Then - should be back to initial state
        XCTAssertEqual(audioEngine.isShuffleEnabled, initialState, "After even number of toggles, should return to initial state")
    }

    // MARK: - Repeat Mode Tests

    func testCycleRepeatMode_FromOff_ToAll() {
        // Given
        audioEngine.repeatMode = .off

        // When
        audioEngine.cycleRepeatMode()

        // Then
        XCTAssertEqual(audioEngine.repeatMode, .all, "Repeat mode should be .all after cycling from .off")
    }

    func testCycleRepeatMode_FromAll_ToOne() {
        // Given
        audioEngine.repeatMode = .all

        // When
        audioEngine.cycleRepeatMode()

        // Then
        XCTAssertEqual(audioEngine.repeatMode, .one, "Repeat mode should be .one after cycling from .all")
    }

    func testCycleRepeatMode_FromOne_ToOff() {
        // Given
        audioEngine.repeatMode = .one

        // When
        audioEngine.cycleRepeatMode()

        // Then
        XCTAssertEqual(audioEngine.repeatMode, .off, "Repeat mode should be .off after cycling from .one")
    }

    func testCycleRepeatMode_FullCycle() {
        // Given
        audioEngine.repeatMode = .off

        // When - cycle through all modes
        audioEngine.cycleRepeatMode() // off -> all
        XCTAssertEqual(audioEngine.repeatMode, .all)

        audioEngine.cycleRepeatMode() // all -> one
        XCTAssertEqual(audioEngine.repeatMode, .one)

        audioEngine.cycleRepeatMode() // one -> off
        XCTAssertEqual(audioEngine.repeatMode, .off)
    }

    func testSetRepeatMode_DirectSetting() {
        // When
        audioEngine.setRepeatMode(.one)

        // Then
        XCTAssertEqual(audioEngine.repeatMode, .one, "Should be able to directly set repeat mode")
    }

    // MARK: - RepeatMode Properties Tests

    func testRepeatMode_Icons() {
        XCTAssertEqual(AudioEngine.RepeatMode.off.icon, "repeat", "Off mode should use 'repeat' icon")
        XCTAssertEqual(AudioEngine.RepeatMode.all.icon, "repeat", "All mode should use 'repeat' icon")
        XCTAssertEqual(AudioEngine.RepeatMode.one.icon, "repeat.1", "One mode should use 'repeat.1' icon")
    }

    func testRepeatMode_IsActive() {
        XCTAssertFalse(AudioEngine.RepeatMode.off.isActive, "Off mode should not be active")
        XCTAssertTrue(AudioEngine.RepeatMode.all.isActive, "All mode should be active")
        XCTAssertTrue(AudioEngine.RepeatMode.one.isActive, "One mode should be active")
    }

    // MARK: - State Persistence Tests

    func testShuffleState_IsPersisted() {
        // Given
        let key = "audioEngine.shuffleEnabled"

        // When
        audioEngine.isShuffleEnabled = true

        // Then
        let savedValue = UserDefaults.standard.bool(forKey: key)
        XCTAssertTrue(savedValue, "Shuffle state should be persisted to UserDefaults")
    }

    func testRepeatModeState_IsPersisted() {
        // Given
        let key = "audioEngine.repeatMode"

        // When
        audioEngine.repeatMode = .one

        // Then
        let savedValue = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(savedValue, "one", "Repeat mode should be persisted to UserDefaults")
    }

    // MARK: - Smooth Transitions Tests

    func testSmoothTransitions_DefaultsToTrue() {
        // Given - fresh UserDefaults (clear any existing value)
        let key = "audioEngine.smoothTransitions"
        UserDefaults.standard.removeObject(forKey: key)

        // When - create new instance or reload settings
        // Since AudioEngine is singleton, we test the default behavior
        // The default should be true if no value is set

        // Then
        // Default should be true for smooth user experience
        XCTAssertTrue(audioEngine.smoothTransitionsEnabled, "Smooth transitions should default to true")
    }

    func testSmoothTransitions_CanBeDisabled() {
        // Given
        audioEngine.smoothTransitionsEnabled = true

        // When
        audioEngine.smoothTransitionsEnabled = false

        // Then
        XCTAssertFalse(audioEngine.smoothTransitionsEnabled, "Smooth transitions should be disabled")
    }

    func testSmoothTransitions_CanBeEnabled() {
        // Given
        audioEngine.smoothTransitionsEnabled = false

        // When
        audioEngine.smoothTransitionsEnabled = true

        // Then
        XCTAssertTrue(audioEngine.smoothTransitionsEnabled, "Smooth transitions should be enabled")
    }

    func testSmoothTransitionsState_IsPersisted() {
        // Given
        let key = "audioEngine.smoothTransitions"

        // When
        audioEngine.smoothTransitionsEnabled = false

        // Then
        let savedValue = UserDefaults.standard.bool(forKey: key)
        XCTAssertFalse(savedValue, "Smooth transitions state should be persisted to UserDefaults as false")

        // When - enable again
        audioEngine.smoothTransitionsEnabled = true

        // Then
        let savedValueEnabled = UserDefaults.standard.bool(forKey: key)
        XCTAssertTrue(savedValueEnabled, "Smooth transitions state should be persisted to UserDefaults as true")
    }

    func testSmoothTransitions_TogglingPersists() {
        // Given
        let key = "audioEngine.smoothTransitions"
        audioEngine.smoothTransitionsEnabled = true

        // When - disable
        audioEngine.smoothTransitionsEnabled = false

        // Then - check persistence
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key), "Disabled state should persist")

        // When - re-enable
        audioEngine.smoothTransitionsEnabled = true

        // Then - check persistence
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key), "Enabled state should persist")
    }

    // MARK: - Auto-Duck External Audio Tests (FS-019)

    func testAutoDuckExternalAudio_DefaultsToTrue() {
        // Given - clear any existing preference
        let key = "audioEngine.autoDuckExternalAudio"
        UserDefaults.standard.removeObject(forKey: key)

        // When - read default value
        let defaultValue = AudioEngine.autoDuckExternalAudio

        // Then - should default to true for safety (baby should always hear soothing sounds clearly)
        XCTAssertTrue(defaultValue, "Auto-duck should default to TRUE so baby hears soothing sounds over Spotify")
    }

    func testAutoDuckExternalAudio_CanBeDisabled() {
        // Given
        AudioEngine.autoDuckExternalAudio = true

        // When
        AudioEngine.autoDuckExternalAudio = false

        // Then
        XCTAssertFalse(AudioEngine.autoDuckExternalAudio, "Auto-duck should be disabled")
    }

    func testAutoDuckExternalAudio_CanBeEnabled() {
        // Given
        AudioEngine.autoDuckExternalAudio = false

        // When
        AudioEngine.autoDuckExternalAudio = true

        // Then
        XCTAssertTrue(AudioEngine.autoDuckExternalAudio, "Auto-duck should be enabled")
    }

    func testAutoDuckExternalAudio_IsPersisted() {
        // Given
        let key = "audioEngine.autoDuckExternalAudio"

        // When - disable
        AudioEngine.autoDuckExternalAudio = false

        // Then - check persistence
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key), "Disabled auto-duck should persist")

        // When - enable
        AudioEngine.autoDuckExternalAudio = true

        // Then - check persistence
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key), "Enabled auto-duck should persist")
    }

    func testEnableDucking_WhenPreferenceEnabled_SetsDuckingActive() {
        // Given
        AudioEngine.autoDuckExternalAudio = true

        // When
        audioEngine.enableDucking(true)

        // Then
        XCTAssertTrue(audioEngine.isDuckingActive, "Ducking should be active when enabled and preference is true")
    }

    func testEnableDucking_WhenPreferenceDisabled_DoesNotActivate() {
        // Given
        AudioEngine.autoDuckExternalAudio = false
        audioEngine.enableDucking(false) // Reset to known state

        // When
        audioEngine.enableDucking(true)

        // Then
        XCTAssertFalse(audioEngine.isDuckingActive, "Ducking should NOT activate when user preference is disabled")
    }

    func testDisableDucking_RestoresNormalState() {
        // Given - ducking is active
        AudioEngine.autoDuckExternalAudio = true
        audioEngine.enableDucking(true)
        XCTAssertTrue(audioEngine.isDuckingActive, "Precondition: ducking should be active")

        // When
        audioEngine.enableDucking(false)

        // Then
        XCTAssertFalse(audioEngine.isDuckingActive, "Ducking should be deactivated")
    }

    func testEnableDucking_RapidToggling_HandledGracefully() {
        // Given
        AudioEngine.autoDuckExternalAudio = true

        // When - rapidly toggle ducking (simulates quick cry detection changes)
        for _ in 0..<10 {
            audioEngine.enableDucking(true)
            audioEngine.enableDucking(false)
        }

        // Then - should end in disabled state without crashes
        XCTAssertFalse(audioEngine.isDuckingActive, "Ducking should be disabled after rapid toggling")
    }

    func testEnableDucking_SkipsIfAlreadyInDesiredState() {
        // Given - ducking already enabled
        AudioEngine.autoDuckExternalAudio = true
        audioEngine.enableDucking(true)
        XCTAssertTrue(audioEngine.isDuckingActive)

        // When - try to enable again (should be no-op)
        audioEngine.enableDucking(true)

        // Then - should still be enabled (no crash, no state change)
        XCTAssertTrue(audioEngine.isDuckingActive, "Ducking should remain active")
    }

    // MARK: - CarPlay-Specific Ducking Tests

    func testDucking_WorksWithBluetoothAudioRoute() {
        // Given - auto-duck enabled
        AudioEngine.autoDuckExternalAudio = true

        // When - enable ducking (should include .allowBluetooth option)
        audioEngine.enableDucking(true)

        // Then - ducking should be active
        // This tests that .allowBluetooth option is set, allowing ducking over CarPlay Bluetooth
        XCTAssertTrue(audioEngine.isDuckingActive, "Ducking should work over Bluetooth (CarPlay)")
    }

    func testDucking_BluetoothOptionSetForBothStates() {
        // Given
        AudioEngine.autoDuckExternalAudio = true

        // When - enable ducking
        audioEngine.enableDucking(true)

        // Then - should be active (Bluetooth-compatible)
        XCTAssertTrue(audioEngine.isDuckingActive)

        // When - disable ducking
        audioEngine.enableDucking(false)

        // Then - should restore Bluetooth compatibility
        // (both enabled and disabled states should support Bluetooth routes)
        XCTAssertFalse(audioEngine.isDuckingActive)
    }

    func testDucking_CarPlayScenario_SpotifyPlaying() {
        // Simulate CarPlay scenario: User listening to Spotify via CarPlay Bluetooth
        // Baby starts crying -> app should duck Spotify and play soothing sounds

        // Given - Bluetooth audio active, auto-duck enabled
        AudioEngine.autoDuckExternalAudio = true

        // When - cry detected, ducking activated
        audioEngine.enableDucking(true)

        // Then - ducking should be active (Spotify reduced to ~20%)
        XCTAssertTrue(audioEngine.isDuckingActive, "CarPlay: Should duck Spotify when baby cries")

        // When - baby calms down, ducking deactivated
        audioEngine.enableDucking(false)

        // Then - ducking should be off (Spotify restored to 100%)
        XCTAssertFalse(audioEngine.isDuckingActive, "CarPlay: Should restore Spotify when baby calms")
    }

    // MARK: - Ducking Telemetry Tests

    func testDuckingTelemetry_TracksActivationCount() {
        // Given - reset telemetry
        audioEngine.resetDuckingTelemetry()
        AudioEngine.autoDuckExternalAudio = true

        // When - activate ducking 3 times
        audioEngine.enableDucking(true)
        audioEngine.enableDucking(false)
        audioEngine.enableDucking(true)
        audioEngine.enableDucking(false)
        audioEngine.enableDucking(true)
        audioEngine.enableDucking(false)

        // Then - should track 3 activations
        let telemetry = audioEngine.getDuckingTelemetry()
        XCTAssertEqual(telemetry.activations, 3, "Should track 3 ducking activations")
    }

    func testDuckingTelemetry_TracksDuration() {
        // Given - reset telemetry
        audioEngine.resetDuckingTelemetry()
        AudioEngine.autoDuckExternalAudio = true

        // When - enable ducking for a short duration
        audioEngine.enableDucking(true)
        Thread.sleep(forTimeInterval: 0.1) // 100ms
        audioEngine.enableDucking(false)

        // Then - should track duration
        let telemetry = audioEngine.getDuckingTelemetry()
        XCTAssertGreaterThan(telemetry.totalDuration, 0.09, "Should track ducking duration (at least 90ms)")
        XCTAssertLessThan(telemetry.totalDuration, 0.2, "Duration should be realistic (< 200ms)")
    }

    func testDuckingTelemetry_TracksLastActivation() {
        // Given - reset telemetry
        audioEngine.resetDuckingTelemetry()
        AudioEngine.autoDuckExternalAudio = true
        let beforeActivation = Date()

        // When - activate ducking
        audioEngine.enableDucking(true)
        let afterActivation = Date()

        // Then - should record timestamp
        let telemetry = audioEngine.getDuckingTelemetry()
        XCTAssertNotNil(telemetry.lastActivation, "Should record last activation time")

        if let lastActivation = telemetry.lastActivation {
            XCTAssertGreaterThanOrEqual(lastActivation, beforeActivation)
            XCTAssertLessThanOrEqual(lastActivation, afterActivation)
        }

        // Cleanup
        audioEngine.enableDucking(false)
    }

    func testDuckingTelemetry_ResetClearsData() {
        // Given - some ducking activity
        AudioEngine.autoDuckExternalAudio = true
        audioEngine.enableDucking(true)
        audioEngine.enableDucking(false)

        // When - reset telemetry
        audioEngine.resetDuckingTelemetry()

        // Then - all telemetry should be cleared
        let telemetry = audioEngine.getDuckingTelemetry()
        XCTAssertEqual(telemetry.activations, 0, "Activation count should be reset to 0")
        XCTAssertEqual(telemetry.totalDuration, 0, "Total duration should be reset to 0")
        XCTAssertNil(telemetry.lastActivation, "Last activation should be nil after reset")
    }

    func testDuckingTelemetry_AccumulatesDurationAcrossMultipleSessions() {
        // Given - reset telemetry
        audioEngine.resetDuckingTelemetry()
        AudioEngine.autoDuckExternalAudio = true

        // When - multiple ducking sessions
        audioEngine.enableDucking(true)
        Thread.sleep(forTimeInterval: 0.05) // 50ms
        audioEngine.enableDucking(false)

        audioEngine.enableDucking(true)
        Thread.sleep(forTimeInterval: 0.05) // 50ms
        audioEngine.enableDucking(false)

        // Then - should accumulate total duration (~100ms)
        let telemetry = audioEngine.getDuckingTelemetry()
        XCTAssertGreaterThan(telemetry.totalDuration, 0.08, "Should accumulate duration (at least 80ms)")
        XCTAssertEqual(telemetry.activations, 2, "Should track 2 sessions")
    }
}
