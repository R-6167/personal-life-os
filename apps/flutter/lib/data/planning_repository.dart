import 'package:sqflite/sqflite.dart';

import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';
import 'task_repository.dart';

class BusyInterval {
  const BusyInterval(this.startMs, this.endMs);
  final int startMs;
  final int endMs;
  int get durationMs => endMs - startMs;
}

List<BusyInterval> mergeBusyIntervals(List<BusyInterval> raw) {
  if (raw.isEmpty) return const [];
  final sorted = [...raw]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <BusyInterval>[];
  var curStart = sorted.first.startMs;
  var curEnd = sorted.first.endMs;
  for (var i = 1; i < sorted.length; i++) {
    final n = sorted[i];
    if (n.startMs <= curEnd) {
      if (n.endMs > curEnd) curEnd = n.endMs;
    } else {
      out.add(BusyInterval(curStart, curEnd));
      curStart = n.startMs;
      curEnd = n.endMs;
    }
  }
  out.add(BusyInterval(curStart, curEnd));
  return out;
}

class PlanningRepository {
  PlanningRepository(this._db);
  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listBlocksOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    final ownerId = await _db.requireOwnerId();
    return (await _db.database).query(
      'time_blocks',
      where: "owner_id = ? AND start_at <= ? AND end_at >= ? AND (status IS NULL OR status != 'CANCELLED')",
      whereArgs: [ownerId, end, start],
      orderBy: 'start_at ASC',
    );
  }

  Future<String> scheduleTaskSession({
    required String taskId,
    required DateTime start,
    int durationMinutes = 30,
    String? title,
  }) async {
    durationMinutes = durationMinutes.clamp(15, 8 * 60);
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: durationMinutes)).millisecondsSinceEpoch;
    final blockId = AppDatabase.newId();

    await _db.txn((txn) async {
      final taskRows = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
        limit: 1,
      );
      if (taskRows.isEmpty) {
        throw StateError('Task not found, archived, or not owned by the current user: $taskId');
      }
      await txn.update(
        'time_blocks',
        {'status': 'CANCELLED', 'updated_at': now},
        where: "task_id = ? AND owner_id = ? AND status = 'PLANNED'",
        whereArgs: [taskId, ownerId],
      );
      final changed = await txn.update(
        'tasks',
        {
          'scheduled_start': startMs,
          'scheduled_end': endMs,
          'status': EntityStatus.inProgress,
          'updated_at': now,
        },
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
      );
      if (changed != 1) {
        throw StateError('Task could not be scheduled: $taskId');
      }
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
        'event_type': 'TASK_SCHEDULED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata':
            '{"start":$startMs,"end":$endMs,"minutes":$durationMinutes,"blockId":"$blockId"}',
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

  Future<String> dropTaskOntoDay({
    required String taskId,
    required DateTime start,
    int durationMinutes = 30,
    String? title,
  }) =>
      scheduleTaskSession(
        taskId: taskId,
        start: start,
        durationMinutes: durationMinutes,
        title: title,
      );

  Future<void> rescheduleTaskSession({
    required String taskId,
    required DateTime start,
    int? durationMinutes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final taskRows = await db.query(
      'tasks',
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [taskId, ownerId],
      limit: 1,
    );
    if (taskRows.isEmpty) {
      throw StateError('Task not found, archived, or not owned by the current user: $taskId');
    }

    final existingStart = taskRows.first['scheduled_start'] as int?;
    final existingEnd = taskRows.first['scheduled_end'] as int?;
    var minutes = durationMinutes;
    if (minutes == null &&
        existingStart != null &&
        existingEnd != null &&
        existingEnd > existingStart) {
      minutes = ((existingEnd - existingStart) / 60000).round();
    }
    minutes ??= (taskRows.first['estimated_minutes'] as int?) ?? 30;
    minutes = minutes.clamp(15, 8 * 60);

    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    final title = taskRows.first['title'] as String?;
    final blockId = AppDatabase.newId();

    await _db.txn((txn) async {
      final current = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
        limit: 1,
      );
      if (current.isEmpty) {
        throw StateError('Task not found, archived, or not owned by the current user: $taskId');
      }
      await txn.update(
        'time_blocks',
        {'status': 'CANCELLED', 'updated_at': now},
        where: "task_id = ? AND owner_id = ? AND status = 'PLANNED'",
        whereArgs: [taskId, ownerId],
      );
      final changed = await txn.update(
        'tasks',
        {
          'scheduled_start': startMs,
          'scheduled_end': endMs,
          'status': EntityStatus.inProgress,
          'updated_at': now,
        },
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
      );
      if (changed != 1) {
        throw StateError('Task could not be rescheduled: $taskId');
      }
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
        'event_type': 'TASK_RESCHEDULED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata':
            '{"start":$startMs,"end":$endMs,"minutes":$minutes,"blockId":"$blockId"}',
      });
    });
  }

  Future<void> moveBlock({
    required String blockId,
    required DateTime start,
    DateTime? end,
    int? durationMinutes,
  }) async {
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final resolvedEnd = end ?? start.add(Duration(minutes: durationMinutes ?? 30));
    final endMs = resolvedEnd.millisecondsSinceEpoch;
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.query(
      'time_blocks',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [blockId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Time block not found or not owned by the current user: $blockId');
    }
    final taskId = rows.first['task_id'] as String?;

    await _db.txn((txn) async {
      await txn.update(
        'time_blocks',
        {'start_at': startMs, 'end_at': endMs, 'updated_at': now},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [blockId, ownerId],
      );
      if (taskId != null) {
        await txn.update(
          'tasks',
          {
            'scheduled_start': startMs,
            'scheduled_end': endMs,
            'updated_at': now,
          },
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [taskId, ownerId],
        );
      }
    });
  }

  Future<void> cancelBlock(String blockId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query(
      'time_blocks',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [blockId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Time block not found or not owned by the current user: $blockId');
    }
    final taskId = rows.first['task_id'] as String?;

    await _db.txn((txn) async {
      await txn.update(
        'time_blocks',
        {'status': 'CANCELLED', 'updated_at': now},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [blockId, ownerId],
      );
      if (taskId != null) {
        await txn.update(
          'tasks',
          {
            'scheduled_start': null,
            'scheduled_end': null,
            'updated_at': now,
          },
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [taskId, ownerId],
        );
      }
    });
  }

  Future<String> addFocusBlock({
    required DateTime start,
    int durationMinutes = 30,
    required String title,
  }) async {
    durationMinutes = durationMinutes.clamp(10, 8 * 60);
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: durationMinutes)).millisecondsSinceEpoch;
    await (await _db.database).insert('time_blocks', {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'type': 'FOCUS',
      'start_at': startMs,
      'end_at': endMs,
      'status': 'PLANNED',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<BusyInterval>> collectDayBusy({
    required DateTime day,
    int dayStartHour = 8,
    int dayEndHour = 22,
  }) async {
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final startMs = dayStart.millisecondsSinceEpoch;
    final endMs = dayEnd.millisecondsSinceEpoch;
    final busy = <BusyInterval>[];
    final db = await _db.database;

    try {
      final events = await db.query(
        'calendar_events',
        where: 'start_at < ? AND end_at > ?',
        whereArgs: [endMs, startMs],
      );
      for (final e in events) {
        if ('${e['status'] ?? ''}' == 'CANCELLED') continue;
        final s = e['start_at'] as int;
        final en = e['end_at'] as int;
        busy.add(BusyInterval(s < startMs ? startMs : s, en > endMs ? endMs : en));
      }
    } catch (_) {}

    final blocks = await listBlocksOnDay(day);
    for (final b in blocks) {
      final s = b['start_at'] as int;
      final en = b['end_at'] as int;
      busy.add(BusyInterval(s < startMs ? startMs : s, en > endMs ? endMs : en));
    }

    try {
      final tasks = await db.query(
        'tasks',
        where:
            'scheduled_start IS NOT NULL AND scheduled_start < ? AND '
            '(scheduled_end IS NULL OR scheduled_end > ?) AND '
            'status NOT IN (?, ?) AND archived_at IS NULL',
        whereArgs: [
          endMs,
          startMs,
          EntityStatus.completed,
          EntityStatus.cancelled,
        ],
      );
      for (final row in tasks) {
        final s = row['scheduled_start'] as int?;
        if (s == null) continue;
        var e = row['scheduled_end'] as int?;
        if (e == null) {
          final est = (row['estimated_minutes'] as int?) ?? 30;
          e = s + est * 60 * 1000;
        }
        busy.add(BusyInterval(s < startMs ? startMs : s, e > endMs ? endMs : e));
      }
    } catch (_) {}

    return mergeBusyIntervals(busy);
  }

  Future<bool> conflictsWithLocked({
    required DateTime start,
    required int durationMinutes,
    String? ignoreTaskId,
    String? ignoreBlockId,
  }) async {
    durationMinutes = durationMinutes.clamp(1, 8 * 60);
    final end = start.add(Duration(minutes: durationMinutes));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final db = await _db.database;

    try {
      final events = await db.query(
        'calendar_events',
        where: 'start_at < ? AND end_at > ?',
        whereArgs: [endMs, startMs],
      );
      for (final e in events) {
        if ('${e['status'] ?? ''}' == 'CANCELLED') continue;
        return true;
      }
    } catch (_) {}

    final blocks = await db.query(
      'time_blocks',
      where:
          "start_at < ? AND end_at > ? AND (status IS NULL OR status != 'CANCELLED')",
      whereArgs: [endMs, startMs],
    );
    for (final b in blocks) {
      final bid = b['id'] as String?;
      if (ignoreBlockId != null && bid == ignoreBlockId) continue;
      final tid = b['task_id'] as String?;
      if (ignoreTaskId != null && tid == ignoreTaskId) continue;
      return true;
    }

    try {
      final tasks = await db.query(
        'tasks',
        where:
            'scheduled_start IS NOT NULL AND scheduled_start < ? AND '
            '(scheduled_end IS NULL OR scheduled_end > ?) AND '
            'status NOT IN (?, ?) AND archived_at IS NULL',
        whereArgs: [
          endMs,
          startMs,
          EntityStatus.completed,
          EntityStatus.cancelled,
        ],
      );
      for (final row in tasks) {
        final tid = row['id'] as String?;
        if (ignoreTaskId != null && tid == ignoreTaskId) continue;
        final s = row['scheduled_start'] as int?;
        if (s == null) continue;
        var e = row['scheduled_end'] as int?;
        if (e == null) {
          final est = (row['estimated_minutes'] as int?) ?? 30;
          e = s + est * 60 * 1000;
        }
        if (s < endMs && e > startMs) return true;
      }
    } catch (_) {}

    return false;
  }

  Future<int> availableMinutes({
    required DateTime day,
    int dayStartHour = 8,
    int dayEndHour = 22,
  }) async {
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final total = dayEnd.difference(dayStart).inMinutes;
    final merged = await collectDayBusy(
      day: day,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
    var busyMinutes = 0;
    for (final m in merged) {
      busyMinutes += (m.durationMs / 60000).floor();
    }
    final free = total - busyMinutes;
    return free < 0 ? 0 : free;
  }

  Future<List<DateTime>> suggestSlots({
    required DateTime day,
    int durationMinutes = 30,
    int dayStartHour = 8,
    int dayEndHour = 22,
    int limit = 8,
  }) async {
    final slots = <DateTime>[];
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final need = Duration(minutes: durationMinutes.clamp(5, 8 * 60));

    final merged = await collectDayBusy(
      day: day,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );

    var cursor = dayStart;
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      if (cursor.isBefore(now)) {
        final rounded = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          (now.minute ~/ 15) * 15,
        );
        cursor = rounded.add(const Duration(minutes: 15));
      }
    }

    for (final m in merged) {
      final gapEnd = DateTime.fromMillisecondsSinceEpoch(m.startMs);
      if (gapEnd.isAfter(cursor) && gapEnd.difference(cursor) >= need) {
        slots.add(cursor);
        if (slots.length >= limit) return slots;
      }
      final after = DateTime.fromMillisecondsSinceEpoch(m.endMs);
      if (after.isAfter(cursor)) cursor = after;
    }
    if (dayEnd.difference(cursor) >= need) {
      slots.add(cursor);
    }
    return slots;
  }
}
