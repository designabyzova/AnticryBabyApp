#!/bin/bash
# Build the MAIN BabyInCarApp (not Watch app)

cd "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp"

echo "🔍 Finding main app target..."

# Switch to full Xcode (requires password - will prompt)
echo "Switching to Xcode developer directory..."
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Clean build
echo "🧹 Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/BabyInCarApp-*

# Build the MAIN app (not watch)
echo "🔨 Building BabyInCarApp..."
xcodebuild -project BabyInCarApp.xcodeproj \
  -scheme BabyInCarApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  clean build

echo "✅ Build complete!"
