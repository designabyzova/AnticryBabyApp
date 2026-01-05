#!/usr/bin/env python3
"""
Unit Tests for Model Evaluation Framework

Tests the ModelEvaluator class with real model loading and inference.
Coverage Target: 85%
"""

import pytest
import json
from pathlib import Path
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.evaluate_model import ModelEvaluator, generate_test_commands


class TestModelEvaluator:
    """Test suite for ModelEvaluator"""

    @pytest.fixture
    def evaluator(self):
        """Create evaluator with small test model"""
        # Use DistilBERT for real testing (matches production model)
        return ModelEvaluator(model_name="distilbert-base-uncased", device="cpu")

    def test_load_model(self, evaluator):
        """Test: Model loads without errors"""
        evaluator.load_model(num_labels=150)

        assert evaluator.model is not None, "Model should be loaded"
        assert evaluator.tokenizer is not None, "Tokenizer should be loaded"
        assert evaluator.model.training is False, "Model should be in eval mode"

    def test_inference_output(self, evaluator):
        """Test: Model returns logits array"""
        evaluator.load_model(num_labels=150)

        import torch

        # Run inference
        inputs = evaluator.tokenizer(
            "play lullabies",
            return_tensors="pt",
            padding=True,
            truncation=True
        )

        with torch.no_grad():
            outputs = evaluator.model(**inputs)

        # Check outputs
        assert outputs.logits is not None, "Model should return logits"
        assert outputs.logits.shape[0] == 1, "Batch size should be 1"
        assert outputs.logits.shape[1] == 150, "Should have 150 intent classes"

    def test_latency_measurement(self, evaluator):
        """Test: Latency captured accurately"""
        evaluator.load_model(num_labels=150)

        test_commands = generate_test_commands(n=10)
        results = evaluator.measure_latency(test_commands, n_runs=10)

        # Validate results structure
        assert "mean" in results, "Should have mean latency"
        assert "p50" in results, "Should have p50 latency"
        assert "p95" in results, "Should have p95 latency"
        assert "p99" in results, "Should have p99 latency"

        # Validate latency values are reasonable
        assert results["mean"] > 0, "Mean latency should be positive"
        assert results["p95"] >= results["p50"], "P95 should be >= P50"
        assert results["p99"] >= results["p95"], "P99 should be >= P95"

        # Latency should be < 5000ms on CPU (generous upper bound)
        assert results["p95"] < 5000, f"P95 latency too high: {results['p95']}ms"

    def test_model_size_measurement(self, evaluator):
        """Test: Model size calculated correctly"""
        evaluator.load_model(num_labels=150)

        size_results = evaluator.measure_model_size()

        # Validate results structure
        assert "num_parameters" in size_results
        assert "size_fp32_mb" in size_results
        assert "size_fp16_mb" in size_results
        assert "size_int8_mb" in size_results

        # DistilBERT should have ~66M parameters
        assert 60_000_000 < size_results["num_parameters"] < 80_000_000

        # FP16 should be half of FP32
        assert abs(size_results["size_fp16_mb"] - size_results["size_fp32_mb"] / 2) < 1

        # INT8 should be quarter of FP32
        assert abs(size_results["size_int8_mb"] - size_results["size_fp32_mb"] / 4) < 1


class TestTestCommandGeneration:
    """Test suite for test command generation"""

    def test_generates_correct_count(self):
        """Test: Generates requested number of commands"""
        commands = generate_test_commands(n=50)
        assert len(commands) == 50, "Should generate exactly 50 commands"

    def test_commands_not_empty(self):
        """Test: All commands are non-empty strings"""
        commands = generate_test_commands(n=30)

        for cmd in commands:
            assert isinstance(cmd, str), "Command should be a string"
            assert len(cmd) > 0, "Command should not be empty"

    def test_commands_have_variety(self):
        """Test: Commands have some variety"""
        commands = generate_test_commands(n=100)
        unique_commands = set(commands)

        # Should have at least 10 unique commands (we have 15 base commands)
        assert len(unique_commands) >= 10, "Should have variety in commands"


# Run tests if executed directly
if __name__ == "__main__":
    pytest.main([__file__, "-v", "--cov=scripts.evaluate_model", "--cov-report=term-missing"])
