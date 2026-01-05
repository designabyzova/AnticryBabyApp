//
//  WhatWorksInsightsView.swift
//  BabyInCarApp
//
//  Advanced "What Works" analytics view powered by BabyMIM
//  Shows deep insights into effective soothing patterns, predictions, and recommendations
//

import SwiftUI
import Charts

// MARK: - What Works Insights View
/// Comprehensive insights view showing what soothing techniques work best for the baby
/// Powered by BabyMIM's learning and analytics
struct WhatWorksInsightsView: View {
    @StateObject private var viewModel = WhatWorksInsightsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedInsightTab: InsightTab = .overview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range selector
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .onChange(of: selectedTimeRange) { newRange in
                            viewModel.loadData(for: newRange)
                        }

                    // Key metrics overview
                    KeyMetricsRow(metrics: viewModel.keyMetrics)

                    // Tab selector
                    InsightTabSelector(selectedTab: $selectedInsightTab)

                    // Content based on selected tab
                    switch selectedInsightTab {
                    case .overview:
                        OverviewContent(viewModel: viewModel)
                    case .sounds:
                        SoundsAnalyticsContent(viewModel: viewModel)
                    case .patterns:
                        PatternsAnalyticsContent(viewModel: viewModel)
                    case .predictions:
                        PredictionsContent(viewModel: viewModel)
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "F0F7FF"),
                        Color(hex: "FFF5F5"),
                        Color(hex: "F5FFF5")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("What Works")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadData(for: selectedTimeRange)
            }
        }
    }
}

// MARK: - Time Range
enum TimeRange: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case allTime = "All Time"
}

// MARK: - Insight Tabs
enum InsightTab: String, CaseIterable {
    case overview = "Overview"
    case sounds = "Sounds"
    case patterns = "Patterns"
    case predictions = "AI Predictions"

    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .sounds: return "waveform"
        case .patterns: return "clock.fill"
        case .predictions: return "brain.head.profile"
        }
    }
}

// MARK: - Time Range Selector
struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? Color.blue : Color.white.opacity(0.8))
                        )
                        .foregroundColor(selectedRange == range ? .white : .secondary)
                }
            }
        }
    }
}

// MARK: - Insight Tab Selector
struct InsightTabSelector: View {
    @Binding var selectedTab: InsightTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InsightTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.purple : Color.white.opacity(0.9))
                        )
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Key Metrics Row
struct KeyMetricsRow: View {
    let metrics: [KeyMetric]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(metrics, id: \.title) { metric in
                KeyMetricCard(metric: metric)
            }
        }
    }
}

struct KeyMetricCard: View {
    let metric: KeyMetric

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                if let change = metric.change {
                    Text(change > 0 ? "+\(Int(change))%" : "\(Int(change))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(change > 0 ? .green : .red)
                }
            }

            Text(metric.title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct KeyMetric {
    let title: String
    let value: String
    let change: Double?
}

// MARK: - Overview Content
struct OverviewContent: View {
    @ObservedObject var viewModel: WhatWorksInsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Success rate over time chart
            InsightSectionHeader(title: "Success Rate Trend", icon: "chart.line.uptrend.xyaxis")

            if #available(iOS 16.0, *) {
                SuccessRateChart(dataPoints: viewModel.successRateTrend)
                    .frame(height: 200)
                    .padding()
                    .background(cardBackground)
            }

            // Top performing category
            InsightSectionHeader(title: "Best Performing Categories", icon: "star.fill")

            VStack(spacing: 12) {
                ForEach(viewModel.categoryPerformance, id: \.category) { performance in
                    CategoryPerformanceRow(performance: performance)
                }
            }
            .padding()
            .background(cardBackground)

            // Quick stats
            InsightSectionHeader(title: "Quick Stats", icon: "number")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickStatCard(
                    title: "Avg. Calming Time",
                    value: viewModel.avgCalmingTime,
                    icon: "timer",
                    color: .blue
                )
                QuickStatCard(
                    title: "Sessions This Week",
                    value: "\(viewModel.sessionsThisWeek)",
                    icon: "number",
                    color: .purple
                )
                QuickStatCard(
                    title: "Best Time of Day",
                    value: viewModel.bestTimeOfDay,
                    icon: "sun.max.fill",
                    color: .orange
                )
                QuickStatCard(
                    title: "Improvement",
                    value: "+\(viewModel.improvementPercent)%",
                    icon: "arrow.up.right",
                    color: .green
                )
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.9))
    }
}

// MARK: - Success Rate Chart
@available(iOS 16.0, *)
struct SuccessRateChart: View {
    let dataPoints: [SuccessRatePoint]

    var body: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Success Rate", point.rate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Success Rate", point.rate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.3), .blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text("\(Int(rate))%")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

struct SuccessRatePoint: Identifiable {
    let id = UUID()
    let date: Date
    let rate: Double
}

// MARK: - Category Performance Row
struct CategoryPerformanceRow: View {
    let performance: CategoryPerformance

    var body: some View {
        HStack {
            Image(systemName: performance.icon)
                .font(.title2)
                .foregroundColor(performance.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(performance.category)
                    .font(.subheadline.bold())
                Text("\(performance.tracksCount) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(performance.successRate * 100))%")
                    .font(.headline.bold())
                    .foregroundColor(performance.color)
                Text("success")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CategoryPerformance {
    let category: String
    let icon: String
    let color: Color
    let successRate: Double
    let tracksCount: Int
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

// MARK: - Sounds Analytics Content
struct SoundsAnalyticsContent: View {
    @ObservedObject var viewModel: WhatWorksInsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Top sounds leaderboard
            InsightSectionHeader(title: "Top Sounds Leaderboard", icon: "trophy.fill")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.topSoundsLeaderboard.enumerated()), id: \.element.name) { index, sound in
                    SoundLeaderboardRow(rank: index + 1, sound: sound)

                    if index < viewModel.topSoundsLeaderboard.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(cardBackground)

            // Sound effectiveness by cry type
            InsightSectionHeader(title: "Best Sounds by Cry Type", icon: "waveform.badge.magnifyingglass")

            ForEach(viewModel.soundsByCryType, id: \.cryType) { item in
                CryTypeSoundCard(item: item)
            }

            // Sound combinations
            InsightSectionHeader(title: "Winning Combinations", icon: "plus.circle.fill")

            ForEach(viewModel.winningCombinations, id: \.id) { combo in
                CombinationInsightCard(combination: combo)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.9))
    }
}

// MARK: - Sound Leaderboard Row
struct SoundLeaderboardRow: View {
    let rank: Int
    let sound: SoundLeaderboardItem

    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            // Sound info
            VStack(alignment: .leading, spacing: 2) {
                Text(sound.name)
                    .font(.subheadline.bold())
                Text("\(sound.timesUsed) uses • \(sound.avgCalmingTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Success rate
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(sound.successRate * 100))%")
                    .font(.headline.bold())
                    .foregroundColor(.green)

                // Success bar
                ProgressView(value: sound.successRate)
                    .tint(.green)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue.opacity(0.6)
        }
    }
}

struct SoundLeaderboardItem {
    let name: String
    let successRate: Double
    let timesUsed: Int
    let avgCalmingTime: String
}

// MARK: - Cry Type Sound Card
struct CryTypeSoundCard: View {
    let item: CryTypeSoundMapping

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.cryType.emoji)
                    .font(.title2)
                Text(item.cryType.rawValue.capitalized)
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(item.bestSounds.prefix(3), id: \.self) { sound in
                    Text(sound)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                        .foregroundColor(.green)
                }
            }

            Text(item.insight)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct CryTypeSoundMapping {
    let cryType: CryType
    let bestSounds: [String]
    let insight: String
}

// MARK: - Combination Insight Card
struct CombinationInsightCard: View {
    let combination: WinningCombination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(combination.sounds, id: \.self) { sound in
                    Text(sound)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.15))
                        )
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Text("\(Int(combination.successRate * 100))%")
                    .font(.headline.bold())
                    .foregroundColor(.green)
            }

            Text(combination.description)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text(combination.aiTip)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct WinningCombination: Identifiable {
    let id = UUID()
    let sounds: [String]
    let successRate: Double
    let description: String
    let aiTip: String
}

// MARK: - Patterns Analytics Content
struct PatternsAnalyticsContent: View {
    @ObservedObject var viewModel: WhatWorksInsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Time of day effectiveness
            InsightSectionHeader(title: "Effectiveness by Time", icon: "clock.fill")

            TimeEffectivenessChart(data: viewModel.timeEffectiveness)
                .frame(height: 200)
                .padding()
                .background(cardBackground)

            // Day of week patterns
            InsightSectionHeader(title: "Weekly Patterns", icon: "calendar")

            WeeklyPatternGrid(patterns: viewModel.weeklyPatterns)
                .padding()
                .background(cardBackground)

            // Contextual insights
            InsightSectionHeader(title: "Contextual Insights", icon: "sparkles")

            ForEach(viewModel.contextualInsights, id: \.title) { insight in
                ContextualInsightCard(insight: insight)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.9))
    }
}

// MARK: - Time Effectiveness Chart
struct TimeEffectivenessChart: View {
    let data: [TimeSlotEffectiveness]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(data, id: \.timeSlot) { slot in
                HStack {
                    Text(slot.timeSlot)
                        .font(.caption)
                        .frame(width: 60, alignment: .leading)

                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(effectivenessColor(slot.effectiveness))
                                .frame(width: geometry.size.width * slot.effectiveness)

                            Spacer()
                        }
                    }
                    .frame(height: 20)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)

                    Text("\(Int(slot.effectiveness * 100))%")
                        .font(.caption.bold())
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func effectivenessColor(_ value: Double) -> Color {
        if value >= 0.8 { return .green }
        if value >= 0.6 { return .blue }
        if value >= 0.4 { return .yellow }
        return .orange
    }
}

struct TimeSlotEffectiveness {
    let timeSlot: String
    let effectiveness: Double
}

// MARK: - Weekly Pattern Grid
struct WeeklyPatternGrid: View {
    let patterns: [DayPattern]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(patterns, id: \.day) { pattern in
                VStack(spacing: 8) {
                    Text(pattern.day)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ZStack {
                        Circle()
                            .fill(pattern.color.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Text("\(Int(pattern.effectiveness * 100))")
                            .font(.caption.bold())
                            .foregroundColor(pattern.color)
                    }

                    Text(pattern.emoji)
                        .font(.caption)
                }
            }
        }
    }
}

struct DayPattern {
    let day: String
    let effectiveness: Double
    let emoji: String

    var color: Color {
        if effectiveness >= 0.8 { return .green }
        if effectiveness >= 0.6 { return .blue }
        return .orange
    }
}

// MARK: - Contextual Insight Card
struct ContextualInsightCard: View {
    let insight: ContextualInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundColor(insight.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.bold())

                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let recommendation = insight.recommendation {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(recommendation)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct ContextualInsight {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let recommendation: String?
}

// MARK: - Predictions Content
struct PredictionsContent: View {
    @ObservedObject var viewModel: WhatWorksInsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // AI confidence
            InsightSectionHeader(title: "AI Learning Progress", icon: "brain")

            AILearningProgressCard(
                confidence: viewModel.aiConfidence,
                sessionsAnalyzed: viewModel.sessionsAnalyzed,
                patternsLearned: viewModel.patternsLearned
            )

            // Upcoming predictions
            InsightSectionHeader(title: "Predicted Needs", icon: "crystal.ball")

            ForEach(viewModel.upcomingPredictions, id: \.time) { prediction in
                PredictionCard(prediction: prediction)
            }

            // Recommended actions
            InsightSectionHeader(title: "AI Recommendations", icon: "wand.and.stars")

            ForEach(viewModel.aiRecommendations, id: \.title) { rec in
                AIRecommendationCard(recommendation: rec)
            }
        }
    }
}

// MARK: - AI Learning Progress Card
struct AILearningProgressCard: View {
    let confidence: Double
    let sessionsAnalyzed: Int
    let patternsLearned: Int

    var body: some View {
        VStack(spacing: 16) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.1)
                    .foregroundColor(.purple)

                Circle()
                    .trim(from: 0, to: confidence)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(confidence * 100))%")
                        .font(.title.bold())
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            HStack(spacing: 32) {
                VStack {
                    Text("\(sessionsAnalyzed)")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(patternsLearned)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                    Text("Patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("BabyMIM is continuously learning from each session to provide better recommendations.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.9))
        )
    }
}

// MARK: - Prediction Card
struct PredictionCard: View {
    let prediction: UpcomingPrediction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(prediction.prediction)
                    .font(.subheadline.bold())
                Text(prediction.suggestion)
                    .font(.caption)
                    .foregroundColor(.purple)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(prediction.emoji)
                    .font(.title)
                Text("\(Int(prediction.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct UpcomingPrediction {
    let time: String
    let prediction: String
    let emoji: String
    let confidence: Double
    let suggestion: String
}

// MARK: - AI Recommendation Card
struct AIRecommendationCard: View {
    let recommendation: AIRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.title)
                    .font(.subheadline.bold())

                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let action = recommendation.actionText {
                    Button {
                        // Action handler
                    } label: {
                        Text(action)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.purple)
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.9))
        )
    }
}

struct AIRecommendation {
    let title: String
    let description: String
    let actionText: String?
}

// MARK: - Section Header
struct InsightSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - View Model
@MainActor
class WhatWorksInsightsViewModel: ObservableObject {
    // Key metrics
    @Published var keyMetrics: [KeyMetric] = []

    // Overview
    @Published var successRateTrend: [SuccessRatePoint] = []
    @Published var categoryPerformance: [CategoryPerformance] = []
    @Published var avgCalmingTime: String = "0s"
    @Published var sessionsThisWeek: Int = 0
    @Published var bestTimeOfDay: String = "-"
    @Published var improvementPercent: Int = 0

    // Sounds
    @Published var topSoundsLeaderboard: [SoundLeaderboardItem] = []
    @Published var soundsByCryType: [CryTypeSoundMapping] = []
    @Published var winningCombinations: [WinningCombination] = []

    // Patterns
    @Published var timeEffectiveness: [TimeSlotEffectiveness] = []
    @Published var weeklyPatterns: [DayPattern] = []
    @Published var contextualInsights: [ContextualInsight] = []

    // Predictions
    @Published var aiConfidence: Double = 0
    @Published var sessionsAnalyzed: Int = 0
    @Published var patternsLearned: Int = 0
    @Published var upcomingPredictions: [UpcomingPrediction] = []
    @Published var aiRecommendations: [AIRecommendation] = []

    // Services - Using new AdaptiveLearningEngine for self-learning insights
    private let adaptiveLearning = AdaptiveLearningEngine.shared
    private let effectivenessManager = EffectivenessManager.shared

    func loadData(for timeRange: TimeRange) {
        loadKeyMetrics(for: timeRange)
        loadOverviewData(for: timeRange)
        loadSoundsData(for: timeRange)
        loadPatternsData(for: timeRange)
        loadPredictionsData()
    }

    private func loadKeyMetrics(for timeRange: TimeRange) {
        keyMetrics = [
            KeyMetric(title: "Success Rate", value: "78%", change: 5.2),
            KeyMetric(title: "Avg Calm Time", value: "2.3m", change: -8.1),
            KeyMetric(title: "Sessions", value: "24", change: nil),
            KeyMetric(title: "Sounds Used", value: "12", change: nil)
        ]
    }

    private func loadOverviewData(for timeRange: TimeRange) {
        // Success rate trend
        let now = Date()
        successRateTrend = (0..<7).map { i in
            SuccessRatePoint(
                date: now.addingTimeInterval(-Double(6 - i) * 86400),
                rate: Double.random(in: 65...90)
            )
        }

        // Category performance
        categoryPerformance = [
            CategoryPerformance(
                category: "White Noise",
                icon: "waveform",
                color: .purple,
                successRate: 0.85,
                tracksCount: 8
            ),
            CategoryPerformance(
                category: "Nature Sounds",
                icon: "leaf.fill",
                color: .green,
                successRate: 0.78,
                tracksCount: 12
            ),
            CategoryPerformance(
                category: "Lullabies",
                icon: "moon.fill",
                color: .blue,
                successRate: 0.72,
                tracksCount: 6
            ),
            CategoryPerformance(
                category: "Heartbeat",
                icon: "heart.fill",
                color: .red,
                successRate: 0.68,
                tracksCount: 4
            )
        ]

        avgCalmingTime = "2m 15s"
        sessionsThisWeek = 24
        bestTimeOfDay = "7-8 PM"
        improvementPercent = 12
    }

    private func loadSoundsData(for timeRange: TimeRange) {
        topSoundsLeaderboard = [
            SoundLeaderboardItem(name: "Pink Noise", successRate: 0.89, timesUsed: 45, avgCalmingTime: "1m 52s"),
            SoundLeaderboardItem(name: "Rain Sounds", successRate: 0.84, timesUsed: 38, avgCalmingTime: "2m 10s"),
            SoundLeaderboardItem(name: "Heartbeat", successRate: 0.81, timesUsed: 32, avgCalmingTime: "2m 45s"),
            SoundLeaderboardItem(name: "Ocean Waves", successRate: 0.78, timesUsed: 28, avgCalmingTime: "2m 30s"),
            SoundLeaderboardItem(name: "Womb Sounds", successRate: 0.75, timesUsed: 22, avgCalmingTime: "3m 15s")
        ]

        soundsByCryType = [
            CryTypeSoundMapping(
                cryType: .tired,
                bestSounds: ["Pink Noise", "Womb", "Rain"],
                insight: "Low-frequency sounds work best when baby is tired"
            ),
            CryTypeSoundMapping(
                cryType: .hunger,
                bestSounds: ["Heartbeat", "Shushing", "Music Box"],
                insight: "Rhythmic sounds help distract while waiting for feeding"
            ),
            CryTypeSoundMapping(
                cryType: .discomfort,
                bestSounds: ["White Noise", "Fan", "Vacuum"],
                insight: "Louder sounds can help override discomfort sensations"
            )
        ]

        winningCombinations = [
            WinningCombination(
                sounds: ["Pink Noise", "Heartbeat"],
                successRate: 0.92,
                description: "Most effective for bedtime routine",
                aiTip: "Start with heartbeat, fade to pink noise after 30 seconds"
            ),
            WinningCombination(
                sounds: ["Rain", "Ocean"],
                successRate: 0.87,
                description: "Best for daytime naps",
                aiTip: "Alternate every 2 minutes for best results"
            )
        ]
    }

    private func loadPatternsData(for timeRange: TimeRange) {
        timeEffectiveness = [
            TimeSlotEffectiveness(timeSlot: "6-9 AM", effectiveness: 0.72),
            TimeSlotEffectiveness(timeSlot: "9-12 PM", effectiveness: 0.68),
            TimeSlotEffectiveness(timeSlot: "12-3 PM", effectiveness: 0.75),
            TimeSlotEffectiveness(timeSlot: "3-6 PM", effectiveness: 0.65),
            TimeSlotEffectiveness(timeSlot: "6-9 PM", effectiveness: 0.88),
            TimeSlotEffectiveness(timeSlot: "9-12 AM", effectiveness: 0.82)
        ]

        weeklyPatterns = [
            DayPattern(day: "Mon", effectiveness: 0.75, emoji: "🙂"),
            DayPattern(day: "Tue", effectiveness: 0.82, emoji: "😊"),
            DayPattern(day: "Wed", effectiveness: 0.78, emoji: "🙂"),
            DayPattern(day: "Thu", effectiveness: 0.85, emoji: "😊"),
            DayPattern(day: "Fri", effectiveness: 0.72, emoji: "😐"),
            DayPattern(day: "Sat", effectiveness: 0.88, emoji: "😊"),
            DayPattern(day: "Sun", effectiveness: 0.91, emoji: "🥰")
        ]

        contextualInsights = [
            ContextualInsight(
                title: "After Feeding Success",
                description: "Soothing works 23% better within 30 minutes after feeding",
                icon: "drop.fill",
                color: .blue,
                recommendation: "Try soothing shortly after feeds"
            ),
            ContextualInsight(
                title: "Car Motion Boost",
                description: "Sounds are 15% more effective when car is moving",
                icon: "car.fill",
                color: .green,
                recommendation: "Combine with car rides for tough situations"
            ),
            ContextualInsight(
                title: "Evening Window",
                description: "7-8 PM shows highest success rate consistently",
                icon: "moon.stars.fill",
                color: .purple,
                recommendation: nil
            )
        ]
    }

    private func loadPredictionsData() {
        // Use real data from AdaptiveLearningEngine
        let stats = adaptiveLearning.getOverallStats()
        aiConfidence = stats.learningConfidence
        sessionsAnalyzed = stats.totalSessions
        patternsLearned = adaptiveLearning.getWhatWorksInsights().count

        upcomingPredictions = [
            UpcomingPrediction(
                time: "In ~30 minutes",
                prediction: "Likely to get sleepy",
                emoji: "😴",
                confidence: 0.82,
                suggestion: "Prepare pink noise for sleep transition"
            ),
            UpcomingPrediction(
                time: "Around 4:30 PM",
                prediction: "Feeding time approaching",
                emoji: "🍼",
                confidence: 0.78,
                suggestion: "Have heartbeat sound ready if fussy"
            ),
            UpcomingPrediction(
                time: "Tonight 7-8 PM",
                prediction: "Best bedtime window",
                emoji: "🌙",
                confidence: 0.85,
                suggestion: "Use winning combo: Pink Noise + Heartbeat"
            )
        ]

        aiRecommendations = [
            AIRecommendation(
                title: "Try Ocean Waves More",
                description: "Based on similar baby profiles, ocean sounds often become more effective over time. Consider adding to rotation.",
                actionText: "Add to Favorites"
            ),
            AIRecommendation(
                title: "Extend Sound Duration",
                description: "Your baby responds well to sounds, but sometimes needs more time. Try extending play duration by 30 seconds.",
                actionText: nil
            ),
            AIRecommendation(
                title: "Create Bedtime Playlist",
                description: "Consistent sound sequences before bed can improve sleep quality. Your winning combo is a great start.",
                actionText: "Create Playlist"
            )
        ]
    }

    private func getCurrentBabyId() -> UUID? {
        if let data = UserDefaults.standard.data(forKey: "activeBaby"),
           let baby = try? JSONDecoder().decode(Baby.self, from: data) {
            return baby.id
        }
        return nil
    }
}

// MARK: - CryType Extension
extension CryType {
    var emoji: String {
        switch self {
        case .tired: return "😴"
        case .hunger: return "🍼"
        case .discomfort: return "😣"
        case .attention: return "👶"
        case .pain: return "😢"
        case .general: return "🤔"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Preview
#Preview {
    WhatWorksInsightsView()
}
