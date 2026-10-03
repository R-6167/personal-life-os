import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Future<List<Project>> listActive() async {
    final db = await _db.database;
    // Schema has no priority column — order by recency only.
    final rows = await db.query(
      'projects',
      where: "(status = ? OR status IS NULL OR status = '') AND (archived_at IS NULL)",
      whereArgs: [EntityStatus.active],
      orderBy: 'created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<Project>> listAll() async {
    final db = await _db.database;
    final rows = await db.query(
      'projects',
      where: 'archived_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<Project>> listByGoal(String goalId) async {
    final db = await _db.database;
    final rows = await db.query(
      'projects',
      where: 'goal_id = ? AND archived_at IS NULL',
      whereArgs: [goalId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.first);
  }

  Future<Project> create({required String title, String? description, String? goalId}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final project = Project(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      goalId: goalId,
      title: title.trim(),
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = project.toInsertMap();
      if (description != null && description.trim().isNotEmpty) {
        map['description'] = description.trim();
      }
      await txn.insert('projects', map);
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'PROJECT_CREATED',
        'entity_type': 'PROJECT',
        'entity_id': project.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return project;
  }

  Future<void> linkGoal(String projectId, String? goalId) async {
    final db = await _db.database;
    await db.update(
      'projects',
      {'goal_id': goalId, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<Map<String, int>> progress(String projectId) async {
    final db = await _db.database;
    final total = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE project_id = ? AND status != 'CANCELLED'",
      [projectId],
    );
    final done = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE project_id = ? AND status = 'COMPLETED'",
      [projectId],
    );
    return {
      'total': (total.first['c'] as int?) ?? 0,
      'done': (done.first['c'] as int?) ?? 0,
    };
  }
}
