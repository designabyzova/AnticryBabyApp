"""
Tests for audio preprocessing - DeepInfant V2 specifications
"""

import pytest
import numpy as np
import tempfile
import os
import sys

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import (
    load_and_preprocess_audio,
    extract_features,
    get_action_category,
    SAMPLE_RATE,
    N_FFT,
    HOP_LENGTH,
    N_MELS,
    F_MIN,
    F_MAX,
    REQUIRED_DURATION,
    REQUIRED_SAMPLES,
)


class TestDeepInfantV2Constants:
    """Test that constants match DeepInfant V2 specifications"""

    def test_sample_rate(self):
        assert SAMPLE_RATE == 16000, "Sample rate should be 16kHz"

    def test_fft_size(self):
        assert N_FFT == 1024, "FFT size should be 1024"

    def test_hop_length(self):
        assert HOP_LENGTH == 256, "Hop length should be 256"

    def test_mel_bands(self):
        assert N_MELS == 80, "Mel bands should be 80"

    def test_frequency_range(self):
        assert F_MIN == 20, "fMin should be 20Hz"
        assert F_MAX == 8000, "fMax should be 8000Hz"

    def test_duration(self):
        assert REQUIRED_DURATION == 7.0, "Duration should be 7 seconds"

    def test_samples(self):
        assert REQUIRED_SAMPLES == 112000, "Required samples should be 112,000"


class TestActionCategoryMapping:
    """Test DeepInfant V2 cry type to action category mapping (5 → 3)"""

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

    def test_legacy_hunger_maps_to_hungry(self):
        assert get_action_category("hunger") == "hungry"

    def test_legacy_pain_maps_to_uncomfortable(self):
        assert get_action_category("pain") == "uncomfortable"

    def test_unknown_defaults_to_uncomfortable(self):
        assert get_action_category("unknown_type") == "uncomfortable"

    def test_case_insensitive(self):
        assert get_action_category("HUNGRY") == "hungry"
        assert get_action_category("Tired") == "tired"


class TestFeatureExtraction:
    """Test audio feature extraction"""

    @pytest.fixture
    def sine_wave(self):
        """Generate 7 seconds of 440Hz sine wave at 16kHz"""
        t = np.arange(REQUIRED_SAMPLES) / SAMPLE_RATE
        return np.sin(2 * np.pi * 440 * t).astype(np.float32)

    @pytest.fixture
    def silence(self):
        """Generate 7 seconds of silence"""
        return np.zeros(REQUIRED_SAMPLES, dtype=np.float32)

    def test_features_from_sine_wave(self, sine_wave):
        features = extract_features(sine_wave, SAMPLE_RATE)

        # Should have all expected keys
        assert "rms" in features
        assert "spectral_centroid" in features
        assert "spectral_rolloff" in features
        assert "zero_crossing_rate" in features
        assert "pitch_mean" in features
        assert "onset_strength" in features
        assert "spectral_contrast" in features
        assert "duration_seconds" in features

        # RMS should be non-zero for sine wave
        assert features["rms"] > 0

        # Duration should be 7 seconds
        assert features["duration_seconds"] == pytest.approx(7.0, rel=0.1)

    def test_features_from_silence(self, silence):
        features = extract_features(silence, SAMPLE_RATE)

        # RMS should be zero for silence
        assert features["rms"] == pytest.approx(0, abs=0.001)


class TestMelSpectrogramGeneration:
    """Test mel-spectrogram generation with correct parameters"""

    def generate_test_wav(self, duration_seconds=7.0, frequency=440.0):
        """Generate a test WAV file"""
        import wave
        import struct

        samples = int(duration_seconds * SAMPLE_RATE)
        t = np.arange(samples) / SAMPLE_RATE
        audio = (np.sin(2 * np.pi * frequency * t) * 32767).astype(np.int16)

        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            wav_file = wave.open(f.name, 'wb')
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            wav_file.writeframes(audio.tobytes())
            wav_file.close()
            return f.name

    def test_mel_spectrogram_shape(self):
        """Test that mel-spectrogram has correct shape (80, ~431)"""
        wav_path = self.generate_test_wav(duration_seconds=7.0)

        try:
            with open(wav_path, 'rb') as f:
                audio_bytes = f.read()

            mel_spec, features = load_and_preprocess_audio(audio_bytes)

            # Shape should be (80, ~431) for 7 seconds
            assert mel_spec.shape[0] == N_MELS, f"Expected {N_MELS} mel bands, got {mel_spec.shape[0]}"

            # Time frames: (112000 - 1024) / 256 + 1 ≈ 434
            # Some variance is expected due to librosa's handling
            assert 400 <= mel_spec.shape[1] <= 450, f"Expected ~431 time frames, got {mel_spec.shape[1]}"

        finally:
            os.unlink(wav_path)

    def test_mel_spectrogram_normalized(self):
        """Test that mel-spectrogram is normalized to [0, 1]"""
        wav_path = self.generate_test_wav()

        try:
            with open(wav_path, 'rb') as f:
                audio_bytes = f.read()

            mel_spec, _ = load_and_preprocess_audio(audio_bytes)

            # Check normalization
            assert mel_spec.min() >= 0.0, "Mel-spectrogram should have min >= 0"
            assert mel_spec.max() <= 1.0, "Mel-spectrogram should have max <= 1"

        finally:
            os.unlink(wav_path)

    def test_short_audio_padded(self):
        """Test that short audio is padded to 7 seconds"""
        wav_path = self.generate_test_wav(duration_seconds=2.0)

        try:
            with open(wav_path, 'rb') as f:
                audio_bytes = f.read()

            mel_spec, features = load_and_preprocess_audio(audio_bytes)

            # Should still have correct shape after padding
            assert mel_spec.shape[0] == N_MELS
            # Duration should be reported as full 7 seconds after padding
            assert features["duration_seconds"] == pytest.approx(7.0, rel=0.1)

        finally:
            os.unlink(wav_path)

    def test_long_audio_trimmed(self):
        """Test that long audio is trimmed to 7 seconds"""
        wav_path = self.generate_test_wav(duration_seconds=10.0)

        try:
            with open(wav_path, 'rb') as f:
                audio_bytes = f.read()

            mel_spec, features = load_and_preprocess_audio(audio_bytes)

            # Should have correct shape after trimming
            assert mel_spec.shape[0] == N_MELS
            # Duration should be exactly 7 seconds
            assert features["duration_seconds"] == pytest.approx(7.0, rel=0.1)

        finally:
            os.unlink(wav_path)


class TestCryDetection:
    """Test cry detection logic"""

    # These tests require the full classify_with_features function
    # which depends on more complex setup

    def test_silence_not_detected_as_cry(self):
        """Silence should not be detected as a cry"""
        features = {
            "rms": 0.0,
            "spectral_centroid": 0.0,
            "spectral_rolloff": 0.0,
            "zero_crossing_rate": 0.0,
            "pitch_mean": 0.0,
            "onset_strength": 0.0,
            "spectral_contrast": 0.0,
            "duration_seconds": 7.0
        }

        from main import classify_with_features
        result = classify_with_features(features, np.zeros((80, 431)))

        assert result["is_cry"] == False, "Silence should not be detected as cry"

    def test_loud_audio_detected(self):
        """Audio with sufficient energy should be considered for cry detection"""
        features = {
            "rms": 0.1,  # Non-trivial energy
            "spectral_centroid": 800.0,
            "spectral_rolloff": 3000.0,
            "zero_crossing_rate": 0.05,
            "pitch_mean": 400.0,
            "onset_strength": 0.3,
            "spectral_contrast": 10.0,
            "duration_seconds": 7.0
        }

        from main import classify_with_features
        result = classify_with_features(features, np.random.rand(80, 431))

        # With these features, it should at least attempt classification
        # (result may be is_cry=True or False depending on thresholds)
        assert "is_cry" in result
        assert "cry_confidence" in result


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
