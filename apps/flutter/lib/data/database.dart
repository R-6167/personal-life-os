import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/enums.dart';

/// Local SQLite — schema from assets/schema.sql (Flutter MVP subset of contract).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _uuid = Uuid();

  /// Bump when schema.sql changes so onUpgrade re-applies cleanly.
  static const schemaVersion = 2;

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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _applySchema(db);
        await _seedDefaultUser(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Dev-friendly: rebuild from assets when schema version changes.
        await _dropAllTables(db);
        await _applySchema(db);
        await _seedDefaultUser(db);
      },
    );
  }

  Future<void> _dropAllTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final row in rows) {
      final name = row['name'] as String?;
      if (name == null) continue;
      await db.execute('DROP TABLE IF EXISTS $name');
    }
  }

  Future<void> _applySchema(Database db) async {
    final raw = await rootBundle.loadString('assets/schema.sql');
    final statements = _splitSql(raw);
    for (final stmt in statements) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      if (s.toUpperCase().startsWith('PRAGMA')) continue; // already set in onConfigure
      await db.execute(s);
    }
  }

  /// Strip -- comments (including mid-line) then split on ;
  /// so semicolons inside comments cannot truncate CREATE TABLE.
  List<String> _splitSql(String raw) {
    final withoutBlock = raw.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
    final buf = StringBuffer();
    for (final line in withoutBlock.split('\n')) {
      final idx = line.indexOf('--');
      if (idx >= 0) {
        buf.writeln(line.substring(0, idx));
      } else {
        buf.writeln(line);
      }
    }
    return buf
        .toString()
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _seedDefaultUser(Database db) async {
    final existing = await db.query('users', limit: 1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.insert('users', {
      'id': id,
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
    if (rows.isEmpty) {
      throw StateError('No user row — schema seed failed');
    }
    return rows.first['id'] as String;
  }

  static String newId() => _uuid.v4();

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
