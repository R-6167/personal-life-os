import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/goal_repository.dart';
import '../data/link_repository.dart';
import '../data/note_repository.dart';
import '../data/project_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';

/// A suggested link discovered from note text (offline "AI").
class LinkSuggestion {
  LinkSuggestion({
    required this.entityType,
    required this.entityId,
    required this.label,
    required this.score,
    required this.matchedAs,
  });

  final String entityType;
  final String entityId;
  final String label;
  final double score; // 0..1
  final String matchedAs; // fragment that matched
}

/// Offline intelligence over notes — the memory layer.
class NoteIntelligence {
  NoteIntelligence({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Pull actionable lines from free-form note text.
  static List<String> extractTaskCandidates(String content) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      var line = raw.trim();
      if (line.isEmpty) continue;

      line = line.replaceFirst(RegExp(r'^[-*•]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\[[ xX]?\]\s*'), '');
      line = line.replaceFirst(
          RegExp(r'^(TODO|Action|Next|Follow[- ]?up)\s*:\s*', caseSensitive: false), '');

      line = line.trim();
      if (line.length < 3) continue;
      if (line.length > 120) line = '${line.substring(0, 117)}…';
      if (RegExp(r'^#+\s').hasMatch(raw.trim())) continue;
      final key = line.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(line);
    }
    return out;
  }

  /// Scan note text for mentions of known life entities and rank suggestions.
  ///
  /// Matching (all offline, no network):
  /// - exact case-insensitive phrase
  /// - word-boundary when name is short
  /// - token overlap for multi-word names
  /// - @name and #name shorthand
  Future<List<LinkSuggestion>> suggestLinks({
    required String noteId,
    required String content,
    String? title,
  }) async {
    final haystack = '${title ?? ''}\n$content'.toLowerCase();
    if (haystack.trim().length < 3) return [];

    // Already linked → skip
    final existing = <String>{};
    for (final row in await LinkRepository(_db).linksFor('NOTE', noteId)) {
      final peer = LinkRepository.peerOf(row, 'NOTE', noteId);
      existing.add('${peer['type']}:${peer['id']}');
    }

    final candidates = await _allLinkableEntities();
    final scored = <LinkSuggestion>[];

    for (final c in candidates) {
      final key = '${c['type']}:${c['id']}';
      if (existing.contains(key)) continue;
      final label = c['label']!;
      final labelLower = label.toLowerCase().trim();
      if (labelLower.length < 3) continue;

      final hit = _matchScore(haystack, labelLower);
      if (hit == null) continue;
      scored.add(LinkSuggestion(
        entityType: c['type']!,
        entityId: c['id']!,
        label: label,
        score: hit.score,
        matchedAs: hit.fragment,
      ));
    }

    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.label.length.compareTo(b.label.length); // prefer specific
    });

    // Cap + de-dupe near-identical labels
    final out = <LinkSuggestion>[];
    final seenLabels = <String>{};
    for (final s in scored) {
      if (s.score < 0.55) continue;
      final lk = s.label.toLowerCase();
      if (seenLabels.contains(lk)) continue;
      seenLabels.add(lk);
      out.add(s);
      if (out.length >= 12) break;
    }
    return out;
  }

  /// Apply selected suggestions as ABOUT links.
  Future<int> applyLinkSuggestions({
    required String noteId,
    required List<LinkSuggestion> suggestions,
  }) async {
    final links = LinkRepository(_db);
    var n = 0;
    for (final s in suggestions) {
      await links.link(
        sourceType: 'NOTE',
        sourceId: noteId,
        targetType: s.entityType,
        targetId: s.entityId,
        relationship: 'MENTIONED',
      );
      n++;
    }
    if (n > 0) {
      final ownerId = await _db.requireOwnerId();
      final now = AppDatabase.nowMs();
      await (await _db.database).insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'NOTE_AUTO_LINKED',
        'entity_type': 'NOTE',
        'entity_id': noteId,
        'occurred_at': now,
        'recorded_at': now,
        'source': EventSource.system,
        'metadata': '{"count":$n}',
      });
    }
    return n;
  }

  /// Suggest + apply high-confidence matches automatically (score ≥ 0.85).
  Future<int> autoLinkStrongMentions({
    required String noteId,
    required String content,
    String? title,
  }) async {
    final suggestions = await suggestLinks(noteId: noteId, content: content, title: title);
    final strong = suggestions.where((s) => s.score >= 0.85).toList();
    if (strong.isEmpty) return 0;
    return applyLinkSuggestions(noteId: noteId, suggestions: strong);
  }

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

  Future<List<Map<String, String>>> _allLinkableEntities() async {
    final out = <Map<String, String>>[];
    final db = _db;

    for (final p in await ProjectRepository(db).listActive()) {
      out.add({'type': 'PROJECT', 'id': p.id, 'label': p.title});
    }
    for (final g in await GoalRepository(db).listActive()) {
      out.add({'type': 'GOAL', 'id': g.id, 'label': g.title});
    }
    for (final t in await TaskRepository(db).listOpen()) {
      out.add({'type': 'TASK', 'id': t.id, 'label': t.title});
    }
    for (final p in await ExtendedRepository(db).listPeople()) {
      out.add({'type': 'PERSON', 'id': '${p['id']}', 'label': '${p['name']}'});
    }
    for (final e in await ExtendedRepository(db).listUpcomingAppointments(days: 90)) {
      out.add({'type': 'EVENT', 'id': '${e['id']}', 'label': '${e['title']}'});
    }
    for (final b in await BillRepository(db).listActive()) {
      out.add({'type': 'BILL', 'id': b.id, 'label': b.name});
    }
    for (final p in await ExtendedRepository(db).listPractical()) {
      out.add({'type': 'PRACTICAL', 'id': '${p['id']}', 'label': '${p['title']}'});
    }
    try {
      final habits = await (await db.database).query(
        'habits',
        where: "status = 'ACTIVE'",
        orderBy: 'title ASC',
      );
      for (final h in habits) {
        out.add({'type': 'HABIT', 'id': '${h['id']}', 'label': '${h['title']}'});
      }
    } catch (_) {}

    return out;
  }

  _Match? _matchScore(String haystack, String name) {
    // @name or #name
    final slug = name.replaceAll(RegExp(r'\s+'), '');
    if (haystack.contains('@$slug') || haystack.contains('#$slug')) {
      return _Match(1.0, '@$name');
    }
    if (haystack.contains('@$name') || haystack.contains('#$name')) {
      return _Match(1.0, '@$name');
    }

    // Exact phrase
    if (haystack.contains(name)) {
      // Prefer word-ish boundaries for short names to avoid "AI" in "said"
      if (name.length <= 4) {
        final re = RegExp(r'(^|[^a-z0-9])' + RegExp.escape(name) + r'([^a-z0-9]|$)');
        if (!re.hasMatch(haystack)) return null;
      }
      return _Match(name.length >= 8 ? 0.95 : 0.88, name);
    }

    // Multi-word: require all significant tokens present near each other
    final tokens = name
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList();
    if (tokens.length >= 2) {
      final all = tokens.every(haystack.contains);
      if (all) {
        // Bonus if tokens appear in order
        var idx = 0;
        var ordered = true;
        for (final t in tokens) {
          final at = haystack.indexOf(t, idx);
          if (at < 0) {
            ordered = false;
            break;
          }
          idx = at + t.length;
        }
        return _Match(ordered ? 0.78 : 0.65, name);
      }
    }

    return null;
  }
}

class _Match {
  _Match(this.score, this.fragment);
  final double score;
  final String fragment;
}
