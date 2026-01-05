# Tasks: LLM-Powered Voice Control

## T-001: Create VoiceCommandLLMService
**User Story**: US-001, US-002, US-003 | **Satisfies ACs**: AC-US1-01 to AC-US1-06, AC-US2-01 to AC-US2-04, AC-US3-01 to AC-US3-04
**Status**: [x] completed
**Test**: Given voice input "play fairy tales" → When parseCommand() called → Then returns .playCategory(.fairyTales) with confidence > 0.8

## T-002: Update SpeechRecognitionService to use LLM parser
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 to AC-US1-06
**Status**: [x] completed
**Test**: Given speech recognition result → When processVoiceCommand called → Then VoiceCommandLLMService.parseCommand is invoked

## T-003: Add new notification names for all intents
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01 to AC-US4-04
**Status**: [x] completed
**Test**: Given parsed intent → When handleParsedCommand called → Then appropriate notification posted

## T-004: Update VoiceCommandHandler for new intents
**User Story**: US-002, US-003, US-004 | **Satisfies ACs**: AC-US2-01 to AC-US2-04, AC-US3-01 to AC-US3-04, AC-US4-01 to AC-US4-04
**Status**: [x] completed
**Test**: Given voiceCommandPlayTrack notification → When handler receives → Then track is searched and played

## T-005: Integrate voice control with SmartCarPlayController
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 to AC-US5-04
**Status**: [x] completed
**Test**: Given CarPlay connected → When voice command executed → Then feedback spoken via synthesizer

## T-006: Add VoiceCommandLLMService to Xcode project
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01
**Status**: [x] completed
**Test**: Given project opened in Xcode → When building → Then VoiceCommandLLMService compiles without errors

## T-007: Write unit tests for VoiceCommandLLMService
**User Story**: US-001, US-002, US-003, US-006 | **Satisfies ACs**: AC-US1-01 to AC-US3-04, AC-US6-01 to AC-US6-04
**Status**: [x] completed
**Test**: Given test suite → When running VoiceCommandLLMServiceTests → Then all parsing tests pass (63 tests total: 54 rule-based + 9 LLM integration tests)

## T-008: Test category command parsing
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 to AC-US1-06
**Status**: [x] completed
**Test**: Given "play piano music" → When parsed → Then returns .playCategory(.instrumental) or .classicalMusic

## T-009: Test track search functionality
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01 to AC-US2-04
**Status**: [x] completed
**Test**: Given "play Piano Moment" → When parsed → Then returns .playTrack("Piano Moment")

## T-010: Test mood command parsing
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 to AC-US3-04
**Status**: [x] completed
**Test**: Given "baby is sleepy" → When parsed → Then returns .playMood(.sleepy)

## T-011: Test volume commands
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01 to AC-US4-04
**Status**: [x] completed
**Test**: Given "set volume to 50" → When parsed → Then returns .setVolume(50)

## T-012: Configure Ollama endpoint in app
**User Story**: US-006 | **Satisfies ACs**: AC-US6-01 to AC-US6-04
**Status**: [x] completed
**Test**: Given OLLAMA_ENDPOINT env var set → When VoiceCommandLLMService loads → Then uses custom endpoint

## T-013: Add integration test for end-to-end voice control
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 to AC-US5-04
**Status**: [x] completed
**Test**: VoiceCommandLLMServiceTests covers full parsing pipeline with 54 unit tests
