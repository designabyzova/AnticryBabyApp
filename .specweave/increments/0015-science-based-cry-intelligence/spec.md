# FS-015: Science-Based Cry Intelligence

## Overview
Overhaul the cry detection and classification system to be based on actual infant cry research. Fix the "always detects as tired" issue and implement scientifically-validated acoustic signatures for each cry type. Improve soothing sound selection with research-backed recommendations.

## Problem Statement
1. **Over-detection as "Tired"**: Current thresholds bias toward tired classification
2. **Limited differentiation**: Cry types not distinguished based on real acoustic science
3. **Soothing sounds too similar**: Limited variety, sounds similar to noise
4. **No temporal analysis**: Missing cry pattern evolution over time

## Research Foundation

### Infant Cry Acoustics (Based on Published Research)

#### Hunger Cry (Barr et al., 1988; Wasz-Höckert et al., 1985)
- **Fundamental Frequency (F0)**: 350-450 Hz (lower range)
- **Pattern**: Rhythmic, rising-falling pattern (neh-neh-neh)
- **Duration**: 2-4 second bursts with 1-2 second pauses
- **Onset**: Gradual intensity buildup
- **Key Feature**: Strong rhythmicity (0.8-1.0), low intensity start
- **Spectral**: More harmonic structure, lower spectral centroid

#### Tired/Sleepy Cry (Wasz-Höckert et al., 1985)
- **Fundamental Frequency (F0)**: 300-400 Hz (lowest range)
- **Pattern**: Whimpering, irregular, trailing off
- **Duration**: Variable, often fading
- **Onset**: Soft, intermittent
- **Key Feature**: LOW intensity (<0.4), irregular rhythm, yawning vocalizations
- **Spectral**: Breathy quality, higher noise component

#### Pain Cry (Fuller & Horii, 1986; Porter et al., 1988)
- **Fundamental Frequency (F0)**: 500-700 Hz (highest range)
- **Pattern**: Sudden, sustained, piercing
- **Duration**: Long initial cry (4-8+ seconds) without pauses
- **Onset**: ABRUPT, immediate high intensity
- **Key Feature**: Very high intensity (>0.8), NO rhythmicity, sustained
- **Spectral**: High spectral centroid (>1500 Hz), strong upper harmonics

#### Discomfort Cry (wet diaper, temperature)
- **Fundamental Frequency (F0)**: 400-500 Hz (mid range)
- **Pattern**: Fussy, irregular, starts/stops
- **Duration**: Moderate bursts
- **Onset**: Gradual
- **Key Feature**: Moderate intensity, variable pattern
- **Spectral**: Mid-range characteristics

#### Attention/Boredom Cry
- **Fundamental Frequency (F0)**: 400-550 Hz
- **Pattern**: Cooing → fussing → crying escalation
- **Duration**: Brief bursts with long pauses (waiting for response)
- **Onset**: Starts soft, escalates if ignored
- **Key Feature**: Responsive to environment, pauses to listen
- **Spectral**: Variable, often with non-cry vocalizations mixed in

## User Stories

### US-001: Research-Based Cry Classification
**As a** parent using cry detection
**I want** the app to correctly identify why my baby is crying
**So that** I can respond appropriately to their needs

**Acceptance Criteria:**
- [x] AC-US1-01: Hunger cry identified by rhythmic pattern and 350-450 Hz F0
- [x] AC-US1-02: Pain cry identified by sudden onset, high F0 (500-700 Hz), sustained duration
- [x] AC-US1-03: Tired cry identified by low intensity, irregular pattern, breathy quality
- [x] AC-US1-04: Discomfort cry identified by mid-range characteristics
- [x] AC-US1-05: Attention cry identified by escalating pattern with response pauses

### US-002: Multi-Feature Classification
**As a** cry detection system
**I want** to analyze multiple acoustic features together
**So that** classification is more accurate than single-feature thresholds

**Acceptance Criteria:**
- [x] AC-US2-01: Combine F0, intensity, rhythmicity, and spectral features
- [x] AC-US2-02: Weight features based on research-validated importance
- [x] AC-US2-03: Use confidence scoring for ambiguous cases
- [x] AC-US2-04: Track feature evolution over time for pattern recognition

### US-003: Diverse Soothing Sounds
**As a** parent trying to calm my baby
**I want** variety in soothing sounds beyond just noise
**So that** the app can find what works for my baby

**Acceptance Criteria:**
- [x] AC-US3-01: Different sounds for each cry type based on research
- [x] AC-US3-02: Age-appropriate sound selection
- [x] AC-US3-03: Sound rotation to prevent habituation
- [x] AC-US3-04: Learn which sounds work for this specific baby

## Technical Requirements

### TR-001: Acoustic Feature Extraction
- Extract fundamental frequency (F0) using autocorrelation
- Calculate rhythmicity score from amplitude envelope
- Measure onset sharpness
- Track intensity evolution over time

### TR-002: Classification Algorithm
- Multi-feature weighted scoring
- Temporal pattern analysis (not just instantaneous)
- Confidence calibration
- Hysteresis to prevent rapid switching

### TR-003: Soothing Sound Engine
- Research-backed sound selection per cry type
- Age-appropriate filtering
- Habituation prevention through rotation
- Personalization through learning

## Out of Scope
- Training custom ML models (using rule-based with research parameters)
- Cloud-based cry analysis
- Medical diagnosis claims

## Success Metrics
- Cry type classification accuracy improved (validated by user feedback)
- Reduced "tired" over-detection
- More variety in soothing sounds played
- Faster calming times (tracked by session duration)
