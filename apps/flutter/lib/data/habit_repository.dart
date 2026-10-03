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
        'enabled': 1,
        'start_date': now,
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
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final db = await _db.database;
    final existing = await db.query(
      'habit_occurrences',
      where: 'habit_id = ? AND expected_at >= ? AND expected_at <= ?',
      whereArgs: [habitId, start, end],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await db.insert('habit_occurrences', {
      'id': id,
      'habit_id': habitId,
      'expected_at': now,
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
        'entity_type': 'HABIT_OCCURRENCE',
        'entity_id': occId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  /// Alias used by home/life hubs.
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
        'entity_type': 'HABIT_OCCURRENCE',
        'entity_id': occId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
        'metadata': reason != null ? '{"reason":"$reason"}' : null,
      });
    });
  }

  Future<int> markMissedBeforeToday() async {
    final start = AppDatabase.startOfTodayMs();
    final db = await _db.database;
    return db.rawUpdate(
      "UPDATE habit_occurrences SET status = ?, updated_at = ? "
      "WHERE status = ? AND expected_at < ?",
      [
        HabitOccurrenceStatus.missed,
        AppDatabase.nowMs(),
        HabitOccurrenceStatus.expected,
        start,
      ],
    );
  }

  Future<String?> todayStatus(String habitId) async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final rows = await (await _db.database).query(
      'habit_occurrences',
      where: 'habit_id = ? AND expected_at >= ? AND expected_at <= ?',
      whereArgs: [habitId, start, end],
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
      orderBy: 'expected_at DESC',
      limit: 90,
    );
    if (rows.isEmpty) return 0;
    var streak = 0;
    var day = DateTime.now();
    final completedDays = <String>{};
    for (final r in rows) {
      final ms = r['expected_at'] as int? ?? r['completed_at'] as int? ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      completedDays.add('${d.year}-${d.month}-${d.day}');
    }
    for (var i = 0; i < 90; i++) {
      final key = '${day.year}-${day.month}-${day.day}';
      if (completedDays.contains(key)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else if (i == 0) {
        day = day.subtract(const Duration(days: 1));
      } else {
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
      {
        'status': EntityStatus.archived,
        'archived_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> setSchedule({
    required String habitId,
    required String frequency,
    String? daysOfWeek,
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
        'enabled': 1,
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'habit_schedules',
        {
          'frequency': frequency,
          'days_of_week': daysOfWeek,
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
      orderBy: 'expected_at DESC',
      limit: limit,
    );
  }
}
