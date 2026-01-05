//
//  BabyMoodProfile.swift
//  BabyInCarApp
//
//  Comprehensive baby mood and personality profile for the BabyMIM system.
//  Tracks learned preferences, personality traits, patterns, and parent observations.
//

import Foundation

// MARK: - Baby Mood Profile

/// Comprehensive profile that captures everything the AI learns about a specific baby.
/// This is the core data model for personalized soothing recommendations.
struct BabyMoodProfile: Codable, Identifiable {
    let id: UUID
    let babyId: UUID
    let babyName: String
    let birthDate: Date
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Learned Sound Preferences

    /// Effectiveness scores for each sound type (0-1)
    var soundEffectiveness: [String: Double]

    /// Best sounds for each cry type, ordered by effectiveness
    var favoriteSoundsForCryType: [String: [SoundPreference]]

    /// Optimal volume level (0-1) learned from successful soothing
    var optimalVolume: Float

    /// Preferred soothing intensity (gentle vs active)
    var preferredIntensity: SoothingIntensity

    // MARK: - Personality Traits (Inferred from Behavior)

    /// How quickly baby typically responds to soothing (0-1, higher = faster)
    var soothingResponsiveness: Double

    /// Preference for new sounds vs familiar ones (0-1, higher = likes novelty)
    var noveltyPreference: Double

    /// Sensitivity to rhythmic patterns (0-1, higher = more responsive)
    var rhythmSensitivity: Double

    /// Pitch preference (-1 = low, 0 = neutral, 1 = high)
    var pitchPreference: Double

    /// How long baby typically takes to calm (seconds)
    var averageCalmingTime: TimeInterval

    /// Distress tolerance - how long before escalation (seconds)
    var distressTolerance: TimeInterval

    // MARK: - Temporal Patterns

    /// Typical times when baby cries
    var typicalCryingTimes: [TimePattern]

    /// Typical sleep schedule
    var typicalSleepSchedule: [TimePattern]

    /// Mood patterns by time of day
    var moodByTimeOfDay: [TimeOfDay: BabyMood]

    /// Days since patterns were last updated
    var patternLastUpdated: Date

    // MARK: - Parent Observations

    /// Parent-tagged preferences and notes
    var parentObservations: [ParentObservation]

    /// Known triggers that cause crying
    var knownTriggers: [String]

    /// Known comforts that help calm
    var knownComforts: [String]

    /// Special circumstances (teething, growth spurt, etc.)
    var specialCircumstances: [SpecialCircumstance]

    // MARK: - Learning Metadata

    /// Number of soothing sessions recorded
    var totalSessions: Int

    /// Number of successful soothing sessions
    var successfulSessions: Int

    /// Confidence in profile accuracy (0-1, increases with more data)
    var profileConfidence: Double

    /// Version for migration support
    var version: Int

    // MARK: - Initialization

    init(babyId: UUID, babyName: String, birthDate: Date) {
        self.id = UUID()
        self.babyId = babyId
        self.babyName = babyName
        self.birthDate = birthDate
        self.createdAt = Date()
        self.updatedAt = Date()

        // Initialize with neutral defaults
        self.soundEffectiveness = [:]
        self.favoriteSoundsForCryType = [:]
        self.optimalVolume = 0.5
        self.preferredIntensity = .moderate

        // Neutral personality traits
        self.soothingResponsiveness = 0.5
        self.noveltyPreference = 0.5
        self.rhythmSensitivity = 0.5
        self.pitchPreference = 0.0
        self.averageCalmingTime = 60.0
        self.distressTolerance = 120.0

        // Empty patterns (to be learned)
        self.typicalCryingTimes = []
        self.typicalSleepSchedule = []
        self.moodByTimeOfDay = [:]
        self.patternLastUpdated = Date()

        // Empty observations
        self.parentObservations = []
        self.knownTriggers = []
        self.knownComforts = []
        self.specialCircumstances = []

        // Learning metadata
        self.totalSessions = 0
        self.successfulSessions = 0
        self.profileConfidence = 0.1
        self.version = 1
    }

    // MARK: - Computed Properties

    /// Baby's age in months
    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
    }

    /// Baby's age in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
    }

    /// Success rate of soothing sessions
    var successRate: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(successfulSessions) / Double(totalSessions)
    }

    /// Whether we have enough data for reliable predictions
    var hasReliableData: Bool {
        totalSessions >= 5 && profileConfidence >= 0.3
    }

    /// Alias for totalSessions (for UI consistency)
    var totalSoothingSessions: Int { totalSessions }

    /// Learning progress (alias for profileConfidence for UI)
    var learningProgress: Double { profileConfidence }

    /// Voice print quality (placeholder - would come from voice analysis)
    var voicePrintQuality: Double { min(1.0, Double(totalSessions) / 20.0) }

    /// Recent mood score (placeholder calculation)
    var recentMoodScore: Double {
        // Calculate based on recent session success
        guard totalSessions > 0 else { return 5.0 }
        return 5.0 + (successRate * 5.0) // 5-10 range
    }

    /// Learned patterns (list of pattern descriptions)
    var learnedPatterns: [String] {
        var patterns: [String] = []
        if !typicalCryingTimes.isEmpty { patterns.append("Crying patterns") }
        if !typicalSleepSchedule.isEmpty { patterns.append("Sleep schedule") }
        if !knownTriggers.isEmpty { patterns.append("Known triggers") }
        if !knownComforts.isEmpty { patterns.append("Comfort preferences") }
        if !soundEffectiveness.isEmpty { patterns.append("Sound effectiveness") }
        return patterns
    }

    /// Inferred personality traits for UI display
    var inferredPersonality: InferredPersonalityTraits {
        InferredPersonalityTraits(
            soothingResponsiveness: soothingResponsiveness,
            noveltyPreference: noveltyPreference,
            rhythmSensitivity: rhythmSensitivity,
            pitchPreference: pitchPreference
        )
    }

    /// Struct for bundling personality traits
    struct InferredPersonalityTraits {
        let soothingResponsiveness: Double
        let noveltyPreference: Double
        let rhythmSensitivity: Double
        let pitchPreference: Double
    }

    // MARK: - Query Methods

    /// Get best sounds for a specific cry type
    func getBestSounds(for cryType: CryType, limit: Int = 5) -> [SoundPreference] {
        let key = cryType.rawValue
        return Array((favoriteSoundsForCryType[key] ?? []).prefix(limit))
    }

    /// Get overall best sounds regardless of cry type
    func getOverallBestSounds(limit: Int = 5) -> [(sound: GeneratorType, score: Double)] {
        return soundEffectiveness
            .compactMap { key, score -> (GeneratorType, Double)? in
                guard let sound = GeneratorType(rawValue: key) else { return nil }
                return (sound, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }

    /// Get current mood prediction based on time of day
    func predictCurrentMood() -> BabyMood {
        let timeOfDay = TimeOfDay.current
        return moodByTimeOfDay[timeOfDay] ?? .unknown
    }

    /// Check if currently in a typical crying time
    func isTypicalCryingTime() -> Bool {
        let now = Date()
        return typicalCryingTimes.contains { $0.includes(date: now) }
    }

    // MARK: - Update Methods

    /// Record a soothing session outcome
    mutating func recordSession(
        cryType: CryType,
        soundsUsed: [GeneratorType],
        wasSuccessful: Bool,
        calmingTime: TimeInterval,
        intensity: Double
    ) {
        totalSessions += 1
        if wasSuccessful {
            successfulSessions += 1
        }

        // Update sound effectiveness
        for sound in soundsUsed {
            let key = sound.rawValue
            let currentScore = soundEffectiveness[key] ?? 0.5
            let adjustment = wasSuccessful ? 0.1 : -0.05
            soundEffectiveness[key] = max(0, min(1, currentScore + adjustment))
        }

        // Update favorites for cry type
        if wasSuccessful {
            updateFavoritesForCryType(cryType, with: soundsUsed)
        }

        // Update calming time average
        averageCalmingTime = (averageCalmingTime * 0.8) + (calmingTime * 0.2)

        // Update responsiveness based on calming time
        let expectedTime = 60.0 // baseline expectation
        if calmingTime < expectedTime {
            soothingResponsiveness = min(1, soothingResponsiveness + 0.02)
        } else if calmingTime > expectedTime * 2 {
            soothingResponsiveness = max(0, soothingResponsiveness - 0.01)
        }

        // Update profile confidence
        profileConfidence = min(0.95, 0.1 + (Double(totalSessions) * 0.05))

        updatedAt = Date()
    }

    /// Update favorite sounds for a cry type
    private mutating func updateFavoritesForCryType(_ cryType: CryType, with sounds: [GeneratorType]) {
        let key = cryType.rawValue
        var favorites = favoriteSoundsForCryType[key] ?? []

        for sound in sounds {
            if let index = favorites.firstIndex(where: { $0.soundType == sound.rawValue }) {
                // Increment existing
                favorites[index].successCount += 1
                favorites[index].lastUsed = Date()
            } else {
                // Add new
                favorites.append(SoundPreference(
                    soundType: sound.rawValue,
                    successCount: 1,
                    totalCount: 1,
                    lastUsed: Date()
                ))
            }
        }

        // Sort by success rate and recency
        favorites.sort { a, b in
            let scoreA = a.successRate * 0.7 + a.recencyScore * 0.3
            let scoreB = b.successRate * 0.7 + b.recencyScore * 0.3
            return scoreA > scoreB
        }

        // Keep top 10
        favoriteSoundsForCryType[key] = Array(favorites.prefix(10))
    }

    /// Record a personality trait observation
    mutating func updatePersonalityTrait(_ trait: PersonalityTrait, value: Double) {
        switch trait {
        case .soothingResponsiveness:
            soothingResponsiveness = (soothingResponsiveness * 0.8) + (value * 0.2)
        case .noveltyPreference:
            noveltyPreference = (noveltyPreference * 0.8) + (value * 0.2)
        case .rhythmSensitivity:
            rhythmSensitivity = (rhythmSensitivity * 0.8) + (value * 0.2)
        case .pitchPreference:
            pitchPreference = (pitchPreference * 0.8) + (value * 0.2)
        }
        updatedAt = Date()
    }

    /// Add a parent observation
    mutating func addObservation(_ observation: ParentObservation) {
        parentObservations.append(observation)
        // Keep last 50 observations
        if parentObservations.count > 50 {
            parentObservations.removeFirst(parentObservations.count - 50)
        }
        updatedAt = Date()
    }

    /// Add a known trigger
    mutating func addTrigger(_ trigger: String) {
        if !knownTriggers.contains(trigger) {
            knownTriggers.append(trigger)
            updatedAt = Date()
        }
    }

    /// Add a known comfort
    mutating func addComfort(_ comfort: String) {
        if !knownComforts.contains(comfort) {
            knownComforts.append(comfort)
            updatedAt = Date()
        }
    }

    /// Set a special circumstance
    mutating func setSpecialCircumstance(_ circumstance: SpecialCircumstance) {
        // Remove existing of same type
        specialCircumstances.removeAll { $0.type == circumstance.type }
        specialCircumstances.append(circumstance)
        updatedAt = Date()
    }

    /// Update crying time patterns
    mutating func updateCryingPattern(at time: Date) {
        let pattern = TimePattern(from: time)

        // Check if similar pattern exists
        if let index = typicalCryingTimes.firstIndex(where: { $0.overlaps(with: pattern) }) {
            typicalCryingTimes[index].occurrences += 1
            typicalCryingTimes[index].lastOccurred = time
        } else {
            typicalCryingTimes.append(pattern)
        }

        // Keep only patterns with multiple occurrences, sorted by frequency
        typicalCryingTimes = typicalCryingTimes
            .filter { $0.occurrences >= 2 }
            .sorted { $0.occurrences > $1.occurrences }
            .prefix(10)
            .map { $0 }

        patternLastUpdated = Date()
        updatedAt = Date()
    }
}

// MARK: - Supporting Types

/// Sound preference with tracking data
struct SoundPreference: Codable, Identifiable {
    let id: UUID
    let soundType: String
    var successCount: Int
    var totalCount: Int
    var lastUsed: Date

    init(soundType: String, successCount: Int, totalCount: Int, lastUsed: Date) {
        self.id = UUID()
        self.soundType = soundType
        self.successCount = successCount
        self.totalCount = totalCount
        self.lastUsed = lastUsed
    }

    var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(successCount) / Double(totalCount)
    }

    var recencyScore: Double {
        let daysSince = Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day ?? 0
        return max(0, 1.0 - Double(daysSince) / 30.0)
    }

    var generatorType: GeneratorType? {
        GeneratorType(rawValue: soundType)
    }
}

/// Soothing intensity levels
enum SoothingIntensity: String, Codable, CaseIterable {
    case gentle = "Gentle"
    case moderate = "Moderate"
    case active = "Active"
    case intense = "Intense"

    var volumeMultiplier: Float {
        switch self {
        case .gentle: return 0.6
        case .moderate: return 0.8
        case .active: return 1.0
        case .intense: return 1.2
        }
    }
}

/// Personality traits that can be learned
enum PersonalityTrait: String, Codable {
    case soothingResponsiveness
    case noveltyPreference
    case rhythmSensitivity
    case pitchPreference
}

/// Time of day categories
enum TimeOfDay: String, Codable, CaseIterable {
    case earlyMorning = "Early Morning"    // 5-8am
    case morning = "Morning"               // 8-12pm
    case afternoon = "Afternoon"           // 12-5pm
    case evening = "Evening"               // 5-8pm
    case night = "Night"                   // 8pm-12am
    case lateNight = "Late Night"          // 12-5am

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default: return .lateNight
        }
    }
}

/// Baby's current mood state
enum BabyMood: String, Codable, CaseIterable {
    case content = "Content"
    case sleepy = "Sleepy"
    case alert = "Alert"
    case fussy = "Fussy"
    case hungry = "Hungry"
    case playful = "Playful"
    case uncomfortable = "Uncomfortable"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .content: return "face.smiling"
        case .sleepy: return "moon.zzz"
        case .alert: return "eye"
        case .fussy: return "cloud.ocean"
        case .hungry: return "fork.knife"
        case .playful: return "hands.sparkles"
        case .uncomfortable: return "thermometer"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .content: return "green"
        case .sleepy: return "purple"
        case .alert: return "blue"
        case .fussy: return "orange"
        case .hungry: return "yellow"
        case .playful: return "pink"
        case .uncomfortable: return "red"
        case .unknown: return "gray"
        }
    }
}

/// Recurring time pattern
struct TimePattern: Codable, Identifiable {
    let id: UUID
    let hour: Int
    let minute: Int
    let dayOfWeek: Int? // nil = any day
    var occurrences: Int
    var lastOccurred: Date

    init(from date: Date) {
        self.id = UUID()
        let components = Calendar.current.dateComponents([.hour, .minute, .weekday], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
        self.dayOfWeek = nil // Start with any day
        self.occurrences = 1
        self.lastOccurred = date
    }

    /// Check if this pattern includes a given time (within 30-minute window)
    func includes(date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let dateMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let patternMinutes = hour * 60 + minute

        let diff = abs(dateMinutes - patternMinutes)
        return diff <= 30 || diff >= (24 * 60 - 30) // Within 30 minutes
    }

    /// Check if this pattern overlaps with another
    func overlaps(with other: TimePattern) -> Bool {
        let thisMinutes = hour * 60 + minute
        let otherMinutes = other.hour * 60 + other.minute

        let diff = abs(thisMinutes - otherMinutes)
        return diff <= 60 || diff >= (24 * 60 - 60) // Within 1 hour
    }

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return "Unknown" }
        return formatter.string(from: date)
    }
}

/// Parent observation with timestamp
struct ParentObservation: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let note: String
    let category: ObservationCategory
    let relatedCryType: CryType?

    init(note: String, category: ObservationCategory, relatedCryType: CryType? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.note = note
        self.category = category
        self.relatedCryType = relatedCryType
    }
}

/// Categories for parent observations
enum ObservationCategory: String, Codable, CaseIterable {
    case feeding = "Feeding"
    case sleeping = "Sleeping"
    case comfort = "Comfort"
    case health = "Health"
    case development = "Development"
    case environment = "Environment"
    case other = "Other"
}

/// Special circumstances affecting the baby
struct SpecialCircumstance: Codable, Identifiable {
    let id: UUID
    let type: CircumstanceType
    let startDate: Date
    var endDate: Date?
    let notes: String?

    init(type: CircumstanceType, notes: String? = nil) {
        self.id = UUID()
        self.type = type
        self.startDate = Date()
        self.endDate = nil
        self.notes = notes
    }

    var isActive: Bool {
        endDate == nil || endDate! > Date()
    }
}

/// Types of special circumstances
enum CircumstanceType: String, Codable, CaseIterable {
    case teething = "Teething"
    case growthSpurt = "Growth Spurt"
    case illness = "Illness"
    case vaccination = "Vaccination"
    case travel = "Travel"
    case newEnvironment = "New Environment"
    case sleepRegression = "Sleep Regression"
    case separationAnxiety = "Separation Anxiety"
    case learningNewSkill = "Learning New Skill"
    case dietChange = "Diet Change"

    var icon: String {
        switch self {
        case .teething: return "mouth"
        case .growthSpurt: return "arrow.up.right"
        case .illness: return "cross.case"
        case .vaccination: return "syringe"
        case .travel: return "airplane"
        case .newEnvironment: return "house"
        case .sleepRegression: return "bed.double"
        case .separationAnxiety: return "person.2"
        case .learningNewSkill: return "star"
        case .dietChange: return "carrot"
        }
    }

    var typicalDuration: TimeInterval {
        switch self {
        case .teething: return 7 * 24 * 3600 // 1 week
        case .growthSpurt: return 3 * 24 * 3600 // 3 days
        case .illness: return 7 * 24 * 3600 // 1 week
        case .vaccination: return 2 * 24 * 3600 // 2 days
        case .travel: return 14 * 24 * 3600 // 2 weeks
        case .newEnvironment: return 7 * 24 * 3600 // 1 week
        case .sleepRegression: return 21 * 24 * 3600 // 3 weeks
        case .separationAnxiety: return 30 * 24 * 3600 // 1 month
        case .learningNewSkill: return 7 * 24 * 3600 // 1 week
        case .dietChange: return 7 * 24 * 3600 // 1 week
        }
    }
}

// MARK: - Profile Manager

/// Manages persistence and retrieval of baby mood profiles
class BabyMoodProfileManager: ObservableObject {
    static let shared = BabyMoodProfileManager()

    @Published var profiles: [UUID: BabyMoodProfile] = [:]
    @Published var activeProfileId: UUID?

    private let storageKey = "BabyMoodProfiles"
    private let activeProfileKey = "ActiveBabyMoodProfileId"

    private init() {
        loadProfiles()
    }

    // MARK: - Profile Access

    /// Get active profile
    var activeProfile: BabyMoodProfile? {
        guard let id = activeProfileId else { return nil }
        return profiles[id]
    }

    /// Get profile for a specific baby
    func getProfile(for babyId: UUID) -> BabyMoodProfile? {
        return profiles.values.first { $0.babyId == babyId }
    }

    /// Create or get profile for a baby
    func getOrCreateProfile(for baby: Baby) -> BabyMoodProfile {
        if let existing = getProfile(for: baby.id) {
            return existing
        }

        let profile = BabyMoodProfile(
            babyId: baby.id,
            babyName: baby.name,
            birthDate: baby.birthDate
        )
        profiles[profile.id] = profile

        if activeProfileId == nil {
            activeProfileId = profile.id
        }

        saveProfiles()
        return profile
    }

    /// Set active profile
    func setActiveProfile(_ profileId: UUID) {
        guard profiles[profileId] != nil else { return }
        activeProfileId = profileId
        UserDefaults.standard.set(profileId.uuidString, forKey: activeProfileKey)
    }

    // MARK: - Profile Updates

    /// Update a profile (thread-safe)
    func updateProfile(_ profile: BabyMoodProfile) {
        var updated = profile
        updated.updatedAt = Date()
        profiles[profile.id] = updated
        saveProfiles()
    }

    /// Record a soothing session
    func recordSession(
        profileId: UUID,
        cryType: CryType,
        soundsUsed: [GeneratorType],
        wasSuccessful: Bool,
        calmingTime: TimeInterval,
        intensity: Double
    ) {
        guard var profile = profiles[profileId] else { return }
        profile.recordSession(
            cryType: cryType,
            soundsUsed: soundsUsed,
            wasSuccessful: wasSuccessful,
            calmingTime: calmingTime,
            intensity: intensity
        )
        profiles[profileId] = profile
        saveProfiles()
    }

    /// Add observation to profile
    func addObservation(
        profileId: UUID,
        note: String,
        category: ObservationCategory,
        relatedCryType: CryType? = nil
    ) {
        guard var profile = profiles[profileId] else { return }
        let observation = ParentObservation(
            note: note,
            category: category,
            relatedCryType: relatedCryType
        )
        profile.addObservation(observation)
        profiles[profileId] = profile
        saveProfiles()
    }

    // MARK: - Persistence

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UUID: BabyMoodProfile].self, from: data) {
            profiles = decoded
        }

        if let activeIdString = UserDefaults.standard.string(forKey: activeProfileKey),
           let activeId = UUID(uuidString: activeIdString) {
            activeProfileId = activeId
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Export profile data for backup/sync
    func exportProfile(_ profileId: UUID) -> Data? {
        guard let profile = profiles[profileId] else { return nil }
        return try? JSONEncoder().encode(profile)
    }

    /// Import profile from data
    func importProfile(from data: Data) -> BabyMoodProfile? {
        guard let profile = try? JSONDecoder().decode(BabyMoodProfile.self, from: data) else {
            return nil
        }
        profiles[profile.id] = profile
        saveProfiles()
        return profile
    }
}
