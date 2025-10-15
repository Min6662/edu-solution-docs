#!/bin/bash

# Test build script for the education app
echo "🚀 Starting build process..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Try to build debug APK
echo "🔨 Building debug APK..."
flutter build apk --debug

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📱 APK location: build/app/outputs/flutter-apk/app-debug.apk"
    
    # Check if ADB is available and device connected
    if command -v adb &> /dev/null; then
        echo "📋 Checking for connected devices..."
        adb devices
        
        echo "🔄 To install on device, run:"
        echo "adb install build/app/outputs/flutter-apk/app-debug.apk"
    fi
else
    echo "❌ Build failed!"
    echo "💡 Trying alternative approach..."
    
    # Try flutter run instead
    echo "🏃 Attempting to run directly..."
    flutter run --debug
fi