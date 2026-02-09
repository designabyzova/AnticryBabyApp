# FS-029: Smart Cry-Type Playlist Generation System

**Version**: 1.0
**Date**: January 18, 2026
**Status**: Planning
**Priority**: High

---

## 1. Executive Summary

This feature implements an intelligent playlist generation system that leverages the DeepInfant V2 CoreML model for cry classification and generates optimal soothing playlists based on multiple weighted criteria. The system does NOT train any models - it uses the existing DeepInfant V2 model for on-device cry classification and implements smart playlist selection logic.

### Core Capabilities

| Capability | Description |
|------------|-------------|
| **Cry Classification Integration** | Use DeepInfant V2 CoreML model to classify cry types (hunger, tired, pain) |
| **Multi-Criteria Playlist Generation** | Weight 4 factors: age, cry type, effectiveness history, favorites |
| **Category Rotation** | Prevent audio fatigue through intelligent rotation |
| **Temporal Stability** | Avoid rapid playlist changes - require 15-30 seconds of consistent cry type |
| **User Feedback Loop** | "It Helped!" button stores last 1-2 tracks for future recommendations |
| **Audio Tagging System** | Add cry-suitability tags to all 270 library tracks |

---

## 2. System Architecture

### 2.1 High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Smart Cry-Playlist System                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────────────┐  │
│  │ Microphone   │───▶│ DeepInfant V2    │───▶│  Cry Type + Confidence   │  │
│  │ Audio Input  │    │ CoreML Inference │    │  (hunger/tired/pain)     │  │
│  └──────────────┘    └──────────────────┘    └───────────┬──────────────┘  │
│                                                           │                  │
│                      ┌────────────────────────────────────┘                  │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ TEMPORAL STABILIZER (15-30 sec consistency check)                     │  │
│  │ ├── Collect cry type predictions over sliding window                  │  │
│  │ ├── Require >70% agreement before acting                              │  │
│  │ └── Hysteresis: prevent rapid state changes                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ PLAYLIST GENERATOR (Multi-Criteria Weighting)                         │  │
│  │                                                                        │  │
│  │   Score = W1×AgeSuitability + W2×CryTypeFit + W3×Effectiveness +     │  │
│  │           W4×Favorites + RotationBonus - RecentlyPlayedPenalty        │  │
│  │                                                                        │  │
│  │   Weights (configurable):                                              │  │
│  │   ├── W1 (Age): 0.20 - Baby age appropriate                           │  │
│  │   ├── W2 (CryType): 0.35 - Matches identified cry type                │  │
│  │   ├── W3 (Effectiveness): 0.30 - Historical "It Helped!" data         │  │
│  │   └── W4 (Favorites): 0.15 - Parent-marked favorites                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ SMART QUEUE (Spotify-like, existing SmartEmergencyQueue)              │  │
│  │ ├── Current track playing                                             │  │
│  │ ├── Up-next queue (10 tracks)                                         │  │
│  │ ├── AI reasoning displayed ("Selected for hunger, high effectiveness")│  │
│  │ └── Crossfade transitions                                             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ USER FEEDBACK COLLECTOR                                               │  │
│  │ ├── "It Helped!" button → Store last 1-2 tracks with cry type        │  │
│  │ ├── "Cry Stopped" auto-detection → Record as success                  │  │
│  │ └── Data stored in Cloudflare D1 (per-user, private)                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Cry Type Change Detection

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                  Cry Type Change Detection Protocol                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INITIAL DETECTION:                                                          │
│  ├── Listen for 15-20 seconds minimum                                       │
│  ├── Collect predictions every 2 seconds (7-10 samples)                     │
│  ├── Require >70% agreement on cry type                                      │
│  └── If uncertain, wait additional 10 seconds                                │
│                                                                              │
│  CHANGE DETECTION (while playlist playing):                                  │
│  ├── Continue monitoring in background (every 5 seconds)                    │
│  ├── If new cry type detected consistently for 20-30 seconds:               │
│  │   └── PROMPT USER: "Cry type may have changed to [tired]. Change playlist?"│
│  ├── User confirms → Generate new playlist for new cry type                 │
│  └── User declines → Continue current playlist                               │
│                                                                              │
│  CRY STOPPED DETECTION:                                                      │
│  ├── Monitor for 60 seconds of no crying                                    │
│  ├── If silence detected:                                                    │
│  │   ├── Show "Baby seems calmer! Did the music help?" prompt               │
│  │   ├── "Yes, it helped!" → Record last 1-2 tracks as effective            │
│  │   └── "No" → Note for future reference                                   │
│  └── Continue playing until manually stopped or sleep timer                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Cry Type Definitions (Focus: 3 Primary Types)

### 3.1 Primary Cry Types for MVP

| Cry Type | DeepInfant Output | Audio Characteristics | Recommended Sounds |
|----------|-------------------|----------------------|-------------------|
| **Hunger** | `hunger` | Rhythmic, rising pitch, lip smacking, urgent | Shushing, gentle lullabies, rhythmic music box |
| **Tired** | `tired` | Low-pitched, yawning quality, intermittent | Womb sounds, heartbeat, slow lullabies, soft piano |
| **Pain** | `pain` | High-pitched, sudden onset, sustained, intense | ALERT PARENT FIRST, then gentle heartbeat if < intensity 7 |

### 3.2 Secondary Cry Types (Phase 2)

| Cry Type | DeepInfant Output | Notes |
|----------|-------------------|-------|
| Attention | `attention` | Wants interaction - chimes, novelty sounds |
| Discomfort | `discomfort` | Physical discomfort - similar to tired |
| General | `general` | Unknown - use age-appropriate defaults |

---

## 4. Audio Library Tagging System

### 4.1 New Tag Schema for tracks.json

Each track will have new `crySuitability` scores (0.0 - 1.0):

```json
{
  "id": "a17077f1-7399-48a4-ac39-71c21856fc52",
  "title": "Air on the G String",
  "artist": "J.S. Bach",
  "category": "lullabies",
  "calmScore": 0.95,
  "tags": ["bach", "baroque", "bedtime", "classical"],
  "ageRangeMin": 0,
  "ageRangeMax": 36,

  "crySuitability": {
    "hunger": 0.6,
    "tired": 0.95,
    "pain": 0.4,
    "attention": 0.5,
    "discomfort": 0.7,
    "general": 0.8
  },

  "acousticProfile": {
    "tempo": "slow",
    "energy": "low",
    "pitch": "medium",
    "rhythm": "flowing",
    "predictability": "high"
  }
}
```

### 4.2 Cry Suitability Assignment Rules

#### For HUNGER Cries:
| Factor | High Score (0.8+) | Medium Score (0.5-0.7) | Low Score (<0.5) |
|--------|-------------------|------------------------|------------------|
| Tempo | Moderate (60-90 BPM) | Slow or Fast | Very slow |
| Rhythm | Regular, predictable | Semi-regular | Irregular |
| Dynamics | Steady | Some variation | High variation |
| Type | Shushing, rhythmic lullabies | Classical, ambient | Fairy tales, podcasts |

#### For TIRED Cries:
| Factor | High Score (0.8+) | Medium Score (0.5-0.7) | Low Score (<0.5) |
|--------|-------------------|------------------------|------------------|
| Tempo | Very slow (<60 BPM) | Slow (60-80 BPM) | Medium/Fast |
| Energy | Very low | Low | Medium or higher |
| Dynamics | Minimal variation | Some variation | High variation |
| Type | Womb, heartbeat, slow piano | Lullabies, ambient | Children's songs, stories |

#### For PAIN Cries:
| Factor | High Score (0.8+) | Medium Score (0.5-0.7) | Low Score (<0.5) |
|--------|-------------------|------------------------|------------------|
| Intensity | **If > 7: ALERT PARENT** | < 7: gentle sounds | N/A |
| Type | Heartbeat, womb only | Soft piano | Everything else |
| Priority | Parent notification | Comfort sounds | Never auto-play loud |

### 4.3 Category-to-Cry-Type Mapping (Defaults)

| Category | Hunger | Tired | Pain | Attention | Discomfort |
|----------|--------|-------|------|-----------|------------|
| Lullabies | 0.7 | 0.95 | 0.5 | 0.6 | 0.8 |
| Classical (slow) | 0.6 | 0.9 | 0.5 | 0.5 | 0.7 |
| Classical (medium) | 0.7 | 0.6 | 0.3 | 0.7 | 0.5 |
| Ambient | 0.5 | 0.85 | 0.6 | 0.4 | 0.75 |
| Fairy Tales | 0.3 | 0.4 | 0.2 | 0.8 | 0.3 |
| Children's Songs | 0.6 | 0.3 | 0.2 | 0.9 | 0.4 |
| Modern Piano | 0.65 | 0.85 | 0.55 | 0.5 | 0.7 |

### 4.4 Generated Sounds Cry Suitability (Already Defined)

From existing `GeneratorType.bestForCryTypes`:

| Generator | Hunger | Tired | Pain | Attention | Discomfort |
|-----------|--------|-------|------|-----------|------------|
| Womb | 0.6 | 0.95 | 0.7 | 0.5 | 0.85 |
| Heartbeat | 0.5 | 0.9 | 0.65 | 0.4 | 0.8 |
| Shushing | 0.9 | 0.8 | 0.6 | 0.7 | 0.75 |
| Lullaby (generated) | 0.75 | 0.9 | 0.5 | 0.7 | 0.7 |
| Music Box | 0.7 | 0.85 | 0.45 | 0.8 | 0.65 |
| Soft Piano | 0.65 | 0.9 | 0.55 | 0.6 | 0.75 |
| Gentle Guitar | 0.7 | 0.85 | 0.5 | 0.65 | 0.7 |
| Chimes | 0.5 | 0.7 | 0.4 | 0.9 | 0.55 |
| Bells | 0.55 | 0.65 | 0.35 | 0.85 | 0.5 |
| Aquarium | 0.6 | 0.8 | 0.55 | 0.5 | 0.7 |

---

## 5. Playlist Generation Algorithm

### 5.1 Track Scoring Formula

```swift
func calculateTrackScore(
    track: AudioTrack,
    babyAge: Int,           // in months
    cryType: CryType,
    effectivenessData: EffectivenessData,
    favorites: Set<UUID>,
    recentlyPlayed: [UUID],
    categoryPlayCount: [String: Int]
) -> Double {

    // Base weights (configurable)
    let W1_AGE = 0.20
    let W2_CRY_TYPE = 0.35
    let W3_EFFECTIVENESS = 0.30
    let W4_FAVORITES = 0.15

    // 1. Age Suitability Score (0-1)
    let ageScore: Double
    if babyAge >= track.ageRangeMin && babyAge <= track.ageRangeMax {
        // Perfect age range
        let midPoint = (track.ageRangeMin + track.ageRangeMax) / 2
        let distance = abs(babyAge - midPoint)
        let maxDistance = (track.ageRangeMax - track.ageRangeMin) / 2
        ageScore = 1.0 - (Double(distance) / Double(max(maxDistance, 1))) * 0.3
    } else {
        // Outside age range - penalize
        let distanceOutside = min(
            abs(babyAge - track.ageRangeMin),
            abs(babyAge - track.ageRangeMax)
        )
        ageScore = max(0.3, 1.0 - Double(distanceOutside) * 0.1)
    }

    // 2. Cry Type Suitability Score (0-1)
    let cryTypeScore = track.crySuitability[cryType.rawValue] ?? 0.5

    // 3. Effectiveness Score (0-1)
    let effectivenessScore: Double
    if let trackEffectiveness = effectivenessData.getEffectiveness(
        trackId: track.id,
        cryType: cryType
    ) {
        // We have historical data for this track + cry type
        effectivenessScore = trackEffectiveness.successRate
    } else if let generalEffectiveness = effectivenessData.getEffectiveness(trackId: track.id) {
        // We have general effectiveness data (not cry-type specific)
        effectivenessScore = generalEffectiveness.successRate * 0.8 // Slight penalty
    } else {
        // No data - use default based on calmScore
        effectivenessScore = track.calmScore * 0.7
    }

    // 4. Favorites Score (0 or 1)
    let favoritesScore: Double = favorites.contains(track.id) ? 1.0 : 0.0

    // Weighted sum
    var score = W1_AGE * ageScore +
                W2_CRY_TYPE * cryTypeScore +
                W3_EFFECTIVENESS * effectivenessScore +
                W4_FAVORITES * favoritesScore

    // 5. Rotation Bonus (encourage variety)
    let categoryCount = categoryPlayCount[track.category.rawValue] ?? 0
    if categoryCount == 0 {
        score += 0.10  // Bonus for unplayed category
    } else if categoryCount < 3 {
        score += 0.05  // Small bonus for under-represented
    }

    // 6. Recently Played Penalty
    if let recentIndex = recentlyPlayed.firstIndex(of: track.id) {
        let recencyPenalty = 0.3 * (1.0 - Double(recentIndex) / Double(recentlyPlayed.count))
        score -= recencyPenalty
    }

    return max(0, min(1, score))
}
```

### 5.2 Playlist Generation Process

```swift
func generatePlaylist(
    for cryType: CryType,
    babyAge: Int,
    targetTracks: Int = 10
) -> [AudioTrack] {

    // 1. Get all eligible tracks
    var eligibleTracks = contentLibrary.getAllTracks().filter { track in
        // Filter out banned content
        !BannedSounds.isBanned(track) &&
        // Filter out premium if not subscribed
        (!track.isPremium || subscriptionManager.isPremium) &&
        // Basic age filtering (allow some flexibility)
        track.ageRangeMin <= babyAge + 6 && track.ageRangeMax >= babyAge - 3
    }

    // 2. Special handling for PAIN
    if cryType == .pain {
        // Only allow very gentle sounds
        eligibleTracks = eligibleTracks.filter { track in
            track.calmScore >= 0.9 &&
            (track.crySuitability["pain"] ?? 0) >= 0.5
        }
    }

    // 3. Score all tracks
    let scoredTracks = eligibleTracks.map { track -> (AudioTrack, Double) in
        let score = calculateTrackScore(
            track: track,
            babyAge: babyAge,
            cryType: cryType,
            effectivenessData: effectivenessManager.getData(),
            favorites: favoritesManager.getFavorites(),
            recentlyPlayed: playbackHistory.getRecent(limit: 20),
            categoryPlayCount: sessionCategoryCount
        )
        return (track, score)
    }

    // 4. Sort by score descending
    let sortedTracks = scoredTracks.sorted { $0.1 > $1.1 }

    // 5. Select top tracks with category diversity
    var selectedTracks: [AudioTrack] = []
    var selectedCategories: [String: Int] = [:]
    let maxPerCategory = max(2, targetTracks / 4)  // No more than 25% from one category

    for (track, _) in sortedTracks {
        if selectedTracks.count >= targetTracks { break }

        let category = track.category.rawValue
        let currentCategoryCount = selectedCategories[category] ?? 0

        if currentCategoryCount < maxPerCategory {
            selectedTracks.append(track)
            selectedCategories[category] = currentCategoryCount + 1
        }
    }

    // 6. If not enough tracks, fill without category restriction
    if selectedTracks.count < targetTracks {
        for (track, _) in sortedTracks {
            if selectedTracks.count >= targetTracks { break }
            if !selectedTracks.contains(where: { $0.id == track.id }) {
                selectedTracks.append(track)
            }
        }
    }

    return selectedTracks
}
```

### 5.3 Category Rotation Algorithm

```swift
class CategoryRotationManager {
    // Track how many times each category was played this session
    private var sessionCategoryPlayCount: [String: Int] = [:]

    // Track last N categories played (for immediate rotation)
    private var recentCategories: [String] = []
    private let recentCategoryWindow = 5

    func recordCategoryPlayed(_ category: String) {
        sessionCategoryPlayCount[category, default: 0] += 1
        recentCategories.append(category)
        if recentCategories.count > recentCategoryWindow {
            recentCategories.removeFirst()
        }
    }

    func getRotationBonus(for category: String) -> Double {
        let sessionCount = sessionCategoryPlayCount[category] ?? 0
        let recentCount = recentCategories.filter { $0 == category }.count

        // High bonus for categories not played recently
        if recentCount == 0 {
            return 0.15
        } else if sessionCount < 3 {
            return 0.08
        } else if recentCount < 2 {
            return 0.05
        }

        return 0.0
    }

    func resetSession() {
        sessionCategoryPlayCount = [:]
        recentCategories = []
    }
}
```

---

## 6. DeepInfant V2 CoreML Integration

### 6.1 Model Wrapper Service

```swift
/// CryClassificationService wraps DeepInfant V2 CoreML model
/// NO MODEL TRAINING - only inference using existing model
@MainActor
class CryClassificationService: ObservableObject {

    // MARK: - Published State
    @Published private(set) var currentCryType: CryType = .unknown
    @Published private(set) var confidence: Double = 0.0
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isStable: Bool = false  // True after stability window

    // MARK: - Configuration
    private let stabilityWindowDuration: TimeInterval = 20  // seconds
    private let minimumConfidence: Double = 0.70
    private let predictionInterval: TimeInterval = 2.0
    private let stabilityAgreementThreshold: Double = 0.70  // 70% agreement

    // MARK: - Private State
    private var model: DeepInfant_V2?
    private var audioEngine: AVAudioEngine?
    private var predictionHistory: [(CryType, Double, Date)] = []

    // MARK: - Initialization
    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine if available
            model = try DeepInfant_V2(configuration: config)
        } catch {
            print("Failed to load DeepInfant_V2 model: \(error)")
        }
    }

    // MARK: - Public API
    func startListening() async throws {
        guard !isListening else { return }
        isListening = true
        isStable = false
        predictionHistory = []

        // Start audio capture
        try await startAudioCapture()

        // Start prediction loop
        await runPredictionLoop()
    }

    func stopListening() {
        isListening = false
        isStable = false
        audioEngine?.stop()
        predictionHistory = []
    }

    // MARK: - Stability Check
    private func checkStability() -> (CryType, Double)? {
        let windowStart = Date().addingTimeInterval(-stabilityWindowDuration)
        let recentPredictions = predictionHistory.filter { $0.2 >= windowStart }

        guard recentPredictions.count >= 5 else { return nil }

        // Count cry type occurrences
        var typeCounts: [CryType: Int] = [:]
        for (type, confidence, _) in recentPredictions {
            if confidence >= minimumConfidence {
                typeCounts[type, default: 0] += 1
            }
        }

        // Find dominant type
        guard let (dominantType, count) = typeCounts.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let agreementRatio = Double(count) / Double(recentPredictions.count)

        if agreementRatio >= stabilityAgreementThreshold {
            let avgConfidence = recentPredictions
                .filter { $0.0 == dominantType }
                .map { $0.1 }
                .reduce(0, +) / Double(count)

            return (dominantType, avgConfidence)
        }

        return nil
    }
}
```

### 6.2 Temporal Stabilizer

```swift
/// Prevents rapid cry type changes with hysteresis
class CryTypeStabilizer {

    // Current stable state
    private(set) var stableCryType: CryType = .unknown
    private var stabilityStartTime: Date?

    // Configuration
    let initialDetectionWindow: TimeInterval = 20  // First detection
    let changeDetectionWindow: TimeInterval = 30   // Subsequent changes
    let minimumAgreement: Double = 0.70

    // State
    private var currentPredictions: [(CryType, Double, Date)] = []

    func addPrediction(_ type: CryType, confidence: Double) {
        let now = Date()
        currentPredictions.append((type, confidence, now))

        // Clean old predictions
        let windowStart = now.addingTimeInterval(-max(initialDetectionWindow, changeDetectionWindow))
        currentPredictions = currentPredictions.filter { $0.2 >= windowStart }

        evaluateStability()
    }

    private func evaluateStability() {
        let window = stableCryType == .unknown ? initialDetectionWindow : changeDetectionWindow
        let windowStart = Date().addingTimeInterval(-window)
        let windowPredictions = currentPredictions.filter { $0.2 >= windowStart }

        guard windowPredictions.count >= 3 else { return }

        // Count types
        var typeCounts: [CryType: (count: Int, totalConfidence: Double)] = [:]
        for (type, confidence, _) in windowPredictions {
            let existing = typeCounts[type] ?? (0, 0)
            typeCounts[type] = (existing.count + 1, existing.totalConfidence + confidence)
        }

        // Find dominant
        guard let (dominantType, data) = typeCounts.max(by: { $0.value.count < $1.value.count }) else {
            return
        }

        let agreement = Double(data.count) / Double(windowPredictions.count)
        let avgConfidence = data.totalConfidence / Double(data.count)

        if agreement >= minimumAgreement && avgConfidence >= 0.70 {
            if dominantType != stableCryType {
                // Cry type has changed
                let previousType = stableCryType
                stableCryType = dominantType
                stabilityStartTime = Date()

                // Notify observers
                NotificationCenter.default.post(
                    name: .cryTypeStabilized,
                    object: nil,
                    userInfo: [
                        "newType": dominantType,
                        "previousType": previousType,
                        "confidence": avgConfidence
                    ]
                )
            }
        }
    }

    func reset() {
        stableCryType = .unknown
        stabilityStartTime = nil
        currentPredictions = []
    }
}
```

---

## 7. User Feedback System

### 7.1 Feedback Data Model

```swift
/// Records what helped for future recommendations
struct HelpedFeedbackRecord: Codable {
    let id: UUID
    let timestamp: Date
    let cryType: CryType
    let tracksPlayed: [UUID]  // Last 1-2 tracks before feedback
    let babyAge: Int
    let sessionDuration: TimeInterval  // How long until "It Helped"
    let wasAutoDetected: Bool  // True if cry-stop was auto-detected
}

/// Stored effectiveness per track per cry type
struct TrackCryEffectiveness: Codable {
    let trackId: UUID
    var perCryType: [String: CryTypeEffectiveness]

    struct CryTypeEffectiveness: Codable {
        var helpedCount: Int
        var totalPlays: Int
        var lastHelped: Date?

        var successRate: Double {
            guard totalPlays > 0 else { return 0.5 }  // Default 50%
            return Double(helpedCount) / Double(totalPlays)
        }
    }
}
```

### 7.2 Feedback Collection Service

```swift
class FeedbackCollectionService: ObservableObject {

    // Track current session
    private var sessionStartTime: Date?
    private var tracksPlayedThisSession: [UUID] = []
    private var currentCryType: CryType?

    // Storage
    private let storage: CloudflareD1Client  // Or local storage

    // MARK: - Session Tracking

    func startSession(cryType: CryType) {
        sessionStartTime = Date()
        tracksPlayedThisSession = []
        currentCryType = cryType
    }

    func recordTrackPlayed(_ trackId: UUID) {
        tracksPlayedThisSession.append(trackId)
        // Keep only last 5 tracks
        if tracksPlayedThisSession.count > 5 {
            tracksPlayedThisSession.removeFirst()
        }
    }

    // MARK: - User Feedback

    /// Called when user taps "It Helped!" button
    func recordItHelped() async {
        guard let cryType = currentCryType,
              let startTime = sessionStartTime else { return }

        // Get last 2 tracks (most likely to have helped)
        let helpfulTracks = Array(tracksPlayedThisSession.suffix(2))

        let record = HelpedFeedbackRecord(
            id: UUID(),
            timestamp: Date(),
            cryType: cryType,
            tracksPlayed: helpfulTracks,
            babyAge: BabyProfileManager.shared.currentBaby?.ageMonths ?? 0,
            sessionDuration: Date().timeIntervalSince(startTime),
            wasAutoDetected: false
        )

        // Save to storage
        await saveFeedbackRecord(record)

        // Update effectiveness scores
        for trackId in helpfulTracks {
            await updateEffectiveness(trackId: trackId, cryType: cryType, helped: true)
        }

        endSession()
    }

    /// Called when cry-stop is auto-detected
    func recordCryStoppedAutomatically() async {
        // Same as manual but marked as auto-detected
        guard let cryType = currentCryType,
              let startTime = sessionStartTime else { return }

        let helpfulTracks = Array(tracksPlayedThisSession.suffix(2))

        let record = HelpedFeedbackRecord(
            id: UUID(),
            timestamp: Date(),
            cryType: cryType,
            tracksPlayed: helpfulTracks,
            babyAge: BabyProfileManager.shared.currentBaby?.ageMonths ?? 0,
            sessionDuration: Date().timeIntervalSince(startTime),
            wasAutoDetected: true
        )

        await saveFeedbackRecord(record)

        // Lower weight for auto-detected (less certain)
        for trackId in helpfulTracks {
            await updateEffectiveness(trackId: trackId, cryType: cryType, helped: true, weight: 0.7)
        }
    }

    // MARK: - Storage

    private func updateEffectiveness(
        trackId: UUID,
        cryType: CryType,
        helped: Bool,
        weight: Double = 1.0
    ) async {
        var effectiveness = await loadEffectiveness(trackId: trackId)
        var cryData = effectiveness.perCryType[cryType.rawValue] ?? .init(helpedCount: 0, totalPlays: 0, lastHelped: nil)

        cryData.totalPlays += 1
        if helped {
            cryData.helpedCount += Int(weight)
            cryData.lastHelped = Date()
        }

        effectiveness.perCryType[cryType.rawValue] = cryData
        await saveEffectiveness(effectiveness)
    }
}
```

---

## 8. Data Storage (Cloudflare D1)

### 8.1 Database Schema

```sql
-- User's effectiveness data (private per user)
CREATE TABLE track_effectiveness (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    track_id TEXT NOT NULL,
    cry_type TEXT NOT NULL,
    helped_count INTEGER DEFAULT 0,
    total_plays INTEGER DEFAULT 0,
    last_helped_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id, track_id, cry_type)
);

CREATE INDEX idx_effectiveness_user ON track_effectiveness(user_id);
CREATE INDEX idx_effectiveness_track ON track_effectiveness(track_id);
CREATE INDEX idx_effectiveness_cry_type ON track_effectiveness(cry_type);

-- Feedback history (for analytics)
CREATE TABLE feedback_history (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    cry_type TEXT NOT NULL,
    tracks_played TEXT NOT NULL,  -- JSON array of track IDs
    baby_age_months INTEGER,
    session_duration_seconds INTEGER,
    was_auto_detected INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_feedback_user ON feedback_history(user_id);
CREATE INDEX idx_feedback_cry_type ON feedback_history(cry_type);
```

### 8.2 API Endpoints

```typescript
// Worker endpoint for effectiveness data
export async function handleEffectivenessSync(request: Request, env: Env) {
    const userId = await getUserId(request);

    if (request.method === 'GET') {
        // Fetch all effectiveness data for user
        const results = await env.DB.prepare(`
            SELECT track_id, cry_type, helped_count, total_plays, last_helped_at
            FROM track_effectiveness
            WHERE user_id = ?
        `).bind(userId).all();

        return Response.json({ effectiveness: results.results });
    }

    if (request.method === 'POST') {
        // Sync effectiveness updates
        const { updates } = await request.json();

        for (const update of updates) {
            await env.DB.prepare(`
                INSERT INTO track_effectiveness
                (id, user_id, track_id, cry_type, helped_count, total_plays, last_helped_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id, track_id, cry_type) DO UPDATE SET
                    helped_count = helped_count + excluded.helped_count,
                    total_plays = total_plays + excluded.total_plays,
                    last_helped_at = COALESCE(excluded.last_helped_at, last_helped_at),
                    updated_at = datetime('now')
            `).bind(
                update.id,
                userId,
                update.trackId,
                update.cryType,
                update.helpedCount,
                update.totalPlays,
                update.lastHelpedAt
            ).run();
        }

        return Response.json({ success: true });
    }
}
```

---

## 9. User Interface Changes

### 9.1 Cry Detection UI Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   CRY DETECTION SCREEN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │                    [Listening...]                        │  │
│    │                                                          │  │
│    │         ◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉                   │  │
│    │         (Audio waveform visualization)                   │  │
│    │                                                          │  │
│    │    Analyzing cry pattern...                             │  │
│    │    ████████████░░░░░░░░░░░░░░░░░░  (15/20 sec)         │  │
│    │                                                          │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  DETECTED: HUNGER CRY (87% confidence)                  │  │
│    │                                                          │  │
│    │  🍼 Rhythmic pattern suggests hunger                    │  │
│    │                                                          │  │
│    │  [Start Soothing Playlist]                              │  │
│    │                                                          │  │
│    │  Or select manually:                                     │  │
│    │  [Hungry] [Tired] [Uncomfortable]                       │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Playlist Playing UI (SmartQueueView Enhancement)

```
┌─────────────────────────────────────────────────────────────────┐
│                   NOW PLAYING (HUNGER)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  [Album Art]        Brahms Lullaby                       │  │
│    │                     Johannes Brahms                      │  │
│    │                                                          │  │
│    │  ━━━━━━━━━━━━━━━━━━○─────────────────  1:42 / 3:21     │  │
│    │                                                          │  │
│    │       [⏮]    [⏸]    [⏭]    [❤️]                        │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  AI REASONING                                            │  │
│    │  ────────────────────────────────────────────────        │  │
│    │  🧠 Selected for:                                        │  │
│    │     • Hunger cry type (92% match)                        │  │
│    │     • Previously helped 3 times for similar cries        │  │
│    │     • Age-appropriate (6 months)                         │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  UP NEXT                                                 │  │
│    │  ────────────────────────────────────────────────        │  │
│    │  1. Air on G String - Bach (Lullaby)                     │  │
│    │  2. Shushing Sound - Generated (87% effective)           │  │
│    │  3. Clair de Lune - Debussy (Classical)                  │  │
│    │  ...                                                     │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  [Baby seems calmer?]                                    │  │
│    │                                                          │  │
│    │       [ 😊 It Helped! ]        [ Still Crying ]          │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 9.3 Cry Type Change Prompt

```
┌─────────────────────────────────────────────────────────────────┐
│                   CRY PATTERN CHANGE DETECTED                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│    We've noticed the cry pattern may have changed.              │
│                                                                  │
│    Previous: HUNGER                                              │
│    New:      TIRED (82% confidence)                              │
│                                                                  │
│    Would you like to switch to a tiredness-focused playlist?    │
│                                                                  │
│    ┌───────────────────────┐  ┌───────────────────────┐         │
│    │   Yes, Switch Now     │  │   No, Keep Current    │         │
│    └───────────────────────┘  └───────────────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. Voice Interaction Mode

> **NOTE**: Voice Interaction and Car Drive Mode are implemented in a **separate increment**: **FS-030**
>
> See: `.specweave/increments/0030-voice-interaction-car-mode/spec.md`
>
> This increment (FS-029) provides the foundation that FS-030 builds upon:
> - Cry type change detection triggers
> - "It Helped!" feedback hooks
> - Cry-stopped auto-detection
>
> FS-030 adds voice prompts (TTS) and voice responses (SFSpeechRecognizer) for hands-free operation.

---

## 11. Existing Code Analysis (Avoid Duplication)

### 11.1 EXISTING Implementations (DO NOT RECREATE)

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| **CryType enum** | `WatchModels.swift` | ✅ Complete | 7 types defined |
| **TrackEffectiveness model** | `TrackEffectiveness.swift` | ✅ Complete | Per-track, per-cry-type stats |
| **EffectivenessManager** | `EffectivenessManager.swift` | ✅ Complete | CRUD + queries |
| **UltraSmartPlaylistSelector** | `UltraSmartPlaylistSelector.swift` | ✅ Complete | 7-factor ML scoring |
| **GeneratorType.bestForCryTypes** | `AudioTrack.swift` | ✅ Complete | Sound-to-cry mapping |
| **TrackMetadata.crySuitability** | `TrackMetadata.swift` | ✅ Schema exists | Needs data population |
| **SmartPlaylistBuilder** | `SmartPlaylistBuilder.swift` | ⚠️ Partial | Needs queue auto-fill |
| **AVSpeechSynthesizer** | `SmartCarPlayController.swift` | ✅ Complete | Voice output exists |
| **BabyMoodProfile** | `BabyMoodProfile.swift` | ✅ Complete | Personalization foundation |

### 11.2 NEW Implementations Required

| Component | File (Proposed) | Reason |
|-----------|-----------------|--------|
| **CryClassificationService** | `Services/CryClassificationService.swift` | CoreML inference wrapper (doesn't exist) |
| **AudioFeatureExtractor** | `Services/AudioFeatureExtractor.swift` | Mel spectrogram generation (doesn't exist) |
| **CryTypeStabilizer** | `Services/CryTypeStabilizer.swift` | Temporal smoothing (doesn't exist) |
| **CategoryRotationManager** | `Services/CategoryRotationManager.swift` | Rotation bonus (doesn't exist) |
| **VoiceInteractionService** | `Services/VoiceInteractionService.swift` | Speech recognition (doesn't exist) |
| **CryDetectionView** | `Views/CryDetection/CryDetectionView.swift` | Detection UI (doesn't exist) |

### 11.3 EXTEND Existing Implementations

| Component | File | Extension Needed |
|-----------|------|------------------|
| **SmartPlaylistBuilder** | `SmartPlaylistBuilder.swift` | Add queue auto-replenishment logic |
| **SmartEmergencyQueue** | (existing) | Pass cry type to UltraSmartPlaylistSelector |
| **SmartCarPlayController** | `SmartCarPlayController.swift` | Add speech recognition (SFSpeechRecognizer) |
| **tracks.json** | `Resources/Audio/tracks.json` | Populate crySuitability scores for 270 tracks |

### 11.4 Weight Comparison (Existing vs Proposed)

**Existing UltraSmartPlaylistSelector weights:**
```swift
// Already implemented!
baseScore: 0.5
cryTypeMatch: 0.25
ageOptimality: 0.15
historicalEffectiveness: 0.30  // ← Highest!
timeOfDayMatch: 0.10
cryIntensityMatch: 0.15
recencyPenalty: 0.10
calmingScore: 0.15
```

**Proposed in spec (Section 5.1):**
```swift
W1 (Age): 0.20
W2 (CryType): 0.35
W3 (Effectiveness): 0.30
W4 (Favorites): 0.15
+ RotationBonus
- RecentlyPlayedPenalty
```

**Resolution**: The existing `UltraSmartPlaylistSelector` already implements sophisticated scoring. We should:
1. **ADD** `CategoryRotationManager` integration (new)
2. **ADD** `Favorites` factor (W4 = 0.15) to existing selector
3. **KEEP** existing weights as they are research-backed
4. **NOT** create duplicate scoring logic

---

## 12. Acceptance Criteria

### 10.1 Core Functionality

- [ ] **AC-FS029-01**: DeepInfant V2 CoreML model successfully loads and runs inference
- [ ] **AC-FS029-02**: Cry type classification returns one of: hunger, tired, pain, attention, discomfort, general, unknown
- [ ] **AC-FS029-03**: System waits 15-20 seconds before declaring stable cry type
- [ ] **AC-FS029-04**: Playlist generation uses all 4 criteria: age, cry type, effectiveness, favorites
- [ ] **AC-FS029-05**: Category rotation ensures no more than 25% of playlist from single category

### 10.2 Tagging System

- [ ] **AC-FS029-06**: All 270 tracks have `crySuitability` scores for all 3 primary cry types
- [ ] **AC-FS029-07**: Generated sounds use existing `bestForCryTypes` mapping
- [ ] **AC-FS029-08**: tracks.json schema validation passes with new fields

### 10.3 User Feedback

- [ ] **AC-FS029-09**: "It Helped!" button records last 2 tracks with cry type
- [ ] **AC-FS029-10**: Effectiveness data syncs to Cloudflare D1
- [ ] **AC-FS029-11**: Cry-stop auto-detection works within 60 seconds of silence

### 10.4 Cry Type Change Handling

- [ ] **AC-FS029-12**: System detects cry type changes after 20-30 seconds of consistent new type
- [ ] **AC-FS029-13**: User is prompted to confirm playlist change (not automatic)
- [ ] **AC-FS029-14**: Current playlist continues until user confirms change

### 10.5 Performance

- [ ] **AC-FS029-15**: CoreML inference completes in <50ms
- [ ] **AC-FS029-16**: Playlist generation completes in <200ms
- [ ] **AC-FS029-17**: Battery usage <5%/hour during continuous monitoring

---

## 11. Non-Goals (Explicitly Out of Scope)

1. **NO model training** - We use existing DeepInfant V2 as-is
2. **NO new datasets** - Existing tracks.json is the only data source
3. **NO cloud inference** - 100% on-device
4. **NO automatic playlist switching** - Always prompt user
5. **NO premium audio purchase** - Use existing library only
6. **NO multi-baby detection** - Single baby focus

---

## 12. Dependencies

### 12.1 Internal Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| DeepInfant_V2.mlmodelc | ✅ Available | Built into app bundle |
| SmartEmergencyQueue | ✅ Available | Existing Spotify-like queue |
| EffectivenessManager | ✅ Available | Existing tracking system |
| ContentLibraryService | ✅ Available | tracks.json access |
| AudioEngine | ✅ Available | Playback + monitoring |

### 12.2 External Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Cloudflare D1 | Needs setup | For effectiveness sync |
| Core ML 6+ | ✅ Available | iOS 16+ |
| AVFoundation | ✅ Available | Audio capture |
| Accelerate | ✅ Available | Feature extraction |

---

## 13. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Model accuracy < 70% | Medium | High | Fall back to manual selection |
| Battery drain > 5%/hr | Low | Medium | Reduce prediction frequency |
| False pain alerts | Low | High | Require higher confidence (85%+) |
| User ignores feedback prompts | Medium | Medium | Auto-detection backup |
| Cloudflare D1 sync fails | Low | Low | Local storage fallback |

---

## 14. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cry type accuracy | >80% | User confirms/overrides |
| "It Helped!" rate | >60% | Feedback button clicks |
| Playlist override rate | <30% | User changes playlist |
| Time to calm | <4 min median | Session duration |
| Feature adoption | >50% users | Analytics |

---

*Document created: January 18, 2026*
*FS-029: Smart Cry-Type Playlist Generation System v1.0*
