# Quick Start Guide - Test the Updated App (₹500 Model)

## 🎯 Business Model

**Price:** ₹500 paid app on Google Play  
**Limit:** 10 entries per app installation (device-based)  
**Reinstall:** Can uninstall and reinstall for ₹500 to get 10 more entries  

---

## 🚀 Start Backend

```powershell
# Navigate to backend
cd backend

# Create .env file (if not exists)
@"
MSG91_AUTH_KEY=your_key_here
MSG91_SENDER_ID=TRAINSEAT
MSG91_ROUTE=4
DEBUG=True
HOST=0.0.0.0
PORT=8000
PNR_API_PROVIDER=mock
"@ | Out-File -FilePath .env -Encoding UTF8

# Install dependencies
pip install -r requirements.txt

# Run server
python main.py
```

Server will start at: **http://localhost:8000**  
API Docs: **http://localhost:8000/docs**

---

## 📱 Test Flutter App

```powershell
# Navigate to mobile app
cd mobile-app

# Install dependencies
flutter pub get

# Run on emulator/device
flutter run
```

---

## 🧪 Test Flow

### Test 1: Create Entry
1. Click "Create Exchange Request"
2. Enter phone: `9876543210`
3. Click "Send OTP"
4. **Check backend console** for debug OTP (e.g., `123456`)
5. Enter OTP, click "Verify"
6. **Should show Create Entry screen with "10 of 10 entries remaining"**
7. Fill form:
   - Train Number: `12345`
   - Date: Select tomorrow
   - Time: Select any time
   - Current Bogie: `B3`, Seat: `45`
   - Desired Bogie: `A2`, Seat: `12`
8. Click "Create Entry"
9. **Should show success with "9 entries remaining"**

### Test 2: Entry Limit (Device-Based)
1. Create entries until you reach 10
2. Try to create 11th entry
3. **Should show "Limit Reached" dialog**
4. Dialog should mention:
   - "All 10 entries used"
   - "Uninstall and reinstall to get 10 more for ₹500"
5. **Cannot create more until app is cleared**

### Test 2b: Reset Limit (Simulate Reinstall)
1. In create entry screen (after limit reached)
2. Clear app data: Settings → Apps → Train Seat Exchange → Clear Data
3. **Or:** Uninstall and reinstall the app
4. Open app again
5. Verify OTP again (fresh start)
6. **Should show "10 of 10 entries remaining" again**
7. Can create 10 more entries

### Test 3: Search
1. Click "Search Available Exchanges"
2. Enter:
   - Train Number: `12345`
   - Date: Same as entry created
3. Click "Search"
4. **Should show the entry you created**
5. Click "Call" button
6. **Should open phone dialer with the number**

### Test 4: PNR Auto-Fill (Mock Mode)
1. Create Entry screen
2. Enter PNR: `1234567890`
3. Click "Verify"
4. **Mock data should auto-fill train details**

---

## 🐛 Troubleshooting

### Backend not starting?
```powershell
# Check Python version
python --version  # Should be 3.8+

# Reinstall dependencies
pip install --upgrade -r requirements.txt
```

### Flutter app not running?
```powershell
# Check Flutter installation
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### API connection errors?
```dart
// Check mobile-app/lib/config/api_config.dart
// For Android emulator, use:
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

// For iOS simulator, use:
static const String baseUrl = 'http://localhost:8000/api/v1';

// For real device on same network:
static const String baseUrl = 'http://192.168.x.x:8000/api/v1';
```

---

## 📊 Test API Endpoints Manually

### 1. Send OTP
```powershell
curl -X POST http://localhost:8000/api/v1/otp/send `
  -H "Content-Type: application/json" `
  -d '{"phone": "9876543210"}'
```

### 2. Verify OTP
```powershell
curl -X POST http://localhost:8000/api/v1/otp/verify `
  -H "Content-Type: application/json" `
  -d '{"phone": "9876543210", "otp": "123456"}'
```

### 3. Check User Limits (Analytics Only)
```powershell
# Server still tracks but doesn't enforce
curl http://localhost:8000/api/v1/user/limits/9876543210

# Response shows total entries ever created by this phone
# But doesn't prevent new entries
```

### 4. Create Entry
```powershell
curl -X POST http://localhost:8000/api/v1/entry/create `
  -H "Content-Type: application/json" `
  -d '{
    "phone": "9876543210",
    "train_number": "12345",
    "train_date": "2026-04-25",
    "departure_time": "10:30",
    "current_bogie": "B3",
    "current_seat": "45",
    "desired_bogie": "A2",
    "desired_seat": "12"
  }'
```

### 5. Search Entries
```powershell
curl -X POST http://localhost:8000/api/v1/entry/search `
  -H "Content-Type: application/json" `
  -d '{
    "train_number": "12345",
    "train_date": "2026-04-25"
  }'
```

---

## ✅ Expected Results

After full testing, you should have:
- ✅ OTP send/verify working
- ✅ Entry creation showing remaining count (device-based)
- ✅ Entry limit enforcement (stops at 10 per installation)
- ✅ Limit reset after clearing app data/reinstalling
- ✅ Search returning created entries
- ✅ Phone call button working
- ✅ Clear messaging about reinstalling for more entries
- ✅ Database files created in `backend/data/`:
  - `user_limits.db` (analytics only)
  - `train_12345_20260425.db` (or similar)

---

## 🎯 Next: Build Release APK

Once testing is complete:

```powershell
cd mobile-app

# Build release APK
flutter build apk --release

# APK location:
# build\app\outputs\flutter-apk\app-release.apk
```

Install on real device and test!

---

Jai Shriram! Happy Testing! 🚀
