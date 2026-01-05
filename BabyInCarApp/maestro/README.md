# E2E Testing with Maestro

This directory contains end-to-end tests for the Baby in Car app using [Maestro](https://maestro.mobile.dev/).

## Prerequisites

### 1. Install Maestro

```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
```

Verify installation:
```bash
~/.maestro/bin/maestro --version
```

### 2. Setup iOS Simulator

Ensure Xcode is installed and an iOS simulator is available:
```bash
# List available simulators
xcrun simctl list devices

# Boot iPhone 15 simulator (recommended)
xcrun simctl boot "iPhone 15"
```

### 3. Build and Install App

```bash
cd BabyInCarApp
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath build/

# Install to simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/BabyInCarApp.app
```

## Running Tests

### Run All Tests

```bash
~/.maestro/bin/maestro test maestro/flows/
```

### Run Specific Test

```bash
# Onboarding flow
~/.maestro/bin/maestro test maestro/flows/onboarding_flow.yaml

# Cry detection flow
~/.maestro/bin/maestro test maestro/flows/cry_detection_flow.yaml

# Audio playback flow
~/.maestro/bin/maestro test maestro/flows/playback_flow.yaml

# Library navigation flow
~/.maestro/bin/maestro test maestro/flows/library_navigation_flow.yaml

# Playlist management flow
~/.maestro/bin/maestro test maestro/flows/playlist_flow.yaml
```

### Run with Recording

```bash
~/.maestro/bin/maestro test --record maestro/flows/cry_detection_flow.yaml
```

### Run in Headed Mode (Visual)

```bash
~/.maestro/bin/maestro studio maestro/flows/cry_detection_flow.yaml
```

## Test Flows Overview

### 1. Onboarding Flow (`onboarding_flow.yaml`)
Tests the complete new user onboarding experience:
- Welcome screens navigation
- Permission requests (microphone)
- Baby profile creation
- Verification of successful onboarding

**Duration**: ~30 seconds

### 2. Cry Detection Flow (`cry_detection_flow.yaml`)
Tests the core cry detection and monitoring features:
- Enable/disable AI monitoring
- Calibration process
- Emergency stop functionality
- Pattern tracking
- Settings configuration

**Duration**: ~45 seconds

### 3. Audio Playback Flow (`playback_flow.yaml`)
Tests all audio playback controls and features:
- Play/pause functionality
- Skip forward/backward
- Shuffle and repeat modes
- Volume control
- Queue management
- Favorites toggling
- Mini player behavior

**Duration**: ~60 seconds

### 4. Library Navigation Flow (`library_navigation_flow.yaml`)
Tests content browsing and discovery:
- Category filtering (Classical, White Noise, Lullabies)
- Search functionality
- Sorting options
- Age-based filtering
- Track details view
- Premium content indicators

**Duration**: ~45 seconds

### 5. Playlist Management Flow (`playlist_flow.yaml`)
Tests playlist creation and management:
- Create new playlist
- Add/remove tracks
- Reorder tracks
- Edit playlist details
- Share playlist
- Delete playlist

**Duration**: ~60 seconds

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-tests:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install Maestro
        run: curl -fsSL "https://get.maestro.mobile.dev" | bash

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Build app
        run: |
          cd BabyInCarApp
          xcodebuild -project BabyInCarApp.xcodeproj \
            -scheme BabyInCarApp \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -derivedDataPath build/

      - name: Boot simulator
        run: |
          xcrun simctl boot "iPhone 15" || true
          xcrun simctl install booted BabyInCarApp/build/Build/Products/Debug-iphonesimulator/BabyInCarApp.app

      - name: Run Maestro tests
        run: ~/.maestro/bin/maestro test maestro/flows/

      - name: Upload screenshots
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: maestro-screenshots
          path: ~/.maestro/tests/**/*.png
```

## Troubleshooting

### Issue: "App not found"

Ensure the app is installed on the simulator:
```bash
xcrun simctl list apps booted | grep "com.anticry.babyincar"
```

If not found, reinstall:
```bash
xcrun simctl install booted BabyInCarApp/build/Build/Products/Debug-iphonesimulator/BabyInCarApp.app
```

### Issue: "Element not found"

Use Maestro Studio to inspect the app hierarchy:
```bash
~/.maestro/bin/maestro studio
```

### Issue: Microphone permission blocking test

For automated testing, you may need to pre-grant permissions:
```bash
xcrun simctl privacy booted grant microphone com.anticry.babyincar
```

### Issue: Test times out

Increase timeout in flow:
```yaml
- waitForAnimationToEnd:
    timeout: 10000  # 10 seconds
```

## Recording Flows

To record a new flow interactively:
```bash
~/.maestro/bin/maestro record maestro/flows/new_flow.yaml
```

Then interact with the app - Maestro will record your actions.

## Best Practices

1. **Use Accessibility Identifiers**: Prefer `id:` over `text:` for stability
   ```swift
   Button("Play") { }
       .accessibilityIdentifier("playButton")
   ```

2. **Add Waits**: Use `waitForAnimationToEnd` after UI transitions
   ```yaml
   - tapOn: "Next"
   - waitForAnimationToEnd:
       timeout: 2000
   ```

3. **Take Screenshots**: Capture key states for debugging
   ```yaml
   - takeScreenshot: "feature_complete"
   ```

4. **Clear State**: Start tests with clean state
   ```yaml
   - launchApp:
       clearState: true
       clearKeychain: true
   ```

5. **Assertions**: Verify expected UI elements
   ```yaml
   - assertVisible: "Expected Text"
   - assertNotVisible: "Hidden Element"
   ```

## Test Coverage

| Feature Area | Test Coverage | Critical Paths |
|--------------|---------------|----------------|
| Onboarding | ✅ | New user setup |
| Cry Detection | ✅ | Toggle, calibration, emergency |
| Audio Playback | ✅ | Play, pause, skip, shuffle, repeat |
| Library Navigation | ✅ | Browse, search, filter |
| Playlist Management | ✅ | CRUD operations |
| Favorites | ⚠️ Partial | Add/remove (in playback_flow) |
| Profile Management | ❌ Not yet | Multi-baby profiles |
| Premium Features | ❌ Not yet | Paywall, subscriptions |
| Voice Commands | ❌ Not yet | Speech recognition |

## Next Steps

1. Add accessibility identifiers to all interactive elements
2. Implement profile management E2E test
3. Add premium feature E2E tests
4. Create voice command E2E tests (requires simulator audio support)
5. Add performance benchmarks to E2E flows

## Resources

- [Maestro Documentation](https://maestro.mobile.dev/getting-started/introduction)
- [Maestro CLI Reference](https://maestro.mobile.dev/cli/test-suites-and-reports)
- [Maestro Cloud](https://maestro.mobile.dev/getting-started/maestro-cloud)
