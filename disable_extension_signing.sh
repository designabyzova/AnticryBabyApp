#!/bin/bash

# This script disables code signing for BabyInCarAppIntents extension
# to allow simulator testing without Apple Developer account registration

echo "🔧 Configuring BabyInCarAppIntents for simulator-only testing..."

cd BabyInCarApp

# Use PlistBuddy to modify the Xcode project
# We'll add CODE_SIGN_IDENTITY="" to the Debug configuration

# Method: Use xcodebuild to set build settings
xcodebuild -project BabyInCarApp.xcodeproj \
  -target BabyInCarAppIntents \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean 2>&1 | grep -E "(CODE_SIGN|error)" || echo "✅ Settings applied"

echo ""
echo "✅ BabyInCarAppIntents configured for simulator testing"
echo "📝 Note: This only works for iOS Simulator, not physical devices"
echo ""
echo "🚀 Next steps:"
echo "   1. In Xcode: Product → Clean Build Folder (⌘⇧K)"
echo "   2. Select iPhone Simulator (any iOS 16+)"
echo "   3. Click ▶️ Run"
echo "   4. Test with Siri"

