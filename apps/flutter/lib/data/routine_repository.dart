import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class RoutineRepository {
  RoutineRepository(this._db);
  final AppDatabase _db;

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
      'description': description,
      'estimated_minutes': estimatedMinutes,
      'status': EntityStatus.active,
      'created_at': now,
      'updated_at': now,
    });
    return Routine(
      id: id,
      ownerId: ownerId,
      name: name,
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<Map<String, Object?>>> listSteps(String routineId) async {
    return (await _db.database).query(
      'routine_steps',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'sort_order ASC',
    );
  }

  Future<void> addStep(String routineId, String title, {int? estimatedMinutes}) async {
    final db = await _db.database;
    final existing = await listSteps(routineId);
    await db.insert('routine_steps', {
      'id': AppDatabase.newId(),
      'routine_id': routineId,
      'title': title,
      'sort_order': existing.length,
      'estimated_minutes': estimatedMinutes,
      'created_at': AppDatabase.nowMs(),
      'updated_at': AppDatabase.nowMs(),
    });
  }

  Future<String?> ensureTodayOccurrence(String routineId) async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final db = await _db.database;
    final existing = await db.query(
      'routine_occurrences',
      where: 'routine_id = ? AND expected_at >= ? AND expected_at <= ?',
      whereArgs: [routineId, start, end],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await db.insert('routine_occurrences', {
      'id': id,
      'routine_id': routineId,
      'expected_at': now,
      'status': RoutineOccurrenceStatus.expected,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> ensureAllTodayOccurrences() async {
    final routines = await listActive();
    for (final r in routines) {
      await ensureTodayOccurrence(r.id);
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
    final start = AppDatabase.startOfTodayMs();
    final db = await _db.database;
    return db.rawUpdate(
      "UPDATE routine_occurrences SET status = ?, updated_at = ? "
      "WHERE status = ? AND expected_at < ?",
      [
        RoutineOccurrenceStatus.missed,
        AppDatabase.nowMs(),
        RoutineOccurrenceStatus.expected,
        start,
      ],
    );
  }

  Future<List<Map<String, Object?>>> listMissed({int limit = 20}) async {
    return (await _db.database).query(
      'routine_occurrences',
      where: 'status = ?',
      whereArgs: [RoutineOccurrenceStatus.missed],
      orderBy: 'expected_at DESC',
      limit: limit,
    );
  }

  Future<String?> todayStatus(String routineId) async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final rows = await (await _db.database).query(
      'routine_occurrences',
      where: 'routine_id = ? AND expected_at >= ? AND expected_at <= ?',
      whereArgs: [routineId, start, end],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<void> setSchedule({
    required String routineId,
    required String frequency,
    String? daysOfWeek,
    int? preferredTime,
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
        'enabled': 1,
        'start_date': now,
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
