import '../data/database.dart';
import '../domain/db_map.dart';

/// One coherent chain of the person's life work.
/// Goal → Project → Milestone → Task → Scheduled work → Completion → Activity.
class LifeThreadNode {
  final String kind;
  final String id;
  final String title;
  final String status;
  final int? whenMs;
  final String? parentKind;
  final String? parentId;

  const LifeThreadNode({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    this.whenMs,
    this.parentKind,
    this.parentId,
  });
}

class LifeThreadActivity {
  final String eventType;
  final String entityType;
  final String entityId;
  final int occurredAt;
  final String? titleHint;

  const LifeThreadActivity({
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.occurredAt,
    this.titleHint,
  });
}

/// Nested branch under a goal: Project → milestones → tasks.
class ProjectBranch {
  final Map<String, Object?> project;
  final List<Map<String, Object?>> milestones;
  final List<Map<String, Object?>> tasks;
  final int tasksDone;
  final int tasksTotal;
  final int milestonesDone;
  final int milestonesTotal;
  final double progressRatio;
  final String? nextTaskTitle;
  final String? nextTaskId;

  const ProjectBranch({
    required this.project,
    required this.milestones,
    required this.tasks,
    required this.tasksDone,
    required this.tasksTotal,
    required this.milestonesDone,
    required this.milestonesTotal,
    required this.progressRatio,
    this.nextTaskTitle,
    this.nextTaskId,
  });
}

class GoalNextMove {
  final String kind; // TASK | HABIT | PROJECT
  final String id;
  final String title;
  final String reason;
  final String? projectTitle;

  const GoalNextMove({
    required this.kind,
    required this.id,
    required this.title,
    required this.reason,
    this.projectTitle,
  });
}

class GoalThread {
  final Map<String, Object?> goal;
  final List<Map<String, Object?>> projects;
  final List<ProjectBranch> branches;
  final List<Map<String, Object?>> milestones;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> directTasks;
  final List<Map<String, Object?>> habits;
  final List<Map<String, Object?>> scheduled;
  final List<LifeThreadActivity> activity;
  final List<GoalNextMove> nextMoves;
  final String doingSummary;
  final double progressRatio;
  final int projectsDone;
  final int projectsTotal;
  final int tasksDone;
  final int tasksTotal;
  final int milestonesDone;
  final int milestonesTotal;
  final int habitsActive;

  const GoalThread({
    required this.goal,
    required this.projects,
    required this.branches,
    required this.milestones,
    required this.tasks,
    required this.directTasks,
    required this.habits,
    required this.scheduled,
    required this.activity,
    required this.nextMoves,
    required this.doingSummary,
    required this.progressRatio,
    required this.projectsDone,
    required this.projectsTotal,
    required this.tasksDone,
    required this.tasksTotal,
    required this.milestonesDone,
    required this.milestonesTotal,
    required this.habitsActive,
  });
}

class ProjectThread {
  final Map<String, Object?> project;
  final Map<String, Object?>? goal;
  final List<Map<String, Object?>> milestones;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> scheduled;
  final List<LifeThreadActivity> activity;
  final double progressRatio;
  final int tasksDone;
  final int tasksTotal;
  final int milestonesDone;
  final int milestonesTotal;

  const ProjectThread({
    required this.project,
    this.goal,
    required this.milestones,
    required this.tasks,
    required this.scheduled,
    required this.activity,
    required this.progressRatio,
    required this.tasksDone,
    required this.tasksTotal,
    required this.milestonesDone,
    required this.milestonesTotal,
  });
}

class LifeThreadService {
  LifeThreadService([AppDatabase? db]) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<GoalThread> forGoal(String goalId) async {
    final db = await _db.database;
    final goals = await db.query('goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    final goal = goals.isEmpty ? <String, Object?>{'id': goalId, 'title': 'Goal'} : goals.first;

    final projects = await db.query(
      'projects',
      where: 'goal_id = ? AND archived_at IS NULL',
      whereArgs: [goalId],
      orderBy: 'created_at DESC',
    );
    final projectIds = projects.map((p) => dbStr(p['id'])).where((id) => id.isNotEmpty).toList();

    List<Map<String, Object?>> milestones = [];
    if (projectIds.isNotEmpty) {
      final placeholders = List.filled(projectIds.length, '?').join(',');
      milestones = await db.rawQuery(
        'SELECT * FROM milestones WHERE project_id IN ($placeholders) ORDER BY position ASC, created_at ASC',
        projectIds,
      );
    }

    final tasksByGoal = await db.query(
      'tasks',
      where: "goal_id = ? AND status != 'CANCELLED'",
      whereArgs: [goalId],
      orderBy: 'CASE status WHEN \'COMPLETED\' THEN 1 ELSE 0 END, due_at ASC, created_at DESC',
    );

    List<Map<String, Object?>> projectTasks = [];
    if (projectIds.isNotEmpty) {
      final placeholders = List.filled(projectIds.length, '?').join(',');
      projectTasks = await db.rawQuery(
        "SELECT * FROM tasks WHERE project_id IN ($placeholders) AND status != 'CANCELLED' ORDER BY priority DESC, due_at ASC, created_at ASC",
        projectIds,
      );
    }

    final seen = <String>{};
    final allTasks = <Map<String, Object?>>[];
    for (final t in [...tasksByGoal, ...projectTasks]) {
      final id = dbStr(t['id']);
      if (seen.add(id)) allTasks.add(t);
    }

    final directTasks = allTasks
        .where((t) => dbStrOrNull(t['project_id']) == null || !projectIds.contains(dbStr(t['project_id'])))
        .toList();

    // Habits linked to this goal (goal_id column or entity_links).
    final habits = await _habitsForGoal(db, goalId);

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + const Duration(days: 14).inMilliseconds;
    final scheduled = allTasks.where((t) {
      final s = t['scheduled_start'] as int?;
      return s != null && s >= dayStart && s <= dayEnd;
    }).toList()
      ..sort((a, b) => ((a['scheduled_start'] as int?) ?? 0).compareTo((b['scheduled_start'] as int?) ?? 0));

    final habitIds = habits.map((h) => dbStr(h['id'])).toList();
    final entityIds = <String>{
      goalId,
      ...projectIds,
      ...allTasks.map((t) => dbStr(t['id'])),
      ...milestones.map((m) => dbStr(m['id'])),
      ...habitIds,
    };
    final activity = await _activityFor(entityIds.toList(), limit: 40);

    // Nested branches per project
    final branches = <ProjectBranch>[];
    for (final p in projects) {
      final pid = dbStr(p['id']);
      final pMs = milestones.where((m) => dbStr(m['project_id']) == pid).toList();
      final pTs = allTasks.where((t) => dbStr(t['project_id']) == pid).toList();
      final td = pTs.where((t) => dbStr(t['status']) == 'COMPLETED').length;
      final md = pMs.where((m) => dbStr(m['status']) == 'COMPLETED').length;
      final tt = pTs.length;
      final mt = pMs.length;
      final pr = (tt + mt == 0)
          ? 0.0
          : ((tt == 0 ? 0.0 : td / tt) * 0.7 + (mt == 0 ? 0.0 : md / mt) * 0.3).clamp(0.0, 1.0);
      final open = pTs.where((t) => dbStr(t['status']) != 'COMPLETED').toList();
      String? nextTitle;
      String? nextId;
      if (open.isNotEmpty) {
        open.sort((a, b) {
          final pa = dbIntOr(a['priority']);
          final pb = dbIntOr(b['priority']);
          if (pa != pb) return pb.compareTo(pa);
          final da = a['due_at'] as int?;
          final dbv = b['due_at'] as int?;
          if (da != null && dbv != null) return da.compareTo(dbv);
          if (da != null) return -1;
          if (dbv != null) return 1;
          return 0;
        });
        nextTitle = dbStr(open.first['title']);
        nextId = dbStr(open.first['id']);
      }
      branches.add(ProjectBranch(
        project: p,
        milestones: pMs,
        tasks: pTs,
        tasksDone: td,
        tasksTotal: tt,
        milestonesDone: md,
        milestonesTotal: mt,
        progressRatio: pr,
        nextTaskTitle: nextTitle,
        nextTaskId: nextId,
      ));
    }

    final projectsDone = projects.where((p) => dbStr(p['status']) == 'COMPLETED').length;
    final tasksDone = allTasks.where((t) => dbStr(t['status']) == 'COMPLETED').length;
    final milestonesDone = milestones.where((m) => dbStr(m['status']) == 'COMPLETED').length;
    final pt = projects.length;
    final tt = allTasks.length;
    final mt = milestones.length;
    double ratio = 0;
    if (tt + pt + mt > 0) {
      ratio = ((tt == 0 ? 0.0 : tasksDone / tt) * 0.55 +
              (pt == 0 ? 0.0 : projectsDone / pt) * 0.25 +
              (mt == 0 ? 0.0 : milestonesDone / mt) * 0.20)
          .clamp(0.0, 1.0);
    }

    final nextMoves = _buildNextMoves(branches: branches, directTasks: directTasks, habits: habits);
    final summary = _doingSummary(
      goalTitle: dbStr(goal['title'], 'this goal'),
      branches: branches,
      directOpen: directTasks.where((t) => dbStr(t['status']) != 'COMPLETED').length,
      habits: habits.length,
      scheduled: scheduled.length,
      progress: ratio,
    );

    return GoalThread(
      goal: goal,
      projects: projects,
      branches: branches,
      milestones: milestones,
      tasks: allTasks,
      directTasks: directTasks,
      habits: habits,
      scheduled: scheduled,
      activity: activity,
      nextMoves: nextMoves,
      doingSummary: summary,
      progressRatio: ratio,
      projectsDone: projectsDone,
      projectsTotal: pt,
      tasksDone: tasksDone,
      tasksTotal: tt,
      milestonesDone: milestonesDone,
      milestonesTotal: mt,
      habitsActive: habits.length,
    );
  }

  Future<List<Map<String, Object?>>> _habitsForGoal(dynamic db, String goalId) async {
    try {
      final byCol = await db.query(
        'habits',
        where: "goal_id = ? AND (status = 'ACTIVE' OR status IS NULL) AND archived_at IS NULL",
        whereArgs: [goalId],
        orderBy: 'title ASC',
      );
      if (byCol.isNotEmpty) return List<Map<String, Object?>>.from(byCol);
    } catch (_) {}
    try {
      return List<Map<String, Object?>>.from(await db.rawQuery('''
        SELECT h.* FROM habits h
        JOIN entity_links l ON (
          (l.from_type = 'GOAL' AND l.from_id = ? AND l.to_type = 'HABIT' AND l.to_id = h.id)
          OR (l.to_type = 'GOAL' AND l.to_id = ? AND l.from_type = 'HABIT' AND l.from_id = h.id)
          OR (l.source_type = 'GOAL' AND l.source_id = ? AND l.target_type = 'HABIT' AND l.target_id = h.id)
        )
        WHERE h.archived_at IS NULL
        ORDER BY h.title ASC
      ''', [goalId, goalId, goalId]));
    } catch (_) {
      return [];
    }
  }

  List<GoalNextMove> _buildNextMoves({
    required List<ProjectBranch> branches,
    required List<Map<String, Object?>> directTasks,
    required List<Map<String, Object?>> habits,
  }) {
    final moves = <GoalNextMove>[];
    for (final b in branches) {
      if (b.nextTaskId != null && b.nextTaskTitle != null) {
        moves.add(GoalNextMove(
          kind: 'TASK',
          id: b.nextTaskId!,
          title: b.nextTaskTitle!,
          reason: 'Next on “${dbStr(b.project['title'])}”',
          projectTitle: dbStr(b.project['title']),
        ));
      }
    }
    final openDirect = directTasks.where((t) => dbStr(t['status']) != 'COMPLETED').toList();
    for (final t in openDirect.take(3)) {
      moves.add(GoalNextMove(
        kind: 'TASK',
        id: dbStr(t['id']),
        title: dbStr(t['title']),
        reason: 'Direct work on this goal',
      ));
    }
    for (final h in habits.take(2)) {
      moves.add(GoalNextMove(
        kind: 'HABIT',
        id: dbStr(h['id']),
        title: dbStr(h['title']),
        reason: 'Supporting habit',
      ));
    }
    return moves.take(6).toList();
  }

  String _doingSummary({
    required String goalTitle,
    required List<ProjectBranch> branches,
    required int directOpen,
    required int habits,
    required int scheduled,
    required double progress,
  }) {
    if (branches.isEmpty && directOpen == 0 && habits == 0) {
      return 'Nothing is linked to “$goalTitle” yet. Add a project or habit to start moving.';
    }
    final parts = <String>[];
    parts.add('${(progress * 100).round()}% overall');
    if (branches.isNotEmpty) {
      final active = branches.where((b) => dbStr(b.project['status']) != 'COMPLETED').length;
      parts.add('$active active project${active == 1 ? '' : 's'}');
    }
    if (directOpen > 0) parts.add('$directOpen direct task${directOpen == 1 ? '' : 's'}');
    if (habits > 0) parts.add('$habits habit${habits == 1 ? '' : 's'}');
    if (scheduled > 0) parts.add('$scheduled on calendar this fortnight');
    return 'Toward “$goalTitle”: ${parts.join(' · ')}';
  }

  Future<ProjectThread> forProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [projectId], limit: 1);
    final project = rows.isEmpty ? <String, Object?>{'id': projectId, 'title': 'Project'} : rows.first;

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
    final tasks = await db.query(
      'tasks',
      where: "project_id = ? AND status != 'CANCELLED'",
      whereArgs: [projectId],
      orderBy: 'CASE status WHEN \'COMPLETED\' THEN 1 ELSE 0 END, due_at ASC, created_at DESC',
    );

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + const Duration(days: 14).inMilliseconds;
    final scheduled = tasks.where((t) {
      final s = t['scheduled_start'] as int?;
      return s != null && s >= dayStart && s <= dayEnd;
    }).toList()
      ..sort((a, b) => ((a['scheduled_start'] as int?) ?? 0).compareTo((b['scheduled_start'] as int?) ?? 0));

    final entityIds = <String>{
      projectId,
      if (goalId != null) goalId,
      ...milestones.map((m) => dbStr(m['id'])),
      ...tasks.map((t) => dbStr(t['id'])),
    };
    final activity = await _activityFor(entityIds.toList(), limit: 25);

    final tasksDone = tasks.where((t) => dbStr(t['status']) == 'COMPLETED').length;
    final milestonesDone =
        milestones.where((m) => dbStr(m['status']) == 'COMPLETED').length;
    final tt = tasks.length;
    final mt = milestones.length;
    final ratio = (tt + mt == 0)
        ? 0.0
        : ((tt == 0 ? 0.0 : tasksDone / tt) * 0.7 + (mt == 0 ? 0.0 : milestonesDone / mt) * 0.3)
            .clamp(0.0, 1.0);

    return ProjectThread(
      project: project,
      goal: goal,
      milestones: milestones,
      tasks: tasks,
      scheduled: scheduled,
      activity: activity,
      progressRatio: ratio,
      tasksDone: tasksDone,
      tasksTotal: tt,
      milestonesDone: milestonesDone,
      milestonesTotal: mt,
    );
  }

  Future<List<LifeThreadActivity>> _activityFor(List<String> entityIds, {int limit = 20}) async {
    if (entityIds.isEmpty) return [];
    final db = await _db.database;
    final placeholders = List.filled(entityIds.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT event_type, entity_type, entity_id, occurred_at
      FROM activity_events
      WHERE entity_id IN ($placeholders)
      ORDER BY occurred_at DESC
      LIMIT ?
      ''',
      [...entityIds, limit],
    );
    return rows
        .map((r) => LifeThreadActivity(
              eventType: dbStr(r['event_type']),
              entityType: dbStr(r['entity_type']),
              entityId: dbStr(r['entity_id']),
              occurredAt: dbIntOr(r['occurred_at']),
            ))
        .toList();
  }

  /// Link an existing habit to a goal (goal_id + entity_links fallback).
  Future<void> linkHabitToGoal({required String goalId, required String habitId}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    try {
      await db.update(
        'habits',
        {'goal_id': goalId, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [habitId],
      );
    } catch (_) {}
    try {
      await db.insert('entity_links', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'from_type': 'GOAL',
        'from_id': goalId,
        'to_type': 'HABIT',
        'to_id': habitId,
        'relation': 'SUPPORTS',
        'created_at': now,
      });
    } catch (_) {
      try {
        await db.insert('entity_links', {
          'id': AppDatabase.newId(),
          'source_type': 'GOAL',
          'source_id': goalId,
          'target_type': 'HABIT',
          'target_id': habitId,
          'relationship_type': 'SUPPORTS',
          'created_at': now,
        });
      } catch (_) {}
    }
  }
}
