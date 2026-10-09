# Ordin Relationship Audit — Baseline and Gap Matrix

**Audit date:** 2026-10-09  
**Baseline:** `main` after project-workspace schema fix (`6ecaad0e5eaaecfb33e789cef58346dbc2f76ec9`) and phased roadmap documentation (`6c698b7598ffe2281f336e572688439965069517`).  
**Scope:** Goal/project/milestone/task relationships, cross-domain links, schema contracts, and the path that opens a project workspace. This is a source audit; device verification is still required.

## Baseline status

- The project-workspace fix has merged. CI and APK build both passed on the merge commit:
  - CI: https://github.com/R-6167/personal-life-os/actions/runs/37907636826
  - APK: https://github.com/R-6167/personal-life-os/actions/runs/37907636805
- SonarCloud's main-branch security-rating check still fails. Keep this as a separate open gate; do not suppress findings or weaken the gate.
- Project open has an actual route: `LifeHub` pushes `ProjectDetailScreen(projectId: p.id)`. The detail screen loads `ProjectWorkspaceService.load(projectId)`. A previously confirmed schema mismatch (`milestones.position` missing from canonical schema/migration) was fixed in PR #9, with a regression test.

## Relationship model observed in code

| Relationship | Current implementation | Audit assessment |
|---|---|---|
| Goal → Project | `projects.goal_id`; goal detail can create projects; project workspace links back to the goal | Basic path exists. Need validation, orphan handling, and owner-consistent reads/writes. |
| Goal → Task | `tasks.goal_id`; goal detail can create direct tasks | Basic path exists. Goal progress counts tasks and projects, but excludes habit contribution despite supporting goal-linked habits. |
| Goal → Habit | `habits.goal_id`; goal detail can link a habit | Link path exists. Progress currently returns `habitsTotal = 0` and `habitsDoneToday = 0` unconditionally, so those fields are placeholders rather than live metrics. |
| Project → Milestone | `milestones.project_id`; project workspace loads and renders milestones | Basic read/create/complete path exists after schema fix. No clear milestone edit/reorder flow was found in the reviewed screen/repository. |
| Project → Task | `tasks.project_id`; project workspace lists project tasks and subtasks | Basic path exists. Workspace currently presents milestones and tasks as separate lists, not as milestone-grouped work. |
| Milestone → Task | `tasks.milestone_id`; task creation accepts a milestone ID | Storage path exists, but the project screen's normal task creation path does not pass a milestone ID, and task update has no milestone-assignment parameter. Existing tasks cannot be reassigned through the reviewed repository API. |
| Task → Subtask | `tasks.parent_task_id`; workspace groups children under root tasks | Basic path exists. Relationship validity (same project/owner, no cycles, parent existence) needs validation. |
| Task → Dependency | `task_dependencies`; workspace queries dependency status | Partial. Dependency records have no schema-level foreign keys; repository query paths can hide errors by returning empty results. Validate orphan and self/cycle dependencies. |
| Project → Notes/resources | `entity_links` plus workspace query helpers | Partial and fragile: workspace supports multiple historical column-name variants via SQL that references columns not present in the canonical schema, then catches errors and returns empty lists. Attachment/link direction and schema contract need a single canonical form. |
| Project/goal/task → Activity | `activity_events` | Partial. Project workspace loads activity by entity IDs but its query does not filter by `owner_id`; ensure ownership and entity types are enforced consistently. |
| Life area/function → entities | No explicit configurable life-area table/model was found in the canonical schema or reviewed repositories | Product/model gap if “functions” means areas of life. First clarify terminology and then introduce a reusable relationship rather than duplicating each entity by domain. |

## Prioritized gap register

### P0 — Data integrity and project workspace correctness

1. **Project detail loading and schema drift.** Previously, `ProjectWorkspaceService.load` ordered milestones by `position` while the canonical schema and upgrade migration omitted the column. Fixed by PR #9: canonical schema, upgrade-safe column addition, schema-contract verification, test DB alignment, and a workspace regression test. CI/APK are green; device confirmation remains outstanding.
2. **Milestone creation ownership.** `milestones.owner_id` is required, but create previously omitted it. Fixed in PR #9 by obtaining and storing the current owner ID.
3. **Relationship validation.** Project/task/goal/milestone IDs are often plain text columns without foreign keys. Repositories currently accept potentially incompatible combinations. Add validation at repository boundaries before adding constraints or destructive migrations.
4. **Task-to-milestone workflow is incomplete.** A task can store `milestone_id`, but the project UI/repository update path does not provide an end-to-end way to assign/reassign tasks to milestones. Implement after integrity rules and tests are defined.
5. **Project workspace error visibility.** The detail screen catches all load errors and shows a generic retry message. This is acceptable user-facing behavior, but diagnostic logging should capture the underlying exception without exposing sensitive data.

### P1 — Truthful progress and connected project execution

6. **Goal progress placeholders.** Goal-linked habits are supported, but goal progress reports habit metrics as hard-coded zero. Either implement honest habit contribution metrics or remove those fields from user-facing calculations until supported.
7. **Progress definitions differ by context.** Project workspace weights tasks at 70% and milestones at 30%; goal progress weights tasks at 60% and projects at 40%. Document what these ratios mean, exclude cancelled/archived items consistently, and test empty/mixed states before presenting progress as a reliable signal.
8. **Milestone workspace semantics.** Milestones are visible and can be completed, but no clear edit/reorder or per-milestone task grouping/assignment flow was found in the reviewed implementation.
9. **Archive/status consistency.** Audit goal/project/task progress queries for consistent archived, cancelled, and completed filtering. For example, goal progress currently includes task counts without an archived filter, while project workspace excludes archived tasks.
10. **Cross-domain links fail silently.** Note/resource queries catch SQL errors and return empty arrays. This makes schema drift appear as “no linked items”; use a canonical schema/query and log unexpected failures.

### P2 — Wider Personal Life OS relationships

11. **Configurable life areas/functions.** No explicit life-area entity was found in the canonical schema. If the product's “functions” are work, health, learning, relationships, home, finance, and personal growth, define that concept explicitly and connect entities through reusable links.
12. **Consistent related-record navigation.** Add visible, validated links/backlinks among projects, goals, milestones, tasks, notes/resources, people, routines/habits, calendar blocks, and work sessions where useful. Avoid forcing unrelated items into the same hierarchy.
13. **Search and discovery.** Audit whether cross-domain search can open the correct detail route and handle missing/archived records.
14. **Ownership and deletion policy.** Add a matrix for every relationship: who owns each record, whether links may be null, archive vs delete behavior, and whether history must survive.
15. **Test coverage.** Add repository and widget tests for invalid links, owner mismatch, missing goal/project, milestone assignment, progress edge cases, empty workspaces, navigation, and migrations from existing schema versions.

## Recommended execution order

1. Finish/retain PR #9 as the project workspace schema correction; validate on device.
2. Phase 0 audit (this document): trace relationship paths and turn each gap into a tested, prioritized change.
3. Phase 1 integrity: define validation rules, owner-scoped repository operations, schema migration tests, and invalid-link/rollback tests.
4. Phase 2 project workflow: assign/reassign tasks to milestones, group tasks by milestone in the project workspace, add milestone edit/reorder behavior, and test the goal → project → milestone → task flow.
5. Phase 3 life areas and cross-domain links: resolve “functions” terminology, model configurable life areas, and add related-record navigation without duplicating core entities.
6. Phase 4 progress/planning: reconcile progress calculations, habits/routines, scheduling, work sessions, reminders, and reviews.
7. Phase 5 discovery and polish: global search, backlinks, empty/error states, and large-list performance.
8. Phase 6 reliability/release readiness: automation, security, migration, backup/restore, and device checks. Main-branch SonarCloud security rating remains an independent gate.
9. **Last, as explicitly requested:** Phase 7 investigate/fix the screen-refresh issue in issue #5, then add regression tests for focus, text entry, scrolling, chips/controls, navigation, and valid mutation refresh.

## Audit constraints and cautions

- This report reflects source code inspected on the audit date, not an assertion that all device behavior has been reproduced.
- Do not add foreign keys or destructive schema changes to existing user databases without a migration plan and upgrade/rollback tests.
- Do not claim a relationship is complete just because an ID column exists. Creation, validation, persistence, display, navigation, update, archive/delete semantics, and tests must agree.
- The screen-refresh issue remains deliberately deferred until the earlier phases are ready.
