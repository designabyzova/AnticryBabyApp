# Tasks: FS-030 Voice Interaction & Car Drive Mode

**Feature**: FS-030 | **Status**: Completed | **Priority**: High
**Depends On**: FS-029 (Smart Cry-Type Playlist System)
**Overview**: Total Tasks: 23 | Completed: 23 | In Progress: 0 | Pending: 0

---

## User Stories

### US-001: Hands-Free Voice Prompts
**As a** parent driving with my baby,
**I want** the app to speak questions to me instead of showing pop-ups,
**So that** I can keep my eyes on the road.

### US-002: Voice Response Recognition
**As a** parent using voice mode,
**I want** to answer "yes" or "no" by speaking,
**So that** I don't need to touch my phone while driving.

### US-003: Automatic CarPlay Integration
**As a** parent using CarPlay,
**I want** voice mode to automatically enable when CarPlay connects,
**So that** I have a seamless hands-free experience.

### US-004: Voice Interaction Settings
**As a** user,
**I want** to configure voice interaction settings,
**So that** I can customize the experience to my preferences.

---

## Phase 1: Voice Prompt System (TTS)

### T-001: Create VoiceInteractionService with AVSpeechSynthesizer
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-01, AC-FS030-04 | **Status**: [x] completed
**Test**: Given voice mode active → When speak() called → Then AVSpeechSynthesizer speaks text

**Implementation**:
- Create `VoiceInteractionService.swift` in Services/
- Initialize AVSpeechSynthesizer
- Implement `speak(_ text: String) async` method
- Configure voice rate, volume, pitch
- Support device locale language detection

---

### T-002: Implement audio ducking during voice prompts
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-02, AC-FS030-03 | **Status**: [x] completed
**Test**: Given music playing → When voice prompt starts → Then music volume ducks to 20%

**Implementation**:
- Add `duckAudio()` method to VoiceInteractionService
- Store previous volume before ducking
- Add `restoreAudio()` method
- Call duckAudio before speak, restoreAudio after
- Use animated volume transitions

---

### T-003: Create voice prompt templates for all contexts
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-01 | **Status**: [x] completed
**Test**: Given cry type change → When prompt generated → Then returns appropriate text

**Implementation**:
- Create `VoicePromptTemplates.swift`
- Template: cry type change prompt
- Template: cry stopped prompt
- Template: initial detection announcement
- Template: pain alert announcement
- Template: confirmation messages

---

## Phase 2: Speech Recognition

### T-004: Implement SFSpeechRecognizer wrapper
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-05 | **Status**: [x] completed
**Test**: Given speech permission granted → When listenForResponse() called → Then returns recognized text

**Implementation**:
- Add SFSpeechRecognizer to VoiceInteractionService
- Implement `listenForResponse(timeout:) async -> String?`
- Configure for short confirmation responses
- Handle partial results for early exit
- Implement timeout handling

---

### T-005: Implement response categorization (yes/no/unknown)
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-06, AC-FS030-07 | **Status**: [x] completed
**Test**: Given "yeah sure" recognized → When categorized → Then returns .yes

**Implementation**:
- Create ResponseCategory enum (yes, no, unknown)
- Implement `categorizeResponse(_ text: String?) -> ResponseCategory`
- Define yes word list: yes, yeah, yep, sure, okay, switch, change
- Define no word list: no, nope, keep, stay, cancel, don't
- Case-insensitive matching

---

### T-006: Implement askYesNoQuestion flow with retry
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-08, AC-FS030-09 | **Status**: [x] completed
**Test**: Given unknown response → When first attempt → Then retries once

**Implementation**:
- Implement `askYesNoQuestion(prompt:) async -> VoiceResponse`
- Flow: duck → speak → listen → categorize → confirm/retry
- Implement retry logic (max 1 retry)
- Return VoiceResponse enum: yes, no, timeout, fallbackToUI
- Handle all edge cases

---

### T-007: Request speech recognition permission
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-05 | **Status**: [x] completed
**Test**: Given permission not requested → When voice mode activates → Then permission requested

**Implementation**:
- Add Info.plist NSSpeechRecognitionUsageDescription
- Implement `requestSpeechRecognitionPermission() async -> Bool`
- Handle .authorized, .denied, .restricted, .notDetermined
- Fall back to UI if denied

---

## Phase 3: Voice Mode Triggers

### T-008: Implement isVoiceModeActive computed property
**User Story**: US-003 | **Satisfies ACs**: AC-FS030-10, AC-FS030-11, AC-FS030-12 | **Status**: [x] completed
**Test**: Given CarPlay active → When checked → Then isVoiceModeActive == true

**Implementation**:
- Check SmartCarPlayController.shared.isActive
- Check UserPreferences.shared.handsFreeModeEnabled
- Check CryClassificationService.shared.isListening
- Return true if any condition met

---

### T-009: Connect CarPlay events to voice mode
**User Story**: US-003 | **Satisfies ACs**: AC-FS030-10 | **Status**: [x] completed
**Test**: Given CarPlay connects → When detected → Then voice mode updates

**Implementation**:
- Modify SmartCarPlayController.activate() to call updateVoiceModeStatus()
- Modify SmartCarPlayController.deactivate() similarly
- Announce "CarPlay connected. Voice commands active." on connect

---

### T-010: Implement fallback to touch UI
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-13 | **Status**: [x] completed
**Test**: Given voice mode disabled → When confirmation needed → Then shows touch UI

**Implementation**:
- In askYesNoQuestion, check isVoiceModeActive first
- If false, return .fallbackToUI
- Caller posts notification to show appropriate UI view
- Define notifications: .showCryTypeChangePrompt, .showCryStoppedPrompt

---

## Phase 4: Integration with FS-029

### T-011: Connect cry type change to voice prompt
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-14, AC-FS030-16 | **Status**: [x] completed
**Test**: Given cry type changes in voice mode → When detected → Then voice prompt plays

**Implementation**:
- Create `handleCryTypeChange(from:to:confidence:) async` function
- Generate prompt from template
- Call askYesNoQuestion
- On .yes: regenerate playlist
- On .no/.timeout: mute change detection 5 min
- On .fallbackToUI: post notification

---

### T-012: Connect cry stopped detection to voice prompt
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-15, AC-FS030-17 | **Status**: [x] completed
**Test**: Given cry stops in voice mode → When detected → Then asks "Did it help?"

**Implementation**:
- Create `handleCryStoppedDetection() async` function
- Generate "Did the music help?" prompt
- Call askYesNoQuestion
- On .yes: record helped, announce confirmation
- On .no: record did not help
- On .fallbackToUI: post notification

---

### T-013: Announce initial cry detection
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-01 | **Status**: [x] completed
**Test**: Given cry detected in voice mode → When stable → Then announces cry type

**Implementation**:
- Create `handleCryDetected(cryType:) async` function
- Announce "I've detected a [hunger] cry. Starting playlist."
- No response expected (announcement only)
- Call from CryTypeStabilizer when stable type confirmed

---

## Phase 5: Settings UI

### T-014: Create VoiceInteractionSettingsView
**User Story**: US-004 | **Satisfies ACs**: AC-FS030-18, AC-FS030-19, AC-FS030-20 | **Status**: [x] completed
**Test**: Given settings view → When rendered → Then shows all voice options

**Implementation**:
- Create `VoiceInteractionSettingsView.swift` in Views/Settings/
- Toggle: Enable Hands-Free Mode
- Toggle: Voice Prompts
- Toggle: Voice Responses
- Slider: Voice Volume
- Toggle: Auto-enable in CarPlay
- Link to speech recognition settings

---

### T-015: Implement VoiceInteractionSettings model
**User Story**: US-004 | **Satisfies ACs**: AC-FS030-18 | **Status**: [x] completed
**Test**: Given settings changed → When saved → Then persists to UserDefaults

**Implementation**:
- Create VoiceInteractionSettings struct (Codable)
- Properties: handsFreeModeEnabled, voicePromptsEnabled, voiceResponsesEnabled, voiceVolume, voiceRate, autoEnableInCarPlay
- Add extension to UserPreferences for voiceSettings
- Wire up @AppStorage in settings view

---

### T-016: Add Voice settings to main Settings menu
**User Story**: US-004 | **Satisfies ACs**: AC-FS030-18 | **Status**: [x] completed
**Test**: Given settings screen → When viewed → Then shows "Voice & Hands-Free" row

**Implementation**:
- Add NavigationLink to ProfileView/SettingsView
- Icon: waveform.and.mic or car
- Title: "Voice & Hands-Free"
- Navigate to VoiceInteractionSettingsView

---

## Phase 6: Error Handling & Polish

### T-017: Implement error handling for voice failures
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-13 | **Status**: [x] completed
**Test**: Given speech recognition fails → When error occurs → Then falls back to UI

**Implementation**:
- Define VoiceError enum
- Handle: speechRecognitionDenied, networkUnavailable, audioSessionFailed, recognitionFailed
- Announce appropriate error messages
- Fall back to touch UI on fatal errors

---

### T-018: Configure audio session for voice interaction
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-02 | **Status**: [x] completed
**Test**: Given voice prompt starting → When audio session configured → Then uses voiceChat mode

**Implementation**:
- Add `configureForVoiceInteraction()` to AudioSessionManager
- Use category: .playAndRecord, mode: .voiceChat
- Options: .defaultToSpeaker, .allowBluetooth
- Restore to normal mode after interaction

---

### T-019: Add localization support for voice prompts
**User Story**: US-001 | **Satisfies ACs**: AC-FS030-04 | **Status**: [x] completed
**Test**: Given device in Spanish → When prompt generated → Then uses Spanish

**Implementation**:
- Add voice prompt strings to Localizable.xcstrings
- Support: English, Spanish, Russian (primary languages)
- Use Locale.current for TTS voice selection
- Use same locale for speech recognition

---

## Phase 7: Testing

### T-020: Write unit tests for VoiceInteractionService
**User Story**: US-002 | **Satisfies ACs**: AC-FS030-06, AC-FS030-07 | **Status**: [x] completed
**Test**: Given test cases → When categorizeResponse called → Then correct category returned

**Implementation**:
- Test yes word recognition
- Test no word recognition
- Test unknown/ambiguous responses
- Test empty/nil responses
- Test case insensitivity

---

### T-021: Write unit tests for voice mode triggers
**User Story**: US-003 | **Satisfies ACs**: AC-FS030-10, AC-FS030-11, AC-FS030-12 | **Status**: [x] completed
**Test**: Given CarPlay active → When isVoiceModeActive checked → Then returns true

**Implementation**:
- Mock SmartCarPlayController
- Mock UserPreferences
- Mock CryClassificationService
- Test all trigger combinations

---

### T-022: Write integration tests for voice + FS-029 flow
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-FS030-14, AC-FS030-15 | **Status**: [x] completed
**Test**: Given cry type changes → When voice mode active → Then full flow completes

**Implementation**:
- Mock VoiceInteractionService responses
- Test handleCryTypeChange with .yes response
- Test handleCryTypeChange with .no response
- Test handleCryStoppedDetection flow

---

### T-023: Create E2E Maestro flow for voice settings
**User Story**: US-004 | **Satisfies ACs**: AC-FS030-18 | **Status**: [x] completed
**Test**: Given app launched → When settings opened → Then voice options visible

**Implementation**:
- Create `maestro/flows/voice_settings_flow.yaml`
- Navigate to Settings
- Navigate to Voice & Hands-Free
- Toggle hands-free mode
- Verify options visible

---

## Summary

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1: Voice Prompts (TTS) | T-001 to T-003 | [x] 3/3 |
| Phase 2: Speech Recognition | T-004 to T-007 | [x] 4/4 |
| Phase 3: Voice Mode Triggers | T-008 to T-010 | [x] 3/3 |
| Phase 4: Integration with FS-029 | T-011 to T-013 | [x] 3/3 |
| Phase 5: Settings UI | T-014 to T-016 | [x] 3/3 |
| Phase 6: Error Handling | T-017 to T-019 | [x] 3/3 |
| Phase 7: Testing | T-020 to T-023 | [x] 4/4 |
| **Total** | **23 tasks** | **23/23** |

---

*Tasks created: January 18, 2026*
*FS-030: Voice Interaction & Car Drive Mode*
