import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/domain/enums.dart';
import 'package:ordin/domain/models.dart';
import 'package:ordin/services/ordin_operator.dart';

import '../helpers/test_db.dart';

void main() {
  late final AppDatabase db;

  setUp(() async {
    db = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('action executor atomically reschedules a task and records the action', () async {
    final task = await dbTestTask();
    final day = DateTime(2030, 1, 15).millisecondsSinceEpoch;

    final result = await OrdinOperator(db: db).execute(
      OrdinActionProposal(
        id: 'proposal-1',
        kind: OrdinIntentKind.rescheduleTaskToday,
        title: 'Reschedule',
        rationale: 'test',
        preview: 'Move task',
        entityType: 'TASK',
        entityId: task.id,
        payload: {'dayMs': day},
      ),
    );

    expect(result.ok, isTrue);

    final rows = await (await db.database).query(
      'tasks',
      columns: ['due_at'],
      where: 'id = ?',
      whereArgs: [task.id],
      limit: 1,
    );
    expect(rows.single['due_at'], DateTime(2030, 1, 15, 23, 59).millisecondsSinceEpoch);

    final events = await (await db.database).query(
      'activity_events',
      where: 'event_type = ? AND entity_id = ?',
      whereArgs: ['ASSISTANT_ACTION_EXECUTED', task.id],
    );
    expect(events, hasLength(1));
    expect(events.single['source'], EventSource.system);
  });

  test('action executor rejects a stale proposal for another owner', () async {
    final task = await dbTestTask();
    final otherOwner = 'other-owner';
    final now = DateTime.now().millisecondsSinceEpoch;
    await (await db.database).insert('users', {
      'id': otherOwner,
      'display_name': 'Other',
      'name': 'Other',
      'currency': Defaults.currency,
      'week_start_day': Defaults.weekStartDay,
      'created_at': now,
      'updated_at': now,
    });
    await (await db.database).insert('tasks', {
      'id': 'foreign-task',
      'owner_id': otherOwner,
      'title': 'Foreign task',
      'status': EntityStatus.inbox,
      'priority': 0,
      'created_at': now,
      'updated_at': now,
    });

    final result = await OrdinOperator(db: db).execute(
      OrdinActionProposal(
        id: 'proposal-2',
        kind: OrdinIntentKind.completeTask,
        title: 'Complete',
        rationale: 'test',
        preview: 'Complete foreign',
        entityType: 'TASK',
        entityId: 'foreign-task',
      ),
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('not owned'));

    final rows = await (await db.database).query(
      'tasks',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: ['foreign-task'],
      limit: 1,
    );
    expect(rows.single['status'], EntityStatus.inbox);
  });
}

Future<Task> dbTestTask() async {
  final ownerId = await AppDatabase.instance.requireOwnerId();
  final now = AppDatabase.nowMs();
  final task = Task(
    id: AppDatabase.newId(),
    ownerId: ownerId,
    title: 'Action boundary task',
    status: EntityStatus.inbox,
    priority: 0,
    createdAt: now,
    updatedAt: now,
  );
  await (await AppDatabase.instance.database).insert('tasks', task.toInsertMap());
  return task;
}
