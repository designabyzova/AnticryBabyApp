# BabyInCarAppIntents - Siri Intents Extension

## Overview

This is the **Intents Extension** for the Lulla app. It enables Siri voice control by handling media intents and passing them to the main app.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Siri: "Hey Siri, play lullabies in Lulla"          │
└────────────────┬─────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────┐
│  iOS Routes to Extension                             │
│  (Matches bundle ID: com.babyincar.app.intents)      │
└────────────────┬─────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────┐
│  IntentHandler.swift (This Extension)                │
│  ├─ Receives INPlayMediaIntent                       │
│  ├─ Parses "lullabies" → category                    │
│  └─ Creates NSUserActivity with userInfo             │
└────────────────┬─────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────┐
│  iOS Launches Main App                               │
│  Passes NSUserActivity("com.lulla.playMedia")        │
└────────────────┬─────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────┐
│  BabyInCarApp.swift (Main App)                       │
│  ├─ .onContinueUserActivity() receives activity      │
│  ├─ handlePlayMediaActivity() parses userInfo        │
│  └─ AudioEngine plays lullabies playlist             │
└──────────────────────────────────────────────────────┘
```

## Files

### IntentHandler.swift
Main entry point for the extension. Implements:
- `INPlayMediaIntentHandling` - "play X"
- `INSearchForMediaIntentHandling` - "find X"
- `INAddMediaIntentHandling` - "add to favorites"

### SharedAudioModels.swift
Lightweight models used by both extension and main app:
- `IntentAudioCategory` - Category enum
- `IntentAction` - Action types
- `IntentActivityType` - Activity identifiers

### Info.plist
Extension configuration:
- `NSExtension` settings
- Supported intents declaration
- Principal class reference

### BabyInCarAppIntents.entitlements
Extension capabilities:
- Siri capability
- App Groups (`group.com.babyincar`)
- Keychain sharing

## Supported Voice Commands

### Play Category
- "Hey Siri, play lullabies in Lulla"
- "Hey Siri, play classical music in Lulla"
- "Hey Siri, play nature sounds in Lulla"

### Emergency Mode
- "Hey Siri, calm baby in Lulla"
- "Hey Siri, baby crying in Lulla"

### Search
- "Hey Siri, find Mozart in Lulla"

### Favorites
- "Hey Siri, add to favorites in Lulla"

## Key Design Decisions

### Why Separate Extension?
- **Required by Apple:** SiriKit media intents need dedicated extension
- **Process isolation:** Extension runs separately from main app
- **Better reliability:** Extension can start even if app is terminated
- **Faster response:** Lightweight extension launches quickly

### Why Minimal Models?
- **Memory efficiency:** Extension has strict memory limits
- **Fast launch:** Fewer imports = faster cold start
- **Focused purpose:** Extension only needs to parse and route

### Why NSUserActivity Handoff?
- **Standard pattern:** Apple-recommended approach for extensions
- **Main app handles playback:** AudioEngine stays in main app
- **Flexibility:** Can add rich data in userInfo dictionary
- **Testable:** Can simulate activities in tests

## Data Flow Example

### "Hey Siri, play lullabies in Lulla"

1. **Extension receives:**
   ```swift
   INPlayMediaIntent(
       mediaSearch: INMediaSearch(mediaName: "lullabies")
   )
   ```

2. **Extension parses:**
   ```swift
   parseCategory("lullabies") → "lullabies"
   ```

3. **Extension creates activity:**
   ```swift
   NSUserActivity(activityType: "com.lulla.playMedia")
   userActivity.userInfo = [
       "action": "playCategory",
       "category": "lullabies"
   ]
   ```

4. **Main app receives:**
   ```swift
   .onContinueUserActivity("com.lulla.playMedia") { activity in
       handlePlayMediaActivity(activity)
   }
   ```

5. **Main app executes:**
   ```swift
   playCategory("lullabies")
   → AudioEngine.play(playlist: lullabiesPlaylist)
   ```

## Debugging

### Console Logs
Look for these log prefixes:
- `🎤 [Extension]` - Logs from this extension
- `🎤 [App]` - Logs from main app handlers

### Common Issues

**Extension not invoked:**
- Check extension is added to Xcode project
- Verify bundle ID matches: `com.babyincar.app.intents`
- Check extension is embedded in main app

**Activity not received:**
- Verify activity types match exactly
- Check main app has `.onContinueUserActivity()` handlers
- Look for typos in activity type strings

**Parsing fails:**
- Check category mapping in `parseCategory()`
- Verify emergency phrases list matches user input
- Add console logs to see what Siri understood

## App Store Submission

✅ Extension auto-included in app bundle
✅ No separate review process
✅ Same version number as main app
✅ Works immediately after approval

## Testing

### Simulator
Use text input (voice doesn't work in simulator):
```
Hardware → Keyboard → Toggle Software Keyboard
Open Siri → Type: "play lullabies in Lulla"
```

### Device
Best for realistic testing:
```
Say: "Hey Siri, play lullabies in Lulla"
Check: Console logs in Xcode
```

### CarPlay
Ultimate test environment:
```
Connect to CarPlay
Say: "Hey Siri, play classical music in Lulla"
Verify: Music plays through car speakers
```

## Resources

- [SiriKit Documentation](https://developer.apple.com/documentation/sirikit/)
- [Media Intents Guide](https://developer.apple.com/documentation/sirikit/media)
- [App Extensions Guide](https://developer.apple.com/app-extensions/)
