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

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // MARK: - Configuration
    private let maxConcurrentDownloads = 3
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB

    private override init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)

        super.init()

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

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
    func getDownloadState(for trackId: String) -> DownloadState {
        if let state = downloadStates[trackId] {
            return state
        }

        // Check if file exists in cache
        if isTrackCached(trackId: trackId) {
            downloadStates[trackId] = .downloaded
            return .downloaded
        }

        return .notDownloaded
    }

    /// Download a track from the server
    func downloadTrack(_ track: AudioTrack) async throws -> URL {
        let trackId = track.id.uuidString

        // Check if already downloaded
        if let cachedURL = getCachedURL(for: trackId) {
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
        if let urlString = track.streamURL, let url = URL(string: urlString) {
            streamURL = url
        } else {
            // Fetch stream URL from API
            streamURL = try await fetchStreamURL(for: trackId)
        }

        // Start download
        return try await startDownload(trackId: trackId, from: streamURL)
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
        try? fileManager.removeItem(at: fileURL)
        downloadStates[trackId] = .notDownloaded
    }

    /// Clear all cache
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        downloadStates.removeAll()
    }

    /// Get cache size
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
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
        if fileManager.fileExists(atPath: fileURL.path) {
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

    private func startDownload(trackId: String, from url: URL) async throws -> URL {
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
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
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
        guard let enumerator = fileManager.enumerator(
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
            try? fileManager.removeItem(at: file.url)
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

        do {
            // Remove existing file if any
            try? fileManager.removeItem(at: destinationURL)

            // Move downloaded file to cache
            try fileManager.moveItem(at: location, to: destinationURL)

            Task { @MainActor in
                self.downloadStates[trackId] = .downloaded
                self.downloadTasks.removeValue(forKey: trackId)
                self.activeDownloads.removeAll { $0.trackId == trackId }
                self.updateTotalProgress()
                self.cleanupCacheIfNeeded()

                self.completionHandlers[trackId]?(.success(destinationURL))
                self.completionHandlers.removeValue(forKey: trackId)
            }
        } catch {
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
