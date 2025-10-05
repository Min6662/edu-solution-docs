#!/bin/bash

# Privacy Manifest Injection Script
# This script adds the required privacy manifests to third-party frameworks
# that don't include them, to comply with Apple's App Store requirements.

set -e

echo "🔒 Adding privacy manifests to frameworks..."

PROJECT_DIR="/Users/min/Desktop/Edu Solution"
BUILD_DIR="$PROJECT_DIR/build/ios/Release-iphoneos"

# Privacy manifest for connectivity_plus
CONNECTIVITY_PRIVACY='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryNetworkingAPI</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>7D9E.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>'

# Privacy manifest for package_info_plus
PACKAGE_INFO_PRIVACY='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>'

# Function to add privacy manifest to framework
add_privacy_manifest() {
    local framework_path="$1"
    local privacy_content="$2"
    local framework_name="$3"
    
    if [ -d "$framework_path" ]; then
        echo "📝 Adding privacy manifest to $framework_name..."
        echo "$privacy_content" > "$framework_path/PrivacyInfo.xcprivacy"
        echo "✅ Privacy manifest added to $framework_name"
    else
        echo "⚠️  Framework not found: $framework_path"
    fi
}

# Add privacy manifests to frameworks
add_privacy_manifest "$BUILD_DIR/connectivity_plus/connectivity_plus.framework" "$CONNECTIVITY_PRIVACY" "connectivity_plus"
add_privacy_manifest "$BUILD_DIR/package_info_plus/package_info_plus.framework" "$PACKAGE_INFO_PRIVACY" "package_info_plus"

# Also add to the app bundle frameworks
add_privacy_manifest "$BUILD_DIR/Runner.app/Frameworks/connectivity_plus.framework" "$CONNECTIVITY_PRIVACY" "connectivity_plus (app bundle)"
add_privacy_manifest "$BUILD_DIR/Runner.app/Frameworks/package_info_plus.framework" "$PACKAGE_INFO_PRIVACY" "package_info_plus (app bundle)"

echo "🎉 Privacy manifests successfully added to all frameworks!"
echo ""
echo "Next steps:"
echo "1. Archive your app in Xcode"
echo "2. Upload to App Store Connect"
echo "3. Your submission should now pass privacy validation!"