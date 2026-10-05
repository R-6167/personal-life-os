# Personal Life OS — Remaining work

**Current:** Flutter offline client `0.19.0` · schema v20  
**Last updated:** Phase 3 Universal Recurrence

Keep this list ordered by **impact**. Check items off when merged to `main`.

---

## Highest impact (active)

- [x] Reminder lifecycle UI (create → notify → snooze → complete) — **More → Reminders**
- [x] Hide balances applied on Finance amounts
- [x] **User currency** — Settings currency drives all new amounts / UI (not hardcoded KES)
- [x] Phase 2 planning engine (busy merge, deps, duration, Build My Day apply)
- [x] Phase 3 universal recurrence (tasks + subscriptions + schedule columns)
- [ ] Green APK every time (`flutter analyze` clean + release build)
- [ ] Milestone + task dependency UX polish (create/complete already partial)
- [ ] Real branded app icon (replace system drawable)
- [ ] Short first-run onboarding tip
- [ ] Smoke tests: import/export, pay bill, complete habit

## Product depth (DOCX gaps)

- [x] Recurring **tasks** via task_recurrences + DomainRecurrence (complete → spawn next)
- [ ] Recurring tasks **UI** (picker on task detail)
- [ ] Calendar ↔ tasks bidirectional polish
- [ ] Cash-flow period reconciliation UI
- [x] Subscriptions recurrence (frequency / next_renewal via DomainRecurrence; pause/cancel/renew)
- [ ] Subscriptions full **UI** lifecycle polish
- [ ] People ↔ notes ↔ projects linking UX
- [ ] Flexible / adaptive routines
- [ ] Vehicle / service records specialization
- [ ] Reminder deep-link from notification tap → entity screen

## Ship readiness

- [ ] CI pipeline (analyze + test + APK artifact)
- [ ] Release signing / Play-ready keystore docs
- [ ] Accessibility pass (semantics, large text)
- [ ] Empty states on every hub screen

## Explicitly out of scope (for now)

- Cloud sync / accounts
- Multi-device live merge (beyond backup file)
- Biometrics (PIN is enough for v1)

---

## Phase 2 — Planning Engine (2026-10-03)

- [x] Busy intervals merged (blocks + calendar + scheduled tasks)
- [x] `collectDayBusy` shared by availableMinutes + suggestSlots
- [x] Slot suggestions respect duration against free gaps
- [x] Dependencies block scheduling (`listBlockedTaskIds`)
- [x] Task duration (estimate) drives fit (15–180 min)
- [x] Atomic schedule/reschedule (task + block + history)
- [x] Build My Day apply skips blocked tasks; sorts by score
- [x] `listDueToday` / `listScheduledOnDay` restored on TaskRepository

Still open: notification deep-link, adaptive routines, cash-flow UI.

---

## Phase 3 — Universal Recurrence (2026-10-05)

- [x] One brain: RecurrenceRule → OccurrenceGenerator → Occurrence
- [x] domain_recurrence.dart shared adapter
- [x] Habits / routines / bills on DomainRecurrence
- [x] Tasks: setRecurrenceRule / getRecurrenceRule / spawn on complete / clearRecurrence
- [x] Subscriptions: frequency, interval, next_renewal_at, renewSubscription
- [x] Schema: task_recurrences full columns; subscription + schedule intervals
- [ ] Recurring reminders series (optional)
- [ ] Recurring practical responsibilities UI
