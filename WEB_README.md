# 🌐 Edu Solution Web App

A comprehensive school management web application built with Flutter Web. Features student enrollment, class management, QR attendance tracking, and multi-language support.

## ✨ Features

### 📚 Core Functionality
- **Student Management**: Add, edit, and manage student information
- **Photo Management**: Upload, view, and delete student photos
- **Class Enrollment**: Dual class system (morning/evening classes)
- **QR Code Attendance**: Scan and track attendance
- **Multi-language**: English and Khmer support
- **Form Caching**: Auto-save form data for better UX

### 🌐 Web-Specific Features
- **Progressive Web App (PWA)**: Install as native app
- **Offline Support**: Works without internet after initial load
- **Responsive Design**: Optimized for desktop, tablet, and mobile
- **Cross-browser Compatibility**: Chrome, Firefox, Safari, Edge

## 🚀 Deployment Options

### 1. Firebase Hosting (Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and initialize
firebase login
firebase init hosting

# Deploy
firebase deploy
```

### 2. Netlify
1. **Drag & Drop**: Upload `build/web` folder to [Netlify](https://netlify.com)
2. **Git Integration**: Connect your repository for automatic deployments

### 3. Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod build/web
```

### 4. Docker Deployment
```bash
# Build Docker image
docker build -t edu-solution-web .

# Run container
docker run -p 80:80 edu-solution-web

# Access at http://localhost
```

### 5. Traditional Web Hosting
Upload the contents of `build/web/` to your web server. Use the provided `.htaccess` (Apache) or `nginx.conf` (Nginx) configurations.

## 📱 PWA Installation

Users can install the web app as a native application:

1. **Chrome/Edge**: Click the install icon in the address bar
2. **Safari**: Add to Home Screen
3. **Firefox**: Add to Home Screen

## 🔧 Development

### Prerequisites
- Flutter SDK 3.22.1+
- Dart 3.4.1+
- Web browser (Chrome recommended for development)

### Setup
```bash
# Clone repository
git clone <repository-url>
cd edu-solution

# Install dependencies
flutter pub get

# Enable web support
flutter config --enable-web

# Run in development mode
flutter run -d chrome
```

### Build for Production
```bash
# Build optimized web version
flutter build web --release

# Or use our deployment script
./deploy_web.sh
```

## 🌍 Browser Compatibility

| Browser | Version | Support |
|---------|---------|---------|
| Chrome  | 88+     | ✅ Full |
| Firefox | 85+     | ✅ Full |
| Safari  | 14+     | ✅ Full |
| Edge    | 88+     | ✅ Full |

## 📊 Performance

- **Build Size**: ~29MB (optimized)
- **First Load**: ~3-5 seconds
- **Subsequent Loads**: <1 second (cached)
- **Offline**: Full functionality after first load

## 🔒 Security Features

- **HTTPS Required**: Secure connections only
- **Content Security Policy**: XSS protection
- **Same-Origin Policy**: Frame protection
- **Secure Headers**: HSTS, X-Content-Type-Options

## 🛠️ Configuration Files

### Apache (.htaccess)
```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

### Nginx (nginx.conf)
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

## 📈 Analytics & Monitoring

The web app supports:
- Google Analytics
- Firebase Analytics
- Custom event tracking
- Performance monitoring

## 🌟 User Experience

### Desktop Features
- **Multi-window Support**: Open multiple tabs
- **Keyboard Navigation**: Full keyboard accessibility
- **Copy/Paste**: Standard browser functionality
- **Print Support**: Student reports and class lists

### Mobile Web Features
- **Touch Gestures**: Native-like interactions
- **Camera Access**: Photo capture and upload
- **Home Screen Install**: PWA installation
- **Offline Mode**: Works without internet

## 🔄 Updates

The web app auto-updates when new versions are deployed:
- **Service Worker**: Automatic background updates
- **Version Detection**: Notify users of new features
- **Cache Management**: Smart cache invalidation

## 📞 Support

For technical support or feature requests:
- Email: support@edusolution.app
- Documentation: [docs.edusolution.app](https://docs.edusolution.app)
- GitHub Issues: [github.com/edusolution/issues](https://github.com/edusolution/issues)

## 📄 License

Copyright © 2025 Edu Solution Team. All rights reserved.

---

**Built with ❤️ using Flutter Web**