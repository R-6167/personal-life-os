# Ordin

Offline personal life OS (`com.aetherion.ordin`).

Everything runs on-device in Flutter + SQLite. No account. No TypeScript runtime. No Expo.

## Life thread (how the product is meant to feel)

One system understanding the person's life — not a pile of separate screens:

```
Goal
  → Project
    → Milestone
      → Tasks
        → Scheduled work
          → Calendar
            → Completion
              → Activity history
                → Progress toward goal
```

Open a **Goal** or **Project** to see that chain: linked work, next 14 days of scheduled tasks, progress, and activity history.

## App

| Path | Purpose |
|------|---------|
| `apps/flutter/` | The only app |
| `apps/flutter/assets/schema.sql` | Canonical SQLite schema |
| `.github/workflows/flutter-apk.yml` | Sideloadable APK builds |

## Build APK

GitHub Actions → **Flutter APK** workflow → download the artifact → install on your phone.

## Privacy

All data stays in local SQLite on the device. Backups are optional export from **More**.
