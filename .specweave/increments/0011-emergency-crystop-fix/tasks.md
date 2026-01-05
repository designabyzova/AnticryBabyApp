# Tasks for FS-011: Emergency Cry-Stop Intelligence Fix

## Implementation Tasks

### T-001: Fix EmergencyCryStopService.activate() to always use SmartCryResponseEngine
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02 | **Status**: [x] completed
**Test**: Given emergency button tapped → When activate() called → Then SmartCryResponseEngine.activate() is invoked
**Implementation**: Removed condition `if useSmartResponse && isAIMonitoringEnabled` - now always uses SmartCryResponseEngine

### T-002: Add fallback intelligent selection when no cry data available
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03, AC-US1-04, AC-US1-05 | **Status**: [x] completed
**Test**: Given no active cry detection → When emergency activated → Then selects from top 5 historically effective sounds for baby's age
**Implementation**: SmartCryResponseEngine already has 4-level priority fallback system with age-appropriate defaults

### T-003: Implement sound rotation to prevent repetition
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-04 | **Status**: [x] completed
**Test**: Given 3 consecutive emergency activations → When checking sounds played → Then all 3 are different
**Implementation**: Added `recentlyPlayedSounds` tracking, `applyRotation()`, and `applySequenceRotation()` methods

### T-004: Add auto-switch when sound not working
**User Story**: US-002 | **Satisfies ACs**: AC-US2-03 | **Status**: [x] completed
**Test**: Given sound playing for 30s → When baby still crying (simulated) → Then automatically switches to next best sound
**Implementation**: Already implemented in SmartCryResponseEngine's `evaluateEffectiveness()` and `escalateResponse()` methods

### T-005: Ensure "Baby is Calm" records to AdaptiveLearningEngine
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03 | **Status**: [x] completed
**Test**: Given "Baby is Calm" tapped → When checking AdaptiveLearningEngine → Then session recorded with sound type and time-to-calm
**Implementation**: Already implemented in EmergencyModeView.handleBabyIsCalm() - records to AdaptiveLearningEngine.recordSession()

### T-006: Verify learning persists across sessions
**User Story**: US-003 | **Satisfies ACs**: AC-US3-04 | **Status**: [x] completed
**Test**: Given learning recorded → When app restarted → Then learned preferences still available
**Implementation**: AdaptiveLearningEngine uses UserDefaults persistence via saveSessionHistory()

## Testing Tasks

### T-007: Write unit tests for SmartCryResponseEngine activation
**User Story**: US-001 | **Status**: [x] completed
**Test**: Unit tests cover all activation paths
**Implementation**: EmergencyCryStopTests.swift - EmergencyCryStopActivationTests suite

### T-008: Write unit tests for sound rotation logic
**User Story**: US-002 | **Status**: [x] completed
**Test**: Unit tests verify no consecutive duplicates
**Implementation**: EmergencyCryStopTests.swift - EmergencySoundRotationTests suite

### T-009: Write E2E test for emergency button flow
**User Story**: US-001, US-002 | **Status**: [x] completed
**Test**: Maestro test taps emergency button and verifies sound plays
**Implementation**: emergency_sound_rotation_flow.yaml - tests 4 consecutive activations

### T-010: Write E2E test for "Baby is Calm" feedback flow
**User Story**: US-003 | **Status**: [x] completed
**Test**: Maestro test completes emergency session with feedback
**Implementation**: emergency_baby_calm_flow.yaml (pre-existing) + rotation test includes learning flow
