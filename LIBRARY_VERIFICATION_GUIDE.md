# Library Category Verification Guide

## 🎯 What Was Fixed

The Library page was only showing 1 track per category because:

1. **Category Mapping Bug** - Categories from `tracks.json` weren't mapping correctly to Swift enums
2. **Streaming Disabled** - Only bundled tracks (1 emergency track) were being loaded, not the 341 streamed tracks from R2

### Fixes Applied

✅ **Fixed category mapping** in [ContentLibraryService.swift:398-438](BabyInCarApp/BabyInCarApp/Services/ContentLibraryService.swift#L398-L438)
- Added explicit mappings for all categories: `classical`, `fairytales_en`, `fairytales_ru`, `children`, `lullabies`, `ambient`, `acoustic`
- Added debug logging for unknown categories

✅ **Enabled R2 streaming** in [ContentLibraryService.swift:311-400](BabyInCarApp/BabyInCarApp/Services/ContentLibraryService.swift#L311-L400)
- All 342 tracks from `tracks.json` now load
- Non-bundled tracks marked as `.streamed` with R2 URLs
- Bundled tracks marked as `.bundled`

✅ **Added comprehensive logging**
- Shows total tracks loaded
- Shows bundled vs streamed counts
- Shows per-category breakdown

## 📊 Expected Track Counts

After the fix, you should see:

| Category | Track Count | Source |
|----------|-------------|--------|
| **Classical Music** | 116 | tracks.json |
| **Fairy Tales** | 82 (44 EN + 38 RU) | tracks.json (fairytales_en + fairytales_ru) |
| **Children's Songs** | 44 | tracks.json (children + lullabies) |
| **Instrumental** | 42 | tracks.json (ambient + acoustic) |
| **Nature Sounds** | ~56+ | Generated sounds + bundled |
| **White Noise** | ~10 | Generated sounds |
| **Podcasts** | Variable | podcast_metadata.json files |

**Total: 342+ tracks across all categories**

## 🧪 Testing Steps

### Step 1: Build the App in Xcode

```bash
# Open Xcode
open BabyInCarApp/BabyInCarApp.xcodeproj

# OR build from command line (if Xcode is set as default)
cd BabyInCarApp
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

### Step 2: Run the App and Check Console

**In Xcode:**
1. Select iPhone 15 simulator
2. Click Run (⌘R)
3. Open Console (⌘⇧Y)
4. Look for these log messages on app launch:

```
[ContentLibrary] 📦 Loading tracks from tracks.json (342 total)
[ContentLibrary] ✅ Loaded 342 tracks from metadata:
  - 📦 Bundled: 1
  - 🌐 Streamed: 341
  - By category: Classical=116, Fairy Tales=82, Children=44, Podcasts=0
```

**✅ SUCCESS CRITERIA**: You should see **342 total tracks loaded**

### Step 3: Manual UI Verification

**Navigate to Library tab and verify:**

1. **Classical Music**
   - Tap "Classical Music" category
   - Should see **116 tracks** (scroll to verify multiple pages)
   - Tracks should show: Mozart, Bach, Chopin, Brahms, etc.

2. **Fairy Tales**
   - Tap "Fairy Tales" category
   - Should see **82 tracks** total
   - Some tracks should show 🇬🇧 flag (English)
   - Some tracks should show 🇷🇺 flag (Russian)

3. **Children's Songs**
   - Tap "Children's Songs" category
   - Should see **44 tracks** (includes lullabies)

4. **Instrumental**
   - Tap "Instrumental" category
   - Should see **42 tracks** (ambient + acoustic)

5. **Nature Sounds**
   - Tap "Nature Sounds" category
   - Should see multiple tracks (ocean, birds, river, etc.)

6. **Category Filter Chips**
   - Scroll to top of Library page
   - See filter chips: All, Classical Music, Fairy Tales, etc.
   - Tap each filter to show only that category

### Step 4: Run Maestro E2E Test

**Install Maestro** (if not already installed):
```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
```

**Run the verification test:**
```bash
# From project root
~/.maestro/bin/maestro test maestro/flows/library_category_verification.yaml
```

**Expected output:**
```
✅ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  library_category_verification
✅ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Flow completed successfully! (Screenshot: library_categories_verified.png)
```

### Step 5: Verify Streaming Works

**Test streaming playback:**

1. Tap any track from Classical Music category
2. Should start playing (streaming from R2)
3. Check console for streaming logs
4. Verify track plays without errors

**Expected console logs:**
```
[AudioEngine] 🎵 Playing track: [Track Title] (streamed)
[AudioEngine] 📡 Streaming URL: https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/...
```

## 🐛 Troubleshooting

### Issue: Still seeing only 1 track per category

**Check:**
```bash
# Verify tracks.json exists and has 342 tracks
jq '.tracks | length' BabyInCarApp/BabyInCarApp/Resources/Audio/tracks.json

# Should output: 342
```

**Solution:** Rebuild the app (⌘⇧K to clean, then ⌘R to run)

### Issue: Console doesn't show ContentLibrary logs

**Check:**
1. In Xcode Console, enable "Debug" level logging
2. Clear console and relaunch app
3. Logs appear on app startup in `ContentLibraryService.init()`

### Issue: Tracks won't play (streaming error)

**Check:**
1. Verify internet connection
2. Check R2 URL is accessible: https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev
3. Look for 404 errors in console - means track file not uploaded to R2 yet

**Temporary fix:** Mark track as bundled or download to cache

### Issue: Maestro test fails

**Check:**
1. App is installed on simulator
2. Simulator is running iOS 15+ with correct device name
3. Accessibility identifiers exist in SwiftUI views

**Run in debug mode:**
```bash
~/.maestro/bin/maestro test --debug maestro/flows/library_category_verification.yaml
```

## 📝 Verification Checklist

Before considering the task complete, verify:

- [ ] Console shows "Loaded 342 tracks from metadata"
- [ ] Console shows bundled vs streamed breakdown
- [ ] Console shows per-category counts (Classical=116, etc.)
- [ ] Classical Music category shows 116 tracks in UI
- [ ] Fairy Tales category shows 82 tracks with language flags
- [ ] Children's Songs category shows 44 tracks
- [ ] Instrumental category shows 42 tracks
- [ ] All categories are scrollable vertically
- [ ] Category filter chips work correctly
- [ ] Search finds tracks across all categories
- [ ] Streaming playback works for non-bundled tracks
- [ ] Maestro E2E test passes completely

## 🎉 Success Criteria

**The Library page is working correctly when:**

1. ✅ All 342 tracks load on app startup (console confirms)
2. ✅ Each category shows the correct track count
3. ✅ Tapping a category shows all tracks (not just 1)
4. ✅ Vertical scrolling works in category detail views
5. ✅ Language flags appear for fairy tales (🇬🇧 🇷🇺)
6. ✅ Streaming playback works from R2
7. ✅ Maestro E2E test passes all assertions

---

## 🔍 Code References

**Key files modified:**
- [ContentLibraryService.swift:311-438](BabyInCarApp/BabyInCarApp/Services/ContentLibraryService.swift#L311-L438) - Track loading and category mapping
- [LibraryView.swift:45-116](BabyInCarApp/BabyInCarApp/Views/LibraryView.swift#L45-L116) - Library UI (already had vertical scrolling)
- [CategoryDetailView.swift:910-1010](BabyInCarApp/BabyInCarApp/Views/LibraryView.swift#L910-L1010) - Category detail (already had vertical scrolling)

**E2E Test:**
- [library_category_verification.yaml](maestro/flows/library_category_verification.yaml) - Comprehensive category verification

**Track metadata:**
- [tracks.json](BabyInCarApp/BabyInCarApp/Resources/Audio/tracks.json) - 342 track definitions
