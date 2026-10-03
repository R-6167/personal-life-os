import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// entity_links: connect notes ↔ project, goal, task, person, event, finance/practical.
///
/// Supports both schema styles:
///   from_type/from_id/to_type/to_id/relation  (schema.sql)
///   source_type/source_id/target_type/target_id/relationship_type  (legacy)
class LinkRepository {
  LinkRepository(this._db);
  final AppDatabase _db;

  bool? _useFromColumns;

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
    await (await _db.database).delete('entity_links', where: 'id = ?', whereArgs: [linkId]);
  }

  Future<List<Map<String, Object?>>> linksFor(String type, String id) async {
    final db = await _db.database;
    final fromStyle = await _fromStyle(db);
    if (fromStyle) {
      return db.rawQuery('''
        SELECT * FROM entity_links
        WHERE (from_type = ? AND from_id = ?) OR (to_type = ? AND to_id = ?)
        ORDER BY created_at DESC
      ''', [type, id, type, id]);
    }
    return db.rawQuery('''
      SELECT * FROM entity_links
      WHERE (source_type = ? AND source_id = ?) OR (target_type = ? AND target_id = ?)
      ORDER BY created_at DESC
    ''', [type, id, type, id]);
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
    final rows = await db.query(table, columns: [col], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first[col]?.toString();
  }
}
