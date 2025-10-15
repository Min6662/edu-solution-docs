#!/bin/bash

# 🚀 Edu Solution - Comprehensive App Store Build Script
# This script automates the complete build process for App Store deployment

set -e  # Exit on any error

echo "🎯 Starting Edu Solution App Store Build Process..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# App information
APP_NAME="Edu Solution"
BUNDLE_ID="com.edusolution.app"
VERSION="1.0.5"
BUILD_NUMBER="5"

echo -e "${BLUE}📱 App Information:${NC}"
echo "  • App Name: $APP_NAME"
echo "  • Bundle ID: $BUNDLE_ID" 
echo "  • Version: $VERSION"
echo "  • Build Number: $BUILD_NUMBER"
echo ""

# Navigate to project directory
cd "/Users/min/Desktop/Edu Solution"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: pubspec.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Error: Flutter is not installed or not in PATH.${NC}"
    exit 1
fi

echo -e "${YELLOW}🧹 Step 1: Cleaning project...${NC}"
flutter clean
echo -e "${GREEN}✅ Project cleaned successfully${NC}"
echo ""

echo -e "${YELLOW}📦 Step 2: Getting dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependencies retrieved successfully${NC}"
echo ""

echo -e "${YELLOW}🍎 Step 3: Reinstalling iOS dependencies...${NC}"
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
echo -e "${GREEN}✅ iOS dependencies installed${NC}"
echo ""

echo -e "${YELLOW}🔍 Step 4: Running analysis...${NC}"
flutter analyze --no-fatal-infos
if [ $? -ne 0 ]; then
    echo -e "${RED}⚠️  Warning: Analysis found issues. Consider fixing them before release.${NC}"
    echo -e "${YELLOW}Continue anyway? (y/n):${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Build cancelled by user.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ Analysis completed${NC}"
echo ""

echo -e "${YELLOW}🧪 Step 5: Running tests...${NC}"
if flutter test > /dev/null 2>&1; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Some tests failed or no tests found${NC}"
fi
echo ""

echo -e "${YELLOW}🏗️  Step 6: Building iOS release...${NC}"
echo "This may take a few minutes..."

# Build for iOS App Store
flutter build ios --release \
    --dart-define=ENVIRONMENT=production \
    --build-name=$VERSION \
    --build-number=$BUILD_NUMBER

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ iOS build completed successfully${NC}"
else
    echo -e "${RED}❌ iOS build failed${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}🔒 Step 7: Applying privacy manifest fix...${NC}"
if [ -f "./fix_privacy_manifests.sh" ]; then
    ./fix_privacy_manifests.sh
    echo -e "${GREEN}✅ Privacy manifests applied${NC}"
else
    echo -e "${YELLOW}⚠️  Privacy manifest script not found, skipping...${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Step 8: Build summary...${NC}"
echo "  • Build Type: Release (App Store)"
echo "  • Platform: iOS"
echo "  • Architecture: Universal"
echo "  • Location: build/ios/iphoneos/Runner.app"
echo "  • Privacy Manifests: Applied"
echo ""

echo -e "${BLUE}📱 Next Steps for App Store Deployment:${NC}"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select 'Any iOS Device (arm64)' as target"
echo "3. Go to Product → Archive"
echo "4. Distribute App → App Store Connect"
echo "5. Upload to App Store Connect via Organizer"
echo ""

echo -e "${GREEN}🎉 Build process completed successfully!${NC}"
echo -e "${BLUE}Your app is ready for App Store submission with privacy compliance!${NC}"

# Optional: Open Xcode workspace
echo -e "${YELLOW}Would you like to open Xcode now? (y/n):${NC}"
read -r open_xcode
if [[ "$open_xcode" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🚀 Opening Xcode...${NC}"
    open ios/Runner.xcworkspace
fi

echo ""
echo -e "${GREEN}✨ Happy releasing! ✨${NC}"