# FS-0009: Self-Learning Cry Detection System

## Overview
Build an innovative, self-learning cry detection system that combines on-device ML training with adaptive feedback loops. The system learns from each baby's unique cry patterns and user feedback to continuously improve effectiveness.

## Scientific Foundation
Based on cutting-edge research:
- [Frontiers in AI 2024](https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2024.1337356/full) - MFCC-based Random Forest achieves 96.39% accuracy
- [DeepInfant](https://github.com/skytells-research/DeepInfant) - CNN-LSTM hybrid with 89% accuracy, CoreML ready
- Key features: MFCC (13-20 coefficients), Mel-spectrograms, ZCR, RMS, Spectral Centroid

## User Stories

### US-001: On-Device ML Model Training
**As a** parent
**I want** the app to learn my baby's unique cry patterns
**So that** detection becomes more accurate over time

**Acceptance Criteria:**
- [ ] AC-US1-01: System uses CoreML for on-device inference
- [ ] AC-US1-02: Model updates based on labeled user feedback
- [ ] AC-US1-03: Training data stored securely on device
- [ ] AC-US1-04: Model versioning with rollback capability
- [ ] AC-US1-05: Privacy-first: no audio leaves device

### US-002: Adaptive Learning from Feedback
**As a** parent
**I want** to provide feedback on cry detection accuracy
**So that** the system learns what works for my baby

**Acceptance Criteria:**
- [ ] AC-US2-01: "Baby is Calm" button shows success animation
- [ ] AC-US2-02: Audio fades out gracefully over 2-3 seconds
- [ ] AC-US2-03: Haptic feedback confirms action
- [ ] AC-US2-04: Feedback stored with session context
- [ ] AC-US2-05: Learning algorithm weighs recent feedback higher

### US-003: Effectiveness Analytics
**As a** parent
**I want** to see what sounds work best for my baby
**So that** I can make informed choices

**Acceptance Criteria:**
- [ ] AC-US3-01: Track effectiveness per sound type
- [ ] AC-US3-02: Track effectiveness per cry type
- [ ] AC-US3-03: Show "What Works" insights dashboard
- [ ] AC-US3-04: Time-to-calm metrics tracked
- [ ] AC-US3-05: Weekly/monthly trend analysis

### US-004: E2E Testing Coverage
**As a** developer
**I want** comprehensive E2E tests
**So that** the system reliability is verified

**Acceptance Criteria:**
- [ ] AC-US4-01: Maestro E2E test framework setup
- [ ] AC-US4-02: Emergency mode flow tested
- [ ] AC-US4-03: Baby is Calm feedback flow tested
- [ ] AC-US4-04: Learning system behavior verified
- [ ] AC-US4-05: All critical paths covered

## Technical Architecture

### ML Pipeline
```
Audio Input (16kHz)
    → FFT/STFT (4096 samples)
    → Mel-Spectrogram (128 bins)
    → MFCC Extraction (20 coefficients)
    → CNN Feature Extraction
    → LSTM Temporal Context
    → Classification (9 cry types)
```

### Cry Categories (Based on Research)
1. hunger - Rhythmic, escalating
2. tired - Whiny, continuous
3. pain - Sudden, high-pitched
4. discomfort - Fussy, intermittent
5. attention - Short bursts
6. belly_pain - Intense, drawing knees
7. cold_hot - Unsettled whimpering
8. lonely - Escalating with pauses
9. unknown - Unclassified

### Learning System Architecture
```
User Feedback → Session Context → Feature Storage
                      ↓
           Effectiveness Scorer
                      ↓
    Sound-CryType Effectiveness Matrix
                      ↓
         Personalized Recommendations
```

## Success Metrics
- Detection accuracy: >85% for trained babies
- Time-to-calm improvement: 20% reduction
- User satisfaction: 4.5+ stars
- E2E test coverage: 100% critical paths
