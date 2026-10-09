# Phase 0 — Ordin Relationship and Workflow Gap Matrix

**Audit date:** 2026-10-09  
**Baseline:** `main` after project-workspace compatibility fix and roadmap merge  
**Scope:** Current source/schema/navigation relationships. This is a static repository audit; device behavior is not claimed verified.

## Summary

Ordin already has a useful set of primitives and domain modules: goals, projects, milestones, tasks/subtasks, habits, routines, calendar/planning, notes, people, finances, health/wellbeing, practical administration, and generic entity links. It is not starting from zero.

The principal gap is that the app currently combines several separately implemented domain features, but not every relationship is a complete end-to-end contract. Some connections are present in columns and repository methods but are not fully validated, reflected in progress, or made discoverable across the UI. The first project-open failure also exposed schema drift, now addressed in the project-workspace fix.

**Important distinction:** this is a code audit, not proof that every listed workflow fails in the installed APK. Each finding below is classified by evidence and needs tests before broad fixes.

## Current relationship model (observed)

- Goal → Projects: `projects.goal_id`, `ProjectRepository.listByGoal`, and the goal detail screen's project tree.
- Goal → Tasks: `tasks.goal_id`, task repository queries, and goal detail's direct-task section.
- Goal → Habits: `habits.goal_id`, goal thread service/repository methods, and the goal detail habits section.
- Project → Milestones: `milestones.project_id`, milestone repository, and project workspace loading.
- Project → Tasks/Subtasks: `tasks.project_id` and `tasks.parent_task_id`.
- Task → Milestone: `tasks.milestone_id`; task creation/update has some same-project/owner validation.
- Tasks → Dependencies/Planning: `task_dependencies`, scheduled task fields, time blocks, and work sessions.
- Project → Notes/Documents: generic `entity_links` rows, queried by the project workspace.
- Activity: `activity_events` records are surfaced in goal/project workspaces.
- Top-level organization: `LifeHub` groups goals, projects, habits, routines, and notes, but the canonical schema does not currently contain a first-class configurable life-area/function entity.

## Findings matrix

| ID | Severity | Area | Finding | Evidence / consequence | Planned response |
|---|---|---|---|---|---|
| P0-01 | Fixed; verify release | Project open/schema | The workspace ordered milestones by `position`, but the canonical `milestones` table and additive migration omitted that column. Milestone inserts also omitted required `owner_id`. | Could fail loading a project or creating its first milestone. | Project fix merged via PR #9: add/migrate/verify `position`, write `owner_id`, and add workspace contract test. Confirm latest main CI/APK and test result before marking device behavior verified. |
| P0-02 | High | Goal progress | `GoalRepository.progress()` returns `habitsTotal: 0` and `habitsDoneToday: 0` as hard-coded values, despite goal-linked habits being supported and displayed. The goal progress ratio only uses tasks and projects. | Goal progress can misrepresent progress when a goal is supported by habits. | Define explicit progress semantics, query linked habits and today's occurrences, and test zero/paused/archived/completed cases. Avoid implying habit contribution until the calculation is clear. |
| P0-03 | High | Goal progress consistency | Goal project totals exclude archived projects, but project-completed totals do not. Task totals/completed totals do not consistently exclude archived tasks; totals also exclude cancelled tasks while completed counts are queried independently. | Numerator and denominator may describe different sets, producing misleading progress. | Make progress queries use one shared eligible-record definition and test archived/cancelled/empty combinations. |
| P0-04 | High | Relationship validation | Project goal linking is a direct update by project ID; the repository method does not verify the project and goal exist under the current owner before writing. Task create/update validates the milestone/project pair, but other links (project, goal, parent task) need a full consistency audit. | Orphaned or mismatched references can be stored even when individual fields are valid IDs. | Add transaction-safe relationship validation in repository boundaries; test wrong-owner, missing, archived, and mismatched project/milestone/goal/parent combinations. |
| P0-05 | High | Generic links | `entity_links` is deliberately generic and supports current and legacy column naming schemes. The inspected link queries/deletion use entity IDs but do not consistently scope reads/deletes by `owner_id`, and arbitrary type/target validity is not enforced at this boundary. | Links can be orphaned or inconsistent; ownership assumptions are fragile if multi-profile support is ever introduced. | Keep backward compatibility, normalize link schema assumptions, validate both endpoints/owner, and add orphan/duplicate/unlink tests before tightening constraints. |
| P0-06 | Medium | Life-area/function model | The schema has domain tables and `LifeHub`, but no first-class configurable life-area/function record that can connect work across domains. | A user can see separate modules, but cannot yet use one configurable life area as a durable cross-domain organizing entity. | Decide clear product language; if “functions” means areas of life, add a first-class life-area model only after relationship integrity is stable. Do not duplicate tasks/goals per area. |
| P0-07 | Medium | Milestone workflow | Milestones can be created and completed, and have a `position` field, but the repository currently initializes new milestones at position 0 and no reorder operation was found in the inspected milestone repository. | Ordering exists in the read contract but does not yet have an explicit, user-controlled ordering contract. | Add stable ordering/reorder semantics with tests; ensure duplicate/default positions remain deterministic. |
| P0-08 | Medium | Error visibility | Project detail now handles load failures with a retry state. In other inspected paths, broad catch-and-return-empty patterns exist (for example dependency/link/workspace helper reads). | A failed query can look like “no related data” rather than a real error. | Audit catches, classify recoverable optional data vs required workspace data, and log/propagate errors where an empty result would mislead. |
| P0-09 | Medium | Archive/detail semantics | Some list methods exclude archived entities, while detail getters/workspace queries are ID-based and do not uniformly apply archived/owner policy. | A stale link may open an archived item as if it were active, or return a partial workspace. | Define explicit open-archived behavior (view-only/restore/not found) and apply it consistently to direct and linked navigation. |
| P0-10 | Medium | Navigation and discoverability | The goal detail screen can open project/task details; the project workspace has related sections. A generic `entity_links` table alone does not make backlinks or cross-domain navigation complete. | A record may have a stored relationship that is not visible or navigable from both ends. | Build an entity-by-entity navigation matrix and add links/backlinks where useful; verify buttons/cards and stale-link handling with widget tests. |
| P0-11 | Medium | Data contract coverage | Existing tests cover critical task/finance/work-session flows and the project workspace contract, but the reviewed test set does not yet establish end-to-end coverage for the full goal → project → milestone → task → scheduled session chain or cross-domain links. | Regressions can pass isolated repository tests while a user-facing relationship remains disconnected. | Add layered repository/widget/integration tests incrementally, starting with the core goal/project/milestone/task path. |

## Phase 0 conclusions

1. The overall concept is sound: goals should represent outcomes, projects should organize coordinated work, milestones should mark meaningful checkpoints, and tasks should be actionable steps. Habits/routines and schedules should support goals without being forced into a project.
2. Ordin already contains most of these entity types. The work is primarily to make existing relationships consistent, validated, visible, and tested before adding more domain structures.
3. A first-class configurable life-area/function entity is a likely product-level addition, but it should come after the core relationship contracts. First clarify the label and role; the current app's hubs are navigation groupings, not equivalent persistent data.
4. Progress numbers need a documented contract. They must not silently count different record sets or report linked habits as zero.
5. The persistent screen-refresh issue remains deferred to the final phase, as requested.

## Ordered next actions

1. **Phase 1A — Relationship integrity:** add tests and safe validation for goal/project/task/milestone/parent-task references; align owner, archive, and not-found behavior.
2. **Phase 1B — Progress correctness:** fix goal/project progress query consistency and linked-habit contribution with a documented formula.
3. **Phase 1C — Generic links:** validate ownership and endpoint existence; test project notes/resources and reverse navigation.
4. **Phase 2 — Complete project workflow:** verify create/open/edit/complete/reopen/archive, milestone ordering, task grouping, goal navigation, next-action, scheduling, and error/retry states.
5. **Phase 3 — Life areas/functions:** introduce a configurable cross-domain organizing model only after the core relationships are stable.
6. Continue release/security gates and device verification. Do **not** start Phase 7 screen-refresh work until all prior phases are ready.

## Validation policy

- Each implementation change must include a regression test that fails before the fix where practical.
- Run Flutter tests, analyzer, CI, SonarCloud, and APK build on the proposed commit.
- Do not merge while required checks or artifact upload are pending.
- A green build does not count as real-device verification.
- Keep the main-branch SonarCloud security-rating concern as a separate open gate until the exact finding is identified and addressed.
