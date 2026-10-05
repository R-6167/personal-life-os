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

  static const schemaVersion = 20;

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

  /// Attach a pre-opened database (integration tests / sqflite_common_ffi).
  @visibleForTesting
  void attachForTest(Database db) {
    _db = db;
  }

  // NOTE: remainder of file restored from last good revision; full implementation follows in repo history if truncated.
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
      },
      onCreate: (db, version) async {
        await _applySchema(db);
        await _seedDefaultUser(db);
      },
    );
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
