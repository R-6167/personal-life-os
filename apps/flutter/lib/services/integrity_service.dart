import 'dart:convert';

import '../data/database.dart';
import '../data/export_service.dart';
import '../domain/db_map.dart';

class IntegrityReport {
  IntegrityReport({
    required this.ok,
    required this.checks,
    this.fixed = 0,
  });

  final bool ok;
  final List<String> checks;
  final int fixed;

  String get summary {
    final head = ok ? 'Integrity OK' : 'Integrity issues';
    final body = checks.take(6).join(' · ');
    final fix = fixed > 0 ? ' · fixed $fixed' : '';
    return '$head$fix · $body';
  }
}

/// Offline integrity: duplicates, orphans, status vocabulary, backup shape.
class IntegrityService {
  IntegrityService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<IntegrityReport> run({bool repair = true}) async {
    final checks = <String>[];
    var fixed = 0;
    final db = await _db.database;

    final users = await db.query('users');
    checks.add(users.isEmpty ? 'FAIL: no user row' : 'OK: ${users.length} user(s)');

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
          checks.add('FIXED: habit occurrence duplicates');
        }
      }
    } catch (e) {
      checks.add('SKIP: habit occurrence dedupe ($e)');
    }

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
        checks.add('WARN: ${dups.length} duplicate bill groups');
        if (repair) {
          await db.execute('''
            DELETE FROM bill_occurrences WHERE id NOT IN (
              SELECT MAX(id) FROM bill_occurrences GROUP BY bill_id, due_at
            )
          ''');
          fixed += dups.length;
          checks.add('FIXED: bill occurrence duplicates');
        }
      }
    } catch (e) {
      checks.add('SKIP: bill occurrence dedupe ($e)');
    }

    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM task_dependencies d
        WHERE NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = d.task_id)
           OR NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = d.depends_on_task_id)
      ''');
      final c = dbIntOr(orphans.first['c']);
      if (c == 0) {
        checks.add('OK: task dependencies');
      } else {
        checks.add('WARN: $c orphan task dependencies');
        if (repair) {
          await db.execute('''
            DELETE FROM task_dependencies WHERE
              NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = task_id)
              OR NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = depends_on_task_id)
          ''');
          fixed += c;
          checks.add('FIXED: orphan task dependencies');
        }
      }
    } catch (e) {
      checks.add('SKIP: dependency check ($e)');
    }

    try {
      final bad = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM debts WHERE status = 'ACTIVE'",
      );
      final c = dbIntOr(bad.first['c']);
      if (c == 0) {
        checks.add('OK: debt status vocabulary');
      } else {
        checks.add('WARN: $c debts with ACTIVE status');
        if (repair) {
          await db.execute("UPDATE debts SET status = 'OPEN' WHERE status = 'ACTIVE'");
          fixed += c;
          checks.add('FIXED: debt ACTIVE → OPEN');
        }
      }
    } catch (e) {
      checks.add('SKIP: debt status ($e)');
    }

    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM bill_occurrences o
        WHERE NOT EXISTS (SELECT 1 FROM bills b WHERE b.id = o.bill_id)
      ''');
      final c = dbIntOr(orphans.first['c']);
      if (c == 0) {
        checks.add('OK: bill occurrences linked');
      } else {
        checks.add('WARN: $c orphan bill occurrences');
        if (repair) {
          await db.execute('''
            DELETE FROM bill_occurrences WHERE NOT EXISTS (
              SELECT 1 FROM bills b WHERE b.id = bill_id
            )
          ''');
          fixed += c;
          checks.add('FIXED: orphan bill occurrences');
        }
      }
    } catch (e) {
      checks.add('SKIP: bill orphan check ($e)');
    }

    try {
      final neg = await db.rawQuery('''
        SELECT
          (SELECT COUNT(*) FROM expenses WHERE amount_minor < 0) +
          (SELECT COUNT(*) FROM income WHERE amount_minor < 0) AS c
      ''');
      final c = dbIntOr(neg.first['c']);
      checks.add(c == 0 ? 'OK: non-negative money amounts' : 'WARN: $c negative money rows');
    } catch (e) {
      checks.add('SKIP: money sign check ($e)');
    }

    try {
      final empty = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM tasks WHERE title IS NULL OR trim(title) = ''
      ''');
      final c = dbIntOr(empty.first['c']);
      if (c == 0) {
        checks.add('OK: task titles present');
      } else {
        checks.add('WARN: $c tasks with empty title');
        if (repair) {
          await db.execute(
            "UPDATE tasks SET title = 'Untitled' WHERE title IS NULL OR trim(title) = ''",
          );
          fixed += c;
          checks.add('FIXED: empty task titles');
        }
      }
    } catch (e) {
      checks.add('SKIP: task title check ($e)');
    }

    final ok = checks.every((c) => !c.startsWith('FAIL'));
    return IntegrityReport(ok: ok, checks: checks, fixed: fixed);
  }

  Future<IntegrityReport> verifyBackupJson(String raw) async {
    final checks = <String>[];
    try {
      if (raw.isEmpty) {
        return IntegrityReport(ok: false, checks: ['FAIL: empty backup']);
      }
      if (raw.length > ExportService.maxRawChars) {
        return IntegrityReport(ok: false, checks: ['FAIL: backup exceeds size limit']);
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return IntegrityReport(ok: false, checks: ['FAIL: not a JSON object']);
      }
      final map = Map<String, dynamic>.from(decoded);

      final app = map['app']?.toString();
      if (app != null && !ExportService.legacyAppTags.contains(app)) {
        checks.add('FAIL: app tag is $app');
      } else if (app != null) {
        checks.add('OK: app tag ($app)');
      } else {
        checks.add('WARN: missing app tag (legacy backup?)');
      }

      if (map.containsKey('schemaVersion') || map.containsKey('contractVersion')) {
        checks.add('OK: version metadata');
      } else {
        checks.add('WARN: no schema/contract version');
      }

      var tableHits = 0;
      for (final t in ExportService.tables) {
        if (map.containsKey(t) || map.containsKey(_toCamel(t))) tableHits++;
      }
      if (tableHits == 0 && map['tables'] is Map) {
        tableHits = (map['tables'] as Map).length;
        checks.add('OK: nested tables map ($tableHits)');
      } else if (tableHits > 0) {
        checks.add('OK: $tableHits known tables present');
      } else {
        checks.add('FAIL: no recognizable table data');
      }

      final hasUsers = map['users'] is List || map['Users'] is List;
      if (!hasUsers && tableHits < 2) {
        checks.add('WARN: thin backup (few tables)');
      }

      final ok = checks.every((c) => !c.startsWith('FAIL'));
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
