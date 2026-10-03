import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';
import '../services/recurrence_engine.dart';

class HabitRepository {
  HabitRepository(this._db);
  final AppDatabase _db;

  static int dayKey([DateTime? day]) {
    final d = day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  Future<List<Habit>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'habits',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'created_at DESC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<Habit?> getById(String id) async {
    final rows = await (await _db.database).query('habits', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first);
  }

  Future<Habit> create({
    required String title,
    String? description,
    String frequency = 'DAILY',
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final habit = Habit(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: EntityStatus.active,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      final map = habit.toInsertMap();
      if (description != null && description.isNotEmpty) {
        map['description'] = description;
      }
      await txn.insert('habits', map);
      await txn.insert('habit_schedules', {
        'id': AppDatabase.newId(),
        'habit_id': habit.id,
        'frequency': frequency,
        'target_count': 1,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_CREATED',
        'entity_type': 'HABIT',
        'entity_id': habit.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return habit;
  }

  Future<Map<String, Object?>?> scheduleOf(String habitId) async {
    final rows = await (await _db.database).query(
      'habit_schedules',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> ensureTodayOccurrence(String habitId) async {
    final day = dayKey();
    final db = await _db.database;
    final existing = await db.query(
      'habit_occurrences',
      where: 'habit_id = ? AND scheduled_date = ?',
      whereArgs: [habitId, day],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final sch = await scheduleOf(habitId);
    if (sch != null) {
      final habit = await getById(habitId);
      final start = habit != null
          ? DateTime.fromMillisecondsSinceEpoch(habit.createdAt)
          : DateTime.fromMillisecondsSinceEpoch(day);
      final rule = RecurrenceRule.fromLegacy(
        frequency: '${sch['frequency'] ?? 'DAILY'}',
        interval: 1,
        dtStart: start,
        daysOfWeekCsv: sch['days_of_week'] as String?,
      );
      if (!rule.generator().occursOn(DateTime.fromMillisecondsSinceEpoch(day))) {
        return null;
      }
    }

    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    try {
      await db.insert('habit_occurrences', {
        'id': id,
        'habit_id': habitId,
        'scheduled_date': day,
        'status': HabitOccurrenceStatus.expected,
        'created_at': now,
        'updated_at': now,
      });
    } catch (_) {
      final again = await db.query(
        'habit_occurrences',
        where: 'habit_id = ? AND scheduled_date = ?',
        whereArgs: [habitId, day],
        limit: 1,
      );
      if (again.isNotEmpty) return again.first['id'] as String;
      rethrow;
    }
    return id;
  }

  Future<void> ensureAllTodayOccurrences() async {
    final habits = await listActive();
    for (final h in habits) {
      try {
        await ensureTodayOccurrence(h.id);
      } catch (_) {}
    }
  }

  Future<void> markDoneToday(String habitId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final occId = await ensureTodayOccurrence(habitId);
    if (occId == null) return;
    await _db.txn((txn) async {
      await txn.update(
        'habit_occurrences',
        {
          'status': HabitOccurrenceStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [occId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_COMPLETED',
        'entity_type': 'HABIT',
        'entity_id': habitId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> completeToday(String habitId) => markDoneToday(habitId);

  Future<void> skipToday(String habitId, {String? reason}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final occId = await ensureTodayOccurrence(habitId);
    if (occId == null) return;
    await _db.txn((txn) async {
      await txn.update(
        'habit_occurrences',
        {
          'status': HabitOccurrenceStatus.skipped,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [occId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_SKIPPED',
        'entity_type': 'HABIT',
        'entity_id': habitId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': reason,
      });
    });
  }

  Future<int> markMissedBeforeToday() async {
    final db = await _db.database;
    final today = dayKey();
    try {
      return await db.rawUpdate(
        'UPDATE habit_occurrences SET status = ? WHERE status = ? AND scheduled_date < ?',
        [HabitOccurrenceStatus.missed, HabitOccurrenceStatus.expected, today],
      );
    } catch (_) {
      return 0;
    }
  }

  Future<String?> todayStatus(String habitId) async {
    final day = dayKey();
    final rows = await (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ? AND scheduled_date = ?',
      whereArgs: [habitId, day],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<int> streakDays(String habitId) async {
    final db = await _db.database;
    final rows = await db.query(
      'habit_occurrences',
      where: 'habit_id = ? AND status = ?',
      whereArgs: [habitId, HabitOccurrenceStatus.completed],
      orderBy: 'scheduled_date DESC',
      limit: 120,
    );
    if (rows.isEmpty) return 0;
    var streak = 0;
    var expect = dayKey();
    for (final r in rows) {
      final ms = r['scheduled_date'] as int? ?? 0;
      if (ms == expect) {
        streak++;
        final d = DateTime.fromMillisecondsSinceEpoch(expect);
        expect = DateTime(d.year, d.month, d.day - 1).millisecondsSinceEpoch;
      } else if (ms < expect) {
        break;
      }
    }
    return streak;
  }

  Future<void> pause(String habitId) async {
    await (await _db.database).update(
      'habits',
      {'status': EntityStatus.paused, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> resume(String habitId) async {
    await (await _db.database).update(
      'habits',
      {'status': EntityStatus.active, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> archive(String habitId) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'habits',
      {'status': EntityStatus.archived, 'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> setSchedule({
    required String habitId,
    required String frequency,
    String? daysOfWeek,
    int targetCount = 1,
  }) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query('habit_schedules', where: 'habit_id = ?', whereArgs: [habitId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('habit_schedules', {
        'id': AppDatabase.newId(),
        'habit_id': habitId,
        'frequency': frequency,
        'days_of_week': daysOfWeek,
        'target_count': targetCount,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'habit_schedules',
        {
          'frequency': frequency,
          'days_of_week': daysOfWeek,
          'target_count': targetCount,
          'updated_at': now,
        },
        where: 'habit_id = ?',
        whereArgs: [habitId],
      );
    }
  }

  Future<List<Map<String, Object?>>> recentOccurrences(String habitId, {int limit = 30}) async {
    return (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'scheduled_date DESC',
      limit: limit,
    );
  }
}
