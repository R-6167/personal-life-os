# Architecture

## Contract-first (TypeScript + Flutter)

```
contract/          ← shared rules (human + enums.json)
src/               ← TypeScript: schema, domain, events, CLI
apps/flutter/      ← Flutter: offline UI + SQLite implementing the contract
mobile/            ← legacy Expo prototype (optional; not the target client)
```

**Rule:** TypeScript defines the data model. Flutter implements the same model locally. No TypeScript runtime inside the APK.

See [contract/CONTRACT.md](contract/CONTRACT.md).

## Offline phone path

1. Flutter opens on-device SQLite.
2. Schema = `src/db/schema.sql` (copied to `apps/flutter/assets/schema.sql`).
3. APK via **Flutter APK Build** workflow (same idea as Resonate).

## TypeScript path

- Domain services, repositories, event bus under `src/`.
- Useful for CLI, tests, and a future sync API using the same JSON shapes.
