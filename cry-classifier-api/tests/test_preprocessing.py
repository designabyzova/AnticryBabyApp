"""
Tests for the Cry Classification API - DeepInfant V2 Backend

Covers:
- Audio preprocessing (VGGish features, sample preparation)
- Action category mapping (9 model classes -> 5 cry types -> 3 actions)
- Classification backends (CoreML, ONNX, rule-based)
- API response format
- Edge cases
"""

import pytest
import numpy as np
import tempfile
import os
import sys
import wave
import struct

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import (
    load_audio_from_bytes,
    prepare_coreml_input,
    compute_vggish_features,
    extract_features,
    classify_with_features,
    get_action_category,
    _aggregate_probabilities,
    _softmax,
    _prepare_long_audio,
    SAMPLE_RATE,
    REQUIRED_SAMPLES,
    REQUIRED_DURATION,
    VGGISH_SAMPLE_RATE,
    VGGISH_WINDOW_LENGTH,
    VGGISH_HOP_LENGTH,
    VGGISH_N_MELS,
    VGGISH_N_FRAMES,
    VGGISH_F_MIN,
    VGGISH_F_MAX,
    FALLBACK_SAMPLES,
    CLASS_LABELS,
    MODEL_TO_CRY_TYPE,
)


# ========== Helpers ==========

def generate_wav_bytes(duration_seconds: float = 1.0, frequency: float = 440.0,
                       sample_rate: int = 16000) -> bytes:
    """Generate a WAV file as bytes for testing."""
    samples = int(duration_seconds * sample_rate)
    t = np.arange(samples) / sample_rate
    audio = (np.sin(2 * np.pi * frequency * t) * 32767).astype(np.int16)

    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        wav_file = wave.open(f.name, 'wb')
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio.tobytes())
        wav_file.close()

        with open(f.name, 'rb') as rf:
            wav_bytes = rf.read()

        os.unlink(f.name)
        return wav_bytes


def generate_sine_wave(frequency: float = 440.0, duration_seconds: float = 1.0,
                       sample_rate: int = 16000) -> np.ndarray:
    """Generate a sine wave as float32 numpy array."""
    t = np.arange(int(duration_seconds * sample_rate)) / sample_rate
    return np.sin(2 * np.pi * frequency * t).astype(np.float32)


# ========== Configuration Constants ==========

class TestDeepInfantV2Constants:
    """Test that configuration constants match DeepInfant V2 specifications."""

    def test_sample_rate(self):
        assert SAMPLE_RATE == 16000, "Sample rate should be 16kHz"

    def test_required_samples(self):
        assert REQUIRED_SAMPLES == 15600, "Required samples should be 15,600 (~975ms)"

    def test_required_duration(self):
        assert REQUIRED_DURATION == pytest.approx(0.975, rel=0.01)

    def test_vggish_parameters(self):
        """VGGish preprocessing must match Apple's soundAnalysisPreprocessing."""
        assert VGGISH_SAMPLE_RATE == 16000
        assert VGGISH_WINDOW_LENGTH == 400, "VGGish uses 25ms window = 400 samples"
        assert VGGISH_HOP_LENGTH == 160, "VGGish uses 10ms hop = 160 samples"
        assert VGGISH_N_MELS == 64, "VGGish uses 64 mel bands"
        assert VGGISH_N_FRAMES == 96, "VGGish produces 96 time frames"
        assert VGGISH_F_MIN == 125.0, "VGGish min freq = 125Hz"
        assert VGGISH_F_MAX == 7500.0, "VGGish max freq = 7500Hz"

    def test_class_labels(self):
        """Model should output exactly 9 classes."""
        assert len(CLASS_LABELS) == 9
        assert "belly_pain" in CLASS_LABELS
        assert "burping" in CLASS_LABELS
        assert "cold_hot" in CLASS_LABELS
        assert "discomfort" in CLASS_LABELS
        assert "hungry" in CLASS_LABELS
        assert "lonely" in CLASS_LABELS
        assert "scared" in CLASS_LABELS
        assert "tired" in CLASS_LABELS
        assert "unknown" in CLASS_LABELS


# ========== Action Category Mapping ==========

class TestActionCategoryMapping:
    """Test cry type to action category mapping."""

    def test_hungry_maps_to_hungry(self):
        assert get_action_category("hungry") == "hungry"

    def test_needs_burping_maps_to_uncomfortable(self):
        assert get_action_category("needs_burping") == "uncomfortable"

    def test_belly_pain_maps_to_uncomfortable(self):
        assert get_action_category("belly_pain") == "uncomfortable"

    def test_discomfort_maps_to_uncomfortable(self):
        assert get_action_category("discomfort") == "uncomfortable"

    def test_tired_maps_to_tired(self):
        assert get_action_category("tired") == "tired"

    def test_burping_maps_to_uncomfortable(self):
        """Direct model output 'burping' should map to uncomfortable."""
        assert get_action_category("burping") == "uncomfortable"

    def test_cold_hot_maps_to_uncomfortable(self):
        assert get_action_category("cold_hot") == "uncomfortable"

    def test_lonely_maps_to_uncomfortable(self):
        assert get_action_category("lonely") == "uncomfortable"

    def test_scared_maps_to_uncomfortable(self):
        assert get_action_category("scared") == "uncomfortable"

    def test_unknown_maps_to_uncomfortable(self):
        assert get_action_category("unknown") == "uncomfortable"

    def test_legacy_hunger_maps_to_hungry(self):
        assert get_action_category("hunger") == "hungry"

    def test_legacy_pain_maps_to_uncomfortable(self):
        assert get_action_category("pain") == "uncomfortable"

    def test_case_insensitive(self):
        assert get_action_category("HUNGRY") == "hungry"
        assert get_action_category("Tired") == "tired"
        assert get_action_category("BELLY_PAIN") == "uncomfortable"

    def test_unknown_type_defaults_to_uncomfortable(self):
        assert get_action_category("nonexistent_type") == "uncomfortable"


# ========== Probability Aggregation ==========

class TestProbabilityAggregation:
    """Test aggregation of 9 model classes to 5 user-facing cry types."""

    def test_basic_aggregation(self):
        raw = {
            "hungry": 0.5,
            "burping": 0.1,
            "belly_pain": 0.1,
            "discomfort": 0.1,
            "cold_hot": 0.05,
            "lonely": 0.05,
            "scared": 0.0,
            "tired": 0.1,
            "unknown": 0.0,
        }
        result = _aggregate_probabilities(raw)

        assert set(result.keys()) == {"hungry", "needs_burping", "belly_pain", "discomfort", "tired"}
        assert result["hungry"] > 0
        assert result["needs_burping"] > 0
        assert result["belly_pain"] > 0
        assert result["discomfort"] > 0  # Aggregated from discomfort + cold_hot + lonely + scared
        assert result["tired"] > 0
        assert sum(result.values()) == pytest.approx(1.0, abs=0.01)

    def test_discomfort_aggregates_multiple_classes(self):
        """discomfort, cold_hot, lonely, scared should all aggregate into 'discomfort'."""
        raw = {
            "hungry": 0.0, "burping": 0.0, "belly_pain": 0.0,
            "discomfort": 0.25, "cold_hot": 0.25,
            "lonely": 0.25, "scared": 0.25,
            "tired": 0.0, "unknown": 0.0,
        }
        result = _aggregate_probabilities(raw)
        # All 4 classes should aggregate into discomfort
        assert result["discomfort"] == pytest.approx(1.0, abs=0.01)

    def test_unknown_redistributed(self):
        """Unknown probability should be redistributed evenly."""
        raw = {
            "hungry": 0.0, "burping": 0.0, "belly_pain": 0.0,
            "discomfort": 0.0, "cold_hot": 0.0,
            "lonely": 0.0, "scared": 0.0,
            "tired": 0.0, "unknown": 1.0,
        }
        result = _aggregate_probabilities(raw)
        # Each of the 5 cry types should get 0.2
        for key in result:
            assert result[key] == pytest.approx(0.2, abs=0.01)

    def test_probabilities_sum_to_one(self):
        """Result probabilities should always sum to 1.0."""
        raw = {label: 1.0 / len(CLASS_LABELS) for label in CLASS_LABELS}
        result = _aggregate_probabilities(raw)
        assert sum(result.values()) == pytest.approx(1.0, abs=0.01)


# ========== Audio Preprocessing ==========

class TestCoreMLInput:
    """Test audio preparation for CoreML model input."""

    def test_exact_length(self):
        """Audio with exactly 15,600 samples should pass through unchanged."""
        y = np.random.randn(REQUIRED_SAMPLES).astype(np.float32)
        result = prepare_coreml_input(y)
        assert len(result) == REQUIRED_SAMPLES
        assert result.dtype == np.float32

    def test_short_audio_padded(self):
        """Short audio should be zero-padded to 15,600 samples."""
        y = np.ones(5000, dtype=np.float32)
        result = prepare_coreml_input(y)
        assert len(result) == REQUIRED_SAMPLES
        assert result[:5000].sum() == 5000
        assert result[5000:].sum() == 0

    def test_long_audio_trimmed(self):
        """Long audio should be trimmed to 15,600 samples."""
        y = np.ones(30000, dtype=np.float32) * 0.5
        result = prepare_coreml_input(y)
        assert len(result) == REQUIRED_SAMPLES

    def test_output_dtype(self):
        """Output should always be float32."""
        y = np.ones(REQUIRED_SAMPLES, dtype=np.float64)
        result = prepare_coreml_input(y)
        assert result.dtype == np.float32


class TestVGGishFeatures:
    """Test VGGish-style log-mel spectrogram computation."""

    def test_output_shape(self):
        """VGGish features should have shape [1, 96, 64]."""
        y = generate_sine_wave(440.0, 1.0)
        features = compute_vggish_features(y)
        assert features.shape == (1, VGGISH_N_FRAMES, VGGISH_N_MELS)

    def test_output_dtype(self):
        """Output should be float32."""
        y = generate_sine_wave(440.0, 1.0)
        features = compute_vggish_features(y)
        assert features.dtype == np.float32

    def test_silence_features(self):
        """Silence should produce consistent low-energy features."""
        y = np.zeros(REQUIRED_SAMPLES, dtype=np.float32)
        features = compute_vggish_features(y)
        assert features.shape == (1, VGGISH_N_FRAMES, VGGISH_N_MELS)
        # Silence should have low values (log of small number)
        assert features.max() < 0  # log(0 + 0.01) = log(0.01) = -4.6

    def test_short_audio(self):
        """Short audio should still produce correct shape."""
        y = generate_sine_wave(440.0, 0.1)  # Very short
        features = compute_vggish_features(y)
        assert features.shape == (1, VGGISH_N_FRAMES, VGGISH_N_MELS)

    def test_long_audio(self):
        """Long audio should be trimmed and produce correct shape."""
        y = generate_sine_wave(440.0, 5.0)  # Much longer than needed
        features = compute_vggish_features(y)
        assert features.shape == (1, VGGISH_N_FRAMES, VGGISH_N_MELS)


class TestFeatureExtraction:
    """Test audio feature extraction for rule-based classifier."""

    @pytest.fixture
    def sine_wave(self):
        """Generate a 440Hz sine wave."""
        return generate_sine_wave(440.0, 7.0)

    @pytest.fixture
    def silence(self):
        """Generate silence."""
        return np.zeros(FALLBACK_SAMPLES, dtype=np.float32)

    def test_features_from_sine_wave(self, sine_wave):
        features = extract_features(sine_wave, SAMPLE_RATE)

        expected_keys = {
            "rms", "spectral_centroid", "spectral_rolloff",
            "zero_crossing_rate", "pitch_mean", "onset_strength",
            "spectral_contrast", "duration_seconds"
        }
        assert set(features.keys()) == expected_keys
        assert features["rms"] > 0
        assert features["duration_seconds"] == pytest.approx(7.0, rel=0.1)

    def test_features_from_silence(self, silence):
        features = extract_features(silence, SAMPLE_RATE)
        assert features["rms"] == pytest.approx(0, abs=0.001)


class TestLoadAudioFromBytes:
    """Test loading audio from WAV bytes."""

    def test_load_wav(self):
        """Should load a valid WAV file."""
        wav_bytes = generate_wav_bytes(1.0, 440.0)
        y = load_audio_from_bytes(wav_bytes)
        assert len(y) > 0
        assert isinstance(y, np.ndarray)

    def test_correct_sample_rate(self):
        """Audio should be resampled to 16kHz."""
        # Generate at 44.1kHz
        wav_bytes = generate_wav_bytes(1.0, 440.0, sample_rate=44100)
        y = load_audio_from_bytes(wav_bytes)
        # At 16kHz, 1 second should be ~16000 samples
        assert 15000 < len(y) < 17000


# ========== Rule-Based Classification ==========

class TestRuleBasedClassification:
    """Test the rule-based fallback classifier."""

    def test_silence_not_detected_as_cry(self):
        """Silence should not be detected as a cry."""
        features = {
            "rms": 0.0,
            "spectral_centroid": 0.0,
            "spectral_rolloff": 0.0,
            "zero_crossing_rate": 0.0,
            "pitch_mean": 0.0,
            "onset_strength": 0.0,
            "spectral_contrast": 0.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        assert result["is_cry"] is False
        assert result["cry_type"] is None
        assert result["confidence"] == 0.0

    def test_cry_detected_with_sufficient_features(self):
        """Audio with cry-like features should be detected."""
        features = {
            "rms": 0.1,
            "spectral_centroid": 800.0,
            "spectral_rolloff": 3000.0,
            "zero_crossing_rate": 0.05,
            "pitch_mean": 400.0,
            "onset_strength": 0.3,
            "spectral_contrast": 10.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        assert result["is_cry"] is True
        assert result["cry_type"] is not None
        assert result["confidence"] > 0

    def test_result_has_5_probabilities(self):
        """Result should have exactly 5 user-facing cry types."""
        features = {
            "rms": 0.1,
            "spectral_centroid": 800.0,
            "spectral_rolloff": 3000.0,
            "zero_crossing_rate": 0.05,
            "pitch_mean": 400.0,
            "onset_strength": 0.3,
            "spectral_contrast": 10.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        expected_types = {"hungry", "needs_burping", "belly_pain", "discomfort", "tired"}
        assert set(result["probabilities"].keys()) == expected_types

    def test_probabilities_sum_to_one(self):
        """Probabilities should sum to approximately 1.0."""
        features = {
            "rms": 0.1,
            "spectral_centroid": 800.0,
            "spectral_rolloff": 3000.0,
            "zero_crossing_rate": 0.05,
            "pitch_mean": 400.0,
            "onset_strength": 0.3,
            "spectral_contrast": 10.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        if result["is_cry"]:
            total = sum(result["probabilities"].values())
            assert total == pytest.approx(1.0, abs=0.01)

    def test_high_pitch_suggests_pain(self):
        """High pitch with strong onset should suggest belly_pain."""
        features = {
            "rms": 0.1,
            "spectral_centroid": 1200.0,
            "spectral_rolloff": 4000.0,
            "zero_crossing_rate": 0.12,
            "pitch_mean": 550.0,
            "onset_strength": 0.8,
            "spectral_contrast": 5.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        assert result["is_cry"] is True
        assert result["probabilities"]["belly_pain"] > result["probabilities"]["tired"]

    def test_low_energy_suggests_tired(self):
        """Low energy with gradual onset should suggest tired."""
        features = {
            "rms": 0.03,
            "spectral_centroid": 450.0,
            "spectral_rolloff": 1500.0,
            "zero_crossing_rate": 0.04,
            "pitch_mean": 350.0,
            "onset_strength": 0.2,
            "spectral_contrast": 5.0,
            "duration_seconds": 7.0,
        }
        result = classify_with_features(features)
        assert result["is_cry"] is True
        assert result["probabilities"]["tired"] > result["probabilities"]["belly_pain"]


# ========== Softmax ==========

class TestSoftmax:
    """Test softmax computation."""

    def test_basic_softmax(self):
        x = np.array([1.0, 2.0, 3.0])
        result = _softmax(x)
        assert result.sum() == pytest.approx(1.0, abs=1e-6)
        assert result[2] > result[1] > result[0]

    def test_uniform_input(self):
        x = np.array([1.0, 1.0, 1.0, 1.0])
        result = _softmax(x)
        assert all(p == pytest.approx(0.25, abs=1e-6) for p in result)

    def test_large_values(self):
        """Should handle large values without overflow."""
        x = np.array([1000.0, 1001.0, 999.0])
        result = _softmax(x)
        assert result.sum() == pytest.approx(1.0, abs=1e-6)
        assert not np.any(np.isnan(result))


# ========== Model Class Mapping ==========

class TestModelToUserMapping:
    """Test the mapping from 9 model classes to 5 user-facing types."""

    def test_all_model_classes_mapped(self):
        """Every model class should have a mapping."""
        for label in CLASS_LABELS:
            assert label in MODEL_TO_CRY_TYPE, f"Missing mapping for {label}"

    def test_mapping_values_valid(self):
        """All mapped values should be valid cry types."""
        valid_types = {"hungry", "needs_burping", "belly_pain", "discomfort", "tired", "unknown"}
        for label, cry_type in MODEL_TO_CRY_TYPE.items():
            assert cry_type in valid_types, f"Invalid mapping: {label} -> {cry_type}"

    def test_hungry_maps_directly(self):
        assert MODEL_TO_CRY_TYPE["hungry"] == "hungry"

    def test_burping_maps_to_needs_burping(self):
        assert MODEL_TO_CRY_TYPE["burping"] == "needs_burping"

    def test_belly_pain_maps_directly(self):
        assert MODEL_TO_CRY_TYPE["belly_pain"] == "belly_pain"

    def test_tired_maps_directly(self):
        assert MODEL_TO_CRY_TYPE["tired"] == "tired"

    def test_cold_hot_maps_to_discomfort(self):
        assert MODEL_TO_CRY_TYPE["cold_hot"] == "discomfort"


# ========== Prepare Long Audio ==========

class TestPrepareLongAudio:
    """Test audio preparation for rule-based classifier."""

    def test_short_audio_padded(self):
        y = np.ones(1000, dtype=np.float32)
        result = _prepare_long_audio(y)
        assert len(result) == FALLBACK_SAMPLES
        assert result[:1000].sum() == 1000
        assert result[1000:].sum() == 0

    def test_exact_length_unchanged(self):
        y = np.ones(FALLBACK_SAMPLES, dtype=np.float32) * 0.5
        result = _prepare_long_audio(y)
        assert len(result) == FALLBACK_SAMPLES
        np.testing.assert_array_equal(result, y)

    def test_long_audio_trimmed(self):
        y = np.ones(200000, dtype=np.float32)
        result = _prepare_long_audio(y)
        assert len(result) == FALLBACK_SAMPLES


# ========== API Response Format ==========

class TestAPIResponseFormat:
    """Test that the API returns the expected response format."""

    @pytest.fixture
    def test_client(self):
        """Create a test client for the FastAPI app."""
        try:
            from httpx import AsyncClient, ASGITransport
            from main import app
            return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")
        except ImportError:
            pytest.skip("httpx not installed")

    @pytest.mark.asyncio
    async def test_health_endpoint(self, test_client):
        """GET / should return health status."""
        async with test_client as client:
            response = await client.get("/")
            assert response.status_code == 200
            data = response.json()
            assert "status" in data
            assert "model_loaded" in data
            assert "model_type" in data
            assert "inference_backend" in data
            assert data["status"] == "healthy"

    @pytest.mark.asyncio
    async def test_classify_endpoint_format(self, test_client):
        """POST /classify should return correct format."""
        wav_bytes = generate_wav_bytes(1.0, 440.0)

        async with test_client as client:
            response = await client.post(
                "/classify",
                files={"audio": ("test.wav", wav_bytes, "audio/wav")},
            )
            assert response.status_code == 200
            data = response.json()

            # Required fields
            assert "is_cry" in data
            assert "cry_type" in data
            assert "action_category" in data
            assert "confidence" in data
            assert "probabilities" in data
            assert "model_used" in data

            # Confidence should be a number
            assert isinstance(data["confidence"], (int, float))

            # model_used should indicate the backend
            assert data["model_used"] in ("deepinfant_v2", "deepinfant_v2_onnx", "rule_based")

    @pytest.mark.asyncio
    async def test_classify_empty_file_rejected(self, test_client):
        """POST /classify with empty file should return 400."""
        async with test_client as client:
            response = await client.post(
                "/classify",
                files={"audio": ("test.wav", b"", "audio/wav")},
            )
            assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_classify_probabilities_format(self, test_client):
        """Probabilities should have 5 user-facing cry types."""
        wav_bytes = generate_wav_bytes(1.0, 440.0)

        async with test_client as client:
            response = await client.post(
                "/classify",
                files={"audio": ("test.wav", wav_bytes, "audio/wav")},
            )
            data = response.json()
            probs = data["probabilities"]

            if data["is_cry"]:
                expected_keys = {"hungry", "needs_burping", "belly_pain", "discomfort", "tired"}
                assert set(probs.keys()) == expected_keys
                total = sum(probs.values())
                assert total == pytest.approx(1.0, abs=0.05)

    @pytest.mark.asyncio
    async def test_action_category_present_when_cry(self, test_client):
        """action_category should be present when cry is detected."""
        wav_bytes = generate_wav_bytes(1.0, 440.0)

        async with test_client as client:
            response = await client.post(
                "/classify",
                files={"audio": ("test.wav", wav_bytes, "audio/wav")},
            )
            data = response.json()

            if data["is_cry"]:
                assert data["action_category"] in ("hungry", "uncomfortable", "tired")


# ========== CoreML Integration (macOS only) ==========

class TestCoreMLIntegration:
    """Test CoreML model integration. Only runs on macOS with model available."""

    @pytest.fixture(autouse=True)
    def check_coreml(self):
        from main import _inference_backend
        if _inference_backend != "coreml":
            pytest.skip("CoreML not available")

    def test_coreml_classify_silence(self):
        from main import classify_with_coreml
        silence = np.zeros(REQUIRED_SAMPLES, dtype=np.float32)
        result = classify_with_coreml(silence)

        assert result["is_cry"] is True  # Model always outputs a class
        assert result["cry_type"] is not None
        assert 0 <= result["confidence"] <= 1

    def test_coreml_classify_sine(self):
        from main import classify_with_coreml
        t = np.arange(REQUIRED_SAMPLES) / SAMPLE_RATE
        sine = (np.sin(2 * np.pi * 440 * t) * 0.5).astype(np.float32)
        result = classify_with_coreml(sine)

        assert result["is_cry"] is True
        assert result["cry_type"] in {"hungry", "needs_burping", "belly_pain", "discomfort", "tired"}
        assert "probabilities" in result
        assert sum(result["probabilities"].values()) == pytest.approx(1.0, abs=0.05)

    def test_coreml_output_has_5_types(self):
        from main import classify_with_coreml
        audio = np.random.randn(REQUIRED_SAMPLES).astype(np.float32) * 0.1
        result = classify_with_coreml(audio)

        expected_types = {"hungry", "needs_burping", "belly_pain", "discomfort", "tired"}
        assert set(result["probabilities"].keys()) == expected_types


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
