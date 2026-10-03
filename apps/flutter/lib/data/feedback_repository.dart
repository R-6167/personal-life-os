import 'database.dart';

class FeedbackRepository {
  FeedbackRepository(this._db);
  final AppDatabase _db;

  Future<void> create({
    required String title,
    String? body,
    String kind = 'FEEDBACK', // FEEDBACK | BUG | IDEA
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('feedback_items', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'kind': kind,
      'title': title,
      'body': body,
      'status': 'OPEN',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> list({int limit = 100}) async {
    return (await _db.database).query(
      'feedback_items',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> close(String id) async {
    await (await _db.database).update(
      'feedback_items',
      {'status': 'CLOSED', 'updated_at': AppDatabase.nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await (await _db.database).delete('feedback_items', where: 'id = ?', whereArgs: [id]);
  }

  /// Shareable text dump for email / GitHub issues (user chooses).
  Future<String> exportText() async {
    final rows = await list();
    final buf = StringBuffer('Personal Life OS — local feedback export\n');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
    for (final r in rows) {
      buf.writeln('---');
      buf.writeln('[${r['kind']}] ${r['title']} (${r['status']})');
      if (r['body'] != null) buf.writeln('${r['body']}');
      final ms = r['created_at'] as int?;
      if (ms != null) {
        buf.writeln(DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String());
      }
    }
    return buf.toString();
  }
}
