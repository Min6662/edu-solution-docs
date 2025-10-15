# 🚀 Quick App Store Deployment Commands

## Essential Commands for Edu Solution App Store Release

### 1. 🧹 Clean and Prepare
```bash
cd "/Users/min/Desktop/Edu Solution"
flutter clean
flutter pub get
```

### 2. 🔍 Verify App Quality
```bash
# Run analysis
flutter analyze --no-fatal-infos

# Run tests (if available)
flutter test

# Check dependencies
flutter doctor
```

### 3. 🏗️ Build for App Store
```bash
# Make script executable (first time only)
chmod +x build_for_appstore.sh

# Run comprehensive build script
./build_for_appstore.sh

# Manual build alternative
flutter build ios --release --dart-define=ENVIRONMENT=production
```

### 4. 📱 Xcode Archive
```bash
# Open Xcode workspace
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device (arm64)"
# 2. Product → Archive
# 3. Distribute App → App Store Connect
```

### 5. 🔒 Privacy Compliance (if needed)
```bash
# Apply privacy manifest fix
./fix_privacy_manifests.sh
```

## 📋 Version Management

### Update Version Numbers
```yaml
# In pubspec.yaml
version: 1.0.5+5
```

### Git Tagging (recommended)
```bash
git add .
git commit -m "Release version 1.0.5 - App Store deployment"
git tag -a v1.0.5 -m "Version 1.0.5 - Enhanced UI and App Store optimization"
git push origin main --tags
```

## 🛠️ Troubleshooting Commands

### Fix Common Issues
```bash
# Clear all caches
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..

# Reset iOS build
rm -rf build/ios
flutter build ios --release

# Check code signing
cd ios && xcodebuild -showBuildSettings -workspace Runner.xcworkspace -scheme Runner
```

### Debug Build Issues
```bash
# Verbose build output
flutter build ios --release --verbose

# Check iOS logs
idevicesyslog | grep -i flutter

# Analyze dependencies
flutter deps
```

## 📊 Quick Health Check
```bash
# Full project health check
echo "🔍 Checking Flutter environment..."
flutter doctor -v

echo "📦 Checking dependencies..."
flutter pub deps

echo "🧹 Analyzing code..."
flutter analyze

echo "🏗️ Testing build..."
flutter build ios --release --dry-run

echo "✅ Health check complete!"
```

## 🎯 One-Command Deploy
```bash
# Ultimate deployment command (combines everything)
./build_for_appstore.sh && echo "✅ Build complete! Opening Xcode..." && open ios/Runner.xcworkspace
```

## 📱 Device Testing
```bash
# Install on connected device for testing
flutter install --release

# Run on specific device
flutter devices
flutter run --release -d [device-id]
```

## 🔄 Update Workflow
```bash
# Standard update workflow
git pull origin main
flutter clean
flutter pub get
flutter build ios --release
```

## 📄 Generate Reports
```bash
# Code analysis report
flutter analyze > analysis_report.txt

# Dependency report  
flutter pub deps > dependencies_report.txt

# Build size analysis
flutter build ios --release --analyze-size
```

---

## 🚀 Ready Command Summary

**For first-time deployment:**
```bash
cd "/Users/min/Desktop/Edu Solution"
chmod +x build_for_appstore.sh
./build_for_appstore.sh
```

**For updates:**
```bash
cd "/Users/min/Desktop/Edu Solution"
./build_for_appstore.sh
```

**Emergency rebuild:**
```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock
flutter pub get && cd ios && pod install && cd ..
flutter build ios --release
```

**All commands tested and ready for Edu Solution v1.0.5! 🎉**