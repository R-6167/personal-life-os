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

  Future<Habit> create({required String title}) async {
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
      await txn.insert('habits', habit.toInsertMap());
      await txn.insert('habit_schedules', {
        'id': AppDatabase.newId(),
        'habit_id': habit.id,
        'frequency': 'DAILY',
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
    return habit;
  }

  Future<void> markDoneToday(String habitId) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final scheduledDate = AppDatabase.startOfTodayMs();
    await _db.txn((txn) async {
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
}
