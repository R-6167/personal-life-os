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
  test('project notes and resources persist with canonical links', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    const projectId = 'project-related-records';
    final now = AppDatabase.nowMs();

    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'title': 'Related records test',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    final workspace = ProjectWorkspaceService(app);
    await workspace.attachNote(projectId: projectId, content: 'Decision record');
    await workspace.attachResource(projectId: projectId, title: 'Design document');

    final loaded = await workspace.load(projectId);
    expect(loaded.notes, hasLength(1));
    expect(loaded.notes.single['content'], 'Decision record');
    expect(loaded.resources, hasLength(1));
    expect(loaded.resources.single['title'], 'Design document');

    final links = await db.query(
      'entity_links',
      where: "from_type = 'PROJECT' AND from_id = ?",
      whereArgs: [projectId],
    );
    expect(links, hasLength(2));
    expect(links.map((row) => row['relation']).toSet(), {'RELATED'});
  });

  test('project note/resource attachment rejects unknown project without orphan rows', () async {
    final app = AppDatabase.instance;
    final db = await app.database;
    final workspace = ProjectWorkspaceService(app);

    await expectLater(
      workspace.attachNote(projectId: 'missing-project', content: 'Should not persist'),
      throwsStateError,
    );
    await expectLater(
      workspace.attachResource(projectId: 'missing-project', title: 'Should not persist'),
      throwsStateError,
    );

    expect(await db.query('notes'), isEmpty);
    expect(await db.query('documents'), isEmpty);
    expect(await db.query('entity_links'), isEmpty);
  });

}
