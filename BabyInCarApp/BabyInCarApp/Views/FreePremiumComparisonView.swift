//
//  FreePremiumComparisonView.swift
//  BabyInCarApp
//
//  Side-by-side comparison of Free vs Premium features
//  Designed to educate, not pressure - show value without frustration
//

import SwiftUI

/// Shows a clear comparison between Free and Premium tiers
struct FreePremiumComparisonView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var trialManager = TrialManager.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared
    @Environment(\.dismiss) var dismiss

    // Personalization data
    @State private var usageStats: UsageStats?
    @State private var showingSubscriptionView = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with personalization
                    headerSection

                    // Trial status banner (if applicable)
                    if trialManager.trialState.isActive {
                        trialBanner
                    }

                    // Feature comparison table
                    comparisonTable

                    // Personalized value props (if we have usage data)
                    if let stats = usageStats {
                        personalizedSection(stats: stats)
                    }

                    // CTA Section
                    ctaSection

                    // Fine print
                    finePrintSection
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBackground)
            .navigationTitle("Free vs Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .task {
            await loadUsageStats()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary.opacity(0.2), Color.appSecondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appPrimary, .appSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Compare Plans")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appText)

            Text("See what you get with Premium")
                .font(.system(size: 16))
                .foregroundColor(.appTextSecondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 20))
                .foregroundColor(.appWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Trial Active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)

                Text("\(trialManager.trialDaysRemaining) days remaining")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            Text("Full Premium Access")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appSuccess)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.appSuccess.opacity(0.15))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appWarning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appWarning.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Feature")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Free")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 60)

                Text("Premium")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 70)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appPrimary.opacity(0.05))

            Divider()

            // Feature rows
            ForEach(comparisonRows, id: \.feature) { row in
                ComparisonRow(row: row)
                Divider()
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8)
        .padding(.horizontal, 20)
    }

    private var comparisonRows: [ComparisonRowData] {
        [
            ComparisonRowData(
                feature: "Mood Selection & Tracking",
                freeValue: .checkmark,
                premiumValue: .checkmark,
                highlight: false
            ),
            ComparisonRowData(
                feature: "Baby Profile",
                freeValue: .checkmark,
                premiumValue: .checkmark,
                highlight: false
            ),
            ComparisonRowData(
                feature: "\"It Helped!\" Feedback",
                freeValue: .checkmark,
                premiumValue: .checkmark,
                highlight: false
            ),
            ComparisonRowData(
                feature: "CarPlay Support",
                freeValue: .checkmark,
                premiumValue: .checkmark,
                highlight: false
            ),
            ComparisonRowData(
                feature: "Content Library",
                freeValue: .text("25 tracks"),
                premiumValue: .text("100+ tracks"),
                highlight: true
            ),
            ComparisonRowData(
                feature: "Offline Downloads",
                freeValue: .cross,
                premiumValue: .unlimited,
                highlight: true
            ),
            ComparisonRowData(
                feature: "AI Insights",
                freeValue: .text("Top 5"),
                premiumValue: .text("Full"),
                highlight: true
            ),
            ComparisonRowData(
                feature: "AI Recommendations",
                freeValue: .cross,
                premiumValue: .checkmark,
                highlight: true
            ),
            ComparisonRowData(
                feature: "Mood Predictions",
                freeValue: .cross,
                premiumValue: .checkmark,
                highlight: true
            ),
            ComparisonRowData(
                feature: "Custom Sound Mixes",
                freeValue: .cross,
                premiumValue: .checkmark,
                highlight: true
            ),
            ComparisonRowData(
                feature: "Priority Support",
                freeValue: .cross,
                premiumValue: .checkmark,
                highlight: false
            )
        ]
    }

    // MARK: - Personalized Section

    private func personalizedSection(stats: UsageStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Based on Your Usage")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                if stats.premiumTracksViewed > 0 {
                    PersonalizedValueProp(
                        icon: "music.note.list",
                        iconColor: .appPrimary,
                        title: "Unlock \(stats.premiumTracksViewed) tracks you've previewed",
                        subtitle: "Keep exploring content your baby might love"
                    )
                }

                if stats.effectiveTracks > 0 {
                    PersonalizedValueProp(
                        icon: "heart.fill",
                        iconColor: .appSecondary,
                        title: "\(stats.effectiveTracks) tracks work for your baby",
                        subtitle: "Get unlimited access to similar content"
                    )
                }

                if stats.feedbackSessionCount > 3 {
                    PersonalizedValueProp(
                        icon: "brain.head.profile",
                        iconColor: .appSuccess,
                        title: "Learned from \(stats.feedbackSessionCount) feedback sessions",
                        subtitle: "Unlock full insights and recommendations"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            Button {
                showingSubscriptionView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))

                    Text("Upgrade to Premium")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.appPrimary, .appSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .appPrimary.opacity(0.3), radius: 8, y: 4)
            }

            // Best value hint
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.appSuccess)

                Text("Save 40% with yearly plan")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Fine Print

    private var finePrintSection: some View {
        VStack(spacing: 8) {
            Text("Cry detection is always free. We believe every parent deserves help.")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Text("Cancel anytime. No hidden fees.")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Load Usage Stats

    private func loadUsageStats() async {
        // Gather personalized usage data
        let engagement = EngagementTriggerService.shared
        let effectiveness = EffectivenessManager.shared

        usageStats = UsageStats(
            premiumTracksViewed: gatekeeper.premiumTracksViewedCount,
            effectiveTracks: effectiveness.effectiveTracksCount,
            feedbackSessionCount: engagement.feedbackSessionCount
        )
    }
}

// MARK: - Supporting Types

struct UsageStats {
    let premiumTracksViewed: Int
    let effectiveTracks: Int
    let feedbackSessionCount: Int
}

struct ComparisonRowData {
    let feature: String
    let freeValue: CellValue
    let premiumValue: CellValue
    let highlight: Bool

    enum CellValue {
        case checkmark
        case cross
        case text(String)
        case unlimited
    }
}

// MARK: - Comparison Row View

struct ComparisonRow: View {
    let row: ComparisonRowData

    var body: some View {
        HStack {
            Text(row.feature)
                .font(.system(size: 14))
                .foregroundColor(row.highlight ? .appText : .appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            cellView(for: row.freeValue, isPremium: false)
                .frame(width: 60)

            cellView(for: row.premiumValue, isPremium: true)
                .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(row.highlight ? Color.appPrimary.opacity(0.03) : Color.clear)
    }

    @ViewBuilder
    private func cellView(for value: ComparisonRowData.CellValue, isPremium: Bool) -> some View {
        switch value {
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isPremium ? .appSuccess : .appTextSecondary)

        case .cross:
            Image(systemName: "minus.circle")
                .font(.system(size: 16))
                .foregroundColor(.appTextTertiary)

        case .text(let text):
            Text(text)
                .font(.system(size: 12, weight: isPremium ? .semibold : .regular))
                .foregroundColor(isPremium ? .appPrimary : .appTextSecondary)

        case .unlimited:
            Text("Unlimited")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.appSuccess)
        }
    }
}

// MARK: - Personalized Value Prop

struct PersonalizedValueProp: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 6)
        )
    }
}

#Preview {
    FreePremiumComparisonView()
}
