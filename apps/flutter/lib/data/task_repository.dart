import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/domain_recurrence.dart';
import '../services/recurrence_engine.dart';
import 'database.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Future<List<Task>> listOpen() async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC, updated_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listOverdue() async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'due_at IS NOT NULL AND due_at < ? AND status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [now, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'due_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listDueToday() async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where:
          'due_at IS NOT NULL AND due_at >= ? AND due_at <= ? AND status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [start, end, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listScheduledOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where:
          'scheduled_start IS NOT NULL AND scheduled_start <= ? AND '
          '(scheduled_end IS NULL OR scheduled_end > ?) AND '
          'status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [end, start, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'scheduled_start ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Set<String>> listBlockedTaskIds() async {
    final db = await _db.database;
    try {
      final rows = await db.rawQuery(
        'SELECT DISTINCT d.task_id AS id '
        'FROM task_dependencies d '
        'INNER JOIN tasks dep ON dep.id = d.depends_on_task_id '
        'WHERE dep.status NOT IN (?, ?) AND dep.archived_at IS NULL',
        [EntityStatus.completed, EntityStatus.cancelled],
      );
      return rows.map((r) => r['id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<bool> isBlocked(String taskId) async {
    final blocked = await listBlockedTaskIds();
    return blocked.contains(taskId);
  }

  Future<List<Task>> listByProject(String projectId) async {
    final rows = await (await _db.database).query(
      'tasks',
      where: 'project_id = ? AND archived_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'status ASC, priority DESC, updated_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listByGoal(String goalId) async {
    final rows = await (await _db.database).query(
      'tasks',
      where: 'goal_id = ? AND archived_at IS NULL',
      whereArgs: [goalId],
      orderBy: 'status ASC, priority DESC, updated_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getById(String id) async {
    final rows = await (await _db.database).query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<String?> descriptionOf(String taskId) async {
    final rows = await (await _db.database).query(
      'tasks',
      columns: ['description'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final d = rows.first['description'];
    return d is String ? d : null;
  }

  Future<void> reschedule(String taskId, DateTime day) async {
    final due = DateTime(day.year, day.month, day.day, 23, 59).millisecondsSinceEpoch;
    await update(id: taskId, dueAt: due);
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
    String? status,
    int? dueAt,
    bool clearDue = false,
    int? priority,
    String? description,
    String? projectId,
    String? goalId,
    int? scheduledStart,
    int? scheduledEnd,
    int? estimatedMinutes,
  }) async {
    final now = AppDatabase.nowMs();
    final patch = <String, Object?>{'updated_at': now};
    if (title != null) patch['title'] = title;
    if (status != null) patch['status'] = status;
    if (clearDue) {
      patch['due_at'] = null;
    } else if (dueAt != null) {
      patch['due_at'] = dueAt;
    }
    if (priority != null) patch['priority'] = priority;
    if (description != null) patch['description'] = description;
    if (projectId != null) patch['project_id'] = projectId.isEmpty ? null : projectId;
    if (goalId != null) patch['goal_id'] = goalId;
    if (scheduledStart != null) patch['scheduled_start'] = scheduledStart;
    if (scheduledEnd != null) patch['scheduled_end'] = scheduledEnd;
    if (estimatedMinutes != null) patch['estimated_minutes'] = estimatedMinutes;
    await (await _db.database).update('tasks', patch, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> dependencies(String taskId) async {
    final db = await _db.database;
    try {
      return await db.rawQuery(
        'SELECT d.id, d.depends_on_task_id, t.title AS depends_on_title '
        'FROM task_dependencies d '
        'LEFT JOIN tasks t ON t.id = d.depends_on_task_id '
        'WHERE d.task_id = ?',
        [taskId],
      );
    } catch (_) {
      return [];
    }
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
    DateTime? until,
    int? count,
    DateTime? dtStart,
  }) async {
    final rule = RecurrenceRule.fromLegacy(
      frequency: frequency,
      interval: intervalN,
      dtStart: dtStart ?? DateTime.now(),
      until: until,
      count: count,
      daysOfWeekCsv: daysOfWeek,
    );
    await setRecurrenceRule(taskId: taskId, rule: rule);
  }

  Map<String, Object?> _recurrencePayload(RecurrenceRule rule, int now) {
    final daysCsv = rule.byWeekDays.isEmpty ? null : rule.byWeekDays.join(',');
    return {
      'frequency': rule.frequency.wire,
      'interval': rule.safeInterval,
      'interval_n': rule.safeInterval,
      'days_of_week': daysCsv,
      'start_date': rule.dtStart.millisecondsSinceEpoch,
      'end_at': rule.until?.millisecondsSinceEpoch,
      'until_at': rule.until?.millisecondsSinceEpoch,
      'count': rule.count,
      'by_month_days': rule.byMonthDays.isEmpty ? null : rule.byMonthDays.join(','),
      'enabled': 1,
      'updated_at': now,
    };
  }

  Future<void> setRecurrenceRule({
    required String taskId,
    required RecurrenceRule rule,
  }) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final payload = _recurrencePayload(rule, now);
    final existing =
        await db.query('task_recurrences', where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (existing.isNotEmpty) {
      await db.update('task_recurrences', payload, where: 'task_id = ?', whereArgs: [taskId]);
    } else {
      await db.insert('task_recurrences', {
        'id': AppDatabase.newId(),
        'task_id': taskId,
        'created_at': now,
        ...payload,
      });
    }
  }

  Future<Map<String, Object?>?> getRecurrence(String taskId) async {
    final rows = await (await _db.database).query(
      'task_recurrences',
      where: 'task_id = ? AND (enabled IS NULL OR enabled = 1)',
      whereArgs: [taskId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<RecurrenceRule?> getRecurrenceRule(String taskId) async {
    final row = await getRecurrence(taskId);
    if (row == null) return null;
    return DomainRecurrence.ruleFromScheduleMap(row);
  }

  /// Creates the next occurrence inside an existing [txn] (no nested transaction).
  Future<Task?> _spawnNextInTxn(
    dynamic txn, {
    required String completedTaskId,
    required Task src,
    required RecurrenceRule rule,
    required String ownerId,
    required int now,
    String? description,
  }) async {
    final base = src.dueAt != null
        ? DateTime.fromMillisecondsSinceEpoch(src.dueAt!)
        : DateTime.fromMillisecondsSinceEpoch(now);
    final next = rule.generator().nextAfter(base);
    if (next == null) return null;

    final created = Task(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      projectId: src.projectId,
      goalId: src.goalId,
      title: src.title,
      status: EntityStatus.planned,
      priority: src.priority,
      dueAt: DateTime(next.year, next.month, next.day, 23, 59).millisecondsSinceEpoch,
      createdAt: now,
      updatedAt: now,
    );
    final map = created.toInsertMap();
    if (description != null && description.isNotEmpty) {
      map['description'] = description;
    }
    map['parent_task_id'] = completedTaskId;
    await txn.insert('tasks', map);

    final payload = _recurrencePayload(rule, now);
    await txn.insert('task_recurrences', {
      'id': AppDatabase.newId(),
      'task_id': created.id,
      'created_at': now,
      ...payload,
    });

    await txn.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'TASK_OCCURRENCE_SPAWNED',
      'entity_type': 'TASK',
      'entity_id': created.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.system,
      'metadata':
          '{"parentTaskId":"$completedTaskId","dueAt":${created.dueAt}}',
    });
    return created;
  }

  /// Standalone spawn (e.g. repair). Prefer [complete] for the lifecycle path.
  Future<Task?> spawnNextOccurrence(String completedTaskId) async {
    final rule = await getRecurrenceRule(completedTaskId);
    if (rule == null) return null;
    final src = await getById(completedTaskId);
    if (src == null) return null;
    final desc = await descriptionOf(completedTaskId);
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    return _db.txn((txn) async {
      return _spawnNextInTxn(
        txn,
        completedTaskId: completedTaskId,
        src: src,
        rule: rule,
        ownerId: ownerId,
        now: now,
        description: desc,
      );
    });
  }

  Future<void> clearRecurrence(String taskId) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    await db.update(
      'task_recurrences',
      {'enabled': 0, 'updated_at': now},
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  /// Atomic lifecycle: complete + activity + (optional) next occurrence in one txn.
  /// Returns the spawned next task when recurrence applies and a next date exists.
  Future<Task?> complete(String taskId) async {
    final rule = await getRecurrenceRule(taskId);
    final src = await getById(taskId);
    if (src == null) return null;
    final desc = await descriptionOf(taskId);
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();

    return _db.txn((txn) async {
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
        'metadata': rule == null ? null : '{"recurring":true}',
      });

      if (rule == null) return null;
      return _spawnNextInTxn(
        txn,
        completedTaskId: taskId,
        src: src,
        rule: rule,
        ownerId: ownerId,
        now: now,
        description: desc,
      );
    });
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
        'event_type': 'TASK_CANCELLED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
