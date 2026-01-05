//
//  SearchView.swift
//  BabyInCarApp
//
//  Content Search & Discovery View
//

import SwiftUI

// MARK: - Search View

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.searchQuery.isEmpty {
                            // Empty state: show suggestions
                            suggestionsView
                        } else if viewModel.isLoading {
                            loadingView
                        } else if viewModel.searchResults.isEmpty {
                            emptyResultsView
                        } else {
                            searchResultsView
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isSearchFocused = false
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                }
            }
        }
        .task {
            await viewModel.loadSuggestions()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search fairy tales, lullabies...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            if !viewModel.searchQuery.isEmpty {
                Button("Search") {
                    Task { await viewModel.search() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Recent Searches
            if !viewModel.suggestions.recent.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            Task { await viewModel.clearHistory() }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    ForEach(viewModel.suggestions.recent) { item in
                        Button {
                            viewModel.searchQuery = item.query
                            Task { await viewModel.search() }
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                Text(item.query)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(item.resultsCount) results")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Popular Searches
            if !viewModel.suggestions.popular.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular")
                        .font(.headline)

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.suggestions.popular) { item in
                            Button {
                                viewModel.searchQuery = item.query
                                Task { await viewModel.search() }
                            } label: {
                                Text(item.query)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Browse by Category
            if !viewModel.suggestions.featuredTaxonomies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse")
                        .font(.headline)

                    // Group by taxonomy type
                    let grouped = Dictionary(grouping: viewModel.suggestions.featuredTaxonomies) { $0.taxonomyType }

                    ForEach(["origin", "theme", "author"], id: \.self) { type in
                        if let items = grouped[type], !items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(taxonomyTypeDisplayName(type))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(items) { item in
                                            NavigationLink {
                                                TaxonomyBrowseView(
                                                    type: TaxonomyType(rawValue: item.taxonomyType) ?? .origin,
                                                    value: item.taxonomyValue,
                                                    displayName: item.displayName
                                                )
                                            } label: {
                                                TaxonomyChip(
                                                    name: item.displayName,
                                                    icon: item.icon,
                                                    color: item.color,
                                                    count: item.trackCount
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Results header
            HStack {
                Text("\(viewModel.totalResults) results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                // Filter chips could go here
            }

            // Active filters
            if let filters = viewModel.activeFilters, hasActiveFilters(filters) {
                FlowLayout(spacing: 8) {
                    ForEach(activeFilterItems(filters), id: \.0) { key, value in
                        HStack(spacing: 4) {
                            Text(value)
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                        .onTapGesture {
                            viewModel.removeFilter(key)
                        }
                    }
                }
            }

            // Results list
            ForEach(viewModel.searchResults) { track in
                SearchResultRow(track: track, allTracks: viewModel.searchResults)
            }

            // Load more
            if viewModel.hasMoreResults {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    HStack {
                        if viewModel.isLoadingMore {
                            ProgressView()
                        }
                        Text("Load More")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No results for \"\(viewModel.searchQuery)\"")
                .font(.headline)
            Text("Try different keywords or browse categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func taxonomyTypeDisplayName(_ type: String) -> String {
        switch type {
        case "origin": return "By Origin"
        case "theme": return "By Theme"
        case "author": return "By Author"
        case "source": return "By Source"
        default: return type.capitalized
        }
    }

    private func hasActiveFilters(_ filters: SearchFilters) -> Bool {
        filters.origin != nil || filters.author != nil || filters.theme != nil ||
        filters.category != nil || filters.language != nil
    }

    private func activeFilterItems(_ filters: SearchFilters) -> [(String, String)] {
        var items: [(String, String)] = []
        if let v = filters.origin { items.append(("origin", v)) }
        if let v = filters.author { items.append(("author", v)) }
        if let v = filters.theme { items.append(("theme", v)) }
        if let v = filters.category { items.append(("category", v)) }
        if let v = filters.language { items.append(("language", v)) }
        return items
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let track: SearchTrack
    let allTracks: [SearchTrack]  // Full search results for context
    @EnvironmentObject private var audioEngine: AudioEngine

    var body: some View {
        Button {
            playTrack()
        } label: {
            HStack(spacing: 12) {
                // Artwork or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))

                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .foregroundColor(categoryColor)
                }
                .frame(width: 56, height: 56)

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Tags
                    HStack(spacing: 4) {
                        if let themes = track.taxonomies?.theme, !themes.isEmpty {
                            ForEach(themes.prefix(2), id: \.self) { theme in
                                Text(theme)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                Spacer()

                // Duration & Premium badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDuration(track.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if track.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch track.category {
        case "fairy_tales": return .purple
        case "classical_music": return .blue
        case "nature_sounds": return .green
        case "white_noise": return .gray
        case "lullabies", "children_songs": return .pink
        default: return .orange
        }
    }

    private var categoryIcon: String {
        switch track.category {
        case "fairy_tales": return "book.fill"
        case "classical_music": return "music.note"
        case "nature_sounds": return "leaf.fill"
        case "white_noise": return "waveform"
        case "lullabies", "children_songs": return "moon.stars.fill"
        default: return "music.note.list"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func playTrack() {
        // Convert SearchTrack to AudioTrack for playback
        let audioTrack = AudioTrack(
            id: UUID(uuidString: track.id) ?? UUID(),
            title: track.title,
            artist: track.artist,
            category: AudioCategory(rawValue: track.category) ?? .instrumental,
            language: Language(rawValue: track.language),
            duration: TimeInterval(track.duration),
            ageRangeMin: track.ageRangeMin,
            ageRangeMax: track.ageRangeMax,
            calmingScore: track.calmingScore,
            audioSourceType: AudioSourceType(rawValue: track.audioSourceType) ?? .streamed,
            streamURL: track.streamUrl,
            serverId: track.id  // Store original server ID for API calls
        )

        // Convert all search results to AudioTrack array for playlist context
        let allAudioTracks = allTracks.map { searchTrack in
            AudioTrack(
                id: UUID(uuidString: searchTrack.id) ?? UUID(),
                title: searchTrack.title,
                artist: searchTrack.artist,
                category: AudioCategory(rawValue: searchTrack.category) ?? .instrumental,
                language: Language(rawValue: searchTrack.language),
                duration: TimeInterval(searchTrack.duration),
                ageRangeMin: searchTrack.ageRangeMin,
                ageRangeMax: searchTrack.ageRangeMax,
                calmingScore: searchTrack.calmingScore,
                audioSourceType: AudioSourceType(rawValue: searchTrack.audioSourceType) ?? .streamed,
                streamURL: searchTrack.streamUrl,
                serverId: searchTrack.id
            )
        }

        // Play with full search results as context for next/previous navigation
        audioEngine.play(track: audioTrack, fromTracks: allAudioTracks, contextName: "Search Results")
    }
}

// MARK: - Taxonomy Chip

struct TaxonomyChip: View {
    let name: String
    let icon: String?
    let color: String?
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(name)
                .font(.subheadline)
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(chipColor.opacity(0.15))
        .foregroundColor(chipColor)
        .cornerRadius(20)
    }

    private var chipColor: Color {
        if let hex = color {
            return Color(hex: hex)
        }
        return .accentColor
    }
}

// MARK: - Taxonomy Browse View

struct TaxonomyBrowseView: View {
    let type: TaxonomyType
    let value: String
    let displayName: String

    @StateObject private var viewModel = TaxonomyBrowseViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.tracks) { track in
                        SearchResultRow(track: track, allTracks: viewModel.tracks)
                    }

                    if viewModel.hasMore {
                        Button {
                            Task { await viewModel.loadMore() }
                        } label: {
                            if viewModel.isLoadingMore {
                                ProgressView()
                            } else {
                                Text("Load More")
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(displayName)
        .task {
            await viewModel.load(type: type, value: value)
        }
    }
}

// MARK: - View Models

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchTrack] = []
    @Published var suggestions = SearchSuggestions(recent: [], popular: [], featuredTaxonomies: [])
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var totalResults = 0
    @Published var hasMoreResults = false
    @Published var activeFilters: SearchFilters?

    private var currentOffset = 0
    private let pageSize = 30

    func loadSuggestions() async {
        do {
            let response = try await APIClient.shared.getSearchSuggestions()
            suggestions = response.suggestions
        } catch {
            print("Failed to load suggestions: \(error)")
        }
    }

    func search() async {
        guard !searchQuery.isEmpty else { return }

        isLoading = true
        currentOffset = 0

        do {
            let response = try await APIClient.shared.searchTracks(query: searchQuery, limit: pageSize)
            searchResults = response.tracks
            totalResults = response.total
            hasMoreResults = response.hasMore
            activeFilters = response.filters
        } catch {
            print("Search failed: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMoreResults, !isLoadingMore else { return }

        isLoadingMore = true
        currentOffset += pageSize

        do {
            let response = try await APIClient.shared.searchTracks(
                query: searchQuery,
                limit: pageSize,
                offset: currentOffset
            )
            searchResults.append(contentsOf: response.tracks)
            hasMoreResults = response.hasMore
        } catch {
            print("Load more failed: \(error)")
        }

        isLoadingMore = false
    }

    func clearHistory() async {
        do {
            try await APIClient.shared.clearSearchHistory()
            // Create a new suggestions with empty recent but keep other values
            suggestions = SearchSuggestions(
                recent: [],
                popular: suggestions.popular,
                featuredTaxonomies: suggestions.featuredTaxonomies
            )
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    func removeFilter(_ key: String) {
        // Re-search without the filter
        Task {
            await search()
        }
    }
}

@MainActor
class TaxonomyBrowseViewModel: ObservableObject {
    @Published var tracks: [SearchTrack] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = false

    private var type: TaxonomyType = .origin
    private var value = ""
    private var currentOffset = 0
    private let pageSize = 50

    func load(type: TaxonomyType, value: String) async {
        self.type = type
        self.value = value
        isLoading = true
        currentOffset = 0

        do {
            let response = try await APIClient.shared.browseTaxonomy(type: type, value: value)
            tracks = response.tracks
            hasMore = response.hasMore
        } catch {
            print("Browse failed: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }

        isLoadingMore = true
        currentOffset += pageSize

        do {
            let response = try await APIClient.shared.browseTaxonomy(
                type: type,
                value: value,
                limit: pageSize,
                offset: currentOffset
            )
            tracks.append(contentsOf: response.tracks)
            hasMore = response.hasMore
        } catch {
            print("Load more failed: \(error)")
        }

        isLoadingMore = false
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

// Note: Color.init(hex:) is defined in Extensions/Colors.swift

// Note: SearchSuggestions.recent is now accessed directly from the struct in APIClient.swift

#Preview {
    SearchView()
        .environmentObject(AudioEngine.shared)
}
