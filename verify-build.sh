#!/bin/bash
# Build verification script for BabyInCarApp
# This script attempts to verify the build without requiring sudo

set -e

echo "🔍 BUILD VERIFICATION SCRIPT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$(dirname "$0")/BabyInCarApp"

echo "📋 Project: BabyInCarApp"
echo "📍 Location: $(pwd)"
echo ""

# Check if Xcode is available
if command -v xcodebuild &> /dev/null; then
    echo "✅ xcodebuild found"

    # Try to run xcodebuild
    echo ""
    echo "🔨 Attempting build with xcodebuild..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    xcodebuild \
        -project BabyInCarApp.xcodeproj \
        -scheme BabyInCarApp \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        clean build \
        2>&1 | tee build-output.log

    BUILD_STATUS=$?

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $BUILD_STATUS -eq 0 ]; then
        echo "✅ BUILD SUCCESSFUL!"

        # Count warnings
        WARNINGS=$(grep -c "warning:" build-output.log || echo "0")
        echo "⚠️  Warnings: $WARNINGS"

        if [ $WARNINGS -gt 0 ]; then
            echo ""
            echo "📋 Warning Summary:"
            grep "warning:" build-output.log | head -10
        fi

        exit 0
    else
        echo "❌ BUILD FAILED!"

        # Show errors
        echo ""
        echo "📋 Error Summary:"
        grep "error:" build-output.log | head -20

        exit 1
    fi
else
    echo "❌ xcodebuild not found or not configured"
    echo ""
    echo "💡 To fix this, run:"
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "⚠️  Cannot verify build without xcodebuild"
    exit 1
fi
