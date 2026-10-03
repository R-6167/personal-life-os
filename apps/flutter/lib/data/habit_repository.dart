import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class HabitRepository {
  HabitRepository(this._db);
  final AppDatabase _db;

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

  Future<Habit> create({equired String title, String? description, String frequency = 'DAILY'}) async {
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
        'interval_n': 1,
        'start_date': now,
        'enabled': 1,
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
    await ensureTodayOccurrence(habit.id);
    return habit;
  }

  Future<void> setSchedule({equired String habitId, required String frequency, int intervalN = 1, String? daysOfWeek}) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query('habit_schedules', where: 'habit_id = ?', whereArgs: [habitId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('habit_schedules', {
        'id': AppDatabase.newId(),
        'habit_id': habitId,
        'frequency': frequency,
        'interval_n': intervalN,
        'days_of_week': daysOfWeek,
        'start_date': now,
        'enabled': 1,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'habit_schedules',
        {
          'frequency': frequency,
          'interval_n': intervalN,
          'days_of_week': daysOfWeek,
          'updated_at': now,
          'enabled': 1,
        },
        where: 'habit_id = ?',
        whereArgs: [habitId],
      );
    }
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

  /// Ensure an EXPECTED occurrence exists for today (if schedule applies).
  Future<String?> ensureTodayOccurrence(String habitId) async {
    final day = AppDatabase.startOfTodayMs();
    final db = await _db.database;
    final existing = await db.query(
      'habit_occurrences',
      where: 'habit_id = ? AND scheduled_date = ?',
      whereArgs: [habitId, day],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    if (!await _appliesToday(habitId)) return null;

    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await db.insert('habit_occurrences', {
      'id': id,
      'habit_id': habitId,
      'scheduled_date': day,
      'status': HabitOccurrenceStatus.expected,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> ensureAllTodayOccurrences() async {
    final habits = await listActive();
    for (final h in habits) {
      await ensureTodayOccurrence(h.id);
    }
  }

  Future<bool> _appliesToday(String habitId) async {
    final sched = await scheduleOf(habitId);
    if (sched == null) return true;
    if ((sched['enabled'] as int?) == 0) return false;
    final freq = (sched['frequency'] as String?) ?? 'DAILY';
    final now = DateTime.now();
    if (freq == 'DAILY') return true;
    if (freq == 'WEEKLY') {
      final days = sched['days_of_week'] as String?;
      if (days == null || days.isEmpty) return true;
      // 1=Mon .. 7=Sun
      final wd = now.weekday;
      return days.split(',').map((e) => e.trim()).contains('$wd');
    }
    if (freq == 'MONTHLY') {
      return now.day == 1 || now.day == 15;
    }
    return true;
  }

  /// Idempotent complete for today.
  Future<void> markDoneToday(String habitId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final scheduledDate = AppDatabase.startOfTodayMs();
    await ensureTodayOccurrence(habitId);

    await _db.txn((txn) async {
      final existing = await txn.query(
        'habit_occurrences',
        where: 'habit_id = ? AND scheduled_date = ?',
        whereArgs: [habitId, scheduledDate],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as String;
        await txn.update(
          'habit_occurrences',
          {
            'status': HabitOccurrenceStatus.completed,
            'completed_at': now,
            'skipped_at': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('activity_events', {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'event_type': 'HABIT_COMPLETED',
          'entity_type': 'HABIT_OCCURRENCE',
          'entity_id': id,
          'occurred_at': now,
          'recorded_at': now,
          'source': EventSource.user,
          'metadata': '{"scheduledDate":$scheduledDate}',
        });
        return;
      }

      final occId = AppDatabase.newId();
      await txn.insert('habit_occurrences', {
        'id': occId,
        'habit_id': habitId,
        'scheduled_date': scheduledDate,
        'status': HabitOccurrenceStatus.completed,
        'completed_at': now,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_COMPLETED',
        'entity_type': 'HABIT_OCCURRENCE',
        'entity_id': occId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': '{"scheduledDate":$scheduledDate}',
      });
    });
  }

  Future<void> skipToday(String habitId, {String? reason}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final day = AppDatabase.startOfTodayMs();
    await ensureTodayOccurrence(habitId);
    await _db.txn((txn) async {
      final existing = await txn.query(
        'habit_occurrences',
        where: 'habit_id = ? AND scheduled_date = ?',
        whereArgs: [habitId, day],
        limit: 1,
      );
      if (existing.isEmpty) return;
      final id = existing.first['id'] as String;
      await txn.update(
        'habit_occurrences',
        {
          'status': HabitOccurrenceStatus.skipped,
          'skipped_at': now,
          'reason': reason,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_SKIPPED',
        'entity_type': 'HABIT_OCCURRENCE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  /// Mark open EXPECTED occurrences before today as MISSED.
  Future<int> markMissedBeforeToday() async {
    final ownerId = await _db.requireOwnerId();
    final day = AppDatabase.startOfTodayMs();
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query(
      'habit_occurrences',
      where: 'status = ? AND scheduled_date < ?',
      whereArgs: [HabitOccurrenceStatus.expected, day],
    );
    var n = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      await db.update(
        'habit_occurrences',
        {'status': HabitOccurrenceStatus.missed, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'HABIT_MISSED',
        'entity_type': 'HABIT_OCCURRENCE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.system,
      });
      n++;
    }
    return n;
  }

  Future<bool> isDoneToday(String habitId) async {
    final rows = await (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ? AND scheduled_date = ? AND status = ?',
      whereArgs: [habitId, AppDatabase.startOfTodayMs(), HabitOccurrenceStatus.completed],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> todayStatus(String habitId) async {
    final rows = await (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ? AND scheduled_date = ?',
      whereArgs: [habitId, AppDatabase.startOfTodayMs()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<int> streakDays(String habitId) async {
    final rows = await (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ? AND status = ?',
      whereArgs: [habitId, HabitOccurrenceStatus.completed],
      orderBy: 'scheduled_date DESC',
      limit: 60,
    );
    if (rows.isEmpty) return 0;
    var streak = 0;
    var cursor = DateTime.fromMillisecondsSinceEpoch(AppDatabase.startOfTodayMs());
    // Allow today incomplete without breaking streak count of previous days
    final todayDone = rows.any((r) => r['scheduled_date'] == AppDatabase.startOfTodayMs());
    if (!todayDone) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    for (var i = 0; i < 60; i++) {
      final dayMs = DateTime(cursor.year, cursor.month, cursor.day).millisecondsSinceEpoch;
      final hit = rows.any((r) => r['scheduled_date'] == dayMs);
      if (!hit) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> pause(String habitId) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'habits',
      {'status': EntityStatus.paused, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> resume(String habitId) async {
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'habits',
      {'status': EntityStatus.active, 'updated_at': now},
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

  Future<List<Map<String, Object?>>> recentOccurrences(String habitId, {int limit = 14}) async {
    return (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'scheduled_date DESC',
      limit: limit,
    );
  }
}
