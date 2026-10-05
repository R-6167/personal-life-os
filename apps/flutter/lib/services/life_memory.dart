import '../data/database.dart';
import '../data/link_repository.dart';
import '../data/note_repository.dart';
import '../domain/db_map.dart';

/// A single recalled fact from local life data (not cloud AI).
class MemoryFact {
  MemoryFact({
    required this.kind,
    required this.text,
    required this.score,
    this.entityType,
    this.entityId,
    this.whenMs,
  });

  final String kind; // NOTE | ACTIVITY | GOAL | TASK | FINANCE | HABIT | WORK
  final String text;
  final double score;
  final String? entityType;
  final String? entityId;
  final int? whenMs;
}

/// Offline memory layer: notes + activity + links → searchable personal context.
class LifeMemoryService {
  LifeMemoryService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Keyword / phrase recall across notes, titles, recent activity.
  Future<List<MemoryFact>> recall(String query, {int limit = 12}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final tokens = q
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return [];

    final facts = <MemoryFact>[];
    final db = await _db.database;

    // Notes as long-term memory
    try {
      final notes = await NoteRepository(_db).list();
      for (final n in notes.take(80)) {
        final title = n.title ?? '';
        final content = n.content;
        final hay = '$title $content'.toLowerCase();
        final score = _tokenScore(hay, tokens);
        if (score <= 0) continue;
        final snippet = content.isEmpty
            ? title
            : (content.length > 120 ? '${content.substring(0, 120)}…' : content);
        facts.add(MemoryFact(
          kind: 'NOTE',
          text: title.isEmpty ? snippet : '$title — $snippet',
          score: score + 0.15,
          entityType: 'NOTE',
          entityId: n.id,
          whenMs: n.updatedAt,
        ));
      }
    } catch (_) {}

    // Open tasks / goals / projects by title
    for (final table in [
      ('tasks', 'title', 'TASK'),
      ('goals', 'title', 'GOAL'),
      ('projects', 'title', 'PROJECT'),
      ('habits', 'title', 'HABIT'),
      ('people', 'name', 'PERSON'),
    ]) {
      try {
        final rows = await db.query(table.$1, limit: 60, orderBy: 'updated_at DESC');
        for (final r in rows) {
          final label = dbStr(r[table.$2]);
          if (label.isEmpty) continue;
          final score = _tokenScore(label.toLowerCase(), tokens);
          if (score <= 0) continue;
          facts.add(MemoryFact(
            kind: table.$3,
            text: label,
            score: score,
            entityType: table.$3,
            entityId: dbStr(r['id']),
            whenMs: r['updated_at'] as int?,
          ));
        }
      } catch (_) {}
    }

    // Recent activity headlines
    try {
      final acts = await db.query(
        'activity_events',
        orderBy: 'occurred_at DESC',
        limit: 100,
      );
      for (final a in acts) {
        final type = dbStr(a['event_type']);
        final et = dbStr(a['entity_type']);
        final eid = dbStr(a['entity_id']);
        final hay = '$type $et'.toLowerCase();
        var score = _tokenScore(hay, tokens);
        if (score <= 0 && eid.isNotEmpty) {
          final title = await LinkRepository(_db).resolveTitle(et, eid);
          if (title != null) {
            score = _tokenScore(title.toLowerCase(), tokens);
            if (score > 0) {
              facts.add(MemoryFact(
                kind: 'ACTIVITY',
                text: '${type.replaceAll('_', ' ').toLowerCase()}: $title',
                score: score * 0.9,
                entityType: et,
                entityId: eid,
                whenMs: a['occurred_at'] as int?,
              ));
              continue;
            }
          }
        }
        if (score <= 0) continue;
        facts.add(MemoryFact(
          kind: 'ACTIVITY',
          text: type.replaceAll('_', ' ').toLowerCase(),
          score: score * 0.7,
          entityType: et,
          entityId: eid,
          whenMs: a['occurred_at'] as int?,
        ));
      }
    } catch (_) {}

    facts.sort((a, b) => b.score.compareTo(a.score));
    final seen = <String>{};
    final out = <MemoryFact>[];
    for (final f in facts) {
      final key = f.text.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(f);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// High-level insights derived from recent history (reasoning, not storage).
  Future<List<String>> insights({int limit = 6}) async {
    final db = await _db.database;
    final out = <String>[];
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final twoWeeks = now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;

    try {
      final ws = await db.rawQuery(
        "SELECT COALESCE(SUM(accumulated_ms),0) AS ms, COUNT(*) AS n "
        "FROM work_sessions WHERE status = 'COMPLETED' AND started_at >= ?",
        [weekAgo],
      );
      final ms = (ws.first['ms'] as int?) ?? 0;
      final n = (ws.first['n'] as int?) ?? 0;
      if (n > 0) {
        final hours = (ms / 3600000).toStringAsFixed(1);
        out.add('You logged ${hours}h across $n work session${n == 1 ? '' : 's'} this week.');
      } else {
        out.add('No completed work sessions this week — start one from a scheduled task.');
      }
    } catch (_) {}

    try {
      final done = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM activity_events "
        "WHERE event_type = 'TASK_COMPLETED' AND occurred_at >= ?",
        [weekAgo],
      );
      final created = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM activity_events "
        "WHERE event_type = 'TASK_CREATED' AND occurred_at >= ?",
        [weekAgo],
      );
      final d = (done.first['n'] as int?) ?? 0;
      final c = (created.first['n'] as int?) ?? 0;
      if (c > 0 || d > 0) {
        out.add('This week: $d task${d == 1 ? '' : 's'} completed, $c created.');
        if (c > d + 2) {
          out.add('You are adding work faster than finishing it — tighten scope or clear overdue.');
        }
      }
    } catch (_) {}

    try {
      final hab = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM activity_events "
        "WHERE event_type = 'HABIT_COMPLETED' AND occurred_at >= ?",
        [weekAgo],
      );
      final n = (hab.first['n'] as int?) ?? 0;
      if (n > 0) {
        out.add('$n habit completion${n == 1 ? '' : 's'} logged this week.');
      }
    } catch (_) {}

    try {
      final nowMs = AppDatabase.nowMs();
      final od = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM tasks "
        "WHERE status != 'COMPLETED' AND status != 'CANCELLED' "
        "AND due_at IS NOT NULL AND due_at < ?",
        [nowMs],
      );
      final n = (od.first['n'] as int?) ?? 0;
      if (n > 0) {
        out.add('$n overdue task${n == 1 ? '' : 's'} still open — clear these before new commitments.');
      }
    } catch (_) {}

    try {
      final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final exp = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor),0) AS s FROM expenses WHERE occurred_at >= ?',
        [monthStart],
      );
      final s = (exp.first['s'] as int?) ?? 0;
      if (s > 0) {
        out.add('Month spend so far: recorded ${(s / 100).toStringAsFixed(0)} (local expenses).');
      }
    } catch (_) {}

    try {
      final goals = await db.query(
        'goals',
        where: "status = 'ACTIVE' OR status IS NULL",
        limit: 10,
      );
      for (final g in goals) {
        final id = dbStr(g['id']);
        final title = dbStr(g['title']);
        final acts = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM activity_events WHERE entity_id = ? AND occurred_at >= ?',
          [id, twoWeeks],
        );
        final n = (acts.first['n'] as int?) ?? 0;
        if (n == 0 && title.isNotEmpty) {
          out.add('Goal “$title” has been quiet for 2+ weeks.');
          if (out.length >= limit) break;
        }
      }
    } catch (_) {}

    return out.take(limit).toList();
  }

  /// Related entities around a subject via links + title match.
  Future<List<String>> contextAround(String subject, {int limit = 8}) async {
    final recalled = await recall(subject, limit: limit);
    final lines = <String>[];
    for (final f in recalled) {
      lines.add('${f.kind}: ${f.text}');
    }
    final links = LinkRepository(_db);
    for (final f in recalled.take(3)) {
      if (f.entityType == null || f.entityId == null) continue;
      try {
        final related = await links.relatedWithTitles(f.entityType!, f.entityId!);
        for (final r in related.take(3)) {
          lines.add('  ↔ ${r['type']}: ${r['title']}');
        }
      } catch (_) {}
    }
    return lines.take(limit + 4).toList();
  }

  double _tokenScore(String haystack, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    var hits = 0;
    var weight = 0.0;
    for (final t in tokens) {
      if (haystack.contains(t)) {
        hits++;
        weight += t.length >= 5 ? 1.0 : 0.6;
      }
    }
    if (hits == 0) return 0;
    return (weight / tokens.length) * (hits / tokens.length);
  }
}
