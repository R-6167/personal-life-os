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
    final body = checks.take(8).join(' · ');
    final fix = fixed > 0 ? ' · fixed $fixed' : '';
    return '$head$fix · $body';
  }
}

/// Offline integrity: FKs, orphans, duplicates, migrations, events, backups.
class IntegrityService {
  IntegrityService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Columns we expect after migrations (additive schema).
  static const expectedColumns = <String, List<String>>{
    'tasks': [
      'id', 'title', 'status', 'project_id', 'goal_id', 'due_at',
      'completed_at', 'parent_task_id', 'estimated_minutes',
    ],
    'projects': ['id', 'title', 'status', 'goal_id', 'target_date'],
    'goals': ['id', 'title', 'status', 'target_date'],
    'notes': ['id', 'content', 'title', 'archived_at'],
    'reminders': ['id', 'title', 'trigger_at', 'source_type', 'source_id', 'status'],
    'habit_occurrences': ['id', 'habit_id', 'scheduled_date', 'status'],
    'bill_occurrences': ['id', 'bill_id', 'due_at', 'status'],
    'activity_events': [
      'id', 'event_type', 'entity_type', 'entity_id', 'occurred_at', 'recorded_at',
    ],
    'entity_links': ['id'], // from_* or source_* — validated separately
    'work_sessions': ['id', 'task_id', 'status', 'started_at', 'accumulated_ms'],
    'time_blocks': ['id', 'start_at', 'end_at', 'task_id'],
  };

  Future<IntegrityReport> run({bool repair = true}) async {
    final checks = <String>[];
    var fixed = 0;
    final db = await _db.database;

    final users = await db.query('users');
    checks.add(users.isEmpty ? 'FAIL: no user row' : 'OK: ${users.length} user(s)');

    try {
      final fk = await db.rawQuery('PRAGMA foreign_keys');
      final on = fk.isNotEmpty && (fk.first.values.first == 1 || '${fk.first.values.first}' == '1');
      checks.add(on ? 'OK: foreign_keys ON' : 'WARN: foreign_keys OFF');
      if (!on && repair) {
        await db.execute('PRAGMA foreign_keys = ON');
        checks.add('FIXED: foreign_keys enabled');
        fixed++;
      }
    } catch (e) {
      checks.add('SKIP: pragma foreign_keys ($e)');
    }

    fixed += await _validateMigrations(db, checks, repair);
    fixed += await _ensureIndexes(db, checks, repair);

    fixed += await _dedupe(
      db, checks, repair,
      table: 'habit_occurrences', group: 'habit_id, scheduled_date', label: 'habit occurrences',
    );
    fixed += await _dedupe(
      db, checks, repair,
      table: 'bill_occurrences', group: 'bill_id, due_at', label: 'bill occurrences',
    );
    fixed += await _dedupe(
      db, checks, repair,
      table: 'routine_occurrences', group: 'routine_id, scheduled_date', label: 'routine occurrences',
    );
    fixed += await _dedupeEntityLinks(db, checks, repair);

    fixed += await _orphans(db, checks, repair);
    fixed += await _statusVocabulary(db, checks, repair);
    fixed += await _eventConsistency(db, checks, repair);
    fixed += await _dataQuality(db, checks, repair);
    fixed += await _timeRanges(db, checks, repair);
    fixed += await _workSessions(db, checks, repair);
    fixed += await _selfRefs(db, checks, repair);

    final ok = checks.every((c) => !c.startsWith('FAIL'));
    return IntegrityReport(ok: ok, checks: checks, fixed: fixed);
  }

  Future<int> _validateMigrations(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    for (final entry in expectedColumns.entries) {
      final table = entry.key;
      final need = entry.value;
      try {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        if (info.isEmpty) {
          checks.add('WARN: table $table missing');
          continue;
        }
        final cols = info.map((r) => '${r['name']}').toSet();
        // entity_links: accept either schema style
        if (table == 'entity_links') {
          final okFrom = cols.contains('from_type') && cols.contains('to_type');
          final okSrc = cols.contains('source_type') && cols.contains('target_type');
          if (okFrom || okSrc) {
            checks.add('OK: entity_links schema');
          } else {
            checks.add('WARN: entity_links missing link columns');
          }
          continue;
        }
        final missing = need.where((c) => !cols.contains(c)).toList();
        if (missing.isEmpty) {
          checks.add('OK: $table columns');
        } else {
          checks.add('WARN: $table missing ${missing.join(', ')}');
          if (repair) {
            for (final col in missing) {
              final type = col.endsWith('_at') ||
                      col.endsWith('_minutes') ||
                      col.endsWith('_ms') ||
                      col == 'priority' ||
                      col == 'interrupt_count'
                  ? 'INTEGER'
                  : 'TEXT';
              try {
                await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
                fixed++;
              } catch (_) {}
            }
            checks.add('FIXED: attempted ALTER for $table');
          }
        }
      } catch (e) {
        checks.add('SKIP: $table schema ($e)');
      }
    }
    return fixed;
  }

  Future<int> _ensureIndexes(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    const indexes = <String, String>{
      'uq_habit_occ_day':
          'CREATE UNIQUE INDEX IF NOT EXISTS uq_habit_occ_day ON habit_occurrences(habit_id, scheduled_date)',
      'idx_tasks_status': 'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)',
      'idx_tasks_project': 'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id)',
      'idx_activity_occurred':
          'CREATE INDEX IF NOT EXISTS idx_activity_occurred ON activity_events(occurred_at)',
      'idx_reminders_trigger':
          'CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_at)',
      'idx_work_sessions_task':
          'CREATE INDEX IF NOT EXISTS idx_work_sessions_task ON work_sessions(task_id)',
    };
    try {
      final existing = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index'");
      final names = existing.map((r) => '${r['name']}').toSet();
      var missing = 0;
      for (final e in indexes.entries) {
        if (names.contains(e.key)) continue;
        missing++;
        if (repair) {
          try {
            await db.execute(e.value);
            fixed++;
          } catch (_) {}
        }
      }
      if (missing == 0) {
        checks.add('OK: critical indexes present');
      } else {
        checks.add(repair
            ? 'FIXED: ensured $missing indexes'
            : 'WARN: $missing indexes missing');
      }
    } catch (e) {
      checks.add('SKIP: indexes ($e)');
    }
    return fixed;
  }

  Future<int> _dedupe(
    dynamic db,
    List<String> checks,
    bool repair, {
    required String table,
    required String group,
    required String label,
  }) async {
    try {
      final dups = await db.rawQuery('''
        SELECT $group, COUNT(*) AS c
        FROM $table
        GROUP BY $group
        HAVING c > 1
      ''');
      if (dups.isEmpty) {
        checks.add('OK: no duplicate $label');
        return 0;
      }
      checks.add('WARN: ${dups.length} duplicate $label groups');
      if (!repair) return 0;
      await db.execute('''
        DELETE FROM $table WHERE id NOT IN (
          SELECT MAX(id) FROM $table GROUP BY $group
        )
      ''');
      checks.add('FIXED: $label duplicates');
      return dups.length as int;
    } catch (e) {
      checks.add('SKIP: $label dedupe ($e)');
      return 0;
    }
  }

  Future<int> _dedupeEntityLinks(dynamic db, List<String> checks, bool repair) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(entity_links)');
      final cols = info.map((r) => '${r['name']}').toSet();
      final fromStyle = cols.contains('from_type');
      final group = fromStyle
          ? 'from_type, from_id, to_type, to_id'
          : 'source_type, source_id, target_type, target_id';
      final dups = await db.rawQuery('''
        SELECT $group, COUNT(*) AS c FROM entity_links
        GROUP BY $group HAVING c > 1
      ''');
      if (dups.isEmpty) {
        checks.add('OK: no duplicate entity_links');
        return 0;
      }
      checks.add('WARN: ${dups.length} duplicate entity_links');
      if (!repair) return 0;
      await db.execute('''
        DELETE FROM entity_links WHERE id NOT IN (
          SELECT MAX(id) FROM entity_links GROUP BY $group
        )
      ''');
      checks.add('FIXED: duplicate entity_links');
      return dups.length as int;
    } catch (e) {
      checks.add('SKIP: entity_links dedupe ($e)');
      return 0;
    }
  }

  Future<int> _orphans(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;

    Future<int> nullBadFk({
      required String table,
      required String column,
      required String parentTable,
      required String label,
    }) async {
      try {
        final rows = await db.rawQuery('''
          SELECT COUNT(*) AS c FROM $table t
          WHERE t.$column IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM $parentTable p WHERE p.id = t.$column)
        ''');
        final c = dbIntOr(rows.first['c']);
        if (c == 0) {
          checks.add('OK: no orphan $label');
          return 0;
        }
        checks.add('WARN: $c orphan $label');
        if (repair) {
          await db.execute('''
            UPDATE $table SET $column = NULL
            WHERE $column IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM $parentTable p WHERE p.id = $table.$column)
          ''');
          checks.add('FIXED: nullified orphan $label');
          return c;
        }
        return 0;
      } catch (e) {
        checks.add('SKIP: orphan $label ($e)');
        return 0;
      }
    }

    Future<int> deleteOrphans({
      required String table,
      required String column,
      required String parentTable,
      required String label,
    }) async {
      try {
        final rows = await db.rawQuery('''
          SELECT COUNT(*) AS c FROM $table c
          WHERE NOT EXISTS (SELECT 1 FROM $parentTable p WHERE p.id = c.$column)
        ''');
        final c = dbIntOr(rows.first['c']);
        if (c == 0) {
          checks.add('OK: no orphan $label');
          return 0;
        }
        checks.add('WARN: $c orphan $label');
        if (repair) {
          await db.execute('''
            DELETE FROM $table WHERE NOT EXISTS (
              SELECT 1 FROM $parentTable p WHERE p.id = $table.$column
            )
          ''');
          checks.add('FIXED: deleted orphan $label');
          return c;
        }
        return 0;
      } catch (e) {
        checks.add('SKIP: orphan $label ($e)');
        return 0;
      }
    }

    fixed += await nullBadFk(
      table: 'tasks', column: 'project_id', parentTable: 'projects', label: 'task→project',
    );
    fixed += await nullBadFk(
      table: 'tasks', column: 'goal_id', parentTable: 'goals', label: 'task→goal',
    );
    fixed += await nullBadFk(
      table: 'projects', column: 'goal_id', parentTable: 'goals', label: 'project→goal',
    );
    fixed += await nullBadFk(
      table: 'tasks', column: 'parent_task_id', parentTable: 'tasks', label: 'task→parent',
    );
    fixed += await nullBadFk(
      table: 'habits', column: 'goal_id', parentTable: 'goals', label: 'habit→goal',
    );
    fixed += await nullBadFk(
      table: 'time_blocks', column: 'task_id', parentTable: 'tasks', label: 'block→task',
    );
    fixed += await nullBadFk(
      table: 'work_sessions', column: 'task_id', parentTable: 'tasks', label: 'session→task',
    );

    fixed += await deleteOrphans(
      table: 'habit_occurrences', column: 'habit_id', parentTable: 'habits', label: 'habit_occ',
    );
    fixed += await deleteOrphans(
      table: 'bill_occurrences', column: 'bill_id', parentTable: 'bills', label: 'bill_occ',
    );
    fixed += await deleteOrphans(
      table: 'milestones', column: 'project_id', parentTable: 'projects', label: 'milestones',
    );
    fixed += await deleteOrphans(
      table: 'debt_payments', column: 'debt_id', parentTable: 'debts', label: 'debt_payments',
    );
    fixed += await deleteOrphans(
      table: 'savings_contributions', column: 'goal_id', parentTable: 'savings_goals', label: 'savings_contrib',
    );
    fixed += await deleteOrphans(
      table: 'shopping_items', column: 'list_id', parentTable: 'shopping_lists', label: 'shopping_items',
    );

    // entity_links — empty endpoints
    try {
      final info = await db.rawQuery('PRAGMA table_info(entity_links)');
      final cols = info.map((r) => '${r['name']}').toSet();
      final fromStyle = cols.contains('from_type');
      if (fromStyle) {
        final bad = await db.rawQuery('''
          SELECT COUNT(*) AS c FROM entity_links
          WHERE from_id IS NULL OR to_id IS NULL OR from_id = '' OR to_id = ''
        ''');
        final c = dbIntOr(bad.first['c']);
        if (c == 0) {
          checks.add('OK: entity_links endpoints');
        } else {
          checks.add('WARN: $c broken entity_links');
          if (repair) {
            await db.execute('''
              DELETE FROM entity_links
              WHERE from_id IS NULL OR to_id IS NULL OR from_id = '' OR to_id = ''
            ''');
            fixed += c;
            checks.add('FIXED: broken entity_links');
          }
        }
      } else if (cols.contains('source_type')) {
        final bad = await db.rawQuery('''
          SELECT COUNT(*) AS c FROM entity_links
          WHERE source_id IS NULL OR target_id IS NULL OR source_id = '' OR target_id = ''
        ''');
        final c = dbIntOr(bad.first['c']);
        if (c == 0) {
          checks.add('OK: entity_links endpoints');
        } else if (repair) {
          await db.execute('''
            DELETE FROM entity_links
            WHERE source_id IS NULL OR target_id IS NULL OR source_id = '' OR target_id = ''
          ''');
          fixed += c;
          checks.add('FIXED: broken entity_links');
        }
      }
    } catch (e) {
      checks.add('SKIP: entity_links ($e)');
    }

    // Reminders pointing at deleted sources (nullify, keep reminder)
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM reminders
        WHERE source_type = 'TASK' AND source_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = reminders.source_id)
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: reminder→task links');
      } else {
        checks.add('WARN: $c reminders for missing tasks');
        if (repair) {
          await db.execute('''
            UPDATE reminders SET source_id = NULL, source_type = NULL
            WHERE source_type = 'TASK' AND source_id IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = reminders.source_id)
          ''');
          fixed += c;
          checks.add('FIXED: cleared orphan reminder sources');
        }
      }
    } catch (e) {
      checks.add('SKIP: reminder sources ($e)');
    }

    return fixed;
  }

  Future<int> _statusVocabulary(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    Future<void> normalize(String table, Set<String> allowed, String fallback) async {
      try {
        final rows = await db.rawQuery(
          'SELECT DISTINCT status FROM $table WHERE status IS NOT NULL',
        );
        final bad = <String>[];
        for (final r in rows) {
          final s = '${r['status']}';
          if (!allowed.contains(s)) bad.add(s);
        }
        if (bad.isEmpty) {
          checks.add('OK: $table status vocabulary');
        } else {
          checks.add('WARN: $table unknown status ${bad.join(',')}');
          if (repair) {
            for (final s in bad) {
              await db.execute(
                'UPDATE $table SET status = ? WHERE status = ?',
                [fallback, s],
              );
              fixed++;
            }
            checks.add('FIXED: $table status → $fallback');
          }
        }
      } catch (e) {
        checks.add('SKIP: $table status ($e)');
      }
    }

    await normalize('tasks', {'INBOX', 'ACTIVE', 'DONE', 'COMPLETED', 'CANCELLED', 'ARCHIVED'}, 'ACTIVE');
    await normalize('projects', {'ACTIVE', 'DONE', 'COMPLETED', 'CANCELLED', 'ARCHIVED', 'ON_HOLD'}, 'ACTIVE');
    await normalize('goals', {'ACTIVE', 'DONE', 'COMPLETED', 'CANCELLED', 'ARCHIVED'}, 'ACTIVE');
    await normalize('reminders', {'PENDING', 'DONE', 'CANCELLED', 'SNOOZED'}, 'PENDING');
    await normalize('debts', {'OPEN', 'ACTIVE', 'PAID', 'CANCELLED'}, 'OPEN');
    await normalize('work_sessions', {'RUNNING', 'PAUSED', 'COMPLETED', 'CANCELLED'}, 'COMPLETED');

    return fixed;
  }

  Future<int> _eventConsistency(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;

    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM tasks
        WHERE status IN ('DONE','COMPLETED') AND completed_at IS NULL
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: completed tasks have completed_at');
      } else {
        checks.add('WARN: $c completed tasks missing completed_at');
        if (repair) {
          await db.execute('''
            UPDATE tasks SET completed_at = COALESCE(updated_at, created_at)
            WHERE status IN ('DONE','COMPLETED') AND completed_at IS NULL
          ''');
          fixed += c;
          checks.add('FIXED: completed_at backfilled');
        }
      }
    } catch (e) {
      checks.add('SKIP: completed_at ($e)');
    }

    try {
      final missing = await db.rawQuery('''
        SELECT t.id, t.title, t.completed_at, t.owner_id FROM tasks t
        WHERE t.status IN ('DONE','COMPLETED')
          AND NOT EXISTS (
            SELECT 1 FROM activity_events e
            WHERE e.entity_type = 'TASK' AND e.entity_id = t.id
              AND e.event_type IN ('TASK_COMPLETED','TASK_DONE')
          )
        LIMIT 50
      ''');
      if (missing.isEmpty) {
        checks.add('OK: completed tasks have completion events');
      } else {
        checks.add('WARN: ${missing.length} completed tasks without event');
        if (repair) {
          final now = AppDatabase.nowMs();
          for (final t in missing) {
            await db.insert('activity_events', {
              'id': AppDatabase.newId(),
              'owner_id': t['owner_id'] ?? (await _db.requireOwnerId()),
              'event_type': 'TASK_COMPLETED',
              'entity_type': 'TASK',
              'entity_id': t['id'],
              'occurred_at': t['completed_at'] ?? now,
              'recorded_at': now,
              'source': 'SYSTEM',
              'metadata': '{"repaired":true}',
            });
            fixed++;
          }
          checks.add('FIXED: backfilled TASK_COMPLETED events');
        }
      }
    } catch (e) {
      checks.add('SKIP: task event consistency ($e)');
    }

    try {
      final missing = await db.rawQuery('''
        SELECT o.id, o.bill_id, o.paid_at FROM bill_occurrences o
        WHERE o.status IN ('PAID','PAID_PARTIAL')
          AND NOT EXISTS (
            SELECT 1 FROM activity_events e
            WHERE e.entity_id = o.id AND e.event_type LIKE '%PAID%'
          )
        LIMIT 30
      ''');
      if (missing.isEmpty) {
        checks.add('OK: paid bills have payment events');
      } else {
        checks.add('WARN: ${missing.length} paid bills without event');
        if (repair) {
          final ownerId = await _db.requireOwnerId();
          final now = AppDatabase.nowMs();
          for (final o in missing) {
            await db.insert('activity_events', {
              'id': AppDatabase.newId(),
              'owner_id': ownerId,
              'event_type': 'BILL_PAID',
              'entity_type': 'BILL_OCCURRENCE',
              'entity_id': o['id'],
              'occurred_at': o['paid_at'] ?? now,
              'recorded_at': now,
              'source': 'SYSTEM',
              'metadata': '{"repaired":true}',
            });
            fixed++;
          }
          checks.add('FIXED: backfilled BILL_PAID events');
        }
      }
    } catch (e) {
      checks.add('SKIP: bill event consistency ($e)');
    }

    // Events with null entity_id
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM activity_events
        WHERE entity_id IS NULL OR entity_id = '' OR event_type IS NULL OR event_type = ''
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: activity_events required fields');
      } else {
        checks.add('WARN: $c incomplete activity_events');
        if (repair) {
          await db.execute('''
            DELETE FROM activity_events
            WHERE entity_id IS NULL OR entity_id = '' OR event_type IS NULL OR event_type = ''
          ''');
          fixed += c;
          checks.add('FIXED: removed incomplete events');
        }
      }
    } catch (e) {
      checks.add('SKIP: event fields ($e)');
    }

    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM activity_events e
        WHERE e.entity_type = 'TASK'
          AND NOT EXISTS (SELECT 1 FROM tasks t WHERE t.id = e.entity_id)
      ''');
      final c = dbIntOr(rows.first['c']);
      checks.add(c == 0
          ? 'OK: task events resolve'
          : 'WARN: $c task events for missing tasks (history kept)');
    } catch (e) {
      checks.add('SKIP: orphan events ($e)');
    }

    return fixed;
  }

  Future<int> _dataQuality(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    try {
      final rows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM tasks WHERE title IS NULL OR trim(title) = ''",
      );
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: task titles');
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

    try {
      final rows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM notes WHERE content IS NULL OR trim(content) = ''",
      );
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: note content');
      } else {
        checks.add('WARN: $c empty notes');
        if (repair) {
          await db.execute(
            "UPDATE notes SET content = '(empty)' WHERE content IS NULL OR trim(content) = ''",
          );
          fixed += c;
          checks.add('FIXED: empty notes');
        }
      }
    } catch (e) {
      checks.add('SKIP: note content ($e)');
    }

    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM expenses WHERE amount_minor < 0',
      );
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: expense amounts');
      } else {
        checks.add('WARN: $c negative expenses');
        if (repair) {
          await db.execute('UPDATE expenses SET amount_minor = ABS(amount_minor) WHERE amount_minor < 0');
          fixed += c;
          checks.add('FIXED: abs expense amounts');
        }
      }
    } catch (e) {
      checks.add('SKIP: expense amounts ($e)');
    }

    // Debt remaining > original
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM debts
        WHERE remaining_amount_minor > original_amount_minor
          AND original_amount_minor IS NOT NULL
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: debt remaining ≤ original');
      } else {
        checks.add('WARN: $c debts with remaining > original');
        if (repair) {
          await db.execute('''
            UPDATE debts SET remaining_amount_minor = original_amount_minor
            WHERE remaining_amount_minor > original_amount_minor
              AND original_amount_minor IS NOT NULL
          ''');
          fixed += c;
          checks.add('FIXED: capped debt remaining');
        }
      }
    } catch (e) {
      checks.add('SKIP: debt remaining ($e)');
    }

    // Savings current > target (flag only)
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM savings_goals
        WHERE current_amount_minor > target_amount_minor
          AND target_amount_minor > 0
          AND status = 'ACTIVE'
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: savings within target');
      } else {
        checks.add('WARN: $c savings goals over target (mark REACHABLE?)');
        if (repair) {
          await db.execute('''
            UPDATE savings_goals SET status = 'REACHED'
            WHERE current_amount_minor >= target_amount_minor
              AND target_amount_minor > 0 AND status = 'ACTIVE'
          ''');
          fixed += c;
          checks.add('FIXED: savings goals marked REACHED');
        }
      }
    } catch (e) {
      checks.add('SKIP: savings ($e)');
    }

    return fixed;
  }

  Future<int> _timeRanges(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM time_blocks
        WHERE end_at IS NOT NULL AND start_at IS NOT NULL AND end_at < start_at
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: time_block ranges');
      } else {
        checks.add('WARN: $c time_blocks with end < start');
        if (repair) {
          await db.execute('''
            UPDATE time_blocks SET end_at = start_at + 1800000
            WHERE end_at IS NOT NULL AND start_at IS NOT NULL AND end_at < start_at
          ''');
          fixed += c;
          checks.add('FIXED: time_block ranges (+30m)');
        }
      }
    } catch (e) {
      checks.add('SKIP: time_block ranges ($e)');
    }

    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM tasks
        WHERE scheduled_end IS NOT NULL AND scheduled_start IS NOT NULL
          AND scheduled_end < scheduled_start
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: task schedule ranges');
      } else {
        checks.add('WARN: $c tasks with scheduled_end < start');
        if (repair) {
          await db.execute('''
            UPDATE tasks SET scheduled_end = scheduled_start + 1800000
            WHERE scheduled_end IS NOT NULL AND scheduled_start IS NOT NULL
              AND scheduled_end < scheduled_start
          ''');
          fixed += c;
          checks.add('FIXED: task schedule ranges');
        }
      }
    } catch (e) {
      checks.add('SKIP: task schedule ranges ($e)');
    }

    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM calendar_events
        WHERE end_at IS NOT NULL AND start_at IS NOT NULL AND end_at < start_at
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: calendar event ranges');
      } else if (repair) {
        await db.execute('''
          UPDATE calendar_events SET end_at = start_at + 3600000
          WHERE end_at IS NOT NULL AND start_at IS NOT NULL AND end_at < start_at
        ''');
        fixed += c;
        checks.add('FIXED: calendar event ranges');
      } else {
        checks.add('WARN: $c calendar events with end < start');
      }
    } catch (e) {
      checks.add('SKIP: calendar ranges ($e)');
    }

    return fixed;
  }

  Future<int> _workSessions(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    // Stuck RUNNING sessions older than 24h → mark COMPLETED
    try {
      final cutoff = AppDatabase.nowMs() - const Duration(hours: 24).inMilliseconds;
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM work_sessions
        WHERE status = 'RUNNING' AND started_at < ?
      ''', [cutoff]);
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: no stuck work sessions');
      } else {
        checks.add('WARN: $c work sessions running >24h');
        if (repair) {
          final now = AppDatabase.nowMs();
          await db.execute('''
            UPDATE work_sessions
            SET status = 'COMPLETED', ended_at = COALESCE(ended_at, ?), updated_at = ?
            WHERE status = 'RUNNING' AND started_at < ?
          ''', [now, now, cutoff]);
          fixed += c;
          checks.add('FIXED: closed stuck work sessions');
        }
      }
    } catch (e) {
      checks.add('SKIP: work sessions ($e)');
    }

    // Negative accumulated_ms
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM work_sessions WHERE accumulated_ms < 0',
      );
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: session durations');
      } else if (repair) {
        await db.execute('UPDATE work_sessions SET accumulated_ms = 0 WHERE accumulated_ms < 0');
        fixed += c;
        checks.add('FIXED: negative session durations');
      } else {
        checks.add('WARN: $c negative session durations');
      }
    } catch (e) {
      checks.add('SKIP: session durations ($e)');
    }

    return fixed;
  }

  Future<int> _selfRefs(dynamic db, List<String> checks, bool repair) async {
    var fixed = 0;
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM tasks
        WHERE parent_task_id IS NOT NULL AND parent_task_id = id
      ''');
      final c = dbIntOr(rows.first['c']);
      if (c == 0) {
        checks.add('OK: no self-parent tasks');
      } else {
        checks.add('WARN: $c tasks parent themselves');
        if (repair) {
          await db.execute(
            'UPDATE tasks SET parent_task_id = NULL WHERE parent_task_id = id',
          );
          fixed += c;
          checks.add('FIXED: cleared self-parent tasks');
        }
      }
    } catch (e) {
      checks.add('SKIP: self-parent ($e)');
    }
    return fixed;
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
      var rowCount = 0;
      for (final t in ExportService.tables) {
        final key = map.containsKey(t)
            ? t
            : (map.containsKey(_toCamel(t)) ? _toCamel(t) : null);
        if (key == null) continue;
        tableHits++;
        final list = map[key];
        if (list is List) rowCount += list.length;
      }
      if (tableHits == 0 && map['tables'] is Map) {
        tableHits = (map['tables'] as Map).length;
        checks.add('OK: nested tables map ($tableHits)');
      } else if (tableHits > 0) {
        checks.add('OK: $tableHits known tables · $rowCount rows');
      } else {
        checks.add('FAIL: no recognizable table data');
      }

      final hasUsers = (map['users'] is List && (map['users'] as List).isNotEmpty) ||
          (map['Users'] is List && (map['Users'] as List).isNotEmpty);
      final hasTasks = map['tasks'] is List && (map['tasks'] as List).isNotEmpty;
      if (hasTasks && !hasUsers) {
        checks.add('WARN: tasks without users table (restore may reseed)');
      }

      final ok = checks.every((c) => !c.startsWith('FAIL'));
      return IntegrityReport(ok: ok, checks: checks);
    } catch (e) {
      return IntegrityReport(ok: false, checks: ['FAIL: $e']);
    }
  }

  Future<IntegrityReport> verifyRestoreDryRun(String raw) async {
    final structure = await verifyBackupJson(raw);
    if (!structure.ok) return structure;

    final checks = List<String>.from(structure.checks);
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      var importable = 0;
      for (final t in ExportService.tables) {
        final key = map.containsKey(t)
            ? t
            : (map.containsKey(_toCamel(t)) ? _toCamel(t) : null);
        if (key == null) continue;
        final list = map[key];
        if (list is! List) continue;
        importable += list.length;
        if (list.isNotEmpty && list.first is Map) {
          final row = Map<String, dynamic>.from(list.first as Map);
          final id = row['id'] ?? row['Id'];
          if (id == null) {
            checks.add('WARN: $t row missing id');
          }
        }
      }
      checks.add('OK: dry-run would touch ~$importable rows');
      checks.add('OK: restore dry-run (no DB writes)');
      return IntegrityReport(ok: true, checks: checks);
    } catch (e) {
      checks.add('FAIL: dry-run $e');
      return IntegrityReport(ok: false, checks: checks);
    }
  }

  String _toCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }
}
