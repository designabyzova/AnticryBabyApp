# Quick Test Guide - Baby in Car App

## 🚀 One-Command Test Run

```bash
# Install Maestro (one-time)
curl -fsSL "https://get.maestro.mobile.dev" | bash

# Run all E2E tests
~/.maestro/bin/maestro test maestro/flows/
```

---

## 📱 Setup (First Time Only)

### 1. Boot Simulator

```bash
# Boot iPhone 15
xcrun simctl boot "iPhone 15"

# Or list all available simulators
xcrun simctl list devices | grep iPhone
```

### 2. Fix Xcode Path (if needed)

```bash
# Check current path
xcode-select -p

# If shows /Library/Developer/CommandLineTools, fix it:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 3. Build & Install App

```bash
cd BabyInCarApp

# Build for simulator
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath build/

# Install to simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/BabyInCarApp.app
```

### 4. Grant Permissions (optional - prevents permission dialogs)

```bash
xcrun simctl privacy booted grant microphone com.anticry.babyincar
xcrun simctl privacy booted grant speech com.anticry.babyincar
```

---

## 🧪 Running Tests

### All Tests

```bash
~/.maestro/bin/maestro test maestro/flows/
```

### Individual Tests

```bash
# Onboarding flow (~30s)
~/.maestro/bin/maestro test maestro/flows/onboarding_flow.yaml

# Cry detection (~45s)
~/.maestro/bin/maestro test maestro/flows/cry_detection_flow.yaml

# Audio playback (~60s)
~/.maestro/bin/maestro test maestro/flows/playback_flow.yaml

# Library navigation (~45s)
~/.maestro/bin/maestro test maestro/flows/library_navigation_flow.yaml

# Playlist management (~60s)
~/.maestro/bin/maestro test maestro/flows/playlist_flow.yaml
```

### Visual Debugging

```bash
# Run test in interactive mode
~/.maestro/bin/maestro studio maestro/flows/cry_detection_flow.yaml
```

### Record Test Execution

```bash
# Save video of test run
~/.maestro/bin/maestro test --record maestro/flows/playback_flow.yaml
```

---

## 🔍 Troubleshooting

### "App not found"

Check if app is installed:
```bash
xcrun simctl list apps booted | grep babyincar
```

Reinstall:
```bash
xcrun simctl install booted BabyInCarApp/build/Build/Products/Debug-iphonesimulator/BabyInCarApp.app
```

### "Element not found"

Use Maestro Studio to inspect UI:
```bash
~/.maestro/bin/maestro studio
```

### Test times out

Simulator may be slow. Restart:
```bash
xcrun simctl shutdown all
xcrun simctl boot "iPhone 15"
```

### Permission dialogs block test

Grant permissions before running:
```bash
xcrun simctl privacy booted grant microphone com.anticry.babyincar
```

---

## 📊 Expected Results

### ✅ Passing Test Output

```
✅ onboarding_flow.yaml
  ✓ Welcome screen displayed
  ✓ Navigation to profile setup
  ✓ Profile created successfully
  ⏱ Duration: 28.4s

✅ cry_detection_flow.yaml
  ✓ Monitoring toggle works
  ✓ Calibration completed
  ✓ Emergency stop functional
  ⏱ Duration: 43.2s

...
```

### ❌ Failing Test Output

```
❌ playback_flow.yaml
  ✓ Play button found
  ✗ Element not found: pauseButton

  📸 Screenshot saved: ~/.maestro/tests/20260102_031500/screenshots/
  📹 Recording saved: ~/.maestro/tests/20260102_031500/recording.mp4
```

---

## 🎯 Test Coverage

| Flow | Duration | Critical? |
|------|----------|-----------|
| Onboarding | ~30s | ⭐⭐⭐ |
| Cry Detection | ~45s | ⭐⭐⭐ |
| Audio Playback | ~60s | ⭐⭐⭐ |
| Library Navigation | ~45s | ⭐⭐ |
| Playlist Management | ~60s | ⭐⭐ |

**Total Runtime**: ~4 minutes (all flows)

---

## 📝 Next Steps After Tests Pass

1. **Add Accessibility IDs** to all buttons/views
2. **Create unit tests** for PlaylistManager
3. **Add performance benchmarks** to E2E flows
4. **Integrate into CI/CD** (GitHub Actions)

---

## 🆘 Need Help?

- **Maestro Docs**: https://maestro.mobile.dev/
- **Test Failures**: Check [TEST_STATUS_REPORT.md](TEST_STATUS_REPORT.md)
- **Full Documentation**: See [maestro/README.md](maestro/README.md)
