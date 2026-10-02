import '../domain/enums.dart';
import '../domain/models.dart';
import 'database.dart';

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

  Future<Note> create({String? title, required String content}) async {
    final db = await _db.database;
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
    await db.insert('notes', note.toInsertMap());
    return note;
  }
}
