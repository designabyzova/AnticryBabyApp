#!/usr/bin/env python3
"""
Integration Tests for Model Evaluation Pipeline

Tests the full evaluation workflow end-to-end.
Coverage Target: 80%
"""

import pytest
import json
from pathlib import Path
import sys
import tempfile

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.evaluate_model import ModelEvaluator, generate_test_commands


class TestEvaluationPipeline:
    """Integration tests for full evaluation pipeline"""

    @pytest.fixture
    def temp_output(self):
        """Create temporary output file"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            yield Path(f.name)

        # Cleanup
        Path(f.name).unlink(missing_ok=True)

    def test_full_evaluation_run(self):
        """Test: Full evaluation runs without errors"""
        evaluator = ModelEvaluator(model_name="distilbert-base-uncased", device="cpu")
        evaluator.load_model(num_labels=150)

        # Generate test inputs
        test_commands = generate_test_commands(n=20)

        # Run latency measurement
        latency_results = evaluator.measure_latency(test_commands, n_runs=20)

        # Run size measurement
        size_results = evaluator.measure_model_size()

        # Validate both results exist
        assert latency_results is not None
        assert size_results is not None

        # Validate latency keys
        assert all(k in latency_results for k in ["mean", "p50", "p95", "p99"])

        # Validate size keys
        assert all(k in size_results for k in ["num_parameters", "size_fp32_mb", "size_int8_mb"])

    def test_results_json_created(self, temp_output):
        """Test: Results file is created with correct structure"""
        evaluator = ModelEvaluator(model_name="distilbert-base-uncased", device="cpu")
        evaluator.load_model(num_labels=150)

        # Generate test data
        test_commands = generate_test_commands(n=10)

        # Run evaluation
        latency_results = evaluator.measure_latency(test_commands, n_runs=10)
        size_results = evaluator.measure_model_size()

        # Aggregate results
        results = {
            "model_name": "distilbert-base-uncased",
            "latency": latency_results,
            "size": size_results,
            "device": evaluator.device,
        }

        # Save results
        evaluator.save_results(results, temp_output)

        # Verify file was created
        assert temp_output.exists(), "Results file should be created"

        # Load and validate JSON structure
        with open(temp_output, "r") as f:
            loaded_results = json.load(f)

        assert "model_name" in loaded_results
        assert "latency" in loaded_results
        assert "size" in loaded_results
        assert loaded_results["model_name"] == "distilbert-base-uncased"


# Run tests if executed directly
if __name__ == "__main__":
    pytest.main([__file__, "-v", "--cov=scripts.evaluate_model", "--cov-report=term-missing"])
