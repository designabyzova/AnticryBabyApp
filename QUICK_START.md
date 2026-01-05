# 🚀 QUICK START: Verify Library Shows All 342 Tracks

## ⚡ One-Command Test

```bash
./build_and_test.sh
```

That's it! This script will:
1. Set up Xcode (prompts for password once)
2. Build the app
3. Install Maestro
4. Run E2E tests

---

## 📊 What to Expect

### During Build
```
Step 1: Setting up Xcode developer tools...
  Switching to Xcode.app (requires password)...
  [Enter your password]
  ✅ Switched to Xcode

Step 4: Building app...
  This will take 2-5 minutes...
  ✅ Build succeeded!
```

### In Console Logs
```
[ContentLibrary] 📦 Loading tracks from tracks.json (342 total)
[ContentLibrary] ✅ Loaded 342 tracks from metadata:
  - 📦 Bundled: 1
  - 🌐 Streamed: 341
  - By category: Classical=116, Fairy Tales=82, Children=44, Podcasts=0
```

### E2E Test Results
```
✅ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  library_category_verification
✅ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ALL TESTS PASSED!
📊 Library page is now showing all 342 tracks correctly!
```

---

## 🎯 Success Checklist

After running the script, verify:

- [ ] Build succeeded (no errors)
- [ ] Console shows "Loaded 342 tracks"
- [ ] E2E test passed
- [ ] Classical Music shows 116 tracks
- [ ] Fairy Tales shows 82 tracks
- [ ] All categories scroll vertically

---

## 🔧 Manual Alternative

If you prefer to test manually:

```bash
# 1. Open Xcode
open BabyInCarApp/BabyInCarApp.xcodeproj

# 2. Select iPhone 15 simulator
# 3. Press ⌘R to run
# 4. Open Console (⌘⇧Y)
# 5. Look for [ContentLibrary] logs
```

---

## 📚 More Info

- **Full details**: See [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md)
- **Troubleshooting**: See [LIBRARY_VERIFICATION_GUIDE.md](LIBRARY_VERIFICATION_GUIDE.md)
- **E2E test**: See [maestro/flows/library_category_verification.yaml](maestro/flows/library_category_verification.yaml)

---

## 💡 What Changed?

**Before**: Library showed ~5 tracks total
**After**: Library shows **342 tracks** across all categories

**Key fixes**:
- Fixed category mapping in ContentLibraryService
- Enabled R2 streaming for all tracks
- Added language detection for fairy tales

All code changes are in [ContentLibraryService.swift](BabyInCarApp/BabyInCarApp/Services/ContentLibraryService.swift)

---

Ready? Run: `./build_and_test.sh` 🚀
