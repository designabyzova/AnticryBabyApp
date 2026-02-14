import SwiftUI

/// Enhanced category detail view with Spotify-level multi-filtering
/// Displays tracks for a specific category with smart tag-based discovery
struct CategoryDetailView: View {
    let category: AudioCategory

    @StateObject private var filterVM = FilterViewModel()
    @ObservedObject private var contentLibrary = ContentLibraryService.shared
    @ObservedObject private var gatekeeper = FreemiumGatekeeper.shared
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var appState: AppState

    @State private var showFilterSheet = false
    @State private var showSoftPaywall = false
    @State private var softPaywallTrack: AudioTrack?
    @State private var scrollOffset: CGFloat = 0

    private let languageFilteredCategories: Set<AudioCategory> = [.fairyTales, .childrenSongs, .podcasts]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Hero header with category info
                    categoryHeader
                        .id("header")

                    // Filter presets (Quick Picks)
                    if !FilterPreset.defaults.isEmpty {
                        FilterPresetSection(
                            presets: FilterPreset.defaults,
                            isPremiumUser: gatekeeper.hasPremiumAccess,
                            onPresetApply: { preset in
                                filterVM.applyPreset(preset)
                            }
                        )
                        .padding(.vertical, 16)
                    }

                    // Active filter summary
                    if filterVM.hasActiveFilters {
                        activeFilterSummary
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    // Horizontal filter chips (top-level tags)
                    if !filterVM.availableTags.isEmpty {
                        FilterChipBar(
                            tags: topLevelTags,
                            selectedTags: filterVM.selectedTags,
                            trackCounts: filterVM.trackCounts,
                            onTagToggle: { tag in
                                filterVM.toggleTag(tag)
                            }
                        )
                        .padding(.bottom, 8)
                    }

                    // Advanced filters button
                    advancedFiltersButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Track grid/list
                    trackGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
            }
            .background(Color.appBackground)
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        if filterVM.hasActiveFilters {
                            Button(role: .destructive) {
                                filterVM.clearFilters()
                            } label: {
                                Label("Clear Filters", systemImage: "xmark.circle")
                            }
                        }

                        Divider()

                        Button {
                            // Sort options
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                advancedFilterSheet
            }
            .sheet(isPresented: $showSoftPaywall) {
                if let track = softPaywallTrack {
                    SoftPaywallSheet(
                        track: track,
                        onUpgrade: {},
                        onDismiss: {
                            gatekeeper.recordPromptDismissed(for: track)
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .onAppear {
                // Initialize filter with category-specific tracks
                loadCategoryTracks()
            }
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        VStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.gradientStart, category.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: category.gradientStart.opacity(0.4), radius: 20, x: 0, y: 10)

                Image(systemName: category.iconName)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(.white)
            }

            // Category name and track count
            VStack(spacing: 4) {
                Text(category.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.appText)

                let count = filterVM.hasActiveFilters ? filterVM.filteredTracks.count : categoryTracks.count
                Text("\(count) track\(count != 1 ? "s" : "")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Active Filter Summary

    private var activeFilterSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.appPrimary)

            Text(filterVM.shortFilterSummary)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appText)

            Spacer()

            // Reset button
            FilterResetButton(
                activeFilterCount: filterVM.activeFilterCount,
                onReset: {
                    filterVM.clearFilters()
                },
                onUndo: filterVM.canUndo ? {
                    filterVM.undoFilterChange()
                } : nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Advanced Filters Button

    private var advancedFiltersButton: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            showFilterSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))

                Text("More Filters")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.appPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appPrimary.opacity(0.3), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground).opacity(0.5))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Track Grid

    private var trackGrid: some View {
        let tracks = filterVM.hasActiveFilters ? filterVM.filteredTracks : categoryTracks

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(tracks) { track in
                CategoryTrackCard(
                    track: track,
                    isLocked: !gatekeeper.canPlayTrack(track),
                    onTap: { handleTrackTap(track) }
                )
            }
        }
    }

    // MARK: - Advanced Filter Sheet

    private var advancedFilterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter presets
                    FilterPresetSection(
                        presets: FilterPreset.defaults,
                        isPremiumUser: gatekeeper.hasPremiumAccess,
                        onPresetApply: { preset in
                            filterVM.applyPreset(preset)
                            showFilterSheet = false
                        }
                    )

                    Divider()
                        .padding(.horizontal, 20)

                    // Grouped filters by type
                    GroupedFilterView(
                        tagsByType: filterVM.tagsByType,
                        selectedTags: filterVM.selectedTags,
                        trackCounts: filterVM.trackCounts,
                        onTagToggle: { tag in
                            filterVM.toggleTag(tag)
                        }
                    )
                }
                .padding(.bottom, 100)
            }
            .background(Color.appBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if filterVM.hasActiveFilters {
                        Button("Clear") {
                            filterVM.clearFilters()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                // Results count
                if filterVM.hasActiveFilters {
                    HStack {
                        Text("\(filterVM.filteredTracks.count) results")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary)
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    )
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Helpers

    private var categoryTracks: [AudioTrack] {
        let allTracks = contentLibrary.getTracks(for: category)

        // Filter by language if applicable
        guard languageFilteredCategories.contains(category),
              !appState.selectedLanguages.isEmpty else {
            return allTracks
        }

        return allTracks.filter { track in
            guard let trackLanguage = track.language else { return true }
            return appState.selectedLanguages.contains(trackLanguage)
        }
    }

    private var topLevelTags: [FilterTag] {
        // Show most important tag types in horizontal scroll
        let priorityTypes: [FilterTagType] = [
            .subcategory,
            .mood,
            .instrument,
            .ageRange,
            .calmingLevel
        ]

        var tags: [FilterTag] = []
        for type in priorityTypes {
            if let typeTags = filterVM.tagsByType[type] {
                tags.append(contentsOf: typeTags)
            }
        }

        return tags
    }

    private func loadCategoryTracks() {
        // Filter tracks by category and update FilterViewModel
        // This would ideally be done in FilterViewModel with a category parameter
        // For now, we rely on ContentLibraryService filtering
    }

    private func handleTrackTap(_ track: AudioTrack) {
        if gatekeeper.canPlayTrack(track) {
            let contextTracks = filterVM.hasActiveFilters ? filterVM.filteredTracks : categoryTracks
            audioEngine.play(
                track: track,
                fromTracks: contextTracks,
                contextName: category.displayName
            )
        } else if gatekeeper.shouldShowUpgradePrompt(for: track) {
            softPaywallTrack = track
            gatekeeper.recordPromptShown(for: track)
            showSoftPaywall = true
        }
    }
}

// MARK: - Track Card Component

private struct CategoryTrackCard: View {
    let track: AudioTrack
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Album art / category icon
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [track.category.gradientStart, track.category.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: track.category.iconName)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        )

                    // Lock badge
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .padding(8)
                    }
                }

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                    }

                    // Duration
                    Text(track.formattedDuration)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryDetailView(category: .classicalMusic)
            .environmentObject(AudioEngine.shared)
            .environmentObject(AppState())
    }
}
