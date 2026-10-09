import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// entity_links: connect notes ↔ project, goal, task, person, event, finance/practical.
///
/// Supports the canonical from_type/from_id/to_type/to_id/relation schema and
/// the legacy source_type/source_id/target_type/target_id/relationship_type schema.
class LinkRepository {
  LinkRepository(this._db);
  final AppDatabase _db;

  bool? _useFromColumns;

  static const Map<String, String> _entityTables = {
    'PERSON': 'people', 'GOAL': 'goals', 'PROJECT': 'projects',
    'MILESTONE': 'milestones', 'TASK': 'tasks', 'HABIT': 'habits',
    'HABIT_SCHEDULE': 'habit_schedules', 'HABIT_OCCURRENCE': 'habit_occurrences',
    'ROUTINE': 'routines', 'ROUTINE_STEP': 'routine_steps',
    'ROUTINE_SCHEDULE': 'routine_schedules', 'ROUTINE_OCCURRENCE': 'routine_occurrences',
    'EVENT': 'calendar_events', 'CALENDAR_EVENT': 'calendar_events',
    'TIME_BLOCK': 'time_blocks', 'REMINDER': 'reminders',
    'NOTE': 'notes', 'DOCUMENT': 'documents', 'BILL': 'bills',
    'BILL_OCCURRENCE': 'bill_occurrences', 'SUBSCRIPTION': 'subscriptions',
    'DEBT': 'debts', 'DEBT_PAYMENT': 'debt_payments', 'EXPENSE': 'expenses',
    'INCOME': 'income', 'FINANCIAL_ACCOUNT': 'financial_accounts',
    'SAVINGS_GOAL': 'savings_goals', 'SAVINGS_CONTRIBUTION': 'savings_contributions',
    'PRACTICAL': 'practical_items', 'PRACTICAL_ITEM': 'practical_items',
    'SHOPPING_LIST': 'shopping_lists', 'SHOPPING_ITEM': 'shopping_items',
    'WELLNESS_CHECKIN': 'wellness_checkins', 'HEALTH_METRIC': 'health_metrics',
    'GOAL_REFLECTION': 'goal_reflections', 'WORK_SESSION': 'work_sessions',
    'BUDGET': 'budgets', 'APP_USAGE_EVENT': 'app_usage_events',
    'ERROR_LOG': 'error_logs', 'FEEDBACK_ITEM': 'feedback_items',
  };

  Future<void> _ensureOwnedEntity(
    Database db, {
    required String type,
    required String entityId,
    required String ownerId,
  }) async {
    final table = _entityTables[type.toUpperCase()];
    if (table == null) throw StateError('Unsupported link entity type: $type');
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final columns = info.map((row) => '${row['name']}').toSet();
    if (!columns.contains('owner_id')) {
      throw StateError('Link entity type has no owner scope: $type');
    }
    final where = columns.contains('archived_at')
        ? 'id = ? AND owner_id = ? AND archived_at IS NULL'
        : 'id = ? AND owner_id = ?';
    final rows = await db.query(
      table, columns: ['id'], where: where, whereArgs: [entityId, ownerId], limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Linked entity not found or not owned by the current user: $type/$entityId');
    }
  }

  Future<bool> _fromStyle(Database db) async {
    if (_useFromColumns != null) return _useFromColumns!;
    try {
      final info = await db.rawQuery('PRAGMA table_info(entity_links)');
      final cols = info.map((r) => '${r['name']}').toSet();
      _useFromColumns = cols.contains('from_type');
    } catch (_) {
      _useFromColumns = true;
    }
    return _useFromColumns!;
  }

  Future<void> link({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    String relationship = 'RELATED',
  }) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final fromStyle = await _fromStyle(db);
    await _ensureOwnedEntity(db, type: sourceType, entityId: sourceId, ownerId: ownerId);
    await _ensureOwnedEntity(db, type: targetType, entityId: targetId, ownerId: ownerId);

    // Skip duplicates
    final existing = await linksFor(sourceType, sourceId);
    for (final e in existing) {
      final aType = '${e['from_type'] ?? e['source_type']}';
      final aId = '${e['from_id'] ?? e['source_id']}';
      final bType = '${e['to_type'] ?? e['target_type']}';
      final bId = '${e['to_id'] ?? e['target_id']}';
      final match =
          (aType == sourceType && aId == sourceId && bType == targetType && bId == targetId) ||
          (aType == targetType && aId == targetId && bType == sourceType && bId == sourceId);
      if (match) return;
    }

    if (fromStyle) {
      await db.insert(
        'entity_links',
        {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'from_type': sourceType,
          'from_id': sourceId,
          'to_type': targetType,
          'to_id': targetId,
          'relation': relationship,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.insert(
        'entity_links',
        {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'source_type': sourceType,
          'source_id': sourceId,
          'target_type': targetType,
          'target_id': targetId,
          'relationship_type': relationship,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> unlink(String linkId) async {
    final ownerId = await _db.requireOwnerId();
    await (await _db.database).delete(
      'entity_links',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [linkId, ownerId],
    );
  }

  Future<List<Map<String, Object?>>> linksFor(String type, String id) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final fromStyle = await _fromStyle(db);
    final rows = fromStyle
        ? await db.rawQuery('''
            SELECT * FROM entity_links
            WHERE owner_id = ? AND ((from_type = ? AND from_id = ?) OR (to_type = ? AND to_id = ?))
            ORDER BY created_at DESC
          ''', [ownerId, type, id, type, id])
        : await db.rawQuery('''
            SELECT * FROM entity_links
            WHERE owner_id = ? AND ((source_type = ? AND source_id = ?) OR (target_type = ? AND target_id = ?))
            ORDER BY created_at DESC
          ''', [ownerId, type, id, type, id]);

    final valid = <Map<String, Object?>>[];
    for (final row in rows) {
      final fromType = '${row['from_type'] ?? row['source_type'] ?? ''}';
      final fromId = '${row['from_id'] ?? row['source_id'] ?? ''}';
      final toType = '${row['to_type'] ?? row['target_type'] ?? ''}';
      final toId = '${row['to_id'] ?? row['target_id'] ?? ''}';
      try {
        await _ensureOwnedEntity(db, type: fromType, entityId: fromId, ownerId: ownerId);
        await _ensureOwnedEntity(db, type: toType, entityId: toId, ownerId: ownerId);
        valid.add(row);
      } on StateError {
        // A previously valid link may become stale if either endpoint is archived
        // or changes owner; do not surface that relationship.
      }
    }
    return valid;
  }

  /// Normalized peer on the other side of a link relative to [type]/[id].
  static Map<String, String> peerOf(Map<String, Object?> row, String type, String id) {
    final fromType = '${row['from_type'] ?? row['source_type'] ?? ''}';
    final fromId = '${row['from_id'] ?? row['source_id'] ?? ''}';
    final toType = '${row['to_type'] ?? row['target_type'] ?? ''}';
    final toId = '${row['to_id'] ?? row['target_id'] ?? ''}';
    if (fromType == type && fromId == id) {
      return {'type': toType, 'id': toId};
    }
    return {'type': fromType, 'id': fromId};
  }

  /// Bidirectional related peers with resolved titles (notes, tasks, people, …).
  Future<List<Map<String, String>>> relatedWithTitles(String type, String id) async {
    final rows = await linksFor(type, id);
    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final r in rows) {
      final peer = peerOf(r, type, id);
      final pType = peer['type'] ?? '';
      final pId = peer['id'] ?? '';
      if (pType.isEmpty || pId.isEmpty) continue;
      final key = '$pType:$pId';
      if (seen.contains(key)) continue;
      seen.add(key);
      final title = await resolveTitle(pType, pId) ?? pId;
      final rel = '${r['relation'] ?? r['relationship_type'] ?? 'RELATED'}';
      out.add({'type': pType, 'id': pId, 'title': title, 'relation': rel});
    }
    return out;
  }

  Future<String?> resolveTitle(String entityType, String entityId) async {
    final db = await _db.database;
    try {
      switch (entityType) {
        case 'TASK':
          return _col(db, 'tasks', entityId, 'title');
        case 'PROJECT':
          return _col(db, 'projects', entityId, 'title');
        case 'GOAL':
          return _col(db, 'goals', entityId, 'title');
        case 'PERSON':
          return _col(db, 'people', entityId, 'name');
        case 'EVENT':
        case 'CALENDAR_EVENT':
          return _col(db, 'calendar_events', entityId, 'title');
        case 'BILL':
          return _col(db, 'bills', entityId, 'name');
        case 'EXPENSE':
          return _col(db, 'expenses', entityId, 'description');
        case 'HABIT':
          return _col(db, 'habits', entityId, 'title');
        case 'PRACTICAL':
          return _col(db, 'practical_items', entityId, 'title');
        case 'DOCUMENT':
          return _col(db, 'documents', entityId, 'title');
        case 'NOTE':
          final t = await _col(db, 'notes', entityId, 'title');
          if (t != null && t.isNotEmpty) return t;
          final c = await _col(db, 'notes', entityId, 'content');
          if (c == null) return null;
          return c.length > 40 ? '${c.substring(0, 40)}…' : c;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _col(Database db, String table, String id, String col) async {
    final ownerId = await _db.requireOwnerId();
    final rows = await db.query(
      table, columns: [col], where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId], limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[col]?.toString();
  }
}
