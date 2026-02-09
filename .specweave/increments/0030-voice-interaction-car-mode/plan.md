# Implementation Plan: FS-030 Voice Interaction & Car Drive Mode

**Feature**: FS-030 | **Created**: January 18, 2026
**Depends On**: FS-029 (Smart Cry-Type Playlist System)

---

## Overview

This plan implements hands-free voice interaction for safe driving scenarios. The feature builds upon FS-029's cry detection and playlist system, adding voice prompts (TTS) and voice recognition (STT) for touch-free confirmation dialogs.

---

## Implementation Phases

### Phase 1: Voice Prompts (TTS) - Tasks T-001 to T-003

**Goal**: Implement text-to-speech prompts with audio ducking

**Approach**:
1. **VoiceInteractionService** - Singleton service managing all voice interaction
   - AVSpeechSynthesizer for TTS
   - Configurable volume, rate, language
   - File: `Services/VoiceInteractionService.swift`

2. **Audio Ducking** - Lower music during voice prompts
   - Store previous volume
   - Duck to 20% before speaking
   - Restore after interaction complete
   - Use animated transitions for smooth UX

3. **Prompt Templates** - Predefined text for each scenario
   - Cry type change: "The cry pattern has changed to [X]. Switch playlist?"
   - Cry stopped: "Your baby seems calmer. Did the music help?"
   - Announcements: No response needed

**Key Code**:
```swift
func speak(_ text: String) async {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
    utterance.rate = 0.45  // Slightly slow for clarity
    utterance.volume = 0.8
    speechSynthesizer.speak(utterance)
}
```

---

### Phase 2: Speech Recognition - Tasks T-004 to T-007

**Goal**: Implement SFSpeechRecognizer for yes/no responses

**Approach**:
1. **SFSpeechRecognizer Wrapper**
   - Configure for short confirmation responses
   - Enable partial results for early matching
   - 5-second timeout
   - File: Part of `VoiceInteractionService.swift`

2. **Response Categorization**
   - Yes words: yes, yeah, yep, sure, okay, switch, change
   - No words: no, nope, keep, stay, cancel, don't
   - Unknown: anything else → retry once

3. **Permission Handling**
   - Request speech recognition permission
   - Fall back to touch UI if denied
   - Update Info.plist descriptions

**Key Code**:
```swift
func categorizeResponse(_ text: String?) -> ResponseCategory {
    guard let text = text?.lowercased() else { return .unknown }

    let yesWords = ["yes", "yeah", "sure", "okay", "switch"]
    let noWords = ["no", "nope", "keep", "stay", "cancel"]

    if yesWords.contains(where: text.contains) { return .yes }
    if noWords.contains(where: text.contains) { return .no }
    return .unknown
}
```

---

### Phase 3: Voice Mode Triggers - Tasks T-008 to T-010

**Goal**: Auto-enable voice mode based on context

**Triggers**:
1. **CarPlay Connected** - SmartCarPlayController.isActive
2. **Hands-Free Setting** - UserPreferences.handsFreeModeEnabled
3. **Mic Active** - CryClassificationService.isListening

**Approach**:
- `isVoiceModeActive` computed property checks all triggers
- Update status when any trigger changes
- Fall back to touch UI when voice mode disabled

**Integration Points**:
- SmartCarPlayController.activate() → updateVoiceModeStatus()
- SmartCarPlayController.deactivate() → updateVoiceModeStatus()
- Settings toggle → updateVoiceModeStatus()

---

### Phase 4: Integration with FS-029 - Tasks T-011 to T-013

**Goal**: Connect voice interaction to cry detection events

**Integration Points**:

1. **Cry Type Change** (from CryTypeStabilizer)
   ```swift
   // When cry type changes
   await handleCryTypeChange(from: .hunger, to: .tired, confidence: 0.85)
   ```

2. **Cry Stopped** (from FeedbackCollectionService)
   ```swift
   // When silence detected for 60 seconds
   await handleCryStoppedDetection()
   ```

3. **Initial Detection** (from CryClassificationService)
   ```swift
   // When cry type stabilizes
   await handleCryDetected(cryType: .hunger)
   ```

**Flow**:
```
Event → isVoiceModeActive?
    YES → askYesNoQuestion() → Handle response
    NO  → Post notification → Show touch UI
```

---

### Phase 5: Settings UI - Tasks T-014 to T-016

**Goal**: Allow users to configure voice interaction

**Settings**:
- Enable Hands-Free Mode (toggle)
- Voice Prompts (toggle)
- Voice Responses (toggle)
- Voice Volume (slider)
- Auto-enable in CarPlay (toggle)

**Files**:
- `Views/Settings/VoiceInteractionSettingsView.swift`
- Extension to UserPreferences

---

### Phase 6: Error Handling - Tasks T-017 to T-019

**Goal**: Graceful degradation and localization

**Error Scenarios**:
| Error | Handling |
|-------|----------|
| Speech recognition denied | Fall back to touch UI |
| Network unavailable | Try on-device, then touch UI |
| Audio session failed | Announce error, touch UI |
| Recognition failed | Retry once, then timeout |

**Audio Session**:
- Configure .playAndRecord with .voiceChat mode
- Optimize for speech quality
- Restore normal mode after interaction

**Localization**:
- Add prompts to Localizable.xcstrings
- Support: English, Spanish, Russian
- Use device locale for TTS voice

---

### Phase 7: Testing - Tasks T-020 to T-023

**Goal**: Comprehensive test coverage

**Unit Tests**:
- Response categorization (yes/no/unknown)
- Voice mode triggers
- Error handling

**Integration Tests**:
- Full cry type change flow
- Cry stopped flow
- Settings persistence

**E2E (Maestro)**:
- Settings navigation
- Toggle verification
- Note: Voice recognition requires real device

---

## File Structure

```
BabyInCarApp/
├── Services/
│   └── VoiceInteractionService.swift     (NEW)
├── Views/
│   └── Settings/
│       └── VoiceInteractionSettingsView.swift  (NEW)
├── Models/
│   └── VoiceInteractionSettings.swift    (NEW - or extension)
└── Resources/
    └── Localizable.xcstrings             (MODIFY - add prompts)

BabyInCarApp/Info.plist                   (MODIFY - add permission)

maestro/flows/
└── voice_settings_flow.yaml              (NEW)
```

---

## Dependencies

### From FS-029

| Component | Purpose |
|-----------|---------|
| CryTypeStabilizer | Cry type change events |
| FeedbackCollectionService | "It Helped!" recording |
| SmartPlaylistGenerator | Playlist regeneration |

### Existing

| Component | Purpose |
|-----------|---------|
| SmartCarPlayController | CarPlay connection status |
| AudioEngine | Volume ducking |
| UserPreferences | Settings storage |

### Frameworks

| Framework | Purpose |
|-----------|---------|
| AVFoundation | AVSpeechSynthesizer, audio session |
| Speech | SFSpeechRecognizer |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Speech recognition accuracy < 90% | Limit to simple yes/no, retry once |
| Network unavailable for cloud recognition | Enable on-device fallback |
| User speaks different language | Use device locale, support 3 languages |
| CarPlay audio routing issues | Test thoroughly with car audio |
| Permission denied by user | Graceful fallback to touch UI |

---

## Success Criteria

Before marking increment complete:
- [ ] Voice prompts work with audio ducking
- [ ] Speech recognition recognizes yes/no accurately
- [ ] Voice mode auto-enables in CarPlay
- [ ] Settings UI allows full configuration
- [ ] Falls back to touch UI when voice unavailable
- [ ] All acceptance criteria (20 total) pass
- [ ] Test coverage > 80% for VoiceInteractionService
- [ ] Works in English, Spanish, Russian

---

## Notes

1. **Safety First**: No complex commands - only yes/no
2. **No Wake Word**: Only listen when prompting (not always-on)
3. **Privacy**: No audio stored, only recognized text
4. **CarPlay Priority**: Must work seamlessly in car environment

---

*Plan created: January 18, 2026*
*FS-030: Voice Interaction & Car Drive Mode*
