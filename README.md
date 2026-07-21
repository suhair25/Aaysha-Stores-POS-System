# Aaysha Stores

Aaysha Stores is an ERP/POS Flutter application with offline-first local storage, Firebase sync, export, barcode, and notification support.

## Firebase Setup

This project uses Firebase for authentication, Firestore, and storage. The generated Firebase configuration file is `lib/firebase_options.dart`.

### 1. Install FlutterFire CLI

```powershell
dart pub global activate flutterfire_cli
```

Make sure the Dart tools global bin folder is on your PATH, for example:

```powershell
$env:Path += ";$HOME\AppData\Local\Pub\Cache\bin"
```

### 2. Create or use an existing Firebase project

1. Go to https://console.firebase.google.com
2. Create a new Firebase project or open an existing one
3. Add Android, iOS, and Web apps if needed

### 3. Configure your Flutter app

From the project root:

```powershell
flutterfire configure --project "YOUR_FIREBASE_PROJECT_ID" --out=lib/firebase_options.dart
```

This will generate `lib/firebase_options.dart` and wire your Firebase apps.

### 4. Android setup

- Ensure `android/app/google-services.json` exists
- In `android/build.gradle`, confirm `classpath 'com.google.gms:google-services:4.3.15'` is present
- In `android/app/build.gradle`, apply `com.google.gms.google-services`

### 5. iOS setup

- Ensure `ios/Runner/GoogleService-Info.plist` exists
- In Xcode, add the plist to the Runner target

### 6. Web setup

- Ensure `web/firebase-messaging-sw.js` is configured if using push notifications
- Add Firebase config to your web app registration if needed

## Run the app

```powershell
flutter pub get
flutter run
```

## Notes

- Firebase initialization happens in `lib/main.dart` using `Firebase.initializeApp(...)`
- The app also supports desktop via SQLite FFI when running on Windows, macOS, or Linux
- If Firebase initialization fails, the app continues with local storage only
