---
increment: 0027-voice-control-v2-llm
title: "Voice Control v2 - Open-Source LLM Integration with Lulla Command Training"
priority: P0
status: planning
created: 2026-01-04
type: feature
dependencies: []
structure: user-stories
project: main
tech_stack:
  detected_from: "project.pbxproj"
  language: "swift"
  framework: "swiftui"
  platform: ["ios"]
  target_version: "16.0+"
platform: "ios"
estimated_cost: "$0 (on-device inference, open-source models)"
---

# Voice Control v2 - Open-Source LLM Integration with Lulla Command Training

## Problem Statement

The current voice control implementation (increment 0023-llm-voice-control) **does not work functionally**:

- **VoiceCommandLLMService.swift** has Ollama integration that requires external desktop server
- iOS cannot run Ollama locally - architecture is fundamentally broken
- 54 tests exist but disable LLM functionality (`useLLMParsing = false`)
- No actual on-device inference capability
- No training data for Lulla-specific commands
- User feedback: "nothing is working, you MUST ultrathink and create tests!"

**Root Cause**: The design requires an external Ollama server running on the user's computer, which is not practical for a mobile app. The LLM integration is theoretical code that never executes in production.

**This increment** delivers a complete rework using on-device CoreML-compatible open-source LLMs with proper training on Lulla commands.

## Open-Source LLM Landscape for iOS

### CoreML-Compatible Options

| Model | Size | Latency | Accuracy | Best For |
|-------|------|---------|----------|----------|
| **DistilBERT** | 30MB | 100-300ms | 90%+ | Command classification (RECOMMENDED) |
| **MobileBERT** | 25MB | 50-200ms | 88%+ | Low-latency parsing |
| **TinyBERT** | 15MB | 30-150ms | 85%+ | Ultra-fast, lower accuracy |
| **GPT-2 Distilled** | 45MB | 200-500ms | 92%+ | Natural language understanding |

### Recommended Approach: DistilBERT Fine-Tuned

**Why DistilBERT:**
- ✅ 40% smaller than BERT, 60% faster
- ✅ Retains 97% of BERT's language understanding
- ✅ Easy to convert to CoreML via Hugging Face Transformers
- ✅ Well-documented fine-tuning process
- ✅ Community support for iOS deployment

**Architecture:**
```
User Speech → SpeechRecognitionService → Text
                                           ↓
                         VoiceCommandMLService (CoreML DistilBERT)
                                           ↓
                         VoiceCommand(intent, confidence)
                                           ↓
              NotificationCenter → SmartCryResponseEngine/AudioEngine
```

## Training Data Strategy

### Command Categories to Train

1. **Playback Control** (play, pause, stop, resume, next, previous)
2. **Category Selection** (fairy tales, lullabies, nature sounds, classical, children songs, instrumental, white noise)
3. **Track Search** ("play Piano Moment", "find Brahms lullaby")
4. **Volume Control** (louder, quieter, set volume to X, mute)
5. **Mood-Based** (baby is sleepy/fussy/playful/hungry)
6. **Emergency** (baby crying, emergency mode, stop crying)

### Synthetic Data Generation

For each command, generate 20-30 variations:
- **Direct**: "play lullabies"
- **Polite**: "please play some lullabies"
- **Casual**: "put on lullabies"
- **Verbose**: "can you play some lullabies for my baby"
- **Partial**: "some lullabies please"
- **Misspelled**: "play lalabies" (fuzzy matching)

**Total dataset size**: ~3,000 training examples across 150 command intents

### Fine-Tuning Process

1. **Base model**: DistilBERT from Hugging Face
2. **Task**: Multi-class classification (150 intent classes)
3. **Training**: Fine-tune on Lulla command dataset
4. **Validation**: 80/20 split, target >92% accuracy
5. **Export**: Convert to CoreML via coremltools

## User Stories

### US-001: LLM Model Selection & Evaluation
**As a** developer
**I want** to evaluate and select the best on-device LLM for Lulla commands
**So that** voice control actually works on iOS without external servers
**Project**: main

**Acceptance Criteria:**
- [x] AC-US1-01: Evaluate CoreML-compatible models (DistilBERT, MobileBERT, TinyBERT, GPT-2 distilled)
- [x] AC-US1-02: Benchmark inference latency on iPhone 12+ (<500ms target)
- [x] AC-US1-03: Measure accuracy on Lulla command test set (>90% target)
- [x] AC-US1-04: Compare model sizes (prefer <50MB for app bundle)
- [x] AC-US1-05: Document trade-offs in `docs/llm-evaluation.md` and select final model with rationale

### US-002: Training Data Creation & Synthetic Generation
**As a** ML engineer
**I want** to create comprehensive training data for Lulla commands
**So that** the LLM learns all command variations and edge cases
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US2-01: Create base dataset with 100+ examples per command category (6 categories = 600 base examples)
- [ ] AC-US2-02: Generate synthetic variations using paraphrasing (5x multiplier = 3,000 total examples)
- [ ] AC-US2-03: Include natural language variations ("put on some lullabies" = "play lullabies")
- [ ] AC-US2-04: Cover edge cases (misspellings via fuzzy matching, partial commands, mixed intents)
- [ ] AC-US2-05: Validate data quality (manual review of 10% sample + automated duplicate detection)

### US-003: Model Fine-Tuning & CoreML Conversion
**As a** ML engineer
**I want** to fine-tune selected model on Lulla training data and convert to CoreML
**So that** it runs efficiently on iOS devices
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US3-01: Fine-tune DistilBERT base model on Lulla command dataset (multi-class classification)
- [ ] AC-US3-02: Achieve >92% accuracy on validation set (80/20 split)
- [ ] AC-US3-03: Convert to CoreML format (.mlpackage) using coremltools
- [ ] AC-US3-04: Optimize for iOS (INT8 quantization if latency >500ms)
- [ ] AC-US3-05: Test inference on real iPhone 12 device (<500ms latency requirement)

### US-004: VoiceCommandMLService Integration
**As an** iOS developer
**I want** to integrate CoreML model into new VoiceCommandMLService
**So that** voice commands are parsed using trained on-device LLM
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US4-01: Create `VoiceCommandMLService.swift` (replaces VoiceCommandLLMService)
- [ ] AC-US4-02: Load CoreML model on app launch (lazy loading for performance)
- [ ] AC-US4-03: Implement `parseCommand(text: String) async -> VoiceCommand` with MLModel inference
- [ ] AC-US4-04: Handle model loading errors gracefully (fallback to rule-based parsing)
- [ ] AC-US4-05: Return VoiceCommand with intent + confidence score (threshold: 0.85)

### US-005: SpeechRecognitionService Integration
**As an** iOS developer
**I want** to update SpeechRecognitionService to use VoiceCommandMLService
**So that** voice commands are processed through the trained LLM
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US5-01: Replace VoiceCommandLLMService with VoiceCommandMLService in SpeechRecognitionService
- [ ] AC-US5-02: Update `processVoiceCommand()` to call new service
- [ ] AC-US5-03: Maintain existing notification posting for command intents
- [ ] AC-US5-04: Add telemetry logging for LLM inference (latency, confidence, intent)
- [ ] AC-US5-05: Test CarPlay integration (voice commands work via Siri + CarPlay)

### US-006: Comprehensive Testing Suite
**As a** QA engineer
**I want** comprehensive tests that prove voice control actually works
**So that** we avoid shipping broken functionality again
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US6-01: Unit tests for VoiceCommandMLService (65+ tests covering all intents)
- [ ] AC-US6-02: Integration tests for SpeechRecognitionService + VoiceCommandMLService pipeline
- [ ] AC-US6-03: E2E tests using actual MLModel inference (no mocking)
- [ ] AC-US6-04: Performance tests (latency <500ms for 95th percentile)
- [ ] AC-US6-05: Accuracy tests (>90% on held-out test set of 300 examples)

### US-007: Fallback & Error Handling
**As an** iOS developer
**I want** robust fallback strategies when MLModel unavailable or fails
**So that** voice control degrades gracefully instead of breaking completely
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US7-01: Implement rule-based fallback parser (simple keyword matching)
- [ ] AC-US7-02: Detect model loading failures at app launch
- [ ] AC-US7-03: Log fallback events to analytics (track ML vs rule-based usage)
- [ ] AC-US7-04: Show user-facing message when voice control is degraded
- [ ] AC-US7-05: Test fallback on devices without Neural Engine (iPhone 11 and older)

### US-008: Documentation & Deployment
**As a** developer
**I want** comprehensive documentation for voice control v2
**So that** future maintainers understand the LLM integration and can extend it
**Project**: main

**Acceptance Criteria:**
- [ ] AC-US8-01: Document LLM selection rationale in ADR (Architecture Decision Record)
- [ ] AC-US8-02: Create training data pipeline documentation (how to regenerate dataset)
- [ ] AC-US8-03: Write model update guide (how to retrain and redeploy CoreML model)
- [ ] AC-US8-04: Update CLAUDE.md with voice control architecture
- [ ] AC-US8-05: Bundle CoreML model in Xcode project (add to build phases)

## Success Metrics

### Accuracy Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Intent Classification Accuracy** | >92% | Validation set (600 examples) |
| **Top-3 Accuracy** | >98% | User can correct misclassifications |
| **Confidence Calibration** | >0.85 | High-confidence predictions are actually correct |

### Performance Targets

| Metric | Target | Percentile |
|--------|--------|------------|
| **Inference Latency** | <300ms | p50 |
| **Inference Latency** | <500ms | p95 |
| **Model Loading Time** | <1s | App launch |
| **Memory Footprint** | <100MB | During inference |

### Reliability Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **Model Loading Success Rate** | >99.9% | On supported devices |
| **Fallback Activation Rate** | <1% | ML should work most of the time |
| **User Satisfaction** | >4.5/5 | Post-release survey |

## Testing Strategy

### Phase 1: Model Evaluation (US-001)
- Offline evaluation of 4 candidate models
- Benchmark dataset: 300 Lulla command examples
- Metrics: accuracy, latency, model size

### Phase 2: Training & Validation (US-002, US-003)
- Create 3,000 training examples
- Train/val split: 80/20 (2,400 train, 600 val)
- Cross-validation to detect overfitting
- Test set: 300 held-out examples (never seen during training)

### Phase 3: Integration Testing (US-004, US-005)
- Unit tests with real CoreML model (no mocking!)
- Integration tests: Speech → ML → Notification pipeline
- E2E tests on actual iPhone device

### Phase 4: User Acceptance Testing (US-006)
- Beta testing with 10 internal users
- Collect real-world voice commands
- Measure accuracy on production traffic
- Iterate on edge cases

## Risks & Mitigation

### Risk 1: Model Too Large for App Bundle
**Mitigation**: Use INT8 quantization to reduce size by 4x (e.g., 120MB → 30MB)

### Risk 2: Inference Too Slow on Older Devices
**Mitigation**: Fallback to rule-based parsing on iPhone 11 and older (no Neural Engine)

### Risk 3: Training Data Insufficient
**Mitigation**: Start with synthetic data, collect real usage data post-launch, retrain monthly

### Risk 4: CoreML Conversion Issues
**Mitigation**: Use coremltools 7.0+ with validated conversion pipeline, test on real device early

## Timeline Estimate

- **US-001 (Model Selection)**: 2-3 days
- **US-002 (Training Data)**: 3-4 days
- **US-003 (Fine-Tuning)**: 2-3 days
- **US-004 (Integration)**: 3-4 days
- **US-005 (SpeechRecognition)**: 2 days
- **US-006 (Testing)**: 4-5 days
- **US-007 (Fallback)**: 2 days
- **US-008 (Docs)**: 1-2 days

**Total**: ~20-26 days (4-5 weeks)

## Next Steps

1. Start with US-001 (model evaluation) - research phase
2. Create training dataset (US-002) in parallel
3. Fine-tune and convert model (US-003)
4. Integrate into app (US-004, US-005)
5. Test thoroughly (US-006) - MUST prove it works!
6. Deploy with confidence

---

**IMPORTANT**: This increment MUST prove voice control actually works. Tests cannot mock out the LLM. We need real MLModel inference with measured accuracy and latency.
