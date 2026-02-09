//
//  CryPredictionAccuracyTracker.swift
//  BabyInCarApp
//
//  Tracks cry prediction accuracy over time for personalization.
//

import Foundation
import Combine

final class CryPredictionAccuracyTracker: ObservableObject {
    static let shared = CryPredictionAccuracyTracker()

    @Published private(set) var overallAccuracy: Double = 0
    @Published private(set) var recentAccuracy: Double = 0
    @Published private(set) var totalPredictions: Int = 0
    @Published private(set) var correctPredictions: Int = 0
    @Published private(set) var isImproving: Bool = false
    @Published private(set) var accuracyByType: [CryType: Double] = [:]

    var trendDescription: String {
        if totalPredictions < 5 { return "Learning..." }
        if isImproving { return "Improving" }
        return "Stable"
    }

    var bestPerformingType: (type: CryType, accuracy: Double)? {
        accuracyByType.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    var worstPerformingType: (type: CryType, accuracy: Double)? {
        accuracyByType.min(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    private init() {}

    func recordPrediction(predicted: CryType, actual: CryType) {
        totalPredictions += 1
        if predicted == actual {
            correctPredictions += 1
        }
        overallAccuracy = totalPredictions > 0
            ? Double(correctPredictions) / Double(totalPredictions) * 100
            : 0
    }
}
