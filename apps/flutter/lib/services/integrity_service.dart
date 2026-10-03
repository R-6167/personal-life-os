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

  String get summary {
    final head = ok ? 'Integrity OK' : 'Integrity issues';
    final body = checks.take(6).join(' · ');
    final fix = fixed > 0 ? ' · fixed $fixed' : '';
    return '$head$fix · $body';
  }
}

/// Offline integrity: duplicate protection, orphan soft-checks, backup round-trip verify.
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
          checks.add('FIXED: removed duplicate habit occurrences');
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

    try {
      final orphans = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM task_dependencies d
        WHERE NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = d.task_id)
           OR NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = d.depends_on_task_id)
      ''');
      final c = (orphans.first['c'] as int?) ?? 0;
      checks.add(c == 0 ? 'OK: task dependencies' : 'WARN: $c orphan task dependencies');
    } catch (e) {
      checks.add('SKIP: dependency check ($e)');
    }

    final ok = checks.every((c) => !c.startsWith('FAIL'));
    return IntegrityReport(ok: ok, checks: checks, fixed: fixed);
  }

  Future<IntegrityReport> verifyBackupJson(String raw) async {
    final checks = <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return IntegrityReport(ok: false, checks: ['FAIL: not a JSON object']);
      }
      final map = decoded as Map<String, dynamic>;
      checks.add(map.containsKey('tables') || map.containsKey('version')
          ? 'OK: backup shape'
          : 'WARN: unusual backup keys');
      if (map['tables'] is Map) {
        final tables = map['tables'] as Map;
        checks.add('OK: ${tables.length} tables in backup');
      }
      final ok = checks.every((c) => !c.startsWith('FAIL'));
      return IntegrityReport(ok: ok, checks: checks);
    } catch (e) {
      return IntegrityReport(ok: false, checks: ['FAIL: $e']);
    }
  }
}
