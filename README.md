# Personal Life OS

A local-first personal life management system designed around a SQLite memory layer, structured goals, tasks, habits, routines, finances, and historical activity tracking.

## Vision

Personal Life OS is a calm, deterministic productivity and life-management app that keeps a complete record of your responsibilities, plans, habits, and money. It is intentionally local-first, with a single source of truth in SQLite and an event-driven history model.

## Product goals

- Keep personal plans and responsibilities in one place
- Local-first and privacy-conscious data storage
- Clear separation between data layer, domain services, and intelligence layer
- A complete activity history for planning and review
- Simple recurring patterns for tasks, habits, routines, and bills
- Financial tracking without requiring external bank integrations

## Architecture overview

- SQLite database as the memory/state layer
- Repositories for persistence
- Domain services for business rules
- Event recorder for historical activity
- Context builder for planning / local intelligence
- Optional Momentum integration at the top of the stack

## Getting started

```bash
npm install
npm run dev
```

## Database

The project starts with a foundational SQLite schema for:

- users
- categories
- goals
- projects
- milestones
- tasks
- habit and routine records
- financial accounts and transactions
- people, notes, reminders, and activity events

See `src/db/schema.sql` for the initial schema starting point.

## Recommended next steps

1. Add repository/service layer for tasks, goals, finance, routines
2. Build a UI for dashboard / today / backlog / calendar
3. Add recurring occurrence generation
4. Add event-driven activity streams and insights
5. Connect optional external intelligence layer via a context contract
