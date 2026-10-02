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
      title: title,
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = project.toInsertMap();
      if (description != null && description.isNotEmpty) map['description'] = description;
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
      "SELECT COUNT(*) AS c FROM tasks WHERE project_id = ? AND status != ?",
      [projectId, EntityStatus.cancelled],
    );
    final done = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE project_id = ? AND status = ?',
      [projectId, EntityStatus.completed],
    );
    final milestones = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM milestones WHERE project_id = ?',
      [projectId],
    );
    final milestonesDone = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM milestones WHERE project_id = ? AND status = ?',
      [projectId, MilestoneStatus.completed],
    );
    return {
      'tasksTotal': (total.first['c'] as int?) ?? 0,
      'tasksDone': (done.first['c'] as int?) ?? 0,
      'milestonesTotal': (milestones.first['c'] as int?) ?? 0,
      'milestonesDone': (milestonesDone.first['c'] as int?) ?? 0,
    };
  }

  Future<void> complete(String id) async {
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'projects',
        {
          'status': EntityStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'PROJECT_COMPLETED',
        'entity_type': 'PROJECT',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
