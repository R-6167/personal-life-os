import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
import 'database.dart';
import 'relationship_validator.dart';

class MilestoneRepository {
  MilestoneRepository(this._db);
  final AppDatabase _db;

  Future<List<Milestone>> listForProject(String projectId) async {
    final ownerId = await _db.requireOwnerId();
    final rows = await (await _db.database).query(
      'milestones',
      where: 'project_id = ? AND owner_id = ?',
      whereArgs: [projectId, ownerId],
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(Milestone.fromMap).toList();
  }

  Future<Milestone> create({required String projectId, required String title}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Milestone title must not be empty.');
    }
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: projectId,
        );
        final rows = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), -1) AS max_position '
          'FROM milestones WHERE project_id = ? AND owner_id = ?',
          [projectId, ownerId],
        );
        final position = ((rows.first['max_position'] as int?) ?? -1) + 1;
        await txn.insert('milestones', {
          'id': id,
          'owner_id': ownerId,
          'project_id': projectId,
          'title': cleanTitle,
          'status': MilestoneStatus.planned,
          'position': position,
          'created_at': now,
          'updated_at': now,
        });
      },
      eventType: 'MILESTONE_CREATED',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
    );
    return Milestone(
      id: id,
      projectId: projectId,
      title: cleanTitle,
      status: MilestoneStatus.planned,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> complete(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.query(
          'milestones',
          columns: ['id', 'project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Milestone not found or not owned by the current user: $id');
        }
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: rows.first['project_id'] as String,
        );
        final changed = await txn.update(
          'milestones',
          {
            'status': MilestoneStatus.completed,
            'completed_at': now,
            'updated_at': now,
          },
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Milestone not found or not owned by the current user: $id');
        }
      },
      eventType: 'MILESTONE_COMPLETED',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
    );
  }
}
