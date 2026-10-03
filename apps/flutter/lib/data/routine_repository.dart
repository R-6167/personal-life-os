import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/domain_recurrence.dart';
import 'database.dart';

class RoutineRepository {
  RoutineRepository(this._db);
  final AppDatabase _db;

  static int dayKey([DateTime? day]) {
    final d = day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  Future<List<Routine>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'routines',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'name ASC',
    );
    return rows.map(Routine.fromMap).toList();
  }

  Future<Routine?> getById(String id) async {
    final rows = await (await _db.database).query('routines', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Routine.fromMap(rows.first);
  }

  Future<Routine> create({
    required String name,
    String? description,
    int? estimatedMinutes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('routines', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'status': EntityStatus.active,
      'created_at': now,
      'updated_at': now,
    });
    return Routine(
      id: id,
      ownerId: ownerId,
      name: name,
      status: EntityStatus.active,
      estimatedMinutes: estimatedMinutes,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<Map<String, Object?>>> listSteps(String routineId) async {
    return (await _db.database).query(
      'routine_steps',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'position ASC',
    );
  }

  Future<void> addStep(String routineId, String title, {int? estimatedMinutes}) async {
    final db = await _db.database;
    final existing = await listSteps(routineId);
    await db.insert('routine_steps', {
      'id': AppDatabase.newId(),
      'routine_id': routineId,
      'title': title,
      'position': existing.length,
      'estimated_minutes': estimatedMinutes,
      'created_at': AppDatabase.nowMs(),
      'updated_at': AppDatabase.nowMs(),
    });
  }

  Future<Map<String, Object?>?> scheduleOf(String routineId) async {
    final rows = await (await _db.database).query(
      'routine_schedules',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> ensureTodayOccurrence(String routineId) async {
    final day = dayKey();
    final db = await _db.database;
    final existing = await db.query(
      'routine_occurrences',
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, day],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final sch = await scheduleOf(routineId);
    if (sch != null) {
      final rule = DomainRecurrence.ruleFromScheduleMap(
        sch,
        fallbackStart: DateTime.fromMillisecondsSinceEpoch(day),
      );
      if (!DomainRecurrence.occursOn(rule, DateTime.fromMillisecondsSinceEpoch(day))) {
        return null;
      }
    }

    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    try {
      await db.insert('routine_occurrences', {
        'id': id,
        'routine_id': routineId,
        'scheduled_date': day,
        'status': RoutineOccurrenceStatus.expected,
        'created_at': now,
        'updated_at': now,
      });
    } catch (_) {
      final again = await db.query(
        'routine_occurrences',
        where: 'routine_id = ? AND scheduled_date = ?',
        whereArgs: [routineId, day],
        limit: 1,
      );
      if (again.isNotEmpty) return again.first['id'] as String;
      rethrow;
    }
    return id;
  }

  Future<void> ensureAllTodayOccurrences() async {
    final routines = await listActive();
    for (final r in routines) {
      try {
        await ensureTodayOccurrence(r.id);
      } catch (_) {}
    }
  }

  Future<void> completeToday(String routineId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final occId = await ensureTodayOccurrence(routineId);
    if (occId == null) return;
    await _db.txn((txn) async {
      await txn.update(
        'routine_occurrences',
        {
          'status': RoutineOccurrenceStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [occId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'ROUTINE_COMPLETED',
        'entity_type': 'ROUTINE_OCCURRENCE',
        'entity_id': occId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> recoverMissed(String occurrenceId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _db.txn((txn) async {
      await txn.update(
        'routine_occurrences',
        {
          'status': RoutineOccurrenceStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [occurrenceId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'ROUTINE_RECOVERED',
        'entity_type': 'ROUTINE_OCCURRENCE',
        'entity_id': occurrenceId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<int> markMissedBeforeToday() async {
    final day = dayKey();
    final db = await _db.database;
    return db.rawUpdate(
      'UPDATE routine_occurrences SET status = ?, updated_at = ? '
      'WHERE status = ? AND scheduled_date < ?',
      [
        RoutineOccurrenceStatus.missed,
        AppDatabase.nowMs(),
        RoutineOccurrenceStatus.expected,
        day,
      ],
    );
  }

  Future<List<Map<String, Object?>>> listMissed({int limit = 20}) async {
    return (await _db.database).query(
      'routine_occurrences',
      where: 'status = ?',
      whereArgs: [RoutineOccurrenceStatus.missed],
      orderBy: 'scheduled_date DESC',
      limit: limit,
    );
  }

  Future<String?> todayStatus(String routineId) async {
    final day = dayKey();
    final rows = await (await _db.database).query(
      'routine_occurrences',
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, day],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<void> setSchedule({
    required String routineId,
    required String frequency,
    String? daysOfWeek,
    String? preferredTime,
  }) async {
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query('routine_schedules', where: 'routine_id = ?', whereArgs: [routineId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('routine_schedules', {
        'id': AppDatabase.newId(),
        'routine_id': routineId,
        'frequency': frequency,
        'days_of_week': daysOfWeek,
        'preferred_time': preferredTime,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'routine_schedules',
        {
          'frequency': frequency,
          'days_of_week': daysOfWeek,
          'preferred_time': preferredTime,
          'updated_at': now,
        },
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );
    }
  }
}
