import 'dart:convert';

import 'database.dart';

class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  Future<String> buildBackupJson() async {
    final db = await _db.database;
    final tables = [
      'users', 'goals', 'projects', 'milestones', 'tasks', 'habits', 'habit_occurrences',
      'routines', 'routine_steps', 'routine_occurrences', 'notes',
      'financial_accounts', 'income', 'expenses', 'bills', 'bill_occurrences', 'activity_events',
    ];
    final data = <String, dynamic>{
      'contractVersion': 1,
      'exportedAt': AppDatabase.nowMs(),
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
}
