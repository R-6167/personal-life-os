import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
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
      await d.execute(
        'CREATE TABLE IF NOT EXISTS work_sessions ('
        'id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, task_id TEXT, time_block_id TEXT, '
        "status TEXT NOT NULL DEFAULT 'RUNNING', planned_start INTEGER, planned_end INTEGER, "
        'planned_minutes INTEGER, started_at INTEGER NOT NULL, ended_at INTEGER, paused_at INTEGER, '
        'accumulated_ms INTEGER NOT NULL DEFAULT 0, interrupt_count INTEGER NOT NULL DEFAULT 0, '
        'note TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      );
      final now = AppDatabase.nowMs();
      await d.insert('users', {
        'id': AppDatabase.newId(),
        'display_name': 'Me',
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
