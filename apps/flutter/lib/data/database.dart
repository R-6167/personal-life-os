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
  static const schemaVersion = 3;

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
    for (final stmt in _splitSql(raw)) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      if (s.toUpperCase().startsWith('PRAGMA')) continue;
      await db.execute(s);
    }
  }

  List<String> _splitSql(String raw) {
    final withoutBlock = raw.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
    final buf = StringBuffer();
    for (final line in withoutBlock.split('\n')) {
      final idx = line.indexOf('--');
      buf.writeln(idx >= 0 ? line.substring(0, idx) : line);
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

  static String newId() => _uuid.v4();
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
