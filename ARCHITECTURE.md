# Architecture

## Phone client = Flutter only

```
contract/           shared rules (CONTRACT.md, enums.json)
src/                TypeScript: schema, domain, events, CLI
apps/flutter/       Flutter offline UI + SQLite (implements contract)
mobile/             legacy Expo prototype — not the shipping client
```

**Integrate by contract:** TypeScript defines the model; Flutter implements the same SQL + status strings locally. No TypeScript runtime in the APK. No Expo for production builds.

## Offline path

1. `apps/flutter` opens on-device SQLite  
2. Schema from `src/db/schema.sql`  
3. APK via **Flutter APK Build** (same pattern as Resonate)

## TypeScript path

Domain services, repositories, event bus under `src/` — CLI, tests, future optional sync API using the same shapes.
