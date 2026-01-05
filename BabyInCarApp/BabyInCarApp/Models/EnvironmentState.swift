//
//  EnvironmentState.swift
//  BabyInCarApp
//
//  Model representing the current car environment audio state.
//  Used for smart music adaptation based on environmental sounds.
//

import Foundation
import CoreMotion

// MARK: - Motion Type

enum MotionType: String, Codable, CaseIterable {
    case stopped = "Stopped"
    case city = "City Driving"          // Stop-and-go, variable
    case highway = "Highway Cruise"      // Steady, consistent
    case acceleration = "Accelerating"   // Engine revving up
    case deceleration = "Slowing Down"   // Braking
    case roughRoad = "Rough Road"        // Bumpy, variable motion
    case unknown = "Unknown"

    var soothingFactor: Double {
        switch self {
        case .stopped:
            return 0.1  // No motion soothing
        case .city:
            return 0.4  // Some soothing, but variable
        case .highway:
            return 0.9  // Ideal for baby sleep
        case .acceleration:
            return 0.3  // Variable, less soothing
        case .deceleration:
            return 0.3  // Variable, less soothing
        case .roughRoad:
            return 0.5  // Rhythmic but jarring
        case .unknown:
            return 0.2
        }
    }

    var description: String {
        switch self {
        case .stopped:
            return "Car is stationary"
        case .city:
            return "Stop-and-go city driving"
        case .highway:
            return "Smooth highway cruising"
        case .acceleration:
            return "Car is speeding up"
        case .deceleration:
            return "Car is slowing down"
        case .roughRoad:
            return "Driving on rough road"
        case .unknown:
            return "Motion unknown"
        }
    }
}

// MARK: - Engine Sound Level

enum EngineSoundLevel: String, Codable {
    case quiet = "Quiet"           // Electric vehicle or parked
    case low = "Low Hum"           // Idle or slow
    case moderate = "Moderate"     // Normal driving
    case loud = "Loud"             // High RPM
    case veryLoud = "Very Loud"    // Sports car / acceleration

    var soothingFactor: Double {
        switch self {
        case .quiet:
            return 0.1  // No engine soothing
        case .low:
            return 0.7  // Good low rumble
        case .moderate:
            return 0.8  // Ideal soothing
        case .loud:
            return 0.5  // A bit too intense
        case .veryLoud:
            return 0.2  // Too loud, potentially jarring
        }
    }

    static func fromDecibels(_ dB: Float) -> EngineSoundLevel {
        switch dB {
        case ..<30:
            return .quiet
        case 30..<50:
            return .low
        case 50..<65:
            return .moderate
        case 65..<80:
            return .loud
        default:
            return .veryLoud
        }
    }
}

// MARK: - Road Noise Type

enum RoadNoiseType: String, Codable {
    case silent = "Silent"          // Parked
    case smooth = "Smooth"          // Good highway
    case moderate = "Moderate"      // Normal roads
    case rough = "Rough"            // Bumpy road
    case variable = "Variable"      // Stop-start traffic

    var soothingFactor: Double {
        switch self {
        case .silent:
            return 0.1
        case .smooth:
            return 0.9  // Ideal white-noise-like
        case .moderate:
            return 0.6
        case .rough:
            return 0.3
        case .variable:
            return 0.4
        }
    }
}

// MARK: - Environment State

struct EnvironmentState: Codable {
    let id: UUID
    let timestamp: Date

    // Audio levels (0.0 - 1.0 normalized)
    let engineSoundLevel: Float
    let roadNoiseLevel: Float
    let cabinNoiseLevel: Float

    // Categorized assessments
    let engineCategory: EngineSoundLevel
    let roadNoiseCategory: RoadNoiseType
    let motionType: MotionType

    // Computed soothing score (0.0 - 1.0)
    // Higher = environment is already providing soothing sounds
    let soothingScore: Double

    // Detailed metrics for debugging/analytics
    let lowFrequencyPower: Float     // 20-200Hz (engine rumble)
    let midFrequencyPower: Float     // 200-1000Hz (road/tire noise)
    let highFrequencyPower: Float    // 1000-4000Hz (wind, rattles)
    let spectralConsistency: Float   // How consistent is the sound (0-1)

    // Motion data
    let speed: Double?               // If available from Core Location
    let acceleration: CMAcceleration?

    // Recommendation
    let recommendedMusicVolumeMultiplier: Float

    init(
        engineSoundLevel: Float,
        roadNoiseLevel: Float,
        cabinNoiseLevel: Float,
        engineCategory: EngineSoundLevel,
        roadNoiseCategory: RoadNoiseType,
        motionType: MotionType,
        lowFrequencyPower: Float,
        midFrequencyPower: Float,
        highFrequencyPower: Float,
        spectralConsistency: Float,
        speed: Double? = nil,
        acceleration: CMAcceleration? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.engineSoundLevel = engineSoundLevel
        self.roadNoiseLevel = roadNoiseLevel
        self.cabinNoiseLevel = cabinNoiseLevel
        self.engineCategory = engineCategory
        self.roadNoiseCategory = roadNoiseCategory
        self.motionType = motionType
        self.lowFrequencyPower = lowFrequencyPower
        self.midFrequencyPower = midFrequencyPower
        self.highFrequencyPower = highFrequencyPower
        self.spectralConsistency = spectralConsistency
        self.speed = speed
        self.acceleration = acceleration

        // Calculate soothing score
        let engineFactor = Double(engineSoundLevel) * engineCategory.soothingFactor
        let roadFactor = Double(roadNoiseLevel) * roadNoiseCategory.soothingFactor
        let motionFactor = motionType.soothingFactor
        let consistencyBonus = Double(spectralConsistency) * 0.2

        // Weighted combination
        self.soothingScore = min(1.0, (engineFactor * 0.35 + roadFactor * 0.25 + motionFactor * 0.3 + consistencyBonus) * 1.1)

        // Music volume recommendation
        // When environment is very soothing (0.8+), reduce music to 40%
        // When environment is not soothing (0.2-), keep music at 100%
        self.recommendedMusicVolumeMultiplier = Float(max(0.4, 1.0 - (soothingScore * 0.6)))
    }

    // MARK: - Convenience Methods

    /// Whether the environment is providing significant soothing
    var isNaturallySoothing: Bool {
        soothingScore > 0.6
    }

    /// Whether we should supplement with music
    var needsMusicSupplementation: Bool {
        soothingScore < 0.5
    }

    /// Human-readable summary
    var summary: String {
        switch soothingScore {
        case 0.8...1.0:
            return "Excellent soothing environment - car sounds are working great!"
        case 0.6..<0.8:
            return "Good environment - some supplemental sounds may help"
        case 0.4..<0.6:
            return "Moderate environment - recommended to add soothing sounds"
        case 0.2..<0.4:
            return "Limited natural soothing - playing calming sounds"
        default:
            return "Quiet environment - full soothing sounds recommended"
        }
    }

    /// Get explanation for parent
    var parentExplanation: String {
        ResearchKnowledgeBase.shared.getCarEnvironmentExplanation(soothingScore: soothingScore)
    }
}

// MARK: - CMAcceleration Codable Extension

extension CMAcceleration: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, z
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let z = try container.decode(Double.self, forKey: .z)
        self.init(x: x, y: y, z: z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
}

// MARK: - Environment History

class EnvironmentStateHistory: ObservableObject {
    static let shared = EnvironmentStateHistory()

    @Published var recentStates: [EnvironmentState] = []
    private let maxHistorySize = 60 // ~1 minute at 1Hz

    private init() {}

    func addState(_ state: EnvironmentState) {
        recentStates.append(state)
        if recentStates.count > maxHistorySize {
            recentStates.removeFirst()
        }
    }

    /// Average soothing score over recent history
    var averageSoothingScore: Double {
        guard !recentStates.isEmpty else { return 0 }
        return recentStates.reduce(0) { $0 + $1.soothingScore } / Double(recentStates.count)
    }

    /// Trend: is the soothing getting better or worse?
    var soothingTrend: Double {
        guard recentStates.count >= 10 else { return 0 }
        let recentHalf = recentStates.suffix(recentStates.count / 2)
        let olderHalf = recentStates.prefix(recentStates.count / 2)
        let recentAvg = recentHalf.reduce(0) { $0 + $1.soothingScore } / Double(recentHalf.count)
        let olderAvg = olderHalf.reduce(0) { $0 + $1.soothingScore } / Double(olderHalf.count)
        return recentAvg - olderAvg // Positive = getting better
    }

    /// Dominant motion type in recent history
    var dominantMotionType: MotionType {
        guard !recentStates.isEmpty else { return .unknown }
        var counts: [MotionType: Int] = [:]
        for state in recentStates {
            counts[state.motionType, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
}
