# Personal Life OS — Remaining work

**Current:** Flutter offline client `0.18.x` · schema v11  
**Last updated:** Reminder lifecycle + hide balances + file picker hardening

Keep this list ordered by **impact**. Check items off when merged to `main`.

---

## Highest impact (active)

- [x] Reminder lifecycle UI (create → notify → snooze → complete) — **More → Reminders**
- [x] Hide balances applied on Finance amounts (Settings toggle → masks via `formatMoneyMinor`)
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

When picking “next,” take the first unchecked item under **Highest impact**.
