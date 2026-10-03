import '../data/database.dart';
import '../data/link_repository.dart';
import '../data/note_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';

/// Offline intelligence over notes — the memory layer.
class NoteIntelligence {
  NoteIntelligence({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Pull actionable lines from free-form note text.
  ///
  /// Recognizes:
  /// - markdown / bullet lines (- * •)
  /// - checkbox lines ([ ] / [x])
  /// - TODO: / Action: / Next:
  /// - numbered lists
  static List<String> extractTaskCandidates(String content) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      var line = raw.trim();
      if (line.isEmpty) continue;

      // Strip common prefixes
      line = line.replaceFirst(RegExp(r'^[-*•]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\[[ xX]?\]\s*'), '');
      line = line.replaceFirst(RegExp(r'^(TODO|Action|Next|Follow[- ]?up)\s*:\s*', caseSensitive: false), '');

      line = line.trim();
      if (line.length < 3) continue;
      if (line.length > 120) line = '${line.substring(0, 117)}…';

      // Skip pure headings / short noise
      if (RegExp(r'^#+\s').hasMatch(raw.trim())) continue;
      final key = line.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(line);
    }
    return out;
  }

  /// Create tasks from selected candidate lines; link each to the note (+ optional project).
  Future<int> createTasksFromNote({
    required String noteId,
    required List<String> titles,
    String? projectId,
    String? goalId,
  }) async {
    if (titles.isEmpty) return 0;
    final tasks = TaskRepository(_db);
    final links = LinkRepository(_db);
    var n = 0;
    for (final title in titles) {
      final t = await tasks.create(
        title: title,
        status: EntityStatus.inbox,
        projectId: projectId,
        goalId: goalId,
      );
      await links.link(
        sourceType: 'NOTE',
        sourceId: noteId,
        targetType: 'TASK',
        targetId: t.id,
        relationship: 'SPAWNED',
      );
      n++;
    }
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': 'NOTE_TASKS_EXTRACTED',
      'entity_type': 'NOTE',
      'entity_id': noteId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.user,
      'metadata': '{"count":$n}',
    });
    return n;
  }

  /// Notes linked to a given entity (memory around a project/goal/…).
  Future<List<Map<String, Object?>>> notesAbout(String entityType, String entityId) async {
    final linkRows = await LinkRepository(_db).linksFor(entityType, entityId);
    final noteIds = <String>{};
    for (final row in linkRows) {
      final peer = LinkRepository.peerOf(row, entityType, entityId);
      if (peer['type'] == 'NOTE') noteIds.add(peer['id']!);
    }
    final notes = NoteRepository(_db);
    final out = <Map<String, Object?>>[];
    for (final id in noteIds) {
      final n = await notes.getById(id);
      if (n == null) continue;
      out.add({
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'updated_at': n.updatedAt,
      });
    }
    out.sort((a, b) => ((b['updated_at'] as int?) ?? 0).compareTo((a['updated_at'] as int?) ?? 0));
    return out;
  }
}
