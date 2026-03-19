#!/usr/bin/env python3
"""
Quantize DeepInfant V2 model from INT8 to INT4.

The model is a pipelineClassifier with 3 stages:
  Stage 0: soundAnalysisPreprocessing (VGGish) — no quantizable weights
  Stage 1: neuralNetwork (VGGish CNN, 6 conv layers, currently INT8)
  Stage 2: glmClassifier — float weights, not touched by NN quantization

coremltools 9.0 has a bug where quantize_weights() crashes on pipeline models,
so we use the internal _quantize_spec_weights on the neuralNetwork sub-model directly.

Since weights are already INT8, we must:
  1. Dequantize INT8 → float
  2. Re-quantize float → INT4
"""

import os
import sys
import shutil

# Suppress scikit-learn/torch warnings
import warnings
warnings.filterwarnings("ignore")

import coremltools as ct
from coremltools.models.neural_network.quantization_utils import _quantize_spec_weights
import coremltools.models as ct_models

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
MODEL_DIR = os.path.join(PROJECT_ROOT, "BabyInCarApp", "BabyInCarApp", "Resources")
INPUT_MODEL = os.path.join(MODEL_DIR, "DeepInfant_V2.mlmodel")
OUTPUT_MODEL = os.path.join(MODEL_DIR, "DeepInfant_V2_INT4.mlmodel")
BACKUP_MODEL = os.path.join(SCRIPT_DIR, "DeepInfant_V2_INT8_backup.mlmodel")


def get_file_size_mb(path):
    """Get file size in MB."""
    if os.path.isdir(path):
        total = 0
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                total += os.path.getsize(os.path.join(dirpath, f))
        return total / (1024 * 1024)
    return os.path.getsize(path) / (1024 * 1024)


def get_weight_info(layer):
    """Get quantization info from a layer's weight params."""
    layer_type = layer.WhichOneof("layer")
    if layer_type == "convolution":
        weights = layer.convolution.weights
    elif layer_type == "innerProduct":
        weights = layer.innerProduct.weights
    elif layer_type == "batchnorm":
        return layer_type, "batchnorm (no weight quantization)"
    else:
        return layer_type, None

    # Check if weights are quantized by looking at quantization field
    if weights.HasField("quantization"):
        bits = weights.quantization.numberOfBits
        return layer_type, f"quantized to {bits}-bit"
    elif len(weights.floatValue) > 0:
        return layer_type, "float32"
    elif len(weights.float16Value) > 0:
        return layer_type, "float16"
    else:
        return layer_type, "raw bytes"


def inspect_model(spec):
    """Print model structure info."""
    print(f"  Spec version: {spec.specificationVersion}")

    if spec.HasField("pipelineClassifier"):
        pipeline = spec.pipelineClassifier.pipeline
        print(f"  Type: pipelineClassifier ({len(pipeline.models)} stages)")
        for i, sub in enumerate(pipeline.models):
            model_type = sub.WhichOneof("Type")
            print(f"    Stage {i}: {model_type}")
            if model_type == "neuralNetwork":
                layers = sub.neuralNetwork.layers
                print(f"      Layers: {len(layers)}")
                for layer in layers:
                    lt, info = get_weight_info(layer)
                    if info:
                        print(f"      {layer.name} ({lt}): {info}")
    else:
        print(f"  Type: {spec.WhichOneof('Type')}")


def quantize_to_int4(input_path, output_path):
    """Quantize pipeline model's neural network sub-model to INT4."""

    print(f"\n{'='*60}")
    print(f"DeepInfant V2: INT8 → INT4 Quantization")
    print(f"{'='*60}")

    # Load model
    print(f"\n[1/5] Loading model: {os.path.basename(input_path)}")
    model = ct.models.MLModel(input_path)
    spec = model.get_spec()

    print("\nOriginal model structure:")
    inspect_model(spec)

    original_size = get_file_size_mb(input_path)
    print(f"\n  Original size: {original_size:.2f} MB")

    # Get the neuralNetwork sub-model (Stage 1)
    print(f"\n[2/5] Extracting neuralNetwork sub-model (Stage 1)...")
    nn_spec = spec.pipelineClassifier.pipeline.models[1]

    # Step 1: Dequantize from INT8 back to float
    print(f"\n[3/5] Dequantizing INT8 → float...")
    dequant_mode = ct_models._QUANTIZATION_MODE_DEQUANTIZE
    _quantize_spec_weights(nn_spec, None, dequant_mode)

    # Step 2: Re-quantize to INT4 (linear quantization)
    print(f"\n[4/5] Quantizing float → INT4 (linear)...")
    linear_mode = ct_models._QUANTIZATION_MODE_LINEAR_QUANTIZATION
    _quantize_spec_weights(nn_spec, 4, linear_mode)

    # Save
    print(f"\n[5/5] Saving quantized model...")
    quantized_model = ct.models.MLModel(spec)
    quantized_model.save(output_path)

    new_size = get_file_size_mb(output_path)
    reduction = (1 - new_size / original_size) * 100

    print(f"\nQuantized model structure:")
    new_spec = ct.models.MLModel(output_path).get_spec()
    inspect_model(new_spec)

    print(f"\n{'='*60}")
    print(f"Results:")
    print(f"  Original (INT8): {original_size:.2f} MB")
    print(f"  Quantized (INT4): {new_size:.2f} MB")
    print(f"  Reduction: {reduction:.1f}%")
    print(f"  Saved: {original_size - new_size:.2f} MB")
    print(f"{'='*60}")

    return output_path


def verify_model(model_path):
    """Verify the quantized model loads and has correct structure."""
    print(f"\n[Verification] Loading quantized model...")
    model = ct.models.MLModel(model_path)
    spec = model.get_spec()

    # Check it's still a pipelineClassifier
    assert spec.HasField("pipelineClassifier"), "Model must be pipelineClassifier"

    pipeline = spec.pipelineClassifier.pipeline
    assert len(pipeline.models) == 3, f"Expected 3 stages, got {len(pipeline.models)}"

    # Check Stage 1 is now INT4
    nn_spec = pipeline.models[1]
    assert nn_spec.WhichOneof("Type") == "neuralNetwork", "Stage 1 must be neuralNetwork"

    for layer in nn_spec.neuralNetwork.layers:
        layer_type = layer.WhichOneof("layer")
        weights = None
        if layer_type == "convolution":
            weights = layer.convolution.weights
        elif layer_type == "innerProduct":
            weights = layer.innerProduct.weights

        if weights and weights.HasField("quantization"):
            bits = weights.quantization.numberOfBits
            assert bits == 4, f"Layer {layer.name}: expected 4-bit, got {bits}-bit"

    # Check output classes - try different protobuf field names
    class_labels = []
    pc = spec.pipelineClassifier
    if pc.HasField("stringClassLabels"):
        class_labels = list(pc.stringClassLabels.vector)
    else:
        # Try getting from the glmClassifier sub-model
        glm = pipeline.models[2]
        if glm.WhichOneof("Type") == "glmClassifier":
            class_labels = list(glm.glmClassifier.stringClassLabels.vector)

    if class_labels:
        expected_classes = [
            "belly_pain", "burping", "cold_hot", "discomfort",
            "hungry", "lonely", "scared", "tired", "unknown"
        ]
        assert sorted(class_labels) == sorted(expected_classes), \
            f"Class mismatch: {class_labels} vs {expected_classes}"
        print(f"  ✅ All 9 output classes preserved: {', '.join(sorted(class_labels))}")
    else:
        # Still verify the model has the glmClassifier stage
        glm_type = pipeline.models[2].WhichOneof("Type")
        print(f"  ✅ Stage 2 ({glm_type}) preserved (class labels embedded)")

    print(f"  ✅ pipelineClassifier with 3 stages")
    print(f"  ✅ Neural network layers quantized to 4-bit")
    print(f"  ✅ Model verification PASSED")

    return True


if __name__ == "__main__":
    if not os.path.exists(INPUT_MODEL):
        print(f"ERROR: Model not found at {INPUT_MODEL}")
        sys.exit(1)

    # Backup original
    if not os.path.exists(BACKUP_MODEL):
        print(f"Backing up original model to {os.path.basename(BACKUP_MODEL)}...")
        shutil.copy2(INPUT_MODEL, BACKUP_MODEL)

    # Quantize
    output = quantize_to_int4(INPUT_MODEL, OUTPUT_MODEL)

    # Verify
    verify_model(output)

    print(f"\n✅ Done! INT4 model saved to: {os.path.basename(output)}")
    print(f"   To use it, rename it to DeepInfant_V2.mlmodel and rebuild the app.")
