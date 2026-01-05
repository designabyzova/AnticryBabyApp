import Foundation
import WatchKit

/// Manages local storage of audio files and metadata on Apple Watch
@MainActor
final class WatchStorageManager: ObservableObject {
    static let shared = WatchStorageManager()

    @Published private(set) var syncedTracks: [WatchTrack] = []
    @Published private(set) var storageUsed: Int64 = 0 // in bytes

    private let maxStorageBytes: Int64 = 50 * 1024 * 1024 // 50MB limit
    private let maxTracks = 20 // Limit to 20 favorite tracks

    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let manifestURL: URL

    private init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        manifestURL = documentsURL.appendingPathComponent("favorites_manifest.json")

        loadManifest()
        calculateStorageUsed()
    }

    // MARK: - Public Methods

    /// Save received audio file to watch storage
    func saveTrack(_ track: WatchTrack, fileData: Data) throws {
        // Check storage limits
        let fileSize = Int64(fileData.count)
        if syncedTracks.count >= maxTracks {
            // Remove oldest track to make space
            if let oldest = syncedTracks.min(by: { $0.id < $1.id }) {
                try removeTrack(oldest)
            }
        }

        if storageUsed + fileSize > maxStorageBytes {
            throw StorageError.insufficientSpace
        }

        // Save audio file
        let fileURL = audioFileURL(for: track.id)
        try fileData.write(to: fileURL)

        // Update track with local URL
        var updatedTrack = track
        updatedTrack.localURL = fileURL
        updatedTrack.isSynced = true

        // Add to synced tracks
        if let index = syncedTracks.firstIndex(where: { $0.id == track.id }) {
            syncedTracks[index] = updatedTrack
        } else {
            syncedTracks.append(updatedTrack)
        }

        // Save manifest
        saveManifest()
        calculateStorageUsed()

        print("✅ Saved track: \(track.title) (\(fileSize) bytes)")
    }

    /// Remove track from storage
    func removeTrack(_ track: WatchTrack) throws {
        guard let url = track.localURL else { return }

        try? fileManager.removeItem(at: url)
        syncedTracks.removeAll { $0.id == track.id }

        saveManifest()
        calculateStorageUsed()

        print("🗑 Removed track: \(track.title)")
    }

    /// Clear all cached audio
    func clearAll() throws {
        for track in syncedTracks {
            try? removeTrack(track)
        }

        syncedTracks.removeAll()
        saveManifest()
        calculateStorageUsed()

        print("🗑 Cleared all cached audio")
    }

    /// Get track by ID
    func track(byId id: String) -> WatchTrack? {
        syncedTracks.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func audioFileURL(for trackId: String) -> URL {
        documentsURL.appendingPathComponent("\(trackId).mp3")
    }

    private func loadManifest() {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            print("📁 No manifest found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let tracks = try JSONDecoder().decode([WatchTrack].self, from: data)

            // Verify files still exist and update URLs
            syncedTracks = tracks.compactMap { track in
                let url = audioFileURL(for: track.id)
                guard fileManager.fileExists(atPath: url.path) else {
                    print("⚠️ Audio file missing for: \(track.title)")
                    return nil
                }

                var updatedTrack = track
                updatedTrack.localURL = url
                updatedTrack.isSynced = true
                return updatedTrack
            }

            print("✅ Loaded \(syncedTracks.count) tracks from manifest")
        } catch {
            print("❌ Failed to load manifest: \(error)")
            syncedTracks = []
        }
    }

    private func saveManifest() {
        do {
            let data = try JSONEncoder().encode(syncedTracks)
            try data.write(to: manifestURL)
            print("💾 Saved manifest with \(syncedTracks.count) tracks")
        } catch {
            print("❌ Failed to save manifest: \(error)")
        }
    }

    private func calculateStorageUsed() {
        var totalBytes: Int64 = 0

        for track in syncedTracks {
            guard let url = track.localURL,
                  let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                  let fileSize = attrs[.size] as? Int64 else {
                continue
            }
            totalBytes += fileSize
        }

        storageUsed = totalBytes
        print("💾 Storage used: \(formatBytes(totalBytes)) / \(formatBytes(maxStorageBytes))")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Storage Info

    var storagePercentUsed: Double {
        Double(storageUsed) / Double(maxStorageBytes)
    }

    var formattedStorageUsed: String {
        formatBytes(storageUsed)
    }

    var formattedMaxStorage: String {
        formatBytes(maxStorageBytes)
    }

    var canAddMoreTracks: Bool {
        syncedTracks.count < maxTracks && storagePercentUsed < 0.9
    }
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case insufficientSpace
    case trackNotFound
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .insufficientSpace:
            return "Not enough storage space on Apple Watch"
        case .trackNotFound:
            return "Track not found in local storage"
        case .fileWriteFailed:
            return "Failed to write audio file"
        }
    }
}
