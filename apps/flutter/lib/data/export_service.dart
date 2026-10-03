import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';
import '../services/integrity_service.dart';

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
    'practical_items', 'documents', 'shopping_lists', 'shopping_items',
    'wellness_checkins', 'health_metrics', 'goal_reflections', 'budgets',
    'app_usage_events', 'error_logs', 'feedback_items',
    'activity_events',
  ];

  /// Hard limit on decoded backup text size (chars).
  static const maxRawChars = 30 * 1024 * 1024;

  Future<String> buildBackupJson() async {
    final db = await _db.database;
    final data = <String, dynamic>{
      'contractVersion': 2,
      'exportedAt': AppDatabase.nowMs(),
      'app': 'personal-life-os',
      'schemaVersion': AppDatabase.schemaVersion,
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

  Future<ImportResult> importBackupJson(String raw, {bool replaceUsers = false}) async {
    if (raw.length > maxRawChars) {
      return ImportResult(
        ok: false,
        message: 'Backup too large (${(raw.length / 1024).toStringAsFixed(0)} KB).',
      );
    }

    final verify = await IntegrityService(db: _db).verifyBackupJson(raw);
    if (!verify.ok) {
      return ImportResult(ok: false, message: verify.checks.join('; '));
    }

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

    // Reject non-PLOS payloads that happen to be JSON objects.
    final app = map['app']?.toString();
    if (app != null && app != 'personal-life-os') {
      return ImportResult(
        ok: false,
        message: 'Unrecognized backup app tag: $app',
      );
    }

    final inserted = <String, int>{};
    var total = 0;
    var skipped = 0;

    await _db.txn((txn) async {
      for (final table in tables) {
        if (table == 'users' && !replaceUsers) continue;
        final rows = map[table] ?? map[_toCamel(table)];
        if (rows is! List) continue;
        var n = 0;
        for (final row in rows) {
          if (row is! Map) {
            skipped++;
            continue;
          }
          final snake = <String, Object?>{};
          row.forEach((k, v) {
            final key = _toSnake('$k');
            final sanitized = _sanitizeValue(v);
            if (sanitized != null || v == null) {
              snake[key] = sanitized;
            }
          });
          if (snake['id'] == null) {
            skipped++;
            continue;
          }
          // id must be a short non-empty string
          final id = snake['id'];
          if (id is! String || id.isEmpty || id.length > 80) {
            skipped++;
            continue;
          }
          try {
            await txn.insert(table, snake, conflictAlgorithm: ConflictAlgorithm.ignore);
            n++;
          } catch (_) {
            skipped++;
          }
        }
        if (n > 0) {
          inserted[table] = n;
          total += n;
        }
      }
    });

    final report = await IntegrityService(db: _db).run(repair: true);

    final skipNote = skipped > 0 ? ' Skipped $skipped invalid rows.' : '';
    return ImportResult(
      ok: true,
      message: total == 0
          ? 'No new rows imported (may already exist). Integrity: ${report.checks.length} checks.$skipNote'
          : 'Imported $total rows across ${inserted.length} tables. Integrity fixed ${report.fixed}.$skipNote',
      inserted: inserted,
      total: total,
    );
  }

  /// Only allow primitives SQLite can store safely.
  Object? _sanitizeValue(Object? v) {
    if (v == null) return null;
    if (v is bool) return v ? 1 : 0;
    if (v is int) return v;
    if (v is double) {
      if (v.isNaN || v.isInfinite) return null;
      return v;
    }
    if (v is String) {
      // Cap pathological strings
      return v.length > 50000 ? v.substring(0, 50000) : v;
    }
    // Nested objects/arrays not supported in column cells
    return null;
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
