# FS-027: Voice Control v2 - Open-Source LLM Integration with Lulla Command Training

**Increment**: 0027-voice-control-v2-llm
**Project**: main
**Priority**: P0
**Type**: feature
**Status**: Active

## Overview

Complete rework of voice control using on-device CoreML-compatible open-source LLMs with proper training on Lulla commands. Replaces broken Ollama-based implementation with functional on-device inference.

## Problem Statement

The current voice control implementation (increment 0023-llm-voice-control) **does not work functionally**:

- VoiceCommandLLMService.swift has Ollama integration that requires external desktop server
- iOS cannot run Ollama locally - architecture is fundamentally broken
- 54 tests exist but disable LLM functionality (`useLLMParsing = false`)
- No actual on-device inference capability
- No training data for Lulla-specific commands
- User feedback: "nothing is working, you MUST ultrathink and create tests!"

**Root Cause**: The design requires an external Ollama server, which is not practical for a mobile app.

## Solution Approach

On-device CoreML-compatible LLM (DistilBERT) fine-tuned on Lulla commands with proper training data:

- **Model**: DistilBERT (30MB, 100-300ms latency, 90%+ accuracy)
- **Training**: 3,000 synthetic examples across 150 command intents
- **Deployment**: Bundled .mlpackage in iOS app
- **Testing**: Real MLModel inference (no mocking!)

## User Stories

- [US-001](./us-001-llm-model-selection-evaluation.md): LLM Model Selection & Evaluation
- [US-002](./us-002-training-data-creation-synthetic-generation.md): Training Data Creation & Synthetic Generation
- [US-003](./us-003-model-fine-tuning-coreml-conversion.md): Model Fine-Tuning & CoreML Conversion
- [US-004](./us-004-voicecommandmlservice-integration.md): VoiceCommandMLService Integration
- [US-005](./us-005-speechrecognitionservice-integration.md): SpeechRecognitionService Integration
- [US-006](./us-006-comprehensive-testing-suite.md): Comprehensive Testing Suite
- [US-007](./us-007-fallback-error-handling.md): Fallback & Error Handling
- [US-008](./us-008-documentation-deployment.md): Documentation & Deployment

## Success Metrics

| Metric | Target | Percentile |
|--------|--------|------------|
| Intent Classification Accuracy | >92% | Validation set |
| Inference Latency | <300ms | p50 |
| Inference Latency | <500ms | p95 |
| Model Size | <50MB | App bundle |
| Fallback Rate | <1% | Production |

## Timeline

**Estimated**: 4-5 weeks (37 tasks)

- Phase 1: ML Research & Training (10 days)
- Phase 2: iOS Integration (6 days)
- Phase 3: Testing (5 days)
- Phase 4: Documentation (3 days)

## Related Documents

- [Increment Specification](../../../increments/0027-voice-control-v2-llm/spec.md)
- [Technical Architecture Plan](../../../increments/0027-voice-control-v2-llm/plan.md)
- [Implementation Tasks](../../../increments/0027-voice-control-v2-llm/tasks.md)
- ADR-0130: DistilBERT Model Selection
- ADR-0131: On-Device vs Cloud Inference
- ADR-0132: CoreML vs TensorFlow Lite
- ADR-0133: Synthetic Training Data Approach
