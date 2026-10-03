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

  Future<Map<String, Object?>?> rawById(String id) async {
    final rows = await (await _db.database).query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Goal> create({required String title, String? description, int? targetDate, int priority = 0}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final goal = Goal(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: EntityStatus.active,
      priority: priority,
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

  Future<void> updateMeta({
    required String id,
    int? priority,
    int? targetDate,
    bool clearTarget = false,
    String? progressMode,
    double? manualProgress,
    String? description,
  }) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'goals',
      {
        if (priority != null) 'priority': priority,
        if (clearTarget) 'target_date': null,
        if (targetDate != null) 'target_date': targetDate,
        if (progressMode != null) 'progress_mode': progressMode,
        if (manualProgress != null) 'manual_progress': manualProgress,
        if (description != null) 'description': description,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final habits = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM habits WHERE goal_id = ? AND archived_at IS NULL',
      [goalId],
    );
    final day = AppDatabase.startOfTodayMs();
    final habitsDoneToday = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM habits h
      JOIN habit_occurrences o ON o.habit_id = h.id
      WHERE h.goal_id = ? AND o.scheduled_date = ? AND o.status = ?
      ''',
      [goalId, day, HabitOccurrenceStatus.completed],
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
    final raw = await rawById(goalId);
    if (raw == null) return 0;
    final mode = (raw['progress_mode'] as String?) ?? ProgressMode.calculated;
    if (mode == ProgressMode.manual) {
      final m = raw['manual_progress'] as num?;
      return ((m ?? 0).toDouble()).clamp(0.0, 1.0);
    }
    final p = await progress(goalId);
    final pt = p['projectsTotal'] ?? 0;
    final pd = p['projectsDone'] ?? 0;
    final tt = p['tasksTotal'] ?? 0;
    final td = p['tasksDone'] ?? 0;
    final ht = p['habitsTotal'] ?? 0;
    final hd = p['habitsDoneToday'] ?? 0;
    if (tt + pt + ht == 0) return 0;
    final score = (tt == 0 ? 0.0 : td / tt) * 0.5 +
        (pt == 0 ? 0.0 : pd / pt) * 0.3 +
        (ht == 0 ? 0.0 : hd / ht) * 0.2;
    return score.clamp(0.0, 1.0);
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
