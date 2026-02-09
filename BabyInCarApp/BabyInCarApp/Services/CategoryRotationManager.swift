//
//  CategoryRotationManager.swift
//  BabyInCarApp
//
//  Manages category rotation to ensure playlist diversity (FS-029)
//  Prevents "audio fatigue" by tracking which categories have been played
//

import Foundation

/// Tracks category plays per session to provide rotation bonuses
/// Ensures diversity by boosting underrepresented categories
@MainActor
class CategoryRotationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CategoryRotationManager()

    // MARK: - Configuration

    /// Bonus for categories not played this session
    static let unplayedBonus: Double = 0.15

    /// Bonus for underplayed categories (played less than average)
    static let underplayedBonus: Double = 0.08

    /// Number of recent categories to track for immediate rotation
    static let recentCategoryWindowSize = 5

    // MARK: - State

    /// Play count per category this session
    @Published private(set) var sessionCategoryCounts: [AudioCategory: Int] = [:]

    /// Recent category history (last N categories played)
    @Published private(set) var recentCategories: [AudioCategory] = []

    /// Session start time for timeout
    private var sessionStartTime: Date = Date()

    /// Session timeout in seconds (reset after 2 hours of inactivity)
    static let sessionTimeoutSeconds: TimeInterval = 7200

    private init() {
        resetSession()
    }

    // MARK: - Public API

    /// Get rotation bonus for a category (0.0 - 0.15)
    /// Higher bonus = category should be prioritized for diversity
    func getRotationBonus(for category: AudioCategory) -> Double {
        checkSessionTimeout()

        let currentCount = sessionCategoryCounts[category] ?? 0
        let totalPlays = sessionCategoryCounts.values.reduce(0, +)

        // If no plays yet, all categories equal
        guard totalPlays > 0 else {
            return Self.unplayedBonus
        }

        // Category never played this session
        if currentCount == 0 {
            return Self.unplayedBonus
        }

        // Calculate average plays per category
        let playedCategories = sessionCategoryCounts.filter { $0.value > 0 }.count
        let averagePlays = Double(totalPlays) / Double(max(1, playedCategories))

        // Underplayed category (below average)
        if Double(currentCount) < averagePlays * 0.7 {
            return Self.underplayedBonus
        }

        // Check recent window - penalize if played very recently
        if let lastIndex = recentCategories.lastIndex(of: category) {
            let recency = recentCategories.count - 1 - lastIndex
            if recency < 2 {
                return 0.0 // Just played, no bonus
            }
        }

        // Default: small bonus based on relative underrepresentation
        let representationRatio = Double(currentCount) / averagePlays
        if representationRatio < 1.0 {
            return Self.underplayedBonus * (1.0 - representationRatio)
        }

        return 0.0
    }

    /// Record that a category was played
    func recordCategoryPlayed(_ category: AudioCategory) {
        checkSessionTimeout()

        // Update count
        sessionCategoryCounts[category, default: 0] += 1

        // Update recent history
        recentCategories.append(category)
        if recentCategories.count > Self.recentCategoryWindowSize {
            recentCategories.removeFirst()
        }

        print("[CategoryRotation] Recorded \(category.rawValue), total: \(sessionCategoryCounts[category] ?? 0)")
    }

    /// Reset session (e.g., when starting new emergency session)
    func resetSession() {
        sessionCategoryCounts.removeAll()
        recentCategories.removeAll()
        sessionStartTime = Date()
        print("[CategoryRotation] Session reset")
    }

    /// Get rotation statistics for insights
    func getRotationStats() -> CategoryRotationStats {
        let totalPlays = sessionCategoryCounts.values.reduce(0, +)
        let playedCount = sessionCategoryCounts.filter { $0.value > 0 }.count
        let unplayedCount = AudioCategory.allCases.count - playedCount

        let topCategory = sessionCategoryCounts.max(by: { $0.value < $1.value })
        let leastCategory = sessionCategoryCounts.filter { $0.value > 0 }.min(by: { $0.value < $1.value })

        return CategoryRotationStats(
            totalPlays: totalPlays,
            categoriesPlayed: playedCount,
            categoriesUnplayed: unplayedCount,
            mostPlayedCategory: topCategory?.key.rawValue,
            mostPlayedCount: topCategory?.value ?? 0,
            leastPlayedCategory: leastCategory?.key.rawValue,
            leastPlayedCount: leastCategory?.value ?? 0
        )
    }

    /// Get all category counts for UI display
    func getCategoryCounts() -> [AudioCategory: Int] {
        return sessionCategoryCounts
    }

    // MARK: - Private Methods

    /// Check if session has timed out
    private func checkSessionTimeout() {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        if elapsed > Self.sessionTimeoutSeconds {
            resetSession()
        }
    }
}

// MARK: - Category Rotation Stats

struct CategoryRotationStats {
    let totalPlays: Int
    let categoriesPlayed: Int
    let categoriesUnplayed: Int
    let mostPlayedCategory: String?
    let mostPlayedCount: Int
    let leastPlayedCategory: String?
    let leastPlayedCount: Int

    var diversityScore: Double {
        // Score based on how evenly distributed plays are
        guard totalPlays > 0 else { return 1.0 }

        let idealPlaysPer = Double(totalPlays) / Double(AudioCategory.allCases.count)
        guard idealPlaysPer > 0 else { return 1.0 }

        // Perfect diversity = 1.0, all plays in one category = 0.0
        let maxDifference = Double(max(mostPlayedCount, 1))
        return max(0.0, 1.0 - (maxDifference / idealPlaysPer - 1.0) / Double(AudioCategory.allCases.count))
    }
}
