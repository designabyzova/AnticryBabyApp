# Baby Mood Intelligence (BabyMIM) - Revolutionary AI Soothing System

## Overview

BabyMIM is a revolutionary AI-powered system that creates a comprehensive understanding of each baby's unique personality, preferences, and emotional state. Unlike traditional cry-response systems that simply play sounds when crying is detected, BabyMIM uses LLM reasoning to make intelligent, personalized, and predictive soothing decisions.

## Epic: FS-004 - Baby Mood Intelligence System

### Problem Statement
Current baby soothing apps react to crying with generic sounds. They don't understand:
- Each baby's unique cry signature and personality
- Context (time of day, recent activities, environment)
- What actually works for THIS specific baby
- How to predict and prevent crying before it starts

### Solution
Build a comprehensive AI system that:
1. Creates unique "voice prints" for each baby's cry
2. Tracks context signals (time, activities, environment)
3. Maintains a learning profile of each baby's preferences
4. Uses LLM reasoning to select optimal soothing strategies
5. Generates dynamic, personalized sound mixes
6. Continuously learns and improves

---

## User Stories

### US-001: Baby Mood Profile
**As a** parent
**I want** the app to learn my baby's unique preferences and personality
**So that** soothing sounds are personalized to what works for my baby

#### Acceptance Criteria
- [x] AC-US1-01: System creates and persists BabyMoodProfile with learned preferences
- [x] AC-US1-02: Profile tracks favorite sounds per cry type with effectiveness scores
- [x] AC-US1-03: Profile learns personality traits (soothing responsiveness, novelty preference, rhythm sensitivity)
- [x] AC-US1-04: Profile stores typical patterns (crying times, sleep schedule, mood by time of day)
- [x] AC-US1-05: Profile supports parent-tagged observations and known triggers/comforts

### US-002: Cry Audio Embedding
**As a** developer
**I want** to extract rich audio embeddings from baby cries
**So that** we can understand the emotional content and unique signature of each cry

#### Acceptance Criteria
- [x] AC-US2-01: CryAudioEmbedder extracts fundamental frequency, variability, and intensity envelope
- [x] AC-US2-02: Embedder captures emotional markers (tremolo, breath pattern, onset sharpness)
- [x] AC-US2-03: Embedder tracks temporal patterns (burst duration, pause duration, rhythmicity)
- [x] AC-US2-04: System creates 128-dimensional baby voice print that improves over time
- [x] AC-US2-05: Embeddings are fast enough for real-time use (<50ms)

### US-003: Context Signal Collection
**As a** developer
**I want** to collect contextual signals about the baby's situation
**So that** the AI can make informed soothing decisions

#### Acceptance Criteria
- [x] AC-US3-01: ContextSignalCollector tracks time-based context (time of day, since last feed/sleep/diaper)
- [x] AC-US3-02: Collector monitors environment (ambient noise, car motion, temperature if available)
- [x] AC-US3-03: Collector tracks recent history (crying episodes today, last calming method, success)
- [x] AC-US3-04: Collector supports parent notes and special circumstances
- [x] AC-US3-05: Context is efficiently gathered without significant battery drain

### US-004: LLM Reasoning Engine
**As a** developer
**I want** an LLM-powered reasoning engine
**So that** soothing decisions are intelligent and personalized

#### Acceptance Criteria
- [x] AC-US4-01: BabyMoodLLMEngine analyzes cry embedding, context, and profile to recommend strategy
- [x] AC-US4-02: Engine generates sound sequences with timing and transitions
- [x] AC-US4-03: Engine provides human-readable reasoning for recommendations
- [x] AC-US4-04: Engine supports both local (on-device) and cloud-based inference
- [x] AC-US4-05: Engine generates natural language insights for parents

### US-005: Dynamic Sound Mixing
**As a** parent
**I want** personalized sound mixes created for my baby
**So that** soothing is more effective than single sounds

#### Acceptance Criteria
- [x] AC-US5-01: DynamicSoundMixer creates multi-layer sound mixes
- [x] AC-US5-02: Mixer supports per-layer volume, pitch adjustment, and rhythm sync
- [x] AC-US5-03: Mixer can sync sounds to detected breathing rhythm
- [x] AC-US5-04: Mixer supports smooth transitions between sounds
- [x] AC-US5-05: Mixer generates baby-specific preset mixes based on profile

### US-006: Adaptive Feedback Loop
**As a** developer
**I want** the system to continuously learn from outcomes
**So that** soothing effectiveness improves over time

#### Acceptance Criteria
- [x] AC-US6-01: AdaptiveFeedbackLoop monitors cry intensity during soothing
- [x] AC-US6-02: Loop records outcomes (worked, time to calm, sounds used)
- [x] AC-US6-03: Loop updates baby profile with learned preferences
- [x] AC-US6-04: Loop adjusts personality trait scores based on behavior
- [x] AC-US6-05: Loop supports explicit parent feedback integration

### US-007: Baby Mood Dashboard UI
**As a** parent
**I want** to see my baby's current mood and predictions
**So that** I can proactively soothe before crying escalates

#### Acceptance Criteria
- [x] AC-US7-01: Dashboard shows current mood with confidence score
- [x] AC-US7-02: Dashboard displays factors contributing to mood assessment
- [x] AC-US7-03: Dashboard shows predictions (e.g., "May get fussy in 30min")
- [x] AC-US7-04: Dashboard provides proactive tips based on patterns
- [x] AC-US7-05: Dashboard integrates with existing app navigation

### US-008: What Works Insights View
**As a** parent
**I want** to see what sounds and strategies work best for my baby
**So that** I can understand my baby's preferences

#### Acceptance Criteria
- [x] AC-US8-01: View shows top effective sounds per cry type with success rates
- [x] AC-US8-02: View displays discovered preferences (pitch, rhythm, etc.)
- [x] AC-US8-03: View shows effectiveness by category
- [x] AC-US8-04: View highlights recently discovered patterns
- [x] AC-US8-05: View allows filtering by time period

---

## Technical Architecture

### New Files to Create

1. **Models/**
   - `BabyMoodProfile.swift` - Comprehensive baby profile model

2. **Services/**
   - `CryAudioEmbedder.swift` - Advanced audio feature extraction
   - `ContextSignalCollector.swift` - Context gathering service
   - `BabyMoodLLMEngine.swift` - LLM reasoning integration
   - `DynamicSoundMixer.swift` - Multi-layer sound mixing
   - `AdaptiveFeedbackLoop.swift` - Continuous learning system
   - `BabyMoodIntelligence.swift` - Main orchestrator

3. **Views/**
   - `BabyMoodDashboardView.swift` - Mood dashboard UI
   - `WhatWorksInsightsView.swift` - Insights view (rename existing or new)

### Integration Points

- `SmartCryResponseEngine.swift` - Update to use BabyMIM as primary decision maker
- `CryDetectionService.swift` - Provide audio data to CryAudioEmbedder
- `AudioEngine.swift` - Support dynamic sound mixing
- `HomeView.swift` - Add mood dashboard access

---

## Success Metrics

1. **Calming Time Reduction**: 30% faster calming compared to non-personalized approach
2. **Parent Satisfaction**: "It Helped" feedback rate > 80%
3. **Prediction Accuracy**: Mood predictions correct > 70% of the time
4. **Learning Speed**: Meaningful personalization within first 10 crying episodes
