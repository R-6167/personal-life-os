import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/atomic_write.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/domain/enums.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase appDb;

  setUp(() async {
    appDb = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('task create + complete writes state and activity event', () async {
    final ownerId = await appDb.requireOwnerId();
    final tasks = TaskRepository(appDb);
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();

    final db = await appDb.database;
    await db.insert('tasks', {
      'id': id,
      'owner_id': ownerId,
      'title': 'Integration task',
      'status': EntityStatus.inbox,
      'priority': 1,
      'created_at': now,
      'updated_at': now,
    });

    await tasks.complete(id);

    final row =
        (await db.query('tasks', where: 'id = ?', whereArgs: [id])).single;
    expect(row['status'], EntityStatus.completed);
    expect(row['completed_at'], isNotNull);

    final events = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'TASK_COMPLETED'",
      whereArgs: [id],
    );
    expect(events.length, greaterThanOrEqualTo(1));
    expect(events.first['entity_type'], 'TASK');
  });

  test('AtomicWrite.run commits state + event together', () async {
    final ownerId = await appDb.requireOwnerId();
    final db = await appDb.database;
    final now = AppDatabase.nowMs();
    final taskId = AppDatabase.newId();

    await db.insert('tasks', {
      'id': taskId,
      'owner_id': ownerId,
      'title': 'Atomic pair',
      'status': EntityStatus.inbox,
      'priority': 0,
      'created_at': now,
      'updated_at': now,
    });

    await AtomicWrite.run(
      db: appDb,
      state: (txn) async {
        await txn.update(
          'tasks',
          {'status': EntityStatus.inProgress, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [taskId],
        );
      },
      eventType: 'TASK_STARTED',
      entityType: 'TASK',
      entityId: taskId,
    );

    final task =
        (await db.query('tasks', where: 'id = ?', whereArgs: [taskId])).single;
    expect(task['status'], EntityStatus.inProgress);
    final ev = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'TASK_STARTED'",
      whereArgs: [taskId],
    );
    expect(ev, isNotEmpty);
  });
}
