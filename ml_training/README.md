# Lulla Voice Command ML Training

Machine learning training pipeline for on-device voice command classification using CoreML.

## Overview

This module trains a DistilBERT model to classify 150 voice command intents for the Lulla baby app. The trained model is converted to CoreML and deployed on-device for zero-latency, privacy-preserving voice control.

## Setup

### 1. Install Dependencies

```bash
# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Verify Setup

```bash
python scripts/setup_env.py
```

Expected output:
```
✅ Python 3.9+
✅ Dependencies installed
✅ PyTorch
✅ Hugging Face Transformers
✅ CoreML Tools
✅ Apple Metal (GPU acceleration) available
```

## Quick Start

### Evaluate a Model

```bash
python scripts/evaluate_model.py \
  --model distilbert-base-uncased \
  --n-runs 100 \
  --output results/distilbert_eval.json
```

### Run Tests

```bash
# All tests with coverage
pytest

# Unit tests only
pytest tests/test_evaluation.py

# Integration tests only
pytest tests/test_evaluation_pipeline.py
```

## Directory Structure

```
ml_training/
├── data/                    # Training data
│   ├── base/               # Base command examples
│   ├── expanded/           # Paraphrased variations
│   ├── edge_cases/         # Misspellings, edge cases
│   └── splits/             # Train/val/test splits
├── scripts/                # Training scripts
│   ├── setup_env.py       # Environment setup
│   ├── evaluate_model.py  # Model evaluation
│   ├── paraphrase_generator.py
│   ├── train_model.py
│   └── convert_to_coreml.py
├── tests/                  # Unit & integration tests
│   ├── test_evaluation.py
│   └── test_evaluation_pipeline.py
├── docs/                   # Documentation
│   └── llm-research.md    # Model selection research
├── models/                 # Trained models
│   └── LullaVoiceCommand.mlpackage
├── results/                # Evaluation results
├── requirements.txt        # Python dependencies
└── pytest.ini             # Test configuration
```

## Workflow

### Phase 1: Model Selection (US-001)
1. Research CoreML-compatible models ✅
2. Set up evaluation framework ✅
3. Benchmark DistilBERT
4. Benchmark MobileBERT
5. Compare and select final model

### Phase 2: Training Data (US-002)
1. Create base dataset (600 examples)
2. Generate synthetic variations (3,000 total)
3. Add edge cases (misspellings, partials)
4. Validate data quality
5. Split into train/val/test

### Phase 3: Fine-Tuning (US-003)
1. Set up training pipeline
2. Fine-tune on Lulla commands
3. Achieve >92% validation accuracy
4. Convert to CoreML
5. Test on real iPhone

### Phase 4: Integration (US-004-008)
1. Create VoiceCommandMLService.swift
2. Integrate into SpeechRecognitionService
3. Write 65+ unit tests
4. Performance & accuracy testing
5. Fallback & error handling

## Testing

### Coverage Targets

| Test Type | Target | Current |
|-----------|--------|---------|
| Unit | 85% | TBD |
| Integration | 80% | TBD |
| Overall | 82% | TBD |

### Running Tests

```bash
# All tests with coverage report
pytest

# Generate HTML coverage report
pytest --cov-report=html
open coverage_html/index.html

# Run specific test
pytest tests/test_evaluation.py::TestModelEvaluator::test_load_model -v
```

## Model Specifications

### DistilBERT (Recommended)

- **Size**: ~30MB (INT8 quantized)
- **Latency**: 200-400ms (iPhone 12+)
- **Accuracy**: 90-92% (expected)
- **Input**: Text string (max 128 tokens)
- **Output**: 150 intent probabilities

### Training Hyperparameters

```python
{
  "model": "distilbert-base-uncased",
  "epochs": 5,
  "batch_size": 16,
  "learning_rate": 2e-5,
  "warmup_steps": 500,
  "num_labels": 150,
}
```

## Command Categories

1. **Playback**: play, pause, stop, resume, next, previous
2. **Category**: lullabies, fairy tales, nature, classical, children songs
3. **Search**: track search with real track names
4. **Volume**: louder, quieter, mute, set volume
5. **Mood**: sleepy, fussy, playful, hungry
6. **Emergency**: baby crying, emergency mode

## License

Apache 2.0 (same as DistilBERT)

## References

- DistilBERT Paper: https://arxiv.org/abs/1910.01108
- Hugging Face Transformers: https://huggingface.co/transformers
- CoreML Tools: https://coremltools.readme.io
