# Personal Life OS — Remaining work

**Current:** Flutter offline client `0.19.0` · schema v19  
**Last updated:** Phase 2 Planning Engine

Keep this list ordered by **impact**. Check items off when merged to `main`.

---

## Highest impact (active)

- [x] Reminder lifecycle UI (create → notify → snooze → complete) — **More → Reminders**
- [x] Hide balances applied on Finance amounts
- [x] **User currency** — Settings currency drives all new amounts / UI (not hardcoded KES)
- [x] Phase 2 planning engine (busy merge, deps, duration, Build My Day apply)
- [ ] Green APK every time (`flutter analyze` clean + release build)
- [ ] Milestone + task dependency UX polish (create/complete already partial)
- [ ] Real branded app icon (replace system drawable)
- [ ] Short first-run onboarding tip
- [ ] Smoke tests: import/export, pay bill, complete habit

## Product depth (DOCX gaps)

- [ ] Recurring **tasks** (not only habits) end-to-end UI
- [ ] Calendar ↔ tasks bidirectional polish
- [ ] Cash-flow period reconciliation UI
- [ ] Subscriptions full lifecycle (pause / cancel / renew)
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
