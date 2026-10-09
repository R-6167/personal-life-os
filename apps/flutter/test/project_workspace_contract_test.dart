import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/services/project_workspace.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
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
}
