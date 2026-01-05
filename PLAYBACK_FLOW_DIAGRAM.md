# Audio Playback Flow Diagrams

## Before Fix: Chaos 🔥

```
User taps track in Library
│
├─> AudioEngine.play(track A)  🎵 Playing...
│
Baby cries!
│
├─> CryDetectionService detects
├─> SmartCryResponseEngine.activate()
├─> audioEngine.playImmediateWithoutFade(emergency sound)  🎵 Playing...
│
❌ PROBLEM: Both Track A AND Emergency Sound playing at once!
```

---

## After Fix: Coordinated ✅

```
User taps track in Library
│
├─> AudioEngine.play(track A)  🎵 Playing (Priority 10)
│   └─ PlaybackSession: activeSource = .userSelection
│
Baby cries!
│
├─> CryDetectionService detects
├─> SmartCryResponseEngine.activate()
├─> PlaybackSessionManager.requestPlayback(emergency, from: .singleSound)
│   │
│   ├─ Priority Check: singleSound(90) vs userSelection(10)
│   ├─ Decision: 90 > 10 → INTERRUPT ✅
│   ├─ PlaybackSession: activeSource = .singleSound
│   └─> AudioEngine.playImmediateWithoutFade(emergency)
│
✅ Result: Track A stopped, Emergency sound playing alone
```

---

## Priority Decision Tree

```
┌─────────────────────────────────────────────┐
│   PlaybackSessionManager.requestPlayback()  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Active source exists? │
        └──────┬───────┬────────┘
               │       │
              NO      YES
               │       │
               │       ▼
               │  ┌─────────────────────────┐
               │  │ Compare priorities:      │
               │  │ new.priority vs active   │
               │  └──────┬─────────┬────────┘
               │         │         │
               │     HIGHER    LOWER/EQUAL
               │         │         │
               │         ▼         ▼
               │    INTERRUPT   LATEST WINS
               │         │         │
               ▼         ▼         ▼
        ┌────────────────────────────┐
        │   Update activeSource      │
        │   Call AudioEngine.play()  │
        └────────────────────────────┘
```

---

## Emergency Response Flow

```
👶 Baby starts crying
│
▼
🎤 Microphone picks up sound
│
▼
🧠 CryDetectionService analyzes audio
├─ FFT analysis
├─ ML classification
└─ Confidence threshold check
│
▼
✅ Cry detected! (confidence > 70%)
│
▼
🚨 SmartCryResponseEngine.activate()
│
├─ Determine cry type (hunger/tired/pain)
├─ Select appropriate sound (lullaby/heartbeat)
└─ Request playback via SessionManager
   │
   ▼
   📱 PlaybackSessionManager.requestPlayback()
   ├─ Source: .singleSound (priority 90)
   ├─ forceImmediate: true
   └─ Interrupt active user playback
      │
      ▼
      🔊 Emergency sound plays INSTANTLY
      │
      └─ User sees emergency UI
         └─ Can switch sounds or exit
```

---

## Emergency Playlist Flow

```
🚨 Emergency sound playing (single sound)
│
▼
⏱️ 30 seconds pass, baby still crying
│
▼
🧠 SmartCryResponseEngine escalates
│
├─ Decide: Try emergency playlist
└─ Build cry-specific queue
   │
   ▼
   📋 SmartEmergencyQueue.buildQueue()
   ├─ Select 10-20 tracks based on cry type
   ├─ ONLY melodic content (no noise!)
   └─ Science-based category priorities
      │
      ▼
      📱 PlaybackSessionManager.requestPlayback(playlist)
      ├─ Source: .emergencyMode (priority 100)
      ├─ forceImmediate: true
      └─ Interrupt single emergency sound
         │
         ▼
         🎵 Emergency playlist starts
         ├─ Track 1/15 playing
         ├─ User sees queue
         └─ Can skip/pause/exit
```

---

## Smooth Transition Flow (User Mode)

```
User taps Track A in Library
│
▼
AudioEngine.play(Track A)
├─ smoothTransitionsEnabled? YES
├─ Already playing? NO
└─ Start with fade-in (0.5s)
   │
   🎵 Track A playing
   │
User taps Track B
│
▼
AudioEngine.play(Track B)
├─ smoothTransitionsEnabled? YES
├─ Already playing? YES
└─ crossfadeToTrack(B, duration: 1.0)
   │
   ├─ Fade out Track A: 1.0 → 0.0 (1 second)
   ├─ Fade in Track B: 0.0 → 1.0 (1 second)
   └─ Overlap during transition
      │
      🎵 Smooth transition, no gap
```

---

## Stop Flow

```
User exits Emergency Mode
│
▼
SmartCryResponseEngine.deactivate()
│
├─ Stop emergency queue (if active)
└─ PlaybackSessionManager.stopPlayback(from: .emergencyMode)
   │
   ├─ Verify source matches activeSource
   ├─ Call AudioEngine.stop()
   └─ Clear activeSource
      │
      🔇 All audio stopped
      │
User plays new track from Library
│
▼
PlaybackSessionManager.requestPlayback(track, from: .userSelection)
├─ No active source → ACCEPTED ✅
└─ AudioEngine.play(track)
   │
   🎵 Normal playback resumes
```

---

## Priority Comparison Examples

### Example 1: User → Emergency
```
Before:
  activeSource = .userSelection (10)

Request:
  new = .emergencyMode (100)

Decision:
  100 > 10 → INTERRUPT ✅

Result:
  activeSource = .emergencyMode
  Emergency plays, user track stopped
```

### Example 2: Emergency → User (Blocked)
```
Before:
  activeSource = .emergencyMode (100)

Request:
  new = .userSelection (10)

Decision:
  10 < 100 → REJECT ❌

Result:
  activeSource = .emergencyMode (unchanged)
  Emergency continues, user request ignored
```

### Example 3: Single Sound → Emergency Playlist
```
Before:
  activeSource = .singleSound (90)

Request:
  new = .emergencyMode (100)

Decision:
  100 > 90 → INTERRUPT ✅

Result:
  activeSource = .emergencyMode
  Playlist starts, single sound stopped
```

### Example 4: User → User (Latest Wins)
```
Before:
  activeSource = .userSelection (10)

Request:
  new = .userSelection (10)

Decision:
  10 = 10 → Latest wins

Result:
  activeSource = .userSelection (updated)
  New track plays with smooth crossfade
```

---

## Console Log Timeline

```
[00:00] User plays track
[AudioEngine] 🎵 Play request: Brahms Lullaby
[PlaybackSession] 🎵 Playback request: Brahms Lullaby from User Selection
[PlaybackSession] ✅ Playing: Brahms Lullaby

[00:15] Baby starts crying
[CryDetection] 🔴 CRY DETECTED! Type: hunger, Confidence: 85%
[SmartCryResponse] ▶️ PLAYING: lullaby for phase: attentionCapture
[PlaybackSession] 🎵 Playback request: lullaby from Single Sound
[PlaybackSession] 🔄 Interrupting User Selection for Single Sound
[PlaybackSession] ✅ Playing: lullaby

[00:45] User taps different emergency sound
[SmartCryResponse] 🔄 User switched to: musicBox
[PlaybackSession] 🎵 Playback request: musicBox from Single Sound
[PlaybackSession] ✅ Playing: musicBox

[01:00] Emergency playlist activates
[SmartQueue] Starting queue with 15 tracks
[PlaybackSession] 🎵 Playlist request: Emergency Hunger Playlist from Emergency Mode
[PlaybackSession] 🔄 Interrupting Single Sound for Emergency Mode
[PlaybackSession] ✅ Playing playlist: Emergency Hunger Playlist

[01:30] User exits emergency
[SmartCryResponse] Deactivating - stopping all audio...
[PlaybackSession] 🛑 Stopping playback from Emergency Mode

[01:35] User plays library track
[AudioEngine] 🎵 Play request: Mozart Sonata
[PlaybackSession] 🎵 Playback request: Mozart Sonata from User Selection
[PlaybackSession] ✅ Playing: Mozart Sonata
```

---

## State Machine

```
┌─────────────┐
│    IDLE     │ ← Initial state
└──────┬──────┘
       │ play(track, from: .userSelection)
       ▼
┌─────────────┐
│   PLAYING   │ ← User listening
│  (User: 10) │
└──────┬──────┘
       │ play(emergency, from: .singleSound)
       ▼
┌─────────────┐
│   PLAYING   │ ← Emergency active
│ (Single: 90)│
└──────┬──────┘
       │ play(playlist, from: .emergencyMode)
       ▼
┌─────────────┐
│   PLAYING   │ ← Emergency playlist
│  (Emer: 100)│
└──────┬──────┘
       │ stopPlayback(from: .emergencyMode)
       ▼
┌─────────────┐
│    IDLE     │ ← Ready for user
└─────────────┘
```

---

## Summary

The PlaybackSessionManager acts as a **traffic controller** for audio:

1. **Receives requests** from different sources
2. **Checks priorities** (higher interrupts lower)
3. **Coordinates transitions** (smooth or instant)
4. **Tracks active source** (single source of truth)
5. **Ensures cleanup** (proper stop handling)

Result: **Predictable, smooth audio playback with proper emergency prioritization!**
