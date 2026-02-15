"""
Cry Classification API - DeepInfant V2 Backend

This API provides baby cry classification using the DeepInfant V2 model.
It processes audio files and returns cry type predictions with confidence scores.

Model pipeline (CoreML DeepInfant V2):
  Step 0: VGGish preprocessing (16kHz -> [1, 96, 64] log-mel spectrogram)
  Step 1: VGG-like CNN (8-bit quantized) -> [12288] features
  Step 2: GLM Classifier -> 9 classes (softmax)

The model takes 15,600 raw audio samples at 16kHz (~975ms) as input.

Inference backends (in priority order):
  1. CoreML (macOS only) - Direct model inference, 100% accurate
  2. ONNX Runtime - Cross-platform, uses exported CNN+GLM with VGGish preprocessing
  3. Rule-based fallback - Feature-based heuristic classification

Deployment: Railway, Fly.io, or any Python hosting
"""

import io
import os
import tempfile
from typing import Optional
from enum import Enum

import numpy as np
import librosa
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


# ========== Configuration ==========

# DeepInfant V2 model input specification
SAMPLE_RATE = 16000           # 16kHz sample rate
REQUIRED_SAMPLES = 15600      # ~975ms at 16kHz (model input size)
REQUIRED_DURATION = 0.975     # seconds

# VGGish preprocessing parameters (Apple's soundAnalysisPreprocessing)
# These produce the [1, 96, 64] log-mel spectrogram expected by the CNN
VGGISH_SAMPLE_RATE = 16000
VGGISH_WINDOW_LENGTH = 400    # 25ms window
VGGISH_HOP_LENGTH = 160       # 10ms hop
VGGISH_N_MELS = 64            # 64 mel bands
VGGISH_F_MIN = 125.0          # Minimum frequency
VGGISH_F_MAX = 7500.0         # Maximum frequency
VGGISH_N_FRAMES = 96          # Output time frames
VGGISH_LOG_OFFSET = 0.01      # Offset for log computation

# Rule-based fallback preprocessing (uses longer audio for better features)
FALLBACK_N_FFT = 1024
FALLBACK_HOP_LENGTH = 256
FALLBACK_N_MELS = 80
FALLBACK_F_MIN = 20
FALLBACK_F_MAX = 8000
FALLBACK_DURATION = 7.0       # 7 seconds for rule-based
FALLBACK_SAMPLES = 112000     # 7s * 16kHz

# DeepInfant V2 class labels (9 classes)
CLASS_LABELS = [
    "belly_pain", "burping", "cold_hot", "discomfort",
    "hungry", "lonely", "scared", "tired", "unknown"
]

# Map 9 model classes to 5 user-facing cry types
MODEL_TO_CRY_TYPE = {
    "hungry": "hungry",
    "burping": "needs_burping",
    "belly_pain": "belly_pain",
    "discomfort": "discomfort",
    "cold_hot": "discomfort",
    "tired": "tired",
    "lonely": "discomfort",
    "scared": "discomfort",
    "unknown": "unknown",
}


# ========== Model Loading ==========

# Inference backend state
_inference_backend = "none"
_coreml_model = None
_onnx_session = None


def _try_load_coreml():
    """Attempt to load the CoreML model (macOS only)."""
    global _coreml_model, _inference_backend
    try:
        import coremltools as ct

        search_paths = [
            os.environ.get('DEEPINFANT_MODEL_PATH', ''),
            'models/DeepInfant_V2.mlmodel',
            '../BabyInCarApp/BabyInCarApp/Resources/DeepInfant_V2.mlmodel',
        ]

        for path in search_paths:
            if path and os.path.exists(path):
                _coreml_model = ct.models.MLModel(path)
                _inference_backend = "coreml"
                print(f"[INFO] CoreML model loaded from {path}")

                # Verify model input: should accept audioSamples [15600]
                spec = _coreml_model.get_spec()
                for inp in spec.description.input:
                    if inp.name == 'audioSamples':
                        shape = list(inp.type.multiArrayType.shape)
                        print(f"[INFO] Model input: {inp.name} shape={shape}")
                return True

        print("[INFO] CoreML model file not found")
        return False
    except ImportError:
        print("[INFO] coremltools not available (not macOS)")
        return False
    except Exception as e:
        print(f"[WARN] Failed to load CoreML model: {e}")
        return False


def _try_load_onnx():
    """Attempt to load the ONNX model (cross-platform)."""
    global _onnx_session, _inference_backend
    try:
        import onnxruntime as ort

        onnx_path = os.environ.get(
            'DEEPINFANT_ONNX_PATH',
            'models/deepinfant_v2_cnn_glm.onnx'
        )

        if os.path.exists(onnx_path):
            _onnx_session = ort.InferenceSession(onnx_path)
            _inference_backend = "onnx"
            print(f"[INFO] ONNX model loaded from {onnx_path}")

            # Verify input shape
            inp = _onnx_session.get_inputs()[0]
            print(f"[INFO] ONNX input: {inp.name} shape={inp.shape}")
            return True

        print(f"[INFO] ONNX model not found at {onnx_path}")
        return False
    except ImportError:
        print("[INFO] onnxruntime not available")
        return False
    except Exception as e:
        print(f"[WARN] Failed to load ONNX model: {e}")
        return False


# Load models at startup (priority: CoreML > ONNX > rule-based)
if not _try_load_coreml():
    if not _try_load_onnx():
        _inference_backend = "rule_based"
        print("[INFO] Using rule-based fallback classification")


# ========== Enums and Models ==========

class ActionCategory(str, Enum):
    HUNGRY = "hungry"
    UNCOMFORTABLE = "uncomfortable"
    TIRED = "tired"


def get_action_category(cry_type: str) -> str:
    """Map cry type to action category.

    - hungry -> hungry (feed baby)
    - needs_burping, belly_pain, discomfort -> uncomfortable (check physical needs)
    - tired -> tired (help baby sleep)
    """
    mapping = {
        "hungry": ActionCategory.HUNGRY.value,
        "needs_burping": ActionCategory.UNCOMFORTABLE.value,
        "belly_pain": ActionCategory.UNCOMFORTABLE.value,
        "discomfort": ActionCategory.UNCOMFORTABLE.value,
        "tired": ActionCategory.TIRED.value,
        # Legacy mappings for backwards compatibility
        "hunger": ActionCategory.HUNGRY.value,
        "pain": ActionCategory.UNCOMFORTABLE.value,
        "attention": ActionCategory.UNCOMFORTABLE.value,
        "general": ActionCategory.UNCOMFORTABLE.value,
        # Direct model output mappings
        "burping": ActionCategory.UNCOMFORTABLE.value,
        "cold_hot": ActionCategory.UNCOMFORTABLE.value,
        "lonely": ActionCategory.UNCOMFORTABLE.value,
        "scared": ActionCategory.UNCOMFORTABLE.value,
        "unknown": ActionCategory.UNCOMFORTABLE.value,
    }
    return mapping.get(cry_type.lower(), ActionCategory.UNCOMFORTABLE.value)


class ClassificationResult(BaseModel):
    is_cry: bool
    cry_type: Optional[str] = None
    action_category: Optional[str] = None
    confidence: float
    probabilities: dict
    model_used: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_type: str
    inference_backend: str


# ========== FastAPI App ==========

app = FastAPI(
    title="Cry Classification API",
    description="DeepInfant V2 baby cry classification service",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ========== Audio Processing ==========

def load_audio_from_bytes(audio_bytes: bytes) -> np.ndarray:
    """Load audio from bytes and resample to 16kHz mono.

    Returns raw audio samples as float32 numpy array.
    """
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        y, sr = librosa.load(temp_path, sr=SAMPLE_RATE, mono=True)
        return y
    finally:
        os.unlink(temp_path)


def prepare_coreml_input(y: np.ndarray) -> np.ndarray:
    """Prepare audio samples for CoreML model input.

    The DeepInfant V2 CoreML model expects exactly 15,600 float32 samples
    at 16kHz (~975ms). Pads short audio or trims long audio.
    """
    if len(y) < REQUIRED_SAMPLES:
        y = np.pad(y, (0, REQUIRED_SAMPLES - len(y)), mode='constant')
    elif len(y) > REQUIRED_SAMPLES:
        y = y[:REQUIRED_SAMPLES]
    return y.astype(np.float32)


def compute_vggish_features(y: np.ndarray) -> np.ndarray:
    """Compute VGGish-style log-mel spectrogram for ONNX inference.

    Replicates Apple's soundAnalysisPreprocessing (VGGish mode):
    - 16kHz sample rate
    - 25ms window (400 samples), 10ms hop (160 samples)
    - 64 mel bands, 125Hz-7500Hz
    - Log mel spectrogram
    - Output shape: [1, 96, 64]
    """
    # Ensure correct length
    y = prepare_coreml_input(y)

    # Compute mel spectrogram with VGGish parameters
    mel_spec = librosa.feature.melspectrogram(
        y=y,
        sr=VGGISH_SAMPLE_RATE,
        n_fft=VGGISH_WINDOW_LENGTH,
        hop_length=VGGISH_HOP_LENGTH,
        n_mels=VGGISH_N_MELS,
        fmin=VGGISH_F_MIN,
        fmax=VGGISH_F_MAX,
        window='hann',
        center=True,
        pad_mode='constant',
    )

    # Convert to log scale (matching VGGish: log(mel + offset))
    log_mel = np.log(mel_spec + VGGISH_LOG_OFFSET)

    # Ensure correct number of frames
    if log_mel.shape[1] < VGGISH_N_FRAMES:
        # Pad with log(offset) (silence)
        pad_width = VGGISH_N_FRAMES - log_mel.shape[1]
        log_mel = np.pad(
            log_mel,
            ((0, 0), (0, pad_width)),
            mode='constant',
            constant_values=np.log(VGGISH_LOG_OFFSET)
        )
    elif log_mel.shape[1] > VGGISH_N_FRAMES:
        log_mel = log_mel[:, :VGGISH_N_FRAMES]

    # Transpose to [frames, mel_bands] then reshape to [1, 96, 64]
    # VGGish output is [time, mel] = [96, 64]
    features = log_mel.T  # [96, 64]

    return features.reshape(1, VGGISH_N_FRAMES, VGGISH_N_MELS).astype(np.float32)


def extract_features(y: np.ndarray, sr: int) -> dict:
    """Extract audio features for rule-based classification and debugging."""
    rms = librosa.feature.rms(y=y)[0]
    rms_mean = float(np.mean(rms))

    spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    centroid_mean = float(np.mean(spectral_centroid))

    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
    rolloff_mean = float(np.mean(rolloff))

    zcr = librosa.feature.zero_crossing_rate(y)[0]
    zcr_mean = float(np.mean(zcr))

    pitches, magnitudes = librosa.piptrack(y=y, sr=sr)
    pitch_mean = float(np.mean(pitches[pitches > 0])) if np.any(pitches > 0) else 0

    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    onset_mean = float(np.mean(onset_env))

    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    contrast_mean = float(np.mean(contrast))

    return {
        "rms": rms_mean,
        "spectral_centroid": centroid_mean,
        "spectral_rolloff": rolloff_mean,
        "zero_crossing_rate": zcr_mean,
        "pitch_mean": pitch_mean,
        "onset_strength": onset_mean,
        "spectral_contrast": contrast_mean,
        "duration_seconds": len(y) / sr
    }


# ========== Classification Backends ==========

def classify_with_coreml(audio_samples: np.ndarray) -> dict:
    """Classify using the CoreML DeepInfant V2 model.

    The model takes raw audio samples [15600] and internally performs:
    1. VGGish preprocessing -> [1, 96, 64] log-mel spectrogram
    2. CNN feature extraction -> [12288] features
    3. GLM classification -> 9 class probabilities

    Output keys: 'target' (string), 'targetProbability' (dict)
    """
    if _coreml_model is None:
        raise RuntimeError("CoreML model not available")

    # Model expects exactly 15,600 float32 samples
    samples = prepare_coreml_input(audio_samples)
    prediction = _coreml_model.predict({'audioSamples': samples})

    # Parse output
    target = prediction['target']
    target_probs = prediction['targetProbability']

    # Map to user-facing cry type
    cry_type = MODEL_TO_CRY_TYPE.get(target, "discomfort")
    confidence = float(target_probs.get(target, 0.0))

    # Build probabilities dict with 5 user-facing cry types
    probabilities = _aggregate_probabilities(target_probs)

    return {
        'is_cry': True,
        'cry_type': cry_type,
        'confidence': confidence,
        'probabilities': probabilities,
    }


def classify_with_onnx(audio_samples: np.ndarray) -> dict:
    """Classify using the ONNX-exported CNN+GLM model.

    Steps:
    1. Compute VGGish features in Python (replaces soundAnalysisPreprocessing)
    2. Run CNN+GLM through ONNX Runtime
    3. Apply softmax to get probabilities
    """
    if _onnx_session is None:
        raise RuntimeError("ONNX model not available")

    # Compute VGGish preprocessing
    vggish_features = compute_vggish_features(audio_samples)

    # ONNX model expects [batch, channels, height, width] = [1, 1, 96, 64]
    onnx_input = vggish_features.reshape(1, 1, VGGISH_N_FRAMES, VGGISH_N_MELS)

    # Run inference
    logits = _onnx_session.run(None, {'preprocessed_audio': onnx_input})[0][0]

    # Apply softmax
    probs = _softmax(logits)

    # Find best class
    best_idx = int(np.argmax(probs))
    best_label = CLASS_LABELS[best_idx]
    confidence = float(probs[best_idx])

    # Map to user-facing cry type
    cry_type = MODEL_TO_CRY_TYPE.get(best_label, "discomfort")

    # Build probabilities
    raw_probs = {CLASS_LABELS[i]: float(probs[i]) for i in range(len(CLASS_LABELS))}
    probabilities = _aggregate_probabilities(raw_probs)

    return {
        'is_cry': True,
        'cry_type': cry_type,
        'confidence': confidence,
        'probabilities': probabilities,
    }


def classify_with_features(features: dict) -> dict:
    """Rule-based classification using audio features.

    This is a fallback when no neural network model is available.
    Uses research-backed acoustic characteristics of different cry types:
    - Hungry: Lower pitch (300-450Hz), rhythmic, moderate intensity
    - Tired: Gradual onset, lower energy, whiny quality
    - Belly pain: High pitch (>450Hz), sudden onset, high intensity
    - Needs burping: Moderate pitch, intermittent pattern
    - Discomfort: Irregular, moderate-high pitch
    """
    pitch = features['pitch_mean']
    centroid = features['spectral_centroid']
    rms = features['rms']
    zcr = features['zero_crossing_rate']
    onset = features['onset_strength']
    contrast = features['spectral_contrast']

    # ===== CRY DETECTION =====
    cry_indicators = 0
    max_indicators = 10

    if 250 < pitch < 600:
        cry_indicators += 3
    elif 200 < pitch < 800:
        cry_indicators += 2
    elif 100 < pitch < 1000:
        cry_indicators += 1

    if 400 < centroid < 1500:
        cry_indicators += 2
    elif 200 < centroid < 3000:
        cry_indicators += 1

    if rms > 0.005:
        cry_indicators += 1
    if rms > 0.02:
        cry_indicators += 1
    if rms > 0.05:
        cry_indicators += 1

    if 0.02 < zcr < 0.20:
        cry_indicators += 1

    if onset > 0.1:
        cry_indicators += 1

    cry_confidence = min(1.0, cry_indicators / max_indicators)
    is_cry = cry_confidence >= 0.25

    if not is_cry:
        return {
            'is_cry': False,
            'cry_type': None,
            'confidence': 0.0,
            'probabilities': {
                "hungry": 0.0,
                "needs_burping": 0.0,
                "belly_pain": 0.0,
                "discomfort": 0.0,
                "tired": 0.0,
            },
        }

    # ===== CRY TYPE SCORING =====
    scores = {
        'hungry': 0.5,
        'needs_burping': 0.5,
        'belly_pain': 0.5,
        'discomfort': 0.5,
        'tired': 0.5,
    }

    # HUNGRY: Lower pitch, rhythmic, moderate intensity
    if 300 < pitch < 450 and 0.02 < rms < 0.08:
        scores['hungry'] += 3.0
    if 400 < centroid < 800:
        scores['hungry'] += 2.0
    if onset < 0.5:
        scores['hungry'] += 1.0

    # TIRED: Lower energy, whiny, gradual buildup
    if rms < 0.05:
        scores['tired'] += 2.0
    if 300 < centroid < 600:
        scores['tired'] += 2.0
    if onset < 0.3:
        scores['tired'] += 2.0
    if pitch < 400:
        scores['tired'] += 1.0

    # BELLY_PAIN: High pitch, sudden onset, high intensity
    if pitch > 450:
        scores['belly_pain'] += 3.0
    if centroid > 800:
        scores['belly_pain'] += 2.0
    if rms > 0.06:
        scores['belly_pain'] += 2.0
    if onset > 0.6:
        scores['belly_pain'] += 2.0
    if zcr > 0.10:
        scores['belly_pain'] += 1.0

    # NEEDS_BURPING: Variable, intermittent pattern
    if abs(contrast) > 10:
        scores['needs_burping'] += 2.0
    if 350 < pitch < 500:
        scores['needs_burping'] += 1.5
    if 0.03 < rms < 0.06:
        scores['needs_burping'] += 1.5

    # DISCOMFORT: Irregular, moderate intensity
    if 400 < pitch < 550:
        scores['discomfort'] += 2.0
    if 0.04 < rms < 0.08:
        scores['discomfort'] += 1.5
    if 600 < centroid < 1000:
        scores['discomfort'] += 2.0
    if 0.5 < onset < 0.8:
        scores['discomfort'] += 1.0

    # Normalize to probabilities
    total = sum(scores.values())
    probabilities = {k: v / total for k, v in scores.items()} if total > 0 else \
        {k: 0.2 for k in scores}

    best_type = max(probabilities, key=probabilities.get)
    best_confidence = probabilities[best_type]

    return {
        'is_cry': True,
        'cry_type': best_type,
        'confidence': best_confidence,
        'probabilities': probabilities,
    }


# ========== Helpers ==========

def _softmax(x: np.ndarray) -> np.ndarray:
    """Compute softmax probabilities."""
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum()


def _aggregate_probabilities(raw_probs: dict) -> dict:
    """Aggregate 9 model classes into 5 user-facing cry types.

    Model classes -> User cry types:
      hungry -> hungry
      burping -> needs_burping
      belly_pain -> belly_pain
      discomfort, cold_hot, lonely, scared -> discomfort (summed)
      tired -> tired
      unknown -> (excluded, redistributed)
    """
    aggregated = {
        "hungry": 0.0,
        "needs_burping": 0.0,
        "belly_pain": 0.0,
        "discomfort": 0.0,
        "tired": 0.0,
    }

    for model_class, prob in raw_probs.items():
        cry_type = MODEL_TO_CRY_TYPE.get(model_class.lower(), "discomfort")
        if cry_type == "unknown":
            # Redistribute unknown probability evenly
            for key in aggregated:
                aggregated[key] += float(prob) / len(aggregated)
        elif cry_type in aggregated:
            aggregated[cry_type] += float(prob)

    # Renormalize to ensure sum = 1.0
    total = sum(aggregated.values())
    if total > 0:
        aggregated = {k: v / total for k, v in aggregated.items()}

    return aggregated


# ========== API Endpoints ==========

@app.get("/", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    model_loaded = _inference_backend in ("coreml", "onnx")
    model_type_map = {
        "coreml": "CoreML DeepInfant V2",
        "onnx": "ONNX DeepInfant V2 (CNN+GLM)",
        "rule_based": "Rule-based fallback",
        "none": "No model loaded",
    }
    return HealthResponse(
        status="healthy",
        model_loaded=model_loaded,
        model_type=model_type_map.get(_inference_backend, "unknown"),
        inference_backend=_inference_backend,
    )


@app.post("/classify", response_model=ClassificationResult)
async def classify_cry(
    audio: UploadFile = File(..., description="Audio file (WAV, MP3, etc.)")
):
    """
    Classify a baby cry audio file.

    Accepts audio files in various formats (WAV, MP3, M4A, etc.)
    Returns cry type classification with confidence scores.

    Response format:
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
        },
        "model_used": "deepinfant_v2"
    }
    """
    # Read audio file
    try:
        audio_bytes = await audio.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read audio file: {e}")

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # Load audio
    try:
        y = load_audio_from_bytes(audio_bytes)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process audio: {e}")

    # Classify using the best available backend
    try:
        if _inference_backend == "coreml":
            result = classify_with_coreml(y)
            model_used = "deepinfant_v2"
        elif _inference_backend == "onnx":
            result = classify_with_onnx(y)
            model_used = "deepinfant_v2_onnx"
        else:
            # Rule-based fallback needs longer audio and features
            y_long = _prepare_long_audio(y)
            features = extract_features(y_long, SAMPLE_RATE)
            result = classify_with_features(features)
            model_used = "rule_based"
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {e}")

    # Get action category
    cry_type = result.get('cry_type')
    action_category = get_action_category(cry_type) if cry_type else None

    return ClassificationResult(
        is_cry=result['is_cry'],
        cry_type=cry_type,
        action_category=action_category,
        confidence=result.get('confidence', 0.0),
        probabilities=result.get('probabilities', {}),
        model_used=model_used,
    )


def _prepare_long_audio(y: np.ndarray) -> np.ndarray:
    """Pad or trim audio to FALLBACK_SAMPLES for rule-based classification."""
    if len(y) < FALLBACK_SAMPLES:
        return np.pad(y, (0, FALLBACK_SAMPLES - len(y)), mode='constant')
    elif len(y) > FALLBACK_SAMPLES:
        return y[:FALLBACK_SAMPLES]
    return y


# ========== Run Server ==========

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
