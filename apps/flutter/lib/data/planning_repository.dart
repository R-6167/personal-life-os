import 'package:sqflite/sqflite.dart';

import '../domain/enums.dart';
import 'database.dart';
import 'task_repository.dart';

/// Inclusive busy interval in milliseconds [start, end).
class BusyInterval {
  const BusyInterval(this.startMs, this.endMs);
  final int startMs;
  final int endMs;

  int get durationMs => endMs > startMs ? endMs - startMs : 0;
}

/// Merge overlapping/adjacent busy intervals so free-time is not double-counted.
List<BusyInterval> mergeBusyIntervals(List<BusyInterval> raw) {
  if (raw.isEmpty) return const [];
  final sorted = List<BusyInterval>.from(raw)
    ..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <BusyInterval>[];
  var cur = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final n = sorted[i];
    if (n.startMs <= cur.endMs) {
      cur = BusyInterval(cur.startMs, n.endMs > cur.endMs ? n.endMs : cur.endMs);
    } else {
      out.add(cur);
      cur = n;
    }
  }
  out.add(cur);
  return out;
}

/// Time blocks, free-time math, day/week agenda.
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

  /// Atomic: task schedule fields + time_block + activity event in one transaction.
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

    await _db.txn((txn) async {
      await txn.update(
        'tasks',
        {
          'scheduled_start': startMs,
          'scheduled_end': endMs,
          'status': EntityStatus.inProgress,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
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

  /// Atomic reschedule of task session + matching time blocks.
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

    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    final title = taskRows.first['title'] as String?;

    await _db.txn((txn) async {
      await txn.update(
        'tasks',
        {
          'scheduled_start': startMs,
          'scheduled_end': endMs,
          'status': EntityStatus.inProgress,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      if (blocks.isEmpty) {
        final blockId = AppDatabase.newId();
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
      } else {
        for (final b in blocks) {
          await txn.update(
            'time_blocks',
            {
              'start_at': startMs,
              'end_at': endMs,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [b['id']],
          );
        }
      }

      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_RESCHEDULED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"start":$startMs,"end":$endMs,"minutes":$minutes}',
      });
    });
  }

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
    final mins = durationMinutes ?? ((oldEnd - oldStart) / 60000).round().clamp(10, 240);
    final taskId = b['task_id'] as String?;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = start.add(Duration(minutes: mins)).millisecondsSinceEpoch;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();

    await _db.txn((txn) async {
      await txn.update(
        'time_blocks',
        {'start_at': startMs, 'end_at': endMs, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [blockId],
      );
      if (taskId != null && taskId.isNotEmpty) {
        await txn.update(
          'tasks',
          {
            'scheduled_start': startMs,
            'scheduled_end': endMs,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TIME_BLOCK_MOVED',
        'entity_type': 'TIME_BLOCK',
        'entity_id': blockId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"start":$startMs,"end":$endMs}',
      });
    });
  }

  Future<void> cancelBlock(String blockId) async {
    final rows =
        await (await _db.database).query('time_blocks', where: 'id = ?', whereArgs: [blockId], limit: 1);
    if (rows.isEmpty) return;
    final taskId = rows.first['task_id'] as String?;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();

    await _db.txn((txn) async {
      await txn.update(
        'time_blocks',
        {'status': 'CANCELLED', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [blockId],
      );
      if (taskId != null && taskId.isNotEmpty) {
        await txn.update(
          'tasks',
          {
            'scheduled_start': null,
            'scheduled_end': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TIME_BLOCK_CANCELLED',
        'entity_type': 'TIME_BLOCK',
        'entity_id': blockId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<String> addFocusBlock({
    required DateTime start,
    int durationMinutes = 45,
    String title = 'Focus',
  }) async {
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

  /// Free minutes in the work window after merging overlapping busy intervals.
  Future<int> availableMinutes({
    required DateTime day,
    int dayStartHour = 8,
    int dayEndHour = 22,
  }) async {
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final windowStart = dayStart.millisecondsSinceEpoch;
    final windowEnd = dayEnd.millisecondsSinceEpoch;
    final total = dayEnd.difference(dayStart).inMinutes;

    final busy = <BusyInterval>[];

    final blocks = await listBlocksOnDay(day);
    for (final b in blocks) {
      final s = b['start_at'] as int?;
      final e = b['end_at'] as int?;
      if (s == null || e == null) continue;
      final cs = s < windowStart ? windowStart : s;
      final ce = e > windowEnd ? windowEnd : e;
      if (ce > cs) busy.add(BusyInterval(cs, ce));
    }

    final db = await _db.database;
    try {
      final events = await db.query(
        'calendar_events',
        where: 'start_at < ? AND end_at > ?',
        whereArgs: [windowEnd, windowStart],
      );
      for (final ev in events) {
        final status = '${ev['status'] ?? ''}';
        if (status == 'CANCELLED') continue;
        final s = ev['start_at'] as int?;
        final e = ev['end_at'] as int?;
        if (s == null || e == null) continue;
        final cs = s < windowStart ? windowStart : s;
        final ce = e > windowEnd ? windowEnd : e;
        if (ce > cs) busy.add(BusyInterval(cs, ce));
      }
    } catch (_) {}

    final merged = mergeBusyIntervals(busy);
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
  }) async {
    final slots = <DateTime>[];
    final dayStart = DateTime(day.year, day.month, day.day, dayStartHour);
    final dayEnd = DateTime(day.year, day.month, day.day, dayEndHour);
    final windowStart = dayStart.millisecondsSinceEpoch;
    final windowEnd = dayEnd.millisecondsSinceEpoch;

    final busy = <BusyInterval>[];
    for (final b in await listBlocksOnDay(day)) {
      final s = b['start_at'] as int?;
      final e = b['end_at'] as int?;
      if (s == null || e == null) continue;
      busy.add(BusyInterval(
        s < windowStart ? windowStart : s,
        e > windowEnd ? windowEnd : e,
      ));
    }
    try {
      final events = await (await _db.database).query(
        'calendar_events',
        where: 'start_at < ? AND end_at > ?',
        whereArgs: [windowEnd, windowStart],
      );
      for (final ev in events) {
        if ('${ev['status'] ?? ''}' == 'CANCELLED') continue;
        final s = ev['start_at'] as int?;
        final e = ev['end_at'] as int?;
        if (s == null || e == null) continue;
        busy.add(BusyInterval(
          s < windowStart ? windowStart : s,
          e > windowEnd ? windowEnd : e,
        ));
      }
    } catch (_) {}

    final merged = mergeBusyIntervals(busy.where((b) => b.endMs > b.startMs).toList());
    final need = Duration(minutes: durationMinutes);
    var cursor = dayStart;
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      if (cursor.isBefore(now)) {
        final rounded = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15) * 15);
        cursor = rounded.add(const Duration(minutes: 15));
      }
    }

    for (final m in merged) {
      final gapEnd = DateTime.fromMillisecondsSinceEpoch(m.startMs);
      if (gapEnd.isAfter(cursor) && gapEnd.difference(cursor) >= need) {
        slots.add(cursor);
        if (slots.length >= 6) return slots;
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
