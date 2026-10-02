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

  Future<Routine> create({required String name}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await _db.txn((txn) async {
      await txn.insert('routines', {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'status': EntityStatus.active,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('routine_steps', {
        'id': AppDatabase.newId(),
        'routine_id': id,
        'title': 'Step 1',
        'position': 0,
        'optional': 0,
        'created_at': now,
        'updated_at': now,
      });
    });
    return Routine(id: id, ownerId: ownerId, name: name, status: EntityStatus.active, createdAt: now, updatedAt: now);
  }

  Future<void> completeToday(String routineId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final day = AppDatabase.startOfTodayMs();
    await _db.txn((txn) async {
      final occId = AppDatabase.newId();
      await txn.insert('routine_occurrences', {
        'id': occId,
        'routine_id': routineId,
        'scheduled_date': day,
        'status': RoutineOccurrenceStatus.completed,
        'started_at': now,
        'completed_at': now,
        'created_at': now,
        'updated_at': now,
      });
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
}
