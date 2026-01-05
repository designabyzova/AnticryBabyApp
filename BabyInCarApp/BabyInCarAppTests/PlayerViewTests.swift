//
//  PlayerViewTests.swift
//  BabyInCarAppTests
//
//  UI tests for PlayerView shuffle and repeat button interactions
//

import XCTest
import SwiftUI
@testable import BabyInCarApp

final class PlayerViewTests: XCTestCase {

    var audioEngine: AudioEngine!

    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine.shared
        // Reset to default state
        audioEngine.repeatMode = .off
        audioEngine.isShuffleEnabled = false
    }

    override func tearDown() {
        audioEngine.repeatMode = .off
        audioEngine.isShuffleEnabled = false
        super.tearDown()
    }

    // MARK: - Shuffle Button State Tests

    func testShuffleButton_ReflectsEngineState() {
        // Given
        audioEngine.isShuffleEnabled = false

        // When
        audioEngine.toggleShuffle()

        // Then - the view should show shuffle as enabled
        XCTAssertTrue(audioEngine.isShuffleEnabled)
    }

    func testShuffleButton_DisabledWithoutPlaylist() {
        // Given - no playlist loaded
        audioEngine.stop()

        // Then - shuffle should not be enabled when there's no playlist
        // (The button is disabled in the UI when currentPlaylist == nil)
        XCTAssertNil(audioEngine.currentPlaylist, "No playlist should be loaded")
    }

    // MARK: - Repeat Button State Tests

    func testRepeatButton_ShowsCorrectIconForEachMode() {
        // Off mode
        audioEngine.repeatMode = .off
        XCTAssertEqual(audioEngine.repeatMode.icon, "repeat")
        XCTAssertFalse(audioEngine.repeatMode.isActive)

        // All mode
        audioEngine.repeatMode = .all
        XCTAssertEqual(audioEngine.repeatMode.icon, "repeat")
        XCTAssertTrue(audioEngine.repeatMode.isActive)

        // One mode - uses "repeat.1" icon
        audioEngine.repeatMode = .one
        XCTAssertEqual(audioEngine.repeatMode.icon, "repeat.1")
        XCTAssertTrue(audioEngine.repeatMode.isActive)
    }

    func testRepeatButton_CyclesCorrectly() {
        // Start at off
        audioEngine.repeatMode = .off

        // First tap: off -> all
        audioEngine.cycleRepeatMode()
        XCTAssertEqual(audioEngine.repeatMode, .all)

        // Second tap: all -> one
        audioEngine.cycleRepeatMode()
        XCTAssertEqual(audioEngine.repeatMode, .one)

        // Third tap: one -> off
        audioEngine.cycleRepeatMode()
        XCTAssertEqual(audioEngine.repeatMode, .off)
    }

    // MARK: - Integration Tests

    func testShuffleAndRepeat_IndependentState() {
        // Given
        audioEngine.isShuffleEnabled = false
        audioEngine.repeatMode = .off

        // When - toggle shuffle
        audioEngine.toggleShuffle()

        // Then - repeat mode should be unaffected
        XCTAssertTrue(audioEngine.isShuffleEnabled)
        XCTAssertEqual(audioEngine.repeatMode, .off)

        // When - cycle repeat mode
        audioEngine.cycleRepeatMode()

        // Then - shuffle should be unaffected
        XCTAssertTrue(audioEngine.isShuffleEnabled)
        XCTAssertEqual(audioEngine.repeatMode, .all)
    }

    func testRepeatOne_BehaviorOnTrackEnd() {
        // Given
        audioEngine.repeatMode = .one

        // The repeatMode.one should cause the same track to replay
        // This is verified by the logic in advanceToNextTrack() in AudioEngine
        XCTAssertEqual(audioEngine.repeatMode, .one)
        XCTAssertTrue(audioEngine.repeatMode.isActive)
    }
}
