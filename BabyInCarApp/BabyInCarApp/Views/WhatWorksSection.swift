//
//  WhatWorksSection.swift
//  BabyInCarApp
//
//  Smart section showing tracks that have proven effective
//  for calming the baby based on user feedback
//

import SwiftUI

// MARK: - What Works Section

/// Section showing tracks with proven effectiveness for the baby
struct WhatWorksSection: View {
    @StateObject private var effectivenessManager = EffectivenessManager.shared
    @StateObject private var babyProfile = BabyProfileManager.shared
    @StateObject private var contentLibrary = ContentLibraryService.shared
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var selectedCryType: CryType? = nil
    @State private var showAllTracks = false

    // Available cry type filters
    private let cryTypeFilters: [CryType] = [.hunger, .tired, .discomfort, .attention]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            // Section Header
            sectionHeader

            // Cry type filter pills
            if effectivenessManager.hasEffectivenessData {
                cryTypeFilters_view
            }

            // Content
            if effectivenessManager.hasEffectivenessData {
                tracksCarousel
            } else {
                WhatWorksEmptyState()
            }
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .sheet(isPresented: $showAllTracks) {
            WhatWorksFullListView(selectedCryType: selectedCryType)
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.appSuccess)

                    Text(sectionTitle)
                        .font(.appHeadline)
                        .foregroundColor(.appText)
                }

                if effectivenessManager.tracksWithPositiveFeedback > 0 {
                    Text("\(effectivenessManager.tracksWithPositiveFeedback) proven tracks")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }

            Spacer()

            // See All button
            if effectivenessManager.tracksWithPositiveFeedback > 3 {
                Button {
                    showAllTracks = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.appCaptionMedium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }

    private var sectionTitle: String {
        // Note: BabyProfileManager doesn't have currentBaby property
        return "What Works for Your Baby"
    }

    // MARK: - Cry Type Filters

    private var cryTypeFilters_view: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingS) {
                // All filter
                FilterPill(
                    title: "All",
                    icon: "sparkles",
                    isSelected: selectedCryType == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCryType = nil
                    }
                }

                // Cry type filters
                ForEach(cryTypeFilters, id: \.rawValue) { cryType in
                    FilterPill(
                        title: cryType.rawValue,
                        icon: cryType.iconName,
                        isSelected: selectedCryType == cryType
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCryType = cryType
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Tracks Carousel

    private var tracksCarousel: some View {
        let tracks = effectivenessManager.getTopEffectiveTracks(limit: 8, cryType: selectedCryType)

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DesignTokens.spacingM) {
                ForEach(tracks) { track in
                    EffectiveTrackCard(
                        track: track,
                        effectiveness: effectivenessManager.getEffectiveness(for: track.id)
                    ) {
                        audioEngine.play(track: track, fromTracks: tracks, contextName: "Effective Tracks")
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(title)
                    .font(.appCaptionMedium)
            }
            .foregroundColor(isSelected ? .white : .appTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.appPrimary : Color.appCardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(Color.appTextTertiary.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Effective Track Card

/// Track card variant that shows effectiveness badge
struct EffectiveTrackCard: View {
    let track: AudioTrack
    let effectiveness: TrackEffectiveness?
    let onPlay: () -> Void

    @State private var showDetailPopover = false

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                // Artwork with badge
                ZStack(alignment: .topTrailing) {
                    // Artwork placeholder (or real artwork)
                    RoundedRectangle(cornerRadius: DesignTokens.radiusM)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(track.category.color).opacity(0.8),
                                    Color(track.category.color).opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .overlay(
                            Image(systemName: track.category.icon)
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.9))
                        )

                    // Effectiveness badge
                    if let effectiveness = effectiveness, effectiveness.helpedCount > 0 {
                        EffectivenessBadge(
                            score: effectiveness.effectivenessScore,
                            size: .small
                        )
                        .padding(8)
                    }
                }

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
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(CardPressStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if effectiveness != nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDetailPopover = true
                    }
                }
        )
        .sheet(isPresented: $showDetailPopover) {
            if let effectiveness = effectiveness {
                EffectivenessDetailPopover(
                    effectiveness: effectiveness,
                    isPresented: $showDetailPopover
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - What Works Empty State

/// Friendly empty state when no effectiveness data exists
struct WhatWorksEmptyState: View {
    var body: some View {
        VStack(spacing: DesignTokens.spacingM) {
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appPrimary, .appSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DesignTokens.spacingXS) {
                Text("Start noting what helps!")
                    .font(.appHeadline)
                    .foregroundColor(.appText)

                Text("Tap 'It Helped!' when a track calms your baby.\nWe'll learn what works best.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingL)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusL)
                .fill(Color.appCardBackground)
        )
    }
}

// MARK: - What Works Full List View

/// Full screen view showing all effective tracks with filtering
struct WhatWorksFullListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var effectivenessManager = EffectivenessManager.shared
    @EnvironmentObject var audioEngine: AudioEngine

    @State var selectedCryType: CryType?

    private let cryTypeFilters: [CryType] = [.hunger, .tired, .discomfort, .attention, .general]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Cry type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingS) {
                        FilterPill(
                            title: "All",
                            icon: "sparkles",
                            isSelected: selectedCryType == nil
                        ) {
                            withAnimation { selectedCryType = nil }
                        }

                        ForEach(cryTypeFilters, id: \.rawValue) { cryType in
                            FilterPill(
                                title: cryType.rawValue,
                                icon: cryType.iconName,
                                isSelected: selectedCryType == cryType
                            ) {
                                withAnimation { selectedCryType = cryType }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingM)
                }
                .padding(.vertical, DesignTokens.spacingM)

                // Track list
                let tracks = effectivenessManager.getTopEffectiveTracks(limit: 50, cryType: selectedCryType)

                if tracks.isEmpty {
                    Spacer()
                    Text("No tracks match this filter")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                } else {
                    List {
                        ForEach(tracks) { track in
                            EffectiveTrackRow(
                                track: track,
                                effectiveness: effectivenessManager.getEffectiveness(for: track.id)
                            ) {
                                audioEngine.play(track: track, fromTracks: tracks, contextName: "Effective Tracks")
                                dismiss()
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(
                                top: 8, leading: 16, bottom: 8, trailing: 16
                            ))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("What Works")
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
}

// MARK: - Effective Track Row

/// List row for effective tracks with more detail
private struct EffectiveTrackRow: View {
    let track: AudioTrack
    let effectiveness: TrackEffectiveness?
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: DesignTokens.spacingM) {
                // Artwork
                RoundedRectangle(cornerRadius: DesignTokens.radiusS)
                    .fill(Color(track.category.color).opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: track.category.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(track.category.color))
                    )

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.appBodyMedium)
                        .foregroundColor(.appText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(track.category.rawValue)
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)

                        if let effectiveness = effectiveness, effectiveness.helpedCount > 0 {
                            Text("•")
                                .foregroundColor(.appTextTertiary)

                            Text(effectiveness.effectivenessDescription)
                                .font(.appCaption)
                                .foregroundColor(.appSuccess)
                        }
                    }
                }

                Spacer()

                // Badge
                if let effectiveness = effectiveness, effectiveness.helpedCount > 0 {
                    EffectivenessBadge(
                        score: effectiveness.effectivenessScore,
                        size: .medium
                    )
                }

                // Play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.appPrimary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("What Works Section") {
    ScrollView {
        WhatWorksSection()
            .environmentObject(AudioEngine.shared)
    }
    .background(Color.appBackground)
}

#Preview("What Works Empty") {
    WhatWorksEmptyState()
        .padding()
        .background(Color.appBackground)
}
