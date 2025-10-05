#!/bin/bash

# Automated iOS Build with Privacy Manifest Fix
# This script builds your iOS app and automatically adds required privacy manifests

set -e

echo "🚀 Starting iOS build with privacy manifest fix..."

# Navigate to project directory
cd "/Users/min/Desktop/Edu Solution"

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Reinstall pods
echo "📦 Reinstalling iOS dependencies..."
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..

# Build iOS app
echo "🔨 Building iOS app..."
flutter build ios --release

# Apply privacy manifest fix
echo "🔒 Applying privacy manifest fix..."
./fix_privacy_manifests.sh

echo ""
echo "✅ Build complete with privacy manifests!"
echo ""
echo "🎯 Next steps for App Store submission:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select 'Any iOS Device (arm64)'"
echo "3. Product → Archive"
echo "4. Distribute App → App Store Connect"
echo ""
echo "Your app should now pass Apple's privacy validation! 🎉"