import 'atomic_write.dart';
import 'database.dart';

/// Dependency mutations mixed into [TaskRepository].
mixin TaskDependencyMutations {
  AppDatabase get dependencyDb;

  /// Declare that [taskId] is blocked until [dependsOnTaskId] is done.
  /// Rejects self-links, missing/foreign tasks, duplicates, and cycles.
  Future<void> addDependency({
    required String taskId,
    required String dependsOnTaskId,
  }) async {
    if (taskId == dependsOnTaskId) {
      throw ArgumentError('A task cannot depend on itself.');
    }
    final ownerId = await dependencyDb.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: dependencyDb,
      state: (txn) async {
        Future<Map<String, Object?>?> loadTask(String id) async {
          final rows = await txn.query(
            'tasks',
            columns: ['id', 'owner_id', 'archived_at'],
            where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
            limit: 1,
          );
          return rows.isEmpty ? null : rows.first;
        }

        if (await loadTask(taskId) == null) {
          throw StateError('Task not found or not owned: $taskId');
        }
        if (await loadTask(dependsOnTaskId) == null) {
          throw StateError('Dependency target not found or not owned: $dependsOnTaskId');
        }

        final existing = await txn.query(
          'task_dependencies',
          columns: ['id'],
          where: 'task_id = ? AND depends_on_task_id = ?',
          whereArgs: [taskId, dependsOnTaskId],
          limit: 1,
        );
        if (existing.isNotEmpty) return;

        final seen = <String>{};
        final queue = <String>[dependsOnTaskId];
        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          if (!seen.add(current)) continue;
          if (current == taskId) {
            throw StateError('Adding this dependency would create a cycle.');
          }
          final rows = await txn.query(
            'task_dependencies',
            columns: ['depends_on_task_id'],
            where: 'task_id = ?',
            whereArgs: [current],
          );
          for (final row in rows) {
            final next = row['depends_on_task_id'] as String?;
            if (next != null) queue.add(next);
          }
        }

        await txn.insert('task_dependencies', {
          'id': AppDatabase.newId(),
          'task_id': taskId,
          'depends_on_task_id': dependsOnTaskId,
          'created_at': now,
        });
      },
      eventType: 'TASK_DEPENDENCY_ADDED',
      entityType: 'TASK',
      entityId: taskId,
      occurredAt: now,
    );
  }

  Future<void> removeDependency({
    required String taskId,
    required String dependsOnTaskId,
  }) async {
    final ownerId = await dependencyDb.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: dependencyDb,
      state: (txn) async {
        final owned = await txn.query(
          'tasks',
          columns: ['id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [taskId, ownerId],
          limit: 1,
        );
        if (owned.isEmpty) {
          throw StateError('Task not found or not owned: $taskId');
        }
        await txn.delete(
          'task_dependencies',
          where: 'task_id = ? AND depends_on_task_id = ?',
          whereArgs: [taskId, dependsOnTaskId],
        );
      },
      eventType: 'TASK_DEPENDENCY_REMOVED',
      entityType: 'TASK',
      entityId: taskId,
      occurredAt: now,
    );
  }
}
