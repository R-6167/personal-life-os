# Reliability & integrity

## Atomic mutations

Any change that updates **domain state** and records an **activity event** must use:

```dart
await AtomicWrite.run(
  state: (txn) async { /* all writes via txn */ },
  eventType: '...',
  entityType: '...',
  entityId: '...',
);
```

Or `AtomicWrite.runWithEvents` when multiple events belong to one lifecycle step
(e.g. bill paid → expense → balance).

Do **not** insert into `activity_events` outside the same transaction as the state write.

### Covered write paths

| Path | Pattern |
|------|---------|
| Task create / reopen / delete | `AtomicWrite.run` |
| Task complete (+ optional spawn) | `_db.txn` multi-event |
| Work session start / complete | single SQLite `transaction` |
| Expense / income create | `AtomicWrite.run` |
| Account create / balance adjust | `AtomicWrite.run` |
| Goal / project create & complete | `AtomicWrite.run` |
| Note create / update / delete | `AtomicWrite.run` |
| Milestone complete | `AtomicWrite.run` |
| Bill create / payOccurrence | `_db.txn` (multi-table + multi-event) |
| Note auto-link / task extract audit | `AtomicWrite.run` |
| Smart reminder series | `_db.txn` |

## UI reload (scoped, not global)

`HomeShell._reload` accepts `Set<ReloadDomain>`:

- `tasks` / `life` / `finance` / `today`
- Tab switch changes index only (no fetch)
- `IndexedStack` keeps off-screen tabs alive
- Cache invalidation is prefix-scoped via `QueryCache.invalidate(prefix)`

## Schema repair (v23)

- Hard-ensure `users` table + default row on open
- Soft columns: `notes.archived_at`, goals/projects descriptions, etc.
- If boot still shows `no such table: users`, clear app data once

## CI gates (must stay green)

1. `flutter test` (runs first)
2. `flutter analyze --no-fatal-infos --no-fatal-warnings`
3. (APK workflow) `flutter build apk --release`

## Smoke coverage (pure, no device)

| Area | Test file |
|------|-----------|
| Busy-interval merge | `free_time_merge_test.dart` |
| Recurrence engine | `recurrence_engine_test.dart` |
| Personal situation narrative | `personal_situation_test.dart` |
| AI settings / modes | `ai_settings_test.dart` |
| Prompt grounding | `prompt_builder_test.dart` |
| Atomic contract types | `atomic_write_contract_test.dart` |
| Critical flow smoke | `smoke_critical_flows_test.dart` |

## Integration tests (in-memory SQLite)

Uses `sqflite_common_ffi` + `AppDatabase.attachForTest` via `test/helpers/test_db.dart`:

| File | Flow |
|------|------|
| `integration_task_lifecycle_test.dart` | Task complete + AtomicWrite |
| `integration_work_session_test.dart` | Work session start atomicity |
| `integration_finance_lifecycle_test.dart` | Expense, income+balance, bill pay |

Run: `cd apps/flutter && flutter test`

## Artifacts

- Never commit `*.gguf`, `build/`, `.dart_tool/`, `local.properties`, or APKs.
- Import GGUF into app documents at runtime only.
