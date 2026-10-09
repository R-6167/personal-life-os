import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase app;
  late String ownerId;
  late int now;

  setUp(() async {
    app = await openTestDb();
    ownerId = await app.requireOwnerId();
    now = AppDatabase.nowMs();
  });

  tearDown(() async {
    await closeTestDb();
  });

  Future<void> insertGoal(String id) async {
    final db = await app.database;
    await db.insert('goals', {
      'id': id,
      'owner_id': ownerId,
      'title': id,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertProject(String id, {String? goalId}) async {
    final db = await app.database;
    await db.insert('projects', {
      'id': id,
      'owner_id': ownerId,
      'goal_id': goalId,
      'title': id,
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
  }

  test('project goal link rejects missing goals and allows unlinking', () async {
    await insertProject('project-a');
    final projects = ProjectRepository(app);

    await expectLater(
      projects.linkGoal('project-a', 'missing-goal'),
      throwsStateError,
    );

    await insertGoal('goal-a');
    await projects.linkGoal('project-a', 'goal-a');
    expect((await projects.getById('project-a'))?.goalId, 'goal-a');

    await projects.linkGoal('project-a', null);
    expect((await projects.getById('project-a'))?.goalId, isNull);
  });

  test('project goal link rejects a missing project', () async {
    await insertGoal('goal-a');
    await expectLater(
      ProjectRepository(app).linkGoal('missing-project', 'goal-a'),
      throwsStateError,
    );
  });

  test('task creation inherits its project goal', () async {
    await insertGoal('goal-a');
    await insertProject('project-a', goalId: 'goal-a');

    final task = await TaskRepository(app).create(
      title: 'First action',
      projectId: 'project-a',
    );

    expect(task.projectId, 'project-a');
    expect(task.goalId, 'goal-a');
  });

  test('task creation rejects a goal that conflicts with its project', () async {
    await insertGoal('goal-a');
    await insertGoal('goal-b');
    await insertProject('project-a', goalId: 'goal-a');

    await expectLater(
      TaskRepository(app).create(
        title: 'Mismatched action',
        projectId: 'project-a',
        goalId: 'goal-b',
      ),
      throwsStateError,
    );
  });

  test('task creation rejects unknown project and goal references', () async {
    await insertGoal('goal-a');
    final tasks = TaskRepository(app);

    await expectLater(
      tasks.create(title: 'Orphan project task', projectId: 'missing-project'),
      throwsStateError,
    );
    await expectLater(
      tasks.create(title: 'Orphan goal task', goalId: 'missing-goal'),
      throwsStateError,
    );
  });

  test('subtasks must remain under their parent project and goal', () async {
    await insertGoal('goal-a');
    await insertProject('project-a', goalId: 'goal-a');
    await insertProject('project-b', goalId: 'goal-a');
    final tasks = TaskRepository(app);
    final parent = await tasks.create(title: 'Parent', projectId: 'project-a');

    await expectLater(
      tasks.create(
        title: 'Mismatched subtask',
        projectId: 'project-b',
        parentTaskId: parent.id,
      ),
      throwsStateError,
    );

    final child = await tasks.create(
      title: 'Valid subtask',
      projectId: 'project-a',
      parentTaskId: parent.id,
    );
    expect(child.projectId, parent.projectId);
    expect(child.goalId, parent.goalId);
  });
}
