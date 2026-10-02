import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/enums.dart';

/// Local SQLite — schema from assets/schema.sql (copy of src/db/schema.sql).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _uuid = Uuid();

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
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _applySchema(db);
        await _seedDefaultUser(db);
      },
    );
  }

  Future<void> _applySchema(Database db) async {
    final raw = await rootBundle.loadString('assets/schema.sql');
    // Split on semicolons; skip empty / comment-only chunks carefully.
    final statements = _splitSql(raw);
    for (final stmt in statements) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      await db.execute(s);
    }
  }

  List<String> _splitSql(String raw) {
    final lines = raw.split('\n').where((l) {
      final t = l.trim();
      return t.isNotEmpty && !t.startsWith('--');
    });
    final cleaned = lines.join('\n');
    return cleaned.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _seedDefaultUser(Database db) async {
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
