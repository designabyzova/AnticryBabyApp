//
//  AudioDownloadManager.swift
//  BabyInCarApp
//
//  Manages downloading and caching audio files from the server
//

import Foundation
import Combine

// MARK: - Download State

enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
}

// MARK: - Download Task

struct DownloadTask: Identifiable {
    let id: String
    let trackId: String
    let url: URL
    var progress: Double
    var state: DownloadState
    var localURL: URL?
}

// MARK: - Audio Download Manager

@MainActor
class AudioDownloadManager: NSObject, ObservableObject {
    static let shared = AudioDownloadManager()

    // MARK: - Published Properties
    @Published var downloadStates: [String: DownloadState] = [:]
    @Published var activeDownloads: [DownloadTask] = []
    @Published var totalDownloadProgress: Double = 0
    @Published var isDownloading: Bool = false

    // MARK: - Private Properties
    private var urlSession: URLSession!
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]
    private var completionHandlers: [String: (Result<URL, Error>) -> Void] = [:]

    // Note: cacheDirectory needs to be nonisolated for URLSessionDelegate methods
    // FileManager.default is accessed directly in nonisolated methods to avoid Sendable issues
    private nonisolated let cacheDirectory: URL

    // MARK: - Configuration
    private let maxConcurrentDownloads = 3
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB

    private override init() {
        // Setup cache directory - must be done before super.init() for nonisolated property
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)

        super.init()

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Setup URL session with background configuration
        let config = URLSessionConfiguration.background(withIdentifier: "com.babyincar.audiodownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForResource = 300 // 5 minutes
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Load existing download states from cache
        loadCachedStates()
    }

    // MARK: - Public API

    /// Get download state for a track
    /// Note: For accurate state, prefer checking AudioCacheService.shared.isTrackCached() directly
    func getDownloadState(for trackId: String) -> DownloadState {
        // First check if actively downloading or failed
        if let state = downloadStates[trackId] {
            if case .downloading = state {
                return state
            }
            if case .failed = state {
                return state
            }
        }

        // Use AudioCacheService as the single source of truth for downloaded state
        if AudioCacheService.shared.isTrackCached(trackId) {
            downloadStates[trackId] = .downloaded
            return .downloaded
        }

        // Also check local file existence as fallback
        if isTrackCached(trackId: trackId) {
            downloadStates[trackId] = .downloaded
            return .downloaded
        }

        return .notDownloaded
    }

    /// Download a track from the server
    func downloadTrack(_ track: AudioTrack) async throws -> URL {
        // Use serverId for API calls if available, otherwise fall back to UUID string
        let trackId = track.serverId ?? track.id.uuidString

        // Check if already downloaded (verify with AudioCacheService for single source of truth)
        let cacheService = AudioCacheService.shared
        if cacheService.isTrackCached(trackId), let cachedURL = getCachedURL(for: trackId) {
            downloadStates[trackId] = .downloaded
            return cachedURL
        }

        // Check if already downloading
        if case .downloading = downloadStates[trackId] {
            // Wait for existing download
            return try await waitForDownload(trackId: trackId)
        }

        // Get stream URL from track or API
        let streamURL: URL
        if let urlString = track.streamURL, !urlString.isEmpty, let url = URL(string: urlString) {
            streamURL = url
        } else {
            // Fetch stream URL from API using serverId
            streamURL = try await fetchStreamURL(for: trackId)
        }

        // Start download and save metadata
        let localURL = try await startDownload(trackId: trackId, from: streamURL, track: track)
        return localURL
    }

    /// Download multiple tracks
    func downloadTracks(_ tracks: [AudioTrack], progressHandler: ((Double) -> Void)? = nil) async throws {
        let total = tracks.count
        var completed = 0

        for track in tracks {
            do {
                _ = try await downloadTrack(track)
                completed += 1
                progressHandler?(Double(completed) / Double(total))
            } catch {
                print("Failed to download track \(track.title): \(error)")
                // Continue with other tracks
            }
        }
    }

    /// Cancel a download
    func cancelDownload(trackId: String) {
        if let task = downloadTasks[trackId] {
            task.cancel()
            downloadTasks.removeValue(forKey: trackId)
        }
        downloadStates[trackId] = .notDownloaded
        activeDownloads.removeAll { $0.trackId == trackId }
        updateTotalProgress()
    }

    /// Cancel all downloads
    func cancelAllDownloads() {
        for (trackId, task) in downloadTasks {
            task.cancel()
            downloadStates[trackId] = .notDownloaded
        }
        downloadTasks.removeAll()
        activeDownloads.removeAll()
        isDownloading = false
        totalDownloadProgress = 0
    }

    /// Delete cached track
    func deleteCachedTrack(trackId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        try? FileManager.default.removeItem(at: fileURL)
        downloadStates[trackId] = .notDownloaded
    }

    /// Clear all cache
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        downloadStates.removeAll()
    }

    /// Get cache size
    func getCacheSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    /// Get local URL for cached track
    func getCachedURL(for trackId: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    /// Check if track is cached
    func isTrackCached(trackId: String) -> Bool {
        return getCachedURL(for: trackId) != nil
    }

    // MARK: - Private Methods

    private func fetchStreamURL(for trackId: String) async throws -> URL {
        let baseURL = APIConfig.baseURL
        let urlString = "\(baseURL)/audio/stream/\(trackId)"
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        return url
    }

    /// Tracks pending for metadata save after download completes
    private var pendingTrackMetadata: [String: AudioTrack] = [:]

    private func startDownload(trackId: String, from url: URL, track: AudioTrack? = nil) async throws -> URL {
        // Store track for metadata save after download completes
        if let track = track {
            pendingTrackMetadata[trackId] = track
        }

        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(with: url)
            task.taskDescription = trackId

            downloadTasks[trackId] = task
            completionHandlers[trackId] = { result in
                switch result {
                case .success(let localURL):
                    continuation.resume(returning: localURL)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Update state
            downloadStates[trackId] = .downloading(progress: 0)
            activeDownloads.append(DownloadTask(
                id: UUID().uuidString,
                trackId: trackId,
                url: url,
                progress: 0,
                state: .downloading(progress: 0)
            ))
            isDownloading = true

            task.resume()
        }
    }

    private func waitForDownload(trackId: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            completionHandlers[trackId] = { result in
                switch result {
                case .success(let localURL):
                    continuation.resume(returning: localURL)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func updateTotalProgress() {
        guard !activeDownloads.isEmpty else {
            totalDownloadProgress = 0
            isDownloading = false
            return
        }

        let total = activeDownloads.reduce(0.0) { $0 + $1.progress }
        totalDownloadProgress = total / Double(activeDownloads.count)
        isDownloading = activeDownloads.contains { $0.state.isDownloading }
    }

    private func loadCachedStates() {
        guard let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for case let fileURL as URL in enumerator {
            let trackId = fileURL.deletingPathExtension().lastPathComponent
            downloadStates[trackId] = .downloaded
        }
    }

    private func cleanupCacheIfNeeded() {
        let currentSize = getCacheSize()
        guard currentSize > maxCacheSize else { return }

        // Get all cached files sorted by access date
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]
        ) else { return }

        var files: [(url: URL, date: Date, size: Int64)] = []
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey]),
               let date = values.contentAccessDate,
               let size = values.fileSize {
                files.append((fileURL, date, Int64(size)))
            }
        }

        // Sort by oldest first
        files.sort { $0.date < $1.date }

        // Delete oldest files until under limit
        var sizeToFree = currentSize - maxCacheSize
        for file in files {
            guard sizeToFree > 0 else { break }
            try? FileManager.default.removeItem(at: file.url)
            let trackId = file.url.deletingPathExtension().lastPathComponent
            downloadStates[trackId] = .notDownloaded
            sizeToFree -= file.size
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension AudioDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let trackId = downloadTask.taskDescription else { return }

        let destinationURL = cacheDirectory.appendingPathComponent("\(trackId).audio")
        // Use FileManager.default directly in nonisolated context to avoid Sendable issues
        let fm = FileManager.default

        do {
            // Remove existing file if any
            try? fm.removeItem(at: destinationURL)

            // Move downloaded file to cache
            try fm.moveItem(at: location, to: destinationURL)

            // Get file size for metadata
            let fileSize: Int64 = (try? fm.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0

            Task { @MainActor in
                self.downloadStates[trackId] = .downloaded
                self.downloadTasks.removeValue(forKey: trackId)
                self.activeDownloads.removeAll { $0.trackId == trackId }
                self.updateTotalProgress()
                self.cleanupCacheIfNeeded()

                // Save metadata to AudioCacheService for proper tracking
                if let track = self.pendingTrackMetadata[trackId] {
                    AudioCacheService.shared.saveTrackMetadata(track, fileSize: fileSize)
                    self.pendingTrackMetadata.removeValue(forKey: trackId)
                }

                self.completionHandlers[trackId]?(.success(destinationURL))
                self.completionHandlers.removeValue(forKey: trackId)
            }
        } catch {
            Task { @MainActor in
                self.downloadStates[trackId] = .failed(error: error.localizedDescription)
                self.downloadTasks.removeValue(forKey: trackId)
                self.activeDownloads.removeAll { $0.trackId == trackId }
                self.updateTotalProgress()
                self.pendingTrackMetadata.removeValue(forKey: trackId)

                self.completionHandlers[trackId]?(.failure(error))
                self.completionHandlers.removeValue(forKey: trackId)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let trackId = downloadTask.taskDescription else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        Task { @MainActor in
            self.downloadStates[trackId] = .downloading(progress: progress)

            if let index = self.activeDownloads.firstIndex(where: { $0.trackId == trackId }) {
                self.activeDownloads[index].progress = progress
                self.activeDownloads[index].state = .downloading(progress: progress)
            }

            self.updateTotalProgress()
            self.progressHandlers[trackId]?(progress)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let trackId = downloadTask.taskDescription,
              let error = error else { return }

        Task { @MainActor in
            self.downloadStates[trackId] = .failed(error: error.localizedDescription)
            self.downloadTasks.removeValue(forKey: trackId)
            self.activeDownloads.removeAll { $0.trackId == trackId }
            self.updateTotalProgress()

            self.completionHandlers[trackId]?(.failure(error))
            self.completionHandlers.removeValue(forKey: trackId)
        }
    }
}

// MARK: - Download Error

enum DownloadError: LocalizedError {
    case invalidURL
    case noStreamURL
    case downloadFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .noStreamURL:
            return "No stream URL available for this track"
        case .downloadFailed:
            return "Download failed"
        case .fileNotFound:
            return "Downloaded file not found"
        }
    }
}
