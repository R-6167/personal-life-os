import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Future<List<Task>> listOpen() async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: "status != ? AND (archived_at IS NULL)",
      whereArgs: [EntityStatus.completed],
      orderBy: 'priority DESC, due_at ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task> create({required String title, String status = EntityStatus.inbox}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final task = Task(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('tasks', task.toInsertMap());
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'TASK_CREATED',
      'entity_type': 'TASK',
      'entity_id': task.id,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
    return task;
  }

  Future<void> complete(String taskId) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await db.update(
      'tasks',
      {
        'status': EntityStatus.completed,
        'completed_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'TASK_COMPLETED',
      'entity_type': 'TASK',
      'entity_id': taskId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
    });
  }
}
