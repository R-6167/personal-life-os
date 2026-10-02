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
    final db = await _db.database;
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
    await db.insert('habits', habit.toInsertMap());
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'HABIT_CREATED',
      'entity_type': 'HABIT',
      'entity_id': habit.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
    return habit;
  }

  Future<void> markDoneToday(String habitId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final dayStart = DateTime.now();
    final scheduledDate = DateTime(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;

    await db.insert('habit_occurrences', {
      'id': AppDatabase.newId(),
      'habit_id': habitId,
      'scheduled_date': scheduledDate,
      'status': HabitOccurrenceStatus.completed,
      'completed_at': now,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'HABIT_COMPLETED',
      'entity_type': 'HABIT_OCCURRENCE',
      'entity_id': habitId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': '{"scheduledDate":$scheduledDate}',
    });
  }
}
