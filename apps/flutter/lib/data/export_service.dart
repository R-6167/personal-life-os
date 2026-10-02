import 'dart:convert';

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
