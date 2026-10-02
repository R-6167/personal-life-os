# Personal Life OS — Flutter (offline client)

Implements [`contract/CONTRACT.md`](../../contract/CONTRACT.md).

TypeScript owns the schema and domain. This app **mirrors** that contract in Dart + local SQLite.

## Bootstrap (one time)

You need the Flutter SDK on a machine once to generate platform folders (or use CI only after the first push of `android/`).

```bash
cd apps/flutter

# If android/ ios/ are missing:
flutter create . --project-name personal_life_os --org com.personallifeos

# Copy canonical schema into assets (re-run when schema.sql changes)
mkdir -p assets
cp ../../src/db/schema.sql assets/schema.sql

flutter pub get
```

Update `pubspec.yaml` assets if needed (already listed):

```yaml
flutter:
  assets:
    - assets/schema.sql
```

## Run

```bash
flutter run
# or build APK like Resonate:
flutter build apk --release --no-shrink
```

## GitHub APK

Workflow: [`.github/workflows/flutter-apk.yml`](../../.github/workflows/flutter-apk.yml)

**Actions → Flutter APK Build → Run workflow** → download artifact → install on phone.

Requires `apps/flutter/android/` present (from `flutter create`).

## Layout

```
lib/
  main.dart                 # app shell
  domain/                   # models matching contract (camelCase)
  data/
    database.dart           # opens SQLite, applies schema.sql
    task_repository.dart    # example repository
  ui/
    home_shell.dart         # offline shell / tabs
assets/
  schema.sql                # copy of src/db/schema.sql
```

## Rules of engagement

- Do not invent parallel column names; follow `schema.sql`.
- Status strings must match `contract/enums.json`.
- Money = minor units; times = Unix ms.
