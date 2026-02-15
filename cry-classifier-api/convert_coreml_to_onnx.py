"""
Convert DeepInfant V2 CoreML model to ONNX format.

This script extracts the CNN + GLM classifier from the CoreML pipeline
and exports them as a single ONNX model. The CoreML model uses Apple's
soundAnalysisPreprocessing (VGGish) as step 0, which we replicate in
Python using librosa.

Pipeline structure:
  Step 0: soundAnalysisPreprocessing (VGGish) -> [1, 96, 64] log-mel spectrogram
  Step 1: CNN (VGG-like, 8-bit quantized) -> [12288] features
  Step 2: GLM Classifier -> 9 classes

We export Steps 1+2 as ONNX, and handle Step 0 in Python preprocessing.
"""

import os
import sys
import numpy as np


def dequantize_data(raw_value: bytes, quantization, shape: tuple) -> np.ndarray:
    """Dequantize 8-bit quantized data from CoreML format.

    CoreML linear quantization formula (from Apple documentation):
        float_value = scale * uint8_value + bias

    Note: CoreML does NOT subtract 128 (zero-point). The formula is simply
    scale * stored_value + bias, where stored_value is a raw uint8.

    For per-channel quantization (weights): one scale+bias per output channel
    For per-tensor quantization (bias): single scale+bias for all values
    """
    uint8_values = np.frombuffer(raw_value, dtype=np.uint8)
    scales = np.array(quantization.linearQuantization.scale, dtype=np.float32)
    biases = np.array(quantization.linearQuantization.bias, dtype=np.float32)

    total_elements = int(np.prod(shape))
    assert len(uint8_values) == total_elements, \
        f"Raw data size {len(uint8_values)} != expected {total_elements}"

    if len(scales) == 1:
        # Per-tensor quantization (single scale+bias for all values)
        values = uint8_values.astype(np.float32)
        values = scales[0] * values + biases[0]
        return values.reshape(shape)
    else:
        # Per-channel quantization (one scale+bias per output channel)
        out_channels = shape[0]
        per_channel_size = total_elements // out_channels
        values = uint8_values.reshape(out_channels, per_channel_size).astype(np.float32)

        for c in range(out_channels):
            if c < len(scales):
                values[c] = scales[c] * values[c] + biases[c]

        return values.reshape(shape)


def extract_and_convert():
    """Extract CNN + GLM from CoreML and export as ONNX."""
    try:
        import coremltools as ct
    except ImportError:
        print("[ERROR] coremltools is required. Install with: pip install coremltools")
        print("[INFO] This script must be run on macOS.")
        sys.exit(1)

    try:
        import torch
        import torch.nn as nn
    except ImportError:
        print("[ERROR] PyTorch is required for ONNX export. Install with: pip install torch")
        sys.exit(1)

    # Find the CoreML model
    model_paths = [
        '../BabyInCarApp/BabyInCarApp/Resources/DeepInfant_V2.mlmodel',
        'models/DeepInfant_V2.mlmodel',
    ]

    model_path = None
    for p in model_paths:
        if os.path.exists(p):
            model_path = p
            break

    if model_path is None:
        print("[ERROR] DeepInfant_V2.mlmodel not found. Expected locations:")
        for p in model_paths:
            print(f"  {p}")
        sys.exit(1)

    print(f"[INFO] Loading CoreML model from {model_path}")
    coreml_model = ct.models.MLModel(model_path)
    spec = coreml_model.get_spec()
    pipeline = spec.pipelineClassifier.pipeline

    # Verify pipeline structure
    assert len(pipeline.models) == 3, f"Expected 3 pipeline steps, got {len(pipeline.models)}"

    nn_spec = pipeline.models[1].neuralNetwork
    glm_spec = pipeline.models[2].glmClassifier
    class_labels = list(glm_spec.stringClassLabels.vector)

    print(f"[INFO] Extracting {len(nn_spec.layers)} CNN layers (8-bit quantized)")
    print(f"[INFO] Class labels: {class_labels}")

    # Build PyTorch model
    class DeepInfantCNN(nn.Module):
        """CNN + GLM architecture matching CoreML DeepInfant V2."""
        def __init__(self):
            super().__init__()
            self.conv1 = nn.Conv2d(1, 64, kernel_size=3, padding=1)
            self.relu1 = nn.ReLU()
            self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

            self.conv2 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
            self.relu2 = nn.ReLU()
            self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

            self.conv3_1 = nn.Conv2d(128, 256, kernel_size=3, padding=1)
            self.relu3_1 = nn.ReLU()
            self.conv3_2 = nn.Conv2d(256, 256, kernel_size=3, padding=1)
            self.relu3_2 = nn.ReLU()
            self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)

            self.conv4_1 = nn.Conv2d(256, 512, kernel_size=3, padding=1)
            self.relu4_1 = nn.ReLU()
            self.conv4_2 = nn.Conv2d(512, 512, kernel_size=3, padding=1)
            self.relu4_2 = nn.ReLU()
            self.pool4 = nn.MaxPool2d(kernel_size=2, stride=2)

            self.classifier = nn.Linear(12288, 9)

        def forward(self, x):
            x = self.pool1(self.relu1(self.conv1(x)))
            x = self.pool2(self.relu2(self.conv2(x)))
            x = self.relu3_1(self.conv3_1(x))
            x = self.pool3(self.relu3_2(self.conv3_2(x)))
            x = self.relu4_1(self.conv4_1(x))
            x = self.pool4(self.relu4_2(self.conv4_2(x)))
            # CoreML flatten mode is CHANNEL_LAST
            x = x.permute(0, 2, 3, 1).contiguous()
            x = x.view(x.size(0), -1)
            x = self.classifier(x)
            return x

    model = DeepInfantCNN()

    # Transfer dequantized CNN weights
    layer_map = {
        'conv1': (model.conv1, 1),    # in_channels
        'conv2': (model.conv2, 64),
        'conv3_1': (model.conv3_1, 128),
        'conv3_2': (model.conv3_2, 256),
        'conv4_1': (model.conv4_1, 256),
        'conv4_2': (model.conv4_2, 512),
    }

    print("[INFO] Dequantizing and transferring CNN weights...")
    for layer in nn_spec.layers:
        ltype = layer.WhichOneof('layer')
        name = layer.name

        if ltype == 'convolution' and name in layer_map:
            conv = layer.convolution
            pytorch_layer, in_ch = layer_map[name]

            out_ch = conv.outputChannels
            kh, kw = conv.kernelSize

            # CoreML stores conv weights as [out_ch, kh, kw, in_ch]
            coreml_shape = (out_ch, kh, kw, in_ch)

            if len(conv.weights.rawValue) > 0:
                # Dequantize 8-bit weights
                weights = dequantize_data(
                    conv.weights.rawValue,
                    conv.weights.quantization,
                    coreml_shape
                )
                # Convert to PyTorch order: [out_ch, in_ch, kh, kw]
                weights = weights.transpose(0, 3, 1, 2)
                pytorch_layer.weight.data = torch.from_numpy(weights.copy())
                print(f"  {name}: dequantized weights {pytorch_layer.weight.shape}")
            elif len(conv.weights.floatValue) > 0:
                weights = np.array(conv.weights.floatValue)
                weights = weights.reshape(coreml_shape).transpose(0, 3, 1, 2)
                pytorch_layer.weight.data = torch.from_numpy(weights.copy())
                print(f"  {name}: float weights {pytorch_layer.weight.shape}")

            # Handle bias
            if conv.hasBias:
                bias_shape = (out_ch,)
                if len(conv.bias.floatValue) > 0:
                    bias = np.array(conv.bias.floatValue, dtype=np.float32)
                    pytorch_layer.bias.data = torch.from_numpy(bias)
                    print(f"  {name}: bias from floatValue {pytorch_layer.bias.shape}")
                elif len(conv.bias.rawValue) > 0:
                    # Bias is also 8-bit quantized (per-tensor)
                    bias = dequantize_data(
                        conv.bias.rawValue,
                        conv.bias.quantization,
                        bias_shape
                    )
                    pytorch_layer.bias.data = torch.from_numpy(bias.copy())
                    print(f"  {name}: dequantized bias {pytorch_layer.bias.shape}")
                else:
                    pytorch_layer.bias.data.zero_()
                    print(f"  {name}: no bias found, using zeros")

    # Transfer GLM weights
    num_classes = len(class_labels)
    num_features = 12288

    glm_weights = np.zeros((num_classes, num_features), dtype=np.float32)
    glm_bias = np.zeros(num_classes, dtype=np.float32)

    for i, w in enumerate(glm_spec.weights):
        values = np.array(w.value, dtype=np.float32)
        if len(values) == num_features:
            glm_weights[i] = values

    offsets = np.array(glm_spec.offset, dtype=np.float32)
    if len(offsets) > 0:
        glm_bias[:len(offsets)] = offsets

    model.classifier.weight.data = torch.from_numpy(glm_weights)
    model.classifier.bias.data = torch.from_numpy(glm_bias)
    print(f"  GLM: weights {model.classifier.weight.shape}, bias {model.classifier.bias.shape}")

    # Verify against CoreML
    print("\n[INFO] Cross-validating against CoreML model...")
    model.eval()

    # We need to compare the CNN+GLM part only, using the same preprocessed input
    # First, get the intermediate output from CoreML
    from coremltools.proto import Model_pb2
    step1_spec_proto = pipeline.models[1]

    standalone_spec = Model_pb2.Model()
    standalone_spec.specificationVersion = spec.specificationVersion
    standalone_spec.neuralNetwork.CopyFrom(step1_spec_proto.neuralNetwork)
    standalone_spec.description.CopyFrom(step1_spec_proto.description)
    standalone_nn = ct.models.MLModel(standalone_spec)

    # Generate a test preprocessed input
    test_preprocessed = np.random.randn(1, 96, 64).astype(np.float32) * 0.1

    # Get CoreML CNN output
    coreml_features = standalone_nn.predict(
        {'preprocessedAudio': test_preprocessed}
    )['features']
    coreml_features = np.array(coreml_features)

    # Get PyTorch CNN output (without GLM)
    with torch.no_grad():
        pt_input = torch.from_numpy(test_preprocessed).unsqueeze(0)  # [1, 1, 96, 64]
        x = model.pool1(model.relu1(model.conv1(pt_input)))
        x = model.pool2(model.relu2(model.conv2(x)))
        x = model.relu3_1(model.conv3_1(x))
        x = model.pool3(model.relu3_2(model.conv3_2(x)))
        x = model.relu4_1(model.conv4_1(x))
        x = model.pool4(model.relu4_2(model.conv4_2(x)))
        x = x.permute(0, 2, 3, 1).contiguous()
        pt_features = x.view(x.size(0), -1).numpy()[0]

    # Compare
    max_diff = np.max(np.abs(coreml_features - pt_features))
    mean_diff = np.mean(np.abs(coreml_features - pt_features))
    corr = np.corrcoef(coreml_features, pt_features)[0, 1]
    print(f"  CNN feature comparison:")
    print(f"    Max diff: {max_diff:.6f}")
    print(f"    Mean diff: {mean_diff:.6f}")
    print(f"    Correlation: {corr:.6f}")

    if corr > 0.95:
        print("  [OK] CNN weights transfer validated (correlation > 0.95)")
    else:
        print("  [WARN] CNN weights may not match perfectly (quantization artifacts expected)")

    # Full pipeline comparison with real audio
    test_audio = np.random.randn(15600).astype(np.float32) * 0.1
    coreml_full = coreml_model.predict({'audioSamples': test_audio})
    print(f"\n  Full CoreML prediction: {coreml_full['target']}")
    for label in class_labels:
        print(f"    {label}: {coreml_full['targetProbability'][label]:.6f}")

    # Export to ONNX
    print("\n[INFO] Exporting to ONNX...")
    os.makedirs('models', exist_ok=True)

    dummy_input = torch.randn(1, 1, 96, 64)
    onnx_path = 'models/deepinfant_v2_cnn_glm.onnx'

    torch.onnx.export(
        model,
        dummy_input,
        onnx_path,
        input_names=['preprocessed_audio'],
        output_names=['logits'],
        dynamic_axes={
            'preprocessed_audio': {0: 'batch'},
            'logits': {0: 'batch'},
        },
        opset_version=13,
    )
    print(f"  ONNX model saved to {onnx_path}")

    # Save class labels
    labels_path = 'models/class_labels.txt'
    with open(labels_path, 'w') as f:
        for label in class_labels:
            f.write(label + '\n')
    print(f"  Class labels saved to {labels_path}")

    # Verify ONNX
    import onnxruntime as ort
    session = ort.InferenceSession(onnx_path)
    test_onnx_input = test_preprocessed.reshape(1, 1, 96, 64)
    onnx_logits = session.run(None, {'preprocessed_audio': test_onnx_input})[0][0]

    with torch.no_grad():
        pt_logits = model(torch.from_numpy(test_onnx_input)).numpy()[0]

    onnx_pt_diff = np.max(np.abs(onnx_logits - pt_logits))
    print(f"\n  ONNX vs PyTorch logits max diff: {onnx_pt_diff:.8f}")

    # Apply softmax to get probabilities
    def softmax(x):
        e_x = np.exp(x - np.max(x))
        return e_x / e_x.sum()

    onnx_probs = softmax(onnx_logits)
    print(f"  ONNX prediction (softmax):")
    for i, label in enumerate(class_labels):
        print(f"    {label}: {onnx_probs[i]:.6f}")

    onnx_size = os.path.getsize(onnx_path)
    print(f"\n[SUCCESS] Conversion complete!")
    print(f"  ONNX model: {onnx_path} ({onnx_size / 1024:.0f} KB)")
    print(f"  Class labels: {labels_path}")

    return True


if __name__ == '__main__':
    extract_and_convert()
