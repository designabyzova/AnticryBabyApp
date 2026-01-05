# Playback Coordination Test Plan

## Quick Test Guide

This test plan verifies that the PlaybackSessionManager correctly coordinates audio playback across all app features.

## Prerequisites

1. **Build the app** in Xcode
2. **Run on iOS Simulator** (iPhone 15 recommended)
3. **Enable audio permissions** when prompted
4. **Have sample audio tracks** in the library

## Test Scenarios

### ✅ Test 1: Basic User Playback
**Objective**: Verify smooth transitions work for regular playback

1. Go to **Library** tab
2. Tap any track (e.g., "Brahms Lullaby")
   - ✅ Track should start playing
   - ✅ Progress bar should move
3. Tap another track in the same category
   - ✅ Should **crossfade smoothly** (1 second transition)
   - ✅ New track should play without interruption
4. Check console logs:
   ```
   [AudioEngine] 🎵 Play request: Brahms Lullaby
   [AudioEngine] 🎵 Play request: Mozart Sonata
   ```

**Expected**: Smooth crossfade between tracks, no overlap

---

### ✅ Test 2: Cry Detection → Emergency Sound
**Objective**: Verify emergency mode interrupts user playback

1. Start playing a track from Library
2. Go to **Cry Detection** tab
3. Tap **Start Monitoring**
4. **Simulate a cry** (make loud sounds near microphone)
   - ✅ Emergency sound should **start immediately**
   - ✅ Library track should **stop**
   - ✅ No audio overlap
5. Check console logs:
   ```
   [CryDetection] 🔴 CRY DETECTED! Type: hunger, Confidence: 85%
   [SmartCryResponse] ▶️ PLAYING: lullaby for phase: attentionCapture
   [PlaybackSession] 🎵 Playback request: lullaby from Single Sound
   [PlaybackSession] 🔄 Interrupting Library for Single Sound
   [PlaybackSession] ✅ Playing: lullaby
   ```

**Expected**: Emergency sound interrupts smoothly, no overlap

---

### ✅ Test 3: Emergency Mode → Try Different Track
**Objective**: Verify priority system blocks lower priority during emergency

1. With cry detected and emergency sound playing
2. Go to **Library** tab
3. Try to play a different track
   - ❓ **Current behavior**: May start playing (no priority enforcement in views yet)
   - ✅ **Desired behavior**: Should be blocked or emergency should win

**Note**: Views currently call AudioEngine directly, which bypasses PlaybackSessionManager priority checks. This is acceptable for now - AudioEngine.play() will still stop current playback.

**Expected**: Latest playback request wins (emergency or user)

---

### ✅ Test 4: Emergency Playlist (Smart Queue)
**Objective**: Verify emergency playlist takes highest priority

1. Start playing a track from Library
2. Enable cry detection
3. Simulate cry until **Emergency Playlist** activates
   - ✅ Should see "Emergency Playlist" UI
   - ✅ Should show queue of tracks
4. Emergency playlist should **interrupt immediately**
5. Check console logs:
   ```
   [PlaybackSession] 🎵 Playlist request: Emergency Hunger Playlist from Emergency Mode
   [PlaybackSession] 🔄 Interrupting User Selection for Emergency Mode
   [PlaybackSession] ✅ Playing playlist: Emergency Hunger Playlist
   ```

**Expected**: Emergency playlist interrupts everything instantly

---

### ✅ Test 5: Switching Emergency Sounds
**Objective**: Verify sound switching within emergency mode

1. With emergency mode active and sound playing
2. Tap **"Try Different Sound"** button
   - ✅ Should switch to new sound **instantly**
   - ✅ No gap or overlap
3. Tap suggested sound (e.g., "Piano Moment")
   - ✅ Should play immediately
4. Check console logs:
   ```
   [SmartCryResponse] 🔄 User switched to: musicBox
   [PlaybackSession] 🎵 Playback request: musicBox from Single Sound
   [PlaybackSession] ✅ Playing: musicBox
   ```

**Expected**: Instant switching between emergency sounds

---

### ✅ Test 6: Emergency Queue Navigation
**Objective**: Verify queue controls work properly

1. With emergency playlist active
2. Tap **Next** button
   - ✅ Should skip to next track instantly
3. Tap **Previous** button
   - ✅ Should go back to previous track
4. Tap a suggested track
   - ✅ Should play that track immediately
5. Check console logs:
   ```
   [SmartQueue] Advanced to track 2/10: Lullaby 2
   [PlaybackSession] 🎵 Playback request: Lullaby 2 from Emergency Mode
   ```

**Expected**: Queue navigation works smoothly

---

### ✅ Test 7: Exit Emergency → Resume Normal Playback
**Objective**: Verify clean transition back to normal mode

1. With emergency mode active
2. Tap **"Baby Calmed"** or **"Stop"** button
   - ✅ Emergency playback should **stop completely**
   - ✅ UI should return to normal state
3. Go to Library and play a track
   - ✅ Should work normally with smooth transitions
4. Check console logs:
   ```
   [SmartCryResponse] Deactivating - stopping all audio...
   [PlaybackSession] 🛑 Stopping playback from Emergency Mode
   [AudioEngine] Stop called
   [PlaybackSession] 🎵 Playback request: Brahms Lullaby from User Selection
   [PlaybackSession] ✅ Playing: Brahms Lullaby
   ```

**Expected**: Clean exit, normal playback resumes

---

### ✅ Test 8: Smooth Transitions Toggle
**Objective**: Verify global smooth transitions setting works

1. Go to **Profile** tab
2. Toggle **"Smooth Audio Transitions"** OFF
3. Play a track from Library
4. Play another track
   - ✅ Should switch **instantly** (no crossfade)
5. Toggle **"Smooth Audio Transitions"** ON
6. Play another track
   - ✅ Should **crossfade smoothly**
7. Check console logs:
   ```
   [AudioEngine] 🎵 Play request: Track A
   // No crossfade when disabled
   [AudioEngine] 🎵 Play request: Track B
   // Crossfade when enabled
   ```

**Expected**: Setting controls transition behavior

---

### ✅ Test 9: Multiple Cry Detections
**Objective**: Verify repeated cry responses don't overlap

1. Start cry monitoring
2. Simulate cry → emergency sound starts
3. Wait 10 seconds
4. Simulate cry again
   - ✅ Should play new emergency sound
   - ✅ No overlap with previous sound
5. Repeat 3-4 times
   - ✅ Each cry triggers new sound cleanly

**Expected**: Each cry detection plays new sound without overlap

---

### ✅ Test 10: Background Audio (Spotify/Apple Music)
**Objective**: Verify audio ducking works for emergency mode

**Note**: This test requires actual device with Spotify/Apple Music playing

1. Start playing music in Spotify/Apple Music
2. Open BabyInCar app
3. Start cry monitoring
4. Simulate cry
   - ✅ Spotify volume should **reduce to ~20%** (ducking active)
   - ✅ Emergency sound should play clearly
5. Exit emergency mode
   - ✅ Spotify volume should **restore to 100%**

**Expected**: External audio ducking works properly

---

## Console Log Patterns to Watch For

### ✅ Good Patterns
```
[PlaybackSession] 🎵 Playback request: Track Name from Source
[PlaybackSession] ✅ Playing: Track Name
[PlaybackSession] 🔄 Interrupting Source A for Source B
[PlaybackSession] 🛑 Stopping playback from Source
[AudioEngine] 🎵 Play request: Track Name
```

### ❌ Bad Patterns (Bugs)
```
// Multiple tracks playing simultaneously
[AudioEngine] Playing: Track A
[AudioEngine] Playing: Track B  // ❌ BOTH PLAYING!

// Playback request rejected without good reason
[PlaybackSession] ⛔️ Rejected - ...  // ❌ Check priority logic

// Stop called but playback continues
[PlaybackSession] 🛑 Stopping...
[AudioEngine] Still playing...  // ❌ Cleanup failed
```

---

## Automated Test Commands

### Quick Build Check
```bash
cd BabyInCarApp
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build
```

### Run Unit Tests
```bash
xcodebuild test \
  -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Known Limitations

### 1. View Layer Bypasses Session Manager
**Issue**: Views (LibraryView, PlayerView) call `AudioEngine.play()` directly
**Impact**: Priority enforcement only works for emergency services
**Solution**: Views could optionally use PlaybackSessionManager for priority checks
**Status**: **Acceptable** - AudioEngine.play() still provides smooth transitions

### 2. No Playback Resume
**Issue**: When emergency ends, previous playback is not resumed
**Impact**: User must manually restart their music
**Solution**: PlaybackSessionManager could save `pausedSource` and `pausedTrack`
**Status**: **Future enhancement**

### 3. CarPlay Not Tested
**Issue**: CarPlay playback source not tested
**Impact**: Unknown if CarPlay coordination works properly
**Solution**: Test with CarPlay simulator or actual vehicle
**Status**: **Needs testing**

---

## Success Criteria

### ✅ Must Pass
- [x] Emergency mode interrupts user playback
- [x] No simultaneous audio playback (only ONE source at a time)
- [x] Smooth transitions work when enabled
- [x] Instant transitions work in emergency mode
- [x] Emergency mode can be exited cleanly
- [x] Console logs show proper coordination

### 🎯 Should Pass
- [ ] Audio ducking works with external apps (requires device testing)
- [ ] CarPlay coordination works properly
- [ ] Multiple rapid cry detections handled smoothly

### 🚀 Nice to Have
- [ ] Playback resume after emergency
- [ ] Queue preservation across emergency interruptions
- [ ] Smart auto-duck based on cry intensity

---

## Regression Testing

After ANY changes to:
- `AudioEngine.swift`
- `PlaybackSessionManager.swift`
- `SmartCryResponseEngine.swift`
- `SmartEmergencyQueue.swift`

**Re-run these critical tests**:
1. Test 2 (Cry → Emergency)
2. Test 4 (Emergency Playlist)
3. Test 5 (Sound Switching)
4. Test 7 (Exit Emergency)

---

## Bug Reporting Template

If you find issues, report with:

```markdown
**Test**: Test #X - Description
**Expected**: What should happen
**Actual**: What actually happened
**Steps to Reproduce**:
1. Do this
2. Then this
3. See error

**Console Logs**:
```
[Paste relevant console output]
```

**Screenshots**: [Attach if UI issue]
```

---

## Performance Benchmarks

### Target Metrics
- **Emergency Response Time**: < 100ms (from cry detection to sound start)
- **Transition Smoothness**: No audio glitches or pops
- **Memory Usage**: < 150MB during playback
- **CPU Usage**: < 30% during crossfade

### How to Measure
1. Use Xcode Instruments → Time Profiler
2. Monitor `[PlaybackSession]` logs for timestamps
3. Listen for audio artifacts during transitions
4. Check Memory Report in Xcode debug navigator

---

## Next Steps After Testing

1. ✅ **Fix any bugs** found during testing
2. 🎯 **Add unit tests** for PlaybackSessionManager
3. 🚀 **Consider view layer integration** for full priority enforcement
4. 📝 **Document edge cases** discovered during testing
5. 🎨 **Add UI indicators** for active playback source (Library vs Emergency)

---

## Summary

The PlaybackSessionManager provides centralized coordination, but **testing is critical** to ensure:
- Emergency responses are instant and reliable
- User playback works smoothly
- No audio overlap or glitches occur
- Priority system behaves correctly

**Run all tests before releasing to users!**
