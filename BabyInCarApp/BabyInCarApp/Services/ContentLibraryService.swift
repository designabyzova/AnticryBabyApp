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
            streamURL: apiTrack.streamUrl
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
    private func loadBundledTracksFromMetadata() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        guard let url = Bundle.main.url(forResource: "tracks", withExtension: "json", subdirectory: "Audio"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trackArray = json["tracks"] as? [[String: Any]] else {
            print("Could not load tracks.json metadata")
            return tracks
        }

        for trackData in trackArray {
            guard let id = trackData["id"] as? String,
                  let title = trackData["title"] as? String,
                  let categoryStr = trackData["category"] as? String,
                  let filename = trackData["filename"] as? String else {
                continue
            }

            let artist = trackData["artist"] as? String ?? "Various Artists"
            let subcategory = trackData["subcategory"] as? String ?? "misc"
            let duration = trackData["duration"] as? Double ?? 180.0
            let calmScore = trackData["calmScore"] as? Double ?? 0.8
            let tags = trackData["tags"] as? [String] ?? []

            // Map category string to AudioCategory
            let category = mapStringToAudioCategory(categoryStr)

            // Extract file info from filename path
            let pathComponents = filename.split(separator: "/")
            let fileNameWithExt = String(pathComponents.last ?? "")
            let fileNameParts = fileNameWithExt.split(separator: ".")
            let fileName = String(fileNameParts.first ?? "")
            let fileExtension = fileNameParts.count > 1 ? String(fileNameParts.last!) : "mp3"
            let subdirectory = pathComponents.count > 1 ? "Audio/" + pathComponents.dropLast().joined(separator: "/") : "Audio"

            // Verify file exists in bundle
            if Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory) != nil {
                let track = AudioTrack(
                    id: UUID(uuidString: id) ?? UUID(),
                    title: title,
                    artist: artist,
                    category: category,
                    duration: duration > 0 ? duration : 180,
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    calmingScore: calmScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: fileExtension
                )
                tracks.append(track)
            }
        }

        print("Loaded \(tracks.count) bundled tracks from metadata")
        return tracks
    }

    /// Map category string from JSON to AudioCategory enum
    private func mapStringToAudioCategory(_ str: String) -> AudioCategory {
        switch str.lowercased() {
        case "nature": return .natureSounds
        case "whitenoise": return .whiteNoise
        case "lullabies": return .childrenSongs
        case "classical": return .classicalMusic
        case "ambient": return .instrumental
        case "children": return .childrenSongs
        case "acoustic": return .instrumental
        case "podcasts", "podcast": return .podcasts
        case "children_stories", "childrenstories": return .podcasts
        case "russian_fairy_tales", "russianfairytales": return .fairyTales
        case "russian_fairy_tales_english": return .fairyTales
        case "fairytales", "fairy_tales": return .fairyTales
        default: return .instrumental
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

        // MARK: White Noise & Calming Sounds
        let whiteNoiseGenerators: [(GeneratorType, String)] = [
            (.whiteNoise, "Pure White Noise"),
            (.pinkNoise, "Soft Pink Noise"),
            (.brownNoise, "Deep Brown Noise"),
            (.blueNoise, "Crisp Blue Noise"),
            (.violetNoise, "Bright Violet Noise"),
            (.greyNoise, "Balanced Grey Noise"),
            (.velvetNoise, "Smooth Velvet Noise"),
            (.womb, "Womb Sounds"),
            (.heartbeat, "Mother's Heartbeat"),
            (.shushing, "Gentle Shushing"),
            (.vacuum, "Vacuum Cleaner"),
            (.hairDryer, "Hair Dryer"),
            (.fan, "Electric Fan"),
            (.washingMachine, "Washing Machine"),
            (.carEngine, "Car Engine Hum")
        ]

        for (generator, title) in whiteNoiseGenerators {
            tracks.append(AudioTrack(
                title: title,
                artist: "Baby in Car",
                category: generator.category,
                duration: 3600, // 1 hour
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

        // MARK: Nature Sounds
        let natureSounds: [(GeneratorType, String)] = [
            (.rain, "Gentle Rain"),
            (.rainOnRoof, "Cozy Rain on Roof"),
            (.ocean, "Ocean Waves"),
            (.river, "Babbling Brook"),
            (.wind, "Soft Breeze"),
            (.thunderstorm, "Distant Thunder"),
            (.thunderRumble, "Rolling Thunder"),
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

        // MARK: Bundled Real Nature Sounds (downloaded royalty-free)
        let bundledNature: [(String, String, String, Int, Double)] = [
            // (title, fileName, extension, duration_seconds, calmingScore)
            ("Ambient Nature", "ambient_nature", "mp3", 600, 0.90),
            ("Rain Ambience", "rain_ambient", "mp3", 300, 0.92),
            ("Wind in Trees", "wind_trees", "mp3", 280, 0.88),
            ("Ocean Waves (Real)", "ocean_waves", "mp3", 60, 0.91),
            ("Wind Sounds", "wind", "mp3", 70, 0.85),
            ("Gentle Rain", "rain_gentle", "mp3", 120, 0.94),
            ("Rain Sounds", "rain_sounds", "mp3", 120, 0.93),
            ("SoundBible Ocean Waves", "sb_ocean_waves", "mp3", 60, 0.90),
            ("SoundBible Rain", "sb_rain2", "mp3", 60, 0.91),
            ("Forest Stream", "sb_stream", "mp3", 60, 0.89),
            ("Distant Thunderstorm", "sb_thunderstorm", "mp3", 60, 0.85),
            ("Gentle Wind", "sb_wind", "mp3", 60, 0.86)
        ]

        for (title, fileName, ext, duration, calmingScore) in bundledNature {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/nature") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Nature Collection",
                    category: .natureSounds,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // MARK: Bundled Real White Noise / Household Sounds (from whitenoise folder)
        let bundledWhiteNoise: [(String, String, String, Int, Double)] = [
            // (title, fileName, extension, duration_seconds, calmingScore)
            ("Pure White Noise (Real)", "white_noise", "mp3", 600, 0.95),
            ("Mother's Heartbeat (Real)", "heartbeat", "mp3", 120, 0.96),
            ("Hair Dryer Sound", "hair_dryer", "mp3", 60, 0.88),
            ("Vacuum Cleaner Sound", "vacuum_cleaner", "mp3", 60, 0.85)
        ]

        for (title, fileName, ext, duration, calmingScore) in bundledWhiteNoise {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/whitenoise") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "White Noise Collection",
                    category: .whiteNoise,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // MARK: Toddler-Focused Travel & Ambient Sounds (12-36 months)
        let toddlerSounds: [(GeneratorType, String)] = [
            (.trainRide, "Train Journey"),
            (.airplaneCabin, "Airplane Cabin"),
            (.cityAmbience, "City Night Sounds"),
            (.aquarium, "Aquarium Bubbles")
        ]

        for (generator, title) in toddlerSounds {
            tracks.append(AudioTrack(
                title: title,
                artist: "Toddler Sounds",
                category: generator.category,
                duration: 3600,
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

        // MARK: Instrumental / Music Box - Use REAL bundled audio, not synthetic generators
        // Bundled instrumental files from Audio/lullabies folder
        let bundledInstrumental: [(String, String, String, Int, Double)] = [
            // Bells collection (15 WAV files)
            ("Soft Bells 1", "bells_001", "wav", 120, 0.88),
            ("Soft Bells 2", "bells_002", "wav", 120, 0.88),
            ("Soft Bells 3", "bells_003", "wav", 120, 0.87),
            ("Soft Bells 4", "bells_004", "wav", 120, 0.86),
            ("Soft Bells 5", "bells_005", "wav", 120, 0.85),
            // Harp collection (15 WAV files)
            ("Gentle Harp 1", "harp_001", "wav", 120, 0.92),
            ("Gentle Harp 2", "harp_002", "wav", 120, 0.91),
            ("Gentle Harp 3", "harp_003", "wav", 120, 0.90),
            ("Gentle Harp 4", "harp_004", "wav", 120, 0.89),
            ("Gentle Harp 5", "harp_005", "wav", 120, 0.88),
            // Soft Guitar collection (15 WAV files)
            ("Acoustic Lullaby 1", "soft_guitar_001", "wav", 120, 0.85),
            ("Acoustic Lullaby 2", "soft_guitar_002", "wav", 120, 0.84),
            ("Acoustic Lullaby 3", "soft_guitar_003", "wav", 120, 0.83),
            ("Acoustic Lullaby 4", "soft_guitar_004", "wav", 120, 0.82),
            ("Acoustic Lullaby 5", "soft_guitar_005", "wav", 120, 0.81),
            // Dreamy Arp collection (15 WAV files)
            ("Dreamy Arp 1", "dreamy_arp_001", "wav", 120, 0.87),
            ("Dreamy Arp 2", "dreamy_arp_002", "wav", 120, 0.86),
            ("Dreamy Arp 3", "dreamy_arp_003", "wav", 120, 0.85),
            ("Dreamy Arp 4", "dreamy_arp_004", "wav", 120, 0.84),
            ("Dreamy Arp 5", "dreamy_arp_005", "wav", 120, 0.83)
        ]

        for (title, fileName, ext, duration, calmingScore) in bundledInstrumental {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/lullabies") != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Instrumental Collection",
                    category: .instrumental,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }
        // NOTE: Do NOT use synthetic generators (.lullaby, .musicBox, etc.) for instrumental.
        // They produce simple sine wave beeps, not real music.

        // MARK: Classical Music (Using public domain compositions)
        let classicalTracks = generateClassicalMusicTracks()
        tracks.append(contentsOf: classicalTracks)

        // MARK: Fairy Tales (Text-to-Speech based)
        let fairyTales = generateFairyTaleTracks()
        tracks.append(contentsOf: fairyTales)

        // MARK: Children's Songs (Simple generated melodies)
        let childrenSongs = generateChildrenSongTracks()
        tracks.append(contentsOf: childrenSongs)

        // MARK: Russian Children's Content
        let russianTracks = generateRussianContentTracks()
        tracks.append(contentsOf: russianTracks)

        return tracks
    }

    // MARK: - Russian Content

    private func generateRussianContentTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // MARK: Load Russian Fairytales from bundled files (fairytales/ru/)
        // These are REAL audio files that exist in the bundle - Russian folk tales
        let russianFairytales: [(String, String, String, Int, ClosedRange<Int>)] = [
            // (title, fileName, extension, duration_estimate, ageRange)
            ("Алёнушка", "ru_afanasyev_alyonushka", "mp3", 130, 12...36),
            ("Баба Яга", "ru_afanasyev_baba_yaga", "mp3", 68, 18...36),
            ("Баба Яга (часть 1)", "ru_afanasyev_baba_yaga_1", "mp3", 280, 18...36),
            ("Баба Яга (часть 2)", "ru_afanasyev_baba_yaga_2", "mp3", 280, 18...36),
            ("Демьянова уха", "ru_afanasyev_demyan", "mp3", 220, 18...36),
            ("Финист - Ясный Сокол", "ru_afanasyev_finist", "mp3", 310, 18...36),
            ("Фролка-сидень", "ru_afanasyev_frolka", "mp3", 350, 18...36),
            ("Головиха", "ru_afanasyev_goloviha", "mp3", 68, 12...36),
            ("Хаврошечка", "ru_afanasyev_havroshechka", "mp3", 320, 12...36),
            ("Иван-дурак", "ru_afanasyev_ivan_durak", "mp3", 360, 18...36),
            ("Иван и Марфа", "ru_afanasyev_ivan_marfa", "mp3", 760, 18...36),
            ("Иван Попялов", "ru_afanasyev_ivan_popyalov", "mp3", 480, 18...36),
            ("Кочет и Курица", "ru_afanasyev_kochet_kuritsa", "mp3", 88, 6...24),
            ("Кощей Бессмертный", "ru_afanasyev_koschei", "mp3", 88, 18...36),
            ("Кот, Петух и Лиса", "ru_afanasyev_kot_petuh_lisa", "mp3", 160, 12...36),
            ("Коза-дереза", "ru_afanasyev_koza", "mp3", 270, 12...36),
            ("Сестрица Алёнушка и братец Иванушка", "ru_afanasyev_kozlenochek", "mp3", 420, 12...36),
            ("Летучий корабль", "ru_afanasyev_letuchiy_korabl", "mp3", 360, 18...36),
            ("Лутонюшка", "ru_afanasyev_lutonyushka", "mp3", 180, 12...36),
            ("Марко Богатый", "ru_afanasyev_marko_bogatiy", "mp3", 230, 18...36),
            ("Марья Моревна", "ru_afanasyev_marya_morevna", "mp3", 147, 18...36),
            ("Мена", "ru_afanasyev_mena", "mp3", 340, 12...36),
            ("Мизгирь", "ru_afanasyev_mizgir", "mp3", 147, 18...36),
            ("Молодец и река", "ru_afanasyev_molodets", "mp3", 1450, 18...36),
            ("Мужик и медведь", "ru_afanasyev_muzhik_medved", "mp3", 205, 12...36),
            ("Набитый дурак", "ru_afanasyev_nabitiy_durak", "mp3", 130, 12...36),
            ("Не любо - не слушай", "ru_afanasyev_ne_lyubo", "mp3", 320, 18...36),
            ("Петушок - золотой гребешок", "ru_afanasyev_petushok", "mp3", 340, 6...24),
            ("Семь Симеонов", "ru_afanasyev_sem_simeonov", "mp3", 345, 18...36),
            ("Сивка-Бурка", "ru_afanasyev_sivka_burka", "mp3", 860, 18...36),
            ("Свинка", "ru_afanasyev_svinka", "mp3", 810, 12...36),
            ("Царевна-лягушка", "ru_afanasyev_tsarevna_lyagushka", "mp3", 440, 12...36),
            ("Царевна-лягушка (версия 2)", "ru_afanasyev_tsarevna_lyagushka_v2", "mp3", 320, 12...36),
            ("Подземное царство", "ru_afanasyev_tsarevna_underground", "mp3", 280, 18...36),
            ("Василиса Прекрасная", "ru_afanasyev_vasilisa", "mp3", 158, 18...36),
            ("Волк и семеро козлят", "ru_afanasyev_volk", "mp3", 68, 6...24),
            ("Волк и Коза", "ru_afanasyev_volk_koza", "mp3", 310, 6...24),
            ("Жар-птица", "ru_afanasyev_zhar_ptitsa", "mp3", 180, 12...36)
        ]

        for (title, fileName, ext, duration, ageRange) in russianFairytales {
            // Check if file exists in bundle - these are REAL audio files
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/fairytales/ru") != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Русские народные сказки",
                    category: .fairyTales,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    calmingScore: 0.75,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // NOTE: Russian lullabies and children's songs (like "Спи, малыш", "Баю-баюшки-баю")
        // are NOT bundled locally - the Audio/russian folder does not exist.
        // These should be fetched from the API via fetchServerContent().
        //
        // DO NOT create synthetic fallbacks that produce beeps instead of real music.
        // The generated lullaby/musicBox sounds are just simple sine waves, not real songs.

        return tracks
    }

    private func generateClassicalMusicTracks() -> [AudioTrack] {
        // Real bundled audio files - royalty-free classical music from Public Domain
        var tracks: [AudioTrack] = []

        // Piano pieces (Public Domain recordings from archive.org, Musopen)
        let bundledPiano: [(String, String, String, String, Int, Double)] = [
            // (title, artist/composer, fileName, extension, duration_seconds, calmingScore)
            ("Moonlight Sonata", "Ludwig van Beethoven", "moonlight_sonata", "mp3", 360, 0.92),
            ("Clair de Lune", "Claude Debussy", "clair_de_lune", "mp3", 300, 0.95),
            ("Nocturne Op.9 No.2", "Frédéric Chopin", "chopin_nocturne_op9_no2", "mp3", 270, 0.93),
            ("Gymnopédie No.1", "Erik Satie", "gymnopedie_no1", "mp3", 180, 0.90),
            ("Three Gymnopédies", "Erik Satie", "satie_three_gymnopedies", "mp3", 600, 0.88),
            ("Calm Piano", "Relaxing Music", "calm_piano", "mp3", 315, 0.88),
            ("Soft Strings", "Classical Collection", "soft_strings", "mp3", 280, 0.86),
            ("Dreamy Piano", "Sleep Sounds", "dreamy_piano", "mp3", 240, 0.87),
            ("Piano Peaceful", "Ambient Music", "piano_peaceful", "mp3", 220, 0.85),
            ("Ambient Calm", "Classical Collection", "ambient_calm", "mp3", 180, 0.84)
        ]

        for (title, artist, fileName, ext, duration, calmingScore) in bundledPiano {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/classical") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .classicalMusic,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 60,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // Violin & Orchestral pieces (Public Domain)
        let bundledViolin: [(String, String, String, String, Int, Double)] = [
            ("Air on the G String", "J.S. Bach", "bach_air_on_g_string", "mp3", 300, 0.94),
            ("Air on G String (Violin/Cello)", "J.S. Bach", "bach_air_violin_cello", "mp3", 300, 0.92),
            ("Canon in D", "Johann Pachelbel", "pachelbel_canon", "mp3", 300, 0.90),
            ("Canon in D (Original)", "Johann Pachelbel", "canon_in_d", "mp3", 300, 0.89),
            ("Romantic Violin", "Classical Collection", "romantic_violin", "mp3", 3600, 0.88),
            ("Gymnopédie", "Erik Satie", "gymnopedie", "mp3", 180, 0.87)
        ]

        for (title, artist, fileName, ext, duration, calmingScore) in bundledViolin {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/classical") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .classicalMusic,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 55,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // Lullabies (Public Domain)
        let bundledLullabies: [(String, String, String, String, Int, Double)] = [
            ("Brahms' Lullaby", "Johannes Brahms", "brahms_lullaby", "mp3", 180, 0.96)
        ]

        for (title, artist, fileName, ext, duration, calmingScore) in bundledLullabies {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/classical") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .classicalMusic,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 50,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // Bensound ambient tracks (Royalty-free with attribution)
        let bensoundTracks: [(String, String, String, String, Int, Double)] = [
            ("Relaxing", "Bensound", "bensound_relaxing", "mp3", 240, 0.90),
            ("Slow Motion", "Bensound", "bensound_slowmotion", "mp3", 180, 0.88),
            ("Memories", "Bensound", "bensound_memories", "mp3", 200, 0.87),
            ("Tenderness", "Bensound", "bensound_tenderness", "mp3", 160, 0.89),
            ("All That", "Bensound", "bensound_allthat", "mp3", 180, 0.85)
        ]

        for (title, artist, fileName, ext, duration, calmingScore) in bensoundTracks {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/ambient") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .classicalMusic,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 70,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // NOTE: Do NOT use synthetic generator fallbacks for classical music.
        // If bundled files are missing, the app should fetch from API via fetchServerContent().
        // Synthetic lullaby generators produce beeps, not real classical music.

        return tracks
    }

    private func generateFairyTaleTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // MARK: English Fairy Tales from bundled files (fairytales/en/)
        // These are REAL Grimm fairy tale audio files
        let englishFairytales: [(String, String, String, Int, ClosedRange<Int>)] = [
            // Grimm fairy tales
            ("Briar Rose (Sleeping Beauty)", "en_grimm_briar_rose", "mp3", 580, 12...36),
            ("Cat and Mouse", "en_grimm_cat_mouse", "mp3", 420, 12...36),
            ("Chanticleer and Partlet", "en_grimm_chanticleer", "mp3", 740, 12...36),
            ("Cinderella", "en_grimm_cinderella", "mp3", 950, 12...36),
            ("Clever Elsie", "en_grimm_clever_elsie", "mp3", 530, 12...36),
            ("Clever Gretel", "en_grimm_clever_gretel", "mp3", 380, 12...36),
            ("The Dog and the Sparrow", "en_grimm_dog_sparrow", "mp3", 530, 12...36),
            ("The Fisherman and His Wife", "en_grimm_fisherman_wife", "mp3", 900, 12...36),
            ("Frederick and Catherine", "en_grimm_frederick_catherine", "mp3", 745, 18...36),
            ("The Frog Prince", "en_grimm_frog_prince", "mp3", 485, 6...24),
            ("Fundevogel", "en_grimm_fundevogel", "mp3", 400, 12...36),
            ("The Golden Bird", "en_grimm_golden_bird", "mp3", 980, 18...36),
            ("The Goose Girl", "en_grimm_goose_girl", "mp3", 880, 18...36),
            ("Hans in Luck", "en_grimm_hans_luck", "mp3", 950, 18...36),
            ("Hansel and Gretel", "en_grimm_hansel_gretel", "mp3", 1150, 12...36),
            ("Jorinda and Jorindel", "en_grimm_jorinda_jorindel", "mp3", 480, 12...36),
            ("The Little Peasant", "en_grimm_little_peasant", "mp3", 805, 18...36),
            ("The Miser in the Bush", "en_grimm_miser_bush", "mp3", 475, 18...36),
            ("Mother Holle", "en_grimm_mother_holle", "mp3", 490, 12...36),
            ("Mouse, Bird, and Sausage", "en_grimm_mouse_bird_sausage", "mp3", 260, 6...24),
            ("The Old Man and His Grandson", "en_grimm_old_man_grandson", "mp3", 120, 6...24),
            ("Old Sultan", "en_grimm_old_sultan", "mp3", 350, 12...36),
            ("Rapunzel", "en_grimm_rapunzel", "mp3", 585, 12...36),
            ("Little Red Riding Hood", "en_grimm_red_riding_hood", "mp3", 585, 6...24),
            ("The Robber Bridegroom", "en_grimm_robber_bridegroom", "mp3", 560, 18...36),
            ("Rumpelstiltskin", "en_grimm_rumpelstiltskin", "mp3", 490, 12...36),
            ("Snow White", "en_grimm_snow_white", "mp3", 950, 12...36),
            ("Straw, Coal, and Bean", "en_grimm_straw_coal_bean", "mp3", 220, 6...24),
            ("Sweetheart Roland", "en_grimm_sweetheart_roland", "mp3", 580, 18...36),
            ("The Pink", "en_grimm_the_pink", "mp3", 665, 12...36),
            ("Tom Thumb", "en_grimm_tom_thumb", "mp3", 965, 12...36),
            ("The Travelling Musicians", "en_grimm_travelling_musicians", "mp3", 555, 6...24),
            ("The Twelve Dancing Princesses", "en_grimm_twelve_princesses", "mp3", 610, 12...36),
            ("The Valiant Little Tailor", "en_grimm_valiant_tailor", "mp3", 1320, 18...36),
            ("The Willow-Wren", "en_grimm_willow_wren", "mp3", 385, 12...36),
            // Additional English fairy tales (en_ht_ series)
            ("Cat and Mouse (HT)", "en_ht_cat_mouse", "mp3", 400, 12...36),
            ("Faithful John", "en_ht_faithful_john", "mp3", 990, 18...36),
            ("The Frog King", "en_ht_frog_king", "mp3", 460, 6...24),
            ("A Good Bargain", "en_ht_good_bargain", "mp3", 580, 18...36),
            ("Our Lady's Child", "en_ht_our_lady_child", "mp3", 695, 12...36),
            ("Pack of Ragamuffins", "en_ht_pack_ragamuffins", "mp3", 290, 12...36),
            ("The Strange Musician", "en_ht_strange_musician", "mp3", 340, 12...36),
            ("The Twelve Brothers", "en_ht_twelve_brothers", "mp3", 850, 18...36),
            ("Wolf and Seven Kids", "en_ht_wolf_seven_kids", "mp3", 380, 6...24),
            ("The Youth Who Went to Learn Fear", "en_ht_youth_fear", "mp3", 1240, 18...36)
        ]

        for (title, fileName, ext, duration, ageRange) in englishFairytales {
            // Check if file exists in bundle - these are REAL audio files
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/fairytales/en") != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Classic Fairy Tales",
                    category: .fairyTales,
                    language: .english,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    calmingScore: 0.75,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // NOTE: Other language fairy tales (Spanish, French, German, etc.)
        // are NOT bundled locally. They should be fetched from the API via fetchServerContent().
        // DO NOT create textToSpeech fallbacks - use API streaming instead.

        return tracks
    }

    private func generateChildrenSongTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // Bundled children's songs from Audio/children folder (Bensound royalty-free)
        let bundledChildrenSongs: [(String, String, String, Int, ClosedRange<Int>, Double)] = [
            // (title, fileName, extension, duration_seconds, ageRange, calmingScore)
            ("Cute", "bensound_cute", "mp3", 169, 6...36, 0.82),
            ("Happy Rock", "bensound_happyrock", "mp3", 105, 12...36, 0.70),
            ("Little Idea", "bensound_littleidea", "mp3", 147, 6...36, 0.80),
            ("Sunny", "bensound_sunny", "mp3", 130, 6...36, 0.78)
        ]

        for (title, fileName, ext, duration, ageRange, calmingScore) in bundledChildrenSongs {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/children") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Bensound",
                    category: .childrenSongs,
                    language: .english,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 100,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // Bundled lullaby audio files from Audio/lullabies folder
        let bundledLullabies: [(String, String, String, Int, ClosedRange<Int>)] = [
            ("Gentle Melody", "gentle_melody", "mp3", 360, 0...36),
            ("Lullaby Melody", "lullaby_melody", "mp3", 320, 0...36),
            ("Sleep Sounds", "sleep_sounds", "mp3", 260, 0...24),
            ("Bedtime Tune", "bedtime_tune", "mp3", 340, 0...36),
            ("Soft Lullaby for Baby", "soft_lullaby_baby", "mp3", 280, 0...36),
            ("Suo Gan (Welsh Lullaby)", "suo_gan", "mp3", 240, 0...36),
            ("Twinkle Twinkle Little Star", "twinkle_twinkle", "mp3", 120, 0...36),
            ("Rock-a-Bye Baby", "rock_a_bye_baby", "mp3", 90, 0...24)
        ]

        for (title, fileName, ext, duration, ageRange) in bundledLullabies {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/lullabies") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/children") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: "Lullaby Collection",
                    category: .childrenSongs,
                    language: .english,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 70,
                    calmingScore: 0.85,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            }
        }

        // NOTE: Do NOT add synthetic fallbacks that produce beeps (.generated with .musicBox)
        // Real bundled lullabies and Bensound files are sufficient.
        // Additional content should come from API streaming, not synthetic generation.

        return tracks
    }

    // MARK: - Default Playlists

    private func generateDefaultPlaylists() -> [Playlist] {
        var playlists: [Playlist] = []

        // Newborn Essentials (0-3 months)
        let newbornTracks = allTracks.filter {
            $0.ageRangeMin == 0 && [.whiteNoise, .natureSounds].contains($0.category)
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
            $0.calmingScore >= 0.85 && [.whiteNoise, .natureSounds, .classicalMusic].contains($0.category)
        }
        playlists.append(Playlist(
            name: "Sleep Time Favorites",
            description: "The most soothing sounds for peaceful sleep",
            tracks: Array(sleepTracks.prefix(15)),
            isSystemGenerated: true,
            artworkName: "sleep_playlist"
        ))

        // White Noise Collection
        let whiteNoiseTracks = allTracks.filter { $0.category == .whiteNoise }
        playlists.append(Playlist(
            name: "White Noise Collection",
            description: "All white noise and mechanical sounds",
            tracks: whiteNoiseTracks,
            category: .whiteNoise,
            isSystemGenerated: true,
            artworkName: "whitenoise_playlist"
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

        // Premium Noise Collection (all noise variants)
        let allNoiseTypes = allTracks.filter {
            [GeneratorType.whiteNoise, .pinkNoise, .brownNoise, .blueNoise, .violetNoise, .greyNoise, .velvetNoise]
                .contains($0.generatorType ?? .whiteNoise)
        }
        playlists.append(Playlist(
            name: "Complete Noise Collection",
            description: "White, pink, brown, blue, violet, grey & velvet noise",
            tracks: allNoiseTypes,
            category: .whiteNoise,
            isSystemGenerated: true,
            artworkName: "noise_collection"
        ))

        // Travel Sounds (for car rides, flights, trains)
        let travelTracks = allTracks.filter {
            [GeneratorType.trainRide, .airplaneCabin, .carEngine, .cityAmbience].contains($0.generatorType ?? .whiteNoise)
        }
        playlists.append(Playlist(
            name: "Travel Companion",
            description: "Familiar travel sounds to calm during journeys",
            tracks: travelTracks,
            isSystemGenerated: true,
            artworkName: "travel_playlist"
        ))

        // Cozy Night Sounds
        let cozyNightTracks = allTracks.filter {
            [GeneratorType.rainOnRoof, .fireplace, .campfire, .thunderRumble, .rain].contains($0.generatorType ?? .whiteNoise)
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

    func getTracks(for language: Language) -> [AudioTrack] {
        return allTracks.filter { $0.language == language }
    }

    func getTracks(forAgeMonths age: Int) -> [AudioTrack] {
        return allTracks.filter { $0.ageRangeMin <= age && $0.ageRangeMax >= age }
    }

    func getTrack(by id: UUID) -> AudioTrack? {
        return allTracks.first { $0.id == id }
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
