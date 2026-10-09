# Ordin — Personal Life OS Improvement Roadmap

**Status:** Proposed implementation plan  
**Repository:** `R-6167/personal-life-os`  
**Principle:** Ordin should help a person manage the connected reality of their life—not just provide a collection of disconnected CRUD screens.

This roadmap is deliberately phased. Each phase should be audited, implemented in small reviewable changes, tested, and merged only after its required checks pass. Do not start the deferred screen-refresh fix until all earlier readiness work is complete.

## Product intent

A personal life OS should make it possible to understand what matters, turn intentions into work, connect that work to the rest of life, and see whether actions are producing the intended results. The app should connect relevant information without forcing every record into one giant object or making unrelated domains depend on each other.

The target relationship model is:

`Life area / role → Goal → Project → Milestone → Task → Work session / calendar block`

This is a common path, not a rigid hierarchy. A task may exist without a project; a goal may be advanced by several projects; a project may support a goal; a habit or routine may support a goal; a calendar event may exist independently. Explicit links should connect these records where they are meaningfully related.

## Target capabilities and relationships

### 1. Life areas and roles ("functions")

Represent broad areas of life such as work, learning, health, finances, relationships, home, personal growth, and community. These should be configurable rather than hard-coded as a fixed list.

Each area should be able to show:
- Active goals and their health/status.
- Projects and the next actionable tasks.
- Relevant habits, routines, and scheduled commitments.
- Related notes, people, resources, and reviews.
- Signals needing attention (overdue commitments, blocked work, stale goals), with sensible controls to avoid noise.

Audit whether the existing app's concept of "functions" means life areas, app modules, or executable functions in code. The data model and labels must use one clear meaning; do not add a new entity until this is resolved.

### 2. Goals

A goal represents an intended outcome, not a task list. It should support a clear title, description, status, target date where useful, review/reflection, and progress evidence.

Connections:
- A goal can have multiple supporting projects.
- A goal can be advanced by tasks, habits, or routines even without a project.
- Goal progress should be derived from explicit, understandable evidence rather than arbitrary percentages.
- Removing or archiving a project must not silently delete its goal.

### 3. Projects and project workspace

Opening a project must reliably navigate to a real detail workspace, not a blank, stuck, or generic screen. The workspace should answer: **Why does this project matter, where does it stand, and what should I do next?**

Minimum workspace:
- Project title, description, status, target date, and linked goal(s).
- Milestones, ordered consistently, with status, due date if supported, and completion state.
- Tasks and subtasks, grouped by milestone and with an unassigned section.
- Progress derived from milestones/tasks with the calculation explained.
- Next action, blockers/dependencies, and overdue items.
- Notes and resources explicitly linked to the project.
- Relevant calendar/time blocks and work-session history.
- Recent activity and a clear way to edit/archive the project.
- Empty, loading, error, and retry states; failures must not appear as infinite loading.

A project can exist without a goal. A milestone belongs to a project. Tasks may link to a project, goal, and milestone, but invalid combinations must be validated (for example, a task's milestone should belong to the same project as the task). Avoid duplicating the same relationship in multiple places without a clear source of truth.

### 4. Tasks and execution

Tasks are the actionable unit across Ordin. They should support:
- Optional project, goal, milestone, parent task, due date, schedule, estimate, priority, and status.
- Dependencies and blocked-by visibility where supported.
- Completion, reopening, and archive semantics that remain consistent across screens.
- A reliable “next action” view across all life areas.
- Links to work sessions, time blocks, reminders, and related notes.
- Safe behavior for tasks without a project or goal.

Every task mutation should update the relevant views without losing unrelated state. Completing a task should not accidentally complete a milestone or project unless an explicit, tested rule says so.

### 5. Related life domains

Audit existing screens and tables before adding new structures. Where the domain exists, connect it to the common life model:
- **Calendar and time:** events, time blocks, task scheduling, work sessions, conflicts.
- **Habits and routines:** schedules, occurrences, streak/consistency, links to goals and life areas.
- **Notes and resources:** optional links to goals, projects, tasks, people, and life areas; search and backlinks.
- **People and relationships:** people, commitments, follow-ups, and notes with explicit links.
- **Finance:** accounts, income, expenses, bills, subscriptions, debts, budgets, and savings goals; connect only relevant financial goals/projects and preserve financial integrity.
- **Health and wellbeing:** check-ins and metrics, with optional links to relevant goals/routines; keep sensitive information appropriately scoped.
- **Learning and personal growth:** learning goals, projects, study tasks, resources, and review notes, using existing primitives where possible.
- **Home and practical administration:** documents, practical items, shopping lists, reminders, and recurring responsibilities.
- **Work and focus:** work sessions, planned blocks, task outcomes, interruptions, and project-level time summaries.

Do not build duplicate task, goal, note, or reminder systems for each domain. Prefer shared primitives plus domain-specific metadata where it genuinely adds value.

### 6. Cross-domain links and navigation

The app should make connections discoverable:
- A record shows what it is linked to and provides a safe way to open linked records.
- Related records provide backlinks where useful.
- Global search finds entities across supported domains and opens the correct detail view.
- Deep links/navigation preserve entity identity and handle deleted, archived, or unavailable records gracefully.
- A link is not considered implemented merely because an ID column exists: creation, validation, display, navigation, mutation, and deletion behavior must all work.

Use foreign keys or application-level validation intentionally. The current schema contains several relationship IDs without declared foreign-key constraints, so audit ownership, orphan prevention, delete/archive rules, and migration compatibility before strengthening constraints on existing user databases.

## Phased implementation plan

### Phase 0 — Baseline and contract audit

**Purpose:** Establish what exists, what works, and what is only partially wired.

- Inventory screens, routes, repositories, tables, migrations, and tests.
- Trace the full path for each key relationship: create → persist → load → display → navigate → edit → archive/delete.
- Build a relationship matrix for life areas/functions, goals, projects, milestones, tasks, habits/routines, calendar, notes/resources, people, and domain modules.
- Identify missing columns, schema drift, missing repository methods, unconnected buttons, placeholder actions, inconsistent ownership, invalid relationship combinations, and silent failures.
- Add focused tests around confirmed defects before making broad architectural changes.
- Record baseline CI, analyzer, SonarCloud, APK, and test status. Keep the existing security rating issue open until its exact finding is understood; do not weaken quality gates to make them pass.

**Exit criteria:** A prioritized defect register, a verified entity relationship map, and reproducible tests for critical failures.

### Phase 1 — Data and relationship integrity

- Align canonical SQLite schema, additive migrations, test schema, repositories, and schema-contract checks.
- Verify required columns and indexes on both fresh installs and upgrades from existing schema versions.
- Ensure every created row receives the required owner ID and that reads/writes enforce ownership consistently.
- Validate task–milestone–project–goal consistency and prevent orphan or cross-project links.
- Define archive/delete behavior and preserve history where appropriate.
- Add repository tests for relationship creation, querying, invalid links, migration upgrades, and rollback behavior.

**Exit criteria:** Fresh and upgraded databases meet the same contract; relationship mutations either succeed completely or fail safely.

### Phase 2 — Projects, goals, milestones, and tasks form one usable workflow

- Make project open/detail loading robust, including loading/error/retry/empty states.
- Deliver the project workspace described above.
- Connect goal ↔ projects, project ↔ milestones, and project/milestone/goal ↔ tasks with validation and visible navigation.
- Make milestone creation, ordering, editing, completion, and task assignment work end-to-end.
- Derive project and goal progress from documented rules; handle unassigned tasks and empty projects honestly.
- Ensure task detail and task lists navigate back to their owning project/milestone/goal.
- Add widget and repository tests for open project, empty workspace, linked goal, milestone creation/reordering/completion, task assignment, invalid relationships, and progress calculations.

**Exit criteria:** A user can create a goal, create a project for it, add milestones, attach tasks, complete work, and see accurate progress in each relevant view.

### Phase 3 — Life areas/functions and cross-domain organization

- Resolve the meaning of "functions" and choose clear product language (for example, "Life Areas" if these mean areas of life).
- Allow configurable life areas and connect goals/projects/tasks and relevant habits/routines to them.
- Add area overview screens with active goals, projects, next actions, upcoming commitments, and attention items.
- Connect existing notes, resources, people, calendar entries, and work sessions through explicit links where useful.
- Ensure links are visible and navigable, with sensible empty states.
- Avoid forced links: standalone tasks, notes, events, and projects must remain valid.

**Exit criteria:** Life areas give a meaningful overview without duplicating the source data or creating circular ownership.

### Phase 4 — Execution, planning, and review

- Unify task execution across Today, project workspace, calendar, and life-area views.
- Make scheduling, reminders, work sessions, and completion history agree on the same task identity and status.
- Add reliable blocked/dependency visibility and actionable next steps.
- Add goal/project review flows and show evidence of progress (completed milestones/tasks, relevant habits, time invested) without misleading scores.
- Audit recurring items, notification permissions, time zones, lifecycle/relaunch behavior, and idempotency.
- Add tests for transitions, duplicate actions, background/foreground, offline/local persistence, and notification tap routing.

**Exit criteria:** A user can plan, execute, review, and resume work across screens without divergent status or lost records.

### Phase 5 — Search, links, and overall coherence

- Audit global search and cross-entity navigation.
- Add backlinks and related-record sections where they provide real value.
- Verify all cards, chips, buttons, and menu actions lead to the correct destination or perform the stated action.
- Standardize create/edit/archive flows, validation, empty states, error messages, and accessibility labels.
- Review performance for large lists and avoid repeated full-table loads where targeted queries suffice.
- Add navigation and integration tests across the most important life workflows.

**Exit criteria:** Core entities are discoverable, linked records open correctly, and users can recover from empty, stale, missing, or archived records.

### Phase 6 — Reliability and release readiness

- Run full unit, repository, widget, migration, integration, and analyzer suites.
- Run SonarCloud/security checks and investigate the unresolved main-branch new-code security rating; no speculative suppression or gate weakening.
- Verify release APK builds from the exact tested commit and artifacts upload successfully.
- Perform device checks for cold launch/relaunch, task and project persistence, notifications, navigation, and backup/restore.
- Check logs for silent catches, unobserved async errors, transaction boundaries, and inconsistent error handling.
- Maintain a release checklist and document known limitations.

**Exit criteria:** Automated gates are green and device verification is recorded honestly; no device behavior is claimed verified solely because the APK compiled.

### Phase 7 — Last: investigate and fix the persistent screen-refresh issue

**Explicitly deferred until Phases 0–6 are ready.** Track against issue #5: https://github.com/R-6167/personal-life-os/issues/5

Reproduce and instrument the reported symptoms: refresh-like behavior when focusing input fields, scrolling, tapping chips/small controls, and opening or switching screens.

Investigate:
- Whether the behavior is a normal Flutter rebuild or actual route recreation, state loss, or database reload.
- `HomeShell`, `AppDataBus`, invalidation/subscription boundaries, and broad `setState` calls.
- Widget keys, `FutureBuilder`/future lifetimes, controller creation/disposal, and parent rebuild behavior.
- Keyboard/inset/layout changes, focus handling, scroll controller lifetimes, and nested navigation.
- Whether writes or stream events trigger redundant whole-screen refreshes.

Fix the root cause rather than suppressing legitimate rebuilds. Preserve text input, focus, scroll position, selected chips, route state, and in-progress edits. Valid mutations must still refresh the affected data.

Regression coverage:
- Focusing and typing in each representative input does not reset it.
- Scrolling does not jump back unexpectedly.
- Tapping chips and small controls changes only intended state.
- Opening/switching screens preserves expected navigation and scroll state.
- A real mutation refreshes the affected domain, while unrelated domains remain stable.
- No regression to persistence, notifications, accessibility, or loading/error handling.

**Exit criteria:** Reproductions pass on a real device and in automated tests where possible; analyzer, CI, SonarCloud, and APK gates pass on the exact final commit.

## Implementation rules

1. **Audit before inventing.** Reuse existing capabilities when sound; don't create a second subsystem because a screen is incomplete.
2. **One source of truth.** Keep relationship rules, status transitions, and progress calculations explicit and tested.
3. **Small, verifiable changes.** Each PR has a narrow purpose and tests the failure it fixes.
4. **No premature merges.** Wait for all required checks and APK/artifact upload to finish; inspect failures before retrying.
5. **Migrations are product behavior.** Test fresh installs and existing databases, not only in-memory happy paths.
6. **No fake completeness.** A visible control, stored ID, or passing build is not proof of an end-to-end feature.
7. **Protect user data.** Avoid destructive migrations, broad cascades, and silent error swallowing.
8. **Screen refresh remains last.** Do not start Phase 7 until all earlier readiness phases are complete.
9. **Keep a living record.** Update this roadmap with PRs, commits, test results, outstanding risks, and verified device results as each phase advances.

## Immediate priorities

1. Finish and validate the project workspace/schema compatibility fix currently under review.
2. Run the Phase 0 relationship audit and produce a file-backed gap matrix with severity and test coverage.
3. Resolve confirmed integrity and navigation gaps in the order above.
4. Keep the main-branch SonarCloud security rating issue visible as an independent release gate.
5. Do not begin the screen-refresh fix until the other phases are ready.
