# Tasks - AI Chatbot & Smart CarPlay

## T-001: Create ResearchKnowledgeBase
**User Story**: US-004 | **Satisfies ACs**: AC-US4-04 | **Status**: [x] completed
**Test**: Given research database → When querying for "car engine" → Then returns Honda study citation

Create ResearchKnowledgeBase.swift with:
- Scientific research citations (Honda, Karp, noise studies)
- Query methods by topic (cry_type, sound_type, technique)
- Localized explanations for parents

---

## T-002: Create EnvironmentState Model
**User Story**: US-002 | **Satisfies ACs**: AC-US2-04 | **Status**: [x] completed
**Test**: Given environment readings → When creating state → Then calculates soothing score correctly

Create EnvironmentState.swift with:
- Engine sound level (0-1)
- Road noise level (0-1)
- Motion type (stopped, city, highway, acceleration)
- Overall soothing score (0-1)
- Timestamp

---

## T-003: Implement EnvironmentSoundDetector
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05 | **Status**: [x] completed
**Test**: Given car highway audio → When analyzing → Then soothing score > 0.7

Create EnvironmentSoundDetector.swift with:
- Parallel audio tap (separate from cry detection)
- FFT analysis for 20-500Hz (engine/road frequencies)
- Accelerometer integration for motion detection
- Real-time EnvironmentState publishing
- Thread-safe audio buffer management

---

## T-004: Create ChatMessage Model
**User Story**: US-005 | **Satisfies ACs**: AC-US5-04 | **Status**: [x] completed
**Test**: Given chat message → When encoding/decoding → Then preserves all fields

Create ChatMessage.swift with:
- id, timestamp, sender (user/assistant)
- message text
- associated action (play track, show info)
- research citations if applicable
- Codable for persistence

---

## T-005: Implement LibraryChatbotService
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03, AC-US1-04, AC-US1-05 | **Status**: [x] completed
**Test**: Given query "tired baby sounds" → When processing → Then returns lullaby recommendations with reasoning

Create LibraryChatbotService.swift with:
- Natural language query processing
- Integration with BabyMoodIntelligence for personalization
- Integration with ContentLibraryService for track lookup
- Research-backed explanations via ResearchKnowledgeBase
- Chat history management
- Intent classification (search, recommend, explain, history)

---

## T-006: Implement SmartCarPlayController
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03, AC-US3-04, AC-US3-05 | **Status**: [x] completed
**Test**: Given highway driving → When baby is calm → Then music volume reduced by environment factor

Create SmartCarPlayController.swift with:
- Combined monitoring (cry + environment)
- Smart volume calculation based on environment soothing score
- Voice feedback via AVSpeechSynthesizer
- CarPlay audio session integration
- Decision logging for transparency

---

## T-007: Create ChatMessageView Component
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed
**Test**: Given message from user → When rendering → Then appears right-aligned with user styling

Create ChatMessageView.swift with:
- Message bubble styling (user vs assistant)
- Timestamp display
- Action button if message has associated action
- Research citation expandable section

---

## T-008: Create QuickActionButtons Component
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02 | **Status**: [x] completed
**Test**: Given quick actions → When tapping "What works best?" → Then sends query to chatbot

Create QuickActionButtons.swift with:
- Horizontal scroll of common queries
- Dynamic buttons based on current context
- Visual feedback on tap
- Integration with LibraryChatbotService

---

## T-009: Create ChatbotView
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01, AC-US5-02, AC-US5-03, AC-US5-04, AC-US5-05 | **Status**: [x] completed
**Test**: Given chatbot view → When sending message → Then response appears with animation

Create ChatbotView.swift with:
- Message list with auto-scroll
- Text input field with send button
- Voice input toggle (existing SpeechRecognitionService)
- Quick action buttons at bottom
- Currently playing track info with "Why this?" button
- Loading state during LLM processing

---

## T-010: Integrate Research Explanations in Recommendations
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03 | **Status**: [x] completed
**Test**: Given pink noise recommendation → When explaining → Then includes womb sounds research

Update BabyMoodLLMEngine or SmartCryResponseEngine to:
- Include scientific reasoning in SoothingRecommendation
- Reference baby's personal history statistics
- Explain environment-aware decisions

---

## T-011: Add Environment Detection to CryDetectionService
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 | **Status**: [x] completed
**Test**: Given both services running → When cry detected → Then no interference with environment detection

Modify CryDetectionService.swift to:
- Allow shared audio session with EnvironmentSoundDetector
- Provide audio buffer access for parallel processing
- Add isEnvironmentDetectionEnabled flag

---

## T-012: Create CarPlay Smart Mode UI
**User Story**: US-003 | **Satisfies ACs**: AC-US3-05 | **Status**: [x] completed
**Test**: Given CarPlay connected → When smart mode enabled → Then shows environment status

Create SmartModeCarPlayTemplate or modify existing CarPlay views:
- Show current environment soothing score
- Show baby state indicator
- Toggle for smart volume mode
- Current decision explanation text

---

## T-013: Unit Tests for EnvironmentSoundDetector
**User Story**: US-002 | **Satisfies ACs**: All US-002 | **Status**: [x] completed
**Test**: Test coverage > 80% for EnvironmentSoundDetector

Create EnvironmentSoundDetectorTests.swift with:
- Test FFT analysis for engine frequencies
- Test soothing score calculation
- Test motion detection integration
- Test concurrent operation with mocked audio

---

## T-014: Unit Tests for LibraryChatbotService
**User Story**: US-001 | **Satisfies ACs**: All US-001 | **Status**: [x] completed
**Test**: Test coverage > 80% for LibraryChatbotService

Create LibraryChatbotServiceTests.swift with:
- Test intent classification
- Test personalized recommendations
- Test research citation inclusion
- Test history context usage

---

## T-015: Unit Tests for SmartCarPlayController
**User Story**: US-003 | **Satisfies ACs**: All US-003 | **Status**: [x] completed
**Test**: Test coverage > 80% for SmartCarPlayController

Create SmartCarPlayControllerTests.swift with:
- Test volume calculation formula
- Test environment + baby state decisions
- Test voice feedback triggers
- Test audio session handling

---

## T-016: E2E Test - Chatbot Flow
**User Story**: US-001, US-005 | **Satisfies ACs**: All US-001, US-005 | **Status**: [x] completed
**Test**: E2E test for chatbot interaction

Create maestro/flows/chatbot_flow.yaml:
- Launch app, navigate to chatbot
- Send natural language query
- Verify response appears
- Tap play button on recommendation
- Verify track starts playing

---

## T-017: Verify Build Succeeds
**User Story**: All | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: xcodebuild succeeds with no errors

Run full build and verify:
- No compilation errors
- No linker errors
- All tests pass
