//
//  ContentLibraryService.swift
//  BabyInCarApp
//
//  Content library management - online-first with generated audio
//

import Foundation
import Combine

@MainActor
class ContentLibraryService: ObservableObject {
    static let shared = ContentLibraryService()

    @Published var allTracks: [AudioTrack] = []
    @Published var playlists: [Playlist] = []
    @Published var isLoading: Bool = false

    private init() {
        loadContent()
    }

    // MARK: - Content Loading

    func loadContent() {
        isLoading = true

        // Generate all available tracks
        allTracks = generateAllTracks()

        // Create default playlists
        playlists = generateDefaultPlaylists()

        isLoading = false
    }

    // MARK: - Generated Audio Content

    private func generateAllTracks() -> [AudioTrack] {
        var tracks: [AudioTrack] = []

        // MARK: White Noise & Calming Sounds
        let whiteNoiseGenerators: [(GeneratorType, String)] = [
            (.whiteNoise, "Pure White Noise"),
            (.pinkNoise, "Soft Pink Noise"),
            (.brownNoise, "Deep Brown Noise"),
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
            (.ocean, "Ocean Waves"),
            (.river, "Babbling Brook"),
            (.wind, "Soft Breeze"),
            (.thunderstorm, "Distant Thunder"),
            (.birds, "Morning Birds"),
            (.crickets, "Summer Crickets"),
            (.fireplace, "Crackling Fire")
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

        // MARK: Instrumental / Music Box
        let musicalSounds: [(GeneratorType, String)] = [
            (.lullaby, "Music Box Lullaby"),
            (.musicBox, "Gentle Music Box"),
            (.chimes, "Wind Chimes"),
            (.bells, "Soft Bells")
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

        return tracks
    }

    private func generateClassicalMusicTracks() -> [AudioTrack] {
        // These would be linked to royalty-free classical music or generated
        let classicalPieces: [(String, String, Int)] = [
            ("Brahms' Lullaby", "Johannes Brahms", 180),
            ("Twinkle Twinkle Little Star", "Mozart Variation", 120),
            ("Clair de Lune", "Claude Debussy", 300),
            ("Canon in D", "Johann Pachelbel", 240),
            ("Gymnopédie No. 1", "Erik Satie", 180),
            ("Air on G String", "J.S. Bach", 300),
            ("Moonlight Sonata", "Beethoven", 360),
            ("Für Elise", "Beethoven", 180),
            ("Swan Lake Theme", "Tchaikovsky", 240),
            ("Nocturne Op. 9 No. 2", "Chopin", 270)
        ]

        return classicalPieces.map { (title, artist, duration) in
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
                generatorType: .lullaby // Use music generator as placeholder
            )
        }
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
        let songs: [(String, Int, ClosedRange<Int>)] = [
            ("Twinkle Twinkle Little Star", 120, 0...36),
            ("Rock-a-Bye Baby", 150, 0...24),
            ("Hush Little Baby", 180, 0...24),
            ("All the Pretty Horses", 180, 0...24),
            ("You Are My Sunshine", 150, 3...36),
            ("Mary Had a Little Lamb", 90, 6...36),
            ("Itsy Bitsy Spider", 60, 6...36),
            ("Row Row Row Your Boat", 60, 6...36),
            ("Old MacDonald", 120, 9...36),
            ("Wheels on the Bus", 150, 9...36),
            ("ABC Song", 90, 12...36),
            ("Head Shoulders Knees and Toes", 90, 12...36),
            ("If You're Happy and You Know It", 90, 12...36),
            ("Baby Shark (Calm Version)", 120, 12...36),
            ("Five Little Ducks", 120, 12...36)
        ]

        return songs.map { (title, duration, ageRange) in
            AudioTrack(
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
            )
        }
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
