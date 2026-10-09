import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database.dart';
import '../../data/milestone_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/db_map.dart';
import '../../services/project_workspace.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/life_chain.dart';
import 'goal_detail_screen.dart';
import 'task_detail_screen.dart';

/// Full project workspace:
/// Overview · Goal · Progress · Next action · Milestones · Tasks/subtasks ·
/// Dependencies · Scheduled · Notes · Resources · Activity · Deadline
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  ProjectWorkspace? _ws;
  String? _loadError;
  bool _loading = true;

  final _projects = ProjectRepository(AppDatabase.instance);
  final _milestonesRepo = MilestoneRepository(AppDatabase.instance);
  final _tasksRepo = TaskRepository(AppDatabase.instance);
  final _workspace = ProjectWorkspaceService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final ws = await _workspace.load(widget.projectId);
      if (!mounted) return;
      setState(() {
        _ws = ws;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ws = null;
        _loading = false;
        _loadError = 'Could not load this project. Please try again.';
      });
    }
  }

  Future<void> _addTask({String? parentTaskId, String? milestoneId}) async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(parentTaskId == null ? 'New task' : 'Subtask',
            style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final goalId = dbStrOrNull(_ws?.project['goal_id']);
    await _tasksRepo.create(
      title: title,
      projectId: widget.projectId,
      goalId: goalId,
      milestoneId: milestoneId,
      parentTaskId: parentTaskId,
    );
    HapticFeedback.lightImpact();
    await _load();
  }

  Future<void> _addMilestone() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Milestone', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _milestonesRepo.create(projectId: widget.projectId, title: title);
    await _load();
  }

  Future<void> _setDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _projects.updateMeta(
      id: widget.projectId,
      targetDate: DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch,
    );
    await _load();
  }

  Future<void> _addNote() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Project note', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(hintText: 'Context, decision, link…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await _workspace.attachNote(projectId: widget.projectId, content: c.text.trim());
    await _load();
  }

  Future<void> _addResource() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Resource / file ref', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title or path'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await _workspace.attachResource(projectId: widget.projectId, title: c.text.trim());
    await _load();
  }

  Future<void> _scheduleNext() async {
    final na = _ws?.nextAction;
    if (na == null) return;
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (day == null) return;
    final start = DateTime(day.year, day.month, day.day, 9);
    await _tasksRepo.scheduleSession(taskId: na.taskId, start: start, durationMinutes: 45);
    await _load();
  }

  String _fmt(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtTime(int? ms) {
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.amber, size: 32),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.silver)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final ws = _ws;
    if (ws == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Project not found')));
    }
    final title = dbStr(ws.project['title'], 'Project');
    final goalTitle = ws.goal != null ? dbStr(ws.goal!['title']) : null;
    final goalId = ws.goal != null ? dbStr(ws.goal!['id']) : null;
    final desc = dbStrOrNull(ws.project['description']);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'deadline') await _setDeadline();
                if (v == 'note') await _addNote();
                if (v == 'resource') await _addResource();
                if (v == 'complete') {
                  await _projects.complete(widget.projectId);
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'deadline', child: Text('Set deadline')),
                PopupMenuItem(value: 'note', child: Text('Add note')),
                PopupMenuItem(value: 'resource', child: Text('Add resource')),
                PopupMenuItem(value: 'complete', child: Text('Mark project complete')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addTask(),
          icon: const Icon(Icons.add),
          label: const Text('Task'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // —— Overview / chain ——
            LifeChainBanner(
              steps: const ['Goal', 'Project', 'Milestone', 'Task', 'Schedule', 'Done'],
              subtitle:
                  '${(ws.progressRatio * 100).round()}% · ${ws.milestonesDone}/${ws.milestonesTotal} milestones · ${ws.tasksDone}/${ws.tasksTotal} tasks',
            ),
            const SizedBox(height: 10),

            // —— Next action (most important) ——
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Next action',
                        style: TextStyle(
                          color: AppTheme.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (ws.nextAction == null)
                    Text(
                      'No open work — add a task or mark a milestone.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45)),
                    )
                  else ...[
                    Text(
                      ws.nextAction!.title,
                      style: const TextStyle(
                        color: AppTheme.silver,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (ws.nextAction!.reason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ws.nextAction!.reason!,
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await _tasksRepo.complete(ws.nextAction!.taskId);
                            HapticFeedback.selectionClick();
                            await _load();
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Done'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(taskId: ws.nextAction!.taskId)))
                                .then((_) => _load());
                          },
                          child: const Text('Open'),
                        ),
                        OutlinedButton(
                          onPressed: _scheduleNext,
                          child: const Text('Schedule'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // —— Progress + deadline ——
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dbStr(ws.project['status'], 'ACTIVE'),
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                      const Spacer(),
                      if (ws.targetDate != null)
                        Text('Deadline ${_fmt(ws.targetDate)}',
                            style: TextStyle(color: AppTheme.woodLight, fontSize: 12))
                      else
                        TextButton(
                          onPressed: _setDeadline,
                          child: const Text('Set deadline', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ws.progressRatio,
                    backgroundColor: AppTheme.silver.withValues(alpha: 0.15),
                    color: AppTheme.amber,
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 8),
                    Text(desc, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ],
              ),
            ),

            // —— Goal ——
            if (goalTitle != null && goalId != null) ...[
              const SizedBox(height: 10),
              GlassCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goalId)),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppTheme.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Goal: $goalTitle', style: const TextStyle(color: AppTheme.silver)),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                  ],
                ),
              ),
            ],

            // —— Milestones ——
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Milestones', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addMilestone, child: const Text('Add')),
              ],
            ),
            if (ws.milestones.isEmpty)
              Text('Stages toward finishing this project.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...ws.milestones.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        title: Text(dbStr(m['title']), style: const TextStyle(color: AppTheme.silver)),
                        subtitle: Text(dbStr(m['status']),
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Add task to milestone',
                              icon: const Icon(Icons.add_task, color: AppTheme.silverMuted),
                              onPressed: () => _addTask(milestoneId: dbStr(m['id'])),
                            ),
                            if (dbStr(m['status']) != 'COMPLETED')
                              IconButton(
                                tooltip: 'Complete milestone',
                                icon: const Icon(Icons.flag, color: AppTheme.amber),
                                onPressed: () async {
                                  await _milestonesRepo.complete(dbStr(m['id']));
                                  await _load();
                                },
                              )
                            else
                              const Icon(Icons.flag, color: AppTheme.amber),
                          ],
                        ),
                      ),
                    ),
                  )),

            // —— Tasks + subtasks ——
            const SizedBox(height: 12),
            const Text('Tasks', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (ws.tasks.isEmpty)
              Text('Add the work that moves this project.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...ws.tasks.map((task) {
                final id = dbStr(task['id']);
                final children =
                    ws.subtasks.where((s) => dbStrOrNull(s['parent_task_id']) == id).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GlassCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
                          );
                          await _load();
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: ListTile(
                          title: Text(dbStr(task['title']), style: const TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            [
                              dbStr(task['status']),
                              if (dbStrOrNull(task['milestone_id']) != null)
                                'Milestone: ${ws.milestones.firstWhere((m) => dbStr(m['id']) == dbStr(task['milestone_id']))['title']}',
                              if (task['scheduled_start'] != null)
                                'sched ${_fmtTime(task['scheduled_start'] as int?)}',
                            ].join(' · '),
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Subtask',
                                icon: const Icon(Icons.subdirectory_arrow_right,
                                    color: AppTheme.silverMuted, size: 20),
                                onPressed: () => _addTask(parentTaskId: id),
                              ),
                              if (dbStr(task['status']) != 'COMPLETED')
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                  onPressed: () async {
                                    await _tasksRepo.complete(id);
                                    await _load();
                                  },
                                )
                              else
                                const Icon(Icons.check_circle, color: AppTheme.amber),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ...children.map((s) => Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 6),
                          child: GlassCard(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(taskId: dbStr(s['id']))),
                              );
                              await _load();
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.subdirectory_arrow_right,
                                  color: AppTheme.silverMuted, size: 18),
                              title: Text(dbStr(s['title']),
                                  style: const TextStyle(color: AppTheme.silver, fontSize: 14)),
                              trailing: dbStr(s['status']) != 'COMPLETED'
                                  ? IconButton(
                                      icon: const Icon(Icons.check_circle_outline,
                                          color: AppTheme.amber, size: 20),
                                      onPressed: () async {
                                        await _tasksRepo.complete(dbStr(s['id']));
                                        await _load();
                                      },
                                    )
                                  : const Icon(Icons.check_circle, color: AppTheme.amber, size: 18),
                            ),
                          ),
                        )),
                  ],
                );
              }),

            // —— Dependencies ——
            if (ws.dependencies.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Dependencies',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...ws.dependencies.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      child: Text(
                        'Blocked by: ${dbStr(d['depends_on_title'])} (${dbStr(d['depends_on_status'])})',
                        style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                      ),
                    ),
                  )),
            ],

            // —— Scheduled sessions ——
            if (ws.scheduled.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Scheduled sessions',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...ws.scheduled.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(taskId: dbStr(t['id']))))
                            .then((_) => _load());
                      },
                      child: Text(
                        '${_fmtTime(t['scheduled_start'] as int?)}  ·  ${dbStr(t['title'])}',
                        style: const TextStyle(color: AppTheme.silver),
                      ),
                    ),
                  )),
            ],

            // —— Notes ——
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Notes', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addNote, child: const Text('Add')),
              ],
            ),
            if (ws.notes.isEmpty)
              Text('Decisions, context, links for this project.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...ws.notes.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      child: Text(dbStr(n['content']),
                          style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    ),
                  )),

            // —— Resources ——
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Files / resources',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addResource, child: const Text('Add')),
              ],
            ),
            if (ws.resources.isEmpty)
              Text('References, docs, paths — offline pointers.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
            else
              ...ws.resources.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      child: Text(dbStr(r['title']), style: const TextStyle(color: AppTheme.silver)),
                    ),
                  )),

            // —— Activity ——
            const SizedBox(height: 16),
            const Text('Activity',
                style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ActivityTimeline(
              items: ws.activity
                  .map((a) => (
                        label: humanEvent(dbStr(a['event_type'])),
                        at: dbIntOr(a['occurred_at']),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
