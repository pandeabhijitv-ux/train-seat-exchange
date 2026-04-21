# Train Seat Exchange - Deployment Guide

## Option 1: Deploy as PWA (Progressive Web App)

### 1. Deploy Backend to Cloud

#### Using Render.com (Free):
1. Push code to GitHub
2. Go to https://render.com
3. Click "New Web Service"
4. Connect your GitHub repo
5. Configure:
   - Build Command: `pip install -r backend/requirements.txt`
   - Start Command: `cd backend && python main.py`
   - Add environment variables (MSG91_AUTH_KEY, RAZORPAY keys, etc.)

#### Using Railway.app (Free):
1. Go to https://railway.app
2. Click "Deploy from GitHub"
3. Select your repo
4. Railway auto-detects Python and deploys

#### Using Azure App Service:
```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Login and deploy
az login
az webapp up --name train-seat-exchange --runtime "PYTHON:3.11" --location "centralindia"
```

### 2. Update API URL
After deploying, update the API URL in `mobile-test.html`:
```javascript
const API_BASE = 'https://your-app-name.onrender.com/api/v1';
```

### 3. Install PWA on Phone
1. Open the deployed URL in Chrome on mobile
2. Click menu → "Add to Home Screen"
3. App icon appears on home screen like a native app!

---

## Option 2: Build Flutter App (Native Android/iOS)

### Requirements:
- Flutter SDK installed
- Android Studio (for Android) or Xcode (for iOS)

### Steps:

1. **Update API Config:**
```dart
// mobile-app/lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://your-backend-url.com';
}
```

2. **Build Android APK:**
```powershell
cd mobile-app
flutter build apk --release
```
APK will be in: `mobile-app\build\app\outputs\flutter-apk\app-release.apk`

3. **Build iOS (requires Mac):**
```bash
flutter build ios --release
```

4. **Test on Phone:**
```powershell
# Connect phone via USB
flutter run --release
```

---

## Option 3: Upload to App Stores

### Google Play Store:
1. Create Google Play Developer account ($25 one-time)
2. Build signed APK:
```powershell
cd mobile-app
flutter build appbundle --release
```
3. Upload to Google Play Console
4. Fill in app details, screenshots
5. Submit for review

### Apple App Store:
1. Create Apple Developer account ($99/year)
2. Build iOS app in Xcode
3. Upload via App Store Connect
4. Submit for review

---

## Quick Start: Deploy Backend Now

### Using Render.com (Recommended - Free):

1. **Create GitHub Repo:**
```powershell
cd C:\train-seat-exchange
git init
git add .
git commit -m "Initial commit"
# Create repo on github.com, then:
git remote add origin https://github.com/yourusername/train-seat-exchange.git
git push -u origin main
```

2. **Deploy to Render:**
- Go to https://render.com
- Sign up (free)
- New → Web Service
- Connect GitHub repo
- Settings:
  - Root Directory: `backend`
  - Build: `pip install -r requirements.txt`
  - Start: `python main.py`
- Add environment variables from `.env`
- Deploy!

3. **Access Your App:**
Your app will be live at: `https://train-seat-exchange.onrender.com`

---

## Estimated Costs

| Option | Cost | Time |
|--------|------|------|
| PWA (Render.com) | FREE | 15 min |
| PWA (Railway.app) | FREE | 15 min |
| PWA (Azure) | ~₹500/month | 20 min |
| Google Play | $25 one-time | 2-3 days review |
| Apple App Store | $99/year | 3-7 days review |

**Recommendation:** Start with PWA on Render.com (free, fast, works like native app)
