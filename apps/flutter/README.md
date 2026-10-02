# Personal Life OS — Flutter (phone app)

**No Expo.** Offline client implementing [`contract/CONTRACT.md`](../../contract/CONTRACT.md).

## Build APK on GitHub

1. Ensure `android/` is present (you already added it; CI uses the updated Gradle/manifest).
2. **Actions → Flutter APK Build → Run workflow**
3. Download artifact **`personal-life-os-flutter-apk`**
4. Uninstall any old Expo build, install this APK

Package ID: `com.personallifeos.personal_life_os`  
Label: **Personal Life OS**

## Local (optional)

```bash
cd apps/flutter
cp ../../src/db/schema.sql assets/schema.sql
flutter pub get
flutter run
# or
flutter build apk --release --no-shrink
```

`android/local.properties` is gitignored — Flutter/CI set `flutter.sdk` automatically on the runner.

## Tabs

Today · Tasks · Habits · Goals · Notes — all on-device SQLite.
