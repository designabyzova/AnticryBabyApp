#!/bin/bash

# Siri Integration Setup Verification Script
# Checks that all components are correctly configured

set -e

echo "🔍 Verifying Siri Integration Setup..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅ $1 exists${NC}"
    else
        echo -e "${RED}❌ $1 NOT FOUND${NC}"
        ((ERRORS++))
    fi
}

# Function to check string in file
check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✅ $1 contains: $2${NC}"
    else
        echo -e "${RED}❌ $1 missing: $2${NC}"
        ((ERRORS++))
    fi
}

echo "📁 1. Checking Extension Files..."
check_file "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift"
check_file "BabyInCarApp/BabyInCarAppIntents/Info.plist"
check_file "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements"
echo ""

echo "📝 2. Checking IntentHandler.swift Implementation..."
check_content "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift" "INPlayMediaIntentHandling"
check_content "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift" "INSearchForMediaIntentHandling"
check_content "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift" "INAddMediaIntentHandling"
check_content "BabyInCarApp/BabyInCarAppIntents/IntentHandler.swift" "parseCategory"
echo ""

echo "🎛️ 3. Checking Info.plist Configuration..."
check_content "BabyInCarApp/BabyInCarAppIntents/Info.plist" "com.apple.intents-service"
check_content "BabyInCarApp/BabyInCarAppIntents/Info.plist" "INPlayMediaIntent"
check_content "BabyInCarApp/BabyInCarAppIntents/Info.plist" "INSearchForMediaIntent"
check_content "BabyInCarApp/BabyInCarAppIntents/Info.plist" "INAddMediaIntent"
echo ""

echo "🔐 4. Checking Entitlements..."
check_content "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements" "com.apple.developer.siri"
check_content "BabyInCarApp/BabyInCarAppIntents/BabyInCarAppIntents.entitlements" "group.com.babyincar"
echo ""

echo "📱 5. Checking Main App Integration..."
check_content "BabyInCarApp/BabyInCarApp/BabyInCarApp.swift" "onContinueUserActivity"
check_content "BabyInCarApp/BabyInCarApp/BabyInCarApp.swift" "com.lulla.playMedia"
check_content "BabyInCarApp/BabyInCarApp/BabyInCarApp.swift" "handlePlayMediaActivity"
echo ""

echo "🔧 6. Checking Code Signing Configuration..."
if grep -q "CODE_SIGNING_ALLOWED = NO" BabyInCarApp/BabyInCarApp.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✅ Code signing disabled for extensions${NC}"
else
    echo -e "${RED}❌ Code signing NOT disabled${NC}"
    ((ERRORS++))
fi

# Count occurrences (should be 4 - main app + 2 extensions + tests)
SIGNING_COUNT=$(grep -c "CODE_SIGNING_ALLOWED = NO" BabyInCarApp/BabyInCarApp.xcodeproj/project.pbxproj 2>/dev/null || echo "0")
if [ "$SIGNING_COUNT" -eq 4 ]; then
    echo -e "${GREEN}✅ All 4 targets configured (main + 2 extensions + tests)${NC}"
else
    echo -e "${YELLOW}⚠️  Expected 4 targets, found: $SIGNING_COUNT${NC}"
    ((WARNINGS++))
fi
echo ""

echo "📋 7. Summary..."
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ ALL CHECKS PASSED! Setup is complete! 🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open Xcode: open BabyInCarApp/BabyInCarApp.xcodeproj"
    echo "2. Clean build: ⌘⇧K"
    echo "3. Build: ⌘B"
    echo "4. Run: ⌘R"
    echo "5. Test Siri: Type 'play lullabies in Lulla'"
    echo ""
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Setup should work, but review warnings above."
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Please fix the errors above before proceeding."
    exit 1
fi
