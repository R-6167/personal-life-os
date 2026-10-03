import 'dart:convert';

import '../data/database.dart';
import '../data/export_service.dart';

class IntegrityReport {
  IntegrityReport({
    required this.ok,
    required this.checks,
    this.fixed = 0,
  });

  final bool ok;
  final List<String> checks;
  final int fixed;
}

/// Offline integrity: duplicate protection, orphan soft-checks, backup round-trip verify.
class IntegrityService {
  IntegrityService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<IntegrityReport> run({bool repair = true}) async {
    final checks = <String>[];
    var fixed = 0;
    final db = await _db.database;

    // Users
    final users = await db.query('users');
    checks.add(users.isEmpty ? 'FAIL: no user row' : 'OK: ${users.length} user(s)');

    // Duplicate habit occurrences (same habit + day)
    try {
      final dups = await db.rawQuery('''
        SELECT habit_id, scheduled_date, COUNT(*) AS c
        FROM habit_occurrences
        GROUP BY habit_id, scheduled_date
        HAVING c > 1
      ''');
      if (dups.isEmpty) {
        checks.add('OK: no duplicate habit occurrences');
      } else {
        checks.add('WARN: ${dups.length} duplicate habit day groups');
        if (repair) {
          await db.execute('''
            DELETE FROM habit_occurrences WHERE id NOT IN (
              SELECT MAX(id) FROM habit_occurrences GROUP BY habit_id, scheduled_date
            )
          ''');
          fixed += dups.length;
          checks.add('FIXED: removed duplicate habit occurrences');
        }
      }
    } catch (e) {
      checks.add('SKIP: habit occurrence dedupe ($e)');
    }

    // Duplicate bill occurrences same bill + due_at
    try {
      final dups = await db.rawQuery('''
        SELECT bill_id, due_at, COUNT(*) AS c
        FROM bill_occurrences
        GROUP BY bill_id, due_at
        HAVING c > 1
      ''');
      if (dups.isEmpty) {
        checks.add('OK: no duplicate bill occurrences');
      } else {
        checks.add('WARN: ${dups.length} duplicate bill occurrence groups');
        if (repair) {
          await db.execute('''
            DELETE FROM bill_occurrences WHERE id NOT IN (
              SELECT MAX(id) FROM bill_occurrences GROUP BY bill_id, due_at
            )
          ''');
          fixed += dups.length;
          checks.add('FIXED: removed duplicate bill occurrences');
        }
      }
    } catch (e) {
      checks.add('SKIP: bill occurrence dedupe ($e)');
    }

    // Activity events present
    final events = await db.rawQuery('SELECT COUNT(*) AS c FROM activity_events');
    final eventCount = (events.first['c'] as int?) ?? 0;
    checks.add('OK: $eventCount activity events');

    // Orphan tasks pointing at missing goals (soft — only report)
    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM tasks t
        WHERE t.goal_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM goals g WHERE g.id = t.goal_id)
      ''');
      final n = (orphans.first['c'] as int?) ?? 0;
      checks.add(n == 0 ? 'OK: task→goal links valid' : 'WARN: $n tasks with missing goal');
    } catch (_) {
      checks.add('SKIP: task→goal check');
    }

    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM projects p
        WHERE p.goal_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM goals g WHERE g.id = p.goal_id)
      ''');
      final n = (orphans.first['c'] as int?) ?? 0;
      checks.add(n == 0 ? 'OK: project→goal links valid' : 'WARN: $n projects with missing goal');
    } catch (_) {}

    // Budgets with category
    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM budgets b
        WHERE b.category_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM categories c WHERE c.id = b.category_id)
      ''');
      final n = (orphans.first['c'] as int?) ?? 0;
      checks.add(n == 0 ? 'OK: budget→category links valid' : 'WARN: $n budgets with missing category');
    } catch (_) {}

    final ok = !checks.any((c) => c.startsWith('FAIL'));
    return IntegrityReport(ok: ok, checks: checks, fixed: fixed);
  }

  /// Export → parse → structural verify (does not re-import unless called).
  Future<IntegrityReport> verifyBackupJson(String raw) async {
    final checks = <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return IntegrityReport(ok: false, checks: ['FAIL: not a JSON object']);
      }
      final map = Map<String, dynamic>.from(decoded);
      checks.add(map['contractVersion'] != null
          ? 'OK: contractVersion ${map['contractVersion']}'
          : 'WARN: missing contractVersion');
      checks.add(map['exportedAt'] != null ? 'OK: exportedAt present' : 'WARN: no exportedAt');
      var tablesWithRows = 0;
      for (final t in ExportService.tables) {
        final rows = map[t] ?? map[_toCamel(t)];
        if (rows is List && rows.isNotEmpty) tablesWithRows++;
      }
      checks.add(tablesWithRows > 0
          ? 'OK: $tablesWithRows tables with data'
          : 'WARN: backup has no table data');
      // Spot-check ids on goals/tasks if present
      for (final t in ['goals', 'tasks', 'expenses', 'activity_events']) {
        final rows = map[t];
        if (rows is! List || rows.isEmpty) continue;
        var missingId = 0;
        for (final r in rows.take(50)) {
          if (r is Map && r['id'] == null && r['Id'] == null) missingId++;
        }
        checks.add(missingId == 0
            ? 'OK: $t rows have ids (sampled)'
            : 'WARN: $t has $missingId rows without id');
      }
      final ok = !checks.any((c) => c.startsWith('FAIL'));
      return IntegrityReport(ok: ok, checks: checks);
    } catch (e) {
      return IntegrityReport(ok: false, checks: ['FAIL: $e']);
    }
  }

  String _toCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }
}
