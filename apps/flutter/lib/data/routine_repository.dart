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
      where: 'status = ?',
      whereArgs: [EntityStatus.active],
      orderBy: 'created_at DESC',
    );
    return rows.map(Routine.fromMap).toList();
  }

  Future<Routine?> getById(String id) async {
    final rows = await (await _db.database).query('routines', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Routine.fromMap(rows.first);
  }

  Future<Routine> create({required String name, String? description, int? estimatedMinutes}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await _db.txn((txn) async {
      await txn.insert('routines', {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'description': description,
        'status': EntityStatus.active,
        'estimated_minutes': estimatedMinutes,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('routine_schedules', {
        'id': AppDatabase.newId(),
        'routine_id': id,
        'frequency': 'DAILY',
        'enabled': 1,
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'ROUTINE_CREATED',
        'entity_type': 'ROUTINE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
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

  Future<void> addStep(String routineId, String title, {bool optional = false, int? estimatedMinutes}) async {
    final now = AppDatabase.nowMs();
    final steps = await listSteps(routineId);
    final position = steps.length;
    await (await _db.database).insert('routine_steps', {
      'id': AppDatabase.newId(),
      'routine_id': routineId,
      'title': title,
      'position': position,
      'optional': optional ? 1 : 0,
      'estimated_minutes': estimatedMinutes,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> removeStep(String stepId) async {
    await (await _db.database).delete('routine_steps', where: 'id = ?', whereArgs: [stepId]);
  }

  Future<void> setStepOptional(String stepId, bool optional) async {
    await (await _db.database).update(
      'routine_steps',
      {'optional': optional ? 1 : 0, 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [stepId],
    );
  }

  Future<void> setSchedule({equired String routineId, required String frequency, String? daysOfWeek, int? preferredTime}) async {
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
          'enabled': 1,
          'updated_at': now,
        },
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );
    }
  }

  Future<String?> ensureTodayOccurrence(String routineId) async {
    final day = AppDatabase.startOfTodayMs();
    final db = await _db.database;
    final existing = await db.query(
      'routine_occurrences',
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, day],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await db.insert('routine_occurrences', {
      'id': id,
      'routine_id': routineId,
      'scheduled_date': day,
      'status': RoutineOccurrenceStatus.expected,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> ensureAllTodayOccurrences() async {
    for (final r in await listActive()) {
      await ensureTodayOccurrence(r.id);
    }
  }

  Future<void> startToday(String routineId) async {
    final now = AppDatabase.nowMs();
    final day = AppDatabase.startOfTodayMs();
    await ensureTodayOccurrence(routineId);
    await (await _db.database).update(
      'routine_occurrences',
      {'status': RoutineOccurrenceStatus.started, 'started_at': now, 'updated_at': now},
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, day],
    );
  }

  Future<void> completeToday(String routineId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final day = AppDatabase.startOfTodayMs();
    await ensureTodayOccurrence(routineId);
    await _db.txn((txn) async {
      final rows = await txn.query(
        'routine_occurrences',
        where: 'routine_id = ? AND scheduled_date = ?',
        whereArgs: [routineId, day],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final occId = rows.first['id'] as String;
      await txn.update(
        'routine_occurrences',
        {
          'status': RoutineOccurrenceStatus.completed,
          'started_at': rows.first['started_at'] ?? now,
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

  Future<void> skipToday(String routineId) async {
    final now = AppDatabase.nowMs();
    final day = AppDatabase.startOfTodayMs();
    await ensureTodayOccurrence(routineId);
    await (await _db.database).update(
      'routine_occurrences',
      {'status': RoutineOccurrenceStatus.skipped, 'updated_at': now},
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, day],
    );
  }

  /// Recover a missed occurrence by completing it late.
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
    final ownerId = await _db.requireOwnerId();
    final day = AppDatabase.startOfTodayMs();
    final now = AppDatabase.nowMs();
    final db = await _db.database;
    final rows = await db.query(
      'routine_occurrences',
      where: 'status IN (?, ?) AND scheduled_date < ?',
      whereArgs: [RoutineOccurrenceStatus.expected, RoutineOccurrenceStatus.started, day],
    );
    var n = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      await db.update(
        'routine_occurrences',
        {'status': RoutineOccurrenceStatus.missed, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'ROUTINE_MISSED',
        'entity_type': 'ROUTINE_OCCURRENCE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.system,
      });
      n++;
    }
    return n;
  }

  Future<List<Map<String, Object?>>> listMissed({int limit = 20}) async {
    return (await _db.database).rawQuery('''
      SELECT o.*, r.name AS routine_name
      FROM routine_occurrences o
      JOIN routines r ON r.id = o.routine_id
      WHERE o.status = ?
      ORDER BY o.scheduled_date DESC
      LIMIT ?
    ''', [RoutineOccurrenceStatus.missed, limit]);
  }

  Future<String?> todayStatus(String routineId) async {
    final rows = await (await _db.database).query(
      'routine_occurrences',
      where: 'routine_id = ? AND scheduled_date = ?',
      whereArgs: [routineId, AppDatabase.startOfTodayMs()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }
}
