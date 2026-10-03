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
      if (description != null) map['description'] = description;
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
    int? priority,
    String? description,
    String? projectId,
    String? goalId,
    int? estimatedMinutes,
    bool clearDue = false,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final patch = <String, Object?>{'updated_at': now};
    if (title != null) patch['title'] = title;
    if (status != null) patch['status'] = status;
    if (priority != null) patch['priority'] = priority;
    if (description != null) patch['description'] = description;
    if (projectId != null) patch['project_id'] = projectId;
    if (goalId != null) patch['goal_id'] = goalId;
    if (estimatedMinutes != null) patch['estimated_minutes'] = estimatedMinutes;
    if (clearDue) {
      patch['due_at'] = null;
    } else if (dueAt != null) {
      patch['due_at'] = dueAt;
    }
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

  Future<void> setRecurrenceRule({
    required String taskId,
    required RecurrenceRule rule,
  }) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final daysCsv = rule.byWeekDays.isEmpty ? null : rule.byWeekDays.join(',');
    final payload = <String, Object?>{
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
    final interval = (row['interval'] as int?) ?? (row['interval_n'] as int?) ?? 1;
    final untilMs = row['until_at'] as int? ?? row['end_at'] as int?;
    final startMs = row['start_date'] as int?;
    final monthCsv = row['by_month_days'] as String?;
    int? monthDay;
    if (monthCsv != null && monthCsv.trim().isNotEmpty) {
      monthDay = int.tryParse(monthCsv.split(',').first.trim());
    }
    return RecurrenceRule.fromLegacy(
      frequency: '${row['frequency'] ?? 'DAILY'}',
      interval: interval,
      dtStart: startMs == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(startMs),
      until: untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs),
      count: row['count'] as int?,
      daysOfWeekCsv: row['days_of_week'] as String?,
      monthDay: monthDay,
    );
  }

  Future<Task?> spawnNextOccurrence(String completedTaskId) async {
    final rule = await getRecurrenceRule(completedTaskId);
    if (rule == null) return null;
    final src = await getById(completedTaskId);
    if (src == null) return null;
    final base = src.dueAt != null
        ? DateTime.fromMillisecondsSinceEpoch(src.dueAt!)
        : DateTime.now();
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
      LEFT JOIN tasks t ON t.id = d.depends_on_task_id
      WHERE d.task_id = ?
    ''', [taskId]);
  }
}
