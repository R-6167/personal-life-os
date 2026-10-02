import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';

class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  static const tables = [
    'users', 'categories', 'people', 'goals', 'projects', 'milestones', 'tasks',
    'task_dependencies', 'task_recurrences', 'habits', 'habit_schedules', 'habit_occurrences',
    'routines', 'routine_steps', 'routine_schedules', 'routine_occurrences',
    'calendar_events', 'time_blocks', 'reminders', 'notes', 'entity_links',
    'financial_accounts', 'income', 'expenses', 'bills', 'bill_occurrences',
    'subscriptions', 'debts', 'debt_payments', 'savings_goals', 'savings_contributions',
    'practical_items', 'documents', 'shopping_lists', 'shopping_items', 'activity_events',
  ];

  Future<String> buildBackupJson() async {
    final db = await _db.database;
    final data = <String, dynamic>{
      'contractVersion': 1,
      'exportedAt': AppDatabase.nowMs(),
      'app': 'personal-life-os',
    };
    for (final t in tables) {
      try {
        final rows = await db.query(t);
        data[t] = rows.map(_camel).toList();
      } catch (_) {
        data[t] = [];
      }
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Validate + import. Never wipes existing user unless [replaceUsers] is true.
  /// Returns counts of inserted rows by table.
  Future<ImportResult> importBackupJson(String raw, {bool replaceUsers = false}) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return ImportResult(ok: false, message: 'Invalid JSON');
    }
    if (decoded is! Map) {
      return ImportResult(ok: false, message: 'Backup must be a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map['contractVersion'] == null && map['goals'] == null && map['tasks'] == null) {
      return ImportResult(ok: false, message: 'Unrecognized backup (missing tables)');
    }

    final inserted = <String, int>{};
    var total = 0;

    await _db.txn((txn) async {
      for (final table in tables) {
        if (table == 'users' && !replaceUsers) continue;
        final rows = map[table] ?? map[_toCamel(table)];
        if (rows is! List) continue;
        var n = 0;
        for (final row in rows) {
          if (row is! Map) continue;
          final snake = <String, Object?>{};
          row.forEach((k, v) {
            snake[_toSnake('$k')] = v;
          });
          if (snake['id'] == null) continue;
          try {
            await txn.insert(table, snake, conflictAlgorithm: ConflictAlgorithm.ignore);
            n++;
          } catch (_) {}
        }
        if (n > 0) {
          inserted[table] = n;
          total += n;
        }
      }
    });

    return ImportResult(
      ok: true,
      message: total == 0
          ? 'No new rows imported (may already exist)'
          : 'Imported $total rows across ${inserted.length} tables',
      inserted: inserted,
      total: total,
    );
  }

  Future<List<Map<String, Object?>>> recentActivity({int limit = 40}) async {
    final db = await _db.database;
    return db.query(
      'activity_events',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
  }

  Map<String, dynamic> _camel(Map<String, Object?> row) {
    final out = <String, dynamic>{};
    row.forEach((k, v) => out[_toCamel(k)] = v);
    return out;
  }

  String _toCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }

  String _toSnake(String camel) {
    return camel.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  }
}

class ImportResult {
  ImportResult({
    required this.ok,
    required this.message,
    this.inserted = const {},
    this.total = 0,
  });
  final bool ok;
  final String message;
  final Map<String, int> inserted;
  final int total;
}
