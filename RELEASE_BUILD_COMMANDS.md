# Release Build Commands

## 1. Prepare Android Signing

Copy [mobile-app/android/key.properties.example](mobile-app/android/key.properties.example) to `mobile-app/android/key.properties` and fill in real values.

Example:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

## 2. Final Android Release Build

Run this from Windows PowerShell:

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

Output bundle:

1. `mobile-app/build/app/outputs/bundle/release/app-release.aab`

## 3. If You Want A Quick Local Debug Build

```powershell
cd c:\train-seat-exchange\mobile-app
flutter build apk --debug `
  --dart-define=FIREBASE_API_KEY=your_firebase_api_key `
  --dart-define=FIREBASE_APP_ID=your_android_app_id `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id `
  --dart-define=FIREBASE_PROJECT_ID=your_project_id
```

## 4. Before Uploading To Play Console

1. Ensure backend is already deployed on Render.
2. Ensure Firebase phone auth works on a real Android device.
3. Ensure release SHA-1 and SHA-256 are added in Firebase.
4. Ensure `RailSeatExchange` is visible as the Android app label.
5. Ensure the release keystore is the one whose SHA fingerprints were added to Firebase.