import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

class MilestoneRepository {
  MilestoneRepository(this._db);
  final AppDatabase _db;

  Future<List<Milestone>> listForProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'milestones',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(Milestone.fromMap).toList();
  }

  Future<Milestone> create({required String projectId, required String title}) async {
    final db = await _db.database;
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await db.insert('milestones', {
      'id': id,
      'project_id': projectId,
      'title': title,
      'status': MilestoneStatus.planned,
      'position': 0,
      'created_at': now,
      'updated_at': now,
    });
    return Milestone(
      id: id,
      projectId: projectId,
      title: title,
      status: MilestoneStatus.planned,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> complete(String id) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _db.txn((txn) async {
      await txn.update(
        'milestones',
        {'status': MilestoneStatus.completed, 'completed_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'MILESTONE_COMPLETED',
        'entity_type': 'MILESTONE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }
}
