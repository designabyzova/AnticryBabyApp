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

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
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
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFile: URL

    // MARK: - Configuration
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let minFreeSpace: Int64 = 100 * 1024 * 1024 // 100 MB minimum free space

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)
        metadataFile = documentsPath.appendingPathComponent("AudioCacheMetadata.json")

        // Ensure cache directory exists
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load metadata
        loadMetadata()
        updateStatistics()
    }

    // MARK: - Public API

    /// Get local URL for a cached track
    func getCachedURL(for trackId: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            // Clean up orphaned metadata
            cachedTracks.removeValue(forKey: trackId)
            return nil
        }
        return fileURL
    }

    /// Check if a track is cached
    func isTrackCached(_ trackId: String) -> Bool {
        return getCachedURL(for: trackId) != nil
    }

    /// Save track metadata after download
    func saveTrackMetadata(_ track: AudioTrack, fileSize: Int64) {
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
            expiresAt: Date().addingTimeInterval(maxCacheAge)
        )

        cachedTracks[track.id.uuidString] = metadata
        saveMetadata()
        updateStatistics()
    }

    /// Update last played time for a track
    func updateLastPlayed(trackId: String) {
        guard var metadata = cachedTracks[trackId] else { return }

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
            expiresAt: metadata.expiresAt
        )

        saveMetadata()
    }

    /// Delete a cached track
    func deleteCachedTrack(_ trackId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        try? fileManager.removeItem(at: fileURL)
        cachedTracks.removeValue(forKey: trackId)
        saveMetadata()
        updateStatistics()
    }

    /// Clear all cache
    func clearAllCache() async {
        isCleaningCache = true

        await Task.detached { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
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
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
