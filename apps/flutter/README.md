# Personal Life OS — Flutter (the phone app)

**No Expo.** Offline client that implements [`contract/CONTRACT.md`](../../contract/CONTRACT.md).

TypeScript (`src/`) owns schema + domain. This app mirrors it in Dart + SQLite.

## One-time setup (required for APK)

Needs the Flutter SDK once (same as Resonate):

```bash
cd apps/flutter

flutter create . --project-name personal_life_os --org com.personallifeos

mkdir -p assets
cp ../../src/db/schema.sql assets/schema.sql

flutter pub get
```

Commit generated `android/` (and `ios/` if you want).

## Run locally

```bash
flutter run
# or
flutter build apk --release --no-shrink
```

## GitHub APK (after android/ is committed)

**Actions → Flutter APK Build → Run workflow**

Artifact: `personal-life-os-flutter-apk` → install on phone.

CI always refreshes `assets/schema.sql` from `src/db/schema.sql`.

## What’s in the app now

| Tab | Contract tables |
|-----|-----------------|
| Today | Counts from local DB |
| Tasks | `tasks` + `TASK_*` events |
| Habits | `habits` / `habit_occurrences` + `HABIT_*` |
| Goals | `goals` + `GOAL_*` |
| Notes | `notes` |

## Not Expo

The old `mobile/` Expo prototype is not the phone target. Ignore **Manual APK Build** (Expo).
