//
//  AIAccuracyBadge.swift
//  BabyInCarApp
//
//  Displays AI accuracy stats and learning progress
//  Shows how well the AI understands THIS baby
//

import SwiftUI

/// Compact badge showing AI accuracy for this baby
struct AIAccuracyBadge: View {
    @ObservedObject var tracker: CryPredictionAccuracyTracker
    @State private var showDetails = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                Text("\(Int(tracker.overallAccuracy))% Accurate")
                    .font(.caption)
                    .fontWeight(.semibold)

                // Trend indicator
                if tracker.isImproving {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(accuracyColor.opacity(0.9))
            )
        }
        .sheet(isPresented: $showDetails) {
            AIAccuracyDetailView(tracker: tracker)
        }
    }

    private var accuracyColor: Color {
        switch tracker.overallAccuracy {
        case 85...:
            return .green
        case 70..<85:
            return .blue
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }
}

/// Detailed view of AI accuracy stats
struct AIAccuracyDetailView: View {
    @ObservedObject var tracker: CryPredictionAccuracyTracker
    @Environment(\.dismiss) private var dismiss
    @State private var animateOnAppear = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall Stats Card
                    overallStatsCard

                    // Per-Type Accuracy
                    perTypeAccuracyCard

                    // Learning Progress
                    learningProgressCard

                    // Insights
                    if tracker.totalPredictions > 20 {
                        insightsCard
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("AI Learning Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                animateOnAppear = true
            }
        }
    }

    // MARK: - Overall Stats Card

    private var overallStatsCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Overall Performance")
                    .font(.headline)
                Spacer()
            }

            // Big accuracy circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: animateOnAppear ? CGFloat(tracker.overallAccuracy / 100) : 0)
                    .stroke(
                        accuracyGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(tracker.overallAccuracy))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)

                    Text(tracker.trendDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Stats row
            HStack(spacing: 24) {
                StatItem(
                    label: "Total",
                    value: "\(tracker.totalPredictions)",
                    icon: "number"
                )

                Divider()
                    .frame(height: 30)

                StatItem(
                    label: "Correct",
                    value: "\(tracker.correctPredictions)",
                    icon: "checkmark.circle"
                )

                Divider()
                    .frame(height: 30)

                StatItem(
                    label: "Recent",
                    value: "\(Int(tracker.recentAccuracy))%",
                    icon: "clock"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    private var accuracyGradient: LinearGradient {
        switch tracker.overallAccuracy {
        case 85...:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case 70..<85:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case 50..<70:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: - Per-Type Accuracy

    private var perTypeAccuracyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.purple)
                Text("Accuracy by Cry Type")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(sortedTypeAccuracy, id: \.type) { item in
                    TypeAccuracyRow(
                        type: item.type,
                        accuracy: item.accuracy,
                        animate: animateOnAppear
                    )
                }
            }

            if tracker.accuracyByType.isEmpty {
                Text("Not enough data yet. Keep using the app!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    private struct TypeAccuracyItem {
        let type: CryType
        let accuracy: Double
    }

    private var sortedTypeAccuracy: [TypeAccuracyItem] {
        tracker.accuracyByType
            .map { TypeAccuracyItem(type: $0.key, accuracy: $0.value) }
            .sorted { $0.accuracy > $1.accuracy }
    }

    // MARK: - Learning Progress

    private var learningProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.indigo)
                Text("Learning Status")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 10) {
                ProgressRow(
                    label: "Data Collected",
                    current: tracker.totalPredictions,
                    target: 100,
                    color: .blue
                )

                ProgressRow(
                    label: "Confidence Level",
                    current: Int(tracker.overallAccuracy),
                    target: 90,
                    color: .green
                )
            }

            if tracker.totalPredictions < 20 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("More usage improves accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Insights

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("AI Insights")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 10) {
                if let best = tracker.bestPerformingType {
                    InsightRow(
                        icon: "star.fill",
                        color: .green,
                        text: "Best at detecting: \(best.type.rawValue) (\(Int(best.accuracy))%)"
                    )
                }

                if let worst = tracker.worstPerformingType {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        text: "Needs more data for: \(worst.type.rawValue) (\(Int(worst.accuracy))%)"
                    )
                }

                if tracker.isImproving {
                    InsightRow(
                        icon: "arrow.up.right.circle.fill",
                        color: .blue,
                        text: "Accuracy improving with recent predictions"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct TypeAccuracyRow: View {
    let type: CryType
    let accuracy: Double
    let animate: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundColor(colorForType)
                .frame(width: 24)

            Text(type.rawValue)
                .font(.callout)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    Capsule()
                        .fill(colorForType)
                        .frame(width: geometry.size.width * (animate ? CGFloat(accuracy / 100) : 0))
                }
            }
            .frame(height: 8)

            Text("\(Int(accuracy))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(colorForType)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var colorForType: Color {
        switch accuracy {
        case 85...:
            return .green
        case 70..<85:
            return .blue
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }
}

struct ProgressRow: View {
    let label: String
    let current: Int
    let target: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(current)/\(target)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(1.0, CGFloat(current) / CGFloat(target)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.callout)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Previews

#Preview("Accuracy Badge") {
    AIAccuracyBadge(tracker: CryPredictionAccuracyTracker.shared)
        .padding()
}

#Preview("Accuracy Detail") {
    let tracker = CryPredictionAccuracyTracker.shared
    return AIAccuracyDetailView(tracker: tracker)
}
