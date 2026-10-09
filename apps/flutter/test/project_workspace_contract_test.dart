import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/milestone_repository.dart';
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
}
