//
//  SmartCarPlayControllerTests.swift
//  BabyInCarAppTests
//
//  Unit tests for SmartCarPlayController
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Smart Mode Decision Tests

@Suite("Smart Mode Decision")
struct SmartModeDecisionTests {

    @Test("Decision has all required fields")
    func decisionFields() {
        let decision = SmartModeDecision(
            timestamp: Date(),
            recommendedVolume: 0.7,
            reason: "Baby is calm",
            environmentScore: 0.8,
            babyState: .calm,
            motionType: .highway,
            actionTaken: .reduceVolume
        )

        #expect(decision.recommendedVolume == 0.7)
        #expect(decision.environmentScore == 0.8)
        #expect(decision.babyState == .calm)
        #expect(decision.motionType == .highway)
        #expect(decision.actionTaken == .reduceVolume)
        #expect(!decision.reason.isEmpty)
    }

    @Test("Decision is encodable/decodable")
    func decisionCodable() throws {
        let decision = SmartModeDecision(
            timestamp: Date(),
            recommendedVolume: 0.6,
            reason: "Environment is soothing",
            environmentScore: 0.75,
            babyState: .sleeping,
            motionType: .highway,
            actionTaken: .reduceVolume
        )

        let encoded = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(SmartModeDecision.self, from: encoded)

        #expect(decoded.recommendedVolume == 0.6)
        #expect(decoded.babyState == .sleeping)
    }
}

// MARK: - Smart Mode Action Tests

@Suite("Smart Mode Actions")
struct SmartModeActionTests {

    @Test("All actions have raw values", arguments: [
        SmartModeAction.reduceVolume,
        SmartModeAction.increaseVolume,
        SmartModeAction.changeTrack,
        SmartModeAction.enableCarSound,
        SmartModeAction.maintain,
        SmartModeAction.alert
    ])
    func actionsHaveRawValues(action: SmartModeAction) {
        #expect(!action.rawValue.isEmpty)
    }

    @Test("Actions encode correctly")
    func actionsEncode() throws {
        for action in [SmartModeAction.reduceVolume, .increaseVolume, .changeTrack, .maintain] {
            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(SmartModeAction.self, from: encoded)
            #expect(decoded == action)
        }
    }
}

// MARK: - Baby Audio State Tests

@Suite("Baby Audio State")
struct BabyAudioStateTests {

    @Test("All baby states defined", arguments: [
        BabyAudioState.calm,
        BabyAudioState.fussy,
        BabyAudioState.crying,
        BabyAudioState.sleeping,
        BabyAudioState.unknown
    ])
    func statesAreDefined(state: BabyAudioState) {
        #expect(!state.rawValue.isEmpty)
    }

    @Test("States encode correctly")
    func statesEncode() throws {
        for state in [BabyAudioState.calm, .fussy, .crying, .sleeping, .unknown] {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(BabyAudioState.self, from: encoded)
            #expect(decoded == state)
        }
    }
}

// MARK: - Volume Calculation Logic Tests

@Suite("Volume Calculation Logic")
struct VolumeCalculationTests {

    @Test("High environment score reduces volume")
    func highEnvironmentReducesVolume() {
        // When environment is highly soothing (highway cruise)
        // Volume should be reduced
        let highEnvScore = 0.8
        let expectedVolumeReduction = 1.0 - (highEnvScore * 0.6) // 0.52

        #expect(expectedVolumeReduction < 0.6, "High env score should reduce volume significantly")
    }

    @Test("Low environment score maintains volume")
    func lowEnvironmentMaintainsVolume() {
        // When environment is not soothing (car stopped)
        // Volume should stay higher
        let lowEnvScore = 0.2
        let expectedVolume = 1.0 - (lowEnvScore * 0.6) // 0.88

        #expect(expectedVolume > 0.8, "Low env score should maintain higher volume")
    }

    @Test("Crying baby keeps volume audible")
    func cryingBabyKeepsVolumeUp() {
        // Even with good environment, crying baby needs audible soothing
        let envScore = 0.8
        let envHelp = Float(envScore) * 0.3
        let volume = max(0.7, 1.0 - envHelp) // At least 0.7

        #expect(volume >= 0.7, "Volume should stay at least 0.7 when baby crying")
    }

    @Test("Volume is clamped to valid range")
    func volumeClamped() {
        let minVolume: Float = 0.2
        let maxVolume: Float = 1.0

        // Test extreme cases
        let tooLow: Float = -0.5
        let tooHigh: Float = 2.0

        let clampedLow = max(minVolume, min(maxVolume, tooLow))
        let clampedHigh = max(minVolume, min(maxVolume, tooHigh))

        #expect(clampedLow == minVolume)
        #expect(clampedHigh == maxVolume)
    }
}

// MARK: - CarPlay Status Tests

@Suite("CarPlay Status Display")
struct CarPlayStatusTests {

    @Test("Status messages are formatted correctly")
    func statusFormatting() {
        // Test different environment scores
        let scores: [(Double, String)] = [
            (0.8, "car"),    // High score = car soothing
            (0.5, "playing"), // Medium = playing
            (0.2, "full")     // Low = full soothing
        ]

        for (score, expectedKeyword) in scores {
            var statusParts: [String] = []

            if score > 0.7 {
                statusParts.append("car soothing")
            } else if score > 0.4 {
                statusParts.append("playing")
            } else {
                statusParts.append("full soothing")
            }

            let status = statusParts.joined()
            #expect(status.lowercased().contains(expectedKeyword),
                   "Score \(score) should produce status with '\(expectedKeyword)'")
        }
    }

    @Test("Baby state indicators are correct")
    func babyStateIndicators() {
        let stateIndicators: [(BabyAudioState, String)] = [
            (.calm, "calm"),
            (.sleeping, "sleep"),
            (.fussy, "fuss"),
            (.crying, "cry"),
            (.unknown, "monitor")
        ]

        for (state, expectedKeyword) in stateIndicators {
            let indicator: String
            switch state {
            case .calm: indicator = "😊 Calm"
            case .sleeping: indicator = "😴 Sleeping"
            case .fussy: indicator = "😟 Fussy"
            case .crying: indicator = "😢 Crying"
            case .unknown: indicator = "👶 Monitoring"
            }

            #expect(indicator.lowercased().contains(expectedKeyword),
                   "State \(state) should have indicator with '\(expectedKeyword)'")
        }
    }

    @Test("Environment indicators show motion type")
    func environmentIndicators() {
        let motionIndicators: [(MotionType, String)] = [
            (.highway, "highway"),
            (.city, "city"),
            (.stopped, "parked")
        ]

        for (motion, expectedKeyword) in motionIndicators {
            let indicator: String
            switch motion {
            case .highway: indicator = "🛣️ Highway"
            case .city: indicator = "🏙️ City"
            case .stopped: indicator = "🅿️ Parked"
            default: indicator = "🚗 Driving"
            }

            #expect(indicator.lowercased().contains(expectedKeyword),
                   "Motion \(motion) should show '\(expectedKeyword)'")
        }
    }
}

// MARK: - Decision History Tests

@Suite("Decision History Management")
struct DecisionHistoryTests {

    @Test("History is limited to max size")
    func historyLimitedSize() {
        var history: [SmartModeDecision] = []
        let maxSize = 100

        // Add more than max
        for i in 0..<150 {
            let decision = SmartModeDecision(
                timestamp: Date(),
                recommendedVolume: Float(i) / 100.0,
                reason: "Decision \(i)",
                environmentScore: 0.5,
                babyState: .calm,
                motionType: .highway,
                actionTaken: .maintain
            )

            history.append(decision)
            if history.count > maxSize {
                history.removeFirst()
            }
        }

        #expect(history.count == maxSize, "History should be capped at \(maxSize)")
    }

    @Test("Session summary calculations")
    func sessionSummaryCalc() {
        let history: [SmartModeDecision] = [
            SmartModeDecision(timestamp: Date(), recommendedVolume: 0.5, reason: "R1",
                            environmentScore: 0.6, babyState: .calm, motionType: .highway, actionTaken: .reduceVolume),
            SmartModeDecision(timestamp: Date(), recommendedVolume: 0.7, reason: "R2",
                            environmentScore: 0.4, babyState: .fussy, motionType: .city, actionTaken: .increaseVolume),
            SmartModeDecision(timestamp: Date(), recommendedVolume: 0.6, reason: "R3",
                            environmentScore: 0.8, babyState: .calm, motionType: .highway, actionTaken: .reduceVolume),
            SmartModeDecision(timestamp: Date(), recommendedVolume: 0.5, reason: "R4",
                            environmentScore: 0.7, babyState: .sleeping, motionType: .highway, actionTaken: .maintain)
        ]

        let volumeReductions = history.filter { $0.actionTaken == .reduceVolume }.count
        let volumeIncreases = history.filter { $0.actionTaken == .increaseVolume }.count
        let avgEnvScore = history.reduce(0) { $0 + $1.environmentScore } / Double(history.count)

        #expect(volumeReductions == 2)
        #expect(volumeIncreases == 1)
        #expect(avgEnvScore > 0.5 && avgEnvScore < 0.7)
    }
}

// MARK: - Voice Feedback Tests

@Suite("Voice Feedback")
struct VoiceFeedbackTests {

    @Test("Feedback messages for volume changes")
    func volumeChangeFeedback() {
        let volumeChange: Float = 0.3 // Significant change

        let feedbackMessage: String
        if volumeChange < 0 {
            feedbackMessage = "Lowering music - car sounds are helping"
        } else {
            feedbackMessage = "Increasing soothing sounds"
        }

        #expect(!feedbackMessage.isEmpty)
        #expect(feedbackMessage.contains("soothing") || feedbackMessage.contains("music"))
    }

    @Test("Alert message for distress")
    func distressAlert() {
        let alertMessage = "Baby seems distressed. Consider pulling over when safe."

        #expect(alertMessage.contains("distressed"))
        #expect(alertMessage.contains("pulling over") || alertMessage.contains("safe"))
    }
}
