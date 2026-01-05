//
//  InsightsView.swift
//  BabyInCarApp
//
//  Effectiveness insights dashboard showing what works for the baby
//  Includes statistics, category breakdown, and top tracks
//

import SwiftUI
import Charts

// MARK: - Insights View

/// Dashboard showing effectiveness insights and statistics
struct InsightsView: View {
    @StateObject private var effectivenessManager = EffectivenessManager.shared
    @StateObject private var babyProfile = BabyProfileManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if effectivenessManager.hasEffectivenessData {
                    VStack(spacing: DesignTokens.spacingL) {
                        // Summary stats
                        statsSection

                        // Category breakdown
                        categoryBreakdownSection

                        // Top tracks
                        topTracksSection

                        // Recent activity
                        recentActivitySection
                    }
                    .padding()
                } else {
                    emptyState
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Overview")
                .font(.appHeadline)
                .foregroundColor(.appText)

            HStack(spacing: DesignTokens.spacingM) {
                StatCard(
                    title: "It Helped!",
                    value: "\(effectivenessManager.totalHelpedCount)",
                    icon: "hand.thumbsup.fill",
                    color: .appSuccess
                )

                StatCard(
                    title: "Proven Tracks",
                    value: "\(effectivenessManager.tracksWithPositiveFeedback)",
                    icon: "music.note.list",
                    color: .appPrimary
                )
            }

            if let topCategory = effectivenessManager.getMostEffectiveCategory() {
                HStack(spacing: DesignTokens.spacingM) {
                    StatCard(
                        title: "Best Category",
                        value: topCategory.rawValue,
                        icon: topCategory.icon,
                        color: Color(topCategory.color)
                    )

                    Spacer()
                }
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("By Category")
                .font(.appHeadline)
                .foregroundColor(.appText)

            let categoryStats = effectivenessManager.getCategoryStatistics()

            if #available(iOS 16.0, *), !categoryStats.isEmpty {
                // Bar chart
                Chart(categoryStats, id: \.category.rawValue) { item in
                    BarMark(
                        x: .value("Score", item.score),
                        y: .value("Category", item.category.rawValue)
                    )
                    .foregroundStyle(Color(item.category.color))
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(Int(item.score))%")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.appCaption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(categoryStats.count * 44 + 20))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(Color.appCardBackground)
                )
            } else {
                // Fallback for older iOS
                VStack(spacing: DesignTokens.spacingS) {
                    ForEach(categoryStats, id: \.category.rawValue) { item in
                        CategoryStatRow(
                            category: item.category,
                            score: item.score,
                            count: item.count
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(Color.appCardBackground)
                )
            }
        }
    }

    // MARK: - Top Tracks

    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Top 5 Most Effective")
                .font(.appHeadline)
                .foregroundColor(.appText)

            let topTracks = effectivenessManager.getTopEffectiveTracks(limit: 5)

            VStack(spacing: 0) {
                ForEach(Array(topTracks.enumerated()), id: \.element.id) { index, track in
                    if let effectiveness = effectivenessManager.getEffectiveness(for: track.id) {
                        TopTrackRow(
                            rank: index + 1,
                            track: track,
                            effectiveness: effectiveness
                        )

                        if index < topTracks.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                    .fill(Color.appCardBackground)
            )
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Recent Activity")
                .font(.appHeadline)
                .foregroundColor(.appText)

            let recentFeedback = Array(effectivenessManager.recentFeedback.suffix(5).reversed())

            if recentFeedback.isEmpty {
                Text("No recent activity")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                            .fill(Color.appCardBackground)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(recentFeedback) { record in
                        RecentFeedbackRow(record: record)

                        if record.id != recentFeedback.last?.id {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(Color.appCardBackground)
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingL) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appPrimary, .appSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DesignTokens.spacingS) {
                Text("No Insights Yet")
                    .font(.appTitle2)
                    .foregroundColor(.appText)

                Text("Start using \"It Helped!\" to track what works for your baby. Insights will appear here as you collect feedback.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.appTitle2)
                .foregroundColor(.appText)

            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                .fill(Color.appCardBackground)
        )
    }
}

// MARK: - Category Stat Row

private struct CategoryStatRow: View {
    let category: AudioCategory
    let score: Double
    let count: Int

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundColor(Color(category.color))
                .frame(width: 28)

            Text(category.rawValue)
                .font(.appBody)
                .foregroundColor(.appText)

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(category.color))
                        .frame(width: geometry.size.width * (score / 100), height: 8)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(score))%")
                .font(.appCaptionMedium)
                .foregroundColor(.appTextSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Top Track Row

private struct TopTrackRow: View {
    let rank: Int
    let track: AudioTrack
    let effectiveness: TrackEffectiveness

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Rank
            Text("\(rank)")
                .font(.appTitle2)
                .foregroundColor(rankColor)
                .frame(width: 28)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.appBodyMedium)
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(track.category.rawValue)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            // Effectiveness
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(effectiveness.effectivenessScore))%")
                    .font(.appBodyMedium)
                    .foregroundColor(.appSuccess)

                Text("\(effectiveness.helpedCount) helped")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .appTextSecondary
        }
    }
}

// MARK: - Recent Feedback Row

private struct RecentFeedbackRow: View {
    let record: EffectivenessFeedbackRecord
    @StateObject private var contentLibrary = ContentLibraryService.shared

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            // Icon
            Image(systemName: record.helped ? "hand.thumbsup.fill" : "hand.thumbsdown")
                .font(.system(size: 16))
                .foregroundColor(record.helped ? .appSuccess : .appTextTertiary)
                .frame(width: 28)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                if let track = contentLibrary.getTrack(by: record.trackId) {
                    Text(track.title)
                        .font(.appBodyMedium)
                        .foregroundColor(.appText)
                        .lineLimit(1)
                } else {
                    Text("Unknown Track")
                        .font(.appBodyMedium)
                        .foregroundColor(.appTextSecondary)
                }

                HStack(spacing: 6) {
                    Text(record.timestamp.formatted(.relative(presentation: .named)))
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)

                    if let cryType = record.cryType {
                        Text("•")
                            .foregroundColor(.appTextTertiary)

                        Text(cryType)
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Insights View") {
    InsightsView()
}

#Preview("Stat Card") {
    HStack {
        StatCard(
            title: "It Helped!",
            value: "24",
            icon: "hand.thumbsup.fill",
            color: .appSuccess
        )

        StatCard(
            title: "Proven Tracks",
            value: "8",
            icon: "music.note.list",
            color: .appPrimary
        )
    }
    .padding()
    .background(Color.appBackground)
}
