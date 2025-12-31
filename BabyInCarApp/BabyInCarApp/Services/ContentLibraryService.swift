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
        default: return .instrumental
        }
    }

    // MARK: - Generated Audio Content

    private func generateAllTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // First, load all bundled tracks from metadata JSON
        let bundledTracks = loadBundledTracksFromMetadata()
        tracks.append(contentsOf: bundledTracks)

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

        // MARK: Instrumental / Music Box
        let musicalSounds: [(GeneratorType, String)] = [
            (.lullaby, "Music Box Lullaby"),
            (.musicBox, "Gentle Music Box"),
            (.chimes, "Wind Chimes"),
            (.bells, "Soft Bells"),
            (.softPiano, "Dreamy Piano"),
            (.gentleGuitar, "Acoustic Lullaby")
        ]

        for (generator, title) in musicalSounds {
            tracks.append(AudioTrack(
                title: title,
                artist: "Instrumental",
                category: .instrumental,
                duration: 1800,
                ageRangeMin: generator.optimalAgeRange.lowerBound,
                ageRangeMax: generator.optimalAgeRange.upperBound,
                calmingScore: generator.calmingScore,
                audioSourceType: .generated,
                generatorType: generator
            ))
        }

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

        // Russian Lullabies (AI-generated or bundled)
        let russianLullabies: [(String, String, String, String, Int, Double)] = [
            // (title, titleEn/artist, fileName, extension, duration, calmingScore)
            ("Спи, малыш", "Sleep Little One", "ru_lullaby_01", "mp3", 120, 0.92),
            ("Баю-баюшки-баю", "Hush-a-bye", "ru_lullaby_02", "mp3", 150, 0.95),
            ("Колыбельная звёзд", "Star Lullaby", "ru_lullaby_03", "mp3", 180, 0.90),
            ("Сладких снов", "Sweet Dreams", "ru_lullaby_04", "mp3", 120, 0.88)
        ]

        for (title, artist, fileName, ext, duration, calmingScore) in russianLullabies {
            // Check if bundled file exists
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/russian") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 60,
                    calmingScore: calmingScore,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            } else {
                // Fallback to generated placeholder
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 60,
                    calmingScore: calmingScore,
                    audioSourceType: .generated,
                    generatorType: .lullaby
                ))
            }
        }

        // Russian Children's Songs
        let russianSongs: [(String, String, String, String, Int, ClosedRange<Int>)] = [
            ("Солнышко", "Little Sun", "ru_song_01", "mp3", 90, 3...36),
            ("Весёлый дождик", "Happy Rain", "ru_song_02", "mp3", 100, 3...36),
            ("Маленькая звёздочка", "Little Star", "ru_song_03", "mp3", 120, 0...36)
        ]

        for (title, artist, fileName, ext, duration, ageRange) in russianSongs {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/russian") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 75,
                    calmingScore: 0.80,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            } else {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 75,
                    calmingScore: 0.80,
                    audioSourceType: .generated,
                    generatorType: .musicBox
                ))
            }
        }

        // Russian Calming Melodies (Instrumental)
        let russianInstrumental: [(String, String, String, String, Int)] = [
            ("Тихий вечер", "Quiet Evening", "ru_calm_01", "mp3", 180),
            ("Зимняя сказка", "Winter Fairytale", "ru_calm_02", "mp3", 200),
            ("Берёзовая роща", "Birch Grove", "ru_calm_03", "mp3", 180)
        ]

        for (title, artist, fileName, ext, duration) in russianInstrumental {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/russian") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .instrumental,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 55,
                    calmingScore: 0.88,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            } else {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .instrumental,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 55,
                    calmingScore: 0.88,
                    audioSourceType: .generated,
                    generatorType: .softPiano
                ))
            }
        }

        // Russian Educational Songs (Logorhythmic)
        let russianEducational: [(String, String, String, String, Int, ClosedRange<Int>)] = [
            ("Ручки-ножки", "Hands and Feet", "ru_edu_01", "mp3", 90, 12...36),
            ("Пальчики", "Little Fingers", "ru_edu_02", "mp3", 80, 6...24)
        ]

        for (title, artist, fileName, ext, duration, ageRange) in russianEducational {
            if Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Audio/russian") != nil ||
               Bundle.main.url(forResource: fileName, withExtension: ext) != nil {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 65,
                    calmingScore: 0.75,
                    audioSourceType: .bundled,
                    fileName: fileName,
                    fileExtension: ext
                ))
            } else {
                tracks.append(AudioTrack(
                    title: title,
                    artist: artist,
                    category: .childrenSongs,
                    language: .russian,
                    duration: TimeInterval(duration),
                    ageRangeMin: ageRange.lowerBound,
                    ageRangeMax: ageRange.upperBound,
                    tempoBPM: 65,
                    calmingScore: 0.75,
                    audioSourceType: .generated,
                    generatorType: .musicBox
                ))
            }
        }

        // Russian Fairy Tales
        let russianStories: [(String, Int, ClosedRange<Int>)] = [
            ("Колобок", 300, 12...36),
            ("Репка", 240, 12...36),
            ("Теремок", 360, 12...36),
            ("Курочка Ряба", 180, 6...24),
            ("Три медведя", 420, 18...36),
            ("Маша и медведь", 480, 18...36)
        ]

        for (title, duration, ageRange) in russianStories {
            tracks.append(AudioTrack(
                title: title,
                artist: "Русские сказки",
                category: .fairyTales,
                language: .russian,
                duration: TimeInterval(duration),
                ageRangeMin: ageRange.lowerBound,
                ageRangeMax: ageRange.upperBound,
                calmingScore: 0.72,
                audioSourceType: .textToSpeech
            ))
        }

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

        // Fallback to generated if no bundled files available
        if tracks.isEmpty {
            let classicalPieces: [(String, String, Int)] = [
                ("Brahms' Lullaby", "Johannes Brahms", 180),
                ("Clair de Lune", "Claude Debussy", 300),
                ("Canon in D", "Johann Pachelbel", 240),
                ("Gymnopédie No. 1", "Erik Satie", 180)
            ]

            tracks = classicalPieces.map { (title, artist, duration) in
                AudioTrack(
                    title: title,
                    artist: artist,
                    category: .classicalMusic,
                    duration: TimeInterval(duration),
                    ageRangeMin: 0,
                    ageRangeMax: 36,
                    tempoBPM: 60,
                    calmingScore: 0.85,
                    audioSourceType: .generated,
                    generatorType: .lullaby
                )
            }
        }

        return tracks
    }

    private func generateFairyTaleTracks() -> [AudioTrack] {
        let stories: [(String, Language, Int, ClosedRange<Int>)] = [
            // English Stories
            ("Goodnight Moon", .english, 300, 0...12),
            ("The Very Hungry Caterpillar", .english, 420, 6...24),
            ("Where the Wild Things Are", .english, 480, 12...36),
            ("Guess How Much I Love You", .english, 360, 3...24),
            ("The Runaway Bunny", .english, 420, 6...24),
            ("Pat the Bunny", .english, 240, 0...12),
            ("Brown Bear, Brown Bear", .english, 180, 3...18),
            ("Chicka Chicka Boom Boom", .english, 240, 6...24),
            ("The Snowy Day", .english, 360, 12...36),
            ("Corduroy", .english, 480, 18...36),

            // Spanish Stories
            ("Buenas Noches Luna", .spanish, 300, 0...12),
            ("La Oruga Muy Hambrienta", .spanish, 420, 6...24),
            ("Donde Viven los Monstruos", .spanish, 480, 12...36),
            ("Adivina Cuánto Te Quiero", .spanish, 360, 3...24),

            // French Stories
            ("Bonne Nuit Lune", .french, 300, 0...12),
            ("La Chenille Qui Fait des Trous", .french, 420, 6...24),
            ("Max et les Maximonstres", .french, 480, 12...36),

            // German Stories
            ("Gute Nacht Mond", .german, 300, 0...12),
            ("Die kleine Raupe Nimmersatt", .german, 420, 6...24),

            // Italian Stories
            ("Buonanotte Luna", .italian, 300, 0...12),
            ("Il Piccolo Bruco Maisazio", .italian, 420, 6...24),

            // Mandarin Stories
            ("晚安月亮", .mandarin, 300, 0...12),
            ("好饿的毛毛虫", .mandarin, 420, 6...24),

            // Japanese Stories
            ("おやすみなさいおつきさま", .japanese, 300, 0...12),
            ("はらぺこあおむし", .japanese, 420, 6...24)
        ]

        return stories.map { (title, language, duration, ageRange) in
            AudioTrack(
                title: title,
                artist: "Story Time",
                category: .fairyTales,
                language: language,
                duration: TimeInterval(duration),
                ageRangeMin: ageRange.lowerBound,
                ageRangeMax: ageRange.upperBound,
                calmingScore: 0.75,
                audioSourceType: .textToSpeech
            )
        }
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

        // Add generated fallbacks
        let songs: [(String, Int, ClosedRange<Int>)] = [
            ("Twinkle Twinkle Little Star", 120, 0...36),
            ("Rock-a-Bye Baby", 150, 0...24),
            ("Hush Little Baby", 180, 0...24),
            ("You Are My Sunshine", 150, 3...36)
        ]

        for (title, duration, ageRange) in songs {
            tracks.append(AudioTrack(
                title: title,
                artist: "Children's Songs",
                category: .childrenSongs,
                language: .english,
                duration: TimeInterval(duration),
                ageRangeMin: ageRange.lowerBound,
                ageRangeMax: ageRange.upperBound,
                tempoBPM: 80,
                calmingScore: 0.7,
                audioSourceType: .generated,
                generatorType: .musicBox
            ))
        }

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
