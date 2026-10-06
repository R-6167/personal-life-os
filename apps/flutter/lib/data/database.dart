import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/enums.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _uuid = Uuid();

  static const schemaVersion = 21;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  void resetHandle() {
    _db = null;
  }

  @visibleForTesting
  void attachForTest(Database db) {
    _db = db;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'personal_life_os.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {}
        try {
          await db.execute('PRAGMA synchronous = NORMAL');
        } catch (_) {}
        try {
          await db.execute('PRAGMA temp_store = MEMORY');
        } catch (_) {}
      },
      onCreate: (db, version) async {
        await _applySchema(db);
        await _seedDefaultUser(db);
        await _applyV6Constraints(db);
        await _migrateToV12(db);
        await _migrateToV13(db);
        await _migrateToV14(db);
        await _migrateToV15(db);
        await _migrateToV16(db);
        await _migrateToV17(db);
        await _migrateToV18(db);
        await _migrateToV19(db);
        await _migrateToV20(db);
        await _migrateToV21(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 6) await _migrateToV6(db);
        if (oldVersion < 7) await _migrateToV7(db);
        if (oldVersion < 8) await _migrateToV8(db);
        if (oldVersion < 9) await _migrateToV9(db);
        if (oldVersion < 10) await _migrateToV10(db);
        if (oldVersion < 11) await _migrateToV11(db);
        if (oldVersion < 12) await _migrateToV12(db);
        if (oldVersion < 13) await _migrateToV13(db);
        if (oldVersion < 14) await _migrateToV14(db);
        if (oldVersion < 15) await _migrateToV15(db);
        if (oldVersion < 16) await _migrateToV16(db);
        if (oldVersion < 17) await _migrateToV17(db);
        if (oldVersion < 18) await _migrateToV18(db);
        if (oldVersion < 19) await _migrateToV19(db);
        if (oldVersion < 20) await _migrateToV20(db);
        if (oldVersion < 21) await _migrateToV21(db);
      },
    );
  }

  Future<void> _migrateToV6(Database db) async {
    await _applySchema(db);
    await _applyV6Constraints(db);
  }

  Future<void> _migrateToV7(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV8(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV9(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV10(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV11(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV12(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at)');
  }

  Future<void> _migrateToV13(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV14(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV15(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, '''
      CREATE TABLE IF NOT EXISTS work_sessions (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        task_id TEXT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        status TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_work_sessions_task ON work_sessions(task_id)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_work_sessions_status ON work_sessions(status)');
  }

  Future<void> _migrateToV16(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, 'ALTER TABLE subscriptions ADD COLUMN frequency TEXT');
    await _tryAlter(db, 'ALTER TABLE subscriptions ADD COLUMN next_renewal_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE subscriptions ADD COLUMN default_account_id TEXT');
  }

  Future<void> _migrateToV17(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV18(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV19(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN interval_n INTEGER');
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN start_date INTEGER');
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN until_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN enabled INTEGER DEFAULT 1');
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN count INTEGER');
    await _tryAlter(db, 'ALTER TABLE task_recurrences ADD COLUMN by_month_days TEXT');
    try {
      await db.execute('UPDATE task_recurrences SET interval_n = interval WHERE interval_n IS NULL AND interval IS NOT NULL');
    } catch (_) {}
    try {
      await db.execute('UPDATE task_recurrences SET interval = interval_n WHERE interval IS NULL AND interval_n IS NOT NULL');
    } catch (_) {}
    try {
      await db.execute('UPDATE task_recurrences SET until_at = end_at WHERE until_at IS NULL AND end_at IS NOT NULL');
    } catch (_) {}
    try {
      await db.execute('UPDATE task_recurrences SET end_at = until_at WHERE end_at IS NULL AND until_at IS NOT NULL');
    } catch (_) {}
    try {
      await db.execute('UPDATE task_recurrences SET enabled = 1 WHERE enabled IS NULL');
    } catch (_) {}
  }

  Future<void> _migrateToV20(Database db) async {
    await _applySchema(db);
    try {
      await db.execute('''
        DELETE FROM routine_occurrences WHERE id NOT IN (
          SELECT MAX(id) FROM routine_occurrences GROUP BY routine_id, scheduled_date
        )
      ''');
    } catch (_) {}
    await _tryAlter(db, 'CREATE UNIQUE INDEX IF NOT EXISTS uq_routine_occ_day ON routine_occurrences(routine_id, scheduled_date)');
    await _tryAlter(db, 'CREATE UNIQUE INDEX IF NOT EXISTS uq_habit_occ_day ON habit_occurrences(habit_id, scheduled_date)');
    await _tryAlter(db, 'ALTER TABLE habit_schedules ADD COLUMN interval INTEGER');
    await _tryAlter(db, 'ALTER TABLE routine_schedules ADD COLUMN interval INTEGER');
    await _tryAlter(db, 'ALTER TABLE bills ADD COLUMN interval INTEGER');
  }

  /// Activity history: durable indexes for life timeline + entity trails.
  Future<void> _migrateToV21(Database db) async {
    await _applySchema(db);
    await _tryAlter(
      db,
      'CREATE INDEX IF NOT EXISTS idx_activity_owner_occurred ON activity_events(owner_id, occurred_at DESC)',
    );
    await _tryAlter(
      db,
      'CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at DESC)',
    );
    await _tryAlter(
      db,
      'CREATE INDEX IF NOT EXISTS idx_activity_entity ON activity_events(entity_type, entity_id, occurred_at DESC)',
    );
    await _tryAlter(
      db,
      'CREATE INDEX IF NOT EXISTS idx_activity_event_type ON activity_events(event_type, occurred_at DESC)',
    );
    await _tryAlter(db, 'ALTER TABLE activity_events ADD COLUMN summary TEXT');
  }

  Future<void> _tryAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {}
  }

  Future<void> _applyV6Constraints(Database db) async {
    try {
      await db.execute('''
        DELETE FROM habit_occurrences WHERE id NOT IN (
          SELECT MAX(id) FROM habit_occurrences GROUP BY habit_id, scheduled_date
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS uq_habit_occ_day ON habit_occurrences(habit_id, scheduled_date)');
    } catch (_) {}
  }

  Future<void> _applySchema(Database db) async {
    final raw = await rootBundle.loadString('assets/schema.sql');
    for (final stmt in _splitSql(raw)) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      await db.execute(s);
    }
  }

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

  Future<void> _seedDefaultUser(Database db) async {
    final existing = await db.query('users', limit: 1);
    if (existing.isNotEmpty) return;
    final now = nowMs();
    await db.insert('users', {
      'id': newId(),
      'display_name': 'Me',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<String> requireOwnerId() async {
    final db = await database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) {
      await _seedDefaultUser(db);
      final again = await db.query('users', limit: 1);
      return again.first['id'] as String;
    }
    return rows.first['id'] as String;
  }

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static int startOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  static int endOfTodayMs() =>
      startOfTodayMs() + const Duration(days: 1).inMilliseconds - 1;

  static String newId() => _uuid.v4();
}
