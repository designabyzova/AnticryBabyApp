# Technical Architecture: Apple Watch Companion App

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    iPhone (Parent App)                       │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│ │  AudioEngine    │  │ CryDetection    │  │ WatchSync    │ │
│ │  (Full Power)   │  │ (ML + FFT)      │  │ Manager      │ │
│ └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│          │                    │                   │         │
│          └────────────────────┼───────────────────┘         │
│                               │                              │
│                    ┌──────────┴──────────┐                  │
│                    │  WCSessionDelegate  │                  │
│                    │  (WatchConnectivity)│                  │
│                    └──────────┬──────────┘                  │
└───────────────────────────────┼─────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │  WatchConnectivity    │
                    │  (Bluetooth/WiFi)     │
                    └───────────┬───────────┘
                                │
┌───────────────────────────────┼─────────────────────────────┐
│                    ┌──────────┴──────────┐                  │
│                    │  WCSessionDelegate  │                  │
│                    │  (WatchConnectivity)│                  │
│                    └──────────┬──────────┘                  │
│                               │                              │
│          ┌────────────────────┼───────────────────┐         │
│          │                    │                   │         │
│ ┌────────┴────────┐  ┌────────┴────────┐  ┌──────┴───────┐ │
│ │ WatchAudioPlayer│  │  CryAlertView   │  │ FavoritesSync│ │
│ │ (WKAudioFile)   │  │  (Notifications)│  │ Manager      │ │
│ └─────────────────┘  └─────────────────┘  └──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Apple Watch (Companion)                   │
└─────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. WatchSyncManager (iPhone Side)

```swift
// BabyInCarApp/Services/WatchSyncManager.swift
class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    @Published var isWatchReachable = false
    @Published var isWatchAppInstalled = false

    private var session: WCSession?

    // State sync
    func syncPlaybackState(_ state: PlaybackState)
    func syncFavorites(_ favorites: [AudioTrack])
    func sendCryAlert(_ alert: CryAlert)

    // File transfer
    func transferAudioFile(_ track: AudioTrack)
    func cancelAllTransfers()

    // Commands from watch
    func handleCommand(_ command: WatchCommand)
}
```

### 2. WatchAudioPlayer (Watch Side)

```swift
// BabyInCarWatchApp/Services/WatchAudioPlayer.swift
class WatchAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: WatchTrack?
    @Published var progress: Double = 0

    private var player: WKAudioFilePlayer?
    private var playerItem: WKAudioFilePlayerItem?

    func play(track: WatchTrack)
    func pause()
    func resume()
    func skip(direction: SkipDirection)
    func setVolume(_ volume: Float) // Digital Crown
}
```

### 3. WatchConnectivityManager (Watch Side)

```swift
// BabyInCarWatchApp/Services/WatchConnectivityManager.swift
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var iPhonePlaybackState: PlaybackState?
    @Published var favorites: [WatchTrack] = []
    @Published var pendingCryAlerts: [CryAlert] = []

    // Send commands to iPhone
    func sendPlayCommand()
    func sendPauseCommand()
    func sendSkipCommand(_ direction: SkipDirection)
    func requestStateSync()
}
```

## Data Models (Shared)

```swift
// Shared/Models/WatchModels.swift

struct WatchTrack: Codable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let localURL: URL?  // Only set on watch after sync
    let artworkData: Data?
}

struct PlaybackState: Codable {
    let isPlaying: Bool
    let currentTrackId: String?
    let progress: Double
    let volume: Float
    let sleepTimerRemaining: TimeInterval?
}

struct CryAlert: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cryType: CryType
    let confidence: Double
    let suggestedAction: String
}

enum WatchCommand: Codable {
    case play
    case pause
    case skipNext
    case skipPrevious
    case setSleepTimer(minutes: Int)
    case cancelSleepTimer
    case startSoothingMusic
}
```

## Watch App UI Structure

```
BabyInCarWatchApp/
├── BabyInCarWatchApp.swift          # App entry point
├── Views/
│   ├── ContentView.swift            # Tab container
│   ├── NowPlayingView.swift         # Current track + controls
│   ├── FavoritesListView.swift      # Synced favorites
│   ├── RemoteControlView.swift      # iPhone playback control
│   ├── CryAlertsView.swift          # Alert history
│   └── SleepTimerView.swift         # Timer picker
├── Services/
│   ├── WatchAudioPlayer.swift       # WKAudioFilePlayer wrapper
│   └── WatchConnectivityManager.swift
└── Models/
    └── WatchModels.swift            # Shared models
```

## File Transfer Strategy

### Storage Budget (50MB max on watch)
- Max 20 favorite tracks
- Average track size: 2-3MB (compressed)
- Artwork: 50KB per track
- Total estimated: ~45MB for 20 tracks

### Transfer Priority
1. Currently playing track (immediate)
2. User's top 5 favorites (high)
3. Recently played tracks (medium)
4. Remaining favorites (background)

### Transfer Protocol
```swift
func syncFavoritesToWatch() {
    let favorites = FavoritesManager.shared.favorites.prefix(20)

    for track in favorites {
        // Check if already on watch
        guard !isTrackOnWatch(track.id) else { continue }

        // Transfer compressed audio file
        let fileURL = AudioCacheService.shared.localURL(for: track)
        session.transferFile(fileURL, metadata: [
            "trackId": track.id,
            "title": track.title,
            "artist": track.artist
        ])
    }
}
```

## Cry Alert Flow

```
iPhone detects cry
       │
       ▼
CryDetectionService.onCryDetected { cryType, confidence in
    let alert = CryAlert(
        id: UUID(),
        timestamp: Date(),
        cryType: cryType,
        confidence: confidence,
        suggestedAction: getSuggestedAction(for: cryType)
    )

    WatchSyncManager.shared.sendCryAlert(alert)
}
       │
       ▼
WatchSyncManager sends via WCSession.sendMessage()
       │
       ▼
Watch receives alert
       │
       ▼
WatchConnectivityManager posts notification
       │
       ▼
WKNotificationScene displays alert with haptic
       │
       ▼
User taps "Play Soothing Music" → starts WatchAudioPlayer
```

## Testing Strategy

### Unit Tests
- WatchSyncManager message encoding/decoding
- WatchAudioPlayer state management
- File transfer metadata handling

### Integration Tests
- WCSession activation and pairing
- State synchronization round-trip
- File transfer completion callbacks

### Device Testing (Required)
- Real Apple Watch + iPhone pairing
- Audio playback on physical watch
- Haptic feedback verification
- Battery drain under playback

## Dependencies

### watchOS Frameworks
- WatchKit (UI and app lifecycle)
- WatchConnectivity (iPhone sync)
- AVFoundation (limited, for WKAudioFilePlayer)
- UserNotifications (cry alerts)

### Minimum Requirements
- watchOS 9.0+
- iOS 16.0+ (parent app)
- iPhone paired with Apple Watch
