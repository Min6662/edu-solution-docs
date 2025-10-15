#!/bin/bash

# Quick GitHub Pages Setup
# Run this after creating your GitHub repository

echo "🔧 QUICK GITHUB PAGES SETUP"
echo "============================"
echo ""

# Get user input
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter your repository name (default: edu-solution-web): " REPO_NAME
REPO_NAME=${REPO_NAME:-edu-solution-web}

echo ""
echo "📤 Setting up repository: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo ""

# Navigate to deployment directory
if [ ! -d "github-pages-deploy" ]; then
    echo "❌ Error: Please run ./deploy_to_github.sh first"
    exit 1
fi

cd github-pages-deploy

# Add remote and push
echo "🔗 Adding GitHub remote..."
git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

echo "📤 Pushing to GitHub..."
git branch -M main
git push -u origin main

echo ""
echo "✅ CODE PUSHED TO GITHUB!"
echo ""
echo "🌐 ENABLE GITHUB PAGES:"
echo "   1. Go to: https://github.com/$GITHUB_USERNAME/$REPO_NAME/settings/pages"
echo "   2. Source: 'Deploy from a branch'"
echo "   3. Branch: 'main'"
echo "   4. Folder: '/ (root)'"
echo "   5. Click 'Save'"
echo ""
echo "🎯 Your app will be live at:"
echo "   https://$GITHUB_USERNAME.github.io/$REPO_NAME"
echo ""
echo "⏱️ Wait 5-10 minutes for deployment to complete"

cd ..