# Ordin Phase 0 — Relationship and Workflow Audit

**Audit date:** 2026-10-09  
**Scope:** Repository-level audit of the goal/project/milestone/task chain and the links that make Ordin a coherent personal life OS.  
**Screen-refresh issue:** Explicitly excluded from implementation in this phase; it remains the final phase as recorded in `ORDIN_PERSONAL_LIFE_OS_ROADMAP.md` and issue #5.

This is a code/schema audit, not a claim of completed real-device verification. Findings below are based on the current repository and should be updated as tests and device runs add evidence.

## Relationship map found in the code

| Relationship | Current representation | Audit status |
|---|---|---|
| Goal → projects | `projects.goal_id`; one goal per project, many projects per goal | Implemented but direct and single-parent only |
| Project → milestones | `milestones.project_id` | Implemented; ordering column repaired in the schema contract fix |
| Project → tasks | `tasks.project_id` | Implemented |
| Milestone → tasks | `tasks.milestone_id` plus app-level validation | Partially guarded; validation differs between create and update |
| Goal → direct tasks | `tasks.goal_id` | Implemented; goal-thread queries need consistent archive/owner filters |
| Goal → habits | `habits.goal_id` | Implemented |
| Project → notes/resources | `entity_links` intended to provide bidirectional links | Link writer/schema mismatch found; repair submitted in PR #20 |
| Task → dependencies | `task_dependencies` | Implemented; dependency validation and orphan handling need audit |
| Task → scheduled work | Task schedule fields, `time_blocks`, `work_sessions` | Exists; end-to-end status/ownership consistency needs tests |
| Configurable life areas/functions → entities | No canonical life-area/function table found in `schema.sql` | Product/data-model gap; resolve meaning before adding an entity |

## Confirmed findings

### P0 — Project workspace could fail during load (repair merged)

- `ProjectWorkspaceService.load()` sorts milestones by `position`, but the canonical milestone schema initially lacked that column.
- Milestone creation also omitted required `owner_id`.
- Fixed in the merged project-workspace schema compatibility change and covered by a regression test for loading a project and creating a milestone.
- Post-merge CI and APK build passed. This does not replace a device check against an installed build.

### P1 — Generic entity-link writes used columns that do not exist (repair submitted)

- Canonical `entity_links` defines `from_type/from_id/to_type/to_id` and does not define `relation`.
- `LinkRepository.link()` attempted to insert `relation` in canonical mode, which conflicts with the schema contract.
- `ProjectWorkspaceService._insertLink()` attempted the same unsupported column, then retried with legacy `source_type/target_type` columns, and swallowed the second failure. The caller could appear successful even though no relationship had been persisted.
- Project workspace link reads also referenced legacy columns that are not in the canonical schema; fallback reads supported only one direction.
- Resource creation could try to write `documents.notes`, a column absent from the canonical schema.
- PR #20 addresses these issues by using canonical columns, transactionally creating each record and link, supporting both link directions, scoping linked reads to the current owner, adding the resource notes column with an additive migration, and adding regression tests.
- Do not mark this repair complete until CI, SonarCloud, APK build, and artifact upload finish successfully.

### P1 — Relationship integrity is uneven

- Task creation checks that a selected milestone belongs to the selected project and current owner.
- Task creation does not consistently validate that the project and goal IDs exist and belong to the current owner, or that the selected goal/project combination is coherent.
- Task update checks milestone/project compatibility in some paths, but other update paths do not consistently enforce the same ownership and relationship rules.
- Milestone creation writes a project ID but does not first verify that the project exists and belongs to the current owner.
- Project-to-goal linking updates `goal_id` without validating the target goal or scoping the project update by owner.
- The schema has limited foreign-key coverage for these cross-entity IDs, so invalid or orphaned links can be persisted unless repositories validate them.
- Phase 1 should centralize and test these rules before adding stricter database constraints that might affect existing user databases.

### P1 — Progress can disagree between screens

- `ProjectWorkspaceService` calculates project progress using 70% task completion and 30% milestone completion.
- `LifeThreadService` uses a different project-branch weighting (55% tasks and 45% milestones).
- `GoalRepository.progressRatio()` uses tasks and projects at 60%/40%, while `LifeThreadService.forGoal()` also includes milestones and a recent-work boost.
- Repository-level project progress counts do not consistently exclude archived tasks, while workspace/goal-thread queries use different filters.
- This can make a project or goal show different progress depending on the screen. Phase 2/4 should define one documented calculation per concept, centralize it, and add tests for empty, archived, cancelled, completed, and mixed-work cases.

### P2 — Milestones are missing planning detail

- The canonical milestone record currently supports title, status, project, ordering, and completion timestamps; it does not define a due/target date or a description.
- The workspace can show and manage milestones, but richer planning (dates, blockers, outcome/acceptance criteria) requires an explicit schema and UI design.
- Add only the fields that are used end-to-end, with an additive migration and tests.

### P2 — “Functions” / life areas are not a first-class entity yet

- The canonical schema has goals, projects, tasks, habits, routines, notes, people, calendar and domain records, but no `functions` or configurable `life_areas` table.
- The current Life hub aggregates life-related records; it is not itself a persisted life-area relationship model.
- Before implementing this, settle the product meaning: if “functions” means areas such as work, health, learning, relationships, finances and home, model them as configurable life areas. If it means app features/modules, that is navigation architecture and should not be represented as personal data.
- Do not force every entity to belong to a life area; links should be optional and meaningful.

### P2 — Error and query behavior needs consistency

- Project detail has a loading/error/retry state.
- Goal detail's load path does not have equivalent error handling around the thread query; a thrown database error can leave the screen in a loading state.
- Several thread/workspace reads are duplicated rather than sharing one query/aggregation contract.
- Phase 0/2 should add consistent loading, not-found, empty, error and retry states, and tests for malformed/missing linked records.

## Priority implementation sequence

1. **Finish PR #20** — canonical entity links and atomic note/resource attachments. Wait for all gates and APK upload.
2. **Phase 0 completion** — add tests for task/project/goal/milestone create/update combinations, owner scoping, orphan links, and progress discrepancies. Trace actual UI routes and verify buttons navigate to the expected detail screen.
3. **Phase 1 — relationship integrity** — validate project, goal, milestone and parent-task relationships in both create and update paths; validate project-goal links; use atomic writes for multi-record changes; add upgrade-safe schema checks.
4. **Phase 2 — project/goal workflow** — make the project workspace a dependable hub for goal, milestones, tasks/subtasks, next action, scheduling, notes/resources and activity. Define one progress rule per concept and test it.
5. **Phase 3 — configurable life areas** — introduce an optional life-area model only after “functions” is unambiguously defined; make related entities discoverable from both directions.
6. **Phase 4–6 — planning, cross-domain links, reliability and release readiness** — complete end-to-end flows across calendar, habits/routines, work sessions, finance, notes/resources and reviews; verify device behavior and security gates.
7. **Final phase only — screen-refresh issue** — investigate and fix issue #5 after the earlier phases are ready. Preserve focus, text, scroll, selection and route state; test legitimate refreshes still occur.

## Required acceptance evidence

- Repository and widget tests prove each relationship can be created, loaded, navigated, updated, and safely removed/archived.
- Fresh database and upgraded database tests prove schema compatibility.
- No silent success when a link write fails.
- Progress calculations agree across screens for the same underlying records.
- CI/analyzer/SonarCloud pass, APK build and artifact upload finish, and real-device checks are recorded separately from automated results.
- Screen-refresh tests are intentionally deferred until the final phase.
