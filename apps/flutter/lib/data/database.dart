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

  static const schemaVersion = 13;

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
      },
    );
  }

  Future<void> _migrateToV6(Database db) async {
    await _applySchema(db);
    await _applyV6Constraints(db);
    await _seedDefaultUser(db);
  }

  Future<void> _migrateToV7(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV8(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV9(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, 'ALTER TABLE budgets ADD COLUMN category_id TEXT');
  }

  Future<void> _migrateToV10(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV11(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV12(Database db) async {
    await _applySchema(db);

    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN description TEXT');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN milestone_id TEXT');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN scheduled_start INTEGER');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN scheduled_end INTEGER');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN estimated_minutes INTEGER');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN completed_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN archived_at INTEGER');

    await _tryAlter(db, 'ALTER TABLE habits ADD COLUMN description TEXT');
    await _tryAlter(db, 'ALTER TABLE habits ADD COLUMN archived_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE routines ADD COLUMN archived_at INTEGER');

    await _tryAlter(db, 'ALTER TABLE expenses ADD COLUMN account_id TEXT');
    await _tryAlter(db, 'ALTER TABLE expenses ADD COLUMN category_id TEXT');
    await _tryAlter(db, 'ALTER TABLE expenses ADD COLUMN payment_method TEXT');
    await _tryAlter(db, 'ALTER TABLE income ADD COLUMN account_id TEXT');
    await _tryAlter(db, 'ALTER TABLE income ADD COLUMN category_id TEXT');
    await _tryAlter(db, 'ALTER TABLE bills ADD COLUMN default_account_id TEXT');
    await _tryAlter(db, 'ALTER TABLE bills ADD COLUMN archived_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE bill_occurrences ADD COLUMN paid_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE bill_occurrences ADD COLUMN actual_amount_minor INTEGER');
    await _tryAlter(db, 'ALTER TABLE bill_occurrences ADD COLUMN expense_id TEXT');

    await _tryAlter(db, 'ALTER TABLE notes ADD COLUMN archived_at INTEGER');
    await _tryAlter(db, 'ALTER TABLE people ADD COLUMN phone TEXT');
    await _tryAlter(db, 'ALTER TABLE people ADD COLUMN archived_at INTEGER');

    await _tryAlter(db, 'ALTER TABLE budgets ADD COLUMN category_id TEXT');

    await _tryAlter(db, 'ALTER TABLE reminders ADD COLUMN message TEXT');
    await _tryAlter(db, 'ALTER TABLE reminders ADD COLUMN source_type TEXT');
    await _tryAlter(db, 'ALTER TABLE reminders ADD COLUMN source_id TEXT');

    await _tryAlter(
      db,
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_habit_occ_day ON habit_occurrences(habit_id, scheduled_date)',
    );
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_expenses_occurred ON expenses(occurred_at)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at)');

    try {
      await db.execute("UPDATE debts SET status = 'OPEN' WHERE status = 'ACTIVE'");
    } catch (_) {}
  }

  /// Project workspace: subtasks + project deadline.
  Future<void> _migrateToV13(Database db) async {
    await _applySchema(db);
    await _tryAlter(db, 'ALTER TABLE tasks ADD COLUMN parent_task_id TEXT');
    await _tryAlter(db, 'ALTER TABLE projects ADD COLUMN target_date INTEGER');
    await _tryAlter(db, 'ALTER TABLE projects ADD COLUMN description TEXT');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_task_id)');
    await _tryAlter(db, 'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id)');
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
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS uq_habit_occ_day ON habit_occurrences(habit_id, scheduled_date)',
      );
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
    final id = newId();
    await db.insert('users', {
      'id': id,
      'display_name': 'Me',
      'name': 'Me',
      'currency': Defaults.currency,
      'week_start_day': Defaults.weekStartDay,
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

  Future<T> txn<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  static String newId() => _uuid.v4();

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static int startOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  static int endOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 23, 59, 59, 999).millisecondsSinceEpoch;
  }
}
