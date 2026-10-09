import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/domain/enums.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<String> _splitSql(String raw) {
  final out = <String>[];
  final buf = StringBuffer();
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.startsWith('--')) continue;
    buf.writeln(line);
    if (t.endsWith(';')) {
      out.add(buf.toString());
      buf.clear();
    }
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

Future<AppDatabase> openTestDb() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final schemaPath = File('assets/schema.sql');
  if (!await schemaPath.exists()) {
    throw StateError('assets/schema.sql not found (run tests from apps/flutter)');
  }
  final raw = await schemaPath.readAsString();

  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onConfigure: (d) async {
      await d.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (d, _) async {
      for (final stmt in _splitSql(raw)) {
        final s = stmt.trim();
        if (s.isEmpty) continue;
        await d.execute(s);
      }
      // Soft columns used by repositories but not always in minimal schema.
      for (final alter in [
        'ALTER TABLE notes ADD COLUMN archived_at INTEGER',
        'ALTER TABLE goals ADD COLUMN archived_at INTEGER',
        'ALTER TABLE projects ADD COLUMN archived_at INTEGER',
        'ALTER TABLE habits ADD COLUMN archived_at INTEGER',
        'ALTER TABLE habits ADD COLUMN goal_id TEXT',
        'ALTER TABLE habit_schedules ADD COLUMN target_count INTEGER DEFAULT 1',
        'ALTER TABLE habit_schedules ADD COLUMN updated_at INTEGER',
        'ALTER TABLE habit_occurrences ADD COLUMN completed_at INTEGER',
        'ALTER TABLE goals ADD COLUMN target_date INTEGER',
        'ALTER TABLE goals ADD COLUMN description TEXT',
        'ALTER TABLE projects ADD COLUMN description TEXT',
        'ALTER TABLE projects ADD COLUMN target_date INTEGER',
        'ALTER TABLE milestones ADD COLUMN completed_at INTEGER',
        'ALTER TABLE milestones ADD COLUMN position INTEGER DEFAULT 0',
        'ALTER TABLE tasks ADD COLUMN description TEXT',
        'ALTER TABLE documents ADD COLUMN notes TEXT',
        "ALTER TABLE entity_links ADD COLUMN relation TEXT DEFAULT 'RELATED'",
      ]) {
        try {
          await d.execute(alter);
        } catch (_) {}
      }
      final now = AppDatabase.nowMs();
      await d.insert('users', {
        'id': AppDatabase.newId(),
        'display_name': 'Me',
        'name': 'Me',
        'currency': Defaults.currency,
        'week_start_day': Defaults.weekStartDay,
        'created_at': now,
        'updated_at': now,
      });
    },
  );

  final app = AppDatabase.instance;
  await app.close();
  app.attachForTest(db);
  return app;
}

Future<void> closeTestDb() async {
  await AppDatabase.instance.close();
  AppDatabase.instance.resetHandle();
}
