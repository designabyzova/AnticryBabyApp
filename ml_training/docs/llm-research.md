# LLM Research: CoreML-Compatible Models for Voice Command Classification

**Date**: 2026-01-04
**Purpose**: Evaluate on-device LLM options for Lulla voice command parsing
**Requirement**: Model must run on iOS via CoreML, classify 150 command intents, achieve >90% accuracy

---

## Executive Summary

After evaluating 4 CoreML-compatible models, **DistilBERT** is recommended for Lulla voice command classification based on the best balance of accuracy, size, and conversion maturity.

**Recommended Model**: DistilBERT (distilbert-base-uncased)
- **Size**: ~30MB (INT8 quantized)
- **Latency**: 200-400ms (estimated on iPhone 12+)
- **Accuracy**: 90-92% (expected on Lulla commands after fine-tuning)
- **Rationale**: Best trade-off between accuracy and size, well-documented CoreML conversion, strong community support

---

## Model Evaluations

### 1. DistilBERT (distilbert-base-uncased)

**Source**: Hugging Face (https://huggingface.co/distilbert-base-uncased)

**Architecture**:
- 6-layer Transformer encoder (vs 12 for BERT)
- 66M parameters
- Knowledge distillation from BERT-base
- Retains 97% of BERT's language understanding

**Size**:
- FP32: ~270MB
- FP16: ~135MB
- INT8 (quantized): ~70MB
- **Target for iOS**: 30-40MB with aggressive quantization

**Latency (estimated)**:
- iPhone 13 (A15, Neural Engine): 100-200ms
- iPhone 12 (A14, Neural Engine): 200-300ms
- iPhone 11 (A13, no Neural Engine): 400-600ms (fallback needed)

**CoreML Conversion**:
- ✅ **Excellent support**: coremltools 7.0+ has built-in Transformers conversion
- ✅ Hugging Face → ONNX → CoreML pipeline is well-documented
- ✅ Community examples available for iOS deployment
- ✅ Supports INT8 quantization via coremltools

**License**: Apache 2.0 (commercial use allowed)

**Fine-Tuning**:
- Easy to fine-tune on custom datasets
- Standard Hugging Face Trainer API
- Fast convergence (3-5 epochs typical)
- Works well with 1,000+ training examples

**Pros**:
- 40% smaller than BERT, 60% faster
- High accuracy retention (97% of BERT)
- Excellent CoreML conversion support
- Well-documented, large community
- Good balance of speed and accuracy

**Cons**:
- Still relatively large (~30-40MB after quantization)
- Requires Neural Engine for <300ms latency
- May need fallback for iPhone 11 and older

**Use Case Fit**: **Excellent** for Lulla command classification
- Can handle natural language variations
- Multi-class classification is a core use case
- Fine-tuning on 3,000 examples should achieve >92% accuracy

---

### 2. MobileBERT (google/mobilebert-uncased)

**Source**: Hugging Face (https://huggingface.co/google/mobilebert-uncased)

**Architecture**:
- 24-layer inverted bottleneck structure
- 25M parameters (smaller than DistilBERT)
- Optimized for mobile deployment
- Designed specifically for edge devices

**Size**:
- FP32: ~100MB
- FP16: ~50MB
- INT8 (quantized): ~25MB
- **Target for iOS**: 20-30MB

**Latency (estimated)**:
- iPhone 13 (A15): 50-150ms
- iPhone 12 (A14): 100-200ms
- iPhone 11 (A13): 200-400ms (better than DistilBERT on older devices)

**CoreML Conversion**:
- ✅ **Good support**: Can convert via ONNX → CoreML
- ⚠️ Less documented than DistilBERT
- ✅ Quantization works well
- ⚠️ Fewer community examples for iOS

**License**: Apache 2.0

**Fine-Tuning**:
- Standard Hugging Face fine-tuning
- May require more epochs than DistilBERT (architecture difference)
- Slightly lower accuracy on some benchmarks

**Pros**:
- Smaller size than DistilBERT (~25MB vs ~30MB)
- Faster inference (optimized for mobile)
- Better performance on older devices without Neural Engine
- Lower memory footprint

**Cons**:
- Slightly lower accuracy than DistilBERT (~1-2% drop)
- Less mature CoreML conversion pipeline
- Fewer community resources
- May require more training data to match DistilBERT accuracy

**Use Case Fit**: **Very Good** for Lulla commands
- Best choice if latency <200ms is critical
- Good for supporting iPhone 11 and older
- May sacrifice 1-2% accuracy vs DistilBERT

---

### 3. TinyBERT (huawei-noah/TinyBERT_General_4L_312D)

**Source**: Hugging Face (https://huggingface.co/huawei-noah/TinyBERT_General_4L_312D)

**Architecture**:
- 4-layer Transformer
- 14.5M parameters
- Aggressive knowledge distillation
- 4.4x smaller than BERT-base

**Size**:
- FP32: ~60MB
- FP16: ~30MB
- INT8 (quantized): ~15MB
- **Target for iOS**: 10-20MB

**Latency (estimated)**:
- iPhone 13: 30-100ms
- iPhone 12: 50-150ms
- iPhone 11: 100-300ms

**CoreML Conversion**:
- ⚠️ **Moderate support**: ONNX conversion works but less tested
- ⚠️ Limited community examples for iOS
- ✅ Small size makes conversion easier

**License**: Apache 2.0

**Fine-Tuning**:
- Standard fine-tuning process
- May require more data to compensate for smaller capacity
- Risk of underfitting on complex tasks

**Pros**:
- Smallest model (10-20MB)
- Fastest inference (30-100ms)
- Minimal memory footprint
- Works well on older devices

**Cons**:
- Lower accuracy than DistilBERT (~3-5% drop expected)
- May struggle with natural language variations
- Less community support
- Higher risk of underfitting

**Use Case Fit**: **Good** for simple command classification
- Best for strict latency requirements (<100ms)
- May sacrifice accuracy for speed
- Risk: 150 intent classes may be challenging for such a small model

---

### 4. GPT-2 Distilled (distilgpt2)

**Source**: Hugging Face (https://huggingface.co/distilgpt2)

**Architecture**:
- 6-layer decoder-only Transformer
- 82M parameters
- Generative model (not classification)
- Knowledge distillation from GPT-2

**Size**:
- FP32: ~320MB
- FP16: ~160MB
- INT8 (quantized): ~80MB
- **Target for iOS**: 40-50MB

**Latency (estimated)**:
- iPhone 13: 200-400ms
- iPhone 12: 300-500ms
- iPhone 11: 500-800ms (too slow)

**CoreML Conversion**:
- ⚠️ **Challenging**: Decoder architecture is harder to convert
- ⚠️ Generative models less optimized for classification
- ⚠️ Requires custom classification head

**License**: MIT

**Fine-Tuning**:
- Requires adding classification head
- More complex training setup
- Generative bias may not fit classification task

**Pros**:
- Best natural language understanding
- Can handle complex, verbose commands
- Good at capturing context

**Cons**:
- Largest model (~40-50MB)
- Slowest inference (300-500ms)
- Over-engineered for classification
- Complex CoreML conversion
- Not designed for classification tasks

**Use Case Fit**: **Poor** for Lulla commands
- Overkill for command classification
- Size and latency penalties not justified
- Simpler encoder models (BERT family) are better suited

---

## Comparison Table

| Model | Size (INT8) | Latency (p95) | Accuracy (est.) | CoreML Support | Complexity | Recommendation |
|-------|-------------|---------------|-----------------|----------------|------------|----------------|
| **DistilBERT** | ~30MB | 200-400ms | 90-92% | ✅ Excellent | Medium | ⭐ **Recommended** |
| **MobileBERT** | ~25MB | 100-300ms | 88-90% | ✅ Good | Medium | Alternative (speed) |
| **TinyBERT** | ~15MB | 50-200ms | 85-88% | ⚠️ Moderate | Low | Fallback (size) |
| **GPT-2 Distilled** | ~45MB | 300-600ms | 92%+ | ⚠️ Challenging | High | ❌ Not recommended |

---

## Final Recommendation: DistilBERT

### Why DistilBERT?

1. **Best Accuracy/Size Trade-off**: 90-92% expected accuracy with ~30MB size
2. **Proven CoreML Conversion**: Mature tooling, extensive documentation
3. **Strong Fine-Tuning**: Works well with 1,000-3,000 training examples
4. **Community Support**: Large ecosystem, many iOS deployment examples
5. **Meets Requirements**: <50MB size, <500ms latency, >90% accuracy

### Conversion Strategy

```python
# Fine-tune on Lulla commands
from transformers import DistilBertForSequenceClassification, Trainer

model = DistilBertForSequenceClassification.from_pretrained(
    "distilbert-base-uncased",
    num_labels=150  # Lulla command intents
)

# Fine-tune on 3,000 Lulla examples
trainer = Trainer(model=model, args=training_args, train_dataset=train_data)
trainer.train()

# Convert to CoreML
import coremltools as ct
from transformers.convert_graph_to_onnx import convert

# PyTorch → ONNX → CoreML
onnx_path = convert(framework="pt", model=model, output="model.onnx")
coreml_model = ct.converters.onnx.convert(
    model=onnx_path,
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16  # Then quantize to INT8
)
coreml_model.save("LullaVoiceCommand.mlpackage")
```

### Quantization Plan

1. **Initial**: FP16 model (~135MB) for testing
2. **Optimize**: INT8 quantization (~35MB) if latency acceptable
3. **Aggressive**: Further pruning to reach ~30MB if needed

### Fallback Strategy

If latency >500ms on iPhone 12:
1. Try MobileBERT as alternative (faster, slightly less accurate)
2. Implement rule-based parser for iPhone 11 and older
3. Use model size as a feature flag (download on-demand for older devices)

---

## Next Steps

1. ✅ **Research complete**: DistilBERT selected
2. **T-002**: Set up evaluation framework with DistilBERT
3. **T-003**: Benchmark DistilBERT on 300 Lulla test commands
4. **US-002**: Create 3,000-example training dataset
5. **US-003**: Fine-tune DistilBERT on Lulla commands
6. **US-003**: Convert to CoreML and validate on device

---

## References

- DistilBERT paper: https://arxiv.org/abs/1910.01108
- MobileBERT paper: https://arxiv.org/abs/2004.02984
- TinyBERT paper: https://arxiv.org/abs/1909.10351
- CoreML Transformers: https://coremltools.readme.io/docs/transformers
- Hugging Face iOS: https://huggingface.co/docs/transformers/serialization#coreml

---

**License Compatibility**: All models use Apache 2.0 or MIT licenses, allowing commercial use in Lulla app.

**Cost**: $0 (all models are open-source, on-device inference)

**Decision Date**: 2026-01-04
**Decision**: DistilBERT (distilbert-base-uncased) with INT8 quantization
