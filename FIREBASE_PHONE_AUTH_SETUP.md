# Firebase Phone Auth Setup

This project now uses Firebase Phone Authentication for verified user registration.

## User Flow

1. User enters full name and 10-digit Indian phone number.
2. Firebase sends an OTP SMS to that phone.
3. User enters the OTP, or Android auto-fills it when available.
4. Firebase signs the user into the app.
5. The app sends the Firebase ID token to the backend.
6. The backend verifies that token and registers the verified phone.

The user does not need a separate Firebase account.

## Firebase Console Checklist

### 1. Create Project

1. Open Firebase Console.
2. Click `Create project`.
3. Project name suggestion: `rail-seat-exchange`.
4. Google Analytics is optional for now.

### 2. Add Android App

Use these values:

1. Android package name: `com.trainexchange.train_seat_exchange`
2. Android app nickname: `RailSeatExchange`
3. SHA certificate fingerprints: add both debug and release fingerprints

### 3. Enable Phone Authentication

1. Go to `Authentication`.
2. Open `Sign-in method`.
3. Enable `Phone`.
4. Save.

### 4. Add Test Numbers First

Before real production testing:

1. In Firebase Authentication, open `Settings` or test phone number section.
2. Add your own number as a test number.
3. Set a fixed OTP like `123456`.

This lets you test without consuming real SMS sends.

### 5. Get Android Firebase Values

Copy these values from Firebase project settings for the Android app:

1. `API key`
2. `App ID`
3. `Messaging Sender ID`
4. `Project ID`
5. `Storage bucket` if shown

This repo currently initializes Firebase using `--dart-define`, so you do not need to commit `google-services.json` for this implementation.

## SHA Fingerprint Commands

### Debug Keystore SHA

Run on Windows:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

### Release Keystore SHA

After you create your production keystore:

```powershell
keytool -list -v -alias upload -keystore "c:\path\to\upload-keystore.jks"
```

If your alias is not `upload`, use the alias from [mobile-app/android/key.properties.example](mobile-app/android/key.properties.example).

## Flutter Build-Time Configuration

Use these defines for release builds:

```powershell
cd c:\train-seat-exchange\mobile-app
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://your-backend-domain/api/v1 `
  --dart-define=FIREBASE_API_KEY=your_firebase_api_key `
  --dart-define=FIREBASE_APP_ID=your_android_app_id `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id `
  --dart-define=FIREBASE_PROJECT_ID=your_project_id `
  --dart-define=FIREBASE_STORAGE_BUCKET=your_storage_bucket
```

`FIREBASE_STORAGE_BUCKET` is optional.

## Backend Configuration

The backend verifies Firebase ID tokens using Firebase Admin SDK.

Set one of these on Render:

1. `FIREBASE_CREDENTIALS_PATH` pointing to a mounted service-account JSON file
2. `FIREBASE_SERVICE_ACCOUNT_JSON` containing the service-account JSON as a one-line secret

Also set:

1. `FIREBASE_PROJECT_ID`

### Create Service Account JSON

1. Open Firebase Console.
2. Go to `Project settings`.
3. Open `Service accounts`.
4. Click `Generate new private key`.
5. Download the JSON.
6. Use that file in Render as either a secret file or a secret env value.

## Authentication Logic In This Project

1. Flutter verifies the phone number with Firebase.
2. Firebase signs in the device user.
3. Flutter sends the Firebase ID token automatically in the `Authorization: Bearer <token>` header.
4. FastAPI verifies that token and extracts the verified phone number.
5. Backend allows registration, entry creation, and contact reveal only for the authenticated phone number.

## Notes For You

1. You no longer need MSG91 for the production verification flow.
2. The old backend OTP path remains only as a fallback/debug path.
3. Real production verification should use Firebase Phone Auth.
