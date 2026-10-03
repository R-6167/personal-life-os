# Ordin — Flutter (phone app)

**Offline-first personal life OS.** No Expo. Local SQLite + Material 3 glass UI.

## Identity

| | |
|--|--|
| **Name** | Ordin |
| **Application ID** | `com.aetherion.ordin` |
| **Version** | see `pubspec.yaml` |

## Build APK on GitHub

1. **Actions → Flutter APK Build → Run workflow**
2. Download artifact **ordin-flutter-apk**
3. Uninstall any older package ID build if needed, then install the APK

Package ID changed from `com.personallifeos.personal_life_os` — Android treats Ordin as a **new app**.

## Local (optional)

```bash
cd apps/flutter
flutter pub get
flutter run
# or
flutter build apk --release --no-shrink
```
