# Personal Life OS — Integration Contract

**Integrate by contract, not by running TypeScript inside Flutter.**

| Layer | Language | Role |
|-------|----------|------|
| Canonical schema + domain + events | **TypeScript** (`src/`) | Source of truth |
| Phone UI + local SQLite | **Flutter** (`apps/flutter/`) | Offline client that **implements this contract** |
| Optional CLI / future API | **TypeScript** | Same rules, other surfaces |

Flutter does **not** embed Node or call a remote server for core features.
It opens a local SQLite database whose tables, columns, statuses, and event names match this contract.

---

## Canonical sources (do not fork blindly)

| Artifact | Path |
|----------|------|
| SQL schema | [`src/db/schema.sql`](../src/db/schema.sql) |
| Record types | [`src/services/repositories/repository-types.ts`](../src/services/repositories/repository-types.ts) |
| Activity events | [`src/types/events.ts`](../src/types/events.ts) |
| Machine-readable enums | [`contract/enums.json`](./enums.json) |

When you change schema or enums in TypeScript, update `contract/enums.json` and the Flutter models in the same PR.

---

## Global rules

1. **IDs** — `TEXT` primary keys (UUID strings).
2. **Timestamps** — Unix **milliseconds** (`INTEGER`), never seconds.
3. **Money** — integer **minor units** (`amount_minor`, `current_balance_minor`, …). Currency is ISO 4217 (`KES`, `USD`, …).
4. **Statuses** — uppercase string enums as in `enums.json` (e.g. `ACTIVE`, `COMPLETED`).
5. **Ownership** — almost every row has `owner_id` → `users.id`.
6. **Offline-first** — the phone app must work with zero network after install.
7. **Events** — meaningful state changes should append to `activity_events` with the same `event_type` / `entity_type` strings as TypeScript.

---

## Core entities (Flutter MVP)

Implement these first on mobile; the rest of `schema.sql` can follow.

### users
`id`, `name`, `display_name`, `timezone`, `locale`, `currency`, `week_start_day`, `created_at`, `updated_at`

### goals
`id`, `owner_id`, `title`, `description`, `status`, `priority`, `start_date`, `target_date`, `completed_at`, `progress_mode`, `manual_progress`, `created_at`, `updated_at`, `archived_at`

### projects
`id`, `owner_id`, `goal_id`, `title`, `description`, `status`, `priority`, dates, progress fields, timestamps

### tasks
`id`, `owner_id`, `project_id`, `milestone_id`, `goal_id`, `parent_task_id`, `title`, `description`, `status`, `priority`, `scheduled_start`, `scheduled_end`, `due_at`, `estimated_minutes`, `actual_minutes`, `completed_at`, `category_id`, timestamps

### habits
`id`, `owner_id`, `goal_id`, `title`, `description`, `status`, `target_count`, `preferred_time`, `duration_minutes`, `start_date`, `end_date`, `category_id`, timestamps

### habit_occurrences
`id`, `habit_id`, `scheduled_date`, `scheduled_time`, `status`, `completed_at`, `skipped_at`, `actual_duration_minutes`, `reason`, `notes`, timestamps

### routines / routine_steps / routine_occurrences
Same shapes as schema.

### notes
`id`, `owner_id`, `title`, `content`, timestamps, `archived_at`

### financial_accounts, expenses, income, bills, bill_occurrences
Minor units + ISO currency; see schema.

### activity_events
`id`, `owner_id`, `event_type`, `entity_type`, `entity_id`, `occurred_at`, `recorded_at`, `source`, `external_id`, `metadata` (JSON text)

---

## Status enums (subset)

See [`enums.json`](./enums.json) for the full list.

| Domain | Values |
|--------|--------|
| Goal / Project | `ACTIVE`, `PAUSED`, `COMPLETED`, `CANCELLED`, `ARCHIVED` |
| Task | `INBOX`, `PLANNED`, `IN_PROGRESS`, `WAITING`, `COMPLETED`, `CANCELLED` |
| Habit | `ACTIVE`, `PAUSED`, `ARCHIVED` |
| Habit occurrence | `EXPECTED`, `COMPLETED`, `MISSED`, `SKIPPED`, `PARTIAL` |
| Progress mode | `CALCULATED`, `MANUAL` |

---

## JSON field naming

- **SQL columns**: `snake_case` (`owner_id`, `due_at`).
- **TypeScript records**: `camelCase` (`ownerId`, `dueAt`).
- **Dart models**: `camelCase` fields; map to/from `snake_case` in SQL.

---

## Backup / export shape (future sync)

When exporting or syncing, prefer a single JSON document:

```json
{
  "contractVersion": 1,
  "exportedAt": 1730000000000,
  "user": { },
  "goals": [ ],
  "projects": [ ],
  "tasks": [ ],
  "habits": [ ],
  "notes": [ ],
  "activityEvents": [ ]
}
```

Field names in export: **camelCase**, matching TypeScript record types.

---

## Flutter obligations

1. Ship schema from `src/db/schema.sql` (copy into `apps/flutter/assets/schema.sql` when schema changes).
2. Open DB on first launch; run the SQL file if tables are missing.
3. Default currency `KES`, locale `en`, week start Monday (`1`) unless user changes it.
4. Never require network for Today / Tasks / Habits / Notes / local finance entry.

---

## TypeScript obligations

1. Schema and enums remain authoritative.
2. Domain services and event names stay stable or versioned.
3. Do not rename SQL columns without a migration note in this contract.
