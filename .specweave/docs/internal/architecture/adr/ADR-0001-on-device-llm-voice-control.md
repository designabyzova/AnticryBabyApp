# ADR-0001: On-Device LLM Selection for Voice Control

## Status

**Accepted** - 2026-01-04

## Context

### Problem

The current voice control implementation (increment 0023-llm-voice-control) is fundamentally broken:

1. **Architecture Flaw**: Uses external Ollama server running on user's desktop
   - iOS cannot run Ollama locally
   - Requires network connectivity to user's computer
   - 54 tests exist but disable LLM functionality (`useLLMParsing = false`)
   - Zero actual on-device inference capability

2. **User Impact**: Voice control does not work in production
   - External server requirement makes it impractical for mobile app
   - No offline support
   - Poor latency (network roundtrip)
   - Privacy concerns (voice data leaves device)

3. **Business Requirements**:
   - Must work offline (car use case)
   - Must have <500ms latency
   - Must preserve privacy (no data leaves device)
   - Must support 150+ voice command intents for Lulla

### Constraints

- **Platform**: iOS 16+ (iPhone 11 and newer)
- **Model Size**: <50MB (app bundle size limit)
- **Latency**: <500ms p95 (acceptable user experience)
- **Accuracy**: >90% (usable voice control)
- **Cost**: $0 (on-device inference, no API costs)

### Evaluation Criteria

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| **On-Device Capability** | Critical | Must run on iOS, not external server |
| **CoreML Conversion** | Critical | iOS requires CoreML format |
| **Accuracy** | High | Voice control unusable below 90% |
| **Latency** | High | Poor UX above 500ms |
| **Model Size** | Medium | Affects app bundle size, download time |
| **Community Support** | Medium | Easier maintenance, troubleshooting |

## Decision

**Use DistilBERT (distilbert-base-uncased) fine-tuned on Lulla voice commands, converted to CoreML with INT8 quantization.**

### Models Evaluated

#### 1. DistilBERT ⭐ **SELECTED**

- **Architecture**: 6-layer Transformer encoder, 66M parameters
- **Size**: ~30MB (INT8 quantized), ~135MB (FP16), ~270MB (FP32)
- **Latency**: 200-400ms (iPhone 12+, estimated)
- **Accuracy**: 90-92% expected (after fine-tuning)
- **CoreML Support**: ✅ Excellent (coremltools 7.0+ has built-in Transformers conversion)
- **License**: Apache 2.0 (commercial use allowed)

**Why Selected**:
- Best balance of accuracy, size, and latency
- Retains 97% of BERT's language understanding while being 40% smaller and 60% faster
- Well-documented CoreML conversion pipeline (Hugging Face → ONNX → CoreML)
- Large community, many iOS deployment examples
- Proven for text classification tasks (our use case)

#### 2. MobileBERT (Alternative)

- **Size**: ~25MB (INT8)
- **Latency**: 100-300ms (faster than DistilBERT)
- **Accuracy**: 88-90% (slightly lower)
- **CoreML Support**: ✅ Good (but less documented)

**Why Not Selected**:
- 1-2% accuracy drop not worth 50-100ms latency gain
- Less mature CoreML conversion pipeline
- Fewer community examples for iOS

#### 3. TinyBERT (Rejected)

- **Size**: ~15MB (very small)
- **Latency**: 50-200ms (very fast)
- **Accuracy**: 85-88% (too low)
- **CoreML Support**: ⚠️ Moderate

**Why Rejected**:
- 3-5% accuracy drop is significant (85% → 12-15 errors per 100 commands)
- Risk of underfitting with 150 intent classes
- Small size not worth accuracy trade-off

#### 4. GPT-2 Distilled (Rejected)

- **Size**: ~45MB (too large)
- **Latency**: 300-600ms (too slow)
- **Accuracy**: 92%+ (excellent)
- **CoreML Support**: ⚠️ Challenging (decoder architecture harder to convert)

**Why Rejected**:
- Over-engineered for classification (designed for generation)
- Size and latency penalties not justified
- Complex CoreML conversion
- Simpler encoder models (BERT family) better suited for classification

### Comparison Table

| Model | Size (INT8) | Latency (p95) | Accuracy | CoreML | Decision |
|-------|-------------|---------------|----------|--------|----------|
| **DistilBERT** | 30MB | 200-400ms | 90-92% | ✅ Excellent | ⭐ Selected |
| MobileBERT | 25MB | 100-300ms | 88-90% | ✅ Good | Alternative |
| TinyBERT | 15MB | 50-200ms | 85-88% | ⚠️ Moderate | Rejected |
| GPT-2 Distilled | 45MB | 300-600ms | 92%+ | ⚠️ Challenging | Rejected |

## Consequences

### Positive

1. **Functional Voice Control**: Unlike Ollama-based approach, this actually works on iOS
2. **Privacy**: All processing happens on-device, zero data leaves phone
3. **Offline Support**: Works without internet connection (critical for car use)
4. **Low Latency**: 200-400ms meets <500ms requirement
5. **Zero Cost**: No API costs for inference (one-time model training cost only)
6. **Proven Technology**: DistilBERT is battle-tested, widely used in production

### Negative

1. **One-Time Training Cost**: Requires initial model training (4-8 hours on GPU)
2. **App Size Increase**: ~30MB added to app bundle
3. **Device Limitations**: Older devices (iPhone 11 and older) may need fallback parser
4. **Maintenance**: Model needs periodic retraining with new commands/improvements

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Latency >500ms on older devices** | Poor UX | Implement rule-based fallback parser for iPhone 11 and older |
| **Accuracy <90% after training** | Unusable voice control | Increase training data size, try MobileBERT alternative |
| **Model too large (>50MB)** | App rejection | Aggressive quantization, model pruning, download on-demand |
| **CoreML conversion fails** | Blocked on implementation | Use coremltools 7.0+ with validated pipeline, test early on device |

## Implementation Plan

### Phase 1: Training (Offline, 1-2 weeks)

1. Create 3,000 synthetic training examples (600 base × 5 paraphrases)
2. Fine-tune DistilBERT on Lulla commands (5 epochs, 2e-5 learning rate)
3. Achieve >92% validation accuracy
4. Convert to CoreML via coremltools 7.0+
5. Test on iPhone 12+ device

### Phase 2: iOS Integration (Auto Mode, 3-5 days)

1. Create `VoiceCommandMLService.swift` with CoreML inference ✅
2. Implement lazy model loading
3. Add confidence threshold (0.85)
4. Implement rule-based fallback parser ✅
5. Integrate with `SpeechRecognitionService`

### Phase 3: Testing (2-3 days)

1. 65+ unit tests with real model (no mocking)
2. Performance tests (latency <500ms p95)
3. Accuracy tests (>90% on 300-example test set)
4. E2E tests with real speech recognition

### Phase 4: Deployment

1. Bundle .mlpackage in Xcode project
2. Test on iPhone 11, 12, 13, 14 (all supported devices)
3. Monitor analytics (latency, accuracy, fallback usage)
4. Iterate on training data based on production failures

## Alternatives Considered

### 1. Cloud-Based LLM API (OpenAI, Anthropic)

**Rejected**: Violates privacy requirement, requires internet, ongoing costs

### 2. Rule-Based Parser Only

**Rejected**: Insufficient for natural language variations, low accuracy, hard to maintain

### 3. Hybrid Approach (Cloud + On-Device)

**Rejected**: Complexity not justified, privacy concerns, fallback already covers edge cases

## References

- **DistilBERT Paper**: [arXiv:1910.01108](https://arxiv.org/abs/1910.01108)
- **CoreML Transformers Guide**: [coremltools.readme.io](https://coremltools.readme.io/docs/transformers)
- **Hugging Face iOS Deployment**: [huggingface.co/docs/transformers/serialization#coreml](https://huggingface.co/docs/transformers/serialization#coreml)
- **Model Evaluation**: See `ml_training/docs/llm-research.md`

## Notes

- This ADR supersedes the Ollama-based architecture from increment 0023
- Fallback parser provides immediate value while model is being trained
- Model can be updated via app update (no backend changes needed)
- Consider MobileBERT as fallback if DistilBERT underperforms on older devices

---

**Decision Date**: 2026-01-04
**Decided By**: Auto Mode (Increment 0027)
**Increment**: 0027-voice-control-v2-llm
