# Ordin Phase 0 — Relationship and Workflow Audit

**Baseline commit:** `6c698b7598ffe2281f336e572688439965069517`  
**Audit date:** 2026-10-09  
**Scope:** Project/goal/milestone/task workflow and adjacent cross-domain connections.  
**Status:** Static code/schema audit; runtime/device verification is still required.

## Executive result

Ordin already has a substantial base: SQLite entities for goals, projects, milestones, tasks, habits, routines, calendar/time blocks, work sessions, notes, people, documents, and generic entity links. It also has project and goal detail screens, a project workspace service, and repository/widget/integration tests.

The problem is not simply that the app lacks screens. Several connections are represented in the UI or database but are not yet complete end-to-end. In particular, project resource creation/loading contains schema mismatches; some relationships are stored without validation; and goal progress exposes a habit metric that is hard-coded to zero. The app needs a verified relationship contract and integration tests across creation, persistence, display, navigation, and mutation.

## Findings register

### P0 — Project workspace schema mismatch (fix merged; release verification pending)

**Evidence**
- `apps/flutter/lib/services/project_workspace.dart` queries milestones ordered by `position`.
- The canonical milestone schema previously omitted `position`, and `MilestoneRepository.create` writes it.
- The milestone table requires `owner_id`, which creation previously omitted.

**Impact:** Project detail loading and milestone creation could fail against the canonical schema.  
**Action:** Fixed in the project workspace compatibility PR: canonical schema + upgrade-safe column migration + schema contract check + owner assignment + regression test. Confirm the post-merge CI/APK artifact and test on an upgraded real device before declaring this resolved.

### P1 — Project resource creation is incompatible with the canonical schema

**Evidence**
- `apps/flutter/lib/services/project_workspace.dart`, `attachResource`, inserts a `notes` field into `documents`.
- `apps/flutter/assets/schema.sql` defines `documents` without a `notes` column.
- The project detail UI calls `attachResource` directly and does not catch/report the write failure.

**Impact:** Adding a resource can throw rather than save.  
**Action:** Use fields supported by the canonical schema or add a deliberate migration if resource notes are a real product requirement. Save the document and its project link atomically; show a useful error in the UI.

### P1 — Project resource retrieval silently fails

**Evidence**
- `_linkedResources` queries `entity_links.source_type/source_id/target_type/target_id`.
- The canonical `entity_links` schema uses `from_type/from_id/to_type/to_id`.
- The query catches any failure and returns an empty list without recording the cause.

**Impact:** Resources can appear absent even if link rows exist. This is a schema-contract mismatch hidden by a silent catch.  
**Action:** Query the canonical link columns (or use `LinkRepository`); keep legacy compatibility only if an actual supported legacy schema requires it. Add a round-trip test: attach resource → reload workspace → resource appears.

### P1 — Project note/resource writes are not atomic and link failures are swallowed

**Evidence**
- `attachNote` / `attachResource` write the entity first and link it afterward.
- `_insertLink` catches all errors and tries a legacy column layout, then catches all errors again.
- The canonical `entity_links` schema omits `relation`, although `LinkRepository` and `_insertLink` write it. This can make canonical link creation fail before the legacy fallback also fails.
- If either entity or link insert fails, the method can leave an orphan or report success without a relationship.

**Impact:** Partial writes and invisible broken relationships.  
**Action:** Use a SQLite transaction for entity + link; use the canonical schema deliberately; propagate failures to the UI and log enough context to diagnose them. Do not turn a failed relationship write into apparent success.

### P1 — Goal progress reports habit support that is not implemented

**Evidence**
- `GoalRepository.progress` returns `habitsTotal: 0` and `habitsDoneToday: 0` even though `listLinkedHabits` and `linkHabit` exist.
- `GoalRepository.progressRatio` is derived only from tasks and projects.

**Impact:** Goal detail can imply that habits are part of goal progress while the actual metric is always zero and does not contribute.  
**Action:** Decide and document the intended goal-progress model. Either calculate a meaningful habit contribution with a defined time window and tests, or remove the misleading placeholder until implemented. Avoid arbitrary percentages.

### P1 — Relationship consistency is not validated at repository boundaries

**Evidence**
- `TaskRepository.create` accepts `projectId`, `goalId`, `milestoneId`, and `parentTaskId` and inserts those IDs without checking that the referenced records exist or belong together.
- `TaskRepository.update` can change `project_id` without synchronizing or validating `goal_id` and `milestone_id`.
- `ProjectRepository.linkGoal` updates a goal ID without checking that the goal exists or is owned by the same user.
- The canonical schema has several relationship ID columns but no foreign keys for these links.

**Impact:** Tasks can become attached to a milestone from another project, a project can point at an invalid goal, or an edit can leave stale relationships.  
**Action:** Define relationship invariants and validate them inside the same transaction as the mutation. For a task with a milestone, the milestone must belong to the same project; goal/project combinations must be explicit and consistent. Test invalid links and rollback. Plan safe migration/backfill before adding foreign keys to existing user databases.

### P1 — Search is not yet a life-wide entry point

**Evidence**
- The current `ExtendedRepository.search` implementation searches task titles and note content, but does not search projects, goals, milestones, people, documents, or calendar events.

**Impact:** Users cannot reliably find their life data from one place, despite these entities existing.  
**Action:** Expand search in stages with type-aware results and correct destination routing. Scope queries to the current owner and exclude archived records by default.

### P2 — Progress and status rules need one shared contract

**Evidence**
- `ProjectWorkspaceService` computes progress from task and milestone completion using a 70/30 weighted score.
- `ProjectRepository.progress` exposes raw counts, while `GoalRepository.progressRatio` uses a different 60/40 project/task formula.
- Some queries do not consistently exclude archived tasks/projects or canceled/archived items.

**Impact:** Different screens can tell different stories about the same goal/project; progress may be misleading for an empty workspace or one with archived records.  
**Action:** Define domain-specific progress semantics, expose the basis (e.g., completed/total), and share tested calculation functions across screens. Keep “no work yet” distinct from “0% complete” where that is clearer.

### P2 — Cross-domain link contract is not yet comprehensive

**Evidence**
- `entity_links` can represent links to notes, documents, tasks, people, events, and other entities, but not every entity type has an established display/navigation path from each relevant screen.
- Project workspace activity is based on entity IDs; linked notes/resources have bespoke SQL instead of a shared link-resolution path.

**Impact:** Some stored relationships may not be visible or navigable, so an ID existing in SQLite is not enough to count a feature as connected.  
**Action:** Use one canonical link repository and a supported entity-type registry for peer resolution, title resolution, owner checks, display, and navigation. Add backlinks where useful without forcing unrelated records into a project.

### P2 — “Functions” / life areas need a clear product definition

**Evidence**
- The inspected schema has domain entities but no canonical configurable `life_areas` / `functions` entity.
- “Function” could mean a broad life area (work, health, learning, home) or an internal app function/module; those meanings must not be mixed.

**Impact:** Adding a poorly defined entity now could duplicate modules or create a second competing hierarchy.  
**Action:** During product-model work, explicitly define whether this means configurable Life Areas. If so, make them organizational lenses that can group/link goals, projects, tasks, habits/routines, and relevant records; they should not own or duplicate those records.

### P2 — Regression coverage needs more end-to-end relationship cases

**Evidence**
- A project workspace contract test now covers loading a project and creating a milestone.
- Existing integration tests cover task lifecycle, finance lifecycle, work sessions, and smoke flows, but the audited project-note/resource round trips, invalid relationship cases, goal-linked habit progress, and project/milestone/task cross-navigation are not yet covered by a focused suite.

**Action:** Add repository and widget tests for each relationship path, including invalid links, fresh schema, upgraded schema, failure rollback, empty states, and navigation destinations.

## Target relationship contract

- A goal may be supported by multiple projects; a project may exist without a goal.
- A milestone belongs to exactly one project.
- A task may exist independently or link to a project, goal, milestone, and parent task.
- If a task links to a milestone, that milestone must belong to the task's project.
- If a task has both a project and goal, the relationship must follow a documented policy (for example, goal is the project's goal, unless explicit multi-goal support is later introduced).
- A habit/routine may support a goal without being forced into a project.
- Notes/resources/people/events/time blocks/work sessions should link through explicit, validated relations and be navigable in both directions where useful.
- Calendar events and finance records can remain standalone; link them to a goal/project only when meaningful.
- Archive/delete behavior must preserve history and never silently orphan or cascade-delete unrelated user data.

## Next execution order

1. Verify the merged project workspace fix on the post-merge CI and release APK.
2. Implement the project resource/note round-trip fix with transaction and regression tests.
3. Add relationship validation for task/project/milestone/goal creation and updates.
4. Define and test goal/project progress rules, including linked habits.
5. Build out life-area/function semantics and cross-domain navigation.
6. Expand global search and integration coverage.
7. Finish release/device reliability verification and the unresolved security-gate investigation.
8. **Last:** investigate and fix the persistent screen-refresh issue in [issue #5](https://github.com/R-6167/personal-life-os/issues/5). Do not begin it until the preceding readiness work is complete.

## Audit limitations

This is a static audit of repository code and schema. It does not prove every bug reproduces on-device, nor does it claim that every existing domain has been exhaustively audited. Runtime logs, real-device tests, and expanded integration coverage remain part of the plan.
