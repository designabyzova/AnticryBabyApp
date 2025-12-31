//
//  TrackDownloadView.swift
//  BabyInCarApp
//
//  UI components for track download progress and management
//

import SwiftUI

// MARK: - Track Download Button

struct TrackDownloadButton: View {
    let track: AudioTrack
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    var body: some View {
        let state = downloadManager.getDownloadState(for: track.id.uuidString)

        Button(action: handleTap) {
            downloadStateIcon(state)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func downloadStateIcon(_ state: DownloadState) -> some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .font(.title2)
                .foregroundColor(.accentColor)

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "stop.fill")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }

        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
    }

    private func handleTap() {
        let state = downloadManager.getDownloadState(for: track.id.uuidString)

        switch state {
        case .notDownloaded, .failed:
            Task {
                do {
                    _ = try await downloadManager.downloadTrack(track)
                } catch {
                    print("Download failed: \(error)")
                }
            }

        case .downloading:
            downloadManager.cancelDownload(trackId: track.id.uuidString)

        case .downloaded:
            // Already downloaded - could show options to delete
            break
        }
    }
}

// MARK: - Track Row with Download

struct TrackRowWithDownload: View {
    let track: AudioTrack
    let onPlay: () -> Void
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: onPlay) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(track.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if track.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Source indicator
            sourceIndicator

            // Download button (only for streamable tracks)
            if track.audioSourceType == .streamed {
                TrackDownloadButton(track: track)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var sourceIndicator: some View {
        let state = downloadManager.getDownloadState(for: track.id.uuidString)

        HStack(spacing: 4) {
            switch state {
            case .downloaded:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)

            case .downloading(let progress):
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)

            default:
                if track.audioSourceType == .generated {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if track.audioSourceType == .bundled {
                    Image(systemName: "internaldrive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Download Progress View

struct DownloadProgressView: View {
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    var body: some View {
        if downloadManager.isDownloading {
            VStack(spacing: 8) {
                HStack {
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(downloadManager.totalDownloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Cancel All") {
                        downloadManager.cancelAllDownloads()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }

                ProgressView(value: downloadManager.totalDownloadProgress)
                    .progressViewStyle(.linear)

                if !downloadManager.activeDownloads.isEmpty {
                    Text("Downloading \(downloadManager.activeDownloads.count) track(s)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
}

// MARK: - Downloads Manager View

struct DownloadsManagerView: View {
    @ObservedObject var downloadManager = AudioDownloadManager.shared
    @ObservedObject var cacheService = AudioCacheService.shared
    @ObservedObject var library = ContentLibraryService.shared
    @State private var showClearCacheAlert = false
    @State private var isEditMode = false
    @State private var selectedTracks: Set<String> = []
    @State private var showDeleteSelectedAlert = false
    @State private var downloadOnWiFiOnly: Bool = UserDefaults.standard.bool(forKey: "downloadOnWiFiOnly")
    @State private var selectedCategory: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var cachedTracks: [CachedTrackMetadata] {
        cacheService.getCachedTracksSortedByRecent()
    }

    private var groupedByCategory: [String: [CachedTrackMetadata]] {
        Dictionary(grouping: cachedTracks, by: { $0.category })
    }

    private var categoryBreakdown: [(category: String, size: Int64, count: Int)] {
        groupedByCategory.map { (category: $0.key, size: $0.value.reduce(0) { $0 + $1.fileSize }, count: $0.value.count) }
            .sorted { $0.size > $1.size }
    }

    private var filteredTracks: [CachedTrackMetadata] {
        if let category = selectedCategory {
            return cachedTracks.filter { $0.category == category }
        }
        return cachedTracks
    }

    var body: some View {
        List {
            // Storage Overview Section
            storageOverviewSection

            // Active Downloads Section
            if !downloadManager.activeDownloads.isEmpty {
                activeDownloadsSection
            }

            // Settings Section
            settingsSection

            // Storage Breakdown Section
            if !categoryBreakdown.isEmpty {
                storageBreakdownSection
            }

            // Downloaded Tracks Section
            downloadedTracksSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Manage Downloads")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if cacheService.isCleaningCache {
                    ProgressView()
                } else if !cachedTracks.isEmpty {
                    Button(isEditMode ? "Done" : "Select") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedTracks.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .alert("Clear All Downloads", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task {
                    await cacheService.clearAllCache()
                    selectedTracks.removeAll()
                    isEditMode = false
                }
            }
        } message: {
            Text("This will delete all \(cachedTracks.count) downloaded tracks (\(cacheService.cacheStatistics?.formattedSize ?? "0 MB")). They can be downloaded again when needed.")
        }
        .alert("Delete Selected", isPresented: $showDeleteSelectedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete \(selectedTracks.count) Tracks", role: .destructive) {
                deleteSelectedTracks()
            }
        } message: {
            let selectedSize = selectedTracks.compactMap { trackId in
                cachedTracks.first { $0.trackId == trackId }?.fileSize
            }.reduce(0, +)
            Text("Delete \(selectedTracks.count) selected tracks (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))?")
        }
    }

    // MARK: - Storage Overview Section

    @ViewBuilder
    private var storageOverviewSection: some View {
        Section {
            if let stats = cacheService.cacheStatistics {
                // Storage usage bar
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stats.formattedSize)
                                .font(.system(size: 34, weight: .bold))
                            Text("\(stats.totalTracks) tracks downloaded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Storage indicator
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: min(CGFloat(stats.totalSize) / CGFloat(500 * 1024 * 1024), 1.0))
                                .stroke(storageColor(for: stats.totalSize), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(Double(stats.totalSize) / Double(500 * 1024 * 1024) * 100))%")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }

                    // Storage warning if approaching limit
                    if stats.totalSize > 400 * 1024 * 1024 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Storage nearly full. Consider removing unused tracks.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)

                // Device free space
                if let freeSpace = cacheService.getDeviceFreeSpace() {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.secondary)
                        Text("Device Free Space")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Downloads")
                            .font(.headline)
                        Text("Download tracks to play offline")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Storage")
        }
    }

    // MARK: - Active Downloads Section

    @ViewBuilder
    private var activeDownloadsSection: some View {
        Section {
            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("Downloading \(downloadManager.activeDownloads.count) track\(downloadManager.activeDownloads.count == 1 ? "" : "s")")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(downloadManager.totalDownloadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: downloadManager.totalDownloadProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
            .padding(.vertical, 4)

            // Individual downloads
            ForEach(downloadManager.activeDownloads) { task in
                EnhancedDownloadRow(task: task, library: library)
            }

            // Cancel all button
            Button(role: .destructive) {
                downloadManager.cancelAllDownloads()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel All Downloads")
                }
            }
        } header: {
            HStack {
                Text("Active Downloads")
                Spacer()
                if downloadManager.isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }

    // MARK: - Settings Section

    @ViewBuilder
    private var settingsSection: some View {
        Section {
            Toggle(isOn: $downloadOnWiFiOnly) {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download on WiFi Only")
                        Text("Save cellular data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: downloadOnWiFiOnly) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "downloadOnWiFiOnly")
            }
        } header: {
            Text("Settings")
        }
    }

    // MARK: - Storage Breakdown Section

    @ViewBuilder
    private var storageBreakdownSection: some View {
        Section {
            ForEach(categoryBreakdown, id: \.category) { item in
                Button {
                    withAnimation {
                        if selectedCategory == item.category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = item.category
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: categoryIcon(for: item.category))
                            .foregroundColor(categoryColor(for: item.category))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category)
                                .foregroundColor(.primary)
                            Text("\(item.count) track\(item.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundColor(.secondary)

                        if selectedCategory == item.category {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if selectedCategory != nil {
                Button {
                    withAnimation {
                        selectedCategory = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Show All Categories")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        } header: {
            Text("Storage by Category")
        }
    }

    // MARK: - Downloaded Tracks Section

    @ViewBuilder
    private var downloadedTracksSection: some View {
        Section {
            if filteredTracks.isEmpty {
                if selectedCategory != nil {
                    Text("No tracks in this category")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No downloaded tracks")
                            .foregroundColor(.secondary)
                        Text("Download tracks from the library to play offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                // Select/Deselect all when in edit mode
                if isEditMode {
                    Button {
                        if selectedTracks.count == filteredTracks.count {
                            selectedTracks.removeAll()
                        } else {
                            selectedTracks = Set(filteredTracks.map { $0.trackId })
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedTracks.count == filteredTracks.count ? "checkmark.circle.fill" : "circle")
                            Text(selectedTracks.count == filteredTracks.count ? "Deselect All" : "Select All")
                        }
                    }
                }

                ForEach(filteredTracks, id: \.trackId) { metadata in
                    EnhancedCachedTrackRow(
                        metadata: metadata,
                        isEditMode: isEditMode,
                        isSelected: selectedTracks.contains(metadata.trackId),
                        onToggleSelection: {
                            if selectedTracks.contains(metadata.trackId) {
                                selectedTracks.remove(metadata.trackId)
                            } else {
                                selectedTracks.insert(metadata.trackId)
                            }
                        }
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let trackId = filteredTracks[index].trackId
                        cacheService.deleteCachedTrack(trackId)
                    }
                }
            }

            // Action buttons
            if !cachedTracks.isEmpty {
                if isEditMode && !selectedTracks.isEmpty {
                    Button(role: .destructive) {
                        showDeleteSelectedAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete \(selectedTracks.count) Selected")
                        }
                    }
                }

                Button(role: .destructive) {
                    showClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Clear All Downloads")
                    }
                }
            }
        } header: {
            HStack {
                if let category = selectedCategory {
                    Text("\(category) (\(filteredTracks.count))")
                } else {
                    Text("Downloaded Tracks (\(filteredTracks.count))")
                }

                Spacer()

                if isEditMode && !selectedTracks.isEmpty {
                    Text("\(selectedTracks.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func deleteSelectedTracks() {
        for trackId in selectedTracks {
            cacheService.deleteCachedTrack(trackId)
        }
        selectedTracks.removeAll()
        isEditMode = false
    }

    private func storageColor(for size: Int64) -> Color {
        let percentage = Double(size) / Double(500 * 1024 * 1024)
        if percentage > 0.9 {
            return .red
        } else if percentage > 0.7 {
            return .orange
        } else {
            return .green
        }
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "white noise": return "waveform"
        case "nature sounds": return "leaf"
        case "classical music": return "music.note"
        case "instrumental": return "pianokeys"
        case "fairy tales": return "book"
        case "children songs", "children's songs": return "music.mic"
        default: return "music.note.list"
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "white noise": return .purple
        case "nature sounds": return .green
        case "classical music": return .orange
        case "instrumental": return .blue
        case "fairy tales": return .pink
        case "children songs", "children's songs": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Enhanced Download Row

struct EnhancedDownloadRow: View {
    let task: DownloadTask
    let library: ContentLibraryService
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    private var trackTitle: String {
        if let uuid = UUID(uuidString: task.trackId),
           let track = library.getTrack(by: uuid) {
            return track.title
        }
        return "Downloading..."
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(task.progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(task.progress * 100))")
                    .font(.caption2)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trackTitle)
                    .font(.subheadline)
                    .lineLimit(1)

                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }

            Button {
                downloadManager.cancelDownload(trackId: task.trackId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Cached Track Row

struct EnhancedCachedTrackRow: View {
    let metadata: CachedTrackMetadata
    let isEditMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    @ObservedObject var cacheService = AudioCacheService.shared

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Category badge
                    Text(metadata.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: metadata.fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if metadata.playCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text("\(metadata.playCount)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                // Download date
                Text("Downloaded \(metadata.downloadedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isEditMode {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                onToggleSelection()
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                cacheService.deleteCachedTrack(metadata.trackId)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Active Download Row

struct ActiveDownloadRow: View {
    let task: DownloadTask
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.trackId)
                    .font(.body)
                    .lineLimit(1)

                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
            }

            Spacer()

            Button {
                downloadManager.cancelDownload(trackId: task.trackId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Cached Track Row

struct CachedTrackRow: View {
    let metadata: CachedTrackMetadata
    @ObservedObject var cacheService = AudioCacheService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metadata.title)
                .font(.body)

            HStack(spacing: 8) {
                Text(metadata.category)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(ByteCountFormatter.string(fromByteCount: metadata.fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if metadata.playCount > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Played \(metadata.playCount)x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                cacheService.deleteCachedTrack(metadata.trackId)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Bulk Download View

struct BulkDownloadView: View {
    let tracks: [AudioTrack]
    @ObservedObject var downloadManager = AudioDownloadManager.shared
    @State private var isDownloading = false
    @State private var progress: Double = 0
    @Environment(\.dismiss) private var dismiss

    var downloadableTracks: [AudioTrack] {
        tracks.filter { track in
            track.audioSourceType == .streamed &&
            !downloadManager.getDownloadState(for: track.id.uuidString).isDownloaded
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if downloadableTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("All tracks downloaded!")
                            .font(.headline)

                        Text("All tracks in this selection are already available offline.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if isDownloading {
                    VStack(spacing: 16) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)

                        Text("Downloading \(Int(progress * Double(downloadableTracks.count))) of \(downloadableTracks.count) tracks")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Cancel") {
                            downloadManager.cancelAllDownloads()
                            isDownloading = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)

                        Text("\(downloadableTracks.count) tracks available for download")
                            .font(.headline)

                        Text("Download these tracks to play them offline without an internet connection.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            startBulkDownload()
                        } label: {
                            Text("Download All")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }

                Spacer()
            }
            .navigationTitle("Download Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func startBulkDownload() {
        isDownloading = true
        progress = 0

        Task {
            try? await downloadManager.downloadTracks(downloadableTracks) { currentProgress in
                Task { @MainActor in
                    progress = currentProgress
                }
            }

            await MainActor.run {
                isDownloading = false
            }
        }
    }
}

// MARK: - Offline Mode Banner

struct OfflineModeBanner: View {
    @ObservedObject var cacheService = AudioCacheService.shared
    @ObservedObject var downloadManager = AudioDownloadManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Active download indicator
            if downloadManager.isDownloading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text("Downloading \(downloadManager.activeDownloads.count) track\(downloadManager.activeDownloads.count == 1 ? "" : "s")...")
                        .font(.caption)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(Int(downloadManager.totalDownloadProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
            }

            // Offline mode status
            if let stats = cacheService.cacheStatistics, stats.totalTracks > 0 {
                NavigationLink(destination: DownloadsManagerView()) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Offline Content Ready")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text("\(stats.totalTracks) tracks • \(stats.formattedSize)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Compact Offline Badge (for use in headers)

struct OfflineBadge: View {
    @ObservedObject var cacheService = AudioCacheService.shared

    var body: some View {
        if let stats = cacheService.cacheStatistics, stats.totalTracks > 0 {
            NavigationLink(destination: DownloadsManagerView()) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(stats.totalTracks)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.15))
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Download Button") {
    VStack(spacing: 20) {
        TrackDownloadButton(track: AudioTrack(
            title: "Test Track",
            category: .classicalMusic,
            duration: 180,
            audioSourceType: .streamed,
            streamURL: "https://example.com/audio.mp3"
        ))
    }
    .padding()
}

#Preview("Downloads Manager") {
    DownloadsManagerView()
}
