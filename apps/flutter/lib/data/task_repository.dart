import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/recurrence_engine.dart';
import 'database.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Future<List<Task>> listOpen() async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: "status != ? AND status != ? AND (archived_at IS NULL)",
      whereArgs: [EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listOverdue() async {
    final open = await listOpen();
    return open.where((t) => t.isOverdue).toList();
  }

  Future<List<Task>> listDueToday() async {
    final open = await listOpen();
    return open.where((t) => t.isDueToday || t.isOverdue).toList();
  }

  Future<List<Task>> listByProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'project_id = ? AND archived_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'status ASC, priority DESC, due_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listByGoal(String goalId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'goal_id = ? AND archived_at IS NULL',
      whereArgs: [goalId],
      orderBy: 'status ASC, priority DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listScheduledOnDay(DateTime day) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    final rows = await db.query(
      'tasks',
      where: 'archived_at IS NULL AND scheduled_start IS NOT NULL AND scheduled_start >= ? AND scheduled_start <= ?',
      whereArgs: [start, end],
      orderBy: 'scheduled_start ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<String?> descriptionOf(String id) async {
    final db = await _db.database;
    final rows = await db.query('tasks', columns: ['description'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['description'] as String?;
  }

  Future<Task> create({
    required String title,
    String status = EntityStatus.inbox,
    int? dueAt,
    int priority = 0,
    String? description,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? parentTaskId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final task = Task(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      projectId: projectId,
      goalId: goalId,
      title: title,
      status: status,
      priority: priority,
      dueAt: dueAt,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = task.toInsertMap();
      if (description != null && description.isNotEmpty) map['description'] = description;
      if (milestoneId != null) map['milestone_id'] = milestoneId;
      if (parentTaskId != null) map['parent_task_id'] = parentTaskId;
      await txn.insert('tasks', map);
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_CREATED',
        'entity_type': 'TASK',
        'entity_id': task.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return task;
  }

  Future<void> update({
    required String id,
    String? title,
    String? description,
    int? priority,
    int? dueAt,
    bool clearDue = false,
    String? projectId,
    String? goalId,
    String? status,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final patch = <String, Object?>{'updated_at': now};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description.isEmpty ? null : description;
    if (priority != null) patch['priority'] = priority;
    if (clearDue) {
      patch['due_at'] = null;
    } else if (dueAt != null) {
      patch['due_at'] = dueAt;
    }
    if (projectId != null) patch['project_id'] = projectId.isEmpty ? null : projectId;
    if (goalId != null) patch['goal_id'] = goalId.isEmpty ? null : goalId;
    if (status != null) patch['status'] = status;

    await _db.txn((txn) async {
      await txn.update('tasks', patch, where: 'id = ?', whereArgs: [id]);
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_UPDATED',
        'entity_type': 'TASK',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> reschedule(String id, DateTime day) async {
    final due = DateTime(day.year, day.month, day.day, 23, 59).millisecondsSinceEpoch;
    await update(id: id, dueAt: due, status: EntityStatus.planned);
  }

  Future<void> scheduleSession({
    required String taskId,
    required DateTime start,
    int durationMinutes = 30,
    int? estimatedMinutes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: durationMinutes)).millisecondsSinceEpoch;
    await _db.txn((txn) async {
      await txn.update(
        'tasks',
        {
          'scheduled_start': startMs,
          'scheduled_end': endMs,
          if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
          'status': EntityStatus.inProgress,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_SCHEDULED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"start":$startMs,"end":$endMs,"minutes":$durationMinutes}',
      });
    });
  }

  Future<void> clearSchedule(String taskId) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'tasks',
      {'scheduled_start': null, 'scheduled_end': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> setRecurrence({
    required String taskId,
    required String frequency,
    int intervalN = 1,
    String? daysOfWeek,
  }) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final existing = await db.query('task_recurrences', where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (existing.isNotEmpty) {
      await db.update(
        'task_recurrences',
        {
          'frequency': frequency,
          'interval_n': intervalN,
          'days_of_week': daysOfWeek,
          'enabled': 1,
          'updated_at': now,
        },
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
    } else {
      await db.insert('task_recurrences', {
        'id': AppDatabase.newId(),
        'task_id': taskId,
        'frequency': frequency,
        'interval_n': intervalN,
        'days_of_week': daysOfWeek,
        'start_date': now,
        'enabled': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<Map<String, Object?>?> getRecurrence(String taskId) async {
    final rows = await (await _db.database).query(
      'task_recurrences',
      where: 'task_id = ? AND enabled = 1',
      whereArgs: [taskId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Task?> spawnNextOccurrence(String completedTaskId) async {
    final ruleRow = await getRecurrence(completedTaskId);
    if (ruleRow == null) return null;
    final src = await getById(completedTaskId);
    if (src == null) return null;

    final freq = '${ruleRow['frequency'] ?? 'DAILY'}';
    final n = (ruleRow['interval_n'] as int?) ?? 1;
    final daysCsv = ruleRow['days_of_week'] as String?;
    final untilMs = ruleRow['until_at'] as int? ?? ruleRow['end_at'] as int?;
    final base = src.dueAt != null
        ? DateTime.fromMillisecondsSinceEpoch(src.dueAt!)
        : DateTime.now();
    final dtStart = ruleRow['start_date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(ruleRow['start_date'] as int)
        : base;

    final rule = RecurrenceRule.fromLegacy(
      frequency: freq,
      interval: n,
      dtStart: dtStart,
      until: untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs),
      daysOfWeekCsv: daysCsv,
      monthDay: base.day,
    );
    final next = rule.generator().nextAfter(base);
    if (next == null) return null;

    return create(
      title: src.title,
      status: EntityStatus.planned,
      dueAt: DateTime(next.year, next.month, next.day, 23, 59).millisecondsSinceEpoch,
      priority: src.priority,
      projectId: src.projectId,
      goalId: src.goalId,
    );
  }

  Future<void> complete(String taskId) async {
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'tasks',
        {
          'status': EntityStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_COMPLETED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    await spawnNextOccurrence(taskId);
  }

  Future<void> reopen(String taskId) async {
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'tasks',
        {
          'status': EntityStatus.inbox,
          'completed_at': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_REOPENED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> delete(String taskId) async {
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'tasks',
        {
          'status': EntityStatus.cancelled,
          'archived_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_DELETED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> addDependency({required String taskId, required String dependsOnTaskId}) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('task_dependencies', {
      'id': AppDatabase.newId(),
      'task_id': taskId,
      'depends_on_task_id': dependsOnTaskId,
      'type': 'BLOCKED_BY',
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> dependencies(String taskId) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT d.*, t.title AS depends_on_title
      FROM task_dependencies d
      JOIN tasks t ON t.id = d.depends_on_task_id
      WHERE d.task_id = ?
    ''', [taskId]);
  }
}
