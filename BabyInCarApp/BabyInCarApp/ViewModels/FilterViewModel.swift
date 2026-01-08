import Foundation
import SwiftUI
import Combine

/// Smart multi-filter view model with Spotify-level UX
/// Supports tag combinations, presets, undo, and intelligent track counting
@MainActor
final class FilterViewModel: ObservableObject {

    // MARK: - Published State

    /// Currently selected filter tags (multi-select)
    @Published var selectedTags: Set<FilterTag> = []

    /// All available tags extracted from current track set
    @Published var availableTags: [FilterTag] = []

    /// Tags grouped by type for organized display
    @Published var tagsByType: [FilterTagType: [FilterTag]] = [:]

    /// Track count for each tag (dynamic based on other filters)
    @Published var trackCounts: [FilterTag: Int] = [:]

    /// Filtered tracks based on selected tags
    @Published var filteredTracks: [AudioTrack] = []

    /// Active filter preset (if any)
    @Published var activePreset: FilterPreset?

    /// Previous filter state for undo
    @Published private(set) var previousFilterState: Set<FilterTag>?

    // MARK: - Dependencies

    private let contentLibrary: ContentLibraryService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(contentLibrary: ContentLibraryService = .shared) {
        self.contentLibrary = contentLibrary

        // Subscribe to track changes
        contentLibrary.$tracks
            .sink { [weak self] tracks in
                self?.updateAvailableTags(from: tracks)
                self?.applyFilters(to: tracks)
            }
            .store(in: &cancellables)
    }

    // MARK: - Filter Operations

    /// Toggle a filter tag on/off with smart multi-select
    func toggleTag(_ tag: FilterTag) {
        if selectedTags.contains(tag) {
            // Deselect tag
            selectedTags.remove(tag)
        } else {
            // Select tag (allow multiple selections)
            selectedTags.insert(tag)
        }

        // Clear active preset when manually changing filters
        activePreset = nil

        // Apply filters
        applyFilters(to: contentLibrary.tracks)
    }

    /// Apply a filter preset (replaces current filters)
    func applyPreset(_ preset: FilterPreset) {
        // Save current state for undo
        previousFilterState = selectedTags

        // Replace filters with preset tags
        selectedTags = Set(preset.tags)
        activePreset = preset

        // Apply filters
        applyFilters(to: contentLibrary.tracks)

        // Haptic feedback
        HapticManager.shared.notification(type: .success)
    }

    /// Clear all filters
    func clearFilters() {
        // Save current state for undo
        previousFilterState = selectedTags

        // Clear selection
        selectedTags.removeAll()
        activePreset = nil

        // Reset to all tracks
        applyFilters(to: contentLibrary.tracks)
    }

    /// Undo last filter change
    func undoFilterChange() {
        guard let previous = previousFilterState else { return }

        selectedTags = previous
        previousFilterState = nil
        activePreset = nil

        applyFilters(to: contentLibrary.tracks)
    }

    /// Remove specific tag type filters (e.g., clear all language filters)
    func clearTagType(_ type: FilterTagType) {
        selectedTags = selectedTags.filter { $0.type != type }
        applyFilters(to: contentLibrary.tracks)
    }

    // MARK: - Tag Extraction & Counting

    /// Extract all available tags from tracks
    private func updateAvailableTags(from tracks: [AudioTrack]) {
        var allTags: Set<FilterTag> = []
        var typeGroups: [FilterTagType: Set<FilterTag>] = [:]

        for track in tracks {
            // Extract tags from track
            let trackTags = FilterTag.extractTags(from: track)

            for tag in trackTags {
                allTags.insert(tag)

                // Group by type
                if typeGroups[tag.type] == nil {
                    typeGroups[tag.type] = []
                }
                typeGroups[tag.type]?.insert(tag)
            }
        }

        // Convert to sorted arrays
        availableTags = Array(allTags).sorted { $0.displayName < $1.displayName }

        tagsByType = typeGroups.mapValues { tags in
            Array(tags).sorted { $0.displayName < $1.displayName }
        }

        // Update track counts
        updateTrackCounts(for: tracks)
    }

    /// Update track counts for each tag (dynamic based on current filters)
    private func updateTrackCounts(for tracks: [AudioTrack]) {
        var counts: [FilterTag: Int] = [:]

        for tag in availableTags {
            // Count how many tracks would match if this tag is added
            let matchingTracks = tracks.filter { track in
                matchesTag(track, tag) && matchesCurrentFilters(track, excluding: tag)
            }
            counts[tag] = matchingTracks.count
        }

        trackCounts = counts
    }

    // MARK: - Filter Application

    /// Apply current filters to tracks
    private func applyFilters(to tracks: [AudioTrack]) {
        guard !selectedTags.isEmpty else {
            filteredTracks = tracks
            updateTrackCounts(for: tracks)
            return
        }

        // Filter tracks that match ALL selected tags (AND logic within types, OR across types)
        filteredTracks = tracks.filter { track in
            matchesAllFilters(track)
        }

        // Update counts based on filtered set
        updateTrackCounts(for: filteredTracks)
    }

    /// Check if track matches all current filters
    private func matchesAllFilters(_ track: AudioTrack) -> Bool {
        guard !selectedTags.isEmpty else { return true }

        // Group selected tags by type
        let tagsByType = Dictionary(grouping: selectedTags, by: { $0.type })

        // For each tag type, track must match at least ONE tag (OR logic within type)
        for (type, tags) in tagsByType {
            let matchesAnyInType = tags.contains { tag in
                matchesTag(track, tag)
            }

            if !matchesAnyInType {
                return false // Track doesn't match any tag in this type
            }
        }

        return true // Track matches all tag types
    }

    /// Check if track matches current filters excluding one specific tag
    private func matchesCurrentFilters(_ track: AudioTrack, excluding excludedTag: FilterTag) -> Bool {
        let otherTags = selectedTags.filter { $0 != excludedTag }
        guard !otherTags.isEmpty else { return true }

        let tagsByType = Dictionary(grouping: otherTags, by: { $0.type })

        for (_, tags) in tagsByType {
            let matchesAnyInType = tags.contains { tag in
                matchesTag(track, tag)
            }
            if !matchesAnyInType {
                return false
            }
        }

        return true
    }

    /// Check if a track matches a specific tag
    private func matchesTag(_ track: AudioTrack, _ tag: FilterTag) -> Bool {
        switch tag.type {
        case .category:
            return track.category.rawValue == tag.value

        case .language:
            return track.language?.rawValue == tag.value

        case .ageRange:
            // Parse age range from tag value (e.g., "0-3")
            let parts = tag.value.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2,
                  let tagMin = parts.first,
                  let tagMax = parts.last,
                  let trackMin = track.ageRangeMin,
                  let trackMax = track.ageRangeMax else {
                return false
            }
            // Check overlap
            return trackMin <= tagMax && trackMax >= tagMin

        case .calmingLevel:
            switch tag.value {
            case "very-calming":
                return track.calmingScore >= 0.8
            case "calming":
                return track.calmingScore >= 0.6 && track.calmingScore < 0.8
            case "moderate":
                return track.calmingScore < 0.6
            default:
                return false
            }

        case .duration:
            switch tag.value {
            case "short":
                return track.duration < 180
            case "medium":
                return track.duration >= 180 && track.duration < 600
            case "long":
                return track.duration >= 600
            default:
                return false
            }

        case .tempo:
            guard let bpm = track.tempoBPM else { return false }
            switch tag.value {
            case "slow":
                return bpm < 60
            case "medium":
                return bpm >= 60 && bpm < 120
            case "fast":
                return bpm >= 120
            default:
                return false
            }

        case .contentType:
            return track.sourceType.rawValue == tag.value

        case .subcategory, .instrument, .mood, .theme, .origin, .author, .collection:
            // These require metadata parsing (not yet implemented in AudioTrack)
            // TODO: Add metadata field to AudioTrack for subcategory/tags
            return false
        }
    }

    // MARK: - Helper Computed Properties

    /// Active filter count
    var activeFilterCount: Int {
        selectedTags.count
    }

    /// Whether filters are active
    var hasActiveFilters: Bool {
        !selectedTags.isEmpty
    }

    /// Whether undo is available
    var canUndo: Bool {
        previousFilterState != nil
    }

    /// Get tags for a specific type
    func tags(for type: FilterTagType) -> [FilterTag] {
        tagsByType[type] ?? []
    }

    /// Get selected tags for a specific type
    func selectedTags(for type: FilterTagType) -> Set<FilterTag> {
        Set(selectedTags.filter { $0.type == type })
    }

    /// Check if a tag is selected
    func isSelected(_ tag: FilterTag) -> Bool {
        selectedTags.contains(tag)
    }

    /// Get track count for a tag
    func count(for tag: FilterTag) -> Int? {
        trackCounts[tag]
    }
}

// MARK: - Filter Summary

extension FilterViewModel {
    /// Generate human-readable filter summary
    var filterSummary: String {
        guard !selectedTags.isEmpty else {
            return "All tracks"
        }

        let tagsByType = Dictionary(grouping: selectedTags, by: { $0.type })

        var parts: [String] = []

        for type in FilterTagType.allCases {
            guard let tags = tagsByType[type], !tags.isEmpty else { continue }

            let tagNames = tags.map { $0.displayName }.sorted().joined(separator: ", ")
            parts.append("\(type.displayName): \(tagNames)")
        }

        return parts.joined(separator: " • ")
    }

    /// Short filter summary for compact display
    var shortFilterSummary: String {
        guard !selectedTags.isEmpty else {
            return "All"
        }

        if selectedTags.count == 1, let first = selectedTags.first {
            return first.displayName
        }

        return "\(selectedTags.count) filters"
    }
}

// MARK: - Preset Management

extension FilterViewModel {
    /// Available filter presets
    var availablePresets: [FilterPreset] {
        FilterPreset.defaults
    }

    /// Check if a preset is applicable (has matching tracks)
    func canApplyPreset(_ preset: FilterPreset) -> Bool {
        // Simulate applying preset and check if any tracks match
        let presetTags = Set(preset.tags)
        return contentLibrary.tracks.contains { track in
            matchesPresetTags(track, tags: presetTags)
        }
    }

    private func matchesPresetTags(_ track: AudioTrack, tags: Set<FilterTag>) -> Bool {
        let tagsByType = Dictionary(grouping: tags, by: { $0.type })

        for (_, typeTags) in tagsByType {
            let matchesAnyInType = typeTags.contains { tag in
                matchesTag(track, tag)
            }
            if !matchesAnyInType {
                return false
            }
        }

        return true
    }
}
