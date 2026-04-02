# ReadFlow — Smart Document & Ebook Reader

A professional Flutter app for Android (Play Store ready).
Dark theme · TTS · PDF · EPUB · DOCX · TXT

---

## Features

### Free tier
- Read PDF, EPUB, TXT, DOCX files
- Text-to-speech with word highlighting
- Dark / Light / Sepia reading themes
- Bookmarks
- Reading progress tracking
- Library management (grid + list view)
- Reading stats (time, pages, streak)
- Search by title / author / genre
- Continue reading section

### Pro (₹149 one-time)
- Natural AI voices
- Speed reading (RSVP mode)
- Highlights + notes + export
- Cloud import (Google Drive, Dropbox)
- Folder organisation
- No ads

---

## Setup (step by step)

### 1. Install Flutter
```
https://flutter.dev/docs/get-started/install
```
Choose Android setup. Install Android Studio too.

### 2. Clone / copy this project
Put this folder wherever you want on your computer.

### 3. Install dependencies
```bash
cd readflow
flutter pub get
```

### 4. Connect your Android phone
- Enable Developer Mode on phone (Settings → About → tap Build Number 7 times)
- Enable USB Debugging
- Connect via USB

### 5. Run the app
```bash
flutter run
```

### 6. Build release APK for Play Store
```bash
# Generate keystore (do this once, keep the file safe)
keytool -genkey -v -keystore ~/readflow-key.jks -keyAlg RSA -keySize 2048 -validity 10000 -alias readflow

# Build release
flutter build appbundle --release
```

The `.aab` file will be in `build/app/outputs/bundle/release/`
Upload this to Google Play Console.

---

## File structure

```
lib/
  main.dart              ← App entry + splash screen
  theme/
    app_theme.dart       ← All colors, fonts, gradients
  models/
    document.dart        ← Document, Bookmark, Highlight models
  services/
    library_service.dart ← All library logic + storage
    tts_service.dart     ← Text-to-speech engine
  screens/
    home_screen.dart     ← Library + navigation
    reader_screen.dart   ← Reading experience
    search_screen.dart   ← Search
    stats_screen.dart    ← Reading statistics
    settings_screen.dart ← Settings + Pro upgrade
  widgets/
    common_widgets.dart  ← Reusable UI components
```

---

## Monetisation setup

### AdMob (free tier ads)
1. Create account at admob.google.com
2. Add your app
3. Replace App ID in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### In-app purchase (Pro unlock)
1. Upload app to Play Console first
2. Go to Monetise → Products → In-app products
3. Create product with ID: `readflow_pro`
4. Price: ₹149
5. The `in_app_purchase` package is already included

---

## Play Store checklist

- [ ] App icon (512×512 PNG) — use Canva or Figma
- [ ] Feature graphic (1024×500 PNG)
- [ ] 8 screenshots (phone size)
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Privacy policy URL (required — use Google Sites, free)
- [ ] Content rating questionnaire
- [ ] $25 developer account fee (one-time)

---

## Key packages used

| Package | Purpose |
|---------|---------|
| syncfusion_flutter_pdfviewer | PDF rendering |
| flutter_tts | Text-to-speech |
| file_picker | File import |
| shared_preferences | Local storage |
| fl_chart | Reading stats charts |
| flutter_animate | Smooth animations |
| google_fonts | Inter font |
| provider | State management |
| in_app_purchase | Pro unlock |

---

## Customisation tips

- Change app name: edit `name` in `pubspec.yaml` and `android:label` in `AndroidManifest.xml`
- Change primary color: edit `AppTheme.primary` in `lib/theme/app_theme.dart`
- Change Pro price: edit the string in `settings_screen.dart` and Play Console
- Add more languages: edit `availableLanguages` in `tts_service.dart`
"# readflow-App" 
