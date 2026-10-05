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

## CI gates (must stay green)

1. `flutter analyze --no-fatal-infos --no-fatal-warnings`
2. `flutter test`
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

## Artifacts

- Never commit `*.gguf`, `build/`, `.dart_tool/`, `local.properties`, or APKs.
- Import GGUF into app documents at runtime only.
