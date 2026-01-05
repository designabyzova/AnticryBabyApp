# FS-023: LLM-Powered Voice Control for CarPlay

## Problem Statement
Voice control is completely broken - the app hears commands but returns "command not recognized" for natural language inputs like "play fairy tales" or "play piano music". The existing simple keyword matching fails for real user speech patterns.

## Solution
Implement LLM-powered voice command parsing using:
1. **Enhanced rule-based parsing** with fuzzy matching (instant, no API)
2. **Ollama local inference** for complex commands (llama3.2)
3. **Cloud API fallback** when Ollama unavailable

## User Stories

### US-001: Natural Language Command Recognition
**As a** parent driving with my baby
**I want** to speak naturally like "play some fairy tales" or "put on piano music"
**So that** voice control works without memorizing exact commands

**Acceptance Criteria:**
- [x] AC-US1-01: "play fairy tales" maps to Fairy Tales category
- [x] AC-US1-02: "play piano" or "piano music" maps to Instrumental/Classical
- [x] AC-US1-03: "play lullabies" maps to Children's Songs category
- [x] AC-US1-04: "play nature sounds" or "rain" maps to Nature Sounds
- [x] AC-US1-05: "play podcasts" maps to Podcasts category
- [x] AC-US1-06: Fuzzy matching works for partial category names

### US-002: Track Search by Name
**As a** parent who knows a specific song
**I want** to say "play Piano Moment" or the song title
**So that** I can play my favorite tracks by name

**Acceptance Criteria:**
- [x] AC-US2-01: "play [track name]" searches database for matching track
- [x] AC-US2-02: Fuzzy matching finds tracks with partial title matches
- [x] AC-US2-03: Word overlap matching finds tracks ("moment piano" → "Piano Moment")
- [x] AC-US2-04: Feedback indicates what track was found and is playing

### US-003: Mood-Based Playback
**As a** parent describing baby's state
**I want** to say "baby is sleepy" or "calm mode"
**So that** appropriate music plays for the mood

**Acceptance Criteria:**
- [x] AC-US3-01: "sleepy", "bedtime", "naptime" triggers sleepy mood
- [x] AC-US3-02: "crying", "upset" triggers crying mood playlist
- [x] AC-US3-03: "playful", "happy" triggers playful mood
- [x] AC-US3-04: Mood maps to appropriate category automatically

### US-004: Volume and Playback Controls
**As a** hands-free driver
**I want** natural volume commands like "louder" or "volume 50 percent"
**So that** I can control volume without touching the phone

**Acceptance Criteria:**
- [x] AC-US4-01: "louder", "volume up", "turn up" increases volume
- [x] AC-US4-02: "quieter", "softer", "turn down" decreases volume
- [x] AC-US4-03: "volume to 50" or "50 percent" sets specific level
- [x] AC-US4-04: "mute" and "unmute" work correctly

### US-005: CarPlay Voice Integration
**As a** CarPlay user
**I want** voice control enabled by default
**So that** I can control the app while driving safely

**Acceptance Criteria:**
- [x] AC-US5-01: Voice control is enabled automatically in CarPlay
- [x] AC-US5-02: SmartCarPlayController has voice command listeners
- [x] AC-US5-03: Voice feedback speaks command results
- [x] AC-US5-04: Unrecognized commands give helpful suggestions

### US-006: LLM Integration
**As a** developer
**I want** LLM parsing for complex/ambiguous commands
**So that** voice control handles natural speech better

**Acceptance Criteria:**
- [x] AC-US6-01: Ollama endpoint is configurable via environment
- [x] AC-US6-02: LLM parsing kicks in when rule-based confidence < 0.8
- [x] AC-US6-03: Cloud API fallback works when Ollama unavailable
- [x] AC-US6-04: Timeout handling prevents slow responses (5s max)

## Technical Implementation

### Files Created
1. `VoiceCommandLLMService.swift` - LLM-powered command parser
2. Updated `SpeechRecognitionService.swift` - Uses new parser
3. Updated `SmartCarPlayController.swift` - Voice control integration

### Voice Command Intents Supported
- Basic: play, pause, stop, next, previous
- Volume: volumeUp, volumeDown, mute, unmute, setVolume
- Content: playCategory, playMood, playTrack, searchTrack, playPlaylist
- Modes: shuffleOn, shuffleOff, repeatMode, sleepTimer
- Special: emergency, quit

### Category Aliases
| Spoken | Maps To |
|--------|---------|
| fairy tale, stories, story | Fairy Tales |
| classical, mozart, bach, piano music | Classical Music |
| piano, instrumental, music box | Instrumental |
| lullaby, lullabies, kids songs | Children's Songs |
| rain, ocean, nature, forest | Nature Sounds |
| white noise, noise, shushing | White Noise |
| podcast, podcasts | Podcasts |

## Out of Scope
- Siri Shortcuts integration (future)
- Multi-language voice commands (future)
- Custom wake word (future)
