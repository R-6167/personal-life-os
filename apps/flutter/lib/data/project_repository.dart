import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
import 'database.dart';
import 'relationship_validator.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Future<List<Project>> listActive() async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final rows = await db.query(
      'projects',
      where: "owner_id = ? AND (status = ? OR status IS NULL OR status = '') AND archived_at IS NULL",
      whereArgs: [ownerId, EntityStatus.active],
      orderBy: 'created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<Project>> listByGoal(String goalId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final rows = await db.query(
      'projects',
      where: 'goal_id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [goalId, ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project?> getById(String id) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final rows = await db.query(
      'projects',
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.first);
  }

  Future<Project> create({required String title, String? description, String? goalId}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final project = Project(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      goalId: goalId,
      title: title.trim(),
      status: EntityStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        if (goalId != null) {
          await RelationshipValidator.validateGoal(txn, ownerId: ownerId, goalId: goalId);
        }
        final map = project.toInsertMap();
        if (description != null && description.trim().isNotEmpty) {
          map['description'] = description.trim();
        }
        await txn.insert('projects', map);
      },
      eventType: 'PROJECT_CREATED',
      entityType: 'PROJECT',
      entityId: project.id,
      occurredAt: now,
    );
    return project;
  }

  Future<void> linkGoal(String projectId, String? goalId) async {
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await RelationshipValidator.validateProject(
        txn,
        ownerId: ownerId,
        projectId: projectId,
      );
      if (goalId != null) {
        await RelationshipValidator.validateGoal(
          txn,
          ownerId: ownerId,
          goalId: goalId,
        );
      }
      await txn.update(
        'projects',
        {'goal_id': goalId, 'updated_at': AppDatabase.nowMs()},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [projectId, ownerId],
      );
    });
  }

  Future<void> updateMeta({
    required String id,
    String? title,
    String? description,
    int? targetDate,
    bool clearTarget = false,
  }) async {
    final patch = <String, Object?>{'updated_at': AppDatabase.nowMs()};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description.isEmpty ? null : description;
    if (clearTarget) {
      patch['target_date'] = null;
    } else if (targetDate != null) {
      patch['target_date'] = targetDate;
    }
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await RelationshipValidator.validateProject(
        txn,
        ownerId: ownerId,
        projectId: id,
      );
      final changed = await txn.update(
        'projects',
        patch,
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [id, ownerId],
      );
      if (changed != 1) {
        throw StateError('Project not found or not owned by the current user: $id');
      }
    });
  }

  Future<Map<String, int>> progress(String projectId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final total = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE owner_id = ? AND project_id = ? "
      "AND archived_at IS NULL AND COALESCE(status, '') != 'CANCELLED'",
      [ownerId, projectId],
    );
    final done = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE owner_id = ? AND project_id = ? "
      "AND archived_at IS NULL AND status = 'COMPLETED'",
      [ownerId, projectId],
    );
    final mt = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM milestones WHERE owner_id = ? AND project_id = ?',
      [ownerId, projectId],
    );
    final md = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM milestones WHERE owner_id = ? AND project_id = ? AND status = 'COMPLETED'",
      [ownerId, projectId],
    );
    return {
      'total': (total.first['c'] as int?) ?? 0,
      'done': (done.first['c'] as int?) ?? 0,
      'tasksTotal': (total.first['c'] as int?) ?? 0,
      'tasksDone': (done.first['c'] as int?) ?? 0,
      'milestonesTotal': (mt.first['c'] as int?) ?? 0,
      'milestonesDone': (md.first['c'] as int?) ?? 0,
    };
  }

  Future<void> complete(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await RelationshipValidator.validateProject(txn, ownerId: ownerId, projectId: id);
        final changed = await txn.update(
          'projects',
          {'status': EntityStatus.completed, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Project not found or not owned by the current user: $id');
        }
      },
      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }
}
