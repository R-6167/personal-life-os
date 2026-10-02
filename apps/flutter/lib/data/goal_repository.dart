import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class GoalRepository {
  GoalRepository(this._db);
  final AppDatabase _db;

  Future<List<Goal>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'goals',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'priority DESC, created_at DESC',
    );
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  Future<Goal> create({required String title, String? description, int? targetDate}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final goal = Goal(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = goal.toInsertMap();
      if (description != null && description.isNotEmpty) map['description'] = description;
      if (targetDate != null) map['target_date'] = targetDate;
      await txn.insert('goals', map);
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'GOAL_CREATED',
        'entity_type': 'GOAL',
        'entity_id': goal.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return goal;
  }

  Future<Map<String, int>> progress(String goalId) async {
    final db = await _db.database;
    final projects = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects WHERE goal_id = ? AND archived_at IS NULL',
      [goalId],
    );
    final projectsDone = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects WHERE goal_id = ? AND status = ?',
      [goalId, EntityStatus.completed],
    );
    final tasks = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE goal_id = ? AND status != ?",
      [goalId, EntityStatus.cancelled],
    );
    final tasksDone = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks WHERE goal_id = ? AND status = ?',
      [goalId, EntityStatus.completed],
    );
    return {
      'projectsTotal': (projects.first['c'] as int?) ?? 0,
      'projectsDone': (projectsDone.first['c'] as int?) ?? 0,
      'tasksTotal': (tasks.first['c'] as int?) ?? 0,
      'tasksDone': (tasksDone.first['c'] as int?) ?? 0,
    };
  }

  Future<void> complete(String id) async {
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'goals',
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
        'event_type': 'GOAL_COMPLETED',
        'entity_type': 'GOAL',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
