#!/bin/bash

echo "=== Testing Enrollment Fix ==="
echo "1. Cleaning project..."
flutter clean

echo "2. Getting dependencies..."
flutter pub get

echo "3. Building debug APK..."
flutter build apk --debug

echo "4. APK built successfully!"
echo "Install the APK from: build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "To test the fix:"
echo "1. Add a student and assign them to a class"
echo "2. Go to class list and click 'View' on that class"
echo "3. The student should now appear in the enrolled students list"
echo "4. Check the debug logs for enrollment creation details"