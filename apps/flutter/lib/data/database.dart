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

  static const schemaVersion = 22;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Run [action] inside a SQLite transaction on the opened database.
  Future<T> txn<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction<T>(action);
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

  Future<void> _applySchema(Database db) async {
    final sql = await rootBundle.loadString('assets/schema.sql');
    for (final stmt in sql.split(';')) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      try {
        await db.execute(s);
      } catch (_) {}
    }
  }

  Future<void> _seedDefaultUser(Database db) async {
    final now = nowMs();
    await db.insert('users', {
      'id': newId(),
      'display_name': 'Me',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _applyV6Constraints(Database db) async {}

  Future<void> _migrateToV6(Database db) async {
    await _applySchema(db);
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
  }

  Future<void> _migrateToV13(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV14(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV15(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV16(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV17(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV18(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV19(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV20(Database db) async {
    await _applySchema(db);
  }

  Future<void> _migrateToV21(Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_owner_occurred ON activity_events(owner_id, occurred_at DESC)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_entity ON activity_events(entity_type, entity_id)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_event_type ON activity_events(event_type)',
      );
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE activity_events ADD COLUMN summary TEXT');
    } catch (_) {}
  }

  Future<String> requireOwnerId() async {
    final db = await database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) {
      final id = newId();
      final now = nowMs();
      await db.insert('users', {
        'id': id,
        'display_name': 'Me',
        'created_at': now,
        'updated_at': now,
      });
      return id;
    }
    return rows.first['id'] as String;
  }

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static int startOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  static int endOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 23, 59, 59, 999).millisecondsSinceEpoch;
  }

  static int endOfDayMs(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch +
      const Duration(days: 1).inMilliseconds - 1;

  static String newId() => _uuid.v4();
}
