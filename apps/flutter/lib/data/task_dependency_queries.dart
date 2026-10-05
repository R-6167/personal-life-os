import '../domain/enums.dart';
import 'database.dart';

/// Dependency lookups used by Build My Day and planning UX.
class TaskDependencyQueries {
  TaskDependencyQueries(this._db);
  final AppDatabase _db;

  Future<List<String>> listBlockerTitles(String taskId) async {
    final db = await _db.database;
    try {
      final rows = await db.rawQuery(
        'SELECT dep.title AS title '
        'FROM task_dependencies d '
        'INNER JOIN tasks dep ON dep.id = d.depends_on_task_id '
        'WHERE d.task_id = ? AND dep.status NOT IN (?, ?) AND dep.archived_at IS NULL '
        'ORDER BY dep.priority DESC',
        [taskId, EntityStatus.completed, EntityStatus.cancelled],
      );
      final titles = <String>[];
      for (final r in rows) {
        final title = '${r['title'] ?? ''}'.trim();
        if (title.isNotEmpty) titles.add(title);
      }
      return titles;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<String>>> listBlockedWithReasons() async {
    final db = await _db.database;
    final out = <String, List<String>>{};
    try {
      final rows = await db.rawQuery(
        'SELECT d.task_id AS task_id, dep.title AS title '
        'FROM task_dependencies d '
        'INNER JOIN tasks dep ON dep.id = d.depends_on_task_id '
        'WHERE dep.status NOT IN (?, ?) AND dep.archived_at IS NULL',
        [EntityStatus.completed, EntityStatus.cancelled],
      );
      for (final r in rows) {
        final id = r['task_id'] as String?;
        if (id == null) continue;
        out.putIfAbsent(id, () => []).add('${r['title'] ?? 'Dependency'}');
      }
    } catch (_) {}
    return out;
  }

  Future<int> countDependentsWaiting(String taskId) async {
    final db = await _db.database;
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM task_dependencies d '
        'INNER JOIN tasks t ON t.id = d.task_id '
        'WHERE d.depends_on_task_id = ? AND t.status NOT IN (?, ?) AND t.archived_at IS NULL',
        [taskId, EntityStatus.completed, EntityStatus.cancelled],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
