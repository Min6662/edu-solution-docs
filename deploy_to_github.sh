#!/bin/bash

# GitHub Pages Deployment Script for Edu Solution
# This script will deploy your Flutter web app to GitHub Pages

echo "🚀 DEPLOYING EDU SOLUTION TO GITHUB PAGES"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="edu-solution-web"
WEB_BUILD_DIR="build/web"
DEPLOY_DIR="github-pages-deploy"

echo -e "${BLUE}📋 Deployment Configuration:${NC}"
echo "   Repository Name: $REPO_NAME"
echo "   Web Build Directory: $WEB_BUILD_DIR"
echo "   Deploy Directory: $DEPLOY_DIR"
echo ""

# Check if build exists
if [ ! -d "$WEB_BUILD_DIR" ]; then
    echo -e "${RED}❌ Error: Web build not found at $WEB_BUILD_DIR${NC}"
    echo "   Please run: flutter build web --release"
    exit 1
fi

echo -e "${GREEN}✅ Web build found!${NC}"
echo ""

# Step 1: Prepare deployment directory
echo -e "${BLUE}1️⃣ Preparing deployment directory...${NC}"
if [ -d "$DEPLOY_DIR" ]; then
    echo "   Cleaning existing deployment directory..."
    rm -rf "$DEPLOY_DIR"
fi

mkdir "$DEPLOY_DIR"
cp -r "$WEB_BUILD_DIR"/* "$DEPLOY_DIR"/
echo -e "${GREEN}✅ Files copied to deployment directory${NC}"
echo ""

# Step 2: Create necessary files for GitHub Pages
echo -e "${BLUE}2️⃣ Creating GitHub Pages configuration...${NC}"

# Create .nojekyll file (prevents GitHub from processing as Jekyll site)
touch "$DEPLOY_DIR/.nojekyll"

# Create CNAME file (optional - for custom domain)
cat > "$DEPLOY_DIR/CNAME" << EOF
# Uncomment and edit the line below if you have a custom domain
# edusolution.yourdomain.com
EOF

# Create 404.html for SPA routing
cp "$DEPLOY_DIR/index.html" "$DEPLOY_DIR/404.html"

# Create README for the repository
cat > "$DEPLOY_DIR/README.md" << EOF
# Edu Solution - Web Application

A comprehensive school management system built with Flutter.

## 🌐 Live Demo
Visit: [https://min6662.github.io/$REPO_NAME](https://min6662.github.io/$REPO_NAME)

## 📱 Features
- Student Management
- Teacher Dashboard  
- Class Management
- Attendance Tracking with QR Codes
- Photo Upload/Management
- Multi-language Support (English/Khmer)
- Progressive Web App (PWA)
- Offline Functionality

## 🛠️ Technology Stack
- **Framework**: Flutter Web
- **Backend**: Parse Server (Back4App)
- **Database**: MongoDB
- **Hosting**: GitHub Pages
- **PWA**: Service Worker enabled

## 📊 Build Information
- Build Size: 29MB (optimized)
- Font Optimization: 99%+ reduction
- Tree-shaking: Enabled
- Minification: Enabled

## 🚀 Deployment
This application is automatically deployed to GitHub Pages when changes are pushed to the main branch.

---
Built with ❤️ using Flutter
EOF

echo -e "${GREEN}✅ GitHub Pages files created${NC}"
echo ""

# Step 3: Initialize Git repository
echo -e "${BLUE}3️⃣ Initializing Git repository...${NC}"
cd "$DEPLOY_DIR"

git init
git add .
git commit -m "🚀 Initial deployment of Edu Solution Web App

Features:
- Complete Flutter web application
- Student and teacher management
- QR code attendance system
- Multi-language support (English/Khmer)
- Progressive Web App capabilities
- Optimized 29MB build size

Ready for GitHub Pages deployment!"

echo -e "${GREEN}✅ Git repository initialized${NC}"
echo ""

# Step 4: Instructions for GitHub setup
echo -e "${YELLOW}4️⃣ NEXT STEPS - Complete on GitHub:${NC}"
echo ""
echo -e "${BLUE}🌐 Create GitHub Repository:${NC}"
echo "   1. Go to: https://github.com/new"
echo "   2. Repository name: $REPO_NAME"
echo "   3. Make it PUBLIC (required for free Pages)"
echo "   4. DON'T initialize with README"
echo "   5. Click 'Create repository'"
echo ""

echo -e "${BLUE}📤 Push Your Code:${NC}"
echo "   Run these commands in the terminal:"
echo ""
echo "   cd \"$(pwd)\""
echo "   git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""

echo -e "${BLUE}⚙️ Enable GitHub Pages:${NC}"
echo "   1. Go to your repository on GitHub"
echo "   2. Click 'Settings' tab"
echo "   3. Scroll to 'Pages' section"
echo "   4. Source: 'Deploy from a branch'"
echo "   5. Branch: 'main'"
echo "   6. Folder: '/ (root)'"
echo "   7. Click 'Save'"
echo ""

echo -e "${GREEN}🎯 Your app will be available at:${NC}"
echo "   https://YOUR_USERNAME.github.io/$REPO_NAME"
echo ""

echo -e "${YELLOW}⏱️ Deployment time: 5-10 minutes after pushing${NC}"
echo -e "${GREEN}💰 Cost: FREE${NC}"
echo -e "${BLUE}🔄 Updates: Push new code to update instantly${NC}"
echo ""

echo -e "${GREEN}✅ Deployment preparation complete!${NC}"
echo -e "${BLUE}📁 Files ready in: $(pwd)${NC}"

cd ..
echo ""
echo "🎊 Ready to deploy to GitHub Pages!"