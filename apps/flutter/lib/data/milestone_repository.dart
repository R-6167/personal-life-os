import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
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
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.update(
          'milestones',
          {
            'status': MilestoneStatus.completed,
            'completed_at': now,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      eventType: 'MILESTONE_COMPLETED',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
    );
  }
}
