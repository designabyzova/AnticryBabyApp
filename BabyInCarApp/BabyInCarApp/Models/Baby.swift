//
//  Baby.swift
//  BabyInCarApp
//
//  Data model for baby profile
//

import Foundation

struct Baby: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var birthDate: Date
    var photoData: Data?

    init(id: UUID = UUID(), name: String, birthDate: Date, photoData: Data? = nil) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.photoData = photoData
    }

    // MARK: - Age Calculations

    var ageInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return max(0, min(36, components.month ?? 0))
    }

    var ageInWeeks: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: birthDate, to: Date())
        return max(0, components.weekOfYear ?? 0)
    }

    var ageInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: birthDate, to: Date())
        return max(0, components.day ?? 0)
    }

    var formattedAge: String {
        let months = ageInMonths
        let weeks = ageInWeeks

        if months == 0 {
            if weeks == 0 {
                return "\(ageInDays) days old"
            }
            return "\(weeks) weeks old"
        } else if months == 1 {
            return "1 month old"
        } else {
            return "\(months) months old"
        }
    }

    var developmentalStage: DevelopmentalStage {
        DevelopmentalStage.forAge(months: ageInMonths)
    }

    // MARK: - Display Name

    var displayName: String {
        name.isEmpty ? "Baby" : name
    }
}

// MARK: - Developmental Stage
enum DevelopmentalStage: String, Codable, CaseIterable {
    case fourthTrimester = "Fourth Trimester"       // 0-3 months
    case earlyRegulation = "Early Regulation"       // 3-6 months
    case sensoryExploration = "Sensory Exploration" // 6-9 months
    case motorDevelopment = "Motor Development"     // 9-12 months
    case vocabularyBurst = "Vocabulary Burst"       // 12-18 months
    case sentenceBuilding = "Sentence Building"     // 18-24 months
    case imaginationGrowth = "Imagination Growth"   // 24-36 months

    static func forAge(months: Int) -> DevelopmentalStage {
        switch months {
        case 0..<3:
            return .fourthTrimester
        case 3..<6:
            return .earlyRegulation
        case 6..<9:
            return .sensoryExploration
        case 9..<12:
            return .motorDevelopment
        case 12..<18:
            return .vocabularyBurst
        case 18..<24:
            return .sentenceBuilding
        default:
            return .imaginationGrowth
        }
    }

    var ageRange: ClosedRange<Int> {
        switch self {
        case .fourthTrimester: return 0...2
        case .earlyRegulation: return 3...5
        case .sensoryExploration: return 6...8
        case .motorDevelopment: return 9...11
        case .vocabularyBurst: return 12...17
        case .sentenceBuilding: return 18...23
        case .imaginationGrowth: return 24...36
        }
    }

    var description: String {
        switch self {
        case .fourthTrimester:
            return "Mimics intrauterine environment with womb sounds, heartbeat, and shushing"
        case .earlyRegulation:
            return "Sleep cycle development with gentle lullabies and soothing sounds"
        case .sensoryExploration:
            return "Language acquisition window with simple melodies and vowel-rich stories"
        case .motorDevelopment:
            return "Motor and cognitive development with rhythmic music and interactive sounds"
        case .vocabularyBurst:
            return "Vocabulary explosion period with simple stories and animal sounds"
        case .sentenceBuilding:
            return "Attention span development with narrative stories and classical variations"
        case .imaginationGrowth:
            return "Cognitive complexity readiness with complex stories and multilingual content"
        }
    }

    var recommendedCategories: [AudioCategory] {
        switch self {
        case .fourthTrimester:
            return [.ambient, .natureSounds, .lullabies]
        case .earlyRegulation:
            return [.ambient, .lullabies, .classicalMusic, .instrumental]
        case .sensoryExploration:
            return [.natureSounds, .classicalMusic, .fairyTales, .childrenSongs]
        case .motorDevelopment:
            return [.childrenSongs, .classicalMusic, .fairyTales, .instrumental]
        case .vocabularyBurst:
            return [.fairyTales, .childrenSongs, .classicalMusic, .podcasts]
        case .sentenceBuilding:
            return [.fairyTales, .podcasts, .classicalMusic, .natureSounds]
        case .imaginationGrowth:
            return [.fairyTales, .podcasts, .classicalMusic, .childrenSongs]
        }
    }

    var audioCharacteristics: AudioCharacteristics {
        switch self {
        case .fourthTrimester:
            return AudioCharacteristics(
                tempoBPM: 60...80,
                frequencyRange: .lowMid,
                dynamicRange: .narrow,
                preferredDuration: 180...600
            )
        case .earlyRegulation:
            return AudioCharacteristics(
                tempoBPM: 60...90,
                frequencyRange: .lowMid,
                dynamicRange: .narrow,
                preferredDuration: 180...480
            )
        case .sensoryExploration:
            return AudioCharacteristics(
                tempoBPM: 70...100,
                frequencyRange: .midRange,
                dynamicRange: .moderate,
                preferredDuration: 120...360
            )
        case .motorDevelopment:
            return AudioCharacteristics(
                tempoBPM: 80...110,
                frequencyRange: .midRange,
                dynamicRange: .moderate,
                preferredDuration: 120...300
            )
        case .vocabularyBurst:
            return AudioCharacteristics(
                tempoBPM: 70...100,
                frequencyRange: .full,
                dynamicRange: .moderate,
                preferredDuration: 180...600
            )
        case .sentenceBuilding:
            return AudioCharacteristics(
                tempoBPM: 60...100,
                frequencyRange: .full,
                dynamicRange: .wide,
                preferredDuration: 300...900
            )
        case .imaginationGrowth:
            return AudioCharacteristics(
                tempoBPM: 60...120,
                frequencyRange: .full,
                dynamicRange: .wide,
                preferredDuration: 300...1200
            )
        }
    }
}

// MARK: - Audio Characteristics
struct AudioCharacteristics {
    let tempoBPM: ClosedRange<Int>
    let frequencyRange: FrequencyRange
    let dynamicRange: DynamicRange
    let preferredDuration: ClosedRange<Int> // seconds

    enum FrequencyRange {
        case lowMid      // Focused on lower frequencies
        case midRange    // Balanced mid frequencies
        case full        // Full frequency spectrum
    }

    enum DynamicRange {
        case narrow      // Minimal volume variation
        case moderate    // Some volume variation
        case wide        // Full dynamic expression
    }
}
