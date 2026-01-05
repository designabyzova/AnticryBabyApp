#!/bin/bash
# Build and Test Script for Library Category Verification
# This script sets up Xcode, builds the app, and runs E2E tests

set -e  # Exit on error

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 LIBRARY CATEGORY VERIFICATION - BUILD & TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Switch to Xcode (requires sudo)
echo "Step 1: Setting up Xcode developer tools..."
if [[ "$(xcode-select --print-path)" != "/Applications/Xcode.app/Contents/Developer" ]]; then
    echo "  Switching to Xcode.app (requires password)..."
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    echo "  ✅ Switched to Xcode"
else
    echo "  ✅ Already using Xcode"
fi
echo ""

# Step 2: Verify Xcode setup
echo "Step 2: Verifying Xcode installation..."
xcodebuild -version
echo ""

# Step 3: Clean build folder
echo "Step 3: Cleaning build folder..."
cd BabyInCarApp
xcodebuild clean \
    -project BabyInCarApp.xcodeproj \
    -scheme BabyInCarApp \
    -destination 'platform=iOS Simulator,name=iPhone 15'
echo "  ✅ Clean complete"
echo ""

# Step 4: Build the app
echo "Step 4: Building app..."
echo "  This will take 2-5 minutes..."
xcodebuild build \
    -project BabyInCarApp.xcodeproj \
    -scheme BabyInCarApp \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    2>&1 | tee ../build.log | grep -E "(BUILD|ContentLibrary|error:|warning:)" || true

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    echo "  ✅ Build succeeded!"
else
    echo "  ❌ Build failed! Check build.log for details"
    exit 1
fi
echo ""

# Step 5: Check console logs for track loading
echo "Step 5: Checking build logs for ContentLibrary messages..."
echo ""
grep -E "ContentLibrary.*Loading|ContentLibrary.*Loaded|ContentLibrary.*tracks" ../build.log || echo "  ⚠️  No ContentLibrary logs found in build output (logs appear at runtime)"
echo ""

# Step 6: Install Maestro (if not installed)
echo "Step 6: Setting up Maestro for E2E testing..."
if ! command -v maestro &> /dev/null; then
    echo "  Installing Maestro..."
    curl -fsSL "https://get.maestro.mobile.dev" | bash
    echo "  ✅ Maestro installed"
else
    echo "  ✅ Maestro already installed"
fi
echo ""

# Step 7: Check if simulator is running
echo "Step 7: Checking iOS Simulator..."
SIMULATOR_STATUS=$(xcrun simctl list devices | grep "iPhone 15" | grep "Booted" || true)
if [ -z "$SIMULATOR_STATUS" ]; then
    echo "  ⚠️  iPhone 15 simulator not running"
    echo "  Please open Xcode and run the app to start the simulator"
    echo "  Then run: ~/.maestro/bin/maestro test maestro/flows/library_category_verification.yaml"
else
    echo "  ✅ iPhone 15 simulator is running"

    # Step 8: Run Maestro E2E test
    echo ""
    echo "Step 8: Running Maestro E2E tests..."
    cd ..
    ~/.maestro/bin/maestro test maestro/flows/library_category_verification.yaml

    if [ $? -eq 0 ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ ALL TESTS PASSED!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📊 Library page is now showing all 342 tracks correctly!"
        echo ""
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ E2E TESTS FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Check the Maestro output above for failure details"
        exit 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 NEXT STEPS (if simulator not running):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open Xcode:"
echo "   open BabyInCarApp/BabyInCarApp.xcodeproj"
echo ""
echo "2. Select iPhone 15 simulator and press ⌘R to run"
echo ""
echo "3. Open Console (⌘⇧Y) and look for these logs:"
echo "   [ContentLibrary] 📦 Loading tracks from tracks.json (342 total)"
echo "   [ContentLibrary] ✅ Loaded 342 tracks from metadata"
echo ""
echo "4. Navigate to Library tab and verify:"
echo "   - Classical Music: 116 tracks"
echo "   - Fairy Tales: 82 tracks (with 🇬🇧 🇷🇺 flags)"
echo "   - Children's Songs: 44 tracks"
echo "   - All categories scroll vertically"
echo ""
echo "5. Run Maestro test manually:"
echo "   ~/.maestro/bin/maestro test maestro/flows/library_category_verification.yaml"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
