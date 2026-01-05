//
//  EnvironmentSoundDetectorTests.swift
//  BabyInCarAppTests
//
//  Unit tests for EnvironmentSoundDetector
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Environment State Tests

@Suite("Environment State Model")
struct EnvironmentStateTests {

    @Test("Soothing score calculation is correct")
    func soothingScoreCalculation() {
        // High engine + low road noise + highway = high soothing
        let highSoothingState = EnvironmentState(
            engineSoundLevel: 0.7,
            roadNoiseLevel: 0.3,
            cabinNoiseLevel: 0.05,
            engineCategory: .moderate,
            roadNoiseCategory: .smooth,
            motionType: .highway,
            lowFrequencyPower: 0.1,
            midFrequencyPower: 0.05,
            highFrequencyPower: 0.02,
            spectralConsistency: 0.8,
            acceleration: nil
        )

        #expect(highSoothingState.soothingScore > 0.5, "Highway cruising should have high soothing score")
        #expect(highSoothingState.isNaturallySoothing, "Should be naturally soothing")
    }

    @Test("Low soothing score for stopped car")
    func lowSoothingScoreWhenStopped() {
        let stoppedState = EnvironmentState(
            engineSoundLevel: 0.1,
            roadNoiseLevel: 0.0,
            cabinNoiseLevel: 0.01,
            engineCategory: .quiet,
            roadNoiseCategory: .silent,
            motionType: .stopped,
            lowFrequencyPower: 0.01,
            midFrequencyPower: 0.01,
            highFrequencyPower: 0.01,
            spectralConsistency: 0.2,
            acceleration: nil
        )

        #expect(stoppedState.soothingScore < 0.4, "Stopped car should have lower soothing score")
        #expect(!stoppedState.isNaturallySoothing, "Stopped car is not naturally soothing")
    }

    @Test("Volume multiplier inversely proportional to soothing")
    func volumeMultiplierCalculation() {
        let highSoothing = EnvironmentState(
            engineSoundLevel: 0.8,
            roadNoiseLevel: 0.4,
            cabinNoiseLevel: 0.05,
            engineCategory: .loud,
            roadNoiseCategory: .smooth,
            motionType: .highway,
            lowFrequencyPower: 0.15,
            midFrequencyPower: 0.08,
            highFrequencyPower: 0.03,
            spectralConsistency: 0.85,
            acceleration: nil
        )

        let lowSoothing = EnvironmentState(
            engineSoundLevel: 0.1,
            roadNoiseLevel: 0.1,
            cabinNoiseLevel: 0.01,
            engineCategory: .quiet,
            roadNoiseCategory: .silent,
            motionType: .stopped,
            lowFrequencyPower: 0.01,
            midFrequencyPower: 0.01,
            highFrequencyPower: 0.01,
            spectralConsistency: 0.1,
            acceleration: nil
        )

        #expect(highSoothing.recommendedMusicVolumeMultiplier < lowSoothing.recommendedMusicVolumeMultiplier,
                "Higher soothing = lower music volume needed")
    }

    @Test("State summary is not empty")
    func stateSummaryGenerated() {
        let state = EnvironmentState(
            engineSoundLevel: 0.5,
            roadNoiseLevel: 0.3,
            cabinNoiseLevel: 0.03,
            engineCategory: .moderate,
            roadNoiseCategory: .smooth,
            motionType: .city,
            lowFrequencyPower: 0.08,
            midFrequencyPower: 0.05,
            highFrequencyPower: 0.02,
            spectralConsistency: 0.6,
            acceleration: nil
        )

        #expect(!state.summary.isEmpty, "Summary should not be empty")
    }
}

// MARK: - Motion Type Tests

@Suite("Motion Type Classification")
struct MotionTypeTests {

    @Test("Motion types have correct base soothing", arguments: [
        (MotionType.highway, true),      // Highway is soothing
        (MotionType.city, false),        // City is not very soothing
        (MotionType.stopped, false),     // Stopped is not soothing
        (MotionType.roughRoad, false)    // Rough road is not soothing
    ])
    func motionTypeSoothingLevels(input: (MotionType, Bool)) {
        let (motionType, shouldBeSoothing) = input
        let baseSoothing = motionType.baseSoothingContribution

        if shouldBeSoothing {
            #expect(baseSoothing > 0.3, "\(motionType) should have high base soothing")
        } else {
            #expect(baseSoothing <= 0.3, "\(motionType) should have low base soothing")
        }
    }
}

// MARK: - Engine Sound Level Tests

@Suite("Engine Sound Categories")
struct EngineSoundLevelTests {

    @Test("All engine levels are defined", arguments: EngineSoundLevel.allCases)
    func engineLevelsDefined(level: EngineSoundLevel) {
        #expect(!level.rawValue.isEmpty)
    }

    @Test("Moderate engine is most soothing")
    func moderateEngineMostSoothing() {
        let quiet = EngineSoundLevel.quiet.soothingFactor
        let moderate = EngineSoundLevel.moderate.soothingFactor
        let veryLoud = EngineSoundLevel.veryLoud.soothingFactor

        #expect(moderate > quiet, "Moderate should be more soothing than quiet")
        #expect(moderate > veryLoud, "Moderate should be more soothing than very loud")
    }
}

// MARK: - Road Noise Type Tests

@Suite("Road Noise Categories")
struct RoadNoiseTypeTests {

    @Test("Smooth road contributes to soothing")
    func smoothRoadSoothing() {
        let smooth = RoadNoiseType.smooth.soothingFactor
        let rough = RoadNoiseType.rough.soothingFactor

        #expect(smooth > rough, "Smooth road should be more soothing than rough")
    }
}

// MARK: - Environment State History Tests

@Suite("Environment State History")
struct EnvironmentStateHistoryTests {

    @Test("History singleton exists")
    func historyExists() {
        let history = EnvironmentStateHistory.shared
        #expect(history != nil)
    }

    @Test("Can add states to history")
    func addStatesToHistory() {
        let history = EnvironmentStateHistory.shared
        let initialCount = history.recentStates.count

        let testState = EnvironmentState(
            engineSoundLevel: 0.5,
            roadNoiseLevel: 0.3,
            cabinNoiseLevel: 0.03,
            engineCategory: .moderate,
            roadNoiseCategory: .smooth,
            motionType: .highway,
            lowFrequencyPower: 0.08,
            midFrequencyPower: 0.05,
            highFrequencyPower: 0.02,
            spectralConsistency: 0.6,
            acceleration: nil
        )

        history.addState(testState)

        #expect(history.recentStates.count >= initialCount)
    }

    @Test("Average soothing score is calculated")
    func averageSoothingScore() {
        let history = EnvironmentStateHistory.shared

        // Add a few test states
        for _ in 0..<3 {
            let state = EnvironmentState(
                engineSoundLevel: 0.6,
                roadNoiseLevel: 0.3,
                cabinNoiseLevel: 0.04,
                engineCategory: .moderate,
                roadNoiseCategory: .smooth,
                motionType: .highway,
                lowFrequencyPower: 0.1,
                midFrequencyPower: 0.06,
                highFrequencyPower: 0.02,
                spectralConsistency: 0.7,
                acceleration: nil
            )
            history.addState(state)
        }

        let avgScore = history.getAverageSoothingScore(duration: 60)
        #expect(avgScore >= 0 && avgScore <= 1, "Average score should be between 0 and 1")
    }
}
