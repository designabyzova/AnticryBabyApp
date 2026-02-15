#!/bin/bash

# Xcode Cloud Post-Build Script
# Runs after xcodebuild completes (build or archive action)
# Distribution to TestFlight is handled by the Xcode Cloud workflow — NOT this script

set -e

echo "=== Xcode Cloud Post-Build ==="
echo "Scheme:   $CI_XCODE_SCHEME"
echo "Workflow: $CI_WORKFLOW"
echo "Build:    $CI_BUILD_NUMBER"
echo "Product:  $CI_PRODUCT"

# Skip non-archive actions
if [ -z "$CI_ARCHIVE_PATH" ]; then
    echo "Not an archive action — nothing to do."
    exit 0
fi

echo "Archive:  $CI_ARCHIVE_PATH"

# Validate the archive exists and contains the app
if [ ! -d "$CI_ARCHIVE_PATH" ]; then
    echo "WARNING: Archive path does not exist (build may have failed)."
    echo "=== Post-build complete (archive not available) ==="
    exit 0
fi

APP_PATH=$(find "$CI_ARCHIVE_PATH/Products" -name "*.app" -maxdepth 3 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "WARNING: No .app found inside archive (build may have failed)."
    echo "=== Post-build complete (app not found) ==="
    exit 0
fi

echo "App:      $APP_PATH"

# Print version info from the built app
INFO_PLIST="$APP_PATH/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "unknown")
    BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "unknown")
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "unknown")
    echo "---"
    echo "Bundle:   $BUNDLE_ID"
    echo "Version:  $VERSION ($BUILD)"
fi

# Verify privacy manifest is included
if [ -f "$APP_PATH/PrivacyInfo.xcprivacy" ]; then
    echo "Privacy manifest: included"
else
    echo "WARNING: PrivacyInfo.xcprivacy not found in app bundle!"
fi

echo "=== Post-build complete — Xcode Cloud will handle TestFlight distribution ==="
