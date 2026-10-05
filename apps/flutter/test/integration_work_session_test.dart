import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/domain/enums.dart';
import 'package:ordin/services/work_session_service.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase appDb;

  setUp(() async {
    appDb = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('start work session is atomic with activity event', () async {
    final ownerId = await appDb.requireOwnerId();
    final db = await appDb.database;
    final now = AppDatabase.nowMs();
    final taskId = AppDatabase.newId();

    await db.insert('tasks', {
      'id': taskId,
      'owner_id': ownerId,
      'title': 'Focus task',
      'status': EntityStatus.inbox,
      'priority': 0,
      'created_at': now,
      'updated_at': now,
    });

    final session = await WorkSessionService(appDb).start(taskId: taskId);
    expect(session.id, isNotEmpty);

    final task =
        (await db.query('tasks', where: 'id = ?', whereArgs: [taskId])).single;
    expect(task['status'], EntityStatus.inProgress);

    final events = await db.query(
      'activity_events',
      where: "entity_id = ? AND event_type = 'WORK_STARTED'",
      whereArgs: [session.id],
    );
    expect(events, isNotEmpty);

    final sessions = await db.query(
      'work_sessions',
      where: 'id = ?',
      whereArgs: [session.id],
    );
    expect(sessions.single['status'], 'RUNNING');
  });
}
