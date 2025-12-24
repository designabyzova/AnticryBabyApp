# How to Run Baby in Car iOS App

## 📋 Prerequisites

### 1. Install Xcode (Required)
- Open **Mac App Store**
- Search for **"Xcode"**
- Click **Get** → **Install** (free, ~12GB)
- Wait 30-60 minutes for download
- Open Xcode once to accept license and install components

### 2. After Xcode Installation
Open Terminal and run:
```bash
# Switch to full Xcode (not just command line tools)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Accept license
sudo xcodebuild -license accept

# Install iOS Simulator runtime (if prompted)
xcodebuild -downloadPlatform iOS
```

### 3. Apple ID (Required for Physical Device)
- Free Apple ID works for 7-day testing
- Paid Developer Account ($99/year) for App Store publishing

---

## 🖥️ Running on iOS Simulator

### Method 1: Using Xcode (Recommended)

1. **Open the Project**
   ```bash
   open "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp.xcodeproj"
   ```
   Or double-click `BabyInCarApp.xcodeproj` in Finder

2. **Wait for Indexing**
   - Xcode will show "Indexing..." in the Activity bar
   - Wait until it completes (1-3 minutes first time)

3. **Select a Simulator**
   - Look at the top toolbar in Xcode
   - Click on the device name (might say "Any iOS Device")
   - Choose a simulator, e.g.:
     - **iPhone 15 Pro** (latest)
     - **iPhone 14** (good for testing)
     - **iPhone SE (3rd generation)** (smallest screen)

4. **Build and Run**
   - Press **⌘R** (Command + R)
   - Or click the **▶ Play button** in top-left
   - Wait for build (first time takes 2-5 minutes)
   - Simulator launches automatically with your app!

### Method 2: Using Terminal

```bash
# Navigate to project
cd "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp"

# List available simulators
xcrun simctl list devices available

# Build and run on specific simulator
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug \
  build

# Then launch simulator
open -a Simulator

# Install the app
xcrun simctl install booted build/Debug-iphonesimulator/BabyInCarApp.app

# Launch the app
xcrun simctl launch booted com.babyincar.app
```

### Simulator Tips
- **Rotate**: ⌘← or ⌘→
- **Home button**: ⌘⇧H (Shift+Command+H)
- **Screenshot**: ⌘S
- **Shake gesture**: ⌘⌃Z (Control+Command+Z)
- **Toggle keyboard**: ⌘K

---

## 📱 Running on Physical iPhone

### Step 1: Connect Your iPhone

1. **Plug in iPhone** with Lightning/USB-C cable
2. **Unlock iPhone**
3. **Trust this Computer** - tap "Trust" on iPhone popup
4. Enter your iPhone passcode if asked

### Step 2: Configure Signing in Xcode

1. **Open Project** in Xcode (if not already open)
   ```bash
   open "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp.xcodeproj"
   ```

2. **Select Project in Navigator**
   - Click on **BabyInCarApp** (blue icon) in left sidebar
   - This opens project settings

3. **Select Target**
   - In the center panel, click **BabyInCarApp** under TARGETS

4. **Go to Signing & Capabilities Tab**
   - Click **Signing & Capabilities** tab at the top

5. **Enable Automatic Signing**
   - Check ✅ **Automatically manage signing**

6. **Select Your Team**
   - Click **Team** dropdown
   - If empty, click **Add Account...**
   - Sign in with your **Apple ID** (any Apple ID works!)
   - Select your name/team from dropdown

7. **Change Bundle Identifier** (Required for personal team)
   - Find **Bundle Identifier** field
   - Change from `com.babyincar.app` to something unique:
     ```
     com.YOURNAME.babyincar
     ```
   - Example: `com.johnsmith.babyincar`

8. **Wait for Provisioning**
   - Xcode creates a signing certificate automatically
   - Yellow warning → should turn to ✅ green checkmark

### Step 3: Select Your iPhone

1. **Find Device Selector** - top toolbar in Xcode
2. **Click on it** (might say "iPhone 15 Pro" or similar)
3. **Find your iPhone** under "iOS Devices" section
   - It shows your iPhone's name
4. **Select it**

### Step 4: Build and Run

1. Press **⌘R** (Command + R) or click **▶ Play**
2. **First time on device - you'll get an error!** This is normal.

### Step 5: Trust Developer on iPhone (First Time Only)

You'll see error: "Could not launch. iPhone is not trusted"

**On your iPhone:**
1. Go to **Settings**
2. Tap **General**
3. Scroll down to **VPN & Device Management**
4. Tap on **Developer App** (your Apple ID email)
5. Tap **Trust "[Your Email]"**
6. Tap **Trust** to confirm

### Step 6: Run Again

1. Back in Xcode, press **⌘R** again
2. App should now install and launch! 🎉

---

## 🔧 Troubleshooting

### "No signing certificate"
```
Solution:
1. Xcode → Settings → Accounts
2. Click your Apple ID
3. Click "Manage Certificates"
4. Click + → "Apple Development"
5. Try building again
```

### "Device is busy" or "Preparing device"
```
Solution:
- Wait 2-3 minutes (Xcode is processing device)
- Unplug and replug iPhone
- Restart Xcode
```

### "App installation failed"
```
Solution:
1. On iPhone: Settings → General → iPhone Storage
2. Find and delete "BabyInCarApp" if present
3. Try running again from Xcode
```

### "Untrusted Developer"
```
Solution:
iPhone → Settings → General → VPN & Device Management → Trust
```

### Build Errors
```
Solution:
1. Xcode → Product → Clean Build Folder (⌘⇧K)
2. Close Xcode
3. Delete: ~/Library/Developer/Xcode/DerivedData
4. Reopen project and build again
```

### "Provisioning profile" errors
```
Solution:
1. Change Bundle Identifier to something unique
2. Xcode → Product → Clean Build Folder
3. Build again
```

### CarPlay Not Working in Simulator
```
Note: CarPlay requires special entitlements.
For testing, Apple requires you to:
1. Request CarPlay entitlement from Apple
2. Use a physical CarPlay-enabled device/head unit
```

---

## 📊 Quick Reference

### Keyboard Shortcuts (Xcode)
| Action | Shortcut |
|--------|----------|
| Run | ⌘R |
| Stop | ⌘. |
| Clean Build | ⌘⇧K |
| Build Only | ⌘B |
| Show/Hide Navigator | ⌘0 |
| Show/Hide Debug | ⌘⇧Y |

### Simulator Shortcuts
| Action | Shortcut |
|--------|----------|
| Home | ⌘⇧H |
| Rotate Left | ⌘← |
| Rotate Right | ⌘→ |
| Shake | ⌃⌘Z |
| Screenshot | ⌘S |
| Toggle Keyboard | ⌘K |

---

## ✅ Success Checklist

### Simulator
- [ ] Xcode installed from App Store
- [ ] Project opens without errors
- [ ] Simulator selected (iPhone 15 Pro)
- [ ] Build succeeds (⌘R)
- [ ] App appears in simulator

### Physical Device
- [ ] iPhone connected via cable
- [ ] "Trust This Computer" accepted on iPhone
- [ ] Signed in with Apple ID in Xcode
- [ ] Bundle ID changed to unique value
- [ ] Team selected (your Apple ID)
- [ ] Green checkmark in Signing & Capabilities
- [ ] Your iPhone selected as destination
- [ ] Developer trusted on iPhone (Settings)
- [ ] App launches on iPhone

---

## 🚀 Next Steps After Running

1. **Test the App**
   - Complete onboarding
   - Add a baby profile
   - Play some audio tracks
   - Try the Emergency Cry-Stop button

2. **Test Voice Commands** (Physical device only)
   - "Play music"
   - "Stop"
   - "Play white noise"

3. **Deploy Backend** (for full functionality)
   - See `babyincar-api/SECRETS_AND_DEPLOYMENT.md`

---

## 📞 Still Having Issues?

1. **Restart Xcode** - Fixes 50% of issues
2. **Restart Mac** - Fixes another 25%
3. **Delete DerivedData**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. **Check Apple Developer Status**: [developer.apple.com/system-status](https://developer.apple.com/system-status/)
