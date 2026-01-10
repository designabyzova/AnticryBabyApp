#!/bin/bash

# Xcode Cloud Post-Build Script
# This script runs after each successful archive build
# It automatically uploads the build to TestFlight

set -e

echo "=== Xcode Cloud Post-Build Script ==="
echo "CI_ARCHIVE_PATH: $CI_ARCHIVE_PATH"
echo "CI_PRODUCT: $CI_PRODUCT"
echo "CI_XCODE_PROJECT: $CI_XCODE_PROJECT"
echo "CI_XCODE_SCHEME: $CI_XCODE_SCHEME"
echo "CI_WORKFLOW: $CI_WORKFLOW"
echo "CI_BUILD_NUMBER: $CI_BUILD_NUMBER"

# Only process if we have an archive (archive action completed)
if [ -z "$CI_ARCHIVE_PATH" ]; then
    echo "No archive path - this is not an archive action. Skipping TestFlight upload."
    exit 0
fi

# Check if this is the main app scheme (not watch app)
if [[ "$CI_XCODE_SCHEME" != "BabyInCarApp" ]]; then
    echo "Scheme is $CI_XCODE_SCHEME - skipping (only BabyInCarApp uploads to TestFlight)"
    exit 0
fi

echo "Archive found at: $CI_ARCHIVE_PATH"

# Export the archive to IPA
EXPORT_PATH="$CI_DERIVED_DATA_PATH/Export"
mkdir -p "$EXPORT_PATH"

# Create export options plist for App Store distribution
EXPORT_OPTIONS="$EXPORT_PATH/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>teamID</key>
    <string>NMCB2JZ7QG</string>
</dict>
</plist>
EOF

echo "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$CI_ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

echo "=== Archive exported successfully ==="
echo "The build will be automatically submitted to TestFlight by Xcode Cloud"

# Note: When using Xcode Cloud with "destination: upload",
# the build is automatically uploaded to App Store Connect/TestFlight
# No need for manual altool upload

echo "=== Post-build script completed ==="
