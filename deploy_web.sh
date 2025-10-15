#!/bin/bash

echo "🌐 Edu Solution Web Deployment Script"
echo "====================================="
echo ""

# Set version
VERSION="1.0.8"
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
WEB_DIR="/Users/min/Desktop/Edu Solution"

echo "📦 Building Web Version v$VERSION"
echo "Build Date: $BUILD_DATE"
echo ""

cd "$WEB_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build for web with optimizations
echo "🔨 Building optimized web version..."
flutter build web --release \
  --web-renderer canvaskit \
  --base-href "/" \
  --source-maps \
  --pwa-strategy offline-first

if [ $? -eq 0 ]; then
    echo "✅ Web build successful!"
    echo ""
    
    # Enhance the built index.html
    echo "🎨 Enhancing web files..."
    cp web/index_enhanced.html build/web/index.html
    
    # Create deployment info
    echo "📋 Creating deployment info..."
    cat > build/web/deployment-info.json << EOF
{
  "app_name": "Edu Solution",
  "version": "$VERSION",
  "build_date": "$BUILD_DATE",
  "platform": "web",
  "features": [
    "Student Management",
    "Class Enrollment", 
    "Photo Management with Delete",
    "QR Attendance Tracking",
    "Dual Class System",
    "Multi-language Support (English/Khmer)",
    "Form Caching",
    "Progressive Web App (PWA)"
  ],
  "compatibility": {
    "browsers": ["Chrome 88+", "Firefox 85+", "Safari 14+", "Edge 88+"],
    "mobile": true,
    "offline": true
  }
}
EOF

    # Create .htaccess for Apache servers
    echo "⚙️ Creating server configuration files..."
    cat > build/web/.htaccess << 'EOF'
# Edu Solution Web App - Apache Configuration
RewriteEngine On

# Handle client-side routing
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
</IfModule>

# Compress files
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>

# Security headers
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
EOF

    # Create nginx configuration
    cat > build/web/nginx.conf << 'EOF'
# Edu Solution Web App - Nginx Configuration
server {
    listen 80;
    server_name your-domain.com;
    
    root /path/to/edu-solution/build/web;
    index index.html;
    
    # Handle client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Compress responses
    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
    gzip_min_length 1024;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
EOF

    # Calculate build size
    BUILD_SIZE=$(du -sh build/web | cut -f1)
    
    echo ""
    echo "🎉 WEB DEPLOYMENT READY!"
    echo "======================="
    echo ""
    echo "📦 Build Information:"
    echo "• Version: $VERSION"
    echo "• Build Size: $BUILD_SIZE"
    echo "• Location: build/web/"
    echo "• PWA Enabled: Yes"
    echo "• Offline Support: Yes"
    echo ""
    echo "🌐 Deployment Options:"
    echo ""
    echo "1. 🚀 Firebase Hosting (Recommended):"
    echo "   firebase init hosting"
    echo "   firebase deploy"
    echo ""
    echo "2. 📡 Netlify:"
    echo "   • Drag and drop build/web folder to Netlify"
    echo "   • Or connect GitHub repository"
    echo ""
    echo "3. ☁️  Vercel:"
    echo "   vercel --prod build/web"
    echo ""
    echo "4. 🐳 Docker:"
    echo "   docker build -t edu-solution-web ."
    echo "   docker run -p 80:80 edu-solution-web"
    echo ""
    echo "5. 🖥️  Local Testing:"
    echo "   cd build/web"
    echo "   python -m http.server 8080"
    echo "   # or"
    echo "   npx serve -s . -p 8080"
    echo ""
    echo "📱 PWA Installation:"
    echo "• Users can install as app from browser"
    echo "• Works offline after first load"
    echo "• Responsive design for all devices"
    echo ""
    echo "🔧 Server Configuration:"
    echo "• Apache: Use .htaccess (already created)"
    echo "• Nginx: Use nginx.conf (already created)"
    echo ""
    echo "✨ Features Available in Web Version:"
    echo "• ✅ All mobile app features"
    echo "• ✅ Responsive design"
    echo "• ✅ Photo upload/delete"
    echo "• ✅ Class management"
    echo "• ✅ Student enrollment"
    echo "• ✅ Form caching"
    echo "• ✅ Multi-language support"
    echo "• ✅ QR code functionality"
    echo "• ✅ PWA capabilities"
    echo ""
    echo "🎯 Ready for production deployment!"
    
else
    echo "❌ Web build failed!"
    exit 1
fi