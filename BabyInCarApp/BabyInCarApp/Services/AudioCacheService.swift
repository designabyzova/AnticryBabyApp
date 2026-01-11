//
//  AudioCacheService.swift
//  BabyInCarApp
//
//  Manages local audio file caching and metadata
//

import Foundation
import Combine

// MARK: - Cached Track Metadata

struct CachedTrackMetadata: Codable {
    let trackId: String
    let title: String
    let artist: String
    let category: String
    let duration: TimeInterval
    let fileSize: Int64
    let downloadedAt: Date
    let lastPlayedAt: Date?
    let playCount: Int
    let expiresAt: Date?
    let fileExtension: String  // Audio format extension (mp3, wav, m4a, etc.)

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    // Regular initializer
    init(
        trackId: String,
        title: String,
        artist: String,
        category: String,
        duration: TimeInterval,
        fileSize: Int64,
        downloadedAt: Date,
        lastPlayedAt: Date?,
        playCount: Int,
        expiresAt: Date?,
        fileExtension: String
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.category = category
        self.duration = duration
        self.fileSize = fileSize
        self.downloadedAt = downloadedAt
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.expiresAt = expiresAt
        self.fileExtension = fileExtension
    }

    // Migration support for existing cached metadata without fileExtension
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try container.decode(String.self, forKey: .trackId)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        category = try container.decode(String.self, forKey: .category)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        downloadedAt = try container.decode(Date.self, forKey: .downloadedAt)
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        playCount = try container.decode(Int.self, forKey: .playCount)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        // Default to mp3 for backward compatibility with existing cache
        fileExtension = try container.decodeIfPresent(String.self, forKey: .fileExtension) ?? "mp3"
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalTracks: Int
    let totalSize: Int64
    let oldestTrack: Date?
    let newestTrack: Date?
    let mostPlayed: String?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Audio Cache Service

@MainActor
class AudioCacheService: ObservableObject {
    static let shared = AudioCacheService()

    // MARK: - Published Properties
    @Published var cachedTracks: [String: CachedTrackMetadata] = [:]
    @Published var cacheStatistics: CacheStatistics?
    @Published var isCleaningCache: Bool = false

    // MARK: - Private Properties
    // Note: cacheDirectory and metadataFile need to be nonisolated for Task.detached access
    // FileManager.default is accessed directly where needed to avoid Sendable issues
    private nonisolated let cacheDirectory: URL
    private nonisolated let metadataFile: URL

    // MARK: - Configuration
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let minFreeSpace: Int64 = 100 * 1024 * 1024 // 100 MB minimum free space

    private init() {
        // Initialize nonisolated properties first
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)
        metadataFile = documentsPath.appendingPathComponent("AudioCacheMetadata.json")

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load metadata
        loadMetadata()
        updateStatistics()
    }

    // MARK: - Public API

    /// Get local URL for a cached track
    func getCachedURL(for trackId: String) -> URL? {
        // First check if we have metadata with file extension
        if let metadata = cachedTracks[trackId] {
            let fileURL = cacheDirectory.appendingPathComponent("\(trackId).\(metadata.fileExtension)")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        // Fallback: check for legacy .audio extension (backward compatibility)
        let legacyURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        // Also check common extensions directly (fallback for corrupted metadata)
        for ext in ["mp3", "wav", "m4a", "aac"] {
            let fileURL = cacheDirectory.appendingPathComponent("\(trackId).\(ext)")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        // Clean up orphaned metadata
        cachedTracks.removeValue(forKey: trackId)
        return nil
    }

    /// Check if a track is cached
    func isTrackCached(_ trackId: String) -> Bool {
        return getCachedURL(for: trackId) != nil
    }

    /// Save track metadata after download
    func saveTrackMetadata(_ track: AudioTrack, fileSize: Int64) {
        // Determine file extension from track metadata or stream URL
        let fileExt = getFileExtension(for: track)

        let metadata = CachedTrackMetadata(
            trackId: track.id.uuidString,
            title: track.title,
            artist: track.artist,
            category: track.category.rawValue,
            duration: track.duration,
            fileSize: fileSize,
            downloadedAt: Date(),
            lastPlayedAt: nil,
            playCount: 0,
            expiresAt: Date().addingTimeInterval(maxCacheAge),
            fileExtension: fileExt
        )

        cachedTracks[track.id.uuidString] = metadata
        saveMetadata()
        updateStatistics()
    }

    /// Get file extension for a track from metadata or stream URL
    func getFileExtension(for track: AudioTrack) -> String {
        // First, check track's fileExtension property
        if let ext = track.fileExtension, !ext.isEmpty {
            return ext
        }

        // Try to extract from fileName
        if let fileName = track.fileName {
            let pathExtension = (fileName as NSString).pathExtension.lowercased()
            if !pathExtension.isEmpty {
                return pathExtension
            }
        }

        // Try to extract from streamURL
        if let urlString = track.streamURL, let url = URL(string: urlString) {
            let pathExtension = url.pathExtension.lowercased()
            if !pathExtension.isEmpty {
                return pathExtension
            }
        }

        // Default to mp3 if no extension can be determined
        return "mp3"
    }

    /// Update last played time for a track
    func updateLastPlayed(trackId: String) {
        guard let metadata = cachedTracks[trackId] else { return }

        cachedTracks[trackId] = CachedTrackMetadata(
            trackId: metadata.trackId,
            title: metadata.title,
            artist: metadata.artist,
            category: metadata.category,
            duration: metadata.duration,
            fileSize: metadata.fileSize,
            downloadedAt: metadata.downloadedAt,
            lastPlayedAt: Date(),
            playCount: metadata.playCount + 1,
            expiresAt: metadata.expiresAt,
            fileExtension: metadata.fileExtension
        )

        saveMetadata()
    }

    /// Delete a cached track
    func deleteCachedTrack(_ trackId: String) {
        // Use getCachedURL to find the actual file (handles different extensions)
        if let fileURL = getCachedURL(for: trackId) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        // Also try to remove legacy .audio file if it exists
        let legacyURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        try? FileManager.default.removeItem(at: legacyURL)

        cachedTracks.removeValue(forKey: trackId)
        saveMetadata()
        updateStatistics()
    }

    /// Clear all cache
    func clearAllCache() async {
        isCleaningCache = true

        // Capture nonisolated properties for use in detached task
        let cacheDirPath = cacheDirectory
        await Task.detached {
            let fm = FileManager.default
            try? fm.removeItem(at: cacheDirPath)
            try? fm.createDirectory(at: cacheDirPath, withIntermediateDirectories: true)
        }.value

        cachedTracks.removeAll()
        saveMetadata()
        updateStatistics()

        isCleaningCache = false
    }

    /// Clean expired and excess cache
    func cleanupCache() async {
        isCleaningCache = true

        // Remove expired tracks
        let expiredTracks = cachedTracks.filter { $0.value.isExpired }
        for trackId in expiredTracks.keys {
            deleteCachedTrack(trackId)
        }

        // Check if we need to free up space
        let currentSize = getCurrentCacheSize()
        if currentSize > maxCacheSize {
            await trimCacheToSize(maxCacheSize)
        }

        // Check device free space
        if let freeSpace = getDeviceFreeSpace(), freeSpace < minFreeSpace {
            await trimCacheToSize(max(0, currentSize - (minFreeSpace - freeSpace)))
        }

        updateStatistics()
        isCleaningCache = false
    }

    /// Get current cache size
    func getCurrentCacheSize() -> Int64 {
        return cachedTracks.values.reduce(0) { $0 + $1.fileSize }
    }

    /// Get device free space
    func getDeviceFreeSpace() -> Int64? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let values = try? documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let freeSpace = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return freeSpace
    }

    /// Get all cached tracks sorted by most recently played
    func getCachedTracksSortedByRecent() -> [CachedTrackMetadata] {
        return cachedTracks.values
            .sorted { ($0.lastPlayedAt ?? $0.downloadedAt) > ($1.lastPlayedAt ?? $1.downloadedAt) }
    }

    /// Get offline playable tracks
    func getOfflinePlayableTracks(from library: ContentLibraryService) -> [AudioTrack] {
        let cachedIds = Set(cachedTracks.keys)
        return library.allTracks.filter { cachedIds.contains($0.id.uuidString) }
    }

    /// Preload tracks for offline use
    func preloadTracksForOffline(_ tracks: [AudioTrack]) async {
        let downloadManager = AudioDownloadManager.shared

        for track in tracks {
            // Skip if already cached
            guard !isTrackCached(track.id.uuidString) else { continue }

            // Skip generated/synthesized tracks (they don't need downloading)
            guard track.audioSourceType == .streamed || track.audioSourceType == .bundled else { continue }

            do {
                _ = try await downloadManager.downloadTrack(track)
            } catch {
                print("Failed to preload track \(track.title): \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataFile),
              let metadata = try? JSONDecoder().decode([String: CachedTrackMetadata].self, from: data) else {
            return
        }
        cachedTracks = metadata

        // Verify files exist
        for (trackId, _) in cachedTracks {
            if getCachedURL(for: trackId) == nil {
                cachedTracks.removeValue(forKey: trackId)
            }
        }
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(cachedTracks) else { return }
        try? data.write(to: metadataFile)
    }

    private func updateStatistics() {
        let tracks = Array(cachedTracks.values)

        guard !tracks.isEmpty else {
            cacheStatistics = CacheStatistics(
                totalTracks: 0,
                totalSize: 0,
                oldestTrack: nil,
                newestTrack: nil,
                mostPlayed: nil
            )
            return
        }

        let totalSize = tracks.reduce(0) { $0 + $1.fileSize }
        let oldestTrack = tracks.min(by: { $0.downloadedAt < $1.downloadedAt })?.downloadedAt
        let newestTrack = tracks.max(by: { $0.downloadedAt < $1.downloadedAt })?.downloadedAt
        let mostPlayed = tracks.max(by: { $0.playCount < $1.playCount })?.trackId

        cacheStatistics = CacheStatistics(
            totalTracks: tracks.count,
            totalSize: totalSize,
            oldestTrack: oldestTrack,
            newestTrack: newestTrack,
            mostPlayed: mostPlayed
        )
    }

    private func trimCacheToSize(_ targetSize: Int64) async {
        // Sort by LRU (Least Recently Used)
        var sortedTracks = cachedTracks.values.sorted {
            let date1 = $0.lastPlayedAt ?? $0.downloadedAt
            let date2 = $1.lastPlayedAt ?? $1.downloadedAt
            return date1 < date2 // Oldest first
        }

        var currentSize = getCurrentCacheSize()

        while currentSize > targetSize && !sortedTracks.isEmpty {
            let trackToRemove = sortedTracks.removeFirst()
            deleteCachedTrack(trackToRemove.trackId)
            currentSize -= trackToRemove.fileSize
        }
    }
}

// MARK: - Smart Preloading

extension AudioCacheService {
    /// Preload recommended tracks based on user preferences
    func preloadRecommendedTracks(
        for baby: Baby?,
        library: ContentLibraryService
    ) async {
        var tracksToPreload: [AudioTrack] = []

        // Get age-appropriate tracks
        if let ageMonths = baby?.ageInMonths {
            let ageAppropriateTracks = library.allTracks.filter {
                $0.ageRangeMin <= ageMonths && $0.ageRangeMax >= ageMonths
            }
            tracksToPreload.append(contentsOf: ageAppropriateTracks.prefix(10))
        }

        // Get high calming score tracks
        let calmingTracks = library.allTracks
            .filter { $0.calmingScore >= 0.85 }
            .sorted { $0.calmingScore > $1.calmingScore }
            .prefix(5)
        tracksToPreload.append(contentsOf: calmingTracks)

        // Get favorites
        let favorites = FavoritesManager.shared.getFavoriteTracks()
        tracksToPreload.append(contentsOf: favorites)

        // Remove duplicates and already cached
        let uniqueTracks = Array(Set(tracksToPreload.map { $0.id }))
            .compactMap { id in tracksToPreload.first { $0.id == id } }
            .filter { !isTrackCached($0.id.uuidString) }

        // Preload
        await preloadTracksForOffline(Array(uniqueTracks.prefix(20)))
    }

    /// Check WiFi and preload if appropriate
    func smartPreloadIfAppropriate(library: ContentLibraryService, baby: Baby?) async {
        // Check if user allows WiFi-only downloads
        let preferences = UserDefaults.standard
        let wifiOnly = preferences.bool(forKey: "downloadOnWiFiOnly")

        if wifiOnly {
            // Check if on WiFi (simplified check)
            guard isOnWiFi() else { return }
        }

        // Check if there's enough free space
        guard let freeSpace = getDeviceFreeSpace(),
              freeSpace > minFreeSpace * 2 else { return }

        await preloadRecommendedTracks(for: baby, library: library)
    }

    private func isOnWiFi() -> Bool {
        // Simplified WiFi check - in production, use NWPathMonitor
        return true
    }
}
