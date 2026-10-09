import 'package:sqflite/sqflite.dart';

/// Validates cross-entity references before a write is committed.
///
/// Keep these checks at repository transaction boundaries so invalid links
/// cannot be persisted by UI or assistant callers.
class RelationshipValidator {
  RelationshipValidator._();

  static Future<void> validateGoal(
    Transaction txn, {
    required String ownerId,
    required String goalId,
  }) async {
    final rows = await txn.query(
      'goals',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [goalId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Goal not found, archived, or not owned by the current user.');
    }
  }

  static Future<void> validateProject(
    Transaction txn, {
    required String ownerId,
    required String projectId,
  }) async {
    final rows = await txn.query(
      'projects',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [projectId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Project not found, archived, or not owned by the current user.');
    }
  }

  static Future<void> validateTaskLinks(
    Transaction txn, {
    required String ownerId,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? parentTaskId,
    String? taskId,
  }) async {
    if (projectId != null) {
      await validateProject(txn, ownerId: ownerId, projectId: projectId);
    }
    if (goalId != null) {
      await validateGoal(txn, ownerId: ownerId, goalId: goalId);
    }

    if (milestoneId != null) {
      if (projectId == null || projectId.isEmpty) {
        throw StateError('A task milestone requires a project.');
      }
      final rows = await txn.query(
        'milestones',
        columns: ['id'],
        where: 'id = ? AND project_id = ? AND owner_id = ?',
        whereArgs: [milestoneId, projectId, ownerId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('The milestone must belong to the task project and current owner.');
      }
    }

    if (parentTaskId != null) {
      if (taskId != null && parentTaskId == taskId) {
        throw StateError('A task cannot be its own parent.');
      }
      final rows = await txn.query(
        'tasks',
        columns: ['id', 'project_id'],
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [parentTaskId, ownerId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Parent task not found, archived, or not owned by the current user.');
      }
      final parentProjectId = rows.first['project_id'] as String?;
      if (parentProjectId != projectId) {
        throw StateError('Parent and child tasks must belong to the same project.');
      }
    }
  }
}
