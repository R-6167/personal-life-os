import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/services/notification_diagnostics.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('notification failure is persisted with structured local context', () async {
    await NotificationDiagnostics.record(
      'schedule_reminder',
      StateError('platform rejected schedule'),
      details: {'reminderId': 'reminder-1', 'sourceType': 'TASK'},
    );

    final rows = await (await db.database).query(
      'error_logs',
      where: "message LIKE ?",
      whereArgs: ['Notification schedule_reminder failed:%'],
    );

    expect(rows, hasLength(1));
    expect(rows.single['level'], 'ERROR');
    expect(rows.single['owner_id'], await db.requireOwnerId());
    final context = jsonDecode(rows.single['context'] as String) as Map<String, dynamic>;
    expect(context['subsystem'], 'notifications');
    expect(context['operation'], 'schedule_reminder');
    expect(context['reminderId'], 'reminder-1');
    expect(context['sourceType'], 'TASK');
  });
}
