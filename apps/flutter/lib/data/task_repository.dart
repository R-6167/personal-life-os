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
      where: "status != ? AND status != ? AND (archived_at IS NULL)",
      whereArgs: [EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> listOverdue() async {
    final open = await listOpen();
    return open.where((t) => t.isOverdue).toList();
  }

  Future<List<Task>> listDueToday() async {
    final open = await listOpen();
    return open.where((t) => t.isDueToday || t.isOverdue).toList();
  }

  Future<Task> create({required String title, String status = EntityStatus.inbox, int? dueAt}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final task = Task(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      status: status,
      dueAt: dueAt,
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
    await _db.txn((txn) async {
      final now = AppDatabase.nowMs();
      final ownerId = await _db.requireOwnerId();
      await txn.update(
        'tasks',
        {'status': EntityStatus.completed, 'completed_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_COMPLETED',
        'entity_type': 'TASK',
        'entity_id': taskId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
