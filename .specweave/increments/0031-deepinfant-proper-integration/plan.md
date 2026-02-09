# DeepInfant V2 Proper Integration - Implementation Plan

## Executive Summary

This plan outlines a phased approach to properly integrate DeepInfant V2 into the AntiCry Baby App. The key discovery is that the current implementation uses mocks and rule-based heuristics instead of actual neural network inference, with completely wrong audio preprocessing parameters.

**Current state**: Broken (mocks, wrong params)
**Target state**: Fully functional cry detection with CoreML (iOS) and PyTorch (web API)

---

## Architecture Decision: 3 Action Categories

### Why 3 Categories Instead of 5?

| Approach | Pros | Cons |
|----------|------|------|
| **5 classes** (raw model output) | Maximum granularity | 5 playlists to maintain, confusing for parents |
| **3 categories** (mapped) | Actionable, simple UX, fewer playlists | Loses some nuance |

**Decision**: Use **3 action categories** for playlist selection while preserving 5-class output in the model.

```
Model Output (5)           Action Category (3)        Response
─────────────────────────────────────────────────────────────────
hungry                  →  HUNGRY            →  Distraction playlist
needs_burping          ─┐
belly_pain             ─┼→ UNCOMFORTABLE     →  Soothing playlist
discomfort             ─┘
tired                   →  TIRED             →  Lullaby playlist
```

---

## Phase 1: Audio Preprocessing (Days 1-3)

### Goal
Create correct mel-spectrogram generator matching DeepInfant V2 specs.

### Key Changes

| Parameter | Before | After |
|-----------|--------|-------|
| Duration | 975ms | **7 seconds** |
| FFT Size | 2048 | **1024** |
| Hop Length | 512 | **256** |
| Mel Bands | 128 (web) / 0 (iOS) | **80** |
| Frequency Range | 0-8kHz | **20Hz-8000Hz** |

### iOS Implementation

```swift
// MelSpectrogramGenerator.swift
import Accelerate

class MelSpectrogramGenerator {
    // DeepInfant V2 specifications
    static let numMelBands: Int = 80
    static let fftSize: Int = 1024
    static let hopLength: Int = 256
    static let fMin: Float = 20.0
    static let fMax: Float = 8000.0
    static let sampleRate: Double = 16000.0
    static let requiredSamples: Int = 112_000  // 7 seconds

    private var fftSetup: FFTSetup?
    private var melFilterbank: [[Float]]

    init() {
        fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Float(Self.fftSize))),
            FFTRadix(kFFTRadix2)
        )
        melFilterbank = createMelFilterbank()
    }

    func generate(from samples: [Float]) -> [[Float]] {
        // 1. Apply windowing (Hann)
        // 2. Compute STFT using vDSP
        // 3. Apply mel filterbank
        // 4. Convert to log scale
        // 5. Normalize to [0, 1]
    }
}
```

### Python Implementation

```python
# cry-classifier-api/preprocessing.py
import librosa
import numpy as np

def preprocess_audio(audio_bytes: bytes) -> np.ndarray:
    """Convert audio to mel-spectrogram for DeepInfant V2."""

    # Load and resample
    y, sr = librosa.load(audio_file, sr=16000, mono=True)

    # Pad/trim to exactly 7 seconds
    target_length = 7 * 16000  # 112,000 samples
    if len(y) < target_length:
        y = np.pad(y, (0, target_length - len(y)))
    else:
        y = y[:target_length]

    # Generate mel-spectrogram with DeepInfant specs
    mel = librosa.feature.melspectrogram(
        y=y,
        sr=16000,
        n_fft=1024,
        hop_length=256,
        n_mels=80,
        fmin=20,
        fmax=8000
    )

    # Convert to log scale and normalize
    log_mel = librosa.power_to_db(mel, ref=np.max)
    normalized = (log_mel - log_mel.min()) / (log_mel.max() - log_mel.min() + 1e-6)

    return normalized  # Shape: (80, 431)
```

### Deliverables
- [ ] `MelSpectrogramGenerator.swift` for iOS
- [ ] Updated `preprocessing.py` for Python API
- [ ] Unit tests for both implementations
- [ ] Verified output shape: (80, 431)

---

## Phase 2: Model Integration (Days 4-7)

### Goal
Replace mocks with actual DeepInfant V2 neural network.

### iOS: CoreML Conversion

```bash
# Step 1: Clone DeepInfant repository
git clone https://github.com/skytells-research/DeepInfant.git
cd DeepInfant

# Step 2: Export model (if PyTorch)
python export_model.py --format onnx

# Step 3: Convert to CoreML
pip install coremltools onnx
python -c "
import coremltools as ct
import onnx

# Load ONNX model
onnx_model = onnx.load('deepinfant_v2.onnx')

# Convert to CoreML
mlmodel = ct.converters.onnx.convert(
    onnx_model,
    minimum_ios_deployment_target='15.0'
)

# Optimize for Neural Engine
mlmodel = ct.models.neural_network.quantization_utils.quantize_weights(
    mlmodel, nbits=16
)

mlmodel.save('DeepInfant_V2.mlmodel')
"
```

### iOS Model Wrapper

```swift
// DeepInfantModel.swift
import CoreML

class DeepInfantModel {
    private let model: DeepInfant_V2

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // GPU + Neural Engine
        model = try DeepInfant_V2(configuration: config)
    }

    func predict(melSpectrogram: [[Float]]) throws -> [DeepInfantCryType: Float] {
        // Convert to MLMultiArray
        let input = try MLMultiArray(shape: [1, 80, 431, 1], dataType: .float32)
        // ... fill array ...

        let output = try model.prediction(input: input)

        return [
            .hungry: output.probabilities["hungry"] ?? 0,
            .needsBurping: output.probabilities["needs_burping"] ?? 0,
            .bellyPain: output.probabilities["belly_pain"] ?? 0,
            .discomfort: output.probabilities["discomfort"] ?? 0,
            .tired: output.probabilities["tired"] ?? 0
        ]
    }
}
```

### Python: PyTorch Model

```python
# cry-classifier-api/model.py
import torch
import torch.nn as nn

class DeepInfantV2(nn.Module):
    """CNN-LSTM architecture as per DeepInfant paper."""

    def __init__(self, num_classes=5):
        super().__init__()

        # CNN layers
        self.conv1 = nn.Conv2d(1, 32, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.dropout = nn.Dropout(0.25)

        # LSTM layer
        self.lstm = nn.LSTM(
            input_size=128 * 10,  # After conv/pool
            hidden_size=256,
            num_layers=2,
            batch_first=True,
            bidirectional=True
        )

        # Classification head
        self.fc = nn.Linear(512, num_classes)

    def forward(self, x):
        # x shape: (batch, 1, 80, 431)
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = self.pool(F.relu(self.conv3(x)))
        x = self.dropout(x)

        # Reshape for LSTM
        batch, c, h, w = x.shape
        x = x.permute(0, 3, 1, 2).reshape(batch, w, c * h)

        # LSTM
        x, _ = self.lstm(x)
        x = x[:, -1, :]  # Last timestep

        # Classification
        x = self.fc(x)
        return F.softmax(x, dim=1)


# Load weights at startup
model = DeepInfantV2()
model.load_state_dict(torch.load("models/deepinfant_v2.pth", map_location="cpu"))
model.eval()
```

### Deliverables
- [ ] `DeepInfant_V2.mlmodel` (CoreML format)
- [ ] `DeepInfantModel.swift` wrapper
- [ ] `model.py` with PyTorch architecture
- [ ] Model weights file (`deepinfant_v2.pth`)
- [ ] Remove `DeepInfant_V2_Mock.swift`

---

## Phase 3: Service Integration (Days 8-10)

### Goal
Wire up preprocessing → model → classification result.

### Updated CryClassificationService

```swift
// CryClassificationService.swift
class CryClassificationService {
    static let requiredSampleCount = 112_000  // 7 seconds at 16kHz

    private let melGenerator = MelSpectrogramGenerator()
    private let model: DeepInfantModel

    init() throws {
        model = try DeepInfantModel()
    }

    func classify(audioSamples: [Float]) async throws -> CryClassificationResult {
        // 1. Generate mel-spectrogram
        let melSpec = melGenerator.generate(from: audioSamples)

        // 2. Run inference
        let probabilities = try model.predict(melSpectrogram: melSpec)

        // 3. Find best prediction
        let (cryType, confidence) = probabilities.max(by: { $0.value < $1.value })!

        // 4. Map to action category
        let actionCategory = ActionCategory.from(cryType)

        return CryClassificationResult(
            isCry: confidence > 0.5,
            rawCryType: cryType,
            actionCategory: actionCategory,
            confidence: confidence,
            probabilities: probabilities
        )
    }
}
```

### Action Category Mapping

```swift
enum ActionCategory: String, Codable {
    case hungry = "hungry"
    case uncomfortable = "uncomfortable"
    case tired = "tired"

    var displayName: String {
        switch self {
        case .hungry: return "Hungry"
        case .uncomfortable: return "Uncomfortable"
        case .tired: return "Tired"
        }
    }

    var suggestedAction: String {
        switch self {
        case .hungry: return "Baby may be hungry - try feeding"
        case .uncomfortable: return "Baby seems uncomfortable - check diaper, temperature, or gas"
        case .tired: return "Baby is tired - try soothing to sleep"
        }
    }

    var playlistCategory: String {
        switch self {
        case .hungry: return "distraction"
        case .uncomfortable: return "soothing"
        case .tired: return "lullaby"
        }
    }

    static func from(_ cryType: DeepInfantCryType) -> ActionCategory {
        switch cryType {
        case .hungry: return .hungry
        case .needsBurping, .bellyPain, .discomfort: return .uncomfortable
        case .tired: return .tired
        }
    }
}
```

### Deliverables
- [ ] Updated `CryClassificationService.swift`
- [ ] `ActionCategory.swift` enum
- [ ] `CryClassificationResult` model
- [ ] Playlist integration with action categories

---

## Phase 4: Memory Optimization (Days 11-12)

### Goal
Ensure stable operation during extended monitoring sessions.

### Circular Buffer for Audio

```swift
class CircularAudioBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let capacity: Int

    init(durationSeconds: Double = 7.0, sampleRate: Double = 16000.0) {
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
        var result = [Float](repeating: 0, count: capacity)
        for i in 0..<capacity {
            result[i] = buffer[(writeIndex + i) % capacity]
        }
        return result
    }

    func reset() {
        buffer = [Float](repeating: 0, count: capacity)
        writeIndex = 0
    }
}
```

### Memory Budget

| Component | Allocation | Notes |
|-----------|------------|-------|
| Audio buffer | 450 KB | 112,000 × 4 bytes |
| Mel-spectrogram | 138 KB | 80 × 431 × 4 bytes |
| CoreML model | ~15 MB | Loaded once, shared |
| Working memory | ~5 MB | FFT buffers, temps |
| **Total** | **~20 MB** | Well under 50 MB limit |

### Lazy Loading

```swift
class CryDetectionManager {
    private var _classificationService: CryClassificationService?

    var classificationService: CryClassificationService {
        if _classificationService == nil {
            _classificationService = try? CryClassificationService()
        }
        return _classificationService!
    }

    func unloadModel() {
        _classificationService = nil
    }
}
```

### Deliverables
- [ ] `CircularAudioBuffer.swift`
- [ ] Lazy model loading
- [ ] Memory pressure handlers
- [ ] Instruments profiling report

---

## Phase 5: Testing Suite (Days 13-15)

### Goal
Comprehensive test coverage ensuring reliability.

### Test Data Sources

1. **donateacry-corpus**: Real baby cry recordings
   - Download from: https://github.com/gveres/donateacry-corpus
   - 5 categories matching DeepInfant classes

2. **Synthetic test audio**: For edge cases
   ```python
   # Generate test tones
   silence = np.zeros(112000)
   noise = np.random.randn(112000) * 0.1
   tone_440hz = np.sin(2 * np.pi * 440 * np.arange(112000) / 16000)
   ```

### Test Categories

| Type | Tool | Coverage Target |
|------|------|-----------------|
| Unit tests (preprocessing) | XCTest/Swift Testing | 90% |
| Unit tests (model) | XCTest with mock inputs | 85% |
| Integration tests | XCTest with test audio | 80% |
| E2E (iOS) | Maestro | 5 flows |
| E2E (Web) | Playwright | 10 tests |

### Sample Maestro Flow

```yaml
# maestro/flows/cry_detection_deepinfant_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Cry Detection"
- assertVisible: "Listening..."

# Simulate cry detection (via accessibility action)
- runScript:
    file: inject_cry_audio.js

- waitForAnimationToEnd
- assertVisible:
    text: "Cry Detected"
    timeout: 10000

- assertVisible:
    anyOf:
      - "Hungry"
      - "Uncomfortable"
      - "Tired"

- takeScreenshot: cry_classification_result
```

### Deliverables
- [ ] Unit test files for all services
- [ ] Test audio fixtures
- [ ] Maestro E2E flows
- [ ] Playwright tests
- [ ] CI/CD integration

---

## Phase 6: Polish & Documentation (Days 16-17)

### Goal
Production-ready code with proper documentation.

### Tasks
- [ ] Error handling for model load failures
- [ ] Graceful degradation (show generic message if classification fails)
- [ ] Update CLAUDE.md with DeepInfant integration docs
- [ ] API documentation (OpenAPI spec)
- [ ] Code comments for complex algorithms

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| CoreML conversion fails | HIGH | Use ONNX intermediate, try TFLite |
| Model too large | MEDIUM | Quantize to INT8 (~4x smaller) |
| Accuracy lower than expected | MEDIUM | Fine-tune on more data, adjust thresholds |
| Memory issues on old devices | LOW | Aggressive lazy loading, reduce buffer size |

---

## Success Criteria

1. **Accuracy**: >85% on donateacry-corpus test set
2. **Latency**: <100ms inference on iPhone 12+
3. **Memory**: <50MB peak during monitoring
4. **Tests**: >80% coverage, all E2E passing
5. **Stability**: 1-hour continuous monitoring without crash

---

## Timeline Summary

| Phase | Days | Key Deliverable |
|-------|------|-----------------|
| 1. Preprocessing | 1-3 | Mel-spectrogram generators |
| 2. Model Integration | 4-7 | Working CoreML + PyTorch |
| 3. Service Integration | 8-10 | End-to-end classification |
| 4. Memory Optimization | 11-12 | Circular buffer, profiling |
| 5. Testing | 13-15 | Full test suite |
| 6. Polish | 16-17 | Documentation, error handling |

**Total: ~17 working days**
