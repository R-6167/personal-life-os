import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class GoalRepository {
  GoalRepository(this._db);
  final AppDatabase _db;

  Future<List<Goal>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'goals',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'priority DESC, created_at DESC',
    );
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal> create({required String title}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final goal = Goal(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('goals', goal.toInsertMap());
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'GOAL_CREATED',
      'entity_type': 'GOAL',
      'entity_id': goal.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
    return goal;
  }

  Future<void> complete(String id) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await db.update(
      'goals',
      {
        'status': EntityStatus.completed,
        'completed_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'GOAL_COMPLETED',
      'entity_type': 'GOAL',
      'entity_id': id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
  }
}
