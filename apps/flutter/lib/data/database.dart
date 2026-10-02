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

  /// Bump only when adding a non-destructive migration in onUpgrade.
  static const schemaVersion = 6;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'personal_life_os.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _applySchema(db);
        await _seedDefaultUser(db);
        await _applyV6Constraints(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Never drop user data. Only additive / constraint migrations.
        if (oldVersion < 6) {
          await _migrateToV6(db);
        }
      },
    );
  }

  Future<void> _migrateToV6(Database db) async {
    // Ensure all tables from schema exist (IF NOT EXISTS is safe).
    await _applySchema(db);
    await _applyV6Constraints(db);
    await _seedDefaultUser(db);
  }

  Future<void> _applyV6Constraints(Database db) async {
    // Deduplicate habit occurrences before unique index (keep latest).
    try {
      await db.execute('''
        DELETE FROM habit_occurrences
        WHERE id NOT IN (
          SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (
              PARTITION BY habit_id, scheduled_date ORDER BY updated_at DESC, created_at DESC
            ) AS rn FROM habit_occurrences
          ) WHERE rn = 1
        )
      ''');
    } catch (_) {
      // SQLite without window functions: best-effort cleanup via grouped max.
      try {
        await db.execute('''
          DELETE FROM habit_occurrences WHERE id NOT IN (
            SELECT MAX(id) FROM habit_occurrences GROUP BY habit_id, scheduled_date
          )
        ''');
      } catch (_) {}
    }
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
      if (s.isEmpty || s.toUpperCase().startsWith('PRAGMA')) continue;
      try {
        await db.execute(s);
      } catch (_) {
        // Table may already exist during additive upgrade.
      }
    }
  }

  List<String> _splitSql(String raw) {
    final withoutBlock = raw.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
    final buf = StringBuffer();
    for (final line in withoutBlock.split('\n')) {
      final idx = line.indexOf('--');
      buf.writeln(idx >= 0 ? line.substring(0, idx) : line);
    }
    return buf.toString().split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _seedDefaultUser(Database db) async {
    final existing = await db.query('users', limit: 1);
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('users', {
      'id': _uuid.v4(),
      'name': 'Owner',
      'display_name': 'Me',
      'timezone': 'Africa/Nairobi',
      'locale': Defaults.locale,
      'currency': Defaults.currency,
      'week_start_day': Defaults.weekStartDay,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<String> requireOwnerId() async {
    final db = await database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) throw StateError('No user row');
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

  static int endOfTodayMs() =>
      startOfTodayMs() + const Duration(days: 1).inMilliseconds - 1;
}
