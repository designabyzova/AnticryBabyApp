# DeepInfant V2 Proper Integration

## Executive Summary

**Problem**: Current cry detection implementation is broken - using mocks and rule-based heuristics instead of actual DeepInfant V2 neural network. Audio preprocessing parameters are completely wrong.

**Solution**: Properly integrate DeepInfant V2 with correct audio preprocessing (7s duration, 80 mel bands) for both iOS (CoreML) and web (Python backend with PyTorch/TensorFlow).

---

## Critical Findings (Research)

### Current State vs Required State

| Parameter | Current (WRONG) | Required (DeepInfant V2) |
|-----------|-----------------|--------------------------|
| **Audio Duration** | 975ms (15,600 samples) | **7 seconds (112,000 samples)** |
| **Sample Rate** | 16kHz ✓ | 16kHz ✓ |
| **Input Type** | Raw audio waveform | **Mel-spectrogram image** |
| **Mel Bands** | 128 (web) / none (iOS) | **80 mel bands** |
| **FFT Size** | 2048 (web) | **1024** |
| **Hop Length** | 512 (web) | **256** |
| **Frequency Range** | 0-8kHz | **20Hz - 8000Hz** |
| **Model** | Mock/Rule-based | **CNN-LSTM Neural Network** |
| **Cry Classes** | 6 (hunger, tired, pain, attention, discomfort, general) | **5 (hungry, needs_burping, belly_pain, discomfort, tired)** |

### Source of Truth
- GitHub: https://github.com/skytells-research/DeepInfant
- Model architecture: CNN + LSTM
- Training dataset: donateacry-corpus (multiple cry types)

---

## Feature Specification

### FS-001: DeepInfant V2 Proper Integration

**Goal**: Achieve accurate baby cry detection with correct DeepInfant V2 implementation across iOS and web platforms.

**Success Metrics**:
- [ ] AC-FS1-01: Cry detection accuracy > 85% on test dataset
- [ ] AC-FS1-02: False positive rate < 10% (non-cry sounds detected as cry)
- [ ] AC-FS1-03: Inference latency < 100ms on iOS (CoreML)
- [ ] AC-FS1-04: Inference latency < 500ms on web (API)
- [ ] AC-FS1-05: Memory usage < 50MB peak during inference

---

## User Stories

### US-001: Correct Audio Preprocessing Pipeline

**As a** developer
**I want** audio to be preprocessed according to DeepInfant V2 specifications
**So that** the model receives correctly formatted input

**Acceptance Criteria**:
- [x] AC-US1-01: Audio resampled to 16kHz mono
- [ ] AC-US1-02: Audio padded/trimmed to exactly 7 seconds (112,000 samples)
- [ ] AC-US1-03: Mel-spectrogram generated with 80 bands, 1024 FFT, 256 hop
- [ ] AC-US1-04: Frequency range limited to 20Hz-8000Hz
- [ ] AC-US1-05: Power-to-dB conversion applied (log mel-spectrogram)
- [ ] AC-US1-06: Spectrogram normalized to [0, 1] range

**Test**:
```
Given a 10-second baby cry audio file at 44.1kHz
When preprocessing is applied
Then output is mel-spectrogram of shape (80, 431) with values in [0, 1]
```

### US-002: iOS CoreML Integration

**As a** mobile user
**I want** cry detection to run on-device
**So that** I get instant results without network dependency

**Acceptance Criteria**:
- [ ] AC-US2-01: DeepInfant_V2.mlmodel converted from PyTorch/TF
- [ ] AC-US2-02: CoreML model bundled in app (< 20MB)
- [ ] AC-US2-03: Inference uses Metal GPU acceleration when available
- [ ] AC-US2-04: Fallback to CPU (Neural Engine) on older devices
- [ ] AC-US2-05: Real-time audio capture with 7-second sliding window
- [ ] AC-US2-06: Cry classes mapped: hungry→hunger, needs_burping→discomfort, belly_pain→pain

**Test**:
```
Given microphone audio stream on iPhone 12
When cry is detected in 7-second window
Then cry type is classified within 100ms with confidence score
```

### US-003: Python Backend with Real Model

**As a** web user
**I want** accurate cry classification via API
**So that** web detector works correctly

**Acceptance Criteria**:
- [ ] AC-US3-01: PyTorch or TensorFlow model loaded from weights file
- [ ] AC-US3-02: /classify endpoint accepts audio file
- [ ] AC-US3-03: Audio preprocessed with librosa using correct parameters
- [ ] AC-US3-04: Model inference returns 5 class probabilities
- [ ] AC-US3-05: Response includes is_cry, cry_type, confidence, probabilities
- [ ] AC-US3-06: Model weights cached in memory (no reload per request)

**Test**:
```
Given a 7-second WAV file uploaded to /classify
When model inference completes
Then response has cry_type in [hungry, needs_burping, belly_pain, discomfort, tired]
```

### US-004: Memory-Optimized Audio Buffer

**As a** mobile user
**I want** continuous monitoring without memory issues
**So that** the app doesn't crash during extended use

**Acceptance Criteria**:
- [ ] AC-US4-01: Circular buffer implementation for 7-second window
- [ ] AC-US4-02: Memory usage constant at ~2MB for audio buffer
- [ ] AC-US4-03: No memory leaks during 1-hour continuous monitoring
- [ ] AC-US4-04: Automatic buffer cleanup when monitoring stops
- [ ] AC-US4-05: Background mode audio capture with low power usage

**Test**:
```
Given app monitoring for 1 hour continuously
When memory profiled with Instruments
Then peak memory < 100MB and no leaks detected
```

### US-005: End-to-End Testing Suite

**As a** QA engineer
**I want** comprehensive test coverage
**So that** cry detection reliability is verified

**Acceptance Criteria**:
- [ ] AC-US5-01: Unit tests for audio preprocessing (mel-spectrogram)
- [ ] AC-US5-02: Unit tests for model inference (mock inputs)
- [ ] AC-US5-03: Integration tests with test audio files
- [ ] AC-US5-04: E2E tests with Playwright for web frontend
- [ ] AC-US5-05: E2E tests with Maestro for iOS app
- [ ] AC-US5-06: Test audio files from donateacry-corpus included

**Test**:
```
Given test suite execution
When all tests run
Then coverage > 80% for cry detection services
```

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     BABY CRY DETECTION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ Audio Input │───▶│ Preprocessing    │───▶│ DeepInfant V2 │  │
│  │ (16kHz mono)│    │ (7s, mel-spec)   │    │ (CNN-LSTM)    │  │
│  └─────────────┘    └──────────────────┘    └───────────────┘  │
│                                                      │          │
│                                                      ▼          │
│                                             ┌───────────────┐   │
│                                             │ Classification│   │
│                                             │ 5 cry types   │   │
│                                             └───────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### iOS Architecture (CoreML)

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS App (Swift)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 AudioCaptureService                        │ │
│  │  - AVAudioEngine with input node                          │ │
│  │  - 16kHz sample rate                                       │ │
│  │  - CircularBuffer (7 seconds = 112,000 samples)           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              MelSpectrogramGenerator                       │ │
│  │  - Accelerate.framework (vDSP for FFT)                    │ │
│  │  - 80 mel bands, 1024 FFT, 256 hop                        │ │
│  │  - Output: MLMultiArray (80 x 431)                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              CryClassificationService                      │ │
│  │  - CoreML model: DeepInfant_V2.mlmodel                    │ │
│  │  - GPU/Neural Engine acceleration                          │ │
│  │  - Output: CryType + confidence                           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Web Architecture (Python API)

```
┌─────────────────────────────────────────────────────────────────┐
│                   Web Frontend (JavaScript)                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────┐    ┌────────────────────┐              │
│  │ AudioProcessor.js  │───▶│ API Client         │              │
│  │ (Web Audio API)    │    │ POST /classify     │              │
│  └────────────────────┘    └────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Python Backend (FastAPI)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────┐    ┌────────────────────┐              │
│  │ Audio Preprocessor │───▶│ DeepInfant Model   │              │
│  │ - librosa          │    │ - PyTorch/TF       │              │
│  │ - 7s, 80 mel bands │    │ - Cached in memory │              │
│  └────────────────────┘    └────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### Mel-Spectrogram Parameters (CRITICAL)

```python
# Python (librosa)
mel_spectrogram = librosa.feature.melspectrogram(
    y=audio,
    sr=16000,
    n_fft=1024,      # FFT window size
    hop_length=256,  # Step between windows
    n_mels=80,       # Number of mel bands
    fmin=20,         # Min frequency (Hz)
    fmax=8000        # Max frequency (Hz)
)
log_mel = librosa.power_to_db(mel_spectrogram, ref=np.max)
normalized = (log_mel - log_mel.min()) / (log_mel.max() - log_mel.min())
```

```swift
// Swift (Accelerate framework)
let fftSize: Int = 1024
let hopLength: Int = 256
let numMelBands: Int = 80
let sampleRate: Double = 16000.0
let fMin: Float = 20.0
let fMax: Float = 8000.0

// Use vDSP for FFT, apply mel filterbank
```

### Cry Type Mapping (5 Model Classes → 3 Action Categories)

**Strategy**: Keep DeepInfant's 5-class granularity for detection accuracy, but map to **3 actionable categories** for playlist selection.

| DeepInfant V2 Output | Action Category | Playlist Type | Parent Action |
|----------------------|-----------------|---------------|---------------|
| `hungry` | **HUNGRY** | Distraction/calming music | Feed baby |
| `needs_burping` | **UNCOMFORTABLE** | Gentle rhythmic sounds | Check physical needs |
| `belly_pain` | **UNCOMFORTABLE** | Calming soothing sounds | Check physical needs |
| `discomfort` | **UNCOMFORTABLE** | Soft ambient music | Check physical needs |
| `tired` | **TIRED** | Lullabies, sleep music | Help baby sleep |

**Why 3 categories?**
1. **Actionable**: Parents can respond with clear actions (Feed / Check / Sleep)
2. **Manageable**: 3 curated playlists are easier to maintain than 5
3. **Accurate**: Model still detects 5 types, we just group for response

**Implementation**:
```swift
enum ActionCategory: String {
    case hungry = "hungry"
    case uncomfortable = "uncomfortable"
    case tired = "tired"

    static func from(modelOutput: DeepInfantCryType) -> ActionCategory {
        switch modelOutput {
        case .hungry: return .hungry
        case .needsBurping, .bellyPain, .discomfort: return .uncomfortable
        case .tired: return .tired
        }
    }
}
```

**Optional UI Enhancement**: Show detailed cry type in advanced mode while using 3 categories for playlist selection.

---

## Memory Optimization Strategy

### iOS Memory Budget

| Component | Max Memory | Strategy |
|-----------|------------|----------|
| Audio buffer | 2 MB | Circular buffer, preallocated |
| Mel-spectrogram | 0.5 MB | Single array, reused |
| CoreML model | 20 MB | Lazy load, shared instance |
| Total | < 50 MB | Monitor with Instruments |

### Circular Buffer Implementation

```swift
class CircularAudioBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let capacity: Int  // 112,000 samples for 7 seconds

    init(durationSeconds: Double, sampleRate: Double) {
        capacity = Int(durationSeconds * sampleRate)
        buffer = [Float](repeating: 0, count: capacity)
    }

    func append(_ samples: [Float]) {
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    func getOrderedSamples() -> [Float] {
        // Return samples in correct order starting from oldest
        var result = [Float](repeating: 0, count: capacity)
        for i in 0..<capacity {
            result[i] = buffer[(writeIndex + i) % capacity]
        }
        return result
    }
}
```

### Memory Leak Prevention

1. **Weak references** for delegates and closures
2. **Autorelease pools** for batch audio processing
3. **Manual buffer cleanup** on `deinit`
4. **Memory pressure notifications** to release non-critical caches

---

## Testing Strategy

### Test Pyramid

```
         ┌─────────┐
         │   E2E   │  5%  - Maestro (iOS), Playwright (Web)
         ├─────────┤
         │ Integra │ 20%  - Service + Model integration
         │  tion   │
         ├─────────┤
         │  Unit   │ 75%  - Preprocessing, inference, mapping
         │  Tests  │
         └─────────┘
```

### Test Data

1. **donateacry-corpus**: Real baby cry recordings (public dataset)
2. **Synthetic test audio**: Generated tones for edge cases
3. **Non-cry audio**: Music, speech, silence for false positive testing

### E2E Test Scenarios

| Platform | Tool | Scenario |
|----------|------|----------|
| iOS | Maestro | Tap "Start Listening" → Detect cry → Show classification |
| iOS | Maestro | Upload audio file → Classify → Display result |
| Web | Playwright | Grant mic → Record → Classify → Show probabilities |
| Web | Playwright | Upload WAV → API call → Display cry type |

---

## Implementation Phases

### Phase 1: Audio Preprocessing (Week 1)
- [ ] Implement MelSpectrogramGenerator for iOS
- [ ] Update Python backend with correct parameters
- [ ] Unit tests for preprocessing

### Phase 2: Model Integration (Week 2)
- [ ] Convert DeepInfant weights to CoreML format
- [ ] Load PyTorch/TF model in Python backend
- [ ] Verify inference with test inputs

### Phase 3: iOS Full Integration (Week 3)
- [ ] Replace mock with real CoreML model
- [ ] Implement circular buffer for audio capture
- [ ] Memory profiling and optimization

### Phase 4: Testing & Polish (Week 4)
- [ ] E2E tests with Maestro and Playwright
- [ ] Performance benchmarks
- [ ] Documentation and error handling

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CoreML conversion fails | High | Use ONNX as intermediate format |
| Model too large for app | Medium | Quantization (INT8) or pruning |
| Audio quality varies | Medium | Normalize input, handle edge cases |
| Memory pressure on old devices | Medium | Lazy loading, aggressive cleanup |

---

## Success Criteria

1. **Accuracy**: > 85% on test dataset
2. **Latency**: < 100ms iOS, < 500ms web
3. **Memory**: < 50MB peak
4. **Tests**: > 80% coverage
5. **No crashes**: 1-hour continuous monitoring stress test
