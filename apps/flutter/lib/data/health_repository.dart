import '../domain/enums.dart';
import 'database.dart';

class HealthRepository {
  HealthRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, Object?>?> todayCheckin() async {
    final ownerId = await _db.requireOwnerId();
    final day = AppDatabase.startOfTodayMs();
    final rows = await (await _db.database).query(
      'wellness_checkins',
      where: 'owner_id = ? AND day = ?',
      whereArgs: [ownerId, day],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveCheckin({
    int? mood,
    int? energy,
    double? sleepHours,
    int? stress,
    String? notes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final day = AppDatabase.startOfTodayMs();
    final now = AppDatabase.nowMs();
    final existing = await todayCheckin();
    if (existing != null) {
      await (await _db.database).update(
        'wellness_checkins',
        {
          if (mood != null) 'mood': mood,
          if (energy != null) 'energy': energy,
          if (sleepHours != null) 'sleep_hours': sleepHours,
          if (stress != null) 'stress': stress,
          if (notes != null) 'notes': notes,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      final id = AppDatabase.newId();
      await _db.txn((txn) async {
        await txn.insert('wellness_checkins', {
          'id': id,
          'owner_id': ownerId,
          'day': day,
          'mood': mood,
          'energy': energy,
          'sleep_hours': sleepHours,
          'stress': stress,
          'notes': notes,
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('activity_events', {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'event_type': 'WELLNESS_CHECKIN',
          'entity_type': 'WELLNESS_CHECKIN',
          'entity_id': id,
          'occurred_at': now,
          'recorded_at': now,
          'source': EventSource.user,
        });
      });
    }
  }

  Future<List<Map<String, Object?>>> recentCheckins({int limit = 14}) async {
    final ownerId = await _db.requireOwnerId();
    return (await _db.database).query(
      'wellness_checkins',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'day DESC',
      limit: limit,
    );
  }

  Future<void> logMetric({
    required String type,
    required double value,
    String? unit,
    String? notes,
    DateTime? when,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final measured = (when ?? DateTime.now()).millisecondsSinceEpoch;
    await (await _db.database).insert('health_metrics', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'metric_type': type,
      'value': value,
      'unit': unit,
      'measured_at': measured,
      'notes': notes,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listMetrics(String type, {int limit = 30}) async {
    final ownerId = await _db.requireOwnerId();
    return (await _db.database).query(
      'health_metrics',
      where: 'owner_id = ? AND metric_type = ?',
      whereArgs: [ownerId, type],
      orderBy: 'measured_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>> weeklySummary() async {
    final checkins = await recentCheckins(limit: 7);
    double moodSum = 0, energySum = 0, sleepSum = 0;
    var moodN = 0, energyN = 0, sleepN = 0;
    for (final c in checkins) {
      final m = c['mood'] as int?;
      final e = c['energy'] as int?;
      final s = c['sleep_hours'] as num?;
      if (m != null) {
        moodSum += m;
        moodN++;
      }
      if (e != null) {
        energySum += e;
        energyN++;
      }
      if (s != null) {
        sleepSum += s.toDouble();
        sleepN++;
      }
    }
    final exercise = await listMetrics('EXERCISE_MINUTES', limit: 7);
    var exerciseTotal = 0.0;
    for (final x in exercise) {
      exerciseTotal += (x['value'] as num).toDouble();
    }
    return {
      'checkin_days': checkins.length,
      'avg_mood': moodN == 0 ? null : moodSum / moodN,
      'avg_energy': energyN == 0 ? null : energySum / energyN,
      'avg_sleep': sleepN == 0 ? null : sleepSum / sleepN,
      'exercise_minutes_week': exerciseTotal,
    };
  }
}
