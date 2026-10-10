import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/screens/project_detail_screen.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/link_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/data/planning_repository.dart';
import 'package:ordin/data/task_dependency_queries.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/domain/enums.dart';
import 'package:ordin/services/project_workspace.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('project repository rejects reads and mutations for another owner', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final project = await projects.create(title: 'Owner-scoped project');
    final db = await app.database;
    final otherOwnerId = AppDatabase.newId();
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'projects',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: [project.id],
    );

    expect(await projects.getById(project.id), isNull);
    expect(await projects.listActive(), isEmpty);
    await expectLater(
      projects.updateMeta(id: project.id, title: 'Unauthorized edit'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      projects.complete(project.id),
      throwsA(isA<StateError>()),
    );

    final stored = await db.query(
      'projects',
      columns: ['title', 'status'],
      where: 'id = ?',
      whereArgs: [project.id],
      limit: 1,
    );
    expect(stored.single['title'], 'Owner-scoped project');
    expect(stored.single['status'], 'ACTIVE');
  });

  test('milestone completion rejects another owner milestone', () async {
    final app = AppDatabase.instance;
    final project = await ProjectRepository(app).create(title: 'Milestone ownership');
    final milestone = await MilestoneRepository(app).create(
      projectId: project.id,
      title: 'Protected milestone',
    );
    final db = await app.database;
    final otherOwnerId = AppDatabase.newId();
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'milestones',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: [milestone.id],
    );

    await expectLater(
      MilestoneRepository(app).complete(milestone.id),
      throwsA(isA<StateError>()),
    );
    final stored = await db.query(
      'milestones',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [milestone.id],
      limit: 1,
    );
    expect(stored.single['status'], isNot('COMPLETED'));
  });

  test('project workspace loads and can create a milestone', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    const projectId = 'project-workspace-contract';
    final now = AppDatabase.nowMs();

    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'title': 'Workspace contract test',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    final initial = await ProjectWorkspaceService(app).load(projectId);
    expect(initial.project['title'], 'Workspace contract test');
    expect(initial.milestones, isEmpty);

    await MilestoneRepository(app).create(
      projectId: projectId,
      title: 'First milestone',
    );

    final refreshed = await ProjectWorkspaceService(app).load(projectId);
    expect(refreshed.milestones, hasLength(1));
    expect(refreshed.milestones.single['title'], 'First milestone');
    expect(refreshed.milestones.single['owner_id'], ownerId);
    expect(refreshed.milestones.single['position'], 0);
  });

  test('project task can be linked to its own milestone', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    const projectId = 'milestone-task-project';
    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'title': 'Milestone task project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    final milestone = await MilestoneRepository(app).create(
      projectId: projectId,
      title: 'Build foundation',
    );

    await TaskRepository(app).create(
      title: 'Wire the data model',
      projectId: projectId,
      milestoneId: milestone.id,
    );

    final workspace = await ProjectWorkspaceService(app).load(projectId);
    expect(workspace.tasks, hasLength(1));
    expect(workspace.tasks.single['milestone_id'], milestone.id);
  });

  test('task cannot be linked to a milestone from another project', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    for (final id in ['project-a', 'project-b']) {
      await db.insert('projects', {
        'id': id,
        'owner_id': ownerId,
        'title': id,
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
    }
    final milestone = await MilestoneRepository(app).create(
      projectId: 'project-a',
      title: 'Only for A',
    );

    await expectLater(
      TaskRepository(app).create(
        title: 'Invalid cross-project task',
        projectId: 'project-b',
        milestoneId: milestone.id,
      ),
      throwsA(isA<StateError>()),
    );
  });
  test('project goal links must resolve to an active goal owned by the user', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();

    await db.insert('projects', {
      'id': 'goal-link-project',
      'owner_id': ownerId,
      'title': 'Goal link project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    await expectLater(
      ProjectRepository(app).linkGoal('goal-link-project', 'missing-goal'),
      throwsA(isA<StateError>()),
    );
    final unchanged = await db.query(
      'projects',
      columns: ['goal_id'],
      where: 'id = ?',
      whereArgs: ['goal-link-project'],
      limit: 1,
    );
    expect(unchanged.single['goal_id'], isNull);

    await db.insert('goals', {
      'id': 'goal-link-valid',
      'owner_id': ownerId,
      'title': 'Valid goal',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    await ProjectRepository(app).linkGoal('goal-link-project', 'goal-link-valid');
    final linked = await db.query(
      'projects',
      columns: ['goal_id'],
      where: 'id = ?',
      whereArgs: ['goal-link-project'],
      limit: 1,
    );
    expect(linked.single['goal_id'], 'goal-link-valid');
  });

  test('task rejects missing project and goal references', () async {
    final tasks = TaskRepository(AppDatabase.instance);
    await expectLater(
      tasks.create(title: 'Missing project', projectId: 'not-a-project'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      tasks.create(title: 'Missing goal', goalId: 'not-a-goal'),
      throwsA(isA<StateError>()),
    );
  });

  test('child task must have a parent in the same project', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    for (final id in ['parent-project-a', 'parent-project-b']) {
      await db.insert('projects', {
        'id': id,
        'owner_id': ownerId,
        'title': id,
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
    }
    final parent = await TaskRepository(app).create(
      title: 'Parent in A',
      projectId: 'parent-project-a',
    );

    await expectLater(
      TaskRepository(app).create(
        title: 'Child in B',
        projectId: 'parent-project-b',
        parentTaskId: parent.id,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('milestones receive stable sequential positions', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    await db.insert('projects', {
      'id': 'ordered-milestones-project',
      'owner_id': ownerId,
      'title': 'Ordered milestones',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    await MilestoneRepository(app).create(
      projectId: 'ordered-milestones-project',
      title: 'First',
    );
    await MilestoneRepository(app).create(
      projectId: 'ordered-milestones-project',
      title: 'Second',
    );

    final rows = await db.query(
      'milestones',
      columns: ['title', 'position'],
      where: 'project_id = ?',
      whereArgs: ['ordered-milestones-project'],
      orderBy: 'position ASC',
    );
    expect(rows.map((r) => r['title']).toList(), ['First', 'Second']);
    expect(rows.map((r) => r['position']).toList(), [0, 1]);
  });


  test('project notes and resources persist as visible workspace links', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    const projectId = 'project-linked-records';
    final now = AppDatabase.nowMs();
    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'title': 'Linked records project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    final workspaceService = ProjectWorkspaceService(app);
    await workspaceService.attachNote(
      projectId: projectId,
      content: 'Decision log for the project',
    );
    await workspaceService.attachResource(
      projectId: projectId,
      title: 'Project brief',
      notes: 'Reference notes survive reload',
    );

    final workspace = await workspaceService.load(projectId);
    expect(workspace.notes, hasLength(1));
    expect(workspace.notes.single['content'], 'Decision log for the project');
    expect(workspace.resources, hasLength(1));
    expect(workspace.resources.single['title'], 'Project brief');
    expect(workspace.resources.single['notes'], 'Reference notes survive reload');
  });

  test('cannot attach project notes to another owner or missing project', () async {
    final service = ProjectWorkspaceService(AppDatabase.instance);
    await expectLater(
      service.attachNote(projectId: 'missing-project', content: 'Must not persist'),
      throwsA(isA<StateError>()),
    );
    final db = await AppDatabase.instance.database;
    expect(await db.query('notes'), isEmpty);
    expect(await db.query('entity_links'), isEmpty);
  });

  test('task repository scopes reads and lifecycle mutations to current owner', () async {
    final app = AppDatabase.instance;
    final tasks = TaskRepository(app);
    final task = await tasks.create(title: 'Protected task');
    final db = await app.database;
    final otherOwnerId = AppDatabase.newId();
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'tasks',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: [task.id],
    );

    expect(await tasks.getById(task.id), isNull);
    expect(await tasks.descriptionOf(task.id), isNull);
    expect(await tasks.listOpen().then((items) => items.map((item) => item.id)), isNot(contains(task.id)));
    await expectLater(
      tasks.update(id: task.id, title: 'Unauthorized edit'),
      throwsA(isA<StateError>()),
    );
    await expectLater(tasks.reopen(task.id), throwsA(isA<StateError>()));
    await expectLater(tasks.delete(task.id), throwsA(isA<StateError>()));
    await expectLater(tasks.clearSchedule(task.id), throwsA(isA<StateError>()));
    await expectLater(
      PlanningRepository(app).scheduleTaskSession(
        taskId: task.id,
        start: DateTime(2026, 10, 10, 9),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await tasks.complete(task.id), isNull);

    final stored = await db.query(
      'tasks',
      columns: ['title', 'status', 'scheduled_start', 'archived_at'],
      where: 'id = ?',
      whereArgs: [task.id],
      limit: 1,
    );
    expect(stored.single['title'], 'Protected task');
    expect(stored.single['status'], EntityStatus.inbox);
    expect(stored.single['scheduled_start'], isNull);
    expect(stored.single['archived_at'], isNull);
    expect(
      await db.query(
        'time_blocks',
        where: 'task_id = ?',
        whereArgs: [task.id],
      ),
      isEmpty,
    );
  });

  test('task dependency reads do not expose other owners tasks', () async {
    final app = AppDatabase.instance;
    final tasks = TaskRepository(app);
    final source = await tasks.create(title: 'Source task');
    final target = await tasks.create(title: 'Target task');
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final otherOwnerId = AppDatabase.newId();
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'tasks',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: [target.id],
    );
    await db.insert('task_dependencies', {
      'id': AppDatabase.newId(),
      'task_id': source.id,
      'depends_on_task_id': target.id,
      'created_at': now,
    });

    expect(await tasks.dependencies(source.id), isEmpty);
    expect(await tasks.listBlockedTaskIds(), isNot(contains(source.id)));
    final dependencyQueries = TaskDependencyQueries(app);
    expect(await dependencyQueries.listBlockerTitles(source.id), isEmpty);
    expect(
      (await dependencyQueries.listBlockedWithReasons()).containsKey(source.id),
      isFalse,
    );
    expect(await dependencyQueries.countDependentsWaiting(target.id), 0);
    expect(ownerId, isNot(otherOwnerId));
  });

  test('planning availability ignores calendar, block, and task rows from other owners', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final task = await TaskRepository(app).create(title: 'Foreign scheduled task');
    final ownerId = await app.requireOwnerId();
    final otherOwnerId = AppDatabase.newId();
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'tasks',
      {
        'owner_id': otherOwnerId,
        'scheduled_start': DateTime(2026, 10, 10, 9).millisecondsSinceEpoch,
        'scheduled_end': DateTime(2026, 10, 10, 10).millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );
    await db.insert('calendar_events', {
      'id': AppDatabase.newId(),
      'owner_id': otherOwnerId,
      'title': 'Private event',
      'start_at': DateTime(2026, 10, 10, 10).millisecondsSinceEpoch,
      'end_at': DateTime(2026, 10, 10, 11).millisecondsSinceEpoch,
      'status': 'CONFIRMED',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('time_blocks', {
      'id': AppDatabase.newId(),
      'owner_id': otherOwnerId,
      'title': 'Private block',
      'type': 'FOCUS',
      'start_at': DateTime(2026, 10, 10, 11).millisecondsSinceEpoch,
      'end_at': DateTime(2026, 10, 10, 12).millisecondsSinceEpoch,
      'status': 'PLANNED',
      'created_at': now,
      'updated_at': now,
    });

    final planning = PlanningRepository(app);
    expect(
      await planning.collectDayBusy(day: DateTime(2026, 10, 10)),
      isEmpty,
    );
    expect(
      await planning.conflictsWithLocked(
        start: DateTime(2026, 10, 10, 9),
        durationMinutes: 60,
      ),
      isFalse,
    );
    expect(ownerId, isNot(otherOwnerId));
  });

  test('entity links validate both endpoint owners and scope unlink', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    await db.insert('projects', {
      'id': 'owner-link-project',
      'owner_id': ownerId,
      'title': 'Owner link project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('notes', {
      'id': 'owner-link-note',
      'owner_id': ownerId,
      'title': 'Owner link note',
      'content': 'Initially owned by current user',
      'created_at': now,
      'updated_at': now,
    });
    final links = LinkRepository(app);
    await links.link(
      sourceType: 'PROJECT',
      sourceId: 'owner-link-project',
      targetType: 'NOTE',
      targetId: 'owner-link-note',
    );

    final otherOwnerId = AppDatabase.newId();
    await db.insert('users', {
      'id': otherOwnerId,
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.update(
      'notes',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: ['owner-link-note'],
    );
    await expectLater(
      links.link(
        sourceType: 'PROJECT',
        sourceId: 'owner-link-project',
        targetType: 'NOTE',
        targetId: 'owner-link-note',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await links.linksFor('PROJECT', 'owner-link-project'), isEmpty);

    final existing = await db.query(
      'entity_links',
      columns: ['id'],
      where: 'from_id = ?',
      whereArgs: ['owner-link-project'],
      limit: 1,
    );
    expect(existing, hasLength(1));
    await db.update(
      'entity_links',
      {'owner_id': otherOwnerId},
      where: 'id = ?',
      whereArgs: [existing.single['id']],
    );
    await links.unlink(existing.single['id'] as String);
    final stillExists = await db.query(
      'entity_links',
      where: 'id = ?',
      whereArgs: [existing.single['id']],
    );
    expect(stillExists, hasLength(1));
  });

  test('generic entity links persist against the canonical schema', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    await db.insert('projects', {
      'id': 'generic-link-project',
      'owner_id': ownerId,
      'title': 'Generic link project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('notes', {
      'id': 'generic-link-note',
      'owner_id': ownerId,
      'title': 'Decision',
      'content': 'A related note',
      'created_at': now,
      'updated_at': now,
    });

    final links = LinkRepository(app);
    await links.link(
      sourceType: 'PROJECT',
      sourceId: 'generic-link-project',
      targetType: 'NOTE',
      targetId: 'generic-link-note',
    );

    final rows = await db.query('entity_links');
    expect(rows, hasLength(1));
    expect(rows.single['from_type'], 'PROJECT');
    expect(rows.single['to_type'], 'NOTE');
    expect(await links.relatedWithTitles('PROJECT', 'generic-link-project'), [
      {
        'type': 'NOTE',
        'id': 'generic-link-note',
        'title': 'Decision',
        'relation': 'RELATED',
      },
    ]);
  });

  testWidgets('project workspace stays mounted while milestone mutations reload data',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = await ProjectRepository(AppDatabase.instance).create(
      title: 'Workspace refresh regression',
    );
    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailScreen(projectId: project.id)),
    );
    for (var i = 0; i < 40 &&
        find.text('Workspace refresh regression').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Workspace refresh regression'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.ensureVisible(find.text('Milestones'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).last, 'First milestone');
    await tester.tap(find.text('Save'));
    await tester.pump();

    var sawBlockingLoader = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        sawBlockingLoader = true;
      }
      if (find.text('First milestone').evaluate().isNotEmpty) break;
    }

    expect(find.text('First milestone'), findsOneWidget);
    expect(find.text('Workspace refresh regression'), findsOneWidget);
    expect(
      sawBlockingLoader,
      isFalse,
      reason: 'Refreshing data should not replace a loaded workspace with a full-screen loader.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
