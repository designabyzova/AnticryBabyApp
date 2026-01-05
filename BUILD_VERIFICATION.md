# FS-017 Build Verification Guide

## 🎯 Purpose

This guide helps verify the Smart Emergency Playlist System implementation and prepare the iOS app for testing.

## ✅ Quick Start (2 Minutes)

### Step 1: Add New Swift Files to Xcode Project

Open `BabyInCarApp.xcodeproj` in Xcode and add these files:

**Models** (Right-click Models folder → Add Files):
- `BabyInCarApp/Models/CryScenarioPlaylist.swift`
- `BabyInCarApp/Models/TrackMetadata.swift`
- `BabyInCarApp/Models/EmergencySession.swift`
- `BabyInCarApp/Models/UserLanguagePreference.swift`

**Services** (Right-click Services folder → Add Files):
- `BabyInCarApp/Services/PlaylistSelector.swift`
- `BabyInCarApp/Services/EmergencyQueueManager.swift`

**Views** (Right-click Views folder → Add Files):
- `BabyInCarApp/Views/EmergencyQueueView.swift`

**Components** (Right-click Views/Components folder → Add Files):
- `BabyInCarApp/Views/Components/CurrentTrackCard.swift`
- `BabyInCarApp/Views/Components/UpcomingTrackRow.swift`
- `BabyInCarApp/Views/Components/CancelButton.swift`
- `BabyInCarApp/Views/Components/TrackProgressBar.swift`
- `BabyInCarApp/Views/Components/TrackMetadataSheet.swift`

**IMPORTANT**: When adding files, ensure "Add to targets: BabyInCarApp" is checked!

### Step 2: Build the Project

```bash
# In Xcode: Product → Build (⌘B)
# Or use simulator: Product → Run (⌘R)
```

### Step 3: Test Emergency Mode

1. Launch app in simulator
2. Go to Cry Detection tab
3. Enable microphone permissions
4. Simulate a cry (or tap "Test Emergency Mode" button if added)
5. Emergency Queue View should slide up from bottom
6. Verify:
   - Playlist name displayed
   - Current track card shows (with placeholder gradient)
   - Progress bar animates
   - Upcoming tracks list scrolls
   - Cancel button works (shows effectiveness dialog)

## 🔍 Expected Behavior

### Normal Mode (useEmergencyPlaylists = false)
- Single track playback
- No queue view
- Traditional cry response

### Emergency Mode (useEmergencyPlaylists = true)
- AI-selected playlist based on cry type
- Spotify-like queue interface
- Smooth track transitions
- Effectiveness tracking

## 🐛 Troubleshooting Build Errors

### Error: "Cannot find 'AudioTrack' in scope"

**Fix**: AudioTrack model already exists in the project. No action needed.

### Error: "Cannot find type 'CryType' in scope"

**Fix**: CryType enum should exist in CryDetectionService.swift. If missing, add:

```swift
enum CryType: String, Codable, CaseIterable {
    case hunger
    case tired
    case pain
    case discomfort
    case attention
    case general
}
```

### Error: "Value of type 'SmartCryResponseEngine' has no member 'playlistSelector'"

**Fix**: The playlistSelector property was added in this increment. Ensure SmartCryResponseEngine.swift has the latest changes (check git diff).

### Error: "Cannot find 'LanguageBadge' in scope"

**Fix**: LanguageBadge is a simple component used by UpcomingTrackRow. Add this file:

```swift
// BabyInCarApp/Views/Components/LanguageBadge.swift
import SwiftUI

struct LanguageBadge: View {
    let language: String
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(flagEmoji(for: language))
                .font(compact ? .caption2 : .caption)
            if !compact {
                Text(languageName(for: language))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }

    private func flagEmoji(for code: String) -> String {
        switch code {
        case "en": return "🇬🇧"
        case "ru": return "🇷🇺"
        case "multi": return "🌐"
        default: return "🌍"
        }
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "ru": return "Russian"
        case "multi": return "Instrumental"
        default: return code.uppercased()
        }
    }
}
```

### Error: "Cannot find 'CalmingScoreBadge' or 'TempoBadge' in scope"

**Fix**: Add these simple badge components:

```swift
// BabyInCarApp/Views/Components/CalmingScoreBadge.swift
import SwiftUI

struct CalmingScoreBadge: View {
    let score: Double  // 0.0 - 1.0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
            Text(String(format: "%.0f%%", score * 100))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.red)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }
}

// BabyInCarApp/Views/Components/TempoBadge.swift
import SwiftUI

struct TempoBadge: View {
    let bpm: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "metronome")
                .font(.caption2)
            Text("\(bpm) BPM")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
}
```

## 🧪 Testing with Mock Data

The app is configured to work with mock data for local testing. No backend required!

### Mock Playlists

PlaylistSelector.swift includes `mockPlaylists` for offline testing:

```swift
// In PlaylistSelector.swift
static let mockPlaylists: [CryScenarioPlaylist] = [
    // 16 pre-configured playlists across all cry types + languages
]
```

### Mock Track Metadata

TrackMetadata.swift includes research-backed metadata examples:

```swift
// Mock track with all metadata
TrackMetadata(
    trackId: "track-brahms-lullaby",
    crySuitability: ["hunger": 0.75, "tired": 0.95, "pain": 0.65],
    acousticFeatures: AcousticFeatures(tempoBpm: 60, key: "C", mode: "major"),
    researchCitations: "Trehub et al. (2015) - Lullabies and infant affect regulation"
)
```

### Enable Mock Mode

In `PlaylistSelector.swift`, the `selectOptimalPlaylist` method automatically uses mock data if API is unavailable:

```swift
// API call fails → falls back to mock data automatically
do {
    let playlists = try await fetchFromAPI()
    return playlists
} catch {
    print("API unavailable, using mock data")
    return Self.mockPlaylists.filter { /* ... */ }
}
```

## 📊 Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Database Schema | ✅ | Migration 013 applied |
| API Endpoints | ✅ | 4 emergency + 2 preferences endpoints |
| Swift Models | ✅ | 4 models created |
| Swift Services | ✅ | PlaylistSelector + EmergencyQueueManager |
| UI Components | ✅ | EmergencyQueueView + 5 sub-components |
| Integration | ✅ | SmartCryResponseEngine modified |
| Mock Data | ✅ | Full mock playlists for testing |
| Xcode Project | ⏳ | **Needs manual file addition** |
| Build Verification | ⏳ | **Run after adding files** |
| E2E Tests | ⏳ | Maestro flows not yet created |

## 🚀 Next Steps After Build Success

1. **Test Emergency Mode UI** - Verify Spotify-like interface
2. **Test Language Filtering** - Switch between English/Russian
3. **Test Cancel Flow** - Verify effectiveness dialog
4. **Write Maestro E2E Tests** - Automate UI testing
5. **Integrate with Real Backend** - Once API is deployed

## 🔗 Related Documentation

- Implementation Summary: `.specweave/increments/0017-smart-emergency-playlists/IMPLEMENTATION_SUMMARY.md`
- Spec: `.specweave/increments/0017-smart-emergency-playlists/spec.md`
- Plan: `.specweave/increments/0017-smart-emergency-playlists/plan.md`
- Tasks: `.specweave/increments/0017-smart-emergency-playlists/tasks.md`

## ✅ Success Criteria

- [ ] All new Swift files added to Xcode project
- [ ] Project builds without errors
- [ ] Emergency Queue View displays correctly
- [ ] Cancel button triggers effectiveness dialog
- [ ] Mock playlists load successfully
- [ ] No crashes or memory leaks

---

**Note**: This is autonomous implementation following the SpecWeave workflow. The backend integration will happen after iOS UI verification is complete.
