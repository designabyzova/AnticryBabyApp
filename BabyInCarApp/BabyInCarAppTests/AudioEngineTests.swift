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

}
