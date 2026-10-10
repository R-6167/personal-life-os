import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('milestone create assigns sequential positions and reorder rewrites order', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final milestones = MilestoneRepository(app);
    final project = await projects.create(title: 'Reorder project');

    final a = await milestones.create(projectId: project.id, title: 'A');
    final b = await milestones.create(projectId: project.id, title: 'B');
    final c = await milestones.create(projectId: project.id, title: 'C');

    var list = await milestones.listForProject(project.id);
    expect(list.map((m) => m.title).toList(), ['A', 'B', 'C']);
    expect(list.map((m) => m.position).toList(), [0, 1, 2]);

    await milestones.reorder(
      projectId: project.id,
      orderedIds: [c.id, a.id, b.id],
    );

    list = await milestones.listForProject(project.id);
    expect(list.map((m) => m.title).toList(), ['C', 'A', 'B']);
    expect(list.map((m) => m.position).toList(), [0, 1, 2]);
  });

  test('milestone reorder rejects incomplete or foreign id lists', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final milestones = MilestoneRepository(app);
    final project = await projects.create(title: 'Strict reorder');
    final a = await milestones.create(projectId: project.id, title: 'Only');

    await expectLater(
      milestones.reorder(projectId: project.id, orderedIds: [a.id, 'missing-id']),
      throwsA(isA<StateError>()),
    );
  });

  test('task dependency add/remove and cycle rejection', () async {
    final app = AppDatabase.instance;
    final tasks = TaskRepository(app);
    final t1 = await tasks.create(title: 'Task one');
    final t2 = await tasks.create(title: 'Task two');
    final t3 = await tasks.create(title: 'Task three');

    await tasks.addDependency(taskId: t1.id, dependsOnTaskId: t2.id);
    var deps = await tasks.dependencies(t1.id);
    expect(deps, hasLength(1));
    expect(deps.first['depends_on_task_id'], t2.id);

    await expectLater(
      tasks.addDependency(taskId: t1.id, dependsOnTaskId: t1.id),
      throwsA(isA<ArgumentError>()),
    );

    await tasks.addDependency(taskId: t2.id, dependsOnTaskId: t3.id);
    await expectLater(
      tasks.addDependency(taskId: t3.id, dependsOnTaskId: t1.id),
      throwsA(isA<StateError>()),
    );

    await tasks.removeDependency(taskId: t1.id, dependsOnTaskId: t2.id);
    deps = await tasks.dependencies(t1.id);
    expect(deps, isEmpty);
  });
}
