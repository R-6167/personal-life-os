import '../data/database.dart';
import '../domain/db_map.dart';
import 'progress_calculator.dart';

/// What is the next concrete thing I can do on this project?
class NextAction {
  final String taskId;
  final String title;
  final String? reason;
  final int? dueAt;
  final int? scheduledStart;
  final int priority;
  final bool isSubtask;
  final String? parentTitle;

  const NextAction({
    required this.taskId,
    required this.title,
    this.reason,
    this.dueAt,
    this.scheduledStart,
    this.priority = 0,
    this.isSubtask = false,
    this.parentTitle,
  });
}

class ProjectWorkspace {
  final Map<String, Object?> project;
  final Map<String, Object?>? goal;
  final List<Map<String, Object?>> milestones;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> subtasks;
  final List<Map<String, Object?>> dependencies;
  final List<Map<String, Object?>> scheduled;
  final List<Map<String, Object?>> notes;
  final List<Map<String, Object?>> resources;
  final List<Map<String, Object?>> activity;
  final NextAction? nextAction;
  final double progressRatio;
  final int tasksDone;
  final int tasksTotal;
  final int milestonesDone;
  final int milestonesTotal;
  final int? targetDate;

  const ProjectWorkspace({
    required this.project,
    this.goal,
    required this.milestones,
    required this.tasks,
    required this.subtasks,
    required this.dependencies,
    required this.scheduled,
    required this.notes,
    required this.resources,
    required this.activity,
    this.nextAction,
    required this.progressRatio,
    required this.tasksDone,
    required this.tasksTotal,
    required this.milestonesDone,
    required this.milestonesTotal,
    this.targetDate,
  });
}

class ProjectWorkspaceService {
  ProjectWorkspaceService([AppDatabase? db]) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<ProjectWorkspace> load(String projectId) async {
    final db = await _db.database;
    final prows = await db.query('projects', where: 'id = ?', whereArgs: [projectId], limit: 1);
    if (prows.isEmpty) {
      throw StateError('Project not found: $projectId');
    }
    final project = prows.first;

    Map<String, Object?>? goal;
    final goalId = dbStrOrNull(project['goal_id']);
    if (goalId != null) {
      final g = await db.query('goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
      if (g.isNotEmpty) goal = g.first;
    }

    final milestones = await db.query(
      'milestones',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'position ASC, created_at ASC',
    );

    final allTasks = await db.query(
      'tasks',
      where: "project_id = ? AND archived_at IS NULL AND COALESCE(status, '') != 'CANCELLED'",
      whereArgs: [projectId],
      orderBy: 'priority DESC, due_at ASC, created_at ASC',
    );

    final roots = allTasks.where((t) => dbStrOrNull(t['parent_task_id']) == null).toList();
    final subs = allTasks.where((t) => dbStrOrNull(t['parent_task_id']) != null).toList();

    final taskIds = allTasks.map((t) => dbStr(t['id'])).toList();
    List<Map<String, Object?>> deps = [];
    if (taskIds.isNotEmpty) {
      final ph = List.filled(taskIds.length, '?').join(',');
      deps = await db.rawQuery('''
        SELECT d.*, t.title AS depends_on_title, t.status AS depends_on_status
        FROM task_dependencies d
        JOIN tasks t ON t.id = d.depends_on_task_id
        WHERE d.task_id IN ($ph)
      ''', taskIds);
    }

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final horizon = dayStart + const Duration(days: 21).inMilliseconds;
    final scheduled = allTasks.where((t) {
      final s = t['scheduled_start'] as int?;
      return s != null && s >= dayStart && s <= horizon;
    }).toList()
      ..sort((a, b) =>
          ((a['scheduled_start'] as int?) ?? 0).compareTo((b['scheduled_start'] as int?) ?? 0));

    final notes = await _linkedNotes(projectId);
    final resources = await _linkedResources(projectId);

    final entityIds = <String>{
      projectId,
      if (goalId != null) goalId,
      ...taskIds,
      ...milestones.map((m) => dbStr(m['id'])),
    };
    final activity = await _activity(entityIds.toList());

    final openTasks = allTasks
        .where((t) => dbStr(t['status']) != 'COMPLETED')
        .toList();
    final tasksDone = allTasks.where((t) => dbStr(t['status']) == 'COMPLETED').length;
    final milestonesDone =
        milestones.where((m) => dbStr(m['status']) == 'COMPLETED').length;
    final tt = allTasks.length;
    final mt = milestones.length;
    final ratio = ProgressCalculator.projectRatio(
      tasksDone: tasksDone,
      tasksTotal: tt,
      milestonesDone: milestonesDone,
      milestonesTotal: mt,
    );

    final next = _computeNextAction(
      openTasks: openTasks,
      allTasks: allTasks,
      deps: deps,
    );

    return ProjectWorkspace(
      project: project,
      goal: goal,
      milestones: milestones,
      tasks: roots,
      subtasks: subs,
      dependencies: deps,
      scheduled: scheduled,
      notes: notes,
      resources: resources,
      activity: activity,
      nextAction: next,
      progressRatio: ratio,
      tasksDone: tasksDone,
      tasksTotal: tt,
      milestonesDone: milestonesDone,
      milestonesTotal: mt,
      targetDate: project['target_date'] as int?,
    );
  }

  /// Pure rule: next concrete actionable item.
  /// Prefer unblocked open tasks; if a parent has open subtasks, pick the subtask.
  NextAction? _computeNextAction({
    required List<Map<String, Object?>> openTasks,
    required List<Map<String, Object?>> allTasks,
    required List<Map<String, Object?>> deps,
  }) {
    if (openTasks.isEmpty) return null;

    final completedIds = allTasks
        .where((t) => dbStr(t['status']) == 'COMPLETED')
        .map((t) => dbStr(t['id']))
        .toSet();

    final blockedBy = <String, Set<String>>{};
    for (final d in deps) {
      final tid = dbStr(d['task_id']);
      final dep = dbStr(d['depends_on_task_id']);
      final depStatus = dbStr(d['depends_on_status']);
      if (depStatus != 'COMPLETED') {
        blockedBy.putIfAbsent(tid, () => {}).add(dep);
      }
    }

    bool isBlocked(String id) => blockedBy[id]?.isNotEmpty == true;

    // Candidates: open, not blocked, and either a leaf or a subtask whose parent is open.
    final candidates = <Map<String, Object?>>[];
    for (final t in openTasks) {
      final id = dbStr(t['id']);
      if (isBlocked(id)) continue;

      final parentId = dbStrOrNull(t['parent_task_id']);
      if (parentId != null) {
        // Subtask: actionable if parent not completed (or parent missing)
        if (completedIds.contains(parentId)) continue;
        candidates.add(t);
        continue;
      }

      // Root: if it has open subtasks, skip root — force subtask as next action
      final openChildren = openTasks.where((c) => dbStrOrNull(c['parent_task_id']) == id).toList();
      if (openChildren.isNotEmpty) {
        // Prefer first unblocked open child instead
        for (final c in openChildren) {
          if (!isBlocked(dbStr(c['id']))) candidates.add(c);
        }
        continue;
      }

      candidates.add(t);
    }

    if (candidates.isEmpty) {
      // Fallback: any open unblocked root
      for (final t in openTasks) {
        if (!isBlocked(dbStr(t['id']))) candidates.add(t);
      }
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final pa = dbIntOr(a['priority']);
      final pb = dbIntOr(b['priority']);
      if (pa != pb) return pb.compareTo(pa);
      final da = a['due_at'] as int?;
      final dbv = b['due_at'] as int?;
      if (da != null && dbv != null) return da.compareTo(dbv);
      if (da != null) return -1;
      if (dbv != null) return 1;
      final sa = a['scheduled_start'] as int?;
      final sb = b['scheduled_start'] as int?;
      if (sa != null && sb != null) return sa.compareTo(sb);
      if (sa != null) return -1;
      if (sb != null) return 1;
      return dbIntOr(a['created_at']).compareTo(dbIntOr(b['created_at']));
    });

    final pick = candidates.first;
    final parentId = dbStrOrNull(pick['parent_task_id']);
    String? parentTitle;
    if (parentId != null) {
      for (final t in allTasks) {
        if (dbStr(t['id']) == parentId) {
          parentTitle = dbStr(t['title']);
          break;
        }
      }
    }

    String reason;
    if (pick['scheduled_start'] != null) {
      reason = 'Already on the calendar';
    } else if (pick['due_at'] != null) {
      reason = 'Due soon / has a due date';
    } else if (parentTitle != null) {
      reason = 'Next step under “$parentTitle”';
    } else if (dbIntOr(pick['priority']) > 0) {
      reason = 'Highest priority open work';
    } else {
      reason = 'Oldest open unblocked work';
    }

    return NextAction(
      taskId: dbStr(pick['id']),
      title: dbStr(pick['title']),
      reason: reason,
      dueAt: pick['due_at'] as int?,
      scheduledStart: pick['scheduled_start'] as int?,
      priority: dbIntOr(pick['priority']),
      isSubtask: parentId != null,
      parentTitle: parentTitle,
    );
  }

  Future<void> _ensureOwnedProject(String projectId, String ownerId) async {
    final rows = await (await _db.database).query(
      'projects',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [projectId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Project not found for the current owner.');
    }
  }

  Future<List<Map<String, Object?>>> _linkedNotes(String projectId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    return db.rawQuery('''
      SELECT DISTINCT n.* FROM notes n
      JOIN entity_links l ON (
        (l.from_type = 'PROJECT' AND l.from_id = ? AND l.to_type = 'NOTE' AND l.to_id = n.id)
        OR (l.to_type = 'PROJECT' AND l.to_id = ? AND l.from_type = 'NOTE' AND l.from_id = n.id)
      )
      WHERE l.owner_id = ? AND n.owner_id = ? AND n.archived_at IS NULL
      ORDER BY n.updated_at DESC
      LIMIT 20
    ''', [projectId, projectId, ownerId, ownerId]);
  }

  Future<List<Map<String, Object?>>> _linkedResources(String projectId) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    return db.rawQuery('''
      SELECT DISTINCT d.* FROM documents d
      JOIN entity_links l ON (
        (l.from_type = 'PROJECT' AND l.from_id = ? AND l.to_type = 'DOCUMENT' AND l.to_id = d.id)
        OR (l.to_type = 'PROJECT' AND l.to_id = ? AND l.from_type = 'DOCUMENT' AND l.from_id = d.id)
      )
      WHERE l.owner_id = ? AND d.owner_id = ?
      ORDER BY d.updated_at DESC
      LIMIT 20
    ''', [projectId, projectId, ownerId, ownerId]);
  }

  Future<List<Map<String, Object?>>> _activity(List<String> entityIds) async {
    if (entityIds.isEmpty) return [];
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final ph = List.filled(entityIds.length, '?').join(',');
    return db.rawQuery('''
      SELECT event_type, entity_type, entity_id, occurred_at
      FROM activity_events
      WHERE owner_id = ? AND entity_id IN ($ph)
      ORDER BY occurred_at DESC
      LIMIT 40
    ''', [ownerId, ...entityIds]);
  }

  Future<void> attachNote({required String projectId, required String content}) async {
    final ownerId = await _db.requireOwnerId();
    await _ensureOwnedProject(projectId, ownerId);
    final now = AppDatabase.nowMs();
    final noteId = AppDatabase.newId();
    await _db.txn((txn) async {
      await txn.insert('notes', {
        'id': noteId,
        'owner_id': ownerId,
        'content': content,
        'created_at': now,
        'updated_at': now,
      });
      await _insertLink(
        txn,
        ownerId: ownerId,
        fromType: 'PROJECT',
        fromId: projectId,
        toType: 'NOTE',
        toId: noteId,
        now: now,
      );
    });
  }

  Future<void> attachResource({
    required String projectId,
    required String title,
    String? notes,
  }) async {
    final ownerId = await _db.requireOwnerId();
    await _ensureOwnedProject(projectId, ownerId);
    final now = AppDatabase.nowMs();
    final docId = AppDatabase.newId();
    await _db.txn((txn) async {
      await txn.insert('documents', {
        'id': docId,
        'owner_id': ownerId,
        'title': title,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'created_at': now,
        'updated_at': now,
      });
      await _insertLink(
        txn,
        ownerId: ownerId,
        fromType: 'PROJECT',
        fromId: projectId,
        toType: 'DOCUMENT',
        toId: docId,
        now: now,
      );
    });
  }

  Future<void> _insertLink(
    dynamic txn, {
    required String ownerId,
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    required int now,
  }) async {
    await txn.insert('entity_links', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'from_type': fromType,
      'from_id': fromId,
      'to_type': toType,
      'to_id': toId,
      'relation': 'RELATED',
      'created_at': now,
    });
  }
}
