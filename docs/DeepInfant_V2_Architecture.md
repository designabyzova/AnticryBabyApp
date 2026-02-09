# DeepInfant_V2: Complete Technical Architecture

**Version**: 2.0
**Date**: January 2026
**Status**: Architecture Specification

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Technology Stack](#3-technology-stack)
4. [Kernel Architecture](#4-kernel-architecture)
5. [On-Device vs Cloud Inference](#5-on-device-vs-cloud-inference)
6. [Audio Processing Pipeline](#6-audio-processing-pipeline)
7. [Decision & Recommendation Engine](#7-decision--recommendation-engine)
8. [Personalization Layer](#8-personalization-layer)
9. [Privacy & Security](#9-privacy--security)
10. [Safety Boundaries](#10-safety-boundaries)
11. [Scalability & Performance](#11-scalability--performance)
12. [Key Performance Indicators](#12-key-performance-indicators)
13. [Phased Implementation](#13-phased-implementation)
14. [Risk Mitigation](#14-risk-mitigation)
15. [Future Considerations](#15-future-considerations)

---

## 1. Executive Summary

DeepInfant_V2 is a next-generation on-device ML system designed to understand infant vocalizations and recommend personalized soothing interventions. The system prioritizes:

- **Privacy-first**: All processing on-device, no raw audio leaves the phone
- **Safety-first**: Medical boundary enforcement, no diagnostic claims
- **Effectiveness-first**: Continuous learning from outcomes without experimentation

### Core Capabilities

| Capability | Description |
|------------|-------------|
| Cry Classification | Distinguish hunger, tiredness, discomfort, pain, overstimulation |
| Intensity Analysis | Measure urgency level (1-10 scale) |
| Soothing Recommendation | Suggest tracks/actions based on context |
| Effectiveness Tracking | Learn what works for each baby |
| Parent Insights | Provide actionable, non-medical observations |

---

## 2. System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DeepInfant_V2 System                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────┐   │
│  │   Audio     │───▶│   Feature    │───▶│    ML Inference         │   │
│  │   Input     │    │  Extraction  │    │    Kernel               │   │
│  └─────────────┘    └──────────────┘    └───────────┬─────────────┘   │
│                                                      │                 │
│                                                      ▼                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────┐   │
│  │  Soothing   │◀───│   Decision   │◀───│    Classification       │   │
│  │  Playback   │    │   Engine     │    │    Results              │   │
│  └─────────────┘    └──────────────┘    └─────────────────────────┘   │
│                            │                                           │
│                            ▼                                           │
│                     ┌──────────────┐                                   │
│                     │Personalization│                                  │
│                     │    Layer     │                                   │
│                     └──────────────┘                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Audio Capture** → Microphone captures audio in 2-second windows
2. **Feature Extraction** → Mel spectrograms, MFCCs, pitch contours
3. **ML Inference** → Core ML model classifies cry type and intensity
4. **Decision Engine** → Combines ML output with context and history
5. **Soothing Action** → Triggers appropriate audio/notification
6. **Effectiveness Tracking** → Monitors if intervention worked

---

## 3. Technology Stack

### On-Device (iOS)

| Component | Technology | Purpose |
|-----------|------------|---------|
| ML Runtime | Core ML 6+ | Model inference |
| Audio Processing | AVFoundation + vDSP | Real-time audio capture |
| Feature Extraction | Accelerate Framework | FFT, spectrograms |
| Local Storage | Core Data + SQLite | Encrypted local DB |
| Background Processing | BGTaskScheduler | Continuous monitoring |

### Model Training (Backend)

| Component | Technology | Purpose |
|-----------|------------|---------|
| Training Framework | PyTorch 2.x | Model development |
| Data Pipeline | Apache Beam | Preprocessing at scale |
| Experiment Tracking | MLflow | Model versioning |
| Model Conversion | coremltools | PyTorch → Core ML |
| CI/CD | GitHub Actions | Automated model validation |

### Cloud Services (Minimal)

| Service | Provider | Purpose |
|---------|----------|---------|
| Model Updates | Cloudflare R2 | OTA model delivery |
| Analytics (Aggregated) | PostHog | Privacy-preserving insights |
| Crash Reporting | Sentry | Error tracking |

---

## 4. Kernel Architecture

The ML kernel is the core inference engine, designed for:
- **Low latency**: <50ms inference time
- **Low power**: <5% battery/hour during monitoring
- **High accuracy**: >85% classification accuracy

### Model Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DeepInfant_V2 Model                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Input: Mel Spectrogram (128 bins × 87 frames)                 │
│         = 2 seconds @ 16kHz, 512 hop                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Encoder Block (Shared)                                   │   │
│  │ ├── Conv2D(1, 32, 3×3) + BatchNorm + ReLU              │   │
│  │ ├── Conv2D(32, 64, 3×3) + BatchNorm + ReLU             │   │
│  │ ├── MaxPool2D(2×2)                                      │   │
│  │ ├── Conv2D(64, 128, 3×3) + BatchNorm + ReLU            │   │
│  │ ├── Conv2D(128, 128, 3×3) + BatchNorm + ReLU           │   │
│  │ ├── GlobalAvgPool2D                                     │   │
│  │ └── Output: 128-dim embedding                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│              ┌────────────┴────────────┐                       │
│              ▼                         ▼                        │
│  ┌───────────────────┐    ┌───────────────────┐                │
│  │ Cry Type Head     │    │ Intensity Head    │                │
│  │ ├── Dense(128,64) │    │ ├── Dense(128,32) │                │
│  │ ├── Dropout(0.3)  │    │ ├── Dropout(0.2)  │                │
│  │ ├── Dense(64,6)   │    │ ├── Dense(32,1)   │                │
│  │ └── Softmax       │    │ └── Sigmoid×10    │                │
│  └───────────────────┘    └───────────────────┘                │
│         │                          │                            │
│         ▼                          ▼                            │
│  Cry Type (6 classes)      Intensity (0-10)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Cry Type Classes

| Class | Description | Typical Characteristics |
|-------|-------------|------------------------|
| `hunger` | Baby is hungry | Rhythmic, rising pitch, lip smacking |
| `tired` | Baby needs sleep | Low-pitched, yawning sounds |
| `discomfort` | Physical discomfort | Whiny, intermittent |
| `pain` | Acute pain/distress | High-pitched, sudden onset, sustained |
| `overstimulated` | Sensory overload | Fussy, turning away |
| `unknown` | Uncertain classification | Low confidence catch-all |

### Model Specifications

| Metric | Target | Notes |
|--------|--------|-------|
| Model Size | <15 MB | Core ML optimized |
| Inference Time | <50 ms | iPhone 12+ |
| RAM Usage | <50 MB | Peak during inference |
| Accuracy | >85% | On held-out test set |
| False Positive Rate | <10% | For pain detection |

---

## 5. On-Device vs Cloud Inference

### Decision: 100% On-Device

All inference runs locally on the device. No audio data is ever transmitted.

#### Rationale

| Factor | On-Device | Cloud |
|--------|-----------|-------|
| **Privacy** | ✅ Audio never leaves device | ❌ Audio transmitted |
| **Latency** | ✅ <50ms | ❌ 200-500ms+ |
| **Offline** | ✅ Always works | ❌ Requires network |
| **Cost** | ✅ No server costs | ❌ GPU inference costs |
| **Trust** | ✅ Parents trust local | ❌ Data privacy concerns |

#### What Goes to Cloud (Aggregated Only)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Data That Leaves Device                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ ALLOWED (Aggregated, Anonymized):                          │
│  ├── Model prediction distribution (e.g., "60% hunger")        │
│  ├── Effectiveness rates (e.g., "lullaby worked 80%")          │
│  ├── Feature statistics (e.g., "avg intensity 6.2")            │
│  └── App usage patterns (e.g., "peak usage 2-4am")             │
│                                                                 │
│  ❌ NEVER TRANSMITTED:                                         │
│  ├── Raw audio                                                  │
│  ├── Audio features (spectrograms, MFCCs)                      │
│  ├── Individual baby profiles                                   │
│  ├── Specific timestamps                                        │
│  └── Any PII                                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Audio Processing Pipeline

### Real-Time Processing Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Audio Processing Pipeline                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Microphone                                                            │
│      │                                                                  │
│      ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │ 1. Audio Capture                                              │     │
│  │    └── AVAudioEngine, 16kHz, mono, Float32                   │     │
│  └──────────────────────────────────────────────────────────────┘     │
│      │                                                                  │
│      ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │ 2. Pre-Processing                                             │     │
│  │    ├── Ring buffer (2 sec window, 0.5 sec hop)               │     │
│  │    ├── Noise gate (threshold: -40 dB)                        │     │
│  │    └── Normalization (peak normalize to -3 dB)               │     │
│  └──────────────────────────────────────────────────────────────┘     │
│      │                                                                  │
│      ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │ 3. Feature Extraction (vDSP/Accelerate)                       │     │
│  │    ├── STFT: 1024 FFT, 512 hop                               │     │
│  │    ├── Mel filterbank: 128 bins, 50-8000 Hz                  │     │
│  │    ├── Log compression: log(mel + 1e-6)                      │     │
│  │    └── Delta features (optional)                              │     │
│  └──────────────────────────────────────────────────────────────┘     │
│      │                                                                  │
│      ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │ 4. ML Inference (Core ML)                                     │     │
│  │    ├── Input: MLMultiArray [1, 128, 87]                      │     │
│  │    ├── Inference: ~30ms on Neural Engine                      │     │
│  │    └── Output: cry_type (6), intensity (1)                   │     │
│  └──────────────────────────────────────────────────────────────┘     │
│      │                                                                  │
│      ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │ 5. Post-Processing                                            │     │
│  │    ├── Confidence thresholding (>0.7 for action)             │     │
│  │    ├── Temporal smoothing (3-window majority vote)           │     │
│  │    └── Hysteresis (prevent rapid state changes)              │     │
│  └──────────────────────────────────────────────────────────────┘     │
│      │                                                                  │
│      ▼                                                                  │
│  Decision Engine                                                        │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

### Feature Extraction Details

```swift
// Mel Spectrogram Configuration
struct MelSpectrogramConfig {
    let sampleRate: Int = 16000
    let fftSize: Int = 1024
    let hopSize: Int = 512
    let melBins: Int = 128
    let fMin: Float = 50.0
    let fMax: Float = 8000.0
    let windowDuration: TimeInterval = 2.0

    var framesPerWindow: Int {
        // (2.0 * 16000 - 1024) / 512 + 1 ≈ 87 frames
        return Int((windowDuration * Double(sampleRate) - Double(fftSize)) / Double(hopSize)) + 1
    }
}
```

### Noise Gate Implementation

```swift
class NoiseGate {
    let thresholdDB: Float = -40.0
    let attackTime: Float = 0.001   // 1ms
    let releaseTime: Float = 0.050  // 50ms

    func shouldProcess(rmsDB: Float) -> Bool {
        return rmsDB > thresholdDB
    }
}
```

---

## 7. Decision & Recommendation Engine

### Decision Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Decision Engine                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Inputs:                                                            │
│  ├── ML Output (cry_type, intensity, confidence)                   │
│  ├── Context (time_of_day, last_feeding, last_nap)                │
│  ├── History (what worked before for this cry type)                │
│  └── User Preferences (sound preferences, alert settings)          │
│                                                                      │
│                         │                                            │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Decision Matrix                            │   │
│  │                                                               │   │
│  │  if confidence < 0.7:                                        │   │
│  │      return "monitoring" (no action)                         │   │
│  │                                                               │   │
│  │  if cry_type == "pain" && intensity > 7:                     │   │
│  │      return "alert_parent" (urgent notification)             │   │
│  │                                                               │   │
│  │  if cry_type == "hunger":                                    │   │
│  │      if time_since_last_feed > 2h:                          │   │
│  │          return "suggest_feeding" + soothing_sound          │   │
│  │      else:                                                    │   │
│  │          return "soothing_sound" (might be comfort cry)     │   │
│  │                                                               │   │
│  │  if cry_type == "tired":                                     │   │
│  │      return "play_lullaby" (best_for_this_baby)             │   │
│  │                                                               │   │
│  │  // ... more rules                                           │   │
│  │                                                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                         │                                            │
│                         ▼                                            │
│  Output:                                                             │
│  ├── action: "play_sound" | "alert" | "suggest" | "monitor"        │
│  ├── sound_id: "lullaby_brahms" (if applicable)                    │
│  ├── message: "Baby might be tired" (parent-facing)                │
│  └── confidence: 0.85                                               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommendation Algorithm

```swift
struct SoothingRecommendation {
    let action: RecommendedAction
    let soundTrack: AudioTrack?
    let parentMessage: String
    let confidence: Float
    let reasoning: String  // For transparency
}

enum RecommendedAction {
    case playSoothingSound
    case alertParentUrgent
    case suggestFeeding
    case suggestNap
    case continueMonitoring
}

func recommend(
    mlOutput: CryClassification,
    context: BabyContext,
    history: EffectivenessHistory
) -> SoothingRecommendation {

    // Rule 1: Low confidence = keep monitoring
    guard mlOutput.confidence > 0.7 else {
        return .continueMonitoring
    }

    // Rule 2: Pain = alert parent
    if mlOutput.cryType == .pain && mlOutput.intensity > 7 {
        return .alertParentUrgent(
            message: "Baby seems distressed. Please check on them."
        )
    }

    // Rule 3: Use personalized history
    let bestSound = history.mostEffectiveSound(for: mlOutput.cryType)

    // Rule 4: Context-aware suggestions
    switch mlOutput.cryType {
    case .hunger:
        if context.timeSinceLastFeed > .hours(2) {
            return .suggestFeeding(withSound: bestSound)
        }
    case .tired:
        if context.timeSinceLastNap > .hours(3) {
            return .suggestNap(withSound: bestSound)
        }
    // ...
    }

    return .playSoothingSound(bestSound)
}
```

---

## 8. Personalization Layer

### Learning What Works

The system learns from outcomes WITHOUT experimenting on the baby.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Personalization Pipeline                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. OBSERVE (Never Experiment)                                      │
│     ├── Track: What sound was played?                               │
│     ├── Track: What was the cry type/intensity?                     │
│     └── Track: Did crying stop within 5 minutes?                    │
│                                                                      │
│  2. LEARN (Passive)                                                 │
│     ├── Build effectiveness matrix per cry type                     │
│     ├── Weight recent successes higher (decay factor: 0.95)        │
│     └── Require minimum 3 observations before recommendation        │
│                                                                      │
│  3. RECOMMEND (Conservative)                                        │
│     ├── Suggest sounds with >60% historical success                 │
│     ├── Fall back to population defaults if insufficient data       │
│     └── Never suggest something that failed >3 times recently       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Effectiveness Tracking

```swift
struct EffectivenessRecord: Codable {
    let id: UUID
    let timestamp: Date
    let cryType: CryType
    let intensity: Float
    let soundPlayed: String
    let cryingStoppedWithin: TimeInterval?  // nil = didn't stop
    let parentFeedback: ParentFeedback?     // optional manual input
}

class EffectivenessTracker {
    private var records: [EffectivenessRecord] = []

    func recordOutcome(
        cryType: CryType,
        soundPlayed: AudioTrack,
        cryingStopped: Bool,
        timeToCalm: TimeInterval?
    ) {
        let record = EffectivenessRecord(
            id: UUID(),
            timestamp: Date(),
            cryType: cryType,
            intensity: currentIntensity,
            soundPlayed: soundPlayed.id,
            cryingStoppedWithin: cryingStopped ? timeToCalm : nil,
            parentFeedback: nil
        )
        records.append(record)
        updateModel()
    }

    func mostEffectiveSound(for cryType: CryType) -> AudioTrack {
        let relevant = records.filter { $0.cryType == cryType }
        let grouped = Dictionary(grouping: relevant) { $0.soundPlayed }

        let ranked = grouped.mapValues { records -> Float in
            let successes = records.filter { $0.cryingStoppedWithin != nil }
            return Float(successes.count) / Float(records.count)
        }

        guard let best = ranked.max(by: { $0.value < $1.value }),
              best.value > 0.6 else {
            return defaultSound(for: cryType)
        }

        return AudioTrack(id: best.key)
    }
}
```

### Privacy-Safe Aggregation

```swift
// What we store locally (full detail)
struct LocalBabyProfile: Codable {
    let babyId: UUID  // Local only, never transmitted
    var effectivenessHistory: [EffectivenessRecord]
    var feedingTimes: [Date]
    var napTimes: [Date]
}

// What we send to analytics (aggregated, anonymous)
struct AggregatedInsight: Codable {
    let dateRange: String  // "2026-W03" (week granularity)
    let cryTypeDistribution: [String: Float]  // {"hunger": 0.4, "tired": 0.3, ...}
    let avgEffectivenessRate: Float  // 0.75
    let mostUsedSoundCategory: String  // "lullabies"
    // NO timestamps, NO baby ID, NO audio features
}
```

---

## 9. Privacy & Security

### Privacy Principles

| Principle | Implementation |
|-----------|----------------|
| **Data Minimization** | Only collect what's needed for functionality |
| **Local-First** | All ML inference on-device |
| **No Raw Audio** | Audio features discarded after inference |
| **Anonymization** | All analytics aggregated and anonymized |
| **User Control** | Full data export and deletion |

### Data Classification

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Data Classification                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  🔴 NEVER STORED (ephemeral only):                                 │
│  ├── Raw audio samples                                              │
│  ├── Mel spectrograms after inference                               │
│  └── Audio feature vectors                                          │
│                                                                      │
│  🟡 STORED LOCALLY ONLY (encrypted):                               │
│  ├── Baby profile (name, birth date)                               │
│  ├── Effectiveness history (sound → outcome)                       │
│  ├── Feeding/nap schedule                                           │
│  └── User preferences                                               │
│                                                                      │
│  🟢 MAY BE TRANSMITTED (aggregated, anonymous):                    │
│  ├── Model prediction distributions                                 │
│  ├── Feature effectiveness rates                                    │
│  ├── App usage patterns (time-of-day bins)                         │
│  └── Crash/error reports (no PII)                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Encryption

```swift
// Local data encryption
class SecureStorage {
    private let keychain = KeychainAccess()

    func encryptAndStore(_ data: Data, key: String) throws {
        let encryptionKey = try keychain.getOrCreateKey()
        let encrypted = try AES.GCM.seal(data, using: encryptionKey)
        try FileManager.default.write(encrypted.combined!, to: storageURL(key))
    }

    func retrieveAndDecrypt(key: String) throws -> Data {
        let encrypted = try Data(contentsOf: storageURL(key))
        let encryptionKey = try keychain.getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
}
```

### GDPR/CCPA Compliance

| Right | Implementation |
|-------|----------------|
| Right to Access | In-app data export (JSON) |
| Right to Deletion | Full local data wipe + server request |
| Right to Portability | Export in standard format |
| Right to Opt-Out | Disable all analytics in settings |

---

## 10. Safety Boundaries

### Medical Disclaimer (Enforced in Code)

```swift
// CRITICAL: These phrases must NEVER appear in user-facing text
let FORBIDDEN_MEDICAL_TERMS = [
    "diagnos", "disease", "disorder", "syndrome", "condition",
    "medical", "health issue", "treatment", "therapy", "cure",
    "doctor", "pediatrician", "consult", "professional"
]

func sanitizeParentMessage(_ message: String) -> String {
    var safe = message
    for term in FORBIDDEN_MEDICAL_TERMS {
        if safe.lowercased().contains(term) {
            // Log violation and replace
            Analytics.log(.safetyViolation, ["term": term])
            safe = safe.replacingOccurrences(
                of: term,
                with: "[redacted]",
                options: .caseInsensitive
            )
        }
    }
    return safe
}
```

### Safe Messaging Templates

```swift
// ✅ ALLOWED messages
let SAFE_MESSAGES = [
    "Baby might be feeling hungry",
    "Baby seems tired",
    "Baby may be uncomfortable",
    "Playing soothing sounds",
    "Consider checking on baby"
]

// ❌ FORBIDDEN messages
let UNSAFE_MESSAGES = [
    "Baby has colic",                    // Medical diagnosis
    "Baby is sick",                      // Medical claim
    "Consult your pediatrician",         // Medical advice
    "This could indicate an illness",    // Medical speculation
]
```

### Intensity Alert Thresholds

```swift
struct SafetyThresholds {
    // Alert parent if intensity persists above threshold
    static let urgentAlertIntensity: Float = 8.0
    static let urgentAlertDuration: TimeInterval = 120  // 2 minutes

    // Never delay parent notification for suspected pain
    static let painAlertDelay: TimeInterval = 0  // Immediate

    // Maximum time to play sounds before suggesting parent check
    static let maxUnattendedSoothingTime: TimeInterval = 600  // 10 minutes
}
```

### Fail-Safe Behavior

```swift
func handleMLFailure() {
    // If ML inference fails, ALWAYS notify parent
    NotificationManager.send(
        title: "Monitoring Paused",
        body: "Unable to analyze audio. Please check on baby.",
        priority: .high
    )

    // Fall back to simple volume-based detection
    enableFallbackVolumeMonitoring()
}
```

---

## 11. Scalability & Performance

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Inference Latency | <50ms | P99 on iPhone 12 |
| Battery (Monitoring) | <5%/hour | 1 hour continuous |
| Battery (Active Soothing) | <8%/hour | Playback + monitoring |
| Memory (Peak) | <100MB | During inference |
| App Launch | <2s | Cold start to ready |
| Model Load | <500ms | First inference ready |

### Optimization Strategies

```swift
// 1. Model Quantization (INT8)
let config = MLModelConfiguration()
config.computeUnits = .all  // Use Neural Engine when available

// 2. Batch Prediction (when catching up)
let batchSize = 4  // Process 4 windows in parallel

// 3. Lazy Feature Computation
class LazyFeatureExtractor {
    private var cachedMelBanks: [Float]?

    func getMelFilterbank() -> [Float] {
        if cachedMelBanks == nil {
            cachedMelBanks = computeMelFilterbank()
        }
        return cachedMelBanks!
    }
}

// 4. Background Processing Limits
let backgroundProcessingBudget: TimeInterval = 30  // seconds
```

### Model Update Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    OTA Model Updates                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Check for updates (daily, on WiFi)                             │
│     GET /models/deepinfant_v2/latest.json                          │
│     → { version: "2.3.1", size: 14.2MB, checksum: "sha256:..." }  │
│                                                                      │
│  2. Download in background (if newer)                               │
│     GET /models/deepinfant_v2/2.3.1.mlmodelc.zip                   │
│                                                                      │
│  3. Validate (before activation)                                    │
│     ├── Checksum verification                                       │
│     ├── Model signature (code signing)                              │
│     └── Sanity test (known input → expected output)                │
│                                                                      │
│  4. Atomic swap (on next app launch)                                │
│     ├── Keep previous version as fallback                           │
│     └── Rollback if new model fails 3 consecutive inferences       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 12. Key Performance Indicators

### ML Model KPIs

| KPI | Target | Current | Notes |
|-----|--------|---------|-------|
| Classification Accuracy | >85% | TBD | Held-out test set |
| Pain Detection Recall | >95% | TBD | Critical - minimize false negatives |
| Pain Detection Precision | >80% | TBD | Acceptable false positives |
| Hunger/Tired F1 | >80% | TBD | Most common classes |
| Unknown Rate | <15% | TBD | Model uncertainty |

### Product KPIs

| KPI | Target | Notes |
|-----|--------|-------|
| Time to Calm (median) | <3 min | After soothing starts |
| Soothing Success Rate | >70% | Crying stops within 5 min |
| Parent Override Rate | <20% | Parent changes recommendation |
| Daily Active Use | >5 sessions | Engaged users |
| Retention (D30) | >40% | Monthly retention |

### Technical KPIs

| KPI | Target | Notes |
|-----|--------|-------|
| App Crash Rate | <0.1% | Sessions with crashes |
| ML Inference Failures | <0.5% | Failed predictions |
| Battery Drain | <5%/hr | Monitoring mode |
| Model Load Time | <500ms | Cold start |

---

## 13. Phased Implementation

### Phase 1: Foundation (Weeks 1-4)

**Goal**: Basic cry detection with pre-trained model

| Task | Deliverable |
|------|-------------|
| Audio Pipeline | Real-time capture + feature extraction |
| Core ML Integration | Load and run inference |
| Basic UI | Detection indicator + manual sound selection |
| Baseline Model | Pre-trained on public datasets |

**Exit Criteria**: App detects crying with >70% accuracy

### Phase 2: Classification (Weeks 5-8)

**Goal**: Multi-class cry type classification

| Task | Deliverable |
|------|-------------|
| Multi-Head Model | 6-class cry type + intensity |
| Decision Engine | Rule-based recommendations |
| Parent Feedback | Thumbs up/down on suggestions |
| A/B Framework | Compare model versions |

**Exit Criteria**: 5-class F1 >75%, parent feedback collected

### Phase 3: Personalization (Weeks 9-12)

**Goal**: Learning what works for each baby

| Task | Deliverable |
|------|-------------|
| Effectiveness Tracking | Log outcomes per sound/cry type |
| Personal Model | Bayesian update of priors |
| Context Integration | Time-of-day, feeding schedule |
| Insights Dashboard | Show parents what works |

**Exit Criteria**: Personalized recommendations outperform defaults

### Phase 4: Polish (Weeks 13-16)

**Goal**: Production-ready quality

| Task | Deliverable |
|------|-------------|
| Performance Optimization | <50ms inference, <5% battery |
| Edge Case Handling | Multi-baby, noisy environments |
| OTA Updates | Model update pipeline |
| Privacy Audit | Third-party security review |

**Exit Criteria**: App Store submission ready

---

## 14. Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Model accuracy insufficient | Medium | High | Fallback to volume detection |
| Battery drain too high | Low | Medium | Aggressive optimization, sampling |
| iOS audio restrictions | Low | High | Background modes, interruption handling |
| Model size too large | Low | Low | Quantization, pruning |

### Product Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Parents don't trust AI | Medium | High | Transparency, explain reasoning |
| False pain alerts | Medium | High | High precision threshold |
| Soothing doesn't work | Medium | Medium | Quick parent escalation |
| Privacy concerns | Low | High | On-device only, clear messaging |

### Legal/Safety Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Medical device classification | Low | Critical | Clear disclaimers, no diagnosis |
| Liability for missed pain | Low | Critical | Always escalate high intensity |
| GDPR/CCPA violation | Low | High | Privacy-by-design, no PII |

---

## 15. Future Considerations

### Potential Enhancements (v3.0+)

| Feature | Description | Complexity |
|---------|-------------|------------|
| Multi-baby detection | Distinguish between siblings | High |
| Parent voice recognition | Filter out parent talking | Medium |
| Sleep stage detection | Detect light vs deep sleep | High |
| Predictive alerts | "Baby might wake in 10 min" | High |
| Watch app | Wrist notifications | Medium |
| CarPlay integration | In-car monitoring | Low |

### Research Directions

- **Transfer Learning**: Adapt model to individual baby's voice
- **Federated Learning**: Improve model without collecting data
- **Multi-Modal**: Combine audio with video (with consent)
- **Longitudinal**: Track development over months

### Platform Expansion

| Platform | Feasibility | Notes |
|----------|-------------|-------|
| Android | High | Core ML → TensorFlow Lite |
| Web | Low | No background audio access |
| Smart Speaker | Medium | Privacy concerns |
| Baby Monitor | High | Partnership opportunity |

---

## Appendix A: API Reference

### CryClassification

```swift
struct CryClassification {
    let cryType: CryType
    let intensity: Float        // 0-10
    let confidence: Float       // 0-1
    let timestamp: Date
    let audioFeatures: AudioFeatures?  // Optional, for debugging
}

enum CryType: String, Codable {
    case hunger
    case tired
    case discomfort
    case pain
    case overstimulated
    case unknown
}
```

### DecisionEngineOutput

```swift
struct DecisionEngineOutput {
    let action: RecommendedAction
    let soundTrack: AudioTrack?
    let parentMessage: String
    let confidence: Float
    let reasoning: String
}
```

### EffectivenessRecord

```swift
struct EffectivenessRecord: Codable {
    let id: UUID
    let timestamp: Date
    let cryType: CryType
    let intensity: Float
    let soundPlayed: String
    let cryingStoppedWithin: TimeInterval?
    let parentFeedback: ParentFeedback?
}
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **Mel Spectrogram** | Time-frequency representation of audio using mel scale |
| **MFCC** | Mel-frequency cepstral coefficients, audio features |
| **Core ML** | Apple's on-device ML framework |
| **Neural Engine** | Apple's dedicated ML accelerator chip |
| **Inference** | Running a trained model to make predictions |
| **Quantization** | Reducing model precision (Float32 → INT8) for speed |
| **OTA** | Over-the-air (updates delivered via network) |
| **Hysteresis** | Preventing rapid state changes with thresholds |

---

*Document generated: January 2026*
*DeepInfant_V2 Architecture v2.0*
