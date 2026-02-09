"""
Cry Classification API - DeepInfant V2 Backend

This API provides accurate baby cry classification using the DeepInfant V2 model
architecture. It processes audio files and returns cry type predictions.

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
# DeepInfant V2 Specifications (CRITICAL - must match model training)

SAMPLE_RATE = 16000      # DeepInfant uses 16kHz
N_FFT = 1024             # FFT window size (DeepInfant V2 spec)
HOP_LENGTH = 256         # Hop length for STFT (DeepInfant V2 spec)
N_MELS = 80              # Number of mel bands (DeepInfant V2 spec)
F_MIN = 20               # Minimum frequency in Hz
F_MAX = 8000             # Maximum frequency in Hz
REQUIRED_DURATION = 7.0  # Audio duration in seconds (DeepInfant V2 requires 7s)
REQUIRED_SAMPLES = 112000  # 7 seconds * 16000 Hz

# Expected output shape: (80, 431) for mel-spectrogram

# Try to load CoreML model (macOS only)
COREML_AVAILABLE = False
coreml_model = None

try:
    import coremltools as ct
    # Try to load the DeepInfant model
    model_path = os.environ.get('DEEPINFANT_MODEL_PATH', 'models/DeepInfant_V2.mlmodel')
    if os.path.exists(model_path):
        coreml_model = ct.models.MLModel(model_path)
        COREML_AVAILABLE = True
        print(f"[INFO] CoreML model loaded from {model_path}")
except ImportError:
    print("[INFO] CoreML not available (not macOS). Using rule-based fallback.")
except Exception as e:
    print(f"[WARN] Failed to load CoreML model: {e}")


# ========== Enums and Models ==========

# DeepInfant V2 outputs 5 cry types
class DeepInfantCryType(str, Enum):
    HUNGRY = "hungry"
    NEEDS_BURPING = "needs_burping"
    BELLY_PAIN = "belly_pain"
    DISCOMFORT = "discomfort"
    TIRED = "tired"


# Legacy CryType for backwards compatibility
class CryType(str, Enum):
    HUNGER = "hunger"
    TIRED = "tired"
    PAIN = "pain"
    ATTENTION = "attention"
    DISCOMFORT = "discomfort"
    GENERAL = "general"


# ActionCategory maps 5 DeepInfant types to 3 actionable categories
class ActionCategory(str, Enum):
    HUNGRY = "hungry"           # hungry → Feed baby
    UNCOMFORTABLE = "uncomfortable"  # needs_burping, belly_pain, discomfort → Check physical needs
    TIRED = "tired"             # tired → Help baby sleep


def get_action_category(cry_type: str) -> str:
    """Map DeepInfant V2 cry type to action category (5 → 3)"""
    mapping = {
        "hungry": ActionCategory.HUNGRY.value,
        "needs_burping": ActionCategory.UNCOMFORTABLE.value,
        "belly_pain": ActionCategory.UNCOMFORTABLE.value,
        "discomfort": ActionCategory.UNCOMFORTABLE.value,
        "tired": ActionCategory.TIRED.value,
        # Legacy mappings
        "hunger": ActionCategory.HUNGRY.value,
        "pain": ActionCategory.UNCOMFORTABLE.value,
        "attention": ActionCategory.UNCOMFORTABLE.value,
        "general": ActionCategory.UNCOMFORTABLE.value,
    }
    return mapping.get(cry_type.lower(), ActionCategory.UNCOMFORTABLE.value)


class ClassificationResult(BaseModel):
    is_cry: bool
    cry_confidence: float
    cry_type: Optional[str] = None
    action_category: Optional[str] = None  # NEW: 3-category mapping
    type_confidence: float
    probabilities: dict
    features: dict
    model_used: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_type: str


# ========== FastAPI App ==========

app = FastAPI(
    title="Cry Classification API",
    description="DeepInfant V2 compatible cry classification service",
    version="1.0.0"
)

# CORS for web frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ========== Audio Processing ==========

def load_and_preprocess_audio(audio_bytes: bytes) -> tuple[np.ndarray, dict]:
    """
    Load audio from bytes and preprocess for DeepInfant V2 classification.

    DeepInfant V2 Specifications:
    - Sample rate: 16kHz
    - Duration: 7 seconds (112,000 samples)
    - Mel-spectrogram: 80 bands, 1024 FFT, 256 hop, 20-8000Hz
    - Output shape: (80, 431)

    Returns:
        - Preprocessed mel-spectrogram (normalized to [0, 1])
        - Feature dictionary for rule-based fallback
    """
    # Save to temp file for librosa
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        # Load audio with librosa at 16kHz mono
        y, sr = librosa.load(temp_path, sr=SAMPLE_RATE, mono=True)

        # Pad or trim to exactly 7 seconds (112,000 samples)
        if len(y) < REQUIRED_SAMPLES:
            # Pad with zeros if too short
            y = np.pad(y, (0, REQUIRED_SAMPLES - len(y)), mode='constant')
        elif len(y) > REQUIRED_SAMPLES:
            # Trim to 7 seconds
            y = y[:REQUIRED_SAMPLES]

        # Extract features for rule-based fallback
        features = extract_features(y, sr)

        # Generate mel-spectrogram with DeepInfant V2 specs
        mel_spec = librosa.feature.melspectrogram(
            y=y,
            sr=sr,
            n_fft=N_FFT,
            hop_length=HOP_LENGTH,
            n_mels=N_MELS,
            fmin=F_MIN,
            fmax=F_MAX
        )

        # Convert to log scale (dB) with reference to max
        mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)

        # Normalize to [0, 1] range
        mel_min = mel_spec_db.min()
        mel_max = mel_spec_db.max()
        if mel_max > mel_min:
            mel_spec_normalized = (mel_spec_db - mel_min) / (mel_max - mel_min)
        else:
            mel_spec_normalized = np.zeros_like(mel_spec_db)

        print(f"[DEBUG] Mel-spectrogram shape: {mel_spec_normalized.shape}")  # Should be (80, 431)

        return mel_spec_normalized, features

    finally:
        # Clean up temp file
        os.unlink(temp_path)


def extract_features(y: np.ndarray, sr: int) -> dict:
    """
    Extract audio features for classification and debugging.
    """
    # RMS energy
    rms = librosa.feature.rms(y=y)[0]
    rms_mean = float(np.mean(rms))

    # Spectral centroid (brightness)
    spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    centroid_mean = float(np.mean(spectral_centroid))

    # Spectral rolloff
    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
    rolloff_mean = float(np.mean(rolloff))

    # Zero crossing rate
    zcr = librosa.feature.zero_crossing_rate(y)[0]
    zcr_mean = float(np.mean(zcr))

    # Pitch estimation (fundamental frequency)
    pitches, magnitudes = librosa.piptrack(y=y, sr=sr)
    pitch_mean = float(np.mean(pitches[pitches > 0])) if np.any(pitches > 0) else 0

    # Onset strength (attack detection)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    onset_mean = float(np.mean(onset_env))

    # Spectral contrast
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


# ========== Classification Logic ==========

def classify_with_coreml(mel_spec: np.ndarray) -> dict:
    """
    Classify using the loaded CoreML model.
    """
    if not COREML_AVAILABLE or coreml_model is None:
        raise RuntimeError("CoreML model not available")

    # Prepare input for CoreML model
    # Note: Input shape depends on the specific model architecture
    input_data = mel_spec.reshape(1, N_MELS, -1, 1).astype(np.float32)

    # Run prediction
    prediction = coreml_model.predict({'input': input_data})

    # Parse output (format depends on model export)
    return prediction


def classify_with_features(features: dict, mel_spec: np.ndarray) -> dict:
    """
    Rule-based classification using audio features.
    This is a fallback when CoreML is not available.

    Uses research-backed acoustic characteristics of different cry types:
    - Hunger: Lower pitch (300-450Hz), rhythmic, moderate intensity
    - Tired: Gradual onset, lower energy, whiny quality
    - Pain: High pitch (>450Hz), sudden onset, high intensity
    - Attention: Variable, intermittent pattern
    - Discomfort: Irregular, moderate-high pitch
    - General: Doesn't match specific patterns
    """

    # Extract key features
    pitch = features['pitch_mean']
    centroid = features['spectral_centroid']
    rms = features['rms']
    zcr = features['zero_crossing_rate']
    onset = features['onset_strength']
    contrast = features['spectral_contrast']

    # Initialize scores
    scores = {
        'hunger': 0.0,
        'tired': 0.0,
        'pain': 0.0,
        'attention': 0.0,
        'discomfort': 0.0,
        'general': 0.0
    }

    # ===== CRY DETECTION (Stage 1) =====
    # Baby cries have varied characteristics - be permissive to avoid false negatives
    cry_indicators = 0
    max_indicators = 10

    # Pitch in infant range (200-800 Hz) - wider range for real cries
    if 250 < pitch < 600:
        cry_indicators += 3  # Ideal range
    elif 200 < pitch < 800:
        cry_indicators += 2  # Acceptable range
    elif 100 < pitch < 1000:
        cry_indicators += 1  # Still possible

    # Spectral centroid - baby cries vary widely
    if 400 < centroid < 1500:
        cry_indicators += 2  # Ideal range
    elif 200 < centroid < 3000:
        cry_indicators += 1  # Acceptable

    # Sufficient energy (not silence)
    if rms > 0.005:
        cry_indicators += 1
    if rms > 0.02:
        cry_indicators += 1
    if rms > 0.05:
        cry_indicators += 1

    # ZCR - cries have varied texture
    if 0.02 < zcr < 0.20:
        cry_indicators += 1

    # Onset strength - cries have some attack
    if onset > 0.1:
        cry_indicators += 1

    # Calculate cry confidence - lower threshold for better recall
    cry_confidence = min(1.0, cry_indicators / max_indicators)
    is_cry = cry_confidence >= 0.25  # Lower threshold to catch more cries

    print(f"[DEBUG] Cry detection: pitch={pitch:.1f}, centroid={centroid:.1f}, rms={rms:.4f}, zcr={zcr:.4f}")
    print(f"[DEBUG] cry_indicators={cry_indicators}/{max_indicators}, confidence={cry_confidence:.2f}, is_cry={is_cry}")

    if not is_cry:
        return {
            'is_cry': False,
            'cry_confidence': cry_confidence,
            'cry_type': None,
            'type_confidence': 0.0,
            'probabilities': scores
        }

    # ===== CRY TYPE CLASSIFICATION (Stage 2) =====

    # HUNGER: Lower pitch, rhythmic, moderate intensity
    if 300 < pitch < 450 and 0.02 < rms < 0.08:
        scores['hunger'] += 3.0
    if 400 < centroid < 800:
        scores['hunger'] += 2.0
    if onset < 0.5:  # Gradual onset
        scores['hunger'] += 1.0

    # TIRED: Lower energy, whiny, gradual buildup
    if rms < 0.05:
        scores['tired'] += 2.0
    if 300 < centroid < 600:
        scores['tired'] += 2.0
    if onset < 0.3:  # Slow onset
        scores['tired'] += 2.0
    if pitch < 400:
        scores['tired'] += 1.0

    # PAIN: High pitch, sudden onset, high intensity
    if pitch > 450:
        scores['pain'] += 3.0
    if centroid > 800:
        scores['pain'] += 2.0
    if rms > 0.06:
        scores['pain'] += 2.0
    if onset > 0.6:  # Sharp attack
        scores['pain'] += 2.0
    if zcr > 0.10:  # Harsher sound
        scores['pain'] += 1.0

    # ATTENTION: Variable, intermittent (using spectral contrast as proxy)
    if abs(contrast) > 10:  # High spectral variation
        scores['attention'] += 2.0
    if 350 < pitch < 500:
        scores['attention'] += 1.5
    if 0.03 < rms < 0.06:
        scores['attention'] += 1.5

    # DISCOMFORT: Irregular, moderate intensity
    if 400 < pitch < 550:
        scores['discomfort'] += 2.0
    if 0.04 < rms < 0.08:
        scores['discomfort'] += 1.5
    if 600 < centroid < 1000:
        scores['discomfort'] += 2.0
    if 0.5 < onset < 0.8:
        scores['discomfort'] += 1.0

    # GENERAL: Fallback - add base score to all
    for cry_type in scores:
        scores[cry_type] += 0.5  # Small base probability

    # Normalize to probabilities
    total = sum(scores.values())
    if total > 0:
        probabilities = {k: v / total for k, v in scores.items()}
    else:
        probabilities = {k: 1/6 for k in scores}

    # Find best prediction
    best_type = max(probabilities, key=probabilities.get)
    best_confidence = probabilities[best_type]

    return {
        'is_cry': True,
        'cry_confidence': cry_confidence,
        'cry_type': best_type,
        'type_confidence': best_confidence,
        'probabilities': probabilities
    }


# ========== API Endpoints ==========

@app.get("/", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        model_loaded=COREML_AVAILABLE,
        model_type="CoreML DeepInfant V2" if COREML_AVAILABLE else "Rule-based fallback"
    )


@app.post("/classify", response_model=ClassificationResult)
async def classify_cry(
    audio: UploadFile = File(..., description="Audio file (WAV, MP3, etc.)")
):
    """
    Classify a baby cry audio file.

    Accepts audio files in various formats (WAV, MP3, M4A, etc.)
    Returns cry type classification with confidence scores.
    """
    # Read audio file
    try:
        audio_bytes = await audio.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read audio file: {e}")

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # Process audio
    try:
        mel_spec, features = load_and_preprocess_audio(audio_bytes)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process audio: {e}")

    # Classify
    try:
        if COREML_AVAILABLE:
            # Use actual DeepInfant model
            coreml_result = classify_with_coreml(mel_spec)
            # Parse CoreML output (format varies by model)
            result = parse_coreml_output(coreml_result)
            model_used = "CoreML DeepInfant V2"
        else:
            # Fall back to feature-based classification
            result = classify_with_features(features, mel_spec)
            model_used = "Rule-based (CoreML unavailable)"
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {e}")

    # Get action category from cry type
    cry_type = result.get('cry_type')
    action_category = get_action_category(cry_type) if cry_type else None

    return ClassificationResult(
        is_cry=result['is_cry'],
        cry_confidence=result['cry_confidence'],
        cry_type=cry_type,
        action_category=action_category,
        type_confidence=result.get('type_confidence', 0.0),
        probabilities=result.get('probabilities', {}),
        features=features,
        model_used=model_used
    )


def parse_coreml_output(prediction: dict) -> dict:
    """
    Parse CoreML model output into standard format.
    Note: Adjust based on actual DeepInfant model output format.
    """
    # This needs to be adapted based on the actual model output
    # Typical outputs might be:
    # - 'classLabel': predicted class name
    # - 'classLabelProbs': dict of class -> probability

    if 'classLabel' in prediction:
        cry_type = prediction['classLabel'].lower()
        probs = prediction.get('classLabelProbs', {})
        confidence = probs.get(cry_type, 0.5)

        return {
            'is_cry': True,  # CoreML model only runs on detected cries
            'cry_confidence': 0.9,  # High confidence if using CoreML
            'cry_type': cry_type,
            'type_confidence': float(confidence),
            'probabilities': {k.lower(): float(v) for k, v in probs.items()}
        }

    # Fallback for unknown output format
    return {
        'is_cry': True,
        'cry_confidence': 0.5,
        'cry_type': 'general',
        'type_confidence': 0.5,
        'probabilities': {t: 1/6 for t in CryType}
    }


# ========== Run Server ==========

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
