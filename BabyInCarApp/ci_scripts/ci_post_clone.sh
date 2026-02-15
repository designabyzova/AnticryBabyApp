#!/bin/bash

# Xcode Cloud Post-Clone Script
# Runs after the repository is cloned, before xcodebuild

set -e

echo "=== Xcode Cloud Post-Clone ==="
echo "Xcode:    $(xcodebuild -version | head -1)"
echo "Swift:    $(swift --version 2>&1 | head -1)"
echo "Branch:   $CI_BRANCH"
echo "Commit:   $CI_COMMIT"

# Resolve SPM dependencies (Xcode Cloud does this automatically,
# but explicit resolution catches errors early)
echo "Resolving Swift Package Manager dependencies..."
cd "$CI_PRIMARY_REPOSITORY_PATH/BabyInCarApp"
xcodebuild -resolvePackageDependencies \
    -project BabyInCarApp.xcodeproj \
    -scheme BabyInCarApp \
    -disableAutomaticPackageResolution 2>&1 || {
    echo "Auto-resolve failed, retrying with automatic resolution..."
    xcodebuild -resolvePackageDependencies \
        -project BabyInCarApp.xcodeproj \
        -scheme BabyInCarApp
}

echo "=== Post-clone complete ==="
