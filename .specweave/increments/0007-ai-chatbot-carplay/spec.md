# AI Chatbot & Smart CarPlay - Intelligent Library Discovery & Adaptive Music

## Overview

This increment adds an AI-powered chatbot for intelligent library search/discovery and a Smart CarPlay mode that adapts music based on baby sounds AND environmental signals (car engine, wheel noise, road conditions). Based on scientific research showing:
- Baby cries can be classified with 90-96% accuracy using ML/AI
- Different cry types respond better to different sounds
- Car engine sounds calm babies (Honda research: 11/12 babies calmed, 7 showed reduced heart rate)
- Environmental sounds (tire noise, engine hum) can complement or replace artificial soothing sounds

## Epic: FS-007 - AI Chatbot & Smart CarPlay System

### Problem Statement

Current library browsing requires manual searching. Parents don't know:
- What sounds work best for their specific baby's cry type
- How environmental sounds (car motion, road noise) affect soothing effectiveness
- When to let natural car sounds do the work vs playing additional sounds
- How to get personalized recommendations based on their baby's learned preferences

### Solution

Build an intelligent system with:
1. **AI Chatbot** for natural language library discovery ("Find sounds for tired baby", "What worked best for hunger cries?")
2. **Environment Sound Detector** that analyzes car sounds (engine RPM equivalent, tire/road noise, motion patterns)
3. **Smart CarPlay Controller** that auto-adjusts music based on baby + environment signals
4. **Research-Based Recommendations** citing scientific evidence for why certain sounds work

---

## User Stories

### US-001: AI Library Chatbot
**As a** parent
**I want** to ask the app in natural language what sounds to play
**So that** I can quickly find the right sounds without browsing

#### Acceptance Criteria
- [x] AC-US1-01: LibraryChatbotService processes natural language queries using LLM
- [x] AC-US1-02: Chatbot suggests tracks based on baby's learned profile (from BabyMIM)
- [x] AC-US1-03: Chatbot explains WHY each recommendation is made (citing research or history)
- [x] AC-US1-04: Chatbot supports queries like "What worked last time?", "Sounds for sleepy baby"
- [x] AC-US1-05: Chatbot integrates with existing ContentLibraryService for track lookup

### US-002: Environment Sound Detection
**As a** developer
**I want** to detect and analyze environmental sounds in the car
**So that** the system can use car sounds as part of the soothing strategy

#### Acceptance Criteria
- [x] AC-US2-01: EnvironmentSoundDetector runs parallel to CryDetectionService without interference
- [x] AC-US2-02: Detector identifies car engine sounds and estimates "soothing level" (low rumble = good)
- [x] AC-US2-03: Detector identifies road/tire noise patterns (highway smooth vs city bumpy)
- [x] AC-US2-04: Detector provides real-time environment score (0-1) for how soothing the ambient car sounds are
- [x] AC-US2-05: Detector tracks motion patterns (stops, acceleration, steady cruise)

### US-003: Smart CarPlay Integration
**As a** parent using CarPlay
**I want** the app to automatically adjust music based on baby AND car sounds
**So that** I can focus on driving while the baby is optimally soothed

#### Acceptance Criteria
- [x] AC-US3-01: SmartCarPlayController monitors both baby audio and environment audio
- [x] AC-US3-02: Controller reduces music volume when car sounds are already soothing (highway cruise)
- [x] AC-US3-03: Controller increases/changes music when car sounds are insufficient (stopped, quiet EV)
- [x] AC-US3-04: Controller provides voice feedback ("Road sounds are helping, lowering music")
- [x] AC-US3-05: Controller integrates with existing CarPlay audio session

### US-004: Research-Based Recommendations
**As a** parent
**I want** to understand WHY the app recommends certain sounds
**So that** I trust the recommendations and learn about my baby's preferences

#### Acceptance Criteria
- [x] AC-US4-01: Recommendations include scientific reasoning (e.g., "Pink noise mimics womb at 90dB")
- [x] AC-US4-02: Recommendations reference baby's personal history ("This worked 85% of the time for tired cries")
- [x] AC-US4-03: System explains environment-aware decisions ("Car engine providing low-frequency soothing")
- [x] AC-US4-04: Research citations stored in app for key claims (Harvey Karp 5 S's, Honda study, etc.)

### US-005: Chatbot UI
**As a** parent
**I want** a chat interface to interact with the AI assistant
**So that** I can get recommendations conversationally

#### Acceptance Criteria
- [x] AC-US5-01: ChatbotView provides message-style interface with AI responses
- [x] AC-US5-02: UI shows quick action buttons for common queries ("What works best?", "Play something calming")
- [x] AC-US5-03: UI displays currently playing track with "Why this?" explanation button
- [x] AC-US5-04: Chat history persists across sessions for context
- [x] AC-US5-05: Voice input supported via existing SpeechRecognitionService

---

## Technical Architecture

### New Files to Create

1. **Services/**
   - `LibraryChatbotService.swift` - LLM-powered natural language processing for library queries
   - `EnvironmentSoundDetector.swift` - Parallel audio analysis for car/environment sounds
   - `SmartCarPlayController.swift` - Intelligent CarPlay mode with environment awareness
   - `ResearchKnowledgeBase.swift` - Scientific research citations and explanations

2. **Views/**
   - `ChatbotView.swift` - Conversational UI for AI assistant
   - `ChatMessageView.swift` - Individual message bubble component
   - `QuickActionButtons.swift` - Common query shortcuts

3. **Models/**
   - `ChatMessage.swift` - Chat message model
   - `EnvironmentState.swift` - Car environment state model
   - `ResearchCitation.swift` - Scientific research citation model

### Integration Points

- `BabyMoodIntelligence.swift` - Get baby profile and preferences
- `BabyMoodLLMEngine.swift` - Use existing LLM integration for chatbot
- `CryDetectionService.swift` - Coordinate audio input sharing
- `ContentLibraryService.swift` - Track search and metadata
- `AudioEngine.swift` - Playback control from CarPlay

### Key Algorithms

1. **Environment Sound Analysis**
   - FFT analysis focused on 20-500Hz (engine/road frequencies)
   - Motion detection via accelerometer
   - Noise floor estimation for car cabin
   - Soothing score based on:
     - Low frequency power (engine rumble)
     - Consistency (steady vs variable)
     - Absence of jarring sounds

2. **Smart Volume Control**
   ```
   effectiveVolume = baseVolume * (1 - environmentSoothingScore * 0.6)
   // When car sounds are 100% soothing, reduce music to 40%
   // When car is quiet (parked), keep music at 100%
   ```

3. **Chatbot Intent Recognition**
   - Query classification: search, recommendation, explanation, history
   - Entity extraction: cry type, sound type, time period
   - Context awareness: current baby state, time of day

---

## Research Knowledge Base

### Key Research to Include

1. **Honda Sound Sitter Study**
   - 37 engines tested, NSX most effective
   - 11/12 babies calmed, 7 reduced heart rate
   - Low frequencies match womb sounds

2. **Dr. Harvey Karp's 5 S's**
   - Shushing must match cry volume
   - Womb is 90dB (vacuum cleaner level)
   - Rhythm triggers calming reflex

3. **White/Pink/Brown Noise Research**
   - White noise: 80% fell asleep in 5min (1990 study)
   - Pink noise: deeper sleep, stress reduction
   - Brown noise: promotes REM sleep

4. **Baby Cry Classification**
   - MFCC + ML: 90-96% accuracy
   - Different cry types have distinct acoustic signatures
   - Hungry: rhythmic, low pitch
   - Pain: high pitch, erratic
   - Tired: monotonous, falling melody

---

## Success Metrics

1. **Chatbot Engagement**: 30% of users use chatbot at least weekly
2. **Query Success Rate**: 80% of queries result in track playback
3. **CarPlay Smart Mode Adoption**: 50% of CarPlay sessions use smart mode
4. **Reduced Manual Intervention**: 40% fewer manual track changes in CarPlay

---

## Implementation Notes

### Audio Session Management
- Use `AVAudioSession` category `.playAndRecord` with `.mixWithOthers`
- Environment detection runs on separate audio tap
- Priority: cry detection > music playback > environment analysis

### CarPlay Specifics
- Use `CPNowPlayingTemplate` for playback controls
- Voice feedback via `AVSpeechSynthesizer`
- Respect CarPlay audio focus rules

### Privacy
- Environment analysis is local-only (no cloud)
- Chat history stored locally
- Opt-in for cloud LLM features
