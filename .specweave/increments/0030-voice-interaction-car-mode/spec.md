# FS-030: Voice Interaction & Car Drive Mode

**Version**: 1.0
**Date**: January 18, 2026
**Status**: Planning
**Priority**: High
**Depends On**: FS-029 (Smart Cry-Type Playlist System)

---

## 1. Executive Summary

This feature implements **hands-free voice interaction** for safe operation while driving. When the app is in CarPlay mode, has the microphone active for cry detection, or the user has enabled "Hands-Free Mode", all user confirmations use **voice prompts** (text-to-speech) and **voice recognition** (speech-to-text) instead of touch interaction.

### Core Capabilities

| Capability | Description |
|------------|-------------|
| **Voice Prompts (TTS)** | Speak questions and announcements using AVSpeechSynthesizer |
| **Voice Recognition** | Listen for user responses using SFSpeechRecognizer |
| **CarPlay Integration** | Auto-enable voice mode when CarPlay connects |
| **Audio Ducking** | Lower music volume during voice interaction |
| **Fallback UI** | Show touch UI when voice mode disabled or recognition fails |
| **Multi-Language** | Support device locale for both TTS and recognition |

### Safety Focus

This is a **safety-critical feature** for parents driving with babies:
- No touch interaction required while driving
- Clear voice prompts at appropriate volume
- Short, unambiguous responses ("yes" / "no")
- Graceful timeout handling

---

## 2. System Architecture

### 2.1 High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VOICE INTERACTION SYSTEM                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  VOICE MODE TRIGGERS (any activates voice mode):                            │
│  ├── CarPlay connected (SmartCarPlayController.isActive == true)            │
│  ├── User enabled "Hands-Free Mode" in Settings                             │
│  └── Cry detection microphone already active                                │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 1. EVENT OCCURS (from FS-029)                                         │  │
│  │    ├── Cry type change detected                                       │  │
│  │    ├── Cry stopped (auto-detected)                                    │  │
│  │    └── Pain cry alert                                                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 2. AUDIO DUCKING                                                      │  │
│  │    └── Lower music volume to 20% (via AudioEngine)                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 3. VOICE PROMPT (AVSpeechSynthesizer)                                 │  │
│  │    🔊 "The cry pattern has changed to tired. Would you like me to    │  │
│  │        switch to a tiredness playlist? Say YES or NO."               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 4. VOICE RECOGNITION (SFSpeechRecognizer)                             │  │
│  │    Listen for 5 seconds:                                              │  │
│  │    ├── "Yes" / "Yeah" / "Sure" → Confirm action                      │  │
│  │    ├── "No" / "Nope" / "Keep" → Dismiss prompt                       │  │
│  │    └── Timeout → Repeat once, then auto-dismiss                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 5. CONFIRMATION (Voice)                                               │  │
│  │    🔊 "Okay, switching now." OR "Okay, keeping current playlist."    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                      │                                                       │
│                      ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 6. RESTORE AUDIO                                                      │  │
│  │    └── Restore music volume to 100%                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Voice Mode Decision Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VOICE vs UI MODE DECISION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  When app needs user confirmation:                                          │
│                                                                              │
│  ┌────────────────────────────────────────┐                                 │
│  │ Is Voice Mode Active?                  │                                 │
│  │ ├── CarPlay connected? OR              │                                 │
│  │ ├── Hands-Free Mode enabled? OR        │                                 │
│  │ └── Cry detection mic active?          │                                 │
│  └────────────────────────────────────────┘                                 │
│              │                                                               │
│      YES ────┴──── NO                                                        │
│       │             │                                                        │
│       ▼             ▼                                                        │
│  ┌──────────┐  ┌──────────────────┐                                         │
│  │ Voice    │  │ Touch UI         │                                         │
│  │ Prompt + │  │ CryTypeChange-   │                                         │
│  │ Listen   │  │ PromptView       │                                         │
│  └──────────┘  └──────────────────┘                                         │
│       │                                                                      │
│       ▼                                                                      │
│  ┌──────────────────────────────────────────┐                               │
│  │ Speech Recognition Available?            │                               │
│  │ (SFSpeechRecognizer.authorizationStatus) │                               │
│  └──────────────────────────────────────────┘                               │
│              │                                                               │
│      YES ────┴──── NO                                                        │
│       │             │                                                        │
│       ▼             ▼                                                        │
│  ┌──────────┐  ┌──────────────────┐                                         │
│  │ Listen   │  │ Voice prompt +   │                                         │
│  │ for      │  │ Touch buttons    │                                         │
│  │ response │  │ (hybrid mode)    │                                         │
│  └──────────┘  └──────────────────┘                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Voice Prompts by Context

### 3.1 Prompt Types

| Context | Type | Voice Prompt | Expected Response |
|---------|------|--------------|-------------------|
| **Cry type change** | Question | "The cry pattern has changed to [tired]. Switch playlist? Say yes or no." | "Yes" / "No" |
| **Cry stopped** | Question | "Your baby seems calmer now. Did the music help? Say yes or no." | "Yes" / "No" |
| **Initial detection** | Announcement | "I've detected a [hunger] cry. Starting soothing playlist." | (None) |
| **Pain alert** | Announcement | "Your baby seems very distressed. Please check on them when safe." | (None) |
| **Playlist started** | Announcement | "Playing [tired] playlist now." | (None) |
| **Confirmation** | Announcement | "Okay, switching now." / "Okay, keeping current playlist." | (None) |

### 3.2 Response Recognition

**Affirmative responses** (→ action confirmed):
- "yes", "yeah", "yep", "yup", "uh huh"
- "sure", "okay", "ok", "alright"
- "switch", "change", "do it", "please"

**Negative responses** (→ action dismissed):
- "no", "nope", "nah", "negative"
- "don't", "keep", "stay", "cancel", "stop", "never"

**Unrecognized** (→ timeout handling):
- Any other response or silence

---

## 4. VoiceInteractionService

### 4.1 Service Implementation

```swift
import AVFoundation
import Speech

/// Handles voice prompts and speech recognition for hands-free mode
@MainActor
class VoiceInteractionService: ObservableObject {

    // MARK: - Singleton
    static let shared = VoiceInteractionService()

    // MARK: - Dependencies
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Published State
    @Published private(set) var isVoiceModeActive: Bool = false
    @Published private(set) var isListeningForResponse: Bool = false
    @Published private(set) var isSpeaking: Bool = false
    @Published var lastSpokenPrompt: String?
    @Published var lastRecognizedResponse: String?

    // MARK: - Configuration
    struct Configuration {
        var responseTimeout: TimeInterval = 5.0
        var maxRetries: Int = 1
        var voiceVolume: Float = 0.8
        var voiceRate: Float = 0.45  // Slightly slower than default (0.5)
        var duckMusicToVolume: Float = 0.2
        var preferredLanguage: String? = nil  // nil = device locale
    }

    var configuration = Configuration()

    // MARK: - Voice Mode Triggers

    func updateVoiceModeStatus() {
        isVoiceModeActive =
            SmartCarPlayController.shared.isActive ||
            UserPreferences.shared.handsFreeModeEnabled ||
            CryClassificationService.shared.isListening
    }

    // MARK: - Public API

    /// Ask a yes/no question with voice prompt and recognition
    func askYesNoQuestion(
        prompt: String,
        retryCount: Int = 0
    ) async -> VoiceResponse {
        updateVoiceModeStatus()

        guard isVoiceModeActive else {
            return .fallbackToUI
        }

        // 1. Duck music
        let previousVolume = AudioEngine.shared.currentVolume
        await AudioEngine.shared.setVolume(configuration.duckMusicToVolume)

        // 2. Speak prompt
        await speak(prompt)

        // 3. Listen for response
        guard await requestSpeechRecognitionPermission() else {
            await AudioEngine.shared.setVolume(previousVolume)
            return .fallbackToUI
        }

        let recognizedText = await listenForResponse(timeout: configuration.responseTimeout)

        // 4. Categorize response
        let category = categorizeResponse(recognizedText)

        // 5. Handle result
        switch category {
        case .yes:
            await speak("Okay, switching now.")
            await AudioEngine.shared.setVolume(previousVolume)
            return .yes

        case .no:
            await speak("Okay, keeping the current playlist.")
            await AudioEngine.shared.setVolume(previousVolume)
            return .no

        case .unknown:
            if retryCount < configuration.maxRetries {
                await speak("I didn't catch that.")
                return await askYesNoQuestion(prompt: prompt, retryCount: retryCount + 1)
            } else {
                await speak("No response detected. Keeping current settings.")
                await AudioEngine.shared.setVolume(previousVolume)
                return .timeout
            }
        }
    }

    /// Announce information without expecting a response
    func announce(_ message: String) async {
        updateVoiceModeStatus()
        guard isVoiceModeActive else { return }

        let previousVolume = AudioEngine.shared.currentVolume
        await AudioEngine.shared.setVolume(configuration.duckMusicToVolume + 0.1)  // Slightly higher for announcements
        await speak(message)
        await AudioEngine.shared.setVolume(previousVolume)
    }

    // MARK: - Speech Synthesis

    private func speak(_ text: String) async {
        lastSpokenPrompt = text
        isSpeaking = true

        let utterance = AVSpeechUtterance(string: text)

        // Configure voice
        let languageCode = configuration.preferredLanguage ??
                          Locale.current.language.languageCode?.identifier ?? "en"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = configuration.voiceRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = configuration.voiceVolume
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        await withCheckedContinuation { continuation in
            // Use delegate to know when speech finishes
            let delegate = SpeechDelegate {
                continuation.resume()
            }
            speechSynthesizer.delegate = delegate
            speechSynthesizer.speak(utterance)
        }

        isSpeaking = false
    }

    // MARK: - Speech Recognition

    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func listenForResponse(timeout: TimeInterval) async -> String? {
        isListeningForResponse = true
        defer { isListeningForResponse = false }

        let locale = Locale(identifier: configuration.preferredLanguage ?? Locale.current.identifier)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            return nil
        }

        // Configure for short, confirmation-style responses
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .confirmation
        recognitionRequest.requiresOnDeviceRecognition = false  // Allow cloud for better accuracy

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            var bestTranscription: String?

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    bestTranscription = result.bestTranscription.formattedString
                    self.lastRecognizedResponse = bestTranscription

                    // Early exit if we get a definitive yes/no
                    if self.isDefinitiveResponse(bestTranscription) && !hasResumed {
                        hasResumed = true
                        self.stopListening()
                        continuation.resume(returning: bestTranscription)
                    }
                }

                if error != nil || result?.isFinal == true {
                    if !hasResumed {
                        hasResumed = true
                        self.stopListening()
                        continuation.resume(returning: bestTranscription)
                    }
                }
            }

            // Start audio capture
            do {
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    self.recognitionRequest?.append(buffer)
                }

                audioEngine.prepare()
                try audioEngine.start()
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
                return
            }

            // Timeout handler
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasResumed {
                    hasResumed = true
                    self.stopListening()
                    continuation.resume(returning: bestTranscription)
                }
            }
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    // MARK: - Response Categorization

    private func categorizeResponse(_ response: String?) -> ResponseCategory {
        guard let text = response?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .unknown
        }

        let yesWords = ["yes", "yeah", "yep", "yup", "sure", "okay", "ok", "alright",
                       "switch", "change", "do it", "please", "uh huh", "affirmative"]
        let noWords = ["no", "nope", "nah", "negative", "don't", "keep", "stay",
                      "cancel", "stop", "never", "not"]

        // Check for yes words
        for word in yesWords {
            if text.contains(word) { return .yes }
        }

        // Check for no words
        for word in noWords {
            if text.contains(word) { return .no }
        }

        return .unknown
    }

    private func isDefinitiveResponse(_ response: String?) -> Bool {
        categorizeResponse(response) != .unknown
    }
}

// MARK: - Supporting Types

enum VoiceResponse {
    case yes
    case no
    case timeout
    case fallbackToUI
}

private enum ResponseCategory {
    case yes
    case no
    case unknown
}

// MARK: - Speech Delegate

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
}
```

---

## 5. Integration Points

### 5.1 Cry Type Change (from FS-029)

```swift
// Called by CryTypeStabilizer when cry type changes

func handleCryTypeChange(from oldType: CryType, to newType: CryType, confidence: Double) async {
    let voiceService = VoiceInteractionService.shared

    let prompt = "The cry pattern has changed. It now sounds like your baby might be \(newType.displayName.lowercased()). Would you like me to switch to a \(newType.displayName.lowercased()) playlist? Say yes or no."

    let response = await voiceService.askYesNoQuestion(prompt: prompt)

    switch response {
    case .yes:
        await SmartPlaylistGenerator.shared.regeneratePlaylist(for: newType)

    case .no, .timeout:
        // Keep current playlist
        CryTypeStabilizer.shared.muteChangeDetection(for: 300)  // 5 minutes

    case .fallbackToUI:
        // Show touch UI
        NotificationCenter.default.post(
            name: .showCryTypeChangePrompt,
            object: nil,
            userInfo: ["oldType": oldType, "newType": newType, "confidence": confidence]
        )
    }
}
```

### 5.2 Cry Stopped Detection (from FS-029)

```swift
// Called when cry-stop is auto-detected

func handleCryStoppedDetection() async {
    let voiceService = VoiceInteractionService.shared

    let prompt = "Your baby seems calmer now. Did the music help? Say yes or no."

    let response = await voiceService.askYesNoQuestion(prompt: prompt)

    switch response {
    case .yes:
        FeedbackCollectionService.shared.recordItHelped()
        await voiceService.announce("Great! I'll remember that for next time.")

    case .no:
        FeedbackCollectionService.shared.recordDidNotHelp()

    case .timeout, .fallbackToUI:
        // Show touch UI or do nothing
        if response == .fallbackToUI {
            NotificationCenter.default.post(name: .showCryStoppedPrompt, object: nil)
        }
    }
}
```

### 5.3 CarPlay Connection

```swift
// In SmartCarPlayController

func handleCarPlayConnected() {
    VoiceInteractionService.shared.updateVoiceModeStatus()

    Task {
        await VoiceInteractionService.shared.announce(
            "CarPlay connected. Voice commands are now active."
        )
    }
}

func handleCarPlayDisconnected() {
    VoiceInteractionService.shared.updateVoiceModeStatus()
}
```

---

## 6. User Settings

### 6.1 Settings UI

```swift
struct VoiceInteractionSettingsView: View {
    @AppStorage("handsFreeModeEnabled") private var handsFreeModeEnabled = false
    @AppStorage("voicePromptsEnabled") private var voicePromptsEnabled = true
    @AppStorage("voiceResponsesEnabled") private var voiceResponsesEnabled = true
    @AppStorage("voiceVolume") private var voiceVolume: Double = 0.8
    @AppStorage("autoEnableInCarPlay") private var autoEnableInCarPlay = true

    var body: some View {
        Form {
            Section("Hands-Free Mode") {
                Toggle("Enable Hands-Free Mode", isOn: $handsFreeModeEnabled)
                Text("When enabled, the app will use voice prompts instead of touch interactions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Voice Settings") {
                Toggle("Voice Prompts", isOn: $voicePromptsEnabled)
                Toggle("Voice Responses", isOn: $voiceResponsesEnabled)

                if voiceResponsesEnabled {
                    VStack(alignment: .leading) {
                        Text("Voice Volume: \(Int(voiceVolume * 100))%")
                        Slider(value: $voiceVolume, in: 0.3...1.0)
                    }
                }
            }

            Section("CarPlay") {
                Toggle("Auto-enable in CarPlay", isOn: $autoEnableInCarPlay)
                Text("Automatically enables hands-free mode when CarPlay connects.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Permissions") {
                Button("Configure Speech Recognition") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Voice & Hands-Free")
    }
}
```

### 6.2 Settings Model

```swift
struct VoiceInteractionSettings: Codable {
    var handsFreeModeEnabled: Bool = false
    var voicePromptsEnabled: Bool = true
    var voiceResponsesEnabled: Bool = true
    var voiceVolume: Float = 0.8
    var voiceRate: Float = 0.45
    var preferredLanguage: String? = nil
    var autoEnableInCarPlay: Bool = true
}

extension UserPreferences {
    var handsFreeModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "handsFreeModeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "handsFreeModeEnabled") }
    }

    var voiceSettings: VoiceInteractionSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: "voiceSettings"),
                  let settings = try? JSONDecoder().decode(VoiceInteractionSettings.self, from: data) else {
                return VoiceInteractionSettings()
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "voiceSettings")
            }
        }
    }
}
```

---

## 7. Required Permissions

### 7.1 Info.plist Entries

```xml
<!-- Speech Recognition -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition is used for hands-free voice commands while driving, so you can respond to questions without touching your phone.</string>

<!-- Microphone (already exists for cry detection) -->
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed to detect baby cries and to listen for your voice commands in hands-free mode.</string>
```

### 7.2 Permission Request Flow

```swift
class PermissionManager {
    static func requestVoicePermissions() async -> Bool {
        // 1. Check microphone (should already be granted for cry detection)
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        guard micStatus == .granted else {
            return false
        }

        // 2. Request speech recognition
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
```

---

## 8. Audio Session Management

### 8.1 Audio Session Configuration

```swift
extension AudioSessionManager {
    /// Configure for voice interaction (cry detection + playback + speech)
    func configureForVoiceInteraction() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,  // Optimized for voice
            options: [.defaultToSpeaker, .allowBluetooth]
        )

        try session.setActive(true)
    }

    /// Configure for normal playback (cry detection + playback)
    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            mode: .measurement,  // Good for cry detection
            options: [.defaultToSpeaker]
        )

        try session.setActive(true)
    }
}
```

### 8.2 Audio Ducking

```swift
extension VoiceInteractionService {
    private func duckAudio() async {
        await AudioEngine.shared.setVolume(configuration.duckMusicToVolume, animated: true)
    }

    private func restoreAudio(to volume: Float) async {
        await AudioEngine.shared.setVolume(volume, animated: true)
    }
}
```

---

## 9. Error Handling

### 9.1 Fallback Scenarios

| Scenario | Behavior |
|----------|----------|
| Speech recognition not authorized | Fall back to touch UI |
| Speech recognizer unavailable | Fall back to touch UI |
| Network unavailable (cloud recognition) | Try on-device recognition, then touch UI |
| Audio engine fails | Show error, fall back to touch UI |
| Timeout with no response | Announce "keeping current", dismiss |
| Unrecognized response | Retry once, then timeout |

### 9.2 Error Announcements

```swift
extension VoiceInteractionService {
    func handleError(_ error: VoiceError) async {
        switch error {
        case .speechRecognitionDenied:
            // Don't announce, just fall back silently
            break

        case .networkUnavailable:
            await announce("Voice commands unavailable. Please use touch controls.")

        case .audioSessionFailed:
            await announce("Audio error. Please check your device.")

        case .recognitionFailed:
            await announce("I couldn't hear you clearly. Please try again.")
        }
    }
}

enum VoiceError: Error {
    case speechRecognitionDenied
    case networkUnavailable
    case audioSessionFailed
    case recognitionFailed
}
```

---

## 10. Acceptance Criteria

### 10.1 Voice Prompts

- [ ] **AC-FS030-01**: Voice prompts use AVSpeechSynthesizer with configurable volume and rate
- [ ] **AC-FS030-02**: Voice prompts automatically duck music volume to 20%
- [ ] **AC-FS030-03**: Music volume restores after voice interaction completes
- [ ] **AC-FS030-04**: Voice prompts support device locale language

### 10.2 Voice Recognition

- [ ] **AC-FS030-05**: SFSpeechRecognizer listens for user responses after prompts
- [ ] **AC-FS030-06**: "Yes" variations (yes, yeah, sure, ok) recognized as affirmative
- [ ] **AC-FS030-07**: "No" variations (no, nope, keep, cancel) recognized as negative
- [ ] **AC-FS030-08**: Timeout after 5 seconds if no response detected
- [ ] **AC-FS030-09**: Retry once on unrecognized response before timeout

### 10.3 Voice Mode Triggers

- [ ] **AC-FS030-10**: Voice mode auto-enables when CarPlay connects
- [ ] **AC-FS030-11**: Voice mode enabled when "Hands-Free Mode" setting is on
- [ ] **AC-FS030-12**: Voice mode enabled when cry detection microphone is active
- [ ] **AC-FS030-13**: Falls back to touch UI when voice mode disabled

### 10.4 Integration

- [ ] **AC-FS030-14**: Cry type change (from FS-029) triggers voice prompt in voice mode
- [ ] **AC-FS030-15**: Cry stopped detection (from FS-029) triggers voice prompt
- [ ] **AC-FS030-16**: User can confirm/reject playlist change via voice
- [ ] **AC-FS030-17**: User can confirm "It Helped!" via voice

### 10.5 Settings

- [ ] **AC-FS030-18**: Settings UI allows enabling/disabling hands-free mode
- [ ] **AC-FS030-19**: Settings UI allows configuring voice volume
- [ ] **AC-FS030-20**: Settings UI allows enabling/disabling auto-CarPlay activation

---

## 11. Non-Goals

1. **Complex voice commands** - Only yes/no responses, no "play track X"
2. **Wake word** - No "Hey Lulla" activation
3. **Continuous listening** - Only listen when prompting
4. **Voice identification** - Don't distinguish between parents
5. **Custom TTS voices** - Use system voices only

---

## 12. Dependencies

### 12.1 Internal

| Dependency | From | Required For |
|------------|------|--------------|
| CryTypeStabilizer | FS-029 | Cry type change events |
| FeedbackCollectionService | FS-029 | Recording "It Helped!" |
| SmartCarPlayController | Existing | CarPlay connection status |
| AudioEngine | Existing | Volume ducking |

### 12.2 External

| Framework | Purpose |
|-----------|---------|
| AVFoundation | AVSpeechSynthesizer, audio session |
| Speech | SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest |

---

## 13. Testing Strategy

### 13.1 Unit Tests

```swift
@Suite("VoiceInteractionService")
struct VoiceInteractionServiceTests {

    @Test("Categorizes yes responses correctly")
    func testYesResponses() {
        let service = VoiceInteractionService.shared
        #expect(service.categorizeResponse("yes") == .yes)
        #expect(service.categorizeResponse("Yeah sure") == .yes)
        #expect(service.categorizeResponse("okay switch it") == .yes)
    }

    @Test("Categorizes no responses correctly")
    func testNoResponses() {
        let service = VoiceInteractionService.shared
        #expect(service.categorizeResponse("no") == .no)
        #expect(service.categorizeResponse("nope keep it") == .no)
        #expect(service.categorizeResponse("don't change") == .no)
    }

    @Test("Returns unknown for ambiguous responses")
    func testUnknownResponses() {
        let service = VoiceInteractionService.shared
        #expect(service.categorizeResponse("maybe") == .unknown)
        #expect(service.categorizeResponse("I don't know") == .unknown)
        #expect(service.categorizeResponse("") == .unknown)
    }
}
```

### 13.2 E2E Test (Maestro)

```yaml
# maestro/flows/voice_interaction_flow.yaml
appId: com.anticry.babyincar
---
- launchApp
- tapOn: "Settings"
- tapOn: "Voice & Hands-Free"
- tapOn: "Enable Hands-Free Mode"
- assertVisible: "Voice commands are now active"
- pressKey: home
- launchApp
# Note: Voice recognition testing requires real device
```

---

## 14. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Voice recognition accuracy | >90% | Correct yes/no classification |
| Voice prompt clarity | >95% user understanding | User testing |
| Response time | <2s from prompt end | Timing logs |
| CarPlay adoption | >30% of CarPlay users | Analytics |

---

*Document created: January 18, 2026*
*FS-030: Voice Interaction & Car Drive Mode v1.0*
