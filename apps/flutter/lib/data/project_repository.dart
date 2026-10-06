import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
import 'database.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Future<List<Project>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'projects',
      where: "(status = ? OR status IS NULL OR status = '') AND (archived_at IS NULL)",
      whereArgs: [EntityStatus.active],
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
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final map = project.toInsertMap();
        if (description != null && description.trim().isNotEmpty) {
          map['description'] = description.trim();
        }
        await txn.insert('projects', map);
      },
      eventType: 'PROJECT_CREATED',
      entityType: 'PROJECT',
      entityId: project.id,
      occurredAt: now,
    );
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

  Future<void> updateMeta({
    required String id,
    String? title,
    String? description,
    int? targetDate,
    bool clearTarget = false,
  }) async {
    final patch = <String, Object?>{'updated_at': AppDatabase.nowMs()};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description.isEmpty ? null : description;
    if (clearTarget) {
      patch['target_date'] = null;
    } else if (targetDate != null) {
      patch['target_date'] = targetDate;
    }
    await (await _db.database).update('projects', patch, where: 'id = ?', whereArgs: [id]);
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
    final mt = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM milestones WHERE project_id = ?',
      [projectId],
    );
    final md = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM milestones WHERE project_id = ? AND status = 'COMPLETED'",
      [projectId],
    );
    return {
      'total': (total.first['c'] as int?) ?? 0,
      'done': (done.first['c'] as int?) ?? 0,
      'tasksTotal': (total.first['c'] as int?) ?? 0,
      'tasksDone': (done.first['c'] as int?) ?? 0,
      'milestonesTotal': (mt.first['c'] as int?) ?? 0,
      'milestonesDone': (md.first['c'] as int?) ?? 0,
    };
  }

  Future<void> complete(String id) async {
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.update(
          'projects',
          {'status': EntityStatus.completed, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }
}
