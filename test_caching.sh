#!/bin/bash

echo "🧪 Testing Caching Features for Add Student Screen"
echo "=================================================="

echo "📱 To test the caching functionality:"
echo ""
echo "1. FORM DATA CACHING:"
echo "   • Fill in student name, address, phone, etc."
echo "   • Select morning/evening classes from dropdowns"
echo "   • Add a photo from gallery"
echo "   • Close the app completely"
echo "   • Reopen and go to Add Student screen"
echo "   • ✅ All fields should be restored including dropdowns and image"
echo ""

echo "2. CLASS LIST CACHING:"
echo "   • Open Add Student screen first time (loads from server)"
echo "   • Close and reopen app"
echo "   • Open Add Student screen again"
echo "   • ✅ Class dropdowns should load instantly from cache"
echo ""

echo "3. CACHE CLEARING:"
echo "   • Long press the app title in Add Student screen"
echo "   • Select 'Clear Cache' option"
echo "   • ✅ All form data should be cleared"
echo ""

echo "4. AUTO CACHE CLEANUP:"
echo "   • Save a student successfully"
echo "   • ✅ Form cache should be automatically cleared"
echo ""

echo "🏗️ Building the app for testing..."
cd "/Users/min/Desktop/Edu Solution"
flutter clean
flutter pub get

# Try building debug APK
if flutter build apk --debug; then
    echo ""
    echo "✅ BUILD SUCCESSFUL!"
    echo "📱 APK: build/app/outputs/flutter-apk/app-debug.apk"
    echo ""
    echo "🔧 To install and test:"
    echo "adb install build/app/outputs/flutter-apk/app-debug.apk"
else
    echo ""
    echo "❌ Build failed, trying flutter run..."
    echo "🏃 Running in debug mode..."
    flutter run --debug
fi

echo ""
echo "🐛 DEBUG LOGS TO WATCH:"
echo "Look for these log messages:"
echo "• 'Form data saved to cache (including image info)'"
echo "• 'Image saved to cache: [path]'"
echo "• 'Loaded X classes from cache'"
echo "• 'Restoring class selections - Morning: X, Evening: Y'"
echo "• 'Form data loaded from cache (including image and dropdown selections)'"