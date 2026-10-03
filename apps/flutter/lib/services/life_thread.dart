import '../data/database.dart';
import '../domain/db_map.dart';

/// One coherent chain of the person's life work.
/// Goal → Project → Milestone → Task → Scheduled work → Completion → Activity.
class LifeThreadNode {
  final String kind; // GOAL | PROJECT | MILESTONE | TASK | EVENT
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

class GoalThread {
  final Map<String, Object?> goal;
  final List<Map<String, Object?>> projects;
  final List<Map<String, Object?>> milestones;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> scheduled;
  final List<LifeThreadActivity> activity;
  final double progressRatio;
  final int projectsDone;
  final int projectsTotal;
  final int tasksDone;
  final int tasksTotal;
  final int milestonesDone;
  final int milestonesTotal;

  const GoalThread({
    required this.goal,
    required this.projects,
    required this.milestones,
    required this.tasks,
    required this.scheduled,
    required this.activity,
    required this.progressRatio,
    required this.projectsDone,
    required this.projectsTotal,
    required this.tasksDone,
    required this.tasksTotal,
    required this.milestonesDone,
    required this.milestonesTotal,
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

    final tasks = await db.query(
      'tasks',
      where: "goal_id = ? AND status != 'CANCELLED'",
      whereArgs: [goalId],
      orderBy: 'CASE status WHEN \'COMPLETED\' THEN 1 ELSE 0 END, due_at ASC, created_at DESC',
    );

    // Also pull tasks under projects of this goal (even if goal_id not set on task)
    List<Map<String, Object?>> projectTasks = [];
    if (projectIds.isNotEmpty) {
      final placeholders = List.filled(projectIds.length, '?').join(',');
      projectTasks = await db.rawQuery(
        "SELECT * FROM tasks WHERE project_id IN ($placeholders) AND status != 'CANCELLED' ORDER BY created_at DESC",
        projectIds,
      );
    }
    final seen = <String>{};
    final allTasks = <Map<String, Object?>>[];
    for (final t in [...tasks, ...projectTasks]) {
      final id = dbStr(t['id']);
      if (seen.add(id)) allTasks.add(t);
    }

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + const Duration(days: 14).inMilliseconds;
    final scheduled = allTasks.where((t) {
      final s = t['scheduled_start'] as int?;
      return s != null && s >= dayStart && s <= dayEnd;
    }).toList()
      ..sort((a, b) => ((a['scheduled_start'] as int?) ?? 0).compareTo((b['scheduled_start'] as int?) ?? 0));

    final entityIds = <String>{goalId, ...projectIds, ...allTasks.map((t) => dbStr(t['id']))};
    final activity = await _activityFor(entityIds.toList(), limit: 30);

    final projectsDone = projects.where((p) => dbStr(p['status']) == 'COMPLETED').length;
    final tasksDone = allTasks.where((t) => dbStr(t['status']) == 'COMPLETED').length;
    final milestonesDone =
        milestones.where((m) => dbStr(m['status']) == 'COMPLETED').length;

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

    return GoalThread(
      goal: goal,
      projects: projects,
      milestones: milestones,
      tasks: allTasks,
      scheduled: scheduled,
      activity: activity,
      progressRatio: ratio,
      projectsDone: projectsDone,
      projectsTotal: pt,
      tasksDone: tasksDone,
      tasksTotal: tt,
      milestonesDone: milestonesDone,
      milestonesTotal: mt,
    );
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
}
