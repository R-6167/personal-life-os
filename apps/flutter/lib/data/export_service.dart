import 'dart:convert';

import 'database.dart';

/// Contract-shaped JSON backup (camelCase), offline only.
class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  Future<String> buildBackupJson() async {
    final db = await _db.database;
    final users = await db.query('users');
    final goals = await db.query('goals');
    final projects = await db.query('projects');
    final tasks = await db.query('tasks');
    final habits = await db.query('habits');
    final notes = await db.query('notes');
    final expenses = await db.query('expenses');
    final events = await db.query('activity_events');

    final payload = {
      'contractVersion': 1,
      'exportedAt': AppDatabase.nowMs(),
      'user': users.isEmpty ? null : _camel(users.first),
      'goals': goals.map(_camel).toList(),
      'projects': projects.map(_camel).toList(),
      'tasks': tasks.map(_camel).toList(),
      'habits': habits.map(_camel).toList(),
      'notes': notes.map(_camel).toList(),
      'expenses': expenses.map(_camel).toList(),
      'activityEvents': events.map(_camel).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> _camel(Map<String, Object?> row) {
    final out = <String, dynamic>{};
    row.forEach((k, v) {
      out[_toCamel(k)] = v;
    });
    return out;
  }

  String _toCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }
}
