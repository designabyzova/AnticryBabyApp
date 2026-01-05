//
//  CryPredictionAccuracyTracker.swift
//  BabyInCarApp
//
//  Tracks AI cry classification accuracy over time
//  Learns which cry types are correctly identified for this baby
//

import Foundation
import Combine

/// Tracks accuracy of cry predictions for continuous learning
@MainActor
class CryPredictionAccuracyTracker: ObservableObject {
    static let shared = CryPredictionAccuracyTracker()

    // MARK: - Published State

    /// Overall accuracy percentage (0-100)
    @Published var overallAccuracy: Double = 0

    /// Accuracy per cry type
    @Published var accuracyByType: [CryType: Double] = [:]

    /// Total predictions made
    @Published var totalPredictions: Int = 0

    /// Correct predictions
    @Published var correctPredictions: Int = 0

    /// Recent accuracy trend (last 20 predictions)
    @Published var recentAccuracy: Double = 0

    // MARK: - Prediction History

    private struct PredictionRecord: Codable {
        let id: UUID
        let timestamp: Date
        let predicted: CryType
        let confidence: Double
        let actual: CryType?  // nil if not yet validated
        let wasCorrect: Bool?
        let validatedAt: Date?
        let sessionId: String?
    }

    private var predictions: [PredictionRecord] = []
    private let maxHistorySize = 1000  // Keep last 1000 predictions
    private let userDefaultsKey = "cry_prediction_history"

    // MARK: - Initialization

    private init() {
        loadHistory()
        calculateAccuracy()
    }

    // MARK: - Tracking

    /// Record a new cry prediction
    func recordPrediction(
        predicted: CryType,
        confidence: Double,
        sessionId: String? = nil
    ) -> UUID {
        let id = UUID()
        let record = PredictionRecord(
            id: id,
            timestamp: Date(),
            predicted: predicted,
            confidence: confidence,
            actual: nil,
            wasCorrect: nil,
            validatedAt: nil,
            sessionId: sessionId
        )

        predictions.append(record)
        totalPredictions += 1

        // Trim history if needed
        if predictions.count > maxHistorySize {
            predictions.removeFirst(predictions.count - maxHistorySize)
        }

        saveHistory()
        return id
    }

    /// Validate a prediction with actual outcome
    /// Call this when user provides feedback or when effectiveness data confirms the type
    func validatePrediction(
        id: UUID,
        actual: CryType,
        wasEffective: Bool? = nil
    ) {
        guard let index = predictions.firstIndex(where: { $0.id == id }) else {
            return
        }

        let predicted = predictions[index].predicted
        let wasCorrect = (predicted == actual) || (wasEffective == true)

        let updated = PredictionRecord(
            id: predictions[index].id,
            timestamp: predictions[index].timestamp,
            predicted: predicted,
            confidence: predictions[index].confidence,
            actual: actual,
            wasCorrect: wasCorrect,
            validatedAt: Date(),
            sessionId: predictions[index].sessionId
        )

        predictions[index] = updated

        if wasCorrect {
            correctPredictions += 1
        }

        saveHistory()
        calculateAccuracy()
    }

    /// Automatically validate using session effectiveness data
    func validateFromSession(
        sessionId: String,
        actualType: CryType,
        wasEffective: Bool
    ) {
        let sessionPredictions = predictions.filter { $0.sessionId == sessionId && $0.actual == nil }

        for record in sessionPredictions {
            validatePrediction(id: record.id, actual: actualType, wasEffective: wasEffective)
        }
    }

    // MARK: - Accuracy Calculation

    private func calculateAccuracy() {
        let validated = predictions.filter { $0.actual != nil }

        guard !validated.isEmpty else {
            overallAccuracy = 0
            recentAccuracy = 0
            accuracyByType = [:]
            return
        }

        // Overall accuracy
        let correct = validated.filter { $0.wasCorrect == true }.count
        overallAccuracy = Double(correct) / Double(validated.count) * 100

        // Recent accuracy (last 20)
        let recentValidated = Array(validated.suffix(20))
        if !recentValidated.isEmpty {
            let recentCorrect = recentValidated.filter { $0.wasCorrect == true }.count
            recentAccuracy = Double(recentCorrect) / Double(recentValidated.count) * 100
        }

        // Accuracy by type
        var accuracyMap: [CryType: Double] = [:]
        for type in CryType.allCases where type != .unknown {
            let typePredictions = validated.filter { $0.predicted == type }
            if !typePredictions.isEmpty {
                let typeCorrect = typePredictions.filter { $0.wasCorrect == true }.count
                accuracyMap[type] = Double(typeCorrect) / Double(typePredictions.count) * 100
            }
        }
        accuracyByType = accuracyMap

        // Update correct predictions count
        correctPredictions = correct
    }

    // MARK: - Insights

    /// Get the best-performing cry type (highest accuracy)
    var bestPerformingType: (type: CryType, accuracy: Double)? {
        accuracyByType.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    /// Get the worst-performing cry type (needs improvement)
    var worstPerformingType: (type: CryType, accuracy: Double)? {
        accuracyByType.min(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    /// Is accuracy improving over time?
    var isImproving: Bool {
        recentAccuracy > overallAccuracy
    }

    /// Get accuracy trend description
    var trendDescription: String {
        if recentAccuracy > overallAccuracy + 5 {
            return "Improving"
        } else if recentAccuracy < overallAccuracy - 5 {
            return "Declining"
        } else {
            return "Stable"
        }
    }

    /// Get confidence level for a specific cry type
    func getConfidenceLevel(for type: CryType) -> String {
        guard let accuracy = accuracyByType[type] else {
            return "Learning"
        }

        switch accuracy {
        case 90...:
            return "Very High"
        case 75..<90:
            return "High"
        case 60..<75:
            return "Moderate"
        case 40..<60:
            return "Low"
        default:
            return "Very Low"
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(predictions) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([PredictionRecord].self, from: data) {
            predictions = decoded
            totalPredictions = predictions.count
        }
    }

    /// Clear all history (useful for testing or reset)
    func clearHistory() {
        predictions = []
        totalPredictions = 0
        correctPredictions = 0
        overallAccuracy = 0
        recentAccuracy = 0
        accuracyByType = [:]
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
