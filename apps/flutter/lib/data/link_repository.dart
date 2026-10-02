import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// entity_links: connect notes, people, tasks, projects, goals, events.
class LinkRepository {
  LinkRepository(this._db);
  final AppDatabase _db;

  Future<void> link({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    String relationship = 'RELATED',
  }) async {
    final db = await _db.database;
    await db.insert(
      'entity_links',
      {
        'id': AppDatabase.newId(),
        'source_type': sourceType,
        'source_id': sourceId,
        'target_type': targetType,
        'target_id': targetId,
        'relationship_type': relationship,
        'created_at': AppDatabase.nowMs(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> linksFor(String type, String id) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT * FROM entity_links
      WHERE (source_type = ? AND source_id = ?) OR (target_type = ? AND target_id = ?)
      ORDER BY created_at DESC
    ''', [type, id, type, id]);
  }
}
