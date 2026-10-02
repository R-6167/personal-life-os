import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Future<List<Project>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'projects',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'priority DESC, created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project> create({required String title}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final project = Project(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('projects', project.toInsertMap());
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'PROJECT_CREATED',
      'entity_type': 'PROJECT',
      'entity_id': project.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
    return project;
  }

  Future<void> complete(String id) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await db.update(
      'projects',
      {
        'status': EntityStatus.completed,
        'completed_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'PROJECT_COMPLETED',
      'entity_type': 'PROJECT',
      'entity_id': id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
  }
}
