import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
import '../services/progress_calculator.dart';
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
      orderBy: 'created_at DESC',
    );
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  Future<Map<String, Object?>?> rawById(String id) async {
    final rows =
        await (await _db.database).query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Goal> create({
required String title, String? description, int? targetDate, int priority = 0, String? lifeAreaId}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final goal = Goal(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title.trim(),
      status: EntityStatus.active,
      priority: priority,
      lifeAreaId: lifeAreaId,
      createdAt: now,
      updatedAt: now,
    );
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final map = goal.toInsertMap();
        if (description != null && description.isNotEmpty) map['description'] = description;
        if (targetDate != null) map['target_date'] = targetDate;
        await txn.insert('goals', map);
      },
      eventType: 'GOAL_CREATED',
      entityType: 'GOAL',
      entityId: goal.id,
      occurredAt: now,
    );
    return goal;
  }

  Future<void> updateMeta({
    required String id,
    int? targetDate,
    bool clearTarget = false,
    String? description,
  }) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'goals',
      {
        if (clearTarget) 'target_date': null,
        if (targetDate != null) 'target_date': targetDate,
        if (description != null) 'description': description,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> progress(String goalId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final projects = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects '
      'WHERE owner_id = ? AND goal_id = ? AND archived_at IS NULL',
      [ownerId, goalId],
    );
    final projectsDone = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects '
      'WHERE owner_id = ? AND goal_id = ? AND archived_at IS NULL AND status = ?',
      [ownerId, goalId, EntityStatus.completed],
    );
    const eligibleTaskUnion = '''
      SELECT t.id, t.status FROM tasks t
      WHERE t.owner_id = ? AND t.goal_id = ? AND t.archived_at IS NULL
        AND COALESCE(t.status, '') != ?
        AND NOT EXISTS (
          SELECT 1 FROM projects p WHERE p.id = t.project_id
            AND p.owner_id = t.owner_id AND p.archived_at IS NOT NULL
        )
      UNION
      SELECT t.id, t.status FROM tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE p.owner_id = ? AND p.goal_id = ? AND p.archived_at IS NULL
        AND t.owner_id = ? AND t.archived_at IS NULL
        AND COALESCE(t.status, '') != ?
    ''';
    final tasks = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ($eligibleTaskUnion)',
      [ownerId, goalId, EntityStatus.cancelled, ownerId, goalId, ownerId, EntityStatus.cancelled],
    );
    final tasksDone = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM ($eligibleTaskUnion) WHERE status = ?",
      [ownerId, goalId, EntityStatus.cancelled, ownerId, goalId, ownerId, EntityStatus.cancelled, EntityStatus.completed],
    );
    final habits = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM habits WHERE owner_id = ? AND goal_id = ? "
      "AND archived_at IS NULL AND (status = ? OR status IS NULL)",
      [ownerId, goalId, EntityStatus.active],
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final habitsDoneToday = await db.rawQuery(
      'SELECT COUNT(DISTINCT o.habit_id) AS c FROM habit_occurrences o '
      'JOIN habits h ON h.id = o.habit_id '
      "WHERE h.owner_id = ? AND h.goal_id = ? AND h.archived_at IS NULL "
      'AND (h.status = ? OR h.status IS NULL) AND o.scheduled_date = ? AND o.status = ?',
      [ownerId, goalId, EntityStatus.active, today, HabitOccurrenceStatus.completed],
    );
    return {
      'projectsTotal': (projects.first['c'] as int?) ?? 0,
      'projectsDone': (projectsDone.first['c'] as int?) ?? 0,
      'tasksTotal': (tasks.first['c'] as int?) ?? 0,
      'tasksDone': (tasksDone.first['c'] as int?) ?? 0,
      'habitsTotal': (habits.first['c'] as int?) ?? 0,
      'habitsDoneToday': (habitsDoneToday.first['c'] as int?) ?? 0,
    };
  }

  Future<double> progressRatio(String goalId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final projectRows = await db.query(
      'projects',
      columns: ['id'],
      where: 'owner_id = ? AND goal_id = ? AND archived_at IS NULL',
      whereArgs: [ownerId, goalId],
      orderBy: 'created_at ASC',
    );
    final projectRatios = <double>[];
    for (final project in projectRows) {
      final projectId = project['id'] as String;
      final taskCounts = await db.rawQuery(
        "SELECT COUNT(*) AS total, "
        "COALESCE(SUM(CASE WHEN status = ? THEN 1 ELSE 0 END), 0) AS done "
        "FROM tasks WHERE owner_id = ? AND project_id = ? AND archived_at IS NULL "
        "AND COALESCE(status, '') != ?",
        [EntityStatus.completed, ownerId, projectId, EntityStatus.cancelled],
      );
      final milestoneCounts = await db.rawQuery(
        "SELECT COUNT(*) AS total, "
        "COALESCE(SUM(CASE WHEN status = ? THEN 1 ELSE 0 END), 0) AS done "
        'FROM milestones WHERE owner_id = ? AND project_id = ?',
        [EntityStatus.completed, ownerId, projectId],
      );
      projectRatios.add(ProgressCalculator.projectRatio(
        tasksDone: (taskCounts.first['done'] as int?) ?? 0,
        tasksTotal: (taskCounts.first['total'] as int?) ?? 0,
        milestonesDone: (milestoneCounts.first['done'] as int?) ?? 0,
        milestonesTotal: (milestoneCounts.first['total'] as int?) ?? 0,
      ));
    }

    final directTasks = await db.rawQuery(
      "SELECT COUNT(*) AS total, "
      "COALESCE(SUM(CASE WHEN t.status = ? THEN 1 ELSE 0 END), 0) AS done "
      "FROM tasks t WHERE t.owner_id = ? AND t.goal_id = ? "
      "AND t.archived_at IS NULL AND COALESCE(t.status, '') != ? "
      "AND (t.project_id IS NULL OR t.project_id NOT IN ("
      "SELECT p.id FROM projects p WHERE p.owner_id = ? AND p.goal_id = ?)) "
      "AND NOT EXISTS (SELECT 1 FROM projects p WHERE p.id = t.project_id "
      "AND p.owner_id = t.owner_id AND p.archived_at IS NOT NULL)",
      [EntityStatus.completed, ownerId, goalId, EntityStatus.cancelled, ownerId, goalId],
    );
    return ProgressCalculator.goalRatio(
      projectRatios: projectRatios,
      directTasksDone: (directTasks.first['done'] as int?) ?? 0,
      directTasksTotal: (directTasks.first['total'] as int?) ?? 0,
    );
  }

  Future<List<Map<String, Object?>>> listLinkedHabits(String goalId) async {
    return (await _db.database).query(
      'habits',
      where: 'goal_id = ? AND archived_at IS NULL',
      whereArgs: [goalId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> linkHabit(String habitId, String goalId) async {
    await (await _db.database).update(
      'habits',
      {'goal_id': goalId, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> unlinkHabit(String habitId) async {
    await (await _db.database).update(
      'habits',
      {'goal_id': null, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> addReflection(String goalId, String content) async {
    await (await _db.database).insert('goal_reflections', {
      'id': AppDatabase.newId(),
      'goal_id': goalId,
      'content': content,
      'created_at': AppDatabase.nowMs(),
    });
  }

  Future<List<Map<String, Object?>>> listReflections(String goalId, {int limit = 20}) async {
    return (await _db.database).query(
      'goal_reflections',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> complete(String id) async {
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.update(
          'goals',
          {
            'status': EntityStatus.completed,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      eventType: 'GOAL_COMPLETED',
      entityType: 'GOAL',
      entityId: id,
      occurredAt: now,
    );
  }
}
