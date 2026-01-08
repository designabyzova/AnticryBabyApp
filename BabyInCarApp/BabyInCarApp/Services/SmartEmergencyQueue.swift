//
//  SmartEmergencyQueue.swift
//  BabyInCarApp
//
//  Ultra-smart emergency queue that builds real playlists from local library
//  USES REAL AUDIO TRACKS, NOT JUST GENERATED SOUNDS!
//

import Foundation
import Combine
import UIKit

/// Smart queue that builds cry-type specific playlists using real audio library tracks.
/// This is the Spotify-like queue experience for emergency cry response.
///
/// NOTE: This replaces the legacy EmergencyQueueManager. See ADR-0126.
/// - SmartEmergencyQueue: AI-powered track selection, queue management
/// - SmartQueueView: Spotify-like UI with animations and gestures
///
/// NEW: Supports PROACTIVE AMBIENT MODE - starts playing immediately when monitoring begins,
/// not waiting for cry detection. Uses only REAL library tracks (classical, lullabies, etc.)
/// - NO generated noise sounds (fan, pink, brown, white noise)
@MainActor
class SmartEmergencyQueue: ObservableObject {
    static let shared = SmartEmergencyQueue()

    // MARK: - Published State (Spotify-like)
    @Published var isActive: Bool = false
    @Published var currentTrack: AudioTrack?
    @Published var upcomingTracks: [AudioTrack] = []
    @Published var playedTracks: [AudioTrack] = []
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var sessionDuration: TimeInterval = 0

    // Queue metadata
    @Published var queueName: String = ""
    @Published var queueDescription: String = ""
    @Published var cryType: CryType = .general
    @Published var babyAge: Int = 12
    @Published var totalTracks: Int = 0
    @Published var currentIndex: Int = 0

    // MARK: - Ambient Mode (Proactive Playlist)
    /// When true, playlist plays IMMEDIATELY when monitoring starts - no cry detection needed
    @Published var isAmbientMode: Bool = false
    /// Human-readable mode name for UI
    @Published var modeName: String = "Smart Soothing"

    // MARK: - Private State
    private var allQueueTracks: [AudioTrack] = []
    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private let audioEngine = AudioEngine.shared
    private let playbackSession = PlaybackSessionManager.shared
    private let contentLibrary = ContentLibraryService.shared
    private let ultraSmartSelector = UltraSmartPlaylistSelector.shared
    private let spotifyEngine = SpotifyQueueEngine.shared

    // MARK: - Spotify-like Queue State
    /// Pool of candidate tracks for replenishment
    private var candidatePool: [AudioTrack] = []
    /// Whether Spotify-like auto-replenishment is enabled
    private var autoReplenishEnabled: Bool = true

    // MARK: - Memory Optimization (Increment 0022, Enhanced in 0028)
    /// Maximum tracks loaded in memory concurrently (prevents 30MB buffer allocation)
    /// UPDATED (Increment 0028): Reduced from 3 to 2 for tighter memory control
    private let maxConcurrentLoadedTracks = 2
    /// Tracks currently loaded in memory (max 2)
    private var loadedTracks: [AudioTrack] = []
    /// IDs of tracks queued but not yet loaded
    private var queuedTrackIds: [UUID] = []

    // MARK: - Configuration
    /// Minimum tracks in queue before fetching more
    private let minQueueSize = 3
    /// Maximum tracks to show in "Up Next"
    private let maxUpNextCount = 8
    /// Mix ratio: 100% REAL library tracks - NO AI GENERATED NOISE!
    /// USER FEEDBACK: White noise, pink noise, fan, washer sounds are SCARY for babies!
    /// SOLUTION: Use ONLY melodic content - classical, lullabies, children's songs, ambient music
    private let realTrackRatio = 1.0
    /// For ambient mode: use 100% REAL tracks - NO generated noise at all!
    private let ambientModeRealTrackRatio = 1.0

    // MARK: - Science-Based Category Priorities
    /// Categories proven effective for infant soothing (research-backed)
    /// Based on: Standley (2002), Rauscher (1993), Shenfield (2003)
    private static let scienceBasedCategories: [String: Double] = [
        "classical": 0.95,      // Brahms Lullaby, Mozart Effect research
        "lullabies": 0.98,      // Cross-cultural calming effect
        "ambient": 0.85,        // Gentle background, no sudden changes
        "acoustic": 0.80,       // Warm guitar/ukulele tones
        "children": 0.75,       // Age-appropriate melodies
        "nature": 0.70,         // Ocean, river (NOT rain/thunder)
        "english": 0.65,        // Fairy tales - engaging distraction
        "russian": 0.65,        // Fairy tales - engaging distraction
    ]

    /// Categories to COMPLETELY BAN from ALL modes (emergency AND ambient)
    /// These sounds are scary, harsh, or inappropriate for baby soothing
    private static let bannedCategories: Set<String> = [
        "whitenoise",           // BANNED: All white/pink/brown noise - scary!
        "noise",                // BANNED: Any noise category
        "generated",            // BANNED: AI generated sounds
    ]

    // MARK: - Smart Rotation State
    /// Track which first tracks have been used recently (for rotation)
    private static var recentFirstTracks: [UUID] = []
    private static let maxRecentFirstTracks = 5

    /// Track session count for rotation decisions
    private static var sessionCount: Int = 0

    /// Generated tracks for rotation (Piano Moment alternatives)
    private static let generatedFirstTrackOptions: [GeneratorType] = [
        .lullaby,       // Default - gentle lullaby melody
        .musicBox,      // Alternative - classic music box
        .softPiano,     // Alternative - gentle piano
        .heartbeat,     // For very young babies
        .ocean,         // Nature option - rhythmic waves
    ]

    // MARK: - Playlist Mode Strategies

    /// Different playlist modes have different selection strategies
    enum PlaylistMode {
        /// Emergency mode: Baby is crying NOW - need immediate, proven calming
        /// - First track: Proven effective OR instant-start generated (NO loading delay!)
        /// - Queue priority: Comfort sounds, high calming scores
        /// - Variety: Lower priority - effectiveness is key
        case emergency

        /// Ambient mode: Continuous background music for monitoring
        /// - First track: High-quality library track with smooth start
        /// - Queue priority: Variety, long-form content
        /// - Variety: High priority - prevent repetition
        case ambient

        /// AI Detection mode: Cry detected by ML, proactive response
        /// - First track: Balance of instant-start AND effectiveness
        /// - Queue priority: Balanced between calming and exploration
        /// - Variety: Medium - try new things while ensuring safety
        case aiDetection

        /// Manual selection: User chose a category
        /// - First track: Top track from selected category
        /// - Queue priority: Category-focused with variety
        /// - Variety: High within category
        case manualCategory
    }

    /// Current playlist mode (affects selection strategy)
    private(set) var currentPlaylistMode: PlaylistMode = .emergency

    /// Set the playlist mode for the next queue build
    /// Use this to indicate how the queue should prioritize tracks
    func setPlaylistMode(_ mode: PlaylistMode) {
        self.currentPlaylistMode = mode
        print("[SmartQueue] 🎯 Playlist mode set to: \(mode)")
    }

    private init() {
        setupObservers()
        // Ensure initial state is synced with actual playback
        syncPlaybackState()
    }

    /// Sync queue state with actual AudioEngine state
    /// Call this to fix "ghost playing" issues where UI shows playing but no audio is active
    /// - Parameter verbose: If true, log diagnostic info (default: false to reduce startup noise)
    func syncPlaybackState(verbose: Bool = false) {
        let actuallyPlaying = audioEngine.playbackState == .playing
        let hasActiveTrack = audioEngine.currentTrack != nil
        let engineState = audioEngine.playbackState

        // Only log when verbose OR when we're actually active (reduces startup noise)
        if verbose || isActive {
            print("[SmartQueue] 🔧 Sync check: isActive=\(isActive), isPlaying=\(isPlaying), hasTrack=\(currentTrack != nil), enginePlaying=\(actuallyPlaying), engineTrack=\(hasActiveTrack), state=\(engineState)")
        }

        // If we think we're playing but AudioEngine isn't, correct our state
        if isPlaying && !actuallyPlaying {
            print("[SmartQueue] 🔧 Fixing state mismatch: queue.isPlaying=true but no audio playing")
            isPlaying = false
        }

        // If AudioEngine is playing but we're not, and we have a current track, update our state
        if !isPlaying && actuallyPlaying && isActive && currentTrack != nil {
            print("[SmartQueue] 🔧 Fixing state mismatch: AudioEngine playing but queue.isPlaying=false")
            isPlaying = true
        }

        // If queue is "active" but there's no track anywhere, reset active state
        if isActive && !hasActiveTrack && currentTrack == nil && allQueueTracks.isEmpty {
            print("[SmartQueue] 🔧 Fixing stale active state: isActive=true but no tracks")
            isActive = false
            isPlaying = false
        }

        // If we think we have a track but AudioEngine has stopped completely, clear our track
        if currentTrack != nil && !hasActiveTrack && engineState == .stopped && upcomingTracks.isEmpty {
            print("[SmartQueue] 🔧 Fixing stale track state: queue has track but engine stopped")
            // Keep the queue active but mark as not playing
            // This allows the user to see the player card but shows paused state
            isPlaying = false
        }
    }

    // MARK: - Queue Building

    /// Build a smart queue for the detected cry type
    /// Uses: 100% REAL MELODIC content from audio library - NO AI generated noise!
    /// PRIORITY ORDER: Classical > Lullabies > Instrumental > Children's Songs > Nature (gentle)
    /// - Parameters:
    ///   - cryType: The type of cry detected
    ///   - babyAge: Baby's age in months
    ///   - language: Preferred language for fairy tales
    ///   - maxTracks: Maximum tracks to include
    ///   - preferredCategories: Set of categories to include (multi-select), or nil for AI default
    func buildQueue(
        for cryType: CryType,
        babyAge: Int,
        language: String = "en",
        maxTracks: Int = 20,
        preferredCategories: Set<AudioCategory>? = nil
    ) async -> [AudioTrack] {
        if let categories = preferredCategories, !categories.isEmpty {
            let categoryNames = categories.map { $0.rawValue }.sorted().joined(separator: " + ")
            print("[SmartQueue] 🎵 Building MULTI-CATEGORY queue: \(categoryNames) for age=\(babyAge)mo")
            self.modeName = categories.count == 1 ? categories.first!.rawValue : "Smart Mix"
        } else {
            print("[SmartQueue] 🎵 Building AI-DEFAULT queue for \(cryType.rawValue), age=\(babyAge)mo, lang=\(language)")
            self.modeName = "AI Instant Calm"
        }
        print("[SmartQueue] ⚠️ NO white noise, NO generated sounds - ONLY real compositions!")

        self.cryType = cryType
        self.babyAge = babyAge
        self.isAmbientMode = false

        // Set playlist mode based on context
        if let categories = preferredCategories, !categories.isEmpty {
            self.currentPlaylistMode = .manualCategory
        } else {
            // Default to emergency mode for cry response
            self.currentPlaylistMode = .emergency
        }

        // Increment session counter for rotation
        SmartEmergencyQueue.sessionCount += 1

        // Get ONLY real melodic tracks from library - NO generated sounds!
        var melodicTracks = await getMelodicTracksForCryType(
            cryType: cryType,
            babyAge: babyAge,
            language: language,
            maxCount: maxTracks - 1,  // Reserve 1 slot for first track
            preferredCategories: preferredCategories
        )

        // SMART FIRST TRACK SELECTION with rotation!
        // Instead of always using the same track, intelligently select based on:
        // 1. What worked best for this baby (effectiveness data)
        // 2. What hasn't been played recently (rotation)
        // 3. Cry type (urgent cries need proven tracks)
        // 4. Baby age (younger babies may prefer womb sounds)
        let smartFirstTrack = selectSmartFirstTrack(
            cryType: cryType,
            babyAge: babyAge,
            melodicTracks: melodicTracks
        )

        // Remove the selected first track from the list if it exists
        melodicTracks.removeAll { $0.id == smartFirstTrack.id }

        // Prepend smart first track for instant playback
        melodicTracks.insert(smartFirstTrack, at: 0)

        // Track this first track for rotation
        recordFirstTrackUsed(smartFirstTrack.id)

        print("[SmartQueue] 🎵 Smart first track: \(smartFirstTrack.title) (session #\(SmartEmergencyQueue.sessionCount))")
        print("[SmartQueue] 🎵 Built queue with \(melodicTracks.count) MELODIC tracks (no white noise!)")

        // Set queue metadata
        if let categories = preferredCategories, !categories.isEmpty {
            let categoryNames = categories.map { $0.rawValue }.sorted().joined(separator: " + ")
            self.queueName = categoryNames
            self.queueDescription = "AI-curated mix for your \(babyAge < 12 ? "baby" : "toddler")"
        } else {
            self.queueName = getQueueName(for: cryType)
            self.queueDescription = getQueueDescription(for: cryType, babyAge: babyAge)
        }

        return melodicTracks
    }

    // MARK: - Spotify-like Queue Building (NEW!)

    /// Build queue using Spotify-like recommendation algorithm
    /// Uses SpotifyQueueEngine for smart track selection based on:
    /// - Cry stop success history
    /// - Favorites
    /// - Play counts
    /// - Rotation policy to prevent repetition
    ///
    /// Maintains exactly 8 upcoming tracks (Spotify radio behavior)
    func buildSpotifyQueue(
        for cryType: CryType,
        babyAge: Int,
        language: String = "en",
        preferredCategories: Set<AudioCategory>? = nil
    ) async -> [AudioTrack] {
        print("[SmartQueue] 🎧 Building SPOTIFY-STYLE queue for \(cryType.rawValue)")

        // Set context for scoring
        spotifyEngine.setContext(
            cryType: cryType,
            babyAge: babyAge,
            preferredCategories: preferredCategories
        )

        // Get all eligible candidate tracks
        candidatePool = await getMelodicTracksForCryType(
            cryType: cryType,
            babyAge: babyAge,
            language: language,
            maxCount: 100, // Large pool for variety
            preferredCategories: preferredCategories
        )

        print("[SmartQueue] 🎧 Candidate pool: \(candidatePool.count) tracks")

        // Use Spotify engine to build initial queue (8 tracks)
        let selectedTracks = spotifyEngine.buildInitialQueue(from: candidatePool)

        // Log the selections with their scores
        print("[SmartQueue] 🎧 Spotify-selected \(selectedTracks.count) tracks:")
        for (index, track) in selectedTracks.enumerated() {
            let score = spotifyEngine.getScoreBreakdown(for: track)
            print("  \(index + 1). \(track.title) (score: \(score.scorePercentage)%)")
        }

        // Set metadata
        self.cryType = cryType
        self.babyAge = babyAge
        self.isAmbientMode = false
        self.modeName = "Spotify Smart Mix"
        self.queueName = "🎧 Your Baby's Mix"
        self.queueDescription = "AI-curated based on what works for your baby"
        self.autoReplenishEnabled = true

        return selectedTracks
    }

    /// Replenish queue to maintain 8 upcoming tracks
    /// Called automatically when a track finishes (Spotify radio behavior)
    private func replenishQueueIfNeeded() {
        guard autoReplenishEnabled else { return }
        guard isActive else { return }

        let currentQueueSize = upcomingTracks.count
        let needed = SpotifyQueueEngine.targetQueueSize - currentQueueSize

        guard needed > 0 else { return }

        print("[SmartQueue] 🔄 Replenishing queue: \(currentQueueSize) → \(SpotifyQueueEngine.targetQueueSize)")

        // Get new tracks from Spotify engine
        let newTracks = spotifyEngine.replenishQueue(
            currentQueue: upcomingTracks,
            from: candidatePool
        )

        // Add to upcoming
        for track in newTracks {
            upcomingTracks.append(track)
            allQueueTracks.append(track)
        }

        totalTracks = allQueueTracks.count

        print("[SmartQueue] 🔄 Added \(newTracks.count) tracks. Queue now: \(upcomingTracks.count) upcoming")

        // Log new tracks
        for track in newTracks {
            let score = spotifyEngine.getScoreBreakdown(for: track)
            print("  + \(track.title) (score: \(score.scorePercentage)%)")
        }
    }

    // MARK: - Smart First Track Selection (Intelligent Rotation!)

    /// Intelligently select the first track based on multiple factors
    /// This provides VARIETY while still prioritizing what WORKS
    /// Selection strategy varies by playlist mode:
    /// - Emergency: Prioritize proven effective tracks (80% proven, 20% exploration)
    /// - AI Detection: Balance effectiveness and variety (60% proven, 40% exploration)
    /// - Ambient: Prioritize variety and smooth starts (30% proven, 70% exploration)
    /// - Manual: Use category-specific selection
    private func selectSmartFirstTrack(
        cryType: CryType,
        babyAge: Int,
        melodicTracks: [AudioTrack]
    ) -> AudioTrack {
        let effectivenessManager = EffectivenessManager.shared
        let favoritesManager = FavoritesManager.shared

        // Adjust proven track probability based on playlist mode
        let provenTrackProbability: Double
        let varietyWeight: Double

        switch currentPlaylistMode {
        case .emergency:
            // Emergency: Strongly favor proven tracks - baby needs help NOW
            provenTrackProbability = 0.80
            varietyWeight = 0.2
        case .aiDetection:
            // AI Detection: Balance - we have a moment to try something new
            provenTrackProbability = 0.60
            varietyWeight = 0.4
        case .ambient:
            // Ambient: Favor variety - this is background music
            provenTrackProbability = 0.30
            varietyWeight = 0.7
        case .manualCategory:
            // Manual: User chose category, respect that but add smart selection
            provenTrackProbability = 0.50
            varietyWeight = 0.5
        }

        // STRATEGY 1: Check if we have a PROVEN effective track for this cry type
        let useProvenTrack = Double.random(in: 0...1) < provenTrackProbability
        if useProvenTrack {
            let effectiveTracks = effectivenessManager.getTopEffectiveTracks(limit: 5, cryType: cryType)
            for track in effectiveTracks {
                // Skip if this was the first track in recent sessions
                // (unless in emergency mode where effectiveness trumps variety)
                let skipRecent = currentPlaylistMode != .emergency
                if !skipRecent || !SmartEmergencyQueue.recentFirstTracks.contains(track.id) {
                    print("[SmartQueue] 🧠 Using PROVEN effective track (\(currentPlaylistMode)): \(track.title)")
                    return track
                }
            }
        }

        // STRATEGY 2: Check favorites that haven't been used recently
        // (More weight in ambient/manual modes, less in emergency)
        if Double.random(in: 0...1) < (0.3 + varietyWeight * 0.5) {
            let favorites = favoritesManager.favoriteTracks
            for trackId in favorites {
                if !SmartEmergencyQueue.recentFirstTracks.contains(trackId),
                   let track = contentLibrary.getTrack(by: trackId) {
                    // Verify it's suitable (age-appropriate, not banned)
                    if track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge {
                        print("[SmartQueue] ⭐ Using FAVORITE track (\(currentPlaylistMode)): \(track.title)")
                        return track
                    }
                }
            }
        }

        // STRATEGY 3: Select from real library tracks (top rated) with rotation AND randomization
        // More exploration in ambient mode, stricter selection in emergency
        let librarySearchDepth = currentPlaylistMode == .ambient ? 20 : 10
        let eligibleTracks = melodicTracks.prefix(librarySearchDepth).filter {
            !SmartEmergencyQueue.recentFirstTracks.contains($0.id)
        }

        if !eligibleTracks.isEmpty {
            // RANDOMIZATION: Pick randomly from top eligible tracks instead of always first
            let randomIndex = Int.random(in: 0..<min(5, eligibleTracks.count))
            let selectedTrack = eligibleTracks[randomIndex]
            print("[SmartQueue] 📚 Using RANDOMIZED library track (\(currentPlaylistMode)): \(selectedTrack.title) (picked #\(randomIndex + 1) of \(eligibleTracks.count) eligible)")
            return selectedTrack
        }

        // STRATEGY 4: Generated tracks - more likely in emergency/AI detection (instant playback)
        // Less likely in ambient mode (prefer streamed library content)
        if currentPlaylistMode == .emergency || currentPlaylistMode == .aiDetection {
            let generatedTrack = selectRotatedGeneratedTrack(cryType: cryType, babyAge: babyAge)
            print("[SmartQueue] 🎹 Using GENERATED track (\(currentPlaylistMode)): \(generatedTrack.title)")
            return generatedTrack
        }

        // Fallback: clear recent history and pick first library track
        SmartEmergencyQueue.recentFirstTracks.removeAll()
        if let first = melodicTracks.first {
            return first
        }

        // Ultimate fallback: default emergency track
        return AudioTrack.defaultEmergencyTrack()
    }

    /// Select a generated track with smart rotation based on cry type and age
    private func selectRotatedGeneratedTrack(cryType: CryType, babyAge: Int) -> AudioTrack {
        // Priority order varies by cry type and age
        var prioritizedTypes: [GeneratorType]

        switch cryType {
        case .tired:
            // For tired: prioritize sleep-inducing sounds
            prioritizedTypes = [.lullaby, .musicBox, .softPiano, .ocean, .heartbeat]
        case .pain:
            // For pain: prioritize comfort sounds
            prioritizedTypes = babyAge < 6
                ? [.heartbeat, .womb, .lullaby, .musicBox, .ocean]
                : [.lullaby, .musicBox, .softPiano, .heartbeat, .ocean]
        case .hunger:
            // For hunger: prioritize engaging/distracting sounds
            prioritizedTypes = [.musicBox, .lullaby, .softPiano, .ocean, .heartbeat]
        case .attention:
            // For attention: prioritize melodic, engaging sounds
            prioritizedTypes = [.musicBox, .softPiano, .lullaby, .ocean, .heartbeat]
        default:
            // Default: use age-based selection
            prioritizedTypes = babyAge < 6
                ? [.heartbeat, .lullaby, .musicBox, .womb, .ocean]
                : [.lullaby, .musicBox, .softPiano, .ocean, .heartbeat]
        }

        // Apply session-based rotation: shift the order based on session count
        let rotationOffset = SmartEmergencyQueue.sessionCount % prioritizedTypes.count
        if rotationOffset > 0 {
            let rotated = Array(prioritizedTypes[rotationOffset...]) + Array(prioritizedTypes[..<rotationOffset])
            prioritizedTypes = rotated
        }

        // Select the first type that hasn't been used recently
        for generatorType in prioritizedTypes {
            let track = createGeneratedTrack(for: generatorType)
            if !SmartEmergencyQueue.recentFirstTracks.contains(track.id) {
                return track
            }
        }

        // Fallback: clear recent history and use default
        SmartEmergencyQueue.recentFirstTracks.removeAll()
        return AudioTrack.defaultEmergencyTrack()
    }

    /// Create a generated track for a specific generator type
    private func createGeneratedTrack(for type: GeneratorType) -> AudioTrack {
        // Use stable UUIDs based on generator type for tracking
        let stableId = UUID(uuidString: "E7744FB8-6D21-4364-\(String(format: "%04X", type.hashValue & 0xFFFF))-000000000001") ?? UUID()

        return AudioTrack(
            id: stableId,
            title: type.rawValue,
            artist: "Lulla",
            category: type.category,
            language: nil,
            duration: 300.0,
            ageRangeMin: type.optimalAgeRange.lowerBound,
            ageRangeMax: type.optimalAgeRange.upperBound,
            optimalAgeMonths: Array(type.optimalAgeRange),
            tempoBPM: 60,
            calmingScore: type.calmingScore,
            isPremium: false,
            isDownloaded: true,
            audioSourceType: .generated,
            generatorType: type,
            fileName: nil,
            fileExtension: nil,
            streamURL: nil,
            serverId: "generated-\(type.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))",
            artworkURL: nil,
            isLocked: false
        )
    }

    /// Record that a track was used as the first track (for rotation)
    private func recordFirstTrackUsed(_ trackId: UUID) {
        SmartEmergencyQueue.recentFirstTracks.insert(trackId, at: 0)
        if SmartEmergencyQueue.recentFirstTracks.count > SmartEmergencyQueue.maxRecentFirstTracks {
            SmartEmergencyQueue.recentFirstTracks.removeLast()
        }
    }

    // MARK: - Ambient Playlist Mode (PROACTIVE - No Cry Detection Required!)

    /// Build an AMBIENT playlist that starts IMMEDIATELY - no cry detection needed
    /// Uses ONLY REAL library tracks - NO generated noise (fan, pink, brown, white noise)
    /// This is for parents who want soothing music playing continuously while monitoring
    ///
    /// CRITICAL: This replaces the old Fan/Brown/Pink noise approach with REAL MUSIC:
    /// - Classical music (Brahms, Mozart, Chopin)
    /// - Lullabies (real recordings, not synthesized)
    /// - Instrumental (harp, piano, guitar)
    /// - Nature sounds (ocean, river - NOT rain/thunder)
    func buildAmbientPlaylist(
        babyAge: Int,
        language: String = "en",
        maxTracks: Int = 30
    ) async -> [AudioTrack] {
        print("[SmartQueue] 🎵 Building AMBIENT playlist (REAL tracks only!) age=\(babyAge)mo")

        self.babyAge = babyAge
        self.isAmbientMode = true
        self.currentPlaylistMode = .ambient  // Set mode for smart selection
        self.modeName = "Ambient Soothing"
        self.cryType = .general // Ambient mode is not cry-specific

        // Get ONLY real tracks from library - NO generated sounds!
        let realTracks = await getAmbientLibraryTracks(
            babyAge: babyAge,
            language: language,
            maxCount: maxTracks
        )

        // Set queue metadata for ambient mode
        self.queueName = "Ambient Soothing"
        self.queueDescription = "Continuous calming music for your \(babyAge < 12 ? "baby" : "toddler")"

        print("[SmartQueue] 🎵 Built ambient playlist: \(realTracks.count) REAL tracks (no generated noise!)")
        return realTracks
    }

    /// Get tracks suitable for ambient/continuous playback
    /// EXCLUDES: All generated sounds, harsh white noise, mechanical sounds
    /// INCLUDES: Classical, lullabies, instrumental, gentle nature (ocean, river, birds), fairy tales
    private func getAmbientLibraryTracks(
        babyAge: Int,
        language: String,
        maxCount: Int
    ) async -> [AudioTrack] {
        let allTracks = contentLibrary.allTracks

        print("[SmartQueue] 🔍 Filtering from \(allTracks.count) total tracks")

        // Filter for ambient-suitable REAL tracks only
        let suitableTracks = allTracks.filter { track in
            // MUST be bundled or streamed - NOT generated!
            guard track.audioSourceType == .bundled || track.audioSourceType == .streamed else {
                return false
            }

            // Age appropriate
            guard track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge else {
                return false
            }

            // Not locked
            guard !track.isLocked else { return false }

            // AMBIENT CATEGORIES - include ALL calming content categories
            // NOTE: This now includes fairyTales (english/russian stories are calming!)
            // CRITICAL: Include ALL calming categories from library!
            let ambientCategories: Set<AudioCategory> = [
                .classicalMusic,   // 116 tracks - Brahms, Mozart, etc.
                .lullabies,        // 30 tracks - Dedicated lullaby category!
                .instrumental,     // 2 tracks - Acoustic, harp, piano
                .ambient,          // 42 tracks - Calming ambient music!
                .childrenSongs,    // 14 tracks - Gentle children's songs
                .natureSounds,     // 56 tracks - Ocean, river, birds (not rain/thunder!)
                .fairyTales,       // 82 tracks - Stories are calming for older babies
            ]

            guard ambientCategories.contains(track.category) else {
                return false
            }

            // EXCLUDE harsh/scary nature sounds
            if track.category == .natureSounds {
                let scaryKeywords = ["rain", "thunder", "storm", "wind", "vacuum", "hair dryer", "washing"]
                let titleLower = track.title.lowercased()
                if scaryKeywords.contains(where: { titleLower.contains($0) }) {
                    return false
                }
            }

            // EXCLUDE ALL white noise, generated sounds, and harsh sounds by title
            // COMPREHENSIVE BAN LIST - same as emergency mode!
            let bannedKeywords: Set<String> = [
                "white noise", "pink noise", "brown noise", "grey noise", "blue noise",
                "pure white", "pure pink", "pure brown",
                "fan", "washer", "washing machine", "vacuum", "hair dryer",
                "rain", "thunder", "storm", "wind", "traffic",
                "airplane", "train", "car engine", "motor",
                "shush", "shushing", "womb", "heartbeat",
            ]
            let titleLower = track.title.lowercased()
            for keyword in bannedKeywords {
                if titleLower.contains(keyword) {
                    return false
                }
            }

            // Language filtering for fairy tales
            if track.category == .fairyTales {
                // For fairy tales, respect user's language preference
                if let trackLang = track.language {
                    // If user's language is Russian, include Russian stories
                    // If user's language is English (or default), include English stories
                    // Allow matching language or English as fallback
                    if trackLang.code != language && trackLang != .english {
                        return false
                    }
                }
            }

            return true
        }

        print("[SmartQueue] 🎵 Found \(suitableTracks.count) suitable REAL tracks")

        // Score and sort by calming effectiveness
        let scoredTracks = suitableTracks.map { track -> (track: AudioTrack, score: Double) in
            var score = track.calmingScore

            // BOOST different categories for ambient mode
            switch track.category {
            case .classicalMusic:
                score += 0.30  // Classical is proven most effective
            case .instrumental:
                score += 0.25  // Ambient/acoustic very calming
            case .childrenSongs:
                score += 0.22  // Lullabies are great
            case .natureSounds:
                // Only ocean/river/birds get boost (gentle sounds)
                let titleLower = track.title.lowercased()
                if titleLower.contains("ocean") || titleLower.contains("wave") {
                    score += 0.20
                } else if titleLower.contains("river") || titleLower.contains("stream") || titleLower.contains("brook") {
                    score += 0.18
                } else if titleLower.contains("bird") || titleLower.contains("forest") {
                    score += 0.15
                } else {
                    score += 0.10  // Other nature sounds
                }
            case .fairyTales:
                // Fairy tales are engaging but calming
                score += 0.15
                // Boost for older babies who can appreciate stories
                if babyAge >= 12 {
                    score += 0.10
                }
            default:
                break
            }

            // Age-specific boost
            if track.isOptimalFor(ageMonths: babyAge) {
                score += 0.10
            }

            return (track, min(1.0, score))
        }

        // Sort by score and take top tracks
        let sortedTracks = scoredTracks
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { $0.track }

        // Shuffle slightly for variety but keep high-scoring ones at front
        var result = Array(sortedTracks)
        if result.count > 5 {
            // Keep top 5 in place (best tracks), shuffle the rest for variety
            let top5 = Array(result.prefix(5))
            var rest = Array(result.dropFirst(5))
            rest.shuffle()
            result = top5 + rest
        }

        print("[SmartQueue] 🎵 Selected \(result.count) ambient tracks:")
        for (index, track) in result.prefix(10).enumerated() {
            print("  \(index + 1). \(track.title) [\(track.category.rawValue)] - \(track.audioSourceType)")
        }

        return result
    }

    /// Start ambient playlist immediately (called when monitoring begins)
    func startAmbientMode(babyAge: Int, language: String = "en") async {
        print("[SmartQueue] 🚀 Starting AMBIENT MODE - immediate playback!")

        let tracks = await buildAmbientPlaylist(
            babyAge: babyAge,
            language: language,
            maxTracks: 30
        )

        guard !tracks.isEmpty else {
            print("[SmartQueue] ⚠️ No ambient tracks available!")
            return
        }

        await startQueue(tracks: tracks)
        print("[SmartQueue] ✅ Ambient mode active with \(tracks.count) REAL tracks")
    }

    /// Switch from ambient mode to cry-specific mode when cry is detected
    func switchToCrySpecificMode(cryType: CryType, babyAge: Int, language: String = "en") async {
        print("[SmartQueue] 🔄 Switching from ambient to cry-specific mode: \(cryType.rawValue)")

        // Stop current playback
        audioEngine.stop()
        isPlaying = false

        // Build cry-specific queue
        let cryTracks = await buildQueue(
            for: cryType,
            babyAge: babyAge,
            language: language,
            maxTracks: 20
        )

        guard !cryTracks.isEmpty else {
            print("[SmartQueue] ⚠️ No cry-specific tracks, continuing ambient")
            return
        }

        // Start cry-specific queue
        await startQueue(tracks: cryTracks)
        self.isAmbientMode = false
        self.modeName = "Cry Response"

        print("[SmartQueue] ✅ Switched to cry-specific mode: \(cryType.rawValue)")
    }

    // MARK: - Spotify-Style Queue Start (Main Entry Point!)

    /// Start a Spotify-style smart queue - the main entry point for smart playback!
    /// This uses the SpotifyQueueEngine algorithm:
    /// - Starts with 8 tracks selected based on cry stop success, favorites, play counts
    /// - Automatically replenishes to 8 when tracks finish (7→8)
    /// - Uses rotation policy to prevent repetition
    ///
    /// USAGE: Call this instead of `startAmbientMode` or `switchToCrySpecificMode` for
    /// the full Spotify-like experience.
    func startSpotifyMode(
        cryType: CryType,
        babyAge: Int,
        language: String = "en",
        preferredCategories: Set<AudioCategory>? = nil
    ) async {
        print("[SmartQueue] 🎧 Starting SPOTIFY MODE for \(cryType.rawValue)!")

        // Build smart queue using Spotify algorithm
        let tracks = await buildSpotifyQueue(
            for: cryType,
            babyAge: babyAge,
            language: language,
            preferredCategories: preferredCategories
        )

        guard !tracks.isEmpty else {
            print("[SmartQueue] ⚠️ No tracks for Spotify mode, falling back to standard queue")
            // Fallback to standard queue
            let fallbackTracks = await buildQueue(
                for: cryType,
                babyAge: babyAge,
                language: language,
                maxTracks: 20
            )
            await startQueue(tracks: fallbackTracks)
            return
        }

        // Enable Spotify-style replenishment
        autoReplenishEnabled = true

        // Start playback
        await startQueue(tracks: tracks)

        print("[SmartQueue] 🎧 Spotify mode active!")
        print("  - \(tracks.count) initial tracks")
        print("  - Auto-replenish: ON (maintains 8 upcoming)")
        print("  - Candidate pool: \(candidatePool.count) tracks")
    }

    /// Switch to Spotify mode from any current state
    /// Stops current playback and starts fresh Spotify-style queue
    func switchToSpotifyMode(cryType: CryType, babyAge: Int, language: String = "en") async {
        print("[SmartQueue] 🔄 Switching to SPOTIFY MODE")

        // Stop current if playing
        if isActive {
            audioEngine.stop()
            isPlaying = false
        }

        // Reset state
        allQueueTracks.removeAll()
        upcomingTracks.removeAll()
        playedTracks.removeAll()
        currentTrack = nil
        currentIndex = 0

        // Start Spotify mode
        await startSpotifyMode(cryType: cryType, babyAge: babyAge, language: language)
    }

    /// Get the current Spotify engine score for a track (for UI display)
    func getTrackScore(_ track: AudioTrack) -> TrackScore {
        return spotifyEngine.getScoreBreakdown(for: track)
    }

    /// Get top recommended tracks based on current scoring (for UI suggestions)
    func getTopRecommendations(limit: Int = 5) -> [TrackScore] {
        guard !candidatePool.isEmpty else { return [] }

        // Exclude already queued tracks
        let queuedIds = Set(allQueueTracks.map { $0.id })
        let available = candidatePool.filter { !queuedIds.contains($0.id) }

        return spotifyEngine.getTopScoredTracks(from: available, limit: limit)
    }

    /// Start emergency queue playback
    /// MEMORY OPTIMIZATION: Only loads first 3 tracks, queues the rest
    func startQueue(tracks: [AudioTrack]) async {
        guard !tracks.isEmpty else {
            print("[SmartQueue] Cannot start empty queue")
            return
        }

        print("[SmartQueue] Starting queue with \(tracks.count) tracks")

        // Reset state
        allQueueTracks = tracks
        currentIndex = 0
        playedTracks = []
        sessionStartTime = Date()
        sessionDuration = 0
        isActive = true

        // MEMORY OPTIMIZATION: Load only first 3 tracks (prevents 30MB buffer allocation)
        let tracksToLoad = min(maxConcurrentLoadedTracks, tracks.count)
        loadedTracks = Array(tracks.prefix(tracksToLoad))
        queuedTrackIds = tracks.dropFirst(tracksToLoad).map { $0.id }

        print("[SmartQueue] 🧠 Memory optimization: Loaded \(loadedTracks.count) tracks, queued \(queuedTrackIds.count)")

        // Set current and upcoming
        currentTrack = tracks[0]
        updateUpcomingTracks()
        totalTracks = tracks.count

        // Start playback through session manager (emergency priority)
        if let first = currentTrack {
            playbackSession.requestPlayback(track: first, from: .emergencyMode, forceImmediate: true)
            isPlaying = true
        }

        // Start tracking
        startDurationTracking()
    }

    /// Advance to next track
    /// MEMORY OPTIMIZATION: Rotates loaded tracks (remove finished, load next)
    /// SPOTIFY-STYLE: Records play for scoring, replenishes queue to maintain 8 tracks
    func next() async {
        // Guard against calling next() when queue is already stopped/inactive
        guard isActive else {
            print("[SmartQueue] ⚠️ Ignoring next() - queue not active")
            return
        }

        // SPOTIFY-STYLE: Record completed track for scoring algorithm
        if let completedTrack = currentTrack {
            spotifyEngine.recordTrackPlayed(completedTrack)
            print("[SmartQueue] 🎧 Recorded play: \(completedTrack.title)")
        }

        // Guard against empty queue or reaching end
        guard !allQueueTracks.isEmpty, currentIndex < allQueueTracks.count - 1 else {
            print("[SmartQueue] End of queue reached (tracks: \(allQueueTracks.count), index: \(currentIndex))")
            // Stop once - isActive will be set to false to prevent loops
            await stop(wasEffective: nil)
            return
        }

        // Add current to played
        if let current = currentTrack {
            playedTracks.append(current)
        }

        // MEMORY OPTIMIZATION: Rotate loaded tracks
        onTrackEnded()

        currentIndex += 1
        currentTrack = allQueueTracks[currentIndex]
        updateUpcomingTracks()

        // SPOTIFY-STYLE: Replenish queue to maintain 8 upcoming tracks
        // When we go from 8 to 7, add 1 more track
        replenishQueueIfNeeded()

        // Crossfade to next
        if let next = currentTrack {
            do {
                try await audioEngine.crossfade(to: next, duration: 2.0)
                // CRITICAL FIX: Reset currentTime to prevent timeline flickering
                // This ensures UI shows correct time for new track
                audioEngine.currentTime = 0
            } catch {
                // Fallback to immediate play
                audioEngine.playImmediateWithoutFade(track: next)
                audioEngine.currentTime = 0
            }
        }

        print("[SmartQueue] Advanced to track \(currentIndex + 1)/\(totalTracks): \(currentTrack?.title ?? "Unknown")")
        print("[SmartQueue] 🧠 Loaded: \(loadedTracks.count), Queued: \(queuedTrackIds.count), Upcoming: \(upcomingTracks.count)")
    }

    /// Handle track completion: remove finished track, load next from queue
    /// MEMORY OPTIMIZATION: Keeps only 3 tracks loaded at a time
    private func onTrackEnded() {
        // Remove first loaded track (the one that just finished)
        if !loadedTracks.isEmpty {
            let finished = loadedTracks.removeFirst()
            print("[SmartQueue] 🗑️ Unloaded finished track: \(finished.title)")
        }

        // Load next track from queued IDs if available
        if !queuedTrackIds.isEmpty {
            let nextId = queuedTrackIds.removeFirst()

            // Find the track in allQueueTracks
            if let nextTrack = allQueueTracks.first(where: { $0.id == nextId }) {
                loadedTracks.append(nextTrack)
                print("[SmartQueue] ✅ Loaded next track: \(nextTrack.title)")
            }
        }

        // Verify we maintain the 3-track limit
        assert(loadedTracks.count <= maxConcurrentLoadedTracks,
               "Memory leak: loaded tracks (\(loadedTracks.count)) exceeds limit (\(maxConcurrentLoadedTracks))")
    }

    /// Skip to previous track
    func previous() async {
        guard currentIndex > 0 else {
            print("[SmartQueue] Already at first track")
            return
        }

        currentIndex -= 1
        currentTrack = allQueueTracks[currentIndex]

        // Remove from played if present
        if !playedTracks.isEmpty {
            playedTracks.removeLast()
        }

        updateUpcomingTracks()

        if let track = currentTrack {
            playbackSession.requestPlayback(track: track, from: .emergencyMode, forceImmediate: true)
            // CRITICAL FIX: Reset currentTime to prevent timeline flickering
            audioEngine.currentTime = 0
            isPlaying = true  // Ensure isPlaying is synced with actual playback
        }
    }

    /// Skip to specific track in queue
    /// CRITICAL FIX: Now replenishes queue to maintain 8 items after skipping
    func skipTo(index: Int) async {
        guard index >= 0 && index < allQueueTracks.count else { return }

        // Add all skipped to played
        while currentIndex < index {
            if currentIndex < allQueueTracks.count {
                playedTracks.append(allQueueTracks[currentIndex])
            }
            currentIndex += 1
        }

        currentTrack = allQueueTracks[currentIndex]
        updateUpcomingTracks()

        // SPOTIFY-STYLE: Replenish queue to maintain 8 upcoming tracks
        // When user skips to track 7, we go from 8 upcoming to 1 upcoming
        // Auto-replenish adds 7 more tracks to restore 8 upcoming
        replenishQueueIfNeeded()

        print("[SmartQueue] 🎯 Skipped to track \(index + 1), upcoming: \(upcomingTracks.count)")

        if let track = currentTrack {
            playbackSession.requestPlayback(track: track, from: .emergencyMode, forceImmediate: true)
            // CRITICAL FIX: Reset currentTime to prevent timeline flickering
            audioEngine.currentTime = 0
            isPlaying = true  // Ensure isPlaying is synced with actual playback
        }
    }

    /// Pause/resume playback
    func togglePlayPause() {
        if isPlaying {
            audioEngine.pause()
            isPlaying = false
        } else {
            // CRITICAL FIX: Check if there's actually audio to resume
            // If audioEngine has no current track or is stopped, we need to START playback, not resume
            let hasActiveAudio = audioEngine.playbackState == .paused ||
                                 audioEngine.playbackState == .playing ||
                                 audioEngine.currentTrack != nil

            if hasActiveAudio {
                // Resume existing playback
                audioEngine.resume()
            } else if let track = currentTrack {
                // No active audio - start playback from current track
                print("[SmartQueue] No active audio to resume - starting playback of: \(track.title)")
                playbackSession.requestPlayback(track: track, from: .emergencyMode, forceImmediate: true)
            }
            isPlaying = true
        }
    }

    /// Play a specific track immediately (for quick suggestions or queue selection)
    /// Used when user taps on a suggested track or selects a track from the queue
    /// CRITICAL FIX: Now maintains full 8-item queue after selection
    func playTrackImmediately(_ track: AudioTrack) async {
        print("[SmartQueue] Playing track immediately: \(track.title)")

        // Check if this track is in the existing queue
        if let trackIndex = allQueueTracks.firstIndex(where: { $0.id == track.id }) {
            // Track is in queue - skip to it (maintains full queue)
            print("[SmartQueue] 🎯 Track found in queue at position \(trackIndex + 1), skipping to it")
            await skipTo(index: trackIndex)
            return
        }

        // Track is NOT in queue (e.g., from quick suggestions)
        // Add current to played if exists
        if let current = currentTrack {
            playedTracks.append(current)
        }

        // Insert the new track at current position
        currentTrack = track

        // If queue is active, insert track into allQueueTracks and update upcoming
        if isActive && !allQueueTracks.isEmpty {
            // Insert at current position + 1
            allQueueTracks.insert(track, at: currentIndex + 1)
            // Update index to point to new track
            currentIndex += 1
            // Update upcoming tracks display
            updateUpcomingTracks()
            // Replenish to maintain 8 items
            replenishQueueIfNeeded()
            print("[SmartQueue] ✅ Inserted track into queue, upcoming: \(upcomingTracks.count)")
        }

        // Play through session manager with emergency priority
        // Use forceImmediate for instant playback in emergency situations
        playbackSession.requestPlayback(track: track, from: .emergencyMode, forceImmediate: true)

        isPlaying = true
    }

    // MARK: - Dynamic Queue Reordering

    /// Boost a track to play next (user indicated it might help)
    /// This is called when user sees a suggestion and wants to try it sooner
    func boostTrackToPlayNext(_ track: AudioTrack) {
        guard isActive else { return }

        // Find the track in upcoming and move it to position 1 (right after current)
        if let index = upcomingTracks.firstIndex(where: { $0.id == track.id }) {
            let boostedTrack = upcomingTracks.remove(at: index)
            upcomingTracks.insert(boostedTrack, at: 0)

            // Also update allQueueTracks
            if let fullIndex = allQueueTracks.firstIndex(where: { $0.id == track.id }),
               fullIndex > currentIndex + 1 {
                let trackToMove = allQueueTracks.remove(at: fullIndex)
                allQueueTracks.insert(trackToMove, at: currentIndex + 1)
            }

            print("[SmartQueue] ⬆️ Boosted \(track.title) to play next")
        } else if !allQueueTracks.contains(where: { $0.id == track.id }) {
            // Track not in queue - add it as next
            allQueueTracks.insert(track, at: currentIndex + 1)
            updateUpcomingTracks()
            totalTracks = allQueueTracks.count
            print("[SmartQueue] ➕ Added \(track.title) to play next")
        }
    }

    /// Demote a track (skip it for now, user doesn't want it)
    /// Moves the track to the end of the queue
    func demoteTrack(_ track: AudioTrack) {
        guard isActive else { return }

        // Find and move to end
        if let index = allQueueTracks.firstIndex(where: { $0.id == track.id }),
           index > currentIndex {
            let demotedTrack = allQueueTracks.remove(at: index)
            allQueueTracks.append(demotedTrack)
            updateUpcomingTracks()
            print("[SmartQueue] ⬇️ Demoted \(track.title) to end of queue")
        }
    }

    /// Real-time effectiveness feedback - adjust queue based on baby's response
    /// Call this when cry detection indicates the baby is calming down or escalating
    func adjustQueueForEffectiveness(isCalmingDown: Bool) {
        guard isActive, let current = currentTrack else { return }

        if isCalmingDown {
            // Baby is calming! Record this track as effective
            EffectivenessManager.shared.recordHelped(
                track: current,
                cryType: cryType,
                playDuration: sessionDuration
            )
            print("[SmartQueue] 😊 Baby calming - recorded effectiveness for: \(current.title)")

            // If we have similar tracks in the queue, boost them
            boostSimilarTracks(to: current)
        } else {
            // Baby still crying - this track might not be working
            // If we've been on this track for >45 seconds, suggest skipping
            let trackDuration = audioEngine.currentTime
            if trackDuration > 45 {
                print("[SmartQueue] 😢 Track not effective after \(Int(trackDuration))s - consider trying next")
                // Don't auto-skip, but the UI can show a suggestion
            }
        }
    }

    /// Boost tracks similar to an effective one
    private func boostSimilarTracks(to effectiveTrack: AudioTrack) {
        // Find tracks with same category or generator type
        let similarIndices = allQueueTracks.enumerated().compactMap { index, track -> Int? in
            guard index > currentIndex else { return nil }

            // Same category
            if track.category == effectiveTrack.category { return index }

            // Same generator type
            if let effectiveGen = effectiveTrack.generatorType,
               let trackGen = track.generatorType,
               effectiveGen == trackGen {
                return index
            }

            // Same artist (for library tracks)
            if track.artist == effectiveTrack.artist && track.artist != "Lulla" {
                return index
            }

            return nil
        }

        // Move similar tracks closer (but not all the way to front)
        for (offset, index) in similarIndices.prefix(2).enumerated() {
            let targetIndex = currentIndex + 2 + offset // Put after next track
            if index > targetIndex {
                let track = allQueueTracks.remove(at: index)
                allQueueTracks.insert(track, at: targetIndex)
            }
        }

        if !similarIndices.isEmpty {
            updateUpcomingTracks()
            print("[SmartQueue] 🔄 Boosted \(similarIndices.count) similar tracks")
        }
    }

    /// Get smart suggestions for the user based on current context
    /// Returns tracks that might work better based on effectiveness data
    func getSmartSuggestions(limit: Int = 3) -> [AudioTrack] {
        let effectivenessManager = EffectivenessManager.shared

        // Get tracks that have worked for this cry type
        var suggestions: [AudioTrack] = []

        // 1. Top effective tracks for this cry type
        let effective = effectivenessManager.getTopEffectiveTracks(limit: 2, cryType: cryType)
        for track in effective where track.id != currentTrack?.id {
            suggestions.append(track)
        }

        // 2. A generated track option (for variety)
        if suggestions.count < limit {
            let generatedOptions: [GeneratorType] = [.lullaby, .musicBox, .softPiano, .ocean]
            for genType in generatedOptions {
                let genTrack = createGeneratedTrack(for: genType)
                if genTrack.id != currentTrack?.id && !suggestions.contains(where: { $0.id == genTrack.id }) {
                    suggestions.append(genTrack)
                    break
                }
            }
        }

        // 3. Fill with top upcoming tracks
        for track in upcomingTracks.prefix(limit - suggestions.count) {
            if !suggestions.contains(where: { $0.id == track.id }) {
                suggestions.append(track)
            }
        }

        return Array(suggestions.prefix(limit))
    }

    /// Stop queue and record effectiveness
    func stop(wasEffective: Bool?) async {
        // Prevent multiple stop calls
        guard isActive else {
            print("[SmartQueue] ⚠️ Already stopped, ignoring stop request")
            return
        }

        print("[SmartQueue] Stopping queue (effective: \(wasEffective?.description ?? "unknown"))")

        // Mark as inactive FIRST to prevent any callbacks from re-triggering
        isActive = false
        isPlaying = false

        playbackSession.stopPlayback(from: .emergencyMode)

        // Record effectiveness if provided
        if let effective = wasEffective, currentTrack != nil {
            recordEffectiveness(effective: effective)
        }

        // Reset
        currentTrack = nil
        upcomingTracks = []
        playedTracks = []
        allQueueTracks = []
        currentIndex = 0
        totalTracks = 0
        sessionDuration = 0
        sessionStartTime = nil
    }

    // MARK: - AI-POWERED SMART Track Selection (Learning Algorithm!)

    /// Track recently played tracks to avoid repetition
    private static var recentlyPlayedTrackIds: [UUID] = []
    private static let maxRecentlyPlayed = 30

    /// Record a track was played for recency tracking
    private func recordTrackPlayed(_ trackId: UUID) {
        SmartEmergencyQueue.recentlyPlayedTrackIds.insert(trackId, at: 0)
        if SmartEmergencyQueue.recentlyPlayedTrackIds.count > SmartEmergencyQueue.maxRecentlyPlayed {
            SmartEmergencyQueue.recentlyPlayedTrackIds.removeLast()
        }
    }

    /// Get AI-powered SMART melodic tracks using:
    /// 1. Effectiveness history (what worked for THIS baby)
    /// 2. Favorites (tracks user loves)
    /// 3. Category rotation (mix Classical, Instrumental, Children's Songs)
    /// 4. Recency penalty (don't repeat same tracks too often)
    /// 5. Cry-type matching (different cries need different music)
    ///
    /// BANNED: White noise, pink noise, brown noise, fan, washer, vacuum, rain, thunder
    private func getMelodicTracksForCryType(
        cryType: CryType,
        babyAge: Int,
        language: String,
        maxCount: Int,
        preferredCategories: Set<AudioCategory>? = nil
    ) async -> [AudioTrack] {
        let allTracks = contentLibrary.allTracks
        let effectivenessManager = EffectivenessManager.shared
        let favoritesManager = FavoritesManager.shared

        if let categories = preferredCategories, !categories.isEmpty {
            let categoryNames = categories.map { $0.rawValue }.sorted().joined(separator: " + ")
            print("[SmartQueue] 🧠 AI-POWERED track selection FILTERED BY: \(categoryNames), age=\(babyAge)mo")
        } else {
            print("[SmartQueue] 🧠 AI-POWERED track selection for \(cryType.rawValue), age=\(babyAge)mo")
        }

        // Get favorites and effective tracks
        let favoriteTrackIds = Set(favoritesManager.favoriteTracks)
        let effectiveTrackIds = Set(effectivenessManager.getTopEffectiveTrackIds(limit: 20, cryType: cryType))
        let recentlyPlayedIds = Set(SmartEmergencyQueue.recentlyPlayedTrackIds)

        print("[SmartQueue] 📊 Data: \(favoriteTrackIds.count) favorites, \(effectiveTrackIds.count) effective, \(recentlyPlayedIds.count) recent")

        // MELODIC categories - use preferred categories if provided, otherwise all melodic categories
        let melodicCategories: Set<AudioCategory>
        if let categories = preferredCategories, !categories.isEmpty {
            melodicCategories = categories
            let categoryNames = categories.map { $0.rawValue }.sorted().joined(separator: " + ")
            print("[SmartQueue] 🎯 Using selected categories: \(categoryNames)")
        } else {
            // AI Default: Classical + Instrumental + Ambient + Nature
            // NOTE: EXCLUDE .lullabies from default playlist - users find them less effective for emergency calming!
            // Lullabies are available as explicit category selection if user wants them.
            // NOTE: Include .ambient - 42 calming tracks in library!
            melodicCategories = [
                .classicalMusic,    // 116 tracks - Brahms, Mozart, Bach, Chopin - BEST!
                .instrumental,      // 2 tracks - Piano, guitar, harp music
                .ambient,           // 42 tracks - very calming background music
                .natureSounds,      // 56 tracks - Ocean, river, birds (gentle nature)
            ]
            print("[SmartQueue] 🎯 Using AI default categories: Classical + Instrumental + Ambient + Nature (NO lullabies)")
        }

        // BANNED keywords in track titles - these are SCARY or HARSH
        let bannedKeywords: Set<String> = [
            "white noise", "pink noise", "brown noise", "grey noise", "blue noise",
            "fan", "washer", "washing machine", "vacuum", "hair dryer",
            "rain", "thunder", "storm", "wind", "traffic",
            "airplane", "train", "car engine", "motor",
            "shush", "shushing", "womb", "heartbeat",
        ]

        let suitableTracks = allTracks.filter { track in
            // MUST be real audio (bundled or streamed), NOT generated!
            guard track.audioSourceType == .bundled || track.audioSourceType == .streamed else {
                return false
            }

            // Age appropriate
            guard track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge else {
                return false
            }

            // Not locked
            guard !track.isLocked else { return false }

            // Check category - melodic only!
            let isMelodicCategory = melodicCategories.contains(track.category)
            let isGentleNature = track.category == .natureSounds

            guard isMelodicCategory || isGentleNature else {
                return false
            }

            // CRITICAL: Check for banned keywords in title!
            let titleLower = track.title.lowercased()
            for keyword in bannedKeywords {
                if titleLower.contains(keyword) {
                    return false
                }
            }

            // For nature sounds, EXCLUDE scary ones but ALLOW all others
            // (was too strict - most library tracks don't have "ocean"/"bird" in title)
            if track.category == .natureSounds {
                let scaryNatureKeywords = ["thunder", "storm", "lightning", "wind", "rain"]
                let hasScaryKeyword = scaryNatureKeywords.contains { titleLower.contains($0) }
                if hasScaryKeyword {
                    return false
                }
            }

            // Language filtering for fairy tales
            if track.category == .fairyTales {
                if let trackLang = track.language {
                    if trackLang.code != language && trackLang != .english {
                        return false
                    }
                }
            }

            return true
        }

        print("[SmartQueue] 🎵 Found \(suitableTracks.count) suitable melodic tracks")

        // AI-POWERED scoring with learning!
        let scoredTracks = suitableTracks.map { track -> (track: AudioTrack, score: Double) in
            var score = track.calmingScore

            // ⭐ FAVORITES BOOST - User's favorite tracks get HIGH priority!
            if favoriteTrackIds.contains(track.id) {
                score += 0.40
                print("[SmartQueue] ⭐ FAVORITE boost: \(track.title)")
            }

            // 🧠 EFFECTIVENESS BOOST - Tracks that WORKED for this baby!
            if effectiveTrackIds.contains(track.id) {
                let effectivenessScore = effectivenessManager.getEffectivenessScore(for: track.id) ?? 0.5
                score += effectivenessScore * 0.35  // Up to 35% boost
                print("[SmartQueue] 🧠 EFFECTIVE boost (\(Int(effectivenessScore * 100))%): \(track.title)")
            }

            // ⏰ RECENCY PENALTY - Don't repeat same tracks too often!
            if recentlyPlayedIds.contains(track.id) {
                if let index = SmartEmergencyQueue.recentlyPlayedTrackIds.firstIndex(of: track.id) {
                    let recencyPenalty = Double(SmartEmergencyQueue.maxRecentlyPlayed - index) / Double(SmartEmergencyQueue.maxRecentlyPlayed) * 0.30
                    score -= recencyPenalty
                }
            }

            // 🎵 CATEGORY scoring for melodic content
            score += calculateCategoryScore(track: track, cryType: cryType, babyAge: babyAge)

            return (track, min(1.5, max(0.0, score)))
        }

        // Sort by score (best first)
        let sortedTracks = scoredTracks.sorted { $0.score > $1.score }

        // 🔄 CATEGORY ROTATION - Mix different categories for variety!
        let finalTracks = applyRotationPolicy(tracks: sortedTracks.map { $0.track }, maxCount: maxCount)

        // Record what we're playing
        for track in finalTracks {
            recordTrackPlayed(track.id)
        }

        // Update queue name based on what's in the queue
        updateQueueNameFromSelection(tracks: finalTracks, cryType: cryType)

        print("[SmartQueue] 🎵 Selected \(finalTracks.count) tracks with AI rotation:")
        for (i, track) in finalTracks.prefix(8).enumerated() {
            let isFav = favoriteTrackIds.contains(track.id) ? "⭐" : ""
            let isEff = effectiveTrackIds.contains(track.id) ? "🧠" : ""
            print("  \(i + 1). \(track.title) [\(track.category.rawValue)] \(isFav)\(isEff)")
        }

        return finalTracks
    }

    /// Calculate category-based score for a track
    private func calculateCategoryScore(track: AudioTrack, cryType: CryType, babyAge: Int) -> Double {
        var score: Double = 0

        switch track.category {
        case .classicalMusic:
            score += 0.35
            if cryType == .tired { score += 0.15 }

            let titleLower = track.title.lowercased()
            if titleLower.contains("brahms") || titleLower.contains("lullaby") { score += 0.10 }
            if titleLower.contains("mozart") { score += 0.08 }
            if titleLower.contains("bach") || titleLower.contains("chopin") { score += 0.06 }

        case .instrumental:
            score += 0.32
            if cryType == .tired || cryType == .discomfort { score += 0.12 }

            let titleLower = track.title.lowercased()
            if titleLower.contains("piano") { score += 0.10 }
            if titleLower.contains("guitar") || titleLower.contains("ukulele") { score += 0.06 }

        case .childrenSongs:
            score += 0.28
            if cryType == .hunger || cryType == .attention { score += 0.12 }

            let titleLower = track.title.lowercased()
            if titleLower.contains("lullaby") || titleLower.contains("колыбельная") { score += 0.12 }

        case .natureSounds:
            score += 0.22
            let titleLower = track.title.lowercased()
            if titleLower.contains("ocean") || titleLower.contains("wave") { score += 0.08 }

        case .fairyTales:
            score += 0.18
            if cryType == .attention { score += 0.15 }
            if babyAge < 6 { score -= 0.20 }

        default:
            break
        }

        // Cry-type specific adjustments
        if cryType == .tired, let tempo = track.tempoBPM, tempo < 80 {
            score += 0.10
        }

        // Age optimization
        if track.isOptimalFor(ageMonths: babyAge) {
            score += 0.08
        }

        return score
    }

    /// Apply rotation policy to mix categories and avoid monotony
    /// NOW WITH RANDOMIZATION: Shuffles tracks within categories for variety!
    private func applyRotationPolicy(tracks: [AudioTrack], maxCount: Int) -> [AudioTrack] {
        guard tracks.count > 3 else { return Array(tracks.prefix(maxCount)) }

        // Group by category
        var byCategory: [AudioCategory: [AudioTrack]] = [:]
        for track in tracks {
            byCategory[track.category, default: []].append(track)
        }

        // RANDOMIZATION: Shuffle tracks within each category (keeping top 2 for quality)
        // This ensures different tracks are selected each session!
        for (category, categoryTracks) in byCategory {
            if categoryTracks.count > 2 {
                // Keep top 2 highest-scored, shuffle the rest
                let top2 = Array(categoryTracks.prefix(2))
                var rest = Array(categoryTracks.dropFirst(2))
                rest.shuffle()
                byCategory[category] = top2 + rest
            }
        }

        // Rotation order: Classical → Instrumental → Children's → Nature → Fairy Tales
        // RANDOMIZATION: Occasionally shuffle the rotation order for variety
        var rotationOrder: [AudioCategory] = [
            .classicalMusic, .instrumental, .childrenSongs, .natureSounds, .fairyTales
        ]

        // 30% chance to shuffle rotation order (keeps things fresh across sessions)
        if Double.random(in: 0...1) < 0.3 {
            rotationOrder.shuffle()
            print("[SmartQueue] 🔀 Shuffled category rotation order for variety")
        }

        var result: [AudioTrack] = []
        var categoryIndex = 0
        var usedFromCategory: [AudioCategory: Int] = [:]

        // First 3 tracks: Take from top categories with some randomization
        // RANDOMIZATION: Pick from top 3 tracks in each category (not always the absolute best)
        for category in rotationOrder.prefix(3) {
            if let categoryTracks = byCategory[category], !categoryTracks.isEmpty {
                // Pick randomly from top 3 tracks in category
                let topN = min(3, categoryTracks.count)
                let randomIdx = Int.random(in: 0..<topN)
                let idx = usedFromCategory[category, default: 0]
                let actualIdx = (idx + randomIdx) % categoryTracks.count
                result.append(categoryTracks[actualIdx])
                usedFromCategory[category] = actualIdx + 1
            }
            if result.count >= 3 { break }
        }

        // Remaining tracks: Rotate through categories with randomization
        while result.count < maxCount {
            let category = rotationOrder[categoryIndex % rotationOrder.count]

            if let categoryTracks = byCategory[category] {
                let idx = usedFromCategory[category, default: 0]
                if idx < categoryTracks.count {
                    let track = categoryTracks[idx]
                    if !result.contains(where: { $0.id == track.id }) {
                        result.append(track)
                        usedFromCategory[category] = idx + 1
                    }
                }
            }

            categoryIndex += 1

            // Safety: prevent infinite loop
            if categoryIndex > maxCount * 2 { break }
        }

        // FINAL SHUFFLE: Shuffle tracks after position 5 for extra variety
        // Keeps first 5 tracks stable (best quality), randomizes the rest
        if result.count > 5 {
            let top5 = Array(result.prefix(5))
            var rest = Array(result.dropFirst(5))
            rest.shuffle()
            result = top5 + rest
            print("[SmartQueue] 🔀 Shuffled tracks 6+ for variety")
        }

        return result
    }

    /// Update queue name based on what tracks are selected
    private func updateQueueNameFromSelection(tracks: [AudioTrack], cryType: CryType) {
        // Count categories
        var categoryCount: [AudioCategory: Int] = [:]
        for track in tracks.prefix(5) {
            categoryCount[track.category, default: 0] += 1
        }

        // Find dominant category
        let dominantCategory = categoryCount.max(by: { $0.value < $1.value })?.key

        // Check for favorites or effective tracks
        let hasFavorites = tracks.prefix(3).contains { FavoritesManager.shared.isFavorite(track: $0) }
        let hasEffective = tracks.prefix(3).contains {
            EffectivenessManager.shared.getEffectiveness(for: $0.id) != nil
        }

        // Build dynamic queue name
        var name: String
        if hasFavorites && hasEffective {
            name = "💖 Your Baby's Favorites"
        } else if hasEffective {
            name = "🧠 What Works for Baby"
        } else if hasFavorites {
            name = "⭐ Your Favorites Mix"
        } else {
            // Name based on category
            switch dominantCategory {
            case .classicalMusic:
                name = "🎻 Classical Soothing"
            case .instrumental:
                name = "🎹 Piano & Melody"
            case .childrenSongs:
                name = "🎵 Lullaby Collection"
            case .natureSounds:
                name = "🌊 Gentle Nature"
            case .fairyTales:
                name = "📖 Storytime"
            default:
                name = "🎶 Smart Soothing Mix"
            }
        }

        // Add cry type context
        let cryLabel: String
        switch cryType {
        case .tired: cryLabel = "Sleep Mode"
        case .hunger: cryLabel = "Distraction Mode"
        case .pain: cryLabel = "Comfort Mode"
        case .attention: cryLabel = "Engagement Mode"
        default: cryLabel = "Soothing Mode"
        }

        self.queueName = name
        self.queueDescription = "\(cryLabel) • AI-curated for your baby"
    }

    // MARK: - Legacy Library Track Selection (kept for reference)

    /// Get tracks from local library suitable for cry type
    /// PRIORITIZES: Classical, Lullabies, Instrumental over generated noise
    private func getLibraryTracksForCryType(
        cryType: CryType,
        babyAge: Int,
        language: String,
        maxCount: Int
    ) async -> [AudioTrack] {
        // Get all available tracks from library
        let allTracks = contentLibrary.allTracks

        // Filter by cry suitability
        let suitableTracks = allTracks.filter { track in
            // Age appropriate
            guard track.ageRangeMin <= babyAge && track.ageRangeMax >= babyAge else {
                return false
            }

            // Not locked (premium gate)
            guard !track.isLocked else { return false }

            // Prefer matching language or instrumental
            if let trackLang = track.language {
                if trackLang.code != language && trackLang != .english {
                    // Allow if instrumental (no language dependency)
                    if track.category != .instrumental && track.category != .classicalMusic {
                        return false
                    }
                }
            }

            return true
        }

        // Score by cry suitability using SCIENCE-BASED scoring
        let scoredTracks = suitableTracks.map { track -> (track: AudioTrack, score: Double) in
            let score = calculateScienceBasedTrackScore(track: track, cryType: cryType, babyAge: babyAge)
            return (track, score)
        }

        // Sort by score and take top
        let topTracks = scoredTracks
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { $0.track }

        print("[SmartQueue] 🔬 Science-based selection: \(topTracks.count) tracks")
        for track in topTracks.prefix(5) {
            print("  - \(track.title) (\(track.category.rawValue))")
        }

        return Array(topTracks)
    }

    /// Calculate SCIENCE-BASED track suitability score
    /// Based on peer-reviewed research on infant auditory processing
    private func calculateScienceBasedTrackScore(track: AudioTrack, cryType: CryType, babyAge: Int) -> Double {
        var score = track.calmingScore

        // SCIENCE-BASED: Category priorities from research
        // References: Standley 2002, Rauscher 1993, Shenfield 2003
        switch track.category {
        case .classicalMusic:
            // Mozart Effect + Brahms Lullaby research: 88-95% effective
            score += 0.35
            // Additional bonus for tired/sleep-inducing
            if cryType == .tired { score += 0.15 }

        case .instrumental:
            // Instrumental music reduces cortisol levels (Standley 2002)
            score += 0.30
            if cryType == .tired || cryType == .discomfort { score += 0.1 }

        case .childrenSongs:
            // Lullabies have cross-cultural calming effect (Shenfield 2003)
            score += 0.28
            if cryType == .hunger || cryType == .attention { score += 0.1 }

        case .natureSounds:
            // Ocean/river sounds: 14% reduction in sympathetic activity
            // BUT avoid rain (scary) - only gentle nature sounds
            score += 0.22
            if cryType == .discomfort { score += 0.1 }

        case .fairyTales:
            // Engaging for attention-seeking cries (distraction method)
            score += 0.20
            if cryType == .attention { score += 0.15 }
            // Penalty for tired (too stimulating)
            if cryType == .tired { score -= 0.15 }

        case .ambient:
            // Womb sounds, heartbeat - effective for newborns
            score += 0.25
            if cryType == .tired || cryType == .pain { score += 0.15 }

        case .lullabies:
            // Traditional lullabies - highly effective for sleep
            score += 0.30
            if cryType == .tired { score += 0.20 }

        default:
            break
        }

        // RESEARCH: Cry-type specific bonuses
        switch cryType {
        case .tired:
            // Research: Slow tempo (60-80 BPM) matches resting heart rate
            if let tempo = track.tempoBPM, tempo < 80 {
                score += 0.15
            }
            // Classical/instrumental most effective for sleep (Rauscher 1993)
            if track.category == .classicalMusic || track.category == .instrumental {
                score += 0.10
            }

        case .pain:
            // Research: Familiar, comforting sounds work best (Porter 1988)
            // Classical + heartbeat-like rhythms
            if track.category == .classicalMusic { score += 0.12 }

        case .hunger:
            // Research: Melodic distraction while feeding works
            if track.category == .childrenSongs { score += 0.12 }

        case .attention:
            // Research: Engaging but not overstimulating
            if track.category == .childrenSongs || track.category == .fairyTales {
                score += 0.12
            }

        case .discomfort:
            // Research: Consistent, predictable sounds soothe
            if track.category == .classicalMusic || track.category == .instrumental {
                score += 0.10
            }

        default:
            break
        }

        // Age-appropriate bonus
        if track.isOptimalFor(ageMonths: babyAge) {
            score += 0.10
        }

        // Penalty for newborns hearing complex sounds
        if babyAge < 3 && (track.category == .fairyTales || track.category == .natureSounds) {
            score -= 0.20
        }

        return min(1.0, max(0.0, score))
    }

    // MARK: - Generated Track Building

    /// Build generated sound tracks for variety
    private func buildGeneratedTracks(for cryType: CryType, babyAge: Int, count: Int) -> [AudioTrack] {
        // Use ultra-smart selector to get optimal sounds
        let optimalSounds = ultraSmartSelector.selectOptimalSounds(
            cryType: cryType,
            babyAge: babyAge,
            cryIntensity: 0.5,
            maxSounds: count
        )

        // Convert to AudioTrack objects
        return optimalSounds.map { generatorType in
            AudioTrack(
                title: generatorType.rawValue,
                artist: "Generated Sound",
                category: generatorType.category,
                duration: generatorType.defaultDuration,
                ageRangeMin: generatorType.optimalAgeRange.lowerBound,
                ageRangeMax: generatorType.optimalAgeRange.upperBound,
                calmingScore: generatorType.calmingScore,
                audioSourceType: .generated,
                generatorType: generatorType
            )
        }
    }

    // MARK: - Queue Ordering

    /// Smart order: interleave real and generated, start strong
    private func smartOrderQueue(_ tracks: [AudioTrack]) -> [AudioTrack] {
        let realTracks = tracks.filter { $0.audioSourceType != .generated }
        let generatedTracks = tracks.filter { $0.audioSourceType == .generated }

        var orderedQueue: [AudioTrack] = []

        // Start with best real track
        if let firstReal = realTracks.first {
            orderedQueue.append(firstReal)
        }

        // Alternate: 2 real, 1 generated for variety
        var realIndex = 1
        var genIndex = 0
        var pattern = 0

        while realIndex < realTracks.count || genIndex < generatedTracks.count {
            if pattern < 2 && realIndex < realTracks.count {
                orderedQueue.append(realTracks[realIndex])
                realIndex += 1
                pattern += 1
            } else if genIndex < generatedTracks.count {
                orderedQueue.append(generatedTracks[genIndex])
                genIndex += 1
                pattern = 0
            } else if realIndex < realTracks.count {
                orderedQueue.append(realTracks[realIndex])
                realIndex += 1
            }
        }

        return orderedQueue
    }

    // MARK: - Queue Names

    private func getQueueName(for cryType: CryType) -> String {
        // Always include the cry type in the name so user knows what was detected!
        switch cryType {
        case .tired: return "😴 Tired Baby - Sleep Time"
        case .hunger: return "🍼 Hungry Baby - Comfort & Calm"
        case .pain: return "😢 Pain/Discomfort - Gentle Relief"
        case .discomfort: return "😣 Uncomfortable - Soothing Sounds"
        case .attention: return "👋 Needs Attention - Engaging Melodies"
        case .general: return "👶 Fussy Baby - Universal Calm"
        case .unknown: return "🎵 Smart Soothing"
        }
    }

    private func getQueueDescription(for cryType: CryType, babyAge: Int) -> String {
        let ageDesc = babyAge < 6 ? "newborn" : babyAge < 12 ? "baby" : "toddler"
        switch cryType {
        case .tired: return "Lullabies & gentle sounds for your \(ageDesc)"
        case .hunger: return "Distracting melodies while feeding"
        case .pain: return "Immediate comfort sounds"
        case .discomfort: return "Calming sounds for mild fussiness"
        case .attention: return "Engaging music for curious \(ageDesc)s"
        default: return "Research-backed calming sounds"
        }
    }

    // MARK: - Progress Tracking

    private func updateUpcomingTracks() {
        let remaining = Array(allQueueTracks.dropFirst(currentIndex + 1))
        upcomingTracks = Array(remaining.prefix(maxUpNextCount))
    }

    private func startDurationTracking() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self,
                      self.isActive,
                      let start = self.sessionStartTime else { return }
                self.sessionDuration = Date().timeIntervalSince(start)
                self.progress = self.audioEngine.currentProgress
            }
            .store(in: &cancellables)
    }

    private func setupObservers() {
        // CRITICAL: Sync isPlaying with actual AudioEngine playback state
        // This prevents the "playing but no sound" issue when queue shows as playing but no audio is active
        audioEngine.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, self.isActive else { return }

                switch state {
                case .playing:
                    if !self.isPlaying {
                        self.isPlaying = true
                    }
                case .paused:
                    if self.isPlaying {
                        self.isPlaying = false
                    }
                case .stopped:
                    // When stopped, also reset isPlaying
                    if self.isPlaying {
                        self.isPlaying = false
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // CRITICAL FIX: Also observe currentTrack changes from AudioEngine
        // This ensures the queue's currentTrack stays in sync with actual playback
        audioEngine.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                guard let self = self, self.isActive else { return }

                // If AudioEngine's track is nil but queue thinks it has a track, sync the state
                if track == nil && self.currentTrack != nil {
                    // Only reset if audioEngine truly stopped (not just between tracks)
                    if self.audioEngine.playbackState == .stopped {
                        print("[SmartQueue] 🔧 AudioEngine stopped - resetting queue state")
                        // Don't reset isActive here - let the stop() function handle it properly
                        // Just update the playing state
                        self.isPlaying = false
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for track completion
        NotificationCenter.default.publisher(for: .audioTrackDidFinish)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, self.isActive else {
                        print("[SmartQueue] ⚠️ Ignoring track finish notification - queue not active")
                        return
                    }
                    await self.next()
                }
            }
            .store(in: &cancellables)

        // MEMORY OPTIMIZATION (Increment 0028, Enhanced 0029): Clean up on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("[SmartQueue] ⚠️ Memory warning received - aggressive cleanup")
                await self?.cleanup(aggressive: true)
            }
        }

        // MEMORY OPTIMIZATION (Increment 0028, Enhanced 0029): Respond to MemoryMonitor cleanup requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryCleanupRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let level = notification.userInfo?["level"] as? String {
                    // Use aggressive cleanup for critical and emergency levels
                    let isAggressive = (level == "critical" || level == "emergency")
                    print("[SmartQueue] 🧹 Memory cleanup requested (\(level), aggressive: \(isAggressive))")
                    await self?.cleanup(aggressive: isAggressive)
                }
            }
        }
    }

    // MARK: - Memory Cleanup

    /// Clean up resources to reduce memory footprint during memory warnings
    /// Preserves queue state but releases unnecessary cached data
    /// - Parameter aggressive: If true, performs more aggressive cleanup (for critical/emergency)
    private func cleanup(aggressive: Bool = false) async {
        print("[SmartQueue] 🧹 Starting memory cleanup (aggressive: \(aggressive))...")

        // MEMORY OPTIMIZATION (Increment 0029): Use autoreleasepool for immediate deallocation
        autoreleasepool {
            // Clear played tracks history (no longer needed)
            let playedCount = playedTracks.count
            playedTracks.removeAll()
            if playedCount > 0 {
                print("[SmartQueue] 🧹 Cleared \(playedCount) played tracks from history")
            }

            if aggressive {
                // AGGRESSIVE MODE: Keep only next track, clear everything else

                // Trim upcoming to just 1 track
                let trimmedCount = max(0, upcomingTracks.count - 1)
                if trimmedCount > 0 {
                    upcomingTracks = Array(upcomingTracks.prefix(1))
                    print("[SmartQueue] 🧹 Aggressive trim: kept 1 upcoming track, removed \(trimmedCount)")
                }

                // Clear recently played tracking
                let recentCount = SmartEmergencyQueue.recentlyPlayedTrackIds.count
                SmartEmergencyQueue.recentlyPlayedTrackIds.removeAll()
                if recentCount > 0 {
                    print("[SmartQueue] 🧹 Cleared \(recentCount) recently played track IDs")
                }

                // Clear first track rotation history
                let rotationCount = SmartEmergencyQueue.recentFirstTracks.count
                SmartEmergencyQueue.recentFirstTracks.removeAll()
                if rotationCount > 0 {
                    print("[SmartQueue] 🧹 Cleared \(rotationCount) rotation history entries")
                }

                // Reduce loaded tracks to just 1 (the current)
                if loadedTracks.count > 1 {
                    let removedCount = loadedTracks.count - 1
                    loadedTracks = Array(loadedTracks.prefix(1))
                    print("[SmartQueue] 🧹 Reduced loaded tracks: kept 1, removed \(removedCount)")
                }

                // If queue is inactive, clear everything
                if !isActive {
                    let queueCount = allQueueTracks.count
                    allQueueTracks.removeAll()
                    loadedTracks.removeAll()
                    queuedTrackIds.removeAll()
                    upcomingTracks.removeAll()
                    print("[SmartQueue] 🧹 Cleared all \(queueCount) queued tracks (queue inactive)")
                }
            } else {
                // NORMAL MODE: Keep next 3 tracks

                // Trim upcoming tracks to minimum (keep next 3)
                let trimmedCount = max(0, upcomingTracks.count - 3)
                if trimmedCount > 0 {
                    upcomingTracks = Array(upcomingTracks.prefix(3))
                    print("[SmartQueue] 🧹 Trimmed \(trimmedCount) upcoming tracks (kept next 3)")
                }

                // Clear all queue tracks cache if queue inactive
                if !isActive {
                    let queueCount = allQueueTracks.count
                    allQueueTracks.removeAll()
                    loadedTracks.removeAll()
                    queuedTrackIds.removeAll()
                    print("[SmartQueue] 🧹 Cleared \(queueCount) queued tracks (queue inactive)")
                }
            }
        }

        // DON'T reset Combine subscriptions on every cleanup - this can cause issues
        // Only reset if truly needed (subscriptions will be recreated naturally)

        print("[SmartQueue] ✅ Memory cleanup complete")
    }

    // MARK: - Effectiveness Recording

    private func recordEffectiveness(effective: Bool) {
        // Record all played tracks effectiveness
        for track in playedTracks {
            if let generator = track.generatorType {
                ultraSmartSelector.recordEffectiveness(
                    sound: generator,
                    cryType: cryType,
                    wasEffective: effective,
                    calmingTimeSeconds: Int(sessionDuration)
                )
            }
        }

        // Record current track too
        if let current = currentTrack, let generator = current.generatorType {
            ultraSmartSelector.recordEffectiveness(
                sound: generator,
                cryType: cryType,
                wasEffective: effective,
                calmingTimeSeconds: Int(sessionDuration)
            )
        }
    }

    // MARK: - Computed Properties

    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var queueProgress: Double {
        guard totalTracks > 0 else { return 0 }
        return Double(currentIndex) / Double(totalTracks)
    }

    var remainingCount: Int {
        return max(0, totalTracks - currentIndex - 1)
    }

    var hasNext: Bool {
        return currentIndex < allQueueTracks.count - 1
    }

    var hasPrevious: Bool {
        return currentIndex > 0
    }
}

// MARK: - Mock for Testing

extension SmartEmergencyQueue {
    /// Mock instance for testing and previews
    /// NOTE: This replaces the legacy EmergencyQueueManager.mock
    static var mock: SmartEmergencyQueue {
        let queue = SmartEmergencyQueue()
        queue.isActive = true
        queue.currentTrack = AudioTrack(
            title: "Brahms Lullaby",
            artist: "Classical Collection",
            category: .classicalMusic,
            duration: 180,
            calmingScore: 0.9,
            audioSourceType: .bundled
        )
        queue.upcomingTracks = [
            AudioTrack(
                title: "Mozart Sonata K.448",
                artist: "Classical Collection",
                category: .classicalMusic,
                duration: 300,
                calmingScore: 0.92,
                audioSourceType: .streamed,
                streamURL: "https://cdn.example.com/mozart.mp3"
            ),
            AudioTrack(
                title: "Колыбельная (Russian Lullaby)",
                artist: "Russian Folk",
                category: .childrenSongs,
                language: .russian,
                duration: 175,
                calmingScore: 0.88,
                audioSourceType: .bundled
            ),
        ]
        queue.isPlaying = true
        queue.progress = 0.45
        queue.sessionDuration = 120
        queue.queueName = "Smart Soothing"
        queue.queueDescription = "AI-powered calming playlist"
        queue.cryType = .tired
        queue.totalTracks = 10
        queue.currentIndex = 2
        return queue
    }
}
