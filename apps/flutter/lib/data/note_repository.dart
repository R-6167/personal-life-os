import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';
import 'link_repository.dart';

class NoteRepository {
  NoteRepository(this._db);
  final AppDatabase _db;

  Future<List<Note>> list() async {
    final db = await _db.database;
    final rows = await db.query(
      'notes',
      where: 'archived_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<Note> create({String? title, required String content}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final note = Note(
      id: AppDatabase.newId(),
      ownerId: ownerId,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _db.txn((txn) async {
      await txn.insert('notes', note.toInsertMap());
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'NOTE_CREATED',
        'entity_type': 'NOTE',
        'entity_id': note.id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
    return note;
  }

  Future<void> update({required String id, String? title, required String content}) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await txn.update(
        'notes',
        {
          'title': title,
          'content': content,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'NOTE_UPDATED',
        'entity_type': 'NOTE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> delete(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await _db.txn((txn) async {
      await txn.update(
        'notes',
        {'archived_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'NOTE_DELETED',
        'entity_type': 'NOTE',
        'entity_id': id,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.user,
      });
    });
  }

  Future<void> linkTo({
    required String noteId,
    required String targetType,
    required String targetId,
  }) async {
    await LinkRepository(_db).link(
      sourceType: 'NOTE',
      sourceId: noteId,
      targetType: targetType,
      targetId: targetId,
      relationship: 'ABOUT',
    );
  }
}
