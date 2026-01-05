#!/usr/bin/env python3
"""
DistilBERT Benchmark for Lulla Voice Commands

Benchmarks DistilBERT-base-uncased on 300 Lulla command examples.
Measures latency (p50, p95), model size, and validates against targets.

Target: p95 < 500ms, size < 50MB quantized
"""

import json
import sys
from pathlib import Path
from typing import List, Dict

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.evaluate_model import ModelEvaluator, generate_test_commands


def generate_lulla_test_commands(n: int = 300) -> List[str]:
    """
    Generate 300 realistic Lulla voice commands for benchmarking

    Covers all 6 command categories with natural language variations.
    """
    playback_commands = [
        "play",
        "play music",
        "start playing",
        "put on some music",
        "begin playback",
        "pause",
        "pause the music",
        "stop playing",
        "hold on",
        "pause it",
        "stop",
        "stop the music",
        "end playback",
        "turn it off",
        "resume",
        "resume playback",
        "continue playing",
        "keep going",
        "next",
        "next track",
        "skip this one",
        "play the next song",
        "previous",
        "go back",
        "previous track",
        "last song",
    ]

    category_commands = [
        "play lullabies",
        "put on lullabies",
        "some lullabies please",
        "lullabies",
        "play fairy tales",
        "put on fairy tales",
        "fairy tales please",
        "tell a fairy tale",
        "play nature sounds",
        "nature sounds",
        "some nature please",
        "ocean sounds",
        "play classical",
        "classical music",
        "some classical please",
        "Mozart",
        "play children songs",
        "kids music",
        "children's songs please",
        "play instrumental",
        "instrumental music",
        "some calm music",
    ]

    search_commands = [
        "play Piano Moment",
        "find Piano Moment",
        "play the Piano Moment track",
        "search for Brahms",
        "find Brahms lullaby",
        "play Brahms",
        "play Mozart",
        "search for ocean waves",
        "find twinkle twinkle",
        "play Baby Elephant Walk",
    ]

    volume_commands = [
        "louder",
        "turn it up",
        "increase volume",
        "make it louder",
        "quieter",
        "turn it down",
        "decrease volume",
        "make it quieter",
        "lower the volume",
        "mute",
        "silence",
        "turn off the sound",
        "set volume to 50",
        "volume 75",
    ]

    mood_commands = [
        "baby is sleepy",
        "my baby is tired",
        "time for sleep",
        "sleepy time",
        "baby is fussy",
        "baby is cranky",
        "fussy baby",
        "baby is playful",
        "baby is happy",
        "playtime",
        "baby is hungry",
        "feeding time",
    ]

    emergency_commands = [
        "baby is crying",
        "baby crying",
        "crying baby",
        "emergency mode",
        "emergency",
        "help baby is crying",
        "stop the crying",
        "baby won't stop crying",
    ]

    all_commands = (
        playback_commands +
        category_commands +
        search_commands +
        volume_commands +
        mood_commands +
        emergency_commands
    )

    # Repeat to reach n examples
    test_set = []
    while len(test_set) < n:
        test_set.extend(all_commands)

    return test_set[:n]


def run_benchmark():
    """Run full DistilBERT benchmark"""
    print("=" * 70)
    print("DistilBERT Benchmark for Lulla Voice Commands")
    print("=" * 70)

    # Initialize evaluator
    model_name = "distilbert-base-uncased"
    evaluator = ModelEvaluator(model_name=model_name)

    print(f"\n📦 Loading {model_name}...")
    evaluator.load_model(num_labels=150)

    # Generate test commands
    print(f"\n📝 Generating 300 Lulla test commands...")
    test_commands = generate_lulla_test_commands(n=300)
    print(f"   ✅ {len(test_commands)} commands generated")

    # Measure latency
    print(f"\n⏱️  Measuring latency (300 inference runs)...")
    print(f"   Device: {evaluator.device}")
    latency_results = evaluator.measure_latency(test_commands, n_runs=300)

    print(f"\n📊 Latency Results:")
    print(f"   Mean:  {latency_results['mean']:.2f}ms")
    print(f"   P50:   {latency_results['p50']:.2f}ms")
    print(f"   P95:   {latency_results['p95']:.2f}ms")
    print(f"   P99:   {latency_results['p99']:.2f}ms")
    print(f"   Min:   {latency_results['min']:.2f}ms")
    print(f"   Max:   {latency_results['max']:.2f}ms")

    # Check against targets
    target_p95_ms = 500
    if latency_results['p95'] < target_p95_ms:
        print(f"   ✅ PASS: P95 ({latency_results['p95']:.2f}ms) < {target_p95_ms}ms target")
    else:
        print(f"   ⚠️  WARNING: P95 ({latency_results['p95']:.2f}ms) >= {target_p95_ms}ms target")
        print(f"   → Quantization to INT8 recommended")

    # Measure model size
    print(f"\n📏 Model Size:")
    size_results = evaluator.measure_model_size()

    print(f"   Parameters: {size_results['num_parameters']:,}")
    print(f"   FP32: {size_results['size_fp32_mb']:.1f}MB")
    print(f"   FP16: {size_results['size_fp16_mb']:.1f}MB")
    print(f"   INT8: {size_results['size_int8_mb']:.1f}MB (quantized)")

    # Check against targets
    target_size_mb = 50
    if size_results['size_int8_mb'] < target_size_mb:
        print(f"   ✅ PASS: INT8 size ({size_results['size_int8_mb']:.1f}MB) < {target_size_mb}MB target")
    else:
        print(f"   ⚠️  WARNING: INT8 size ({size_results['size_int8_mb']:.1f}MB) >= {target_size_mb}MB target")

    # Save results
    output_path = Path(__file__).parent.parent / "results" / "distilbert_benchmark.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    results = {
        "model_name": model_name,
        "num_test_commands": len(test_commands),
        "latency": latency_results,
        "size": size_results,
        "device": evaluator.device,
        "targets": {
            "latency_p95_ms": target_p95_ms,
            "size_int8_mb": target_size_mb,
        },
        "meets_targets": {
            "latency": latency_results['p95'] < target_p95_ms,
            "size": size_results['size_int8_mb'] < target_size_mb,
        },
    }

    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n💾 Results saved to: {output_path}")

    # Summary
    print(f"\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Model: {model_name}")
    print(f"Latency P95: {latency_results['p95']:.2f}ms (target: <{target_p95_ms}ms)")
    print(f"Size (INT8): {size_results['size_int8_mb']:.1f}MB (target: <{target_size_mb}MB)")
    print(f"Device: {evaluator.device}")

    if results['meets_targets']['latency'] and results['meets_targets']['size']:
        print(f"\n✅ DistilBERT meets all targets!")
    else:
        print(f"\n⚠️  DistilBERT does not meet all targets - consider optimizations")

    print("=" * 70)

    return results


if __name__ == "__main__":
    results = run_benchmark()
