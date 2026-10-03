import '../domain/enums.dart';
import 'database.dart';
import 'task_repository.dart';

/// Time blocks, free-time math, day/week agenda (Phase 2 — Planning & Time).
class PlanningRepository {
  PlanningRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listBlocksOnDay(DateTime day) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    return db.query(
      'time_blocks',
      where: 'start_at <= ? AND end_at >= ? AND status != ?',
      whereArgs: [end, start, 'CANCELLED'],
      orderBy: 'start_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> listBlocksInRange(DateTime from, DateTime to) async {
    final db = await _db.database;
    return db.query(
      'time_blocks',
      where: 'start_at < ? AND end_at > ? AND status != ?',
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch, 'CANCELLED'],
      orderBy: 'start_at ASC',
    );
  }

  Future<String> scheduleTaskSession({
    required String taskId,
    required DateTime start,
    int durationMinutes = 30,
    String? title,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: durationMinutes)).millisecondsSinceEpoch;
    final blockId = AppDatabase.newId();

    await TaskRepository(_db).scheduleSession(
      taskId: taskId,
      start: start,
      durationMinutes: durationMinutes,
    );

    await _db.txn((txn) async {
      await txn.insert('time_blocks', {
        'id': blockId,
        'owner_id': ownerId,
        'title': title ?? 'Task session',
        'type': 'TASK',
        'start_at': startMs,
        'end_at': endMs,
        'task_id': taskId,
        'status': 'PLANNED',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TIME_BLOCK_CREATED',
        'entity_type': 'TIME_BLOCK',
        'entity_id': blockId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"taskId":"$taskId"}',
      });
    });
    return blockId;
  }

  /// Move a task session to a new start (keeps duration unless overridden).
  Future<void> rescheduleTaskSession({
    required String taskId,
    required DateTime start,
    int? durationMinutes,
  }) async {
    final db = await _db.database;
    final taskRows = await db.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1);
    if (taskRows.isEmpty) return;

    final existingStart = taskRows.first['scheduled_start'] as int?;
    final existingEnd = taskRows.first['scheduled_end'] as int?;
    var minutes = durationMinutes;
    if (minutes == null && existingStart != null && existingEnd != null) {
      minutes = ((existingEnd - existingStart) / 60000).round().clamp(15, 180);
    }
    minutes ??= (taskRows.first['estimated_minutes'] as int?) ?? 30;

    await TaskRepository(_db).scheduleSession(
      taskId: taskId,
      start: start,
      durationMinutes: minutes,
    );

    // Update matching time blocks for this task on that day
    final dayStart = DateTime(start.year, start.month, start.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final blocks = await db.query(
      'time_blocks',
      where: 'task_id = ? AND start_at >= ? AND start_at < ? AND status != ?',
      whereArgs: [
        taskId,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
        'CANCELLED',
      ],
    );
    final now = AppDatabase.nowMs();
    final endMs = start.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    if (blocks.isEmpty) {
      await scheduleTaskSession(
        taskId: taskId,
        start: start,
        durationMinutes: minutes,
        title: taskRows.first['title'] as String?,
      );
    } else {
      for (final b in blocks) {
        await db.update(
          'time_blocks',
          {
            'start_at': start.millisecondsSinceEpoch,
            'end_at': endMs,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [b['id']],
        );
      }
    }
  }

  /// Move a time block by id.
  Future<void> moveBlock({
    required String blockId,
    required DateTime start,
    int? durationMinutes,
  }) async {
    final db = await _db.database;
    final rows = await db.query('time_blocks', where: 'id = ?', whereArgs: [blockId], limit: 1);
    if (rows.isEmpty) return;
    final b = rows.first;
    final oldStart = b['start_at'] as int;
    final oldEnd = b['end_at'] as int;
    final mins = durationMinutes ??
        ((oldEnd - oldStart) / 60000).round().clamp(10, 240);
    final end = start.add(Duration(minutes: mins));
    final now = AppDatabase.nowMs();
    await db.update(
      'time_blocks',
      {
        'start_at': start.millisecondsSinceEpoch,
        'end_at': end.millisecondsSinceEpoch,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [blockId],
    );
    final taskId = b['task_id'] as String?;
    if (taskId != null) {
      await TaskRepository(_db).scheduleSession(
        taskId: taskId,
        start: start,
        durationMinutes: mins,
      );
    }
  }

  /// Place an unscheduled task onto the day at [start].
  Future<void> dropTaskOntoDay({
    required String taskId,
    required DateTime start,
    int durationMinutes = 30,
    String? title,
  }) async {
    await scheduleTaskSession(
      taskId: taskId,
      start: start,
      durationMinutes: durationMinutes,
      title: title,
    );
  }

  Future<void> completeBlock(String blockId, {bool completeTask = false}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query('time_blocks', where: 'id = ?', whereArgs: [blockId], limit: 1);
    if (rows.isEmpty) return;
    final taskId = rows.first['task_id'] as String?;

    await _db.txn((txn) async {
      await txn.update(
        'time_blocks',
        {'status': 'COMPLETED', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [blockId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TIME_BLOCK_COMPLETED',
        'entity_type': 'TIME_BLOCK',
        'entity_id': blockId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });

    if (completeTask && taskId != null) {
      await TaskRepository(_db).complete(taskId);
    }
  }

  Future<void> cancelBlock(String blockId) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'time_blocks',
      {'status': 'CANCELLED', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [blockId],
    );
  }

  Future<String> addFocusBlock({
    required DateTime start,
    int durationMinutes = 45,
    String title = 'Focus',
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('time_blocks', {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'type': 'FOCUS',
      'start_at': start.millisecondsSinceEpoch,
      'end_at': start.add(Duration(minutes: durationMinutes)).millisecondsSinceEpoch,
      'status': 'PLANNED',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<int> availableMinutes({
    required DateTime day,
    int dayStartHour = 8,
    int dayEndHour = 22,
  }) async {
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final total = dayEnd.difference(dayStart).inMinutes;
    final blocks = await listBlocksOnDay(day);
    var busy = 0;
    for (final b in blocks) {
      final s = DateTime.fromMillisecondsSinceEpoch(b['start_at'] as int);
      final e = DateTime.fromMillisecondsSinceEpoch(b['end_at'] as int);
      final clippedStart = s.isBefore(dayStart) ? dayStart : s;
      final clippedEnd = e.isAfter(dayEnd) ? dayEnd : e;
      if (clippedEnd.isAfter(clippedStart)) {
        busy += clippedEnd.difference(clippedStart).inMinutes;
      }
    }
    final db = await _db.database;
    final events = await db.query(
      'calendar_events',
      where: 'start_at < ? AND end_at > ? AND status != ?',
      whereArgs: [dayEnd.millisecondsSinceEpoch, dayStart.millisecondsSinceEpoch, 'CANCELLED'],
    );
    for (final ev in events) {
      final s = DateTime.fromMillisecondsSinceEpoch(ev['start_at'] as int);
      final e = DateTime.fromMillisecondsSinceEpoch(ev['end_at'] as int);
      final clippedStart = s.isBefore(dayStart) ? dayStart : s;
      final clippedEnd = e.isAfter(dayEnd) ? dayEnd : e;
      if (clippedEnd.isAfter(clippedStart)) {
        busy += clippedEnd.difference(clippedStart).inMinutes;
      }
    }
    final free = total - busy;
    return free < 0 ? 0 : free;
  }

  Future<List<DateTime>> suggestSlots({
    required DateTime day,
    int durationMinutes = 30,
    int dayStartHour = 8,
    int dayEndHour = 22,
  }) async {
    final slots = <DateTime>[];
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final blocks = await listBlocksOnDay(day);
    final starts = <DateTime>[];
    final ends = <DateTime>[];
    for (final b in blocks) {
      starts.add(DateTime.fromMillisecondsSinceEpoch(b['start_at'] as int));
      ends.add(DateTime.fromMillisecondsSinceEpoch(b['end_at'] as int));
    }
    final order = List<int>.generate(starts.length, (i) => i);
    order.sort((a, b) => starts[a].compareTo(starts[b]));

    var cursor = dayStart;
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      if (cursor.isBefore(now)) {
        cursor = DateTime(now.year, now.month, now.day, now.hour + 1);
      }
    }

    for (final i in order) {
      final s = starts[i];
      final e = ends[i];
      while (!cursor.add(Duration(minutes: durationMinutes)).isAfter(s)) {
        if (cursor.isBefore(dayEnd)) slots.add(cursor);
        cursor = cursor.add(const Duration(minutes: 15));
        if (slots.length >= 6) return slots;
      }
      if (cursor.isBefore(e)) cursor = e;
    }
    while (!cursor.add(Duration(minutes: durationMinutes)).isAfter(dayEnd)) {
      slots.add(cursor);
      cursor = cursor.add(const Duration(minutes: 30));
      if (slots.length >= 6) break;
    }
    return slots;
  }

  Future<Map<String, Object?>> daySummary(DateTime day) async {
    final tasks = await TaskRepository(_db).listScheduledOnDay(day);
    final open = await TaskRepository(_db).listOpen();
    final overdue = open.where((t) => t.isOverdue).length;
    final dueToday = open.where((t) => t.isDueToday).length;
    final free = await availableMinutes(day: day);
    final blocks = await listBlocksOnDay(day);
    return {
      'scheduled_tasks': tasks.length,
      'blocks': blocks.length,
      'overdue': overdue,
      'due_today': dueToday,
      'free_minutes': free,
    };
  }
}
