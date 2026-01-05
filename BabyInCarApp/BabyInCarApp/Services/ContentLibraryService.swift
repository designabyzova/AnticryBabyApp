//
//  ContentLibraryService.swift
//  BabyInCarApp
//
//  Content library management - online-first with server API and local fallbacks
//

import Foundation
import Combine

@MainActor
class ContentLibraryService: ObservableObject {
    static let shared = ContentLibraryService()

    @Published var allTracks: [AudioTrack] = []
    @Published var playlists: [Playlist] = []
    @Published var isLoading: Bool = false
    @Published var loadingError: String?
    @Published var lastSyncDate: Date?

    // Server-fetched tracks
    @Published var serverTracks: [AudioTrack] = []
    @Published var serverPlaylists: [Playlist] = []

    private let apiClient = APIClient.shared
    private let cacheService = AudioCacheService.shared
    private let userDefaults = UserDefaults.standard

    private let lastSyncKey = "ContentLibrary.lastSync"
    private let cachedTracksKey = "ContentLibrary.cachedTracks"
    private let cachedPlaylistsKey = "ContentLibrary.cachedPlaylists"

    private init() {
        loadCachedContent()
        loadContent()
    }

    // MARK: - Content Loading

    func loadContent() {
        isLoading = true
        loadingError = nil

        // First, load local/generated content for immediate availability
        let localTracks = generateAllTracks()
        allTracks = localTracks
        playlists = generateDefaultPlaylists()

        // Initialize freemium track selection
        initializeFreemiumSelection()

        // Start trial if needed (for new users)
        TrialManager.shared.startTrialIfNeeded()

        // Then fetch from server in background
        Task {
            await fetchServerContent()
        }

        isLoading = false
    }

    /// Fetch content from server API
    func fetchServerContent() async {
        do {
            // Fetch tracks from API
            let apiTracks = try await apiClient.getTracks()
            let convertedTracks = apiTracks.map { convertAPITrack($0) }

            // Fetch playlists from API
            let apiPlaylists = try await apiClient.getPlaylists()
            let convertedPlaylists = try await convertAPIPlaylists(apiPlaylists)

            // Merge server content with local content
            await MainActor.run {
                self.serverTracks = convertedTracks
                self.serverPlaylists = convertedPlaylists

                // Add server tracks to allTracks (avoid duplicates by ID)
                var trackSet = Set(self.allTracks.map { $0.id })
                for track in convertedTracks {
                    if !trackSet.contains(track.id) {
                        self.allTracks.append(track)
                        trackSet.insert(track.id)
                    }
                }

                // Add server playlists
                var playlistSet = Set(self.playlists.map { $0.id })
                for playlist in convertedPlaylists {
                    if !playlistSet.contains(playlist.id) {
                        self.playlists.append(playlist)
                        playlistSet.insert(playlist.id)
                    }
                }

                self.lastSyncDate = Date()
                self.cacheContent()
            }

            print("Fetched \(convertedTracks.count) tracks and \(convertedPlaylists.count) playlists from server")

        } catch {
            print("Failed to fetch server content: \(error)")
            await MainActor.run {
                self.loadingError = error.localizedDescription
            }
        }
    }

    /// Refresh content from server
    func refresh() async {
        await MainActor.run {
            isLoading = true
            loadingError = nil
        }

        await fetchServerContent()

        await MainActor.run {
            isLoading = false
        }
    }

    /// Force refresh - clears cache and fetches fresh content
    func forceRefresh() async {
        await MainActor.run {
            serverTracks.removeAll()
            serverPlaylists.removeAll()
            clearCachedContent()
        }

        await refresh()
    }

    // MARK: - API Conversion

    private func convertAPITrack(_ apiTrack: APITrack) -> AudioTrack {
        let category = AudioCategory(rawValue: apiTrack.category) ?? .instrumental
        let language = Language.allCases.first { $0.rawValue.lowercased() == apiTrack.language.lowercased() }

        let audioSourceType: AudioSourceType
        switch apiTrack.audioSourceType.lowercased() {
        case "generated": audioSourceType = .generated
        case "bundled": audioSourceType = .bundled
        case "streamed": audioSourceType = .streamed
        case "texttospeech", "tts": audioSourceType = .textToSpeech
        default: audioSourceType = .streamed
        }

        let generatorType = apiTrack.generatorType.flatMap { GeneratorType(rawValue: $0) }

        return AudioTrack(
            id: UUID(uuidString: apiTrack.id) ?? UUID(),
            title: apiTrack.title,
            artist: apiTrack.artist,
            category: category,
            language: language,
            duration: TimeInterval(apiTrack.duration),
            ageRangeMin: apiTrack.ageRangeMin,
            ageRangeMax: apiTrack.ageRangeMax,
            calmingScore: apiTrack.calmingScore,
            isPremium: apiTrack.isPremium,
            isDownloaded: cacheService.isTrackCached(apiTrack.id),
            audioSourceType: audioSourceType,
            generatorType: generatorType,
            streamURL: apiTrack.streamUrl,
            serverId: apiTrack.id,  // Store original API ID for stream URL fetching
            artworkURL: apiTrack.artworkUrl,
            isLocked: apiTrack.isLocked ?? false
        )
    }

    private func convertAPIPlaylists(_ apiPlaylists: [APIPlaylist]) async throws -> [Playlist] {
        var playlists: [Playlist] = []

        for apiPlaylist in apiPlaylists {
            // Fetch full playlist with tracks if needed
            let fullPlaylist: APIPlaylist
            if apiPlaylist.tracks != nil {
                fullPlaylist = apiPlaylist
            } else {
                fullPlaylist = try await apiClient.getPlaylist(id: apiPlaylist.id)
            }

            let category = fullPlaylist.category.flatMap { AudioCategory(rawValue: $0) }
            let tracks = (fullPlaylist.tracks ?? []).map { convertAPITrack($0) }

            let playlist = Playlist(
                id: UUID(uuidString: fullPlaylist.id) ?? UUID(),
                name: fullPlaylist.name,
                description: fullPlaylist.description,
                tracks: tracks,
                category: category,
                targetAgeMonths: fullPlaylist.targetAgeMonths,
                isSystemGenerated: fullPlaylist.isSystem
            )

            playlists.append(playlist)
        }

        return playlists
    }

    // MARK: - Content Caching

    private func loadCachedContent() {
        // Load last sync date
        if let date = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = date
        }

        // Load cached tracks
        if let data = userDefaults.data(forKey: cachedTracksKey),
           let tracks = try? JSONDecoder().decode([AudioTrack].self, from: data) {
            serverTracks = tracks
        }

        // Load cached playlists
        if let data = userDefaults.data(forKey: cachedPlaylistsKey),
           let playlists = try? JSONDecoder().decode([Playlist].self, from: data) {
            serverPlaylists = playlists
        }
    }

    private func cacheContent() {
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)

        if let data = try? JSONEncoder().encode(serverTracks) {
            userDefaults.set(data, forKey: cachedTracksKey)
        }

        if let data = try? JSONEncoder().encode(serverPlaylists) {
            userDefaults.set(data, forKey: cachedPlaylistsKey)
        }
    }

    private func clearCachedContent() {
        userDefaults.removeObject(forKey: cachedTracksKey)
        userDefaults.removeObject(forKey: cachedPlaylistsKey)
        userDefaults.removeObject(forKey: lastSyncKey)
    }

    // MARK: - Filtering with Server Support

    /// Get tracks for a category (prefers server content)
    func getTracksFromServer(category: String? = nil, language: String? = nil, ageMonths: Int? = nil) async -> [AudioTrack] {
        do {
            let apiTracks = try await apiClient.getTracks(category: category, language: language, ageMonths: ageMonths)
            return apiTracks.map { convertAPITrack($0) }
        } catch {
            print("Failed to fetch tracks from server: \(error)")
            // Fallback to local filtering
            return filterLocalTracks(category: category, language: language, ageMonths: ageMonths)
        }
    }

    private func filterLocalTracks(category: String?, language: String?, ageMonths: Int?) -> [AudioTrack] {
        var filtered = allTracks

        if let category = category, let cat = AudioCategory(rawValue: category) {
            filtered = filtered.filter { $0.category == cat }
        }

        if let language = language, let lang = Language.allCases.first(where: { $0.rawValue.lowercased() == language.lowercased() }) {
            filtered = filtered.filter { $0.language == lang }
        }

        if let age = ageMonths {
            filtered = filtered.filter { $0.ageRangeMin <= age && $0.ageRangeMax >= age }
        }

        return filtered
    }

    /// Get recommendations from server
    func getRecommendations(babyId: String, mood: String? = nil) async -> [AudioTrack] {
        do {
            let response = try await apiClient.getRecommendations(babyId: babyId, mood: mood)
            return response.recommendedTracks.map { convertAPITrack($0) }
        } catch {
            print("Failed to fetch recommendations: \(error)")
            // Fallback to local high-calming-score tracks
            return allTracks
                .filter { $0.calmingScore >= 0.85 }
                .sorted { $0.calmingScore > $1.calmingScore }
                .prefix(10)
                .map { $0 }
        }
    }

    /// Get emergency tracks from server
    func getEmergencyTracks(babyId: String) async -> [AudioTrack] {
        do {
            let response = try await apiClient.getRecommendations(babyId: babyId, mood: "crying")
            return response.emergencyTracks.map { convertAPITrack($0) }
        } catch {
            print("Failed to fetch emergency tracks: \(error)")
            // Fallback to womb/heartbeat sounds
            return allTracks.filter {
                $0.generatorType == .womb || $0.generatorType == .heartbeat || $0.generatorType == .shushing
            }
        }
    }

    // MARK: - Load Bundled Tracks from JSON Metadata

    /// Load all bundled tracks from the tracks.json metadata file
    /// NOTE: In streaming-first architecture, most tracks are NOT bundled.
    /// This loads metadata for ALL tracks, marking them as streamed if not in bundle.
    private func loadBundledTracksFromMetadata() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        guard let url = Bundle.main.url(forResource: "tracks", withExtension: "json", subdirectory: "Audio"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trackArray = json["tracks"] as? [[String: Any]] else {
            print("[ContentLibrary] ⚠️ Could not load tracks.json metadata")
            return tracks
        }

        print("[ContentLibrary] 📦 Loading tracks from tracks.json (\(trackArray.count) total)")

        for trackData in trackArray {
            guard let id = trackData["id"] as? String,
                  let title = trackData["title"] as? String,
                  let categoryStr = trackData["category"] as? String,
                  let filename = trackData["filename"] as? String else {
                continue
            }

            let artist = trackData["artist"] as? String ?? "Various Artists"
            // Note: subcategory and tags are parsed from JSON but not currently used in AudioTrack model
            // Keeping the parsing here for future extensibility
            _ = trackData["subcategory"] as? String ?? "misc"
            let duration = trackData["duration"] as? Double ?? 180.0
            let calmScore = trackData["calmScore"] as? Double ?? 0.8
            _ = trackData["tags"] as? [String] ?? []

            // Map category string to AudioCategory
            let category = mapStringToAudioCategory(categoryStr)

            // Determine language from category (english/russian fairy tales)
            let language: Language? = {
                switch categoryStr.lowercased() {
                case "english", "fairytales_en": return .english
                case "russian", "fairytales_ru": return .russian
                case "children", "lullabies": return .english  // Default for children's content
                default: return nil  // Instrumental/nature/etc. have no language
                }
            }()

            // Extract file info from filename path
            let pathComponents = filename.split(separator: "/")
            let fileNameWithExt = String(pathComponents.last ?? "")
            let fileNameParts = fileNameWithExt.split(separator: ".")
            let fileName = String(fileNameParts.first ?? "")
            let fileExtension = fileNameParts.count > 1 ? String(fileNameParts.last!) : "mp3"
            let subdirectory = pathComponents.count > 1 ? "Audio/" + pathComponents.dropLast().joined(separator: "/") : "Audio"

            // STREAMING-FIRST: Check if file exists in bundle, otherwise mark as streamed
            let isBundled = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory) != nil

            // Construct stream URL for non-bundled tracks
            let streamURL: String?
            if !isBundled {
                // URL encode the filename for R2 storage
                // R2 bucket structure: audio/{category}/{filename}
                let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
                streamURL = "\(APIClient.r2PublicURL)/audio/\(encodedFilename)"
            } else {
                streamURL = nil
            }

            let track = AudioTrack(
                id: UUID(uuidString: id) ?? UUID(),
                title: title,
                artist: artist,
                category: category,
                language: language,
                duration: duration > 0 ? duration : 180,
                ageRangeMin: 0,
                ageRangeMax: 36,
                calmingScore: calmScore,
                audioSourceType: isBundled ? .bundled : .streamed,
                fileName: isBundled ? fileName : nil,
                fileExtension: isBundled ? fileExtension : nil,
                streamURL: streamURL
            )
            tracks.append(track)
        }

        let bundledCount = tracks.filter { $0.audioSourceType == .bundled }.count
        let streamedCount = tracks.filter { $0.audioSourceType == .streamed }.count
        print("[ContentLibrary] ✅ Loaded \(tracks.count) tracks from metadata:")
        print("  - 📦 Bundled: \(bundledCount)")
        print("  - 🌐 Streamed: \(streamedCount)")
        print("  - By category: Classical=\(tracks.filter { $0.category == .classicalMusic }.count), Fairy Tales=\(tracks.filter { $0.category == .fairyTales }.count), Children=\(tracks.filter { $0.category == .childrenSongs }.count), Podcasts=\(tracks.filter { $0.category == .podcasts }.count)")

        return tracks
    }

    /// Map category string from JSON to AudioCategory enum
    /// NOTE: White noise category was REMOVED - user feedback says it's scary for babies!
    private func mapStringToAudioCategory(_ str: String) -> AudioCategory {
        switch str.lowercased() {
        // Nature Sounds
        case "nature", "nature_sounds": return .natureSounds

        // Classical Music
        case "classical", "classical_music": return .classicalMusic

        // Lullabies (dedicated category)
        case "lullabies": return .lullabies

        // Children's Songs
        case "children", "children_songs", "childrensongs": return .childrenSongs

        // Ambient (dedicated category)
        case "ambient": return .ambient

        // Instrumental & Acoustic
        case "acoustic": return .instrumental
        case "instrumental": return .instrumental

        // Podcasts & Stories
        case "podcasts", "podcast": return .podcasts
        case "children_stories", "childrenstories": return .podcasts

        // Fairy Tales (Modern & Legacy)
        case "fairytales_en": return .fairyTales
        case "fairytales_ru": return .fairyTales
        case "fairytales", "fairy_tales": return .fairyTales
        case "russian_fairy_tales", "russianfairytales": return .fairyTales
        case "russian_fairy_tales_english": return .fairyTales
        // Legacy: "english" and "russian" categories are FAIRY TALES
        case "english": return .fairyTales
        case "russian": return .fairyTales

        // ⚠️ WHITE NOISE BANNED - Map old whitenoise to ambient instead
        case "whitenoise", "white_noise": return .ambient

        // Fallback to instrumental for unknown categories
        default:
            print("[ContentLibrary] ⚠️ Unknown category '\(str)' - defaulting to instrumental")
            return .instrumental
        }
    }

    // MARK: - Load Podcasts from Metadata Files

    /// Load all podcast tracks from the podcast metadata JSON files
    private func loadPodcastsFromMetadata() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // List of podcast metadata files to load
        let podcastFiles = [
            "podcast_metadata",
            "russian_podcast_metadata",
            "english_podcast_metadata"
        ]

        for fileName in podcastFiles {
            let loadedTracks = loadPodcastMetadataFile(fileName)
            tracks.append(contentsOf: loadedTracks)
        }

        print("Loaded \(tracks.count) podcast tracks from metadata files")
        return tracks
    }

    /// Load podcasts from a specific metadata file
    private func loadPodcastMetadataFile(_ fileName: String) -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Audio"),
              let data = try? Data(contentsOf: url),
              let podcastArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("Could not load \(fileName).json metadata")
            return tracks
        }

        for podcastData in podcastArray {
            guard let id = podcastData["id"] as? String,
                  let title = podcastData["title"] as? String,
                  let filename = podcastData["filename"] as? String else {
                continue
            }

            let artist = podcastData["artist"] as? String ?? "Podcast"
            let categoryStr = podcastData["category"] as? String ?? "podcasts"
            let languageStr = podcastData["language"] as? String ?? "en"
            let durationStr = podcastData["duration"] as? String
            let sizeBytes = podcastData["size_bytes"] as? Int ?? 0

            // Parse duration from string format "HH:MM:SS" or "MM:SS"
            let duration = parseDuration(durationStr) ?? estimateDurationFromSize(sizeBytes)

            // Map language code to Language enum
            let language = mapLanguageCode(languageStr)

            // Map category string to AudioCategory
            let category = mapStringToAudioCategory(categoryStr)

            // Extract file info from filename path
            let pathComponents = filename.split(separator: "/")
            let fileNameWithExt = String(pathComponents.last ?? "")
            let fileNameParts = fileNameWithExt.split(separator: ".")
            let fileNameOnly = String(fileNameParts.first ?? "")
            let fileExtension = fileNameParts.count > 1 ? String(fileNameParts.last!) : "mp3"

            // Build the subdirectory path for bundle lookup
            let subdirectory = "Audio/" + pathComponents.dropLast().joined(separator: "/")

            // Check if the file exists in the bundle or should be streamed
            let isBundled = Bundle.main.url(forResource: fileNameOnly, withExtension: fileExtension, subdirectory: subdirectory) != nil

            // Construct full stream URL from R2 storage for non-bundled podcasts
            let fullStreamURL: String?
            if isBundled {
                fullStreamURL = nil
            } else {
                // URL encode the filename path for special characters
                let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
                fullStreamURL = "\(APIClient.r2PublicURL)/\(encodedFilename)"
            }

            // Create the track - podcasts are typically streamed but may be bundled
            let track = AudioTrack(
                id: UUID(uuidString: id) ?? UUID(),
                title: title,
                artist: artist,
                category: category,
                language: language,
                duration: duration > 0 ? duration : 300, // Default 5 min if unknown
                ageRangeMin: category == .fairyTales ? 12 : 0,
                ageRangeMax: 36,
                calmingScore: 0.75, // Default calming score for podcasts
                audioSourceType: isBundled ? .bundled : .streamed,
                fileName: isBundled ? fileNameOnly : nil,
                fileExtension: isBundled ? fileExtension : nil,
                streamURL: fullStreamURL
            )
            tracks.append(track)
        }

        return tracks
    }

    /// Parse duration from string format "HH:MM:SS" or "MM:SS"
    private func parseDuration(_ durationStr: String?) -> TimeInterval? {
        guard let str = durationStr else { return nil }

        let components = str.split(separator: ":").compactMap { Int($0) }

        switch components.count {
        case 3: // HH:MM:SS
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        case 2: // MM:SS
            return TimeInterval(components[0] * 60 + components[1])
        case 1: // Just seconds
            return TimeInterval(components[0])
        default:
            return nil
        }
    }

    /// Estimate duration from file size (assuming ~128kbps MP3)
    private func estimateDurationFromSize(_ sizeBytes: Int) -> TimeInterval {
        // 128 kbps = 16 KB/s
        let bytesPerSecond = 16 * 1024
        return TimeInterval(sizeBytes) / TimeInterval(bytesPerSecond)
    }

    /// Map language code to Language enum
    private func mapLanguageCode(_ code: String) -> Language? {
        switch code.lowercased() {
        case "en", "english": return .english
        case "ru", "russian": return .russian
        case "es", "spanish": return .spanish
        case "fr", "french": return .french
        case "de", "german": return .german
        case "it", "italian": return .italian
        case "pt", "portuguese": return .portuguese
        case "zh", "mandarin", "chinese": return .mandarin
        case "ja", "japanese": return .japanese
        case "ar", "arabic": return .arabic
        default: return nil
        }
    }

    // MARK: - Generated Audio Content

    private func generateAllTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // First, load all bundled tracks from metadata JSON
        let bundledTracks = loadBundledTracksFromMetadata()
        tracks.append(contentsOf: bundledTracks)

        // MARK: Load Podcasts from metadata files
        let podcastTracks = loadPodcastsFromMetadata()
        tracks.append(contentsOf: podcastTracks)

        // MARK: Baby-Soothing Sounds (GENTLE ONLY - NO white noise, NO mechanical sounds!)
        // ⚠️ WHITE NOISE REMOVED: User feedback says it's SCARY for babies!
        let soothingGenerators: [(GeneratorType, String)] = [
            (.womb, "Womb Sounds"),
            (.heartbeat, "Mother's Heartbeat"),
            (.shushing, "Gentle Shushing")
        ]

        for (generator, title) in soothingGenerators {
            tracks.append(AudioTrack(
                title: title,
                artist: "Lulla",
                category: generator.category,
                duration: 3600, // 1 hour
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

        // MARK: Nature Sounds (ONLY gentle, baby-safe sounds - NO rain/thunder/wind!)
        let natureSounds: [(GeneratorType, String)] = [
            // ❌ REMOVED: .rain, .rainOnRoof, .wind, .thunderstorm, .thunderRumble (scary for babies!)
            (.ocean, "Ocean Waves"),
            (.river, "Babbling Brook"),
            (.birds, "Morning Birds"),
            (.crickets, "Summer Crickets"),
            (.fireplace, "Crackling Fire"),
            (.forest, "Forest Ambience"),
            (.waterfall, "Peaceful Waterfall"),
            (.campfire, "Campfire Night")
        ]

        for (generator, title) in natureSounds {
            tracks.append(AudioTrack(
                title: title,
                artist: "Nature Sounds",
                category: .natureSounds,
                duration: 3600,
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

        // MARK: STREAMING-FIRST ARCHITECTURE
        // All nature sounds, music, fairy tales, etc. are now streamed from R2
        // Only the default emergency track (Piano Moment) is bundled
        // Real audio files are fetched via API and cached on-demand
        // ⚠️ NO white noise content - removed based on user feedback!

        // MARK: Gentle Ambient Sounds (for older babies - soothing only)
        // REMOVED: trainRide, airplaneCabin, cityAmbience - too harsh/stimulating
        let gentleAmbient: [(GeneratorType, String)] = [
            (.aquarium, "Aquarium Bubbles")  // Only keeping the soothing aquarium sound
        ]

        for (generator, title) in gentleAmbient {
            tracks.append(AudioTrack(
                title: title,
                artist: "Lulla",
                category: generator.category,
                duration: 3600,
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

        // MARK: Default Emergency Track (ONLY bundled audio file)
        // Piano Moment - used as fallback when offline and no cached tracks
        if Bundle.main.url(forResource: "bensound_pianomoment", withExtension: "mp3", subdirectory: "Audio/default") != nil {
            tracks.append(AudioTrack(
                title: "Piano Moment",
                artist: "Lulla",
                category: .classicalMusic,
                duration: 180,
                ageRangeMin: 0,
                ageRangeMax: 36,
                calmingScore: 0.92,
                audioSourceType: .bundled,
                fileName: "bensound_pianomoment",
                fileExtension: "mp3"
            ))
        }

        // NOTE: All other content (classical, fairy tales, children's songs, lullabies)
        // is now streamed from R2 via the API. See fetchServerContent() for loading.
        // This reduces app size from 3GB to <50MB.

        return tracks
    }

    // MARK: - Streaming Content Note
    // All Russian, English fairy tales, classical music, lullabies, etc.
    // are now streamed from R2 via fetchServerContent().
    // This reduces app size from 3GB to <50MB.


    // MARK: - Default Playlists

    private func generateDefaultPlaylists() -> [Playlist] {
        var playlists: [Playlist] = []

        // Newborn Essentials (0-3 months)
        let newbornTracks = allTracks.filter {
            $0.ageRangeMin == 0 && [.ambient, .natureSounds, .lullabies].contains($0.category)
        }
        playlists.append(Playlist(
            name: "Newborn Essentials",
            description: "Womb-like sounds perfect for newborns",
            tracks: Array(newbornTracks.prefix(10)),
            targetAgeMonths: 1,
            isSystemGenerated: true,
            artworkName: "newborn_playlist"
        ))

        // Sleep Time Favorites
        let sleepTracks = allTracks.filter {
            $0.calmingScore >= 0.85 && [.ambient, .natureSounds, .classicalMusic, .lullabies].contains($0.category)
        }
        playlists.append(Playlist(
            name: "Sleep Time Favorites",
            description: "The most soothing sounds for peaceful sleep",
            tracks: Array(sleepTracks.prefix(15)),
            isSystemGenerated: true,
            artworkName: "sleep_playlist"
        ))

        // Ambient Sounds Collection (womb, heartbeat, gentle sounds)
        let ambientTracks = allTracks.filter { $0.category == .ambient }
        playlists.append(Playlist(
            name: "Soothing Sounds",
            description: "Gentle womb sounds and calming ambient",
            tracks: ambientTracks,
            category: .ambient,
            isSystemGenerated: true,
            artworkName: "ambient_playlist"
        ))

        // Nature Sounds
        let natureTracks = allTracks.filter { $0.category == .natureSounds }
        playlists.append(Playlist(
            name: "Nature Sounds",
            description: "Peaceful sounds from nature",
            tracks: natureTracks,
            category: .natureSounds,
            isSystemGenerated: true,
            artworkName: "nature_playlist"
        ))

        // Classical for Babies
        let classicalTracks = allTracks.filter { $0.category == .classicalMusic }
        playlists.append(Playlist(
            name: "Classical for Babies",
            description: "Timeless classical pieces for development",
            tracks: classicalTracks,
            category: .classicalMusic,
            isSystemGenerated: true,
            artworkName: "classical_playlist"
        ))

        // Story Time (by language)
        for language in Language.allCases.prefix(5) {
            let languageTracks = allTracks.filter {
                $0.category == .fairyTales && $0.language == language
            }
            if !languageTracks.isEmpty {
                playlists.append(Playlist(
                    name: "Stories in \(language.rawValue)",
                    description: "\(language.flag) Fairy tales in \(language.rawValue)",
                    tracks: languageTracks,
                    category: .fairyTales,
                    isSystemGenerated: true,
                    artworkName: "stories_playlist"
                ))
            }
        }

        // Children's Songs
        let songTracks = allTracks.filter { $0.category == .childrenSongs }
        playlists.append(Playlist(
            name: "Lullabies & Songs",
            description: "Gentle songs for little ones",
            tracks: songTracks,
            category: .childrenSongs,
            isSystemGenerated: true,
            artworkName: "songs_playlist"
        ))

        // Toddler Sleep Sounds (12-36 months)
        let toddlerTracks = allTracks.filter {
            $0.ageRangeMin >= 9 && $0.ageRangeMax >= 24 && $0.calmingScore >= 0.75
        }.sorted { $0.calmingScore > $1.calmingScore }
        playlists.append(Playlist(
            name: "Toddler Sleep Sounds",
            description: "Age-appropriate sounds for older babies and toddlers",
            tracks: Array(toddlerTracks.prefix(15)),
            targetAgeMonths: 18,
            isSystemGenerated: true,
            artworkName: "toddler_playlist"
        ))

        // Cozy Ambient Collection (fire sounds for relaxation)
        let cozyAmbientTypes = allTracks.filter {
            [GeneratorType.fireplace, .campfire].contains($0.generatorType ?? .lullaby)
        }
        if !cozyAmbientTypes.isEmpty {
            playlists.append(Playlist(
                name: "Cozy Ambient",
                description: "Warm, gentle fire sounds for relaxation",
                tracks: cozyAmbientTypes,
                category: .natureSounds,
                isSystemGenerated: true,
                artworkName: "cozy_playlist"
            ))
        }

        // REMOVED: Travel Sounds playlist - harsh sounds like train, airplane, car engine
        // were removed as they don't fit the soothing baby calming purpose

        // Cozy Night Sounds (NO rain/thunder - only gentle fire sounds)
        let cozyNightTracks = allTracks.filter {
            [GeneratorType.fireplace, .campfire].contains($0.generatorType ?? .lullaby)
        }
        playlists.append(Playlist(
            name: "Cozy Night",
            description: "Warm, comforting sounds for bedtime",
            tracks: cozyNightTracks,
            category: .natureSounds,
            isSystemGenerated: true,
            artworkName: "cozy_playlist"
        ))

        // Russian Content Collection
        let russianTracks = allTracks.filter { $0.language == .russian }
        if !russianTracks.isEmpty {
            playlists.append(Playlist(
                name: "Русский контент",
                description: "Колыбельные и песни на русском языке",
                tracks: russianTracks,
                isSystemGenerated: true,
                artworkName: "russian_playlist"
            ))
        }

        // Russian Lullabies
        let russianLullabies = allTracks.filter {
            $0.language == .russian && $0.category == .childrenSongs && $0.calmingScore >= 0.85
        }
        if !russianLullabies.isEmpty {
            playlists.append(Playlist(
                name: "Русские колыбельные",
                description: "Нежные колыбельные для спокойного сна",
                tracks: russianLullabies,
                category: .childrenSongs,
                isSystemGenerated: true,
                artworkName: "russian_lullabies"
            ))
        }

        // Russian Fairy Tales
        let russianFairyTales = allTracks.filter {
            $0.language == .russian && $0.category == .fairyTales
        }
        if !russianFairyTales.isEmpty {
            playlists.append(Playlist(
                name: "Русские сказки",
                description: "Любимые народные сказки для малышей",
                tracks: russianFairyTales,
                category: .fairyTales,
                isSystemGenerated: true,
                artworkName: "russian_stories"
            ))
        }

        // MARK: Podcasts Collection
        let podcastTracks = allTracks.filter { $0.category == .podcasts }
        if !podcastTracks.isEmpty {
            playlists.append(Playlist(
                name: "Story Podcasts",
                description: "Bedtime stories and children's podcasts",
                tracks: podcastTracks,
                category: .podcasts,
                isSystemGenerated: true,
                artworkName: "podcast_playlist"
            ))
        }

        // English Podcasts
        let englishPodcasts = allTracks.filter {
            $0.category == .podcasts && $0.language == .english
        }
        if !englishPodcasts.isEmpty {
            playlists.append(Playlist(
                name: "English Story Podcasts",
                description: "Bedtime stories in English",
                tracks: englishPodcasts,
                category: .podcasts,
                isSystemGenerated: true,
                artworkName: "english_podcasts"
            ))
        }

        // Russian Podcasts (from podcast metadata - fairy tales)
        let russianPodcasts = allTracks.filter {
            ($0.category == .podcasts || $0.category == .fairyTales) && $0.language == .russian
        }
        if !russianPodcasts.isEmpty {
            playlists.append(Playlist(
                name: "Русские подкасты",
                description: "Сказки и истории на русском языке",
                tracks: russianPodcasts,
                category: .podcasts,
                isSystemGenerated: true,
                artworkName: "russian_podcasts"
            ))
        }

        return playlists
    }

    // MARK: - Content Access

    func getAllTracks() -> [AudioTrack] {
        return allTracks
    }

    func getTracks(for category: AudioCategory) -> [AudioTrack] {
        return allTracks.filter { $0.category == category }
    }

    // MARK: - Freemium Content Access

    /// Get all tracks the current user can play (respects freemium tier)
    func getPlayableTracks() -> [AudioTrack] {
        let gatekeeper = FreemiumGatekeeper.shared
        return allTracks.filter { gatekeeper.canPlayTrack($0) }
    }

    /// Get only free tracks (always-free + rotating free)
    func fetchFreeTracks() -> [AudioTrack] {
        let gatekeeper = FreemiumGatekeeper.shared
        return allTracks.filter { gatekeeper.isTrackFree($0) }
    }

    /// Get only premium/locked tracks (for upgrade prompts)
    func fetchPremiumTracks() -> [AudioTrack] {
        let gatekeeper = FreemiumGatekeeper.shared
        return allTracks.filter { !gatekeeper.isTrackFree($0) }
    }

    /// Get free tracks by category
    func getFreeTracks(for category: AudioCategory) -> [AudioTrack] {
        let gatekeeper = FreemiumGatekeeper.shared
        return allTracks.filter { $0.category == category && gatekeeper.isTrackFree($0) }
    }

    /// Get free track count by category
    func getFreeTrackCount(for category: AudioCategory) -> Int {
        return getFreeTracks(for: category).count
    }

    /// Get total free track count
    func getTotalFreeTrackCount() -> Int {
        return fetchFreeTracks().count
    }

    /// Initialize freemium track selection (call after content loads)
    func initializeFreemiumSelection() {
        let gatekeeper = FreemiumGatekeeper.shared
        if gatekeeper.shouldRotateFreeTracks() {
            gatekeeper.selectFreeTracksFrom(allTracks)
        }
    }

    /// Get next free track rotation date
    func getNextFreeTrackRotationDate() -> Date? {
        guard let lastRotation = FreemiumGatekeeper.shared.lastFreeTrackRotation else { return nil }
        return Calendar.current.date(byAdding: .day, value: 7, to: lastRotation)
    }

    func getTracks(for language: Language) -> [AudioTrack] {
        return allTracks.filter { $0.language == language }
    }

    func getTracks(forAgeMonths age: Int) -> [AudioTrack] {
        return allTracks.filter { $0.ageRangeMin <= age && $0.ageRangeMax >= age }
    }

    func getTrack(by id: UUID) -> AudioTrack? {
        return allTracks.first { $0.id == id }
    }

    /// Get track by string ID
    func getTrack(byId id: String) -> AudioTrack? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return getTrack(by: uuid)
    }

    func getPlaylist(by id: UUID) -> Playlist? {
        return playlists.first { $0.id == id }
    }

    func getPlaylists(for category: AudioCategory) -> [Playlist] {
        return playlists.filter { $0.category == category }
    }

    // MARK: - Search

    func searchTracks(query: String) -> [AudioTrack] {
        let lowercasedQuery = query.lowercased()
        return allTracks.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.artist.lowercased().contains(lowercasedQuery) ||
            $0.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }

    func searchPlaylists(query: String) -> [Playlist] {
        let lowercasedQuery = query.lowercased()
        return playlists.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - Advanced Search

    /// Search tracks by multiple criteria
    func searchTracks(
        query: String? = nil,
        category: AudioCategory? = nil,
        minCalmScore: Double? = nil,
        maxDuration: TimeInterval? = nil,
        language: Language? = nil
    ) -> [AudioTrack] {
        var results = allTracks

        if let query = query?.lowercased(), !query.isEmpty {
            results = results.filter {
                $0.title.lowercased().contains(query) ||
                $0.artist.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query)
            }
        }

        if let category = category {
            results = results.filter { $0.category == category }
        }

        if let minCalmScore = minCalmScore {
            results = results.filter { $0.calmingScore >= minCalmScore }
        }

        if let maxDuration = maxDuration {
            results = results.filter { $0.duration <= maxDuration }
        }

        if let language = language {
            results = results.filter { $0.language == language }
        }

        return results.sorted { $0.calmingScore > $1.calmingScore }
    }

    /// Get top calming tracks
    func getTopCalmingTracks(limit: Int = 20) -> [AudioTrack] {
        return allTracks
            .sorted { $0.calmingScore > $1.calmingScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Get tracks by subcategory (using fileName pattern matching)
    func getTracksBySubcategory(_ subcategory: String) -> [AudioTrack] {
        let lowercased = subcategory.lowercased()
        return allTracks.filter {
            $0.fileName?.lowercased().contains(lowercased) == true ||
            $0.title.lowercased().contains(lowercased)
        }
    }

    /// Get random tracks for variety
    func getRandomTracks(count: Int = 10, category: AudioCategory? = nil) -> [AudioTrack] {
        var pool = category != nil ? allTracks.filter { $0.category == category } : allTracks
        pool.shuffle()
        return Array(pool.prefix(count))
    }

    /// Get nature subcategory tracks
    func getNatureTracks(subcategory: String? = nil) -> [AudioTrack] {
        let natureTracks = allTracks.filter { $0.category == .natureSounds }

        guard let subcategory = subcategory?.lowercased() else {
            return natureTracks
        }

        return natureTracks.filter {
            $0.fileName?.lowercased().contains(subcategory) == true ||
            $0.title.lowercased().contains(subcategory)
        }
    }

    /// Get library statistics
    func getLibraryStats() -> (total: Int, byCategory: [AudioCategory: Int]) {
        var stats: [AudioCategory: Int] = [:]
        for track in allTracks {
            stats[track.category, default: 0] += 1
        }
        return (allTracks.count, stats)
    }
}

// MARK: - Favorites Manager
@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published var favoriteTracks: [UUID] = []
    @Published var favoritePlaylists: [UUID] = []

    private let userDefaults = UserDefaults.standard
    private let tracksKey = "favoriteTracks"
    private let playlistsKey = "favoritePlaylists"

    private init() {
        loadFavorites()
    }

    private func loadFavorites() {
        if let data = userDefaults.data(forKey: tracksKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            favoriteTracks = ids
        }

        if let data = userDefaults.data(forKey: playlistsKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            favoritePlaylists = ids
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteTracks) {
            userDefaults.set(data, forKey: tracksKey)
        }

        if let data = try? JSONEncoder().encode(favoritePlaylists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }

    func toggleFavorite(track: AudioTrack) {
        if favoriteTracks.contains(track.id) {
            favoriteTracks.removeAll { $0 == track.id }
        } else {
            favoriteTracks.append(track.id)
        }
        saveFavorites()
    }

    func toggleFavorite(playlist: Playlist) {
        if favoritePlaylists.contains(playlist.id) {
            favoritePlaylists.removeAll { $0 == playlist.id }
        } else {
            favoritePlaylists.append(playlist.id)
        }
        saveFavorites()
    }

    func isFavorite(track: AudioTrack) -> Bool {
        return favoriteTracks.contains(track.id)
    }

    func isFavorite(playlist: Playlist) -> Bool {
        return favoritePlaylists.contains(playlist.id)
    }

    func getFavoriteTracks() -> [AudioTrack] {
        let library = ContentLibraryService.shared
        return favoriteTracks.compactMap { library.getTrack(by: $0) }
    }

    func getFavoritePlaylists() -> [Playlist] {
        let library = ContentLibraryService.shared
        return favoritePlaylists.compactMap { library.getPlaylist(by: $0) }
    }
}
