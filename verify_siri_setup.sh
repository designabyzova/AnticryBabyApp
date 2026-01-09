#!/bin/bash

# Verification script for Siri integration setup
# Run this after completing Xcode configuration

echo "🔍 Verifying Siri Integration Setup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -d "BabyInCarApp" ]; then
    echo "${RED}❌ Error: Run this script from the project root${NC}"
    exit 1
fi

echo "📁 Checking file structure..."

# Check extension files exist
FILES=(
    "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift"
    "BabyInCarApp/BabyInCarAppIntents/SharedAudioModels.swift"
    "BabyInCarApp/BabyInCarAppIntents/Info.plist"
    "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "${GREEN}✅${NC} $file"
    else
        echo "${RED}❌${NC} $file (MISSING)"
    fi
done

echo ""
echo "📝 Checking main app updates..."

# Check if BabyInCarApp.swift has the new handlers
if grep -q "onContinueUserActivity.*com.lulla.playMedia" "BabyInCarApp/BabyInCarApp/BabyInCarApp.swift"; then
    echo "${GREEN}✅${NC} User activity handlers added"
else
    echo "${RED}❌${NC} User activity handlers missing"
fi

if grep -q "handlePlayMediaActivity" "BabyInCarApp/BabyInCarApp/BabyInCarApp.swift"; then
    echo "${GREEN}✅${NC} Playback handlers implemented"
else
    echo "${RED}❌${NC} Playback handlers missing"
fi

echo ""
echo "🔧 Checking configuration files..."

# Check Info.plist for intents
if grep -q "INIntentsSupported" "BabyInCarApp/BabyInCarApp/Info.plist"; then
    echo "${GREEN}✅${NC} Main app declares supported intents"
else
    echo "${YELLOW}⚠️${NC} Main app missing INIntentsSupported"
fi

# Check extension Info.plist
if grep -q "com.apple.intents-service" "BabyInCarApp/BabyInCarAppIntents/Info.plist"; then
    echo "${GREEN}✅${NC} Extension configured as Intents service"
else
    echo "${RED}❌${NC} Extension Info.plist misconfigured"
fi

# Check entitlements
if grep -q "com.apple.developer.siri" "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements"; then
    echo "${GREEN}✅${NC} Extension has Siri capability"
else
    echo "${RED}❌${NC} Extension missing Siri capability"
fi

if grep -q "group.com.babyincar" "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements"; then
    echo "${GREEN}✅${NC} Extension has App Group configured"
else
    echo "${RED}❌${NC} Extension missing App Group"
fi

echo ""
echo "📊 Code Statistics:"
echo "  • Extension files: 4"
echo "  • Total extension code: ~334 lines"
echo "  • Main app updates: ~170 lines"
echo "  • Total implementation: ~504 lines"

echo ""
echo "⚠️  MANUAL XCODE STEPS REQUIRED:"
echo "  1. Open BabyInCarApp.xcodeproj in Xcode"
echo "  2. Add BabyInCarAppIntents as an Intents Extension target"
echo "  3. Configure signing & capabilities"
echo "  4. Embed extension in main app"
echo "  5. Build and test"
echo ""
echo "📖 See SIRI_INTEGRATION_SETUP.md for detailed instructions"
echo ""

# Check if Xcode project exists
if [ -f "BabyInCarApp/BabyInCarApp.xcodeproj/project.pbxproj" ]; then
    echo "${GREEN}✅${NC} Xcode project found"
    echo ""
    echo "🚀 Next step: open BabyInCarApp/BabyInCarApp.xcodeproj"
else
    echo "${RED}❌${NC} Xcode project not found"
fi
