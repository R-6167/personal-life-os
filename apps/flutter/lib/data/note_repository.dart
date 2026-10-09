import '../domain/enums.dart';
import '../domain/models.dart';
import 'atomic_write.dart';
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

  Future<Note> create({String? title, required String content, String? assistantActionPreview}) async {
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
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.insert('notes', note.toInsertMap());
      },
      eventType: 'NOTE_CREATED',
      entityType: 'NOTE',
      entityId: note.id,
      occurredAt: now,
      additionalEvents: assistantActionPreview == null ? const [] : [AtomicEvent(eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'NOTE', entityId: note.id, source: EventSource.system, metadata: '{"action":"addNote"}', occurredAt: now)],
    );
    return note;
  }

  Future<void> update({required String id, String? title, required String content}) async {
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
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
      },
      eventType: 'NOTE_UPDATED',
      entityType: 'NOTE',
      entityId: id,
      occurredAt: now,
    );
  }

  Future<void> delete(String id) async {
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await txn.update(
          'notes',
          {'archived_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      eventType: 'NOTE_DELETED',
      entityType: 'NOTE',
      entityId: id,
      occurredAt: now,
    );
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
