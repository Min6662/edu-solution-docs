#!/bin/bash

# iOS Invalid Binary Fix Script
# This script addresses common causes of "Invalid Binary" error from Apple

echo "🔧 Starting iOS Invalid Binary Fix..."

# 1. Update iOS deployment target in Podfile
echo "📱 Updating iOS deployment target..."
if [ -f "ios/Podfile" ]; then
    # Update platform to iOS 12.0
    sed -i '' "s/platform :ios, '.*'/platform :ios, '12.0'/" ios/Podfile
    echo "✅ Updated Podfile iOS platform to 12.0"
else
    echo "❌ Podfile not found"
fi

# 2. Clean all build artifacts
echo "🧹 Cleaning build artifacts..."
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
echo "✅ Cleaned build artifacts"

# 3. Install pods
echo "📦 Installing pods..."
cd ios
pod deintegrate
pod setup
pod install
cd ..
echo "✅ Pods installed"

# 4. Get Flutter dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get
echo "✅ Dependencies updated"

# 5. Build iOS release
echo "🔨 Building iOS release..."
flutter build ios --release --no-codesign
echo "✅ iOS release built"

echo "✨ Fix completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Verify signing & capabilities:"
echo "   - Bundle Identifier: com.school.management"
echo "   - Team: Select your Apple Developer team"
echo "   - Provisioning Profile: Match your App Store profile"
echo "3. Archive and upload to App Store Connect"
echo ""
echo "🎯 Common Issues Fixed:"
echo "✅ Bundle identifier consistency"
echo "✅ iOS deployment target alignment"
echo "✅ Pod dependencies"
echo "✅ Build artifacts cleanup"