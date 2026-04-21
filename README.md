# Train Seat Exchange 🚂

A platform for exchanging train seat bookings between passengers.

## 💰 Business Model
- **₹500 Paid App** on Google Play Store
- **10 Entries Limit** per app installation
- Can reinstall for ₹500 to get 10 more entries
- No payment gateway integration needed

## Features
- 📱 Phone OTP verification
- 🔍 PNR auto-fill (optional)
- 🔎 Search for seat exchanges by train/date/coach/berth
- 🎯 **Smart proximity-based search** - Best matches shown first
- 📞 Direct phone call to arrange exchange
- 🛡️ Device-side entry limit (10 per installation)
- 📊 Server analytics tracking
- 🗑️ Automated cleanup scheduler

## Tech Stack
- **Backend:** FastAPI (Python)
- **Database:** SQLite (train-specific + user limits)
- **Mobile:** Flutter (Android)
- **SMS:** MSG91
- **PNR:** RapidAPI (optional, can use mock)

## Quick Start

### 1. Backend Setup
```powershell
cd backend
pip install -r requirements.txt
copy .env.example .env
# Edit .env with your API keys
python main.py
```

### 2. Access Application
- API Docs: http://localhost:8000/docs
- Mobile Web: http://localhost:8000/static/mobile-test.html

### 3. Deploy (See DEPLOYMENT.md)
- Backend to Render.com (free tier)
- Build Flutter AAB: `flutter build appbundle --release`
- Upload to Google Play Store at ₹500 price

## Project Structure
```
train-seat-exchange/
├── backend/
│   ├── main.py           # FastAPI app
│   ├── routes.py         # API endpoints
│   ├── models.py         # Pydantic models
│   ├── database.py       # SQLite operations
│   ├── user_limits.py    # Analytics tracking
│   ├── otp_service.py    # OTP handling
│   ├── pnr_service.py    # PNR verification
│   ├── scheduler.py      # Background tasks
│   └── static/
│       └── mobile-test.html  # PWA interface (testing only)
└── mobile-app/          # Flutter app
    └── lib/
        ├── main.dart
        ├── screens/
        │   ├── home_screen.dart
        │   ├── otp_screen.dart
        │   ├── search_screen.dart
        │   └── create_entry_screen.dart
        └── services/
            ├── api_service.dart
            └── entry_limit_service.dart
```

## Testing
```powershell
# Test script
.\test_manual.ps1

# Or use Swagger UI
# http://localhost:8000/docs
```

## License
MIT
