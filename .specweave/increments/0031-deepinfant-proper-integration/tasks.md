# DeepInfant V2 Integration - Tasks

## Overview
Total Tasks: 32 | Completed: 22 | In Progress: 0 | Pending: 4 | Not Needed: 6

---

## Phase 1: Audio Preprocessing Foundation

### T-001: Create MelSpectrogramGenerator for iOS
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03, AC-US1-04, AC-US1-05, AC-US1-06 | **Status**: [x] completed (pre-existing, NOT used — model has internal VGGish preprocessing)
**Test**: Given 7-second audio buffer → When generateMelSpectrogram() called → Then returns (80, 431) Float array normalized to [0,1]

**Implementation**:
```swift
// BabyInCarApp/BabyInCarApp/Services/MelSpectrogramGenerator.swift
class MelSpectrogramGenerator {
    static let numMelBands: Int = 80
    static let fftSize: Int = 1024
    static let hopLength: Int = 256
    static let fMin: Float = 20.0
    static let fMax: Float = 8000.0
    static let sampleRate: Double = 16000.0

    func generate(from samples: [Float]) -> [[Float]]
}
```

### T-002: Implement FFT using Accelerate framework
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03 | **Status**: [x] completed (pre-existing in MelSpectrogramGenerator, not needed for current model)
**Test**: Given 1024 samples → When FFT applied → Then returns 513 frequency bins

**Implementation**:
- Use `vDSP_fft_zrip` for real-to-complex FFT
- Create mel filterbank matrix
- Apply windowing (Hann window)

### T-003: Create Mel Filterbank
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03, AC-US1-04 | **Status**: [x] completed (pre-existing, not needed for current model)
**Test**: Given fMin=20Hz, fMax=8000Hz, 80 bands → When filterbank created → Then shape is (80, 513)

### T-004: Update Python backend preprocessing
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed (updated to 15,600 samples, 3-tier inference)
**Test**: Given WAV file → When preprocessed → Then mel-spectrogram matches DeepInfant specs

**Changes to `cry-classifier-api/main.py`**:
```python
# Replace current settings
N_FFT = 1024       # Was 2048
HOP_LENGTH = 256   # Was 512
N_MELS = 80        # Was 128
REQUIRED_DURATION = 7.0  # Was 2.0

mel_spec = librosa.feature.melspectrogram(
    y=y, sr=sr,
    n_fft=N_FFT,
    hop_length=HOP_LENGTH,
    n_mels=N_MELS,
    fmin=20,
    fmax=8000
)
```

### T-005: Create CircularAudioBuffer for iOS
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed (pre-existing, now wired into AudioCaptureService)
**Test**: Given continuous audio stream → When buffer fills → Then contains exactly 7 seconds in correct order

**Implementation**:
```swift
// BabyInCarApp/BabyInCarApp/Services/CircularAudioBuffer.swift
class CircularAudioBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    let capacity: Int = 112_000  // 7s at 16kHz

    func append(_ samples: [Float])
    func getOrderedSamples() -> [Float]
    func isFull() -> Bool
}
```

### T-006: Unit tests for audio preprocessing
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed (pre-existing tests for MelSpectrogramGenerator and CircularAudioBuffer)
**Test**: All preprocessing unit tests pass

**Test file**: `BabyInCarAppTests/Services/MelSpectrogramGeneratorTests.swift`

---

## Phase 2: Model Integration

### T-007: Download and convert DeepInfant weights to CoreML
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 | **Status**: [N/A] not needed (model already bundled, built with Apple Create ML)
**Test**: Given PyTorch/TF model → When converted with coremltools → Then .mlmodel validates

**Steps**:
1. Clone https://github.com/skytells-research/DeepInfant
2. Load pretrained weights
3. Convert using `coremltools.convert()`
4. Validate output shape: (5,) probabilities

### T-008: Create CoreML model wrapper
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02, AC-US2-03 | **Status**: [N/A] not needed (CryClassificationService already wraps model correctly)
**Test**: Given mel-spectrogram input → When predict() called → Then returns 5 probabilities

**Implementation**:
```swift
// BabyInCarApp/BabyInCarApp/Services/DeepInfantModel.swift
class DeepInfantModel {
    private let model: DeepInfant_V2

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Use GPU/Neural Engine
        model = try DeepInfant_V2(configuration: config)
    }

    func predict(melSpectrogram: MLMultiArray) throws -> [String: Float]
}
```

### T-009: Load PyTorch model in Python backend
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-06 | **Status**: [x] completed (3-tier: CoreML → ONNX → rule-based)
**Test**: Given model weights file → When loaded → Then inference works

**Implementation**:
```python
# cry-classifier-api/main.py
import torch
from model import DeepInfantV2  # CNN-LSTM architecture

model = None

@app.on_event("startup")
async def load_model():
    global model
    model = DeepInfantV2()
    model.load_state_dict(torch.load("models/deepinfant_v2.pth"))
    model.eval()
```

### T-010: Define DeepInfant CNN-LSTM architecture
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 | **Status**: [N/A] not needed (model is VGGish CNN + GLM, not CNN-LSTM; ONNX converter created instead)
**Test**: Given architecture definition → When instantiated → Then matches paper specs

**File**: `cry-classifier-api/model.py`

### T-011: Replace mock model in iOS
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 | **Status**: [N/A] not needed (no mock model exists, real model already in use)
**Test**: Given real CoreML model → When used instead of mock → Then inference returns valid results

**Changes**:
- Remove `DeepInfant_V2_Mock.swift`
- Update `CryClassificationService.swift` to use real model
- Update sample count to 112,000

### T-012: Add model weights to app bundle
**User Story**: US-002 | **Satisfies ACs**: AC-US2-02 | **Status**: [N/A] not needed (model already bundled at 5.1MB)
**Test**: Given .mlmodel file → When added to Xcode → Then builds and loads at runtime

---

## Phase 3: Cry Type Mapping & Integration

### T-013: Create ActionCategory enum
**User Story**: US-002 | **Satisfies ACs**: AC-US2-06 | **Status**: [x] completed (pre-existing in ActionCategory.swift)
**Test**: Given model output → When mapped → Then returns correct ActionCategory

**Implementation**:
```swift
enum DeepInfantCryType: String, Codable {
    case hungry
    case needsBurping = "needs_burping"
    case bellyPain = "belly_pain"
    case discomfort
    case tired
}

enum ActionCategory: String {
    case hungry
    case uncomfortable
    case tired

    static func from(_ cryType: DeepInfantCryType) -> ActionCategory {
        switch cryType {
        case .hungry: return .hungry
        case .needsBurping, .bellyPain, .discomfort: return .uncomfortable
        case .tired: return .tired
        }
    }
}
```

### T-014: Update CryClassificationService
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05 | **Status**: [x] completed (added ActionCategory bridge + memory pressure handling)
**Test**: Given audio stream → When processed → Then returns CryResult with type and category

**Changes to `CryClassificationService.swift`**:
- Update `requiredSampleCount` to 112,000
- Use `MelSpectrogramGenerator`
- Use `DeepInfantModel`
- Return both raw `DeepInfantCryType` and `ActionCategory`

### T-015: Create playlist mapping service
**User Story**: US-002 | **Satisfies ACs**: AC-US2-06 | **Status**: [x] completed (pre-existing CryResponsePlaylist in ActionCategory.swift)
**Test**: Given ActionCategory → When requested → Then returns appropriate playlist

**Implementation**:
```swift
class CryResponsePlaylistService {
    func getPlaylist(for category: ActionCategory) -> [AudioTrack] {
        switch category {
        case .hungry: return distractionPlaylist
        case .uncomfortable: return soothingPlaylist
        case .tired: return lullabyPlaylist
        }
    }
}
```

### T-016: Update Python API response format
**User Story**: US-003 | **Satisfies ACs**: AC-US3-04, AC-US3-05 | **Status**: [x] completed (5 probabilities + action_category + model_used)
**Test**: Given classification result → When formatted → Then includes 5 probabilities and action_category

**Response format**:
```json
{
  "is_cry": true,
  "cry_type": "belly_pain",
  "action_category": "uncomfortable",
  "confidence": 0.87,
  "probabilities": {
    "hungry": 0.05,
    "needs_burping": 0.03,
    "belly_pain": 0.87,
    "discomfort": 0.03,
    "tired": 0.02
  }
}
```

---

## Phase 4: Memory Optimization

### T-017: Implement memory-efficient audio capture
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02 | **Status**: [x] completed (CircularAudioBuffer wired into AudioCaptureService, zero-copy append)
**Test**: Given 1 hour monitoring → When profiled → Then memory constant at ~2MB for buffer

### T-018: Add memory pressure handling
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03 | **Status**: [x] completed (3-level: warning/critical/emergency in CryClassificationService)
**Test**: Given low memory warning → When received → Then non-critical caches released

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleMemoryWarning),
    name: UIApplication.didReceiveMemoryWarningNotification,
    object: nil
)
```

### T-019: Implement lazy model loading
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03 | **Status**: [x] completed (pre-existing: loads on first classify(), unloads on stop)
**Test**: Given app launch → When model not needed → Then model not loaded until first use

### T-020: Add background audio capture
**User Story**: US-004 | **Satisfies ACs**: AC-US4-05 | **Status**: [x] completed (UIBackgroundModes: audio, fetch, processing already in Info.plist)
**Test**: Given app in background → When cry detected → Then notification sent

**Requirements**:
- Background audio capability in Info.plist
- Low-power audio session configuration

### T-021: Memory profiling with Instruments
**User Story**: US-004 | **Satisfies ACs**: AC-US4-03, AC-US4-04 | **Status**: [ ] pending (manual verification needed)
**Test**: Given 1-hour stress test → When profiled → Then no memory leaks, peak < 100MB

---

## Phase 5: Testing Suite

### T-022: Create unit tests for MelSpectrogramGenerator
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed (pre-existing: 180 lines, 8 test groups)
**Test**: All mel-spectrogram unit tests pass

### T-023: Create unit tests for DeepInfantModel
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02 | **Status**: [x] completed (pre-existing: CryClassificationServiceTests 283 lines)
**Test**: All model inference tests pass with mock inputs

### T-024: Create integration tests for CryClassificationService
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03 | **Status**: [ ] pending (needs test audio files)
**Test**: Given test audio files → When classified → Then correct types returned

### T-025: Download donateacry-corpus test files
**User Story**: US-005 | **Satisfies ACs**: AC-US5-06 | **Status**: [ ] pending
**Test**: Test audio files available in `BabyInCarAppTests/Fixtures/`

### T-026: Create Playwright tests for web frontend
**User Story**: US-005 | **Satisfies ACs**: AC-US5-04 | **Status**: [ ] pending
**Test**: All web E2E tests pass

**Tests**:
- Upload audio file → API returns classification
- Display cry type probabilities
- Show action category recommendation

### T-027: Create Maestro tests for iOS
**User Story**: US-005 | **Satisfies ACs**: AC-US5-05 | **Status**: [ ] pending
**Test**: All iOS E2E tests pass

**Flows**:
```yaml
# maestro/flows/cry_detection_deepinfant_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- assertVisible: "Listening..."
- runScript: { file: "inject_test_audio.js" }
- assertVisible:
    id: "cryTypeLabel"
- takeScreenshot: "cry_detected"
```

### T-028: Python API unit tests
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed (63 tests passing)
**Test**: All preprocessing and inference tests pass

```python
# cry-classifier-api/tests/test_preprocessing.py
def test_mel_spectrogram_shape():
    audio = load_test_audio("cry_7s.wav")
    mel = generate_mel_spectrogram(audio)
    assert mel.shape == (80, 431)
```

### T-029: Performance benchmark tests
**User Story**: US-005 | **Satisfies ACs**: AC-FS1-03, AC-FS1-04 | **Status**: [ ] pending
**Test**: iOS inference < 100ms, API inference < 500ms

---

## Phase 6: Documentation & Polish

### T-030: Update CLAUDE.md with DeepInfant specs
**User Story**: - | **Satisfies ACs**: - | **Status**: [ ] pending (needs update with correct model architecture)
**Test**: Documentation reflects actual implementation

### T-031: Create API documentation
**User Story**: - | **Satisfies ACs**: - | **Status**: [ ] pending
**Test**: OpenAPI spec matches implementation

### T-032: Error handling and edge cases
**User Story**: - | **Satisfies ACs**: - | **Status**: [ ] pending
**Test**: Graceful handling of: too short audio, corrupt files, model load failure

---

## Dependencies

```
T-001 ──► T-006 ──► T-022
T-002 ──► T-001
T-003 ──► T-001
T-004 ──► T-028
T-005 ──► T-017
T-007 ──► T-008 ──► T-011 ──► T-014
T-009 ──► T-010
T-013 ──► T-014 ──► T-015
T-025 ──► T-024, T-026, T-027
```

## Priority Order

1. **Critical Path (Blocks everything)**:
   - T-001: MelSpectrogramGenerator
   - T-007: CoreML conversion
   - T-009: PyTorch model loading

2. **Integration (Enables features)**:
   - T-011: Replace mock model
   - T-014: Update CryClassificationService
   - T-016: API response format

3. **Quality (Ensures reliability)**:
   - T-022-T-029: All tests
   - T-021: Memory profiling

4. **Polish (Nice to have)**:
   - T-030-T-032: Documentation
