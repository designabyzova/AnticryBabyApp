#!/usr/bin/env python3
"""
Model Evaluation Script for Lulla Voice Commands

Evaluates models on latency, accuracy, and size metrics.
"""

import json
import time
from pathlib import Path
from typing import Dict, List, Tuple, Any

import torch
import numpy as np
from transformers import AutoTokenizer, AutoModelForSequenceClassification


class ModelEvaluator:
    """Evaluate transformer models for Lulla voice commands"""

    def __init__(self, model_name: str, device: str = None):
        """
        Initialize evaluator

        Args:
            model_name: Hugging Face model name (e.g., "distilbert-base-uncased")
            device: Device to run on ("cpu", "cuda", "mps"). Auto-detect if None.
        """
        self.model_name = model_name

        # Auto-detect device
        if device is None:
            if torch.cuda.is_available():
                self.device = "cuda"
            elif torch.backends.mps.is_available():
                self.device = "mps"  # Apple Silicon
            else:
                self.device = "cpu"
        else:
            self.device = device

        print(f"Using device: {self.device}")

        # Load model and tokenizer
        self.tokenizer = None
        self.model = None

    def load_model(self, num_labels: int = 150):
        """Load model from Hugging Face"""
        print(f"Loading {self.model_name}...")

        self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
        self.model = AutoModelForSequenceClassification.from_pretrained(
            self.model_name,
            num_labels=num_labels
        )
        self.model.to(self.device)
        self.model.eval()

        print(f"✅ Model loaded: {self.model_name}")

    def measure_latency(
        self,
        test_inputs: List[str],
        n_runs: int = 100
    ) -> Dict[str, float]:
        """
        Measure inference latency

        Args:
            test_inputs: List of test text inputs
            n_runs: Number of inference runs per input

        Returns:
            Dict with p50, p95, p99, mean latency (ms)
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")

        latencies = []

        with torch.no_grad():
            for text in test_inputs[:n_runs]:  # Use first n_runs examples
                # Tokenize
                inputs = self.tokenizer(
                    text,
                    return_tensors="pt",
                    padding=True,
                    truncation=True,
                    max_length=128
                ).to(self.device)

                # Warm-up run (not counted)
                if len(latencies) == 0:
                    _ = self.model(**inputs)

                # Measured run
                start = time.perf_counter()
                _ = self.model(**inputs)
                if self.device == "mps" or self.device == "cuda":
                    torch.mps.synchronize() if self.device == "mps" else torch.cuda.synchronize()
                end = time.perf_counter()

                latency_ms = (end - start) * 1000
                latencies.append(latency_ms)

        latencies = np.array(latencies)

        return {
            "mean": float(np.mean(latencies)),
            "p50": float(np.percentile(latencies, 50)),
            "p95": float(np.percentile(latencies, 95)),
            "p99": float(np.percentile(latencies, 99)),
            "min": float(np.min(latencies)),
            "max": float(np.max(latencies)),
        }

    def measure_accuracy(
        self,
        test_set: List[Tuple[str, int]]
    ) -> Dict[str, Any]:
        """
        Measure classification accuracy

        Args:
            test_set: List of (text, label_id) tuples

        Returns:
            Dict with accuracy, per-class metrics
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")

        correct = 0
        total = 0
        predictions = []
        true_labels = []

        with torch.no_grad():
            for text, label in test_set:
                inputs = self.tokenizer(
                    text,
                    return_tensors="pt",
                    padding=True,
                    truncation=True,
                    max_length=128
                ).to(self.device)

                outputs = self.model(**inputs)
                logits = outputs.logits
                pred = torch.argmax(logits, dim=-1).item()

                predictions.append(pred)
                true_labels.append(label)

                if pred == label:
                    correct += 1
                total += 1

        accuracy = correct / total if total > 0 else 0.0

        return {
            "accuracy": accuracy,
            "correct": correct,
            "total": total,
            "predictions": predictions,
            "true_labels": true_labels,
        }

    def measure_model_size(self) -> Dict[str, float]:
        """
        Measure model size (parameters, estimated disk size)

        Returns:
            Dict with num_parameters, estimated_size_mb
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")

        num_params = sum(p.numel() for p in self.model.parameters())

        # Estimate FP32 size (4 bytes per param)
        size_fp32_mb = (num_params * 4) / (1024 ** 2)

        # Estimate FP16 size (2 bytes per param)
        size_fp16_mb = (num_params * 2) / (1024 ** 2)

        # Estimate INT8 size (1 byte per param)
        size_int8_mb = num_params / (1024 ** 2)

        return {
            "num_parameters": num_params,
            "size_fp32_mb": size_fp32_mb,
            "size_fp16_mb": size_fp16_mb,
            "size_int8_mb": size_int8_mb,
        }

    def save_results(self, results: Dict, output_path: Path):
        """Save evaluation results to JSON"""
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, "w") as f:
            json.dump(results, f, indent=2)

        print(f"✅ Results saved to {output_path}")


def generate_test_commands(n: int = 100) -> List[str]:
    """Generate sample test commands for latency evaluation"""
    commands = [
        "play lullabies",
        "pause the music",
        "stop",
        "play fairy tales",
        "turn up the volume",
        "baby is sleepy",
        "next track",
        "play Piano Moment",
        "turn down the volume",
        "baby is crying",
        "resume playback",
        "play classical music",
        "previous track",
        "search for Brahms",
        "emergency mode",
    ]

    # Repeat to reach n examples
    test_set = []
    while len(test_set) < n:
        test_set.extend(commands)

    return test_set[:n]


def main():
    """Main evaluation routine"""
    import argparse

    parser = argparse.ArgumentParser(description="Evaluate model for Lulla voice commands")
    parser.add_argument(
        "--model",
        type=str,
        default="distilbert-base-uncased",
        help="Hugging Face model name"
    )
    parser.add_argument(
        "--n-runs",
        type=int,
        default=100,
        help="Number of latency measurement runs"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("ml_training/results/evaluation.json"),
        help="Output path for results"
    )

    args = parser.parse_args()

    # Initialize evaluator
    evaluator = ModelEvaluator(model_name=args.model)
    evaluator.load_model(num_labels=150)

    # Generate test inputs
    test_commands = generate_test_commands(n=args.n_runs)

    # Measure latency
    print(f"\n📊 Measuring latency ({args.n_runs} runs)...")
    latency_results = evaluator.measure_latency(test_commands, n_runs=args.n_runs)

    print(f"  Mean: {latency_results['mean']:.2f}ms")
    print(f"  P50:  {latency_results['p50']:.2f}ms")
    print(f"  P95:  {latency_results['p95']:.2f}ms")
    print(f"  P99:  {latency_results['p99']:.2f}ms")

    # Measure model size
    print(f"\n📏 Measuring model size...")
    size_results = evaluator.measure_model_size()

    print(f"  Parameters: {size_results['num_parameters']:,}")
    print(f"  FP32: {size_results['size_fp32_mb']:.1f}MB")
    print(f"  FP16: {size_results['size_fp16_mb']:.1f}MB")
    print(f"  INT8: {size_results['size_int8_mb']:.1f}MB")

    # Aggregate results
    results = {
        "model_name": args.model,
        "latency": latency_results,
        "size": size_results,
        "device": evaluator.device,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

    # Save results
    evaluator.save_results(results, args.output)

    print(f"\n✅ Evaluation complete!")


if __name__ == "__main__":
    main()
