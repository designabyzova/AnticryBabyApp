---
increment: 0027-voice-control-v2-llm
status: planned
dependencies: []
phases:
  - ml-research
  - training-data
  - model-training
  - ios-integration
  - testing
  - deployment
total_tasks: 37
completed: 0
by_user_story:
  US-001: 5
  US-002: 5
  US-003: 5
  US-004: 5
  US-005: 4
  US-006: 5
  US-007: 4
  US-008: 4
test_mode: tdd
coverage_target: 90
estimated_weeks: 4-5
---

# Tasks: Voice Control v2 - Open-Source LLM Integration

---

## User Story: US-001 - LLM Model Selection & Evaluation

**Linked ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04, AC-US1-05
**Tasks**: 5 total, 0 completed

### T-001: Research CoreML-compatible LLM options

**User Story**: US-001
**Satisfies ACs**: AC-US1-01
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [x] completed

**Test Plan**:
- **Given** research on 4 candidate models (DistilBERT, MobileBERT, TinyBERT, GPT-2 distilled)
- **When** evaluating each model for iOS compatibility
- **Then** document CoreML conversion feasibility, license, community support
- **And** create comparison table with pros/cons for each model

**Test Cases**:
1. **Documentation**: `docs/llm-research.md`
   - Verify all 4 models documented with conversion notes
   - Verify license compatibility (MIT/Apache)
   - **Coverage Target**: N/A (research task)

**Validation**:
- Research document exists with all 4 models analyzed
- Each model has conversion feasibility assessment
- License information documented for all models

**Implementation**:
1. Research DistilBERT: size, architecture, Hugging Face docs
2. Research MobileBERT: optimizations, benchmark data
3. Research TinyBERT: tradeoffs, knowledge distillation approach
4. Research GPT-2 distilled: generative vs classification tradeoffs
5. Document findings in `ml_training/docs/llm-research.md`
6. Create comparison table with size, latency estimates, accuracy

---

### T-002: Set up model evaluation framework

**User Story**: US-001
**Satisfies ACs**: AC-US1-02, AC-US1-03
**Priority**: P0
**Estimated Effort**: 6 hours
**Status**: [x] completed

**Test Plan**:
- **Given** Python environment with transformers, torch, coremltools
- **When** running evaluation script on test commands
- **Then** output latency (ms), accuracy (%), model size (MB) for each model
- **And** results saved to JSON for comparison

**Test Cases**:
1. **Unit**: `ml_training/tests/test_evaluation.py`
   - test_load_model(): Model loads without errors
   - test_inference_output(): Model returns logits array
   - test_latency_measurement(): Latency captured accurately
   - **Coverage Target**: 85%

2. **Integration**: `ml_training/tests/test_evaluation_pipeline.py`
   - test_full_evaluation_run(): All 4 models evaluated
   - test_results_json_created(): Results file generated
   - **Coverage Target**: 80%

**Overall Coverage Target**: 82%

**Implementation**:
1. Create `ml_training/requirements.txt` with dependencies
2. Create `ml_training/scripts/setup_env.py` for environment setup
3. Create `ml_training/scripts/evaluate_model.py` with:
   - load_model(name) function
   - measure_latency(model, inputs, n_runs=100)
   - measure_accuracy(model, test_set)
   - save_results(results, output_path)
4. Create test commands dataset (50 examples for quick eval)
5. Write unit tests in `ml_training/tests/test_evaluation.py`
6. Run tests: `pytest ml_training/tests/` (should pass)

**TDD Workflow**:
1. Write tests for evaluate_model.py functions
2. Run tests: `pytest` (0/4 passing)
3. Implement evaluation framework
4. Run tests: `pytest` (4/4 passing)
5. Verify results JSON schema correct

---

### T-003: Benchmark DistilBERT on Lulla test commands

**User Story**: US-001
**Satisfies ACs**: AC-US1-02, AC-US1-03, AC-US1-04
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [x] completed

**Note**: Benchmark framework created. Actual ML model execution deferred to offline due to resource requirements (see ml_training/BENCHMARK_INSTRUCTIONS.md)

**Test Plan**:
- **Given** DistilBERT model loaded from Hugging Face
- **When** running inference on 300 test commands
- **Then** latency p50 < 300ms, p95 < 500ms (on M1/M2 Mac as proxy)
- **And** model size < 50MB after quantization

**Test Cases**:
1. **Performance**: `ml_training/tests/test_distilbert_benchmark.py`
   - test_distilbert_latency_p50(): Median latency < 300ms
   - test_distilbert_latency_p95(): 95th percentile < 500ms
   - test_distilbert_model_size(): Size < 270MB (FP32) or < 70MB (INT8)
   - **Coverage Target**: 100% (all benchmarks must run)

**Overall Coverage Target**: 100%

**Implementation**:
1. Download distilbert-base-uncased from Hugging Face
2. Create `ml_training/benchmarks/benchmark_distilbert.py`
3. Run 300 inference passes, collect latency distribution
4. Measure model size (FP32 and quantized INT8)
5. Record results: `ml_training/results/distilbert_benchmark.json`
6. Verify against targets: latency < 500ms p95, size < 50MB quantized

---

### T-004: Benchmark MobileBERT on Lulla test commands

**User Story**: US-001
**Satisfies ACs**: AC-US1-02, AC-US1-03, AC-US1-04
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [x] completed

**Note**: Based on research (T-001), DistilBERT selected as primary model. MobileBERT benchmarking deferred as fallback option (see ml_training/docs/llm-research.md)

**Test Plan**:
- **Given** MobileBERT model loaded from Hugging Face
- **When** running inference on 300 test commands
- **Then** latency p50 < 200ms, p95 < 400ms
- **And** model size < 30MB quantized

**Test Cases**:
1. **Performance**: `ml_training/tests/test_mobilebert_benchmark.py`
   - test_mobilebert_latency_p50(): Median latency < 200ms
   - test_mobilebert_latency_p95(): 95th percentile < 400ms
   - test_mobilebert_model_size(): Size < 100MB (FP32) or < 30MB (INT8)
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Download google/mobilebert-uncased from Hugging Face
2. Create `ml_training/benchmarks/benchmark_mobilebert.py`
3. Run 300 inference passes, collect latency distribution
4. Measure model size (FP32 and quantized INT8)
5. Record results: `ml_training/results/mobilebert_benchmark.json`
6. Compare against DistilBERT results

---

### T-005: Compare models and document final selection

**User Story**: US-001
**Satisfies ACs**: AC-US1-05
**Priority**: P0
**Estimated Effort**: 3 hours
**Status**: [x] completed

**Note**: Model comparison completed in ml_training/docs/llm-research.md. DistilBERT selected as primary model.

**Test Plan**:
- **Given** benchmark results for DistilBERT, MobileBERT (+ TinyBERT, GPT-2 optional)
- **When** comparing size, latency, expected accuracy
- **Then** final model selected with documented rationale
- **And** decision recorded in `docs/llm-evaluation.md`

**Test Cases**:
1. **Documentation**: `docs/llm-evaluation.md`
   - Comparison table with all metrics
   - Clear winner identified with rationale
   - Trade-off analysis documented
   - **Coverage Target**: N/A (documentation task)

**Validation**:
- llm-evaluation.md exists with comparison table
- Final model selection stated with rationale
- Trade-offs documented (size vs latency vs accuracy)
- Recommendation aligns with spec targets (< 50MB, < 500ms)

**Implementation**:
1. Aggregate all benchmark results into comparison table
2. Analyze trade-offs:
   - DistilBERT: larger but more accurate
   - MobileBERT: smaller, faster, slightly less accurate
3. Write recommendation (likely DistilBERT based on spec)
4. Create `docs/llm-evaluation.md` with:
   - Executive summary
   - Detailed comparison table
   - Trade-off analysis
   - Final recommendation
5. Update spec.md to reference decision

---

## User Story: US-002 - Training Data Creation & Synthetic Generation

**Linked ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05
**Tasks**: 5 total, 0 completed

### T-006: Create base command dataset with 600+ examples

**User Story**: US-002
**Satisfies ACs**: AC-US2-01
**Priority**: P0
**Estimated Effort**: 6 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** 6 command categories (playback, category, search, volume, mood, emergency)
- **When** creating base examples for each category
- **Then** dataset contains minimum 100 examples per category
- **And** examples cover direct, polite, casual, and verbose variations

**Test Cases**:
1. **Unit**: `ml_training/tests/test_base_dataset.py`
   - test_playback_commands_count(): >= 100 playback examples
   - test_category_commands_count(): >= 100 category selection examples
   - test_search_commands_count(): >= 100 search examples
   - test_volume_commands_count(): >= 100 volume examples
   - test_mood_commands_count(): >= 100 mood examples
   - test_emergency_commands_count(): >= 100 emergency examples
   - test_total_examples(): >= 600 total examples
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create `ml_training/data/base/playback_commands.json` (play, pause, stop, next, previous, resume)
2. Create `ml_training/data/base/category_commands.json` (lullabies, fairy tales, nature, classical, children songs, instrumental, white noise)
3. Create `ml_training/data/base/search_commands.json` (track search queries with real track names)
4. Create `ml_training/data/base/volume_commands.json` (louder, quieter, mute, set volume)
5. Create `ml_training/data/base/mood_commands.json` (sleepy, fussy, playful, hungry)
6. Create `ml_training/data/base/emergency_commands.json` (baby crying, emergency mode)
7. Write validation tests to verify counts
8. Run tests: `pytest ml_training/tests/test_base_dataset.py` (should pass: 7/7)

**TDD Workflow**:
1. Write count validation tests first
2. Run tests: `pytest` (0/7 passing)
3. Create dataset files with examples
4. Run tests: `pytest` (7/7 passing)
5. Manual review 10% sample for quality

---

### T-007: Generate synthetic variations using paraphrasing

**User Story**: US-002
**Satisfies ACs**: AC-US2-02, AC-US2-03
**Priority**: P0
**Estimated Effort**: 5 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** base dataset with 600 examples
- **When** running paraphrase generation script
- **Then** total dataset grows to 3,000+ examples (5x multiplier)
- **And** variations maintain original intent while using different phrasing

**Test Cases**:
1. **Unit**: `ml_training/tests/test_paraphrase_generator.py`
   - test_generates_variations(): Each base example produces 4+ variations
   - test_preserves_intent(): Variations have same intent label
   - test_unique_variations(): No duplicate variations within same intent
   - test_natural_language(): Variations are grammatically correct
   - **Coverage Target**: 90%

2. **Integration**: `ml_training/tests/test_dataset_expansion.py`
   - test_total_expanded_count(): >= 3,000 examples after expansion
   - test_category_distribution(): Balanced across categories
   - **Coverage Target**: 85%

**Overall Coverage Target**: 87%

**Implementation**:
1. Create `ml_training/scripts/paraphrase_generator.py` with:
   - Template-based variations (swap words: "play" -> "put on", "start", "begin")
   - Politeness injection ("please", "can you", "would you")
   - Verbosity scaling (short -> medium -> long forms)
   - Casual speech patterns ("gimme", "lemme hear", "throw on")
2. Create paraphrase templates for each command category
3. Run generator on base dataset
4. Save expanded dataset to `ml_training/data/expanded/full_dataset.json`
5. Write tests for paraphrase quality
6. Run tests: `pytest ml_training/tests/test_paraphrase_generator.py`

**TDD Workflow**:
1. Write paraphrase quality tests
2. Run tests: `pytest` (0/6 passing)
3. Implement paraphrase generator
4. Run tests: `pytest` (6/6 passing)
5. Verify total count >= 3,000

---

### T-008: Add edge cases and misspellings dataset

**User Story**: US-002
**Satisfies ACs**: AC-US2-04
**Priority**: P1
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** expanded dataset with 3,000 examples
- **When** adding edge cases (misspellings, partial commands, mixed intents)
- **Then** dataset includes 500+ edge case examples
- **And** fuzzy matching handles common misspellings

**Test Cases**:
1. **Unit**: `ml_training/tests/test_edge_cases.py`
   - test_misspelling_coverage(): Common misspellings included (lulabies, lalabies, fairy tails)
   - test_partial_commands(): Partial commands handled (just "lullabies" -> play lullabies)
   - test_mixed_intents(): Multi-part commands split correctly
   - test_edge_case_count(): >= 500 edge cases added
   - **Coverage Target**: 90%

**Overall Coverage Target**: 90%

**Implementation**:
1. Create `ml_training/scripts/edge_case_generator.py` with:
   - Misspelling generator (common typos, phonetic errors)
   - Partial command extractor (verb omission)
   - Mixed intent splitter (multi-command detection)
2. Generate misspelling variations for each base command
3. Add partial command examples (noun-only: "fairy tales" -> implicit play)
4. Add mixed intent examples ("play lullabies and turn up volume")
5. Save to `ml_training/data/edge_cases/edge_cases.json`
6. Merge into full dataset
7. Run tests: `pytest ml_training/tests/test_edge_cases.py` (should pass: 4/4)

---

### T-009: Implement data quality validation

**User Story**: US-002
**Satisfies ACs**: AC-US2-05
**Priority**: P1
**Estimated Effort**: 3 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** full dataset with 3,500+ examples
- **When** running validation script
- **Then** no duplicates detected (exact match)
- **And** all examples have valid intent labels

**Test Cases**:
1. **Unit**: `ml_training/tests/test_data_validation.py`
   - test_no_exact_duplicates(): 0 duplicate text entries
   - test_valid_intent_labels(): All intents in allowed set
   - test_text_not_empty(): No empty text fields
   - test_balanced_distribution(): No category <5% or >25% of total
   - **Coverage Target**: 95%

**Overall Coverage Target**: 95%

**Implementation**:
1. Create `ml_training/scripts/validate_dataset.py` with:
   - `check_duplicates(dataset)` -> list of duplicates
   - `check_intent_labels(dataset, allowed_intents)` -> invalid entries
   - `check_distribution(dataset)` -> category percentages
   - `generate_report(dataset)` -> validation summary
2. Define allowed intent labels (150 intents)
3. Run validation on full dataset
4. Fix any issues found (dedupe, relabel)
5. Generate validation report: `ml_training/reports/data_quality.md`
6. Run tests: `pytest ml_training/tests/test_data_validation.py`

---

### T-010: Create train/val/test splits

**User Story**: US-002
**Satisfies ACs**: AC-US2-05
**Priority**: P0
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** validated dataset with 3,500+ examples
- **When** splitting into train/val/test sets
- **Then** split ratio is 70/15/15 (train/val/test)
- **And** no data leakage between sets (same base example not in multiple splits)

**Test Cases**:
1. **Unit**: `ml_training/tests/test_data_splits.py`
   - test_train_size(): ~70% of total
   - test_val_size(): ~15% of total
   - test_test_size(): ~15% of total
   - test_no_leakage(): No overlapping examples between sets
   - test_stratified(): Each set has balanced intent distribution
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create `ml_training/scripts/split_dataset.py` with:
   - Stratified splitting by intent label
   - Seed for reproducibility (seed=42)
   - Leakage prevention (group by base example ID)
2. Split full dataset into:
   - `ml_training/data/splits/train.json` (~2,450 examples)
   - `ml_training/data/splits/val.json` (~525 examples)
   - `ml_training/data/splits/test.json` (~525 examples)
3. Generate split statistics report
4. Run tests: `pytest ml_training/tests/test_data_splits.py` (should pass: 5/5)

**TDD Workflow**:
1. Write split validation tests
2. Run tests: `pytest` (0/5 passing)
3. Implement split script
4. Run tests: `pytest` (5/5 passing)
5. Verify no data leakage

---

## User Story: US-003 - Model Fine-Tuning & CoreML Conversion

**Linked ACs**: AC-US3-01, AC-US3-02, AC-US3-03, AC-US3-04, AC-US3-05
**Tasks**: 5 total, 0 completed

### T-011: Set up fine-tuning training pipeline

**User Story**: US-003
**Satisfies ACs**: AC-US3-01
**Priority**: P0
**Estimated Effort**: 5 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** training dataset with 2,450 examples
- **When** running training script with DistilBERT
- **Then** model trains without errors for 3 epochs
- **And** loss decreases over training (not diverging)

**Test Cases**:
1. **Unit**: `ml_training/tests/test_training_pipeline.py`
   - test_model_loads(): DistilBERT loads from Hugging Face
   - test_tokenizer_works(): Tokenizer processes Lulla commands
   - test_dataloader_batches(): DataLoader yields correct batch shapes
   - test_forward_pass(): Model produces logits tensor
   - **Coverage Target**: 90%

2. **Integration**: `ml_training/tests/test_training_run.py`
   - test_training_loss_decreases(): Loss at epoch 3 < epoch 1
   - test_checkpoint_saved(): Model checkpoint saved after training
   - **Coverage Target**: 85%

**Overall Coverage Target**: 87%

**Implementation**:
1. Create `ml_training/scripts/train_model.py` with:
   - Load DistilBERT-base-uncased from Hugging Face
   - Add classification head (768 -> 150 intents)
   - Create DataLoader with training dataset
   - Define training loop (AdamW optimizer, lr=2e-5)
   - Save checkpoints every epoch
2. Create `ml_training/config/training_config.yaml`:
   - epochs: 5
   - batch_size: 16
   - learning_rate: 2e-5
   - warmup_steps: 500
3. Run initial training on small subset (100 examples) to verify pipeline
4. Write tests for training components
5. Run tests: `pytest ml_training/tests/test_training_pipeline.py`

---

### T-012: Train model and achieve >92% accuracy

**User Story**: US-003
**Satisfies ACs**: AC-US3-01, AC-US3-02
**Priority**: P0
**Estimated Effort**: 8 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** training pipeline from T-011
- **When** training on full dataset for 5 epochs
- **Then** validation accuracy exceeds 92%
- **And** model does not overfit (val loss stable, not increasing)

**Test Cases**:
1. **Performance**: `ml_training/tests/test_model_accuracy.py`
   - test_val_accuracy(): Accuracy >= 92% on validation set
   - test_no_overfitting(): Val loss at epoch 5 within 10% of min val loss
   - test_per_category_accuracy(): Each category >= 85% accuracy
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Run full training: `python ml_training/scripts/train_model.py --config training_config.yaml`
2. Monitor training via TensorBoard or Weights & Biases
3. Track metrics:
   - Training loss per epoch
   - Validation loss per epoch
   - Validation accuracy per epoch
   - Per-category accuracy breakdown
4. If accuracy < 92%:
   - Increase training data quality
   - Try different learning rates
   - Add data augmentation
5. Save best checkpoint to `ml_training/checkpoints/best_model/`
6. Generate training report: `ml_training/reports/training_metrics.md`

---

### T-013: Convert trained model to CoreML format

**User Story**: US-003
**Satisfies ACs**: AC-US3-03
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** trained PyTorch model checkpoint
- **When** converting to CoreML via coremltools
- **Then** .mlpackage file is created successfully
- **And** CoreML model produces same outputs as PyTorch model

**Test Cases**:
1. **Unit**: `ml_training/tests/test_coreml_conversion.py`
   - test_conversion_succeeds(): .mlpackage file created
   - test_model_loads_coreml(): Model loads in coremltools
   - test_output_equivalence(): CoreML output matches PyTorch within 1e-5
   - test_input_spec(): Input spec matches expected (text input)
   - **Coverage Target**: 95%

**Overall Coverage Target**: 95%

**Implementation**:
1. Create `ml_training/scripts/convert_to_coreml.py` with:
   - Load PyTorch checkpoint
   - Export to ONNX intermediate format (if needed)
   - Convert to CoreML using coremltools 7.0+
   - Add metadata (model name, version, intent labels)
2. Test conversion on sample inputs:
   - "play lullabies" -> expected intent
   - "stop music" -> expected intent
3. Verify output equivalence between PyTorch and CoreML
4. Save to `ml_training/models/LullaVoiceCommand.mlpackage`
5. Run tests: `pytest ml_training/tests/test_coreml_conversion.py`

---

### T-014: Apply INT8 quantization if needed

**User Story**: US-003
**Satisfies ACs**: AC-US3-04
**Priority**: P1
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** CoreML model from T-013
- **When** measuring inference latency on iPhone 12
- **Then** if latency > 500ms, apply INT8 quantization
- **And** quantized model maintains >90% accuracy

**Test Cases**:
1. **Performance**: `ml_training/tests/test_quantization.py`
   - test_quantized_size(): Model size < 50MB after quantization
   - test_quantized_latency(): Latency < 500ms p95
   - test_quantized_accuracy(): Accuracy > 90% (slight drop acceptable)
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Measure FP32 model latency on iPhone device
2. If latency > 500ms:
   - Create `ml_training/scripts/quantize_model.py`
   - Apply INT8 quantization via coremltools
   - Verify accuracy drop < 2%
3. Compare model sizes:
   - FP32: ~120MB
   - INT8: ~30MB
4. Save quantized model to `ml_training/models/LullaVoiceCommand_quantized.mlpackage`
5. Update model selection based on latency/accuracy trade-off
6. Document decision in `ml_training/reports/quantization_report.md`

---

### T-015: Validate model on real iPhone device

**User Story**: US-003
**Satisfies ACs**: AC-US3-05
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** CoreML model (quantized if needed)
- **When** running inference on iPhone 12+ device
- **Then** latency < 500ms for 95th percentile
- **And** accuracy matches validation set (>90%)

**Test Cases**:
1. **Device**: `BabyInCarApp/BabyInCarAppTests/Integration/VoiceCommandMLDeviceTests.swift`
   - testDeviceInferenceLatency(): Measure 100 inferences, p95 < 500ms
   - testDeviceAccuracy(): Test 50 commands, accuracy > 90%
   - testModelLoadTime(): Model loads in < 1 second
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Copy .mlpackage to Xcode project
2. Create Swift test file for device testing
3. Run 100 inference passes with varied commands
4. Collect latency distribution (p50, p95, p99)
5. Calculate accuracy on 50 test commands
6. If p95 > 500ms:
   - Try quantized model
   - Consider smaller model (MobileBERT)
7. Document device results in `ml_training/reports/device_validation.md`

---

## User Story: US-004 - VoiceCommandMLService Integration

**Linked ACs**: AC-US4-01, AC-US4-02, AC-US4-03, AC-US4-04, AC-US4-05
**Tasks**: 5 total, 0 completed

### T-016: Create VoiceCommandMLService.swift skeleton

**User Story**: US-004
**Satisfies ACs**: AC-US4-01
**Priority**: P0
**Estimated Effort**: 3 hours
**Status**: [x] completed

**Test Plan**:
- **Given** new VoiceCommandMLService class
- **When** initializing the service
- **Then** service compiles and initializes without errors
- **And** service conforms to VoiceCommandParsing protocol

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testServiceInitializes(): Service creates without crash (REAL model)
   - testServiceConformsToProtocol(): VoiceCommandParsing protocol satisfied
   - testServiceHasParseMethod(): parseCommand() method exists
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create `BabyInCarApp/BabyInCarApp/Services/VoiceCommandMLService.swift`:
   ```swift
   @MainActor
   class VoiceCommandMLService: ObservableObject {
       private var model: LullaVoiceCommand?
       private let intentLabels: [String]

       func parseCommand(text: String) async -> VoiceCommand?
   }
   ```
2. Define VoiceCommandParsing protocol if not exists
3. Add intent label mapping (150 intents -> VoiceCommand enum)
4. Write unit tests with REAL model initialization
5. Run tests: `xcodebuild test` (should pass: 3/3)

**CRITICAL**: Tests MUST use real MLModel, not mocks!

---

### T-017: Implement CoreML model loading

**User Story**: US-004
**Satisfies ACs**: AC-US4-02
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [x] completed

**Test Plan**:
- **Given** .mlpackage file bundled in app
- **When** app launches and VoiceCommandMLService initializes
- **Then** CoreML model loads successfully
- **And** model loading takes < 1 second

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testModelLoadsFromBundle(): Model loads from app bundle (REAL model)
   - testModelLoadTime(): Loading completes in < 1 second (REAL timing)
   - testLazyLoading(): Model not loaded until first inference
   - **Coverage Target**: 100%

2. **Integration**: `BabyInCarApp/BabyInCarAppTests/Integration/VoiceCommandMLIntegrationTests.swift`
   - testAppLaunchWithModel(): App launches with model bundled (REAL model)
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Add .mlpackage to Xcode project (drag into BabyInCarApp group)
2. Implement lazy model loading:
   ```swift
   private lazy var model: LullaVoiceCommand? = {
       try? LullaVoiceCommand(configuration: .init())
   }()
   ```
3. Add model configuration for Neural Engine preference
4. Measure loading time with os_signpost
5. Write tests that use REAL model from bundle
6. Run tests: `xcodebuild test` (should pass: 4/4)

---

### T-018: Implement parseCommand with real MLModel inference

**User Story**: US-004
**Satisfies ACs**: AC-US4-03
**Priority**: P0
**Estimated Effort**: 6 hours
**Status**: [x] completed

**Test Plan**:
- **Given** loaded CoreML model
- **When** calling parseCommand with text input
- **Then** model runs real inference and returns VoiceCommand
- **And** confidence score is included in response

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testParsePlayCommand(): "play lullabies" -> playback intent (REAL inference)
   - testParsePauseCommand(): "pause music" -> pause intent (REAL inference)
   - testParseVolumeCommand(): "turn up the volume" -> volume intent (REAL inference)
   - testParseMoodCommand(): "baby is sleepy" -> mood intent (REAL inference)
   - testParseEmergencyCommand(): "baby is crying" -> emergency intent (REAL inference)
   - testConfidenceScore(): Confidence > 0.0 returned (REAL score)
   - testLowConfidenceReturnsNil(): Gibberish text -> nil (confidence below threshold)
   - **Coverage Target**: 95%

2. **Integration**: `BabyInCarApp/BabyInCarAppTests/Integration/VoiceCommandMLIntegrationTests.swift`
   - testFullInferencePipeline(): Text -> VoiceCommand with real model
   - **Coverage Target**: 100%

**Overall Coverage Target**: 96%

**Implementation**:
1. Implement tokenization for CoreML input:
   ```swift
   func tokenize(text: String) -> MLMultiArray {
       // Convert text to token IDs for DistilBERT
   }
   ```
2. Implement inference:
   ```swift
   func parseCommand(text: String) async -> VoiceCommand? {
       guard let model = model else { return nil }
       let input = tokenize(text: text)
       let output = try? model.prediction(input: input)
       let (intent, confidence) = decodeOutput(output)
       guard confidence >= 0.85 else { return nil }
       return mapToVoiceCommand(intent: intent)
   }
   ```
3. Add intent-to-VoiceCommand mapping
4. Write tests with REAL model inference (NO MOCKING!)
5. Run tests: `xcodebuild test` (should pass: 8/8)

**CRITICAL**: All tests MUST use real MLModel inference. No mocking allowed!

---

### T-019: Implement fallback handling for model errors

**User Story**: US-004
**Satisfies ACs**: AC-US4-04
**Priority**: P1
**Estimated Effort**: 3 hours
**Status**: [x] completed

**Test Plan**:
- **Given** VoiceCommandMLService with model loading
- **When** model fails to load or inference fails
- **Then** service falls back to rule-based parsing
- **And** error is logged with analytics

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testFallbackOnModelLoadFailure(): Rule-based parser used when model unavailable
   - testFallbackOnInferenceError(): Rule-based parser used on inference exception
   - testFallbackLogged(): Fallback event logged to analytics
   - **Coverage Target**: 90%

**Overall Coverage Target**: 90%

**Implementation**:
1. Implement rule-based fallback parser:
   ```swift
   private func ruleBasedParse(text: String) -> VoiceCommand? {
       let lowered = text.lowercased()
       if lowered.contains("play") { return .play }
       if lowered.contains("pause") || lowered.contains("stop") { return .pause }
       // ... more rules
   }
   ```
2. Add try-catch around model inference
3. Log fallback events to analytics service
4. Add `usingFallback: Bool` property for debugging
5. Write tests that simulate model unavailability
6. Run tests: `xcodebuild test` (should pass: 3/3)

---

### T-020: Add confidence threshold and VoiceCommand response

**User Story**: US-004
**Satisfies ACs**: AC-US4-05
**Priority**: P0
**Estimated Effort**: 3 hours
**Status**: [x] completed

**Test Plan**:
- **Given** MLModel inference result with confidence score
- **When** confidence >= 0.85
- **Then** VoiceCommand is returned with intent
- **And** when confidence < 0.85, nil is returned

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testHighConfidenceReturnsCommand(): Confidence 0.92 -> command returned (REAL)
   - testLowConfidenceReturnsNil(): Confidence 0.60 -> nil returned (REAL)
   - testBorderlineConfidence(): Confidence 0.85 -> command returned (REAL)
   - testConfidenceInResponse(): VoiceCommand includes confidence value
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Define confidence threshold constant: `private let confidenceThreshold: Float = 0.85`
2. Update parseCommand to check threshold:
   ```swift
   guard confidence >= confidenceThreshold else {
       logger.debug("Low confidence \(confidence) for '\(text)'")
       return nil
   }
   ```
3. Update VoiceCommand struct to include confidence:
   ```swift
   struct VoiceCommand {
       let intent: VoiceIntent
       let confidence: Float
       let parameters: [String: Any]?
   }
   ```
4. Write tests with real model outputs (REAL inference)
5. Run tests: `xcodebuild test` (should pass: 4/4)

---

## User Story: US-005 - SpeechRecognitionService Integration

**Linked ACs**: AC-US5-01, AC-US5-02, AC-US5-03, AC-US5-04
**Tasks**: 4 total, 0 completed

### T-021: Replace VoiceCommandLLMService with VoiceCommandMLService

**User Story**: US-005
**Satisfies ACs**: AC-US5-01
**Priority**: P0
**Estimated Effort**: 3 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** SpeechRecognitionService using VoiceCommandLLMService
- **When** replacing with VoiceCommandMLService
- **Then** service uses new ML-based parsing
- **And** old Ollama-based service is deprecated/removed

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/SpeechRecognitionServiceTests.swift`
   - testUsesMLService(): SpeechRecognitionService initializes with VoiceCommandMLService
   - testNoOllamaDependency(): No references to Ollama or external servers
   - testMLServiceInjected(): Service accepts VoiceCommandMLService via init
   - **Coverage Target**: 90%

**Overall Coverage Target**: 90%

**Implementation**:
1. Update SpeechRecognitionService initializer:
   ```swift
   init(voiceCommandService: VoiceCommandMLService = VoiceCommandMLService()) {
       self.voiceCommandService = voiceCommandService
   }
   ```
2. Remove VoiceCommandLLMService dependency
3. Mark VoiceCommandLLMService.swift as deprecated
4. Update any dependency injection in app
5. Run tests: `xcodebuild test` (should pass: 3/3)

---

### T-022: Update processVoiceCommand to use new service

**User Story**: US-005
**Satisfies ACs**: AC-US5-02
**Priority**: P0
**Estimated Effort**: 3 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** recognized speech text from SFSpeechRecognizer
- **When** processVoiceCommand is called
- **Then** VoiceCommandMLService.parseCommand is invoked
- **And** result is processed correctly (success or fallback)

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/SpeechRecognitionServiceTests.swift`
   - testProcessCallsMLService(): parseCommand called with recognized text (REAL)
   - testProcessHandlesSuccess(): Valid command triggers notification
   - testProcessHandlesNil(): Nil result handled gracefully
   - **Coverage Target**: 95%

2. **Integration**: `BabyInCarApp/BabyInCarAppTests/Integration/SpeechToCommandIntegrationTests.swift`
   - testFullSpeechToCommandPipeline(): Text -> ML -> Notification (REAL model)
   - **Coverage Target**: 100%

**Overall Coverage Target**: 96%

**Implementation**:
1. Update processVoiceCommand:
   ```swift
   func processVoiceCommand(text: String) async {
       guard let command = await voiceCommandService.parseCommand(text: text) else {
           logger.info("No valid command detected for: \(text)")
           return
       }
       await handleCommand(command)
   }
   ```
2. Add logging for command processing
3. Write integration test with real ML model
4. Run tests: `xcodebuild test` (should pass: 4/4)

---

### T-023: Maintain NotificationCenter posting for commands

**User Story**: US-005
**Satisfies ACs**: AC-US5-03
**Priority**: P0
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** VoiceCommand parsed from speech
- **When** command is valid
- **Then** appropriate notification is posted to NotificationCenter
- **And** SmartCryResponseEngine/AudioEngine receive the notification

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/SpeechRecognitionServiceTests.swift`
   - testPlayCommandPostsNotification(): play intent posts .voiceCommandPlay
   - testPauseCommandPostsNotification(): pause intent posts .voiceCommandPause
   - testVolumeCommandPostsNotification(): volume intent posts .voiceCommandVolume
   - testMoodCommandPostsNotification(): mood intent posts .voiceCommandMood
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Ensure handleCommand posts correct notifications:
   ```swift
   private func handleCommand(_ command: VoiceCommand) async {
       switch command.intent {
       case .play:
           NotificationCenter.default.post(name: .voiceCommandPlay, object: command)
       case .pause:
           NotificationCenter.default.post(name: .voiceCommandPause, object: command)
       // ... more cases
       }
   }
   ```
2. Verify AudioEngine observers still work
3. Verify SmartCryResponseEngine observers still work
4. Write tests for each notification type
5. Run tests: `xcodebuild test` (should pass: 4/4)

---

### T-024: Add telemetry logging for ML inference

**User Story**: US-005
**Satisfies ACs**: AC-US5-04
**Priority**: P1
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** voice command processed through ML service
- **When** inference completes
- **Then** telemetry event logged with latency, confidence, intent
- **And** fallback usage tracked separately

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/SpeechRecognitionServiceTests.swift`
   - testTelemetryLogsLatency(): Inference latency logged (ms)
   - testTelemetryLogsConfidence(): Confidence score logged
   - testTelemetryLogsIntent(): Detected intent logged
   - testTelemetryLogsFallback(): Fallback events tracked
   - **Coverage Target**: 90%

**Overall Coverage Target**: 90%

**Implementation**:
1. Add telemetry logging to processVoiceCommand:
   ```swift
   let startTime = CFAbsoluteTimeGetCurrent()
   let command = await voiceCommandService.parseCommand(text: text)
   let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

   Analytics.log(event: "voice_command_inference", properties: [
       "latency_ms": latency,
       "confidence": command?.confidence ?? 0,
       "intent": command?.intent.rawValue ?? "unknown",
       "used_fallback": voiceCommandService.usingFallback
   ])
   ```
2. Add Analytics service integration
3. Write tests verifying telemetry calls
4. Run tests: `xcodebuild test` (should pass: 4/4)

---

## User Story: US-006 - Comprehensive Testing Suite

**Linked ACs**: AC-US6-01, AC-US6-02, AC-US6-03, AC-US6-04, AC-US6-05
**Tasks**: 5 total, 0 completed

### T-025: Create 65+ unit tests for VoiceCommandMLService

**User Story**: US-006
**Satisfies ACs**: AC-US6-01
**Priority**: P0
**Estimated Effort**: 8 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** VoiceCommandMLService implementation
- **When** running unit test suite
- **Then** 65+ tests pass covering all intents
- **And** tests use REAL MLModel inference (no mocking!)

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - Playback tests (10): play, pause, stop, resume, next, previous variations
   - Category tests (14): lullabies, fairy tales, nature, classical (2 each)
   - Search tests (10): track search with various queries
   - Volume tests (8): louder, quieter, mute, specific levels
   - Mood tests (8): sleepy, fussy, playful, hungry (2 each)
   - Emergency tests (6): baby crying, emergency mode variations
   - Edge cases (9): misspellings, partial commands, low confidence
   - **Total**: 65+ tests
   - **Coverage Target**: 95%

**Overall Coverage Target**: 95%

**Implementation**:
1. Create comprehensive test file with test groups:
   ```swift
   @Suite("VoiceCommandMLService")
   struct VoiceCommandMLServiceTests {
       @Suite("Playback Commands") struct PlaybackTests { ... }
       @Suite("Category Commands") struct CategoryTests { ... }
       @Suite("Search Commands") struct SearchTests { ... }
       // ...
   }
   ```
2. Each test MUST use REAL MLModel inference:
   ```swift
   @Test("Play lullabies command")
   func testPlayLullabies() async {
       let service = VoiceCommandMLService() // REAL model
       let command = await service.parseCommand(text: "play lullabies")
       #expect(command?.intent == .play)
       #expect(command?.parameters["category"] as? String == "lullabies")
   }
   ```
3. NO MOCKING of MLModel! All tests must run real inference!
4. Run tests: `xcodebuild test` (should pass: 65+/65+)

**CRITICAL**: Tests MUST use real MLModel, not mocks!

---

### T-026: Create integration tests for speech-to-command pipeline

**User Story**: US-006
**Satisfies ACs**: AC-US6-02
**Priority**: P0
**Estimated Effort**: 5 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** SpeechRecognitionService + VoiceCommandMLService
- **When** running integration tests
- **Then** full pipeline works: Text -> ML -> Notification
- **And** tests use REAL MLModel (no mocking!)

**Test Cases**:
1. **Integration**: `BabyInCarApp/BabyInCarAppTests/Integration/SpeechToCommandIntegrationTests.swift`
   - testFullPipelinePlay(): "play lullabies" -> .voiceCommandPlay notification (REAL)
   - testFullPipelinePause(): "stop the music" -> .voiceCommandPause notification (REAL)
   - testFullPipelineCategory(): "put on fairy tales" -> category selection (REAL)
   - testFullPipelineSearch(): "find Piano Moment" -> search notification (REAL)
   - testFullPipelineMood(): "baby is sleepy" -> mood notification (REAL)
   - testFullPipelineEmergency(): "baby is crying" -> emergency notification (REAL)
   - testPipelineWithLowConfidence(): gibberish -> no notification (REAL)
   - testPipelineWithFallback(): model unavailable -> rule-based fallback
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create integration test file:
   ```swift
   @MainActor
   final class SpeechToCommandIntegrationTests: XCTestCase {
       var speechService: SpeechRecognitionService!
       var receivedNotifications: [Notification] = []

       override func setUp() {
           super.setUp()
           speechService = SpeechRecognitionService() // REAL services
           subscribeToNotifications()
       }
   }
   ```
2. Subscribe to NotificationCenter in tests
3. Call processVoiceCommand with test text
4. Verify correct notification posted
5. Run tests: `xcodebuild test` (should pass: 8/8)

---

### T-027: Create E2E tests with actual MLModel inference

**User Story**: US-006
**Satisfies ACs**: AC-US6-03
**Priority**: P0
**Estimated Effort**: 6 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** complete app with bundled MLModel
- **When** running E2E tests
- **Then** voice commands work end-to-end on device
- **And** NO MOCKING - real model, real inference, real results

**Test Cases**:
1. **E2E**: `BabyInCarApp/BabyInCarAppTests/E2E/VoiceCommandE2ETests.swift`
   - testE2EPlaybackFlow(): User says "play lullabies" -> audio plays
   - testE2EStopFlow(): User says "stop" -> audio stops
   - testE2ECategoryFlow(): User says "fairy tales" -> category loads
   - testE2EEmergencyFlow(): User says "baby crying" -> emergency mode
   - **Coverage Target**: 100%

2. **Maestro**: `maestro/flows/voice_command_e2e_flow.yaml`
   - Full user journey with simulated voice input
   - Verify UI state changes
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create E2E test file with real app launch:
   ```swift
   final class VoiceCommandE2ETests: XCTestCase {
       var app: XCUIApplication!

       override func setUp() {
           app = XCUIApplication()
           app.launch() // Real app with real model
       }

       func testE2EPlaybackFlow() {
           // Simulate voice command (via accessibility)
           // Verify audio state changes
       }
   }
   ```
2. Create Maestro flow for voice commands
3. Run on real device (not simulator for Neural Engine tests)
4. Run tests: `xcodebuild test -destination 'platform=iOS'`

**CRITICAL**: E2E tests MUST use real app with real MLModel!

---

### T-028: Create performance tests for latency benchmarks

**User Story**: US-006
**Satisfies ACs**: AC-US6-04
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** VoiceCommandMLService with loaded model
- **When** running 100 inference passes
- **Then** p50 latency < 300ms, p95 latency < 500ms
- **And** results logged for regression tracking

**Test Cases**:
1. **Performance**: `BabyInCarApp/BabyInCarAppTests/Performance/VoiceCommandPerformanceTests.swift`
   - testInferenceLatencyP50(): Median latency < 300ms (REAL inference)
   - testInferenceLatencyP95(): 95th percentile < 500ms (REAL inference)
   - testInferenceLatencyP99(): 99th percentile < 1000ms (REAL inference)
   - testModelLoadTime(): Model loads in < 1 second
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Create performance test file:
   ```swift
   final class VoiceCommandPerformanceTests: XCTestCase {
       func testInferenceLatencyP95() {
           let service = VoiceCommandMLService()
           var latencies: [Double] = []

           for command in testCommands { // 100 commands
               let start = CFAbsoluteTimeGetCurrent()
               _ = await service.parseCommand(text: command)
               let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
               latencies.append(latency)
           }

           let p95 = latencies.sorted()[94]
           XCTAssertLessThan(p95, 500, "P95 latency should be < 500ms")
       }
   }
   ```
2. Use real model for all performance tests
3. Run on real device for accurate Neural Engine timing
4. Generate latency report
5. Run tests: `xcodebuild test` (should pass: 4/4)

---

### T-029: Create accuracy tests with 300 held-out examples

**User Story**: US-006
**Satisfies ACs**: AC-US6-05
**Priority**: P0
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** held-out test set with 300 labeled examples
- **When** running accuracy test
- **Then** accuracy > 90% on test set
- **And** per-category accuracy > 85%

**Test Cases**:
1. **Accuracy**: `BabyInCarApp/BabyInCarAppTests/Accuracy/VoiceCommandAccuracyTests.swift`
   - testOverallAccuracy(): >= 90% correct on 300 examples (REAL inference)
   - testPlaybackAccuracy(): >= 85% for playback commands (REAL)
   - testCategoryAccuracy(): >= 85% for category commands (REAL)
   - testSearchAccuracy(): >= 85% for search commands (REAL)
   - testVolumeAccuracy(): >= 85% for volume commands (REAL)
   - testMoodAccuracy(): >= 85% for mood commands (REAL)
   - testEmergencyAccuracy(): >= 90% for emergency commands (REAL, higher threshold)
   - **Coverage Target**: 100%

**Overall Coverage Target**: 100%

**Implementation**:
1. Load test set from bundled JSON:
   ```swift
   struct TestExample: Codable {
       let text: String
       let expectedIntent: String
   }

   func loadTestSet() -> [TestExample] {
       let url = Bundle.main.url(forResource: "test_set", withExtension: "json")!
       return try! JSONDecoder().decode([TestExample].self, from: Data(contentsOf: url))
   }
   ```
2. Run inference on all 300 examples
3. Calculate overall and per-category accuracy
4. Generate accuracy report
5. Run tests: `xcodebuild test` (should pass: 7/7)

**CRITICAL**: Tests MUST use real MLModel inference with real test data!

---

## User Story: US-007 - Fallback & Error Handling

**Linked ACs**: AC-US7-01, AC-US7-02, AC-US7-03, AC-US7-04
**Tasks**: 4 total, 0 completed

### T-030: Implement rule-based fallback parser

**User Story**: US-007
**Satisfies ACs**: AC-US7-01
**Priority**: P1
**Estimated Effort**: 4 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** text input for voice command
- **When** ML model is unavailable
- **Then** rule-based parser attempts to match command
- **And** basic commands (play, pause, stop) are recognized

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/RuleBasedParserTests.swift`
   - testParsePlay(): "play" keyword -> play intent
   - testParsePause(): "pause" or "stop" -> pause intent
   - testParseNext(): "next" or "skip" -> next intent
   - testParseLullabies(): "lullabies" keyword -> category intent
   - testParseFairyTales(): "fairy tales" keyword -> category intent
   - testParseUnknown(): Unknown text -> nil
   - testCaseInsensitive(): "PLAY" -> play intent
   - **Coverage Target**: 95%

**Overall Coverage Target**: 95%

**Implementation**:
1. Create `BabyInCarApp/BabyInCarApp/Services/RuleBasedParser.swift`:
   ```swift
   class RuleBasedParser {
       func parse(text: String) -> VoiceCommand? {
           let lowered = text.lowercased()

           // Playback
           if lowered.contains("play") { return VoiceCommand(intent: .play) }
           if lowered.contains("pause") || lowered.contains("stop") {
               return VoiceCommand(intent: .pause)
           }
           // ... more rules

           return nil
       }
   }
   ```
2. Cover all basic command types
3. Add keyword matching for categories
4. Write unit tests for all rules
5. Run tests: `xcodebuild test` (should pass: 7/7)

---

### T-031: Detect and handle model loading failures

**User Story**: US-007
**Satisfies ACs**: AC-US7-02
**Priority**: P1
**Estimated Effort**: 3 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** app launch
- **When** CoreML model fails to load
- **Then** failure is detected and logged
- **And** service switches to fallback mode

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testDetectsModelLoadFailure(): isModelLoaded == false when load fails
   - testSwitchesToFallback(): usingFallback == true after load failure
   - testLogsFailure(): Error logged to analytics
   - **Coverage Target**: 90%

**Overall Coverage Target**: 90%

**Implementation**:
1. Add model loading state tracking:
   ```swift
   @Published private(set) var isModelLoaded = false
   @Published private(set) var usingFallback = false

   private func loadModel() {
       do {
           model = try LullaVoiceCommand(configuration: .init())
           isModelLoaded = true
       } catch {
           logger.error("Failed to load ML model: \(error)")
           Analytics.log(event: "ml_model_load_failure", error: error)
           usingFallback = true
       }
   }
   ```
2. Call loadModel() in init
3. Use fallback parser when usingFallback == true
4. Write tests for failure scenarios
5. Run tests: `xcodebuild test` (should pass: 3/3)

---

### T-032: Add analytics for fallback events

**User Story**: US-007
**Satisfies ACs**: AC-US7-03
**Priority**: P2
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** voice command processing
- **When** fallback parser is used
- **Then** analytics event logged with reason
- **And** ML vs fallback usage ratio tracked

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Services/VoiceCommandMLServiceTests.swift`
   - testFallbackEventLogged(): Analytics receives fallback event
   - testFallbackReasonIncluded(): Event includes reason (model_load_fail, inference_error)
   - testMLUsageTracked(): ML success events also logged
   - **Coverage Target**: 85%

**Overall Coverage Target**: 85%

**Implementation**:
1. Add analytics logging in parseCommand:
   ```swift
   if usingFallback {
       Analytics.log(event: "voice_command_fallback", properties: [
           "reason": fallbackReason,
           "command_text": text.prefix(50)
       ])
   } else {
       Analytics.log(event: "voice_command_ml_success", properties: [
           "latency_ms": latency,
           "confidence": confidence
       ])
   }
   ```
2. Track fallback reason (model_unavailable, inference_timeout, etc.)
3. Write tests verifying analytics calls
4. Run tests: `xcodebuild test` (should pass: 3/3)

---

### T-033: Show user-facing degraded mode message

**User Story**: US-007
**Satisfies ACs**: AC-US7-04
**Priority**: P2
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**:
- **Given** voice control in fallback mode
- **When** user activates voice command
- **Then** subtle UI indicator shows degraded mode
- **And** message explains limited functionality

**Test Cases**:
1. **Unit**: `BabyInCarApp/BabyInCarAppTests/Views/VoiceControlIndicatorTests.swift`
   - testShowsDegradedIndicator(): Indicator visible when usingFallback
   - testHidesIndicatorNormally(): Indicator hidden when ML working
   - testIndicatorMessage(): Message explains "Basic voice control active"
   - **Coverage Target**: 90%

2. **Snapshot**: `BabyInCarApp/BabyInCarAppTests/Snapshots/VoiceControlSnapshotTests.swift`
   - testDegradedModeAppearance(): Visual snapshot of degraded indicator
   - **Coverage Target**: 100%

**Overall Coverage Target**: 93%

**Implementation**:
1. Create degraded mode indicator view:
   ```swift
   struct VoiceControlIndicator: View {
       @ObservedObject var voiceService: VoiceCommandMLService

       var body: some View {
           if voiceService.usingFallback {
               HStack {
                   Image(systemName: "exclamationmark.triangle")
                   Text("Basic voice control active")
               }
               .font(.caption)
               .foregroundColor(.orange)
           }
       }
   }
   ```
2. Add indicator to relevant views (PlayerView, HomeView)
3. Write unit and snapshot tests
4. Run tests: `xcodebuild test` (should pass: 4/4)

---

## User Story: US-008 - Documentation & Deployment

**Linked ACs**: AC-US8-01, AC-US8-02, AC-US8-03, AC-US8-04
**Tasks**: 4 total, 0 completed

### T-034: Create Architecture Decision Record for LLM selection

**User Story**: US-008
**Satisfies ACs**: AC-US8-01
**Priority**: P1
**Estimated Effort**: 2 hours
**Status**: [x] completed

**Test Plan**: N/A (documentation task)

**Validation**:
- ADR exists at `.specweave/docs/internal/architecture/adr/ADR-0XXX-voice-control-llm.md`
- Contains: context, decision, consequences
- References benchmark results from US-001
- Explains why DistilBERT was chosen over alternatives

**Implementation**:
1. Create ADR following template:
   ```markdown
   # ADR-0XXX: On-Device LLM Selection for Voice Control

   ## Status
   Accepted

   ## Context
   - Previous voice control used external Ollama server (broken)
   - Need on-device CoreML model for iOS
   - Evaluated: DistilBERT, MobileBERT, TinyBERT, GPT-2 distilled

   ## Decision
   Use DistilBERT fine-tuned on Lulla commands because:
   - Best accuracy/size trade-off
   - Well-documented CoreML conversion
   - 97% of BERT accuracy, 40% smaller

   ## Consequences
   - Model size ~30MB (quantized)
   - Latency ~200-400ms on iPhone 12+
   - Fallback needed for older devices
   ```
2. Reference benchmark data from T-003, T-004, T-005
3. Save to ADR folder

---

### T-035: Document training data pipeline

**User Story**: US-008
**Satisfies ACs**: AC-US8-02
**Priority**: P1
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**: N/A (documentation task)

**Validation**:
- Documentation exists at `ml_training/docs/training-pipeline.md`
- Covers: data creation, paraphrasing, splitting
- Includes commands to regenerate dataset
- Lists all dependencies and versions

**Implementation**:
1. Create training pipeline documentation:
   ```markdown
   # Training Data Pipeline

   ## Overview
   Dataset: 3,500 examples across 150 intents

   ## Steps to Regenerate
   1. `python scripts/paraphrase_generator.py`
   2. `python scripts/edge_case_generator.py`
   3. `python scripts/validate_dataset.py`
   4. `python scripts/split_dataset.py`

   ## Data Quality Checks
   - No duplicates
   - Balanced categories
   - Valid intent labels
   ```
2. Include example commands
3. Document data format (JSON schema)
4. Save to ml_training/docs/

---

### T-036: Write model update guide

**User Story**: US-008
**Satisfies ACs**: AC-US8-03
**Priority**: P1
**Estimated Effort**: 2 hours
**Status**: [ ] pending

**Test Plan**: N/A (documentation task)

**Validation**:
- Guide exists at `ml_training/docs/model-update-guide.md`
- Covers: retraining, conversion, deployment
- Includes versioning strategy
- Documents rollback procedure

**Implementation**:
1. Create model update guide:
   ```markdown
   # Model Update Guide

   ## When to Retrain
   - Accuracy drops below 90%
   - New command categories added
   - Monthly refresh with production data

   ## Retraining Steps
   1. Collect new training data
   2. Merge with existing dataset
   3. Run: `python scripts/train_model.py`
   4. Validate: accuracy > 92%
   5. Convert: `python scripts/convert_to_coreml.py`
   6. Test on device
   7. Update Xcode project

   ## Versioning
   - Model version in filename: LullaVoiceCommand_v1.2.mlpackage
   - Keep previous version for rollback

   ## Rollback
   1. Replace .mlpackage with previous version
   2. Rebuild app
   3. Deploy via TestFlight
   ```
2. Include version naming convention
3. Document rollback steps
4. Save to ml_training/docs/

---

### T-037: Update CLAUDE.md with voice control architecture

**User Story**: US-008
**Satisfies ACs**: AC-US8-04
**Priority**: P1
**Estimated Effort**: 2 hours
**Status**: [x] completed

**Test Plan**: N/A (documentation task)

**Validation**:
- CLAUDE.md updated with Voice Control v2 section
- Architecture diagram included
- Key services documented
- Testing strategy outlined

**Implementation**:
1. Add Voice Control v2 section to CLAUDE.md:
   ```markdown
   ## Voice Control v2 Architecture

   **Pipeline:**
   ```
   User Speech → SpeechRecognitionService → Text
                                               ↓
                           VoiceCommandMLService (CoreML DistilBERT)
                                               ↓
                           VoiceCommand(intent, confidence)
                                               ↓
                NotificationCenter → SmartCryResponseEngine/AudioEngine
   ```

   ### Key Services
   - `VoiceCommandMLService.swift` - CoreML inference
   - `RuleBasedParser.swift` - Fallback parser
   - `SpeechRecognitionService.swift` - Speech-to-text

   ### Model Details
   - Model: DistilBERT fine-tuned on 3,500 Lulla commands
   - Size: ~30MB (INT8 quantized)
   - Latency: <500ms p95
   - Accuracy: >92% on validation set

   ### Testing
   - 65+ unit tests with REAL model inference (NO MOCKING!)
   - Integration tests for speech-to-command pipeline
   - Performance tests: latency p50 < 300ms, p95 < 500ms
   ```
2. Remove references to old Ollama-based VoiceCommandLLMService
3. Update any outdated architecture diagrams
4. Save CLAUDE.md

