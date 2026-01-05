# US-001: LLM Model Selection & Evaluation

**Feature**: [FS-027](./FEATURE.md)
**Project**: main
**Priority**: P0

## User Story

**As a** developer
**I want** to evaluate and select the best on-device LLM for Lulla commands
**So that** voice control actually works on iOS without external servers

## Acceptance Criteria

- [ ] AC-US1-01: Evaluate CoreML-compatible models (DistilBERT, MobileBERT, TinyBERT, GPT-2 distilled)
- [ ] AC-US1-02: Benchmark inference latency on iPhone 12+ (<500ms target)
- [ ] AC-US1-03: Measure accuracy on Lulla command test set (>90% target)
- [ ] AC-US1-04: Compare model sizes (prefer <50MB for app bundle)
- [ ] AC-US1-05: Document trade-offs in `docs/llm-evaluation.md` and select final model with rationale

## Implementation Tasks

- T-001: Research CoreML-compatible LLM options
- T-002: Set up model evaluation framework
- T-003: Benchmark DistilBERT
- T-004: Benchmark MobileBERT
- T-005: Compare models and document final selection

## Testing Strategy

- Benchmark dataset: 300 Lulla command examples
- Metrics: accuracy, latency, model size
- Test on real iPhone 12 device

## Related Documents

- [Technical Plan](../../../increments/0027-voice-control-v2-llm/plan.md) - Model Selection Architecture
- [Tasks](../../../increments/0027-voice-control-v2-llm/tasks.md) - T-001 to T-005
